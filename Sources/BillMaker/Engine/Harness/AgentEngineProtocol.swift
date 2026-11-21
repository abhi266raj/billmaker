import Foundation

/// Defines the contract for an intelligent billing agent engine in BillMaker.
///
/// Both the offline **Local Parsing Engine** (`NativeSwiftAgentEngine`) and the
/// **LLM Parsing Engine** (`LocalLLMAgentEngine`) conform to this protocol.
///
/// The engine receives user natural language text, the store catalog, conversation history,
/// and app settings, and produces an `AgentMessage` containing:
/// - Conversational shopkeeper text
/// - Transparent thought process reasoning
/// - Clean structured JSON payload conforming to `AgentJsonPayload`
/// - Parsed bill summary and item list
public protocol AgentEngine: Sendable {
    /// Processes a natural language user request and returns a structured agent response.
    ///
    /// - Parameters:
    ///   - userInput: The raw input string entered or spoken by the user (e.g. `"2kg aloo aur 1L sarso tel"`).
    ///   - conversationHistory: Prior messages in the conversation, used to resolve pending clarifications (e.g. answering which oil).
    ///   - catalog: The active list of store inventory items, including names, unit types, and prices.
    ///   - settings: Active user preferences, including currency symbol, tax rate, and engine configuration.
    /// - Returns: An `AgentMessage` representing the agent's response, parsed items, computed subtotal, and JSON payload.
    func processMessage(
        userInput: String,
        conversationHistory: [AgentMessage],
        catalog: [Item],
        settings: AppSettings
    ) async throws -> AgentMessage

    /// Prewarms the AI engine in the background to ensure near-instant response times.
    func prewarm(catalog: [Item], settings: AppSettings)

    /// Resets the continuous session transcript to start fresh.
    func resetSession(catalog: [Item], settings: AppSettings)
}

public extension AgentEngine {
    func prewarm(catalog: [Item], settings: AppSettings) {}
    func resetSession(catalog: [Item], settings: AppSettings) {}
}
