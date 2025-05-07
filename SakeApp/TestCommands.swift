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
                try interruptableRunAndPrint(
                    bash: "swift test | \(MiseCommands.miseBin(context)) exec -- xcbeautify --disable-logging",
                    interruptionHandler: context.interruptionHandler
                )
            }
        )
    }
}
