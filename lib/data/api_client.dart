import 'package:dio/dio.dart';

import '../core/config.dart';

class ApiClient {
  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.baseUrl,
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final t = token;
          if (t != null) options.headers['Authorization'] = 'Bearer $t';
          handler.next(options);
        },
        onError: (e, handler) {
          if (e.response?.statusCode == 401 && token != null) {
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
  }

  final Dio dio;
  String? token;

  /// Dipanggil ketika server menolak token (kedaluwarsa / tidak valid).
  void Function()? onUnauthorized;
}

/// true bila error karena tidak ada koneksi / server tidak terjangkau.
bool isNetworkError(Object e) {
  if (e is! DioException) return false;
  return e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout;
}

/// Pesan error yang ramah untuk ditampilkan ke pengguna.
String errorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (isNetworkError(e)) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
    }
    return 'Terjadi kesalahan (${e.response?.statusCode ?? 'tanpa respons'})';
  }
  return e.toString().replaceFirst('Exception: ', '');
}
