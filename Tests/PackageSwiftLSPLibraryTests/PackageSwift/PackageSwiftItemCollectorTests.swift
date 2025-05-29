@testable import PackageSwiftLSPLibrary
import SwiftParser
import SwiftSyntax
import Testing

struct PackageSwiftItemCollectorTests {
    @Test
    func collectPackageSwiftItems() {
        let tree = Parser.parse(source: packageSwift600Fake)
        let converter = SourceLocationConverter(fileName: "/foo/bar/Package.swift", tree: tree)
        let collector = PackageSwiftItemCollector(locationConverter: converter)

        collector.walk(tree)

        let items = collector.items

        let expectedItems: [PackageSwiftItem] = [
            .packageFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .url,
                    stringValueRange: range(startLine: 15, startColumn: 24, endLine: 15, endColumn: 70),
                    stringValue: "https://github.com/apple/swift-argument-parser"
                ),
                .init(
                    label: .from,
                    stringValueRange: range(startLine: 15, startColumn: 80, endLine: 15, endColumn: 85),
                    stringValue: "1.5.0"
                ),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .url,
                    stringValueRange: range(startLine: 16, startColumn: 24, endLine: 16, endColumn: 73),
                    stringValue: "https://github.com/ChimeHQ/LanguageServerProtocol"
                ),
                .init(
                    label: .branch,
                    stringValueRange: range(startLine: 16, startColumn: 85, endLine: 16, endColumn: 89),
                    stringValue: "main"
                ),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .url,
                    stringValueRange: range(startLine: 17, startColumn: 24, endLine: 17, endColumn: 65),
                    stringValue: "https://github.com/ChimeHQ/LanguageServer"
                ),
                .init(
                    label: .branch,
                    stringValueRange: range(startLine: 17, startColumn: 77, endLine: 17, endColumn: 81),
                    stringValue: "main"
                ),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .url,
                    stringValueRange: range(startLine: 18, startColumn: 24, endLine: 18, endColumn: 69),
                    stringValue: "https://github.com/swiftlang/swift-syntax.git"
                ),
                .init(
                    label: .exact,
                    stringValueRange: range(startLine: 18, startColumn: 80, endLine: 18, endColumn: 87),
                    stringValue: "510.0.1"
                ),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .url,
                    stringValueRange: range(startLine: 19, startColumn: 24, endLine: 19, endColumn: 74),
                    stringValue: "https://github.com/swiftlang/swift-package-manager"
                ),
                .init(
                    label: .revision,
                    stringValueRange: range(startLine: 19, startColumn: 88, endLine: 19, endColumn: 92),
                    stringValue: "jepa"
                ),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .url,
                    stringValueRange: range(startLine: 20, startColumn: 24, endLine: 20, endColumn: 73),
                    stringValue: "https://github.com/swiftlang/swift-subprocess.git"
                ),
                .init(
                    label: .branch,
                    stringValueRange: range(startLine: 20, startColumn: 85, endLine: 20, endColumn: 89),
                    stringValue: "main"
                ),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .url,
                    stringValueRange: range(startLine: 21, startColumn: 24, endLine: 21, endColumn: 83),
                    stringValue: "https://github.com/pointfreeco/swift-concurrency-extras.git"
                ),
                .init(
                    label: .from,
                    stringValueRange: range(startLine: 21, startColumn: 93, endLine: 21, endColumn: 98),
                    stringValue: "1.3.1"
                ),
            ])!),

            // Product dependencies
            .productFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .name,
                    stringValueRange: range(startLine: 27, startColumn: 33, endLine: 27, endColumn: 47),
                    stringValue: "ArgumentParser"
                ),
                .init(
                    label: .package,
                    stringValueRange: range(startLine: 27, startColumn: 60, endLine: 27, endColumn: 81),
                    stringValue: "swift-argument-parser"
                ),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .name,
                    stringValueRange: range(startLine: 34, startColumn: 33, endLine: 34, endColumn: 55),
                    stringValue: "LanguageServerProtocol"
                ),
                .init(
                    label: .package,
                    stringValueRange: range(startLine: 34, startColumn: 68, endLine: 34, endColumn: 90),
                    stringValue: "LanguageServerProtocol"
                ),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .name,
                    stringValueRange: range(startLine: 35, startColumn: 33, endLine: 35, endColumn: 47),
                    stringValue: "LanguageServer"
                ),
                .init(
                    label: .package,
                    stringValueRange: range(startLine: 35, startColumn: 60, endLine: 35, endColumn: 74),
                    stringValue: "LanguageServer"
                ),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .name,
                    stringValueRange: range(startLine: 36, startColumn: 33, endLine: 36, endColumn: 44),
                    stringValue: "SwiftSyntax"
                ),
                .init(
                    label: .package,
                    stringValueRange: range(startLine: 36, startColumn: 57, endLine: 36, endColumn: 69),
                    stringValue: "swift-syntax"
                ),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .name,
                    stringValueRange: range(startLine: 38, startColumn: 33, endLine: 38, endColumn: 44),
                    stringValue: "SwiftParser"
                ),
                .init(
                    label: .package,
                    stringValueRange: range(startLine: 38, startColumn: 57, endLine: 38, endColumn: 69),
                    stringValue: "swift-syntax"
                ),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .name,
                    stringValueRange: range(startLine: 39, startColumn: 33, endLine: 39, endColumn: 54),
                    stringValue: "SwiftPMDataModel-auto"
                ),
                .init(
                    label: .package,
                    stringValueRange: range(startLine: 39, startColumn: 67, endLine: 39, endColumn: 88),
                    stringValue: "swift-package-manager"
                ),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .name,
                    stringValueRange: range(startLine: 40, startColumn: 33, endLine: 40, endColumn: 43),
                    stringValue: "Subprocess"
                ),
                .init(
                    label: .package,
                    stringValueRange: range(startLine: 40, startColumn: 56, endLine: 40, endColumn: 72),
                    stringValue: "swift-subprocess"
                ),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(
                    label: .name,
                    stringValueRange: range(startLine: 41, startColumn: 33, endLine: 41, endColumn: 50),
                    stringValue: "ConcurrencyExtras"
                ),
                .init(
                    label: .package,
                    stringValueRange: range(startLine: 41, startColumn: 63, endLine: 41, endColumn: 87),
                    stringValue: "swift-concurrency-extras"
                ),
            ])!),
            .targetDependencyStringLiteral(
                value: "StringTargetWithoutComma",
                valueRange: range(startLine: 47, startColumn: 18, endLine: 47, endColumn: 42)
            ),
            .targetDependencyStringLiteral(
                value: "StringTargetWithComma",
                valueRange: range(startLine: 49, startColumn: 18, endLine: 49, endColumn: 39)
            ),
        ]

        #expect(items == expectedItems)
    }

    private func range(
        startLine: Int,
        startColumn: Int,
        endLine: Int,
        endColumn: Int
    ) -> OneBasedRange {
        OneBasedRange(
            start: OneBasedPosition(line: startLine, column: startColumn)!,
            end: OneBasedPosition(line: endLine, column: endColumn)!
        )
    }
}
