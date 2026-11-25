import type { Category } from './types.ts';

/**
 * Yedek konu belirleyici. Asıl konu, çeviri sırasında dil modeli tarafından seçilir;
 * çeviri yapılamadığında bu kurallar kullanılır. Başlıktaki eşleşme 3, açıklamadaki 1 puandır.
 * Kelimeler tam kelime olarak aranır: "RAM" kelimesi "program" içinde bulunmaz.
 */
const RULES: Record<Category, string[]> = {
  ai: [
    'ai', 'artificial intelligence', 'machine learning', 'deep learning', 'neural', 'llm', 'llms', 'gpt',
    'chatgpt', 'gemini', 'claude', 'llama', 'mistral', 'deepseek', 'qwen', 'openai', 'anthropic', 'deepmind',
    'hugging face', 'transformer', 'diffusion', 'model', 'models', 'agent', 'agents', 'agentic', 'copilot',
    'inference', 'training', 'fine-tuning', 'reasoning', 'multimodal', 'computer vision', 'robotics', 'chatbot',
  ],
  software: [
    'software', 'developer', 'developers', 'programming', 'code', 'coding', 'open source', 'github', 'git',
    'python', 'javascript', 'typescript', 'rust', 'go', 'java', 'kotlin', 'swift', 'flutter', 'dart', 'react',
    'linux', 'windows', 'macos', 'android', 'ios', 'api', 'sdk', 'framework', 'library', 'compiler', 'database',
    'cloud', 'kubernetes', 'docker', 'release', 'update', 'browser', 'chrome', 'firefox', 'app', 'apps',
  ],
  hardware: [
    'chip', 'chips', 'cpu', 'gpu', 'gpus', 'processor', 'semiconductor', 'tsmc', 'intel', 'amd', 'nvidia', 'arm',
    'qualcomm', 'snapdragon', 'ram', 'ssd', 'motherboard', 'laptop', 'smartphone', 'iphone', 'pixel', 'galaxy',
    'display', 'battery', 'hardware', 'raspberry pi', 'rtx', 'radeon', 'ryzen', 'core ultra', 'wafer', 'device',
  ],
  security: [
    'security', 'vulnerability', 'vulnerabilities', 'exploit', 'exploited', 'zero-day', 'cve', 'malware',
    'ransomware', 'phishing', 'breach', 'hack', 'hacked', 'hackers', 'attack', 'attacks', 'backdoor', 'botnet',
    'patch', 'spyware', 'trojan', 'ddos', 'leak', 'leaked', 'cybersecurity', 'threat', 'apt',
  ],
  industry: [
    'acquisition', 'acquires', 'funding', 'raises', 'valuation', 'ipo', 'layoffs', 'ceo', 'lawsuit', 'regulation',
    'antitrust', 'eu', 'ftc', 'policy', 'market', 'revenue', 'earnings', 'startup', 'startups', 'deal', 'tariff',
  ],
};

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

const COMPILED = Object.fromEntries(
  Object.entries(RULES).map(([category, words]) => [
    category,
    words.map((word) => new RegExp(`(?<![\\p{L}\\p{N}])${escapeRegExp(word)}(?![\\p{L}\\p{N}])`, 'iu')),
  ]),
) as Record<Category, RegExp[]>;

export function classify(title: string, excerpt: string, fallback: Category): Category {
  let best: Category = fallback;
  let bestScore = 0;
  for (const category of Object.keys(COMPILED) as Category[]) {
    let score = 0;
    for (const pattern of COMPILED[category]) {
      if (pattern.test(title)) score += 3;
      if (pattern.test(excerpt)) score += 1;
    }
    // Eşitlikte kaynağın varsayılan konusu kazanır.
    if (score > bestScore || (score === bestScore && score > 0 && category === fallback)) {
      best = category;
      bestScore = score;
    }
  }
  return bestScore >= 3 ? best : fallback;
}
