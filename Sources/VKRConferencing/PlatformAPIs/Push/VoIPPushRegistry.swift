import Foundation
import PushKit

/// Owns the `PKPushRegistry` and turns VoIP push payloads into structured
/// `IncomingCall` events.
///
/// The contract from §2.14 of the thesis:
///
///   * The registry must be created on the main thread, **before** the first
///     incoming push arrives — otherwise the cold-start case (Approach C,
///     Scenario 2) won't fire `didReceiveIncomingPushWithPayload:` and the
///     call is lost.
///   * iOS 13+: whoever consumes the push *must* call
///     `CXProvider.reportNewIncomingCall(...)` within ~20 ms (we picked 20 ms
///     in line with §5 recommendations — Apple's hard ceiling is in the
///     hundreds of ms, but 20 ms leaves comfortable headroom for jitter).
final class VoIPPushRegistry: NSObject {

    /// Observers receive `(payload, completion)` and **must** call the
    /// completion before the timeout — usually after `reportNewIncomingCall`.
    typealias Handler = (PKPushPayload, @escaping () -> Void) -> Void

    private(set) var token: String?
    private let telemetry: TelemetryCollector
    private var pushRegistry: PKPushRegistry?
    private var handlers: [UUID: Handler] = [:]

    init(telemetry: TelemetryCollector) {
        self.telemetry = telemetry
    }

    func activate() {
        guard pushRegistry == nil else { return }
        let registry = PKPushRegistry(queue: .main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        self.pushRegistry = registry
        telemetry.record(.voipRegistryActivated)
    }

    @discardableResult
    func observe(_ handler: @escaping Handler) -> UUID {
        let id = UUID()
        handlers[id] = handler
        return id
    }

    func remove(observer id: UUID) {
        handlers.removeValue(forKey: id)
    }
}

extension VoIPPushRegistry: PKPushRegistryDelegate {

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        let hex = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        token = hex
        telemetry.record(.voipTokenUpdated(token: hex))
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        token = nil
        telemetry.record(.voipTokenInvalidated)
    }

    /// The whole point of Approach C. This method runs even from Suspended /
    /// Killed and gives the process a few hundred ms to call
    /// `CXProvider.reportNewIncomingCall` — see CallKitProvider.
    func pushRegistry(_ registry: PKPushRegistry,
                       didReceiveIncomingPushWith payload: PKPushPayload,
                       for type: PKPushType,
                       completion: @escaping () -> Void) {

        let receivedAt = MonotonicClock.now()
        telemetry.record(.voipPushReceived(timestamp: receivedAt))

        guard !handlers.isEmpty else {
            // No one is listening; satisfy the system contract anyway,
            // otherwise the process is killed.
            completion()
            return
        }

        // Fan-out — but ensure completion is invoked exactly once when *any*
        // handler signals back. In practice we wire a single handler at a
        // time, but the design allows multiple observers (Strategy + tests).
        let coordinator = CompletionCoordinator(completion: completion)
        for handler in handlers.values {
            handler(payload, coordinator.signal)
        }
    }
}

private final class CompletionCoordinator {
    private let completion: () -> Void
    private var fired = false
    private let lock = NSLock()

    init(completion: @escaping () -> Void) { self.completion = completion }

    func signal() {
        lock.lock(); defer { lock.unlock() }
        guard !fired else { return }
        fired = true
        completion()
    }
}
