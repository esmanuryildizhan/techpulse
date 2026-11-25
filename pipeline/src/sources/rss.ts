import { XMLParser } from 'fast-xml-parser';
import type { FeedSource, RawNews } from '../types.ts';
import { asArray, canonicalUrl, cleanText, daysAgo, fetchText, stableId, str, toIsoDate, truncate } from '../util.ts';

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
  textNodeName: '#text',
  parseTagValue: false,
  parseAttributeValue: false,
  trimValues: true,
  processEntities: true,
  htmlEntities: true,
  isArray: (name) => name === 'item' || name === 'entry',
});

type Node = Record<string, unknown>;

function pickAtomLink(value: unknown): string {
  const links = asArray(value as Node | Node[] | string);
  let fallback = '';
  for (const link of links) {
    if (typeof link === 'string') {
      fallback ||= link;
      continue;
    }
    const href = str(link['@_href']);
    const rel = str(link['@_rel']);
    if (!href) continue;
    if (rel === '' || rel === 'alternate') return href;
    fallback ||= href;
  }
  return fallback;
}

function pickRssLink(item: Node): string {
  const link = item['link'];
  if (typeof link === 'string' && link) return link;
  if (Array.isArray(link) || (link && typeof link === 'object')) {
    const fromAtom = pickAtomLink(link);
    if (fromAtom) return fromAtom;
  }
  const guid = item['guid'];
  const guidText = str(guid);
  const isPermalink = guid && typeof guid === 'object' ? str((guid as Node)['@_isPermaLink']) !== 'false' : true;
  if (guidText.startsWith('http') && isPermalink) return guidText;
  return '';
}

interface Entry {
  title: string;
  link: string;
  excerpt: string;
  date: string | null;
}

function readEntries(doc: Node): Entry[] {
  const rss = doc['rss'] as Node | undefined;
  if (rss) {
    const channel = rss['channel'] as Node | undefined;
    return asArray(channel?.['item'] as Node[]).map((item) => ({
      title: cleanText(str(item['title'])),
      link: pickRssLink(item),
      excerpt: cleanText(str(item['description']) || str(item['content:encoded'])),
      date: toIsoDate(str(item['pubDate']) || str(item['dc:date']) || str(item['published'])),
    }));
  }
  const feed = doc['feed'] as Node | undefined;
  if (feed) {
    return asArray(feed['entry'] as Node[]).map((entry) => ({
      title: cleanText(str(entry['title'])),
      link: pickAtomLink(entry['link']),
      excerpt: cleanText(str(entry['summary']) || str(entry['content'])),
      date: toIsoDate(str(entry['published']) || str(entry['updated'])),
    }));
  }
  const rdf = doc['rdf:RDF'] as Node | undefined;
  if (rdf) {
    return asArray(rdf['item'] as Node[]).map((item) => ({
      title: cleanText(str(item['title'])),
      link: str(item['link']),
      excerpt: cleanText(str(item['description'])),
      date: toIsoDate(str(item['dc:date'])),
    }));
  }
  throw new Error('Tanınmayan akış biçimi (RSS, Atom veya RDF değil)');
}

export interface ParseOptions {
  now?: number;
  maxAgeDays?: number;
}

/** Bir RSS/Atom/RDF belgesini ortak haber biçimine çevirir. */
export function parseFeed(xml: string, source: FeedSource, options: ParseOptions = {}): RawNews[] {
  const { now = Date.now(), maxAgeDays = 10 } = options;
  const doc = parser.parse(xml) as Node;
  const minTime = daysAgo(maxAgeDays, now);
  const seen = new Set<string>();
  const out: RawNews[] = [];

  for (const entry of readEntries(doc)) {
    if (!entry.title || !entry.link) continue;
    const url = canonicalUrl(entry.link);
    if (!url) continue;
    if (entry.date && Date.parse(entry.date) < minTime) continue;
    const id = stableId(url);
    if (seen.has(id)) continue;
    seen.add(id);
    let excerpt = entry.excerpt;
    // Bazı akışlar açıklama alanına başlığı tekrar yazar; bu bir özet değildir.
    if (excerpt.toLowerCase() === entry.title.toLowerCase()) excerpt = '';
    out.push({
      id,
      url,
      sourceId: source.id,
      title: truncate(entry.title, 300),
      excerpt: truncate(excerpt, 700),
      publishedAt: entry.date,
    });
  }

  out.sort((a, b) => Date.parse(b.publishedAt ?? '0') - Date.parse(a.publishedAt ?? '0'));
  return out.slice(0, source.maxItems);
}

export async function fetchFeed(source: FeedSource, options: ParseOptions = {}): Promise<RawNews[]> {
  const xml = await fetchText(source.url, {
    headers: { Accept: 'application/rss+xml, application/atom+xml, application/xml, text/xml;q=0.9, */*;q=0.8' },
  });
  return parseFeed(xml, source, options);
}
