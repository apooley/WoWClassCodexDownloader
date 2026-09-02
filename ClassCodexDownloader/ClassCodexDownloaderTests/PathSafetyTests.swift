import XCTest
@testable import ClassCodexDownloader

final class PathSafetyTests: XCTestCase {
    private let addons = URL(fileURLWithPath: "/tmp/addons", isDirectory: true)

    func testAcceptsClassCodexRelativeFile() throws {
        let url = try PathSafety.resolvedFileURL(relative: "ClassCodex/foo.lua", under: addons)
        XCTAssertEqual(url.path, "/tmp/addons/ClassCodex/foo.lua")
    }

    func testAcceptsNestedClassCodexFile() throws {
        let url = try PathSafety.resolvedFileURL(relative: "ClassCodex/db/spells.lua", under: addons)
        XCTAssertEqual(url.path, "/tmp/addons/ClassCodex/db/spells.lua")
    }

    func testRejectsParentTraversal() {
        XCTAssertThrowsError(try PathSafety.resolvedFileURL(relative: "../Evil", under: addons)) { error in
            XCTAssertEqual(error as? InstallerError, .unsafePath("../Evil"))
        }
    }

    func testRejectsEmbeddedParentTraversal() {
        XCTAssertThrowsError(
            try PathSafety.resolvedFileURL(relative: "ClassCodex/../passwd", under: addons)
        )
    }

    func testRejectsAbsolutePath() {
        XCTAssertThrowsError(
            try PathSafety.resolvedFileURL(relative: "/etc/passwd", under: addons)
        )
    }

    func testRejectsMissingPrefix() {
        XCTAssertThrowsError(
            try PathSafety.resolvedFileURL(relative: "ClassCodex", under: addons)
        )
    }

    func testRejectsEmptySegments() {
        XCTAssertThrowsError(
            try PathSafety.resolvedFileURL(relative: "ClassCodex//foo.lua", under: addons)
        )
    }
}

final class CDNTests: XCTestCase {
    func testFileURLEncodesEachPathSegment() throws {
        let url = try CDN.fileURL(buildId: "build 1", relativePath: "ClassCodex/My File.lua")
        XCTAssertEqual(
            url.absoluteString,
            "https://wow-class-codex.s3.us-east-1.amazonaws.com/builds/retail/build%201/ClassCodex/My%20File.lua"
        )
    }

    func testFileURLEncodesUnicode() throws {
        let url = try CDN.fileURL(buildId: "b", relativePath: "ClassCodex/é.lua")
        XCTAssertEqual(
            url.absoluteString,
            "https://wow-class-codex.s3.us-east-1.amazonaws.com/builds/retail/b/ClassCodex/%C3%A9.lua"
        )
    }

    func testRejectsOffHostURL() {
        XCTAssertFalse(CDN.isAllowed(URL(string: "https://evil.example/manifest.json")!))
        XCTAssertFalse(CDN.isAllowed(URL(string: "http://wow-class-codex.s3.us-east-1.amazonaws.com/x")!))
        XCTAssertTrue(CDN.isAllowed(URL(string: "https://wow-class-codex.s3.us-east-1.amazonaws.com/x")!))
    }

    func testKnownSHA256() {
        XCTAssertEqual(
            FileSHA256.hexDigest(of: Data("abc".utf8)),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }
}
