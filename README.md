# Bluelist IPTV

A production-ready Android IPTV app built with Flutter, powered by the Xtream Codes API.

## Architecture

**Clean Architecture** with a **feature-based** folder structure:

```
lib/
  core/           ← shared infrastructure (no feature logic)
    constants/    ← app-wide constants & route paths
    di/           ← dependency injection (GetIt service locator)
    errors/       ← Failure types & Dio→Failure error mapper
    network/      ← Dio client, interceptors, connectivity, retry, server config
    router/       ← GoRouter configuration with ShellRoute (bottom nav) + player routes
    theme/        ← Material 3 dark theme
    utils/        ← date/time formatting, stream URL builder
    widgets/      ← reusable UI: loading, error, empty, shimmer
  features/
    auth/         ← login, credentials storage, auto-restore
    live_tv/      ← Live TV categories & channels
    movies/       ← VOD categories, movies, movie details
    series/       ← Series categories, items, seasons, episodes
    epg/          ← Electronic Programme Guide (now/next, full)
    favorites/    ← Saved channels/movies/series (Hive local storage)
    search/       ← Unified search across all content
    player/       ← Video player (media_kit / libmpv)
```

Each feature follows the same three-layer split:

```
feature/
  data/
    datasources/    ← raw API calls (Dio)
    models/         ← JSON serialization (Phase 2+)
    repositories/   ← repository implementations
  domain/
    entities/       ← plain Dart value objects (Equatable)
    repositories/   ← abstract repository contracts
    usecases/       ← single-purpose use cases (Phase 2+)
  presentation/
    bloc/           ← flutter_bloc state management
    pages/          ← full screen widgets
    widgets/        ← feature-specific UI components
```

## Tech Stack

| Concern              | Package                     |
|----------------------|-----------------------------|
| State management     | `flutter_bloc`              |
| HTTP                 | `dio`                       |
| Dependency injection | `get_it`                    |
| Navigation           | `go_router`                 |
| Local storage        | `hive`                      |
| Video player         | `media_kit` (libmpv)        |
| Image caching        | `cached_network_image`      |
| Error handling       | `dartz` (Either)            |
| Connectivity          | `connectivity_plus`         |
| Logging              | `logger`                    |

## Build Phases

| Phase | Scope                                           | Status       |
|-------|-------------------------------------------------|--------------|
| 1     | Project setup, core architecture, Xtream API    | ✅ Complete   |
| 2     | Video player integration (media_kit)            | ✅ Complete   |
| 3     | Live TV feature (categories, channels, EPG)     | ✅ Complete   |
| 4     | Movies feature (categories, grid, details)      | ✅ Complete   |
| 5     | Series feature (categories, grid, seasons)      | ✅ Complete   |
| 6     | Favorites (local storage, toggle, list)         | ✅ Complete   |
| 7     | Search (unified, debounced)                      | ✅ Complete   |
| 8     | Polish (smooth scrolling, reconnection, QA)     | ⬜ Pending    |

## Getting Started

```bash
cd bluelist_iptv
flutter pub get
flutter run
```

Enter your Xtream Codes server URL, username, and password on the login screen.
