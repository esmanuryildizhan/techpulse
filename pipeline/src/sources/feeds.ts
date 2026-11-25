import type { FeedSource } from '../types.ts';

/**
 * Haber kaynakları. Hepsi kendi sitelerinde RSS/Atom akışı yayımlıyor; akışlar başka
 * uygulamaların başlık, kısa açıklama ve bağlantıyı göstermesi için hazırlanır.
 * Biz yalnızca başlık + kaynağın kısa açıklamasından Türkçe özet + bağlantı gösteriyoruz.
 */
export const FEEDS: FeedSource[] = [
  // Resmî şirket ve araştırma blogları
  { id: 'openai', name: 'OpenAI', kind: 'official', url: 'https://openai.com/news/rss.xml', homepage: 'https://openai.com/news', defaultCategory: 'ai', maxItems: 5 },
  { id: 'google-ai', name: 'Google AI', kind: 'official', url: 'https://blog.google/technology/ai/rss/', homepage: 'https://blog.google/technology/ai/', defaultCategory: 'ai', maxItems: 5 },
  { id: 'deepmind', name: 'Google DeepMind', kind: 'official', url: 'https://deepmind.google/blog/rss.xml', homepage: 'https://deepmind.google/discover/blog/', defaultCategory: 'ai', maxItems: 5 },
  { id: 'microsoft-research', name: 'Microsoft Research', kind: 'official', url: 'https://www.microsoft.com/en-us/research/feed/', homepage: 'https://www.microsoft.com/en-us/research/blog/', defaultCategory: 'ai', maxItems: 5 },
  { id: 'huggingface-blog', name: 'Hugging Face Blog', kind: 'official', url: 'https://huggingface.co/blog/feed.xml', homepage: 'https://huggingface.co/blog', defaultCategory: 'ai', maxItems: 5 },
  { id: 'nvidia-developer', name: 'NVIDIA Developer', kind: 'official', url: 'https://developer.nvidia.com/blog/feed', homepage: 'https://developer.nvidia.com/blog/', defaultCategory: 'ai', maxItems: 5 },
  { id: 'apple-ml', name: 'Apple Machine Learning', kind: 'official', url: 'https://machinelearning.apple.com/rss.xml', homepage: 'https://machinelearning.apple.com/', defaultCategory: 'ai', maxItems: 4 },
  { id: 'aws-ml', name: 'AWS Machine Learning', kind: 'official', url: 'https://aws.amazon.com/blogs/machine-learning/feed/', homepage: 'https://aws.amazon.com/blogs/machine-learning/', defaultCategory: 'ai', maxItems: 4 },
  { id: 'github-blog', name: 'GitHub Blog', kind: 'official', url: 'https://github.blog/feed/', homepage: 'https://github.blog/', defaultCategory: 'software', maxItems: 5 },
  { id: 'android-developers', name: 'Android Developers', kind: 'official', url: 'https://android-developers.googleblog.com/feeds/posts/default', homepage: 'https://android-developers.googleblog.com/', defaultCategory: 'software', maxItems: 4 },
  { id: 'flutter', name: 'Flutter Blog', kind: 'official', url: 'https://medium.com/feed/flutter', homepage: 'https://blog.flutter.dev/', defaultCategory: 'software', maxItems: 4 },
  { id: 'meta-engineering', name: 'Engineering at Meta', kind: 'official', url: 'https://engineering.fb.com/feed/', homepage: 'https://engineering.fb.com/', defaultCategory: 'software', maxItems: 4 },

  // Teknoloji haber siteleri
  { id: 'the-verge', name: 'The Verge', kind: 'news', url: 'https://www.theverge.com/rss/index.xml', homepage: 'https://www.theverge.com/', defaultCategory: 'industry', maxItems: 6 },
  { id: 'techcrunch', name: 'TechCrunch', kind: 'news', url: 'https://techcrunch.com/feed/', homepage: 'https://techcrunch.com/', defaultCategory: 'industry', maxItems: 6 },
  { id: 'ars-technica', name: 'Ars Technica', kind: 'news', url: 'https://feeds.arstechnica.com/arstechnica/index', homepage: 'https://arstechnica.com/', defaultCategory: 'industry', maxItems: 6 },
  { id: 'mit-tech-review', name: 'MIT Technology Review', kind: 'news', url: 'https://www.technologyreview.com/topic/artificial-intelligence/feed', homepage: 'https://www.technologyreview.com/', defaultCategory: 'ai', maxItems: 4 },
  { id: 'toms-hardware', name: "Tom's Hardware", kind: 'news', url: 'https://www.tomshardware.com/feeds/all', homepage: 'https://www.tomshardware.com/', defaultCategory: 'hardware', maxItems: 6 },
  { id: 'bleepingcomputer', name: 'BleepingComputer', kind: 'news', url: 'https://www.bleepingcomputer.com/feed/', homepage: 'https://www.bleepingcomputer.com/', defaultCategory: 'security', maxItems: 6 },
  { id: 'the-hacker-news', name: 'The Hacker News', kind: 'news', url: 'https://feeds.feedburner.com/TheHackersNews', homepage: 'https://thehackernews.com/', defaultCategory: 'security', maxItems: 5 },

  // Topluluk
  { id: 'simon-willison', name: 'Simon Willison', kind: 'community', url: 'https://simonwillison.net/atom/everything/', homepage: 'https://simonwillison.net/', defaultCategory: 'ai', maxItems: 4 },
];

/** Hacker News da bir kaynak; RSS değil, Algolia arama API'si üzerinden okunur. */
export const HACKER_NEWS: Omit<FeedSource, 'url'> & { url: string } = {
  id: 'hacker-news',
  name: 'Hacker News',
  kind: 'community',
  url: 'https://hn.algolia.com/api/v1/search?tags=front_page&hitsPerPage=40',
  homepage: 'https://news.ycombinator.com/',
  defaultCategory: 'software',
  maxItems: 15,
};

export function findSource(id: string): FeedSource | undefined {
  if (id === HACKER_NEWS.id) return HACKER_NEWS;
  return FEEDS.find((source) => source.id === id);
}
