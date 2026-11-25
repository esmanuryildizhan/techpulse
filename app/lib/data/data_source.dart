import 'package:dio/dio.dart';

/// Kullanıcıya gösterilecek anlaşılır hata.
class AppException implements Exception {
  const AppException(this.message, {this.offline = false});

  final String message;

  /// Bağlantı yok veya zaman aşımı: çevrimdışı uyarısı gösterilir.
  final bool offline;

  @override
  String toString() => message;

  static AppException from(Object error) {
    if (error is AppException) return error;
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.unknown =>
          const AppException('İnternet bağlantısı kurulamadı.', offline: true),
        DioExceptionType.badResponse => error.response?.statusCode == 404
            ? const AppException('Veri henüz yayınlanmamış (404).')
            : AppException('Sunucu hata verdi (${error.response?.statusCode ?? 0}).'),
        DioExceptionType.badCertificate => const AppException('Güvenli bağlantı doğrulanamadı.'),
        DioExceptionType.cancel => const AppException('İstek iptal edildi.'),
        _ => const AppException('Veri alınamadı.'),
      };
    }
    if (error is FormatException) return const AppException('Gelen veri okunamadı.');
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
      : _dio = dio ??
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
      if (body == null || body.isEmpty) throw const AppException('Sunucudan boş cevap geldi.');
      return body;
    } catch (error) {
      throw AppException.from(error);
    }
  }
}
