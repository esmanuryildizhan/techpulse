import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { mergeKev, mergeModels, mergeNews, mergePapers, mergeRepos } from './merge.ts';
import { FEEDS, HACKER_NEWS } from './sources/feeds.ts';
import { fetchTrendingRepos } from './sources/github.ts';
import { fetchHackerNews } from './sources/hackernews.ts';
import { enrichModel, fetchDailyPapers, fetchTrendingModels } from './sources/huggingface.ts';
import { fetchKev } from './sources/kev.ts';
import { fetchFeed } from './sources/rss.ts';
import type { TranslateFn } from './mt.ts';
import { applyCategories, translatePending } from './translate.ts';
import type { AiModel, Envelope, FeedSource, Meta, Paper, RawNews, Repo, SourceStatus, State, Vulnerability } from './types.ts';
import { SCHEMA_VERSION } from './types.ts';
import { errorMessage, fetchJson, log, mapLimit } from './util.ts';
import { validate } from './validate.ts';

export interface Fetchers {
  feed: (source: FeedSource) => Promise<RawNews[]>;
  hackerNews: () => Promise<RawNews[]>;
  trendingModels: () => Promise<AiModel[]>;
  enrichModel: (model: AiModel) => Promise<AiModel>;
  dailyPapers: () => Promise<Paper[]>;
  repos: () => Promise<Repo[]>;
  kev: () => Promise<Vulnerability[]>;
}

export interface PipelineOptions {
  outDir: string;
  previousBaseUrl?: string;
  previousDir?: string;
  token?: string;
  now?: Date;
  /** Makine çevirisi; null ise çeviri yapılmaz (kayıtlar özgün diliyle yayımlanır). */
  translate?: TranslateFn | null;
  maxTranslationTexts?: number;
  fetchers?: Partial<Fetchers>;
}

export interface PipelineResult {
  state: State;
  meta: Meta;
}

const FILES = ['news', 'models', 'papers', 'repos', 'security'] as const;
type FileKey = (typeof FILES)[number];

async function loadPrevious(options: PipelineOptions): Promise<State> {
  const state: State = { news: [], models: [], papers: [], repos: [], security: [] };
  if (!options.previousBaseUrl && !options.previousDir) return state;
  await Promise.all(
    FILES.map(async (key) => {
      try {
        let envelope: Envelope<unknown>;
        if (options.previousDir) {
          envelope = JSON.parse(await readFile(join(options.previousDir, 'v1', `${key}.json`), 'utf8'));
        } else {
          const base = options.previousBaseUrl!.replace(/\/+$/, '');
          envelope = await fetchJson<Envelope<unknown>>(`${base}/v1/${key}.json?t=${Date.now()}`, { retries: 1, timeoutMs: 20_000 });
        }
        if (envelope?.schemaVersion !== SCHEMA_VERSION) return;
        const warn = (msg: string) => log.warn(`Önceki yayın: ${msg}`);
        (state as unknown as Record<FileKey, unknown[]>)[key] = validate[key](envelope.items, warn);
      } catch (error) {
        log.info(`Önceki ${key}.json okunamadı (ilk çalışmada normaldir): ${errorMessage(error)}`);
      }
    }),
  );
  return state;
}

function defaultFetchers(token: string | undefined): Fetchers {
  return {
    feed: (source) => fetchFeed(source),
    hackerNews: () => fetchHackerNews(),
    trendingModels: () => fetchTrendingModels(),
    enrichModel: (model) => enrichModel(model),
    dailyPapers: () => fetchDailyPapers(),
    repos: () => fetchTrendingRepos(token),
    kev: () => fetchKev(),
  };
}

async function track<T>(
  statuses: SourceStatus[],
  info: Omit<SourceStatus, 'ok' | 'count' | 'error' | 'checkedAt'>,
  run: () => Promise<T[]>,
): Promise<T[] | null> {
  const checkedAt = new Date().toISOString();
  try {
    const items = await run();
    statuses.push({ ...info, ok: true, count: items.length, error: null, checkedAt });
    return items;
  } catch (error) {
    log.warn(`${info.name}: ${errorMessage(error)}`);
    statuses.push({ ...info, ok: false, count: 0, error: errorMessage(error), checkedAt });
    return null;
  }
}

export async function runPipeline(options: PipelineOptions): Promise<PipelineResult> {
  const now = options.now ?? new Date();
  const fetchers: Fetchers = { ...defaultFetchers(options.token), ...(options.fetchers ?? {}) };
  const previous = await loadPrevious(options);
  log.info(
    `Önceki yayın: ${previous.news.length} haber, ${previous.models.length} model, ${previous.papers.length} makale, ` +
      `${previous.repos.length} proje, ${previous.security.length} güvenlik kaydı`,
  );

  // 1) Kaynakları topla. Bir kaynağın çökmesi diğerlerini etkilemez.
  const statuses: SourceStatus[] = [];
  const feedResults = await mapLimit(FEEDS, 6, (source) =>
    track(statuses, { id: source.id, name: source.name, kind: source.kind, homepage: source.homepage }, () => fetchers.feed(source)),
  );
  const hn = await track(
    statuses,
    { id: HACKER_NEWS.id, name: HACKER_NEWS.name, kind: HACKER_NEWS.kind, homepage: HACKER_NEWS.homepage },
    () => fetchers.hackerNews(),
  );
  const [models, papers, repos, kev] = await Promise.all([
    track(statuses, { id: 'hf-models', name: 'Hugging Face (trend modeller)', kind: 'data', homepage: 'https://huggingface.co/models' }, () =>
      fetchers.trendingModels(),
    ),
    track(statuses, { id: 'hf-papers', name: 'Hugging Face Daily Papers', kind: 'data', homepage: 'https://huggingface.co/papers' }, () =>
      fetchers.dailyPapers(),
    ),
    track(statuses, { id: 'github-trending', name: 'GitHub (yükselen projeler)', kind: 'data', homepage: 'https://github.com/' }, () =>
      fetchers.repos(),
    ),
    track(statuses, { id: 'cisa-kev', name: 'CISA KEV', kind: 'data', homepage: 'https://www.cisa.gov/known-exploited-vulnerabilities-catalog' }, () =>
      fetchers.kev(),
    ),
  ]);

  const freshNews = [...feedResults.flatMap((r) => r ?? []), ...(hn ?? [])];

  // 2) Önceki yayınla birleştir. Bir kaynak bu çalışmada okunamadıysa eski kayıtlar korunur.
  const state: State = {
    news: mergeNews(previous.news, freshNews, now),
    models: models ? mergeModels(previous.models, models) : previous.models,
    papers: mergePapers(previous.papers, papers ?? [], now),
    repos: repos ? mergeRepos(previous.repos, repos) : previous.repos,
    security: kev ? mergeKev(previous.security, kev) : previous.security,
  };

  // 3) Yeni modellerin kartını oku (parametre sayısı, lisans, kısa açıklama).
  const toEnrich = state.models.filter((m) => !m.translated && m.cardExcerpt === '').slice(0, 15);
  if (toEnrich.length > 0) {
    const enriched = await mapLimit(toEnrich, 4, async (model) => {
      try {
        return await fetchers.enrichModel(model);
      } catch {
        return model;
      }
    });
    const byId = new Map(enriched.map((m) => [m.id, m]));
    state.models = state.models.map((m) => byId.get(m.id) ?? m);
  }

  // 4) Konuyu belirle ve Türkçeye çevir (açık kaynak OPUS-MT modeli, Actions sunucusunda).
  applyCategories(state);
  const translation = await translatePending(state, options.translate ?? null, {
    maxTexts: options.maxTranslationTexts,
  });
  // Özeti çıkarılmış modellerin kart metnini yayımlamaya gerek yok.
  for (const model of state.models) if (model.translated) model.cardExcerpt = '';

  // 5) Doğrula ve yaz.
  const warn = (msg: string) => log.warn(`Yayın öncesi doğrulama: ${msg}`);
  const output: State = {
    news: validate.news(state.news, warn),
    models: validate.models(state.models, warn),
    papers: validate.papers(state.papers, warn),
    repos: validate.repos(state.repos, warn),
    security: validate.security(state.security, warn),
  };

  const generatedAt = now.toISOString();
  const meta: Meta = {
    schemaVersion: SCHEMA_VERSION,
    generatedAt,
    translator: {
      model: translation.model,
      requests: translation.texts,
      translatedItems: translation.translatedItems,
      pendingItems: translation.pendingItems,
      note: translation.note,
    },
    counts: {
      news: output.news.length,
      models: output.models.length,
      papers: output.papers.length,
      repos: output.repos.length,
      security: output.security.length,
    },
    sources: statuses.sort((a, b) => a.name.localeCompare(b.name, 'tr')),
  };

  await writeOutput(options.outDir, output, meta);
  return { state: output, meta };
}

async function writeOutput(outDir: string, state: State, meta: Meta): Promise<void> {
  const dir = join(outDir, 'v1');
  await mkdir(dir, { recursive: true });
  for (const key of FILES) {
    const envelope: Envelope<unknown> = {
      schemaVersion: SCHEMA_VERSION,
      generatedAt: meta.generatedAt,
      items: (state as unknown as Record<FileKey, unknown[]>)[key],
    };
    await writeFile(join(dir, `${key}.json`), JSON.stringify(envelope));
  }
  await writeFile(join(dir, 'meta.json'), JSON.stringify(meta, null, 2));
  await writeFile(join(outDir, '.nojekyll'), '');
  await writeFile(join(outDir, 'index.html'), landingPage(meta));
}

function landingPage(meta: Meta): string {
  const rows = meta.sources
    .map((s) => `<tr><td>${escapeHtml(s.name)}</td><td>${s.ok ? '✓' : '✗'}</td><td>${s.count}</td></tr>`)
    .join('');
  return `<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>TechPulse Veri API</title><style>body{font:16px/1.5 system-ui,sans-serif;max-width:720px;margin:40px auto;padding:0 16px;color:#1b1b1f}
code{background:#eef;padding:2px 6px;border-radius:4px}table{border-collapse:collapse;width:100%}td{border-bottom:1px solid #ddd;padding:6px 4px}</style></head>
<body><h1>TechPulse Veri API</h1><p>TechPulse mobil uygulamasının okuduğu statik JSON uçları. Son güncelleme: <b>${escapeHtml(meta.generatedAt)}</b></p>
<ul><li><code>v1/news.json</code> — haberler (${meta.counts.news})</li><li><code>v1/models.json</code> — trend modeller (${meta.counts.models})</li>
<li><code>v1/papers.json</code> — makaleler (${meta.counts.papers})</li><li><code>v1/repos.json</code> — yükselen projeler (${meta.counts.repos})</li>
<li><code>v1/security.json</code> — CISA KEV (${meta.counts.security})</li><li><code>v1/meta.json</code> — kaynak durumu</li></ul>
<h2>Kaynaklar</h2><table>${rows}</table><p>İçeriklerin tüm hakları kaynaklarına aittir; TechPulse yalnızca başlık, kısa Türkçe özet ve bağlantı yayımlar.</p></body></html>`;
}

function escapeHtml(text: string): string {
  return text.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);
}
