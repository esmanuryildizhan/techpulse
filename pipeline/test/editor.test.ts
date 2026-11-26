import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { mkdtemp, mkdir, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { extractArticle } from '../src/article.ts';
import { anthropicClient, LlmFatalError, type LlmClient, type LlmRequest } from '../src/llm.ts';
import { runPipeline, type Fetchers } from '../src/pipeline.ts';
import { FEEDS } from '../src/sources/feeds.ts';
import { cleanReadme, parseRepos } from '../src/sources/github.ts';
import { parseHackerNews } from '../src/sources/hackernews.ts';
import { parseDailyPapers, parseTrendingModels } from '../src/sources/huggingface.ts';
import { parseKev } from '../src/sources/kev.ts';
import { normalizeImageUrl, parseFeed } from '../src/sources/rss.ts';
import type { AiModel, Envelope, NewsItem, Paper, Repo, Vulnerability } from '../src/types.ts';
import { applyNews, KEV_SCHEMA, MODEL_SCHEMA, NEWS_SCHEMA, PAPER_SCHEMA, paragraphs, plain, REPO_SCHEMA } from '../src/writer.ts';

const fixture = (name: string) => readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8');
const NOW = new Date('2026-11-25T12:00:00Z');

function fetchers(): Fetchers {
  return {
    feed: async (source) =>
      source.id === 'microsoft-research'
        ? parseFeed(fixture('wordpress-rss.xml'), source, { now: NOW.getTime() })
        : source.id === 'android-developers'
          ? parseFeed(fixture('blogger-atom.xml'), source, { now: NOW.getTime() })
          : [],
    hackerNews: async () => parseHackerNews(JSON.parse(fixture('hn.json'))),
    trendingModels: async () => parseTrendingModels(JSON.parse(fixture('hf-models.json'))),
    enrichModel: async (model) => ({ ...model, cardExcerpt: 'Vision-Seg is a promptable segmentation model trained on images and masks.' }),
    dailyPapers: async () => parseDailyPapers(JSON.parse(fixture('hf-papers.json'))),
    repos: async () => parseRepos(JSON.parse(fixture('github-search.json'))),
    kev: async () => parseKev(JSON.parse(fixture('kev.json'))),
    page: async (url) => {
      if (url.includes('phi-5')) return extractArticle(fixture('article.html'), url);
      throw new Error('HTTP 403');
    },
    // İlk projenin README'si okunur, diğerleri için yalnızca kısa açıklama kalır.
    readme: async (repo) =>
      repo.id === parseRepos(JSON.parse(fixture('github-search.json')))[0].id
        ? `# ${repo.name}\n\nThis toolkit lets you run local AI agents with tools, memory and a small web UI. `.repeat(3)
        : '',
  };
}

/** Sahte editör: şemaya göre tutarlı Türkçe yanıtlar üretir, istekleri kaydeder. */
function fakeEditor(options: { irrelevant?: (user: string) => boolean; fatalAfter?: number } = {}) {
  const requests: LlmRequest[] = [];
  const client: LlmClient = {
    model: 'test/editor',
    async complete<T>(request: LlmRequest) {
      requests.push(request);
      if (options.fatalAfter !== undefined && requests.length > options.fatalAfter) {
        throw new LlmFatalError('Claude API hesabında bakiye yok');
      }
      const title = /Orijinal başlık: (.*)/.exec(request.user)?.[1] ?? /Makale başlığı: (.*)/.exec(request.user)?.[1] ?? 'kayıt';
      let data: unknown;
      if (request.schema === NEWS_SCHEMA) {
        const limited = request.user.includes('Haber metnine ulaşılamadı');
        data = {
          relevant: !(options.irrelevant?.(request.user) ?? false),
          title: `**Türkçe:** ${title}`,
          summary: 'Kısa ve anlaşılır bir spot cümlesi.',
          tldr: ['Birinci önemli bilgi.', 'İkinci önemli bilgi.', 'Üçüncü önemli bilgi.', 'Fazla madde atılmalı.'],
          why: 'Bu gelişme geliştiricilerin model seçimini etkileyebilir.',
          simple: {
            intro: 'Giriş paragrafı yapay zeka ile yazıldı ve Phi-5 modelinden söz ediyor.',
            sections: [
              { heading: 'Küçük model nasıl akıl yürütüyor?', body: 'Birinci paragraf.\n\nİkinci paragraf parametre sayısını anlatıyor.' },
              { heading: 'Lisans ne anlama geliyor?:', body: '- Madde işaretli satır temizlenmeli.' },
            ],
          },
          technical: limited
            ? { intro: '', sections: [] }
            : { intro: 'Teknik giriş.', sections: [{ heading: 'Mimari ve eğitim verisi', body: 'Yedi milyar parametreli model.' }] },
          glossary: [
            { term: 'Phi-5', definition: 'Microsoft\'un küçük dil modeli.', analogy: '', usage: 'Telefonda çalışan asistanlarda.', origin: '' },
            { term: 'parametre', definition: 'Modelin öğrendiği sayısal değerler.', analogy: 'Bir mikserdeki düğmeler gibi.', usage: '', origin: '' },
            { term: 'Kuantum dolanıklık', definition: 'Metinde geçmeyen kavram atılmalı.', analogy: '', usage: '', origin: '' },
            { term: '', definition: 'Boş terim atılmalı.', analogy: '', usage: '', origin: '' },
          ],
          category: 'ai',
          topics: ['dil modelleri', 'Dil Modelleri', 'Açık kaynak', 'Phi-5', 'Fazla etiket'],
          importance: 9,
        };
      } else if (request.schema === PAPER_SCHEMA) {
        data = {
          title: `Makale: ${title}`,
          summary: 'Makalenin spotu.',
          intro: 'Makalenin girişi.',
          primer: [],
          sections: [{ heading: 'Makale ne yapıyor?', body: 'Açıklama.' }],
          topics: ['Görüntü işleme'],
        };
      } else if (request.schema === MODEL_SCHEMA) {
        data = { summary: 'Görüntüleri bölütleyen açık bir model.', highlights: ['Görsel girdi alıyor.', 'Apache 2.0 lisanslı'] };
      } else if (request.schema === REPO_SCHEMA) {
        data = {
          summary: 'Yerel yapay zekâ ajanları için araç seti.',
          what: 'Ajanları bilgisayarda çalıştıran bir araç seti.',
          why: 'Proje, kısa sürede yıldız topladı.',
          useCases: ['Yerel ajan kurmak.', 'Araç çağrısı denemek', ''],
          audience: '',
          caution: '',
        };
      } else if (request.schema === KEV_SCHEMA) {
        data = {
          name: 'fortinet FortiOS sınır dışı yazma açığı',
          description: 'Saldırganın bellekte izin verilmeyen bir alana yazmasına yol açan açık.',
          action: 'Güncellemeyi uygulayın.',
          explanation: 'Uzaktan kod çalıştırılmasına yol açabilir.',
        };
      }
      return { data: data as T, usage: { inputTokens: 1000, outputTokens: 300 } };
    },
  };
  return { client, requests };
}

async function readEnvelope<T>(dir: string, name: string): Promise<Envelope<T>> {
  return JSON.parse(await readFile(join(dir, 'v1', `${name}.json`), 'utf8'));
}

describe('haber sayfası', () => {
  it('kapak görselini ve okunabilir metni çıkarır', () => {
    const page = extractArticle(fixture('article.html'), 'https://research.example.com/blog/phi-5');
    assert.equal(page.imageUrl, 'https://cdn.example.com/images/phi-5-cover.jpg');
    assert.match(page.text, /seven billion parameter language model/);
    assert.match(page.text, /MIT license/);
    assert.doesNotMatch(page.text, /window\.tracking/);
    assert.equal(page.description, 'A small model that reasons and codes.');
  });
});

describe('akış görselleri', () => {
  it('media:content, media:thumbnail, içerikteki img ve enclosure görsellerini bulur', () => {
    const items = parseFeed(fixture('media-rss.xml'), { ...FEEDS[0], maxItems: 10 }, { now: NOW.getTime() });
    const byTitle = new Map(items.map((i) => [i.title, i]));
    assert.equal(byTitle.get('Chipmaker unveils new GPU')?.imageUrl, 'https://cdn.example.com/gpu.jpg');
    assert.equal(byTitle.get('Thumbnail only')?.imageUrl, 'https://cdn.example.com/thumb.png');
    assert.equal(byTitle.get('Inline image in content')?.imageUrl, 'https://news.example.com/uploads/inline.webp');
    assert.equal(byTitle.get('Enclosure image')?.imageUrl, 'https://cdn.example.com/enc.jpg');
    assert.equal(
      normalizeImageUrl('https://cdn.example.com/a.jpg?quality=90&amp;#038;strip=all'),
      'https://cdn.example.com/a.jpg?quality=90&strip=all',
    );
    assert.match(byTitle.get('Inline image in content')?.content ?? '', /full article body/);
    assert.equal(byTitle.get('Thumbnail only')?.content, '');
  });
});

describe('README', () => {
  it('rozetleri, görselleri, HTML ve kod bloklarını atar, metni korur', () => {
    const text = cleanReadme(
      '# Ajan Kiti\n\n[![CI](https://x/b.svg)](https://x)\n![logo](logo.png)\n<p align="center">Yerel <b>ajanlar</b></p>\n\n```bash\npip install kit\n```\n\nAyrıntı için [belgeler](https://docs).',
    );
    assert.equal(text, '# Ajan Kiti\n\n \n \n Yerel ajanlar \n\n [kod örneği] \n\nAyrıntı için belgeler.');
  });
});

describe('editör çıktısının temizliği', () => {
  it('markdown işaretlerini ve tırnakları atar, yazımı düzeltir', () => {
    assert.equal(plain('**Başlık:** "yapay zeka" haberi', 100), 'Başlık: "yapay zekâ" haberi');
    assert.equal(paragraphs('# Bir\n\n- iki\nüç', 100), 'Bir\n\niki\n\nüç');
  });

  it('eksik yanıtı uygulamaz', () => {
    const item = { writer: null, writerVersion: 0 } as unknown as NewsItem;
    const ok = applyNews(item, {
      relevant: true,
      title: 'Başlık',
      summary: 'Spot',
      tldr: ['Tek madde yetmez.'],
      why: 'Neden',
      simple: { intro: 'Giriş', sections: [{ heading: 'Bölüm', body: 'Metin' }] },
      technical: { intro: '', sections: [] },
      glossary: [],
      category: 'ai',
      topics: [],
      importance: 3,
    });
    assert.equal(ok, false);
    assert.equal(item.writer, null);
  });
});

describe('yapay zekâ editörü', () => {
  it('haberleri, makaleleri, modelleri, projeleri ve açıkları yazar', async () => {
    const out = await mkdtemp(join(tmpdir(), 'tp-ai-'));
    const { client, requests } = fakeEditor();
    const { meta } = await runPipeline({ outDir: out, now: NOW, fetchers: fetchers(), llm: client });

    const news = await readEnvelope<NewsItem>(out, 'news');
    assert.equal(news.items.length, 6);
    assert.ok(news.items.every((n) => n.writer === 'ai' && n.writerVersion === 2 && n.translated && n.story !== null && n.article !== null));
    const phi = news.items.find((n) => n.titleOriginal.startsWith('Introducing Phi-5'))!;
    assert.equal(phi.titleTr, 'Türkçe: Introducing Phi-5: a small model that reasons & codes');
    assert.equal(phi.imageUrl, 'https://cdn.example.com/images/phi-5-cover.jpg');
    const story = phi.story!;
    assert.equal(story.basis, 'full');
    assert.deepEqual(story.tldr, ['Birinci önemli bilgi.', 'İkinci önemli bilgi.', 'Üçüncü önemli bilgi.']);
    assert.equal(story.simple.intro, 'Giriş paragrafı yapay zekâ ile yazıldı ve Phi-5 modelinden söz ediyor.');
    assert.equal(story.simple.sections[0].body, 'Birinci paragraf.\n\nİkinci paragraf parametre sayısını anlatıyor.');
    assert.equal(story.simple.sections[1].heading, 'Lisans ne anlama geliyor?');
    assert.equal(story.simple.sections[1].body, 'Madde işaretli satır temizlenmeli.');
    assert.equal(story.technical?.sections[0].heading, 'Mimari ve eğitim verisi');
    // Metinde geçmeyen ve boş kavramlar atılır.
    assert.deepEqual(story.glossary.map((g) => g.term), ['Phi-5', 'parametre']);
    assert.equal(story.glossary[1].analogy, 'Bir mikserdeki düğmeler gibi.');
    // Eski uygulama sürümleri için sade anlatım eski biçimde de yazılır.
    assert.equal(phi.article!.intro, story.simple.intro);
    assert.deepEqual(phi.article!.primer[0], { term: 'Phi-5', explanation: 'Microsoft\'un küçük dil modeli.' });
    assert.deepEqual(phi.topics, ['Dil modelleri', 'Açık kaynak', 'Phi-5', 'Fazla etiket']);
    assert.equal(phi.importance, 5);
    assert.equal(phi.readingMinutes, 1);
    assert.equal(phi.category, 'ai');

    // Sayfası okunamayan haber kısa yazılır ve teknik anlatım içermez.
    const hn = news.items.find((n) => n.sourceId === 'hacker-news')!;
    assert.equal(hn.story!.basis, 'excerpt');
    assert.equal(hn.story!.technical, null);

    // Haber isteği sayfa metnini içerir; sayfası okunamayan haber için kısa yazma talimatı verilir.
    const phiRequest = requests.find((r) => r.user.includes('Introducing Phi-5'))!;
    assert.match(phiRequest.user, /seven billion parameter/);
    assert.match(phiRequest.system, /Doğruluk kuralları/);
    const hnRequest = requests.find((r) => r.user.includes('Hacker News:'))!;
    assert.match(hnRequest.user, /Haber metnine ulaşılamadı/);

    const papers = await readEnvelope<Paper>(out, 'papers');
    assert.ok(papers.items.every((p) => p.writer === 'ai' && p.article?.sections.length === 1));
    assert.match(papers.items[0].imageUrl ?? '', /^https:\/\/cdn-thumbnails\.huggingface\.co\//);

    const models = await readEnvelope<AiModel>(out, 'models');
    assert.equal(models.items[0].summaryTr, 'Görüntüleri bölütleyen açık bir model.');
    assert.deepEqual(models.items[0].highlights, ['Görsel girdi alıyor', 'Apache 2.0 lisanslı']);
    assert.equal(models.items[0].cardExcerpt, '');

    const repos = await readEnvelope<Repo>(out, 'repos');
    assert.ok(repos.items.every((r) => r.writer === 'ai' && r.writerVersion === 2 && r.imageUrl?.startsWith('https://opengraph.githubassets.com/1/')));
    assert.ok(repos.items.every((r) => r.descriptionTr === 'Yerel yapay zekâ ajanları için araç seti.'));
    assert.deepEqual(repos.items[0].story!.useCases, ['Yerel ajan kurmak', 'Araç çağrısı denemek']);
    const repoRequest = requests.find((r) => r.schema === REPO_SCHEMA)!;
    assert.match(repoRequest.user, /README:|README okunamadı/);
    assert.ok(repos.items.some((r) => r.story!.basis === 'readme'));

    const security = await readEnvelope<Vulnerability>(out, 'security');
    assert.equal(security.items[0].nameTr, 'Fortinet FortiOS sınır dışı yazma açığı');
    assert.equal(security.items[0].explanationTr, 'Uzaktan kod çalıştırılmasına yol açabilir.');

    assert.equal(meta.editor.model, 'test/editor');
    assert.equal(meta.editor.pending, 0);
    assert.equal(meta.editor.written, requests.length);
    assert.equal(meta.editor.inputTokens, requests.length * 1000);
    assert.equal(meta.translator.model, null);

    // İkinci çalışmada yazılmış kayıtlar tekrar yazılmaz.
    const second = await mkdtemp(join(tmpdir(), 'tp-ai-'));
    const again = fakeEditor();
    await runPipeline({ outDir: second, previousDir: out, now: new Date(NOW.getTime() + 3_600_000), fetchers: fetchers(), llm: again.client });
    assert.equal(again.requests.length, 0);
  });

  it('teknolojiyle ilgisiz haberi gizler ve bir daha yazmaz', async () => {
    const out = await mkdtemp(join(tmpdir(), 'tp-ai-'));
    const { client } = fakeEditor({ irrelevant: (user) => user.includes('Show HN') });
    await runPipeline({ outDir: out, now: NOW, fetchers: fetchers(), llm: client });
    const news = await readEnvelope<NewsItem>(out, 'news');
    const hidden = news.items.filter((n) => n.hidden);
    assert.equal(hidden.length, 1);
    assert.equal(hidden[0].writer, 'ai');

    const again = fakeEditor();
    await runPipeline({ outDir: await mkdtemp(join(tmpdir(), 'tp-ai-')), previousDir: out, now: NOW, fetchers: fetchers(), llm: again.client });
    assert.ok(again.requests.every((r) => !r.user.includes('Show HN')));
  });

  it('bütçe ve ölümcül hatada durur, kalanları bekleyen bırakır', async () => {
    const out = await mkdtemp(join(tmpdir(), 'tp-ai-'));
    const budget = fakeEditor();
    const { meta } = await runPipeline({ outDir: out, now: NOW, fetchers: fetchers(), llm: budget.client, aiMaxItems: 3, aiConcurrency: 1 });
    assert.equal(budget.requests.length, 3);
    assert.equal(meta.editor.written, 3);
    assert.ok(meta.editor.pending > 0);
    const news = await readEnvelope<NewsItem>(out, 'news');
    // En yeni üç haber önce yazılır.
    assert.deepEqual(
      news.items.slice(0, 3).map((n) => n.writer),
      ['ai', 'ai', 'ai'],
    );

    const fatal = fakeEditor({ fatalAfter: 1 });
    const result = await runPipeline({
      outDir: await mkdtemp(join(tmpdir(), 'tp-ai-')),
      now: NOW,
      fetchers: fetchers(),
      llm: fatal.client,
      aiConcurrency: 1,
    });
    assert.equal(result.meta.editor.written, 1);
    assert.match(result.meta.editor.note ?? '', /bakiye/);
    assert.equal(fatal.requests.length, 2, 'ölümcül hatadan sonra yeni istek gönderilmemeli');
  });

  it('önceki sürümün kayıtlarını yeni alanlarla tamamlar', async () => {
    const previous = await mkdtemp(join(tmpdir(), 'tp-old-'));
    await mkdir(join(previous, 'v1'), { recursive: true });
    const oldNews = {
      id: 'abc',
      url: 'https://example.com/a',
      sourceId: 'github-blog',
      sourceName: 'GitHub Blog',
      sourceKind: 'official',
      publishedAt: '2026-11-25T10:00:00.000Z',
      firstSeenAt: '2026-11-25T10:00:00.000Z',
      titleOriginal: 'Old record',
      excerptOriginal: '',
      titleTr: 'Eski kayıt',
      summaryTr: null,
      category: 'software',
      tags: [],
      translated: true,
      points: null,
      comments: null,
      discussionUrl: null,
    };
    await writeFile(join(previous, 'v1', 'news.json'), JSON.stringify({ schemaVersion: 1, generatedAt: NOW.toISOString(), items: [oldNews] }));
    const out = await mkdtemp(join(tmpdir(), 'tp-new-'));
    const none: Fetchers = { ...fetchers(), feed: async () => [], hackerNews: async () => [] };
    await runPipeline({ outDir: out, previousDir: previous, now: NOW, fetchers: none });
    const news = await readEnvelope<NewsItem>(out, 'news');
    assert.equal(news.items.length, 1);
    assert.equal(news.items[0].category, 'dev');
    assert.equal(news.items[0].writer, 'mt');
    assert.equal(news.items[0].hidden, false);
    assert.deepEqual(news.items[0].topics, []);
  });
});

describe('Claude API istemcisi', () => {
  function fakeFetch(responses: { status: number; body: unknown; headers?: Record<string, string> }[]) {
    const calls: { url: string; init: RequestInit }[] = [];
    const impl = (async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      const next = responses.shift()!;
      return new Response(JSON.stringify(next.body), { status: next.status, headers: next.headers });
    }) as unknown as typeof fetch;
    return { impl, calls };
  }
  const request: LlmRequest = { system: 'Talimat', user: 'Girdi', schema: REPO_SCHEMA, maxTokens: 500 };
  const success = {
    content: [{ type: 'text', text: '{"description":"Açıklama"}' }],
    stop_reason: 'end_turn',
    usage: { input_tokens: 10, output_tokens: 5, cache_read_input_tokens: 90 },
  };

  it('yapılandırılmış çıktı ister ve yanıtı çözer', async () => {
    const { impl, calls } = fakeFetch([{ status: 200, body: success }]);
    const client = anthropicClient({ apiKey: 'test-key', fetchImpl: impl });
    const res = await client.complete<{ description: string }>(request);
    assert.equal(res.data.description, 'Açıklama');
    assert.deepEqual(res.usage, { inputTokens: 100, outputTokens: 5 });
    assert.equal(calls[0].url, 'https://api.anthropic.com/v1/messages');
    const headers = calls[0].init.headers as Record<string, string>;
    assert.equal(headers['x-api-key'], 'test-key');
    assert.equal(headers['anthropic-version'], '2023-06-01');
    const body = JSON.parse(String(calls[0].init.body));
    assert.equal(body.model, 'claude-haiku-5-5');
    assert.deepEqual(body.thinking, { type: 'disabled' });
    assert.equal(body.output_config.effort, 'low');
    assert.equal(body.output_config.format.type, 'json_schema');
    assert.deepEqual(body.output_config.format.schema, REPO_SCHEMA);
    assert.deepEqual(body.system[0].cache_control, { type: 'ephemeral' });
  });

  it('yoğunlukta bekleyip yeniden dener, kesilen yanıtta sınırı büyütür', async () => {
    const { impl, calls } = fakeFetch([
      { status: 529, body: { error: { message: 'Overloaded' } }, headers: { 'retry-after': '0' } },
      { status: 200, body: { ...success, stop_reason: 'max_tokens' } },
      { status: 200, body: success },
    ]);
    const client = anthropicClient({ apiKey: 'k', fetchImpl: impl });
    const res = await client.complete<{ description: string }>(request);
    assert.equal(res.data.description, 'Açıklama');
    assert.equal(calls.length, 3);
    assert.equal(JSON.parse(String(calls[2].init.body)).max_tokens, 1000);
  });

  it('geçersiz anahtarda ölümcül hata fırlatır', async () => {
    const { impl } = fakeFetch([{ status: 401, body: { error: { message: 'invalid x-api-key' } } }]);
    const client = anthropicClient({ apiKey: 'bad', fetchImpl: impl });
    await assert.rejects(client.complete(request), LlmFatalError);
  });
});
