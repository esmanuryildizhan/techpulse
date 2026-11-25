import { runPipeline } from './pipeline.ts';
import { log } from './util.ts';

/**
 * Komut satırı girişi. GitHub Actions bu dosyayı saatte bir çalıştırır.
 * Ortam değişkenleri:
 *   GITHUB_TOKEN               GitHub Models ve GitHub arama API'si için (Actions'ta hazır gelir)
 *   PAGES_URL                  Önceki yayının adresi, ör. https://kullanici.github.io/techpulse
 *   OUT_DIR                    Çıktı klasörü (varsayılan: dist)
 *   MAX_TRANSLATION_REQUESTS   Bir çalışmadaki en fazla çeviri isteği (varsayılan: 30)
 *   TRANSLATOR_MODEL           Belirli bir modeli zorlamak için, ör. openai/gpt-4.1-mini
 */
async function main(): Promise<void> {
  const started = Date.now();
  const { meta } = await runPipeline({
    outDir: process.env.OUT_DIR ?? 'dist',
    previousBaseUrl: process.env.PAGES_URL || undefined,
    previousDir: process.env.PREVIOUS_DIR || undefined,
    token: process.env.GITHUB_TOKEN || undefined,
    maxTranslationRequests: Number.parseInt(process.env.MAX_TRANSLATION_REQUESTS ?? '30', 10),
    translatorModel: process.env.TRANSLATOR_MODEL || undefined,
  });

  const failed = meta.sources.filter((s) => !s.ok);
  log.info(`Tamamlandı (${((Date.now() - started) / 1000).toFixed(1)} sn).`);
  log.info(`Kayıtlar: ${JSON.stringify(meta.counts)}`);
  log.info(
    `Çeviri: model=${meta.translator.model ?? '-'}, istek=${meta.translator.requests}, ` +
      `çevrilen=${meta.translator.translatedItems}, bekleyen=${meta.translator.pendingItems}`,
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
