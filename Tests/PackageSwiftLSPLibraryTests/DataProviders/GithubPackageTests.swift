@testable import PackageSwiftLSPLibrary
import Testing

struct GithubPackageTests {
    @Test(arguments: [
        (url: "https://github.com/kattouf/Sake", user: "kattouf", repository: "Sake"),
        (url: "https://github.com/kattouf/Sake.git", user: "kattouf", repository: "Sake"),
    ])
    func testGithubPackageSuccessfullInitialization(url: String, user: String, repository: String) throws {
        let package = try #require(GithubPackage(url: url))
        #expect(package.url == url)
        #expect(package.user == user)
        #expect(package.repository == repository)
    }

    @Test(arguments: [
        "https://githib.com/kattouf/foo/bar/Sake",
        "https://githib.com/kattouf/Sake",
        "https//://github.com/kattouf/Sake.git",
        "github.com/kattouf/Sake",
    ])
    func testGithubPackageFailedInitialization(url: String) throws {
        let package = GithubPackage(url: url)
        #expect(package == nil)
    }
}
