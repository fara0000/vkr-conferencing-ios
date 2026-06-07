# Reproducing Chapter 4 measurements with this client

The iOS test bench is one of two clients (the other being the Android client
in `vkr-conferencing-android`) used to collect every measurement in §4.5–4.9
of the thesis. The Python pipeline in `vkr-conferencing-stats` aggregates the
telemetry these clients emit.

## What the client measures, where it's measured

| Metric | Captured at | Source file |
|---|---|---|
| **TTI** — time-to-incoming-UI | from `pushReceived` to `incomingCallUIShown` | Approach C: `VoIPCallKitHandler.swift`<br>Approach A/B: `CallManager.swift` |
| **TTM** — time-to-media | from `callAccepted` to `callConnected` (first SRTP) | `CallManager.swift` + `PeerConnectionWrapper.swift` |
| **DR** — delivery ratio | per-call boolean (did `incomingCallReceived` ever fire?) | computed off-device by aggregating telemetry events |
| **RT** — recovery time | from a `network*` event to next `callConnected` event for the same call | `NetworkObserver.swift` → `CallManager.swift` |

All four are timed with `CACurrentMediaTime()` via `MonotonicClock` — never
`Date.timeIntervalSinceReferenceDate`. This is the iOS-side answer to §K3 of
the thesis: NTP cannot move the timer during a measurement.

## How a single measurement run is performed

1. Connect the device to a Mac, open `Console.app`, filter on
   `subsystem:io.vkr.conferencing`.
2. In the app, open **Settings** and pick the approach you want to measure.
3. (Optional) Toggle the optimisations you want active for the run.
4. In **Telemetry** tab you should see live event flow.
5. Place the device into the lifecycle state you're measuring:
   * Foreground → app on screen.
   * Background → home-button press.
   * Suspended  → leave alone for ~30 s after backgrounding.
   * Killed     → swipe-up from the app switcher.
6. Have the Node.js test runner in `vkr-conferencing-stats/signaling-server`
   send `n=50` incoming-call notifications. Each one is one *sample* in the
   per-cell distribution.
7. The Python pipeline then computes median, p95, bootstrap CIs and runs
   the relevant significance test.

## Mapping thesis tables to data files

The telemetry server appends a JSONL stream that the analysis pipeline
splits into the five canonical CSVs (`delivery_rate.csv`, `tti.csv`, …
`recovery_time.csv`).

The iOS client is *not* responsible for producing those CSVs — it only
emits raw events. The split happens off-device, in
`vkr-conferencing-stats/scripts/generate_dataset.py`.

## Reproducing Table 4.8 (optimisations) end-to-end

| Run | OptimizationFlags |
|---|---|
| baseline | all off |
| +PrWS | `preWarmedSignaling = true` |
| +STUN | + `stunPrefetch = true` |
| +Trickle | + `trickleICE = true` |
| +DTLS | + `preEstablishedDTLS = true` |

For each row: 50 calls, Wi-Fi baseline, Approach C, Foreground. Read TTM
from `TelemetryView` or via the telemetry pipeline.
