import LanguageServerProtocol
import Workspace

final class HoverService {
    private let resolvedDependenciesProvider: PackageSwiftDependenciesProvider = .shared

    func hover(
        at position: Position,
        in packageSwiftDocument: PackageSwiftDocument
    ) async throws -> HoverResponse {
        logger.info("Looking for hover at \(position) in \(packageSwiftDocument.uri)")
        guard let packageSwiftItem = packageSwiftDocument.item(at: position) else {
            return nil
        }

        switch packageSwiftItem {
        case let .productFunctionCall(arguments):
            guard let argument = arguments.activeArgument() else {
                return nil
            }
            let response: HoverResponse = switch argument.label {
            case .package:
                try await productPackageHover(
                    package: argument.stringValue,
                    context: packageSwiftDocument
                )
            default: nil
            }
            if let response {
                logger.info("Hover found: \(response)")
            } else {
                logger.debug("No hover found")
            }
            return response
        default: return nil
        }
    }
}

private extension HoverService {
    func productPackageHover(
        package: String,
        context: PackageSwiftDocument
    ) async throws -> HoverResponse {
        let resolvedPackages = await resolvedDependenciesProvider.resolvedDependencies(for: context)
        guard
            let packageInfo = resolvedPackages.first(where: {
                $0.identity.description == package.lowercased()
            }),
            !package.isEmpty
        else {
            return nil
        }

        let hoverContent = "### \(packageInfo.displayName)\n\(packageInfo.locationDescription)\(" – \(packageInfo.stateDescription)")" +
            "  \nProducts:  \n\(packageInfo.products.map { "  - \($0)" }.joined(separator: "\n"))"

        return Hover(
            contents: .optionC(.init(kind: .markdown, value: hoverContent)),
            range: nil
        )
    }
}
