import Foundation
import Network
import Combine

/// Observes the OS-level network path so the `CallManager` can fire an
/// ICE Restart on Wi-Fi ↔ LTE handover (§2.17 and Scenario 1 of §3.4).
final class NetworkObserver {

    /// What just changed about the path. Subscribers (`CallManager`)
    /// react by triggering ICE Restart.
    enum PathChange: Equatable {
        case becameSatisfied(interface: NWInterface.InterfaceType?)
        case becameUnsatisfied(reason: String)
        case interfaceChanged(from: NWInterface.InterfaceType?, to: NWInterface.InterfaceType?)
    }

    let pathChanged = PassthroughSubject<PathChange, Never>()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "vkr.network.observer")
    private let telemetry: TelemetryCollector

    private var lastInterface: NWInterface.InterfaceType?
    private var lastStatus: NWPath.Status?

    init(telemetry: TelemetryCollector) {
        self.telemetry = telemetry

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.handle(path: path)
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func handle(path: NWPath) {
        let currentInterface = primaryInterface(of: path)
        defer {
            lastInterface = currentInterface
            lastStatus = path.status
        }

        switch (lastStatus, path.status) {
        case (.some(.satisfied), .unsatisfied):
            telemetry.record(.networkUnsatisfied)
            pathChanged.send(.becameUnsatisfied(reason: "path.unsatisfied"))
        case (.some(.unsatisfied), .satisfied),
             (nil, .satisfied):
            telemetry.record(.networkSatisfied(interface: currentInterface?.label ?? "unknown"))
            pathChanged.send(.becameSatisfied(interface: currentInterface))
        default:
            break
        }

        if let last = lastInterface, last != currentInterface {
            telemetry.record(.networkHandover(from: last.label, to: currentInterface?.label ?? "none"))
            pathChanged.send(.interfaceChanged(from: last, to: currentInterface))
        }
    }

    private func primaryInterface(of path: NWPath) -> NWInterface.InterfaceType? {
        if path.usesInterfaceType(.wifi) { return .wifi }
        if path.usesInterfaceType(.cellular) { return .cellular }
        if path.usesInterfaceType(.wiredEthernet) { return .wiredEthernet }
        if path.usesInterfaceType(.other) { return .other }
        return nil
    }
}

private extension NWInterface.InterfaceType {
    var label: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "cellular"
        case .wiredEthernet: return "ethernet"
        case .loopback: return "loopback"
        case .other: return "other"
        @unknown default: return "unknown"
        }
    }
}
