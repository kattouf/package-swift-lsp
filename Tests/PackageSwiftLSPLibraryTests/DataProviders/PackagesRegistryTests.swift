import Foundation
@testable import PackageSwiftLSPLibrary
import Testing

struct PackagesRegistryTests {
    @Test
    func loadPackagesIfCacheIsEmpty() async throws {
        let apiData = ["https://github.com/test-api-user/test-api-repo"]
        let sut = PackagesRegistry(
            downloader: .init(
                downloadPackagesList: {
                    try (
                        JSONEncoder().encode(apiData), apiData
                    )
                }
            ),
            diskCache: .init(
                writePackagesList: { _ in },
                readPackagesList: {
                    nil
                }
            )
        )

        try await sut.loadPackagesIfNeeded()
        let packages = await sut.getPackages()
        #expect(packages == apiData.compactMap { GithubPackage(url: $0) })
    }

    @Test
    func loadPackagesIfCacheIsNotExpired() async throws {
        let storageData = ["https://github.com/test-storage-user/test-storage-repo"]
        let sut = PackagesRegistry(
            downloader: .init(
                downloadPackagesList: {
                    Issue.record("Should not be called")
                    return (Data(), [])
                }
            ),
            diskCache: .init(
                writePackagesList: { _ in Issue.record("Should not be called") },
                readPackagesList: {
                    (storageData, false)
                }
            )
        )

        try await sut.loadPackagesIfNeeded()
        let packages = await sut.getPackages()
        #expect(packages == storageData.compactMap { GithubPackage(url: $0) })
    }

    @Test
    func loadPackagesIfCacheIsExpiredAndAPIWorksWell() async throws {
        let apiData = ["https://github.com/test-api-user/test-api-repo"]
        let storageData = ["https://github.com/test-storage-user/test-storage-repo"]
        let sut = PackagesRegistry(
            downloader: .init(
                downloadPackagesList: {
                    try (
                        JSONEncoder().encode(apiData), apiData
                    )
                }
            ),
            diskCache: .init(
                writePackagesList: { _ in },
                readPackagesList: {
                    (storageData, true)
                }
            )
        )

        try await sut.loadPackagesIfNeeded()
        let packages = await sut.getPackages()
        #expect(packages == apiData.compactMap { GithubPackage(url: $0) })
    }

    @Test
    func loadPackagesIfCacheIsExpiredAndAPIBroken() async throws {
        let storageData = ["https://github.com/test-storage-user/test-storage-repo"]
        let sut = PackagesRegistry(
            downloader: .init(
                downloadPackagesList: {
                    throw NSError(domain: "API Error", code: 1, userInfo: nil)
                }
            ),
            diskCache: .init(
                writePackagesList: { _ in Issue.record("Should not be called") },
                readPackagesList: {
                    (storageData, true)
                }
            )
        )

        try await sut.loadPackagesIfNeeded()
        let packages = await sut.getPackages()
        #expect(packages == storageData.compactMap { GithubPackage(url: $0) })
    }
}
