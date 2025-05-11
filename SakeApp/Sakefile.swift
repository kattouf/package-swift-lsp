import ArgumentParser
import Foundation
import Sake
import SwiftShell

@main
@CommandGroup
struct Commands: SakeApp {
    public static var configuration: SakeAppConfiguration {
        SakeAppConfiguration(
            commandGroups: [
                TestCommands.self,
                ReleaseCommands.self,
            ]
        )
    }

    public static var lint: Command {
        Command(
            description: "Lint code",
            dependencies: [MiseCommands.ensureSwiftFormatInstalled],
            run: { context in
                try runAndPrint(
                    MiseCommands.miseBin(context),
                    "exec",
                    "--",
                    "swiftformat",
                    swiftformatArgs(for: context),
                    "--lint"
                )
            }
        )
    }

    public static var format: Command {
        Command(
            description: "Format code",
            dependencies: [MiseCommands.ensureSwiftFormatInstalled],
            run: { context in
                try runAndPrint(
                    MiseCommands.miseBin(context),
                    "exec",
                    "--",
                    "swiftformat",
                    swiftformatArgs(for: context)
                )
            }
        )
    }
}

private extension Commands {
    private static func swiftformatArgs(for context: Command.Context) -> [String] {
        [
            "\(context.projectRoot)/Sources",
            "\(context.projectRoot)/SakeApp",
            "\(context.projectRoot)/Tests",
            "\(context.projectRoot)/Package.swift",
        ]
            + (context.environment["GITHUB_ACTIONS"] == "true" ? ["--reporter", "github-actions-log"] : [])
    }
}
