import SwiftSyntax

extension OneBasedPosition {
    init(_ sourceLocation: SourceLocation) {
        self.line = sourceLocation.line
        self.column = sourceLocation.column
    }
}
