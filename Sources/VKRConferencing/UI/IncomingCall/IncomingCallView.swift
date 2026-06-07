import SwiftUI

/// Full-screen incoming-call UI. Only used by Approach B and as a fallback
/// for Approach C when CallKit is unavailable (jailbroken devices, corporate
/// MDM lockdown). Approach C in the normal case renders the system CallKit UI
/// instead — that's the whole point of Approach C.
struct IncomingCallView: View {

    let call: IncomingCall

    @EnvironmentObject private var container: AppContainer

    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .black],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Text(call.callerDisplayName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Incoming call · \(call.conferenceId.prefix(8))")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                HStack(spacing: 80) {
                    Button {
                        container.callManager.declineIncoming(call: call)
                    } label: {
                        actionButtonLabel(system: "phone.down.fill", color: .red)
                    }

                    Button {
                        container.callManager.acceptIncoming(call: call)
                    } label: {
                        actionButtonLabel(system: "phone.fill", color: .green)
                    }
                }
                .padding(.bottom, 64)
            }
            .padding()
        }
    }

    @ViewBuilder
    private func actionButtonLabel(system: String, color: Color) -> some View {
        Image(systemName: system)
            .font(.title)
            .foregroundStyle(.white)
            .frame(width: 76, height: 76)
            .background(color)
            .clipShape(Circle())
            .shadow(radius: 8)
    }
}

/// Compact top-of-screen banner. Closer to the standard UX for "regular" push
/// notifications. Approach B uses this by default; the user can swipe down for
/// the full screen.
struct InAppIncomingCallBanner: View {

    let call: IncomingCall

    @EnvironmentObject private var container: AppContainer

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(call.callerDisplayName)
                    .font(.subheadline.weight(.semibold))
                Text("incoming call")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Decline", role: .destructive) {
                container.callManager.declineIncoming(call: call)
            }
            .buttonStyle(.bordered)

            Button("Accept") {
                container.callManager.acceptIncoming(call: call)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 6)
    }
}
