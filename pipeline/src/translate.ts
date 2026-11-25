import { classify } from './classify.ts';
import type { TranslateFn } from './mt.ts';
import { findSource } from './sources/feeds.ts';
import type { State } from './types.ts';
import { MODEL_SUMMARY_VERSION } from './types.ts';
import { errorMessage, log, truncate } from './util.ts';

/**
 * Çeviri planı: her kaydın Türkçeye çevrilecek alanları (başlık, kısa açıklamanın ilk cümleleri vb.)
 * toplanır, aynı metin bir kez çevrilir, sonuçlar kayıtlara yazılır. Bir kayıt, bütün alanları
 * çevrildiğinde "translated" olarak işaretlenir; böylece sonraki çalışmalarda tekrar çevrilmez.
 *
 * Model yeni bilgi üretmez, yalnızca kaynağın kendi metnini çevirir (makine çevirisi).
 */

/** Metnin ilk cümlelerini, toplam uzunluk `max` karakteri geçmeyecek şekilde alır. */
export function leadSentences(text: string, max: number): string {
  const clean = text.replace(/\s+/g, ' ').trim();
  if (clean.length <= max) return clean;
  const sentences = clean.split(/(?<=[.!?])\s+(?=["“(\[A-Z0-9])/);
  let out = '';
  for (const sentence of sentences) {
    const next = out ? `${out} ${sentence}` : sentence;
    if (next.length > max) break;
    out = next;
  }
  return out || truncate(clean, max);
}

/** Makine çevirisinin sık yaptığı terim ve yazım hatalarını düzeltir. Tekrar uygulanabilir. */
const GLOSSARY: [RegExp, string | ((match: string, ...groups: string[]) => string)][] = [
  [/(?<!\p{L})Kırılganlıkları(?!\p{L})/gu, 'Güvenlik açıkları'],
  [/(?<!\p{L})kırılganlıkları(?!\p{L})/gu, 'güvenlik açıkları'],
  [/(?<!\p{L})Kırılganlıklar(?!\p{L})/gu, 'Güvenlik açıkları'],
  [/(?<!\p{L})kırılganlıklar(?!\p{L})/gu, 'güvenlik açıkları'],
  [/(?<!\p{L})Kırılganlığı(?!\p{L})/gu, 'Güvenlik Açığı'],
  [/(?<!\p{L})kırılganlığı(?!\p{L})/gu, 'güvenlik açığı'],
  [/(?<!\p{L})Kırılganlık(?!\p{L})/gu, 'Güvenlik Açığı'],
  [/(?<!\p{L})kırılganlık(?!\p{L})/gu, 'güvenlik açığı'],
  [/(?<!\p{L})([Yy])apay zeka(?!\p{L})/gu, '$1apay zekâ'],
  [/(?<!\p{L})([GgTt])(üçlendirme|akviye) ([Öö])ğrenme(si|sine|sinde|siyle)?(?!\p{L})/gu, (_m, g) =>
    g === 'G' || g === 'T' ? 'Pekiştirmeli Öğrenme' : 'pekiştirmeli öğrenme'],
  [/(?<!\p{L})sömürüsü(?!\p{L})/gu, 'istismarı'],
  [/(?<!\p{L})sömürü(?!\p{L})/gu, 'istismar'],
  [/(?<!\p{L})sömürülen(?!\p{L})/gu, 'istismar edilen'],
  [/(?<!\p{L})sömürülmüş(?!\p{L})/gu, 'istismar edilmiş'],
  [/(\p{L})%\s?(\d)/gu, '$1 %$2'],
  [/%\s+(\d)/g, '%$1'],
  [/\s+([,.;:!?])/g, '$1'],
];

export function polishTurkish(text: string): string {
  let out = text;
  for (const [pattern, replacement] of GLOSSARY) {
    out = typeof replacement === 'string' ? out.replace(pattern, replacement) : out.replace(pattern, replacement);
  }
  return out;
}

/** Çeviri çıktısını sadeleştirir. */
export function tidy(value: string, max: number): string {
  let text = value.replace(/\s+/g, ' ').trim();
  text = text.replace(/^["'“”‘’«»]+|["'“”‘’«»]+$/g, '').trim();
  text = polishTurkish(text);
  if (text.length > max) text = truncate(text, max);
  return text;
}

/**
 * CISA açık adları kalıplıdır: "<Üretici> <Ürün> <Açık türü> Vulnerability". Açık türü sözlükle
 * çevrilir, üretici ve ürün adı olduğu gibi kalır: "Fortinet FortiOS Sınır Dışı Yazma Açığı".
 * Sözlükte olmayan türler için null döner (makine çevirisine bırakılır).
 */
const VULN_TYPES: Record<string, string> = {
  'remote code execution': 'Uzaktan Kod Çalıştırma',
  'arbitrary code execution': 'Rastgele Kod Çalıştırma',
  'code execution': 'Kod Çalıştırma',
  'privilege escalation': 'Yetki Yükseltme',
  'elevation of privilege': 'Yetki Yükseltme',
  'improper privilege management': 'Hatalı Yetki Yönetimi',
  'os command injection': 'İşletim Sistemi Komut Enjeksiyonu',
  'command injection': 'Komut Enjeksiyonu',
  'code injection': 'Kod Enjeksiyonu',
  'sql injection': 'SQL Enjeksiyonu',
  'injection': 'Enjeksiyon',
  'cross-site scripting': 'Siteler Arası Betik Çalıştırma (XSS)',
  'cross-site scripting (xss)': 'Siteler Arası Betik Çalıştırma (XSS)',
  'cross-site request forgery': 'Siteler Arası İstek Sahteciliği (CSRF)',
  'cross-site request forgery (csrf)': 'Siteler Arası İstek Sahteciliği (CSRF)',
  'server-side request forgery': 'Sunucu Taraflı İstek Sahteciliği (SSRF)',
  'server-side request forgery (ssrf)': 'Sunucu Taraflı İstek Sahteciliği (SSRF)',
  'out-of-bounds write': 'Sınır Dışı Yazma',
  'out-of-bounds read': 'Sınır Dışı Okuma',
  'use-after-free': 'Serbest Bırakılmış Belleğin Kullanımı (Use-After-Free)',
  'heap-based buffer overflow': 'Yığın (Heap) Tabanlı Arabellek Taşması',
  'stack-based buffer overflow': 'Yığıt (Stack) Tabanlı Arabellek Taşması',
  'buffer overflow': 'Arabellek Taşması',
  'integer overflow': 'Tamsayı Taşması',
  'type confusion': 'Tür Karışıklığı',
  'memory corruption': 'Bellek Bozulması',
  'null pointer dereference': 'Boş İşaretçi Başvurusu',
  'path traversal': 'Dizin Geçişi (Path Traversal)',
  'directory traversal': 'Dizin Geçişi (Path Traversal)',
  'authentication bypass': 'Kimlik Doğrulama Atlatma',
  'improper authentication': 'Hatalı Kimlik Doğrulama',
  'missing authentication for critical function': 'Kritik İşlev İçin Eksik Kimlik Doğrulama',
  'missing authorization': 'Eksik Yetkilendirme',
  'incorrect authorization': 'Hatalı Yetkilendirme',
  'improper authorization': 'Hatalı Yetkilendirme',
  'improper access control': 'Hatalı Erişim Denetimi',
  'deserialization of untrusted data': 'Güvenilmeyen Verinin Serileştirmeden Çıkarılması',
  'insecure deserialization': 'Güvensiz Serileştirmeden Çıkarma',
  'information disclosure': 'Bilgi İfşası',
  'exposure of sensitive information': 'Hassas Bilgi İfşası',
  'security feature bypass': 'Güvenlik Özelliği Atlatma',
  'improper input validation': 'Hatalı Girdi Doğrulama',
  'unrestricted upload of file with dangerous type': 'Tehlikeli Türde Dosyanın Kısıtlamasız Yüklenmesi',
  'unrestricted file upload': 'Kısıtlamasız Dosya Yükleme',
  'arbitrary file upload': 'Rastgele Dosya Yükleme',
  'arbitrary file read': 'Rastgele Dosya Okuma',
  'use of hard-coded credentials': 'Koda Gömülü Kimlik Bilgisi Kullanımı',
  'hard-coded credentials': 'Koda Gömülü Kimlik Bilgileri',
  'race condition': 'Yarış Durumu',
  'denial-of-service': 'Hizmet Reddi',
  'denial of service': 'Hizmet Reddi',
  'uncontrolled resource consumption': 'Kontrolsüz Kaynak Tüketimi',
  'external control of critical state data': 'Kritik Durum Verisinin Dışarıdan Denetimi',
  'improper certificate validation': 'Hatalı Sertifika Doğrulama',
  'improper verification of cryptographic signature': 'Hatalı Kriptografik İmza Doğrulama',
  'insufficient verification of data authenticity': 'Veri Özgünlüğünün Yetersiz Doğrulanması',
  'protection mechanism failure': 'Koruma Mekanizması Hatası',
  'mark of the web bypass': 'Web İşareti (MotW) Atlatma',
  'sandbox escape': 'Korumalı Alandan Kaçış',
  'open redirect': 'Açık Yönlendirme',
  'file inclusion': 'Dosya Dahil Etme',
  'spoofing': 'Sahtecilik (Spoofing)',
  'unspecified': 'Belirtilmemiş',
};
const VULN_KEYS = Object.keys(VULN_TYPES).sort((a, b) => b.length - a.length);

export function kevNameTr(name: string): string | null {
  const match = name.trim().match(/^(.*\S)\s+Vulnerabilit(?:y|ies)$/i);
  if (!match) return null;
  const body = match[1];
  const lower = body.toLowerCase();
  for (const key of VULN_KEYS) {
    if (lower === key || lower.endsWith(` ${key}`)) {
      const prefix = body.slice(0, body.length - key.length).trim();
      return `${prefix ? `${prefix} ` : ''}${VULN_TYPES[key]} Açığı`;
    }
  }
  return null;
}

/** Bütün çevrilmiş metinlere terim düzeltmelerini uygular; CISA adlarını sözlükle yeniler. */
export function polishState(state: State): void {
  const fix = (text: string | null) => (text ? polishTurkish(text) : text);
  for (const n of state.news) {
    n.titleTr = fix(n.titleTr);
    n.summaryTr = fix(n.summaryTr);
  }
  for (const p of state.papers) {
    p.titleTr = fix(p.titleTr);
    p.summaryTr = fix(p.summaryTr);
  }
  for (const v of state.security) {
    v.nameTr = kevNameTr(v.nameOriginal) ?? fix(v.nameTr);
    v.descriptionTr = fix(v.descriptionTr);
    v.actionTr = fix(v.actionTr);
  }
  for (const m of state.models) m.summaryTr = fix(m.summaryTr);
  for (const r of state.repos) r.descriptionTr = fix(r.descriptionTr);
}

interface Field {
  source: string;
  apply: (translation: string) => void;
  required: boolean;
}

interface Job {
  fields: Field[];
  done: () => void;
}

function buildJobs(state: State): Job[] {
  const jobs: Job[] = [];

  for (const item of state.news) {
    if (item.translated) continue;
    const lead = leadSentences(item.excerptOriginal, 320);
    jobs.push({
      fields: [
        { source: item.titleOriginal, apply: (t) => (item.titleTr = tidy(t, 160)), required: true },
        ...(lead.length >= 40
          ? [{ source: lead, apply: (t: string) => (item.summaryTr = tidy(t, 380) || null), required: false }]
          : []),
      ],
      done: () => (item.translated = true),
    });
  }

  for (const paper of state.papers) {
    if (paper.translated) continue;
    const lead = leadSentences(paper.abstractOriginal, 420);
    jobs.push({
      fields: [
        { source: paper.titleOriginal, apply: (t) => (paper.titleTr = tidy(t, 180)), required: true },
        ...(lead.length >= 40
          ? [{ source: lead, apply: (t: string) => (paper.summaryTr = tidy(t, 480) || null), required: false }]
          : []),
      ],
      done: () => (paper.translated = true),
    });
  }

  for (const vuln of state.security) {
    if (vuln.translated) continue;
    const fields: Field[] = [];
    const dictionaryName = kevNameTr(vuln.nameOriginal);
    if (dictionaryName) vuln.nameTr = dictionaryName;
    else if (vuln.nameOriginal) fields.push({ source: vuln.nameOriginal, apply: (t) => (vuln.nameTr = tidy(t, 160)), required: true });
    if (vuln.descriptionOriginal) {
      fields.push({
        source: leadSentences(vuln.descriptionOriginal, 420),
        apply: (t) => (vuln.descriptionTr = tidy(t, 480)),
        required: true,
      });
    }
    if (vuln.actionOriginal) {
      fields.push({
        source: leadSentences(vuln.actionOriginal, 300),
        apply: (t) => (vuln.actionTr = tidy(t, 340) || null),
        required: false,
      });
    }
    if (fields.length > 0) jobs.push({ fields, done: () => (vuln.translated = true) });
  }

  for (const model of state.models) {
    if (model.translated) continue;
    const lead = leadSentences(model.cardExcerpt, 260);
    if (lead.length < 60) {
      // Kart okunduysa ama anlamlı bir açıklama yoksa çevrilecek bir şey yok.
      if (model.cardExcerpt) model.translated = true;
      continue;
    }
    jobs.push({
      fields: [{ source: lead, apply: (t) => (model.summaryTr = tidy(t, 300) || null), required: true }],
      done: () => {
        model.translated = true;
        model.summaryVersion = MODEL_SUMMARY_VERSION;
      },
    });
  }

  for (const repo of state.repos) {
    if (repo.translated || repo.descriptionOriginal.length === 0) continue;
    jobs.push({
      fields: [
        { source: leadSentences(repo.descriptionOriginal, 260), apply: (t) => (repo.descriptionTr = tidy(t, 300) || null), required: true },
      ],
      done: () => (repo.translated = true),
    });
  }

  return jobs;
}

export interface TranslateSummary {
  model: string | null;
  texts: number;
  translatedItems: number;
  pendingItems: number;
  note: string | null;
}

/**
 * Bekleyen kayıtları çevirir. `maxTexts`, bir çalışmada çevrilecek en fazla metin sayısıdır;
 * fazlası sonraki çalışmaya kalır (öncelik sırası: haberler, makaleler, güvenlik, modeller, projeler).
 */
export async function translatePending(
  state: State,
  translate: TranslateFn | null,
  options: { maxTexts?: number } = {},
): Promise<TranslateSummary> {
  const maxTexts = options.maxTexts ?? 600;
  const jobs = buildJobs(state);
  if (jobs.length === 0) return { model: null, texts: 0, translatedItems: 0, pendingItems: 0, note: null };
  if (!translate) {
    return { model: null, texts: 0, translatedItems: 0, pendingItems: jobs.length, note: 'Çeviri kapalı' };
  }

  // Bütçeye sığan işleri seç; aynı metin birden fazla kayıtta geçse de bir kez sayılır.
  const unique = new Map<string, number>();
  const selected: Job[] = [];
  for (const job of jobs) {
    const fresh = job.fields.filter((f) => !unique.has(f.source)).length;
    if (unique.size + fresh > maxTexts) break;
    for (const field of job.fields) if (!unique.has(field.source)) unique.set(field.source, unique.size);
    selected.push(job);
  }

  const texts = [...unique.keys()];
  let result;
  try {
    result = await translate(texts);
  } catch (error) {
    const note = `Çeviri yapılamadı: ${errorMessage(error)}`;
    log.warn(note);
    return { model: null, texts: 0, translatedItems: 0, pendingItems: jobs.length, note };
  }

  let translatedItems = 0;
  for (const job of selected) {
    const outputs = job.fields.map((f) => result.translations[unique.get(f.source)!] ?? '');
    const missingRequired = job.fields.some((f, i) => f.required && !outputs[i].trim());
    if (missingRequired) continue;
    job.fields.forEach((field, i) => {
      if (outputs[i].trim()) field.apply(outputs[i]);
    });
    job.done();
    translatedItems++;
  }

  const pendingItems = jobs.length - translatedItems;
  log.info(`Çeviri: ${texts.length} metin, ${translatedItems} kayıt (${result.seconds} sn, ${result.model}); bekleyen ${pendingItems}`);
  return {
    model: result.model,
    texts: texts.length,
    translatedItems,
    pendingItems,
    note: pendingItems > 0 ? `${pendingItems} kayıt sonraki çalışmada çevrilecek` : null,
  };
}

/** Haberlerin konusunu anahtar kelimelere göre belirler (başlık 3 puan, açıklama 1 puan). */
export function applyCategories(state: State): void {
  for (const item of state.news) {
    const source = findSource(item.sourceId);
    item.category = classify(item.titleOriginal, item.excerptOriginal, source?.defaultCategory ?? 'industry');
  }
}
