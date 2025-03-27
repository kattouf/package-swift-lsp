@testable import PackageSwiftLSPLibrary
import SwiftParser
import SwiftSyntax
import Testing

struct PackageSwiftItemCollectorTests {
    @Test
    func collectPackageAndProductFunctionCalls() {
        let tree = Parser.parse(source: packageSwift600Fake)
        let converter = SourceLocationConverter(fileName: "/foo/bar/Package.swift", tree: tree)
        let collector = PackageSwiftItemCollector(locationConverter: converter)

        collector.walk(tree)

        let items = collector.items

        let expectedItems: [PackageSwiftItem] = [
            .packageFunctionCall(arguments: .init(arguments: [
                .init(label: .url, stringValue: "https://github.com/apple/swift-argument-parser"),
                .init(label: .from, stringValue: "1.5.0"),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(label: .url, stringValue: "https://github.com/ChimeHQ/LanguageServerProtocol"),
                .init(label: .branch, stringValue: "main"),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(label: .url, stringValue: "https://github.com/ChimeHQ/LanguageServer"),
                .init(label: .branch, stringValue: "main"),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(label: .url, stringValue: "https://github.com/swiftlang/swift-syntax.git"),
                .init(label: .exact, stringValue: "510.0.1"),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(label: .url, stringValue: "https://github.com/swiftlang/swift-package-manager"),
                .init(label: .revision, stringValue: "jepa"),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(label: .url, stringValue: "https://github.com/swiftlang/swift-subprocess.git"),
                .init(label: .branch, stringValue: "main"),
            ])!),
            .packageFunctionCall(arguments: .init(arguments: [
                .init(label: .url, stringValue: "https://github.com/pointfreeco/swift-concurrency-extras.git"),
                .init(label: .from, stringValue: "1.3.1"),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(label: .name, stringValue: "ArgumentParser"),
                .init(label: .package, stringValue: "swift-argument-parser"),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(label: .name, stringValue: "LanguageServerProtocol"),
                .init(label: .package, stringValue: "LanguageServerProtocol"),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(label: .name, stringValue: "LanguageServer"),
                .init(label: .package, stringValue: "LanguageServer"),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(label: .name, stringValue: "SwiftSyntax"),
                .init(label: .package, stringValue: "swift-syntax"),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(label: .name, stringValue: "SwiftParser"),
                .init(label: .package, stringValue: "swift-syntax"),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(label: .name, stringValue: "SwiftPMDataModel-auto"),
                .init(label: .package, stringValue: "swift-package-manager"),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(label: .name, stringValue: "Subprocess"),
                .init(label: .package, stringValue: "swift-subprocess"),
            ])!),
            .productFunctionCall(arguments: .init(arguments: [
                .init(label: .name, stringValue: "ConcurrencyExtras"),
                .init(label: .package, stringValue: "swift-concurrency-extras"),
            ])!),
        ]

        #expect(items == expectedItems)
    }
}
