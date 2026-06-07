import Foundation

/// Builds the `IncomingCallHandler` for a given approach. Centralising the
/// composition in one place is what keeps `AppContainer` short and makes the
/// runtime switch (Settings → approach) a single function call.
enum IncomingCallHandlerFactory {
    static func make(approach: IncomingCallApproach,
                     callManager: CallManager,
                     signaling: SignalingClient,
                     callKit: CallKitProvider,
                     voipRegistry: VoIPPushRegistry,
                     apnsPushHandler: ApnsPushHandler,
                     telemetry: TelemetryCollector) -> IncomingCallHandler {
        switch approach {
        case .webSocketOnly:
            return WebSocketOnlyHandler(signaling: signaling,
                                       callManager: callManager,
                                       telemetry: telemetry)
        case .pushCustomUI:
            return PushCustomUIHandler(signaling: signaling,
                                      apns: apnsPushHandler,
                                      callManager: callManager,
                                      telemetry: telemetry)
        case .voipPushCallKit:
            return VoIPCallKitHandler(signaling: signaling,
                                     voipRegistry: voipRegistry,
                                     callKit: callKit,
                                     callManager: callManager,
                                     telemetry: telemetry)
        }
    }
}
