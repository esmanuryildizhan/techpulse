# TechPulse

**Teknoloji ve yapay zekâ gündemi, Türkçe.** Yazılımcıların, mühendislik öğrencilerinin ve teknoloji meraklılarının İngilizce kaynaklarda olup biteni tek bir yerden, Türkçe ve kaynağını göstererek takip etmesi için geliştirilmiş bir Android uygulaması (Flutter).

İstanbul Beykent Üniversitesi · Mobil Uygulama Programlama dersi projesi
Ders sorumlusu: Fuat Candan · Geliştirenler: Esma Nur Yıldızhan, Zeynep Yaren Dalgıç

## Uygulamayı telefona kurmak

1. Telefonda bu sayfanın **Releases** bölümündeki `latest` sürümünü açın.
2. `TechPulse.apk` dosyasını indirin ve açın.
3. Telefon "bilinmeyen kaynaklardan yükleme" izni isterse tarayıcınıza bu izni verin.

## Ne yapar?

| Bölüm | İçerik | Kaynak |
|---|---|---|
| **Gündem** | Haber başlıkları ve 2-3 cümlelik Türkçe özetler; konu filtresi (Yapay Zekâ, Yazılım, Donanım, Güvenlik, Sektör) | OpenAI, Google AI, Google DeepMind, Microsoft Research, NVIDIA, Hugging Face, GitHub, AWS, Android ve Flutter blogları; The Verge, TechCrunch, Ars Technica, Tom's Hardware, BleepingComputer, The Hacker News; Hacker News |
| **YZ Radarı** | Hugging Face'te trend olan modeller (görev, beğeni, indirme, parametre), günün öne çıkan makaleleri (Türkçe özet), GitHub'da son 7 günün yükselen projeleri | Hugging Face Hub API, Hugging Face Daily Papers, GitHub Search API |
| **Güvenlik** | Saldırganların şu an kullandığı açıklar | CISA Known Exploited Vulnerabilities (KEV) |
| **Kaydedilenler** | İnternetsiz de açılan yer imleri | Telefondaki SQLite |

Telif: Uygulama haberin tamamını yayımlamaz; yalnızca başlık, kaynağın kısa açıklamasından üretilen Türkçe özet, kaynak adı ve bağlantı gösterir. Haberin tamamı her zaman yayıncının sitesinde açılır.

## Mimari

```
Kaynaklar (RSS/Atom, Hacker News, Hugging Face, GitHub, CISA)
        │  saatte bir
        ▼
GitHub Actions: pipeline/ (Node.js 24 + TypeScript)
  topla → temizle → tekilleştir → konu belirle → OPUS-MT ile Türkçeye çevir → doğrula
        │
        ▼
GitHub Pages: statik JSON API (v1/news.json, models.json, papers.json, repos.json, security.json, meta.json)
        │  HTTPS
        ▼
Flutter uygulaması: app/ (Riverpod 3, dio, sqflite)
  önce önbellek, sonra ağ · çevrimdışı çalışma · yer imleri
```

* Uygulamada hiçbir API anahtarı yoktur. Çeviri, Helsinki Üniversitesi'nin açık kaynaklı İngilizce→Türkçe modeliyle ([OPUS-MT, opus-mt-tc-big-en-tr](https://huggingface.co/Helsinki-NLP/opus-mt-tc-big-en-tr), CC BY 4.0) doğrudan GitHub Actions sunucusunda yapılır; dış bir yapay zekâ servisine bağımlı değildir.
* Bir kaynak çökerse diğerleri çalışmaya devam eder; çeviri yapılamazsa kayıtlar özgün başlıklarıyla yayımlanır ve bir sonraki saatte yeniden denenir.
* Yayımlanan her kayıt şemaya göre doğrulanır; bozuk veri uygulamaya ulaşmaz.

## Klasörler

| Klasör | İçerik |
|---|---|
| `app/` | Flutter uygulaması (`lib/`, `test/`) |
| `pipeline/` | Veri hattı (`src/`, `test/`) |
| `tools/` | Android ayar betiği ve emülatör denemesi |
| `.github/workflows/` | `data.yml` (saatlik veri), `app.yml` (derleme, test, APK) |

## Geliştirme

```bash
# Veri hattı
cd pipeline && npm ci && npm test

# Uygulama (Flutter 3.47)
cd app && flutter pub get && flutter test --exclude-tags screenshots && flutter run
```
