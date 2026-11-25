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
      switch (error.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return const AppException('İnternet bağlantısı kurulamadı.', offline: true);
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 0;
          if (code == 404) return const AppException('Veri henüz yayınlanmamış (404).');
          return AppException('Sunucu hata verdi ($code).');
        case DioExceptionType.cancel:
          return const AppException('İstek iptal edildi.');
        case DioExceptionType.badCertificate:
          return const AppException('Güvenli bağlantı doğrulanamadı.');
        case DioExceptionType.unknown:
          return const AppException('İnternet bağlantısı kurulamadı.', offline: true);
      }
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
