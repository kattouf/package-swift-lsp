import SwiftSyntax

final class PackageSwiftItemCollector: SyntaxVisitor {
    private let locationConverter: SourceLocationConverter
    private(set) var items: [PackageSwiftItem] = []

    init(locationConverter: SourceLocationConverter) {
        self.locationConverter = locationConverter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
              let functionKind = PackageSwiftItem.FunctionKind.from(memberName: member.declName.baseName.text)
        else {
            return .visitChildren
        }

        let arguments = extractArguments(from: node, for: functionKind)

        if let nonEmptyArguments = PackageSwiftItem.NonEmptyFunctionArguments(arguments: arguments) {
            switch functionKind {
            case .package:
                items.append(.packageFunctionCall(arguments: nonEmptyArguments))
            case .product:
                items.append(.productFunctionCall(arguments: nonEmptyArguments))
            }
        }

        return .skipChildren
    }

    // FIXME: copy-paste from PackageSwiftItemLocator
    private func extractArguments(
        from call: FunctionCallExprSyntax,
        for function: PackageSwiftItem.FunctionKind
    ) -> [PackageSwiftItem.FunctionArgument] {
        let allowed = PackageSwiftItem.FunctionArgumentLabel.allowedLabels(for: function)

        return call.arguments.compactMap { argument -> PackageSwiftItem.FunctionArgument? in
            guard let labelText = argument.label?.text,
                  let label = PackageSwiftItem.FunctionArgumentLabel.from(label: labelText),
                  let stringLiteralExpression = argument.expression.as(StringLiteralExprSyntax.self)?.segments,
                  allowed.contains(label)
            else {
                return nil
            }

            let value = stringLiteralExpression.trimmedDescription

            let range = stringLiteralExpression.trimmedRange
            let startPosition = OneBasedPosition(locationConverter.location(for: range.lowerBound))
            let endPosition = OneBasedPosition(locationConverter.location(for: range.upperBound))

            return .init(label: label, stringValueRange: .init(start: startPosition, end: endPosition), stringValue: value)
        }
    }
}
