import Foundation

struct AddonsPathStore {
    static let key = "addonsPath"

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let locateRetailAddOns: () -> URL?

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        locateRetailAddOns: @escaping () -> URL? = { WowInstallLocator.locateRetailAddOns() }
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.locateRetailAddOns = locateRetailAddOns
    }

    var path: String {
        get { defaults.string(forKey: Self.key) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }

    func resolvedInitialPath() -> String {
        let stored = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty, isDirectory(stored) {
            return stored
        }
        if let located = locateRetailAddOns() {
            let locatedPath = located.path
            path = locatedPath
            return locatedPath
        }
        return ""
    }

    private func isDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}
