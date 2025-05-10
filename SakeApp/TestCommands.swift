import ArgumentParser
import Sake
import SakeSwiftShell
import SwiftShell

@CommandGroup
struct TestCommands {
    public static var test: Command {
        Command(
            description: "Run tests with beautified logs",
            dependencies: [MiseCommands.ensureXcbeautifyInstalled],
            run: { context in
                let isGithubActions = context.environment["GITHUB_ACTIONS"] == "true"
                let xcbeautifyRenderer = isGithubActions ? "github-actions" : "terminal"
                try interruptableRunAndPrint(
                    bash: "set -o pipefail && swift test 2>&1 | \(MiseCommands.miseBin(context)) exec -- xcbeautify --disable-logging --renderer \(xcbeautifyRenderer)",
                    interruptionHandler: context.interruptionHandler
                )
            }
        )
    }
}
