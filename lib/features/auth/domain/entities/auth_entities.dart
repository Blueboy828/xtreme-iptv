import 'package:equatable/equatable.dart';

/// Domain entity representing a logged-in user and server connection.
class XtreamCredentials extends Equatable {
  final String baseUrl;
  final String username;
  final String password;

  const XtreamCredentials({
    required this.baseUrl,
    required this.username,
    required this.password,
  });

  @override
  List<Object> get props => [baseUrl, username, password];
}

/// Domain entity representing authenticated user info from Xtream API.
class UserInfo extends Equatable {
  final String username;
  final String? password;
  final String? status;        // "Active"
  final String? expDate;       // expiry timestamp
  final String? maxConnections;
  final bool active;

  const UserInfo({
    required this.username,
    this.password,
    this.status,
    this.expDate,
    this.maxConnections,
    this.active = true,
  });

  @override
  List<Object?> get props => [username, status, expDate, active];
}

/// Domain entity representing server info from Xtream API.
class ServerInfo extends Equatable {
  final String url;
  final String? port;
  final String? httpsPort;
  final String? serverProtocol;
  final String? timezone;
  final int? timestampNow;
  final int? timestampAvailable;

  const ServerInfo({
    required this.url,
    this.port,
    this.httpsPort,
    this.serverProtocol,
    this.timezone,
    this.timestampNow,
    this.timestampAvailable,
  });

  @override
  List<Object?> get props => [url, port, timezone];
}

/// Combined auth result after a successful login.
class AuthResult extends Equatable {
  final UserInfo userInfo;
  final ServerInfo serverInfo;

  const AuthResult({
    required this.userInfo,
    required this.serverInfo,
  });

  @override
  List<Object> get props => [userInfo, serverInfo];
}
