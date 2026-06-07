import SwiftUI

/// Live telemetry tail. Useful during defence: open this screen, place a call,
/// and the audience sees TTI / TTM tick by in real time.
struct TelemetryView: View {

    @EnvironmentObject private var container: AppContainer
    @State private var events: [TelemetryEvent] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Last call") {
                    if let summary = container.telemetry.lastCallSummary {
                        LabeledContent("TTI") { metricLine(summary.ttiMillis) }
                        LabeledContent("TTM") { metricLine(summary.ttmMillis) }
                        LabeledContent("Delivered") {
                            Image(systemName: summary.delivered ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(summary.delivered ? .green : .red)
                        }
                        if let rt = summary.recoveryMillis {
                            LabeledContent("RT") { metricLine(rt) }
                        }
                    } else {
                        Text("No calls yet").foregroundStyle(.secondary)
                    }
                }

                Section("Event tail") {
                    ForEach(Array(events.suffix(40).enumerated().reversed()), id: \.0) { _, event in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.kindDescription)
                                .font(.subheadline.weight(.medium))
                            Text(event.payloadDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Telemetry")
            .task {
                for await event in container.telemetry.events {
                    events.append(event)
                }
            }
        }
    }

    @ViewBuilder
    private func metricLine(_ millis: Double) -> some View {
        Text(String(format: "%.0f ms", millis))
            .font(.system(.body, design: .monospaced))
    }
}
