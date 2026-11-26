import 'package:dio/dio.dart';

/// Hatanın türü: kullanıcıya gösterilecek ekran ve öneri buna göre seçilir.
enum ErrorKind {
  /// Telefonda internet bağlantısı yok.
  offline,

  /// Bağlantı var ama sunucu zamanında yanıt vermedi.
  slow,

  /// Sunucu hata verdi (5xx) veya güvenli bağlantı kurulamadı.
  server,

  /// Dosya bulunamadı (404).
  notFound,

  /// Gelen veri okunamadı.
  data,

  unknown,
}

/// Kullanıcıya gösterilecek anlaşılır hata.
class AppException implements Exception {
  const AppException(this.message, {this.kind = ErrorKind.unknown});

  final String message;
  final ErrorKind kind;

  /// Bağlantı yok veya çok yavaş: çevrimdışı uyarısı gösterilir.
  bool get offline => kind == ErrorKind.offline || kind == ErrorKind.slow;

  @override
  String toString() => message;

  static AppException from(Object error) {
    if (error is AppException) return error;
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout || DioExceptionType.sendTimeout =>
          const AppException('Bağlantı çok yavaş; sunucu zamanında yanıt vermedi.', kind: ErrorKind.slow),
        DioExceptionType.connectionError ||
        DioExceptionType.unknown => const AppException('İnternet bağlantısı kurulamadı.', kind: ErrorKind.offline),
        DioExceptionType.badResponse =>
          error.response?.statusCode == 404
              ? const AppException('Veri henüz yayımlanmamış (404).', kind: ErrorKind.notFound)
              : AppException(
                  'Sunucu şu an yanıt vermiyor (${error.response?.statusCode ?? 0}).',
                  kind: ErrorKind.server,
                ),
        DioExceptionType.badCertificate => const AppException(
          'Güvenli bağlantı doğrulanamadı. Ağınız trafiği değiştiriyor olabilir.',
          kind: ErrorKind.server,
        ),
        DioExceptionType.cancel => const AppException('İstek iptal edildi.'),
        _ => const AppException('Veri alınamadı.'),
      };
    }
    if (error is FormatException) return const AppException('Gelen veri okunamadı.', kind: ErrorKind.data);
    return const AppException('Beklenmeyen bir hata oluştu.');
  }
}

/// Veri hattının yayınladığı JSON dosyalarını getiren arayüz. Testlerde sahtesi kullanılır.
abstract interface class DataSource {
  Future<String> getText(String path);
}

/// GitHub Pages üzerindeki statik JSON uçlarını HTTPS ile okur.
class HttpDataSource implements DataSource {
  HttpDataSource({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 25),
              responseType: ResponseType.plain,
              headers: const {'Accept': 'application/json'},
            ),
          );

  final Dio _dio;

  @override
  Future<String> getText(String path) async {
    try {
      // GitHub Pages dosyaları birkaç dakika önbellekte tutar; dakikalık bir parametre ile
      // kullanıcı yenilediğinde en güncel dosya gelir.
      final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
      final response = await _dio.get<String>(path, queryParameters: {'v': minute});
      final body = response.data;
      if (body == null || body.isEmpty) throw const AppException('Sunucudan boş cevap geldi.', kind: ErrorKind.data);
      return body;
    } catch (error) {
      throw AppException.from(error);
    }
  }
}
