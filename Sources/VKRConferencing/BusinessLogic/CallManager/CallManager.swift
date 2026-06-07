import Foundation
import Combine

/// Central coordinator — the "Call Manager (Session Controller)" of §3.3.
///
/// Single rule: it is the *only* component that knows about the full call
/// flow. The IncomingCallHandler tells it "a call arrived", the UI tells it
/// "accept / decline", the NetworkObserver tells it "the path changed" — and
/// CallManager owns the resulting transitions.
@MainActor
final class CallManager {

    /// How an incoming call reached us. Same data lives on `IncomingCall`,
    /// but this is the *cause* — whether we were woken by VoIP push, regular
    /// push, the live WebSocket or a local test stub.
    enum Source: String, Codable {
        case voipPush
        case apnsPush
        case webSocket
        case localSimulation
    }

    private let signaling: SignalingClient
    private let callKit: CallKitProvider
    private let audioSession: AudioSessionManager
    private let networkObserver: NetworkObserver
    private let peerConnectionFactory: PeerConnectionFactory
    private let stunPrefetcher: StunPrefetcher
    private let preEstablishedDTLS: PreEstablishedDTLS
    private let telemetry: TelemetryCollector
    private let stateStore: CallStateStore

    private var activeCall: IncomingCall?
    private var activePeer: PeerConnectionWrapper?
    private var acceptTimestamp: TimeInterval?
    private var iceRestartInProgress = false
    private var cancellables: Set<AnyCancellable> = []

    init(signaling: SignalingClient,
         callKit: CallKitProvider,
         audioSession: AudioSessionManager,
         networkObserver: NetworkObserver,
         peerConnectionFactory: PeerConnectionFactory,
         stunPrefetcher: StunPrefetcher,
         preEstablishedDTLS: PreEstablishedDTLS,
         telemetry: TelemetryCollector,
         stateStore: CallStateStore) {
        self.signaling = signaling
        self.callKit = callKit
        self.audioSession = audioSession
        self.networkObserver = networkObserver
        self.peerConnectionFactory = peerConnectionFactory
        self.stunPrefetcher = stunPrefetcher
        self.preEstablishedDTLS = preEstablishedDTLS
        self.telemetry = telemetry
        self.stateStore = stateStore

        observeSignaling()
    }

    // MARK: - Incoming call lifecycle

    func handleIncoming(call: IncomingCall, source: Source) async {
        activeCall = call
        await stateStore.transition(to: .incoming(call))

        // For Approaches A and B we do *not* hit CallKit here — the in-app
        // banner is enough. Approach C already invoked CallKit synchronously
        // in `VoIPCallKitHandler` before delegating to us.
        switch source {
        case .voipPush:
            break // CallKit already reported.
        case .apnsPush, .webSocket, .localSimulation:
            telemetry.record(.incomingCallUIShown(
                id: call.callId,
                ttiMillis: MonotonicClock.millisSince(call.receivedAt)
            ))
        }
    }

    func acceptIncoming(call: IncomingCall) {
        Task { await acceptIncoming(callId: call.callId) }
    }

    func acceptIncoming(callId: UUID) async {
        guard let call = activeCall, call.callId == callId else { return }
        acceptTimestamp = MonotonicClock.now()
        telemetry.record(.callAccepted(id: callId, source: .customUI))

        let session = CallSession(id: callId, conferenceId: call.conferenceId,
                                  startedAt: MonotonicClock.now())
        await stateStore.transition(to: .connecting(session))

        audioSession.activateForCall()

        // Build the PeerConnection — uses pre-fetched ICE candidates and
        // pre-established DTLS context if the corresponding optimisations
        // are enabled (§3.5).
        let peer = peerConnectionFactory.makePeerConnection(
            iceServers: stunPrefetcher.iceServers,
            preEstablishedDTLSContext: preEstablishedDTLS.consumeContext()
        )
        peer.onConnected = { [weak self] in
            Task { await self?.didConnect(callId: callId, session: session) }
        }
        peer.onTrickleCandidate = { [weak self] candidate in
            self?.signaling.send(.iceCandidate(callId: callId, candidate: candidate))
        }
        activePeer = peer

        // Acknowledge to the server so the caller is notified.
        signaling.send(.answer(callId: callId, sdp: peer.localAnswerSDP() ?? ""))
    }

    func declineIncoming(call: IncomingCall) {
        Task { await declineIncoming(callId: call.callId) }
    }

    func declineIncoming(callId: UUID) async {
        signaling.send(.bye(callId: callId, reason: "declined"))
        callKit.end(callId: callId)
        await terminate(callId: callId, reason: "declined")
    }

    // MARK: - Outgoing

    func startOutgoing(conferenceId: String) async {
        let callId = UUID()
        let session = CallSession(id: callId, conferenceId: conferenceId,
                                  startedAt: MonotonicClock.now())
        await stateStore.transition(to: .connecting(session))
        signaling.send(.offer(callId: callId, conferenceId: conferenceId,
                              sdp: peerConnectionFactory.placeholderOffer()))
    }

    // MARK: - Hang up

    func hangUp() {
        guard let call = activeCall else { return }
        Task { await terminate(callId: call.callId, reason: "user_hangup") }
    }

    // MARK: - Network handover

    func handleNetworkChange(_ change: NetworkObserver.PathChange) {
        guard let peer = activePeer, !iceRestartInProgress else { return }
        if case .interfaceChanged = change {
            iceRestartInProgress = true
            telemetry.record(.networkHandover(from: "previous", to: "current"))
            peer.restartICE { [weak self] in
                self?.iceRestartInProgress = false
            }
        }
    }

    // MARK: - Internals

    private func observeSignaling() {
        signaling.messages
            .sink { [weak self] message in
                guard let self else { return }
                switch message {
                case .answer(let id, let sdp):
                    self.activePeer?.apply(remoteAnswer: sdp, for: id)
                case .iceCandidate(let id, let candidate):
                    self.activePeer?.add(remoteCandidate: candidate, for: id)
                case .bye(let id, let reason):
                    Task { await self.terminate(callId: id, reason: reason) }
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func didConnect(callId: UUID, session: CallSession) async {
        guard let acceptedAt = acceptTimestamp else { return }
        let ttm = MonotonicClock.millisSince(acceptedAt)
        telemetry.record(.callConnected(id: callId, ttmMillis: ttm))
        await stateStore.transition(to: .active(session))
    }

    private func terminate(callId: UUID, reason: String) async {
        telemetry.record(.callEnded(id: callId, reason: reason))
        activePeer?.close()
        activePeer = nil
        activeCall = nil
        acceptTimestamp = nil
        audioSession.deactivate()
        await stateStore.transition(to: .idle)
    }
}
