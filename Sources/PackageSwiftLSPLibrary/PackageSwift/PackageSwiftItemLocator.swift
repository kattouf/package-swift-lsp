import SwiftSyntax

final class PackageSwiftItemLocator {
    let tree: SourceFileSyntax
    let locationConverter: SourceLocationConverter
    let parser: PackageSwiftItemParser

    init(tree: SourceFileSyntax, locationConverter: SourceLocationConverter) {
        self.tree = tree
        self.locationConverter = locationConverter
        self.parser = PackageSwiftItemParser.defaultParser(locationConverter: locationConverter)
    }

    func item(at position: OneBasedPosition) -> PackageSwiftItem? {
        let offset = locationConverter.position(ofLine: position.line, column: position.column).utf8Offset
        let position = AbsolutePosition(utf8Offset: offset)

        guard let token = tree.token(at: position),
              let node = token.parent
        else {
            return nil
        }

        var current: SyntaxProtocol? = node
        while let node = current {
            if let parsedItem = parser.parse(node, position) {
                return parsedItem
            }

            current = node.parent
        }

        return nil
    }
}
