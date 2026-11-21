import Foundation

/// Output payload produced by BillingSpec.
public struct BillingOutput: Codable, Sendable {
    public var thought: String
    public var message: String
    public var items: BillingItemsContainer

    public init(
        thought: String = "",
        message: String = "",
        items: BillingItemsContainer = BillingItemsContainer()
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

public struct BillingItemsContainer: Codable, Sendable {
    public var verified: [String: BillingVerifiedItem]
    public var rejected: [String: BillingRejectedItem]
    public var needClarification: [String: BillingClarificationItem]

    public init(
        verified: [String: BillingVerifiedItem] = [:],
        rejected: [String: BillingRejectedItem] = [:],
        needClarification: [String: BillingClarificationItem] = [:]
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
        case verified, rejected, needClarification
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
        var resVerified: [String: BillingVerifiedItem] = [:]
        for vKey in ["verified", "accepted", "ready", "items"] {
            guard let k = DynamicCodingKeys(stringValue: vKey) else { continue }
            if let dict = try? container.decode([String: BillingVerifiedItem].self, forKey: k) {
                resVerified = dict
                break
            } else if let arr = try? container.decode([AgentParsedItem].self, forKey: k) {
                for itm in arr {
                    resVerified[itm.itemName] = BillingVerifiedItem(
                        quantity: itm.quantity,
                        unit: itm.unit,
                        unitPrice: itm.unitPrice ?? 0.0
                    )
                }
                break
            }
        }
        self.verified = resVerified

        // 2. Decode rejected
        var resRejected: [String: BillingRejectedItem] = [:]
        for rKey in ["rejected", "unlisted", "not_found"] {
            guard let k = DynamicCodingKeys(stringValue: rKey) else { continue }
            if let dict = try? container.decode([String: BillingRejectedItem].self, forKey: k) {
                resRejected = dict
                break
            } else if let strDict = try? container.decode([String: String].self, forKey: k) {
                for (name, reason) in strDict {
                    resRejected[name] = BillingRejectedItem(reason: reason)
                }
                break
            } else if let arr = try? container.decode([AgentRejectedItem].self, forKey: k) {
                for rej in arr {
                    resRejected[rej.item] = BillingRejectedItem(reason: rej.reason ?? "Not in store catalog")
                }
                break
            } else if let strArr = try? container.decode([String].self, forKey: k) {
                for str in strArr {
                    resRejected[str] = BillingRejectedItem(reason: "Not in store catalog")
                }
                break
            }
        }
        self.rejected = resRejected

        // 3. Decode needClarification
        var resClar: [String: BillingClarificationItem] = [:]
        for cKey in ["needClarification", "need_clarification", "needsClarification"] {
            guard let k = DynamicCodingKeys(stringValue: cKey) else { continue }
            if let dict = try? container.decode([String: BillingClarificationItem].self, forKey: k) {
                resClar = dict
                break
            } else if let arr = try? container.decode([AgentClarificationNeedItem].self, forKey: k) {
                for item in arr {
                    resClar[item.item] = BillingClarificationItem(
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

public struct BillingVerifiedItem: Codable, Sendable {
    public var quantity: Double
    public var unit: String
    public var unitPrice: Double

    public init(quantity: Double = 1.0, unit: String = "pc", unitPrice: Double = 0.0) {
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
    }
}

public struct BillingRejectedItem: Codable, Sendable {
    public var reason: String

    public init(reason: String = "Not in store catalog") {
        self.reason = reason
    }
}

public struct BillingClarificationItem: Codable, Sendable {
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
