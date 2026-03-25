// ============================================================================
// MainWindow.swift — Three-panel layout: Chat + Debug + Logs
// ============================================================================

import SwiftUI

struct MainWindow: View {
    @Bindable var viewModel: ChatViewModel
    let apiClient: APIClient

    @State private var showDebug = true
    @State private var showLogs = true

    var body: some View {
        VStack(spacing: 0) {
            // Main content: Chat + Debug sidebar
            HSplitView {
                ChatView(viewModel: viewModel)
                    .frame(minWidth: 350)

                if showDebug {
                    DebugPanel(viewModel: viewModel)
                        .frame(minWidth: 280, idealWidth: 380, maxWidth: 500)
                }
            }

            // Bottom: Log viewer
            if showLogs {
                Divider()
                LogViewer(apiClient: apiClient)
                    .frame(minHeight: 100, idealHeight: 180, maxHeight: 300)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: { Task { await viewModel.clear() } }) {
                    Label("Clear", systemImage: "trash")
                }
                .keyboardShortcut("k", modifiers: .command)
                .help("Clear chat (Cmd+K)")

                Divider()

                Toggle(isOn: $showDebug) {
                    Label("Debug", systemImage: "ant.circle")
                }
                .keyboardShortcut("d", modifiers: .command)
                .help("Toggle debug panel (Cmd+D)")

                Toggle(isOn: $showLogs) {
                    Label("Logs", systemImage: "list.bullet.rectangle")
                }
                .keyboardShortcut("l", modifiers: .command)
                .help("Toggle log viewer (Cmd+L)")
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
