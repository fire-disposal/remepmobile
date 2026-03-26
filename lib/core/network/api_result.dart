/// API请求结果封装
sealed class ApiResult<T> {
  const ApiResult();
}

class Success<T> extends ApiResult<T> {
  const Success(this.data);

  final T data;
}

class ApiFailure<T> extends ApiResult<T> {
  const ApiFailure({
    required this.message,
    this.statusCode,
    this.code,
  });

  final String message;
  final int? statusCode;
  final String? code;
}

/// 扩展方法
extension ApiResultExtension<T> on ApiResult<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is ApiFailure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message, int? statusCode, String? code) failure,
  }) {
    if (this is Success<T>) {
      final s = this as Success<T>;
      return success(s.data);
    }

    if (this is ApiFailure<T>) {
      final f = this as ApiFailure<T>;
      return failure(f.message, f.statusCode, f.code);
    }

    throw StateError('Unexpected ApiResult type');
  }

  T? get dataOrNull => when(
    success: (data) => data,
    failure: (_, __, ___) => null,
  );

  String? get errorMessageOrNull => when(
    success: (_) => null,
    failure: (message, _, __) => message,
  );
}