@testable import PackageSwiftLSPLibrary
import Testing

struct SemverTests {
    @Test(arguments: zip(["0.0.1", "0.2.1", "v3.2.1", "jepa"], [Semver(major: 0, minor: 0, patch: 1),
                                                                Semver(major: 0, minor: 2, patch: 1),
                                                                Semver(major: 3, minor: 2, patch: 1),
                                                                nil]))
    func semverTnitializationByString(string: String, expectedSemver: Semver?) {
        let semver = Semver(string: string)
        #expect(semver == expectedSemver)
    }

    @Test
    func semverComparison() {
        let semvers = [
            Semver(major: 3, minor: 2, patch: 2),
            Semver(major: 0, minor: 0, patch: 1),
            Semver(major: 3, minor: 2, patch: 1),
            Semver(major: 0, minor: 2, patch: 1),
        ]
        let expectedSortedSemvers = [
            Semver(major: 0, minor: 0, patch: 1),
            Semver(major: 0, minor: 2, patch: 1),
            Semver(major: 3, minor: 2, patch: 1),
            Semver(major: 3, minor: 2, patch: 2),
        ]
        #expect(semvers.sorted(by: Semver.areInIncreasingOrder(lhs:rhs:)) == expectedSortedSemvers)
    }
}
