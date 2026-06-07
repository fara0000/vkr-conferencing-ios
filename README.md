# ВКР Конференции — клиент iOS

> `vkr-conferencing-ios`

Эталонный iOS-клиент к магистерской ВКР **«Исследование подходов к разработке мобильных приложений для онлайн-конференций на основе технологий передачи мультимедийных сообщений»** (ITMO, 2026).

Реализация трёх архитектурных подходов к обработке входящих вызовов на iOS, сравниваемых в Главе 4 ВКР, плюс четыре техники оптимизации критического пути установления соединения.

## What this repo is

A working SwiftUI test-bench app that implements the **same three approaches as runtime-switchable strategies inside one binary** (paragraph 4.1 of the thesis):

| Approach | Delivery channel | Call UI | DR in Suspended (thesis result) |
|---|---|---|---|
| **A — WebSocket-Only** | only WebSocket | in-app | **0 %** |
| **B — Push + Custom UI** | regular APNs push | in-app banner | **66 %** |
| **C — VoIP Push + CallKit** | VoIP Push (PushKit) | system CallKit | **97 %** |

Switching the approach in Settings only swaps the `IncomingCallHandler` implementation — every other layer is shared. That is what makes the comparison fair.

## Architecture — 4 layers

```
┌───────────────────────────────────────────────────┐
│  1. UI Layer (SwiftUI + MVVM)                     │
│     IncomingCallView · ConferenceView · Settings  │
├───────────────────────────────────────────────────┤
│  2. Platform APIs Layer                           │
│     PushKit · CallKit · AVAudioSession · NWPath   │
├───────────────────────────────────────────────────┤
│  3. Business Logic Layer                          │
│     CallManager · SignalingClient · StateStore    │
│     TelemetryCollector · IncomingCallHandlers     │
├───────────────────────────────────────────────────┤
│  4. Media Stack Layer (WebRTC)                    │
│     RTCPeerConnection · ICE · Opus · H.264        │
└───────────────────────────────────────────────────┘
```

Each layer talks only to its neighbour. The whole point of the model is to **isolate platform-specific code** (PushKit, CallKit) from the business logic so that the three approaches become drop-in replacements behind a single protocol.

## Four optimisation techniques

Implemented inside Approach C and individually toggleable in `Settings`. Cumulative effect from the thesis (Wi-Fi baseline, TTM median):

| Technique | Source file | Cumulative Δ median |
|---|---|---|
| Pre-warming WebSocket | `BusinessLogic/Optimizations/PreWarmedSignaling.swift` | **−23 %** |
| STUN pre-fetch | `BusinessLogic/Optimizations/StunPrefetcher.swift` | **−42 %** |
| Trickle ICE | `MediaStack/ICE/TrickleICE.swift` | **−50 %** |
| Pre-established DTLS | `BusinessLogic/Optimizations/PreEstablishedDTLS.swift` | **−62 %** |

## Metrics (TelemetryCollector)

All four metrics from Chapter 4 are emitted as JSON events, timed with `CACurrentMediaTime` (monotonic — NTP-immune):

* **TTI** — time-to-incoming-UI
* **TTM** — time-to-media (first SRTP packet)
* **DR** — delivery ratio
* **RT** — recovery time after a network event

Events are POSTed to the signaling/telemetry server (see [`vkr-conferencing-stats`](../vkr-conferencing-stats)) for off-device aggregation.

## Build

Requires **Xcode 15.3 +** and an Apple Developer team for VoIP push entitlements.

```bash
open Package.swift
```

Xcode will resolve `WebRTC.xcframework` via Swift Package Manager. To enable Approach C you need:

1. A paid Apple Developer account.
2. The **Push Notifications** + **Background Modes (Voice over IP)** capabilities.
3. A VoIP push certificate uploaded to your APNs config.

For Approach A and B you can run on a personal team — they don't require VoIP entitlements.

## Configuration

`Sources/VKRConferencing/App/Config.swift` controls:

```swift
static let signalingURL    = URL(string: "wss://your-signaling-server.example/ws")!
static let stunServers     = ["stun:stun.l.google.com:19302"]
static let turnServers     = [TURNCredential(...)]
static let telemetryURL    = URL(string: "https://your-telemetry-server.example/events")!
```

Point those at the bundled Node.js server in `vkr-conferencing-stats/signaling-server` for local runs.

## Repository map

```
Sources/VKRConferencing/
├── App/                       — entry point, Config, AppDelegate
├── UI/                        — SwiftUI views and view-models (Layer 1)
├── PlatformAPIs/              — Layer 2 (PushKit, CallKit, audio, network)
├── BusinessLogic/
│   ├── CallManager/           — central session controller
│   ├── Signaling/             — WebSocket client (ws + reconnect)
│   ├── StateStore/            — reactive call-state store
│   ├── Telemetry/             — TelemetryCollector + monotonic timers
│   ├── IncomingCallHandlers/  — Strategy pattern: A / B / C
│   └── Optimizations/         — 4 optimisation techniques
├── MediaStack/                — Layer 4 (PeerConnection, ICE, codecs)
docs/
├── ARCHITECTURE.md            — detailed layer description
└── EXPERIMENT.md              — how each result from Ch.4 reproduces
```

## Related repositories

* [`vkr-conferencing-android`](../vkr-conferencing-android) — Android counterpart
* [`vkr-conferencing-stats`](../vkr-conferencing-stats) — Python statistics + Node.js signaling server
* [`vkr-conferencing-landing`](../vkr-conferencing-landing) — landing page with thesis summary

## License

MIT. See [LICENSE](LICENSE).
