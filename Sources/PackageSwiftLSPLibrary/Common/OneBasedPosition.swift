import LanguageServerProtocol

struct OneBasedPosition {
    let line: Int
    let column: Int

    init?(line: Int, column: Int) {
        guard line > 0, column > 0 else {
            return nil
        }

        self.line = line
        self.column = column
    }
}
