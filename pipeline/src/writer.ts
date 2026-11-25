import { fetchArticle, type ArticlePage } from './article.ts';
import { CATEGORY_IDS, CATEGORY_INFO } from './categories.ts';
import { classify } from './classify.ts';
import { LlmFatalError, type LlmClient, type LlmUsage } from './llm.ts';
import { findSource } from './sources/feeds.ts';
import { polishTurkish } from './translate.ts';
import type { AiModel, Article, Category, NewsItem, Paper, Repo, State, Vulnerability } from './types.ts';
import { WRITER_VERSION } from './types.ts';
import { errorMessage, log, mapLimit, truncate } from './util.ts';

/**
 * Yapay zekâ editörü. Her kayıt için kaynağı okuyup TechPulse okuruna özgün, doğru ve akıcı bir
 * Türkçe metin yazar. Kaynak metin yalnızca girdi olarak kullanılır; yayımlanan metin modelin
 * kendi cümleleridir ve her zaman kaynağa bağlantı verilir.
 */

// ---------------------------------------------------------------------------------------------
// Talimatlar

const STYLE_RULES = `## Doğruluk kuralları (en önemli)
- Yalnızca kaynak metinde bulunan olguları yaz. Kaynakta olmayan sayı, tarih, isim, alıntı, fiyat, sürüm numarası veya olay uydurma.
- Kaynakta belirtilmeyen bir şeyi tahmin etme; bilmediğin ayrıntıya hiç değinme.
- Teknik terimleri ve genel arka planı açıklamak için genel bilgini kullanabilirsin (ör. "fidye yazılımı nedir"), ama bu habere ait yeni bir olgu eklemek için kullanamazsın.
- İddiaları kime ait olduğunu belirterek aktar ("Microsoft'a göre", "araştırmacıların açıklamasına göre").
- Kaynak metin kısaysa kısa yaz; uzatmak için tekrar etme, içi boş genel cümleler kurma.

## Dil ve üslup
- Doğal, akıcı ve doğru bir Türkçeyle yaz; TDK yazım kurallarına uy. Çeviri kokan cümle yapılarından, gereksiz edilgen yapılardan ve uzun tamlama zincirlerinden kaçın.
- Kaynağı cümle cümle çevirme. Olayı anla ve deneyimli bir Türk haber editörü gibi kendi cümlelerinle anlat. Doğrudan alıntı gerekiyorsa en fazla bir kısa alıntı kullan.
- Okur konuya yabancı olabilir: teknik kavramları ilk geçtikleri yerde kısaca açıkla, ama uzman okuru da sıkma.
- Özel adları çevirme: şirket, ürün, model, programlama dili, kütüphane, işletim sistemi ve CVE adları aynen kalır (ör. Rust, Go, llama.cpp, Windows 11, GPT-5, CVE-2026-1234).
- Yerleşmiş Türkçe karşılığı olan terimleri Türkçe kullan: vulnerability → güvenlik açığı, exploit → istismar etmek, data breach → veri ihlali, ransomware → fidye yazılımı, open source → açık kaynak, release → sürüm, inference → çıkarım, fine-tuning → ince ayar. Yerleşmemiş terimlerde İngilizcesini koru ve gerekirse kısaca açıkla.
- "Yapay zekâ" yaz. Yüzdeleri "%40", ondalıkları "1,5", büyük sayıları "2,3 milyar dolar" biçiminde, tarihleri "25 Kasım" biçiminde yaz.
- Markdown, madde işareti, emoji, yıldız veya diyez kullanma; düz metin yaz. Paragrafları boş satırla ayır.
- Abartıdan, tık tuzağından, ünlemden ve soru biçimindeki başlıklardan kaçın; ilgiyi olgularla uyandır.`;

const CATEGORY_LIST = CATEGORY_INFO.map((c) => `  - ${c.id}: ${c.label}. ${c.scope}`).join('\n');

export const NEWS_SYSTEM = `Sen TechPulse'un kıdemli teknoloji editörüsün. TechPulse; yazılımcılar, mühendisler ve teknolojiye meraklı herkes için Türkçe teknoloji haberleri yayımlayan bir mobil uygulamadır.

Görevin: Sana verilen kaynak haberi (çoğunlukla İngilizce) okuyup TechPulse okuru için özgün, doğru ve akıcı bir Türkçe haber yazmak. Okur haberi yalnızca senin metninden anlayabilmeli; ayrıntı isteyen okur kaynağa bağlantıdan ulaşır.

${STYLE_RULES}

## Alanlar
- relevant: Haber teknoloji, yazılım, bilim, internet, dijital ürünler veya teknoloji şirketleriyle ilgiliyse true. İndirim, kampanya ve alışveriş önerisi; dizi, film veya oyun eleştirisi; spor; teknolojiyle ilgisi olmayan siyaset ve magazin ise false. false ise diğer alanları birer kısa cümleyle doldur.
- title: En fazla 90 karakterlik Türkçe başlık. Haberin özünü ve okur için neden ilginç olduğunu söylesin; doğru ve dikkat çekici olsun ama yanıltıcı olmasın. Gerekmedikçe iki nokta üst üste kullanma.
  Zayıf: "Microsoft Kasım güncellemesi bazı kullanıcılarda oturum açma sorunlarına yol açtı"
  Daha iyi: "Microsoft'un Kasım güncellemesi bazı kullanıcıların oturum açmasını engelliyor"
- summary: Başlığın altındaki spot; 1-2 cümle, en fazla 220 karakter. Başlığı tekrar etmesin; ne olduğunu ve neden önemli olduğunu söylesin.
- intro: Giriş paragrafı; 2-4 cümle. Konuya yabancı birinin de ne olduğunu anlayacağı biçimde olayı özetler.
- primer: "Önce bunu bil" kutusu. Haberi anlamak için gereken en fazla 3 teknik terim; her açıklama 1-2 sade cümle. Gerek yoksa boş liste.
- sections: Haberin ayrıntılı anlatımı; 2-5 bölüm. Her bölümde kısa bir başlık (heading) ve 1-3 paragraf (body) olur. Haberin türüne uygun başlıklar seç; örnek: "Ne oldu?", "Bu neden önemli?", "Teknik olarak ne anlama geliyor?", "Kimler etkileniyor?", "Ne yapmalı?", "Bundan sonra ne olacak?". Her haberde aynı şablonu kullanma; kaynağın desteklemediği bölümü ekleme. Giriş ile bölümler aynı cümleleri tekrar etmesin. Toplam uzunluk kaynağın zenginliğine göre 150-450 kelime olsun.
- category: Haberin ana konusu; şu kimliklerden biri:
${CATEGORY_LIST}
- topics: 2-4 kısa konu etiketi (1-3 kelime, ilk harfi büyük; ör. "Büyük dil modelleri", "Fidye yazılımı", "Windows", "Kuantum bilgisayar").
- importance: 1-5 arası önem puanı. 5: sektörü etkileyen büyük gelişme (önemli bir model ya da ürün lansmanı, yaygın kullanılan bir yazılımda aktif istismar edilen kritik açık, büyük şirket hamlesi). 4: geniş kitleyi ilgilendiren önemli haber. 3: ilgi çekici standart haber. 2: dar bir kitleyi ilgilendiren duyuru. 1: çok niş içerik, tanıtım veya kişisel not.`;

export const PAPER_SYSTEM = `Sen TechPulse'un bilim editörüsün. Hugging Face'te günün öne çıkan yapay zekâ makalelerinden birini, yapay zekâ ile ilgilenen ama akademisyen olmayan bir okurun anlayacağı sade bir Türkçeyle tanıtacaksın.

${STYLE_RULES}

## Alanlar
- title: Makalenin ne yaptığını anlatan, en fazla 100 karakterlik Türkçe başlık. Model ve yöntem adlarını koru.
- summary: 1-2 cümlelik spot; en fazla 220 karakter.
- intro: 2-3 cümle; makalenin çözmeye çalıştığı sorunu ve ana fikrini anlatır.
- primer: Makaleyi anlamak için gereken en fazla 3 terim; her açıklama 1-2 sade cümle. Gerek yoksa boş liste.
- sections: 2-4 bölüm; örnek başlıklar: "Makale ne yapıyor?", "Nasıl çalışıyor?", "Sonuçlar", "Neden önemli?". Yalnızca özette yazanlara dayan; toplam 120-300 kelime.
- topics: 2-4 kısa konu etiketi (ör. "Dil modelleri", "Görüntü üretimi", "Pekiştirmeli öğrenme").`;

export const MODEL_SYSTEM = `Sen TechPulse'un yapay zekâ editörüsün. Hugging Face'te trend olan bir modeli, model kartındaki bilgilere dayanarak Türk geliştiricilere tanıtacaksın.

${STYLE_RULES}

## Alanlar
- summary: 2-3 cümle; modelin ne yaptığını, ne tür girdi ve çıktılarla çalıştığını ve kimin işine yarayacağını anlatır. Yalnızca verilen bilgilere dayan.
- highlights: En fazla 3 kısa madde (her biri en fazla 60 karakter); modelin öne çıkan, kartta yazan özellikleri (ör. "Görsel ve metin girdisi alıyor", "Apache 2.0 lisanslı"). Bilgi yoksa boş liste.`;

export const REPO_SYSTEM = `Sen TechPulse'un açık kaynak editörüsün. GitHub'da hızla yıldız toplayan yeni bir projeyi tek bakışta anlaşılacak biçimde tanıtacaksın.

${STYLE_RULES}

## Alanlar
- description: 1-2 cümle, en fazla 200 karakter: proje ne yapıyor ve kimin işine yarar. Yalnızca verilen bilgilere dayan.`;

export const KEV_SYSTEM = `Sen TechPulse'un siber güvenlik editörüsün. ABD Siber Güvenlik ve Altyapı Güvenliği Ajansı'nın (CISA) "aktif olarak istismar edilen açıklar" kataloğuna yeni eklenen bir kaydı Türk okura anlatacaksın.

${STYLE_RULES}

## Alanlar
- name: Açığın Türkçe adı; "<Ürün> <açık türü> açığı" biçiminde, ürün adları aynen (ör. "Drupal Core uzaktan kod çalıştırma açığı").
- description: CISA açıklamasının anlaşılır Türkçe anlatımı; 1-3 cümle.
- action: Yapılması gereken; 1-2 cümle, emir kipiyle (ör. "Üreticinin yayımladığı güncellemeyi uygulayın.").
- explanation: Sade dille 2-3 cümle: bu açık saldırgana ne yaptırır, kimleri etkiler ve neden hemen ilgilenmek gerekir.`;

// ---------------------------------------------------------------------------------------------
// Yanıt şemaları (JSON Schema). Sayı ve uzunluk sınırları talimatta verilir, yanıt geldikten sonra denetlenir.

const stringArray = { type: 'array', items: { type: 'string' } };
const primerSchema = {
  type: 'array',
  items: {
    type: 'object',
    additionalProperties: false,
    properties: { term: { type: 'string' }, explanation: { type: 'string' } },
    required: ['term', 'explanation'],
  },
};
const sectionsSchema = {
  type: 'array',
  items: {
    type: 'object',
    additionalProperties: false,
    properties: { heading: { type: 'string' }, body: { type: 'string' } },
    required: ['heading', 'body'],
  },
};

export const NEWS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    relevant: { type: 'boolean' },
    title: { type: 'string' },
    summary: { type: 'string' },
    intro: { type: 'string' },
    primer: primerSchema,
    sections: sectionsSchema,
    category: { type: 'string', enum: [...CATEGORY_IDS] },
    topics: stringArray,
    importance: { type: 'integer' },
  },
  required: ['relevant', 'title', 'summary', 'intro', 'primer', 'sections', 'category', 'topics', 'importance'],
};

export const PAPER_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    title: { type: 'string' },
    summary: { type: 'string' },
    intro: { type: 'string' },
    primer: primerSchema,
    sections: sectionsSchema,
    topics: stringArray,
  },
  required: ['title', 'summary', 'intro', 'primer', 'sections', 'topics'],
};

export const MODEL_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: { summary: { type: 'string' }, highlights: stringArray },
  required: ['summary', 'highlights'],
};

export const REPO_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: { description: { type: 'string' } },
  required: ['description'],
};

export const KEV_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    name: { type: 'string' },
    description: { type: 'string' },
    action: { type: 'string' },
    explanation: { type: 'string' },
  },
  required: ['name', 'description', 'action', 'explanation'],
};

// ---------------------------------------------------------------------------------------------
// Yanıtların denetimi ve temizliği

interface PrimerOut {
  term: string;
  explanation: string;
}
interface SectionOut {
  heading: string;
  body: string;
}
export interface NewsOut {
  relevant: boolean;
  title: string;
  summary: string;
  intro: string;
  primer: PrimerOut[];
  sections: SectionOut[];
  category: string;
  topics: string[];
  importance: number;
}
export interface PaperOut {
  title: string;
  summary: string;
  intro: string;
  primer: PrimerOut[];
  sections: SectionOut[];
  topics: string[];
}
export interface ModelOut {
  summary: string;
  highlights: string[];
}
export interface RepoOut {
  description: string;
}
export interface KevOut {
  name: string;
  description: string;
  action: string;
  explanation: string;
}

/** Tek satırlık metin: markdown işaretlerini ve fazla boşlukları temizler. */
export function plain(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  let text = value.replace(/\*\*|__|`/g, '').replace(/^\s*(#+|[-*•])\s+/gm, '');
  text = text.replace(/\s+/g, ' ').trim().replace(/^["“”']+|["“”']+$/g, '').trim();
  return polishTurkish(truncate(text, max));
}

/** Paragraflı metin: paragraf aralarını korur. */
export function paragraphs(value: unknown, max: number): string {
  if (typeof value !== 'string') return '';
  const parts = value
    .replace(/\r/g, '')
    .split(/\n\s*\n|\n/)
    .map((p) => plain(p, max))
    .filter((p) => p.length > 0);
  return truncate(parts.join('\n\n'), max);
}

function cleanPrimer(list: unknown): Article['primer'] {
  if (!Array.isArray(list)) return [];
  return list
    .map((p) => ({ term: plain((p as PrimerOut)?.term, 60), explanation: plain((p as PrimerOut)?.explanation, 320) }))
    .filter((p) => p.term && p.explanation)
    .slice(0, 3);
}

function cleanSections(list: unknown): Article['sections'] {
  if (!Array.isArray(list)) return [];
  return list
    .map((s) => ({ heading: plain((s as SectionOut)?.heading, 60).replace(/[.:]$/, ''), body: paragraphs((s as SectionOut)?.body, 2400) }))
    .filter((s) => s.heading && s.body)
    .slice(0, 6);
}

function cleanTopics(list: unknown): string[] {
  if (!Array.isArray(list)) return [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const raw of list) {
    const topic = plain(raw, 40).replace(/[.,;]+$/, '');
    const key = topic.toLocaleLowerCase('tr');
    if (!topic || seen.has(key)) continue;
    seen.add(key);
    out.push(topic.charAt(0).toLocaleUpperCase('tr') + topic.slice(1));
    if (out.length === 4) break;
  }
  return out;
}

export function readingMinutes(article: Article): number {
  const words = [article.intro, ...article.primer.map((p) => p.explanation), ...article.sections.map((s) => `${s.heading} ${s.body}`)]
    .join(' ')
    .split(/\s+/)
    .filter(Boolean).length;
  return Math.max(1, Math.round(words / 180));
}

/** Haber yanıtını kayda uygular; yanıt eksikse false döner ve kayıt sonraki çalışmaya kalır. */
export function applyNews(item: NewsItem, out: NewsOut): boolean {
  if (out.relevant === false) {
    item.hidden = true;
    item.writer = 'ai';
    item.writerVersion = WRITER_VERSION;
    return true;
  }
  const title = plain(out.title, 120);
  const summary = plain(out.summary, 300);
  const intro = paragraphs(out.intro, 1200);
  const sections = cleanSections(out.sections);
  if (!title || !summary || !intro || sections.length === 0) return false;
  const article: Article = { intro, primer: cleanPrimer(out.primer), sections };
  item.titleTr = title;
  item.summaryTr = summary;
  item.article = article;
  item.topics = cleanTopics(out.topics);
  item.importance = Math.min(5, Math.max(1, Math.round(Number(out.importance) || 3)));
  item.readingMinutes = readingMinutes(article);
  const category = (CATEGORY_IDS as readonly string[]).includes(out.category) ? (out.category as Category) : null;
  item.category = category ?? classify(item.titleOriginal, item.excerptOriginal, findSource(item.sourceId)?.defaultCategory ?? 'industry');
  item.translated = true;
  item.hidden = false;
  item.writer = 'ai';
  item.writerVersion = WRITER_VERSION;
  return true;
}

export function applyPaper(paper: Paper, out: PaperOut): boolean {
  const title = plain(out.title, 140);
  const summary = plain(out.summary, 300);
  const intro = paragraphs(out.intro, 1000);
  const sections = cleanSections(out.sections);
  if (!title || !summary || !intro || sections.length === 0) return false;
  const article: Article = { intro, primer: cleanPrimer(out.primer), sections };
  paper.titleTr = title;
  paper.summaryTr = summary;
  paper.article = article;
  paper.topics = cleanTopics(out.topics);
  paper.readingMinutes = readingMinutes(article);
  paper.translated = true;
  paper.writer = 'ai';
  paper.writerVersion = WRITER_VERSION;
  return true;
}

export function applyModel(model: AiModel, out: ModelOut): boolean {
  const summary = plain(out.summary, 500);
  if (!summary) return false;
  model.summaryTr = summary;
  model.highlights = (Array.isArray(out.highlights) ? out.highlights : [])
    .map((h) => plain(h, 70).replace(/\.$/, ''))
    .filter(Boolean)
    .slice(0, 3);
  model.translated = true;
  model.writer = 'ai';
  return true;
}

export function applyRepo(repo: Repo, out: RepoOut): boolean {
  const description = plain(out.description, 260);
  if (!description) return false;
  repo.descriptionTr = description;
  repo.translated = true;
  repo.writer = 'ai';
  return true;
}

export function applyKev(vuln: Vulnerability, out: KevOut): boolean {
  const name = plain(out.name, 160);
  const description = plain(out.description, 600);
  if (!name || !description) return false;
  vuln.nameTr = name.charAt(0).toLocaleUpperCase('tr') + name.slice(1);
  vuln.descriptionTr = description;
  vuln.actionTr = plain(out.action, 400) || null;
  vuln.explanationTr = plain(out.explanation, 600) || null;
  vuln.translated = true;
  vuln.writer = 'ai';
  return true;
}

// ---------------------------------------------------------------------------------------------
// Kullanıcı mesajları (tek bir kaydın girdisi)

function kindLabel(kind: string): string {
  return kind === 'official' ? 'resmî blog' : kind === 'community' ? 'geliştirici topluluğu' : 'haber sitesi';
}

export function newsPrompt(item: NewsItem, page: ArticlePage | null, feedContent: string | undefined): string {
  const pageText = page?.text ?? '';
  const feedText = feedContent ?? '';
  const text = pageText.length >= feedText.length ? pageText : feedText;
  const lines = [
    `Kaynak: ${item.sourceName} (${kindLabel(item.sourceKind)})`,
    `Yayın tarihi: ${item.publishedAt.slice(0, 10)}`,
    `Orijinal başlık: ${item.titleOriginal}`,
  ];
  const excerpt = item.excerptOriginal || page?.description || '';
  if (excerpt) lines.push(`Kaynağın kısa açıklaması: ${excerpt}`);
  if (item.points !== null) lines.push(`Hacker News: ${item.points} puan, ${item.comments ?? 0} yorum (bağlantı topluluk tarafından paylaşıldı).`);
  if (text.length >= 300) {
    lines.push('', 'Haber metni:', '"""', text, '"""');
  } else {
    lines.push('', 'Haber metnine ulaşılamadı. Yalnızca başlık ve kısa açıklamaya dayan; kısa yaz ve 2 bölümle yetin.');
  }
  return lines.join('\n');
}

export function paperPrompt(paper: Paper): string {
  return [
    `Makale başlığı: ${paper.titleOriginal}`,
    `Yazarlar: ${paper.authors.join(', ') || 'belirtilmemiş'}`,
    `Hugging Face oyları: ${paper.upvotes}`,
    paper.githubUrl ? `Kod deposu: ${paper.githubUrl}` : '',
    '',
    'Özet (abstract):',
    '"""',
    paper.abstractOriginal,
    '"""',
  ]
    .filter((l) => l !== '')
    .join('\n');
}

export function modelPrompt(model: AiModel): string {
  return [
    `Model: ${model.id}`,
    `Görev: ${model.task}${model.pipelineTag ? ` (${model.pipelineTag})` : ''}`,
    model.parameters ? `Parametre sayısı: ${model.parameters}` : '',
    model.license ? `Lisans: ${model.license}` : '',
    model.library ? `Kütüphane: ${model.library}` : '',
    `İndirme: ${model.downloads}, beğeni: ${model.likes}`,
    '',
    'Model kartından:',
    '"""',
    model.cardExcerpt || '(model kartında açıklama yok)',
    '"""',
  ]
    .filter((l) => l !== '')
    .join('\n');
}

export function repoPrompt(repo: Repo): string {
  return [
    `Proje: ${repo.id}`,
    repo.language ? `Dil: ${repo.language}` : '',
    repo.topics.length ? `Konular: ${repo.topics.join(', ')}` : '',
    `Yıldız: ${repo.stars}`,
    `Açıklama: ${repo.descriptionOriginal}`,
  ]
    .filter(Boolean)
    .join('\n');
}

export function kevPrompt(vuln: Vulnerability): string {
  return [
    `CVE: ${vuln.cveId}`,
    `Üretici: ${vuln.vendor}`,
    `Ürün: ${vuln.product}`,
    `Açığın adı: ${vuln.nameOriginal}`,
    `Açıklama: ${vuln.descriptionOriginal}`,
    `Gerekli işlem: ${vuln.actionOriginal}`,
    `Kataloğa eklenme: ${vuln.dateAdded}${vuln.dueDate ? `, kamu kurumları için son tarih: ${vuln.dueDate}` : ''}`,
    `Fidye yazılımı saldırılarında kullanıldığı biliniyor mu: ${vuln.ransomware ? 'evet' : 'bilinmiyor'}`,
    vuln.cwes.length ? `CWE: ${vuln.cwes.join(', ')}` : '',
  ]
    .filter(Boolean)
    .join('\n');
}

// ---------------------------------------------------------------------------------------------
// Çalıştırma

export interface EditorOptions {
  /** Bir çalışmada yazılacak en fazla kayıt (haber + makale + model + proje + açık). */
  maxItems?: number;
  concurrency?: number;
  /** Bu süreden sonra yeni iş başlatılmaz (ms). */
  deadlineMs?: number;
  /** Bu çalışmada akışlardan okunan tam metinler (haber kimliği → metin). */
  feedContent?: Map<string, string>;
  fetchPage?: (url: string) => Promise<ArticlePage>;
}

export interface EditorSummary {
  model: string | null;
  written: number;
  failed: number;
  pending: number;
  inputTokens: number;
  outputTokens: number;
  note: string | null;
}

interface Job {
  label: string;
  run: () => Promise<boolean>;
}

export function needsNews(item: NewsItem): boolean {
  return item.writer !== 'ai' || item.writerVersion < WRITER_VERSION;
}
export function needsPaper(paper: Paper): boolean {
  return paper.writer !== 'ai' || paper.writerVersion < WRITER_VERSION;
}
export function needsModel(model: AiModel): boolean {
  return model.writer !== 'ai' && model.cardExcerpt.length > 0;
}
export function needsRepo(repo: Repo): boolean {
  return repo.writer !== 'ai' && repo.descriptionOriginal.length > 0;
}
export function needsKev(vuln: Vulnerability): boolean {
  return vuln.writer !== 'ai';
}

/** Bekleyen kayıtları önem sırasına göre yazar: haberler (en yeniden), makaleler, açıklar, modeller, projeler. */
export async function runEditor(state: State, llm: LlmClient, options: EditorOptions = {}): Promise<EditorSummary> {
  const maxItems = options.maxItems ?? 150;
  const deadline = Date.now() + (options.deadlineMs ?? 25 * 60_000);
  const fetchPage = options.fetchPage ?? ((url: string) => fetchArticle(url));
  const usage: LlmUsage = { inputTokens: 0, outputTokens: 0 };
  let fatal: string | null = null;
  let failed = 0;

  async function ask<T>(system: string, user: string, schema: Record<string, unknown>, maxTokens: number): Promise<T | null> {
    if (fatal || Date.now() > deadline) return null;
    try {
      const res = await llm.complete<T>({ system, user, schema, maxTokens });
      usage.inputTokens += res.usage.inputTokens;
      usage.outputTokens += res.usage.outputTokens;
      return res.data;
    } catch (error) {
      if (error instanceof LlmFatalError) fatal = error.message;
      else log.warn(`Yapay zekâ editörü: ${errorMessage(error)}`);
      return null;
    }
  }

  const jobs: Job[] = [];
  const news = state.news.filter(needsNews).sort((a, b) => Date.parse(b.publishedAt) - Date.parse(a.publishedAt));
  for (const item of news) {
    jobs.push({
      label: `haber ${item.id}`,
      run: async () => {
        let page: ArticlePage | null = null;
        try {
          page = await fetchPage(item.url);
        } catch (error) {
          log.info(`Haber sayfası okunamadı (${item.sourceName}): ${errorMessage(error)}`);
        }
        if (page?.imageUrl && !item.imageUrl) item.imageUrl = page.imageUrl;
        const out = await ask<NewsOut>(NEWS_SYSTEM, newsPrompt(item, page, options.feedContent?.get(item.id)), NEWS_SCHEMA, 3500);
        return out ? applyNews(item, out) : false;
      },
    });
  }
  const papers = state.papers.filter(needsPaper).sort((a, b) => b.publishedAt.localeCompare(a.publishedAt) || b.upvotes - a.upvotes);
  for (const paper of papers) {
    jobs.push({
      label: `makale ${paper.id}`,
      run: async () => {
        const out = await ask<PaperOut>(PAPER_SYSTEM, paperPrompt(paper), PAPER_SCHEMA, 2500);
        return out ? applyPaper(paper, out) : false;
      },
    });
  }
  for (const vuln of state.security.filter(needsKev)) {
    jobs.push({
      label: `açık ${vuln.cveId}`,
      run: async () => {
        const out = await ask<KevOut>(KEV_SYSTEM, kevPrompt(vuln), KEV_SCHEMA, 1200);
        return out ? applyKev(vuln, out) : false;
      },
    });
  }
  for (const model of state.models.filter(needsModel)) {
    jobs.push({
      label: `model ${model.id}`,
      run: async () => {
        const out = await ask<ModelOut>(MODEL_SYSTEM, modelPrompt(model), MODEL_SCHEMA, 800);
        return out ? applyModel(model, out) : false;
      },
    });
  }
  for (const repo of state.repos.filter(needsRepo)) {
    jobs.push({
      label: `proje ${repo.id}`,
      run: async () => {
        const out = await ask<RepoOut>(REPO_SYSTEM, repoPrompt(repo), REPO_SCHEMA, 500);
        return out ? applyRepo(repo, out) : false;
      },
    });
  }

  const selected = jobs.slice(0, maxItems);
  let written = 0;
  await mapLimit(selected, options.concurrency ?? 4, async (job) => {
    if (fatal || Date.now() > deadline) return;
    const ok = await job.run().catch((error) => {
      log.warn(`${job.label}: ${errorMessage(error)}`);
      return false;
    });
    if (ok) written++;
    else failed++;
  });

  const pending = jobs.length - written;
  const note = fatal ?? (pending > 0 ? `${pending} kayıt sonraki çalışmalarda yazılacak` : null);
  if (fatal) log.error(`Yapay zekâ editörü durdu: ${fatal}`);
  log.info(
    `Yapay zekâ editörü (${llm.model}): ${written} kayıt yazıldı, ${failed} başarısız, ${pending} bekliyor; ` +
      `${usage.inputTokens} girdi, ${usage.outputTokens} çıktı belirteci.`,
  );
  return { model: llm.model, written, failed, pending, inputTokens: usage.inputTokens, outputTokens: usage.outputTokens, note };
}
