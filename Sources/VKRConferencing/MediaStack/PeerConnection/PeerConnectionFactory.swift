import Foundation

/// Layer 4 entry point.
///
/// In production this wraps `RTCPeerConnectionFactory` from the WebRTC
/// xcframework (pulled in via SwiftPM through `project.yml`). The wrapper
/// pattern is the contract — the rest of the app talks to
/// `PeerConnectionWrapper`, not to a `RTCPeerConnection` directly.
///
/// We keep an in-tree placeholder so the *core* SwiftPM target compiles
/// without the heavy WebRTC binary; replace the body with `RTCPeerConnection`
/// calls when wiring up a real device build.
final class PeerConnectionFactory {

    func makePeerConnection(iceServers: [String],
                            preEstablishedDTLSContext: PreEstablishedDTLS.Context?) -> PeerConnectionWrapper {
        PeerConnectionWrapper(iceServers: iceServers,
                              dtlsContext: preEstablishedDTLSContext)
    }

    /// Placeholder SDP for the outgoing test path — overwritten by the real
    /// WebRTC offer in production builds.
    func placeholderOffer() -> String {
        "v=0\r\no=- 0 0 IN IP4 0.0.0.0\r\ns=VKRConferencing\r\nt=0 0\r\n"
    }
}
