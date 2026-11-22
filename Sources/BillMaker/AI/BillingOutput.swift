import Foundation

// MARK: - AI Layer Spec Output Models

/// Primary single-stage output format produced by BillingSpec via AgentAtom.
/// Clean Apple-formatted Codable model with no baggage or knowledge of previous versions.
public struct BillingOutput: Codable, Sendable {
    public var analysis: String
    public var message: String
    public var items: BillingItemsContainer

    public var thought: String {
        get { analysis }
        set { analysis = newValue }
    }

    public init(
        thought: String = "",
        message: String = "",
        items: BillingItemsContainer = BillingItemsContainer()
    ) {
        self.analysis = thought
        self.message = message
        self.items = items
    }

    public init(
        analysis: String,
        message: String = "",
        items: BillingItemsContainer = BillingItemsContainer()
    ) {
        self.analysis = analysis
        self.message = message
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case analysis
        case thought
        case message
        case items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.analysis = (try? container.decodeIfPresent(String.self, forKey: .analysis))
            ?? (try? container.decodeIfPresent(String.self, forKey: .thought))
            ?? ""
        self.message = (try? container.decodeIfPresent(String.self, forKey: .message)) ?? ""
        self.items = (try container.decodeIfPresent(BillingItemsContainer.self, forKey: .items))
            ?? BillingItemsContainer()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(analysis, forKey: .analysis)
        try container.encode(message, forKey: .message)
        try container.encode(items, forKey: .items)
    }
}

// MARK: - 3 Output Item Categories Container

public struct BillingItemsContainer: Codable, Sendable {
    public var verified: [BillingVerifiedItem]
    public var needClarification: [BillingClarificationItem]
    public var rejected: [BillingRejectedItem]

    public init(
        verified: [BillingVerifiedItem] = [],
        rejected: [BillingRejectedItem] = [],
        needClarification: [BillingClarificationItem] = []
    ) {
        self.verified = verified
        self.rejected = rejected
        self.needClarification = needClarification
    }

    enum CodingKeys: String, CodingKey {
        case verified, needClarification, rejected
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.verified = (try? container.decodeIfPresent([BillingVerifiedItem].self, forKey: .verified)) ?? []
        self.needClarification = (try? container.decodeIfPresent([BillingClarificationItem].self, forKey: .needClarification)) ?? []
        self.rejected = (try? container.decodeIfPresent([BillingRejectedItem].self, forKey: .rejected)) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(verified, forKey: .verified)
        try container.encode(needClarification, forKey: .needClarification)
        try container.encode(rejected, forKey: .rejected)
    }
}

// MARK: - 1. Verified Item Model

public struct BillingVerifiedItem: Codable, Sendable {
    public var id: String
    public var name: String
    public var quantity: Double
    public var unit: String
    public var unitPrice: Double

    public init(
        id: String = "",
        name: String = "",
        quantity: Double = 1.0,
        unit: String = "pc",
        unitPrice: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
    }

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, unitPrice
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        self.quantity = (try? container.decodeIfPresent(Double.self, forKey: .quantity)) ?? 1.0
        self.unit = (try? container.decodeIfPresent(String.self, forKey: .unit)) ?? "pc"
        self.unitPrice = (try? container.decodeIfPresent(Double.self, forKey: .unitPrice)) ?? 0.0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unit, forKey: .unit)
        try container.encode(unitPrice, forKey: .unitPrice)
    }
}

// MARK: - 2. Need Clarification Item Model

public struct BillingClarificationItem: Codable, Sendable {
    public var name: String
    public var reason: String
    public var candidateOptions: [String]
    public var quantity: Double
    public var unit: String

    public init(
        name: String = "",
        reason: String = "",
        candidateOptions: [String] = [],
        quantity: Double = 1.0,
        unit: String = "",
        options: [String]? = nil
    ) {
        self.name = name
        self.reason = reason
        self.candidateOptions = options ?? candidateOptions
        self.quantity = quantity
        self.unit = unit
    }

    public init(
        name: String = "",
        quantity: Double? = nil,
        unit: String? = nil,
        options: [String] = [],
        reason: String = ""
    ) {
        self.name = name
        self.reason = reason
        self.candidateOptions = options
        self.quantity = quantity ?? 1.0
        self.unit = unit ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case name, reason, candidateOptions, options, quantity, unit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        self.reason = (try? container.decodeIfPresent(String.self, forKey: .reason)) ?? "Clarification required"
        self.candidateOptions = (try? container.decodeIfPresent([String].self, forKey: .candidateOptions))
            ?? (try? container.decodeIfPresent([String].self, forKey: .options))
            ?? []
        self.quantity = (try? container.decodeIfPresent(Double.self, forKey: .quantity)) ?? 1.0
        self.unit = (try? container.decodeIfPresent(String.self, forKey: .unit)) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(reason, forKey: .reason)
        try container.encode(candidateOptions, forKey: .candidateOptions)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unit, forKey: .unit)
    }
}

// MARK: - 3. Rejected Item Model

public struct BillingRejectedItem: Codable, Sendable {
    public var name: String
    public var reason: String

    public init(name: String = "", reason: String = "Not in store catalog") {
        self.name = name
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case name, reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        self.reason = (try? container.decodeIfPresent(String.self, forKey: .reason)) ?? "Not in store catalog"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(reason, forKey: .reason)
    }
}

// MARK: - Parser & AgentMessage Conversion

extension BillingOutput {
    /// Resiliently parses raw model output string into a structured `AgentMessage`.
    public static func parse(
        content: String,
        catalog: [Item],
        settings: AppSettings,
        userInput: String? = nil
    ) -> AgentMessage {
        var cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip model turn wrappers if present
        if cleanContent.contains("<start_of_turn>model") {
            cleanContent = cleanContent.replacingOccurrences(of: "<start_of_turn>model", with: "")
                                       .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if cleanContent.contains("<end_of_turn>") {
            cleanContent = cleanContent.replacingOccurrences(of: "<end_of_turn>", with: "")
                                       .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract thought tags
        var extractedThought: String? = nil
        if let startTag = cleanContent.range(of: "<thought>"),
           let endTag = cleanContent.range(of: "</thought>") {
            let thoughtRange = startTag.upperBound..<endTag.lowerBound
            extractedThought = String(cleanContent[thoughtRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            cleanContent.removeSubrange(startTag.lowerBound..<endTag.upperBound)
            cleanContent = cleanContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract JSON candidate block
        guard let rawJson = extractJSONBlock(from: cleanContent) else {
            // Fallback when no valid JSON is extracted
            let thoughtDesc = extractedThought ?? "Model output contained no valid JSON payload."
            ParsingDiagnosticsLogger.shared.log(
                userInput: userInput ?? "",
                rawLLMOutput: content,
                extractedJson: nil,
                outcome: .missingJson,
                rootCauseAnalysis: "Model output contained no valid JSON payload.",
                executionMode: "AgentAtom",
                itemsParsedCount: 0
            )

            return AgentMessage(
                role: .agent,
                text: cleanContent.isEmpty ? "Sorry, I could not parse your order. Please try again." : cleanContent,
                thoughtProcess: thoughtDesc,
                rawJsonOutput: nil,
                status: .error
            )
        }

        // Attempt syntax repair for trailing commas or unclosed brackets
        let (repairedJson, wasRepaired) = repairCorruptedJsonSyntax(rawJson)
        var decodedOutput: BillingOutput? = nil
        var decodeError: String? = nil

        // Try direct or repaired decode
        if let data = repairedJson.data(using: .utf8) {
            if let output = try? JSONDecoder().decode(BillingOutput.self, from: data) {
                decodedOutput = output
            } else if let loose = parseLooseDictionary(jsonData: data) {
                decodedOutput = loose
            }
        }

        if decodedOutput == nil, let originalData = rawJson.data(using: .utf8) {
            do {
                decodedOutput = try JSONDecoder().decode(BillingOutput.self, from: originalData)
            } catch {
                decodeError = error.localizedDescription
                decodedOutput = parseLooseDictionary(jsonData: originalData)
            }
        }

        guard var output = decodedOutput else {
            // Fatal syntax corruption
            let rootCause = "JSON syntax corrupted: not valid JSON - \(decodeError ?? "invalid structure")"
            ParsingDiagnosticsLogger.shared.log(
                userInput: userInput ?? "",
                rawLLMOutput: content,
                extractedJson: rawJson,
                outcome: .decodingError,
                rootCauseAnalysis: rootCause,
                executionMode: "AgentAtom",
                itemsParsedCount: 0
            )

            return AgentMessage(
                role: .agent,
                text: "Could not decode order details.",
                thoughtProcess: extractedThought ?? rootCause,
                rawJsonOutput: rawJson,
                status: .error
            )
        }

        // Apply Guardian business rules reconciliation
        output.reconcileWithCatalog(catalog: catalog, userInput: userInput)

        let agentMessage = output.toAgentMessage(
            catalog: catalog,
            settings: settings,
            rawJson: rawJson,
            extractedThought: extractedThought,
            userInput: userInput
        )

        // Telemetry logging
        let outcome: ParsingOutcome = {
            if wasRepaired { return .autoRescued }
            if agentMessage.status == .needsClarification { return .clarification }
            if agentMessage.status == .error { return .decodingError }
            return .success
        }()

        let analysis: String = {
            if wasRepaired {
                return "Auto-repaired corrupted JSON syntax and successfully parsed."
            }
            if agentMessage.status == .needsClarification {
                return "Clarification requested: \"\(agentMessage.text)\""
            }
            return "Successfully parsed \(agentMessage.parsedItems?.count ?? 0) item(s)."
        }()

        ParsingDiagnosticsLogger.shared.log(
            userInput: userInput ?? "",
            rawLLMOutput: content,
            extractedJson: rawJson,
            outcome: outcome,
            rootCauseAnalysis: analysis,
            executionMode: "AgentAtom",
            itemsParsedCount: agentMessage.parsedItems?.count ?? 0
        )

        return agentMessage
    }

    /// Clean catalog hydration & packet divisibility verification:
    /// Enriches verified items with accurate catalog IDs and prices, and enforces that packet items cannot be sold fractionally.
    public mutating func reconcileWithCatalog(catalog: [Item], userInput: String? = nil) {
        // 1. Reconcile verified items for packet indivisibility and hydrate catalog details
        var updatedVerified: [BillingVerifiedItem] = []
        for var v in items.verified {
            if let cat = catalog.first(where: {
                (!v.id.isEmpty && $0.id == v.id) ||
                $0.name.localizedCaseInsensitiveContains(v.name) ||
                v.name.localizedCaseInsensitiveContains($0.name)
            }) {
                if v.id.isEmpty { v.id = cat.id }
                if v.unitPrice == 0 { v.unitPrice = cat.pricePerUnit }
                if v.unit.isEmpty { v.unit = cat.unitType.shortLabel }

                if cat.sellingType == .packet {
                    let isFractional = (v.quantity.truncatingRemainder(dividingBy: 1.0) != 0)
                    let isLooseWeightUnit = (v.unit.lowercased() == "kg" || v.unit.lowercased() == "g" || v.unit.lowercased() == "gram")
                    if isFractional || isLooseWeightUnit {
                        items.needClarification.append(
                            BillingClarificationItem(
                                name: cat.name,
                                reason: "Packet items cannot be sold in loose fractional weight. Please specify number of packets.",
                                candidateOptions: [cat.name],
                                quantity: v.quantity,
                                unit: v.unit
                            )
                        )
                        continue
                    }
                }
            }
            updatedVerified.append(v)
        }
        items.verified = updatedVerified

        // 2. Divisible loose items (e.g. 500g paneer = 0.5kg) in clarification
        var remainingClarification: [BillingClarificationItem] = []
        for clar in items.needClarification {
            let clarLower = clar.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let genericTerms = ["oil", "tel", "packet", "pkt", "item", "grocery", "masala"]
            let isGeneric = genericTerms.contains(clarLower) || clar.candidateOptions.count > 1

            if !isGeneric,
               let looseMatch = catalog.first(where: { $0.sellingType == .loose && $0.name.lowercased() == clarLower }) {
                items.verified.append(
                    BillingVerifiedItem(
                        id: looseMatch.id,
                        name: looseMatch.name,
                        quantity: clar.quantity,
                        unit: !clar.unit.isEmpty ? clar.unit : looseMatch.unitType.shortLabel,
                        unitPrice: looseMatch.pricePerUnit
                    )
                )
                continue
            }
            remainingClarification.append(clar)
        }
        items.needClarification = remainingClarification
    }

    /// Converts the structured `BillingOutput` into an `AgentMessage` for UI display and live bill updating.
    public func toAgentMessage(
        catalog: [Item],
        settings: AppSettings,
        rawJson: String? = nil,
        extractedThought: String? = nil,
        userInput: String? = nil
    ) -> AgentMessage {
        let finalThought = !thought.isEmpty ? thought : (extractedThought ?? "")

        let commonAliases: [String: String] = [
            "aalu": "Potato", "aloo": "Potato",
            "tamatar": "Tomato",
            "pyaaz": "Onion", "pyaj": "Onion", "onion": "Onion",
            "sarso tel": "Mustard Oil", "sarson tel": "Mustard Oil", "sarso": "Mustard Oil", "sarson": "Mustard Oil",
            "surajmukhi": "Sunflower Oil", "surajmukhi tel": "Sunflower Oil",
            "doodh": "Packet Milk", "dudh": "Packet Milk", "loose doodh": "Cow Milk",
            "paneer": "Paneer", "malai paneer": "Paneer",
            "maggi": "Maggi Noodles", "noodles": "Maggi Noodles",
            "atta": "Atta (Wheat Flour)", "gehu atta": "Atta (Wheat Flour)",
            "chawal": "Basmati Rice", "rice": "Basmati Rice",
            "kela": "Banana", "seb": "Apple"
        ]

        // 1. Resolve verified items against catalog
        var resolvedParsedItems: [AgentParsedItem] = []
        for v in items.verified {
            let cleanLower = v.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            // First attempt name / alias match
            var matchedCatalog = catalog.first(where: {
                $0.name.localizedCaseInsensitiveContains(v.name) ||
                v.name.localizedCaseInsensitiveContains($0.name)
            })

            // Fallback to alias
            if matchedCatalog == nil {
                if let canonical = commonAliases[cleanLower] ?? commonAliases.first(where: { cleanLower.contains($0.key) })?.value {
                    matchedCatalog = catalog.first(where: { $0.name.localizedCaseInsensitiveContains(canonical) })
                }
            }

            // Fallback to ID match
            if matchedCatalog == nil {
                matchedCatalog = catalog.first(where: { $0.id == v.id })
            }

            let itemId = (!v.id.isEmpty ? v.id : matchedCatalog?.id)
            let itemName: String = {
                let colloquialHindiAliases: [String: String] = [
                    "aalu": "Potato", "aloo": "Potato",
                    "tamatar": "Tomato",
                    "pyaaz": "Onion", "pyaj": "Onion",
                    "sarso tel": "Mustard Oil", "sarson tel": "Mustard Oil", "sarso": "Mustard Oil", "sarson": "Mustard Oil",
                    "surajmukhi": "Sunflower Oil", "surajmukhi tel": "Sunflower Oil",
                    "doodh": "Packet Milk", "dudh": "Packet Milk",
                    "kela": "Banana", "seb": "Apple"
                ]
                if let canonical = colloquialHindiAliases[cleanLower] {
                    return matchedCatalog?.name ?? canonical
                }
                return (!v.name.isEmpty ? v.name : (matchedCatalog?.name ?? ""))
            }()
            let unitPrice = v.unitPrice > 0 ? v.unitPrice : (matchedCatalog?.pricePerUnit ?? 0.0)
            let unit = !v.unit.isEmpty ? v.unit : (matchedCatalog?.unitType.shortLabel ?? "pc")

            resolvedParsedItems.append(
                AgentParsedItem(
                    itemId: itemId,
                    itemName: itemName,
                    quantity: v.quantity,
                    unit: unit,
                    unitPrice: unitPrice
                )
            )
        }

        // 2. Compute bill summary if verified items exist
        let billSummary: BillSummary? = resolvedParsedItems.isEmpty ? nil : BillCalculator.computeBill(
            from: resolvedParsedItems,
            catalog: catalog,
            currencySymbol: settings.currencySymbol,
            taxRatePercent: settings.taxRatePercent
        )

        // 3. Determine status and pending clarification
        let status: AgentResponseStatus
        var pendingClarification: PendingClarification? = nil

        if !items.needClarification.isEmpty {
            status = .needsClarification
            let allQueries = items.needClarification.map(\.name).filter { !$0.isEmpty }
            var allCandidates: [String] = []
            for clar in items.needClarification {
                for opt in clar.candidateOptions {
                    if !allCandidates.contains(opt) {
                        allCandidates.append(opt)
                    }
                }
            }

            let firstClar = items.needClarification.first!
            pendingClarification = PendingClarification(
                query: allQueries.joined(separator: ", "),
                reason: firstClar.reason,
                quantity: firstClar.quantity,
                unit: firstClar.unit,
                candidateNames: allCandidates
            )
        } else if !resolvedParsedItems.isEmpty {
            status = .ready
        } else if !items.rejected.isEmpty {
            status = .notFound
        } else {
            status = .info
        }

        // 4. Build conversational text
        let responseText: String = {
            let baseText: String
            if status == .needsClarification {
                let clarText = !message.isEmpty ? message : (pendingClarification != nil ? "Did you mean \(pendingClarification!.candidateNames.joined(separator: " or "))?" : "Clarification required.")
                if !resolvedParsedItems.isEmpty {
                    let verifiedDesc = resolvedParsedItems.map { "\($0.quantity.cleanFormatted) \($0.unit) \($0.itemName)" }.joined(separator: ", ")
                    baseText = "Added \(verifiedDesc) to the bill.\n\(clarText)"
                } else {
                    baseText = clarText
                }
            } else if !resolvedParsedItems.isEmpty {
                if !message.isEmpty {
                    baseText = message
                } else {
                    let itemNames = resolvedParsedItems.map { "\($0.quantity.cleanFormatted) \($0.unit) \($0.itemName)" }.joined(separator: ", ")
                    baseText = "Added \(itemNames) to the bill."
                }
            } else if let firstRejected = items.rejected.first {
                if !message.isEmpty && message != "Items processed." && message != "Order processed." {
                    baseText = message
                } else {
                    baseText = "'\(firstRejected.name)' is not available in our store catalog."
                }
            } else {
                baseText = !message.isEmpty ? message : "Order processed."
            }

            if !items.rejected.isEmpty && !resolvedParsedItems.isEmpty {
                let rejectedNames = items.rejected.map(\.name).joined(separator: ", ")
                return "\(baseText) (Note: Requested item(s) '\(rejectedNames)' not in store catalog and excluded from bill.)"
            }
            return baseText
        }()

        return AgentMessage(
            role: .agent,
            text: responseText,
            thoughtProcess: !finalThought.isEmpty ? finalThought : nil,
            rawJsonOutput: rawJson,
            status: status,
            billSummary: billSummary,
            parsedItems: resolvedParsedItems.isEmpty ? nil : resolvedParsedItems,
            pendingClarification: pendingClarification,
            canUndo: !resolvedParsedItems.isEmpty
        )
    }

    // MARK: - Internal Extraction Helpers

    public static func extractJSONBlock(from text: String) -> String? {
        // 1. Look for ```json ... ``` code blocks
        if let startFence = text.range(of: "```json") {
            let afterFence = text[startFence.upperBound...]
            if let endFence = afterFence.range(of: "```") {
                return String(afterFence[..<endFence.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return String(afterFence).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 2. Look for any ``` ... ``` code blocks
        if let startFence = text.range(of: "```") {
            let afterFence = text[startFence.upperBound...]
            if let endFence = afterFence.range(of: "```") {
                let candidate = String(afterFence[..<endFence.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if candidate.hasPrefix("{") {
                    return candidate
                }
            } else {
                let candidate = String(afterFence).trimmingCharacters(in: .whitespacesAndNewlines)
                if candidate.hasPrefix("{") {
                    return candidate
                }
            }
        }

        // 3. Scan for outer outermost curly braces
        if let firstBrace = text.firstIndex(of: "{") {
            if let lastBrace = text.lastIndex(of: "}"), firstBrace <= lastBrace {
                return String(text[firstBrace...lastBrace])
            } else {
                return String(text[firstBrace...])
            }
        }

        return nil
    }

    private static func repairCorruptedJsonSyntax(_ text: String) -> (String, Bool) {
        var repaired = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = repaired

        // Trailing commas in arrays or objects: ,] or ,}
        let trailingCommaPattern = #",\s*([\]\}])"#
        if let regex = try? NSRegularExpression(pattern: trailingCommaPattern, options: []) {
            let range = NSRange(location: 0, length: repaired.utf16.count)
            repaired = regex.stringByReplacingMatches(in: repaired, options: [], range: range, withTemplate: "$1")
        }

        // Python boolean replacements
        let pythonReplacements = [
            (#":\s*True\b"#, ": true"),
            (#":\s*False\b"#, ": false"),
            (#":\s*None\b"#, ": null")
        ]
        for (pattern, template) in pythonReplacements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: repaired.utf16.count)
                repaired = regex.stringByReplacingMatches(in: repaired, options: [], range: range, withTemplate: template)
            }
        }

        // Bracket stack tracking for truncated braces
        var bracketStack: [Character] = []
        var inString = false
        var isEscaped = false

        for char in repaired {
            if char == "\\" && !isEscaped {
                isEscaped = true
                continue
            }
            if char == "\"" && !isEscaped {
                inString.toggle()
            } else if !inString {
                if char == "{" {
                    bracketStack.append("}")
                } else if char == "[" {
                    bracketStack.append("]")
                } else if char == "}" || char == "]" {
                    if let last = bracketStack.last, last == char {
                        bracketStack.removeLast()
                    }
                }
            }
            isEscaped = false
        }

        if inString {
            repaired.append("\"")
        }
        while let closing = bracketStack.popLast() {
            repaired.append(closing)
        }

        return (repaired, repaired != original)
    }

    private static func parseLooseDictionary(jsonData: Data) -> BillingOutput? {
        guard let dict = (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any] else {
            return nil
        }

        let thought = dict["thought"] as? String ?? ""
        let message = dict["message"] as? String ?? ""

        var verified: [BillingVerifiedItem] = []
        var rejected: [BillingRejectedItem] = []
        var clarification: [BillingClarificationItem] = []

        let itemsDict: [String: Any]
        if let explicitDict = dict["items"] as? [String: Any] {
            itemsDict = explicitDict
        } else if dict["items"] == nil {
            itemsDict = dict
        } else if let arrayList = dict["items"] as? [[String: Any]] {
            itemsDict = ["verified": arrayList]
        } else {
            // dict["items"] is present but invalid type (e.g. string "not-an-array")
            return nil
        }

        if let vList = itemsDict["verified"] as? [[String: Any]] {
            for v in vList {
                let id = "\(v["id"] ?? "")"
                let name = v["name"] as? String ?? ""
                let qty = (v["quantity"] as? NSNumber)?.doubleValue ?? 1.0
                let unit = v["unit"] as? String ?? "pc"
                let price = (v["unitPrice"] as? NSNumber)?.doubleValue ?? 0.0
                verified.append(BillingVerifiedItem(id: id, name: name, quantity: qty, unit: unit, unitPrice: price))
            }
        }

        if let rList = itemsDict["rejected"] as? [[String: Any]] {
            for r in rList {
                let name = r["name"] as? String ?? ""
                let reason = r["reason"] as? String ?? "Not in store catalog"
                rejected.append(BillingRejectedItem(name: name, reason: reason))
            }
        }

        if let cList = itemsDict["needClarification"] as? [[String: Any]] {
            for c in cList {
                let name = c["name"] as? String ?? ""
                let reason = c["reason"] as? String ?? "Clarification required"
                let opts = (c["candidateOptions"] as? [String]) ?? (c["options"] as? [String]) ?? []
                let qty = (c["quantity"] as? NSNumber)?.doubleValue ?? 1.0
                let unit = c["unit"] as? String ?? ""
                clarification.append(BillingClarificationItem(name: name, reason: reason, candidateOptions: opts, quantity: qty, unit: unit))
            }
        }

        return BillingOutput(
            thought: thought,
            message: message,
            items: BillingItemsContainer(verified: verified, rejected: rejected, needClarification: clarification)
        )
    }
}

// MARK: - CustomDebugStringConvertible Conformance

extension BillingOutput: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        BillingOutput(
          thought: "\(thought)",
          message: "\(message)",
          verified: [\(items.verified.map { "\($0.name) (\($0.quantity)\($0.unit))" }.joined(separator: ", "))],
          needClarification: [\(items.needClarification.map(\.name).joined(separator: ", "))],
          rejected: [\(items.rejected.map(\.name).joined(separator: ", "))]
        )
        """
    }
}

extension BillingItemsContainer: CustomDebugStringConvertible {
    public var debugDescription: String {
        "BillingItemsContainer(verified: \(verified.count), needClarification: \(needClarification.count), rejected: \(rejected.count))"
    }
}

extension BillingVerifiedItem: CustomDebugStringConvertible {
    public var debugDescription: String {
        "BillingVerifiedItem(id: \(id), name: \(name), qty: \(quantity) \(unit), price: \(unitPrice))"
    }
}

extension BillingClarificationItem: CustomDebugStringConvertible {
    public var debugDescription: String {
        "BillingClarificationItem(name: \(name), reason: \(reason), options: \(candidateOptions))"
    }
}

extension BillingRejectedItem: CustomDebugStringConvertible {
    public var debugDescription: String {
        "BillingRejectedItem(name: \(name), reason: \(reason))"
    }
}
