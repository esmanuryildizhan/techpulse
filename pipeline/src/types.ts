// TechPulse veri sözleşmesi. Mobil uygulamadaki Dart modelleri bu alan adlarını okur;
// bir alanı değiştirmeden önce app/lib/data/models klasöründeki karşılığını da değiştirin.

export const SCHEMA_VERSION = 1;

export type Category = 'ai' | 'software' | 'hardware' | 'security' | 'industry';
export const CATEGORIES: readonly Category[] = ['ai', 'software', 'hardware', 'security', 'industry'];

export type SourceKind = 'official' | 'news' | 'community';

export interface FeedSource {
  id: string;
  name: string;
  kind: SourceKind;
  /** RSS veya Atom adresi */
  url: string;
  homepage: string;
  defaultCategory: Category;
  /** Bir çalışmada bu kaynaktan alınacak en fazla haber */
  maxItems: number;
}

/** Kaynaktan yeni okunmuş, henüz çevrilmemiş haber */
export interface RawNews {
  id: string;
  url: string;
  sourceId: string;
  title: string;
  excerpt: string;
  publishedAt: string | null;
  points?: number;
  comments?: number;
  discussionUrl?: string;
}

export interface NewsItem {
  id: string;
  url: string;
  sourceId: string;
  sourceName: string;
  sourceKind: SourceKind;
  publishedAt: string;
  firstSeenAt: string;
  titleOriginal: string;
  excerptOriginal: string;
  titleTr: string | null;
  summaryTr: string | null;
  category: Category;
  tags: string[];
  translated: boolean;
  points: number | null;
  comments: number | null;
  discussionUrl: string | null;
}

export type Modality = 'text' | 'vision' | 'audio' | 'multimodal' | 'other';

export interface AiModel {
  id: string;
  author: string;
  name: string;
  url: string;
  pipelineTag: string | null;
  task: string;
  modality: Modality;
  likes: number;
  downloads: number;
  trendingScore: number;
  rank: number;
  createdAt: string | null;
  library: string | null;
  license: string | null;
  parameters: number | null;
  summaryTr: string | null;
  translated: boolean;
  /** Model kartından çıkarılan kısa metin; yalnızca çeviri için tutulur */
  cardExcerpt: string;
}

export interface Paper {
  id: string;
  url: string;
  arxivUrl: string;
  titleOriginal: string;
  abstractOriginal: string;
  titleTr: string | null;
  summaryTr: string | null;
  upvotes: number;
  comments: number;
  publishedAt: string;
  authors: string[];
  githubUrl: string | null;
  tags: string[];
  translated: boolean;
}

export interface Repo {
  id: string;
  owner: string;
  name: string;
  url: string;
  descriptionOriginal: string;
  descriptionTr: string | null;
  language: string | null;
  stars: number;
  forks: number;
  createdAt: string;
  topics: string[];
  isAi: boolean;
  translated: boolean;
}

export interface Vulnerability {
  id: string;
  cveId: string;
  vendor: string;
  product: string;
  nameOriginal: string;
  descriptionOriginal: string;
  actionOriginal: string;
  nameTr: string | null;
  descriptionTr: string | null;
  actionTr: string | null;
  dateAdded: string;
  dueDate: string | null;
  ransomware: boolean;
  cwes: string[];
  nvdUrl: string;
  translated: boolean;
}

export interface Envelope<T> {
  schemaVersion: number;
  generatedAt: string;
  items: T[];
}

export interface SourceStatus {
  id: string;
  name: string;
  kind: SourceKind | 'data';
  homepage: string;
  ok: boolean;
  count: number;
  error: string | null;
  checkedAt: string;
}

export interface Meta {
  schemaVersion: number;
  generatedAt: string;
  translator: {
    model: string | null;
    requests: number;
    translatedItems: number;
    pendingItems: number;
    note: string | null;
  };
  counts: Record<'news' | 'models' | 'papers' | 'repos' | 'security', number>;
  sources: SourceStatus[];
}

export interface State {
  news: NewsItem[];
  models: AiModel[];
  papers: Paper[];
  repos: Repo[];
  security: Vulnerability[];
}
