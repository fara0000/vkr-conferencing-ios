import Foundation
import Combine

/// Approach B. Regular APNs push wakes the app; the app draws its own banner.
///
/// Better than A — actually delivers from Background — but capped around
/// **66 % in Suspended** because regular pushes on iOS do not guarantee
/// wake-up from Suspended (§F9, §F12 in the thesis).
final class PushCustomUIHandler: IncomingCallHandler {

    let approach: IncomingCallApproach = .pushCustomUI
    let rendersInAppUI = true

    private let signaling: SignalingClient
    private let apns: ApnsPushHandler
    private let callManager: CallManager
    private let telemetry: TelemetryCollector
    private var apnsObserver: UUID?
    private var cancellables: Set<AnyCancellable> = []

    init(signaling: SignalingClient,
         apns: ApnsPushHandler,
         callManager: CallManager,
         telemetry: TelemetryCollector) {
        self.signaling = signaling
        self.apns = apns
        self.callManager = callManager
        self.telemetry = telemetry
    }

    func activate() {
        signaling.connect()

        apnsObserver = apns.observe { [weak self] payload in
            guard let self else { return }
            let call = IncomingCall(
                callId: UUID(uuidString: payload.id) ?? UUID(),
                conferenceId: payload.conferenceId,
                callerDisplayName: payload.callerDisplayName,
                receivedAt: MonotonicClock.now(),
                arrivalChannel: .apnsPush
            )
            self.telemetry.record(.incomingCallReceived(id: call.callId, channel: .apnsPush))
            Task { await self.callManager.handleIncoming(call: call, source: .apnsPush) }
        }

        // The WebSocket also delivers calls for active sessions — used as a
        // best-effort fast path while the app *is* foregrounded.
        signaling.messages
            .compactMap { msg -> IncomingCall? in
                guard case .incomingCall(let id, let conf, let caller, _) = msg else { return nil }
                return IncomingCall(callId: id, conferenceId: conf,
                                    callerDisplayName: caller,
                                    receivedAt: MonotonicClock.now(),
                                    arrivalChannel: .signalingWebSocket)
            }
            .sink { [weak self] call in
                self?.telemetry.record(.incomingCallReceived(id: call.callId, channel: .signalingWebSocket))
                Task { await self?.callManager.handleIncoming(call: call, source: .webSocket) }
            }
            .store(in: &cancellables)
    }

    func deactivate() {
        if let observer = apnsObserver { apns.remove(observer: observer) }
        apnsObserver = nil
        cancellables.removeAll()
        signaling.disconnect()
    }
}
