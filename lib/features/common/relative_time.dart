/// Plain Indonesian relative time: `baru saja`, `2 menit lalu`, `1 jam lalu`.
///
/// Rounds down, so it never claims data is fresher than it is. A negative age
/// is clock skew between the edge device and the phone, not a reading from the
/// future, and reads as `baru saja` rather than a negative number.
String relativeIndonesian(Duration age) {
  if (age.isNegative || age.inSeconds < 10) return 'baru saja';
  if (age.inMinutes < 1) return '${age.inSeconds} detik lalu';
  if (age.inHours < 1) return '${age.inMinutes} menit lalu';
  if (age.inDays < 1) return '${age.inHours} jam lalu';
  return '${age.inDays} hari lalu';
}
