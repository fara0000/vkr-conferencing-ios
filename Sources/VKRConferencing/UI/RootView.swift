import SwiftUI

/// Top-level navigation. The thesis only needs three reachable screens for the
/// test-bench: incoming call, conference and settings. Auth is stubbed.
struct RootView: View {

    @EnvironmentObject private var store: CallStateStore
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            ConferenceView()
                .tabItem { Label("Call", systemImage: "phone.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }

            TelemetryView()
                .tabItem { Label("Telemetry", systemImage: "chart.bar.xaxis") }
        }
        .overlay(alignment: .top) {
            // Approach B and the fallback path of Approach C use an in-app
            // banner instead of the system CallKit UI. We render it as a
            // top-level overlay so it sits above any tab content.
            if case .incoming(let call) = store.state,
               container.incomingCallHandler.rendersInAppUI {
                InAppIncomingCallBanner(call: call)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.state)
    }
}
