import LanguageServerProtocol
import Workspace

final class CompletionService: Sendable {
    private struct FunctionCompletionContext {
        let packageSwiftDocument: PackageSwiftDocument
        let argument: PackageSwiftItem.FunctionArgument
    }

    private let resolvedDependenciesProvider: PackageSwiftDependenciesProvider = .shared
    private let packagesRegistry: PackagesRegistry = .shared
    private let gitRefsProvider: GitRefsProvider = .shared

    func complete(
        at position: Position,
        in packageSwiftDocument: PackageSwiftDocument
    ) async throws -> CompletionResponse {
        logger.info("Looking for completion at \(position) in \(packageSwiftDocument.uri)")
        guard let packageSwiftItem = packageSwiftDocument.item(at: position) else {
            return .empty
        }

        switch packageSwiftItem {
        case let .packageFunctionCall(arguments):
            guard let argument = arguments.activeArgument() else {
                return .empty
            }
            return switch argument.label {
            case .url:
                try await completePackageURL(
                    query: argument.stringValue,
                    context: .init(packageSwiftDocument: packageSwiftDocument, argument: argument)
                )
            case .branch:
                if let urlArgument = arguments[.url] {
                    try await completePackageBranch(
                        query: argument.stringValue,
                        url: urlArgument.stringValue,
                        context: .init(packageSwiftDocument: packageSwiftDocument, argument: argument)
                    )
                } else {
                    .empty
                }
            case .exact,
                 .from:
                if let urlArgument = arguments[.url] {
                    try await completePackageVersion(
                        query: argument.stringValue,
                        url: urlArgument.stringValue,
                        context: .init(packageSwiftDocument: packageSwiftDocument, argument: argument)
                    )
                } else {
                    .empty
                }
            default:
                .empty
            }
        case let .productFunctionCall(arguments):
            guard let argument = arguments.activeArgument() else {
                return .empty
            }
            return switch argument.label {
            case .name:
                try await completeProductName(
                    query: argument.stringValue,
                    package: arguments[.package]?.stringValue,
                    context: .init(packageSwiftDocument: packageSwiftDocument, argument: argument)
                )
            case .package:
                try await completeProductPackage(
                    query: argument.stringValue,
                    product: arguments[.name]?.stringValue,
                    context: .init(packageSwiftDocument: packageSwiftDocument, argument: argument)
                )
            default:
                .empty
            }
        case let .targetDependencyStringLiteral(value, range):
            return try await completeProductStringLiteral(
                query: value,
                document: packageSwiftDocument,
                range: range
            )
        }
    }
}

extension CompletionService {
    // MARK: - SwiftPackageIndex Provider

    private func completePackageURL(
        query: String,
        context: FunctionCompletionContext
    ) async throws -> CompletionResponse {
        logger.debug("Complete package URL by query: '\(query)'")
        guard !query.isEmpty else {
            return .empty
        }
        let candidates = await packagesRegistry.getPackages()
        let searchStringGenerator: (GithubPackage) -> String = {
            if query.hasPrefix("https://github.com/") {
                $0.url
            } else {
                "\($0.user)/\($0.repository)"
            }
        }
        let completionItems = FuzzySearch(query: query, candidates: candidates, searchBy: searchStringGenerator)().map {
            CompletionItemDTO(
                label: searchStringGenerator($0),
                insertText: $0.url,
                insertRange: context.argument.stringValueRange
            )
        }
        logger.info("Found \(completionItems.count) candidates for package URL")
        return completionItems.asCompletionResponse()
    }

    // MARK: - Git Provider

    private func completePackageVersion(query: String, url: String, context: FunctionCompletionContext) async throws -> CompletionResponse {
        logger.debug("Complete package version by query: '\(query)' for url: '\(url)'")
        let refs = try await gitRefsProvider.get(.tags, for: url)
            .compactMap(Semver.init(string:))
            .sorted { Semver.areInIncreasingOrder(lhs: $1, rhs: $0) }
            .enumerated().map { index, ref in
                CompletionItemDTO(label: ref.stringValue, insertRange: context.argument.stringValueRange, positionIndex: index)
            }

        guard !query.isEmpty else {
            return refs.asCompletionResponse(disableFilter: true)
        }
        let completionResponse = FuzzySearch(query: query, candidates: refs, searchBy: { $0.label })()
            .asCompletionResponse()
        logger.info("Found \(completionResponse?.items.count ?? 0) candidates for package version")
        return completionResponse
    }

    private func completePackageBranch(query: String, url: String, context: FunctionCompletionContext) async throws -> CompletionResponse {
        logger.debug("Complete package branch by query: '\(query)' for url: '\(url)'")
        let refs = try await gitRefsProvider.get(.branches, for: url)
        guard !query.isEmpty else {
            return refs.asCompletionResponse(disableFilter: true)
        }
        let completionResponse = FuzzySearch(query: query, candidates: refs)()
            .asCompletionResponse(insertRange: context.argument.stringValueRange)
        logger.info("Found \(completionResponse?.items.count ?? 0) candidates for package branch")
        return completionResponse
    }

    // MARK: - SPM Provider

    private func completeProductStringLiteral(
        query: String,
        document: PackageSwiftDocument,
        range: OneBasedRange
    ) async throws -> CompletionResponse {
        logger.debug("Complete product string literal by query: '\(query)')'")
        let resolvedPackages = await resolvedDependenciesProvider.resolvedDependencies(for: document)

        let allProducts: [CompletionItemDTO] = resolvedPackages
            .flatMap { package in
                let packageName = package.displayName.lowercased() == package.identity.description
                    ? package.displayName
                    : package.identity.description
                return package.products.map {
                    CompletionItemDTO(
                        label: $0,
                        insertText: ".product(name: \"\($0)\", package: \"\(packageName)\")",
                        insertRange: range,
                        documentation: packageName,
                    )
                }
            }
        guard !query.isEmpty else {
            logger.info("Found \(allProducts.count) candidates for product name")
            return allProducts
                .asCompletionResponse(disableFilter: true)
        }

        let completionResponse = FuzzySearch(query: query, candidates: allProducts, searchBy: { $0.label })()
            .asCompletionResponse()
        logger.info("Found \(completionResponse?.items.count ?? 0) candidates for product name")
        return completionResponse
    }

    private func completeProductName(
        query: String,
        package: String?,
        context: FunctionCompletionContext
    ) async throws -> CompletionResponse {
        logger.debug("Complete product name by query: '\(query)' for package: '\(package ?? "")'")
        let resolvedPackages = await resolvedDependenciesProvider.resolvedDependencies(for: context.packageSwiftDocument)

        if
            let package,
            let packageInfo = resolvedPackages.first(where: {
                $0.identity.description == package.lowercased()
            }),
            !package.isEmpty
        {
            guard !query.isEmpty else {
                logger.info("Found \(packageInfo.products.count) candidates for product name")
                return packageInfo.products
                    .asCompletionResponse(disableFilter: true, insertRange: context.argument.stringValueRange)
            }

            let completionResponse = FuzzySearch(query: query, candidates: packageInfo.products)()
                .asCompletionResponse(insertRange: context.argument.stringValueRange)
            logger.info("Found \(completionResponse?.items.count ?? 0) candidates for product name")
            return completionResponse
        } else {
            let allProducts: [CompletionItemDTO] = resolvedPackages
                .flatMap { package in
                    package.products.map {
                        CompletionItemDTO(
                            label: $0,
                            insertRange: context.argument.stringValueRange,
                            documentation: package.displayName.lowercased() == package.identity.description
                                ? package.displayName
                                : package.identity.description,
                        )
                    }
                }
            guard !query.isEmpty else {
                logger.info("Found \(allProducts.count) candidates for product name")
                return allProducts
                    .asCompletionResponse(disableFilter: true)
            }

            let completionResponse = FuzzySearch(query: query, candidates: allProducts, searchBy: { $0.label })()
                .asCompletionResponse()
            logger.info("Found \(completionResponse?.items.count ?? 0) candidates for product name")
            return completionResponse
        }
    }

    private func completeProductPackage(
        query: String,
        product: String?,
        context: FunctionCompletionContext
    ) async throws -> CompletionResponse {
        logger.debug("Complete product package name by query: '\(query)' for product: '\(product ?? "")'")
        let resolvedPackages = await resolvedDependenciesProvider.resolvedDependencies(for: context.packageSwiftDocument)

        let packages: [CompletionItemDTO] = resolvedPackages
            .filter {
                if let product, !product.isEmpty {
                    $0.products.map { $0.lowercased() }.contains(product.lowercased())
                } else {
                    true
                }
            }.map {
                CompletionItemDTO(
                    label: $0.displayName.lowercased() == $0.identity.description
                        ? $0.displayName
                        : $0.identity.description,
                    insertRange: context.argument.stringValueRange,
                    documentation: $0.stateDescription
                )
            }

        guard !query.isEmpty else {
            logger.info("Found \(packages.count) candidates for product package")
            return packages
                .asCompletionResponse(disableFilter: true)
        }

        let completionResponse = FuzzySearch(query: query, candidates: packages, searchBy: { $0.label })()
            .asCompletionResponse()
        logger.info("Found \(completionResponse?.items.count ?? 0) candidates for product package")
        return completionResponse
    }
}

private extension CompletionResponse {
    static var empty: CompletionResponse {
        .optionB(.init(isIncomplete: true, items: []))
    }
}

struct CompletionItemDTO {
    let label: String
    let insertText: String?
    let insertRange: OneBasedRange?
    let documentation: String?
    let positionIndex: Int?

    init(
        label: String,
        insertText: String? = nil,
        insertRange: OneBasedRange? = nil,
        documentation: String? = nil,
        positionIndex: Int? = nil
    ) {
        self.label = label
        self.insertText = insertText
        self.insertRange = insertRange
        self.documentation = documentation
        self.positionIndex = positionIndex
    }
}

private extension [String] {
    func asCompletionResponse(
        isIncomplete: Bool = false,
        disableFilter: Bool = false,
        insertRange: OneBasedRange? = nil
    ) -> CompletionResponse {
        .optionB(
            CompletionList(
                isIncomplete: isIncomplete,
                items: map { label in CompletionItem(
                    label: label,
                    kind: .value,
                    filterText: disableFilter ? "" : nil,
                    textEdit: insertRange.map {
                        .optionA(.init(
                            range: LSPRange($0),
                            newText: label
                        ))
                    }
                ) }
            )
        )
    }
}

private extension [CompletionItemDTO] {
    func asCompletionResponse(isIncomplete: Bool = false, disableFilter: Bool = false) -> CompletionResponse {
        .optionB(
            CompletionList(
                isIncomplete: isIncomplete,
                items: map { item in CompletionItem(
                    label: item.label,
                    kind: .value,
                    documentation: item.documentation.map { .optionA($0) },
                    sortText: item.positionIndex.map { String(format: "%05d", $0) },
                    filterText: disableFilter ? "" : nil,
                    insertText: item.insertText,
                    textEdit: item.insertRange.map {
                        .optionA(.init(
                            range: LSPRange($0),
                            newText: item.insertText ?? item.label
                        ))
                    }
                ) }
            )
        )
    }
}
