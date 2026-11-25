# TechPulse: Kurulum ve Kullanım Rehberi

Bu rehber, hiç mobil programlama bilmeyen biri için adım adım yazıldı.

## 1. Uygulamayı Android telefona kurmak (5 dakika)

1. Telefonun tarayıcısında şu adresi açın: **github.com/esmanuryildizhan/techpulse/releases/latest**
2. Sayfanın altındaki **Assets** bölümünde **TechPulse.apk** dosyasına dokunun ve indirin (yaklaşık 20 MB).
3. İndirme bitince bildirimden veya **Dosyalar → İndirilenler** klasöründen **TechPulse.apk** dosyasına dokunun.
4. Telefon "Bilinmeyen uygulamalar yüklenemez" ya da "Bu kaynaktan yüklemeye izin ver" derse **Ayarlar**'a dokunun, açılan sayfadaki anahtarı açın ve geri dönün.
5. **Yükle**'ye dokunun. Google Play Protect bir uyarı gösterirse **Yine de yükle** deyin. Uyarının nedeni uygulamanın Google Play'den değil, bizim derlememizden gelmesidir.
6. Uygulamayı açın. İlk açılışta internet gerekir; sonraki açılışlarda son veriler internetsiz de görünür.

**Güncelleme:** Yeni bir sürüm çıktığında aynı adımları tekrarlayın. Yeni APK eskisinin üstüne kurulur ve kaydedilenler silinmez.

**Telefonda kurulmazsa:** Çok eski (32 bit) bir telefonda aynı sayfadaki **TechPulse-32bit.apk** dosyasını deneyin.

## 2. Veriler nasıl güncelleniyor?

* GitHub Actions'taki **Veri hattı** iş akışı saatte bir (her saatin 17. dakikasında) kendiliğinden çalışır.
* Kaynakları okur, yeni haberleri Türkçeye çevirir ve sonucu şu adreste yayınlar: `https://esmanuryildizhan.github.io/techpulse/`
* **Elle çalıştırmak için:** GitHub'da depoyu açın → **Actions** → soldan **Veri hattı** → sağdaki **Run workflow** → yeşil **Run workflow** düğmesi.
* Uygulamada **Ayarlar → Kaynaklar ve durumları** ekranı, her kaynağın son çalışmada okunup okunamadığını gösterir.

## 3. Kodu bilgisayarda açmak ve çalıştırmak (isteğe bağlı, sunum için)

Kodun bir kopyası masaüstünüzdeki **TechPulse** klasöründe. Yalnızca okumak için **Visual Studio Code** yeterli. Uygulamayı bilgisayarda derleyip çalıştırmak isterseniz aşağıdakileri bir kez kurmanız gerekir (yarım gün sürebilir; çoğu indirme beklemesi):

1. **Git:** git-scm.com → Download for Windows → kurulumda hep **Next**.
2. **Flutter SDK 3.47.9:** docs.flutter.dev → Get started → Windows → Android. SDK arşivini **C:\dev\flutter** klasörüne açın (Program Files gibi boşluklu ya da Türkçe karakterli klasörlere değil).
3. **PATH'e ekleme:** Başlat menüsüne "ortam değişkenleri" yazın → **Sistem ortam değişkenlerini düzenleyin** → **Ortam Değişkenleri** → üstteki listede **Path** → **Düzenle** → **Yeni** → `C:\dev\flutter\bin` → Tamam.
4. **Android Studio:** developer.android.com/studio → kurun → ilk açılışta **Standard** kurulum. Sonra **More Actions → SDK Manager → SDK Tools** sekmesinde **Android SDK Command-line Tools** kutusunu işaretleyip **Apply**.
5. **Lisanslar:** Yeni bir PowerShell penceresinde `flutter doctor --android-licenses` yazın ve her soruya `y` deyin.
6. **Kontrol:** `flutter doctor` yazın. Flutter, Android toolchain ve Android Studio satırları yeşil tik almalı.
7. **VS Code:** code.visualstudio.com → kurun → sol menüde Extensions → **Flutter** eklentisini kurun.
8. **Çalıştırma:** VS Code'da **File → Open Folder → Masaüstü\TechPulse\app**. Terminalde (Ctrl+ö):
   ```
   flutter pub get
   flutter run
   ```
   Telefonunuzu USB ile bağlayın (telefonda Geliştirici seçenekleri → USB hata ayıklama açık) veya Android Studio'dan bir emülatör başlatın.

**Testleri çalıştırmak:** `flutter test --exclude-tags screenshots`

## 4. Kod değişince ne olur?

Kod GitHub'daki depoya gönderildiğinde **Uygulama** iş akışı kendiliğinden:

1. kodu analiz eder (`flutter analyze`),
2. birim ve arayüz testlerini çalıştırır,
3. ekran görüntülerini üretir,
4. APK'yı derler,
5. APK'yı Android emülatöründe açıp sekmeleri gezer ve çökme olup olmadığını kontrol eder,
6. her şey başarılıysa APK'yı **Releases → latest** sayfasına yükler.

## 5. Sık karşılaşılan sorunlar

| Sorun | Çözüm |
|---|---|
| Uygulama "İlk kullanım için internet gerekiyor" diyor | İnternete bağlanıp **Tekrar dene**'ye dokunun. |
| Listenin üstünde "Kaynak verisi … güncellendi; yeni veri bekleniyor" yazıyor | Veri hattı birkaç saattir çalışmamış. GitHub → Actions → Veri hattı'ndan son çalışmaya bakın veya elle çalıştırın. |
| Bir haberin başlığı İngilizce | Çevirisi bir sonraki saatlik çalışmada yapılır. |
| `flutter` komutu tanınmıyor | PATH adımını kontrol edin ve yeni bir terminal açın. |
