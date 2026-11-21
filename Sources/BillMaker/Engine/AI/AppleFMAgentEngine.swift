import Foundation

/// Primary AI Agent Engine supporting configurable execution modes:
/// 1. **Background Daemon (`fm serve`, port 1976)**: Fastest, sub-second responses via system Apple Intelligence daemon.
/// 2. **Embedded In-App (`LanguageModelSession`)**: Runs natively inside the app process memory.
public final class AppleFMAgentEngine: AgentEngine, @unchecked Sendable {
    public init() {}

    /// Prewarms the selected engine backend.
    public func prewarm(catalog: [Item], settings: AppSettings) {
        if settings.executionMode == .backgroundDaemon {
            AppleFMServerManager.shared.ensureDaemonRunning(catalog: catalog, currencySymbol: settings.currencySymbol)
        } else {
            AppleFMBackgroundServer.shared.start(catalog: catalog, currencySymbol: settings.currencySymbol)
        }
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
        do {
            let content: String
            if settings.executionMode == .backgroundDaemon {
                content = try await AppleFMServerManager.shared.queryDaemon(
                    userInput: userInput,
                    conversationHistory: conversationHistory,
                    catalog: catalog,
                    currencySymbol: settings.currencySymbol
                )
            } else {
                let isClarificationPending = conversationHistory.last(where: { $0.role == .agent })?.status == .needsClarification
                if !isClarificationPending {
                    AppleFMBackgroundServer.shared.reset(catalog: catalog, currencySymbol: settings.currencySymbol)
                }
                AppleFMBackgroundServer.shared.start(catalog: catalog, currencySymbol: settings.currencySymbol)
                content = try await AppleFMBackgroundServer.shared.processDirect(
                    userInput: userInput,
                    catalog: catalog,
                    currencySymbol: settings.currencySymbol
                )
            }
            return LLMResponseParser.parse(content: content, catalog: catalog, settings: settings)
        } catch {
            return AgentMessage(
                role: .agent,
                text: "Error generating response: \(error.localizedDescription)",
                thoughtProcess: "Execution error: \(error.localizedDescription)",
                status: .error
            )
        }
    }
}

/// Backwards compatibility typealias
public typealias AIAgentEngine = AppleFMAgentEngine
