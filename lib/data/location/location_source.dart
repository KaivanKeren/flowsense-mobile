import 'package:geolocator/geolocator.dart';

/// Where the device is, if the user allowed it.
///
/// An interface, not a plugin call, for the same reason the API is one:
/// `flutter test` must never touch a platform channel. [FakeLocationSource]
/// stands in everywhere the real one would, so the permission-denied path is
/// testable on a machine with no location service at all.
abstract class LocationSource {
  /// Null when permission was refused, the service is off, or no fix is
  /// available. Every caller has to handle null — a distance is a nicety, and
  /// nothing in this app may depend on having one.
  Future<DeviceLocation?> current();
}

class DeviceLocation {
  const DeviceLocation({required this.lat, required this.lon});

  final double lat;
  final double lon;
}

/// Records what it was asked, and answers whatever the test set up.
class FakeLocationSource implements LocationSource {
  FakeLocationSource({this.location});

  DeviceLocation? location;
  int calls = 0;

  @override
  Future<DeviceLocation?> current() async {
    calls++;
    return location;
  }
}

/// The real thing, over `geolocator`.
///
/// Every failure mode collapses to null rather than throwing. A refused
/// permission is an ordinary answer here, not an error: the list works without
/// it, and the spec requires the app to keep going when it happens.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Future<DeviceLocation?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // A junction is hundreds of metres across. Asking for best-available
          // accuracy would cost battery to sharpen a number that is rendered
          // to one decimal place.
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return DeviceLocation(
        lat: position.latitude,
        lon: position.longitude,
      );
    } on Object {
      // Timeouts, a service switched off mid-call, a platform that has no
      // location at all — none of them are worth surfacing to a rider.
      return null;
    }
  }
}
