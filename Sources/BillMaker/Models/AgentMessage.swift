import Foundation

public enum AgentRole: String, Codable, Sendable {
    case user
    case agent
    case system
}

public enum AgentResponseStatus: String, Codable, Sendable, Equatable, Hashable {
    case ready               // All items resolved, bill computed
    case needsClarification  // Missing weight/quantity, multiple matches, or ambiguous item
    case notFound            // Item requested is not in the store catalog
    case thinking            // In-flight
    case error               // Parsing or connection error
    case info                // General system notice
}

public struct PendingClarification: Codable, Hashable, Sendable {
    public var query: String
    public var reason: String
    public var quantity: Double
    public var unit: String
    public var candidateNames: [String]

    public init(
        query: String = "",
        reason: String = "",
        quantity: Double = 1.0,
        unit: String = "pc",
        candidateNames: [String] = []
    ) {
        self.query = query
        self.reason = reason
        self.quantity = quantity
        self.unit = unit
        self.candidateNames = candidateNames
    }
}

extension PendingClarification: CustomDebugStringConvertible {
    public var debugDescription: String {
        "PendingClarification(query: \(query), reason: \(reason), options: \(candidateNames))"
    }
}

public struct AgentMessage: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var role: AgentRole
    public var text: String
    public var thoughtProcess: String?
    public var rawJsonOutput: String?
    public var status: AgentResponseStatus
    public var billSummary: BillSummary?
    public var parsedItems: [AgentParsedItem]?
    public var pendingClarification: PendingClarification?
    public var hasAutoCorrection: Bool
    public var autoCorrectionNote: String?
    public var unitCorrectionNotes: [String]?
    public var canUndo: Bool
    public var timestamp: Date

    public init(
        id: UUID = UUID(),
        role: AgentRole,
        text: String,
        thoughtProcess: String? = nil,
        rawJsonOutput: String? = nil,
        status: AgentResponseStatus = .ready,
        billSummary: BillSummary? = nil,
        parsedItems: [AgentParsedItem]? = nil,
        pendingClarification: PendingClarification? = nil,
        hasAutoCorrection: Bool = false,
        autoCorrectionNote: String? = nil,
        unitCorrectionNotes: [String]? = nil,
        canUndo: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.thoughtProcess = thoughtProcess
        self.rawJsonOutput = rawJsonOutput
        self.status = status
        self.billSummary = billSummary
        self.parsedItems = parsedItems
        self.pendingClarification = pendingClarification
        self.hasAutoCorrection = hasAutoCorrection
        self.autoCorrectionNote = autoCorrectionNote
        self.unitCorrectionNotes = unitCorrectionNotes
        self.canUndo = canUndo
        self.timestamp = timestamp
    }
}

// JSON Schema exchange model between Agent and Harness
public struct AgentParsedItem: Codable, Hashable, Sendable {
    public var itemId: String?
    public var itemName: String
    public var matchedAlias: String?
    public var quantity: Double
    public var unit: String
    public var unitPrice: Double?
    public var subtotal: Double?
    public var wasAutoCorrected: Bool?
    public var originalSpelling: String?
    public var wasUnitCorrected: Bool?
    public var originalUnit: String?
    public var unitCorrectionNote: String?
    public var notes: String?

    public init(
        itemId: String? = nil,
        itemName: String,
        matchedAlias: String? = nil,
        quantity: Double,
        unit: String,
        unitPrice: Double? = nil,
        subtotal: Double? = nil,
        wasAutoCorrected: Bool? = nil,
        originalSpelling: String? = nil,
        wasUnitCorrected: Bool? = nil,
        originalUnit: String? = nil,
        unitCorrectionNote: String? = nil,
        notes: String? = nil
    ) {
        self.itemId = itemId
        self.itemName = itemName
        self.matchedAlias = matchedAlias
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.subtotal = subtotal ?? ((unitPrice != nil) ? (quantity * unitPrice!) : nil)
        self.wasAutoCorrected = wasAutoCorrected
        self.originalSpelling = originalSpelling
        self.wasUnitCorrected = wasUnitCorrected
        self.originalUnit = originalUnit
        self.unitCorrectionNote = unitCorrectionNote
        self.notes = notes
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        // 1. Resolve Item Name (support itemName, item_name, item, name, product, title)
        var resolvedName: String? = nil
        let nameKeys = ["itemName", "item_name", "item", "name", "product", "product_name", "title"]
        for keyStr in nameKeys {
            if let k = DynamicCodingKeys(stringValue: keyStr),
               let val = try? container.decode(String.self, forKey: k) {
                let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    resolvedName = trimmed
                    break
                }
            }
        }
        self.itemName = resolvedName ?? "Unknown Item"

        // 2. Resolve Item ID (support itemId, item_id, id)
        var resolvedId: String? = nil
        let idKeys = ["itemId", "item_id", "id"]
        for keyStr in idKeys {
            if let k = DynamicCodingKeys(stringValue: keyStr),
               let val = try? container.decode(String.self, forKey: k) {
                resolvedId = val
                break
            }
        }
        self.itemId = resolvedId

        // 3. Resolve Quantity & Unit (supports Double, Int, or String like "2kg", "500g", "1.5")
        var resolvedQty: Double = 1.0
        var unitFromQtyString: String? = nil

        let qtyKeys = ["quantity", "qty", "count", "amount", "weight"]
        for keyStr in qtyKeys {
            guard let k = DynamicCodingKeys(stringValue: keyStr) else { continue }
            if let dbl = try? container.decode(Double.self, forKey: k) {
                resolvedQty = dbl
                break
            } else if let intVal = try? container.decode(Int.self, forKey: k) {
                resolvedQty = Double(intVal)
                break
            } else if let str = try? container.decode(String.self, forKey: k) {
                let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                // Extract numeric prefix and unit suffix (e.g. "2.5kg", "500g")
                let regex = try? NSRegularExpression(pattern: #"^([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]*)$"#)
                if let match = regex?.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) {
                    if let numRange = Range(match.range(at: 1), in: trimmed),
                       let num = Double(trimmed[numRange]) {
                        resolvedQty = num
                    }
                    if match.range(at: 2).location != NSNotFound,
                       let uRange = Range(match.range(at: 2), in: trimmed) {
                        let unitStr = String(trimmed[uRange]).trimmingCharacters(in: .whitespaces)
                        if !unitStr.isEmpty {
                            unitFromQtyString = unitStr
                        }
                    }
                } else if let parsedNum = Double(trimmed) {
                    resolvedQty = parsedNum
                }
                break
            }
        }
        self.quantity = resolvedQty

        // 4. Resolve Unit (support unit, unitType, unit_type, type, measure)
        var resolvedUnit: String? = nil
        let unitKeys = ["unit", "unitType", "unit_type", "type", "measure"]
        for keyStr in unitKeys {
            if let k = DynamicCodingKeys(stringValue: keyStr),
               let val = try? container.decode(String.self, forKey: k) {
                let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    resolvedUnit = trimmed
                    break
                }
            }
        }
        self.unit = resolvedUnit ?? unitFromQtyString ?? "piece"

        // 5. Resolve Unit Price (support unitPrice, unit_price, price, rate, cost, pricePerUnit)
        var resolvedPrice: Double? = nil
        let priceKeys = ["unitPrice", "unit_price", "price", "rate", "cost", "pricePerUnit", "price_per_unit"]
        for keyStr in priceKeys {
            guard let k = DynamicCodingKeys(stringValue: keyStr) else { continue }
            if let dbl = try? container.decode(Double.self, forKey: k) {
                resolvedPrice = dbl
                break
            } else if let intVal = try? container.decode(Int.self, forKey: k) {
                resolvedPrice = Double(intVal)
                break
            } else if let str = try? container.decode(String.self, forKey: k) {
                // Strip currency symbols and whitespace
                let cleaned = str.replacingOccurrences(of: "₹", with: "")
                    .replacingOccurrences(of: "$", with: "")
                    .replacingOccurrences(of: "Rs.", with: "")
                    .replacingOccurrences(of: "Rs", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let dbl = Double(cleaned) {
                    resolvedPrice = dbl
                    break
                }
            }
        }
        self.unitPrice = resolvedPrice

        // 6. Resolve Subtotal (or compute it)
        var resolvedSubtotal: Double? = nil
        let subtotalKeys = ["subtotal", "sub_total", "total", "line_total"]
        for keyStr in subtotalKeys {
            guard let k = DynamicCodingKeys(stringValue: keyStr) else { continue }
            if let dbl = try? container.decode(Double.self, forKey: k) {
                resolvedSubtotal = dbl
                break
            } else if let intVal = try? container.decode(Int.self, forKey: k) {
                resolvedSubtotal = Double(intVal)
                break
            }
        }
        self.subtotal = resolvedSubtotal ?? (resolvedPrice != nil ? (resolvedQty * resolvedPrice!) : nil)

        // 7. Optional fields
        self.matchedAlias = (try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "matchedAlias")!))
            ?? (try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "matched_alias")!))
        self.wasAutoCorrected = try? container.decodeIfPresent(Bool.self, forKey: DynamicCodingKeys(stringValue: "wasAutoCorrected")!)
        self.originalSpelling = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "originalSpelling")!)
        self.wasUnitCorrected = try? container.decodeIfPresent(Bool.self, forKey: DynamicCodingKeys(stringValue: "wasUnitCorrected")!)
        self.originalUnit = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "originalUnit")!)
        self.unitCorrectionNote = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "unitCorrectionNote")!)
        self.notes = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "notes")!)
    }
}


extension AgentMessage: CustomDebugStringConvertible {
    public var debugDescription: String {
        var lines: [String] = [
            "AgentMessage(id: \(id.uuidString.prefix(8)), role: \(role.rawValue), status: \(status.rawValue))",
            "Text: \(text)"
        ]
        if let thought = thoughtProcess, !thought.isEmpty {
            lines.append("Thought: \(thought)")
        }
        if let items = parsedItems, !items.isEmpty {
            lines.append("Items (\(items.count)):")
            for item in items {
                lines.append("  • \(item.quantity.cleanFormatted) \(item.unit) \(item.itemName) @ ₹\(item.unitPrice ?? 0.0)")
            }
        }
        if let summary = billSummary {
            lines.append("Total: ₹\(summary.grandTotal) (Subtotal: ₹\(summary.subtotal), Tax: ₹\(summary.taxAmount))")
        }
        if let clar = pendingClarification {
            lines.append("Clarification: '\(clar.query)' [Options: \(clar.candidateNames.joined(separator: ", "))]")
        }
        if let raw = rawJsonOutput, !raw.isEmpty {
            lines.append("Raw Payload:\n\(raw)")
        }
        return lines.joined(separator: "\n")
    }
}
