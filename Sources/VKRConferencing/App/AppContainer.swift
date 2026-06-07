import Foundation
import Combine

/// Dependency container.
///
/// Composes every layer of the four-layer model into a single object that
/// SwiftUI views can pull off the environment. The split mirrors §3.3 of the
/// thesis exactly:
///
///   • Layer 2 (Platform APIs)  →  voipRegistry, apnsPushHandler, callKit,
///                                 audioSession, networkObserver
///   • Layer 3 (Business Logic) →  callManager, signalingClient, callStateStore,
///                                 telemetry, incomingCallHandler, optimisations
///   • Layer 4 (Media Stack)    →  peerConnectionFactory
///
/// The UI layer (Layer 1) consumes this container as `@EnvironmentObject`.
final class AppContainer: ObservableObject {

    static let shared = AppContainer()

    // MARK: - Settings & state (shared by UI)

    let settings: SettingsStore
    let callStateStore: CallStateStore

    // MARK: - Layer 2 — Platform APIs

    let voipRegistry: VoIPPushRegistry
    let apnsPushHandler: ApnsPushHandler
    let callKit: CallKitProvider
    let audioSession: AudioSessionManager
    let networkObserver: NetworkObserver

    // MARK: - Layer 3 — Business Logic

    let signalingClient: SignalingClient
    let telemetry: TelemetryCollector
    let callManager: CallManager
    let preWarmedSignaling: PreWarmedSignaling
    let stunPrefetcher: StunPrefetcher
    let preEstablishedDTLS: PreEstablishedDTLS

    /// Strategy slot — swapping this object is the only thing that changes
    /// when the user picks a different approach in Settings. Everything else
    /// is shared, which is what makes the comparison in Chapter 4 honest.
    @Published private(set) var incomingCallHandler: IncomingCallHandler

    // MARK: - Layer 4 — Media stack

    let peerConnectionFactory: PeerConnectionFactory

    // MARK: - Plumbing

    private var cancellables: Set<AnyCancellable> = []

    private init() {
        let settings = SettingsStore()
        self.settings = settings

        let store = CallStateStore()
        self.callStateStore = store

        let telemetry = TelemetryCollector(endpoint: Config.telemetryURL)
        self.telemetry = telemetry

        let peerConnectionFactory = PeerConnectionFactory()
        self.peerConnectionFactory = peerConnectionFactory

        let signaling = SignalingClient(url: Config.signalingURL, telemetry: telemetry)
        self.signalingClient = signaling

        let audio = AudioSessionManager(telemetry: telemetry)
        self.audioSession = audio

        let callKit = CallKitProvider(telemetry: telemetry, audioSession: audio)
        self.callKit = callKit

        let network = NetworkObserver(telemetry: telemetry)
        self.networkObserver = network

        let voipRegistry = VoIPPushRegistry(telemetry: telemetry)
        self.voipRegistry = voipRegistry

        let apns = ApnsPushHandler(telemetry: telemetry)
        self.apnsPushHandler = apns

        let preWarm = PreWarmedSignaling(signaling: signaling, flags: settings.optimizationFlags)
        self.preWarmedSignaling = preWarm

        let stunPrefetch = StunPrefetcher(servers: Config.stunServers,
                                          telemetry: telemetry,
                                          flags: settings.optimizationFlags)
        self.stunPrefetcher = stunPrefetch

        let preDTLS = PreEstablishedDTLS(flags: settings.optimizationFlags,
                                        telemetry: telemetry)
        self.preEstablishedDTLS = preDTLS

        let callManager = CallManager(
            signaling: signaling,
            callKit: callKit,
            audioSession: audio,
            networkObserver: network,
            peerConnectionFactory: peerConnectionFactory,
            stunPrefetcher: stunPrefetch,
            preEstablishedDTLS: preDTLS,
            telemetry: telemetry,
            stateStore: store
        )
        self.callManager = callManager

        // Build the initial Strategy.
        self.incomingCallHandler = IncomingCallHandlerFactory.make(
            approach: settings.approach,
            callManager: callManager,
            signaling: signaling,
            callKit: callKit,
            voipRegistry: voipRegistry,
            apnsPushHandler: apns,
            telemetry: telemetry
        )

        // Hot-swap the Strategy whenever the user toggles approach in Settings.
        settings.$approach
            .removeDuplicates()
            .sink { [weak self] newApproach in
                guard let self else { return }
                self.swapHandler(to: newApproach)
            }
            .store(in: &cancellables)

        // Network changes trigger ICE Restart on the active call.
        network.pathChanged
            .sink { [weak self] change in
                guard let self else { return }
                self.callManager.handleNetworkChange(change)
            }
            .store(in: &cancellables)
    }

    private func swapHandler(to approach: IncomingCallApproach) {
        incomingCallHandler.deactivate()
        let next = IncomingCallHandlerFactory.make(
            approach: approach,
            callManager: callManager,
            signaling: signalingClient,
            callKit: callKit,
            voipRegistry: voipRegistry,
            apnsPushHandler: apnsPushHandler,
            telemetry: telemetry
        )
        next.activate()
        incomingCallHandler = next
        telemetry.record(.approachSwitched(to: approach))
    }
}
