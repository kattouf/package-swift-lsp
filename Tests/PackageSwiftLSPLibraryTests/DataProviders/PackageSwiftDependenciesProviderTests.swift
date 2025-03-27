import Basics
@testable import PackageSwiftLSPLibrary
import Testing

struct PackageSwiftDependenciesProviderTests {
    @Test
    func resolving() async throws {
        nonisolated(unsafe) var resolveCallsCount = 0
        let sut = PackageSwiftDependenciesProvider(resolveDependencies: { packagePath, _ in
            resolveCallsCount += 1
            return generateTestResolvedPackagesInfo(forPackagSwiftPath: packagePath.pathString)
        })
        let packageSwiftDocument = try generatePackageSwiftDocument(
            path: "/dev/null/1/Package.swift",
            dependencies: [(url: "https://github.com/example/package", exactVersion: "1.0.0")]
        )

        // normal resolving

        try await sut.resolveDependencies(for: packageSwiftDocument)
        #expect(resolveCallsCount == 1)

        try await sut.resolveDependencies(for: packageSwiftDocument)
        #expect(resolveCallsCount == 1)

        let resolvedDependencies = await sut.resolvedDependencies(for: packageSwiftDocument)
        #expect(resolvedDependencies[0].locationDescription == "/dev/null/1")

        // resolving after dependencies list modification

        let updatedPackageSwiftDocument = try generatePackageSwiftDocument(
            path: packageSwiftDocument.uri,
            dependencies: [(url: "https://github.com/example/package", exactVersion: "1.0.1")]
        )

        try await sut.resolveDependencies(for: updatedPackageSwiftDocument)
        #expect(resolveCallsCount == 2)

        try await sut.resolveDependencies(for: updatedPackageSwiftDocument)
        #expect(resolveCallsCount == 2)

        let updatedResolvedDependencies = await sut.resolvedDependencies(for: updatedPackageSwiftDocument)
        #expect(updatedResolvedDependencies[0].locationDescription == "/dev/null/1")

        // resolving new workspace Package.swift with same dependencies

        let newPackageSwiftDocumentWithSameDependencies = try generatePackageSwiftDocument(
            path: "/dev/null/2/Package.swift",
            dependencies: [(url: "https://github.com/example/package", exactVersion: "1.0.1")]
        )

        try await sut.resolveDependencies(for: newPackageSwiftDocumentWithSameDependencies)
        #expect(resolveCallsCount == 2)

        try await sut.resolveDependencies(for: newPackageSwiftDocumentWithSameDependencies)
        #expect(resolveCallsCount == 2)

        let newResolvedDependencies = await sut.resolvedDependencies(for: newPackageSwiftDocumentWithSameDependencies)
        #expect(newResolvedDependencies[0].locationDescription == "/dev/null/1") // deps from first workspace because of same dependencies

        // resolving new workspace Package.swift with different dependencies

        let newPackageSwiftDocumentWithDifferentDependencies = try generatePackageSwiftDocument(
            path: "/dev/null/2/Package.swift",
            dependencies: [(url: "https://github.com/example/package", exactVersion: "1.0.2")]
        )

        try await sut.resolveDependencies(for: newPackageSwiftDocumentWithDifferentDependencies)
        #expect(resolveCallsCount == 3)

        try await sut.resolveDependencies(for: newPackageSwiftDocumentWithDifferentDependencies)
        #expect(resolveCallsCount == 3)

        let newResolvedDependenciesWithDifferentDependencies = await sut
            .resolvedDependencies(for: newPackageSwiftDocumentWithDifferentDependencies)
        #expect(newResolvedDependenciesWithDifferentDependencies[0].locationDescription == "/dev/null/2")
    }

    @Test
    func resolvingWhenSameDependenciesResolvingAreStillInProgress() async throws {
        nonisolated(unsafe) var resolveCallsCount = 0

        let sut = PackageSwiftDependenciesProvider(resolveDependencies: { packagePath, _ in
            resolveCallsCount += 1
            // Simulate a long-running dependency resolution
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.1 seconds
            return generateTestResolvedPackagesInfo(forPackagSwiftPath: packagePath.pathString)
        })

        let packageSwiftDocument = try generatePackageSwiftDocument(
            path: "/dev/null/1/Package.swift",
            dependencies: [(url: "https://github.com/example/package", exactVersion: "1.0.0")]
        )

        let task1 = Task {
            try await sut.resolveDependencies(for: packageSwiftDocument)
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        let task2 = Task {
            try await sut.resolveDependencies(for: packageSwiftDocument)
        }

        try await task1.value
        try await task2.value

        #expect(resolveCallsCount == 1)

        let resolvedDependencies = await sut.resolvedDependencies(for: packageSwiftDocument)
        #expect(resolvedDependencies.count == 1)
        #expect(resolvedDependencies[0].locationDescription == "/dev/null/1")
    }

    @Test
    func resolvingFallbacksToPreviousResolvedDependencies() async throws {
        enum TestError: Error {
            case somethingWentWrong
        }

        nonisolated(unsafe) let shouldFail = RefBox(true)

        let sut = PackageSwiftDependenciesProvider(resolveDependencies: { packagePath, _ in
            if shouldFail.value {
                throw TestError.somethingWentWrong
            }
            return generateTestResolvedPackagesInfo(forPackagSwiftPath: packagePath.pathString)
        })

        let packageSwiftDocument = try generatePackageSwiftDocument(
            path: "/dev/null/1/Package.swift",
            dependencies: [(url: "https://github.com/example/package", exactVersion: "1.0.0")]
        )

        // First resolving attempt fails
        try await sut.resolveDependencies(for: packageSwiftDocument)

        // No resolved dependencies should be available
        let resolvedDependencies = await sut.resolvedDependencies(for: packageSwiftDocument)
        #expect(resolvedDependencies.isEmpty)

        // Successful resolution
        shouldFail.value = false
        try await sut.resolveDependencies(for: packageSwiftDocument)

        let successfullyResolvedDependencies = await sut.resolvedDependencies(for: packageSwiftDocument)
        #expect(successfullyResolvedDependencies.count == 1)
        #expect(successfullyResolvedDependencies[0].locationDescription == "/dev/null/1")

        // After successful resolution, subsequent failures should fallback to previous results
        shouldFail.value = true
        try await sut.resolveDependencies(for: packageSwiftDocument)

        // Should still have the same dependencies as before if dependencies are the same
        let fallbackDependencies = await sut.resolvedDependencies(for: packageSwiftDocument)
        #expect(fallbackDependencies.count == 1)
        #expect(fallbackDependencies[0].locationDescription == "/dev/null/1")

        // Should still have the same dependencies as before even if dependencies were changed
        let updatedPackageSwiftDocument = try generatePackageSwiftDocument(
            path: packageSwiftDocument.uri,
            dependencies: [(url: "https://github.com/example/package", exactVersion: "1.0.2")]
        )
        let updatedDocumentFallbackDependencies = await sut.resolvedDependencies(for: updatedPackageSwiftDocument)
        #expect(updatedDocumentFallbackDependencies.count == 1)
        #expect(updatedDocumentFallbackDependencies[0].locationDescription == "/dev/null/1")

        // Should have resolved dependencies for a new workspace Package.swift with same dependencies
        let newPackageSwiftDocumentWithSameDependencies = try generatePackageSwiftDocument(
            path: "/dev/null/2/Package.swift",
            dependencies: [(url: "https://github.com/example/package", exactVersion: "1.0.0")]
        )
        let newPackageSwiftDocumentFallbackDependencies = await sut.resolvedDependencies(for: newPackageSwiftDocumentWithSameDependencies)
        #expect(newPackageSwiftDocumentFallbackDependencies.count == 1)
        #expect(newPackageSwiftDocumentFallbackDependencies[0].locationDescription == "/dev/null/1")

        // Should not have resolved dependencies for a new workspace Package.swift with different dependencies
        let newPackageSwiftDocumentWithDifferentDependencies = try generatePackageSwiftDocument(
            path: "/dev/null/2/Package.swift",
            dependencies: [(url: "https://github.com/example/package-2", exactVersion: "1.0.0")]
        )
        #expect(await sut.resolvedDependencies(for: newPackageSwiftDocumentWithDifferentDependencies).isEmpty)
    }

    private func generatePackageSwiftDocument(
        path: String,
        dependencies: [(url: String, exactVersion: String)]
    ) throws -> PackageSwiftDocument {
        let dependenciesString = dependencies.map { ".package(url: \"\($0.url)\", from: \"\($0.exactVersion)\")" }
            .joined(separator: ",\n        ")
        let source = """
        // swift-tools-version: 6.0.0
        import PackageDescription

        let package = Package(
            name: "test-package",
            products: [
                .library(name: "test-package", targets: ["test-package"]),
            ],
            dependencies: [
                \(dependenciesString)
            ],
            targets: [
                .target(name: "test-package", dependencies: []),
            ]
        )
        """

        return PackageSwiftDocument(
            filePath: path,
            source: source
        )
    }

    private func generateTestResolvedPackagesInfo(forPackagSwiftPath location: String) -> [ResolvedPackageInfo] {
        let testData: [ResolvedPackageInfo] = [
            .init(
                identity: "example-package",
                locationDescription: location,
                displayName: "ExamplePackage",
                stateDescription: "1.0.0",
                products: ["ExampleProduct"]
            ),
        ]
        return testData
    }
}

private final class RefBox<T> {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}
