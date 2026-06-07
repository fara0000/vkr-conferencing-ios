import Foundation

/// Compile-time configuration for the test-bench.
///
/// In a production app these would come from a remote config / build settings,
/// but for an experimental client we keep them inline so reviewers can see what
/// the bench was pointed at when reading the thesis.
enum Config {

    /// WebSocket signalling URL. Defaults to the local dev server bundled in
    /// the `vkr-conferencing-stats` repository (`signaling-server/`).
    static let signalingURL: URL = {
        if let env = ProcessInfo.processInfo.environment["VKR_SIGNALING_URL"],
           let url = URL(string: env) {
            return url
        }
        return URL(string: "ws://localhost:8080/ws")!
    }()

    /// HTTP endpoint for telemetry. Each TelemetryEvent is POSTed as one
    /// JSON line — easy to ingest with `jq` or pandas.
    static let telemetryURL: URL = {
        if let env = ProcessInfo.processInfo.environment["VKR_TELEMETRY_URL"],
           let url = URL(string: env) {
            return url
        }
        return URL(string: "http://localhost:8080/events")!
    }()

    /// STUN servers. Google's public ones are fine for development; the thesis
    /// experiment used a self-hosted coturn 4.6.
    static let stunServers: [String] = [
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302"
    ]

    /// TURN credentials. Left empty by default — populate from your coturn
    /// `--user` / `--realm` config if you want to reproduce §4.2 verbatim.
    static let turnServers: [TURNCredential] = []

    /// Default approach for fresh installs. Aligns with the thesis recommendation.
    static let defaultApproach: IncomingCallApproach = .voipPushCallKit

    /// Heartbeat interval for the signalling WebSocket (seconds). The thesis
    /// uses 25 s — half of typical NAT idle timeout to keep the path alive
    /// without burning battery.
    static let signalingHeartbeatInterval: TimeInterval = 25

    /// Maximum delay before a disconnected ICE session is declared failed.
    /// §4.10 recommends ≥ 20 s — anything shorter kills calls during short
    /// blackouts (5–10 s) that the client would otherwise recover from.
    static let iceFailedTimeout: TimeInterval = 20

    /// Bundle identifier of the VoIP push topic. APNs uses
    /// `<bundle-id>.voip` as topic for VoIP push.
    static let voipPushTopic = "io.vkr.conferencing.voip"
}

struct TURNCredential: Equatable, Hashable, Codable {
    let url: String
    let username: String
    let credential: String
}
