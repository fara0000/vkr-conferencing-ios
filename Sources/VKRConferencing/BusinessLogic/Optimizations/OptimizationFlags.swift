import Foundation

/// Toggleable optimisations from §3.5. The thesis recommends turning all four
/// on (Wi-Fi median TTM falls from 2780 → 1050 ms — see Table 4.8); the flags
/// exist so the test bench can reproduce the per-technique deltas.
struct OptimizationFlags: Codable, Equatable {
    /// −22.7 % off TTM median (Table 4.8). Single biggest single-technique win.
    var preWarmedSignaling: Bool

    /// Additional −19 % (cumulative −41.7 %). Resolve the public IP at app
    /// launch so the critical path no longer waits on STUN.
    var stunPrefetch: Bool

    /// Additional −8.7 % (cumulative −50.4 %). Cheapest of all — just a
    /// configuration switch on a modern WebRTC stack.
    var trickleICE: Bool

    /// Additional −11.8 % (cumulative −62.2 %). Requires server support.
    var preEstablishedDTLS: Bool

    static let allEnabled = OptimizationFlags(preWarmedSignaling: true,
                                              stunPrefetch: true,
                                              trickleICE: true,
                                              preEstablishedDTLS: false)

    static let baseline = OptimizationFlags(preWarmedSignaling: false,
                                            stunPrefetch: false,
                                            trickleICE: false,
                                            preEstablishedDTLS: false)
}
