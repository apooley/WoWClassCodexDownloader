import SwiftUI
import AppKit

@main
struct ClassCodexDownloaderApp: App {
    var body: some Scene {
        WindowGroup("ClassCodex Downloader") {
            ContentView()
                .frame(minWidth: 520, minHeight: 420)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 560, height: 480)
    }
}
