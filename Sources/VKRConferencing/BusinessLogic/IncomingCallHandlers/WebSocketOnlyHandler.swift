import Foundation
import Combine

/// Approach A. The control condition of the experiment: no push at all.
///
/// This is the architecture you end up with if you treat a mobile client like
/// a desktop one — it works perfectly while the app sits in the foreground and
/// collapses to **0 % delivery in Suspended** (Table 4.5).
final class WebSocketOnlyHandler: IncomingCallHandler {

    let approach: IncomingCallApproach = .webSocketOnly
    /// No system UI, no banner — Approach A renders nothing if the app isn't
    /// visible.
    let rendersInAppUI = true

    private let signaling: SignalingClient
    private let callManager: CallManager
    private let telemetry: TelemetryCollector
    private var cancellables: Set<AnyCancellable> = []

    init(signaling: SignalingClient, callManager: CallManager, telemetry: TelemetryCollector) {
        self.signaling = signaling
        self.callManager = callManager
        self.telemetry = telemetry
    }

    func activate() {
        signaling.connect()

        signaling.messages
            .compactMap { message -> IncomingCall? in
                guard case .incomingCall(let callId, let conferenceId, let caller, _) = message else { return nil }
                return IncomingCall(
                    callId: callId,
                    conferenceId: conferenceId,
                    callerDisplayName: caller,
                    receivedAt: MonotonicClock.now(),
                    arrivalChannel: .signalingWebSocket
                )
            }
            .sink { [weak self] call in
                guard let self else { return }
                self.telemetry.record(.incomingCallReceived(id: call.callId, channel: .signalingWebSocket))
                Task { await self.callManager.handleIncoming(call: call, source: .webSocket) }
            }
            .store(in: &cancellables)
    }

    func deactivate() {
        cancellables.removeAll()
        signaling.disconnect()
    }
}
