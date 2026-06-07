import Foundation

/// Domain value type that represents a single inbound call event before the
/// user has answered. `IncomingCall` is what every `IncomingCallHandler`
/// produces and what `CallManager` consumes.
struct IncomingCall: Equatable, Identifiable {
    let callId: UUID
    let conferenceId: String
    let callerDisplayName: String
    /// Monotonic timestamp captured when the call entered the process — used
    /// later by `TelemetryCollector` to compute TTI / TTM.
    let receivedAt: TimeInterval
    let arrivalChannel: ArrivalChannel

    var id: UUID { callId }

    enum ArrivalChannel: String, Codable {
        case voipPush
        case apnsPush
        case signalingWebSocket
    }
}

/// An accepted, ongoing call session.
struct CallSession: Equatable, Identifiable {
    let id: UUID
    let conferenceId: String
    let startedAt: TimeInterval
}

/// State machine consumed by the UI. Intentionally simple: the four phases
/// the thesis cares about (idle → incoming → connecting → active) plus
/// terminal `failed`.
enum CallState: Equatable {
    case idle
    case incoming(IncomingCall)
    case connecting(CallSession)
    case active(CallSession)
    case failed(reason: String)

    var canStartOutgoing: Bool {
        if case .idle = self { return true }
        return false
    }

    var userFacingDescription: String {
        switch self {
        case .idle: return "Idle"
        case .incoming(let call): return "Incoming · \(call.callerDisplayName)"
        case .connecting: return "Connecting…"
        case .active: return "On call"
        case .failed(let reason): return "Failed: \(reason)"
        }
    }
}
