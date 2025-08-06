enum PackageSwiftItem {
    case packageFunctionCall(arguments: NonEmptyFunctionArguments)
    case productFunctionCall(arguments: NonEmptyFunctionArguments)
    case targetDependencyStringLiteral(value: String, valueRange: OneBasedRange)
    case targetDefinitionFunctionCall(arguments: NonEmptyFunctionArguments)
    case targetDeclarationFunctionCall(arguments: NonEmptyFunctionArguments)
}

extension PackageSwiftItem {
    struct NonEmptyFunctionArguments {
        let arguments: [FunctionArgument]
        let activeArgumentIndex: Int?

        init?(arguments: [FunctionArgument], activeArgumentIndex: Int? = nil) {
            guard !arguments.isEmpty else {
                return nil
            }
            if let activeArgumentIndex, activeArgumentIndex >= arguments.count {
                return nil
            }
            self.arguments = arguments
            self.activeArgumentIndex = activeArgumentIndex
        }

        subscript(label: FunctionArgumentLabel) -> FunctionArgument? {
            arguments.first { $0.label == label }
        }

        func activeArgument() -> FunctionArgument? {
            guard let activeArgumentIndex else {
                return nil
            }
            return arguments[activeArgumentIndex]
        }
    }

    struct FunctionArgument {
        let label: FunctionArgumentLabel
        let stringValueRange: OneBasedRange
        let stringValue: String
    }

    enum FunctionArgumentLabel {
        case name
        case url
        case exact
        case branch
        case revision
        case from
        case package
        case dependencies
        case path

        static func from(label: String) -> FunctionArgumentLabel? {
            switch label {
            case "name": .name
            case "url": .url
            case "exact": .exact
            case "branch": .branch
            case "revision": .revision
            case "from": .from
            case "package": .package
            case "dependencies": .dependencies
            case "path": .path
            default: nil
            }
        }

        static func allowedLabels(for function: FunctionKind) -> Set<FunctionArgumentLabel> {
            switch function {
            case .package:
                [.name, .url, .exact, .branch, .revision, .from]
            case .product:
                [.name, .package]
            case .target,
                 .testTarget,
                 .executableTarget,
                 .macroTarget,
                 .binaryTarget,
                 .pluginTarget,
                 .systemLibraryTarget:
                [.name]
            }
        }
    }

    enum FunctionKind {
        case package
        case product
        case target
        case testTarget
        case executableTarget
        case macroTarget
        case binaryTarget
        case pluginTarget
        case systemLibraryTarget

        static func from(memberName: String) -> FunctionKind? {
            switch memberName {
            case "package": .package
            case "product": .product
            case "target": .target
            case "testTarget": .testTarget
            case "executableTarget": .executableTarget
            case "macro": .macroTarget
            case "binaryTarget": .binaryTarget
            case "plugin": .pluginTarget
            case "systemLibrary": .systemLibraryTarget
            default: nil
            }
        }
    }
}
