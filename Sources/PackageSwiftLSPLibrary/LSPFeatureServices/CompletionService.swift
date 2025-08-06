import LanguageServerProtocol
import Workspace

final class CompletionService: Sendable {
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
                    queryRange: argument.stringValueRange
                )
            case .branch:
                if let urlArgument = arguments[.url] {
                    try await completePackageBranch(
                        query: argument.stringValue,
                        queryRange: argument.stringValueRange,
                        url: urlArgument.stringValue
                    )
                } else {
                    .empty
                }
            case .exact,
                 .from:
                if let urlArgument = arguments[.url] {
                    try await completePackageVersion(
                        query: argument.stringValue,
                        queryRange: argument.stringValueRange,
                        url: urlArgument.stringValue
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
                    queryRange: argument.stringValueRange,
                    package: arguments[.package]?.stringValue,
                    document: packageSwiftDocument
                )
            case .package:
                try await completeProductPackage(
                    query: argument.stringValue,
                    queryRange: argument.stringValueRange,
                    product: arguments[.name]?.stringValue,
                    document: packageSwiftDocument
                )
            default:
                .empty
            }
        case let .targetDependencyStringLiteral(value, valueRange):
            return try await completeProductNameWithPackageOrLocalTarget(
                query: value,
                queryRange: valueRange,
                document: packageSwiftDocument
            )
        case .targetDefinitionFunctionCall:
            return .empty
        case let .targetDeclarationFunctionCall(arguments):
            guard let argument = arguments.activeArgument() else {
                return .empty
            }
            return switch argument.label {
            case .name:
                try await completeLocalTargetName(
                    query: argument.stringValue,
                    queryRange: argument.stringValueRange,
                    document: packageSwiftDocument
                )
            default:
                .empty
            }
        }
    }
}

extension CompletionService {
    // MARK: - SwiftPackageIndex Provider

    private func completePackageURL(
        query: String,
        queryRange: OneBasedRange
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
                insertRange: queryRange
            )
        }
        logger.info("Found \(completionItems.count) candidates for package URL")
        return completionItems.asCompletionResponse()
    }

    // MARK: - Git Provider

    private func completePackageVersion(query: String, queryRange: OneBasedRange, url: String) async throws -> CompletionResponse {
        logger.debug("Complete package version by query: '\(query)' for url: '\(url)'")
        let refs = try await gitRefsProvider.get(.tags, for: url)
            .compactMap(Semver.init(string:))
            .sorted { Semver.areInIncreasingOrder(lhs: $1, rhs: $0) }
            .enumerated().map { index, ref in
                CompletionItemDTO(label: ref.stringValue, insertRange: queryRange, positionIndex: index)
            }

        guard !query.isEmpty else {
            return refs.asCompletionResponse(disableFilter: true)
        }
        let completionResponse = FuzzySearch(query: query, candidates: refs, searchBy: { $0.label })()
            .asCompletionResponse()
        logger.info("Found \(completionResponse?.items.count ?? 0) candidates for package version")
        return completionResponse
    }

    private func completePackageBranch(query: String, queryRange: OneBasedRange, url: String) async throws -> CompletionResponse {
        logger.debug("Complete package branch by query: '\(query)' for url: '\(url)'")
        let refs = try await gitRefsProvider.get(.branches, for: url)
        guard !query.isEmpty else {
            return refs.asCompletionResponse(disableFilter: true)
        }
        let completionResponse = FuzzySearch(query: query, candidates: refs)()
            .asCompletionResponse(insertRange: queryRange)
        logger.info("Found \(completionResponse?.items.count ?? 0) candidates for package branch")
        return completionResponse
    }

    // MARK: - SPM Provider

    private func completeProductNameWithPackageOrLocalTarget(
        query: String,
        queryRange: OneBasedRange,
        document: PackageSwiftDocument,
    ) async throws -> CompletionResponse {
        logger.debug("Complete product name with package by query: '\(query)')'")
        var completionItems: [CompletionItem] = []

        // Add local targets
        let localTargets = document.allItems().definedTargetsNames.map {
            CompletionItem(
                label: $0,
                kind: .value,
                documentation: .optionA("Local target"),
                textEdit: .optionA(
                    TextEdit(
                        range: LSPRange(queryRange),
                        newText: $0
                    )
                ),
                additionalTextEdits: [
                    TextEdit(
                        range: LSPRange(
                            start: Position(queryRange.end.shiftedColumn(by: $0.count + 1)!),
                            end: Position(queryRange.end.shiftedColumn(by: $0.count + 1)!)
                        ),
                        newText: "),"
                    ),
                    TextEdit(
                        range: LSPRange(
                            start: Position(queryRange.start.shiftedColumn(by: -1)!),
                            end: Position(queryRange.start.shiftedColumn(by: -1)!)
                        ),
                        newText: ".target(name: "
                    ),
                ]
            )
        }
        completionItems.append(contentsOf: localTargets)

        // Add external products
        let externalProductItems: [CompletionItem] = await resolvedDependenciesProvider.resolvedDependencies(for: document)
            .flatMap { package in
                let packageName = package.displayName.lowercased() == package.identity.description
                    ? package.displayName
                    : package.identity.description
                return package.products.map {
                    CompletionItem(
                        label: $0,
                        kind: .value,
                        documentation: .optionA(packageName),
                        textEdit: .optionA(
                            TextEdit(
                                range: LSPRange(queryRange),
                                newText: $0
                            )
                        ),
                        additionalTextEdits: [
                            TextEdit(
                                range: LSPRange(
                                    start: Position(queryRange.end.shiftedColumn(by: $0.count + 1)!),
                                    end: Position(queryRange.end.shiftedColumn(by: $0.count + 1)!)
                                ),
                                newText: ", package: \"\(packageName)\"),"
                            ),
                            TextEdit(
                                range: LSPRange(
                                    start: Position(queryRange.start.shiftedColumn(by: -1)!),
                                    end: Position(queryRange.start.shiftedColumn(by: -1)!)
                                ),
                                newText: ".product(name: "
                            ),
                        ]
                    )
                }
            }
        completionItems.append(contentsOf: externalProductItems)

        guard !query.isEmpty else {
            logger.info("Found \(completionItems.count) candidates for product name")
            return .optionB(CompletionList(
                isIncomplete: false,
                items: completionItems
            ))
        }

        let filteredItems = FuzzySearch(query: query, candidates: completionItems, searchBy: { $0.label })()
        let completionResponse: CompletionResponse = .optionB(
            CompletionList(
                isIncomplete: false,
                items: filteredItems
            )
        )
        logger.info("Found \(completionResponse?.items.count ?? 0) candidates for product name")
        return completionResponse
    }

    private func completeProductName(
        query: String,
        queryRange: OneBasedRange,
        package: String?,
        document: PackageSwiftDocument
    ) async throws -> CompletionResponse {
        logger.debug("Complete product name by query: '\(query)' for package: '\(package ?? "")'")
        let externalPackages = await resolvedDependenciesProvider.resolvedDependencies(for: document)

        if
            let package,
            let packageInfo = externalPackages.first(where: {
                $0.identity.description == package.lowercased()
            }),
            !package.isEmpty
        {
            guard !query.isEmpty else {
                logger.info("Found \(packageInfo.products.count) candidates for product name")
                return packageInfo.products
                    .asCompletionResponse(disableFilter: true, insertRange: queryRange)
            }

            let completionResponse = FuzzySearch(query: query, candidates: packageInfo.products)()
                .asCompletionResponse(insertRange: queryRange)
            logger.info("Found \(completionResponse?.items.count ?? 0) candidates for product name")
            return completionResponse
        } else {
            let allProducts: [CompletionItemDTO] = externalPackages
                .flatMap { package in
                    package.products.map {
                        CompletionItemDTO(
                            label: $0,
                            insertRange: queryRange,
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
        queryRange: OneBasedRange,
        product: String?,
        document: PackageSwiftDocument
    ) async throws -> CompletionResponse {
        logger.debug("Complete product package name by query: '\(query)' for product: '\(product ?? "")'")
        let externalPackages = await resolvedDependenciesProvider.resolvedDependencies(for: document)

        let packages: [CompletionItemDTO] = externalPackages
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
                    insertRange: queryRange,
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

    private func completeLocalTargetName(
        query: String,
        queryRange: OneBasedRange,
        document: PackageSwiftDocument,
    ) async throws -> CompletionResponse {
        logger.debug("Complete local target name by query: '\(query)'")
        let targets: [CompletionItemDTO] = document.allItems().definedTargetsNames.map {
            CompletionItemDTO(
                label: $0,
                insertRange: queryRange,
                documentation: "Local target",
            )
        }

        guard !query.isEmpty else {
            logger.info("Found \(targets.count) candidates for local target")
            return targets
                .asCompletionResponse(disableFilter: true)
        }

        let completionResponse = FuzzySearch(query: query, candidates: targets, searchBy: { $0.label })()
            .asCompletionResponse()
        logger.info("Found \(completionResponse?.items.count ?? 0) candidates for local target")
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

private extension [PackageSwiftItem] {
    var definedTargetsNames: [String] {
        compactMap { packageSwiftItem -> String? in
            if case let .targetDefinitionFunctionCall(arguments) = packageSwiftItem {
                guard let nameArgument = arguments[.name] else {
                    return nil
                }
                if case .name = nameArgument.label {
                    return nameArgument.stringValue
                }
            }
            return nil
        }
    }
}
