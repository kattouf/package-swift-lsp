@testable import PackageSwiftLSPLibrary
import Testing

struct GitRefsLabelsExtractorTests {
    @Test(
        arguments: [
            (
                stdout:
                """
                8b5d5fe233dac491af03b41390fafbe8544ccc6c	refs/heads/command-aliases
                7931aba103bf6d36bf56c3d741c894e203f3e4a7	refs/heads/main
                7931aba103bf6d36bf56c3d741c894e203f3e4a7	refs/heads/feature/jepa
                """,
                expectedOutput:
                [
                    "command-aliases",
                    "main",
                    "feature/jepa",
                ]
            ),
            (
                stdout:
                """
                8b5d5fe233dac491af03b41390fafbe8544ccc6c	refs/tags/0.1.0
                7931aba103bf6d36bf56c3d741c894e203f3e4a7	refs/tags/0.2.0
                7931aba103bf6d36bf56c3d741c894e203f3e4a7	refs/tags/pre-release/0.2.0
                """,
                expectedOutput:
                [
                    "0.1.0",
                    "0.2.0",
                    "pre-release/0.2.0",
                ]
            ),
        ]
    )
    func testExtractLabels(gitLsRemoteStdout: String, extractedOutput: [String]) {
        #expect(GitRefsLabelsExtractor.extractLabels(lsRemoteStdout: gitLsRemoteStdout).sorted() == extractedOutput.sorted())
    }
}
