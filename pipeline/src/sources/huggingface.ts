import type { AiModel, Modality, Paper } from '../types.ts';
import { asArray, cleanText, fetchJson, fetchText, toInt, toIsoDate, truncate } from '../util.ts';

const HF = 'https://huggingface.co';

/** Hugging Face görev etiketlerinin Türkçe karşılıkları ve kip (modality) sınıfları. */
export const TASKS: Record<string, { label: string; modality: Modality }> = {
  'text-generation': { label: 'Metin üretimi', modality: 'text' },
  'text2text-generation': { label: 'Metinden metne üretim', modality: 'text' },
  'text-classification': { label: 'Metin sınıflandırma', modality: 'text' },
  'token-classification': { label: 'Varlık tanıma', modality: 'text' },
  'question-answering': { label: 'Soru yanıtlama', modality: 'text' },
  'fill-mask': { label: 'Maskeli dil modeli', modality: 'text' },
  summarization: { label: 'Özetleme', modality: 'text' },
  translation: { label: 'Çeviri', modality: 'text' },
  'feature-extraction': { label: 'Gömme (embedding)', modality: 'text' },
  'sentence-similarity': { label: 'Cümle benzerliği', modality: 'text' },
  'zero-shot-classification': { label: 'Sıfır atışlı sınıflandırma', modality: 'text' },
  'table-question-answering': { label: 'Tablo soru yanıtlama', modality: 'text' },
  'text-ranking': { label: 'Metin sıralama', modality: 'text' },
  'image-classification': { label: 'Görüntü sınıflandırma', modality: 'vision' },
  'object-detection': { label: 'Nesne tespiti', modality: 'vision' },
  'image-segmentation': { label: 'Görüntü bölütleme', modality: 'vision' },
  'depth-estimation': { label: 'Derinlik kestirimi', modality: 'vision' },
  'image-to-image': { label: 'Görüntüden görüntüye', modality: 'vision' },
  'unconditional-image-generation': { label: 'Görüntü üretimi', modality: 'vision' },
  'zero-shot-image-classification': { label: 'Sıfır atışlı görüntü sınıflandırma', modality: 'vision' },
  'zero-shot-object-detection': { label: 'Sıfır atışlı nesne tespiti', modality: 'vision' },
  'mask-generation': { label: 'Maske üretimi', modality: 'vision' },
  'keypoint-detection': { label: 'Anahtar nokta tespiti', modality: 'vision' },
  'video-classification': { label: 'Video sınıflandırma', modality: 'vision' },
  'image-feature-extraction': { label: 'Görüntü gömme', modality: 'vision' },
  'image-to-3d': { label: 'Görüntüden 3B', modality: 'vision' },
  'text-to-image': { label: 'Metinden görüntü üretimi', modality: 'multimodal' },
  'image-to-text': { label: 'Görüntüden metne', modality: 'multimodal' },
  'image-text-to-text': { label: 'Görsel dil modeli', modality: 'multimodal' },
  'visual-question-answering': { label: 'Görsel soru yanıtlama', modality: 'multimodal' },
  'document-question-answering': { label: 'Belge soru yanıtlama', modality: 'multimodal' },
  'visual-document-retrieval': { label: 'Görsel belge erişimi', modality: 'multimodal' },
  'text-to-video': { label: 'Metinden video üretimi', modality: 'multimodal' },
  'image-to-video': { label: 'Görüntüden video', modality: 'multimodal' },
  'video-text-to-text': { label: 'Video dil modeli', modality: 'multimodal' },
  'any-to-any': { label: 'Çok kipli (her kipten her kipe)', modality: 'multimodal' },
  'text-to-3d': { label: 'Metinden 3B', modality: 'multimodal' },
  'audio-text-to-text': { label: 'Ses dil modeli', modality: 'multimodal' },
  'automatic-speech-recognition': { label: 'Konuşma tanıma', modality: 'audio' },
  'text-to-speech': { label: 'Metinden konuşmaya', modality: 'audio' },
  'text-to-audio': { label: 'Metinden sese', modality: 'audio' },
  'audio-classification': { label: 'Ses sınıflandırma', modality: 'audio' },
  'audio-to-audio': { label: 'Ses dönüştürme', modality: 'audio' },
  'voice-activity-detection': { label: 'Ses etkinliği tespiti', modality: 'audio' },
  'reinforcement-learning': { label: 'Pekiştirmeli öğrenme', modality: 'other' },
  robotics: { label: 'Robotik', modality: 'other' },
  'tabular-classification': { label: 'Tablo sınıflandırma', modality: 'other' },
  'tabular-regression': { label: 'Tablo regresyonu', modality: 'other' },
  'time-series-forecasting': { label: 'Zaman serisi tahmini', modality: 'other' },
  'graph-ml': { label: 'Çizge öğrenmesi', modality: 'other' },
};

export function describeTask(pipelineTag: string | null | undefined): { label: string; modality: Modality } {
  if (!pipelineTag) return { label: 'Görev belirtilmemiş', modality: 'other' };
  return TASKS[pipelineTag] ?? { label: pipelineTag.replace(/-/g, ' '), modality: 'other' };
}

interface HfModelListItem {
  id?: string;
  modelId?: string;
  likes?: number;
  downloads?: number;
  trendingScore?: number;
  pipeline_tag?: string | null;
  library_name?: string | null;
  tags?: string[];
  createdAt?: string | null;
}

function licenseFromTags(tags: string[]): string | null {
  const tag = tags.find((t) => t.startsWith('license:'));
  return tag ? tag.slice('license:'.length) : null;
}

export function parseTrendingModels(list: HfModelListItem[], limit = 40): AiModel[] {
  const out: AiModel[] = [];
  for (const item of list) {
    const id = String(item.id ?? item.modelId ?? '').trim();
    if (!id || !id.includes('/')) continue;
    const [author, ...rest] = id.split('/');
    const tags = asArray(item.tags).map(String);
    const task = describeTask(item.pipeline_tag ?? null);
    out.push({
      id,
      author,
      name: rest.join('/'),
      url: `${HF}/${id}`,
      pipelineTag: item.pipeline_tag ?? null,
      task: task.label,
      modality: task.modality,
      likes: toInt(item.likes),
      downloads: toInt(item.downloads),
      trendingScore: toInt(item.trendingScore),
      rank: out.length + 1,
      createdAt: toIsoDate(item.createdAt),
      library: item.library_name ?? null,
      license: licenseFromTags(tags),
      parameters: null,
      summaryTr: null,
      translated: false,
      cardExcerpt: '',
    });
    if (out.length >= limit) break;
  }
  return out;
}

export async function fetchTrendingModels(): Promise<AiModel[]> {
  const list = await fetchJson<HfModelListItem[]>(`${HF}/api/models?sort=trendingScore&direction=-1&limit=50`);
  if (!Array.isArray(list)) throw new Error('Beklenmeyen model listesi biçimi');
  return parseTrendingModels(list);
}

/** Model kartındaki (README.md) metni çeviri için sadeleştirir. */
export function cleanModelCard(markdown: string, max = 1800): string {
  let text = markdown.replace(/^---[\s\S]*?\n---\s*/, ''); // YAML ön bilgisi
  text = text
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/^\s*\|.*\|\s*$/gm, ' ')
    .replace(/^#+\s*/gm, '')
    .replace(/[*_`>]/g, '');
  return truncate(cleanText(text), max);
}

interface HfModelDetail {
  safetensors?: { total?: number };
  cardData?: { license?: string };
}

export async function enrichModel(model: AiModel): Promise<AiModel> {
  const path = model.id.split('/').map(encodeURIComponent).join('/');
  const [detail, card] = await Promise.allSettled([
    fetchJson<HfModelDetail>(`${HF}/api/models/${path}`, { retries: 0, timeoutMs: 15_000 }),
    fetchText(`${HF}/${path}/raw/main/README.md`, { retries: 0, timeoutMs: 15_000 }),
  ]);
  const enriched = { ...model };
  if (detail.status === 'fulfilled') {
    const total = detail.value.safetensors?.total;
    if (typeof total === 'number' && total > 0) enriched.parameters = total;
    const license = detail.value.cardData?.license;
    if (!enriched.license && typeof license === 'string') enriched.license = license;
  }
  if (card.status === 'fulfilled') enriched.cardExcerpt = cleanModelCard(card.value);
  return enriched;
}

interface HfDailyPaper {
  paper?: {
    id?: string;
    title?: string;
    summary?: string;
    upvotes?: number;
    publishedAt?: string;
    authors?: { name?: string }[];
    githubRepo?: string | null;
    ai_keywords?: string[];
  };
  title?: string;
  summary?: string;
  publishedAt?: string;
  numComments?: number;
}

export function parseDailyPapers(list: HfDailyPaper[]): Paper[] {
  const out: Paper[] = [];
  const seen = new Set<string>();
  for (const entry of list) {
    const paper = entry.paper ?? {};
    const id = String(paper.id ?? '').trim();
    const title = cleanText(paper.title ?? entry.title ?? '');
    if (!id || !title || seen.has(id)) continue;
    seen.add(id);
    const github = typeof paper.githubRepo === 'string' && paper.githubRepo.startsWith('https://') ? paper.githubRepo : null;
    out.push({
      id,
      url: `${HF}/papers/${encodeURIComponent(id)}`,
      arxivUrl: `https://arxiv.org/abs/${encodeURIComponent(id)}`,
      titleOriginal: truncate(title, 300),
      abstractOriginal: truncate(cleanText(paper.summary ?? entry.summary ?? ''), 1500),
      titleTr: null,
      summaryTr: null,
      upvotes: toInt(paper.upvotes),
      comments: toInt(entry.numComments),
      publishedAt: toIsoDate(entry.publishedAt ?? paper.publishedAt) ?? new Date().toISOString(),
      authors: asArray(paper.authors)
        .map((a) => cleanText(a?.name ?? ''))
        .filter(Boolean)
        .slice(0, 6),
      githubUrl: github,
      tags: asArray(paper.ai_keywords).map(String).slice(0, 4),
      translated: false,
    });
  }
  return out;
}

export async function fetchDailyPapers(): Promise<Paper[]> {
  const list = await fetchJson<HfDailyPaper[]>(`${HF}/api/daily_papers?limit=50`);
  if (!Array.isArray(list)) throw new Error('Beklenmeyen makale listesi biçimi');
  return parseDailyPapers(list);
}
