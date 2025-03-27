import ConcurrencyExtras
import Foundation
@testable import PackageSwiftLSPLibrary
import Testing

struct BarrierTests {
    @Test
    func returnsImmediatelyWhenUnlocked() async throws {
        let barrier = Barrier()
        let start = Date()
        try await barrier.waitUntilUnlocked(timeout: .seconds(1))
        let duration = Date().timeIntervalSince(start)
        #expect(duration < 0.2, "Waited longer than expected")
    }

    @Test
    func waitBlocksUntilUnlocked() async throws {
        let barrier = Barrier()
        await barrier.lock()

        let start = Date()
        Task {
            try await Task.sleep(for: .milliseconds(300))
            await barrier.unlock()
        }

        try await barrier.waitUntilUnlocked(timeout: .seconds(1))
        let duration = Date().timeIntervalSince(start)

        #expect(duration >= 0.3, "Waited less than expected")
    }

    @Test
    func waitTimeoutsIfNotUnlocked() async throws {
        let barrier = Barrier()
        await barrier.lock()

        do {
            try await barrier.waitUntilUnlocked(timeout: .milliseconds(100))
            Issue.record("Expected timeout error, but succeeded")
        } catch is BarrierTimeoutError {
            // OK
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func multipleWaitersAreAllResumed() async throws {
        let barrier = Barrier()
        await barrier.lock()

        let results: LockIsolated<[Int]> = .init([])

        async let w1: Void = {
            try await barrier.waitUntilUnlocked(timeout: .seconds(1))
            results.withValue { $0.append(1) }
        }()

        async let w2: Void = {
            try await barrier.waitUntilUnlocked(timeout: .seconds(1))
            results.withValue { $0.append(2) }
        }()

        try await Task.sleep(for: .milliseconds(200))
        await barrier.unlock()

        _ = try await (w1, w2)

        #expect(results.value.sorted() == [1, 2], "Not all continuations resumed: \(results)")
    }
}
