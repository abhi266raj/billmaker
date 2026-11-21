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

/// Structured output payload produced by AgentAtom guided generation
public struct AgentAtomBillingOutput: Codable, Sendable {
    public var thought: String
    public var message: String
    public var items: AgentAtomItemsContainer

    public init(
        thought: String = "",
        message: String = "",
        items: AgentAtomItemsContainer = AgentAtomItemsContainer()
    ) {
        self.thought = thought
        self.message = message
        self.items = items
    }

    public func toAgentJsonPayload(status: String? = nil) -> AgentJsonPayload {
        var verifiedItems: [AgentParsedItem] = []
        for (name, item) in items.verified {
            verifiedItems.append(
                AgentParsedItem(
                    itemName: name,
                    quantity: item.quantity,
                    unit: item.unit,
                    unitPrice: item.unitPrice
                )
            )
        }

        var rejectedItems: [AgentRejectedItem] = []
        for (name, item) in items.rejected {
            rejectedItems.append(
                AgentRejectedItem(
                    item: name,
                    reason: item.reason
                )
            )
        }

        var clarificationItems: [AgentClarificationNeedItem] = []
        for (name, item) in items.needClarification {
            clarificationItems.append(
                AgentClarificationNeedItem(
                    item: name,
                    quantity: item.quantity,
                    unit: item.unit,
                    options: item.options,
                    reason: item.reason
                )
            )
        }

        let resolvedStatus: String
        if let explicit = status {
            resolvedStatus = explicit
        } else if !clarificationItems.isEmpty {
            resolvedStatus = "needs_clarification"
        } else if verifiedItems.isEmpty && !rejectedItems.isEmpty {
            resolvedStatus = "not_found"
        } else {
            resolvedStatus = "ready"
        }

        return AgentJsonPayload(
            status: resolvedStatus,
            message: message,
            thought: thought,
            items: verifiedItems.isEmpty ? nil : verifiedItems,
            rejected: rejectedItems.isEmpty ? nil : rejectedItems,
            needClarification: clarificationItems.isEmpty ? nil : clarificationItems
        )
    }
}

public struct AgentAtomItemsContainer: Codable, Sendable {
    public var verified: [String: AgentAtomVerifiedItem]
    public var rejected: [String: AgentAtomRejectedItem]
    public var needClarification: [String: AgentAtomClarificationItem]

    public init(
        verified: [String: AgentAtomVerifiedItem] = [:],
        rejected: [String: AgentAtomRejectedItem] = [:],
        needClarification: [String: AgentAtomClarificationItem] = [:]
    ) {
        self.verified = verified
        self.rejected = rejected
        self.needClarification = needClarification
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }

    private enum CodingKeys: String, CodingKey {
        case verified
        case rejected
        case needClarification
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(verified, forKey: .verified)
        try container.encode(rejected, forKey: .rejected)
        try container.encode(needClarification, forKey: .needClarification)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        // 1. Decode verified
        var resVerified: [String: AgentAtomVerifiedItem] = [:]
        for vKey in ["verified", "accepted", "ready", "items"] {
            guard let k = DynamicCodingKeys(stringValue: vKey) else { continue }
            if let dict = try? container.decode([String: AgentAtomVerifiedItem].self, forKey: k) {
                resVerified = dict
                break
            } else if let arr = try? container.decode([AgentParsedItem].self, forKey: k) {
                for itm in arr {
                    resVerified[itm.itemName] = AgentAtomVerifiedItem(
                        quantity: itm.quantity,
                        unit: itm.unit,
                        unitPrice: itm.unitPrice ?? 0.0
                    )
                }
                break
            } else if let single = try? container.decode(AgentParsedItem.self, forKey: k) {
                resVerified[single.itemName] = AgentAtomVerifiedItem(
                    quantity: single.quantity,
                    unit: single.unit,
                    unitPrice: single.unitPrice ?? 0.0
                )
                break
            }
        }
        self.verified = resVerified

        // 2. Decode rejected
        var resRejected: [String: AgentAtomRejectedItem] = [:]
        for rKey in ["rejected", "unlisted", "not_found"] {
            guard let k = DynamicCodingKeys(stringValue: rKey) else { continue }
            if let dict = try? container.decode([String: AgentAtomRejectedItem].self, forKey: k) {
                resRejected = dict
                break
            } else if let strDict = try? container.decode([String: String].self, forKey: k) {
                for (name, reason) in strDict {
                    resRejected[name] = AgentAtomRejectedItem(reason: reason)
                }
                break
            } else if let arr = try? container.decode([AgentRejectedItem].self, forKey: k) {
                for rej in arr {
                    resRejected[rej.item] = AgentAtomRejectedItem(reason: rej.reason ?? "Not in store catalog")
                }
                break
            } else if let strArr = try? container.decode([String].self, forKey: k) {
                for str in strArr {
                    resRejected[str] = AgentAtomRejectedItem(reason: "Not in store catalog")
                }
                break
            }
        }
        self.rejected = resRejected

        // 3. Decode needClarification
        var resClar: [String: AgentAtomClarificationItem] = [:]
        for cKey in ["needClarification", "need_clarification", "needsClarification"] {
            guard let k = DynamicCodingKeys(stringValue: cKey) else { continue }
            if let dict = try? container.decode([String: AgentAtomClarificationItem].self, forKey: k) {
                resClar = dict
                break
            } else if let arr = try? container.decode([AgentClarificationNeedItem].self, forKey: k) {
                for item in arr {
                    resClar[item.item] = AgentAtomClarificationItem(
                        quantity: item.quantity,
                        unit: item.unit,
                        options: item.options,
                        reason: item.reason ?? "Ambiguous item"
                    )
                }
                break
            }
        }
        self.needClarification = resClar
    }
}

public struct AgentAtomVerifiedItem: Codable, Sendable {
    public var quantity: Double
    public var unit: String
    public var unitPrice: Double

    public init(quantity: Double = 1.0, unit: String = "pc", unitPrice: Double = 0.0) {
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
    }
}

public struct AgentAtomRejectedItem: Codable, Sendable {
    public var reason: String

    public init(reason: String = "Not in store catalog") {
        self.reason = reason
    }
}

public struct AgentAtomClarificationItem: Codable, Sendable {
    public var quantity: Double
    public var unit: String
    public var options: [String]
    public var reason: String

    public init(quantity: Double = 1.0, unit: String = "pc", options: [String] = [], reason: String = "Ambiguous item") {
        self.quantity = quantity
        self.unit = unit
        self.options = options
        self.reason = reason
    }
}

/// AgentAtom Modelled Specification for BillMaker retail billing operations.
/// Leverages AgentAtom's schema inference via `TypeDecoder` to guide the model towards valid `AgentAtomBillingOutput`s.
public struct AgentAtomBillingSpec: ModelledSpec {
    public typealias Input = BillingAgentInput
    public typealias Output = AgentAtomBillingOutput

    public static let identity = Identity(id: "billmaker-agent", name: "BillMakerBillingAgent", version: "1.0.0")
    public static let role: String = "Fast retail grocery store billing assistant"

    public let input: BillingAgentInput
    public var output: AgentAtomBillingOutput?
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
