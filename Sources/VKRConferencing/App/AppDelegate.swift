import UIKit
import PushKit
import UserNotifications

/// Bridges the UIKit application lifecycle into `AppContainer`.
///
/// Three responsibilities:
///   1. Register the VoIP push registry as soon as the process starts — VoIP
///      tokens must be available before any incoming call can be routed.
///   2. Hand the regular APNs registration off to the Approach-B handler so
///      Push + Custom UI also works.
///   3. Forward `application(_:didFinishLaunchingWithOptions:)` to the
///      `AppContainer` so the configured `IncomingCallHandler` can resume the
///      cold-start scenario described in §3.4 of the thesis (Scenario 3 on
///      Android, but we replicate the same idea on iOS for parity).
final class AppDelegate: NSObject, UIApplicationDelegate {

    private var container: AppContainer { .shared }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // The VoIP registry must be initialised on the main thread before the
        // first push arrives — registering it here covers cold-start from a
        // VoIP push (Approach C, Scenario 2 in §3.4).
        container.voipRegistry.activate()

        // Regular APNs registration — used by Approach B and as a fallback by
        // Approach C when CallKit is unavailable (very old devices / corporate
        // MDM lockdown).
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }

        container.telemetry.record(.appDidFinishLaunch(timestamp: MonotonicClock.now()))
        return true
    }

    // MARK: - Regular APNs

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        container.apnsPushHandler.didRegister(token: token)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        container.telemetry.record(.apnsRegistrationFailed(reason: error.localizedDescription))
    }

    // MARK: - Lifecycle observers used by TelemetryCollector

    func applicationWillResignActive(_ application: UIApplication) {
        container.telemetry.record(.lifecycle(state: .inactive, timestamp: MonotonicClock.now()))
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        container.telemetry.record(.lifecycle(state: .background, timestamp: MonotonicClock.now()))
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        container.telemetry.record(.lifecycle(state: .foregroundInactive, timestamp: MonotonicClock.now()))
        // Re-warm the signalling channel as soon as we come back into the
        // foreground — this is the "Pre-warming WebSocket" optimisation
        // (§3.5, technique 1), which knocks ~23 % off the cumulative TTM.
        container.preWarmedSignaling.warmIfEnabled()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        container.telemetry.record(.lifecycle(state: .foregroundActive, timestamp: MonotonicClock.now()))
    }
}
