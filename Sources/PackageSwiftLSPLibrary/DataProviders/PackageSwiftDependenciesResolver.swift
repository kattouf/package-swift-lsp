import Basics
import ConcurrencyExtras
import PackageGraph
import PackageModel
@preconcurrency import Workspace

struct ResolvedPackageInfo: Sendable, Equatable {
    let identity: String
    let locationDescription: String
    let displayName: String
    let stateDescription: String
    let products: [String]
}

final class PackageSwiftDependenciesResolver: Sendable {
    func resolve(at rootPackagePath: AbsolutePath, cacheKey: String? = nil) async throws -> [ResolvedPackageInfo] {
        let rootInput = PackageGraphRootInput(packages: [rootPackagePath])
        let handler = ObservabilityHandlerWithDiagnostics()
        let observabilitySystem = ObservabilitySystem(handler)
        let localFileSystem = Basics.localFileSystem
        let scratchDirectory = Workspace.DefaultLocations.scratchDirectory(forRootPackage: rootPackagePath)
            .appending(component: "package-swift-lsp")

        var location = try Workspace.Location(forRootPackage: rootPackagePath, fileSystem: localFileSystem)
        location.scratchDirectory = scratchDirectory
        location.resolvedVersionsFile = scratchDirectory
            .appending(component: "Package\(cacheKey.map { "-\($0)" } ?? "").resolved")

        if !localFileSystem.exists(location.resolvedVersionsFile) {
            try localFileSystem.createDirectory(location.scratchDirectory, recursive: true)
            let originalProjectResolvedVersionsFile = rootPackagePath.appending(component: "Package.resolved")
            if localFileSystem.exists(originalProjectResolvedVersionsFile) {
                try localFileSystem.copy(from: originalProjectResolvedVersionsFile, to: location.resolvedVersionsFile)
            }
        }

        let workspace = try Workspace(
            fileSystem: localFileSystem,
            location: location
        )

        let packageGraph = try await workspace.loadPackageGraph(
            rootInput: rootInput,
            forceResolvedVersions: false,
            observabilityScope: observabilitySystem.topScope
        )
        if handler.hasErrors {
            try? localFileSystem.removeFileTree(location.resolvedVersionsFile)
            throw StringError("Failed to resolve dependencies")
        }
        let resolvedDependencies = await workspace.state.dependencies.reduce(into: [PackageIdentity: Workspace.ManagedDependency]()) {
            $0[$1.packageRef.identity] = $1
        }

        var packagesInfo: [ResolvedPackageInfo] = []

        let rootPackagesDirectDependencies = Set(packageGraph.rootPackages.flatMap(\.dependencies))
        for package in packageGraph.packages {
            let identity = package.identity

            guard rootPackagesDirectDependencies.contains(identity) else {
                continue
            }

            guard let resolvedDependency = resolvedDependencies[identity] else {
                continue
            }

            let info = ResolvedPackageInfo(
                identity: identity.description,
                locationDescription: resolvedDependency.packageRef.locationString,
                displayName: package.manifest.displayName,
                stateDescription: resolvedDependency.state.shortDescription ?? "",
                products: package.products.map { $0.name },
            )

            packagesInfo.append(info)
        }

        return packagesInfo
    }
}

private final class ObservabilityHandlerWithDiagnostics: ObservabilityHandlerProvider {
    private final class Handler: DiagnosticsHandler {
        let hasErrors = LockIsolated(false)

        func handleDiagnostic(scope _: ObservabilityScope, diagnostic: Diagnostic) {
            if diagnostic.severity == .error {
                hasErrors.setValue(true)
            }

            switch diagnostic.severity {
            case .error:
                logger.error("SwiftPM: \(diagnostic.message)\n")
            case .warning:
                logger.warning("SwiftPM: \(diagnostic.message)\n")
            case .info:
                logger.info("SwiftPM: \(diagnostic.message)\n")
            case .debug:
                logger.debug("SwiftPM: \(diagnostic.message)\n")
            }
        }
    }

    private let handler = Handler()

    var diagnosticsHandler: any DiagnosticsHandler { handler }

    var hasErrors: Bool { handler.hasErrors.value }
}

private extension Workspace.ManagedDependency.State {
    var shortDescription: String? {
        switch self {
        case let .fileSystem(path):
            path.description
        case let .sourceControlCheckout(checkoutState):
            checkoutState.description
        case let .registryDownload(version):
            version.description
        case let .edited(basedOn, unmanagedPath):
            if let basedOn {
                basedOn.packageRef.identity.description
            } else if let unmanagedPath {
                unmanagedPath.description
            } else {
                nil
            }
        case .custom:
            nil
        }
    }
}
