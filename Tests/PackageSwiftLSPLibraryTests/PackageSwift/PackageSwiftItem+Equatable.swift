@testable import PackageSwiftLSPLibrary

extension PackageSwiftItem: Equatable {
    public static func == (lhs: PackageSwiftItem, rhs: PackageSwiftItem) -> Bool {
        switch (lhs, rhs) {
        case let (.packageFunctionCall(lhsArgs), .packageFunctionCall(rhsArgs)):
            lhsArgs == rhsArgs
        case let (.productFunctionCall(lhsArgs), .productFunctionCall(rhsArgs)):
            lhsArgs == rhsArgs
        default:
            false
        }
    }
}

extension PackageSwiftItem.NonEmptyFunctionArguments: Equatable {
    public static func == (lhs: PackageSwiftItem.NonEmptyFunctionArguments, rhs: PackageSwiftItem.NonEmptyFunctionArguments) -> Bool {
        lhs.arguments == rhs.arguments && lhs.activeArgumentIndex == rhs.activeArgumentIndex
    }
}

extension PackageSwiftItem.FunctionArgument: Equatable {
    public static func == (lhs: PackageSwiftItem.FunctionArgument, rhs: PackageSwiftItem.FunctionArgument) -> Bool {
        lhs.label == rhs.label && lhs.stringValue == rhs.stringValue
    }
}
