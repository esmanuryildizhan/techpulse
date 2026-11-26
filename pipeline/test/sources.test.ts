import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, it } from 'node:test';
import { classify } from '../src/classify.ts';
import { parseRepos } from '../src/sources/github.ts';
import { parseHackerNews } from '../src/sources/hackernews.ts';
import { cleanModelCard, describeTask, parseDailyPapers, parseTrendingModels } from '../src/sources/huggingface.ts';
import { parseKev } from '../src/sources/kev.ts';
import { parseFeed } from '../src/sources/rss.ts';
import type { FeedSource } from '../src/types.ts';
import { canonicalUrl, cleanText, stableId, toIsoDate, truncate } from '../src/util.ts';

const fixture = (name: string) => readFileSync(new URL(`./fixtures/${name}`, import.meta.url), 'utf8');
const NOW = Date.parse('2026-11-25T12:00:00Z');

const source: FeedSource = {
  id: 'microsoft-research',
  name: 'Microsoft Research',
  kind: 'official',
  url: 'https://example.com/feed',
  homepage: 'https://example.com',
  defaultCategory: 'ai',
  maxItems: 10,
};

describe('util', () => {
  it('canonicalUrl izleme parametrelerini, parçayı ve sondaki eğik çizgiyi atar', () => {
    assert.equal(
      canonicalUrl('http://Example.com/a/b/?utm_source=rss&id=7&fbclid=x#top'),
      'https://example.com/a/b?id=7',
    );
    assert.equal(canonicalUrl('https://example.com/'), 'https://example.com/');
    assert.equal(canonicalUrl('javascript:alert(1)'), null);
    assert.equal(canonicalUrl('not a url'), null);
  });

  it('stableId aynı girdi için aynı, farklı girdi için farklı kimlik üretir', () => {
    assert.equal(stableId('a'), stableId('a'));
    assert.notEqual(stableId('a'), stableId('b'));
    assert.equal(stableId('a').length, 24);
  });

  it('cleanText etiketleri ve HTML varlıklarını temizler', () => {
    assert.equal(cleanText('<p>Hello&nbsp;<b>world</b> &amp; more</p>'), 'Hello world & more');
    assert.equal(cleanText('<p>Built with .NET and Node .js , fast</p>'), 'Built with .NET and Node .js, fast');
    assert.equal(cleanText('&lt;p&gt;double&lt;/p&gt;'), 'double');
    assert.equal(cleanText(null), '');
  });

  it('truncate kelime sınırında keser', () => {
    assert.equal(truncate('kısa', 10), 'kısa');
    const cut = truncate('one two three four five six', 15);
    assert.ok(cut.endsWith('…'));
    assert.ok(cut.length <= 16);
  });

  it('toIsoDate RFC 822 ve ISO tarihlerini çözer', () => {
    assert.equal(toIsoDate('Mon, 23 Nov 2026 16:00:00 +0000'), '2026-11-23T16:00:00.000Z');
    assert.equal(toIsoDate('2026-11-22T10:00:00Z'), '2026-11-22T10:00:00.000Z');
    assert.equal(toIsoDate('yesterday-ish'), null);
  });
});

describe('RSS ve Atom', () => {
  it('WordPress RSS akışını okur, tekrarı ve eskiyi atar', () => {
    const items = parseFeed(fixture('wordpress-rss.xml'), source, { now: NOW });
    assert.equal(items.length, 2);
    const [first, second] = items;
    assert.equal(first.title, 'Introducing Phi-5: a small model that reasons & codes');
    assert.equal(first.url, 'https://research.example.com/blog/phi-5');
    assert.match(first.excerpt, /^We release Phi-5, a 7B parameter model/);
    assert.doesNotMatch(first.excerpt, /appeared first/);
    assert.equal(first.publishedAt, '2026-11-23T16:00:00.000Z');
    assert.equal(second.title, 'A post without description');
    assert.equal(second.excerpt, '');
    assert.equal(second.publishedAt, '2026-11-22T10:00:00.000Z');
  });

  it('Blogger Atom akışında alternate bağlantıyı seçer ve HTML içeriği temizler', () => {
    const items = parseFeed(fixture('blogger-atom.xml'), { ...source, id: 'android-developers' }, { now: NOW });
    assert.equal(items.length, 2);
    assert.equal(items[0].title, "What's new in Jetpack Compose 2.0");
    assert.equal(items[0].url, 'https://android-developers.googleblog.com/2026/11/compose.html');
    assert.equal(items[0].excerpt, 'Compose 2.0 brings faster lists and new APIs.');
    assert.equal(items[1].excerpt, 'Short summary.');
  });

  it('maxItems sınırına uyar', () => {
    const items = parseFeed(fixture('wordpress-rss.xml'), { ...source, maxItems: 1 }, { now: NOW });
    assert.equal(items.length, 1);
  });

  it('tanınmayan biçimde hata verir', () => {
    assert.throws(() => parseFeed('<html><body>not a feed</body></html>', source, { now: NOW }));
  });
});

describe('Hacker News', () => {
  it('dış bağlantısı olmayanları atar ve puana göre sıralar', () => {
    const items = parseHackerNews(JSON.parse(fixture('hn.json')));
    assert.equal(items.length, 2);
    assert.equal(items[0].url, 'https://github.com/example/tinydb');
    assert.equal(items[0].points, 420);
    assert.equal(items[0].discussionUrl, 'https://news.ycombinator.com/item?id=46001');
  });
});

describe('Hugging Face', () => {
  it('trend modelleri Türkçe görev adıyla okur', () => {
    const models = parseTrendingModels(JSON.parse(fixture('hf-models.json')));
    assert.equal(models.length, 3);
    assert.equal(models[0].task, 'Görüntü bölütleme');
    assert.equal(models[0].modality, 'vision');
    assert.equal(models[0].license, 'apache-2.0');
    assert.equal(models[0].rank, 1);
    assert.equal(models[1].author, 'bigco');
    assert.equal(models[2].task, 'Görev belirtilmemiş');
  });

  it('bilinmeyen görev etiketi okunur hale gelir', () => {
    assert.deepEqual(describeTask('some-new-task'), { label: 'some new task', modality: 'other' });
  });

  it('model kartını sadeleştirir', () => {
    const card = cleanModelCard(
      '---\nlicense: mit\n---\n# Vision-Seg\n\n<p align="center"><img src="x.png"></p>\n\n' +
        '[Demo](https://a) | [Paper](https://b) | [Discord](https://c)\n\n' +
        'Join our Discord community to get help and chat with other users today!\n\n' +
        'Vision-Seg is a [promptable](https://x) segmentation model that segments any object in images and videos. ' +
        'It was trained on a large dataset of masks.\n\n## Usage\n\n```py\ncode()\n```\n\n| a | b |\n|---|---|\n',
    );
    assert.equal(
      card,
      'Vision-Seg is a promptable segmentation model that segments any object in images and videos. It was trained on a large dataset of masks.',
    );
  });

  it('günlük makaleleri okur, kimliği olmayanı atar', () => {
    const papers = parseDailyPapers(JSON.parse(fixture('hf-papers.json')));
    assert.equal(papers.length, 2);
    assert.equal(papers[0].url, 'https://huggingface.co/papers/2611.01234');
    assert.equal(papers[0].arxivUrl, 'https://arxiv.org/abs/2611.01234');
    assert.equal(papers[0].upvotes, 154);
    assert.equal(papers[0].githubUrl, 'https://github.com/example/seg3d');
    assert.deepEqual(papers[0].authors, ['Ada Lovelace', 'Alan Turing']);
    assert.equal(papers[1].comments, 2);
  });
});

describe('GitHub ve CISA', () => {
  it('çatalları atar ve yapay zekâ projelerini işaretler', () => {
    const repos = parseRepos(JSON.parse(fixture('github-search.json')));
    assert.equal(repos.length, 2);
    assert.equal(repos[0].isAi, true);
    assert.equal(repos[1].isAi, false);
  });

  it('KEV kayıtlarını tarihe göre sıralar ve fidye yazılımı bilgisini çözer', () => {
    const vulns = parseKev(JSON.parse(fixture('kev.json')));
    assert.equal(vulns.length, 2);
    assert.equal(vulns[0].cveId, 'CVE-2026-22222');
    assert.equal(vulns[0].ransomware, true);
    assert.equal(vulns[1].ransomware, false);
    assert.equal(vulns[1].nvdUrl, 'https://nvd.nist.gov/vuln/detail/CVE-2026-11111');
  });
});

describe('yedek konu belirleme', () => {
  it('tam kelime eşleşmesi kullanır', () => {
    assert.equal(classify('New ransomware hits hospitals', '', 'industry'), 'security');
    assert.equal(classify('Nvidia unveils new GPU', '', 'industry'), 'hardware');
    // "program" içinde "ram" geçer ama donanım sayılmamalı
    assert.equal(classify('A program for students', '', 'dev'), 'dev');
    assert.equal(classify('NASA launches a new Mars rover', '', 'industry'), 'science');
    assert.equal(classify('Kubernetes 1.40 adds new scheduler', '', 'industry'), 'cloud');
    assert.equal(classify('Hello', '', 'industry'), 'industry');
  });
});
