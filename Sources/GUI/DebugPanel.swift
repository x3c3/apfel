// ============================================================================
// DebugPanel.swift — Request/response JSON viewer with copy buttons
// ============================================================================

import SwiftUI
import AppKit

struct DebugPanel: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "ant.circle.fill")
                    .foregroundStyle(.orange)
                Text("Debug")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            if let msg = viewModel.selectedMessage {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Timing
                        if let ms = msg.durationMs {
                            debugSection(title: "Timing", icon: "clock") {
                                LabeledContent("Duration", value: "\(ms)ms")
                                if let tokens = msg.tokenCount {
                                    LabeledContent("Est. tokens", value: "~\(tokens)")
                                }
                            }
                        }

                        // Request
                        if let json = msg.requestJSON {
                            debugSection(title: "Request", icon: "arrow.up.doc") {
                                codeBlock(json)
                                copyButton(text: json, label: "Copy request")
                            }
                        }

                        // Response
                        if let json = msg.responseJSON {
                            debugSection(title: "Response", icon: "arrow.down.doc") {
                                codeBlock(json)
                                copyButton(text: json, label: "Copy response")
                            }
                        }

                        // Content
                        debugSection(title: "Content", icon: "text.quote") {
                            codeBlock(msg.content)
                            copyButton(text: msg.content, label: "Copy content")
                        }
                    }
                    .padding(12)
                }
            } else {
                VStack {
                    Spacer()
                    Text("Click a message to inspect")
                        .foregroundStyle(.tertiary)
                        .font(.callout)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Components

    @ViewBuilder
    private func debugSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func codeBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func copyButton(text: String, label: String) -> some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }) {
            Label(label, systemImage: "doc.on.doc")
                .font(.caption2)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
    }
}
