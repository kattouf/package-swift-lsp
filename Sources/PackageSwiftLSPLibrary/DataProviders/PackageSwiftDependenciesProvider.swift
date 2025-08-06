import Basics
import ConcurrencyExtras
import Foundation
import LanguageServerProtocol

final actor PackageSwiftDependenciesProvider {
    private let resolveDependencies: @Sendable (_ rootPackagePath: AbsolutePath, _ cacheKey: String?) async throws -> [ResolvedPackageInfo]

    private var resolvingInProgressByUniqueDependenciesHashValue = Set<String>()
    private var resolvedDependenciesByDependenciesHashValue = [String: [ResolvedPackageInfo]]()
    // used as rollback cache
    private var resolvedDependenciesByDocumentUri = [DocumentUri: [ResolvedPackageInfo]]()

    init(
        resolveDependencies: @escaping @Sendable (_ rootPackagePath: AbsolutePath, _ cacheKey: String?) async throws
            -> [ResolvedPackageInfo]
    ) {
        self.resolveDependencies = resolveDependencies
    }

    static let shared: PackageSwiftDependenciesProvider = {
        let resolver = PackageSwiftDependenciesResolver()
        return .init { rootPackagePath, cacheKey in
            try await resolver.resolve(at: rootPackagePath, cacheKey: cacheKey)
        }
    }()

    func shouldResolveDependencies(for packageSwiftDocument: PackageSwiftDocument) -> Bool {
        let dependenciesCacheKey = packageSwiftDocument.dependenciesDeterministicHashValue()
        if resolvedDependenciesByDependenciesHashValue.keys.contains(dependenciesCacheKey) {
            return false
        }
        if resolvingInProgressByUniqueDependenciesHashValue.contains(dependenciesCacheKey) {
            return false
        }
        return true
    }

    func resolveDependencies(for packageSwiftDocument: PackageSwiftDocument) async throws {
        logger.info("Resolving dependencies for \(packageSwiftDocument.uri)")
        guard shouldResolveDependencies(for: packageSwiftDocument) else {
            return
        }
        let dependenciesCacheKey = packageSwiftDocument.dependenciesDeterministicHashValue()
        _ = resolvingInProgressByUniqueDependenciesHashValue.insert(dependenciesCacheKey)
        defer {
            _ = resolvingInProgressByUniqueDependenciesHashValue.remove(dependenciesCacheKey)
        }
        let rootPackagePath = try AbsolutePath(validating: packageSwiftDocument.uri.replacingOccurrences(of: "file://", with: ""))
            .parentDirectory
        guard let resolvedDependencies = try? await resolveDependencies(
            rootPackagePath,
            dependenciesCacheKey
        ) else {
            logger.error("Failed to resolve dependencies for \(packageSwiftDocument.uri)")
            return
        }
        logger.debug("Resolved dependencies for \(packageSwiftDocument.uri): \(resolvedDependencies)")
        resolvedDependenciesByDependenciesHashValue[dependenciesCacheKey] = resolvedDependencies
        resolvedDependenciesByDocumentUri[packageSwiftDocument.uri] = resolvedDependencies
    }

    func resolvedDependencies(for packageSwiftDocument: PackageSwiftDocument) -> [ResolvedPackageInfo] {
        let resolvedDependencies =
            resolvedDependenciesByDependenciesHashValue[packageSwiftDocument.dependenciesDeterministicHashValue()]
                ?? resolvedDependenciesByDocumentUri[packageSwiftDocument.uri]
                ?? []
        return resolvedDependencies
    }
}

private extension PackageSwiftDocument {
    func dependenciesDeterministicHashValue() -> String {
        allItems()
            .filter {
                if case .packageFunctionCall = $0 {
                    true
                } else {
                    false
                }
            }
            .deterministicHashValue
    }
}

extension PackageSwiftItem: DeterministicHashable {
    var deterministicHashValue: String {
        switch self {
        case let .packageFunctionCall(arguments):
            "packageFunctionCall(\(arguments.deterministicHashValue))"
        case let .productFunctionCall(arguments):
            "productFunctionCall(\(arguments.deterministicHashValue))"
        // TODO: include range in hash value?
        case let .targetDependencyStringLiteral(value, _):
            "targetDependencyStringLiteral(\(value))"
        case let .targetDeclarationFunctionCall(arguments):
            "targetDeclarationFunctionCall(\(arguments.deterministicHashValue))"
        case let .targetDefinitionFunctionCall(arguments):
            "targetDefinitionFunctionCall(\(arguments.deterministicHashValue))"
        }
    }
}

extension PackageSwiftItem.NonEmptyFunctionArguments: DeterministicHashable {
    // TODO: include range in hash value?
    var deterministicHashValue: String {
        arguments.map { "\($0.label):\($0.stringValue)" }.sorted().deterministicHashValue
    }
}
