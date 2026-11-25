import assert from 'node:assert/strict';
import { mkdtemp, readFile } from 'node:fs/promises';
import { readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { runPipeline, type Fetchers } from '../src/pipeline.ts';
import { parseRepos } from '../src/sources/github.ts';
import { parseHackerNews } from '../src/sources/hackernews.ts';
import { parseDailyPapers, parseTrendingModels } from '../src/sources/huggingface.ts';
import { parseKev } from '../src/sources/kev.ts';
import { parseFeed } from '../src/sources/rss.ts';
import { parseModelJson, Translator } from '../src/translator.ts';
import type { Envelope, NewsItem } from '../src/types.ts';

const fixture = (name: string) => readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8');
const NOW = new Date('2026-11-25T12:00:00Z');

/** GitHub Models'i taklit eden sahte sunucu. */
function fakeModels(options: { catalog?: unknown; failFirstModel?: boolean; status?: number } = {}) {
  const calls: { model: string; items: number }[] = [];
  const impl = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = String(input);
    if (url.endsWith('/catalog/models')) {
      return new Response(JSON.stringify(options.catalog ?? []), { status: 200 });
    }
    const body = JSON.parse(String(init?.body));
    if (options.status) return new Response('limit', { status: options.status });
    if (options.failFirstModel && calls.length === 0 && body.model === 'openai/gpt-4.1-mini') {
      calls.push({ model: body.model, items: 0 });
      return new Response('{"error":{"code":"unknown_model"}}', { status: 404 });
    }
    const user = JSON.parse(body.messages[1].content) as { items: Record<string, unknown>[] };
    calls.push({ model: body.model, items: user.items.length });
    const items = user.items.map((item) => {
      const id = item.id;
      if ('snippet' in item) return { id, title_tr: `TR: ${item.title}`, summary_tr: 'Türkçe özet.', category: 'ai', tags: ['Test', '#Etiket'] };
      if ('abstract' in item) return { id, title_tr: `TR: ${item.title}`, summary_tr: 'Makale özeti.', tags: ['Görüntü bölütleme'] };
      if ('card' in item) return { id, summary_tr: 'Model özeti.' };
      if ('topics' in item) return { id, description_tr: 'Proje açıklaması.' };
      return { id, name_tr: 'Açık adı', description_tr: 'Açık açıklaması.', action_tr: 'Yamayı uygulayın.' };
    });
    const content = '```json\n' + JSON.stringify({ items }) + '\n```';
    return new Response(JSON.stringify({ choices: [{ message: { content } }] }), { status: 200 });
  }) as typeof fetch;
  return { impl, calls };
}

function fixtureFetchers(): Fetchers {
  return {
    feed: async (source) =>
      source.id === 'microsoft-research'
        ? parseFeed(fixture('wordpress-rss.xml'), source, { now: NOW.getTime() })
        : source.id === 'android-developers'
          ? parseFeed(fixture('blogger-atom.xml'), source, { now: NOW.getTime() })
          : source.id === 'openai'
            ? Promise.reject(new Error('HTTP 403'))
            : [],
    hackerNews: async () => parseHackerNews(JSON.parse(fixture('hn.json'))),
    trendingModels: async () => parseTrendingModels(JSON.parse(fixture('hf-models.json'))),
    enrichModel: async (model) => ({
      ...model,
      parameters: 2_000_000_000,
      cardExcerpt: 'Vision-Seg is a promptable segmentation model trained on a large dataset of images and masks for general use.',
    }),
    dailyPapers: async () => parseDailyPapers(JSON.parse(fixture('hf-papers.json'))),
    repos: async () => parseRepos(JSON.parse(fixture('github-search.json'))),
    kev: async () => parseKev(JSON.parse(fixture('kev.json'))),
  };
}

async function readEnvelope<T>(dir: string, name: string): Promise<Envelope<T>> {
  return JSON.parse(await readFile(join(dir, 'v1', `${name}.json`), 'utf8'));
}

describe('parseModelJson', () => {
  it('kod bloğu ve çevre metni tolere eder', () => {
    assert.deepEqual(parseModelJson('```json\n{"a":1}\n```'), { a: 1 });
    assert.deepEqual(parseModelJson('Here you go: {"a":2} thanks'), { a: 2 });
    assert.equal(parseModelJson('no json'), null);
  });
});

describe('Translator', () => {
  it('katalogdan düşük katmanlı modeli öne alır', async () => {
    const { impl, calls } = fakeModels({
      catalog: [
        { id: 'openai/gpt-4.1-mini', rate_limit_tier: 'high' },
        { id: 'openai/gpt-4o-mini', rate_limit_tier: 'low' },
      ],
    });
    const t = new Translator({ token: 'x', fetchImpl: impl, retryDelayMs: 0 });
    await t.init();
    await t.completeJson('sys', JSON.stringify({ items: [{ id: '1', title: 'a', snippet: '' }] }));
    assert.equal(calls[0].model, 'openai/gpt-4o-mini');
    assert.equal(t.model, 'openai/gpt-4o-mini');
  });

  it('bulunamayan modelde sıradakine geçer', async () => {
    const { impl, calls } = fakeModels({ failFirstModel: true });
    const t = new Translator({ token: 'x', fetchImpl: impl, retryDelayMs: 0 });
    const out = await t.completeJson('sys', JSON.stringify({ items: [{ id: '1', title: 'a', snippet: '' }] }));
    assert.ok(out);
    assert.equal(calls[1].model, 'openai/gpt-4o-mini');
  });

  it('oran sınırında bu çalışma için durur', async () => {
    const { impl } = fakeModels({ status: 429 });
    const t = new Translator({ token: 'x', fetchImpl: impl, retryDelayMs: 0 });
    assert.equal(await t.completeJson('sys', '{"items":[]}'), null);
    assert.equal(t.available, false);
    assert.match(t.stopReason ?? '', /oran sınırı/);
  });

  it('jeton yoksa hiç istek atmaz', async () => {
    const t = new Translator({});
    assert.equal(t.available, false);
    assert.equal(await t.completeJson('s', 'u'), null);
    assert.equal(t.requests, 0);
  });
});

describe('runPipeline', () => {
  it('kaynakları toplar, çevirir, doğrular ve yazar', async () => {
    const out = await mkdtemp(join(tmpdir(), 'tp-'));
    const { impl, calls } = fakeModels();
    const { meta } = await runPipeline({
      outDir: out,
      token: 'x',
      now: NOW,
      fetchers: fixtureFetchers(),
      translatorFetch: impl,
    });

    const news = await readEnvelope<NewsItem>(out, 'news');
    assert.equal(news.schemaVersion, 1);
    assert.equal(news.items.length, 6); // 2 RSS + 2 Atom + 2 HN
    assert.ok(news.items.every((n) => n.translated && n.titleTr?.startsWith('TR: ')));
    assert.deepEqual(news.items[0].tags, ['Test', 'Etiket']);
    // en yeni haber başta
    assert.equal(news.items[0].sourceId, 'android-developers');
    const hn = news.items.find((n) => n.sourceId === 'hacker-news')!;
    assert.equal(hn.points, 420);
    assert.equal(hn.discussionUrl, 'https://news.ycombinator.com/item?id=46001');

    const models = await readEnvelope<{ summaryTr: string | null; parameters: number | null; cardExcerpt: string }>(out, 'models');
    assert.equal(models.items[0].summaryTr, 'Model özeti.');
    assert.equal(models.items[0].parameters, 2_000_000_000);
    assert.equal(models.items[0].cardExcerpt, '');

    const security = await readEnvelope<{ nameTr: string }>(out, 'security');
    assert.equal(security.items.length, 2);
    assert.equal(security.items[0].nameTr, 'Açık adı');

    assert.equal(meta.counts.news, 6);
    assert.equal(meta.translator.pendingItems, 0);
    const openai = meta.sources.find((s) => s.id === 'openai')!;
    assert.equal(openai.ok, false);
    assert.match(openai.error ?? '', /403/);
    assert.ok(calls.length >= 5);

    const html = await readFile(join(out, 'index.html'), 'utf8');
    assert.match(html, /TechPulse Veri API/);
  });

  it('ikinci çalışmada çevrilmiş kayıtları yeniden çevirmez', async () => {
    const first = await mkdtemp(join(tmpdir(), 'tp-'));
    await runPipeline({ outDir: first, token: 'x', now: NOW, fetchers: fixtureFetchers(), translatorFetch: fakeModels().impl });

    const second = await mkdtemp(join(tmpdir(), 'tp-'));
    const { impl, calls } = fakeModels();
    const { meta } = await runPipeline({
      outDir: second,
      previousDir: first,
      token: 'x',
      now: new Date(NOW.getTime() + 3_600_000),
      fetchers: fixtureFetchers(),
      translatorFetch: impl,
    });
    assert.equal(calls.length, 0, 'çevrilmiş kayıtlar için istek atılmamalı');
    assert.equal(meta.counts.news, 6);
    const news = await readEnvelope<NewsItem>(second, 'news');
    assert.ok(news.items.every((n) => n.translated));
  });

  it('çeviri yapılamazsa yedek konu belirlemeyle yine yayımlar', async () => {
    const out = await mkdtemp(join(tmpdir(), 'tp-'));
    const { meta } = await runPipeline({ outDir: out, now: NOW, fetchers: fixtureFetchers() });
    const news = await readEnvelope<NewsItem>(out, 'news');
    assert.equal(news.items.length, 6);
    assert.ok(news.items.every((n) => !n.translated && n.titleTr === null));
    const gpu = news.items.find((n) => n.titleOriginal.includes('GPU'))!;
    assert.equal(gpu.category, 'hardware');
    assert.match(meta.translator.note ?? '', /GITHUB_TOKEN/);
  });
});
