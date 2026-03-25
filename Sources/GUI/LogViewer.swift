// ============================================================================
// LogViewer.swift — Live request log viewer with filtering
// Polls GET /v1/logs from the apfel server every 2 seconds.
// ============================================================================

import SwiftUI

struct LogViewer: View {
    let apiClient: APIClient
    @State private var logs: [APIClient.LogEntry] = []
    @State private var errorsOnly = false
    @State private var isPolling = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.green)
                Text("Logs")
                    .font(.headline)
                Spacer()

                Toggle("Errors only", isOn: $errorsOnly)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Text("\(logs.count) entries")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Log table
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(filteredLogs) { log in
                            logRow(log)
                                .id(log.id)
                        }
                    }
                }
                .onChange(of: logs.count) { _, _ in
                    if let lastId = filteredLogs.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
        .task {
            // Poll logs every 2 seconds
            while isPolling {
                do {
                    logs = try await apiClient.fetchLogs(errorsOnly: false, limit: 200)
                } catch {
                    // Silently ignore fetch errors
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onDisappear { isPolling = false }
    }

    private var filteredLogs: [APIClient.LogEntry] {
        if errorsOnly {
            return logs.filter { $0.status >= 400 }
        }
        return logs
    }

    private func logRow(_ log: APIClient.LogEntry) -> some View {
        HStack(spacing: 8) {
            // Timestamp
            Text(formatTimestamp(log.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .leading)

            // Method + Path
            Text("\(log.method) \(log.path)")
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)

            Spacer()

            // Status
            Text("\(log.status)")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(log.status >= 400 ? .red : .green)

            // Duration
            Text("\(log.duration_ms)ms")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .trailing)

            // Tokens
            if let tokens = log.estimated_tokens {
                Text("~\(tokens)t")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(log.status >= 400 ? Color.red.opacity(0.05) : Color.clear)
    }

    private func formatTimestamp(_ iso: String) -> String {
        // Extract HH:MM:SS from ISO 8601
        if let tIdx = iso.firstIndex(of: "T"),
           let zIdx = iso.firstIndex(of: "Z") ?? iso.lastIndex(of: "+") {
            let time = iso[iso.index(after: tIdx)..<zIdx]
            return String(time)
        }
        return iso
    }
}
