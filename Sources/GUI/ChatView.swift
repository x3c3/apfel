// ============================================================================
// ChatView.swift — Main chat interface with message list and input field
// ============================================================================

import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            // System prompt (collapsible)
            systemPromptBar

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.messages) { msg in
                            MessageBubble(
                                message: msg,
                                isSelected: viewModel.selectedMessageId == msg.id,
                                onSelect: { viewModel.selectedMessageId = msg.id }
                            )
                            .id(msg.id)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.messages.last?.content) { _, _ in
                    if let lastId = viewModel.messages.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }

            Divider()

            // Input bar
            inputBar
        }
    }

    // MARK: - System Prompt Bar

    private var systemPromptBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "gear")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("System prompt (optional)", text: $viewModel.systemPrompt)
                .textFieldStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message...", text: $viewModel.currentInput, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .onSubmit {
                    if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                        Task { await viewModel.send() }
                    }
                }

            Button(action: { Task { await viewModel.send() } }) {
                Image(systemName: viewModel.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(viewModel.currentInput.isEmpty && !viewModel.isStreaming ? .gray : .blue)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.currentInput.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isStreaming)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
