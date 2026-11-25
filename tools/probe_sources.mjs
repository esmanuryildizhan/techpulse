const UA = 'Mozilla/5.0 (compatible; TechPulseBot/1.0; +https://github.com/esmanuryildizhan/techpulse)';
const feeds = process.argv.slice(2);
const out = [];
async function get(url) {
  const ctl = new AbortController(); const t = setTimeout(() => ctl.abort(), 20000);
  try { const r = await fetch(url, { headers: { 'User-Agent': UA, Accept: '*/*' }, redirect: 'follow', signal: ctl.signal }); const text = await r.text(); return { status: r.status, text, url: r.url }; }
  catch (e) { return { status: 0, text: '', error: String(e) }; } finally { clearTimeout(t); }
}
function firstLink(xml) {
  const m = xml.match(/<item[\s>][\s\S]*?<link>([^<]+)<\/link>/) || xml.match(/<entry[\s>][\s\S]*?<link[^>]*href="([^"]+)"/);
  return m ? m[1].trim().replace(/&amp;/g, '&') : null;
}
for (const f of feeds) {
  const r = await get(f);
  const items = (r.text.match(/<item[\s>]|<entry[\s>]/g) || []).length;
  const imgTags = ['media:content', 'media:thumbnail', '<enclosure', '<img ', 'content:encoded'].filter((t) => r.text.includes(t));
  const link = firstLink(r.text);
  let art = null;
  if (link) {
    const a = await get(link);
    const og = (a.text.match(/<meta[^>]+property=["']og:image["'][^>]*>/i) || [''])[0].slice(0, 160);
    const paras = (a.text.match(/<p[\s>][\s\S]*?<\/p>/gi) || []).map((p) => p.replace(/<[^>]+>/g, '')).join(' ').length;
    art = { link, status: a.status, og: og ? 'yes' : 'no', ogTag: og, paragraphChars: paras };
  }
  out.push({ feed: f, status: r.status, items, imgTags, err: r.error, art });
  console.log(JSON.stringify(out.at(-1)));
}
