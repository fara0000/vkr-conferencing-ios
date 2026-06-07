import Foundation
import CallKit
import AVFoundation
import UIKit

/// Thin facade around `CXProvider` / `CXCallController`.
///
/// Crucial responsibilities (§2.14, §H5 of the thesis):
///
///   1. Report an incoming VoIP push to the system **inside ~20 ms** of
///      receiving the push (iOS 13+ contract — measured in §H1).
///   2. Drive the audio session at the right moment: even in Foreground we
///      register the call through CallKit because that's how iOS hands us a
///      properly configured `AVAudioSession`.
final class CallKitProvider: NSObject {

    typealias AnswerHandler = (UUID) -> Void
    typealias EndHandler = (UUID) -> Void

    private let provider: CXProvider
    private let controller = CXCallController()
    private let telemetry: TelemetryCollector
    private let audioSession: AudioSessionManager

    private var answerHandlers: [UUID: AnswerHandler] = [:]
    private var endHandlers: [UUID: EndHandler] = [:]

    init(telemetry: TelemetryCollector, audioSession: AudioSessionManager) {
        self.telemetry = telemetry
        self.audioSession = audioSession

        let config = CXProviderConfiguration()
        config.supportsVideo = true
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        if let iconData = UIImage(systemName: "phone.fill")?.pngData() {
            config.iconTemplateImageData = iconData
        }
        self.provider = CXProvider(configuration: config)
        super.init()
        self.provider.setDelegate(self, queue: .main)
    }

    /// Schedule an incoming call with the system. **Must** be invoked
    /// synchronously after a VoIP push (§F12, §H1).
    func reportIncoming(call: IncomingCall, completion: @escaping (Error?) -> Void) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: call.callerDisplayName)
        update.hasVideo = true
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false

        let reportedAt = MonotonicClock.now()
        provider.reportNewIncomingCall(with: call.callId, update: update) { [weak self] error in
            let elapsed = MonotonicClock.now() - reportedAt
            self?.telemetry.record(.callKitReported(callId: call.callId,
                                                   elapsedMillis: elapsed * 1000,
                                                   succeeded: error == nil))
            completion(error)
        }
    }

    /// End a call we previously reported — for the explicit `Decline` flow.
    func end(callId: UUID, reason: CXCallEndedReason = .remoteEnded) {
        provider.reportCall(with: callId, endedAt: nil, reason: reason)
    }

    func registerAnswerHandler(_ handler: @escaping AnswerHandler) {
        answerHandlers[UUID()] = handler
    }

    func registerEndHandler(_ handler: @escaping EndHandler) {
        endHandlers[UUID()] = handler
    }
}

extension CallKitProvider: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        telemetry.record(.callKitDidReset)
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        audioSession.activateForCall()
        answerHandlers.values.forEach { $0(action.callUUID) }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        audioSession.deactivate()
        endHandlers.values.forEach { $0(action.callUUID) }
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        self.audioSession.didActivateFromCallKit(audioSession)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        self.audioSession.didDeactivateFromCallKit(audioSession)
    }
}
