# FlowSense Mobile

Two mobile frontends for the FlowSense traffic connector — **warga** (citizen
traffic map) and **operator** (intersection dashboard) — as one Flutter
codebase with two flavors.

> **The backend does not exist yet.** The connector plan ends at
> `data/connector_<camera_id>.jsonl` on local disk; the HTTP service described
> in [`docs/api-contract.md`](docs/api-contract.md) still has to be built. Until
> then the app runs on `FakeFlowSenseApi` backed by real connector output in
> `test/fixtures/`, and says so in the app bar. Everything here builds, runs,
> and tests without it.

## Setup

```bash
flutter pub get
```

Requires Flutter 3.x / Dart 3.12+.

## Running

| Flavor | Who it is for | Entry point | Home screen |
|---|---|---|---|
| `warga` | Riders and drivers | `lib/main_warga.dart` | Map of every intersection, coloured by its worst approach, plus jam notifications |
| `operator` | Traffic control staff | `lib/main_operator.dart` | Intersection list ranked worst-first, per-lane bars, one hour of history |

```bash
flutter run --target=lib/main_warga.dart \
  --dart-define=FLOWSENSE_API_BASE=https://api.example.id \
  --dart-define=FLOWSENSE_API_KEY=...

flutter run --target=lib/main_operator.dart \
  --dart-define=FLOWSENSE_API_BASE=https://api.example.id \
  --dart-define=FLOWSENSE_API_KEY=...
```

Release builds take the same `--target` and `--dart-define` flags:

```bash
flutter build apk --target=lib/main_warga.dart --dart-define=...
```

Both flavors are **read-only**. Neither sends control commands, and there is no
signal actuation from a phone — that is a safety question, not a feature
question.

### Configuration

Everything comes from `--dart-define`, read once in `AppConfig`. Nothing is
hardcoded and no key is committed.

| Define | Default | Meaning |
|---|---|---|
| `FLOWSENSE_API_BASE` | — | Backend base URL |
| `FLOWSENSE_API_KEY` | — | Sent as `X-FlowSense-Key`, mirroring the connector's `X-SDC` |
| `FLOWSENSE_POLL_SECONDS` | `5` | Snapshot poll cadence |
| `FLOWSENSE_STALE_SECONDS` | `30` | Age at which a record is shown as stale |
| `FLOWSENSE_LANE_CAPACITY` | `12` | Fallback capacity for a lane the backend did not calibrate |

Without a base URL **and** a key, `AppConfig.isConfigured` is false and
`buildApi` degrades to `FakeFlowSenseApi` on the bundled fixtures. A demo never
dies on a missing define — and the app bar carries a `Data contoh` badge, so
canned numbers are never passed off as live traffic.

> **Never `git add` a launch config containing a real key.**

## The record schema

The app reads the connector's `.jsonl` line verbatim. It is the connector's
schema, not the app's:

```json
{"ts":1755000000,"camera_id":30,"camera":"Simpang DPRD Arah Kota",
 "total_vehicles":9,"per_lane":{"kota":6,"ploso":3},
 "crossings":{"kota":12,"ploso":7}}
```

| Field | Notes |
|---|---|
| `ts` | Epoch **seconds**, not milliseconds |
| `camera_id` | Coerced to a string; the backend may send either |
| `camera` | Display name |
| `total_vehicles` | Drives marker size and the history chart |
| `per_lane` | `{lane: count}`; keys are ROI lane names from `config/rois.json`, used verbatim |
| `crossings` | **Optional** |

Three rules the app holds to, so the connector team can ship without
coordinating a release:

- **Unknown keys are ignored, never fatal.** New fields can appear at any time.
- **A lane can appear mid-session.** It renders, falling back to
  `FLOWSENSE_LANE_CAPACITY` for its capacity.
- **Absence of data is never reported as free flow.** An uncalibrated lane, a
  missing record, or a stale one reads as `Tidak ada data` in grey — never as
  `Lancar`.

See [`docs/api-contract.md`](docs/api-contract.md) for the four endpoints.

## How it is put together

```
lib/
  core/       config, injected Clock, structured logging, 448 px layout cap
  data/       models, API interface + HTTP and fake impls, polling repository, cache
  domain/     congestion rules, jam alert rule — no package:flutter imports
  features/   UI: map, detail sheet, operator dashboard, alerts
  state/      Riverpod providers
  app/        theme, flavor, entry-point wiring
```

Three constraints hold the design together:

- **`domain/` and `data/models/` import nothing from `package:flutter/`**, so
  the rules are testable without a widget binding — and UI concerns stay out of
  them.
- **Tests never touch the network, a real clock, or a platform channel.** HTTP
  goes through an injected `http.Client`, time through an injected `Clock`,
  notifications through an `AlertNotifier` interface, `shared_preferences`
  through `setMockInitialValues`.
- **A transient failure must not blank the screen.** `TrafficRepository` keeps
  the last good snapshot on screen under a banner saying what happened — the
  mobile mirror of the connector's `ReconnectingStream`.

### Jam alerts

Notifications fire from a rule, not from the UI: an intersection has to read
`macet` on **three consecutive polls** before anyone is interrupted, and three
sustained `lancar` polls to call it off. A single bad frame does not wake
people up, a flapping intersection does not either, and **stale data never
fires** — the connector going down is not a traffic jam. The whole rule is pure
Dart in `lib/domain/alerts.dart`, unit-tested against a `FakeClock`.

## Tests

```bash
flutter test     # 115 tests: no network, no real clock, no platform channels
dart analyze     # must be clean; the build fails on warnings
```

Confirm no key was committed:

```bash
git grep -nE "FLOWSENSE_API_KEY=" -- . ':!*.md'   # expect no matches
```

## Attribution

Map tiles © [OpenStreetMap](https://www.openstreetmap.org/copyright)
contributors. Attribution is rendered on the map itself — it is a licence
obligation, not a nicety. The public OSM tile servers are **not** suitable for
production load; see the [tile usage policy](https://operations.osmfoundation.org/policies/tiles).
