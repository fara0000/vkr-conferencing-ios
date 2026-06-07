# Architecture — VKR Conferencing iOS

This document explains how the source maps onto the **four-layer component
model** from §3.3 of the thesis, and which Swift file owns each box.

```
┌────────────────────────────────────────────────────────────────────┐
│ Layer 1 — UI (SwiftUI + MVVM)                                      │
│ ▪ RootView.swift                                                   │
│ ▪ IncomingCallView.swift + IncomingCallViewModel.swift             │
│ ▪ ConferenceView.swift                                             │
│ ▪ SettingsView.swift + SettingsStore.swift                         │
│ ▪ TelemetryView.swift                                              │
├────────────────────────────────────────────────────────────────────┤
│ Layer 2 — Platform APIs                                            │
│ ▪ Push/VoIPPushRegistry.swift            (PushKit)                 │
│ ▪ Push/ApnsPushHandler.swift             (regular APNs)            │
│ ▪ CallUI/CallKitProvider.swift           (CXProvider + delegate)   │
│ ▪ AudioSession/AudioSessionManager.swift (AVAudioSession)          │
│ ▪ NetworkObserver/NetworkObserver.swift  (NWPathMonitor)           │
├────────────────────────────────────────────────────────────────────┤
│ Layer 3 — Business Logic                                           │
│ ▪ CallManager/CallManager.swift                                    │
│ ▪ Signaling/SignalingClient.swift + ReconnectStrategy.swift        │
│ ▪ Signaling/SignalingMessage.swift                                 │
│ ▪ StateStore/CallState.swift + CallStateStore.swift                │
│ ▪ Telemetry/TelemetryCollector.swift + MonotonicClock.swift        │
│ ▪ IncomingCallHandlers/                                            │
│   ├ IncomingCallHandler.swift (protocol)                           │
│   ├ WebSocketOnlyHandler.swift  ── Approach A                      │
│   ├ PushCustomUIHandler.swift   ── Approach B                      │
│   ├ VoIPCallKitHandler.swift    ── Approach C (recommended)        │
│   └ IncomingCallHandlerFactory.swift                               │
│ ▪ Optimizations/                                                   │
│   ├ OptimizationFlags.swift                                        │
│   ├ PreWarmedSignaling.swift                                       │
│   ├ StunPrefetcher.swift                                           │
│   └ PreEstablishedDTLS.swift                                       │
├────────────────────────────────────────────────────────────────────┤
│ Layer 4 — Media Stack (Google WebRTC)                              │
│ ▪ PeerConnection/PeerConnectionFactory.swift                       │
│ ▪ PeerConnection/PeerConnectionWrapper.swift                       │
│ ▪ ICE/IceServersProvider.swift                                     │
│ ▪ ICE/TrickleICE.swift                                             │
│ ▪ Codecs/CodecPreferences.swift                                    │
└────────────────────────────────────────────────────────────────────┘
```

## Strategy boundary

The dotted line between Layer 2 and Layer 3 — `IncomingCallHandler` — is the
**only** place the three approaches differ. The handler is responsible for:

1. Subscribing to its delivery channel (WebSocket / APNs / VoIP push).
2. Translating the raw payload into a `IncomingCall` domain value.
3. For Approach C *only*: calling `CXProvider.reportNewIncomingCall(...)`
   **synchronously**, before yielding to async signalling code (§F12, §H1).

Everything below that line — `CallManager`, `PeerConnectionWrapper`, the
audio session, the network observer, the telemetry pipeline — is **shared**.
That is what §4.1 of the thesis means when it talks about the comparison
being "fair": the same binary runs, only the strategy slot changes.

## Inter-layer rules

* Layer 1 reads state out of `CallStateStore` and calls methods on
  `CallManager`. Nothing in Layer 1 imports anything from Layer 4.
* Layer 2 emits raw OS events (push payloads, network status changes) into
  Layer 3 via Combine subjects / callbacks. It never touches the UI directly.
* Layer 3 is the only place that owns mutable state. Everything else is a
  view of that state.
* Layer 4 talks to the network on its own thread and reports back via
  `PeerConnectionWrapper`'s closures. It has zero knowledge of CallKit or
  PushKit.

## Where the four optimisations sit

| Technique | File | Cumulative Δ TTM median |
|---|---|---|
| Pre-warming WebSocket | `BusinessLogic/Optimizations/PreWarmedSignaling.swift` | −23 % |
| STUN pre-fetch | `BusinessLogic/Optimizations/StunPrefetcher.swift` | −42 % |
| Trickle ICE | `MediaStack/ICE/TrickleICE.swift` | −50 % |
| Pre-established DTLS | `BusinessLogic/Optimizations/PreEstablishedDTLS.swift` | −62 % |

Each one is gated on a flag in `OptimizationFlags` so the experiment can
toggle them independently and reproduce Table 4.8 row by row.
