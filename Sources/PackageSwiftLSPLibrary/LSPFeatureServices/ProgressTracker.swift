import ConcurrencyExtras
import Foundation
import LanguageServer
import LanguageServerProtocol

actor ProgressTracker {
    static let shared = ProgressTracker()
    private var connection: JSONRPCClientConnection?

    private init() {}

    func setConnection(_ connection: JSONRPCClientConnection) {
        self.connection = connection
    }

    func startTracking(title: String) async throws -> ProgressToken {
        let token = ProgressToken.optionB(UUID().uuidString)
        guard let connection = self.connection else {
            logger.warning("Connection not set, cannot start progress tracking")
            return token
        }
        let request: ServerRequest = .windowWorkDoneProgressCreate(.init(token: token)) { error in
            logger.error("Error creating progress token: \(String(describing: error))")
        }
        let _: LSPAny = try await connection.sendRequest(request)
        try await connection.sendNotification(.protocolProgress(.init(
            token: token,
            value: .hash(["kind": "begin", "title": .string(title)])
        )))
        logger.debug("Started progress tracking with title: \(title) and token: \(token)")
        return token
    }

    func stopTracking(_ token: ProgressToken) async throws {
        guard let connection = self.connection else {
            return
        }
        let notification: ServerNotification = .protocolProgress(.init(token: token, value: .hash(["kind": "end"])))
        try await connection.sendNotification(notification)
        logger.debug("Stopped progress tracking with token: \(token)")
    }
}
