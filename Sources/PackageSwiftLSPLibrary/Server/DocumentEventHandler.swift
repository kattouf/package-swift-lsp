import JSONRPC
import LanguageServerProtocol

final class DocumentEventHandler {
    private let resolvedDependenciesProvider = PackageSwiftDependenciesProvider.shared
    private let packagesRegistry = PackagesRegistry.shared
    private let progressTracker = ProgressTracker.shared

    private let completionService = CompletionService()
    private let hoverService = HoverService()

    private let documentProcessingBarrier = Barrier()
    private var documentProcessingDebouncer = Debouncer()
    private var completionDebouncer = Debouncer()

    private var openDocuments: [DocumentUri: PackageSwiftDocument] = [:]

    func completion(_ params: CompletionParams, _ handler: @escaping ClientRequest.Handler<CompletionResponse>) async throws {
        guard let document = openDocuments[params.textDocument.uri] else {
            logger.debug("Received completion request for non-open document: \(params.textDocument.uri)")
            await handler(.success(.optionA([])))
            return
        }

        await completionDebouncer.run(
            delay: .seconds(0.2),
            operation: { [completionService, documentProcessingBarrier] in
                try await documentProcessingBarrier.waitUntilUnlocked(timeout: .seconds(0.3))

                let completion = try await completionService.complete(
                    at: params.position,
                    in: document
                )
                await handler(.success(completion))
            },
            onError: { error in
                if error is BarrierTimeoutError {
                    logger.debug("Completion didn't wait for document processing finish")
                } else {
                    logger.error("Error during completion: \(error)")
                }
                await handler(.success(.optionB(.init(isIncomplete: true, items: []))))
            },
            onCancel: {
                logger.debug("Completion task was cancelled during debounce")
                await handler(.success(.optionB(.init(isIncomplete: true, items: []))))
            }
        )
    }

    func hover(_ params: TextDocumentPositionParams, _ handler: ClientRequest.Handler<HoverResponse>) async throws {
        guard let document = openDocuments[params.textDocument.uri] else {
            logger.debug("Received hover request for non-open document: \(params.textDocument.uri)")
            await handler(.success(nil))
            return
        }
        let hoverResponse: HoverResponse
        do {
            hoverResponse = try await hoverService.hover(at: params.position, in: document)
        } catch {
            logger.error("Error during hover: \(error)")
            hoverResponse = nil
        }
        await handler(.success(hoverResponse))
    }

    func handleTextDocumentDidOpen(_ params: DidOpenTextDocumentParams) async throws {
        guard params.textDocument.isPackageSwift else {
            logger.debug("Ignoring open non-Package.swift document: \(params.textDocument.uri)")
            return
        }
        guard openDocuments.keys.contains(params.textDocument.uri) == false else {
            logger.debug("Ignoring open already open document: \(params.textDocument.uri)")
            return
        }

        let document = try PackageSwiftDocument(params: params)
        openDocuments[params.textDocument.uri] = document

        var dependenciesResolvingProgressToken: ProgressToken?
        if await resolvedDependenciesProvider.shouldResolveDependencies(for: document) {
            do {
                dependenciesResolvingProgressToken = try await progressTracker
                    .startTracking(title: "package-swift-lsp: Resolving dependencies")
            } catch {
                logger.error("Error starting progress tracking: \(error)")
            }
        }
        try await resolvedDependenciesProvider.resolveDependencies(for: document)
        if let progressToken = dependenciesResolvingProgressToken {
            do {
                try await progressTracker.stopTracking(progressToken)
            } catch {
                logger.error("Error stopping progress tracking: \(error)")
            }
        }

        try await packagesRegistry.loadPackagesIfNeeded()
    }

    func handleTextDocumentDidChange(_ params: DidChangeTextDocumentParams) async throws {
        guard let document = openDocuments[params.textDocument.uri] else {
            logger.debug("Received change request for non-open document: \(params.textDocument.uri)")
            return
        }

        for change in params.contentChanges {
            if change.range != nil {
                logger.error("Error: partial document change not supported")
                continue
            } else {
                await documentProcessingBarrier.lock()
                await documentProcessingDebouncer.run(delay: .seconds(0.2)) { [documentProcessingBarrier] in
                    document.sync(with: change.text)
                    await documentProcessingBarrier.unlock()
                }
            }
        }
    }

    func handleTextDocumentDidSave(_ params: DidSaveTextDocumentParams) async throws {
        guard let document = openDocuments[params.textDocument.uri] else {
            logger.debug("Received save request for non-open document: \(params.textDocument.uri)")
            return
        }

        var progressToken: ProgressToken?
        if await resolvedDependenciesProvider.shouldResolveDependencies(for: document) {
            do {
                progressToken = try await progressTracker
                    .startTracking(title: "package-swift-lsp: Resolving dependencies")
            } catch {
                logger.error("Error starting progress tracking: \(error)")
            }
        }

        try await resolvedDependenciesProvider.resolveDependencies(for: document)

        if let progressToken = progressToken {
            do {
                try await progressTracker.stopTracking(progressToken)
            } catch {
                logger.error("Error stopping progress tracking: \(error)")
            }
        }
    }

    func handleTextDocumentDidClose(_ params: DidCloseTextDocumentParams) async throws {
        guard let document = openDocuments[params.textDocument.uri] else {
            logger.debug("Received close request for non-open document: \(params.textDocument.uri)")
            return
        }

        document.close()
        openDocuments[params.textDocument.uri] = nil
    }
}
