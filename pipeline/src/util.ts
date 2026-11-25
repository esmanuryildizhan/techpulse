import { createHash } from 'node:crypto';
import { decodeHTML } from 'entities';

export const USER_AGENT =
  'Mozilla/5.0 (compatible; TechPulseBot/1.0; +https://github.com/techpulse; student project)';

/** Kısa ve kararlı kimlik: aynı girdi her zaman aynı kimliği üretir. */
export function stableId(input: string, length = 24): string {
  return createHash('sha256').update(input).digest('hex').slice(0, length);
}

const TRACKING_PARAMS = /^(utm_|fbclid$|gclid$|mc_cid$|mc_eid$|ref$|ref_src$|cmpid$|ncid$|sr_share$|guccounter$)/i;

/** Aynı haberin farklı izleme parametreleriyle iki kez görünmemesi için bağlantıyı sadeleştirir. */
export function canonicalUrl(raw: string): string | null {
  let url: URL;
  try {
    url = new URL(raw.trim());
  } catch {
    return null;
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return null;
  url.protocol = 'https:';
  url.hostname = url.hostname.toLowerCase();
  url.hash = '';
  for (const key of [...url.searchParams.keys()]) {
    if (TRACKING_PARAMS.test(key)) url.searchParams.delete(key);
  }
  if (url.pathname.length > 1 && url.pathname.endsWith('/')) url.pathname = url.pathname.replace(/\/+$/, '');
  return url.toString();
}

const INLINE_TAG_RE = /<\/?(?:a|b|strong|em|i|u|span|code|small|sup|sub|mark|abbr|time)(?:\s[^>]*)?>/gi;
const TAG_RE = /<[^>]*>/g;
const FEED_FOOTERS = [
  /The post .{1,200}? appeared first on .{1,120}?\.?$/i,
  /Continue reading\.{0,3}.*$/i,
  /Read more\.{0,3}$/i,
  /\[(?:…|\.\.\.|&#8230;)\]\s*$/,
  /Comments$/,
];

/** HTML etiketlerini ve varlıklarını temizleyip tek satırlık düz metin döndürür. */
export function cleanText(input: unknown): string {
  if (input === null || input === undefined) return '';
  let text = typeof input === 'string' ? input : String(input);
  // Bazı akışlar HTML'i iki kez kodlar (&amp;lt;p&amp;gt;); iki tur çözmek ikisini de karşılar.
  text = decodeHTML(text);
  text = text.replace(/<(script|style|figure|figcaption)[\s\S]*?<\/\1>/gi, ' ');
  text = text.replace(/<br\s*\/?>/gi, ' ').replace(/<\/p>/gi, ' ');
  text = text.replace(INLINE_TAG_RE, '').replace(TAG_RE, ' ');
  text = decodeHTML(text);
  text = text.replace(/\s+/g, ' ').replace(/\s+([,.;:!?)])/g, '$1').trim();
  for (const footer of FEED_FOOTERS) text = text.replace(footer, '').trim();
  return text;
}

/** Metni kelime sınırında keser ve sonuna üç nokta ekler. */
export function truncate(text: string, max: number): string {
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  const lastSpace = cut.lastIndexOf(' ');
  return (lastSpace > max * 0.6 ? cut.slice(0, lastSpace) : cut).replace(/[\s,.;:–-]+$/, '') + '…';
}

/** Akışlardaki farklı tarih biçimlerini ISO 8601'e çevirir; çözülemezse null. */
export function toIsoDate(value: unknown): string | null {
  if (value === null || value === undefined || value === '') return null;
  const ms = Date.parse(String(value).trim());
  if (Number.isNaN(ms)) return null;
  // Gelecekte görünen tarihleri (yanlış saat dilimi) şimdiye çek.
  const clamped = Math.min(ms, Date.now() + 5 * 60_000);
  return new Date(clamped).toISOString();
}

export function daysAgo(days: number, from = Date.now()): number {
  return from - days * 86_400_000;
}

export function asArray<T>(value: T | T[] | undefined | null): T[] {
  if (value === undefined || value === null) return [];
  return Array.isArray(value) ? value : [value];
}

export function toInt(value: unknown, fallback = 0): number {
  const n = typeof value === 'number' ? value : Number.parseInt(String(value ?? ''), 10);
  return Number.isFinite(n) ? Math.trunc(n) : fallback;
}

export function str(value: unknown): string {
  if (value === null || value === undefined) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'object' && '#text' in (value as Record<string, unknown>)) {
    return String((value as Record<string, unknown>)['#text'] ?? '');
  }
  return String(value);
}

export interface FetchOptions {
  timeoutMs?: number;
  headers?: Record<string, string>;
  retries?: number;
}

export class HttpError extends Error {
  readonly status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

/** Zaman aşımlı ve geçici hatalarda bir kez yeniden deneyen GET isteği. */
export async function fetchText(url: string, options: FetchOptions = {}): Promise<string> {
  const { timeoutMs = 20_000, headers = {}, retries = 1 } = options;
  let lastError: unknown;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const response = await fetch(url, {
        headers: { 'User-Agent': USER_AGENT, Accept: '*/*', ...headers },
        signal: AbortSignal.timeout(timeoutMs),
        redirect: 'follow',
      });
      if (!response.ok) {
        const error = new HttpError(response.status, `HTTP ${response.status} (${url})`);
        if (response.status >= 500 || response.status === 429) {
          lastError = error;
          await sleep(1500 * (attempt + 1));
          continue;
        }
        throw error;
      }
      return await response.text();
    } catch (error) {
      lastError = error;
      if (error instanceof HttpError && error.status < 500 && error.status !== 429) throw error;
      if (attempt < retries) await sleep(1500 * (attempt + 1));
    }
  }
  throw lastError instanceof Error ? lastError : new Error(String(lastError));
}

export async function fetchJson<T = unknown>(url: string, options: FetchOptions = {}): Promise<T> {
  const text = await fetchText(url, {
    ...options,
    headers: { Accept: 'application/json', ...(options.headers ?? {}) },
  });
  return JSON.parse(text) as T;
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function errorMessage(error: unknown): string {
  if (error instanceof Error) return error.message.slice(0, 200);
  return String(error).slice(0, 200);
}

/** Sınırlı eşzamanlılıkla eşleme: aynı anda en fazla `limit` iş çalışır. */
export async function mapLimit<T, R>(items: T[], limit: number, fn: (item: T, index: number) => Promise<R>): Promise<R[]> {
  const results = new Array<R>(items.length);
  let next = 0;
  async function worker(): Promise<void> {
    while (next < items.length) {
      const index = next++;
      results[index] = await fn(items[index], index);
    }
  }
  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, () => worker()));
  return results;
}

// Testler sırasında (NODE_TEST_CONTEXT) çıktı üretmeyiz; test çalıştırıcısının kanalını bozmasın.
const quiet = Boolean(process.env.NODE_TEST_CONTEXT) || process.env.TECHPULSE_QUIET === '1';

export const log = {
  info: (...args: unknown[]) => {
    if (!quiet) console.log('•', ...args);
  },
  warn: (...args: unknown[]) => {
    if (!quiet) console.warn('⚠', ...args);
  },
  error: (...args: unknown[]) => console.error('✖', ...args),
};
