import '../../core/api_exception.dart';
import '../../domain/calibration.dart';

/// Lane capacity — the second and last thing the operator console may write.
///
/// **Not in `docs/api-contract.md`.** Proposed here, to be agreed:
///
/// ```
/// GET  /v1/intersections/{id}/capacity → CapacityCalibration
/// PUT  /v1/intersections/{id}/capacity → CapacityCalibration
/// ```
abstract class CalibrationApi {
  Future<CapacityCalibration> calibration(String cameraId);

  /// Replaces the capacities for [cameraId] and records who did it.
  Future<CapacityCalibration> save(
    String cameraId, {
    required Map<String, int> capacity,
    required String by,
  });
}

/// In-memory calibration so the console is demoable with no backend.
class FakeCalibrationApi implements CalibrationApi {
  FakeCalibrationApi({
    Map<String, CapacityCalibration> seed = const {},
    DateTime Function()? now,
  })  : _byCamera = {...seed},
        _now = now ?? DateTime.now;

  final Map<String, CapacityCalibration> _byCamera;
  final DateTime Function() _now;

  int failNext = 0;
  int saveCalls = 0;

  @override
  Future<CapacityCalibration> calibration(String cameraId) async =>
      _byCamera[cameraId] ??
      CapacityCalibration(cameraId: cameraId, capacity: const {});

  @override
  Future<CapacityCalibration> save(
    String cameraId, {
    required Map<String, int> capacity,
    required String by,
  }) async {
    saveCalls++;
    if (failNext > 0) {
      failNext--;
      throw const ApiException('Fake sedang disetel untuk gagal',
          statusCode: 503);
    }

    final saved = CapacityCalibration(
      cameraId: cameraId,
      capacity: Map.unmodifiable(capacity),
      updatedBy: by,
      updatedAt: _now(),
    );
    _byCamera[cameraId] = saved;
    return saved;
  }
}
