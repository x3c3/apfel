// ============================================================================
// MessageBubble.swift — Chat message bubble with copy button
// ============================================================================

import SwiftUI
import AppKit

struct MessageBubble: View {
    let message: ChatMsg
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == "user" { Spacer(minLength: 60) }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                // Role label
                HStack(spacing: 4) {
                    Text(message.role == "user" ? "you" : "ai")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    if let ms = message.durationMs {
                        Text("· \(ms)ms")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if message.isStreaming {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }

                // Message content
                Text(message.content.isEmpty && message.isStreaming ? "..." : message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.role == "user"
                            ? Color.accentColor.opacity(0.15)
                            : Color(nsColor: .controlBackgroundColor)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )

                // Copy button (visible on hover)
                if isHovered && !message.content.isEmpty {
                    Button(action: copyToClipboard) {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }

            if message.role == "assistant" { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
    }
}
