# FlowSense Mobile (Flutter) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the two FlowSense mobile frontends — `warga` (citizen traffic map, read-only) and `operator` (intersection dashboard) — as one Flutter codebase with two flavors. All domain logic (record parsing, congestion classification, alert rules, polling cadence) is pure Dart and unit-tested offline. Networking sits behind an interface with an injected fake, so the app is fully buildable, runnable, and testable **before the backend exists**.

**Architecture:** Layered — `core/` (config, clock, logging, result types), `data/` (models, API interface + HTTP and fake implementations, repository, cache), `domain/` (congestion + alert rules, no Flutter imports), `features/` (UI per screen), `app/` (theme, flavor, router). Riverpod holds state. The repository exposes a `Stream<TrafficSnapshot>` produced by an injectable poller, so widgets never know whether data came from HTTP, cache, or a fixture.

**Tech Stack:** Flutter 3.x / Dart 3.x, Material 3, `flutter_riverpod`, `http`, `flutter_map` + `latlong2` (OpenStreetMap tiles), `fl_chart`, `shared_preferences`, `flutter_local_notifications`, `intl`, `flutter_test`.

---

## Prerequisite: the API this app consumes does not exist yet

The connector plan (`2026-08-01-flowsense-improvements.md`) ends at `data/connector_<camera_id>.jsonl` written to local disk. There is no HTTP surface for a phone to read. **Task 2 of this plan defines the contract; someone still has to build the service that ingests `.jsonl` and serves it.** Until then the app runs on `FakeFlowSenseApi` backed by real connector output copied into `test/fixtures/`, and nothing in Tasks 1–12 is blocked by that gap.

Contract (`docs/api-contract.md`, written in Task 2):

| Endpoint | Returns |
|---|---|
| `GET /v1/intersections` | `[{id, name, lat, lon, lanes: [str], capacity: {lane: int}}]` |
| `GET /v1/snapshot` | `{ts, items: [TrafficRecord]}` — latest record for every intersection, one call, used by the map |
| `GET /v1/intersections/{id}/latest` | one `TrafficRecord` |
| `GET /v1/intersections/{id}/history?from=&to=&bucket=1m` | `[TrafficRecord]`, time-bucketed |

`TrafficRecord` is the connector's `.jsonl` line verbatim: `ts`, `camera_id`, `camera`, `total_vehicles`, `per_lane`, optional `crossings`. Auth header `X-FlowSense-Key`, mirroring the connector's `X-SDC`.

## Global Constraints

- **Schema parity with the connector.** The Dart model must accept every `.jsonl` line the connector emits, treat `crossings` as optional, and **ignore unknown keys instead of throwing** — the connector team can add fields without shipping a new APK.
- **Tests never touch the network, a real clock, or platform channels.** HTTP goes through an injected `http.Client`; time goes through an injected `Clock`; `shared_preferences` uses `setMockInitialValues`.
- **No secrets in source.** Base URL and API key come from `--dart-define` (`FLOWSENSE_API_BASE`, `FLOWSENSE_API_KEY`), read once in `AppConfig`. Never `git add` a launch config containing a real key.
- **Read-only.** Neither flavor sends control commands. No write endpoints, no signal actuation from the phone.
- **Layout ceiling 448 px**, per the proposal's mobile-first constraint. A `MaxWidth448` wrapper centers content on tablets; nothing assumes a wide viewport.
- **`domain/` and `data/models/` import nothing from `package:flutter/`.** This keeps them testable with plain `dart test` semantics and forces UI concerns out of the rules.
- Run all tests with `flutter test` from the project root. Run `dart analyze` before every commit; the build fails on warnings.
- Commit after every task, on the current branch.

---

### Task 1: Project skeleton + repo hygiene

**Files:**
- Create: `flowsense_mobile/` (via `flutter create`)
- Create: `analysis_options.yaml`, `.gitignore` additions
- Create: `lib/core/max_width.dart`
- Create: `test/smoke_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: an analyzable, testable Flutter project; the 448 px layout primitive used by every screen from Task 9 on.

- [ ] **Step 1: Create the project**

```bash
flutter create --org id.ac.umk.flowsense --platforms=android,ios flowsense_mobile
cd flowsense_mobile
```

- [ ] **Step 2: Add dependencies**

```bash
flutter pub add flutter_riverpod http flutter_map latlong2 fl_chart shared_preferences flutter_local_notifications intl
```

- [ ] **Step 3: Tighten `analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml

analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
  errors:
    invalid_annotation_target: ignore

linter:
  rules:
    - always_declare_return_types
    - avoid_print
    - prefer_final_locals
    - unawaited_futures
```

- [ ] **Step 4: Append to `.gitignore`**

```gitignore
.dart_tool/
build/
*.g.dart
.vscode/launch.json
```

- [ ] **Step 5: Create the layout primitive**

`lib/core/max_width.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Caps content at the 448 px mobile-first width the proposal specifies.
class MaxWidth448 extends StatelessWidget {
  const MaxWidth448({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: child,
        ),
      );
}
```

- [ ] **Step 6: Write the smoke test**

`test/smoke_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowsense_mobile/core/max_width.dart';

void main() {
  testWidgets('MaxWidth448 caps its child', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MaxWidth448(child: SizedBox(width: 2000, height: 10)),
    ));
    final box = tester.getSize(find.byType(ConstrainedBox).first);
    expect(box.width, lessThanOrEqualTo(448));
  });
}
```

- [ ] **Step 7: Verify**

Run: `flutter test test/smoke_test.dart` → 1 passed. Then `dart analyze` → no issues.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "chore: scaffold flowsense_mobile with strict lints and 448px layout primitive"
```

---

### Task 2: API contract doc + `AppConfig` from dart-define

**Files:**
- Create: `docs/api-contract.md`
- Create: `lib/core/config/app_config.dart`
- Create: `test/core/app_config_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `AppConfig` with `apiBase`, `apiKey`, `pollInterval`, `staleAfter`, `laneCapacityDefault`; `const AppConfig.fromEnvironment()`; `bool get isConfigured`. Every later task takes `AppConfig` by constructor, never reads `String.fromEnvironment` directly.

- [ ] **Step 1: Write `docs/api-contract.md`**

Copy the four-endpoint table from the top of this plan, add a sample JSON body per endpoint taken from a real `.jsonl` line, and state the two rules the backend must honour: `ts` is epoch **seconds** (integer, matching `build_record`), and `per_lane` keys are the ROI lane names from `config/rois.json` — the app never invents lane names.

- [ ] **Step 2: Write the failing tests**

`test/core/app_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowsense_mobile/core/config/app_config.dart';

void main() {
  test('defaults are safe when nothing is defined', () {
    const cfg = AppConfig();
    expect(cfg.apiKey, isEmpty);
    expect(cfg.isConfigured, isFalse);
    expect(cfg.pollInterval, const Duration(seconds: 5));
    expect(cfg.staleAfter, const Duration(seconds: 30));
  });

  test('explicit values win', () {
    const cfg = AppConfig(
      apiBase: 'https://example.test',
      apiKey: 'k',
      pollInterval: Duration(seconds: 2),
    );
    expect(cfg.isConfigured, isTrue);
    expect(cfg.pollInterval, const Duration(seconds: 2));
  });
}
```

- [ ] **Step 3: Implement `lib/core/config/app_config.dart`**

```dart
/// Runtime configuration. Values come from --dart-define; nothing is hardcoded.
class AppConfig {
  const AppConfig({
    this.apiBase = '',
    this.apiKey = '',
    this.pollInterval = const Duration(seconds: 5),
    this.staleAfter = const Duration(seconds: 30),
    this.laneCapacityDefault = 12,
  });

  const AppConfig.fromEnvironment()
      : apiBase = const String.fromEnvironment('FLOWSENSE_API_BASE'),
        apiKey = const String.fromEnvironment('FLOWSENSE_API_KEY'),
        pollInterval = const Duration(
          seconds: int.fromEnvironment('FLOWSENSE_POLL_SECONDS', defaultValue: 5),
        ),
        staleAfter = const Duration(
          seconds: int.fromEnvironment('FLOWSENSE_STALE_SECONDS', defaultValue: 30),
        ),
        laneCapacityDefault =
            const int.fromEnvironment('FLOWSENSE_LANE_CAPACITY', defaultValue: 12);

  final String apiBase;
  final String apiKey;
  final Duration pollInterval;
  final Duration staleAfter;
  final int laneCapacityDefault;

  bool get isConfigured => apiBase.isNotEmpty && apiKey.isNotEmpty;
}
```

- [ ] **Step 4: Verify** — `flutter test test/core/app_config_test.dart` → 2 passed.

- [ ] **Step 5: Document the run command in `README` scratch notes**

```bash
flutter run --dart-define=FLOWSENSE_API_BASE=https://... --dart-define=FLOWSENSE_API_KEY=...
```

- [ ] **Step 6: Commit**

```bash
git add docs/api-contract.md lib/core/config/app_config.dart test/core/app_config_test.dart
git commit -m "feat: define API contract and dart-define-backed AppConfig"
```

---

### Task 3: Domain models (schema-tolerant parsing)

**Files:**
- Create: `lib/data/models/traffic_record.dart`, `lib/data/models/intersection.dart`, `lib/data/models/traffic_snapshot.dart`
- Create: `test/data/traffic_record_test.dart`
- Create: `test/fixtures/records.jsonl`, `test/fixtures/intersections.json`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `TrafficRecord.fromJson(Map<String, dynamic>)` with `ts` (`DateTime`, from epoch seconds), `cameraId` (`String`), `cameraName`, `totalVehicles`, `perLane` (`Map<String,int>`), `crossings` (`Map<String,int>?`).
  - `Intersection.fromJson` with `id`, `name`, `LatLng`-free `lat`/`lon` doubles, `lanes`, `capacity`.
  - `TrafficSnapshot` = `{DateTime fetchedAt, List<TrafficRecord> records}` plus `TrafficRecord? forCamera(String id)`.

No code generation. Hand-written `fromJson` keeps `build_runner` out of the loop, which matters with a two-week deadline.

- [ ] **Step 1: Create the fixture**

`test/fixtures/records.jsonl` — paste 5 real lines from `data/connector_30.jsonl`. Include at least one line with `crossings` and one without.

- [ ] **Step 2: Write the failing tests**

`test/data/traffic_record_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowsense_mobile/data/models/traffic_record.dart';

void main() {
  test('parses a connector line', () {
    final r = TrafficRecord.fromJson(jsonDecode(
      '{"ts":1755000000,"camera_id":30,"camera":"Simpang DPRD Arah Kota",'
      '"total_vehicles":4,"per_lane":{"kota":2,"ploso":2}}',
    ) as Map<String, dynamic>);

    expect(r.cameraId, '30');            // int id normalised to String
    expect(r.ts.toUtc().year, 2025);
    expect(r.totalVehicles, 4);
    expect(r.perLane['kota'], 2);
    expect(r.crossings, isNull);
  });

  test('reads optional crossings', () {
    final r = TrafficRecord.fromJson(jsonDecode(
      '{"ts":1,"camera_id":"30","camera":"x","total_vehicles":2,'
      '"per_lane":{"kota":1},"crossings":{"kota":12}}',
    ) as Map<String, dynamic>);
    expect(r.crossings!['kota'], 12);
  });

  test('ignores unknown keys instead of throwing', () {
    final r = TrafficRecord.fromJson(jsonDecode(
      '{"ts":1,"camera_id":30,"camera":"x","total_vehicles":0,"per_lane":{},'
      '"future_field":{"anything":true}}',
    ) as Map<String, dynamic>);
    expect(r.totalVehicles, 0);
  });

  test('missing per_lane degrades to empty, not an exception', () {
    final r = TrafficRecord.fromJson(
        jsonDecode('{"ts":1,"camera_id":30,"camera":"x","total_vehicles":3}')
            as Map<String, dynamic>);
    expect(r.perLane, isEmpty);
    expect(r.totalVehicles, 3);
  });
}
```

- [ ] **Step 3: Implement `lib/data/models/traffic_record.dart`**

```dart
/// One record emitted by the FlowSense edge connector.
/// Field names mirror the `.jsonl` schema exactly; unknown keys are ignored.
class TrafficRecord {
  const TrafficRecord({
    required this.ts,
    required this.cameraId,
    required this.cameraName,
    required this.totalVehicles,
    required this.perLane,
    this.crossings,
  });

  factory TrafficRecord.fromJson(Map<String, dynamic> json) => TrafficRecord(
        ts: DateTime.fromMillisecondsSinceEpoch(
            ((json['ts'] as num?)?.toInt() ?? 0) * 1000,
            isUtc: true),
        cameraId: '${json['camera_id'] ?? ''}',
        cameraName: json['camera'] as String? ?? '',
        totalVehicles: (json['total_vehicles'] as num?)?.toInt() ?? 0,
        perLane: _counts(json['per_lane']),
        crossings: json['crossings'] == null ? null : _counts(json['crossings']),
      );

  static Map<String, int> _counts(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        '${e.key}': (e.value as num?)?.toInt() ?? 0,
    };
  }

  final DateTime ts;
  final String cameraId;
  final String cameraName;
  final int totalVehicles;
  final Map<String, int> perLane;
  final Map<String, int>? crossings;
}
```

`Intersection` and `TrafficSnapshot` follow the same shape: total-loss-free parsing, no generated code.

- [ ] **Step 4: Verify** — `flutter test test/data/` → 4 passed.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models test/data test/fixtures
git commit -m "feat: add schema-tolerant models mirroring the connector .jsonl record"
```

---

### Task 4: Congestion classification (pure rules)

**Files:**
- Create: `lib/domain/congestion.dart`
- Create: `test/domain/congestion_test.dart`

**Interfaces:**
- Consumes: `TrafficRecord`, `Intersection`.
- Produces:
  - `enum CongestionLevel { lancar, padat, macet, unknown }`
  - `CongestionLevel levelForLane(int count, int capacity)` — ratio `count/capacity`: `< 0.4` lancar, `< 0.75` padat, else macet; capacity `<= 0` → unknown.
  - `CongestionLevel levelForIntersection(TrafficRecord r, Intersection i)` — the **worst** lane wins, because one blocked approach is what a rider needs to know.
  - `bool isStale(TrafficRecord r, DateTime now, Duration staleAfter)`.

This is the app's analogue of `flowsense/lanes.py`: the one piece of logic worth being fussy about, fully offline-testable.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flowsense_mobile/domain/congestion.dart';

void main() {
  test('lane thresholds', () {
    expect(levelForLane(3, 12), CongestionLevel.lancar);   // 0.25
    expect(levelForLane(6, 12), CongestionLevel.padat);    // 0.50
    expect(levelForLane(10, 12), CongestionLevel.macet);   // 0.83
  });

  test('boundaries are inclusive at the upper level', () {
    expect(levelForLane(4, 10), CongestionLevel.padat);    // exactly 0.4
    expect(levelForLane(75, 100), CongestionLevel.macet);  // exactly 0.75
  });

  test('zero capacity is unknown, never a divide-by-zero', () {
    expect(levelForLane(5, 0), CongestionLevel.unknown);
  });

  test('worst lane decides the intersection', () { /* one macet lane among lancar => macet */ });

  test('empty per_lane is unknown, not lancar', () { /* absence of data != free flow */ });

  test('stale records are detected', () { /* ts 60s old, staleAfter 30s => true */ });
}
```

The fifth test matters: showing green because the connector went down would be the worst failure this app can have.

- [ ] **Step 2: Implement, run, and verify** — 6 passed.

- [ ] **Step 3: Commit**

```bash
git commit -am "feat: add congestion classification rules with staleness detection"
```

---

### Task 5: API client (interface, retrying HTTP impl, injectable fake)

**Files:**
- Create: `lib/data/api/flowsense_api.dart`, `lib/data/api/http_flowsense_api.dart`, `lib/data/api/fake_flowsense_api.dart`, `lib/core/api_exception.dart`
- Create: `test/data/http_flowsense_api_test.dart`

**Interfaces:**
- Consumes: `AppConfig`, `package:http`.
- Produces:
  - `abstract class FlowSenseApi { Future<List<Intersection>> intersections(); Future<TrafficSnapshot> snapshot(); Future<List<TrafficRecord>> history(String id, {DateTime from, DateTime to}); }`
  - `HttpFlowSenseApi(config, {http.Client? client, Future<void> Function(Duration)? sleep})` — sends `X-FlowSense-Key`, retries `retries` times with backoff `base * 2^attempt`, throws `ApiException` when exhausted. Mirrors `flowsense/api.py` deliberately, so the two sides fail the same way.
  - `FakeFlowSenseApi.fromFixtures()` — reads `test/fixtures/*`, cycles records with a synthetic clock, and can be told to fail (`failNext = 2`) so error UI is reachable without a backend.

- [ ] **Step 1: Write the failing tests** using `http.MockClient` from `package:http/testing.dart` and an injected no-op `sleep`, covering: success; two failures then success (assert 3 calls); exhaustion throws `ApiException`; HTTP 401 throws immediately **without** retrying (a bad key will never fix itself); malformed JSON throws `ApiException`, not `FormatException`.

- [ ] **Step 2: Implement all three files.** `HttpFlowSenseApi` must not swallow the underlying error — `ApiException` carries `message`, `statusCode`, and `cause`.

- [ ] **Step 3: Verify** — 5 passed, and `flutter test` overall still green.

- [ ] **Step 4: Commit**

```bash
git add lib/data/api lib/core/api_exception.dart test/data/http_flowsense_api_test.dart
git commit -m "feat: add FlowSenseApi with retrying HTTP client and fixture-backed fake"
```

---

### Task 6: Repository — polling, cache, offline fallback

**Files:**
- Create: `lib/core/clock.dart`, `lib/data/cache/snapshot_cache.dart`, `lib/data/repository/traffic_repository.dart`
- Create: `test/data/traffic_repository_test.dart`

**Interfaces:**
- Consumes: `FlowSenseApi`, `AppConfig`, `Clock`, `SnapshotCache`.
- Produces:
  - `Clock` with `DateTime now()` and `Stream<void> ticks(Duration)`; `FakeClock` drives tests without `Future.delayed`.
  - `SnapshotCache` — last good snapshot as JSON in `shared_preferences`, so a cold start on a dead network shows something (clearly marked stale) rather than a spinner.
  - `TrafficRepository.watch()` → `Stream<RepoState>` where `RepoState` is a sealed class: `RepoLoading`, `RepoData(snapshot, isStale, isFromCache)`, `RepoError(message, lastGood?)`.

The important behaviour: **a transient poll failure must not blank the screen.** It emits `RepoError` carrying the last good snapshot, and the UI keeps rendering that with a staleness banner. This is the mobile mirror of `ReconnectingStream`.

- [ ] **Step 1: Write the failing tests** — first tick emits `RepoData`; a failing tick emits `RepoError` with `lastGood` populated; recovery re-emits fresh `RepoData`; a record older than `staleAfter` sets `isStale`; cold start with a populated cache emits cached data before the first network call resolves; `dispose()` cancels the timer (assert no further API calls after disposal).

- [ ] **Step 2: Implement, verify (6 passed), commit.**

```bash
git commit -am "feat: add polling repository with cache fallback and staleness state"
```

---

### Task 7: Structured logging

**Files:**
- Create: `lib/core/logging/logger.dart`
- Create: `test/core/logger_test.dart`

**Interfaces:**
- Produces: `FlowLog.event(String msg, {Map<String, Object?> fields})` emitting one JSON line per event with `ts`, `level`, `msg`, plus fields — the same shape as `flowsense/telemetry.py`, so connector logs and app logs can be read side by side during the demo. In release builds it routes to a no-op sink by default; the sink is injectable so tests capture lines.

- [ ] **Step 1: Tests** — formatter serialises extra fields; injected sink captures; default sink is silent in release mode.
- [ ] **Step 2: Implement, verify (3 passed), commit.**

---

### Task 8: Riverpod state layer

**Files:**
- Create: `lib/state/providers.dart`
- Create: `test/state/providers_test.dart`

**Interfaces:**
- Produces: `appConfigProvider`, `apiProvider` (throws `UnimplementedError` — always overridden at the root), `repositoryProvider`, `snapshotProvider` (`StreamProvider<RepoState>`), `intersectionsProvider`, `selectedIntersectionProvider`.

- [ ] **Step 1: Tests** using `ProviderContainer(overrides: [apiProvider.overrideWithValue(FakeFlowSenseApi(...))])`: the snapshot stream emits loading then data; overriding the API with a failing fake surfaces `RepoError`; disposing the container tears the repository down.
- [ ] **Step 2: Implement, verify (3 passed), commit.**

---

### Task 9: Warga flavor — map + intersection detail

**Files:**
- Create: `lib/app/theme.dart`, `lib/features/map/map_screen.dart`, `lib/features/map/intersection_marker.dart`, `lib/features/detail/intersection_sheet.dart`, `lib/features/common/stale_banner.dart`
- Create: `test/features/map_screen_test.dart`, `test/features/intersection_sheet_test.dart`

**Interfaces:**
- Consumes: `snapshotProvider`, `intersectionsProvider`, `levelForIntersection`.
- Produces: the citizen-facing screen.

**Design notes.** Keep the palette to four semantic colours driven entirely by `CongestionLevel` — lancar, padat, macet, and a desaturated grey for unknown/stale — and never use those hues for anything decorative, so colour on this screen always means one thing. The marker is the signature element: a filled circle sized by `total_vehicles` with the lane split rendered as a small ring, readable at a glance from a phone mounted on a handlebar. Everything else stays quiet. Copy is plain Indonesian, sentence case, no exclamation marks: `Lancar`, `Padat`, `Macet`, `Data terakhir 2 menit lalu`. The empty state says what to do; the error state says what happened.

- [ ] **Step 1: Write the widget tests first** — markers render one per intersection and carry the level colour; tapping a marker opens the sheet with that camera's lane breakdown; a stale snapshot renders `StaleBanner` and desaturates markers; an error with `lastGood` still renders markers plus the banner; the empty snapshot renders the empty state, not a spinner.
- [ ] **Step 2: Build `theme.dart`** — Material 3, `ColorScheme.fromSeed`, plus a `CongestionColors` `ThemeExtension` so the four semantic colours are looked up, never inlined in widgets.
- [ ] **Step 3: Build the screens.** `flutter_map` with the OSM tile layer, `MarkerLayer` from the snapshot, `showModalBottomSheet` for detail, all content inside `MaxWidth448`.
- [ ] **Step 4: Attribution.** OSM tiles require visible attribution (`RichAttributionWidget`) — this is a licence obligation, and a judge who knows the stack will look for it.
- [ ] **Step 5: Verify** — 5 widget tests pass; `flutter run --dart-define=...` against `FakeFlowSenseApi` shows a live-looking map with no backend.
- [ ] **Step 6: Commit.**

---

### Task 10: Jam alert rule + local notification

**Files:**
- Create: `lib/domain/alerts.dart`, `lib/features/alerts/notifier.dart`
- Create: `test/domain/alerts_test.dart`

**Interfaces:**
- Produces: `AlertRule.evaluate(previous, current, {required Duration since})` → `AlertDecision { none, raise, clear }`. Fires `raise` only when an intersection has been `macet` for **N consecutive polls** (default 3) and no alert is active; `clear` on a sustained return to `lancar`. Debounce is a rule, not a UI detail, so it is unit-tested with a `FakeClock`.

- [ ] **Step 1: Tests** — a single macet poll does not fire; three consecutive do; an already-raised alert does not re-fire; flapping lancar/macet does not fire; stale data never fires (the connector being down is not a traffic jam).
- [ ] **Step 2: Implement the rule, then wire `flutter_local_notifications` behind a `Notifier` interface** with a `FakeNotifier` in tests — no platform channel is touched by `flutter test`.
- [ ] **Step 3: Verify (5 passed), commit.**

---

### Task 11: Operator flavor — dashboard + history

**Files:**
- Create: `lib/features/operator/dashboard_screen.dart`, `lib/features/operator/lane_bars.dart`, `lib/features/operator/history_chart.dart`
- Create: `test/features/dashboard_screen_test.dart`

**Interfaces:**
- Consumes: `snapshotProvider`, `historyProvider` (new, backed by `FlowSenseApi.history`).
- Produces: the operator view — intersection list sorted worst-first, per-lane horizontal bars with counts, and an `fl_chart` line of `total_vehicles` over the last hour.

- [ ] **Step 1: Tests** — list sorts macet above padat above lancar; per-lane bars render one row per key in `per_lane` and handle a lane appearing mid-session; the history chart renders from a fixture and shows an empty state for zero points; the stale banner appears here too.
- [ ] **Step 2: Implement, verify (4 passed), commit.**

Scope note: the operator app stays read-only for GEMASTIK. Signal control from a phone is a safety question, not a feature question, and the proposal does not claim it.

---

### Task 12: Flavors, entry points, README, final verification

**Files:**
- Create: `lib/app/flavor.dart`, `lib/main_warga.dart`, `lib/main_operator.dart`, `README.md`
- Delete: `lib/main.dart`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: `lib/app/flavor.dart`** — `enum Flavor { warga, operator }` plus `Widget homeFor(Flavor)`.

- [ ] **Step 2: Entry points**

```dart
// lib/main_warga.dart
void main() => runApp(ProviderScope(
      overrides: [apiProvider.overrideWithValue(buildApi(const AppConfig.fromEnvironment()))],
      child: const FlowSenseApp(flavor: Flavor.warga),
    ));
```

`buildApi` returns `FakeFlowSenseApi.fromFixtures()` when `config.isConfigured` is false — the demo never dies on a missing key, it degrades to fixtures and says so in the app bar.

- [ ] **Step 3: Write `README.md`** — setup, both run commands with `--dart-define`, the flavor table, a pointer to `docs/api-contract.md`, the record schema, and `flutter test`.

- [ ] **Step 4: Full verification**

```bash
dart analyze                      # no issues
flutter test                      # expected: 1 + 2 + 4 + 6 + 5 + 6 + 3 + 3 + 5 + 5 + 4 = 44 passed
flutter build apk --debug --target=lib/main_warga.dart --dart-define=FLOWSENSE_API_BASE=... 
flutter build apk --debug --target=lib/main_operator.dart --dart-define=FLOWSENSE_API_BASE=...
```

- [ ] **Step 5: Confirm no secret is committed**

```bash
git grep -nE "FLOWSENSE_API_KEY=" -- . ':!*.md'   # expect no matches
```

- [ ] **Step 6: Commit.**

---

## Self-Review

- **Parity with the connector plan.** Secrets to env → Task 2. Retry/backoff with injected transport → Task 5. Reconnect/degradation → Task 6. Structured logging → Task 7. Pure logic unit-tested offline → Tasks 3, 4, 10. Thin entry points over a package → Task 12.
- **Schema coupling is one-directional.** The app reads the connector's record and never dictates it; unknown keys are ignored, `crossings` is optional, and `per_lane` names come from `rois.json`. The connector team can ship without coordinating a release.
- **Buildable before the backend.** Tasks 1–12 all pass with `FakeFlowSenseApi`. The only thing the missing service blocks is a live demo.
- **Failure modes the tests pin down:** empty `per_lane` renders unknown, not green; stale data is visibly stale and cannot fire an alert; a poll failure keeps the last good snapshot on screen; a 401 does not retry.
- **Open decisions for the team:** lane `capacity` values must come from calibration (count the vehicles that physically fit in each ROI at standstill) — the default of 12 is a placeholder and the classification is only as good as that number. Polling at 5 s against a connector emitting at 2 s is a deliberate battery trade-off; SSE would be better and is out of scope here.
