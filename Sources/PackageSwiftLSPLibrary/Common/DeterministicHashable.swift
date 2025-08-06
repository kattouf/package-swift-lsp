import Crypto
import Foundation

protocol DeterministicHashable {
    var deterministicHashValue: String { get }
}

extension Array: DeterministicHashable where Element: DeterministicHashable {
    var deterministicHashValue: String {
        let hash = map(\.deterministicHashValue).sorted().joined()
        return SHA256.hash(data: Data(hash.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension Optional: DeterministicHashable where Wrapped: DeterministicHashable {
    var deterministicHashValue: String {
        switch self {
        case .none:
            "\(Wrapped.self).none"
        case let .some(value):
            value.deterministicHashValue
        }
    }
}

extension String: DeterministicHashable {
    var deterministicHashValue: String {
        SHA256.hash(data: Data(utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension Int: DeterministicHashable {
    var deterministicHashValue: String {
        String(self)
    }
}
