import { migrateCategory } from './categories.ts';
import type { AiModel, NewsItem, Paper, Repo, Vulnerability } from './types.ts';
import { CATEGORIES } from './types.ts';

/**
 * Yayımlanacak her kaydın şemaya uyduğunu doğrular. Hatalı bir kayıt uygulamayı bozmasın diye
 * yayımlanmaz; önceki yayından okunan durum da aynı kontrolden geçer.
 */

type Check = (value: unknown) => boolean;

const isString: Check = (v) => typeof v === 'string';
const isNonEmpty: Check = (v) => typeof v === 'string' && v.trim().length > 0;
const isNullableString: Check = (v) => v === null || typeof v === 'string';
const isInt: Check = (v) => typeof v === 'number' && Number.isFinite(v);
const isNullableInt: Check = (v) => v === null || isInt(v);
const isBool: Check = (v) => typeof v === 'boolean';
const isIso: Check = (v) => typeof v === 'string' && !Number.isNaN(Date.parse(v));
const isNullableIso: Check = (v) => v === null || isIso(v);
const isHttps: Check = (v) => typeof v === 'string' && v.startsWith('https://');
const isStringArray: Check = (v) => Array.isArray(v) && v.every(isString);
const isDate: Check = (v) => typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v);
const isNullableDate: Check = (v) => v === null || isDate(v);

const isWriter: Check = (v) => v === null || v === 'ai' || v === 'mt';
const isNullableHttps: Check = (v) => v === null || isHttps(v);
const isNullableNumber: Check = (v) => v === null || isInt(v);

function isArticle(value: unknown): boolean {
  if (value === null) return true;
  if (!value || typeof value !== 'object') return false;
  const a = value as Record<string, unknown>;
  return (
    isNonEmpty(a['intro']) &&
    Array.isArray(a['primer']) &&
    (a['primer'] as unknown[]).every((p) => conforms(p, { term: isNonEmpty, explanation: isNonEmpty })) &&
    Array.isArray(a['sections']) &&
    (a['sections'] as unknown[]).length > 0 &&
    (a['sections'] as unknown[]).every((s) => conforms(s, { heading: isNonEmpty, body: isNonEmpty }))
  );
}

function isSections(value: unknown, allowEmpty: boolean): boolean {
  return (
    Array.isArray(value) &&
    (allowEmpty || value.length > 0) &&
    value.every((s) => conforms(s, { heading: isNonEmpty, body: isNonEmpty }))
  );
}

function isStoryVersion(value: unknown): boolean {
  return conforms(value, { intro: isNonEmpty }) && isSections((value as Record<string, unknown>)['sections'], false);
}

function isStory(value: unknown): boolean {
  if (value === null) return true;
  if (!value || typeof value !== 'object') return false;
  const s = value as Record<string, unknown>;
  return (
    isStringArray(s['tldr']) &&
    isNonEmpty(s['why']) &&
    isStoryVersion(s['simple']) &&
    (s['technical'] === null || isStoryVersion(s['technical'])) &&
    Array.isArray(s['glossary']) &&
    (s['glossary'] as unknown[]).every((g) =>
      conforms(g, { term: isNonEmpty, definition: isNonEmpty, analogy: isString, usage: isString, origin: isString }),
    ) &&
    (s['basis'] === 'full' || s['basis'] === 'excerpt')
  );
}

function isRepoStory(value: unknown): boolean {
  if (value === null) return true;
  return (
    conforms(value, { what: isNonEmpty, why: isNonEmpty, useCases: isStringArray, audience: isString, caution: isString }) &&
    ['readme', 'description'].includes((value as Record<string, unknown>)['basis'] as string)
  );
}

function conforms(value: unknown, shape: Record<string, Check>): boolean {
  if (!value || typeof value !== 'object') return false;
  const obj = value as Record<string, unknown>;
  return Object.entries(shape).every(([key, check]) => check(obj[key]));
}

const NEWS_SHAPE: Record<string, Check> = {
  id: isNonEmpty,
  url: isHttps,
  sourceId: isNonEmpty,
  sourceName: isNonEmpty,
  sourceKind: (v) => v === 'official' || v === 'news' || v === 'community',
  publishedAt: isIso,
  firstSeenAt: isIso,
  titleOriginal: isNonEmpty,
  excerptOriginal: isString,
  titleTr: isNullableString,
  summaryTr: isNullableString,
  category: (v) => CATEGORIES.includes(v as never),
  tags: isStringArray,
  translated: isBool,
  points: isNullableInt,
  comments: isNullableInt,
  discussionUrl: (v) => v === null || isHttps(v),
  imageUrl: isNullableHttps,
  article: isArticle,
  story: isStory,
  topics: isStringArray,
  importance: isNullableNumber,
  readingMinutes: isNullableNumber,
  writer: isWriter,
  writerVersion: isInt,
  hidden: isBool,
};

const MODEL_SHAPE: Record<string, Check> = {
  id: isNonEmpty,
  author: isNonEmpty,
  name: isNonEmpty,
  url: isHttps,
  pipelineTag: isNullableString,
  task: isNonEmpty,
  modality: (v) => ['text', 'vision', 'audio', 'multimodal', 'other'].includes(v as string),
  likes: isInt,
  downloads: isInt,
  trendingScore: isInt,
  rank: isInt,
  createdAt: isNullableIso,
  library: isNullableString,
  license: isNullableString,
  parameters: isNullableInt,
  summaryTr: isNullableString,
  summaryVersion: (v) => v === undefined || isInt(v),
  translated: isBool,
  cardExcerpt: isString,
  highlights: isStringArray,
  writer: isWriter,
};

const PAPER_SHAPE: Record<string, Check> = {
  id: isNonEmpty,
  url: isHttps,
  arxivUrl: isHttps,
  titleOriginal: isNonEmpty,
  abstractOriginal: isString,
  titleTr: isNullableString,
  summaryTr: isNullableString,
  upvotes: isInt,
  comments: isInt,
  publishedAt: isIso,
  authors: isStringArray,
  githubUrl: (v) => v === null || isHttps(v),
  tags: isStringArray,
  translated: isBool,
  imageUrl: isNullableHttps,
  article: isArticle,
  topics: isStringArray,
  readingMinutes: isNullableNumber,
  writer: isWriter,
  writerVersion: isInt,
};

const REPO_SHAPE: Record<string, Check> = {
  id: isNonEmpty,
  owner: isNonEmpty,
  name: isNonEmpty,
  url: isHttps,
  descriptionOriginal: isString,
  descriptionTr: isNullableString,
  language: isNullableString,
  stars: isInt,
  forks: isInt,
  createdAt: isIso,
  topics: isStringArray,
  isAi: isBool,
  translated: isBool,
  imageUrl: isNullableHttps,
  writer: isWriter,
  writerVersion: isInt,
  story: isRepoStory,
};

const KEV_SHAPE: Record<string, Check> = {
  id: isNonEmpty,
  cveId: (v) => typeof v === 'string' && /^CVE-\d{4}-\d{4,}$/.test(v),
  vendor: isNonEmpty,
  product: isNonEmpty,
  nameOriginal: isString,
  descriptionOriginal: isString,
  actionOriginal: isString,
  nameTr: isNullableString,
  descriptionTr: isNullableString,
  actionTr: isNullableString,
  dateAdded: isDate,
  dueDate: isNullableDate,
  ransomware: isBool,
  cwes: isStringArray,
  nvdUrl: isHttps,
  translated: isBool,
  explanationTr: isNullableString,
  writer: isWriter,
};

function keepValid<T>(label: string, items: unknown, shape: Record<string, Check>, warn: (msg: string) => void): T[] {
  if (!Array.isArray(items)) return [];
  const valid = items.filter((item) => conforms(item, shape)) as T[];
  if (valid.length !== items.length) warn(`${label}: ${items.length - valid.length} geçersiz kayıt atıldı`);
  return valid;
}

export const validate = {
  news: (items: unknown, warn: (m: string) => void = () => {}) => keepValid<NewsItem>('haberler', items, NEWS_SHAPE, warn),
  models: (items: unknown, warn: (m: string) => void = () => {}) => keepValid<AiModel>('modeller', items, MODEL_SHAPE, warn),
  papers: (items: unknown, warn: (m: string) => void = () => {}) => keepValid<Paper>('makaleler', items, PAPER_SHAPE, warn),
  repos: (items: unknown, warn: (m: string) => void = () => {}) => keepValid<Repo>('projeler', items, REPO_SHAPE, warn),
  security: (items: unknown, warn: (m: string) => void = () => {}) =>
    keepValid<Vulnerability>('güvenlik', items, KEV_SHAPE, warn),
};

// ---------------------------------------------------------------------------------------------
// Önceki sürümlerin yayımladığı kayıtlar yeni alanlardan yoksundur; doğrulamadan önce varsayılanlarla tamamlanır.

type Raw = Record<string, unknown>;

function obj(value: unknown): Raw | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? { ...(value as Raw) } : null;
}

function writerOf(item: Raw): 'ai' | 'mt' | null {
  if (item['writer'] === 'ai' || item['writer'] === 'mt') return item['writer'];
  return item['translated'] === true ? 'mt' : null;
}

function withDefaults(item: Raw, defaults: Raw): Raw {
  for (const [key, value] of Object.entries(defaults)) {
    if (item[key] === undefined) item[key] = value;
  }
  return item;
}

export const upgrade = {
  news(value: unknown): unknown {
    const item = obj(value);
    if (!item) return value;
    item['category'] = migrateCategory(item['category']) ?? 'industry';
    return withDefaults(item, {
      imageUrl: null,
      article: null,
      story: null,
      topics: [],
      importance: null,
      readingMinutes: null,
      writer: writerOf(item),
      writerVersion: 0,
      hidden: false,
    });
  },
  models(value: unknown): unknown {
    const item = obj(value);
    if (!item) return value;
    return withDefaults(item, { highlights: [], writer: writerOf(item) });
  },
  papers(value: unknown): unknown {
    const item = obj(value);
    if (!item) return value;
    return withDefaults(item, {
      imageUrl: null,
      article: null,
      topics: [],
      readingMinutes: null,
      writer: writerOf(item),
      writerVersion: 0,
    });
  },
  repos(value: unknown): unknown {
    const item = obj(value);
    if (!item) return value;
    return withDefaults(item, { imageUrl: null, writer: writerOf(item), writerVersion: 0, story: null });
  },
  security(value: unknown): unknown {
    const item = obj(value);
    if (!item) return value;
    return withDefaults(item, { explanationTr: null, writer: writerOf(item) });
  },
};
