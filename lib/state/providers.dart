import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/config/app_config.dart';
import '../data/api/flowsense_api.dart';
import '../data/cache/snapshot_cache.dart';
import '../data/models/intersection.dart';
import '../data/models/traffic_record.dart';
import '../data/repository/traffic_repository.dart';

/// Runtime config. Overridden in tests; read from `--dart-define` in the app.
final appConfigProvider = Provider<AppConfig>(
  (ref) => const AppConfig.fromEnvironment(),
);

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final snapshotCacheProvider =
    Provider<SnapshotCache?>((ref) => const SnapshotCache());

/// **Always overridden at the root** — by `buildApi` in the entry points, and
/// by a fake in tests. Throwing here means a missing override is a loud
/// startup failure rather than a silent fallback to the network.
final apiProvider = Provider<FlowSenseApi>((ref) {
  throw UnimplementedError(
    'apiProvider must be overridden in ProviderScope (see lib/main_*.dart)',
  );
});

final repositoryProvider = Provider<TrafficRepository>((ref) {
  final repository = TrafficRepository(
    api: ref.watch(apiProvider),
    config: ref.watch(appConfigProvider),
    clock: ref.watch(clockProvider),
    cache: ref.watch(snapshotCacheProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

/// The one stream every screen watches. Widgets never learn whether the data
/// came from HTTP, the cache, or a fixture.
final snapshotProvider = StreamProvider<RepoState>(
  (ref) => ref.watch(repositoryProvider).watch(),
);

/// Static-ish geometry: fetched once, not polled.
final intersectionsProvider = FutureProvider<List<Intersection>>(
  (ref) => ref.watch(apiProvider).intersections(),
);

/// Camera id of the intersection whose detail sheet is open, or null.
final selectedIntersectionProvider = StateProvider<String?>((ref) => null);

/// History for one intersection, backed by `FlowSenseApi.history`. Keyed by
/// camera id so the operator dashboard can chart whichever one is selected.
final historyProvider =
    FutureProvider.family<List<TrafficRecord>, String>(
  (ref, cameraId) => ref.watch(apiProvider).history(cameraId),
);
