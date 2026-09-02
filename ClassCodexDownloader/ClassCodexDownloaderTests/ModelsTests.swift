import XCTest
@testable import ClassCodexDownloader

final class ModelsTests: XCTestCase {
    func testDecodesChannelConfig() throws {
        let json = """
        {
          "gameVersionId": "retail",
          "channel": "production",
          "buildId": "abc123",
          "manifestUrl": "https://wow-class-codex.s3.us-east-1.amazonaws.com/m.json",
          "manifestSha256": "deadbeef"
        }
        """.data(using: .utf8)!
        let config = try JSONDecoder().decode(ChannelConfig.self, from: json)
        XCTAssertEqual(config.buildId, "abc123")
        XCTAssertEqual(config.gameVersionId, "retail")
        XCTAssertEqual(config.channel, "production")
    }

    func testDecodesManifestFiles() throws {
        let json = """
        {
          "addon": { "id": "class-codex", "name": "ClassCodex", "gameVersionId": "retail" },
          "build": { "id": "abc123" },
          "files": [
            { "path": "ClassCodex/ClassCodex.toc", "size": 12, "sha256": "abc" }
          ]
        }
        """.data(using: .utf8)!
        let manifest = try JSONDecoder().decode(Manifest.self, from: json)
        XCTAssertEqual(manifest.files.count, 1)
        XCTAssertEqual(manifest.files[0].path, "ClassCodex/ClassCodex.toc")
        XCTAssertEqual(manifest.files[0].size, 12)
    }

    func testRejectsMissingConfigFields() {
        let json = """
        { "gameVersionId": "retail", "channel": "production" }
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(ChannelConfig.self, from: json))
    }
}
