import Foundation

/// Exponential backoff with jitter — §M7 in the thesis: the WebSocket
/// reconnect must survive short blackouts without burning the user's battery.
///
/// 0.5 s → 1 s → 2 s → 4 s … capped at 30 s. Jitter ±20 % to avoid the well
/// known thundering-herd effect after a global blackout.
struct ReconnectStrategy {
    var initialDelay: TimeInterval = 0.5
    var maxDelay: TimeInterval = 30
    var multiplier: Double = 2
    var jitter: Double = 0.2

    private var attempt = 0

    mutating func nextDelay() -> TimeInterval {
        defer { attempt += 1 }
        let base = min(initialDelay * pow(multiplier, Double(attempt)), maxDelay)
        let spread = base * jitter
        return base + Double.random(in: -spread...spread)
    }

    mutating func reset() { attempt = 0 }
}
