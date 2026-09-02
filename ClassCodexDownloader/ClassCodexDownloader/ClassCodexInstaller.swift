import Foundation

final class HostAllowlistRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest
    ) async -> URLRequest? {
        guard let url = request.url, CDN.isAllowed(url) else {
            return nil
        }
        return request
    }
}

final class ClassCodexInstaller {
    private let session: URLSession
    private let files: AddonFileStore
    private let sessionDelegate: NSObject?

    convenience init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = CDN.requestTimeout
        configuration.timeoutIntervalForResource = CDN.requestTimeout
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        let delegate = HostAllowlistRedirectDelegate()
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        self.init(session: session, files: LocalAddonFileStore(), sessionDelegate: delegate)
    }

    init(session: URLSession, files: AddonFileStore, sessionDelegate: NSObject? = nil) {
        self.session = session
        self.files = files
        self.sessionDelegate = sessionDelegate
    }

    deinit {
        session.finishTasksAndInvalidate()
        _ = sessionDelegate
    }

    func install(
        addonsFolder: URL,
        dryRun: Bool,
        progress: @escaping @Sendable (String) -> Void
    ) async throws -> InstallResult {
        var isDirectory: ObjCBool = false
        let folderPath = addonsFolder.path
        guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw InstallerError.addonsFolderNotFound(folderPath)
        }

        progress("Downloading configuration: \(CDN.configURL.absoluteString)")
        let config = try await downloadConfig()
        try validate(config)

        guard let manifestURL = URL(string: config.manifestUrl) else {
            throw InstallerError.disallowedURL(config.manifestUrl)
        }
        try CDN.requireAllowed(manifestURL)

        progress("Downloading manifest, build: \(config.buildId)")
        let manifest = try await downloadManifest(from: manifestURL, expectedSHA256: config.manifestSha256)
        try validate(manifest, expectedBuildId: config.buildId)

        var downloaded = 0
        var skipped = 0

        for entry in manifest.files {
            try Task.checkCancellation()
            try validate(entry)
            let target = try PathSafety.resolvedFileURL(relative: entry.path, under: addonsFolder)

            if isUpToDate(entry, at: target) {
                skipped += 1
                progress("OK       \(entry.path)")
                continue
            }

            progress("DOWNLOAD \(entry.path)")
            if dryRun {
                continue
            }

            let fileURL = try CDN.fileURL(buildId: config.buildId, relativePath: entry.path)
            let data = try await downloadData(from: fileURL, maxBytes: CDN.fileMaxBytes)
            guard data.count == entry.size, FileSHA256.hexDigest(of: data) == entry.sha256.lowercased() else {
                throw InstallerError.fileVerificationFailed(entry.path)
            }

            try files.writeAtomically(data, to: target)
            do {
                let writtenSize = try files.size(of: target)
                let writtenHash = try files.sha256(of: target)
                guard writtenSize == entry.size, writtenHash == entry.sha256.lowercased() else {
                    throw InstallerError.fileVerificationFailed(entry.path)
                }
            } catch {
                try? files.removeItem(at: target)
                if let installerError = error as? InstallerError {
                    throw installerError
                }
                throw InstallerError.fileVerificationFailed(entry.path)
            }
            downloaded += 1
        }

        let result = InstallResult(buildId: config.buildId, downloaded: downloaded, skipped: skipped)
        progress("")
        progress(result.summary)
        progress("Addon folder: \(addonsFolder.appendingPathComponent("ClassCodex", isDirectory: true).path)")
        return result
    }

    private func downloadConfig() async throws -> ChannelConfig {
        let data = try await downloadData(from: CDN.configURL, maxBytes: CDN.configMaxBytes)
        return try JSONDecoder().decode(ChannelConfig.self, from: data)
    }

    private func downloadManifest(from url: URL, expectedSHA256: String) async throws -> Manifest {
        let data = try await downloadData(from: url, maxBytes: CDN.manifestMaxBytes)
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("classcodex-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let manifestPath = tempDir.appendingPathComponent("manifest.json", isDirectory: false)
        try data.write(to: manifestPath, options: .atomic)
        let digest = try FileSHA256.hexDigest(ofFile: manifestPath)
        guard digest == expectedSHA256.lowercased() else {
            throw InstallerError.manifestHashMismatch
        }
        return try JSONDecoder().decode(Manifest.self, from: data)
    }

    private func downloadData(from url: URL, maxBytes: Int) async throws -> Data {
        try CDN.requireAllowed(url)
        var request = URLRequest(url: url, timeoutInterval: CDN.requestTimeout)
        request.setValue(CDN.userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw InstallerError.httpFailure(-1)
        }
        guard http.statusCode == 200 else {
            throw InstallerError.httpFailure(http.statusCode)
        }
        guard data.count <= maxBytes else {
            throw InstallerError.payloadTooLarge
        }
        return data
    }

    private func validate(_ config: ChannelConfig) throws {
        guard config.gameVersionId == CDN.gameVersionId, config.channel == CDN.releaseChannel else {
            throw InstallerError.configMismatch
        }
        guard !config.buildId.isEmpty, !config.manifestUrl.isEmpty, !config.manifestSha256.isEmpty else {
            throw InstallerError.incompleteConfig
        }
    }

    private func validate(_ manifest: Manifest, expectedBuildId: String) throws {
        guard manifest.addon.id == CDN.addonId,
              manifest.addon.name == CDN.addonName,
              manifest.addon.gameVersionId == CDN.gameVersionId else {
            throw InstallerError.unexpectedAddon
        }
        guard manifest.build.id == expectedBuildId else {
            throw InstallerError.buildIdMismatch
        }
        guard !manifest.files.isEmpty else {
            throw InstallerError.emptyManifest
        }
    }

    private func validate(_ entry: FileEntry) throws {
        guard !entry.sha256.isEmpty else {
            throw InstallerError.invalidEntry(entry.path)
        }
        guard entry.size >= 0 else {
            throw InstallerError.invalidEntry(entry.path)
        }
        guard entry.size <= CDN.fileMaxBytes else {
            throw InstallerError.fileTooLarge(entry.path)
        }
    }

    private func isUpToDate(_ entry: FileEntry, at url: URL) -> Bool {
        guard files.isRegularFile(at: url) else { return false }
        guard let size = try? files.size(of: url), size == entry.size else { return false }
        guard let digest = try? files.sha256(of: url) else { return false }
        return digest == entry.sha256.lowercased()
    }
}
