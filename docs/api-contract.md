# FlowSense Mobile API Contract

The contract between the FlowSense edge connector's output and the two mobile
flavors (`warga`, `operator`). **This service does not exist yet.** The connector
plan ends at `data/connector_<camera_id>.jsonl` on local disk; someone still has
to build the HTTP surface described here. Until then the app runs on
`FakeFlowSenseApi` backed by fixtures in `test/fixtures/`.

Base URL comes from `--dart-define=FLOWSENSE_API_BASE`. Every request carries
the header `X-FlowSense-Key: <FLOWSENSE_API_KEY>`, mirroring the connector's
`X-SDC`.

## Endpoints

| Endpoint | Returns |
|---|---|
| `GET /v1/intersections` | `[{id, name, lat, lon, lanes: [str], capacity: {lane: int}}]` |
| `GET /v1/snapshot` | `{ts, items: [TrafficRecord]}` — latest record for every intersection, one call, used by the map |
| `GET /v1/intersections/{id}/latest` | one `TrafficRecord` |
| `GET /v1/intersections/{id}/history?from=&to=&bucket=1m` | `[TrafficRecord]`, time-bucketed |

## Two rules the backend must honour

1. **`ts` is epoch seconds** — an integer, matching the connector's
   `build_record`. Not milliseconds, not ISO-8601. The app multiplies by 1000
   and reads the result as UTC.
2. **`per_lane` keys are the ROI lane names from `config/rois.json`** — verbatim.
   The app never invents, normalises, or translates lane names; it renders
   whatever keys arrive. A lane appearing mid-session is a supported case.

## `TrafficRecord`

The connector's `.jsonl` line verbatim.

| Field | Type | Notes |
|---|---|---|
| `ts` | int | epoch **seconds** |
| `camera_id` | int \| string | normalised to `String` client-side |
| `camera` | string | human-readable name |
| `total_vehicles` | int | |
| `per_lane` | `{string: int}` | ROI lane names → counts |
| `crossings` | `{string: int}` | **optional**, cumulative line crossings |

Unknown keys are ignored by the client, not rejected — the connector team can
add fields without shipping a new APK.

### Sample

```json
{"ts":1755000000,"camera_id":30,"camera":"Simpang DPRD Arah Kota","total_vehicles":4,"per_lane":{"kota":2,"ploso":2}}
```

With optional `crossings`:

```json
{"ts":1755000002,"camera_id":30,"camera":"Simpang DPRD Arah Kota","total_vehicles":9,"per_lane":{"kota":5,"ploso":4},"crossings":{"kota":12,"ploso":7}}
```

## `GET /v1/intersections`

`capacity` values must come from calibration — count the vehicles that
physically fit in each ROI at standstill. The client falls back to
`FLOWSENSE_LANE_CAPACITY` (default 12) only when a lane is missing from
`capacity`, and the congestion classification is only as good as this number.

```json
[
  {
    "id": "30",
    "name": "Simpang DPRD",
    "lat": -6.8047,
    "lon": 110.8405,
    "lanes": ["kota", "ploso"],
    "capacity": {"kota": 14, "ploso": 10}
  }
]
```

## `GET /v1/snapshot`

One call, the latest record per intersection. This is the map's only hot path.

```json
{
  "ts": 1755000004,
  "items": [
    {"ts":1755000004,"camera_id":"30","camera":"Simpang DPRD Arah Kota","total_vehicles":6,"per_lane":{"kota":4,"ploso":2}},
    {"ts":1755000003,"camera_id":"31","camera":"Simpang Tanjung","total_vehicles":11,"per_lane":{"utara":8,"selatan":3},"crossings":{"utara":41,"selatan":19}}
  ]
}
```

Per-item `ts` may lag the envelope `ts`; the client judges staleness per record,
not per response.

## `GET /v1/intersections/{id}/latest`

A bare `TrafficRecord` — same shape as one `items` entry above.

## `GET /v1/intersections/{id}/history`

`from` and `to` are epoch seconds; `bucket` is a duration string (`1m`, `5m`).
Returns records ordered oldest-first, one per bucket, `total_vehicles` averaged
or maxed by the server's choice — the client only plots what it receives.

```json
[
  {"ts":1754996400,"camera_id":"30","camera":"Simpang DPRD Arah Kota","total_vehicles":3,"per_lane":{"kota":2,"ploso":1}},
  {"ts":1754996460,"camera_id":"30","camera":"Simpang DPRD Arah Kota","total_vehicles":7,"per_lane":{"kota":5,"ploso":2}}
]
```

## Errors

| Status | Client behaviour |
|---|---|
| 2xx | parse; malformed JSON surfaces as `ApiException`, never `FormatException` |
| 401 / 403 | **no retry** — a bad key will never fix itself |
| 5xx, timeout, socket error | retry with backoff `base * 2^attempt`, then `ApiException` |

The app is **read-only**. There are no write endpoints, and neither flavor sends
control commands or signal actuation.
