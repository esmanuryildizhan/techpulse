import { classify } from './classify.ts';
import type { TranslateFn } from './mt.ts';
import { findSource } from './sources/feeds.ts';
import type { State } from './types.ts';
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

/** Çeviri çıktısını sadeleştirir. */
export function tidy(value: string, max: number): string {
  let text = value.replace(/\s+/g, ' ').trim();
  text = text.replace(/^["'“”‘’«»]+|["'“”‘’«»]+$/g, '').trim();
  if (text.length > max) text = truncate(text, max);
  return text;
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
    if (vuln.nameOriginal) fields.push({ source: vuln.nameOriginal, apply: (t) => (vuln.nameTr = tidy(t, 160)), required: true });
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
      done: () => (model.translated = true),
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
