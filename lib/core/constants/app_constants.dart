/// Global app-wide constants for Xtreme IPTV.
class AppConstants {
  AppConstants._();

  /// App name shown in UI.
  static const String appName = 'Xtreme IPTV';

  /// Default connection timeout for HTTP requests.
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Default receive timeout for HTTP requests.
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Maximum retry attempts for failed network requests.
  static const int maxRetries = 3;

  /// Base delay for exponential backoff between retries.
  /// Delay = baseDelay * 2^attempt (1s, 2s, 4s, ...).
  static const Duration retryBaseDelay = Duration(seconds: 1);

  /// Maximum delay cap for exponential backoff.
  static const Duration retryMaxDelay = Duration(seconds: 10);

  /// Hive box name for favorites.
  static const String favoritesBox = 'favorites_box';

  /// Hive box name for cached server credentials.
  static const String credentialsBox = 'credentials_box';

  /// Page size for paginated content lists.
  static const int defaultPageSize = 50;

  /// Debounce duration for search input.
  static const Duration searchDebounce = Duration(milliseconds: 400);

  /// Maximum reconnection attempts for player streams.
  static const int maxPlayerReconnects = 5;

  /// Base delay for player reconnection backoff.
  static const Duration playerReconnectBaseDelay = Duration(seconds: 2);

  /// Grid scroll cache extent for smooth pre-rendering.
  static const double gridCacheExtent = 500;

  /// List scroll cache extent for smooth pre-rendering.
  static const double listCacheExtent = 600;
}
