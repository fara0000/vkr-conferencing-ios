import Foundation
import Combine

/// `URLSessionWebSocketTask`-backed signaling client.
///
/// Knows nothing about CallKit or PushKit — its only job is to keep a healthy
/// connection to the Node.js server and stream `SignalingMessage`s to whoever
/// is listening. The pre-warming optimisation (technique 1 in §3.5) is
/// implemented in `PreWarmedSignaling` which simply calls `connect()` when
/// the app comes to the foreground.
final class SignalingClient {

    enum State: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(reason: String)
    }

    let messages = PassthroughSubject<SignalingMessage, Never>()
    let state = CurrentValueSubject<State, Never>(.disconnected)

    private let url: URL
    private let telemetry: TelemetryCollector
    private let session: URLSession
    private var task: URLSessionWebSocketTask?
    private var backoff = ReconnectStrategy()
    private var heartbeat: Task<Void, Never>?
    private var receiveLoop: Task<Void, Never>?
    private var isExplicitDisconnect = false

    init(url: URL, telemetry: TelemetryCollector,
         session: URLSession = .init(configuration: .default)) {
        self.url = url
        self.telemetry = telemetry
        self.session = session
    }

    // MARK: - Public surface

    func connect() {
        guard state.value != .connecting && state.value != .connected else { return }
        state.send(.connecting)
        telemetry.record(.signalingConnecting)
        isExplicitDisconnect = false

        let startedAt = MonotonicClock.now()
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()

        // Note: URLSessionWebSocketTask has no completion for the handshake —
        // we treat the first successful receive (or send) as "connected".
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.task?.send(.string("__open__"))
                self.state.send(.connected)
                self.backoff.reset()
                self.telemetry.record(.signalingConnected(elapsedMillis: MonotonicClock.millisSince(startedAt)))
                self.startReceiveLoop()
                self.startHeartbeat()
            } catch {
                self.handleFailure(error: error)
            }
        }
    }

    func disconnect() {
        isExplicitDisconnect = true
        heartbeat?.cancel()
        receiveLoop?.cancel()
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        state.send(.disconnected)
        telemetry.record(.signalingDisconnected(reason: "client"))
    }

    func send(_ message: SignalingMessage) {
        guard let task else { return }
        do {
            let data = try JSONEncoder().encode(message)
            task.send(.data(data)) { [weak self] error in
                if let error {
                    self?.handleFailure(error: error)
                } else {
                    self?.telemetry.record(.signalingMessageOut(kind: message.kind))
                }
            }
        } catch {
            telemetry.record(.signalingDisconnected(reason: "encode \(error)"))
        }
    }

    // MARK: - Internals

    private func startReceiveLoop() {
        receiveLoop?.cancel()
        receiveLoop = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, let task = self.task {
                do {
                    let frame = try await task.receive()
                    self.handle(frame: frame)
                } catch {
                    self.handleFailure(error: error)
                    return
                }
            }
        }
    }

    private func handle(frame: URLSessionWebSocketTask.Message) {
        let data: Data
        switch frame {
        case .data(let d): data = d
        case .string(let s): data = Data(s.utf8)
        @unknown default: return
        }
        guard let decoded = try? JSONDecoder().decode(SignalingMessage.self, from: data) else { return }
        telemetry.record(.signalingMessageIn(kind: decoded.kind))
        messages.send(decoded)
    }

    private func startHeartbeat() {
        heartbeat?.cancel()
        let interval = Config.signalingHeartbeatInterval
        heartbeat = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                self?.send(.heartbeat)
            }
        }
    }

    private func handleFailure(error: Error) {
        receiveLoop?.cancel()
        heartbeat?.cancel()
        task = nil
        state.send(.failed(reason: error.localizedDescription))
        telemetry.record(.signalingDisconnected(reason: error.localizedDescription))
        guard !isExplicitDisconnect else { return }

        // Auto-reconnect with exponential back-off.
        let delay = backoff.nextDelay()
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            self?.connect()
        }
    }
}
