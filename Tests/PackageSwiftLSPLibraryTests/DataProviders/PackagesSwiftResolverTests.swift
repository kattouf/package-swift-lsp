import Basics
import Foundation
@testable import PackageSwiftLSPLibrary
import Testing

@Suite(.serialized)
struct PackagesSwiftResolverTests {
    @Test(arguments: ["6.0.0", "5.10.0"])
    func resolveDependencies(toolsVersion: String) async throws {
        let dependencies: [(url: String, exactVersion: String)] = [
            ("https://github.com/Alamofire/Alamofire", "5.9.0"),
            ("https://github.com/apple/swift-log", "1.5.2"),
        ]
        let packagePath = try TestWorkspaceGenerator.generateSwiftPackageInTemporaryDirectory(
            toolsVersion: toolsVersion,
            dependencies: dependencies
        )

        let sut = PackageSwiftDependenciesResolver()
        let resolvedPackages = try await sut.resolve(
            at: AbsolutePath(validating: packagePath),
            cacheKey: nil
        )

        let alamofire = try #require(resolvedPackages.first { $0.identity.description == "alamofire" })
        #expect(alamofire.displayName == "Alamofire")
        #expect(alamofire.products == ["Alamofire", "AlamofireDynamic"])
        #expect(alamofire.locationDescription == "https://github.com/Alamofire/Alamofire")
        #expect(alamofire.stateDescription == "5.10.2")

        let swiftArgumentParser = try #require(resolvedPackages.first { $0.identity.description == "swift-log" })
        #expect(swiftArgumentParser.displayName == "swift-log")
        #expect(swiftArgumentParser.products == ["Logging"])
        #expect(swiftArgumentParser.locationDescription == "https://github.com/apple/swift-log")
        #expect(swiftArgumentParser.stateDescription == "1.6.3")

        try? FileManager.default.removeItem(atPath: packagePath)
    }
}
