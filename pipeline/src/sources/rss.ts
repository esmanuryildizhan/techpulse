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
  image: string | null;
  content: string;
}

/** Görsel adresini doğrular: yalnızca https (http olanlar https'e yükseltilir), izleme pikselleri atlanır. */
export function normalizeImageUrl(raw: unknown, base?: string): string | null {
  const value = str(raw).trim();
  if (!value || value.startsWith('data:')) return null;
  let url: URL;
  try {
    url = base ? new URL(value, base) : new URL(value);
  } catch {
    return null;
  }
  if (url.protocol === 'http:') url.protocol = 'https:';
  if (url.protocol !== 'https:') return null;
  const href = url.toString();
  if (/(feedburner|feedsportal|doubleclick|pixel|tracking|gravatar\.com|s\.w\.org\/images\/core\/emoji|\/emoji\/|spacer\.gif|1x1)/i.test(href)) return null;
  if (/\.(svg|ico)(\?|$)/i.test(url.pathname)) return null;
  return href;
}

function attr(node: unknown, name: string): string {
  return node && typeof node === 'object' ? str((node as Node)[`@_${name}`]) : '';
}

/** RSS/Atom ögesindeki görseli bulur: media:content, media:thumbnail, enclosure veya içerikteki ilk <img>. */
function pickImage(item: Node, html: string, base: string): string | null {
  const candidates: unknown[] = [];
  const group = item['media:group'] as Node | undefined;
  for (const media of [...asArray(item['media:content'] as Node[]), ...asArray(group?.['media:content'] as Node[])]) {
    const type = attr(media, 'type');
    const medium = attr(media, 'medium');
    if (medium === 'image' || type.startsWith('image/') || (!medium && !type)) candidates.push(attr(media, 'url'));
  }
  for (const thumb of [...asArray(item['media:thumbnail'] as Node[]), ...asArray(group?.['media:thumbnail'] as Node[])]) {
    candidates.push(attr(thumb, 'url'));
  }
  for (const enclosure of asArray(item['enclosure'] as Node[])) {
    if (attr(enclosure, 'type').startsWith('image/')) candidates.push(attr(enclosure, 'url'));
  }
  for (const link of asArray(item['link'] as Node[])) {
    if (attr(link, 'rel') === 'enclosure' && attr(link, 'type').startsWith('image/')) candidates.push(attr(link, 'href'));
  }
  for (const match of html.matchAll(/<img\b[^>]*?\ssrc=["']([^"']+)["'][^>]*>/gi)) {
    if (/\b(width|height)=["']?1["'\s>]/i.test(match[0])) continue;
    candidates.push(match[1].replace(/&amp;/g, '&'));
  }
  for (const candidate of candidates) {
    const url = normalizeImageUrl(candidate, base);
    if (url) return url;
  }
  return null;
}

function readEntries(doc: Node): Entry[] {
  const rss = doc['rss'] as Node | undefined;
  if (rss) {
    const channel = rss['channel'] as Node | undefined;
    return asArray(channel?.['item'] as Node[]).map((item) => {
      const link = pickRssLink(item);
      const description = str(item['description']);
      const encoded = str(item['content:encoded']);
      return {
        title: cleanText(str(item['title'])),
        link,
        excerpt: cleanText(description || encoded),
        date: toIsoDate(str(item['pubDate']) || str(item['dc:date']) || str(item['published'])),
        image: pickImage(item, `${encoded} ${description}`, link),
        content: cleanText(encoded || description),
      };
    });
  }
  const feed = doc['feed'] as Node | undefined;
  if (feed) {
    return asArray(feed['entry'] as Node[]).map((entry) => {
      const link = pickAtomLink(entry['link']);
      const summary = str(entry['summary']);
      const content = str(entry['content']);
      return {
        title: cleanText(str(entry['title'])),
        link,
        excerpt: cleanText(summary || content),
        date: toIsoDate(str(entry['published']) || str(entry['updated'])),
        image: pickImage(entry, `${content} ${summary}`, link),
        content: cleanText(content || summary),
      };
    });
  }
  const rdf = doc['rdf:RDF'] as Node | undefined;
  if (rdf) {
    return asArray(rdf['item'] as Node[]).map((item) => ({
      title: cleanText(str(item['title'])),
      link: str(item['link']),
      excerpt: cleanText(str(item['description'])),
      date: toIsoDate(str(item['dc:date'])),
      image: null,
      content: cleanText(str(item['description'])),
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
      imageUrl: entry.image,
      content: entry.content.length > excerpt.length + 200 ? truncate(entry.content, 9000) : '',
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
