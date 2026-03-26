// ============================================================================
// TokenCounter.swift — Token counting for context window management
//
// CURRENT: uses chars/4 approximation (macOS 26.1 SDK)
// UPGRADE: when macOS 26.4 SDK is installed, replace with:
//   try await SystemLanguageModel.default.tokenCount(for: text)
//   try await SystemLanguageModel.default.contextSize
// See /open-tickets/TICKET-001-token-counting-api.md
// ============================================================================

import Foundation

actor TokenCounter {
    static let shared = TokenCounter()
    private static let contextWindowSize = 4096

    /// Count tokens in text using chars/4 approximation.
    /// Upgrade path: replace with Apple's tokenCount(for:) when macOS 26.4 SDK is available.
    func count(_ text: String) async -> Int {
        guard !text.isEmpty else { return 0 }
        return max(1, text.count / 4)
    }

    /// Total context window in tokens (4096, fixed for Apple's on-device model).
    func contextSize() async -> Int {
        return Self.contextWindowSize
    }

    /// Tokens available for model input given a reserved output budget.
    func inputBudget(reservedForOutput: Int = 512) async -> Int {
        await contextSize() - reservedForOutput
    }
}
