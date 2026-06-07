import Foundation

/// Combines STUN servers from `Config` with optional pre-fetched candidates
/// from `StunPrefetcher`. Used by `PeerConnectionFactory`.
struct IceServersProvider {
    let stunServers: [String]
    let turnServers: [TURNCredential]

    static let `default` = IceServersProvider(
        stunServers: Config.stunServers,
        turnServers: Config.turnServers
    )
}
