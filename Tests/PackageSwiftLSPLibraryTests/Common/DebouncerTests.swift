import ConcurrencyExtras
import Foundation
@testable import PackageSwiftLSPLibrary
import Testing

struct DebouncerTests {
    @Test
    func executesAfterDelay() async throws {
        let debouncer = Debouncer()
        let result: LockIsolated<[Int]> = .init([])

        await debouncer.run(delay: .milliseconds(200)) {
            result.withValue { $0.append(1) }
        }

        try await Task.sleep(for: .milliseconds(220))
        #expect(result.value == [1], "Expected 1, but got \(result.value.count)")
    }

    @Test
    func doesNotExecuteIfTriggeredBeforeDelay() async throws {
        let debouncer = Debouncer()
        let result: LockIsolated<[Int]> = .init([])

        await debouncer.run(delay: .milliseconds(200)) {
            result.withValue { $0.append(1) }
        }

        try await Task.sleep(for: .milliseconds(50))
        await debouncer.run(delay: .milliseconds(200)) {
            result.withValue { $0.append(2) }
        }

        try await Task.sleep(for: .milliseconds(50))
        await debouncer.run(delay: .milliseconds(100)) {
            result.withValue { $0.append(1337) }
        }

        try await Task.sleep(for: .milliseconds(200))
        #expect(result.value == [1337], "Expected only last run, but got \(result.value.count)")
    }
}
