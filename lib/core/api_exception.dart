/// Every failure the API layer surfaces. Callers never see a raw
/// `FormatException`, `SocketException`, or `http` error — but the original is
/// preserved in [cause] so logs stay diagnosable.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  /// A bad key will never fix itself, so these are not retried.
  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' (HTTP $statusCode)';
    final because = cause == null ? '' : ': $cause';
    return 'ApiException: $message$code$because';
  }
}
