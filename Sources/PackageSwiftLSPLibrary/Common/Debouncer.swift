actor Debouncer {
    private var currentTask: Task<Void, Never>?

    func run(
        delay: Duration,
        operation: @escaping @Sendable () async throws -> Void,
        onError: (@Sendable (Error) async -> Void)? = nil,
        onCancel: (@Sendable () async -> Void)? = nil
    ) {
        currentTask?.cancel()

        currentTask = Task { [delay, operation, onError, onCancel] in
            do {
                try await Task.sleep(for: delay)
                try Task.checkCancellation()

                try await operation()
            } catch is CancellationError {
                if let onCancel {
                    await onCancel()
                }
            } catch {
                if let onError {
                    await onError(error)
                }
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
    }
}
