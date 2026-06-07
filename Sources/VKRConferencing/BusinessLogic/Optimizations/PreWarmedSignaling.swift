import Foundation

/// Technique 1 of §3.5 — open the WebSocket while the app is moving into the
/// foreground so the TCP + TLS handshake is already done by the time a call
/// arrives. Worth ~23 % off TTM (Table 4.8).
final class PreWarmedSignaling {

    private let signaling: SignalingClient
    private let flags: OptimizationFlags

    init(signaling: SignalingClient, flags: OptimizationFlags) {
        self.signaling = signaling
        self.flags = flags
    }

    func warmIfEnabled() {
        guard flags.preWarmedSignaling else { return }
        signaling.connect()
    }
}
