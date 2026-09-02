import Foundation

enum CDN {
    static let host = "wow-class-codex.s3.us-east-1.amazonaws.com"
    static let scheme = "https"
    static let gameVersionId = "retail"
    static let releaseChannel = "production"
    static let requestTimeout: TimeInterval = 60
    static let configMaxBytes = 2 * 1024 * 1024
    static let manifestMaxBytes = 10 * 1024 * 1024
    static let fileMaxBytes = 64 * 1024 * 1024
    static let userAgent = "ClassCodex-installer/1.0"
    static let addonId = "class-codex"
    static let addonName = "ClassCodex"

    static var baseURL: URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        return components.url!
    }

    static var configURL: URL {
        baseURL
            .appendingPathComponent("channels")
            .appendingPathComponent(gameVersionId)
            .appendingPathComponent(releaseChannel)
            .appendingPathComponent("config.json")
    }

    static func isAllowed(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == scheme else { return false }
        guard url.host?.lowercased() == host else { return false }
        if let port = url.port, port != 443 { return false }
        if url.user != nil || url.password != nil { return false }
        return true
    }

    static func requireAllowed(_ url: URL) throws {
        guard isAllowed(url) else {
            throw InstallerError.disallowedURL(url.absoluteString)
        }
    }

    static func fileURL(buildId: String, relativePath: String) throws -> URL {
        let encodedBuild = percentEncode(buildId)
        let encodedPath = relativePath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { percentEncode(String($0)) }
            .joined(separator: "/")
        let string = "\(scheme)://\(host)/builds/\(gameVersionId)/\(encodedBuild)/\(encodedPath)"
        guard let url = URL(string: string) else {
            throw InstallerError.disallowedURL(string)
        }
        try requireAllowed(url)
        return url
    }

    private static func percentEncode(_ part: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return part.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }
}
