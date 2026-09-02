import Foundation

struct AddonsPathStore {
    static let key = "addonsPath"

    private let defaults: UserDefaults
    private let locateRetailAddOns: () -> URL?

    init(
        defaults: UserDefaults = .standard,
        locateRetailAddOns: @escaping () -> URL? = { WowInstallLocator.locateRetailAddOns() }
    ) {
        self.defaults = defaults
        self.locateRetailAddOns = locateRetailAddOns
    }

    var path: String {
        get { defaults.string(forKey: Self.key) ?? "" }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }

    func resolvedInitialPath() -> String {
        let stored = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty,
           let resolved = WowInstallLocator.resolveRetailAddOns(
            from: URL(fileURLWithPath: stored, isDirectory: true)
           ) {
            let resolvedPath = resolved.path
            if resolvedPath != stored {
                path = resolvedPath
            }
            return resolvedPath
        }
        if let located = locateRetailAddOns() {
            let locatedPath = located.path
            path = locatedPath
            return locatedPath
        }
        return ""
    }

    func normalizeAndStore(_ selected: URL) -> String? {
        guard let resolved = WowInstallLocator.resolveRetailAddOns(from: selected) else {
            return nil
        }
        let resolvedPath = resolved.path
        path = resolvedPath
        return resolvedPath
    }
}
