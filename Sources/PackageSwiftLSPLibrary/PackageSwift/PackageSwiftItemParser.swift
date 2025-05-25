import SwiftSyntax

struct PackageSwiftItemParser {
    let parse: (_ node: SyntaxProtocol, _ position: AbsolutePosition?) -> PackageSwiftItem?
}

// MARK: - Default

extension PackageSwiftItemParser {
    static func defaultParser(locationConverter: SourceLocationConverter) -> PackageSwiftItemParser {
        .compositeParser(parsers: [
            .functionParser(locationConverter: locationConverter),
            .stringLiteralParser(locationConverter: locationConverter),
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

// MARK: - String Literal Parser

extension PackageSwiftItemParser {
    static func stringLiteralParser(locationConverter: SourceLocationConverter) -> PackageSwiftItemParser {
        PackageSwiftItemParser { node, _ in
            guard let stringLiteral = node.as(StringLiteralExprSyntax.self),
                  let value = stringLiteral.segments.first?.description
            else {
                return nil
            }

            // Check if the string literal is in a target's dependencies array
            if !isInTargetDependencies(node: stringLiteral) {
                return nil
            }

            let range = stringLiteral.trimmedRange
            let startPosition = OneBasedPosition(locationConverter.location(for: range.lowerBound))
            let endPosition = OneBasedPosition(locationConverter.location(for: range.upperBound))

            return .targetDependencyStringLiteral(value: value, range: .init(start: startPosition, end: endPosition))
        }
    }

    private static func isInTargetDependencies(node: SyntaxProtocol) -> Bool {
        // Check specific parent chain: StringLiteral -> ArrayElement -> ArrayElementList -> ArrayExpr -> LabeledExpr (dependencies) -> LabeledExprList -> FunctionCall

        // StringLiteral -> ArrayElement
        guard let arrayElement = node.parent?.as(ArrayElementSyntax.self) else {
            return false
        }

        // ArrayElement -> ArrayElementList
        guard let arrayElementList = arrayElement.parent?.as(ArrayElementListSyntax.self) else {
            return false
        }

        // ArrayElementList -> Array
        guard let arrayExpr = arrayElementList.parent?.as(ArrayExprSyntax.self) else {
            return false
        }

        // Array -> LabeledExpr with "dependencies" label
        guard let labeledExpr = arrayExpr.parent?.as(LabeledExprSyntax.self),
              labeledExpr.label?.text == "dependencies" else {
            return false
        }

        // LabeledExpr -> LabeledExprList -> FunctionCall
        guard let labeledExprList = labeledExpr.parent?.as(LabeledExprListSyntax.self),
              let functionCall = labeledExprList.parent?.as(FunctionCallExprSyntax.self),
              let memberAccess = functionCall.calledExpression.as(MemberAccessExprSyntax.self) else {
            return false
        }

        // Check if it's a target or plugin function
        let functionName = memberAccess.declName.baseName.text
        let targetFunctions = ["target", "executableTarget", "testTarget", "plugin"]

        return targetFunctions.contains(functionName)
    }
}
