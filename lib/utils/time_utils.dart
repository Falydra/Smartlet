class TimeUtils {
  // Convert any DateTime to WIB (UTC+7) by first normalizing to UTC
  static DateTime toWIB(DateTime dt) {
    // Ensure we start from UTC to avoid double-applying local offsets
    final utc = dt.toUtc();
    return utc.add(const Duration(hours: 7));
  }

  // Format as HH:mm in WIB
  static String formatWibHHmm(DateTime dt) {
    final wib = toWIB(dt);
    final hh = wib.hour.toString().padLeft(2, '0');
    final mm = wib.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // Safely parse ISO string to WIB DateTime (returns null on failure)
  static DateTime? parseIsoToWIB(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    try {
      final dt = DateTime.parse(iso);
      return toWIB(dt);
    } catch (_) {
      return null;
    }
  }
}
