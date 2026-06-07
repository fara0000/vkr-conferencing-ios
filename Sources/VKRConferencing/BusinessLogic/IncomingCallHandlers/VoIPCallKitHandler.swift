import Foundation
import Combine
import PushKit

/// Approach C — the recommendation of the thesis.
///
/// Pipeline:
///   1. VoIP push (PushKit) wakes the process — from any state, including
///      Suspended and freshly post-reboot.
///   2. The handler synchronously asks `CallKitProvider` to call
///      `CXProvider.reportNewIncomingCall(...)` — must happen inside the
///      VoIP push completion (§F12, §H1).
///   3. Only then do we go off and open / reuse the WebSocket to pull the
///      actual SDP offer. That keeps step 2 well inside Apple's hard budget.
///
/// Result: DR ≈ 97 % in Suspended, native call UI on the lock screen.
final class VoIPCallKitHandler: IncomingCallHandler {

    let approach: IncomingCallApproach = .voipPushCallKit
    /// The whole point of Approach C is to *not* render in-app UI for the
    /// incoming surface — CallKit owns it.
    let rendersInAppUI = false

    private let signaling: SignalingClient
    private let voipRegistry: VoIPPushRegistry
    private let callKit: CallKitProvider
    private let callManager: CallManager
    private let telemetry: TelemetryCollector
    private var voipObserver: UUID?

    init(signaling: SignalingClient,
         voipRegistry: VoIPPushRegistry,
         callKit: CallKitProvider,
         callManager: CallManager,
         telemetry: TelemetryCollector) {
        self.signaling = signaling
        self.voipRegistry = voipRegistry
        self.callKit = callKit
        self.callManager = callManager
        self.telemetry = telemetry
    }

    func activate() {
        // 1. Always make sure the registry is alive — it might have been
        //    activated by AppDelegate already, this is idempotent.
        voipRegistry.activate()

        // 2. Wire callbacks so CallKit's answer/end actions reach CallManager.
        callKit.registerAnswerHandler { [weak self] callId in
            self?.telemetry.record(.callAccepted(id: callId, source: .callKitUI))
            Task { await self?.callManager.acceptIncoming(callId: callId) }
        }
        callKit.registerEndHandler { [weak self] callId in
            self?.telemetry.record(.callEnded(id: callId, reason: "callkit"))
            Task { await self?.callManager.declineIncoming(callId: callId) }
        }

        // 3. The actual hot path: VoIP push → CallKit → CallManager.
        voipObserver = voipRegistry.observe { [weak self] payload, completion in
            guard let self else { completion(); return }
            self.process(payload: payload, completion: completion)
        }

        // 4. Keep the WebSocket warm for outgoing + active-call signalling.
        signaling.connect()
    }

    func deactivate() {
        if let id = voipObserver { voipRegistry.remove(observer: id) }
        voipObserver = nil
        signaling.disconnect()
    }

    // MARK: - Hot path

    private func process(payload: PKPushPayload, completion: @escaping () -> Void) {
        let pushReceivedAt = MonotonicClock.now()
        guard let callIdString = payload.dictionaryPayload["callId"] as? String,
              let callId = UUID(uuidString: callIdString),
              let conferenceId = payload.dictionaryPayload["conferenceId"] as? String,
              let caller = payload.dictionaryPayload["caller"] as? String else {
            // Even malformed pushes must complete — otherwise the OS will
            // kill the process (§F12, iOS 13+ contract).
            completion()
            return
        }

        let call = IncomingCall(
            callId: callId,
            conferenceId: conferenceId,
            callerDisplayName: caller,
            receivedAt: pushReceivedAt,
            arrivalChannel: .voipPush
        )

        telemetry.record(.incomingCallReceived(id: call.callId, channel: .voipPush))

        // SYNCHRONOUS — call into CallKit before doing anything else.
        callKit.reportIncoming(call: call) { [weak self] error in
            guard let self else { completion(); return }
            let uiShownAt = MonotonicClock.now()
            let tti = (uiShownAt - pushReceivedAt) * 1000
            self.telemetry.record(.incomingCallUIShown(id: call.callId, ttiMillis: tti))

            // Now and only now we can go off to fetch the offer over the
            // (possibly cold-started) signalling channel. CallKit is already
            // on screen by this point — the user can answer at any moment.
            Task { await self.callManager.handleIncoming(call: call, source: .voipPush) }
            completion()

            if let error {
                self.telemetry.record(.callEnded(id: call.callId, reason: "callkit_error: \(error)"))
            }
        }
    }
}

