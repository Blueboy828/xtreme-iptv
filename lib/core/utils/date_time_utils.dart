import 'package:intl/intl.dart';

/// Utility for formatting EPG / metadata time strings.
///
/// Xtream panels return EPG timestamps like "2026-09-14 21:00:00" with no
/// timezone attached. Some panels use UTC, others use the panel's own local
/// clock. To make the guide match what is actually on screen, the app
/// calibrates itself: the short-EPG response tells us which program the
/// server says is on RIGHT NOW, so we find the clock offset that puts the
/// current time inside that program's window, and use it for all EPG times.
class DateTimeUtils {
  DateTimeUtils._();

  /// Offset (in minutes) added to a raw EPG timestamp to get true UTC.
  static int _epgOffsetMinutes = 0;

  /// True once calibration succeeded against a server-confirmed "now" entry.
  static bool _epgCalibrated = false;

  /// Calibrates the EPG clock using the program the server says is on now.
  ///
  /// [nowStart]/[nowEnd] are the raw timestamps of the CURRENT program
  /// (the first entry of a get_short_epg response). We look for the offset
  /// that places the actual current time inside that window.
  static void calibrateEpgClock(String? nowStart, String? nowEnd) {
    if (_epgCalibrated || nowStart == null || nowEnd == null) return;
    if (nowStart.isEmpty || nowEnd.isEmpty) return;

    final start = _parseAsUtc(nowStart);
    final end = _parseAsUtc(nowEnd);
    if (start == null || end == null || !end.isAfter(start)) return;

    final utcNow = DateTime.now().toUtc();

    bool matches(int offsetMinutes) {
      final s = start.add(Duration(minutes: offsetMinutes));
      final e = end.add(Duration(minutes: offsetMinutes));
      return !utcNow.isBefore(s) && utcNow.isBefore(e);
    }

    // Most common case: the panel already uses UTC.
    if (matches(0)) {
      _epgOffsetMinutes = 0;
      _epgCalibrated = true;
      return;
    }

    // Scan plausible timezone offsets (UTC-15h .. UTC+15h, 30-min steps).
    for (var off = -900; off <= 900; off += 30) {
      if (off == 0) continue;
      if (matches(off)) {
        _epgOffsetMinutes = off;
        _epgCalibrated = true;
        return;
      }
    }

    // No offset matched (provider EPG may be mapped to a wrong window).
    // Keep current settings and retry on a later fetch.
  }

  /// Parses "2026-09-14 21:00:00" as a UTC instant, ignoring any zone
  /// Dart may guess — these strings carry no timezone information at all.
  static DateTime? _parseAsUtc(String timestamp) {
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return null;
    return DateTime.utc(
      dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second,
    );
  }

  /// Converts a raw EPG timestamp into the user's LOCAL time.
  /// Returns null if the string can't be parsed.
  static DateTime? parseEpgDateTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return null;
    final utc = _parseAsUtc(timestamp);
    if (utc == null) return null;
    return utc.add(Duration(minutes: _epgOffsetMinutes)).toLocal();
  }

  /// True if the program with this raw end-timestamp has already finished.
  /// Used to detect stale "now playing" data that needs a refresh.
  static bool epgEntryEnded(String? endTimestamp) {
    final localEnd = parseEpgDateTime(endTimestamp);
    if (localEnd == null) return false;
    return DateTime.now().isAfter(localEnd);
  }

  /// Parses an Xtream EPG timestamp into a human-readable local time,
  /// e.g. "2:00 PM".
  static String formatEpgTime(String? timestamp) {
    final local = parseEpgDateTime(timestamp);
    if (local == null) return '--';
    return DateFormat('h:mm a').format(local);
  }

  /// Returns the formatted start-end range for an EPG entry.
  static String formatEpgRange(String? start, String? end) {
    if (start == null || end == null || start.isEmpty || end.isEmpty) {
      return 'No EPG data';
    }
    return '${formatEpgTime(start)} – ${formatEpgTime(end)}';
  }

  /// Formats a duration in minutes as "1h 30m".
  static String formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
