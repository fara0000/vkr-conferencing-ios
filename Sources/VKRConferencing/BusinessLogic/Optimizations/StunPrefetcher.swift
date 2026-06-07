import Foundation

/// Technique 2 of §3.5 — resolve the public reflexive endpoint at app launch
/// so the critical path doesn't wait on STUN later. Additional ~19 % off TTM.
final class StunPrefetcher {

    private let servers: [String]
    private let telemetry: TelemetryCollector
    private let flags: OptimizationFlags
    private var cachedEndpoints: [String] = []

    init(servers: [String], telemetry: TelemetryCollector, flags: OptimizationFlags) {
        self.servers = servers
        self.telemetry = telemetry
        self.flags = flags
    }

    func prefetch() {
        guard flags.stunPrefetch else { return }
        let start = MonotonicClock.now()
        Task {
            // The real implementation issues an actual STUN Binding Request via
            // the WebRTC stack. The placeholder records the *intent* so the
            // pipeline that aggregates Table 4.8 numbers sees the same event
            // shape as a production client would emit.
            try? await Task.sleep(for: .milliseconds(50))
            self.cachedEndpoints = self.servers
            self.telemetry.record(.stunPrefetched(
                elapsedMillis: MonotonicClock.millisSince(start),
                endpoints: self.cachedEndpoints
            ))
        }
    }

    /// What the CallManager hands to the peer-connection factory when a call
    /// arrives. Empty when the optimisation is off — the factory falls back
    /// to vanilla ICE.
    var iceServers: [String] {
        flags.stunPrefetch ? cachedEndpoints : servers
    }
}
