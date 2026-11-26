import type { Repo } from '../types.ts';
import { asArray, cleanText, fetchJson, toInt, toIsoDate, truncate } from '../util.ts';

const AI_WORDS =
  /\b(ai|llm|llms|gpt|agent|agents|agentic|rag|diffusion|transformer|transformers|machine[- ]learning|deep[- ]learning|neural|inference|embedding|embeddings|vision|multimodal|mcp|fine[- ]?tun\w*|lora|pytorch|tensorflow|onnx|ollama|vllm|cuda|speech|tts|asr|ocr)\b/i;

interface GhSearchItem {
  full_name?: string;
  name?: string;
  html_url?: string;
  description?: string | null;
  language?: string | null;
  stargazers_count?: number;
  forks_count?: number;
  created_at?: string;
  topics?: string[];
  owner?: { login?: string };
  fork?: boolean;
  archived?: boolean;
}

export function parseRepos(data: { items?: GhSearchItem[] }, limit = 30): Repo[] {
  const out: Repo[] = [];
  for (const item of data.items ?? []) {
    const fullName = String(item.full_name ?? '').trim();
    const url = String(item.html_url ?? '');
    if (!fullName || !url.startsWith('https://github.com/') || item.fork || item.archived) continue;
    const description = truncate(cleanText(item.description ?? ''), 400);
    const topics = asArray(item.topics).map(String).slice(0, 8);
    out.push({
      id: fullName,
      owner: item.owner?.login ?? fullName.split('/')[0],
      name: item.name ?? fullName.split('/')[1] ?? fullName,
      url,
      descriptionOriginal: description,
      descriptionTr: null,
      language: item.language ?? null,
      stars: toInt(item.stargazers_count),
      forks: toInt(item.forks_count),
      createdAt: toIsoDate(item.created_at) ?? new Date().toISOString(),
      topics,
      isAi: AI_WORDS.test(`${fullName} ${description} ${topics.join(' ')}`),
      translated: false,
      // GitHub'ın her depo için ürettiği paylaşım görseli (proje adı, açıklama, yıldız sayısı).
      imageUrl: `https://opengraph.githubassets.com/1/${fullName.split('/').map(encodeURIComponent).join('/')}`,
      writer: null,
      writerVersion: 0,
      story: null,
    });
    if (out.length >= limit) break;
  }
  return out;
}

/** Son 7 günde açılmış ve en çok yıldız almış GitHub projeleri. */
export async function fetchTrendingRepos(token: string | undefined, now = Date.now()): Promise<Repo[]> {
  const since = new Date(now - 7 * 86_400_000).toISOString().slice(0, 10);
  const query = encodeURIComponent(`created:>=${since} stars:>=20 fork:false archived:false`);
  const headers: Record<string, string> = {
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  const data = await fetchJson<{ items?: GhSearchItem[] }>(
    `https://api.github.com/search/repositories?q=${query}&sort=stars&order=desc&per_page=40`,
    { headers },
  );
  return parseRepos(data);
}

export const README_LIMIT = 8000;

/**
 * README'yi editöre verilecek sade metne çevirir: rozetler, görseller, HTML etiketleri, kod blokları ve
 * bağlantı adresleri atılır; başlıklar ve paragraflar kalır.
 */
export function cleanReadme(markdown: string): string {
  let text = markdown.replace(/\r/g, '');
  text = text.replace(/<!--[\s\S]*?-->/g, ' ');
  text = text.replace(/```[\s\S]*?```/g, ' [kod örneği] ');
  text = text.replace(/!\[[^\]]*\]\([^)]*\)/g, ' ');
  text = text.replace(/\[!\[[^\]]*\]\([^)]*\)\]\([^)]*\)/g, ' ');
  text = text.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1');
  text = text.replace(/<img[^>]*>/gi, ' ').replace(/<[^>]+>/g, ' ');
  text = text.replace(/^\s*[-*_]{3,}\s*$/gm, ' ');
  text = text.replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();
  return truncate(text, README_LIMIT);
}

/** Projenin README dosyasını GitHub API'sinden okur; yoksa boş metin döner. */
export async function fetchReadme(repo: Repo, token: string | undefined): Promise<string> {
  const headers: Record<string, string> = {
    Accept: 'application/vnd.github.raw+json',
    'X-GitHub-Api-Version': '2022-11-28',
    'User-Agent': 'TechPulse',
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  const path = repo.id.split('/').map(encodeURIComponent).join('/');
  const response = await fetch(`https://api.github.com/repos/${path}/readme`, { headers, signal: AbortSignal.timeout(15_000) });
  if (response.status === 404) return '';
  if (!response.ok) throw new Error(`README: HTTP ${response.status}`);
  return cleanReadme((await response.text()).slice(0, 200_000));
}
