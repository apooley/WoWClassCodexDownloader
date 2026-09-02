import AppKit
import SwiftUI

struct ContentView: View {
    private let pathStore = AddonsPathStore()

    @State private var addonsPath: String
    @State private var dryRun = false
    @State private var logText = ""
    @State private var footer = ""
    @State private var progressLine = ""
    @State private var isRunning = false
    @State private var runTask: Task<Void, Never>?

    init() {
        _addonsPath = State(initialValue: AddonsPathStore().resolvedInitialPath())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ClassCodex Downloader")
                .font(.title2)

            HStack {
                TextField("World of Warcraft AddOns folder", text: $addonsPath)
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
                Button("Choose Folder…") {
                    chooseFolder()
                }
                .disabled(isRunning)
            }

            if addonsPath.isEmpty {
                Text("World of Warcraft (retail) was not found. Choose Interface/AddOns manually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Dry run (download nothing)", isOn: $dryRun)
                .disabled(isRunning)

            HStack {
                Button(isRunning ? "Cancel" : "Update") {
                    if isRunning {
                        runTask?.cancel()
                    } else {
                        startUpdate()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isRunning && addonsPath.isEmpty)

                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                    Text(progressLine)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            ScrollView {
                Text(logText.isEmpty ? "Ready." : logText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 180)
            .border(Color.secondary.opacity(0.3))

            Text(footer)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Select your World of Warcraft Interface/AddOns folder."
        if !addonsPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: addonsPath, isDirectory: true)
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        addonsPath = url.path
        pathStore.path = url.path
    }

    private func startUpdate() {
        pathStore.path = addonsPath
        let folder = URL(fileURLWithPath: addonsPath, isDirectory: true)
        let dryRun = dryRun
        logText = ""
        footer = ""
        progressLine = "Starting…"
        isRunning = true

        runTask = Task {
            let installer = ClassCodexInstaller()
            do {
                let result = try await installer.install(addonsFolder: folder, dryRun: dryRun) { message in
                    Task { @MainActor in
                        appendLog(message)
                    }
                }
                await MainActor.run {
                    footer = result.summary
                    finishRun()
                }
            } catch is CancellationError {
                await MainActor.run {
                    footer = "Cancelled."
                    appendLog("Cancelled.")
                    finishRun()
                }
            } catch {
                await MainActor.run {
                    footer = error.localizedDescription
                    appendLog("Error: \(error.localizedDescription)")
                    finishRun()
                }
            }
        }
    }

    private func appendLog(_ message: String) {
        if !message.isEmpty {
            progressLine = message
        }
        if logText.isEmpty {
            logText = message
        } else {
            logText += "\n" + message
        }
    }

    private func finishRun() {
        isRunning = false
        progressLine = ""
        runTask = nil
    }
}
