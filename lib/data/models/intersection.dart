import 'traffic_record.dart';

/// A monitored intersection, as served by `GET /v1/intersections`.
///
/// Coordinates stay plain doubles: this file must not import `latlong2` or
/// anything from `package:flutter/`, so the domain rules remain testable
/// without a widget binding.
class Intersection {
  const Intersection({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.lanes,
    required this.capacity,
  });

  factory Intersection.fromJson(Map<String, dynamic> json) => Intersection(
        id: '${json['id'] ?? ''}',
        name: json['name'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0,
        lon: (json['lon'] as num?)?.toDouble() ?? 0,
        lanes: _lanes(json['lanes']),
        capacity: TrafficRecord.countsFromJson(json['capacity']),
      );

  static List<String> _lanes(Object? raw) {
    if (raw is! List) return const [];
    return [for (final e in raw) '$e'];
  }

  final String id;
  final String name;
  final double lat;
  final double lon;
  final List<String> lanes;
  final Map<String, int> capacity;

  /// Calibrated capacity for [lane], or [fallback] when the backend did not
  /// supply one. A lane can appear mid-session; that is a supported case.
  int capacityFor(String lane, {required int fallback}) =>
      capacity[lane] ?? fallback;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'lat': lat,
        'lon': lon,
        'lanes': lanes,
        'capacity': capacity,
      };
}
