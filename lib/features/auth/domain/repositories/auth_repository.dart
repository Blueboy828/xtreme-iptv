import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/auth_entities.dart';

/// Contract for authentication operations.
abstract class AuthRepository {
  /// Authenticates against the Xtream Codes server.
  /// Returns [AuthResult] on success or [Failure] on error.
  Future<Either<Failure, AuthResult>> authenticate({
    required String baseUrl,
    required String username,
    required String password,
  });

  /// Restores credentials from local storage (Hive).
  Future<XtreamCredentials?> getStoredCredentials();

  /// Saves credentials to local storage.
  Future<void> saveCredentials(XtreamCredentials credentials);

  /// Clears stored credentials (logout).
  Future<void> clearCredentials();
}
