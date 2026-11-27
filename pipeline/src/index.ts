import { anthropicClient, geminiClient, type LlmClient } from './llm.ts';
import { pythonTranslator } from './mt.ts';
import { runPipeline } from './pipeline.ts';
import { log } from './util.ts';

/**
 * Komut satırı girişi. GitHub Actions bu dosyayı saatte bir çalıştırır.
 * Ortam değişkenleri:
 *   GITHUB_TOKEN          GitHub arama API'si için (Actions'ta hazır gelir)
 *   PAGES_URL             Önceki yayının adresi, ör. https://kullanici.github.io/techpulse
 *   OUT_DIR               Çıktı klasörü (varsayılan: dist)
 *   MAX_TRANSLATION_TEXTS Bir çalışmada çevrilecek en fazla metin (varsayılan: 600)
 *   MT_DISABLED=1         Çeviriyi kapatır (ör. Python kurulu olmayan bir bilgisayarda deneme)
 *   MT_PYTHON, MT_MODEL   Python yorumlayıcısı ve çeviri modeli
 *   GEMINI_API_KEY        Varsa Türkçe metinleri Google Gemini yazar (Google AI Studio ücretsiz katmanı)
 *   GEMINI_MODELS         Sırayla kullanılacak Gemini modelleri, virgülle (varsayılan: gemini-3.5-flash-lite,gemini-3.1-flash-lite)
 *   AI_MAX_REQUESTS       Bir çalışmada Gemini'ye gönderilecek en fazla istek (varsayılan: 150)
 *   ANTHROPIC_API_KEY     Gemini anahtarı yoksa Türkçe metinleri Claude yazar; ikisi de yoksa OPUS-MT çevirir
 *   AI_PROVIDER           İkisi de tanımlıysa hangisi kullanılsın: gemini (varsayılan) veya anthropic
 *   AI_MODEL              Claude modeli (varsayılan: claude-haiku-5-5)
 *   AI_MAX_ITEMS          Bir çalışmada yazılacak en fazla kayıt (varsayılan: 150)
 *   AI_CONCURRENCY        Aynı anda yapılan istek sayısı (varsayılan: 4)
 */
/** Editörün dil modeli: Gemini anahtarı varsa Gemini (ücretsiz katman), yoksa Claude, ikisi de yoksa editör kapalı. */
function editorClient(): LlmClient | null {
  const gemini = process.env.GEMINI_API_KEY?.trim();
  const anthropic = process.env.ANTHROPIC_API_KEY?.trim();
  const preferAnthropic = process.env.AI_PROVIDER === 'anthropic';
  if (gemini && !(preferAnthropic && anthropic)) {
    const models = (process.env.GEMINI_MODELS ?? '').split(',').map((m) => m.trim()).filter(Boolean);
    return geminiClient({
      apiKey: gemini,
      models: models.length > 0 ? models : undefined,
      maxRequests: Number.parseInt(process.env.AI_MAX_REQUESTS || '150', 10),
    });
  }
  return anthropic ? anthropicClient({ apiKey: anthropic, model: process.env.AI_MODEL || undefined }) : null;
}

async function main(): Promise<void> {
  const started = Date.now();
  const llm = editorClient();
  const useMt = !llm && process.env.MT_DISABLED !== '1';
  const { meta } = await runPipeline({
    outDir: process.env.OUT_DIR ?? 'dist',
    previousBaseUrl: process.env.PAGES_URL || undefined,
    previousDir: process.env.PREVIOUS_DIR || undefined,
    token: process.env.GITHUB_TOKEN || undefined,
    translate: useMt ? pythonTranslator() : null,
    maxTranslationTexts: Number.parseInt(process.env.MAX_TRANSLATION_TEXTS ?? '600', 10),
    llm,
    aiMaxItems: Number.parseInt(process.env.AI_MAX_ITEMS || '150', 10),
    aiConcurrency: Number.parseInt(process.env.AI_CONCURRENCY || '6', 10),
  });

  const failed = meta.sources.filter((s) => !s.ok);
  log.info(`Tamamlandı (${((Date.now() - started) / 1000).toFixed(1)} sn).`);
  log.info(`Kayıtlar: ${JSON.stringify(meta.counts)}`);
  log.info(
    `Çeviri: model=${meta.translator.model ?? '-'}, metin=${meta.translator.requests}, ` +
      `çevrilen=${meta.translator.translatedItems}, bekleyen=${meta.translator.pendingItems}`,
  );
  log.info(
    `Editör: model=${meta.editor.model ?? '-'}, yazılan=${meta.editor.written}, başarısız=${meta.editor.failed}, ` +
      `bekleyen=${meta.editor.pending}, belirteç=${meta.editor.inputTokens}/${meta.editor.outputTokens}` +
      (meta.editor.note ? ` (${meta.editor.note})` : ''),
  );
  log.info(`Kaynaklar: ${meta.sources.length - failed.length}/${meta.sources.length} başarılı.`);
  for (const source of failed) log.warn(`  ${source.name}: ${source.error}`);

  if (meta.counts.news === 0 && meta.counts.security === 0) {
    // Hiç veri yoksa boş bir siteyi yayımlamaktansa iş akışını hatalı bitir.
    log.error('Hiç kayıt üretilemedi; yayın yapılmayacak.');
    process.exitCode = 1;
  }
}

main().catch((error) => {
  log.error(error);
  process.exitCode = 1;
});
