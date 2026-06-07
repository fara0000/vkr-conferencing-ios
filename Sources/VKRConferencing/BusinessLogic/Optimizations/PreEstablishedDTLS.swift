import Foundation

/// Technique 4 of §3.5 — negotiate the DTLS context up front so the per-call
/// handshake is shorter. Requires server support (§J4 in the thesis).
///
/// The token returned from `consumeContext()` is what the PeerConnection
/// uses as `dtlsFingerprint` / pre-shared cookie. If the flag is off we
/// return nil and the connection does a fresh handshake — the control case.
final class PreEstablishedDTLS {

    /// Opaque token consumed once per call. The real implementation would
    /// hold a fully negotiated TLS session resumption blob.
    struct Context: Equatable {
        let token: UUID
        let establishedAt: TimeInterval
    }

    private let flags: OptimizationFlags
    private let telemetry: TelemetryCollector
    private var current: Context?

    init(flags: OptimizationFlags, telemetry: TelemetryCollector) {
        self.flags = flags
        self.telemetry = telemetry
    }

    /// Triggered when the app launches / comes to foreground.
    func warmIfEnabled() {
        guard flags.preEstablishedDTLS else { return }
        let start = MonotonicClock.now()
        // Real impl: open a TLS session to the relay / SFU. Here we just
        // record the optimisation as having fired so the telemetry pipeline
        // can count it.
        current = Context(token: UUID(), establishedAt: MonotonicClock.now())
        telemetry.record(.dtlsPreEstablished(durationMillis: MonotonicClock.millisSince(start)))
    }

    /// Called by CallManager when a call is accepted. Single-use — once
    /// consumed the next call needs another warm-up.
    func consumeContext() -> Context? {
        defer { current = nil }
        return current
    }
}
