/// Uygulamanın derleme zamanı ayarları.
///
/// Veri adresi koda gömülü değildir; derlerken şöyle verilir:
/// `flutter run --dart-define=API_BASE_URL=https://kullanici.github.io/techpulse/v1/`
/// Verilmezse aşağıdaki varsayılan adres kullanılır.
abstract final class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://esmanuryildizhan.github.io/techpulse/v1/',
  );

  /// Ağ cevabı bu süreden yeniyse uygulama açılışında tekrar indirilmez.
  static const Duration cacheFreshness = Duration(minutes: 2);

  /// Veri bu süreden eskiyse kullanıcıya "güncellenemiyor" notu gösterilir.
  static const Duration staleAfter = Duration(hours: 6);

  /// Yükleme bu süreyi aşarsa "bağlantı yavaş" notu gösterilir.
  static const Duration slowLoadingAfter = Duration(seconds: 8);

  /// Haber görselleri ağdan yüklensin mi? Testler bunu kapatır; görsel yerine konuya özel kapak çizilir.
  static bool networkImages = true;

  static const String appName = 'TechPulse';
  static const String slogan = 'Teknoloji gündemi, anlaşılır Türkçeyle.';
  static const String appVersion = '3.0.0';
  static const String repositoryUrl = 'https://github.com/esmanuryildizhan/techpulse';
}
