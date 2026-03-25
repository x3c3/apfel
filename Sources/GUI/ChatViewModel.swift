// ============================================================================
// ChatViewModel.swift — State management for the chat interface
// Talks to apfel --serve via APIClient. No AI logic here.
// ============================================================================

import Foundation
import SwiftUI

/// A single chat message with debug metadata.
struct ChatMsg: Identifiable {
    let id: String
    let role: String        // "user" or "assistant"
    var content: String     // grows during streaming
    let timestamp: Date
    var requestJSON: String?
    var responseJSON: String?
    var durationMs: Int?
    var tokenCount: Int?
    var isStreaming: Bool = false
}

/// Observable state for the chat interface.
@Observable
@MainActor
class ChatViewModel {
    var messages: [ChatMsg] = []
    var currentInput: String = ""
    var systemPrompt: String = ""
    var isStreaming: Bool = false
    var selectedMessageId: String?
    var errorMessage: String?

    let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    /// The currently selected message (for debug panel).
    var selectedMessage: ChatMsg? {
        guard let id = selectedMessageId else { return nil }
        return messages.first { $0.id == id }
    }

    /// Send the current input as a message and stream the response.
    func send() async {
        let input = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty, !isStreaming else { return }

        // Add user message
        let userMsg = ChatMsg(
            id: UUID().uuidString,
            role: "user",
            content: input,
            timestamp: Date()
        )
        messages.append(userMsg)
        currentInput = ""
        isStreaming = true
        errorMessage = nil

        // Build message history for context
        let history = messages.filter { $0.role == "user" || $0.role == "assistant" }
            .map { (role: $0.role, content: $0.content) }

        // Create assistant message placeholder
        let assistantId = UUID().uuidString
        var assistantMsg = ChatMsg(
            id: assistantId,
            role: "assistant",
            content: "",
            timestamp: Date(),
            isStreaming: true
        )
        messages.append(assistantMsg)

        let start = Date()

        // Stream the response
        let (stream, requestJSON) = apiClient.streamChatCompletion(
            messages: history,
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt
        )

        assistantMsg.requestJSON = requestJSON
        updateMessage(id: assistantId) { $0.requestJSON = requestJSON }

        do {
            for try await delta in stream {
                updateMessage(id: assistantId) { $0.content += delta }
            }

            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            updateMessage(id: assistantId) { msg in
                msg.isStreaming = false
                msg.durationMs = durationMs
                msg.tokenCount = max(1, msg.content.count / 4)
                // Build response JSON for debug
                msg.responseJSON = """
                {
                  "content": \(jsonEscape(msg.content)),
                  "model": "apple-foundationmodel",
                  "duration_ms": \(durationMs),
                  "estimated_tokens": \(max(1, msg.content.count / 4))
                }
                """
            }
        } catch {
            updateMessage(id: assistantId) { msg in
                msg.content = "Error: \(error.localizedDescription)"
                msg.isStreaming = false
            }
            errorMessage = error.localizedDescription
        }

        isStreaming = false
    }

    /// Clear all messages.
    func clear() {
        messages.removeAll()
        selectedMessageId = nil
        errorMessage = nil
    }

    // MARK: - Helpers

    private func updateMessage(id: String, update: (inout ChatMsg) -> Void) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            update(&messages[idx])
        }
    }

    private func jsonEscape(_ str: String) -> String {
        let escaped = str
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
        return "\"\(escaped)\""
    }
}
