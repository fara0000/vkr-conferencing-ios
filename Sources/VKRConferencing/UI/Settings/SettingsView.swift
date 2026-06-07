import SwiftUI

/// The single most important screen of the test bench: this is where you flip
/// between the three approaches that Chapter 4 compares.
///
/// All three handlers share the rest of the app, so flipping this segmented
/// control is equivalent to swapping the Strategy in §4.1 of the thesis.
struct SettingsView: View {

    @EnvironmentObject private var settings: SettingsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Approach (Chapter 4)") {
                    Picker("Incoming call handler", selection: $settings.approach) {
                        ForEach(IncomingCallApproach.allCases) { approach in
                            Text(approach.shortLabel).tag(approach)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(settings.approach.detailedDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Optimisations (Chapter 3)") {
                    Toggle("Pre-warming WebSocket",
                           isOn: $settings.optimizationFlags.preWarmedSignaling)
                    Toggle("STUN pre-fetch",
                           isOn: $settings.optimizationFlags.stunPrefetch)
                    Toggle("Trickle ICE",
                           isOn: $settings.optimizationFlags.trickleICE)
                    Toggle("Pre-established DTLS",
                           isOn: $settings.optimizationFlags.preEstablishedDTLS)

                    Text("Cumulative TTM effect at Wi-Fi baseline: 2780 → 1050 ms (−62 %, ×2.6).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Network behaviour") {
                    Stepper("ICE failed timeout: \(Int(settings.iceFailedTimeout)) s",
                            value: $settings.iceFailedTimeout,
                            in: 5...60, step: 1)
                    Text("Section 4.10 recommends ≥ 20 s — anything shorter kills calls during normal 5–10 s mobile blackouts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Servers") {
                    LabeledContent("Signaling", value: Config.signalingURL.absoluteString)
                        .font(.footnote)
                    LabeledContent("Telemetry", value: Config.telemetryURL.absoluteString)
                        .font(.footnote)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
