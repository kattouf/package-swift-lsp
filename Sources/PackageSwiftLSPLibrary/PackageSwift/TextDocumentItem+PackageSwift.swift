import Foundation
import LanguageServerProtocol

extension TextDocumentItem {
    var isPackageSwift: Bool {
        guard languageId == "swift" else { return false }

        guard let url = URL(string: uri), let filename = url.pathComponents.last else {
            return false
        }

        if filename == "Package.swift" {
            return true
        }

        // https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageLoading/ToolsVersionParser.swift#L624
        let pattern = "^Package@swift-(\\d+)(?:\\.(\\d+))?(?:\\.(\\d+))?\\.swift$"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return false
        }

        let range = NSRange(location: 0, length: filename.count)
        return regex.firstMatch(in: filename, options: [], range: range) != nil
    }
}
