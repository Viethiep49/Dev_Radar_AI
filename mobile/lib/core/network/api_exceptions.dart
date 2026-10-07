class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  NetworkException([super.message = 'Không có kết nối mạng hoặc server không phản hồi.']);
}

class TimeoutException extends ApiException {
  TimeoutException([super.message = 'Yêu cầu kết nối quá thời gian chờ (Timeout).']);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([super.message = 'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.'])
      : super(statusCode: 401);
}
