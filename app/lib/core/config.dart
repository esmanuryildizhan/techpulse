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

  /// Haber görselleri ağdan yüklensin mi? Testler bunu kapatır; görsel yerine konuya özel kapak çizilir.
  static bool networkImages = true;

  static const String appName = 'TechPulse';
  static const String slogan = 'Teknolojinin nabzı, cebinizde.';
  static const String appVersion = '2.0.0';
  static const String repositoryUrl = 'https://github.com/esmanuryildizhan/techpulse';
  static const String university = 'İstanbul Beykent Üniversitesi';
  static const String course = 'Mobil Uygulama Programlama';
  static const String instructor = 'Fuat Candan';
  static const List<String> authors = ['Esma Nur Yıldızhan', 'Zeynep Yaren Dalgıç'];
}
