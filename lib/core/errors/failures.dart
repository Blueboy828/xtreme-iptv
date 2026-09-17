/// Base failure class representing domain-level errors.
///
/// Uses a `message` field for human-readable descriptions and
/// an optional `code` for programmatic handling.
sealed class Failure {
  final String message;
  final int? code;

  const Failure({required this.message, this.code});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          code == other.code;

  @override
  int get hashCode => message.hashCode ^ code.hashCode;
}

/// Failure for network-related errors (no connectivity, timeout, DNS, etc.).
class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'No internet connection', super.code});
}

/// Failure returned when the server responds with a non-2xx status.
class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Server error occurred',
    super.code,
  });
}

/// Failure for invalid Xtream Codes credentials.
class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Invalid username or password',
    super.code = 401,
  });
}

/// Failure when a requested resource is not found.
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Resource not found',
    super.code = 404,
  });
}

/// Failure for JSON parsing / serialization errors.
class ParseFailure extends Failure {
  const ParseFailure({
    super.message = 'Failed to parse server response',
    super.code,
  });
}

/// Failure for unexpected errors not covered by other types.
class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'Something went wrong',
    super.code,
  });
}
