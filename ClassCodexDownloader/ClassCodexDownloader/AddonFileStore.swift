import Foundation

protocol AddonFileStore: AnyObject {
    func isRegularFile(at url: URL) -> Bool
    func size(of url: URL) throws -> Int
    func sha256(of url: URL) throws -> String
    func writeAtomically(_ data: Data, to url: URL) throws
    func removeItem(at url: URL) throws
}

final class LocalAddonFileStore: AddonFileStore {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func isRegularFile(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }
        return !isDirectory.boolValue
    }

    func size(of url: URL) throws -> Int {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return values.fileSize ?? 0
    }

    func sha256(of url: URL) throws -> String {
        try FileSHA256.hexDigest(ofFile: url)
    }

    func writeAtomically(_ data: Data, to url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        let part = parent.appendingPathComponent(url.lastPathComponent + ".part", isDirectory: false)
        do {
            if fileManager.fileExists(atPath: part.path) {
                try fileManager.removeItem(at: part)
            }
            try data.write(to: part, options: .noFileProtection)
            if fileManager.fileExists(atPath: url.path) {
                _ = try fileManager.replaceItemAt(url, withItemAt: part)
            } else {
                try fileManager.moveItem(at: part, to: url)
            }
        } catch {
            try? fileManager.removeItem(at: part)
            throw error
        }
    }

    func removeItem(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
