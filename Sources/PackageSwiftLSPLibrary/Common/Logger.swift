import Logging

package nonisolated(unsafe) var logger = Logger(label: "com.kattouf.package-swift-lsp")

package func setupLogger() {
    logger.logLevel = .info
    LoggingSystem.bootstrap(StreamLogHandler.standardError)
}
