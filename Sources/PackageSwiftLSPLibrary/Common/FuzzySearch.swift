import Foundation

struct FuzzySearch<T> {
    struct MatchResult {
        let candidate: T
        let score: Int
    }

    let query: String
    let candidates: [T]
    let searchBy: (T) -> String

    init(query: String, candidates: [T], searchBy: @escaping (T) -> String) {
        self.query = query
        self.candidates = candidates
        self.searchBy = searchBy
    }

    func callAsFunction() -> [T] {
        guard !query.isEmpty else {
            return candidates
        }
        return search(query: query, in: candidates, searchBy: searchBy)
    }

    private func search(query: String, in candidates: [T], searchBy: (T) -> String) -> [T] {
        candidates
            .compactMap { candidate -> MatchResult? in
                let searchString = searchBy(candidate)
                return if let score = fuzzyScore(needle: query, haystack: searchString) {
                    MatchResult(candidate: candidate, score: score)
                } else {
                    nil
                }
            }
            .sorted { $0.score < $1.score }
            .map { $0.candidate }
    }
}

private func fuzzyScore(needle: String, haystack: String) -> Int? {
    guard !needle.isEmpty else {
        return 0
    }

    var score = 0
    var lastMatchIndex: String.Index?
    var haystackIndex = haystack.startIndex
    var needleIndex = needle.startIndex

    while haystackIndex < haystack.endIndex, needleIndex < needle.endIndex {
        if haystack[haystackIndex].lowercased() == needle[needleIndex].lowercased() {
            if let last = lastMatchIndex {
                score += haystack.distance(from: last, to: haystackIndex) // difference between matches
            } else {
                score += haystack.distance(from: haystack.startIndex, to: haystackIndex) * 2 // bonus for early match
            }

            lastMatchIndex = haystackIndex
            needleIndex = needle.index(after: needleIndex)
        }

        haystackIndex = haystack.index(after: haystackIndex)
    }

    if needleIndex == needle.endIndex {
        return score
    } else {
        return nil
    }
}

extension FuzzySearch where T == String {
    init(query: String, candidates: [String]) {
        self.query = query
        self.candidates = candidates
        self.searchBy = { $0 }
    }
}
