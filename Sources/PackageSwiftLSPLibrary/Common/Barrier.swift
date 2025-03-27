import Foundation

struct BarrierTimeoutError: Error {}

actor Barrier {
    private var isLocked: Bool = false
    private var waitingContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]

    func lock() {
        isLocked = true
    }

    func unlock() {
        isLocked = false

        for (_, continuation) in waitingContinuations {
            continuation.resume()
        }
        waitingContinuations.removeAll()
    }

    func waitUntilUnlocked(timeout: Duration) async throws {
        if !isLocked {
            return
        }

        let id = UUID()

        try await withCheckedThrowingContinuation { continuation in
            waitingContinuations[id] = continuation

            Task {
                try? await Task.sleep(for: timeout)

                if let continuation = waitingContinuations.removeValue(forKey: id) {
                    continuation.resume(throwing: BarrierTimeoutError())
                }
            }
        }
    }
}
