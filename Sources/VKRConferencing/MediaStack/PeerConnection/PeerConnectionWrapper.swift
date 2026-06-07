import Foundation

/// Thin facade around `RTCPeerConnection`. The `BusinessLogic` layer talks to
/// this object only — never to the WebRTC SDK directly. That isolation lets
/// us swap stacks (Google WebRTC, libdatachannel, OpenH264-only builds) without
/// touching anything above Layer 4.
final class PeerConnectionWrapper {

    /// Fired when the underlying ICE/DTLS path turns `connected`. Drives the
    /// TTM metric (§4.3).
    var onConnected: (() -> Void)?

    /// Fired for every newly discovered local ICE candidate. With Trickle ICE
    /// enabled (§3.5 technique 3) we forward them immediately to the
    /// signalling channel instead of waiting for `gatheringComplete`.
    var onTrickleCandidate: ((ICECandidatePayload) -> Void)?

    let iceServers: [String]
    let dtlsContext: PreEstablishedDTLS.Context?

    private var localSDP: String?
    private var remoteSDP: String?

    init(iceServers: [String], dtlsContext: PreEstablishedDTLS.Context?) {
        self.iceServers = iceServers
        self.dtlsContext = dtlsContext
    }

    func localAnswerSDP() -> String? {
        if localSDP == nil {
            localSDP = "v=0\r\no=- \(UUID().uuidString) 0 IN IP4 0.0.0.0\r\ns=-\r\nt=0 0\r\n"
        }
        return localSDP
    }

    func apply(remoteAnswer sdp: String, for callId: UUID) {
        remoteSDP = sdp
        // In a real build: setRemoteDescription, then onConnected fires when
        // the ICE/DTLS path completes. We simulate the success synchronously
        // so the local test harness (Simulator) can drive the state machine.
        DispatchQueue.main.async { [weak self] in
            self?.onConnected?()
        }
    }

    func add(remoteCandidate: ICECandidatePayload, for callId: UUID) {
        // peerConnection?.add(remoteCandidate.toRTC())
    }

    func restartICE(completion: @escaping () -> Void) {
        // peerConnection?.restartIce()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion()
        }
    }

    func close() {
        // peerConnection?.close()
    }
}
