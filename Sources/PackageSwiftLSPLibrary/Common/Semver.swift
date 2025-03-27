struct Semver: Equatable {
    let stringValue: String
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.stringValue = "\(major).\(minor).\(patch)"
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(string: String) {
        let versionString = string.hasPrefix("v") ? String(string.dropFirst()) : string
        let components = versionString.split(separator: ".")

        guard components.count == 3 else {
            return nil
        }
        guard let majorVersion = Int(components[0]),
              let minorVersion = Int(components[1]),
              let patchVersion = Int(components[2])
        else {
            return nil
        }

        guard majorVersion >= 0, minorVersion >= 0, patchVersion >= 0 else {
            return nil
        }

        self.stringValue = string
        self.major = majorVersion
        self.minor = minorVersion
        self.patch = patchVersion
    }

    static func areInIncreasingOrder(lhs: Semver, rhs: Semver) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }

        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }

        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }

        return false // Versions are equal
    }

    static func == (lhs: Semver, rhs: Semver) -> Bool {
        lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}
