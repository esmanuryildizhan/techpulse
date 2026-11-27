import { errorMessage, log, sleep } from './util.ts';

/**
 * Yapay zekâ editörünün dil modeli istemcisi. Varsayılan sağlayıcı Anthropic'in Claude API'sidir
 * (model: claude-haiku-5-5). Yanıt, JSON şemasına uyan yapılandırılmış çıktı olarak istenir.
 */
export interface LlmRequest {
  /** Görev talimatı; aynı türdeki isteklerde aynıdır ve önbelleğe alınır. */
  system: string;
  /** Tek bir kayda ait girdi (kaynak haber metni vb.). */
  user: string;
  /** Yanıtın uyması gereken JSON şeması. */
  schema: Record<string, unknown>;
  maxTokens: number;
}

export interface LlmUsage {
  inputTokens: number;
  outputTokens: number;
}

export interface LlmResponse<T> {
  data: T;
  usage: LlmUsage;
}

export interface LlmClient {
  readonly model: string;
  complete<T>(request: LlmRequest): Promise<LlmResponse<T>>;
}

/** Anahtar geçersizse veya hesapta bakiye yoksa tekrar denemenin anlamı yoktur; bütün iş durur. */
export class LlmFatalError extends Error {}

export interface AnthropicOptions {
  apiKey: string;
  model?: string;
  effort?: 'low' | 'medium' | 'high';
  baseUrl?: string;
  fetchImpl?: typeof fetch;
  maxAttempts?: number;
  timeoutMs?: number;
}

interface AnthropicContentBlock {
  type: string;
  text?: string;
}

interface AnthropicResponse {
  content?: AnthropicContentBlock[];
  stop_reason?: string;
  usage?: { input_tokens?: number; output_tokens?: number; cache_read_input_tokens?: number; cache_creation_input_tokens?: number };
  error?: { type?: string; message?: string };
}

export function anthropicClient(options: AnthropicOptions): LlmClient {
  const model = options.model ?? 'claude-haiku-5-5';
  const effort = options.effort ?? 'low';
  const baseUrl = (options.baseUrl ?? 'https://api.anthropic.com').replace(/\/+$/, '');
  const doFetch = options.fetchImpl ?? fetch;
  const maxAttempts = options.maxAttempts ?? 5;
  const timeoutMs = options.timeoutMs ?? 300_000;

  async function call(request: LlmRequest, maxTokens: number): Promise<{ response: AnthropicResponse; status: number; retryAfter: number | null }> {
    const body = {
      model,
      max_tokens: maxTokens,
      // Haber yazımı muhakeme gerektirmez; düşünmeyi kapatmak maliyeti ve süreyi öngörülebilir kılar.
      thinking: { type: 'disabled' },
      system: [{ type: 'text', text: request.system, cache_control: { type: 'ephemeral' } }],
      messages: [{ role: 'user', content: request.user }],
      output_config: { effort, format: { type: 'json_schema', schema: request.schema } },
    };
    const res = await doFetch(`${baseUrl}/v1/messages`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': options.apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
    const retryHeader = res.headers.get('retry-after');
    const retryAfter = retryHeader && /^\d+(\.\d+)?$/.test(retryHeader) ? Number(retryHeader) * 1000 : null;
    let json: AnthropicResponse = {};
    try {
      json = (await res.json()) as AnthropicResponse;
    } catch {
      json = {};
    }
    return { response: json, status: res.status, retryAfter };
  }

  return {
    model,
    async complete<T>(request: LlmRequest): Promise<LlmResponse<T>> {
      let maxTokens = request.maxTokens;
      let lastError = '';
      for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        let result;
        try {
          result = await call(request, maxTokens);
        } catch (error) {
          lastError = `Bağlantı hatası: ${errorMessage(error)}`;
          await sleep(2000 * attempt);
          continue;
        }
        const { response, status, retryAfter } = result;
        const apiMessage = response.error?.message ?? '';
        if (status === 401 || status === 403) {
          throw new LlmFatalError(`Claude API anahtarı reddedildi (HTTP ${status}): ${apiMessage}`);
        }
        if (status === 400 && /credit|balance|billing/i.test(apiMessage)) {
          throw new LlmFatalError(`Claude API hesabında bakiye yok: ${apiMessage}`);
        }
        if (status === 429 || status === 529 || status >= 500) {
          lastError = `HTTP ${status} ${apiMessage}`.trim();
          const wait = retryAfter ?? Math.min(60_000, 3000 * 2 ** (attempt - 1));
          log.warn(`Claude API meşgul (${lastError}); ${Math.round(wait / 1000)} sn sonra yeniden denenecek.`);
          await sleep(wait);
          continue;
        }
        if (status !== 200) throw new Error(`Claude API hatası (HTTP ${status}): ${apiMessage}`);

        if (response.stop_reason === 'max_tokens') {
          lastError = 'Yanıt yarıda kesildi (max_tokens)';
          maxTokens = Math.min(maxTokens * 2, 32_000);
          continue;
        }
        if (response.stop_reason === 'refusal') throw new Error('Model bu içeriği yazmayı reddetti');
        const text = (response.content ?? []).filter((b) => b.type === 'text').map((b) => b.text ?? '').join('');
        let data: T;
        try {
          data = JSON.parse(text) as T;
        } catch {
          lastError = 'Yanıt JSON olarak okunamadı';
          continue;
        }
        const usage = response.usage ?? {};
        return {
          data,
          usage: {
            inputTokens: (usage.input_tokens ?? 0) + (usage.cache_read_input_tokens ?? 0) + (usage.cache_creation_input_tokens ?? 0),
            outputTokens: usage.output_tokens ?? 0,
          },
        };
      }
      throw new Error(lastError || 'Claude API yanıt vermedi');
    },
  };
}

// ---------------------------------------------------------------------------------------------
// Google Gemini (Google AI Studio). Ücretsiz katmanda dakikalık ve günlük istek sınırı vardır; istemci
// istekleri aralıklı gönderir, dakika sınırında bekler, bir modelin günlük kotası dolunca listedeki
// sıradaki modele geçer, hepsi dolunca editörü o çalışma için durdurur.

export interface GeminiOptions {
  apiKey: string;
  /** Sırayla denenecek modeller; her modelin günlük kotası ayrıdır. */
  models?: string[];
  baseUrl?: string;
  fetchImpl?: typeof fetch;
  maxAttempts?: number;
  timeoutMs?: number;
  /** İki istek arasındaki en kısa süre (ücretsiz katmanda dakikada 15 istek sınırı için ~4,5 sn). */
  minIntervalMs?: number;
  /** Bir çalışmada en fazla kaç istek gönderilir (günlük kotayı tek çalışmada bitirmemek için). */
  maxRequests?: number;
  sleepImpl?: (ms: number) => Promise<void>;
}

interface GeminiPart {
  text?: string;
  thought?: boolean;
}

interface GeminiResponse {
  candidates?: { content?: { parts?: GeminiPart[] }; finishReason?: string }[];
  usageMetadata?: { promptTokenCount?: number; candidatesTokenCount?: number; thoughtsTokenCount?: number };
  promptFeedback?: { blockReason?: string };
  error?: { code?: number; message?: string; status?: string; details?: { '@type'?: string; retryDelay?: string; violations?: { quotaId?: string }[] }[] };
}

export const GEMINI_DEFAULT_MODELS = ['gemini-3.5-flash-lite', 'gemini-3.1-flash-lite'];

/** Gemini'nin JSON şeması desteği OpenAPI alt kümesine dayanır; desteklemediği anahtarları çıkarır. */
export function geminiSchema(schema: unknown): unknown {
  if (Array.isArray(schema)) return schema.map(geminiSchema);
  if (!schema || typeof schema !== 'object') return schema;
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(schema as Record<string, unknown>)) {
    if (key === 'additionalProperties') continue;
    out[key] = geminiSchema(value);
  }
  return out;
}

function parseDelay(value: string | undefined): number | null {
  const match = value ? /^(\d+(?:\.\d+)?)s$/.exec(value) : null;
  return match ? Math.ceil(Number(match[1]) * 1000) : null;
}

export function geminiClient(options: GeminiOptions): LlmClient {
  const models = options.models && options.models.length > 0 ? [...options.models] : [...GEMINI_DEFAULT_MODELS];
  const baseUrl = (options.baseUrl ?? 'https://generativelanguage.googleapis.com').replace(/\/+$/, '');
  const doFetch = options.fetchImpl ?? fetch;
  const maxAttempts = options.maxAttempts ?? 6;
  const timeoutMs = options.timeoutMs ?? 300_000;
  const minInterval = options.minIntervalMs ?? 4500;
  const maxRequests = options.maxRequests ?? 150;
  const wait = options.sleepImpl ?? sleep;
  let current = 0;
  let sent = 0;
  let nextSlot = 0;

  /** İstekleri en az minInterval aralıkla başlatır (eşzamanlı işler sıraya girer). */
  async function slot(): Promise<void> {
    if (sent >= maxRequests) {
      throw new LlmFatalError(`Bu çalışmanın Gemini istek sınırına (${maxRequests}) ulaşıldı; kalan kayıtlar sonraki çalışmada yazılacak.`);
    }
    sent++;
    const now = Date.now();
    const at = Math.max(now, nextSlot);
    nextSlot = at + minInterval;
    if (at > now) await wait(at - now);
  }

  async function call(model: string, request: LlmRequest, maxTokens: number): Promise<{ response: GeminiResponse; status: number }> {
    await slot();
    const body = {
      systemInstruction: { parts: [{ text: request.system }] },
      contents: [{ role: 'user', parts: [{ text: request.user }] }],
      generationConfig: {
        responseMimeType: 'application/json',
        responseJsonSchema: geminiSchema(request.schema),
        maxOutputTokens: maxTokens,
        temperature: 0.7,
      },
    };
    const res = await doFetch(`${baseUrl}/v1beta/models/${model}:generateContent`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-goog-api-key': options.apiKey },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeoutMs),
    });
    let json: GeminiResponse = {};
    try {
      json = (await res.json()) as GeminiResponse;
    } catch {
      json = {};
    }
    return { response: json, status: res.status };
  }

  return {
    get model() {
      return models[current];
    },
    async complete<T>(request: LlmRequest): Promise<LlmResponse<T>> {
      let maxTokens = Math.max(request.maxTokens, 8000);
      let lastError = '';
      for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        const model = models[current];
        let result;
        try {
          result = await call(model, request, maxTokens);
        } catch (error) {
          if (error instanceof LlmFatalError) throw error;
          lastError = `Bağlantı hatası: ${errorMessage(error)}`;
          await wait(2000 * attempt);
          continue;
        }
        const { response, status } = result;
        const apiMessage = response.error?.message ?? '';
        if (status === 401 || status === 403 || (status === 400 && /API key/i.test(apiMessage))) {
          throw new LlmFatalError(`Gemini API anahtarı reddedildi (HTTP ${status}): ${apiMessage}`);
        }
        if (status === 429) {
          const details = response.error?.details ?? [];
          const quotaIds = details.flatMap((d) => d.violations ?? []).map((v) => v.quotaId ?? '');
          const daily = quotaIds.some((q) => /PerDay/i.test(q)) || /per day|daily/i.test(apiMessage);
          if (daily) {
            if (current < models.length - 1) {
              log.warn(`${model} modelinin ücretsiz günlük kotası doldu; ${models[current + 1]} modeline geçiliyor.`);
              current++;
              attempt--; // model değişimi bir deneme sayılmaz
              continue;
            }
            throw new LlmFatalError('Gemini ücretsiz günlük kotası doldu; kalan kayıtlar yarın yazılacak.');
          }
          const delay = details.map((d) => parseDelay(d.retryDelay)).find((d) => d !== null) ?? 20_000;
          lastError = `HTTP 429 ${apiMessage}`.trim();
          log.warn(`Gemini dakikalık sınırı (${model}); ${Math.round(delay / 1000)} sn bekleniyor.`);
          await wait(delay + 1000);
          continue;
        }
        if (status === 503 || status === 500 || status === 504) {
          lastError = `HTTP ${status} ${apiMessage}`.trim();
          await wait(Math.min(60_000, 4000 * 2 ** (attempt - 1)));
          continue;
        }
        if (status !== 200) throw new Error(`Gemini API hatası (HTTP ${status}): ${apiMessage}`);

        const candidate = response.candidates?.[0];
        const reason = candidate?.finishReason ?? response.promptFeedback?.blockReason ?? '';
        if (reason === 'MAX_TOKENS') {
          lastError = 'Yanıt yarıda kesildi (MAX_TOKENS)';
          maxTokens = Math.min(maxTokens * 2, 65_536);
          continue;
        }
        if (reason === 'RECITATION') {
          // Kaynak metne fazla benzeyen yanıt engellenir; yeni bir deneme genellikle özgün yazar.
          lastError = 'Yanıt kaynak metne fazla benzediği için engellendi';
          continue;
        }
        if (reason && reason !== 'STOP') throw new Error(`Gemini yanıtı engelledi (${reason})`);
        const text = (candidate?.content?.parts ?? []).filter((p) => !p.thought).map((p) => p.text ?? '').join('');
        let data: T;
        try {
          data = JSON.parse(text) as T;
        } catch {
          lastError = 'Yanıt JSON olarak okunamadı';
          continue;
        }
        const usage = response.usageMetadata ?? {};
        return {
          data,
          usage: {
            inputTokens: usage.promptTokenCount ?? 0,
            outputTokens: (usage.candidatesTokenCount ?? 0) + (usage.thoughtsTokenCount ?? 0),
          },
        };
      }
      throw new Error(lastError || 'Gemini API yanıt vermedi');
    },
  };
}
