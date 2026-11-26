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
import type { TranslateFn } from '../src/mt.ts';
import { kevNameTr, leadSentences, polishTurkish, translatePending } from '../src/translate.ts';
import { isRelevant } from '../src/classify.ts';
import { FEEDS } from '../src/sources/feeds.ts';
import type { Envelope, NewsItem } from '../src/types.ts';

const fixture = (name: string) => readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8');
const NOW = new Date('2026-11-25T12:00:00Z');

/** Sahte makine çevirisi: her metnin başına "TR: " ekler ve çağrıları sayar. */
function fakeMt(options: { fail?: boolean } = {}) {
  const calls: string[][] = [];
  const translate: TranslateFn = async (texts) => {
    calls.push(texts);
    if (options.fail) throw new Error('model indirilemedi');
    return { model: 'test/mt', translations: texts.map((t) => `TR: ${t}`), seconds: 0.1 };
  };
  return { translate, calls };
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
    page: async (url) => {
      if (url.includes('phi-5')) return { imageUrl: 'https://cdn.example.com/phi.jpg', text: '', description: '' };
      throw new Error('HTTP 403');
    },
    readme: async () => '',
  };
}

async function readEnvelope<T>(dir: string, name: string): Promise<Envelope<T>> {
  return JSON.parse(await readFile(join(dir, 'v1', `${name}.json`), 'utf8'));
}

describe('leadSentences', () => {
  it('kısa metni olduğu gibi bırakır', () => {
    assert.equal(leadSentences('Kısa bir metin.', 100), 'Kısa bir metin.');
  });
  it('sınırı aşmadan ilk cümleleri alır', () => {
    const text = 'First sentence here. Second sentence is a bit longer. Third one would overflow the limit.';
    assert.equal(leadSentences(text, 60), 'First sentence here. Second sentence is a bit longer.');
  });
  it('ilk cümle bile sığmazsa kelime sınırında keser', () => {
    const out = leadSentences('word '.repeat(40).trim(), 50);
    assert.ok(out.length <= 51 && out.endsWith('…'));
  });
});

describe('çeviri düzeltmeleri', () => {
  it('CISA açık adlarını sözlükle çevirir', () => {
    assert.equal(kevNameTr('Drupal Core Remote Code Execution Vulnerability'), 'Drupal Core Uzaktan Kod Çalıştırma Açığı');
    assert.equal(
      kevNameTr('Juniper Session Smart Router OS Command Injection Vulnerability'),
      'Juniper Session Smart Router İşletim Sistemi Komut Enjeksiyonu Açığı',
    );
    assert.equal(kevNameTr('Something Strange Vulnerability'), null);
    assert.equal(kevNameTr('Not a vuln name'), null);
  });

  it('sık terim hatalarını düzeltir ve tekrar uygulanabilir', () => {
    const fixed = polishTurkish('Drupal Kırılganlığı ve yapay zeka; Güçlendirme Öğrenmesi ile başarılı sömürü % 6 oranında');
    assert.equal(fixed, 'Drupal Güvenlik Açığı ve yapay zekâ; Pekiştirmeli Öğrenme ile başarılı istismar %6 oranında');
    assert.equal(polishTurkish(fixed), fixed);
    assert.equal(polishTurkish('müşterilerin% 6sı'), 'müşterilerin %6sı');
    assert.equal(
      polishTurkish("Kaynak metne göre, şirketin yüksek performanslı GPU'ları satıldı. Kaynağa göre ihracat durdu."),
      "Şirketin yüksek performanslı GPU'ları satıldı. İhracat durdu.",
    );
    assert.equal(polishTurkish('Şirket, kaynağa göre, satışı durdurdu.'), 'Şirket satışı durdurdu.');
    assert.equal(polishTurkish('Microsoft’a göre sorun çözüldü.'), 'Microsoft’a göre sorun çözüldü.');
  });

  it('indirim ve teknolojiyle ilgisiz haberleri ayıklar', () => {
    const verge = FEEDS.find((f) => f.id === 'the-verge');
    const blog = FEEDS.find((f) => f.id === 'openai');
    assert.equal(isRelevant('Best Black Friday 2026 3D Printer deals live', '', blog), false);
    assert.equal(isRelevant('Save $250 on the M5 MacBook Air', '', blog), false);
    assert.equal(isRelevant("Blade Runner 2099's showrunner on adapting the series", 'A TV show', verge), false);
    assert.equal(isRelevant('OpenAI releases a new model', '', verge), true);
    assert.equal(isRelevant('A quiet post', '', blog), true);
  });
});

describe('translatePending', () => {
  it('aynı metni bir kez çevirir ve bütçeye uyar', async () => {
    const state = {
      news: [],
      models: [],
      papers: [],
      repos: [],
      security: parseKev(JSON.parse(fixture('kev.json'))),
    };
    const { translate, calls } = fakeMt();
    const summary = await translatePending(state, translate, { maxTexts: 100 });
    assert.equal(summary.translatedItems, 2);
    // İki kaydın "required action" metinleri farklı; adlar ve açıklamalar farklı: 6 benzersiz metin
    assert.equal(calls[0].length, new Set(calls[0]).size);
    assert.ok(state.security.every((v) => v.translated && v.descriptionTr?.startsWith('TR: ')));
    assert.equal(state.security[0].nameTr, 'Fortinet FortiOS Sınır Dışı Yazma Açığı');

    const tight = { news: [], models: [], papers: [], repos: [], security: parseKev(JSON.parse(fixture('kev.json'))) };
    const limited = await translatePending(tight, fakeMt().translate, { maxTexts: 3 });
    assert.equal(limited.translatedItems, 1);
    assert.equal(limited.pendingItems, 1);
  });

  it('çeviri başarısız olursa kayıtlar bekleyen kalır', async () => {
    const state = { news: [], models: [], papers: [], repos: [], security: parseKev(JSON.parse(fixture('kev.json'))) };
    const summary = await translatePending(state, fakeMt({ fail: true }).translate);
    assert.equal(summary.translatedItems, 0);
    assert.equal(summary.pendingItems, 2);
    assert.match(summary.note ?? '', /model indirilemedi/);
    assert.ok(state.security.every((v) => !v.translated && v.descriptionTr === null));
  });
});

describe('runPipeline', () => {
  it('kaynakları toplar, çevirir, doğrular ve yazar', async () => {
    const out = await mkdtemp(join(tmpdir(), 'tp-'));
    const { translate, calls } = fakeMt();
    const { meta } = await runPipeline({
      outDir: out,
      now: NOW,
      fetchers: fixtureFetchers(),
      translate,
    });

    const news = await readEnvelope<NewsItem>(out, 'news');
    assert.equal(news.schemaVersion, 1);
    assert.equal(news.items.length, 6); // 2 RSS + 2 Atom + 2 HN
    assert.ok(news.items.every((n) => n.translated && n.titleTr?.startsWith('TR: ')));
    const phi = news.items.find((n) => n.titleOriginal.startsWith('Introducing Phi-5'))!;
    assert.match(phi.summaryTr ?? '', /^TR: We release Phi-5/);
    assert.equal(phi.category, 'ai');
    // en yeni haber başta
    assert.equal(news.items[0].sourceId, 'android-developers');
    const hn = news.items.find((n) => n.sourceId === 'hacker-news')!;
    assert.equal(hn.points, 420);
    assert.equal(hn.discussionUrl, 'https://news.ycombinator.com/item?id=46001');

    const models = await readEnvelope<{ summaryTr: string | null; parameters: number | null; cardExcerpt: string }>(out, 'models');
    assert.match(models.items[0].summaryTr ?? '', /^TR: Vision-Seg is a promptable/);
    assert.equal(models.items[0].parameters, 2_000_000_000);
    assert.equal(models.items[0].cardExcerpt, '');

    const security = await readEnvelope<{ nameTr: string }>(out, 'security');
    assert.equal(security.items.length, 2);
    assert.equal(security.items[0].nameTr, 'Fortinet FortiOS Sınır Dışı Yazma Açığı');
    assert.equal(security.items[1].nameTr, 'Microsoft Windows Yetki Yükseltme Açığı');

    assert.equal(meta.counts.news, 6);
    assert.equal(meta.translator.pendingItems, 0);
    const openai = meta.sources.find((s) => s.id === 'openai')!;
    assert.equal(openai.ok, false);
    assert.match(openai.error ?? '', /403/);
    assert.equal(calls.length, 1, 'bütün metinler tek seferde çevrilmeli');
    assert.equal(meta.translator.model, 'test/mt');

    const html = await readFile(join(out, 'index.html'), 'utf8');
    assert.match(html, /TechPulse Veri API/);
  });

  it('ikinci çalışmada çevrilmiş kayıtları yeniden çevirmez', async () => {
    const first = await mkdtemp(join(tmpdir(), 'tp-'));
    await runPipeline({ outDir: first, now: NOW, fetchers: fixtureFetchers(), translate: fakeMt().translate });

    const second = await mkdtemp(join(tmpdir(), 'tp-'));
    const { translate, calls } = fakeMt();
    const { meta } = await runPipeline({
      outDir: second,
      previousDir: first,
      now: new Date(NOW.getTime() + 3_600_000),
      fetchers: fixtureFetchers(),
      translate,
    });
    assert.equal(calls.length, 0, 'çevrilmiş kayıtlar tekrar çevrilmemeli');
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
    assert.match(meta.editor.note ?? '', /kapalı/);
    // Editör yokken yeni haberlerin kapak görseli sayfadan okunur.
    const phi = news.items.find((n) => n.titleOriginal.startsWith('Introducing Phi-5'))!;
    assert.equal(phi.imageUrl, 'https://cdn.example.com/phi.jpg');
    assert.ok(news.items.every((n) => n.writer === null && n.article === null && n.hidden === false));
  });
});
