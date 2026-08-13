# FlowSense Mobile

One mobile app for the FlowSense traffic connector, serving two audiences —
**warga** (citizen traffic map) and **operator** (intersection dashboard) —
switched at runtime from inside the app.

> **The backend does not exist yet.** The connector plan ends at
> `data/connector_<camera_id>.jsonl` on local disk; the HTTP service described
> in [`docs/api-contract.md`](docs/api-contract.md) still has to be built. Until
> then the app runs on `FakeFlowSenseApi` backed by real connector output in
> `test/fixtures/`, and says so on screen. Everything here builds, runs, and
> tests without it.

## Setup

```bash
flutter pub get
```

Requires Flutter 3.x / Dart 3.12+.

## Running

One entry point, `lib/main.dart`, one APK, one icon:

```bash
flutter run \
  --dart-define=FLOWSENSE_API_BASE=https://api.example.id \
  --dart-define=FLOWSENSE_API_KEY=...
```

Release builds take the same `--dart-define` flags:

```bash
flutter build apk --dart-define=...
```

### The two modes

| Mode | Who it is for | Home screen | How to get there |
|---|---|---|---|
| `warga` | Riders and drivers | Map of every intersection, coloured by its worst approach, plus jam notifications | Where the app opens; **Beralih ke tampilan warga** in the console's Akun tab |
| `operator` | Traffic control staff | Intersection list ranked worst-first, per-lane bars, one hour of history | **Masuk sebagai operator** at the bottom of Langganan, then sign in |

The choice is a runtime one — `AppMode`, held in `appModeProvider` and
remembered on the device, so reopening the app lands where the last session
left off. It is **not** an access control: pressing the button only chooses a
shell, and `OperatorGate` still refuses to render the console without a
session. Anyone who arrives at the login screen without an account has a
`Kembali ke tampilan warga` button rather than a dead end.

Jam notifications ride with `warga` only, by construction — the listener is
part of the citizen shell, so an operator watching the console is not also
being told to consider another route.

Both modes are **read-only**. Neither sends control commands, and there is no
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
dies on a missing define — and a `Data contoh` badge rides on every screen that
shows fixture numbers, so canned data is never passed off as live traffic.

`test/fixtures/demo.json` is staging rather than contract: it marks the camera
served deliberately stale and the minutes missing from history, so the
`Data basi` and `Data hilang` paths are reachable without unplugging anything.

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

## The citizen app

Laid out to [`flowsense-warga-layout.md`](flowsense-warga-layout.md). Four
routes behind a three-tab bar:

| Route | Screen | What it is for |
|---|---|---|
| `/` | Peta | The map as a full canvas: a search field and a three-stage detail sheet float over it |
| `/simpang` | Simpang | The same data as a list — worst-first, or nearest-first when location is allowed |
| `/langganan` | Langganan | Which intersections to be notified about, at what level, during which hours |
| `/tentang` | Tentang | Where the data comes from and how far to trust it. Reached from Langganan, not the tab bar |

There is **no `Laporan` tab and no `Profil` tab**. Citizen reports need
moderation they would not get, and there is no account to have a profile for —
which also deletes an entire authentication layer from the backend.

The detail sheet snaps at `0.28 / 0.55 / 0.92`. The compact stage answers the
only question a rider actually has; lanes and the 60-minute history come next;
the camera panel is **last**, on purpose — it is the most eye-catching element
and the least actionable, since nobody reads congestion off low-resolution
video faster than off one coloured bar.

### Two encodings in the history chart

Bar **height is the vehicle count; bar colour is the worst lane's level.** Two
different sources, deliberately: taking the colour from the total would paint
the chart green while one approach was completely blocked. Minutes with no data
are drawn as a 3 px stub at the baseline and are **never interpolated across** —
a smooth line through a connector outage is a lie, and it is the first thing an
examiner asks about if the demo drops out.

### Subscriptions and quiet hours

Stored on the device with `shared_preferences` and sent nowhere. A list of the
junctions somebody checks every morning describes their commute, and the app
has no reason to know it. Active hours default to 06.00–09.00 and 15.00–19.00;
outside them nothing is delivered. A `clear` is the one exception — it only
takes a notification down, and suppressing it would strand a jam warning on
screen after the jam ended.

### Location

`geolocator`, behind a `LocationSource` interface so no test touches a platform
channel. Coarse permission only: the list renders distance to one decimal
place, and street-level precision would buy nothing. **Refusal is a supported
answer** — the nearest-first option hides itself and the list keeps working.

## How it is put together

```
lib/
  core/       config, injected Clock, structured logging, 448 px layout cap
  data/       models, API interface + HTTP and fake impls, repository, cache,
              device-local prefs, LocationSource
  domain/     congestion, jam alerts, history bucketing, subscriptions, geo —
              no package:flutter imports
  features/   UI: shell, map, detail sheet, simpang, langganan, tentang,
              operator dashboard, alerts
  state/      Riverpod providers
  app/        theme (every colour in the app), bootstrap and entry-point wiring
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
flutter test     # 250 tests: no network, no real clock, no platform channels
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
