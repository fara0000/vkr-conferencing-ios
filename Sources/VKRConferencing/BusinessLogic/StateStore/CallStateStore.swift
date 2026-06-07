import Foundation
import Combine

/// Reactive store described in §I4 of the thesis. The UI, telemetry and call
/// manager all subscribe to the same `@Published` state — there's no manual
/// callback wiring.
@MainActor
final class CallStateStore: ObservableObject {

    @Published private(set) var state: CallState = .idle

    func transition(to newState: CallState) {
        guard newState != state else { return }
        state = newState
    }
}
