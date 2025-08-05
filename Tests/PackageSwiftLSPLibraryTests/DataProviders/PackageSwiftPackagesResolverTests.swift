import Basics
import Foundation
@testable import PackageSwiftLSPLibrary
import Testing

@Suite(.serialized)
struct PackageSwiftPackagesResolverTests {
    @Test(arguments: ["6.0", "5.10"])
    func resolvePackages(toolsVersion: String) async throws {
        let dependencies: [(url: String, exactVersion: String)] = [
            ("https://github.com/Alamofire/Alamofire", "5.10.2"),
            ("https://github.com/apple/swift-log", "1.6.3"),
        ]
        let packagePath = try TestWorkspaceGenerator.generateSwiftPackageInTemporaryDirectory(
            packageAndMainTargetName: "test-package",
            toolsVersion: toolsVersion,
            dependencies: dependencies,
            additionalTargets: [
                "SomeLibrary1",
                "SomeLibrary2",
            ]
        )

        let sut = PackageSwiftPackagesResolver()
        let resolvedPackages = try await sut.resolve(
            at: AbsolutePath(validating: packagePath),
            cacheKey: nil
        )
        let externalPackages = resolvedPackages.externalPackages
        let localPackages = resolvedPackages.localPackages

        let alamofire = try #require(externalPackages.first { $0.identity.description == "alamofire" })
        #expect(alamofire.displayName == "Alamofire")
        #expect(alamofire.products == ["Alamofire", "AlamofireDynamic"])
        #expect(alamofire.locationDescription == "https://github.com/Alamofire/Alamofire")
        #expect(alamofire.stateDescription == "5.10.2")

        let swiftArgumentParser = try #require(externalPackages.first { $0.identity.description == "swift-log" })
        #expect(swiftArgumentParser.displayName == "swift-log")
        #expect(swiftArgumentParser.products == ["Logging"])
        #expect(swiftArgumentParser.locationDescription == "https://github.com/apple/swift-log")
        #expect(swiftArgumentParser.stateDescription == "1.6.3")

        let localRootPackage = try #require(localPackages.first)
        #expect(localRootPackage.targets == ["test-package", "SomeLibrary1", "SomeLibrary2"])

        try? FileManager.default.removeItem(atPath: packagePath)
    }
}
