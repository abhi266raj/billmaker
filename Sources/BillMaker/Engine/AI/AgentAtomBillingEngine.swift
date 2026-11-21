import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

/// Structured input payload for AgentAtom's `ModelledSpec`.
public struct BillingAgentInput: Codable, Sendable {
    public let request: String
    public let catalogSummary: String
    public let currencySymbol: String

    public init(request: String, catalogSummary: String, currencySymbol: String) {
        self.request = request
        self.catalogSummary = catalogSummary
        self.currencySymbol = currencySymbol
    }
}

/// AgentAtom Modelled Specification for BillMaker retail billing operations.
/// Leverages AgentAtom's schema inference via `TypeDecoder` to guide the model towards valid `AgentJsonPayload`s.
public struct AgentAtomBillingSpec: ModelledSpec {
    public typealias Input = BillingAgentInput
    public typealias Output = AgentJsonPayload

    public static let identity = Identity(id: "billmaker-agent", name: "BillMakerBillingAgent", version: "1.0.0")
    public static let role: String = "Fast retail grocery store billing assistant"

    public let input: BillingAgentInput
    public var output: AgentJsonPayload?
    public var instructions: String

    public init(input: BillingAgentInput, instructions: String) {
        self.input = input
        self.instructions = instructions
    }
}

/// AI Agent Engine that integrates AgentAtom (https://github.com/abhi266raj/AgentAtom)
/// supporting guided JSON generation and structured Apple Intelligence sessions.
public final class AgentAtomBillingEngine: AgentEngine, @unchecked Sendable {
    private let fallbackEngine: AppleFMAgentEngine

    public init(fallbackEngine: AppleFMAgentEngine = AppleFMAgentEngine()) {
        self.fallbackEngine = fallbackEngine
    }

    public func prewarm(catalog: [Item], settings: AppSettings) {
        fallbackEngine.prewarm(catalog: catalog, settings: settings)
    }

    public func resetSession(catalog: [Item], settings: AppSettings) {
        fallbackEngine.resetSession(catalog: catalog, settings: settings)
    }

    public func processMessage(
        userInput: String,
        conversationHistory: [AgentMessage],
        catalog: [Item],
        settings: AppSettings
    ) async throws -> AgentMessage {
        #if canImport(FoundationModels) && (os(macOS) || os(iOS))
        if #available(macOS 26, iOS 26, *) {
            if let session = AppleIntelligenceSession() {
                let catalogSummary = catalog.map { item in
                    "- \(item.name): \(settings.currencySymbol)\(item.pricePerUnit)/\(item.unitType.shortLabel)"
                }.joined(separator: "\n")

                let instructions = LLMPromptBuilder.buildSystemPrompt(catalog: catalog, currencySymbol: settings.currencySymbol)
                let input = BillingAgentInput(request: userInput, catalogSummary: catalogSummary, currencySymbol: settings.currencySymbol)
                let spec = AgentAtomBillingSpec(input: input, instructions: instructions)

                let operation = AgenticOperation(spec: spec, session: session)
                let result = await operation.execute()

                switch result {
                case .success(let rawOutput):
                    return LLMResponseParser.parse(
                        content: rawOutput,
                        catalog: catalog,
                        settings: settings,
                        userInput: userInput
                    )
                case .failure:
                    // Gracefully fall back to background daemon or embedded engine
                    break
                }
            }
        }
        #endif

        return try await fallbackEngine.processMessage(
            userInput: userInput,
            conversationHistory: conversationHistory,
            catalog: catalog,
            settings: settings
        )
    }
}
