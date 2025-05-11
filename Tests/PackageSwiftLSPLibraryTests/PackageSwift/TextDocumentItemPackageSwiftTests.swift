import LanguageServerProtocol
@testable import PackageSwiftLSPLibrary
import Testing

struct TextDocumentItemPackageSwiftTests {
    @Test
    func standardPackageSwift() {
        let standardPackage = TextDocumentItem(
            uri: "file:///path/to/Package.swift",
            languageId: "swift",
            version: 1,
            text: ""
        )
        #expect(standardPackage.isPackageSwift)
    }

    @Test
    func versionedPackageSwift() {
        let majorVersion = TextDocumentItem(
            uri: "file:///path/to/Package@swift-5.swift",
            languageId: "swift",
            version: 1,
            text: ""
        )
        #expect(majorVersion.isPackageSwift)

        let majorMinorVersion = TextDocumentItem(
            uri: "file:///path/to/Package@swift-5.3.swift",
            languageId: "swift",
            version: 1,
            text: ""
        )
        #expect(majorMinorVersion.isPackageSwift)

        let fullVersion = TextDocumentItem(
            uri: "file:///path/to/Package@swift-5.3.2.swift",
            languageId: "swift",
            version: 1,
            text: ""
        )
        #expect(fullVersion.isPackageSwift)
    }

    @Test
    func nonPackageSwift() {
        let nonPackage = TextDocumentItem(
            uri: "file:///path/to/NotPackage.swift",
            languageId: "swift",
            version: 1,
            text: ""
        )
        #expect(!nonPackage.isPackageSwift)
    }

    @Test
    func invalidVersionFormat() {
        let invalidFormat = TextDocumentItem(
            uri: "file:///path/to/Package@swift-abc.swift",
            languageId: "swift",
            version: 1,
            text: ""
        )
        #expect(!invalidFormat.isPackageSwift)
    }

    @Test
    func nonSwiftLanguageId() {
        let nonSwift = TextDocumentItem(
            uri: "file:///path/to/Package.swift",
            languageId: "objective-c",
            version: 1,
            text: ""
        )
        #expect(!nonSwift.isPackageSwift)
    }
}
