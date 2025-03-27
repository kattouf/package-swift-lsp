@testable import PackageSwiftLSPLibrary
import SwiftParser
import SwiftSyntax
import Testing

struct PackageSwiftItemLocatorTests {
    private static func createLocatorWithTestData() -> PackageSwiftItemLocator {
        let tree = Parser.parse(source: packageSwift600Fake)
        let converter = SourceLocationConverter(fileName: "/foo/bar/Package.swift", tree: tree)
        return PackageSwiftItemLocator(tree: tree, locationConverter: converter)
    }

    private nonisolated(unsafe) static let locator: PackageSwiftItemLocator = createLocatorWithTestData()

    @Test(arguments: [
        (
            line: 15,
            column: 23,
            functionName: "package",
            argumentName: "url",
            argumentValue: "https://github.com/apple/swift-argument-parser"
        ),
        (
            line: 15,
            column: 81,
            functionName: "package",
            argumentName: "from",
            argumentValue: "1.5.0"
        ),
        (
            line: 16,
            column: 87,
            functionName: "package",
            argumentName: "branch",
            argumentValue: "main"
        ),
        (
            line: 18,
            column: 81,
            functionName: "package",
            argumentName: "exact",
            argumentValue: "510.0.1"
        ),
        (
            line: 19,
            column: 85,
            functionName: "package",
            argumentName: "revision",
            argumentValue: "jepa"
        ),
        (
            line: 36,
            column: 35,
            functionName: "product",
            argumentName: "name",
            argumentValue: "SwiftSyntax"
        ),
        (
            line: 36,
            column: 64,
            functionName: "product",
            argumentName: "package",
            argumentValue: "swift-syntax"
        ),
        (
            line: 37,
            column: 35,
            functionName: "product",
            argumentName: "name",
            argumentValue: "BrokenSyntaxLine"
        ),
    ])
    func locatePackageSwiftFunctionArgumentStringValue(
        line: Int,
        column: Int,
        functionName: String,
        argumentName: String,
        argumentValue: String
    ) throws {
        let cursorPosition = try #require(OneBasedPosition(line: line, column: column))

        let item = try #require(Self.locator.item(at: cursorPosition))

        switch item {
        case let .packageFunctionCall(arguments):
            let argumentUnderCursor = try #require(arguments.activeArgument())
            let argumentNameUnderCursor = argumentUnderCursor.label
            let argumentValueUnderCursor = argumentUnderCursor.stringValue

            #expect(functionName == "package")
            #expect(argumentName == "\(argumentNameUnderCursor)")
            #expect(argumentValue == argumentValueUnderCursor)
        case let .productFunctionCall(arguments):
            let argumentUnderCursor = try #require(arguments.activeArgument())
            let argumentNameUnderCursor = argumentUnderCursor.label
            let argumentValueUnderCursor = argumentUnderCursor.stringValue

            #expect(functionName == "product")
            #expect(argumentName == "\(argumentNameUnderCursor)")
            #expect(argumentValue == argumentValueUnderCursor)
        }
    }
}
