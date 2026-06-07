import Foundation

/// Tiny JSON-tagged signaling envelope shared with the Node.js server in
/// `vkr-conferencing-stats/signaling-server`. Intentionally small so it can
/// be inspected with `jq` during the experiment.
enum SignalingMessage: Equatable, Codable {
    case hello(clientId: String, voipToken: String?)
    case offer(callId: UUID, conferenceId: String, sdp: String)
    case answer(callId: UUID, sdp: String)
    case iceCandidate(callId: UUID, candidate: ICECandidatePayload)
    case incomingCall(callId: UUID, conferenceId: String, caller: String, sentAt: TimeInterval)
    case bye(callId: UUID, reason: String)
    case heartbeat
    case ack(messageId: UUID)

    var kind: String {
        switch self {
        case .hello: return "hello"
        case .offer: return "offer"
        case .answer: return "answer"
        case .iceCandidate: return "iceCandidate"
        case .incomingCall: return "incomingCall"
        case .bye: return "bye"
        case .heartbeat: return "heartbeat"
        case .ack: return "ack"
        }
    }

    enum CodingKeys: String, CodingKey { case kind, payload }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)
        switch kind {
        case "hello":
            let p = try container.decode(HelloPayload.self, forKey: .payload)
            self = .hello(clientId: p.clientId, voipToken: p.voipToken)
        case "offer":
            let p = try container.decode(OfferPayload.self, forKey: .payload)
            self = .offer(callId: p.callId, conferenceId: p.conferenceId, sdp: p.sdp)
        case "answer":
            let p = try container.decode(AnswerPayload.self, forKey: .payload)
            self = .answer(callId: p.callId, sdp: p.sdp)
        case "iceCandidate":
            let p = try container.decode(IcePayload.self, forKey: .payload)
            self = .iceCandidate(callId: p.callId, candidate: p.candidate)
        case "incomingCall":
            let p = try container.decode(IncomingCallPayload.self, forKey: .payload)
            self = .incomingCall(callId: p.callId, conferenceId: p.conferenceId, caller: p.caller, sentAt: p.sentAt)
        case "bye":
            let p = try container.decode(ByePayload.self, forKey: .payload)
            self = .bye(callId: p.callId, reason: p.reason)
        case "heartbeat":
            self = .heartbeat
        case "ack":
            let p = try container.decode(AckPayload.self, forKey: .payload)
            self = .ack(messageId: p.messageId)
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: container,
                                                  debugDescription: "Unknown signaling kind \(kind)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        switch self {
        case .hello(let clientId, let token):
            try container.encode(HelloPayload(clientId: clientId, voipToken: token), forKey: .payload)
        case .offer(let id, let conf, let sdp):
            try container.encode(OfferPayload(callId: id, conferenceId: conf, sdp: sdp), forKey: .payload)
        case .answer(let id, let sdp):
            try container.encode(AnswerPayload(callId: id, sdp: sdp), forKey: .payload)
        case .iceCandidate(let id, let cand):
            try container.encode(IcePayload(callId: id, candidate: cand), forKey: .payload)
        case .incomingCall(let id, let conf, let caller, let sentAt):
            try container.encode(IncomingCallPayload(callId: id, conferenceId: conf,
                                                    caller: caller, sentAt: sentAt),
                                 forKey: .payload)
        case .bye(let id, let reason):
            try container.encode(ByePayload(callId: id, reason: reason), forKey: .payload)
        case .heartbeat:
            try container.encodeNil(forKey: .payload)
        case .ack(let messageId):
            try container.encode(AckPayload(messageId: messageId), forKey: .payload)
        }
    }
}

struct ICECandidatePayload: Equatable, Codable {
    let sdpMid: String?
    let sdpMLineIndex: Int32
    let candidate: String
}

private struct HelloPayload: Codable { let clientId: String; let voipToken: String? }
private struct OfferPayload: Codable { let callId: UUID; let conferenceId: String; let sdp: String }
private struct AnswerPayload: Codable { let callId: UUID; let sdp: String }
private struct IcePayload: Codable { let callId: UUID; let candidate: ICECandidatePayload }
private struct IncomingCallPayload: Codable { let callId: UUID; let conferenceId: String; let caller: String; let sentAt: TimeInterval }
private struct ByePayload: Codable { let callId: UUID; let reason: String }
private struct AckPayload: Codable { let messageId: UUID }
