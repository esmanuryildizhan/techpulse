# TechPulse

**Teknoloji ve yapay zekâ gündemi, Türkçe.** Yazılımcıların, mühendislik öğrencilerinin ve teknoloji meraklılarının İngilizce kaynaklarda olup biteni tek bir yerden, Türkçe ve kaynağını göstererek takip etmesi için geliştirilmiş bir Android uygulaması (Flutter).

İstanbul Beykent Üniversitesi · Mobil Uygulama Programlama dersi projesi
Ders sorumlusu: Fuat Candan · Geliştirenler: Esma Nur Yıldızhan, Zeynep Yaren Dalgıç

## Uygulamayı telefona kurmak

1. Telefonda bu sayfanın **Releases** bölümündeki `latest` sürümünü açın.
2. `TechPulse.apk` dosyasını indirin ve açın.
3. Telefon "bilinmeyen kaynaklardan yükleme" izni isterse tarayıcınıza bu izni verin.

Ayrıntılı kurulum, bilgisayarda çalıştırma ve sorun giderme: [docs/KURULUM.md](docs/KURULUM.md)

## Ne yapar?

| Sekme | İçerik |
|---|---|
| **Akış** | "Sizin İçin" (seçilen ilgi alanları) ve "Tüm Gündem" görünümleri; konu, zaman (son 1 saat – 30 gün) ve sıralama filtresi; günün manşeti, "Kısaca" şeridi, zamana göre "Son gelişmeler" |
| **Keşfet** | Arama, şu an popüler haberler, gündemdeki konular, dokuz konu |
| **Radar** | Hugging Face'te öne çıkan modeller ve makaleler, GitHub'da yükselen yeni projeler (README'ye dayanan Türkçe tanıtımla), CISA'nın aktif istismar listesindeki açıklar |
| **Kaydedilen** | İnternetsiz de açılan kayıtlar |
| **Profil** | Ad, ilgi alanları, tema (Sistem/Açık/Koyu), uygulama rengi, yazı boyutu, okuma geçmişi, veri silme |

Her haberde: 30 saniyelik özet, "Bu gelişme neden önemli?", sade anlatım / teknik derinlik geçişi, metinde altı çizili kavramların açıklaması (tanım, benzetme, kullanım alanı, geliştiren), okuma ilerlemesi, yazı boyutu, kaynak bağlantısını açmadan görme ve kopyalama.

Kaynaklar: OpenAI, Google AI, Google DeepMind, Microsoft Research, NVIDIA, Hugging Face, GitHub, AWS, Android ve Flutter blogları; The Verge, TechCrunch, Ars Technica, Tom's Hardware, BleepingComputer, The Hacker News; Hacker News; Hugging Face Hub ve Daily Papers; GitHub Search API; CISA KEV.

Telif: Uygulama haberi kopyalamaz; kaynağı okuyup kendi cümleleriyle Türkçe anlatır, yayıncıyı ve bağlantıyı her zaman gösterir. Kaynak yalnızca kısa bir bölüm yayımlıyorsa bu, haber sayfasında belirtilir.

## Mimari

```
Kaynaklar (RSS/Atom, Hacker News, Hugging Face, GitHub, CISA)
        │  saatte bir
        ▼
GitHub Actions: pipeline/ (Node.js 24 + TypeScript)
  topla → temizle → tekilleştir → konu belirle → haber metnini / README'yi oku
  → yapay zekâ editörü (Claude Haiku 5.5, yapılandırılmış çıktı) Türkçe yazar → doğrula
        │
        ▼
GitHub Pages: statik JSON API (v1/news.json, models.json, papers.json, repos.json, security.json, meta.json)
        │  HTTPS
        ▼
Flutter uygulaması: app/ (Riverpod 3, dio, sqflite)
  önce önbellek, sonra ağ · çevrimdışı çalışma · kaydedilenler ve okuma geçmişi telefonda
```

* Uygulamada hiçbir API anahtarı yoktur. Anahtar yalnızca GitHub Actions'ın şifreli sırlarında (`ANTHROPIC_API_KEY`) durur.
* Editör her kaydı bir kez yazar; yazılan metin bir sonraki çalışmada yeniden kullanılır. Bir kaynak çökerse diğerleri çalışmaya devam eder; editör bir kaydı yazamazsa kayıt kısa özetiyle yayımlanır ve sonraki saatte yeniden denenir.
* Yayımlanan her kayıt şemaya göre doğrulanır; bozuk veri uygulamaya ulaşmaz.

## Klasörler

| Klasör | İçerik |
|---|---|
| `app/` | Flutter uygulaması (`lib/`, `test/`) |
| `pipeline/` | Veri hattı (`src/`, `test/`) |
| `tools/` | Android ayar betiği, emülatör denemesi, CI çıktı betiği |
| `docs/` | Kurulum ve kullanım rehberi |
| `.github/workflows/` | `data.yml` (saatlik veri), `app.yml` (derleme, test, APK) |

## Geliştirme

```bash
# Veri hattı
cd pipeline && npm ci && npm test

# Uygulama (Flutter 3.47)
cd app && flutter pub get && flutter test --exclude-tags screenshots && flutter run
```
