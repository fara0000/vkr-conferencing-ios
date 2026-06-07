import SwiftUI

/// Entry point for the VKR test-bench iOS client.
///
/// The whole `IncomingCallHandler` (Approach A / B / C) lives inside the
/// `AppContainer`, so swapping approaches at runtime is a single property
/// assignment and the rest of the app doesn't need to know.
@main
struct VKRConferencingApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @StateObject
    private var container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(container.callStateStore)
                .environmentObject(container.settings)
        }
    }
}
