import { CATEGORY_INFO } from './categories.ts';
import type { Category, FeedSource } from './types.ts';

/**
 * Kural tabanlı konu belirleyici. Her konunun anahtar kelimeleri başlıkta 3, açıklamada 1 puan alır;
 * en yüksek puan 3 veya üzerindeyse o konu seçilir, değilse kaynağın varsayılan konusu kullanılır.
 * Kelimeler tam kelime olarak aranır: "RAM" kelimesi "program" içinde bulunmaz.
 */
const RULES: Record<Category, string[]> = Object.fromEntries(CATEGORY_INFO.map((c) => [c.id, c.keywords])) as Record<
  Category,
  string[]
>;

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

const COMPILED = Object.fromEntries(
  Object.entries(RULES).map(([category, words]) => [
    category,
    words.map((word) => new RegExp(`(?<![\\p{L}\\p{N}])${escapeRegExp(word)}(?![\\p{L}\\p{N}])`, 'iu')),
  ]),
) as Record<Category, RegExp[]>;

export function classify(title: string, excerpt: string, fallback: Category): Category {
  let best: Category = fallback;
  let bestScore = 0;
  for (const category of Object.keys(COMPILED) as Category[]) {
    let score = 0;
    for (const pattern of COMPILED[category]) {
      if (pattern.test(title)) score += 3;
      if (pattern.test(excerpt)) score += 1;
    }
    // Eşitlikte kaynağın varsayılan konusu kazanır.
    if (score > bestScore || (score === bestScore && score > 0 && category === fallback)) {
      best = category;
      bestScore = score;
    }
  }
  return bestScore >= 3 ? best : fallback;
}

/** Başlık ve açıklamadaki teknoloji kelimelerinin toplam puanı (başlık 3, açıklama 1). */
export function techScore(title: string, excerpt: string): number {
  let score = 0;
  for (const category of Object.keys(COMPILED) as Category[]) {
    for (const pattern of COMPILED[category]) {
      if (pattern.test(title)) score += 3;
      if (pattern.test(excerpt)) score += 1;
    }
  }
  return score;
}

const PROMOTION =
  /(\bdeals?\b|\bsave \$|\$\d[\d,.]*\s*off\b|\b\d+% off\b|black friday|cyber monday|prime day|gift guide|holiday gifts?|\bcoupons?\b|promo code|\bon sale\b|\bbest .+ to buy\b)/i;

/**
 * Geliştirici kitlesi için ilgisiz içerikleri ayıklar: indirim/alışveriş yazıları her kaynaktan,
 * genel haber sitelerinin (The Verge, TechCrunch, Ars Technica) teknolojiyle ilgisi olmayan
 * yazıları (dizi, film, oyun incelemesi vb.) ise teknoloji kelimesi içermiyorsa elenir.
 */
export function isPromotion(title: string): boolean {
  return PROMOTION.test(title);
}

export function isRelevant(title: string, excerpt: string, source: FeedSource | undefined): boolean {
  if (PROMOTION.test(title)) return false;
  if (source && source.kind === 'news' && source.defaultCategory === 'industry') {
    return techScore(title, excerpt) > 0;
  }
  return true;
}
