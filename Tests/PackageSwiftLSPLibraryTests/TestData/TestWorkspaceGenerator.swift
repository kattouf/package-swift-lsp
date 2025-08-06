import Foundation

enum TestWorkspaceGenerator {
    @discardableResult
    static func generateSwiftPackageInTemporaryDirectory(
        packagePath: String? = nil,
        toolsVersion: String,
        dependencies: [(url: String, exactVersion: String)]
    ) throws -> String {
        let packageName = "test-package"
        let packagePath = packagePath.map { URL(filePath: $0) } ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(packageName)
            .appendingPathComponent(toolsVersion)
        let sourcesPath = packagePath.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: packagePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourcesPath, withIntermediateDirectories: true)
        let dependenciesString = dependencies.map { ".package(url: \"\($0.url)\", from: \"\($0.exactVersion)\")" }
            .joined(separator: ",\n        ")
        let packageManifest = """
        // swift-tools-version: \(toolsVersion)
        import PackageDescription

        let package = Package(
            name: "\(packageName)",
            products: [
                .library(name: "\(packageName)", targets: ["\(packageName)"]),
            ],
            dependencies: [
                \(dependenciesString)
            ],
            targets: [
                .target(name: "\(packageName)", dependencies: []),
            ]
        )
        """
        try packageManifest.write(toFile: packagePath.appendingPathComponent("Package.swift").path, atomically: true, encoding: .utf8)
        try "import Foundation".write(toFile: sourcesPath.appendingPathComponent("dummy.swift").path, atomically: true, encoding: .utf8)
        return packagePath.path
    }
}
