import { Readability } from '@mozilla/readability';
import { parseHTML } from 'linkedom';
import { normalizeImageUrl } from './sources/rss.ts';
import { cleanText, truncate, USER_AGENT } from './util.ts';

/**
 * Haber sayfasından iki şey okunur:
 *  1. Kapak görseli (og:image / twitter:image): uygulamadaki kartlarda gösterilir.
 *  2. Haberin düz metni: yalnızca yapay zekâ editörüne kaynak olarak verilir, hiçbir yerde yayımlanmaz.
 */
export interface ArticlePage {
  imageUrl: string | null;
  text: string;
  description: string;
}

export const ARTICLE_TEXT_LIMIT = 12000;
const MAX_HTML_BYTES = 2_500_000;

function meta(document: Document, selectors: string[]): string {
  for (const selector of selectors) {
    const value = document.querySelector(selector)?.getAttribute('content')?.trim();
    if (value) return value;
  }
  return '';
}

/** HTML'den kapak görselini ve okunabilir metni çıkarır. */
export function extractArticle(html: string, pageUrl: string): ArticlePage {
  const { document } = parseHTML(html);
  const image = meta(document as unknown as Document, [
    'meta[property="og:image:secure_url"]',
    'meta[property="og:image"]',
    'meta[name="og:image"]',
    'meta[name="twitter:image"]',
    'meta[name="twitter:image:src"]',
    'meta[property="twitter:image"]',
  ]);
  const description = cleanText(
    meta(document as unknown as Document, ['meta[property="og:description"]', 'meta[name="description"]', 'meta[name="twitter:description"]']),
  );

  let text = '';
  try {
    const parsed = new Readability(document as unknown as Document, { charThreshold: 300 }).parse();
    if (parsed?.textContent) text = parsed.textContent;
  } catch {
    text = '';
  }
  if (text.replace(/\s+/g, ' ').trim().length < 400) {
    // Readability başaramazsa paragrafları doğrudan topla.
    const fresh = parseHTML(html).document;
    text = Array.from(fresh.querySelectorAll('article p, main p, p'))
      .map((p) => p.textContent ?? '')
      .filter((t) => t.trim().length > 40)
      .join('\n');
  }
  text = cleanText(text);

  return {
    imageUrl: normalizeImageUrl(image, pageUrl),
    text: truncate(text, ARTICLE_TEXT_LIMIT),
    description: truncate(description, 600),
  };
}

/** Haber sayfasını indirir; HTML değilse (ör. PDF) yalnızca boş sonuç döner. */
export async function fetchArticle(url: string, timeoutMs = 15_000): Promise<ArticlePage> {
  const empty: ArticlePage = { imageUrl: null, text: '', description: '' };
  const response = await fetch(url, {
    headers: { 'User-Agent': USER_AGENT, Accept: 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.5' },
    signal: AbortSignal.timeout(timeoutMs),
    redirect: 'follow',
  });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const type = response.headers.get('content-type') ?? '';
  if (type && !/html|xml/i.test(type)) {
    await response.body?.cancel();
    return empty;
  }
  const html = (await response.text()).slice(0, MAX_HTML_BYTES);
  return extractArticle(html, response.url || url);
}
