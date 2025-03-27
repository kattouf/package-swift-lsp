import Foundation
import SwiftParser
import SwiftSyntax

final class PackageSwiftParser: Sendable {
    func parse(filePath: String, source: String) -> ParsedPackageSwiftFile {
        let tree = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: filePath, tree: tree)
        return ParsedPackageSwiftFile(tree: tree, locationConverter: converter)
    }
}

struct ParsedPackageSwiftFile: Sendable {
    let tree: SourceFileSyntax
    let locationConverter: SourceLocationConverter

    fileprivate init(tree: SourceFileSyntax, locationConverter: SourceLocationConverter) {
        self.tree = tree
        self.locationConverter = locationConverter
    }
}
