import { findSource } from './sources/feeds.ts';
import type { AiModel, NewsItem, Paper, RawNews, Repo, Vulnerability } from './types.ts';
import { MODEL_SUMMARY_VERSION } from './types.ts';
import { daysAgo, truncate } from './util.ts';

export const NEWS_RETENTION_DAYS = 30;
export const NEWS_CAP = 400;
export const PAPER_RETENTION_DAYS = 21;
export const PAPER_CAP = 150;

/**
 * Yeni okunan haberleri önceki yayındaki kayıtlarla birleştirir. Daha önce çevrilmiş bir haber
 * yeniden çevrilmez (kota tasarrufu); yalnızca puan ve yorum sayısı güncellenir.
 */
export function mergeNews(previous: NewsItem[], fresh: RawNews[], now: Date): NewsItem[] {
  const nowIso = now.toISOString();
  const byId = new Map<string, NewsItem>();
  for (const item of previous) byId.set(item.id, { ...item, tags: [...item.tags] });

  for (const raw of fresh) {
    const existing = byId.get(raw.id);
    if (existing) {
      if (raw.points !== undefined) existing.points = raw.points;
      if (raw.comments !== undefined) existing.comments = raw.comments;
      if (existing.titleOriginal !== raw.title) {
        existing.titleOriginal = raw.title;
        existing.excerptOriginal = truncate(raw.excerpt, 600);
        existing.translated = false;
      }
      continue;
    }
    const source = findSource(raw.sourceId);
    if (!source) continue;
    byId.set(raw.id, {
      id: raw.id,
      url: raw.url,
      sourceId: source.id,
      sourceName: source.name,
      sourceKind: source.kind,
      publishedAt: raw.publishedAt ?? nowIso,
      firstSeenAt: nowIso,
      titleOriginal: raw.title,
      excerptOriginal: truncate(raw.excerpt, 600),
      titleTr: null,
      summaryTr: null,
      category: source.defaultCategory,
      tags: [],
      translated: false,
      points: raw.points ?? null,
      comments: raw.comments ?? null,
      discussionUrl: raw.discussionUrl ?? null,
    });
  }

  const minTime = daysAgo(NEWS_RETENTION_DAYS, now.getTime());
  return [...byId.values()]
    .filter((item) => Date.parse(item.publishedAt) >= minTime)
    .sort((a, b) => Date.parse(b.publishedAt) - Date.parse(a.publishedAt) || a.id.localeCompare(b.id))
    .slice(0, NEWS_CAP);
}

/** Trend sıralaması her çalışmada yenilenir; özet ve model kartı bilgileri korunur. */
export function mergeModels(previous: AiModel[], fresh: AiModel[]): AiModel[] {
  const old = new Map(previous.map((m) => [m.id, m]));
  return fresh.map((model, index) => {
    const before = old.get(model.id);
    const merged: AiModel = { ...model, rank: index + 1 };
    if (before && (before.summaryVersion ?? 0) === MODEL_SUMMARY_VERSION) {
      merged.summaryTr = before.summaryTr;
      merged.summaryVersion = before.summaryVersion;
      merged.translated = before.translated;
      merged.cardExcerpt = before.cardExcerpt;
      merged.parameters = before.parameters ?? model.parameters;
      merged.license = model.license ?? before.license;
    }
    return merged;
  });
}

export function mergePapers(previous: Paper[], fresh: Paper[], now: Date): Paper[] {
  const byId = new Map<string, Paper>();
  for (const paper of previous) byId.set(paper.id, { ...paper });
  for (const paper of fresh) {
    const existing = byId.get(paper.id);
    if (existing) {
      existing.upvotes = paper.upvotes;
      existing.comments = paper.comments;
      existing.githubUrl = paper.githubUrl ?? existing.githubUrl;
    } else {
      byId.set(paper.id, paper);
    }
  }
  const minTime = daysAgo(PAPER_RETENTION_DAYS, now.getTime());
  return [...byId.values()]
    .filter((p) => Date.parse(p.publishedAt) >= minTime)
    .sort((a, b) => b.publishedAt.slice(0, 10).localeCompare(a.publishedAt.slice(0, 10)) || b.upvotes - a.upvotes)
    .slice(0, PAPER_CAP);
}

export function mergeRepos(previous: Repo[], fresh: Repo[]): Repo[] {
  const old = new Map(previous.map((r) => [r.id, r]));
  return fresh.map((repo) => {
    const before = old.get(repo.id);
    if (before && before.descriptionOriginal === repo.descriptionOriginal) {
      return { ...repo, descriptionTr: before.descriptionTr, translated: before.translated };
    }
    return repo;
  });
}

export function mergeKev(previous: Vulnerability[], fresh: Vulnerability[]): Vulnerability[] {
  const old = new Map(previous.map((v) => [v.id, v]));
  return fresh.map((vuln) => {
    const before = old.get(vuln.id);
    if (before && before.translated && before.descriptionOriginal === vuln.descriptionOriginal) {
      return { ...vuln, nameTr: before.nameTr, descriptionTr: before.descriptionTr, actionTr: before.actionTr, translated: true };
    }
    return vuln;
  });
}
