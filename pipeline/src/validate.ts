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
  translated: isBool,
  cardExcerpt: isString,
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
