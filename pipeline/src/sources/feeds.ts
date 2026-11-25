import type { FeedSource } from '../types.ts';

/**
 * Haber kaynakları. Hepsi kendi sitelerinde RSS/Atom akışı yayımlıyor. TechPulse her haberi
 * kaynağına bağlantı vererek, kendi cümleleriyle yazılmış Türkçe bir anlatımla sunar; haberin
 * tamamı kaynağın sitesinde okunur. Akışların erişilebilirliği "Kaynak denetimi" iş akışıyla
 * (tools/probe_sources.mjs) denetlenir.
 *
 * `defaultCategory`, yapay zekâ editörü çalışmadığında kullanılan varsayılan konudur.
 * `maxItems`, bir çalışmada bu kaynaktan alınacak en yeni haber sayısıdır (yoğun akışlarda düşük tutulur).
 */
export const FEEDS: FeedSource[] = [
  // Yapay zekâ şirketleri ve araştırma laboratuvarları
  { id: 'openai', name: 'OpenAI', kind: 'official', url: 'https://openai.com/news/rss.xml', homepage: 'https://openai.com/news', defaultCategory: 'ai', maxItems: 5 },
  { id: 'google-ai', name: 'Google AI', kind: 'official', url: 'https://blog.google/technology/ai/rss/', homepage: 'https://blog.google/technology/ai/', defaultCategory: 'ai', maxItems: 5 },
  { id: 'deepmind', name: 'Google DeepMind', kind: 'official', url: 'https://deepmind.google/blog/rss.xml', homepage: 'https://deepmind.google/discover/blog/', defaultCategory: 'ai', maxItems: 5 },
  { id: 'google-research', name: 'Google Research', kind: 'official', url: 'https://research.google/blog/rss/', homepage: 'https://research.google/blog/', defaultCategory: 'ai', maxItems: 3 },
  { id: 'microsoft-research', name: 'Microsoft Research', kind: 'official', url: 'https://www.microsoft.com/en-us/research/feed/', homepage: 'https://www.microsoft.com/en-us/research/blog/', defaultCategory: 'ai', maxItems: 4 },
  { id: 'huggingface-blog', name: 'Hugging Face Blog', kind: 'official', url: 'https://huggingface.co/blog/feed.xml', homepage: 'https://huggingface.co/blog', defaultCategory: 'ai', maxItems: 5 },
  { id: 'nvidia-developer', name: 'NVIDIA Developer', kind: 'official', url: 'https://developer.nvidia.com/blog/feed', homepage: 'https://developer.nvidia.com/blog/', defaultCategory: 'ai', maxItems: 4 },
  { id: 'apple-ml', name: 'Apple Machine Learning', kind: 'official', url: 'https://machinelearning.apple.com/rss.xml', homepage: 'https://machinelearning.apple.com/', defaultCategory: 'ai', maxItems: 3 },
  { id: 'aws-ml', name: 'AWS Machine Learning', kind: 'official', url: 'https://aws.amazon.com/blogs/machine-learning/feed/', homepage: 'https://aws.amazon.com/blogs/machine-learning/', defaultCategory: 'ai', maxItems: 3 },

  // Yazılım geliştirme
  { id: 'github-blog', name: 'GitHub Blog', kind: 'official', url: 'https://github.blog/feed/', homepage: 'https://github.blog/', defaultCategory: 'dev', maxItems: 5 },
  { id: 'meta-engineering', name: 'Engineering at Meta', kind: 'official', url: 'https://engineering.fb.com/feed/', homepage: 'https://engineering.fb.com/', defaultCategory: 'dev', maxItems: 3 },
  { id: 'stackoverflow-blog', name: 'Stack Overflow Blog', kind: 'official', url: 'https://stackoverflow.blog/feed/', homepage: 'https://stackoverflow.blog/', defaultCategory: 'dev', maxItems: 3 },
  { id: 'jetbrains', name: 'JetBrains Blog', kind: 'official', url: 'https://blog.jetbrains.com/feed/', homepage: 'https://blog.jetbrains.com/', defaultCategory: 'dev', maxItems: 3 },
  { id: 'infoq', name: 'InfoQ', kind: 'news', url: 'https://feed.infoq.com/', homepage: 'https://www.infoq.com/', defaultCategory: 'dev', maxItems: 4 },

  // Mobil
  { id: 'android-developers', name: 'Android Developers', kind: 'official', url: 'https://android-developers.googleblog.com/feeds/posts/default', homepage: 'https://android-developers.googleblog.com/', defaultCategory: 'mobile', maxItems: 4 },
  { id: 'flutter', name: 'Flutter Blog', kind: 'official', url: 'https://medium.com/feed/flutter', homepage: 'https://blog.flutter.dev/', defaultCategory: 'mobile', maxItems: 3 },
  { id: 'apple-developer', name: 'Apple Developer', kind: 'official', url: 'https://developer.apple.com/news/rss/news.rss', homepage: 'https://developer.apple.com/news/', defaultCategory: 'mobile', maxItems: 3 },
  { id: '9to5google', name: '9to5Google', kind: 'news', url: 'https://9to5google.com/feed/', homepage: 'https://9to5google.com/', defaultCategory: 'mobile', maxItems: 3 },

  // Bulut ve DevOps
  { id: 'aws-news', name: 'AWS News Blog', kind: 'official', url: 'https://aws.amazon.com/blogs/aws/feed/', homepage: 'https://aws.amazon.com/blogs/aws/', defaultCategory: 'cloud', maxItems: 3 },
  { id: 'google-cloud', name: 'Google Cloud Blog', kind: 'official', url: 'https://cloudblog.withgoogle.com/rss/', homepage: 'https://cloud.google.com/blog', defaultCategory: 'cloud', maxItems: 3 },
  { id: 'kubernetes', name: 'Kubernetes Blog', kind: 'official', url: 'https://kubernetes.io/feed.xml', homepage: 'https://kubernetes.io/blog/', defaultCategory: 'cloud', maxItems: 3 },
  { id: 'cloudflare', name: 'Cloudflare Blog', kind: 'official', url: 'https://blog.cloudflare.com/rss/', homepage: 'https://blog.cloudflare.com/', defaultCategory: 'cloud', maxItems: 3 },

  // Veri bilimi
  { id: 'kdnuggets', name: 'KDnuggets', kind: 'news', url: 'https://www.kdnuggets.com/feed', homepage: 'https://www.kdnuggets.com/', defaultCategory: 'data', maxItems: 3 },
  { id: 'databricks', name: 'Databricks Blog', kind: 'official', url: 'https://www.databricks.com/feed', homepage: 'https://www.databricks.com/blog', defaultCategory: 'data', maxItems: 3 },

  // Uzay ve bilim
  { id: 'nasa', name: 'NASA', kind: 'official', url: 'https://www.nasa.gov/news-release/feed/', homepage: 'https://www.nasa.gov/news/', defaultCategory: 'science', maxItems: 3 },
  { id: 'quanta', name: 'Quanta Magazine', kind: 'news', url: 'https://www.quantamagazine.org/feed/', homepage: 'https://www.quantamagazine.org/', defaultCategory: 'science', maxItems: 3 },
  { id: 'new-scientist', name: 'New Scientist', kind: 'news', url: 'https://www.newscientist.com/subject/technology/feed/', homepage: 'https://www.newscientist.com/subject/technology/', defaultCategory: 'science', maxItems: 3 },

  // Teknoloji haber siteleri
  { id: 'the-verge', name: 'The Verge', kind: 'news', url: 'https://www.theverge.com/rss/index.xml', homepage: 'https://www.theverge.com/', defaultCategory: 'industry', maxItems: 6 },
  { id: 'techcrunch', name: 'TechCrunch', kind: 'news', url: 'https://techcrunch.com/feed/', homepage: 'https://techcrunch.com/', defaultCategory: 'industry', maxItems: 6 },
  { id: 'ars-technica', name: 'Ars Technica', kind: 'news', url: 'https://feeds.arstechnica.com/arstechnica/index', homepage: 'https://arstechnica.com/', defaultCategory: 'industry', maxItems: 6 },
  { id: 'mit-tech-review', name: 'MIT Technology Review', kind: 'news', url: 'https://www.technologyreview.com/topic/artificial-intelligence/feed', homepage: 'https://www.technologyreview.com/', defaultCategory: 'ai', maxItems: 4 },
  { id: 'toms-hardware', name: "Tom's Hardware", kind: 'news', url: 'https://www.tomshardware.com/feeds/all', homepage: 'https://www.tomshardware.com/', defaultCategory: 'hardware', maxItems: 5 },

  // Siber güvenlik
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
  defaultCategory: 'dev',
  maxItems: 15,
};

export function findSource(id: string): FeedSource | undefined {
  if (id === HACKER_NEWS.id) return HACKER_NEWS;
  return FEEDS.find((source) => source.id === id);
}
