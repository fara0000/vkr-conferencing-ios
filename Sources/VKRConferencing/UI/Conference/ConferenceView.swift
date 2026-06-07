import SwiftUI

/// Active conference surface — kept deliberately small. The thesis is about
/// *delivery* of incoming calls, not in-conference UX, so the screen does just
/// enough to issue and accept a test call and show the call state.
struct ConferenceView: View {

    @EnvironmentObject private var store: CallStateStore
    @EnvironmentObject private var container: AppContainer
    @State private var conferenceId: String = "conf-\(Int.random(in: 1000...9999))"

    var body: some View {
        NavigationStack {
            List {
                Section("Call state") {
                    Text(store.state.userFacingDescription)
                        .font(.headline)
                }

                Section("Initiate test call") {
                    TextField("Conference ID", text: $conferenceId)
                        .textInputAutocapitalization(.never)

                    Button("Place outgoing call") {
                        Task { await container.callManager.startOutgoing(conferenceId: conferenceId) }
                    }
                    .disabled(!store.state.canStartOutgoing)

                    Button("Simulate incoming (test)", role: .none) {
                        let mock = IncomingCall(
                            callId: UUID(),
                            conferenceId: conferenceId,
                            callerDisplayName: "Bench Caller",
                            receivedAt: MonotonicClock.now(),
                            arrivalChannel: .signalingWebSocket
                        )
                        Task { await container.callManager.handleIncoming(call: mock, source: .localSimulation) }
                    }
                }

                Section("Active session") {
                    if case .active(let session) = store.state {
                        LabeledContent("Session ID", value: session.id.uuidString.prefix(8) + "…")
                        LabeledContent("Started", value: String(format: "%.1f s ago", MonotonicClock.now() - session.startedAt))
                        Button("Hang up", role: .destructive) {
                            container.callManager.hangUp()
                        }
                    } else {
                        Text("No active call").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Conference")
        }
    }
}
