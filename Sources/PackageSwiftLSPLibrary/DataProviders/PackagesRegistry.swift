import ConcurrencyExtras
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

struct GithubPackage: Sendable, Equatable {
    let url: String
    let user: String
    let repository: String

    init?(url: String) {
        guard let urlComponents = URLComponents(string: url) else {
            return nil
        }

        guard let host = urlComponents.host, host == "github.com" else {
            return nil
        }

        let path = urlComponents.path.split(separator: "/").map(String.init)
        guard path.count >= 2 else {
            return nil
        }

        self.url = url
        self.user = path[0]
        self.repository = String(path[1].split(separator: ".")[0])
    }
}

// https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/refs/heads/main/packages.json
actor PackagesRegistry {
    private var packages: [String: GithubPackage]?
    private let diskCache: PackagesRegistryDiskCache
    private let downloader: PackagesRegistryDownloader

    init(
        downloader: PackagesRegistryDownloader,
        diskCache: PackagesRegistryDiskCache
    ) {
        self.downloader = downloader
        self.diskCache = diskCache
    }

    private static func defaultRegistry() -> PackagesRegistry {
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let packageListCacheDirectory = cachesDirectory.appendingPathComponent("PackageList")
        if !fileManager.fileExists(atPath: packageListCacheDirectory.path) {
            try? fileManager.createDirectory(at: packageListCacheDirectory, withIntermediateDirectories: true)
        }

        return .init(
            downloader: .defaultDownloader(),
            diskCache: .defaultDiskCache(storageDirectoryPath: packageListCacheDirectory)
        )
    }

    static let shared = PackagesRegistry.defaultRegistry()

    func shouldLoadPackages() -> Bool {
        packages == nil
    }

    func loadPackagesIfNeeded() async throws {
        guard packages == nil else {
            return
        }

        let cachedPackagesList = try diskCache.readPackagesList()

        let urls: [String]
        if let cachedPackagesList {
            if !cachedPackagesList.isExpired {
                urls = cachedPackagesList.packagesList
            } else {
                do {
                    urls = try await downloadAndCachePackagesList()
                } catch {
                    logger.error("Failed to download packages list: \(error). Returning expired cached list.")
                    urls = cachedPackagesList.packagesList
                }
            }
        } else {
            urls = try await downloadAndCachePackagesList()
        }
        let packagesList = parsePackagesList(urls)
        self.packages = Dictionary(uniqueKeysWithValues: packagesList.map { ($0.url, $0) })
        logger.info("Loaded packages count: \(packagesList.count)")
    }

    func getPackages() -> [GithubPackage] {
        if let values = packages?.values {
            Array(values)
        } else {
            []
        }
    }

    func package(for url: String) -> GithubPackage? {
        packages?[url]
    }

    private func downloadAndCachePackagesList() async throws -> [String] {
        let (data, decodedList) = try await downloader.downloadPackagesList()
        try diskCache.writePackagesList(data)
        return decodedList
    }

    private func parsePackagesList(_ urls: [String]) -> [GithubPackage] {
        urls.compactMap(GithubPackage.init(url:))
    }
}

// MARK: - Downloader

struct PackagesRegistryDownloader: Sendable {
    let downloadPackagesList: @Sendable () async throws -> (data: Data, decodedList: [String])

    static func defaultDownloader() -> PackagesRegistryDownloader {
        .init {
            logger.debug("Downloading packages list...")
            let url = URL(string: "https://raw.githubusercontent.com/SwiftPackageIndex/PackageList/refs/heads/main/packages.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedList = try JSONDecoder().decode([String].self, from: data)
            return (data, decodedList)
        }
    }
}

// MARK: - Cache

struct PackagesRegistryDiskCache: Sendable {
    let writePackagesList: @Sendable (Data) throws -> Void
    let readPackagesList: @Sendable () throws -> (packagesList: [String], isExpired: Bool)?

    static func defaultDiskCache(
        storageDirectoryPath: URL,
        expirationTime: TimeInterval = 3 * 60 * 60 // 3 hours
    ) -> PackagesRegistryDiskCache {
        let packagesListPath = storageDirectoryPath.appendingPathComponent("packages.json")

        @Sendable
        func write(_ packagesListJSON: Data) throws {
            if !FileManager.default.fileExists(atPath: storageDirectoryPath.path) {
                try FileManager.default.createDirectory(at: storageDirectoryPath, withIntermediateDirectories: true)
            }
            logger.debug("Caching packages list to \(packagesListPath.path)")
            try packagesListJSON.write(to: packagesListPath)
        }

        @Sendable
        func read() throws -> (packagesList: [String], isExpired: Bool)? {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: packagesListPath.path) {
                logger.debug("Loading packages list from cache...")
                let attributes = try fileManager.attributesOfItem(atPath: packagesListPath.path)
                let isExpired: Bool
                if let modificationDate = attributes[.modificationDate] as? Date {
                    let threeHoursAgo = Date().addingTimeInterval(-expirationTime)
                    isExpired = modificationDate <= threeHoursAgo
                } else {
                    isExpired = false
                }
                let data = try Data(contentsOf: packagesListPath)
                return try (packagesList: JSONDecoder().decode([String].self, from: data), isExpired: isExpired)
            }
            return nil
        }
        return .init(
            writePackagesList: write,
            readPackagesList: read
        )
    }
}
