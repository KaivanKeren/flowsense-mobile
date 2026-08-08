import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/calibration/calibration_api.dart';
import '../domain/calibration.dart';

/// Overridden at the root and in tests. No HTTP implementation yet — the
/// endpoints are proposed, not agreed.
final calibrationApiProvider =
    Provider<CalibrationApi>((ref) => FakeCalibrationApi());

/// The stored calibration for one intersection, including who last set it.
final calibrationProvider =
    FutureProvider.family<CapacityCalibration, String>(
  (ref, cameraId) => ref.watch(calibrationApiProvider).calibration(cameraId),
);
