import LanguageServerProtocol

struct OneBasedPosition: Equatable {
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

extension OneBasedPosition {
    func shiftedColumn(by delta: Int) -> OneBasedPosition? {
        let shiftResult = column.addingReportingOverflow(delta)
        guard shiftResult.overflow == false else {
            return nil
        }
        return OneBasedPosition(line: line, column: shiftResult.partialValue)
    }

    func shiftedLine(by delta: Int) -> OneBasedPosition? {
        let shiftResult = line.addingReportingOverflow(delta)
        guard shiftResult.overflow == false else {
            return nil
        }
        return OneBasedPosition(line: shiftResult.partialValue, column: column)
    }
}

extension OneBasedPosition: Comparable {
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.line < rhs.line {
            return true
        }
        if lhs.line > rhs.line {
            return false
        }

        if lhs.column < rhs.column {
            return true
        }
        return false
    }
}
