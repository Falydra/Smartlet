class TimeUtils {

  static DateTime toWIB(DateTime dt) {

    final utc = dt.toUtc();
    return utc.add(const Duration(hours: 7));
  }


  static String formatWibHHmm(DateTime dt) {
    final wib = toWIB(dt);
    final hh = wib.hour.toString().padLeft(2, '0');
    final mm = wib.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }


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
