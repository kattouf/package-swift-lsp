import Foundation
import Sake
import SakeSwiftShell
import SwiftShell

@CommandGroup
struct MiseCommands {
    static let miseVersion: String = "v2025.4.1"

    static func miseBin(_ context: Command.Context) throws -> String {
        let installPath = "\(context.projectRoot)/.mise/\(miseVersion)/mise"
        if FileManager.default.fileExists(atPath: installPath) {
            return installPath
        }

        print("Installing mise at \(installPath)".ansiBlue)
        try interruptableRunAndPrint(
            bash: "curl https://mise.run | MISE_VERSION=\(miseVersion) MISE_INSTALL_PATH=\"\(installPath)\" sh",
            interruptionHandler: context.interruptionHandler
        )
        try runAndPrint("\(installPath)", "trust", context.projectRoot)
        return installPath
    }

    static var ensureSwiftFormatInstalled: Command {
        Command(
            description: "Ensure swiftformat is installed",
            skipIf: { context in
                try run(miseBin(context), "which", "swiftformat").succeeded
            },
            run: { context in
                print("Installing swiftformat".ansiBlue)
                try interruptableRunAndPrint(
                    miseBin(context), "install", "swiftformat",
                    interruptionHandler: context.interruptionHandler
                )
            }
        )
    }

    static var ensureXcbeautifyInstalled: Command {
        Command(
            description: "Ensure xcbeautify is installed",
            skipIf: { context in
                try run(miseBin(context), "which", "xcbeautify").succeeded
            },
            run: { context in
                print("Installing xcbeautify".ansiBlue)
                try interruptableRunAndPrint(
                    miseBin(context), "install", "xcbeautify",
                    interruptionHandler: context.interruptionHandler
                )
            }
        )
    }

    static var ensureGhInstalled: Command {
        Command(
            description: "Ensure gh is installed",
            skipIf: { context in
                try run(miseBin(context), "which", "gh").succeeded
            },
            run: { context in
                print("Installing gh".ansiBlue)
                try interruptableRunAndPrint(
                    miseBin(context), "install", "gh",
                    interruptionHandler: context.interruptionHandler
                )
            }
        )
    }

    static var ensureGitCliffInstalled: Command {
        Command(
            description: "Ensure git-cliff is installed",
            skipIf: { context in
                try run(miseBin(context), "which", "git-cliff").succeeded
            },
            run: { context in
                print("Installing git-cliff".ansiBlue)
                try interruptableRunAndPrint(
                    miseBin(context), "install", "git-cliff",
                    interruptionHandler: context.interruptionHandler
                )
            }
        )
    }
}
