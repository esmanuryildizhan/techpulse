import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { errorMessage, log } from './util.ts';

/**
 * Makine çevirisi arayüzü. Asıl uygulama, aynı klasördeki Python betiğiyle
 * (mt/translate.py) açık kaynaklı OPUS-MT modelini çalıştırır. Testler sahtesini verir.
 */
export interface TranslationResult {
  model: string;
  translations: string[];
  seconds: number;
}

export type TranslateFn = (texts: string[]) => Promise<TranslationResult>;

export const DEFAULT_MODEL = 'Helsinki-NLP/opus-mt-tc-big-en-tr';

const SCRIPT = fileURLToPath(new URL('../mt/translate.py', import.meta.url));

/** Python betiğini bir kez çalıştırıp bütün metinleri tek seferde çevirir. */
export function pythonTranslator(options: { python?: string; timeoutMs?: number } = {}): TranslateFn {
  const python = options.python ?? process.env.MT_PYTHON ?? 'python3';
  const timeoutMs = options.timeoutMs ?? 20 * 60_000;
  return (texts) =>
    new Promise((resolve, reject) => {
      const child = spawn(python, [SCRIPT], { stdio: ['pipe', 'pipe', 'pipe'] });
      let stdout = '';
      const timer = setTimeout(() => {
        child.kill('SIGKILL');
        reject(new Error(`Çeviri ${Math.round(timeoutMs / 60000)} dakikada bitmedi`));
      }, timeoutMs);
      child.stdout.setEncoding('utf8');
      child.stdout.on('data', (chunk: string) => (stdout += chunk));
      child.stderr.setEncoding('utf8');
      child.stderr.on('data', (chunk: string) => {
        for (const line of chunk.split('\n')) if (line.trim()) log.info(`[çeviri] ${line.trim()}`);
      });
      child.on('error', (error) => {
        clearTimeout(timer);
        reject(error);
      });
      child.on('close', (code) => {
        clearTimeout(timer);
        if (code !== 0) {
          reject(new Error(`Çeviri betiği ${code} koduyla bitti`));
          return;
        }
        try {
          const parsed = JSON.parse(stdout) as Partial<TranslationResult>;
          if (!Array.isArray(parsed.translations) || parsed.translations.length !== texts.length) {
            throw new Error('Çeviri sayısı girdiyle eşleşmiyor');
          }
          resolve({
            model: String(parsed.model ?? DEFAULT_MODEL),
            translations: parsed.translations.map((t) => (typeof t === 'string' ? t : '')),
            seconds: Number(parsed.seconds ?? 0),
          });
        } catch (error) {
          reject(new Error(`Çeviri çıktısı okunamadı: ${errorMessage(error)}`));
        }
      });
      child.stdin.end(JSON.stringify({ texts }));
    });
}
