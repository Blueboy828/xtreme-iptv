import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/xtream_auth_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final XtreamAuthDatasource _datasource;

  AuthRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, AuthResult>> authenticate({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    try {
      final data = await _datasource.authenticate(
        baseUrl: baseUrl,
        username: username,
        password: password,
      );

      final userInfoRaw = data['user_info'] as Map<String, dynamic>;
      final serverInfoRaw = data['server_info'] as Map<String, dynamic>?;

      final userInfo = UserInfo(
        username: userInfoRaw['username']?.toString() ?? username,
        password: userInfoRaw['password']?.toString(),
        status: userInfoRaw['status']?.toString(),
        expDate: userInfoRaw['exp_date']?.toString(),
        maxConnections: userInfoRaw['max_connections']?.toString(),
        active: userInfoRaw['status']?.toString().toLowerCase() == 'active',
      );

      final serverInfo = ServerInfo(
        url: serverInfoRaw?['url']?.toString() ?? '',
        port: serverInfoRaw?['port']?.toString(),
        httpsPort: serverInfoRaw?['https_port']?.toString(),
        serverProtocol: serverInfoRaw?['server_protocol']?.toString(),
        timezone: serverInfoRaw?['timezone']?.toString(),
        timestampNow: int.tryParse(
          serverInfoRaw?['timestamp_now']?.toString() ?? '',
        ),
        timestampAvailable: int.tryParse(
          serverInfoRaw?['timestamp_available']?.toString() ?? '',
        ),
      );

      // Persist credentials for auto-login on next launch.
      await saveCredentials(
        XtreamCredentials(
          baseUrl: baseUrl,
          username: username,
          password: password,
        ),
      );

      return Right(AuthResult(userInfo: userInfo, serverInfo: serverInfo));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<XtreamCredentials?> getStoredCredentials() async {
    final box = Hive.box(AppConstants.credentialsBox);
    final url = box.get('baseUrl') as String?;
    final user = box.get('username') as String?;
    final pass = box.get('password') as String?;

    if (url != null && user != null && pass != null) {
      return XtreamCredentials(
        baseUrl: url,
        username: user,
        password: pass,
      );
    }
    return null;
  }

  @override
  Future<void> saveCredentials(XtreamCredentials credentials) async {
    final box = Hive.box(AppConstants.credentialsBox);
    await box.put('baseUrl', credentials.baseUrl);
    await box.put('username', credentials.username);
    await box.put('password', credentials.password);
  }

  @override
  Future<void> clearCredentials() async {
    final box = Hive.box(AppConstants.credentialsBox);
    await box.clear();
  }
}
