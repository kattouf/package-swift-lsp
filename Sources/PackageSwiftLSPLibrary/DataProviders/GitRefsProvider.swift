import ConcurrencyExtras
import Subprocess

actor GitRefsProvider {
    enum GitError: Error {
        case gitLsRemoteFailure(stdout: String?, stderr: String?)
    }

    enum Refs {
        case tags
        case branches
    }

    private var cache = [String: [String]]()
    private let gitRefsLabelsExtractor: @Sendable (_ lsRemoteStdout: String) -> [String] = GitRefsLabelsExtractor
        .extractLabels(lsRemoteStdout:)
    private init() {}

    static let shared = GitRefsProvider()

    func get(_ refs: Refs, for repositoryURL: String) async throws -> [String] {
        let cacheKey = "\(refs)-\(repositoryURL)"
        if let cachedRefs = cache[cacheKey] {
            return cachedRefs
        }

        let refsArg = switch refs {
        case .tags:
            "--tags"
        case .branches:
            "--heads"
        }

        let result = try await run(
            .name("git"),
            arguments: ["ls-remote", refsArg, repositoryURL],
            output: .string(limit: 512 * 1024),
            error: .string(limit: 512 * 1024)
        )
        guard let stdout = result.standardOutput, result.terminationStatus == .exited(0) else {
            throw GitError.gitLsRemoteFailure(stdout: result.standardOutput, stderr: result.standardError)
        }

        let refs = gitRefsLabelsExtractor(stdout)
        logger.info("Loaded \(refs.count) git refs for \(repositoryURL)")

        cache[cacheKey] = refs
        return refs
    }
}

enum GitRefsLabelsExtractor {
    static func extractLabels(lsRemoteStdout: String) -> [String] {
        let lines = lsRemoteStdout.split(separator: "\n")
        let refs = lines
            .compactMap { line -> String? in
                let parts = line.split(separator: "\t")
                guard parts.count == 2 else {
                    return nil
                }
                let ref = parts[1]

                let refLabel: Substring? = if ref.hasPrefix("refs/tags/") {
                    ref.dropFirst("refs/tags/".count)
                } else if ref.hasPrefix("refs/heads/") {
                    ref.dropFirst("refs/heads/".count)
                } else {
                    nil
                }
                guard let refLabel else {
                    return nil
                }
                if refLabel.hasSuffix("^{}") {
                    return String(refLabel.dropLast(3))
                } else {
                    return String(refLabel)
                }
            }
        return refs
    }
}
