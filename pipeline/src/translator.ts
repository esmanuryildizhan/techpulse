import { errorMessage, log, sleep } from './util.ts';

/**
 * GitHub Models istemcisi. GitHub Actions içinde, iş akışına `models: read` izni verildiğinde
 * hazır GITHUB_TOKEN ile ücretsiz (oran sınırlı) dil modeli çağrısı yapılabilir; ayrıca API
 * anahtarı gerekmez. Sınıra takılırsak bu çalışmada çeviriyi bırakır, bekleyen kayıtları bir
 * sonraki saatlik çalışmaya bırakırız: hat hiçbir zaman çeviri yüzünden durmaz.
 */

export const DEFAULT_ENDPOINT = 'https://models.github.ai/inference/chat/completions';
export const DEFAULT_CATALOG = 'https://models.github.ai/catalog/models';
export const PREFERRED_MODELS = [
  'openai/gpt-4.1-mini',
  'openai/gpt-4o-mini',
  'openai/gpt-5-mini',
  'openai/gpt-4.1-nano',
  'meta/llama-3.3-70b-instruct',
];

export interface TranslatorOptions {
  token?: string;
  endpoint?: string;
  catalogUrl?: string;
  preferredModels?: string[];
  forcedModel?: string;
  maxRequests?: number;
  deadline?: number;
  fetchImpl?: typeof fetch;
  retryDelayMs?: number;
}

export class Translator {
  readonly token: string | undefined;
  readonly endpoint: string;
  readonly catalogUrl: string;
  readonly maxRequests: number;
  readonly deadline: number;
  private readonly fetchImpl: typeof fetch;
  private readonly retryDelayMs: number;
  private candidates: string[];
  private jsonMode = true;
  model: string | null = null;
  requests = 0;
  disabledReason: string | null = null;

  constructor(options: TranslatorOptions = {}) {
    this.token = options.token;
    this.endpoint = options.endpoint ?? DEFAULT_ENDPOINT;
    this.catalogUrl = options.catalogUrl ?? DEFAULT_CATALOG;
    this.maxRequests = options.maxRequests ?? 40;
    this.deadline = options.deadline ?? Date.now() + 10 * 60_000;
    this.fetchImpl = options.fetchImpl ?? fetch;
    this.retryDelayMs = options.retryDelayMs ?? 4000;
    this.candidates = options.forcedModel ? [options.forcedModel] : [...(options.preferredModels ?? PREFERRED_MODELS)];
    if (!this.token) this.disabledReason = 'GITHUB_TOKEN yok; çeviri atlandı';
  }

  get available(): boolean {
    return !this.disabledReason && this.requests < this.maxRequests && Date.now() < this.deadline;
  }

  get stopReason(): string | null {
    if (this.disabledReason) return this.disabledReason;
    if (this.requests >= this.maxRequests) return `Bu çalışmanın istek bütçesi (${this.maxRequests}) doldu`;
    if (Date.now() >= this.deadline) return 'Bu çalışmanın süresi doldu';
    return null;
  }

  /** Katalogdan tercih sırasına göre kullanılabilir ilk modeli seçer. */
  async init(): Promise<void> {
    if (!this.token || this.candidates.length <= 1) return;
    try {
      const response = await this.fetchImpl(this.catalogUrl, {
        headers: { Authorization: `Bearer ${this.token}`, Accept: 'application/json' },
        signal: AbortSignal.timeout(15_000),
      });
      if (!response.ok) return;
      const catalog = (await response.json()) as unknown;
      if (!Array.isArray(catalog)) return;
      // Katalogdaki her model için oran sınırı katmanı ("low" katmanın günlük kotası daha yüksek).
      const tiers = new Map<string, string>();
      for (const entry of catalog) {
        const id = String((entry as { id?: unknown }).id ?? '').toLowerCase();
        if (id) tiers.set(id, String((entry as { rate_limit_tier?: unknown }).rate_limit_tier ?? ''));
      }
      const available = this.candidates.filter((id) => tiers.has(id.toLowerCase()));
      if (available.length > 0) {
        const low = available.filter((id) => tiers.get(id.toLowerCase()) === 'low');
        const rest = available.filter((id) => tiers.get(id.toLowerCase()) !== 'low');
        this.candidates = [...low, ...rest];
      }
    } catch (error) {
      log.warn('Model kataloğu okunamadı:', errorMessage(error));
    }
  }

  /**
   * Sohbet tamamlama isteği atar ve modelin döndürdüğü JSON'u çözer.
   * Başarısız olursa null döner; kalıcı hatalarda çeviriyi bu çalışma için kapatır.
   */
  async completeJson(system: string, user: string, maxTokens = 3000): Promise<unknown | null> {
    while (this.available && this.candidates.length > 0) {
      const model = this.candidates[0];
      this.requests++;
      const body: Record<string, unknown> = {
        model,
        temperature: 0.2,
        max_tokens: maxTokens,
        messages: [
          { role: 'system', content: system },
          { role: 'user', content: user },
        ],
      };
      if (this.jsonMode) body.response_format = { type: 'json_object' };

      let response: Response;
      try {
        response = await this.fetchImpl(this.endpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${this.token}`,
            'Content-Type': 'application/json',
            Accept: 'application/json',
          },
          body: JSON.stringify(body),
          signal: AbortSignal.timeout(90_000),
        });
      } catch (error) {
        log.warn(`Çeviri isteği ağ hatası (${model}):`, errorMessage(error));
        await sleep(this.retryDelayMs);
        return null;
      }

      if (response.ok) {
        this.model = model;
        const payload = (await response.json().catch(() => null)) as
          | { choices?: { message?: { content?: string } }[] }
          | null;
        const content = payload?.choices?.[0]?.message?.content ?? '';
        const parsed = parseModelJson(content);
        if (parsed === null) log.warn('Model geçerli JSON döndürmedi; bu parti sonraki çalışmaya kaldı.');
        return parsed;
      }

      const text = (await response.text().catch(() => '')).slice(0, 300);
      if (response.status === 401 || response.status === 403) {
        this.disabledReason = `GitHub Models erişimi reddedildi (HTTP ${response.status}). İş akışında "models: read" izni olmalı.`;
        return null;
      }
      if (response.status === 429) {
        this.disabledReason = 'GitHub Models oran sınırına ulaşıldı; bekleyenler sonraki çalışmada çevrilecek.';
        return null;
      }
      if (response.status === 400 && this.jsonMode && /response_format|json/i.test(text)) {
        this.jsonMode = false; // model JSON modunu desteklemiyor; komutla isteyelim
        continue;
      }
      if (response.status === 404 || (response.status === 400 && /model/i.test(text))) {
        log.warn(`Model kullanılamıyor (${model}): HTTP ${response.status}. Sıradaki deneniyor.`);
        this.candidates.shift();
        continue;
      }
      if (response.status === 413) {
        log.warn('Parti modele göre fazla büyük; bu parti atlandı.');
        return null;
      }
      log.warn(`Çeviri isteği başarısız: HTTP ${response.status} ${text}`);
      await sleep(this.retryDelayMs);
      return null;
    }
    if (this.candidates.length === 0 && !this.disabledReason) {
      this.disabledReason = 'Kullanılabilir bir dil modeli bulunamadı.';
    }
    return null;
  }
}

/** Model cevabındaki JSON'u çözer; kod bloğu işaretlerini ve öndeki/arkadaki metni tolere eder. */
export function parseModelJson(content: string): unknown | null {
  if (!content) return null;
  let text = content.trim();
  const fence = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fence) text = fence[1].trim();
  try {
    return JSON.parse(text);
  } catch {
    const start = text.search(/[[{]/);
    const end = Math.max(text.lastIndexOf('}'), text.lastIndexOf(']'));
    if (start >= 0 && end > start) {
      try {
        return JSON.parse(text.slice(start, end + 1));
      } catch {
        return null;
      }
    }
    return null;
  }
}
