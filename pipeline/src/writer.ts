import { fetchArticle, type ArticlePage } from './article.ts';
import { CATEGORY_IDS, CATEGORY_INFO } from './categories.ts';
import { classify } from './classify.ts';
import { LlmFatalError, type LlmClient, type LlmUsage } from './llm.ts';
import { findSource } from './sources/feeds.ts';
import { polishTurkish } from './translate.ts';
import type { AiModel, Article, Category, GlossaryEntry, NewsItem, Paper, Repo, RepoStory, State, Story, StoryVersion, Vulnerability } from './types.ts';
import { NEWS_WRITER_VERSION, REPO_WRITER_VERSION, WRITER_VERSION } from './types.ts';
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
- İddiaları kime ait olduğunu belirterek aktar ("Microsoft'a göre", "araştırmacıların açıklamasına göre"). "Kaynağa göre" ya da "kaynak metne göre" gibi ifadeleri kullanma; bilgiyi sahibine (şirket, kurum, yayın, kişi) dayandır.
- Kaynak metin kısaysa kısa yaz; uzatmak için tekrar etme, içi boş genel cümleler kurma.

## Dil ve üslup
- Doğal, akıcı ve doğru bir Türkçeyle yaz; TDK yazım kurallarına uy. Çeviri kokan cümle yapılarından, gereksiz edilgen yapılardan ve uzun tamlama zincirlerinden kaçın.
- Kaynağı cümle cümle çevirme ve kaynağın paragraf sırasını kopyalama. Olayı anla ve deneyimli bir Türk haber editörü gibi kendi kurgunla, kendi cümlelerinle anlat. Doğrudan alıntı gerekiyorsa en fazla bir kısa alıntı kullan.
- Okur konuya yabancı olabilir: teknik kavramları ilk geçtikleri yerde kısaca açıkla, ama uzman okuru da sıkma.
- Özel adları çevirme: şirket, ürün, model, programlama dili, kütüphane, işletim sistemi ve CVE adları aynen kalır (ör. Rust, Go, llama.cpp, Windows 11, GPT-5, CVE-2026-1234).
- Yerleşmiş Türkçe karşılığı olan terimleri Türkçe kullan: vulnerability → güvenlik açığı, exploit → istismar etmek, data breach → veri ihlali, ransomware → fidye yazılımı, open source → açık kaynak, release → sürüm, inference → çıkarım, fine-tuning → ince ayar, wire fraud → elektronik dolandırıcılık, indictment → iddianame. Yerleşmemiş terimlerde İngilizcesini koru ve gerekirse kısaca açıkla; kelimesi kelimesine çeviri uydurma.
- "Yapay zekâ" yaz. Yüzdeleri "%40", ondalıkları "1,5", büyük sayıları "2,3 milyar dolar" biçiminde, tarihleri "25 Kasım" biçiminde yaz.
- Markdown, madde işareti, emoji, yıldız veya diyez kullanma; düz metin yaz. Paragrafları boş satırla ayır.
- Abartıdan, tık tuzağından, ünlemden ve soru biçimindeki başlıklardan kaçın; ilgiyi olgularla uyandır.`;

const CATEGORY_LIST = CATEGORY_INFO.map((c) => `  - ${c.id}: ${c.label}. ${c.scope}`).join('\n');

export const NEWS_SYSTEM = `Sen TechPulse'un kıdemli teknoloji editörüsün. TechPulse; yoğun çalışan yazılımcıların, mühendislerin ve teknolojiye meraklı herkesin dünya teknoloji gündemini Türkçe takip ettiği bir mobil uygulamadır. Okur haberi yalnızca senin metninden, bir haber sitesinde okuyormuş gibi ayrıntısıyla öğrenebilmeli; kaynağa yalnızca daha da derine inmek isterse gider.

Görevin: Kaynak haberi (çoğunlukla İngilizce) okuyup aynı olayı iki seviyede anlatan özgün bir Türkçe haber dosyası hazırlamak: konuya yabancı okur için "sade anlatım", konuyu bilen geliştirici için "teknik derinlik".

${STYLE_RULES}

## Tekrar yasağı
tldr, why, simple ve technical aynı cümleleri tekrar etmez. Giriş (intro) bölümlerin ilk cümlesini tekrar etmez. Bölümler tldr'deki bilgiyi aynı sözlerle yeniden söylemez; her bölüm okura yeni bir şey öğretir.

## Bölüm başlıkları
İçeriğe özgü, okura o bölümde ne öğreneceğini söyleyen kısa başlıklar yaz (en fazla 60 karakter). "Ne oldu?", "Neden önemli?", "Bu neden önemli?", "Arka plan", "Detaylar", "Sonuç", "Kimler etkileniyor?", "Teknik ayrıntılar", "Bundan sonra ne olacak?" gibi her habere uyan kalıp başlıkları KULLANMA.
  Kalıp (yasak): "Ne oldu?"   Özgün: "Saldırganlar kaynak koduna nasıl ulaştı?"
  Kalıp (yasak): "Teknik ayrıntılar"   Özgün: "Parola özetleri neden hâlâ risk altında?"

## Alanlar
- relevant: Haber teknoloji, yazılım, bilim, internet, dijital ürünler veya teknoloji şirketleriyle ilgiliyse true. İndirim, kampanya ve alışveriş önerisi; dizi, film veya oyun eleştirisi; spor; teknolojiyle ilgisi olmayan siyaset ve magazin ise false. false ise diğer metin alanlarını birer kısa cümleyle doldur, listeleri boş bırak.
- title: En fazla 90 karakterlik Türkçe başlık. Haberin özünü ve okur için neden ilginç olduğunu söylesin; doğru ve dikkat çekici olsun ama yanıltıcı olmasın. Soru biçiminde olmasın. Gerekmedikçe iki nokta üst üste kullanma.
- summary: Kartlarda görünen spot; tek cümle, en fazla 200 karakter. Başlığı tekrar etmesin.
- tldr: "30 saniyede" kutusu. Tam 3 madde; her biri en fazla 170 karakterlik tek cümle. Okur yalnızca bunları okusa bile olayın ne olduğunu, kimi etkilediğini ve sonucunu öğrenmeli. Somut ol: kim, ne, ne zaman, ne kadar.
- why: "Bu gelişme neden önemli?" kutusu. 2-3 cümle: olayın sektöre, kullanıcılara ya da geliştiricilere etkisi. Kaynakta dayanağı olmayan öngörüde bulunma.
- simple: Sade anlatım. Konuyu hiç bilmeyen ama meraklı bir okur için. Okur kaynağa gitmeden olayı bütün önemli ayrıntılarıyla öğrenebilmeli: kaynaktaki önemli olguları (rakamlar, tarihler, kimin ne yaptığı ve ne söylediği, tepkiler, sonraki adımlar) eksiksiz aktar.
  - intro: 2-4 cümlelik giriş.
  - sections: 3-5 bölüm; her bölüm bir başlık (heading) ve 2-3 paragraftan (body) oluşur, her paragraf 3-5 cümledir. Uzunluk kaynağa göre: haber metni 3.000 karakterden uzunsa toplam 450-750 kelime, 1.500-3.000 karakter arasındaysa 300-450 kelime, daha kısaysa 150-300 kelime. Teknik ayrıntıyı günlük dile çevir, kısaltmaları ilk geçtiği yerde aç. Olayın arka planını, nasıl geliştiğini ve okur için sonucunu anlat.
- technical: Teknik derinlik. Konuyu bilen bir yazılımcı için aynı olay; sade anlatımı tekrar etme, onu tamamla.
  - intro: 2-3 cümle.
  - sections: 2-4 bölüm; her bölüm 1-3 paragraf. Toplam 300-600 kelime. Kaynaktaki somut teknik ayrıntıları ver: sürüm numaraları, mimari, kullanılan teknolojiler, API, komut ve yapılandırma adları, ölçüm ve kıyaslama sonuçları, CVE kimlikleri ve CVSS puanları, saldırı zinciri, etkilenen sürümler, yamalar ve geçici çözümler. Kaynak böyle ayrıntılar içermiyorsa uydurma: intro'yu boş bırak ve sections'ı boş liste döndür.
- glossary: Metinde geçen ve teknolojiye uzak bir okurun bilmeyeceği 2-6 kavram. Öncelik: (1) ürün, teknoloji, programlama dili, kütüphane, protokol veya kurum adları (ör. Clojure, Kubernetes, CISA, Hugging Face); (2) teknik terim ve kısaltmalar (ör. sıfır gün açığı, RCE, ince ayar, token); (3) İngilizce kalan terimler. "Yazılım", "internet", "uygulama", "şirket", "veri", "yapay zekâ" gibi herkesin bildiği kelimeleri SEÇME. Her kavram için:
  - term: Kavramın simple veya technical metninde AYNEN geçtiği biçim, ek almadan (metinde "Clojure'un" geçiyorsa "Clojure").
  - definition: Nedir? 1-2 sade cümle.
  - analogy: Günlük hayattan bir benzetme, 1 cümle. Benzetme zorlama olacaksa boş metin.
  - usage: Nerede, ne için kullanılır? 1 cümle; gereksizse boş metin.
  - origin: Kim geliştirdi, ne zaman ortaya çıktı? Yalnızca yaygın bilinen ve emin olduğun bir bilgiyse 1 cümle; değilse boş metin.
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

export const REPO_SYSTEM = `Sen TechPulse'un açık kaynak editörüsün. GitHub'da son 7 gün içinde açılmış ve hızla yıldız toplayan bir projeyi, okur GitHub'a gitmeden ne olduğunu anlayacak kısa bir yazıyla tanıtacaksın. Bilgi kaynağın projenin README dosyası ve verilen sayılardır.

${STYLE_RULES}

## Alanlar
- summary: Kartta görünen 1-2 cümle, en fazla 220 karakter: proje ne yapıyor.
- what: "Ne işe yarıyor?" 2-4 cümle: projenin ne olduğu, nasıl çalıştığı ve hangi teknolojilerle yazıldığı.
- why: "Neden ilgi görüyor?" 2-3 cümle. Projenin hangi ihtiyaca, eksikliğe veya merağa cevap verdiğini README'ye ve verilen sayılara dayanarak açıkla; kaç günde kaç yıldız topladığını an (ör. "GTA VI'nın bilgisayar sürümü henüz yok; proje bu boşluğu doldurmayı vaat ettiği için birkaç günde 12 binden fazla yıldız topladı."). Kaynakta olmayan olay, kişi, rakam veya alıntı uydurma; README'deki iddiaları "... vaat ediyor", "... olduğunu söylüyor" diye aktar. Okura bilgi vermeyen "ilginin nedeni bilinemez", "kaynakta açıkça yazmıyor" gibi cümleler kurma.
- useCases: 2-4 madde; bu projeyle neler yapılabilir. Her biri en fazla 120 karakterlik tek cümle; README'de yazanlara dayan.
- audience: Kimin işine yarar? 1 cümle; belirsizse boş metin.
- caution: Gerekiyorsa 1-2 cümlelik dikkat notu. Proje resmî olmayan bir üçüncü taraf çalışmasıysa, telifli bir ürünü kopyaladığını ya da çalıştırdığını iddia ediyorsa, kullanıcıdan bilinmeyen bir çalıştırılabilir dosya indirmesini, parola veya anahtar girmesini ya da güvenlik yazılımını kapatmasını istiyorsa veya gerçek olamayacak kadar iyi görünen iddialar taşıyorsa okuru açıkça uyar. Böyle bir durum yoksa boş metin.`;

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

const storyVersionSchema = {
  type: 'object',
  additionalProperties: false,
  properties: { intro: { type: 'string' }, sections: sectionsSchema },
  required: ['intro', 'sections'],
};
const glossarySchema = {
  type: 'array',
  items: {
    type: 'object',
    additionalProperties: false,
    properties: {
      term: { type: 'string' },
      definition: { type: 'string' },
      analogy: { type: 'string' },
      usage: { type: 'string' },
      origin: { type: 'string' },
    },
    required: ['term', 'definition', 'analogy', 'usage', 'origin'],
  },
};

export const NEWS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    relevant: { type: 'boolean' },
    title: { type: 'string' },
    summary: { type: 'string' },
    tldr: stringArray,
    why: { type: 'string' },
    simple: storyVersionSchema,
    technical: storyVersionSchema,
    glossary: glossarySchema,
    category: { type: 'string', enum: [...CATEGORY_IDS] },
    topics: stringArray,
    importance: { type: 'integer' },
  },
  required: ['relevant', 'title', 'summary', 'tldr', 'why', 'simple', 'technical', 'glossary', 'category', 'topics', 'importance'],
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
  properties: {
    summary: { type: 'string' },
    what: { type: 'string' },
    why: { type: 'string' },
    useCases: stringArray,
    audience: { type: 'string' },
    caution: { type: 'string' },
  },
  required: ['summary', 'what', 'why', 'useCases', 'audience', 'caution'],
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
interface StoryVersionOut {
  intro: string;
  sections: SectionOut[];
}
export interface NewsOut {
  relevant: boolean;
  title: string;
  summary: string;
  tldr: string[];
  why: string;
  simple: StoryVersionOut;
  technical: StoryVersionOut;
  glossary: GlossaryEntry[];
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
  summary: string;
  what: string;
  why: string;
  useCases: string[];
  audience: string;
  caution: string;
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
    .map((s) => ({ heading: plain((s as SectionOut)?.heading, 80).replace(/[.:]$/, ''), body: paragraphs((s as SectionOut)?.body, 3200) }))
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

const GENERIC_HEADINGS = new Set(
  ['ne oldu', 'neden önemli', 'bu neden önemli', 'arka plan', 'detaylar', 'ayrıntılar', 'sonuç', 'teknik ayrıntılar', 'kimler etkileniyor']
);

function cleanVersion(value: unknown, introMax: number): StoryVersion {
  const v = (value ?? {}) as Partial<StoryVersionOut>;
  return { intro: paragraphs(v.intro, introMax), sections: cleanSections(v.sections) };
}

/** Türkçe harf duyarsız "metinde geçiyor mu?" denetimi. */
function mentions(haystack: string, term: string): boolean {
  const lower = (t: string) => t.toLocaleLowerCase('tr');
  return lower(haystack).includes(lower(term));
}

function cleanGlossary(list: unknown, text: string): GlossaryEntry[] {
  if (!Array.isArray(list)) return [];
  const seen = new Set<string>();
  const out: GlossaryEntry[] = [];
  for (const raw of list) {
    const g = (raw ?? {}) as Partial<GlossaryEntry>;
    const term = plain(g.term, 60).replace(/[.,;:]+$/, '');
    const definition = plain(g.definition, 360);
    const key = term.toLocaleLowerCase('tr');
    // Metinde geçmeyen kavram altı çizilemez; çoğunlukla gereksiz bir seçimdir.
    if (!term || !definition || seen.has(key) || !mentions(text, term)) continue;
    seen.add(key);
    out.push({ term, definition, analogy: plain(g.analogy, 280), usage: plain(g.usage, 280), origin: plain(g.origin, 280) });
    if (out.length === 6) break;
  }
  return out;
}

function storyText(story: Pick<Story, 'tldr' | 'why' | 'simple' | 'technical'>): string {
  const version = (v: StoryVersion | null) => (v ? [v.intro, ...v.sections.map((s) => `${s.heading} ${s.body}`)] : []);
  return [...story.tldr, story.why, ...version(story.simple), ...version(story.technical)].join(' ');
}

function words(texts: string[]): number {
  return texts.join(' ').split(/\s+/).filter(Boolean).length;
}

/** Haberin sade anlatımının okuma süresi (dakika). */
export function storyMinutes(story: Story): number {
  return Math.max(1, Math.round(words([...story.tldr, story.why, story.simple.intro, ...story.simple.sections.map((s) => `${s.heading} ${s.body}`)]) / 180));
}

/** Kalıp bölüm başlıkları (ör. "Ne oldu?") talimata rağmen gelirse sayılır; testler ve günlük için. */
export function genericHeadingCount(story: Story): number {
  const all = [...story.simple.sections, ...(story.technical?.sections ?? [])];
  return all.filter((s) => GENERIC_HEADINGS.has(s.heading.toLocaleLowerCase('tr').replace(/[?!.]/g, '').trim())).length;
}

/** Haber yanıtını kayda uygular; yanıt eksikse false döner ve kayıt sonraki çalışmaya kalır. */
export function applyNews(item: NewsItem, out: NewsOut, basis: Story['basis'] = 'full'): boolean {
  if (out.relevant === false) {
    item.hidden = true;
    item.writer = 'ai';
    item.writerVersion = NEWS_WRITER_VERSION;
    return true;
  }
  const title = plain(out.title, 120);
  const summary = plain(out.summary, 300);
  const tldr = (Array.isArray(out.tldr) ? out.tldr : []).map((t) => plain(t, 240)).filter(Boolean).slice(0, 3);
  const why = paragraphs(out.why, 800);
  const simple = cleanVersion(out.simple, 1200);
  const technicalRaw = cleanVersion(out.technical, 1000);
  const technical = technicalRaw.intro && technicalRaw.sections.length > 0 ? technicalRaw : null;
  if (!title || !summary || tldr.length < 2 || !why || !simple.intro || simple.sections.length === 0) return false;
  const partial = { tldr, why, simple, technical };
  const story: Story = { ...partial, glossary: cleanGlossary(out.glossary, storyText(partial)), basis };
  item.titleTr = title;
  item.summaryTr = summary;
  item.story = story;
  // Eski uygulama sürümleri için aynı içeriğin önceki biçimi.
  item.article = {
    intro: simple.intro,
    primer: story.glossary.slice(0, 3).map((g) => ({ term: g.term, explanation: g.definition })),
    sections: simple.sections,
  };
  item.topics = cleanTopics(out.topics);
  item.importance = Math.min(5, Math.max(1, Math.round(Number(out.importance) || 3)));
  item.readingMinutes = storyMinutes(story);
  const category = (CATEGORY_IDS as readonly string[]).includes(out.category) ? (out.category as Category) : null;
  item.category = category ?? classify(item.titleOriginal, item.excerptOriginal, findSource(item.sourceId)?.defaultCategory ?? 'industry');
  item.translated = true;
  item.hidden = false;
  item.writer = 'ai';
  item.writerVersion = NEWS_WRITER_VERSION;
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

export function applyRepo(repo: Repo, out: RepoOut, basis: RepoStory['basis'] = 'readme'): boolean {
  const summary = plain(out.summary, 260);
  const what = paragraphs(out.what, 900);
  const why = paragraphs(out.why, 600);
  if (!summary || !what || !why) return false;
  const useCases = (Array.isArray(out.useCases) ? out.useCases : [])
    .map((u) => plain(u, 160).replace(/\.$/, ''))
    .filter(Boolean)
    .slice(0, 4);
  repo.descriptionTr = summary;
  repo.story = { what, why, useCases, audience: plain(out.audience, 240), caution: plain(out.caution, 400), basis };
  repo.translated = true;
  repo.writer = 'ai';
  repo.writerVersion = REPO_WRITER_VERSION;
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

/** Editöre verilecek haber metni: sayfadan ya da akıştan okunan en uzun metin. */
export function sourceText(page: ArticlePage | null, feedContent: string | undefined): string {
  const pageText = page?.text ?? '';
  const feedText = feedContent ?? '';
  return pageText.length >= feedText.length ? pageText : feedText;
}

export function newsPrompt(item: NewsItem, page: ArticlePage | null, feedContent: string | undefined): string {
  const text = sourceText(page, feedContent);
  const lines = [
    `Kaynak: ${item.sourceName} (${kindLabel(item.sourceKind)})`,
    `Yayın tarihi: ${item.publishedAt.slice(0, 10)}`,
    `Orijinal başlık: ${item.titleOriginal}`,
  ];
  const excerpt = item.excerptOriginal || page?.description || '';
  if (excerpt) lines.push(`Kaynağın kısa açıklaması: ${excerpt}`);
  if (item.points !== null) lines.push(`Hacker News: ${item.points} puan, ${item.comments ?? 0} yorum (bağlantı topluluk tarafından paylaşıldı).`);
  if (text.length >= 300) {
    lines.push('', `Haber metni (${text.length} karakter):`, '"""', text, '"""');
  } else {
    lines.push(
      '',
      'Haber metnine ulaşılamadı. Yalnızca başlık ve kısa açıklamaya dayan: tldr yine 3 madde olsun ama yalnızca bilinenleri söylesin; ' +
        'simple 1-2 bölüm ve en fazla 200 kelime olsun; technical alanında intro boş metin, sections boş liste olsun.',
    );
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

export function repoPrompt(repo: Repo, readme: string): string {
  const lines = [
    `Proje: ${repo.id}`,
    `GitHub'da açılış tarihi: ${repo.createdAt.slice(0, 10)}`,
    `Yıldız: ${repo.stars}, çatallama (fork): ${repo.forks}`,
    repo.language ? `Ana dil: ${repo.language}` : '',
    repo.topics.length ? `Konular: ${repo.topics.join(', ')}` : '',
    `Kısa açıklama: ${repo.descriptionOriginal || '(yok)'}`,
  ].filter(Boolean);
  if (readme.length >= 200) {
    lines.push('', 'README:', '"""', readme, '"""');
  } else {
    lines.push('', 'README okunamadı. Yalnızca kısa açıklamaya dayan; what ve why birer cümle, useCases en fazla 2 madde olsun.');
  }
  return lines.join('\n');
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
  /** Projenin sadeleştirilmiş README metni (yoksa boş). */
  fetchReadme?: (repo: Repo) => Promise<string>;
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
  if (item.hidden && item.writer === 'ai') return false;
  return item.writer !== 'ai' || item.writerVersion < NEWS_WRITER_VERSION || item.story === null;
}
export function needsPaper(paper: Paper): boolean {
  return paper.writer !== 'ai' || paper.writerVersion < WRITER_VERSION;
}
export function needsModel(model: AiModel): boolean {
  return model.writer !== 'ai' && model.cardExcerpt.length > 0;
}
export function needsRepo(repo: Repo): boolean {
  return repo.writer !== 'ai' || repo.writerVersion < REPO_WRITER_VERSION || repo.story === null;
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
        const feed = options.feedContent?.get(item.id);
        const basis = sourceText(page, feed).length >= 300 ? 'full' : 'excerpt';
        const out = await ask<NewsOut>(NEWS_SYSTEM, newsPrompt(item, page, feed), NEWS_SCHEMA, 8000);
        return out ? applyNews(item, out, basis) : false;
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
        let readme = '';
        try {
          readme = (await options.fetchReadme?.(repo)) ?? '';
        } catch (error) {
          log.info(`README okunamadı (${repo.id}): ${errorMessage(error)}`);
        }
        const basis = readme.length >= 200 ? 'readme' : 'description';
        const out = await ask<RepoOut>(REPO_SYSTEM, repoPrompt(repo, readme), REPO_SCHEMA, 2000);
        return out ? applyRepo(repo, out, basis) : false;
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
