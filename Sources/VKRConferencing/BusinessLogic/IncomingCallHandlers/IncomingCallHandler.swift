import Foundation

/// Strategy protocol referred to in §4.1 of the thesis as `IncomingCallHandler`.
///
/// Implementations:
///   * `WebSocketOnlyHandler` — Approach A.
///   * `PushCustomUIHandler`  — Approach B.
///   * `VoIPCallKitHandler`   — Approach C (recommended).
///
/// Each one wires *itself* up to its delivery channel and pushes
/// `IncomingCall` events into `CallManager`. The rest of the app — the UI,
/// the audio session, the media stack, the telemetry — is shared.
protocol IncomingCallHandler: AnyObject {
    var approach: IncomingCallApproach { get }
    /// True when this handler relies on the in-app banner instead of the
    /// system CallKit UI — used by the UI layer to decide whether to render
    /// the overlay.
    var rendersInAppUI: Bool { get }

    func activate()
    func deactivate()
}

/// Public-facing enum used in Settings and Telemetry events.
enum IncomingCallApproach: String, CaseIterable, Identifiable, Codable {
    /// Approach A — only WebSocket, in-app UI. DR plateau: 0 % in Suspended.
    case webSocketOnly = "A_WebSocket"

    /// Approach B — regular APNs push + custom in-app UI. DR plateau: ~66 %.
    case pushCustomUI = "B_PushCustomUI"

    /// Approach C — VoIP push + CallKit. DR plateau: ~97 %.
    case voipPushCallKit = "C_VoIP_CallKit"

    var id: String { rawValue }

    var shortLabel: String {
        switch self {
        case .webSocketOnly: return "A · WS"
        case .pushCustomUI: return "B · Push"
        case .voipPushCallKit: return "C · VoIP"
        }
    }

    var detailedDescription: String {
        switch self {
        case .webSocketOnly:
            return "Approach A — incoming calls arrive only through the WebSocket. Suspended-state DR ≈ 0 %. Useful as a control."
        case .pushCustomUI:
            return "Approach B — regular APNs push wakes the app, which renders its own banner. Suspended-state DR ≈ 66 %. UX inferior to system CallKit on the lock screen."
        case .voipPushCallKit:
            return "Approach C — VoIP push (PushKit) wakes the process from any state and CallKit renders the native incoming-call UI. Suspended-state DR ≈ 97 %. Recommended."
        }
    }
}
