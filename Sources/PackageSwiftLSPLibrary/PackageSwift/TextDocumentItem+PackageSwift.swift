import LanguageServerProtocol

extension TextDocumentItem {
    var isPackageSwift: Bool {
        languageId == "swift" && uri.hasSuffix("Package.swift")
    }
}
