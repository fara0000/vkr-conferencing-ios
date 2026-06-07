import Foundation
import Combine

/// MVVM view-model for the incoming-call surface. Used both by the in-app
/// full-screen view and the banner — they're two presentations of the same
/// state.
@MainActor
final class IncomingCallViewModel: ObservableObject {

    @Published private(set) var call: IncomingCall?
    @Published private(set) var elapsed: TimeInterval = 0

    private let store: CallStateStore
    private let callManager: CallManager
    private var cancellables: Set<AnyCancellable> = []
    private var timerTask: Task<Void, Never>?

    init(store: CallStateStore, callManager: CallManager) {
        self.store = store
        self.callManager = callManager

        store.$state
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .incoming(let call):
                    self.call = call
                    self.startTimer()
                default:
                    self.call = nil
                    self.stopTimer()
                }
            }
            .store(in: &cancellables)
    }

    func accept() {
        guard let call else { return }
        callManager.acceptIncoming(call: call)
    }

    func decline() {
        guard let call else { return }
        callManager.declineIncoming(call: call)
    }

    private func startTimer() {
        timerTask?.cancel()
        let start = MonotonicClock.now()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                self?.elapsed = MonotonicClock.now() - start
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        elapsed = 0
    }
}
