import Foundation

/// Primary AI Agent Engine powered by the persistent, prewarmed `AppleFMBackgroundServer`.
///
/// Features:
/// - Continues the `LanguageModelSession` across conversation turns so context stays warm.
/// - Communicates directly with the prewarmed background server for sub-second responses.
/// - Zero cold starts: model weights & KV cache are pre-loaded at launch.
public final class AppleFMAgentEngine: AgentEngine, @unchecked Sendable {
    public init() {}

    /// Prewarms the background FM server.
    public func prewarm(catalog: [Item], settings: AppSettings) {
        AppleFMBackgroundServer.shared.start(catalog: catalog, currencySymbol: settings.currencySymbol)
    }

    /// Resets the continuous session transcript.
    public func resetSession(catalog: [Item], settings: AppSettings) {
        AppleFMBackgroundServer.shared.reset(catalog: catalog, currencySymbol: settings.currencySymbol)
    }

    public func processMessage(
        userInput: String,
        conversationHistory: [AgentMessage],
        catalog: [Item],
        settings: AppSettings
    ) async throws -> AgentMessage {
        // Ensure background server is started & prewarmed
        AppleFMBackgroundServer.shared.start(catalog: catalog, currencySymbol: settings.currencySymbol)

        do {
            // Process directly via the persistent background server actor
            let content = try await AppleFMBackgroundServer.shared.processDirect(userInput: userInput)
            return LLMResponseParser.parse(content: content, catalog: catalog, settings: settings)
        } catch {
            return AgentMessage(
                role: .agent,
                text: "Error generating response from Apple Foundation Model: \(error.localizedDescription)",
                thoughtProcess: "Background FM server execution error: \(error.localizedDescription)",
                status: .error
            )
        }
    }
}

/// Backwards compatibility typealias
public typealias AIAgentEngine = AppleFMAgentEngine
