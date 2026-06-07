import Foundation

/// Regular (non-VoIP) APNs push pipeline. Used by Approach B.
///
/// Important detail from §3.2: regular pushes on iOS *do not* guarantee
/// wake-up from Suspended. That is why Approach B's DR plateau in the
/// experiment is 66 % — Apple's delivery is best-effort.
final class ApnsPushHandler {

    typealias Handler = (ApnsPayload) -> Void

    private(set) var token: String?
    private let telemetry: TelemetryCollector
    private var handlers: [UUID: Handler] = [:]

    init(telemetry: TelemetryCollector) {
        self.telemetry = telemetry
    }

    func didRegister(token: String) {
        self.token = token
        telemetry.record(.apnsTokenUpdated(token: token))
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

    func deliver(payload: ApnsPayload) {
        telemetry.record(.apnsPushReceived(timestamp: MonotonicClock.now(), id: payload.id))
        handlers.values.forEach { $0(payload) }
    }
}

struct ApnsPayload: Equatable, Codable {
    let id: String
    let conferenceId: String
    let callerDisplayName: String
    let createdAt: TimeInterval
}
