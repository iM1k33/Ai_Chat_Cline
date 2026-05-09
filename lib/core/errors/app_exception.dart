class AppException implements Exception {
  const AppException(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  String toString() {
    final StringBuffer buffer = StringBuffer('AppException: $message');

    if (code != null && code!.isNotEmpty) {
      buffer.write(' (code: $code)');
    }

    if (cause != null) {
      buffer.write(' | cause: $cause');
    }

    return buffer.toString();
  }
}
