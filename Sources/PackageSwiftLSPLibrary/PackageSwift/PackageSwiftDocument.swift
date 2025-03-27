import ConcurrencyExtras
import Foundation
import LanguageServerProtocol
import SwiftSyntax

final class PackageSwiftDocument: Sendable {
    enum Error: Swift.Error {
        case wrongFileType
        case invalidDocumentUri(uri: String)
    }

    private let parser: PackageSwiftParser
    private let parsedPackageSwiftFile: LockIsolated<ParsedPackageSwiftFile>

    let uri: DocumentUri

    // MARK: - Public

    convenience init(
        params: DidOpenTextDocumentParams
    ) throws {
        guard params.textDocument.isPackageSwift else {
            throw Error.wrongFileType
        }

        self.init(filePath: params.textDocument.uri, source: params.textDocument.text)
    }

    init(filePath: String, source: String) {
        let parser = PackageSwiftParser()
        let parsedPackageSwiftFile = parser.parse(filePath: filePath, source: source)

        self.parser = parser
        self.parsedPackageSwiftFile = .init(parsedPackageSwiftFile)
        self.uri = filePath
        logger.info("Open document: \(filePath)")
    }

    func sync(with newText: String) {
        parsedPackageSwiftFile.setValue(parser.parse(filePath: uri, source: newText))
        logger.info("Sync document: \(uri)")
    }

    func close() {
        logger.info("Close document: \(uri)")
    }

    func item(at position: Position) -> PackageSwiftItem? {
        let packageSwiftItemLocator = PackageSwiftItemLocator(
            tree: parsedPackageSwiftFile.tree,
            locationConverter: parsedPackageSwiftFile.locationConverter
        )
        let item = packageSwiftItemLocator.item(at: OneBasedPosition(position))
        if let item {
            logger.debug("Found item at \(position) in \(uri)")
            logger.debug("Item: \(item)")
        } else {
            logger.debug("No item found at \(position) in \(uri)")
        }
        return item
    }

    func allItems() -> [PackageSwiftItem] {
        let packageSwiftItemCollector = PackageSwiftItemCollector(
            locationConverter: parsedPackageSwiftFile.locationConverter
        )
        packageSwiftItemCollector.walk(parsedPackageSwiftFile.tree)
        logger.debug("Found items: \(packageSwiftItemCollector.items.count) in \(uri)")
        return packageSwiftItemCollector.items
    }
}
