import Foundation

enum TestWorkspaceGenerator {
    @discardableResult
    static func generateSwiftPackageInTemporaryDirectory(
        packagePath: String? = nil,
        packageAndMainTargetName: String,
        toolsVersion: String,
        dependencies: [(url: String, exactVersion: String)],
        additionalTargets: [String] = []
    ) throws -> String {
        let packagePath = packagePath.map { URL(filePath: $0) } ?? FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(packageAndMainTargetName)
            .appendingPathComponent(toolsVersion)
        let sourcesPath = packagePath.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: packagePath, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sourcesPath, withIntermediateDirectories: true)
        let dependenciesString = dependencies.map { ".package(url: \"\($0.url)\", exact: \"\($0.exactVersion)\")" }
            .joined(separator: ",\n        ")

        // Generate all targets (main target + additional targets)
        let allTargets = [packageAndMainTargetName] + additionalTargets
        let targetsString = allTargets.map { ".target(name: \"\($0)\", dependencies: [])" }
            .joined(separator: ",\n                ")

        let packageManifest = """
        // swift-tools-version: \(toolsVersion)
        import PackageDescription

        let package = Package(
            name: "\(packageAndMainTargetName)",
            products: [
                .library(name: "\(packageAndMainTargetName)", targets: ["\(packageAndMainTargetName)"]),
            ],
            dependencies: [
                \(dependenciesString)
            ],
            targets: [
                \(targetsString)
            ]
        )
        """
        try packageManifest.write(toFile: packagePath.appendingPathComponent("Package.swift").path, atomically: true, encoding: .utf8)

        // Create source files for all targets
        for target in allTargets {
            let targetSourcePath = sourcesPath.appendingPathComponent(target)
            try FileManager.default.createDirectory(at: targetSourcePath, withIntermediateDirectories: true)
            try "import Foundation"
                .write(toFile: targetSourcePath.appendingPathComponent("dummy.swift").path, atomically: true, encoding: .utf8)
        }

        return packagePath.path
    }
}
