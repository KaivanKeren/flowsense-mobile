# flowsense_mobile

Two FlowSense mobile frontends — `warga` (citizen traffic map) and `operator`
(intersection dashboard) — as one Flutter codebase with two flavors.

> Scratch notes. Task 12 replaces this with the real README.

## Running

```bash
flutter run --dart-define=FLOWSENSE_API_BASE=https://... --dart-define=FLOWSENSE_API_KEY=...
```

Without those defines `AppConfig.isConfigured` is false and the app degrades to
`FakeFlowSenseApi` backed by `test/fixtures/` — the demo never dies on a missing
key.

Optional: `FLOWSENSE_POLL_SECONDS` (5), `FLOWSENSE_STALE_SECONDS` (30),
`FLOWSENSE_LANE_CAPACITY` (12).

**Never `git add` a launch config containing a real key.**

## Docs

- [`docs/api-contract.md`](docs/api-contract.md) — the backend contract.

## Tests

```bash
flutter test
dart analyze
```
