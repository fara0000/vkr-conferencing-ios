import XCTest
@testable import VKRConferencingCore

/// Smoke tests for the Business Logic layer that don't need WebRTC.
///
/// The integration tests that exercise the full CallKit + PushKit pipeline
/// live alongside the iOS app target (UI tests) — they need a real device.
final class IncomingCallHandlerTests: XCTestCase {

    func testApproachEnumStable() {
        XCTAssertEqual(IncomingCallApproach.allCases.count, 3)
        XCTAssertEqual(IncomingCallApproach.voipPushCallKit.rawValue, "C_VoIP_CallKit")
    }

    func testCallStateTransitions() {
        XCTAssertTrue(CallState.idle.canStartOutgoing)
        XCTAssertFalse(CallState.connecting(.preview).canStartOutgoing)
        XCTAssertFalse(CallState.active(.preview).canStartOutgoing)
    }

    func testReconnectStrategyMonotonic() {
        var strategy = ReconnectStrategy(initialDelay: 0.5,
                                         maxDelay: 30,
                                         multiplier: 2,
                                         jitter: 0)
        XCTAssertEqual(strategy.nextDelay(), 0.5, accuracy: 0.001)
        XCTAssertEqual(strategy.nextDelay(), 1.0, accuracy: 0.001)
        XCTAssertEqual(strategy.nextDelay(), 2.0, accuracy: 0.001)
        XCTAssertEqual(strategy.nextDelay(), 4.0, accuracy: 0.001)
        // Cap at maxDelay
        for _ in 0..<20 { _ = strategy.nextDelay() }
        XCTAssertLessThanOrEqual(strategy.nextDelay(), 30.0)
    }

    func testOptimizationFlagsCoding() throws {
        let flags = OptimizationFlags(preWarmedSignaling: true,
                                      stunPrefetch: true,
                                      trickleICE: true,
                                      preEstablishedDTLS: true)
        let data = try JSONEncoder().encode(flags)
        let decoded = try JSONDecoder().decode(OptimizationFlags.self, from: data)
        XCTAssertEqual(decoded, flags)
    }
}

private extension CallSession {
    static var preview: CallSession {
        CallSession(id: UUID(), conferenceId: "preview", startedAt: 0)
    }
}
