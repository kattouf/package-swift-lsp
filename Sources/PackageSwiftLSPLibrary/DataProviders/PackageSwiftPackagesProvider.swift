import Basics
import ConcurrencyExtras
import Foundation
import LanguageServerProtocol

final actor PackageSwiftPackagesProvider {
    private let resolvePackages: @Sendable (_ rootPackagePath: AbsolutePath, _ cacheKey: String?) async throws -> ResolvedPackages

    private var resolvingInProgressByUniquePackagesHashValue = Set<String>()
    private var resolvedPackagesByPackagesHashValue = [String: ResolvedPackages]()
    // is using as rollback cache
    private var resolvedPackagesByDocumentUri = [DocumentUri: ResolvedPackages]()

    init(
        resolvePackages: @escaping @Sendable (_ rootPackagePath: AbsolutePath, _ cacheKey: String?) async throws
            -> ResolvedPackages
    ) {
        self.resolvePackages = resolvePackages
    }

    static let shared: PackageSwiftPackagesProvider = {
        let resolver = PackageSwiftPackagesResolver()
        return .init { rootPackagePath, cacheKey in
            try await resolver.resolve(at: rootPackagePath, cacheKey: cacheKey)
        }
    }()

    func shouldResolvePackages(for packageSwiftDocument: PackageSwiftDocument) -> Bool {
        let packagesCacheKey = packageSwiftDocument.packagesDeterministicHashValue()
        if resolvedPackagesByPackagesHashValue.keys.contains(packagesCacheKey) {
            return false
        }
        if resolvingInProgressByUniquePackagesHashValue.contains(packagesCacheKey) {
            return false
        }
        return true
    }

    func resolvePackages(for packageSwiftDocument: PackageSwiftDocument) async throws {
        logger.info("Resolving packages for \(packageSwiftDocument.uri)")
        guard shouldResolvePackages(for: packageSwiftDocument) else {
            return
        }
        let packagesCacheKey = packageSwiftDocument.packagesDeterministicHashValue()
        _ = resolvingInProgressByUniquePackagesHashValue.insert(packagesCacheKey)
        defer {
            _ = resolvingInProgressByUniquePackagesHashValue.remove(packagesCacheKey)
        }
        let rootPackagePath = try AbsolutePath(validating: packageSwiftDocument.uri.replacingOccurrences(of: "file://", with: ""))
            .parentDirectory
        guard let resolvedPackages = try? await resolvePackages(
            rootPackagePath,
            packagesCacheKey
        ) else {
            logger.error("Failed to resolve packages for \(packageSwiftDocument.uri)")
            return
        }
        logger.debug("Resolved packages for \(packageSwiftDocument.uri): \(resolvedPackages)")
        resolvedPackagesByPackagesHashValue[packagesCacheKey] = resolvedPackages
        resolvedPackagesByDocumentUri[packageSwiftDocument.uri] = resolvedPackages
    }

    func resolvedPackages(for packageSwiftDocument: PackageSwiftDocument) -> ResolvedPackages {
        let resolvedPackages =
            resolvedPackagesByPackagesHashValue[packageSwiftDocument.packagesDeterministicHashValue()]
                ?? resolvedPackagesByDocumentUri[packageSwiftDocument.uri]
                ?? ResolvedPackages(localPackages: [], externalPackages: [])
        return resolvedPackages
    }
}

private extension PackageSwiftDocument {
    /// Hash document by items that we interested in by resolving Package.swift
    func packagesDeterministicHashValue() -> String {
        allItems()
            .filter {
                if case .packageFunctionCall = $0 {
                    true
                } else if case .targetDefinitionFunctionCall = $0 { // as part of "root" package
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
