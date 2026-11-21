import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Primary AI Agent Engine powered natively on-device by Apple Foundation Models (Apple FM).
///
/// Processing is executed entirely by Apple Intelligence:
/// - Spoken and typed natural language interpretation
/// - Multi-item grocery and retail orders without punctuation
/// - Automatic typo fixing and alias matching
/// - Colloquial Hindi & English measurements (e.g. "dedh kilo", "aadha kilo", "dhai", "paav", "500g", "2L")
/// - Unit mismatch detection and auto-correction
/// - Clarification questions when items are ambiguous
/// - Step-by-step reasoning enclosed in `<thought>...</thought>` tags
/// - Structured JSON output matching `AgentJsonPayload`
///
/// The local Mac app handles only the flow, billing calculation, cumulative invoice state, and UI.
public final class AppleFMAgentEngine: AgentEngine, @unchecked Sendable {
    public init() {}

    public func processMessage(
        userInput: String,
        conversationHistory: [AgentMessage],
        catalog: [Item],
        settings: AppSettings
    ) async throws -> AgentMessage {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let systemModel = SystemLanguageModel.default

            guard case .available = systemModel.availability else {
                return AgentMessage(
                    role: .agent,
                    text: "Apple Foundation Models engine is currently unavailable on this device. Please verify Apple Intelligence is enabled in macOS System Settings.",
                    thoughtProcess: "SystemLanguageModel availability: \(systemModel.availability)",
                    status: .error
                )
            }

            let systemPrompt = LLMPromptBuilder.buildSystemPrompt(
                catalog: catalog,
                currencySymbol: settings.currencySymbol
            )

            do {
                let session = LanguageModelSession {
                    systemPrompt
                }

                let response = try await session.respond(to: userInput)
                return LLMResponseParser.parse(content: response.content, catalog: catalog, settings: settings)
            } catch {
                return AgentMessage(
                    role: .agent,
                    text: "Error generating response from Apple Foundation Model: \(error.localizedDescription)",
                    thoughtProcess: "LanguageModelSession execution error: \(error.localizedDescription)",
                    status: .error
                )
            }
        }
        #endif

        return AgentMessage(
            role: .agent,
            text: "Apple Foundation Models requires macOS with Apple Intelligence.",
            thoughtProcess: "OS version does not support Apple Foundation Models.",
            status: .error
        )
    }
}

/// Backwards compatibility typealias
public typealias AIAgentEngine = AppleFMAgentEngine
