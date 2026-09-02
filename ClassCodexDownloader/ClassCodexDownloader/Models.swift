import Foundation

struct ChannelConfig: Decodable, Equatable {
    let gameVersionId: String
    let channel: String
    let buildId: String
    let manifestUrl: String
    let manifestSha256: String
}

struct Manifest: Decodable, Equatable {
    struct Addon: Decodable, Equatable {
        let id: String
        let name: String
        let gameVersionId: String
    }

    struct Build: Decodable, Equatable {
        let id: String
    }

    let addon: Addon
    let build: Build
    let files: [FileEntry]
}

struct FileEntry: Decodable, Equatable {
    let path: String
    let size: Int
    let sha256: String
}

struct InstallResult: Equatable {
    let buildId: String
    let downloaded: Int
    let skipped: Int

    var summary: String {
        "Done. Build: \(buildId); downloaded: \(downloaded); already up to date: \(skipped)."
    }
}

enum InstallerError: Error, Equatable, LocalizedError {
    case addonsFolderNotFound(String)
    case configMismatch
    case incompleteConfig
    case disallowedURL(String)
    case payloadTooLarge
    case manifestHashMismatch
    case unexpectedAddon
    case buildIdMismatch
    case emptyManifest
    case unsafePath(String)
    case invalidEntry(String)
    case fileTooLarge(String)
    case fileVerificationFailed(String)
    case httpFailure(Int)

    var errorDescription: String? {
        switch self {
        case .addonsFolderNotFound(let path):
            return "AddOns folder not found: \(path)"
        case .configMismatch:
            return "The received configuration does not match the configured game version/channel."
        case .incompleteConfig:
            return "Incomplete channel configuration."
        case .disallowedURL(let url):
            return "Download URL is not on the ClassCodex CDN: \(url)"
        case .payloadTooLarge:
            return "Downloaded payload exceeded the size limit."
        case .manifestHashMismatch:
            return "Manifest SHA-256 verification failed."
        case .unexpectedAddon:
            return "The manifest does not belong to the expected ClassCodex addon."
        case .buildIdMismatch:
            return "The build ID in the configuration does not match the build ID in the manifest."
        case .emptyManifest:
            return "The manifest does not contain any files."
        case .unsafePath(let path):
            return "Unsafe manifest path: \(path)"
        case .invalidEntry(let path):
            return "Invalid manifest entry: \(path)"
        case .fileTooLarge(let path):
            return "Manifest file exceeds the size limit: \(path)"
        case .fileVerificationFailed(let path):
            return "Downloaded file verification failed: \(path)"
        case .httpFailure(let status):
            return "Download failed with HTTP status \(status)."
        }
    }
}
