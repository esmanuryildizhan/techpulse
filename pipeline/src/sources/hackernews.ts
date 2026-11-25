import type { RawNews } from '../types.ts';
import { canonicalUrl, cleanText, fetchJson, stableId, toInt, toIsoDate, truncate } from '../util.ts';
import { HACKER_NEWS } from './feeds.ts';

interface AlgoliaHit {
  objectID?: string;
  title?: string | null;
  url?: string | null;
  points?: number | null;
  num_comments?: number | null;
  created_at?: string | null;
}

interface AlgoliaResponse {
  hits?: AlgoliaHit[];
}

/** Hacker News ön sayfasındaki dış bağlantılı yazıları puana göre döndürür. */
export function parseHackerNews(data: AlgoliaResponse, limit = HACKER_NEWS.maxItems): RawNews[] {
  const out: RawNews[] = [];
  const seen = new Set<string>();
  for (const hit of data.hits ?? []) {
    const title = cleanText(hit.title ?? '');
    const objectId = String(hit.objectID ?? '').trim();
    if (!title || !objectId || !hit.url) continue; // "Ask HN" gibi dış bağlantısı olmayanları atla
    const url = canonicalUrl(hit.url);
    if (!url) continue;
    const id = stableId(url);
    if (seen.has(id)) continue;
    seen.add(id);
    out.push({
      id,
      url,
      sourceId: HACKER_NEWS.id,
      title: truncate(title, 300),
      excerpt: '',
      publishedAt: toIsoDate(hit.created_at),
      points: toInt(hit.points),
      comments: toInt(hit.num_comments),
      discussionUrl: `https://news.ycombinator.com/item?id=${encodeURIComponent(objectId)}`,
    });
  }
  out.sort((a, b) => (b.points ?? 0) - (a.points ?? 0));
  return out.slice(0, limit);
}

export async function fetchHackerNews(): Promise<RawNews[]> {
  const data = await fetchJson<AlgoliaResponse>(HACKER_NEWS.url);
  return parseHackerNews(data);
}
