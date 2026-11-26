// TechPulse veri sözleşmesi. Mobil uygulamadaki Dart modelleri bu alan adlarını okur;
// bir alanı değiştirmeden önce app/lib/data/models klasöründeki karşılığını da değiştirin.

export const SCHEMA_VERSION = 1;

/** Model özeti çıkarma yöntemi değişince artırılır; eski özetler yeniden üretilir. */
export const MODEL_SUMMARY_VERSION = 2;

/** Yapay zekâ yazarının talimatı değişince artırılır; eski metinler sırayla yeniden yazılır. */
export const WRITER_VERSION = 1;

/**
 * Haber ve proje yazılarının biçim sürümleri. 2: haberlerde "30 saniyede", "neden önemli", sade ve teknik
 * anlatım ile kavram sözlüğü (story); projelerde README'ye dayanan kısa tanıtım yazısı.
 */
export const NEWS_WRITER_VERSION = 2;
export const REPO_WRITER_VERSION = 2;

export type Category = 'ai' | 'security' | 'dev' | 'data' | 'hardware' | 'cloud' | 'mobile' | 'science' | 'industry';
export const CATEGORIES: readonly Category[] = ['ai', 'security', 'dev', 'data', 'hardware', 'cloud', 'mobile', 'science', 'industry'];

/** Türkçe metni kim üretti: 'ai' = yapay zekâ editörü, 'mt' = makine çevirisi, null = henüz yok. */
export type Writer = 'ai' | 'mt' | null;

/** "Önce bunu bil" kutusundaki terim açıklaması. */
export interface Primer {
  term: string;
  explanation: string;
}

export interface ArticleSection {
  heading: string;
  body: string;
}

/** Yapay zekâ editörünün kaynak haberden yazdığı özgün Türkçe anlatım. */
export interface Article {
  intro: string;
  primer: Primer[];
  sections: ArticleSection[];
}

/** Metindeki altı çizili kavrama dokununca açılan sade açıklama. Boş alanlar uygulamada gösterilmez. */
export interface GlossaryEntry {
  /** Kavramın metinde geçtiği biçim (ör. "Clojure"). */
  term: string;
  /** Nedir? */
  definition: string;
  /** Günlük hayattan benzetme. */
  analogy: string;
  /** Nerede, ne için kullanılır? */
  usage: string;
  /** Kim geliştirdi, nereden çıktı? */
  origin: string;
}

export interface StoryVersion {
  intro: string;
  sections: ArticleSection[];
}

/** Haberin iki seviyeli anlatımı (biçim sürümü 2). */
export interface Story {
  /** "30 saniyede": en önemli 3 bilgi. */
  tldr: string[];
  /** "Bu gelişme neden önemli?" */
  why: string;
  /** Sade anlatım: konuya yabancı okur için. */
  simple: StoryVersion;
  /** Teknik derinlik: konuyu bilen geliştirici için; kaynak yeterli ayrıntı vermiyorsa null. */
  technical: StoryVersion | null;
  glossary: GlossaryEntry[];
  /** Anlatım haberin tam metnine mi, yalnızca kısa açıklamasına mı dayanıyor? */
  basis: 'full' | 'excerpt';
}

/** GitHub projesinin README'ye dayanan kısa tanıtımı. */
export interface RepoStory {
  /** Ne işe yarıyor? */
  what: string;
  /** Neden ilgi görüyor? (yalnızca açılış tarihi, yıldız ve README'deki iddialara dayanır) */
  why: string;
  /** Neler yapılabilir? */
  useCases: string[];
  /** Kimin işine yarar? (boş olabilir) */
  audience: string;
  /** Güvenlik veya telif açısından dikkat notu (boş olabilir). */
  caution: string;
  basis: 'readme' | 'description';
}

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
  /** Akışta haberle birlikte verilen görsel (varsa). */
  imageUrl?: string | null;
  /** Akışın verdiği tam metin (varsa); yalnızca yapay zekâ yazarına girdi olur, yayımlanmaz. */
  content?: string;
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
  /** Haberin kapak görseli (yayıncının og:image'i veya akıştaki görsel). */
  imageUrl: string | null;
  /** Yapay zekâ editörünün yazdığı ayrıntılı anlatım; makine çevirisinde null. Eski uygulama sürümleri bunu okur. */
  article: Article | null;
  /** İki seviyeli anlatım (biçim sürümü 2); yeni uygulama bunu okur. */
  story: Story | null;
  /** 2-4 kısa Türkçe konu etiketi (Keşfet'teki trend konular bunlardan çıkar). */
  topics: string[];
  /** 1 (niş) - 5 (sektörü etkileyen) önem puanı; öne çıkan haberler bununla seçilir. */
  importance: number | null;
  readingMinutes: number | null;
  writer: Writer;
  writerVersion: number;
  /** Yapay zekâ editörü teknolojiyle ilgisiz bulduysa true; uygulamada gösterilmez, yeniden yazılmaz. */
  hidden: boolean;
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
  summaryVersion: number;
  translated: boolean;
  /** Model kartından çıkarılan kısa metin; yalnızca çeviri için tutulur */
  cardExcerpt: string;
  /** Modelin öne çıkan özellikleri (yapay zekâ editörü yazar, en fazla 3 madde). */
  highlights: string[];
  writer: Writer;
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
  imageUrl: string | null;
  article: Article | null;
  topics: string[];
  readingMinutes: number | null;
  writer: Writer;
  writerVersion: number;
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
  imageUrl: string | null;
  writer: Writer;
  writerVersion: number;
  /** README'ye dayanan kısa tanıtım yazısı; henüz yazılmadıysa null. */
  story: RepoStory | null;
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
  /** Açığın sade dille anlatımı: ne işe yarar, kimleri etkiler (yapay zekâ editörü yazar). */
  explanationTr: string | null;
  writer: Writer;
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
  /** Yapay zekâ editörünün bu çalışmadaki özeti. */
  editor: {
    model: string | null;
    written: number;
    failed: number;
    pending: number;
    inputTokens: number;
    outputTokens: number;
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
