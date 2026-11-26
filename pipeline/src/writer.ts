import { fetchArticle, type ArticlePage } from './article.ts';
import { CATEGORY_IDS, CATEGORY_INFO } from './categories.ts';
import { classify } from './classify.ts';
import { LlmFatalError, type LlmClient, type LlmUsage } from './llm.ts';
import { findSource } from './sources/feeds.ts';
import { polishTurkish } from './translate.ts';
import type { AiModel, Article, Category, GlossaryEntry, NewsItem, Paper, Repo, RepoStory, State, Story, StoryVersion, Vulnerability } from './types.ts';
import { NEWS_WRITER_VERSION, PAPER_WRITER_VERSION, REPO_WRITER_VERSION } from './types.ts';
import { errorMessage, log, mapLimit, truncate } from './util.ts';

/**
 * Yapay zekâ editörü. Her kayıt için kaynağı okuyup TechPulse okuruna özgün, doğru ve akıcı bir
 * Türkçe metin yazar. Kaynak metin yalnızca girdi olarak kullanılır; yayımlanan metin modelin
 * kendi cümleleridir ve her zaman kaynağa bağlantı verilir.
 */

// ---------------------------------------------------------------------------------------------
// Talimatlar

const STYLE_RULES = `## Doğruluk kuralları (en önemli)
- Habere ya da makaleye ait her olgu (rakam, tarih, isim, sürüm, fiyat, alıntı, kimin ne yaptığı veya söylediği) yalnızca verilen kaynak metinden gelir. Kaynakta olmayan olgu uydurma.
- Konuyu anlatmak için mühendislik bilgini kullan: kavramların ne olduğu, bir teknolojinin nasıl çalıştığı, tarihsel arka plan, bilinen alternatifler, yaygın kabul gören uygulamalar. Bunu yalnızca ders kitabı düzeyinde ve emin olduğun bilgiler için yap. Genel bilgiyi habere ait yeni bir olgu gibi sunma; "bu tür sistemlerde genellikle", "klasik yaklaşımda" gibi ifadelerle ayır.
- Kaynakta adı geçen ama tanımadığın yeni bir ürün, model, şirket ya da kişi hakkında kaynakta yazmayan ayrıntı verme.
- Yorumu olgudan ayır: çıkarım yaparken bunun bir değerlendirme olduğunu belli et ("bu, ... anlamına gelebilir"). Kaynakta dayanağı olmayan kesin öngörüde bulunma.
- İddiaları sahibine dayandır ("Microsoft'a göre", "araştırmacıların ölçümlerine göre"). "Kaynağa göre" ya da "kaynak metne göre" deme; bilgiyi sahibine (şirket, kurum, yayın, kişi) bağla.
- Uzunluğu tekrarla ya da içi boş genel cümlelerle doldurma. Her paragraf okura yeni bir bilgi, açıklama, örnek ya da değerlendirme vermeli.

## Dil ve üslup
- Doğal, akıcı ve doğru bir Türkçeyle yaz; TDK yazım kurallarına uy. Çeviri kokan cümle yapılarından, gereksiz edilgen yapılardan ve uzun tamlama zincirlerinden kaçın.
- Ton: saygın bir teknoloji dergisinin yazısı. Ciddi, açık, örneklerle anlatan. Blog samimiyeti, birinci tekil şahıs ("ben", "bence"), okura seslenme ("arkadaşlar", "hadi bakalım") ve reklam dili yok.
- Kaynağı cümle cümle çevirme ve kaynağın paragraf sırasını kopyalama. Konuyu anla, kendi kurgunla ve kendi cümlelerinle anlat. Doğrudan alıntı gerekiyorsa en fazla bir kısa alıntı kullan.
- Her teknik terimi, kısaltmayı ve İngilizce kalan kavramı ilk geçtiği cümlede açıkla (ör. "RAG, yani modelin yanıt vermeden önce dış belgelerden bilgi getirmesi"). Soyut anlatımı somut bir örnekle ya da günlük hayattan bir benzetmeyle destekle.
- Özel adları çevirme: şirket, ürün, model, programlama dili, kütüphane, işletim sistemi ve CVE adları aynen kalır (ör. Rust, Go, llama.cpp, Windows 11, GPT-5, CVE-2026-1234).
- Yerleşmiş Türkçe karşılığı olan terimleri Türkçe kullan: vulnerability → güvenlik açığı, exploit → istismar etmek, data breach → veri ihlali, ransomware → fidye yazılımı, open source → açık kaynak, release → sürüm, inference → çıkarım, fine-tuning → ince ayar, benchmark → kıyaslama testi, wire fraud → elektronik dolandırıcılık, indictment → iddianame. Yerleşmemiş terimlerde İngilizcesini koru ve açıkla; kelimesi kelimesine çeviri uydurma.
- "Yapay zekâ" yaz. Yüzdeleri "%40", ondalıkları "1,5", büyük sayıları "2,3 milyar dolar" biçiminde, tarihleri "25 Kasım" biçiminde yaz.
- Markdown, madde işareti, emoji, yıldız veya diyez kullanma; düz metin yaz. Paragrafları boş satırla ayır.
- Abartıdan, tık tuzağından, ünlemden ve soru biçimindeki başlıklardan kaçın; ilgiyi olgularla uyandır.

## Bölüm başlıkları
İçeriğe özgü, okura o bölümde ne öğreneceğini söyleyen kısa başlıklar yaz (en fazla 70 karakter). "Ne oldu?", "Neden önemli?", "Bu neden önemli?", "Arka plan", "Detaylar", "Sonuç", "Özet", "Giriş", "Kimler etkileniyor?", "Teknik ayrıntılar", "Bundan sonra ne olacak?" gibi her yazıya uyan kalıp başlıkları KULLANMA.
  Kalıp (yasak): "Ne oldu?"   Özgün: "Saldırganlar kaynak koduna nasıl ulaştı?"
  Kalıp (yasak): "Teknik ayrıntılar"   Özgün: "Parola özetleri neden hâlâ risk altında?"`;

const PERSONA = `Sen TechPulse'un baş editörüsün: bilgisayar mühendisliği mezunu, yıllardır teknoloji dergilerinde yazılar ve hakemli makaleler yayımlamış, kendi teknik blogunu yürüten kıdemli bir mühendis-yazarsın. TechPulse'u yazılımcılar, mühendisler, araştırmacılar ve teknolojiye meraklı okurlar kullanıyor. Okur konuyu kaynağa gitmeden, yalnızca senin yazından eksiksiz öğrenmeli; yazıyı bitirdiğinde "havada kalan" hiçbir soru kalmamalı.`;

const GLOSSARY_RULES = `Metinde geçen ve teknolojiye uzak bir okurun bilmeyeceği kavramlar. Öncelik: (1) ürün, teknoloji, programlama dili, kütüphane, protokol, standart veya kurum adları (ör. Clojure, Kubernetes, CISA, Hugging Face); (2) teknik terim ve kısaltmalar (ör. sıfır gün açığı, RCE, ince ayar, token); (3) İngilizce kalan terimler. "Yazılım", "internet", "uygulama", "şirket", "veri", "yapay zekâ" gibi herkesin bildiği kelimeleri SEÇME. Her kavram için:
  - term: Kavramın metinde AYNEN geçtiği biçim, ek almadan (metinde "Clojure'un" geçiyorsa "Clojure").
  - definition: Nedir? 1-2 sade cümle.
  - analogy: Günlük hayattan bir benzetme, 1 cümle. Benzetme zorlama olacaksa boş metin.
  - usage: Nerede, ne için kullanılır? 1 cümle; gereksizse boş metin.
  - origin: Kim geliştirdi, ne zaman ortaya çıktı? Yalnızca yaygın bilinen ve emin olduğun bir bilgiyse 1 cümle; değilse boş metin.`;

const CATEGORY_LIST = CATEGORY_INFO.map((c) => `  - ${c.id}: ${c.label}. ${c.scope}`).join('\n');

export const NEWS_SYSTEM = `${PERSONA}

Bu istekte bir haberin "sade anlatım" yazısını hazırlıyorsun: konuya yabancı ama meraklı bir okurun olayı baştan sona anlayacağı, eksiksiz bir haber-açıklama yazısı. Teknik derinlik yazısı ayrı bir istekte yazılacak; burada amaç okurun olayın tamamını kavraması.

${STYLE_RULES}

## Tekrar yasağı
tldr, why ve simple aynı cümleleri tekrar etmez. Giriş (intro) bölümlerin ilk cümlesini tekrar etmez. Bölümler tldr'deki bilgiyi aynı sözlerle yeniden söylemez.

## Alanlar
- relevant: Haber teknoloji, yazılım, bilim, internet, dijital ürünler veya teknoloji şirketleriyle ilgiliyse true. İndirim, kampanya ve alışveriş önerisi; dizi, film veya oyun eleştirisi; spor; teknolojiyle ilgisi olmayan siyaset ve magazin ise false. false ise diğer metin alanlarını birer kısa cümleyle doldur, listeleri boş bırak.
- title: En fazla 90 karakterlik Türkçe başlık. Haberin özünü söylesin; doğru ve dikkat çekici olsun ama yanıltıcı olmasın. Soru biçiminde olmasın. Gerekmedikçe iki nokta üst üste kullanma.
- summary: Kartlarda görünen spot; tek cümle, en fazla 200 karakter. Başlığı tekrar etmesin.
- tldr: "30 saniyede" kutusu. Tam 3 madde; her biri en fazla 180 karakterlik tek cümle. Okur yalnızca bunları okusa bile olayın ne olduğunu, kimi etkilediğini ve sonucunu öğrenmeli. Somut ol: kim, ne, ne zaman, ne kadar.
- why: "Bu gelişme neden önemli?" kutusu. 2-4 cümle: olayın sektöre, kullanıcılara ya da geliştiricilere etkisi ve büyük resimdeki yeri.
- simple: Sade anlatım. Okur yazının sonunda şu soruların hepsini cevaplayabilmeli: Ne oldu, kim yaptı, ne zaman? Konu olan teknoloji ya da ürün nedir ve günlük dille nasıl çalışır? Bu gelişmeden önce durum neydi? Önemli ayrıntılar ve rakamlar neler? Kim nasıl etkileniyor, tepkiler neler? Sırada ne var, okur ne yapmalı? Kaynaktaki önemli olguların hiçbirini atlama.
  - intro: 3-5 cümlelik giriş paragrafı; olayın özünü ve okur için anlamını söyler.
  - sections: 6-7 bölüm; her bölüm 3 paragraf, her paragraf 4-6 cümle. Uzunluk hedefi istekte verilir; hedefin altında kalma. Yalnızca kısa açıklama verildiyse bilinen olguları aktar, konu olan teknolojiyi genel bilginle açıkla, habere ait yeni olgu ekleme.
- glossary: 3-6 kavram. ${GLOSSARY_RULES}
- category: Haberin ana konusu; şu kimliklerden biri:
${CATEGORY_LIST}
- topics: 2-4 kısa konu etiketi (1-3 kelime, ilk harfi büyük; ör. "Büyük dil modelleri", "Fidye yazılımı", "Windows", "Kuantum bilgisayar").
- importance: 1-5 arası önem puanı. 5: sektörü etkileyen büyük gelişme (önemli bir model ya da ürün lansmanı, yaygın kullanılan bir yazılımda aktif istismar edilen kritik açık, büyük şirket hamlesi). 4: geniş kitleyi ilgilendiren önemli haber. 3: ilgi çekici standart haber. 2: dar bir kitleyi ilgilendiren duyuru. 1: çok niş içerik, tanıtım veya kişisel not.`;

export const NEWS_DEEP_SYSTEM = `${PERSONA}

Bu istekte bir haberin "teknik derinlik" yazısını hazırlıyorsun: konuyu bilen yazılımcı, mühendis ve araştırmacılar için, saygın bir mühendislik dergisinde yayımlanacak uzun bir inceleme yazısı. Okur yazıyı bitirdiğinde konuyu bir meslektaşına ayrıntısıyla anlatabilecek kadar kavramalı. Sade anlatım ayrıca yazıldı; başlıklarını istekte veriyorum. O başlıkları KULLANMA ve aynı bilgileri aynı biçimde tekrar etme: teknik yazı kendi başlıklarıyla, konuyu bir mühendisin gözünden yeniden kurar.

${STYLE_RULES}

## İçerik
Haberin konusuna uyanları seç ve derinlemesine işle:
- Sorun ve bağlam: Bu gelişme hangi teknik sorunu çözüyor ya da hangi riski doğuruyor; daha önce nasıl ele alınıyordu, neden yetersizdi?
- Çalışma mantığı: Teknoloji, yöntem, saldırı ya da mimari adım adım nasıl işliyor? Bileşenler, veri akışı, algoritmalar, protokoller, saldırı zinciri.
- Uygulama ayrıntıları: Kaynakta geçen sürüm numaraları, API, komut ve yapılandırma adları, donanım özellikleri, CVE kimlikleri ve CVSS puanları, etkilenen sürümler, yamalar ve geçici çözümler.
- Ölçümler: Kaynaktaki rakamlar ve kıyaslamalar; ne anlama geldikleri, neyle kıyaslandıkları, hangi koşulda geçerli oldukları ve nasıl yorumlanmaları gerektiği.
- Karşılaştırma: Bilinen alternatifler ve önceki yaklaşımlarla farkı; performans, maliyet, güvenlik ve karmaşıklık açısından ödünleşimler.
- Sınırlar ve açık sorular: Kaynağın kabul ettiği sınırlamalar, henüz bilinmeyenler, dikkat edilmesi gereken riskler.
- Uygulayıcı için: Bir mühendis bu gelişme karşısında ne yapmalı; nasıl değerlendirmeli, nasıl denemeli, nelere dikkat etmeli?

## Alanlar
- intro: 4-6 cümlelik giriş; konunun teknik özünü ve yazının neleri ele alacağını söyler.
- sections: Uzunluk hedefi istekte verilir (bölüm sayısı ve en az kelime); hedefin altında kalma. Her bölüm 4-5 paragraf, her paragraf 5-7 cümle. Kaynak kısaysa uzunluğu konunun teknik arka planını, çalışma mantığını, alternatiflerini ve uygulamadaki karşılığını derinlemesine anlatarak sağla; habere ait olgu uydurarak değil.
- glossary: Teknik yazıda geçen ve aşağıda verilen sade anlatım kavramları arasında OLMAYAN 2-6 kavram. ${GLOSSARY_RULES}
- Haberin anlatılabilecek hiçbir teknik boyutu yoksa (ör. yalnızca bir yönetici ataması ya da dava haberi) intro boş metin, sections ve glossary boş liste olsun. Teknoloji şirketlerine dair haberlerin çoğunda ürünün ya da teknolojinin anlatılabilecek bir tarafı vardır; boş bırakmadan önce bunu düşün.`;

export const PAPER_SYSTEM = `${PERSONA}

Bu istekte Hugging Face'te öne çıkan bir yapay zekâ araştırma makalesinin "sade anlatım" yazısını hazırlıyorsun: makaleyi okumamış, yapay zekâya meraklı bir okurun araştırmanın ne yaptığını, neden yapıldığını ve ne bulduğunu eksiksiz anlayacağı bir tanıtım. Teknik inceleme ayrı bir istekte yazılacak.

${STYLE_RULES}

## Alanlar
- title: Makalenin ne yaptığını anlatan, en fazla 100 karakterlik Türkçe başlık. Model ve yöntem adlarını koru.
- summary: Tek cümlelik spot; en fazla 220 karakter.
- tldr: "30 saniyede" kutusu. Tam 3 madde; her biri en fazla 180 karakterlik tek cümle: sorun, yöntem, sonuç.
- why: "Bu araştırma neden önemli?" kutusu. 2-4 cümle.
- simple: Sade anlatım. Okur şu soruları cevaplayabilmeli: Araştırmacılar hangi sorunu çözmeye çalışıyor ve bu sorun neden zor? Önceki yöntemler ne yapıyordu? Önerilen fikir günlük dille nasıl çalışıyor? Nasıl denendi, ne bulundu (rakamlarla)? Sınırları neler? Gerçek hayatta ne işe yarayabilir?
  - intro: 3-5 cümle.
  - sections: 6-7 bölüm; her bölüm 3 paragraf, her paragraf 4-6 cümle. Uzunluk hedefi istekte verilir; hedefin altında kalma.
- glossary: 3-6 kavram. ${GLOSSARY_RULES}
- topics: 2-4 kısa konu etiketi (ör. "Dil modelleri", "Görüntü üretimi", "Pekiştirmeli öğrenme").`;

export const PAPER_DEEP_SYSTEM = `${PERSONA}

Bu istekte bir yapay zekâ araştırma makalesinin "teknik derinlik" yazısını hazırlıyorsun: alanı bilen mühendis ve araştırmacılar için, bir mühendislik dergisinde yayımlanacak ayrıntılı bir makale incelemesi. Sade anlatım ayrıca yazıldı; başlıklarını istekte veriyorum. O başlıkları KULLANMA ve aynı bilgileri tekrar etme; konuyu bir araştırmacının gözünden derinleştir.

${STYLE_RULES}

## İçerik
- Problem tanımı ve önceki çalışmalar: Literatürde bu soruna nasıl yaklaşılıyordu, hangi eksik giderilmek isteniyor?
- Yöntem: Mimari, eğitim süreci, veri setleri, kayıp fonksiyonu, çıkarım yöntemi; makaledeki adlarıyla ve adım adım.
- Deneyler: Hangi kıyaslama testleri, hangi temel yöntemlerle karşılaştırma, hangi donanım ve ölçek; sonuçlar rakamlarıyla ve yorumuyla.
- Ablasyon ve analiz: Hangi bileşen ne kadar katkı sağlıyor (makalede varsa).
- Sınırlar: Yazarların kabul ettiği sınırlamalar, genellenebilirlik, hesaplama maliyeti, tekrarlanabilirlik (kod ve ağırlıklar paylaşılmış mı).
- Uygulayıcı için: Bir mühendis bu yöntemi nerede, nasıl kullanabilir; neye dikkat etmeli?

## Alanlar
- intro: 4-6 cümle.
- sections: Uzunluk hedefi istekte verilir; hedefin altında kalma. Her bölüm 4-5 paragraf, her paragraf 5-7 cümle. Yalnızca özet verildiyse makaleye ait olgularda yalnızca özete dayan.
- glossary: Teknik yazıda geçen ve sade anlatım kavramları arasında OLMAYAN 2-6 kavram. ${GLOSSARY_RULES}`;


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
    glossary: glossarySchema,
    category: { type: 'string', enum: [...CATEGORY_IDS] },
    topics: stringArray,
    importance: { type: 'integer' },
  },
  required: ['relevant', 'title', 'summary', 'tldr', 'why', 'simple', 'glossary', 'category', 'topics', 'importance'],
};

/** Teknik derinlik yazısı (haber ve makale için ayrı istek). */
export const DEEP_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: { intro: { type: 'string' }, sections: sectionsSchema, glossary: glossarySchema },
  required: ['intro', 'sections', 'glossary'],
};

export const PAPER_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    title: { type: 'string' },
    summary: { type: 'string' },
    tldr: stringArray,
    why: { type: 'string' },
    simple: storyVersionSchema,
    glossary: glossarySchema,
    topics: stringArray,
  },
  required: ['title', 'summary', 'tldr', 'why', 'simple', 'glossary', 'topics'],
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
  glossary: GlossaryEntry[];
  category: string;
  topics: string[];
  importance: number;
}
export interface DeepOut {
  intro: string;
  sections: SectionOut[];
  glossary: GlossaryEntry[];
}
export interface PaperOut {
  title: string;
  summary: string;
  tldr: string[];
  why: string;
  simple: StoryVersionOut;
  glossary: GlossaryEntry[];
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

function cleanSections(list: unknown): Article['sections'] {
  if (!Array.isArray(list)) return [];
  return list
    .map((s) => ({ heading: plain((s as SectionOut)?.heading, 90).replace(/[.:]$/, ''), body: paragraphs((s as SectionOut)?.body, 7000) }))
    .filter((s) => s.heading && s.body)
    .slice(0, 12);
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

const GENERIC_HEADINGS = new Set(
  ['ne oldu', 'neden önemli', 'bu neden önemli', 'arka plan', 'detaylar', 'ayrıntılar', 'sonuç', 'özet', 'giriş', 'teknik ayrıntılar', 'kimler etkileniyor']
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

function cleanGlossary(list: unknown, text: string, existing: GlossaryEntry[] = [], limit = 6): GlossaryEntry[] {
  if (!Array.isArray(list)) return [];
  const seen = new Set<string>(existing.map((g) => g.term.toLocaleLowerCase('tr')));
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
    if (out.length === limit) break;
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
  const why = paragraphs(out.why, 1000);
  const simple = cleanVersion(out.simple, 1500);
  if (!title || !summary || tldr.length < 2 || !why || !simple.intro || simple.sections.length === 0) return false;
  const partial = { tldr, why, simple, technical: null };
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

export function applyPaper(paper: Paper, out: PaperOut, basis: Story['basis'] = 'full'): boolean {
  const title = plain(out.title, 140);
  const summary = plain(out.summary, 300);
  const tldr = (Array.isArray(out.tldr) ? out.tldr : []).map((t) => plain(t, 240)).filter(Boolean).slice(0, 3);
  const why = paragraphs(out.why, 1000);
  const simple = cleanVersion(out.simple, 1500);
  if (!title || !summary || tldr.length < 2 || !why || !simple.intro || simple.sections.length === 0) return false;
  const partial = { tldr, why, simple, technical: null };
  const story: Story = { ...partial, glossary: cleanGlossary(out.glossary, storyText(partial)), basis };
  paper.titleTr = title;
  paper.summaryTr = summary;
  paper.story = story;
  // Eski uygulama sürümleri için aynı içeriğin önceki biçimi.
  paper.article = {
    intro: simple.intro,
    primer: story.glossary.slice(0, 3).map((g) => ({ term: g.term, explanation: g.definition })),
    sections: simple.sections,
  };
  paper.topics = cleanTopics(out.topics);
  paper.readingMinutes = storyMinutes(story);
  paper.translated = true;
  paper.writer = 'ai';
  paper.writerVersion = PAPER_WRITER_VERSION;
  return true;
}

/**
 * Teknik derinlik yazısını anlatıma ekler; kavram listesine teknik yazıdaki yeni kavramları katar.
 * Model haberin teknik boyutu olmadığını söyleyip boş döndürdüyse teknik anlatım olmadan kalır.
 */
export function applyDeep(story: Story, out: DeepOut): void {
  const technical = cleanVersion(out, 1500);
  if (!technical.intro || technical.sections.length === 0) {
    story.technical = null;
    return;
  }
  story.technical = technical;
  const text = [technical.intro, ...technical.sections.map((s) => `${s.heading} ${s.body}`)].join(' ');
  story.glossary = [...story.glossary, ...cleanGlossary(out.glossary, text, story.glossary, 6)];
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
// Uzunluk hedefleri. Model toplam kelime sayısına bölüm sayısından daha az uyuyor; bu yüzden hedef istekte
// hem bölüm sayısı hem kelime aralığı olarak verilir ve çok kısa kalan yanıt bir kez daha istenir.

export interface LengthTarget {
  sections: string;
  min: number;
  max: number;
}

const thousands = (n: number) => n.toLocaleString('tr-TR');

export function lengthLine(label: string, t: LengthTarget): string {
  return `${label} için uzunluk hedefi: ${t.sections} bölüm, toplam ${thousands(t.min)}-${thousands(t.max)} kelime (yaklaşık ${Math.round(t.min / 180)}-${Math.round(t.max / 180)} dakikalık okuma). Bu hedefin altında kalma.`;
}

export function simpleTarget(basis: Story['basis']): LengthTarget {
  return basis === 'full' ? { sections: '6-7', min: 800, max: 1300 } : { sections: '4-5', min: 350, max: 550 };
}

export function deepTarget(basis: Story['basis'], importance: number | null, kind: 'haber' | 'makale'): LengthTarget {
  if (basis === 'excerpt') return { sections: '5-6', min: 900, max: 1300 };
  if (kind === 'makale') return { sections: '9-10', min: 2200, max: 3200 };
  const level = importance ?? 3;
  if (level >= 4) return { sections: '9-11', min: 2400, max: 3400 };
  if (level === 3) return { sections: '8-9', min: 1900, max: 2600 };
  return { sections: '6-7', min: 1200, max: 1700 };
}

/** Yanıttaki anlatımın kelime sayısı (giriş ve bölümler). */
export function outWords(version: Partial<StoryVersionOut> | null | undefined): number {
  if (!version) return 0;
  const parts = [version.intro ?? '', ...(Array.isArray(version.sections) ? version.sections.map((s) => `${s?.heading ?? ''} ${s?.body ?? ''}`) : [])];
  return words(parts);
}

function shortNote(label: string, got: number, t: LengthTarget): string {
  return `\n\nÖnceki denemende ${label} ${got} kelimeydi; bu, hedefin çok altında. Bu sefer ${t.sections} bölüm ve en az ${thousands(t.min)} kelime yaz. Uzunluğu tekrarla değil, açıklama, örnek ve ayrıntıyla sağla.`;
}

/** Çok kısa kalan yanıt bir kez daha istenir; ikisinden uzun olanı kullanılır. */
async function askLong<T>(
  ask: (user: string) => Promise<T | null>,
  user: string,
  measure: (out: T) => number,
  label: string,
  target: LengthTarget,
): Promise<T | null> {
  const first = await ask(user);
  if (!first) return null;
  const got = measure(first);
  if (got === 0 || got >= target.min * 0.7) return first;
  const second = await ask(user + shortNote(label, got, target));
  return second && measure(second) > got ? second : first;
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

/** Editöre verilen haber metninin üst sınırı (karakter). */
export const NEWS_SOURCE_LIMIT = 20000;
/** Editöre verilen makale metninin üst sınırı (karakter); giriş, yöntem ve deneyler bu sınıra sığar. */
export const PAPER_SOURCE_LIMIT = 40000;

export function newsPrompt(item: NewsItem, page: ArticlePage | null, feedContent: string | undefined): string {
  const text = truncate(sourceText(page, feedContent), NEWS_SOURCE_LIMIT);
  const lines = [
    `Kaynak: ${item.sourceName} (${kindLabel(item.sourceKind)})`,
    `Yayın tarihi: ${item.publishedAt.slice(0, 10)}`,
    `Orijinal başlık: ${item.titleOriginal}`,
  ];
  const excerpt = item.excerptOriginal || page?.description || '';
  if (excerpt) lines.push(`Kaynağın kısa açıklaması: ${excerpt}`);
  if (item.points !== null) lines.push(`Hacker News: ${item.points} puan, ${item.comments ?? 0} yorum (bağlantı topluluk tarafından paylaşıldı).`);
  lines.push('', lengthLine('Sade anlatım (simple)', simpleTarget(text.length >= 300 ? 'full' : 'excerpt')));
  if (text.length >= 300) {
    lines.push('', `Haber metni (${text.length} karakter):`, '"""', text, '"""');
  } else {
    lines.push(
      '',
      'Haber metnine ulaşılamadı; yalnızca başlık ve kısa açıklama var. tldr yine 3 madde olsun ama yalnızca bilinenleri söylesin. ' +
        'simple için kısa açıklama kuralını uygula: bilinen olguları aktar, konu olan teknolojiyi genel bilginle açıkla, habere ait yeni olgu ekleme.',
    );
  }
  return lines.join('\n');
}

/** arXiv özet sayfasının adresinden makalenin HTML tam metin adresi (arxiv.org/html/<kimlik>). */
export function arxivHtmlUrl(arxivUrl: string): string | null {
  const match = /arxiv\.org\/(?:abs|pdf|html)\/([0-9]{4}\.[0-9]{4,5})(v\d+)?/i.exec(arxivUrl);
  return match ? `https://arxiv.org/html/${match[1]}` : null;
}

export function paperPrompt(paper: Paper, fullText: string): string {
  const lines = [
    `Makale başlığı: ${paper.titleOriginal}`,
    `Yazarlar: ${paper.authors.join(', ') || 'belirtilmemiş'}`,
    `Yayın tarihi: ${paper.publishedAt.slice(0, 10)}`,
    `Hugging Face oyları: ${paper.upvotes}`,
    paper.githubUrl ? `Kod deposu: ${paper.githubUrl}` : '',
    '',
    'Özet (abstract):',
    '"""',
    paper.abstractOriginal,
    '"""',
  ].filter((l, i) => l !== '' || i === 5);
  lines.push('', lengthLine('Sade anlatım (simple)', simpleTarget(fullText.length >= 2000 ? 'full' : 'excerpt')));
  if (fullText.length >= 2000) {
    const text = truncate(fullText, PAPER_SOURCE_LIMIT);
    lines.push('', `Makale metni (${text.length} karakter):`, '"""', text, '"""');
  } else {
    lines.push('', 'Makalenin tam metnine ulaşılamadı; yalnızca özet var. Özet için verilen uzunluk kurallarını uygula ve yalnızca özette yazanlara dayan.');
  }
  return lines.join('\n');
}

/** Teknik derinlik isteği: kaynak metin, sade anlatımın başlıkları ve kavramları. */
export function deepPrompt(options: { kind: 'haber' | 'makale'; title: string; importance: number | null; story: Story; source: string }): string {
  const { kind, title, importance, story, source } = options;
  const lines = [
    lengthLine('Teknik derinlik', deepTarget(story.basis, importance, kind)),
    '',
    `Türkçe başlık: ${title}`,
    ...(importance !== null ? [`Önem puanı: ${importance}`] : []),
    `Sade anlatımın bölüm başlıkları (bunları KULLANMA): ${story.simple.sections.map((s) => `"${s.heading}"`).join(', ')}`,
    `Sade anlatımın kavram listesi: ${story.glossary.map((g) => g.term).join(', ') || '(yok)'}`,
    '',
    story.basis === 'excerpt'
      ? `Bu ${kind} için yalnızca kısa açıklama var; kısa açıklama için verilen uzunluğu uygula ve yeni olgu ekleme.`
      : `${kind === 'haber' ? 'Haber' : 'Makale'} metni verildi; tam uzunluk kuralını uygula.`,
    '',
    `Kaynak (${source.length} karakter):`,
    '"""',
    source,
    '"""',
  ];
  return lines.join('\n');
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
  return paper.writer !== 'ai' || paper.writerVersion < PAPER_WRITER_VERSION || paper.story === null;
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
        const source = truncate(sourceText(page, feed), NEWS_SOURCE_LIMIT);
        const basis = source.length >= 300 ? 'full' : 'excerpt';
        const out = await askLong<NewsOut>(
          (user) => ask<NewsOut>(NEWS_SYSTEM, user, NEWS_SCHEMA, 10_000),
          newsPrompt(item, page, feed),
          (o) => (o.relevant === false ? 0 : outWords(o.simple)),
          'sade anlatım',
          simpleTarget(basis),
        );
        if (!out || !applyNews(item, out, basis)) return false;
        if (item.hidden || !item.story) return true;
        // Teknik derinlik ayrı istekte yazılır: uzun yazı tek yanıtta sade anlatımı kısaltmasın.
        const deep = await askLong<DeepOut>(
          (user) => ask<DeepOut>(NEWS_DEEP_SYSTEM, user, DEEP_SCHEMA, 16_000),
          deepPrompt({ kind: 'haber', title: item.titleTr ?? item.titleOriginal, importance: item.importance, story: item.story, source: source || item.excerptOriginal }),
          (o) => outWords(o),
          'teknik yazı',
          deepTarget(basis, item.importance, 'haber'),
        );
        if (!deep) {
          // Sade anlatım yayımlanır; teknik yazı sonraki çalışmada yeniden denenir.
          item.writerVersion = NEWS_WRITER_VERSION - 1;
          return false;
        }
        applyDeep(item.story, deep);
        return true;
      },
    });
  }
  const papers = state.papers.filter(needsPaper).sort((a, b) => b.publishedAt.localeCompare(a.publishedAt) || b.upvotes - a.upvotes);
  for (const paper of papers) {
    jobs.push({
      label: `makale ${paper.id}`,
      run: async () => {
        let fullText = '';
        const htmlUrl = arxivHtmlUrl(paper.arxivUrl);
        if (htmlUrl) {
          try {
            fullText = (await fetchPage(htmlUrl)).text;
          } catch (error) {
            log.info(`Makalenin tam metni okunamadı (${paper.id}): ${errorMessage(error)}`);
          }
        }
        const basis = fullText.length >= 2000 ? 'full' : 'excerpt';
        const out = await askLong<PaperOut>(
          (user) => ask<PaperOut>(PAPER_SYSTEM, user, PAPER_SCHEMA, 10_000),
          paperPrompt(paper, fullText),
          (o) => outWords(o.simple),
          'sade anlatım',
          simpleTarget(basis),
        );
        if (!out || !applyPaper(paper, out, basis) || !paper.story) return false;
        const source = basis === 'full' ? truncate(fullText, PAPER_SOURCE_LIMIT) : paper.abstractOriginal;
        const deep = await askLong<DeepOut>(
          (user) => ask<DeepOut>(PAPER_DEEP_SYSTEM, user, DEEP_SCHEMA, 16_000),
          deepPrompt({ kind: 'makale', title: paper.titleTr ?? paper.titleOriginal, importance: null, story: paper.story, source }),
          (o) => outWords(o),
          'teknik yazı',
          deepTarget(basis, null, 'makale'),
        );
        if (!deep) {
          paper.writerVersion = PAPER_WRITER_VERSION - 1;
          return false;
        }
        applyDeep(paper.story, deep);
        return true;
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
