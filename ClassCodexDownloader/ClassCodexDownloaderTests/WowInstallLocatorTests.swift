import XCTest
@testable import ClassCodexDownloader

final class WowInstallLocatorTests: XCTestCase {
    private let thunderboltRetailApp = URL(
        fileURLWithPath: "/Volumes/Thunderbolt Storage/Applications/World of Warcraft/_retail_/World of Warcraft.app"
    )
    private let thunderboltAddOns = URL(
        fileURLWithPath: "/Volumes/Thunderbolt Storage/Applications/World of Warcraft/_retail_/Interface/AddOns",
        isDirectory: true
    )
    private let applicationsAddOns = URL(
        fileURLWithPath: "/Applications/World of Warcraft/_retail_/Interface/AddOns",
        isDirectory: true
    )
    private let classicApp = URL(
        fileURLWithPath: "/Applications/World of Warcraft/_classic_/World of Warcraft Classic.app"
    )

    func testFindsAddOnsFromRetailApplication() {
        let found = WowInstallLocator.locateRetailAddOns(
            candidateRoots: [],
            wowApplications: [thunderboltRetailApp],
            isDirectory: { $0.path == self.thunderboltAddOns.path }
        )
        XCTAssertEqual(found, thunderboltAddOns)
    }

    func testFindsAddOnsFromInstallRootApplication() {
        let installRootApp = URL(
            fileURLWithPath: "/Volumes/Games/World of Warcraft/World of Warcraft.app"
        )
        let addOns = URL(
            fileURLWithPath: "/Volumes/Games/World of Warcraft/_retail_/Interface/AddOns",
            isDirectory: true
        )
        let found = WowInstallLocator.locateRetailAddOns(
            candidateRoots: [],
            wowApplications: [installRootApp],
            isDirectory: { $0.path == addOns.path }
        )
        XCTAssertEqual(found, addOns)
    }

    func testFindsAddOnsFromApplicationsSearchRoot() {
        let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let found = WowInstallLocator.locateRetailAddOns(
            candidateRoots: [applications],
            wowApplications: [],
            isDirectory: { $0.path == self.applicationsAddOns.path }
        )
        XCTAssertEqual(found, applicationsAddOns)
    }

    func testFindsAddOnsOnExternalVolumeSearchRoot() {
        let volumeApps = URL(
            fileURLWithPath: "/Volumes/Thunderbolt Storage/Applications",
            isDirectory: true
        )
        let found = WowInstallLocator.locateRetailAddOns(
            candidateRoots: [volumeApps],
            wowApplications: [],
            isDirectory: { $0.path == self.thunderboltAddOns.path }
        )
        XCTAssertEqual(found, thunderboltAddOns)
    }

    func testPrefersInternalApplicationsOverExternalVolume() {
        let found = WowInstallLocator.locateRetailAddOns(
            candidateRoots: [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                URL(fileURLWithPath: "/Volumes/Thunderbolt Storage/Applications", isDirectory: true)
            ],
            wowApplications: [],
            isDirectory: { url in
                url.path == self.applicationsAddOns.path || url.path == self.thunderboltAddOns.path
            }
        )
        XCTAssertEqual(found, applicationsAddOns)
    }

    func testClassicApplicationStillResolvesRetailAddOnsWhenPresent() {
        let found = WowInstallLocator.locateRetailAddOns(
            candidateRoots: [],
            wowApplications: [classicApp],
            isDirectory: { $0.path == self.applicationsAddOns.path }
        )
        XCTAssertEqual(found, applicationsAddOns)
    }

    func testIgnoresClassicWhenRetailAddOnsAreMissing() {
        let classicAddOns = URL(
            fileURLWithPath: "/Applications/World of Warcraft/_classic_/Interface/AddOns",
            isDirectory: true
        )
        let found = WowInstallLocator.locateRetailAddOns(
            candidateRoots: [],
            wowApplications: [classicApp],
            isDirectory: { $0.path == classicAddOns.path }
        )
        XCTAssertNil(found)
    }

    func testRejectsNonAppURL() {
        let found = WowInstallLocator.addOnsFolder(
            fromWowApplication: URL(fileURLWithPath: "/Applications/World of Warcraft"),
            isDirectory: { _ in true }
        )
        XCTAssertNil(found)
    }

    func testRecognizesRetailAddOnsFolderShape() {
        XCTAssertTrue(WowInstallLocator.isRetailAddOnsFolder(thunderboltAddOns))
        XCTAssertFalse(
            WowInstallLocator.isRetailAddOnsFolder(
                URL(fileURLWithPath: "/tmp/Interface/AddOns", isDirectory: true)
            )
        )
    }
}

final class AddonsPathStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "classcodex.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func testUsesStoredPathWhenDirectoryExists() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("stored-addons-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let store = AddonsPathStore(defaults: defaults, locateRetailAddOns: {
            URL(fileURLWithPath: "/should/not/use")
        })
        store.path = folder.path

        XCTAssertEqual(store.resolvedInitialPath(), folder.path)
    }

    func testLocatesWhenStoredPathIsMissing() {
        let located = URL(fileURLWithPath: "/Volumes/Thunderbolt Storage/Applications/World of Warcraft/_retail_/Interface/AddOns")
        let store = AddonsPathStore(defaults: defaults, locateRetailAddOns: { located })
        store.path = "/old/missing/AddOns"

        XCTAssertEqual(store.resolvedInitialPath(), located.path)
        XCTAssertEqual(store.path, located.path)
    }

    func testLocatesWhenNoStoredPath() {
        let located = URL(fileURLWithPath: "/Applications/World of Warcraft/_retail_/Interface/AddOns")
        let store = AddonsPathStore(defaults: defaults, locateRetailAddOns: { located })

        XCTAssertEqual(store.resolvedInitialPath(), located.path)
        XCTAssertEqual(store.path, located.path)
    }

    func testReturnsEmptyWhenNothingFound() {
        let store = AddonsPathStore(defaults: defaults, locateRetailAddOns: { nil })
        XCTAssertEqual(store.resolvedInitialPath(), "")
    }
}
