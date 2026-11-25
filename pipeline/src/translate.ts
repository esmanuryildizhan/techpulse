import { classify } from './classify.ts';
import { findSource } from './sources/feeds.ts';
import type { AiModel, Category, NewsItem, Paper, Repo, Vulnerability } from './types.ts';
import { CATEGORIES } from './types.ts';
import type { Translator } from './translator.ts';
import { log, truncate } from './util.ts';

const STYLE = `You are a senior Turkish technology editor. You turn English technology content into accurate, natural Turkish for a mobile app read by Turkish software developers, engineers and computer-engineering students.
Rules:
- Write fluent, natural Turkish; do not translate word for word. Use correct Turkish grammar, spelling and punctuation (e.g. "yapay zekâ").
- Keep names of companies, products, models, datasets, libraries, programming languages, CVE ids and version numbers exactly as in the source.
- Prefer established Turkish technical terms: yapay zekâ, makine öğrenmesi, derin öğrenme, büyük dil modeli, güvenlik açığı, yama, açık kaynak, geliştirici, işlemci, ekran kartı, veri kümesi, çıkarım. If a term has no common Turkish equivalent, keep the English term.
- Never add facts, numbers, opinions or context that are not in the input. Do not speculate.
- No markdown, no emojis, no surrounding quotation marks.
- Return only valid JSON in exactly the requested shape, one object per input item, with the same "id" values.`;

const NEWS_SYSTEM = `${STYLE}
For each news item return:
- "title_tr": the headline in Turkish, max 110 characters, informative, no clickbait, no trailing period.
- "summary_tr": 1–3 sentences, max 320 characters, summarising only what the snippet says. If the snippet is empty or too short to summarise, return "".
- "category": exactly one of "ai" (artificial intelligence, machine learning, models, AI products), "software" (programming, developer tools, operating systems, apps, open source, cloud), "hardware" (chips, GPUs, devices, phones, PCs, semiconductors), "security" (vulnerabilities, attacks, malware, breaches, privacy incidents), "industry" (business, funding, acquisitions, regulation, policy, companies, society).
- "tags": 0–3 short tags (proper nouns or technologies such as "OpenAI", "Rust", "CVE-2026-1234"), no "#".
JSON shape: {"items":[{"id":"","title_tr":"","summary_tr":"","category":"","tags":[]}]}`;

const PAPER_SYSTEM = `${STYLE}
For each research paper return:
- "title_tr": the title in Turkish, max 150 characters. Keep method/model names (e.g. "SAM 3", "LoRA") as they are.
- "summary_tr": 2–3 sentences, max 420 characters, for a machine-learning student: which problem it addresses, what the method does, and the main result as stated in the abstract. Only use information from the abstract.
- "tags": 1–3 short topic tags in Turkish or established English (e.g. "Görüntü bölütleme", "Difüzyon modelleri", "LLM", "Pekiştirmeli öğrenme").
JSON shape: {"items":[{"id":"","title_tr":"","summary_tr":"","tags":[]}]}`;

const MODEL_SYSTEM = `${STYLE}
For each Hugging Face model return:
- "summary_tr": 1–2 sentences, max 260 characters, explaining what the model is and what it is for, using only the model card text, task and parameter count given. If the card text is empty or uninformative, return "".
JSON shape: {"items":[{"id":"","summary_tr":""}]}`;

const REPO_SYSTEM = `${STYLE}
For each GitHub repository return:
- "description_tr": one sentence, max 180 characters, that explains in Turkish what the project does, based only on its description and topics. If the description is empty, return "".
JSON shape: {"items":[{"id":"","description_tr":""}]}`;

const KEV_SYSTEM = `${STYLE}
For each actively exploited vulnerability from the CISA KEV catalog return:
- "name_tr": the vulnerability name in Turkish, max 120 characters (e.g. "Microsoft Windows Yetki Yükseltme Açığı").
- "description_tr": the description in Turkish, max 420 characters, technically precise.
- "action_tr": the required action in Turkish, max 300 characters.
JSON shape: {"items":[{"id":"","name_tr":"","description_tr":"","action_tr":""}]}`;

/** Model çıktısındaki metni temizler; sınırı aşanı kısaltır. */
export function tidy(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  let text = value
    .replace(/\*\*|__|`/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/^["'“”‘’«»]+|["'“”‘’«»]+$/g, '')
    .replace(/^(özet|başlık|açıklama)\s*:\s*/i, '')
    .trim();
  if (text.length > max) text = truncate(text, max);
  return text;
}

function tidyTags(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const out: string[] = [];
  for (const tag of value) {
    const clean = tidy(tag, 28).replace(/^#/, '');
    if (clean && !out.some((t) => t.toLowerCase() === clean.toLowerCase())) out.push(clean);
    if (out.length >= 3) break;
  }
  return out;
}

function resultsById(parsed: unknown): Map<string, Record<string, unknown>> {
  const map = new Map<string, Record<string, unknown>>();
  let list: unknown = parsed;
  if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
    const obj = parsed as Record<string, unknown>;
    list = obj.items ?? obj.results ?? obj.data ?? Object.values(obj).find(Array.isArray);
  }
  if (!Array.isArray(list)) return map;
  for (const entry of list) {
    if (entry && typeof entry === 'object' && typeof (entry as Record<string, unknown>).id === 'string') {
      map.set((entry as Record<string, unknown>).id as string, entry as Record<string, unknown>);
    }
  }
  return map;
}

function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

async function runBatches<T extends { id: string }>(
  label: string,
  translator: Translator,
  pending: T[],
  batchSize: number,
  system: string,
  toInput: (item: T) => Record<string, unknown>,
  apply: (item: T, result: Record<string, unknown>) => boolean,
  maxTokens = 3000,
): Promise<number> {
  let done = 0;
  for (const batch of chunk(pending, batchSize)) {
    if (!translator.available) break;
    const user = JSON.stringify({ items: batch.map((item) => ({ id: item.id, ...toInput(item) })) });
    const parsed = await translator.completeJson(system, user, maxTokens);
    if (parsed === null) continue;
    const results = resultsById(parsed);
    for (const item of batch) {
      const result = results.get(item.id);
      if (result && apply(item, result)) done++;
    }
  }
  if (pending.length > 0) log.info(`Çeviri [${label}]: ${done}/${pending.length} kayıt çevrildi.`);
  return done;
}

export async function translateNews(translator: Translator, items: NewsItem[]): Promise<number> {
  const pending = items.filter((item) => !item.translated);
  return runBatches(
    'haberler',
    translator,
    pending,
    8,
    NEWS_SYSTEM,
    (item) => ({ source: item.sourceName, title: item.titleOriginal, snippet: truncate(item.excerptOriginal, 600) }),
    (item, result) => {
      const title = tidy(result.title_tr, 140);
      if (!title) return false;
      item.titleTr = title;
      item.summaryTr = tidy(result.summary_tr, 360) || null;
      const category = String(result.category ?? '') as Category;
      if (CATEGORIES.includes(category)) item.category = category;
      item.tags = tidyTags(result.tags);
      item.translated = true;
      return true;
    },
  );
}

export async function translatePapers(translator: Translator, items: Paper[]): Promise<number> {
  const pending = items.filter((item) => !item.translated);
  return runBatches(
    'makaleler',
    translator,
    pending,
    5,
    PAPER_SYSTEM,
    (item) => ({ title: item.titleOriginal, abstract: truncate(item.abstractOriginal, 1400) }),
    (item, result) => {
      const title = tidy(result.title_tr, 170);
      const summary = tidy(result.summary_tr, 460);
      if (!title || !summary) return false;
      item.titleTr = title;
      item.summaryTr = summary;
      const tags = tidyTags(result.tags);
      if (tags.length > 0) item.tags = tags;
      item.translated = true;
      return true;
    },
  );
}

export async function translateModels(translator: Translator, items: AiModel[]): Promise<number> {
  const pending = items.filter((item) => !item.translated && item.cardExcerpt.length >= 80);
  return runBatches(
    'modeller',
    translator,
    pending,
    5,
    MODEL_SYSTEM,
    (item) => ({
      model: item.id,
      task: item.pipelineTag ?? 'unknown',
      parameters: item.parameters,
      card: truncate(item.cardExcerpt, 1500),
    }),
    (item, result) => {
      item.summaryTr = tidy(result.summary_tr, 300) || null;
      item.translated = true;
      return true;
    },
  );
}

export async function translateRepos(translator: Translator, items: Repo[]): Promise<number> {
  const pending = items.filter((item) => !item.translated && item.descriptionOriginal.length > 0);
  return runBatches(
    'projeler',
    translator,
    pending,
    10,
    REPO_SYSTEM,
    (item) => ({ name: item.id, description: item.descriptionOriginal, topics: item.topics }),
    (item, result) => {
      item.descriptionTr = tidy(result.description_tr, 220) || null;
      item.translated = true;
      return true;
    },
    2000,
  );
}

export async function translateKev(translator: Translator, items: Vulnerability[]): Promise<number> {
  const pending = items.filter((item) => !item.translated);
  return runBatches(
    'güvenlik',
    translator,
    pending,
    6,
    KEV_SYSTEM,
    (item) => ({
      name: item.nameOriginal,
      vendor: item.vendor,
      product: item.product,
      description: item.descriptionOriginal,
      action: item.actionOriginal,
    }),
    (item, result) => {
      const name = tidy(result.name_tr, 160);
      const description = tidy(result.description_tr, 480);
      if (!name || !description) return false;
      item.nameTr = name;
      item.descriptionTr = description;
      item.actionTr = tidy(result.action_tr, 340) || null;
      item.translated = true;
      return true;
    },
  );
}

/** Çevrilemeyen haberler için anahtar kelimeyle konu tahmini. */
export function applyFallbackCategories(items: NewsItem[]): void {
  for (const item of items) {
    if (item.translated) continue;
    const source = findSource(item.sourceId);
    item.category = classify(item.titleOriginal, item.excerptOriginal, source?.defaultCategory ?? 'industry');
  }
}
