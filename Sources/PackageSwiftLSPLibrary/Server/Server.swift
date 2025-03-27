import Foundation
import JSONRPC
import LanguageServer
import LanguageServerProtocol

package final class Server {
    private let connection: JSONRPCClientConnection
    private let eventHandler: BaseEventHandler

    package init() {
        let channel = DataChannel.stdioPipe()
        connection = JSONRPCClientConnection(channel)
        eventHandler = BaseEventHandler()
    }

    package func start() async throws {
        logger.info("Starting server")
        do {
            try await startEventLoop()
        } catch {
            logger.error("Server error: \(error)")
            throw error
        }
    }

    private func startEventLoop() async throws {
        for await event in await connection.eventSequence {
            switch event {
            case let .request(_, request):
                switch request {
                case let .initialize(params, handler):
                    if params.capabilities.window?.workDoneProgress == true {
                        await ProgressTracker.shared.setConnection(connection)
                    }
                    try await eventHandler.initialize(params, handler)
                case let .completion(params, handler):
                    try await eventHandler.completion(params, handler)
                case let .hover(params, handler):
                    try await eventHandler.hover(params, handler)
                case let .shutdown(handler):
                    try await eventHandler.shutdown(handler)
                default:
                    eventHandler.notImplemented(request.method)
                }
            case let .notification(notification):
                switch notification {
                case let .initialized(params):
                    try await eventHandler.initialized(params)
                case .exit:
                    try await eventHandler.exit()
                case let .textDocumentDidOpen(params):
                    try await eventHandler.textDocumentDidOpen(params)
                case let .textDocumentDidChange(params):
                    try await eventHandler.textDocumentDidChange(params)
                case let .textDocumentDidClose(params):
                    try await eventHandler.textDocumentDidClose(params)
                case let .textDocumentDidSave(params):
                    try await eventHandler.textDocumentDidSave(params)
                default:
                    eventHandler.notImplemented(notification.method)
                }
            case let .error(error):
                eventHandler.error(error)
            }
        }
    }
}
