import Foundation
import Combine

/// Persisted-on-disk user settings. Backed by `UserDefaults` so the chosen
/// approach survives kill/relaunch — which is part of the experiment design
/// (you don't want to reconfigure between cold-start trials).
final class SettingsStore: ObservableObject {

    @Published var approach: IncomingCallApproach {
        didSet { defaults.set(approach.rawValue, forKey: Keys.approach) }
    }

    @Published var optimizationFlags: OptimizationFlags {
        didSet { defaults.set(try? JSONEncoder().encode(optimizationFlags), forKey: Keys.optimizationFlags) }
    }

    @Published var iceFailedTimeout: TimeInterval {
        didSet { defaults.set(iceFailedTimeout, forKey: Keys.iceFailedTimeout) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.approach = IncomingCallApproach(rawValue: defaults.string(forKey: Keys.approach) ?? "")
            ?? Config.defaultApproach
        if let data = defaults.data(forKey: Keys.optimizationFlags),
           let decoded = try? JSONDecoder().decode(OptimizationFlags.self, from: data) {
            self.optimizationFlags = decoded
        } else {
            self.optimizationFlags = OptimizationFlags.allEnabled
        }
        let stored = defaults.double(forKey: Keys.iceFailedTimeout)
        self.iceFailedTimeout = stored > 0 ? stored : Config.iceFailedTimeout
    }

    private enum Keys {
        static let approach = "vkr.approach"
        static let optimizationFlags = "vkr.optimizations"
        static let iceFailedTimeout = "vkr.ice.timeout"
    }
}
