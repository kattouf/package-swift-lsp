import Foundation

private let isTTY = isatty(STDOUT_FILENO) != 0

extension String {
    var ansiBlue: String {
        guard isTTY else {
            return self
        }
        return "\u{001B}[0;34m\(self)\u{001B}[0m"
    }
}
