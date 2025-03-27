import ArgumentParser
import PackageSwiftLSPLibrary

@main
struct CLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "package-swift-lsp",
        abstract: "LSP server for Package.swift SPM manifest files",
    )

    func run() async throws {
        setupLogger()
        let server = Server()
        try await server.start()
    }
}
