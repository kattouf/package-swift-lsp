import Foundation
@testable import PackageSwiftLSPLibrary
import Testing

struct PackagesRegistryDiskCacheTests {
    private func sut(expirationTime: TimeInterval) -> PackagesRegistryDiskCache {
        let packageListCacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("PackagesRegistryDiskCacheTests")
        try? FileManager.default.createDirectory(at: packageListCacheDirectory, withIntermediateDirectories: true)
        return .defaultDiskCache(storageDirectoryPath: packageListCacheDirectory, expirationTime: expirationTime)
    }

    @Test
    func readWithoutWrite() throws {
        let cache = sut(expirationTime: 0)
        let data = try cache.readPackagesList()
        #expect(data == nil)
    }

    @Test
    func writeAndReadBeforeExpiration() throws {
        let testJSONData = try #require("[\"test\"]".data(using: .utf8))
        let cache = sut(expirationTime: 1)
        try cache.writePackagesList(testJSONData)
        let (packagesList, isExpired) = try #require(try cache.readPackagesList())
        #expect(packagesList == ["test"])
        #expect(isExpired == false)
    }

    @Test
    func writeAndReadAfterExpiration() throws {
        let testJSONData = try #require("[\"test\"]".data(using: .utf8))
        let cache = sut(expirationTime: 0)
        try cache.writePackagesList(testJSONData)
        Thread.sleep(forTimeInterval: 1)
        let (packagesList, isExpired) = try #require(try cache.readPackagesList())
        #expect(packagesList == ["test"])
        #expect(isExpired == true)
    }
}
