import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../utils/storage_service.dart';
import 'api_exceptions.dart';

/// Dio wrapper used by every remote data source.
///
/// - Adds `Authorization: Bearer <access token>`.
/// - On 401 it calls POST /auth/refresh once (shared by parallel requests),
///   saves the new tokens and retries the request. If refreshing fails the
///   tokens are cleared and [sessionExpired] fires so the app returns to login.
/// - Maps Dio errors to [ApiException]s (timeout, no network, backend message).
class ApiClient {
  final Dio dio;
  final StorageService storageService;

  final _sessionExpiredController = StreamController<void>.broadcast();
  Future<bool>? _refreshing;

  /// Fires when the refresh token is missing/expired: the user must log in again.
  Stream<void> get sessionExpired => _sessionExpiredController.stream;

  ApiClient({required this.storageService, Dio? customDio})
      : dio = customDio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.baseUrl,
                connectTimeout: ApiConstants.connectTimeout,
                receiveTimeout: ApiConstants.receiveTimeout,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (_shouldRefresh(error) && await _refreshTokens()) {
            try {
              final retried = await _retry(error.requestOptions);
              return handler.resolve(retried);
            } on DioException catch (retryError) {
              error = retryError;
            }
          }
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: _handleDioError(error),
              response: error.response,
              type: error.type,
            ),
          );
        },
      ),
    );
  }

  bool _shouldRefresh(DioException error) {
    if (error.response?.statusCode != 401) return false;
    final options = error.requestOptions;
    // Never refresh for the auth calls themselves, and only retry a request once.
    if (options.path.startsWith('${ApiConstants.apiV1}/auth/') && options.path != ApiConstants.me) {
      return false;
    }
    return options.extra['retried'] != true;
  }

  /// Returns true when new tokens were saved. Parallel 401s share one refresh call.
  Future<bool> _refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = await storageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await _expireSession();
      return false;
    }
    try {
      // Separate Dio without interceptors, so a 401 here does not loop.
      final response = await Dio(dio.options).post(
        ApiConstants.refresh,
        data: {'refresh_token': refreshToken},
      );
      final data = response.data as Map<String, dynamic>;
      await storageService.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String?,
      );
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 422) {
        await _expireSession(); // refresh token expired or invalid
      }
      return false; // network problem: keep the tokens, the user can retry
    }
  }

  Future<void> _expireSession() async {
    await storageService.clearTokens();
    await storageService.clearUser();
    _sessionExpiredController.add(null);
  }

  Future<Response<dynamic>> _retry(RequestOptions options) async {
    final token = await storageService.getAccessToken();
    final headers = Map<String, dynamic>.from(options.headers);
    headers['Authorization'] = 'Bearer $token';
    return dio.fetch<dynamic>(
      options.copyWith(headers: headers, extra: {...options.extra, 'retried': true}),
    );
  }

  ApiException _handleDioError(DioException error) {
    if (error.error is ApiException) {
      return error.error as ApiException;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return TimeoutException();
    }

    if (error.type == DioExceptionType.connectionError) {
      return NetworkException(
        'Không thể kết nối đến máy chủ backend tại ${ApiConstants.baseUrl}. Vui lòng kiểm tra server hoặc mạng.',
      );
    }

    final response = error.response;
    if (response != null) {
      final statusCode = response.statusCode;
      final data = response.data;

      String message = 'Đã có lỗi xảy ra ($statusCode)';
      if (data is Map<String, dynamic>) {
        final apiError = data['error'];
        if (apiError is Map<String, dynamic> && apiError['message'] != null) {
          // Backend error format: {"error": {"code", "message", "details"}}
          message = apiError['message'].toString();
        } else if (data.containsKey('detail')) {
          message = data['detail'].toString();
        } else if (data.containsKey('message')) {
          message = data['message'].toString();
        }
      }

      if (statusCode == 401) {
        return UnauthorizedException(message);
      }
      return ApiException(message, statusCode: statusCode);
    }

    return NetworkException(error.message ?? 'Lỗi không xác định.');
  }

  Future<T> _send<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (e) {
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      throw _handleDioError(e);
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _send(() => dio.get(path, queryParameters: queryParameters, options: options));

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _send(() => dio.post(path, data: data, queryParameters: queryParameters, options: options));

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _send(() => dio.put(path, data: data, queryParameters: queryParameters, options: options));

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _send(() => dio.patch(path, data: data, queryParameters: queryParameters, options: options));

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) =>
      _send(() => dio.delete(path, data: data, queryParameters: queryParameters, options: options));

  void dispose() {
    _sessionExpiredController.close();
  }
}
