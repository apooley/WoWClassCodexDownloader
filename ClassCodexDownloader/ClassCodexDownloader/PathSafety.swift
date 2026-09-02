import Foundation

enum PathSafety {
    static func resolvedFileURL(relative: String, under addonsFolder: URL) throws -> URL {
        guard relative.hasPrefix("ClassCodex/") else {
            throw InstallerError.unsafePath(relative)
        }
        guard !relative.contains("\\"), !relative.contains("\0") else {
            throw InstallerError.unsafePath(relative)
        }

        let parts = relative.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !parts.contains(where: { $0.isEmpty || $0 == ".." }) else {
            throw InstallerError.unsafePath(relative)
        }

        let addons = addonsFolder.standardizedFileURL
        var resolved = addons
        for part in parts {
            resolved.appendPathComponent(part, isDirectory: false)
        }
        resolved = resolved.standardizedFileURL

        let addonsPath = addons.path
        let prefix = addonsPath.hasSuffix("/") ? addonsPath : addonsPath + "/"
        let resolvedPath = resolved.path
        guard resolvedPath.hasPrefix(prefix), resolvedPath != addonsPath else {
            throw InstallerError.unsafePath(relative)
        }
        return resolved
    }
}
