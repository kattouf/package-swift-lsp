import SwiftSyntax

final class PackageSwiftItemCollector: SyntaxVisitor {
    private let locationConverter: SourceLocationConverter
    private(set) var items: [PackageSwiftItem] = []

    init(locationConverter: SourceLocationConverter) {
        self.locationConverter = locationConverter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let functionParser = PackageSwiftItemParser.functionParser(locationConverter: locationConverter)
        guard let functionCallItem = functionParser.parse(node, nil) else {
            return .visitChildren
        }

        items.append(functionCallItem)
        return .skipChildren
    }
}
