import Foundation

public enum AgentRole: String, Codable, Sendable {
    case user
    case agent
    case system
}

public enum AgentResponseStatus: String, Codable, Sendable {
    case ready               // All items resolved, bill computed
    case needsClarification  // Missing weight/quantity, multiple matches, or ambiguous item
    case notFound            // Item requested is not in the store catalog
    case thinking            // In-flight
    case error               // Parsing or connection error
    case info                // General system notice
}

public struct PendingClarification: Codable, Hashable, Sendable {
    public var query: String
    public var quantity: Double
    public var unit: String
    public var candidateNames: [String]

    public init(query: String = "", quantity: Double = 1.0, unit: String = "pc", candidateNames: [String] = []) {
        self.query = query
        self.quantity = quantity
        self.unit = unit
        self.candidateNames = candidateNames
    }

    private enum CodingKeys: String, CodingKey {
        case query, quantity, unit, candidateNames, candidates, options
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unit, forKey: .unit)
        try container.encode(candidateNames, forKey: .candidateNames)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.query = try container.decodeIfPresent(String.self, forKey: .query) ?? ""
        self.quantity = try container.decodeIfPresent(Double.self, forKey: .quantity) ?? 1.0
        self.unit = try container.decodeIfPresent(String.self, forKey: .unit) ?? "pc"

        var candidates: [String] = []
        if let list = try container.decodeIfPresent([String].self, forKey: .candidateNames) {
            candidates = list
        } else if let list = try container.decodeIfPresent([String].self, forKey: .candidates) {
            candidates = list
        } else if let list = try container.decodeIfPresent([String].self, forKey: .options) {
            candidates = list
        }
        self.candidateNames = candidates
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

public struct AgentRejectedItem: Codable, Hashable, Sendable {
    public var item: String
    public var reason: String?

    public init(item: String, reason: String? = nil) {
        self.item = item
        self.reason = reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var name = ""
        for key in ["item", "name", "itemName", "query"] {
            if let k = DynamicCodingKeys(stringValue: key), let s = try? container.decode(String.self, forKey: k) {
                name = s
                break
            }
        }
        self.item = name
        var resReason: String? = nil
        for key in ["reason", "message", "note"] {
            if let k = DynamicCodingKeys(stringValue: key), let s = try? container.decode(String.self, forKey: k) {
                resReason = s
                break
            }
        }
        self.reason = resReason
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }
}

public struct AgentClarificationNeedItem: Codable, Hashable, Sendable {
    public var item: String
    public var quantity: Double
    public var unit: String
    public var options: [String]
    public var reason: String?

    public init(
        item: String,
        quantity: Double = 1.0,
        unit: String = "pc",
        options: [String] = [],
        reason: String? = nil
    ) {
        self.item = item
        self.quantity = quantity
        self.unit = unit
        self.options = options
        self.reason = reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var name = ""
        for key in ["item", "name", "itemName", "query"] {
            if let k = DynamicCodingKeys(stringValue: key), let s = try? container.decode(String.self, forKey: k) {
                name = s
                break
            }
        }
        self.item = name

        var qty = 1.0
        for key in ["quantity", "qty", "count"] {
            if let k = DynamicCodingKeys(stringValue: key) {
                if let d = try? container.decode(Double.self, forKey: k) { qty = d; break }
                if let s = try? container.decode(String.self, forKey: k), let d = Double(s) { qty = d; break }
            }
        }
        self.quantity = qty

        var u = "pc"
        for key in ["unit", "uom"] {
            if let k = DynamicCodingKeys(stringValue: key), let s = try? container.decode(String.self, forKey: k) {
                u = s
                break
            }
        }
        self.unit = u

        var opts: [String] = []
        for key in ["options", "candidates", "candidateNames", "choices"] {
            if let k = DynamicCodingKeys(stringValue: key), let arr = try? container.decode([String].self, forKey: k) {
                opts = arr
                break
            }
        }
        self.options = opts

        var resReason: String? = nil
        for key in ["reason", "question", "message", "note"] {
            if let k = DynamicCodingKeys(stringValue: key), let s = try? container.decode(String.self, forKey: k) {
                resReason = s
                break
            }
        }
        self.reason = resReason
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }
}

public struct AgentJsonPayload: Codable, Sendable {
    public var status: String // "ready", "needs_clarification", "not_found"
    public var message: String
    public var thought: String?
    public var totalAmount: Double?
    public var totalWeightKg: Double?
    public var items: [AgentParsedItem]?
    public var rejected: [AgentRejectedItem]?
    public var needClarification: [AgentClarificationNeedItem]?
    public var questions: [String]?
    public var options: [String]?
    public var pendingClarification: PendingClarification?
    public var unitCorrections: [String]?

    public init(
        status: String = "ready",
        message: String = "",
        thought: String? = nil,
        totalAmount: Double? = nil,
        totalWeightKg: Double? = nil,
        items: [AgentParsedItem]? = nil,
        rejected: [AgentRejectedItem]? = nil,
        needClarification: [AgentClarificationNeedItem]? = nil,
        questions: [String]? = nil,
        options: [String]? = nil,
        pendingClarification: PendingClarification? = nil,
        unitCorrections: [String]? = nil
    ) {
        self.status = status
        self.message = message
        self.thought = thought
        self.totalAmount = totalAmount
        self.totalWeightKg = totalWeightKg
        self.items = items
        self.rejected = rejected
        self.needClarification = needClarification
        self.questions = questions
        self.options = options
        self.pendingClarification = pendingClarification
        self.unitCorrections = unitCorrections
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        // Status (defaults to "ready")
        var resStatus = "ready"
        if let k = DynamicCodingKeys(stringValue: "status"),
           let s = try? container.decode(String.self, forKey: k) {
            resStatus = s
        }
        self.status = resStatus

        // Message (defaults to empty)
        var resMessage = ""
        for keyStr in ["message", "response", "msg", "text"] {
            if let k = DynamicCodingKeys(stringValue: keyStr),
               let m = try? container.decode(String.self, forKey: k) {
                resMessage = m
                break
            }
        }
        self.message = resMessage

        // Thought
        var resThought: String? = nil
        for keyStr in ["thought", "reasoning", "explanation"] {
            if let k = DynamicCodingKeys(stringValue: keyStr),
               let t = try? container.decode(String.self, forKey: k) {
                resThought = t
                break
            }
        }
        self.thought = resThought

        // Items & Container (supports unified { verified: {}, rejected: {}, needClarification: {} } objects, keyed dictionaries, or flat arrays)
        var resItems: [AgentParsedItem]? = nil
        var resRejected: [AgentRejectedItem]? = nil
        var resNeedClarification: [AgentClarificationNeedItem]? = nil

        for keyStr in ["items", "products", "order", "billedItems", "item_list"] {
            guard let k = DynamicCodingKeys(stringValue: keyStr) else { continue }
            if let nestedContainer = try? container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: k) {
                // Decode verified (supports object-keyed dictionary, single object, array, or empty)
                for vKey in ["verified", "accepted", "ready", "items", "billed"] {
                    if let vk = DynamicCodingKeys(stringValue: vKey),
                       let items = Self.decodeVerifiedItems(from: nestedContainer, key: vk) {
                        resItems = items
                        break
                    }
                }
                // Decode rejected (supports object-keyed dictionary, single object, string dict, array)
                for rKey in ["rejected", "unlisted", "not_found", "declined"] {
                    if let rk = DynamicCodingKeys(stringValue: rKey),
                       let items = Self.decodeRejectedItems(from: nestedContainer, key: rk) {
                        resRejected = items
                        break
                    }
                }
                // Decode needClarification (supports object-keyed dictionary, single object, array)
                for cKey in ["needClarification", "need_clarification", "needsClarification", "needs_clarification", "clarification", "clarifications"] {
                    if let ck = DynamicCodingKeys(stringValue: cKey),
                       let items = Self.decodeClarificationItems(from: nestedContainer, key: ck) {
                        resNeedClarification = items
                        break
                    }
                }
                break
            } else if let flatArr = try? container.decode([AgentParsedItem].self, forKey: k) {
                resItems = flatArr
                break
            }
        }

        // Also check root-level rejected and needClarification in case model placed them at root
        if resRejected == nil {
            for rKey in ["rejected", "unlisted", "not_found"] {
                if let k = DynamicCodingKeys(stringValue: rKey),
                   let items = Self.decodeRejectedItems(from: container, key: k) {
                    resRejected = items
                    break
                }
            }
        }
        if resNeedClarification == nil {
            for cKey in ["needClarification", "need_clarification", "needsClarification", "needs_clarification"] {
                if let k = DynamicCodingKeys(stringValue: cKey),
                   let items = Self.decodeClarificationItems(from: container, key: k) {
                    resNeedClarification = items
                    break
                }
            }
        }

        self.items = resItems
        self.rejected = resRejected
        self.needClarification = resNeedClarification

        // Totals & Clarifications
        if let k = DynamicCodingKeys(stringValue: "totalAmount") {
            self.totalAmount = try? container.decodeIfPresent(Double.self, forKey: k)
        }
        if let k = DynamicCodingKeys(stringValue: "totalWeightKg") {
            self.totalWeightKg = try? container.decodeIfPresent(Double.self, forKey: k)
        }
        if let k = DynamicCodingKeys(stringValue: "questions") {
            self.questions = try? container.decodeIfPresent([String].self, forKey: k)
        }

        var resOptions: [String]? = nil
        for keyStr in ["options", "candidates", "candidateNames", "choices"] {
            if let k = DynamicCodingKeys(stringValue: keyStr),
               let arr = try? container.decode([String].self, forKey: k) {
                resOptions = arr
                break
            }
        }
        self.options = resOptions

        var resClarification = try? container.decodeIfPresent(PendingClarification.self, forKey: DynamicCodingKeys(stringValue: "pendingClarification")!)

        // Auto-populate clarification from needClarification
        if let needs = resNeedClarification, !needs.isEmpty {
            resStatus = "needs_clarification"
            var allCandidateOptions: [String] = []
            for n in needs {
                allCandidateOptions.append(contentsOf: n.options)
            }
            if resOptions == nil || resOptions!.isEmpty {
                resOptions = allCandidateOptions
                self.options = resOptions
            }
            if resClarification == nil {
                let allQueries = needs.map { $0.item }.joined(separator: ", ")
                let firstNeed = needs[0]
                resClarification = PendingClarification(
                    query: allQueries,
                    quantity: firstNeed.quantity,
                    unit: firstNeed.unit,
                    candidateNames: allCandidateOptions
                )
            }
        } else if (resItems == nil || resItems!.isEmpty) && (resRejected?.isEmpty == false) {
            resStatus = "not_found"
        }

        if resClarification == nil, let opts = resOptions, !opts.isEmpty {
            resClarification = PendingClarification(
                query: resMessage,
                quantity: 1.0,
                unit: "pc",
                candidateNames: opts
            )
        } else if let opts = resOptions, !opts.isEmpty, resClarification?.candidateNames.isEmpty == true {
            resClarification?.candidateNames = opts
        }
        self.pendingClarification = resClarification
        self.status = resStatus

        if let k = DynamicCodingKeys(stringValue: "unitCorrections") {
            self.unitCorrections = try? container.decodeIfPresent([String].self, forKey: k)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        try container.encode(status, forKey: DynamicCodingKeys(stringValue: "status")!)
        try container.encode(message, forKey: DynamicCodingKeys(stringValue: "message")!)
        if let thought = thought {
            try container.encode(thought, forKey: DynamicCodingKeys(stringValue: "thought")!)
        }

        var itemsContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(stringValue: "items")!)

        // Encode verified as dictionary object
        if let items = items, !items.isEmpty {
            var verifiedContainer = itemsContainer.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(stringValue: "verified")!)
            for itm in items {
                try verifiedContainer.encode(itm, forKey: DynamicCodingKeys(stringValue: itm.itemName)!)
            }
        } else {
            _ = itemsContainer.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(stringValue: "verified")!)
        }

        // Encode rejected as dictionary object
        if let rejected = rejected, !rejected.isEmpty {
            var rejectedContainer = itemsContainer.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(stringValue: "rejected")!)
            for rej in rejected {
                try rejectedContainer.encode(rej, forKey: DynamicCodingKeys(stringValue: rej.item)!)
            }
        } else {
            _ = itemsContainer.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(stringValue: "rejected")!)
        }

        // Encode needClarification as dictionary object
        if let needClarification = needClarification, !needClarification.isEmpty {
            var clarContainer = itemsContainer.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(stringValue: "needClarification")!)
            for clar in needClarification {
                try clarContainer.encode(clar, forKey: DynamicCodingKeys(stringValue: clar.item)!)
            }
        } else {
            _ = itemsContainer.nestedContainer(keyedBy: DynamicCodingKeys.self, forKey: DynamicCodingKeys(stringValue: "needClarification")!)
        }

        if let totalAmount = totalAmount {
            try container.encode(totalAmount, forKey: DynamicCodingKeys(stringValue: "totalAmount")!)
        }
        if let totalWeightKg = totalWeightKg {
            try container.encode(totalWeightKg, forKey: DynamicCodingKeys(stringValue: "totalWeightKg")!)
        }
        if let questions = questions {
            try container.encode(questions, forKey: DynamicCodingKeys(stringValue: "questions")!)
        }
        if let options = options {
            try container.encode(options, forKey: DynamicCodingKeys(stringValue: "options")!)
        }
        if let pendingClarification = pendingClarification {
            try container.encode(pendingClarification, forKey: DynamicCodingKeys(stringValue: "pendingClarification")!)
        }
        if let unitCorrections = unitCorrections {
            try container.encode(unitCorrections, forKey: DynamicCodingKeys(stringValue: "unitCorrections")!)
        }
    }

    private static func decodeVerifiedItems(from container: KeyedDecodingContainer<DynamicCodingKeys>, key: DynamicCodingKeys) -> [AgentParsedItem]? {
        // 1. Array of items
        if let arr = try? container.decode([AgentParsedItem].self, forKey: key) {
            return arr
        }
        // 2. Dictionary of [itemName: AgentParsedItem]
        if let dict = try? container.decode([String: AgentParsedItem].self, forKey: key) {
            var items: [AgentParsedItem] = []
            for (name, var itm) in dict {
                if itm.itemName == "Unknown Item" || itm.itemName.isEmpty {
                    itm.itemName = name
                }
                items.append(itm)
            }
            return items
        }
        // 3. Dictionary of [itemName: Double] (e.g. {"Potato": 2.0, "Tomato": 1.0})
        if let dblDict = try? container.decode([String: Double].self, forKey: key) {
            return dblDict.map { AgentParsedItem(itemName: $0.key, quantity: $0.value, unit: "pc") }
        }
        // 4. Dictionary of [itemName: Int]
        if let intDict = try? container.decode([String: Int].self, forKey: key) {
            return intDict.map { AgentParsedItem(itemName: $0.key, quantity: Double($0.value), unit: "pc") }
        }
        // 5. Dictionary of [itemName: String] (e.g. {"Potato": "2kg", "Tomato": "1kg"})
        if let strDict = try? container.decode([String: String].self, forKey: key) {
            var items: [AgentParsedItem] = []
            for (name, val) in strDict {
                let (q, u) = parseQuantityAndUnit(val)
                items.append(AgentParsedItem(itemName: name, quantity: q, unit: u))
            }
            return items
        }
        // 6. Single AgentParsedItem object
        if let single = try? container.decode(AgentParsedItem.self, forKey: key) {
            return [single]
        }
        return nil
    }

    private static func decodeRejectedItems(from container: KeyedDecodingContainer<DynamicCodingKeys>, key: DynamicCodingKeys) -> [AgentRejectedItem]? {
        // 1. Array of AgentRejectedItem
        if let arr = try? container.decode([AgentRejectedItem].self, forKey: key) {
            return arr
        }
        // 2. Array of Strings
        if let arr = try? container.decode([String].self, forKey: key) {
            return arr.map { AgentRejectedItem(item: $0) }
        }
        // 3. Dictionary of [itemName: AgentRejectedItem]
        if let dict = try? container.decode([String: AgentRejectedItem].self, forKey: key) {
            var items: [AgentRejectedItem] = []
            for (name, var itm) in dict {
                if itm.item.isEmpty {
                    itm.item = name
                }
                items.append(itm)
            }
            return items
        }
        // 4. Dictionary of [itemName: reasonString]
        if let dict = try? container.decode([String: String].self, forKey: key) {
            return dict.map { AgentRejectedItem(item: $0.key, reason: $0.value) }
        }
        // 5. Single AgentRejectedItem object
        if let single = try? container.decode(AgentRejectedItem.self, forKey: key) {
            return [single]
        }
        return nil
    }

    private static func decodeClarificationItems(from container: KeyedDecodingContainer<DynamicCodingKeys>, key: DynamicCodingKeys) -> [AgentClarificationNeedItem]? {
        // 1. Array of AgentClarificationNeedItem
        if let arr = try? container.decode([AgentClarificationNeedItem].self, forKey: key) {
            return arr
        }
        // 2. Dictionary of [itemName: AgentClarificationNeedItem]
        if let dict = try? container.decode([String: AgentClarificationNeedItem].self, forKey: key) {
            var items: [AgentClarificationNeedItem] = []
            for (name, var itm) in dict {
                if itm.item.isEmpty {
                    itm.item = name
                }
                items.append(itm)
            }
            return items
        }
        // 3. Dictionary of [itemName: [String]] (options array)
        if let dict = try? container.decode([String: [String]].self, forKey: key) {
            return dict.map {
                AgentClarificationNeedItem(item: $0.key, quantity: 1.0, unit: "pc", options: $0.value)
            }
        }
        // 4. Single AgentClarificationNeedItem object
        if let single = try? container.decode(AgentClarificationNeedItem.self, forKey: key) {
            return [single]
        }
        return nil
    }

    private static func parseQuantityAndUnit(_ str: String) -> (Double, String) {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let regex = try? NSRegularExpression(pattern: #"^([0-9]+(?:\.[0-9]+)?)\s*([a-zA-Z]*)$"#)
        if let match = regex?.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.utf16.count)) {
            var qty = 1.0
            var unit = "pc"
            if let numRange = Range(match.range(at: 1), in: trimmed), let num = Double(trimmed[numRange]) {
                qty = num
            }
            if match.range(at: 2).location != NSNotFound, let uRange = Range(match.range(at: 2), in: trimmed) {
                let u = String(trimmed[uRange]).trimmingCharacters(in: .whitespaces)
                if !u.isEmpty { unit = u }
            }
            return (qty, unit)
        }
        if let num = Double(trimmed) { return (num, "pc") }
        return (1.0, "pc")
    }
}
