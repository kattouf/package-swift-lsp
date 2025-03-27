import LanguageServerProtocol

extension LSPRange {
    init(_ oneBasedRange: OneBasedRange) {
        self.init(start: Position(oneBasedRange.start), end: Position(oneBasedRange.end))
    }
}
