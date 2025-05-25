import SwiftSyntax

struct PackageSwiftItemParser {
    let parse: (_ node: SyntaxProtocol, _ position: AbsolutePosition?) -> PackageSwiftItem?
}

// MARK: - Default

extension PackageSwiftItemParser {
    static func defaultParser(locationConverter: SourceLocationConverter) -> PackageSwiftItemParser {
        .compositeParser(parsers: [
            .functionParser(locationConverter: locationConverter),
        ])
    }

    static func compositeParser(
        parsers: [PackageSwiftItemParser]
    ) -> PackageSwiftItemParser {
        PackageSwiftItemParser { node, position in
            for parser in parsers {
                if let item = parser.parse(node, position) {
                    return item
                }
            }
            return nil
        }
    }
}

// MARK: - Function Call Parser

extension PackageSwiftItemParser {
    static func functionParser(locationConverter: SourceLocationConverter) -> PackageSwiftItemParser {
        func findCurrentArgumentIndex(
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

        func extractArguments(
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

        return PackageSwiftItemParser { node, position in
            if let call = node.as(FunctionCallExprSyntax.self),
               let member = call.calledExpression.as(MemberAccessExprSyntax.self),
               let functionKind = PackageSwiftItem.FunctionKind.from(memberName: member.declName.baseName.text),
               let arguments = PackageSwiftItem.NonEmptyFunctionArguments(
                   arguments: extractArguments(from: call, for: functionKind),
                   activeArgumentIndex: position.flatMap { findCurrentArgumentIndex(in: call, at: $0) }
               )
            {
                switch functionKind {
                case .package:
                    return .packageFunctionCall(arguments: arguments)
                case .product:
                    return .productFunctionCall(arguments: arguments)
                }
            }

            return nil
        }
    }
}
