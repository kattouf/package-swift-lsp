import SwiftSyntax

final class PackageSwiftItemLocator {
    let tree: SourceFileSyntax
    let locationConverter: SourceLocationConverter

    init(tree: SourceFileSyntax, locationConverter: SourceLocationConverter) {
        self.tree = tree
        self.locationConverter = locationConverter
    }

    func item(at position: OneBasedPosition) -> PackageSwiftItem? {
        let offset = locationConverter.position(ofLine: position.line, column: position.column).utf8Offset
        let position = AbsolutePosition(utf8Offset: offset)

        guard let token = tree.token(at: position),
              let node = token.parent
        else {
            return nil
        }

        return findCompletionContext(from: node, position: position)
    }

    private func findCompletionContext(from node: Syntax, position: AbsolutePosition) -> PackageSwiftItem? {
        var current: Syntax? = node

        while let node = current {
            if let call = node.as(FunctionCallExprSyntax.self),
               let member = call.calledExpression.as(MemberAccessExprSyntax.self),
               let functionKind = PackageSwiftItem.FunctionKind.from(memberName: member.declName.baseName.text),
               let arguments = PackageSwiftItem.NonEmptyFunctionArguments(
                   arguments: extractArguments(from: call, for: functionKind),
                   activeArgumentIndex: findCurrentArgumentIndex(in: call, at: position)
               )
            {
                switch functionKind {
                case .package:
                    return .packageFunctionCall(arguments: arguments)
                case .product:
                    return .productFunctionCall(arguments: arguments)
                }
            }

            current = node.parent
        }

        return nil
    }

    private func findCurrentArgumentIndex(
        in call: FunctionCallExprSyntax,
        at position: AbsolutePosition
    ) -> Int? {
        for (index, argument) in call.arguments.enumerated() {
            let start = argument.positionAfterSkippingLeadingTrivia
            let end = argument.endPositionBeforeTrailingTrivia
            if start <= position, position <= end {
                return index
            }
        }
        return nil
    }

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
