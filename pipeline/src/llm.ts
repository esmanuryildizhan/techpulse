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
  const timeoutMs = options.timeoutMs ?? 120_000;

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
          maxTokens = Math.min(maxTokens * 2, 16_000);
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
