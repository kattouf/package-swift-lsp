import Foundation
import LanguageServerProtocol

final class BaseEventHandler {
    private let documentEventHandler = DocumentEventHandler()

    // MARK: - Client requests

    func initialize(_: InitializeParams, _ handler: ClientRequest.Handler<InitializationResponse>) async throws {
        logger.debug("Received initialize request")
        var serverCapabilities = ServerCapabilities()
        let textDocumentSync = TextDocumentSyncOptions(
            change: .full,
            save: .optionA(true)
        )
        serverCapabilities.textDocumentSync = .optionA(textDocumentSync)
        serverCapabilities.completionProvider = CompletionOptions(
            workDoneProgress: false,
            triggerCharacters: ["\""],
            allCommitCharacters: nil,
            resolveProvider: false,
            completionItem: nil
        )
        serverCapabilities.hoverProvider = .optionA(true)
        let response = InitializationResponse(
            capabilities: serverCapabilities,
            serverInfo: nil
        )
        await handler(.success(response))
    }

    func completion(_ params: CompletionParams, _ handler: @escaping ClientRequest.Handler<CompletionResponse>) async throws {
        logger.debug("Received completion request")
        try await documentEventHandler.completion(params, handler)
    }

    func hover(_ params: TextDocumentPositionParams, _ handler: ClientRequest.Handler<HoverResponse>) async throws {
        logger.debug("Received hover request")
        try await documentEventHandler.hover(params, handler)
    }

    func shutdown(_ handler: ClientRequest.Handler<LSPAny?>) async throws {
        logger.debug("Received shutdown request")
        await handler(.success(.null))
    }

    func notImplemented(_ method: ClientRequest.Method) {
        logger.warning("Received unimplemented request method: \(method)")
    }

    // MARK: - Client notifications

    func initialized(_: InitializedParams) async throws {
        logger.debug("Received initialized notification")
    }

    func exit() async throws {
        logger.debug("Received exit notification")
        Foundation.exit(0)
    }

    func textDocumentDidOpen(_ params: DidOpenTextDocumentParams) async throws {
        logger.debug("Received textDocument/didOpen notification")
        try await documentEventHandler.handleTextDocumentDidOpen(params)
    }

    func textDocumentDidChange(_ params: DidChangeTextDocumentParams) async throws {
        logger.debug("Received textDocument/didChange notification")
        try await documentEventHandler.handleTextDocumentDidChange(params)
    }

    func textDocumentDidClose(_ params: DidCloseTextDocumentParams) async throws {
        logger.debug("Received textDocument/didClose notification")
        try await documentEventHandler.handleTextDocumentDidClose(params)
    }

    func textDocumentDidSave(_ params: DidSaveTextDocumentParams) async throws {
        logger.debug("Received textDocument/didSave notification")
        try await documentEventHandler.handleTextDocumentDidSave(params)
    }

    func notImplemented(_ method: ClientNotification.Method) {
        logger.warning("Received unimplemented notification method: \(method)")
    }

    // MARK: - Common

    func error(_ error: Error) {
        logger.error("Received error: \(error)")
    }
}
