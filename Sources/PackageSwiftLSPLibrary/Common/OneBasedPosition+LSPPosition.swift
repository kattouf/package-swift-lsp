import LanguageServerProtocol

extension OneBasedPosition {
    init(_ zeroBasedPosition: Position) {
        self.line = zeroBasedPosition.line + 1
        self.column = zeroBasedPosition.character + 1
    }
}

extension Position {
    init(_ oneBasedPosition: OneBasedPosition) {
        self.init(line: oneBasedPosition.line - 1, character: oneBasedPosition.column - 1)
    }
}
