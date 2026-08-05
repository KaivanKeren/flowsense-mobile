import 'dart:math' as math;

/// Great-circle distance in kilometres.
///
/// Haversine on a spherical earth. Kudus spans a few kilometres, where the
/// difference between this and a full ellipsoidal model is centimetres — far
/// below the precision of a distance that gets rendered as `1,2 km`.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0088;
  double toRadians(double deg) => deg * math.pi / 180;

  final dLat = toRadians(lat2 - lat1);
  final dLon = toRadians(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRadians(lat1)) *
          math.cos(toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// `1,2 km` / `450 m` — Indonesian decimal comma, and metres below a kilometre
/// so a nearby junction does not read as `0,4 km`.
String formatDistance(double km) {
  if (km < 1) {
    // Rounded to the nearest 10 m: GPS on a phone is not accurate to the
    // metre, and printing one would overstate what is known.
    final rounded = ((km * 1000) / 10).round() * 10;
    // Rounding can tip 999 m over the line; fall through rather than print
    // "1000 m".
    if (rounded < 1000) return '$rounded m';
  }
  final oneDecimal = (km * 10).round() / 10;
  return '${oneDecimal.toStringAsFixed(1).replaceAll('.', ',')} km';
}
