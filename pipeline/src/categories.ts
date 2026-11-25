import type { Category } from './types.ts';

/**
 * TechPulse konu sınıflandırması. Kimlikler (id) mobil uygulamadaki karşılıklarıyla aynıdır;
 * Türkçe adlar ve açıklamalar hem yapay zekâ yazarına verilen talimatta hem de anahtar kelime
 * yedeğinde kullanılır.
 */
export interface CategoryInfo {
  id: Category;
  label: string;
  /** Yapay zekâ yazarına bu konunun neyi kapsadığını anlatan kısa tanım. */
  scope: string;
  /** Yapay zekâ kullanılamadığında başvurulan anahtar kelimeler (büyük/küçük harf duyarsız, tam kelime). */
  keywords: string[];
}

export const CATEGORY_INFO: readonly CategoryInfo[] = [
  {
    id: 'ai',
    label: 'Yapay Zekâ',
    scope: 'Yapay zekâ modelleri, büyük dil modelleri, üretken yapay zekâ ürünleri, yapay zekâ şirketleri ve araştırmaları, YZ ajanları.',
    keywords: [
      'AI', 'A.I.', 'artificial intelligence', 'machine learning', 'deep learning', 'LLM', 'LLMs', 'large language model',
      'language model', 'GPT', 'ChatGPT', 'OpenAI', 'Gemini', 'Claude', 'Anthropic', 'Llama', 'Mistral', 'DeepSeek', 'Qwen',
      'transformer', 'diffusion', 'neural network', 'generative', 'chatbot', 'agent', 'agents', 'agentic', 'inference',
      'fine-tuning', 'fine-tune', 'RAG', 'embedding', 'embeddings', 'multimodal', 'reasoning model', 'Copilot', 'Hugging Face',
      'computer vision', 'speech recognition', 'text-to-speech', 'reinforcement learning', 'AGI', 'prompt', 'tokens',
    ],
  },
  {
    id: 'security',
    label: 'Siber Güvenlik',
    scope: 'Güvenlik açıkları, siber saldırılar, veri ihlalleri, fidye yazılımları, kötü amaçlı yazılımlar, kimlik avı, gizlilik ve güvenlik güncellemeleri.',
    keywords: [
      'security', 'vulnerability', 'vulnerabilities', 'exploit', 'exploited', 'zero-day', '0-day', 'CVE', 'malware',
      'ransomware', 'phishing', 'breach', 'data breach', 'hacker', 'hackers', 'hacked', 'attack', 'attacks', 'attackers',
      'botnet', 'backdoor', 'spyware', 'trojan', 'patch', 'patched', 'RCE', 'remote code execution', 'privilege escalation',
      'authentication', 'cyber', 'cyberattack', 'cybersecurity', 'infostealer', 'DDoS', 'APT', 'threat actor', 'threat actors',
      'encryption', 'leak', 'leaked', 'credential', 'credentials', 'password', 'passwords', 'supply chain attack',
    ],
  },
  {
    id: 'dev',
    label: 'Yazılım Geliştirme',
    scope: 'Programlama dilleri, geliştirici araçları, açık kaynak projeler, çatılar ve kütüphaneler, IDE ve kod editörleri, yazılım mühendisliği uygulamaları, işletim sistemi ve tarayıcı yazılımları.',
    keywords: [
      'developer', 'developers', 'programming', 'programmer', 'code', 'coding', 'software', 'open source', 'open-source',
      'GitHub', 'GitLab', 'Git', 'API', 'SDK', 'framework', 'library', 'compiler', 'Python', 'JavaScript', 'TypeScript',
      'Rust', 'Golang', 'Java', 'Kotlin', 'Swift', 'C++', 'C#', '.NET', 'Node.js', 'React', 'Vue', 'Linux', 'Windows',
      'macOS', 'kernel', 'browser', 'Chrome', 'Firefox', 'WebAssembly', 'Visual Studio', 'VS Code', 'IDE', 'database',
      'PostgreSQL', 'SQLite', 'release', 'version', 'bug', 'debugging', 'testing', 'refactoring',
    ],
  },
  {
    id: 'data',
    label: 'Veri Bilimi',
    scope: 'Veri analizi, veri mühendisliği, istatistik, veri tabanları ve veri ambarları, analitik araçları, veri görselleştirme, klasik makine öğrenmesi uygulamaları.',
    keywords: [
      'data science', 'data scientist', 'data scientists', 'analytics', 'data engineering', 'data pipeline', 'ETL',
      'data warehouse', 'lakehouse', 'Spark', 'pandas', 'NumPy', 'Jupyter', 'notebook', 'statistics', 'statistical',
      'dataset', 'datasets', 'visualization', 'dashboard', 'BigQuery', 'Snowflake', 'Databricks', 'SQL', 'regression',
      'classification', 'clustering', 'time series', 'feature engineering', 'scikit-learn', 'Kaggle',
    ],
  },
  {
    id: 'hardware',
    label: 'Donanım ve Çip Teknolojileri',
    scope: 'İşlemciler, ekran kartları, yapay zekâ çipleri, yarı iletken üretimi, bilgisayarlar, akıllı cihazlar, bellek ve depolama donanımı.',
    keywords: [
      'chip', 'chips', 'chipmaker', 'semiconductor', 'semiconductors', 'CPU', 'GPU', 'GPUs', 'NPU', 'TPU', 'processor',
      'processors', 'Nvidia', 'AMD', 'Intel', 'Qualcomm', 'TSMC', 'RISC-V', 'Snapdragon', 'Ryzen', 'Xeon', 'GeForce',
      'Radeon', 'RTX', 'silicon', 'wafer', 'foundry', 'motherboard', 'RAM', 'DDR5', 'SSD', 'NAND', 'HBM', 'laptop', 'PC',
      'hardware', 'monitor', 'display', 'headset', 'wearable', 'smartwatch', 'quantum computer', 'quantum chip',
    ],
  },
  {
    id: 'cloud',
    label: 'Bulut ve DevOps',
    scope: 'Bulut bilişim (AWS, Azure, Google Cloud), sunucular ve veri merkezleri, konteynerler ve Kubernetes, DevOps, CI/CD, altyapı, ağ ve kesintiler.',
    keywords: [
      'cloud', 'AWS', 'Amazon Web Services', 'Azure', 'Google Cloud', 'GCP', 'Kubernetes', 'K8s', 'Docker', 'container',
      'containers', 'serverless', 'DevOps', 'CI/CD', 'Terraform', 'infrastructure', 'data center', 'data centers',
      'datacenter', 'datacenters', 'server', 'servers', 'outage', 'Cloudflare', 'CDN', 'microservices', 'observability',
      'SRE', 'deployment', 'virtual machine', 'VM', 'hyperscaler', 'edge computing',
    ],
  },
  {
    id: 'mobile',
    label: 'Mobil Teknolojiler',
    scope: 'Android, iOS, akıllı telefonlar, mobil uygulamalar ve uygulama mağazaları, mobil geliştirme (Flutter, Kotlin, SwiftUI), tabletler.',
    keywords: [
      'Android', 'iOS', 'iPadOS', 'iPhone', 'iPad', 'smartphone', 'smartphones', 'phone', 'phones', 'Pixel', 'Galaxy',
      'Samsung', 'mobile', 'app', 'apps', 'App Store', 'Play Store', 'Google Play', 'Flutter', 'SwiftUI', 'Jetpack Compose',
      'tablet', 'tablets', 'foldable', '5G', 'WhatsApp', 'Telegram',
    ],
  },
  {
    id: 'science',
    label: 'Uzay ve Bilim',
    scope: 'Uzay araştırmaları, roketler ve uydular, fizik, biyoloji, iklim ve enerji bilimi, bilimsel keşifler ve araştırmalar.',
    keywords: [
      'NASA', 'SpaceX', 'space', 'spacecraft', 'rocket', 'rockets', 'satellite', 'satellites', 'orbit', 'Mars', 'Moon',
      'lunar', 'astronaut', 'astronauts', 'telescope', 'galaxy', 'planet', 'asteroid', 'physics', 'physicist', 'quantum',
      'biology', 'scientists', 'scientific', 'research', 'study', 'climate', 'fusion', 'energy', 'battery', 'batteries',
      'solar', 'nuclear', 'gene', 'genome', 'CRISPR', 'medicine', 'neuroscience', 'Starlink', 'Starship', 'ESA',
    ],
  },
  {
    id: 'industry',
    label: 'Teknoloji Dünyası',
    scope: 'Teknoloji şirketlerinin iş ve finans haberleri, satın almalar, yatırımlar, girişimler, yönetici değişiklikleri, düzenlemeler, davalar, teknoloji politikası ve genel tüketici teknolojisi.',
    keywords: [
      'startup', 'startups', 'funding', 'raises', 'raised', 'valuation', 'IPO', 'acquisition', 'acquires', 'acquired',
      'merger', 'layoffs', 'CEO', 'revenue', 'earnings', 'profit', 'investors', 'investment', 'venture', 'regulation',
      'regulators', 'antitrust', 'lawsuit', 'court', 'FTC', 'European Commission', 'EU', 'DMA', 'tariff', 'tariffs',
      'ban', 'policy', 'government', 'Congress', 'Senate', 'Apple', 'Google', 'Microsoft', 'Amazon', 'Meta', 'Tesla',
      'Netflix', 'Spotify', 'subscription', 'streaming',
    ],
  },
];

export const CATEGORY_IDS: readonly Category[] = CATEGORY_INFO.map((c) => c.id);

export function categoryLabel(id: Category): string {
  return CATEGORY_INFO.find((c) => c.id === id)?.label ?? id;
}

/** Önceki sürümün konu kimliklerini yenilerine çevirir (eski yayından okunan kayıtlar için). */
export function migrateCategory(value: unknown): Category | null {
  if (typeof value !== 'string') return null;
  if ((CATEGORY_IDS as readonly string[]).includes(value)) return value as Category;
  if (value === 'software') return 'dev';
  return null;
}
