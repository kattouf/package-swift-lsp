@testable import PackageSwiftLSPLibrary
import Testing

struct FuzzySearchTests {
    @Test
    func emptyQueryReturnsAllCandidates() {
        let candidates = ["a", "b", "c"]
        let query = ""
        let expected = ["a", "b", "c"]

        let result = FuzzySearch(query: query, candidates: candidates)()

        #expect(result == expected, "Expected all candidates to be returned, but got \(result)")
    }

    @Test
    func singleCharacterQueryReturnsMatchingCandidates() {
        let candidates = ["apple", "banana", "cherry"]
        let query = "a"
        let expected = ["apple", "banana"]

        let result = FuzzySearch(query: query, candidates: candidates)()

        #expect(result == expected, "Expected \(expected) but got \(result)")
    }

    @Test
    func multiCharacterQueryReturnsMatchingCandidates() {
        let candidates = ["apple", "banana", "cherry"]
        let query = "bn"
        let expected = ["banana"]

        let result = FuzzySearch(query: query, candidates: candidates)()

        #expect(result == expected, "Expected \(expected) but got \(result)")
    }
}
