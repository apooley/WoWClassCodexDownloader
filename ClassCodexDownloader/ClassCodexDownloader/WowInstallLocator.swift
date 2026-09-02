import AppKit
import Foundation

enum WowInstallLocator {
    static let retailBundleIdentifier = "com.blizzard.worldofwarcraft"
    static let retailFolderName = "_retail_"
    static let installFolderName = "World of Warcraft"

    static func locateRetailAddOns() -> URL? {
        locateRetailAddOns(
            candidateRoots: defaultSearchRoots(),
            wowApplications: NSWorkspace.shared.urlsForApplications(
                withBundleIdentifier: retailBundleIdentifier
            ),
            isDirectory: isDirectory(_:)
        )
    }

    static func locateRetailAddOns(
        candidateRoots: [URL],
        wowApplications: [URL],
        isDirectory: (URL) -> Bool
    ) -> URL? {
        var candidates: [URL] = []
        var seen = Set<String>()

        func appendIfValid(_ url: URL) {
            let standardized = url.standardizedFileURL
            guard isRetailAddOnsFolder(standardized) else { return }
            guard isDirectory(standardized) else { return }
            if seen.insert(standardized.path).inserted {
                candidates.append(standardized)
            }
        }

        for root in candidateRoots {
            let installRoot = root.appendingPathComponent(installFolderName, isDirectory: true)
            appendIfValid(addOnsFolder(inRetail: retailFolder(inInstallRoot: installRoot)))
        }

        for application in wowApplications {
            if let addOns = addOnsFolder(fromWowApplication: application, isDirectory: isDirectory) {
                appendIfValid(addOns)
            }
        }

        if let preferred = candidates.first(where: { $0.path.hasPrefix("/Applications/") }) {
            return preferred
        }
        return candidates.first
    }

    static func addOnsFolder(
        fromWowApplication application: URL,
        isDirectory: (URL) -> Bool
    ) -> URL? {
        let app = application.standardizedFileURL
        guard app.pathExtension.lowercased() == "app" else { return nil }

        var directory = app.deletingLastPathComponent()
        for _ in 0..<6 {
            if directory.lastPathComponent == retailFolderName {
                let addOns = addOnsFolder(inRetail: directory)
                if isDirectory(addOns) {
                    return addOns.standardizedFileURL
                }
            }

            let nestedRetail = directory.appendingPathComponent(retailFolderName, isDirectory: true)
            let nestedAddOns = addOnsFolder(inRetail: nestedRetail)
            if isDirectory(nestedAddOns) {
                return nestedAddOns.standardizedFileURL
            }

            let parent = directory.deletingLastPathComponent()
            if parent.path == directory.path { break }
            directory = parent
        }
        return nil
    }

    static func defaultSearchRoots() -> [URL] {
        var roots: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        ]
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) ?? []
        for volume in volumes {
            roots.append(volume.appendingPathComponent("Applications", isDirectory: true))
        }

        var seen = Set<String>()
        return roots.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    static func isRetailAddOnsFolder(_ url: URL) -> Bool {
        let standardized = url.standardizedFileURL
        let addOns = standardized.lastPathComponent
        let interface = standardized.deletingLastPathComponent().lastPathComponent
        let retail = standardized.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
        return addOns == "AddOns" && interface == "Interface" && retail == retailFolderName
    }

    private static func retailFolder(inInstallRoot installRoot: URL) -> URL {
        installRoot.appendingPathComponent(retailFolderName, isDirectory: true)
    }

    private static func addOnsFolder(inRetail retail: URL) -> URL {
        retail
            .appendingPathComponent("Interface", isDirectory: true)
            .appendingPathComponent("AddOns", isDirectory: true)
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
