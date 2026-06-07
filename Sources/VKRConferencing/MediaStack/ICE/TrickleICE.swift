import Foundation

/// Technique 3 of §3.5 — emit ICE candidates as they're discovered instead of
/// waiting for `gatheringComplete`. Worth ~9 % on top of pre-warming + STUN
/// pre-fetch.
///
/// In the WebRTC SDK this is just a configuration switch — the candidates are
/// always discovered incrementally; Trickle ICE means we *send* them
/// incrementally over the signalling channel rather than batching.
///
/// We expose it as a stand-alone module so the experiment serialises the
/// "off" condition (legacy ICE, batched) when reproducing Table 4.8 row 0.
struct TrickleICE {
    let enabled: Bool

    func send(candidate: ICECandidatePayload, via signaling: SignalingClient, callId: UUID) {
        signaling.send(.iceCandidate(callId: callId, candidate: candidate))
    }
}
