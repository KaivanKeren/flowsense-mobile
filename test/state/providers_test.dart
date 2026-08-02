import 'dart:io';

import 'package:flowsense_mobile/core/clock.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';
import 'package:flowsense_mobile/data/api/fake_flowsense_api.dart';
import 'package:flowsense_mobile/data/repository/traffic_repository.dart';
import 'package:flowsense_mobile/state/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 8, 2, 12);

FakeFlowSenseApi _api() => FakeFlowSenseApi.fromStrings(
      intersectionsJson:
          File('test/fixtures/intersections.json').readAsStringSync(),
      recordsJsonl: File('test/fixtures/records.jsonl').readAsStringSync(),
      now: () => _t0,
    );

ProviderContainer _container(FakeFlowSenseApi api, {FakeClock? clock}) {
  final container = ProviderContainer(overrides: [
    apiProvider.overrideWithValue(api),
    appConfigProvider.overrideWithValue(
      const AppConfig(apiBase: 'https://x.test', apiKey: 'k'),
    ),
    clockProvider.overrideWithValue(clock ?? FakeClock(_t0)),
    // No shared_preferences in these tests: the cache is the repository's
    // concern and is covered in traffic_repository_test.dart.
    snapshotCacheProvider.overrideWithValue(null),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the snapshot provider goes loading, then data', () async {
    final container = _container(_api());

    // Riverpod coalesces rapid state changes, so the provider-level contract
    // is AsyncLoading -> AsyncData. The RepoLoading -> RepoData ordering
    // inside the stream is pinned in traffic_repository_test.dart.
    expect(container.read(snapshotProvider), isA<AsyncLoading<RepoState>>());

    container.listen(snapshotProvider, (_, _) {});
    await pumpEventQueue();

    final state = container.read(snapshotProvider);
    expect(state, isA<AsyncData<RepoState>>());
    expect((state.value! as RepoData).snapshot.records, hasLength(3));
  });

  test('the repository behind the provider still opens with RepoLoading',
      () async {
    final container = _container(_api());
    final states = <RepoState>[];

    container.read(repositoryProvider).watch().listen(states.add);
    await pumpEventQueue();

    expect(states.first, isA<RepoLoading>());
    expect(states.last, isA<RepoData>());
  });

  test('a failing fake surfaces RepoError through the provider', () async {
    final container = _container(_api()..failNext = 1);
    final states = <RepoState>[];

    container.listen(snapshotProvider, (_, next) {
      final value = next.value;
      if (value != null) states.add(value);
    }, fireImmediately: true);

    await pumpEventQueue();

    expect(states.last, isA<RepoError>());
    expect((states.last as RepoError).message, isNotEmpty);
  });

  test('intersectionsProvider resolves from the injected api', () async {
    final container = _container(_api());
    final list = await container.read(intersectionsProvider.future);

    expect(list.map((i) => i.id), ['30', '31', '32']);
  });

  test('historyProvider is keyed per camera', () async {
    final container = _container(_api());

    expect(await container.read(historyProvider('30').future), hasLength(3));
    expect(await container.read(historyProvider('nope').future), isEmpty);
  });

  test('selectedIntersectionProvider starts null and holds a camera id', () {
    final container = _container(_api());

    expect(container.read(selectedIntersectionProvider), isNull);
    container.read(selectedIntersectionProvider.notifier).state = '31';
    expect(container.read(selectedIntersectionProvider), '31');
  });

  test('disposing the container tears the repository down', () async {
    final api = _api();
    final clock = FakeClock(_t0);
    final container = _container(api, clock: clock);

    container.listen(snapshotProvider, (_, _) {}, fireImmediately: true);
    await pumpEventQueue();
    expect(api.tick, 1);
    expect(clock.hasListeners, isTrue);

    container.dispose();
    clock.tick();
    await pumpEventQueue();

    expect(clock.hasListeners, isFalse);
    expect(api.tick, 1, reason: 'polling must not outlive the container');
  });
}
