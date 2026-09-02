import XCTest
@testable import ClassCodexDownloader

final class RecordingFileStore: AddonFileStore {
    private(set) var files: [String: Data] = [:]
    private(set) var writeCount = 0
    private(set) var removeCount = 0
    var sha256AfterWrite: String?

    func seed(_ data: Data, at url: URL) {
        files[url.path] = data
    }

    func isRegularFile(at url: URL) -> Bool {
        files[url.path] != nil
    }

    func size(of url: URL) throws -> Int {
        guard let data = files[url.path] else {
            throw CocoaError(.fileNoSuchFile)
        }
        return data.count
    }

    func sha256(of url: URL) throws -> String {
        if let sha256AfterWrite, files[url.path] != nil, writeCount > 0 {
            return sha256AfterWrite
        }
        guard let data = files[url.path] else {
            throw CocoaError(.fileNoSuchFile)
        }
        return FileSHA256.hexDigest(of: data)
    }

    func writeAtomically(_ data: Data, to url: URL) throws {
        writeCount += 1
        files[url.path] = data
    }

    func removeItem(at url: URL) throws {
        removeCount += 1
        files.removeValue(forKey: url.path)
    }
}

final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var _handler: ((URLRequest) throws -> (Int, Data))?
    private static var _requested: [URL] = []

    static var handler: ((URLRequest) throws -> (Int, Data))? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _handler
        }
        set {
            lock.lock()
            _handler = newValue
            lock.unlock()
        }
    }

    static var requested: [URL] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _requested
        }
        set {
            lock.lock()
            _requested = newValue
            lock.unlock()
        }
    }

    static func reset() {
        handler = nil
        requested = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        if let url = request.url {
            Self._requested.append(url)
        }
        let handler = Self._handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        do {
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/octet-stream"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class ClassCodexInstallerTests: XCTestCase {
    private var addonsFolder: URL!
    private var store: RecordingFileStore!

    override func setUpWithError() throws {
        MockURLProtocol.reset()
        store = RecordingFileStore()
        addonsFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("classcodex-addons-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: addonsFolder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        MockURLProtocol.reset()
        try? FileManager.default.removeItem(at: addonsFolder)
    }

    func testSkipsFileWhenLocalHashMatches() async throws {
        let payload = Data("hello".utf8)
        let hash = FileSHA256.hexDigest(of: payload)
        let relative = "ClassCodex/hello.lua"
        let target = try PathSafety.resolvedFileURL(relative: relative, under: addonsFolder)
        store.seed(payload, at: target)
        try stubChannel(files: [FileEntry(path: relative, size: payload.count, sha256: hash)])

        let result = try await makeInstaller().install(addonsFolder: addonsFolder, dryRun: false) { _ in }

        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.downloaded, 0)
        XCTAssertEqual(store.writeCount, 0)
        XCTAssertFalse(MockURLProtocol.requested.contains { $0.path.contains("/builds/") })
    }

    func testDownloadsAndVerifiesFile() async throws {
        let payload = Data("new-content".utf8)
        let hash = FileSHA256.hexDigest(of: payload)
        let relative = "ClassCodex/hello.lua"
        try stubChannel(
            files: [FileEntry(path: relative, size: payload.count, sha256: hash)],
            fileBodies: [relative: payload]
        )

        let result = try await makeInstaller().install(addonsFolder: addonsFolder, dryRun: false) { _ in }

        XCTAssertEqual(result.downloaded, 1)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(store.writeCount, 1)
        let target = try PathSafety.resolvedFileURL(relative: relative, under: addonsFolder)
        XCTAssertEqual(store.files[target.path], payload)
    }

    func testFailsClosedOnBadHashWithoutKeepingFile() async throws {
        let expected = Data("expected".utf8)
        let actual = Data("tampered".utf8)
        let relative = "ClassCodex/hello.lua"
        try stubChannel(
            files: [FileEntry(path: relative, size: expected.count, sha256: FileSHA256.hexDigest(of: expected))],
            fileBodies: [relative: actual]
        )

        do {
            _ = try await makeInstaller().install(addonsFolder: addonsFolder, dryRun: false) { _ in }
            XCTFail("Expected verification failure")
        } catch let error as InstallerError {
            XCTAssertEqual(error, .fileVerificationFailed(relative))
        }
        XCTAssertEqual(store.writeCount, 0)
        XCTAssertTrue(store.files.isEmpty)
    }

    func testRemovesFileWhenStoredHashDoesNotMatch() async throws {
        let payload = Data("payload".utf8)
        let relative = "ClassCodex/hello.lua"
        store.sha256AfterWrite = String(repeating: "ab", count: 32)
        try stubChannel(
            files: [FileEntry(path: relative, size: payload.count, sha256: FileSHA256.hexDigest(of: payload))],
            fileBodies: [relative: payload]
        )

        do {
            _ = try await makeInstaller().install(addonsFolder: addonsFolder, dryRun: false) { _ in }
            XCTFail("Expected verification failure")
        } catch let error as InstallerError {
            XCTAssertEqual(error, .fileVerificationFailed(relative))
        }
        XCTAssertEqual(store.writeCount, 1)
        XCTAssertEqual(store.removeCount, 1)
        XCTAssertTrue(store.files.isEmpty)
    }

    func testDryRunDoesNotWriteOrFetchAddonFiles() async throws {
        let payload = Data("hello".utf8)
        let relative = "ClassCodex/hello.lua"
        try stubChannel(
            files: [FileEntry(path: relative, size: payload.count, sha256: FileSHA256.hexDigest(of: payload))],
            fileBodies: [relative: payload]
        )

        let result = try await makeInstaller().install(addonsFolder: addonsFolder, dryRun: true) { _ in }

        XCTAssertEqual(result.downloaded, 0)
        XCTAssertEqual(result.skipped, 0)
        XCTAssertEqual(store.writeCount, 0)
        XCTAssertEqual(store.removeCount, 0)
        XCTAssertFalse(MockURLProtocol.requested.contains { $0.path.contains("/builds/") })
    }

    func testRejectsUnsafeManifestPath() async throws {
        try stubChannel(files: [FileEntry(path: "ClassCodex/../Evil.lua", size: 1, sha256: "ab")])

        do {
            _ = try await makeInstaller().install(addonsFolder: addonsFolder, dryRun: false) { _ in }
            XCTFail("Expected unsafe path")
        } catch let error as InstallerError {
            XCTAssertEqual(error, .unsafePath("ClassCodex/../Evil.lua"))
        }
        XCTAssertEqual(store.writeCount, 0)
    }

    func testRejectsOffHostManifestURL() async throws {
        let manifest = try makeManifestData(
            buildId: "build1",
            files: [FileEntry(path: "ClassCodex/a.lua", size: 1, sha256: "ab")]
        )
        stubResponses(
            config: makeConfig(
                buildId: "build1",
                manifestURL: "https://evil.example/manifest.json",
                manifestSHA: FileSHA256.hexDigest(of: manifest)
            ),
            manifest: manifest,
            files: [:]
        )

        do {
            _ = try await makeInstaller().install(addonsFolder: addonsFolder, dryRun: false) { _ in }
            XCTFail("Expected disallowed URL")
        } catch let error as InstallerError {
            guard case .disallowedURL = error else {
                return XCTFail("Wrong error: \(error)")
            }
        }
    }

    func testRejectsConfigMismatch() async throws {
        let manifest = try makeManifestData(
            buildId: "build1",
            files: [FileEntry(path: "ClassCodex/a.lua", size: 1, sha256: "ab")]
        )
        stubResponses(config: try JSONSerialization.data(withJSONObject: jsonObject(
            gameVersionId: "classic",
            channel: "production",
            buildId: "build1",
            manifestURL: "https://wow-class-codex.s3.us-east-1.amazonaws.com/m.json",
            manifestSHA: FileSHA256.hexDigest(of: manifest)
        )), manifest: manifest, files: [:])

        do {
            _ = try await makeInstaller().install(addonsFolder: addonsFolder, dryRun: false) { _ in }
            XCTFail("Expected config mismatch")
        } catch let error as InstallerError {
            XCTAssertEqual(error, .configMismatch)
        }
    }

    func testRejectsManifestHashMismatch() async throws {
        let manifest = try makeManifestData(
            buildId: "build1",
            files: [FileEntry(path: "ClassCodex/a.lua", size: 1, sha256: "ab")]
        )
        stubResponses(
            config: makeConfig(
                buildId: "build1",
                manifestURL: "https://wow-class-codex.s3.us-east-1.amazonaws.com/m.json",
                manifestSHA: String(repeating: "00", count: 32)
            ),
            manifest: manifest,
            files: [:]
        )

        do {
            _ = try await makeInstaller().install(addonsFolder: addonsFolder, dryRun: false) { _ in }
            XCTFail("Expected hash mismatch")
        } catch let error as InstallerError {
            XCTAssertEqual(error, .manifestHashMismatch)
        }
    }

    func testRejectsUnexpectedAddonIdentity() async throws {
        let manifest = """
        {
          "addon": { "id": "other", "name": "Other", "gameVersionId": "retail" },
          "build": { "id": "build1" },
          "files": [{ "path": "ClassCodex/a.lua", "size": 1, "sha256": "ab" }]
        }
        """.data(using: .utf8)!
        stubResponses(
            config: makeConfig(
                buildId: "build1",
                manifestURL: "https://wow-class-codex.s3.us-east-1.amazonaws.com/m.json",
                manifestSHA: FileSHA256.hexDigest(of: manifest)
            ),
            manifest: manifest,
            files: [:]
        )

        do {
            _ = try await makeInstaller().install(addonsFolder: addonsFolder, dryRun: false) { _ in }
            XCTFail("Expected unexpected addon")
        } catch let error as InstallerError {
            XCTAssertEqual(error, .unexpectedAddon)
        }
    }

    private func makeInstaller() -> ClassCodexInstaller {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 5
        let session = URLSession(configuration: configuration)
        return ClassCodexInstaller(session: session, files: store)
    }

    private func stubChannel(files: [FileEntry], fileBodies: [String: Data] = [:]) throws {
        let manifest = try makeManifestData(buildId: "build1", files: files)
        stubResponses(
            config: makeConfig(
                buildId: "build1",
                manifestURL: "https://wow-class-codex.s3.us-east-1.amazonaws.com/m.json",
                manifestSHA: FileSHA256.hexDigest(of: manifest)
            ),
            manifest: manifest,
            files: fileBodies
        )
    }

    private func stubResponses(config: Data, manifest: Data, files: [String: Data]) {
        MockURLProtocol.handler = { request in
            guard let url = request.url else {
                throw URLError(.badURL)
            }
            if url == CDN.configURL {
                return (200, config)
            }
            if url.absoluteString == "https://wow-class-codex.s3.us-east-1.amazonaws.com/m.json" {
                return (200, manifest)
            }
            for (relative, body) in files {
                let expected = try CDN.fileURL(buildId: "build1", relativePath: relative)
                if url == expected {
                    return (200, body)
                }
            }
            return (404, Data())
        }
    }

    private func makeConfig(buildId: String, manifestURL: String, manifestSHA: String) -> Data {
        try! JSONSerialization.data(withJSONObject: jsonObject(
            gameVersionId: CDN.gameVersionId,
            channel: CDN.releaseChannel,
            buildId: buildId,
            manifestURL: manifestURL,
            manifestSHA: manifestSHA
        ))
    }

    private func jsonObject(
        gameVersionId: String,
        channel: String,
        buildId: String,
        manifestURL: String,
        manifestSHA: String
    ) -> [String: String] {
        [
            "gameVersionId": gameVersionId,
            "channel": channel,
            "buildId": buildId,
            "manifestUrl": manifestURL,
            "manifestSha256": manifestSHA
        ]
    }

    private func makeManifestData(buildId: String, files: [FileEntry]) throws -> Data {
        let fileObjects: [[String: Any]] = files.map {
            ["path": $0.path, "size": $0.size, "sha256": $0.sha256]
        }
        let object: [String: Any] = [
            "addon": [
                "id": CDN.addonId,
                "name": CDN.addonName,
                "gameVersionId": CDN.gameVersionId
            ],
            "build": ["id": buildId],
            "files": fileObjects
        ]
        return try JSONSerialization.data(withJSONObject: object)
    }
}
