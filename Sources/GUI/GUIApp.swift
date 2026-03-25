// ============================================================================
// GUIApp.swift — Launch native macOS SwiftUI GUI for apfel
// Spawns apfel --serve as background process, opens SwiftUI window.
// ============================================================================

import AppKit
import SwiftUI

/// Start the GUI: launch server in background, open SwiftUI chat window.
func startGUI() {
    // Pick a port for the background server
    let port = 11434

    // Spawn apfel --serve as a child process
    let serverProcess = Process()
    serverProcess.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
    serverProcess.arguments = ["--serve", "--port", "\(port)", "--cors"]
    serverProcess.standardOutput = FileHandle.nullDevice
    serverProcess.standardError = FileHandle.nullDevice

    do {
        try serverProcess.run()
        printStderr("GUI: server started on port \(port) (PID: \(serverProcess.processIdentifier))")
    } catch {
        printStderr("GUI: failed to start server: \(error)")
        return
    }

    // Wait for server to be ready
    let client = APIClient(port: port)
    let ready = waitForServer(client: client, timeout: 8.0)
    guard ready else {
        printStderr("GUI: server failed to start within 8 seconds")
        serverProcess.terminate()
        return
    }
    printStderr("GUI: server ready")

    // Launch the SwiftUI app
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)

    let delegate = GUIAppDelegate(
        serverProcess: serverProcess,
        apiClient: client
    )
    app.delegate = delegate
    app.run()
}

/// Poll /health until server responds or timeout.
private func waitForServer(client: APIClient, timeout: Double) -> Bool {
    let start = Date()
    let semaphore = DispatchSemaphore(value: 0)
    nonisolated(unsafe) var isReady = false

    Task { @Sendable in
        while Date().timeIntervalSince(start) < timeout {
            if await client.healthCheck() {
                isReady = true
                semaphore.signal()
                return
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
        semaphore.signal()
    }

    semaphore.wait()
    return isReady
}

// MARK: - App Delegate

class GUIAppDelegate: NSObject, NSApplicationDelegate {
    let serverProcess: Process
    let apiClient: APIClient
    var window: NSWindow?

    init(serverProcess: Process, apiClient: APIClient) {
        self.serverProcess = serverProcess
        self.apiClient = apiClient
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let viewModel = ChatViewModel(apiClient: apiClient)
        let contentView = MainWindow(viewModel: viewModel, apiClient: apiClient)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "apfel — Apple Intelligence"
        window.center()
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean shutdown: kill the server process
        if serverProcess.isRunning {
            serverProcess.terminate()
            printStderr("GUI: server process terminated")
        }
    }
}
