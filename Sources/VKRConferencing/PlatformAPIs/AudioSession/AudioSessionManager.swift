import AVFoundation

/// One of the most fragile pieces of any iOS RTC client (§I5 of the thesis).
/// We centralise it here so the rest of the app doesn't have to think about
/// categories, modes or interruption priorities.
final class AudioSessionManager {

    private let telemetry: TelemetryCollector
    private let session: AVAudioSession = .sharedInstance()

    init(telemetry: TelemetryCollector) {
        self.telemetry = telemetry
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    /// Called by our own code path (outgoing call) — for the incoming path
    /// CallKit activates the session for us via `provider(_:didActivate:)`.
    func activateForCall() {
        do {
            try session.setCategory(.playAndRecord,
                                    mode: .voiceChat,
                                    options: [.allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            telemetry.record(.audioSessionActivated)
        } catch {
            telemetry.record(.audioSessionFailed(reason: error.localizedDescription))
        }
    }

    func deactivate() {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            telemetry.record(.audioSessionDeactivated)
        } catch {
            telemetry.record(.audioSessionFailed(reason: error.localizedDescription))
        }
    }

    func didActivateFromCallKit(_ session: AVAudioSession) {
        telemetry.record(.audioSessionActivatedByCallKit)
    }

    func didDeactivateFromCallKit(_ session: AVAudioSession) {
        telemetry.record(.audioSessionDeactivatedByCallKit)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        telemetry.record(.audioInterruption(began: type == .began))
    }
}
