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

// MARK: - Core AI Parsing Engine (formerly LLMResponseParser)
public typealias LLMResponseParser = BillingOutput

extension BillingOutput {
    /// Parses the raw string generated by the AI into an `AgentMessage`, logging full diagnostics.
    public static func parse(
        content: String,
        catalog: [Item],
        settings: AppSettings,
        userInput: String = ""
    ) -> AgentMessage {
        var cleanContent = content
            .replacingOccurrences(of: "<start_of_turn>model", with: "")
            .replacingOccurrences(of: "<start_of_turn>", with: "")
            .replacingOccurrences(of: "<end_of_turn>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var thought: String? = nil

        // 1. Extract thought process enclosed in <thought> or <thinking> tags
        if let thoughtStart = cleanContent.range(of: "<thought>"),
           let thoughtEnd = cleanContent.range(of: "</thought>") {
            let thoughtSubstr = cleanContent[thoughtStart.upperBound..<thoughtEnd.lowerBound]
            thought = String(thoughtSubstr).trimmingCharacters(in: .whitespacesAndNewlines)
            cleanContent.removeSubrange(thoughtStart.lowerBound..<thoughtEnd.upperBound)
        } else if let thoughtStart = cleanContent.range(of: "<thinking>"),
                  let thoughtEnd = cleanContent.range(of: "</thinking>") {
            let thoughtSubstr = cleanContent[thoughtStart.upperBound..<thoughtEnd.lowerBound]
            thought = String(thoughtSubstr).trimmingCharacters(in: .whitespacesAndNewlines)
            cleanContent.removeSubrange(thoughtStart.lowerBound..<thoughtEnd.upperBound)
        }

        // 2. Extract structured JSON payload
        var extractedJson: String? = nil
        var parsedPayload: AgentJsonPayload? = nil
        var lastDecodingError: String? = nil
        var wasSyntaxAutoRepaired = false

        let jsonCandidates = extractJsonCandidates(from: cleanContent)
        for candidate in jsonCandidates {
            let (payload, errorDesc, wasRepaired) = decodePayload(from: candidate)
            if let p = payload {
                extractedJson = candidate
                parsedPayload = p
                wasSyntaxAutoRepaired = wasRepaired
                break
            } else if let err = errorDesc {
                lastDecodingError = err
                extractedJson = candidate
            }
        }

        // 3. Strict Requirement: Output from LLM must be valid JSON; missing JSON is an error
        guard var payload = parsedPayload else {
            let rootCause = lastDecodingError ?? "No valid JSON structure or code fence found in model output."
            ParsingDiagnosticsLogger.shared.log(
                userInput: userInput,
                rawLLMOutput: content,
                extractedJson: extractedJson,
                outcome: lastDecodingError != nil ? .decodingError : .missingJson,
                rootCauseAnalysis: rootCause,
                executionMode: "AgentAtom",
                itemsParsedCount: 0
            )

            return AgentMessage(
                role: .agent,
                text: "Error: AI response did not contain valid structured JSON. Please re-enter the items.",
                thoughtProcess: thought ?? rootCause,
                rawJsonOutput: extractedJson,
                status: .error,
                canUndo: false
            )
        }

        // Guardian Business Rules: Reconcile payload against store catalog & unit divisibility
        reconcilePayloadWithBusinessRules(payload: &payload, catalog: catalog, userInput: userInput)

        // 3a. Item Not Found: Status "not_found", or payload contains rejected items with empty verified
        let hasVerifiedItems = !(payload.items?.isEmpty ?? true)
        let hasRejectedItems = !(payload.rejected?.isEmpty ?? true)
        let hasClarificationItems = !(payload.needClarification?.isEmpty ?? true)

        let isNotFound = payload.status == "not_found"
            || payload.status == "item_not_found"
            || (!hasVerifiedItems && hasRejectedItems)
            || (payload.items?.isEmpty == true && (
                payload.message.localizedCaseInsensitiveContains("not found") ||
                payload.message.localizedCaseInsensitiveContains("not available") ||
                payload.message.localizedCaseInsensitiveContains("not in store") ||
                payload.message.localizedCaseInsensitiveContains("not in the catalog") ||
                payload.message.localizedCaseInsensitiveContains("not in catalog") ||
                payload.message.localizedCaseInsensitiveContains("no match found") ||
                payload.message.localizedCaseInsensitiveContains("no matching item")
            ))

        if isNotFound {
            let msg: String
            if !payload.message.isEmpty {
                msg = payload.message
            } else if let firstRej = payload.rejected?.first {
                let reason = firstRej.reason.map { " (\($0))" } ?? ""
                msg = "No match found. Item '\(firstRej.item)'\(reason) was not found in the store catalog."
            } else {
                msg = "No match found. Item not found in the store catalog."
            }
            let thoughtDesc = thought ?? payload.thought ?? "Requested item is not available in the store catalog."

            ParsingDiagnosticsLogger.shared.log(
                userInput: userInput,
                rawLLMOutput: content,
                extractedJson: extractedJson,
                outcome: .clarification,
                rootCauseAnalysis: "Item not found in catalog: \"\(msg)\"",
                executionMode: "AgentAtom",
                itemsParsedCount: 0
            )

            return AgentMessage(
                role: .agent,
                text: msg,
                thoughtProcess: thoughtDesc,
                rawJsonOutput: extractedJson,
                status: .notFound,
                canUndo: false
            )
        }

        // 3b. Clarification check: Status "needs_clarification", or needClarification present with empty verified, or empty items with a clarifying question/confirmation
        let isClarificationRequest = payload.status == "needs_clarification"
            || (!hasVerifiedItems && hasClarificationItems)
            || (payload.items?.isEmpty == true && (
                payload.message.contains("?") ||
                payload.message.localizedCaseInsensitiveContains("confirm") ||
                payload.message.localizedCaseInsensitiveContains("did you mean") ||
                payload.message.localizedCaseInsensitiveContains("which") ||
                payload.message.localizedCaseInsensitiveContains("please clarify")
            ))

        if isClarificationRequest {
            // Check if user input already uniquely matches one of the candidate items or catalog items
            let cleanUser = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let specificMatches = catalog.filter { cat in
                !cleanUser.isEmpty && (
                    cleanUser.localizedCaseInsensitiveContains(cat.name) ||
                    cat.name.localizedCaseInsensitiveContains(cleanUser) ||
                    ItemCatalogMatcher.aliases(for: cat.name).contains { alias in
                        alias.count >= 4 && cleanUser.localizedCaseInsensitiveContains(alias)
                    }
                )
            }

            // If user's input explicitly matches exactly ONE catalog item and is not a generic query (like "oil" or "tel"),
            // DO NOT repeat the clarification! Resolve it directly to ready!
            if specificMatches.count == 1, let matched = specificMatches.first, !ItemCatalogMatcher.isGenericOilQuery(cleanUser) {
                let qty = payload.pendingClarification?.quantity ?? 1.0
                let unit = payload.pendingClarification?.unit.isEmpty == false
                    ? payload.pendingClarification!.unit
                    : matched.unitType.shortLabel

                var unitPrice = matched.pricePerUnit
                if let customPrice = ItemCatalogMatcher.extractExplicitPrice(for: matched.name, from: userInput) {
                    unitPrice = customPrice
                }

                let resolvedItem = AgentParsedItem(
                    itemId: matched.id.uuidString,
                    itemName: matched.name,
                    quantity: qty,
                    unit: unit,
                    unitPrice: unitPrice
                )

                let summary = BillCalculator.computeBill(
                    from: [resolvedItem],
                    catalog: catalog,
                    currencySymbol: settings.currencySymbol,
                    taxRatePercent: settings.taxRatePercent
                )

                ParsingDiagnosticsLogger.shared.log(
                    userInput: userInput,
                    rawLLMOutput: content,
                    extractedJson: extractedJson,
                    outcome: .autoRescued,
                    rootCauseAnalysis: "Auto-resolved clarification because user specified exact catalog item '\(matched.name)'.",
                    executionMode: "AgentAtom",
                    itemsParsedCount: 1
                )

                return AgentMessage(
                    role: .agent,
                    text: "Added \(qty) \(unit) \(matched.name) to the bill.",
                    thoughtProcess: thought ?? "Unambiguous request for '\(matched.name)'; resolved directly without redundant clarification.",
                    rawJsonOutput: extractedJson,
                    status: .ready,
                    billSummary: summary,
                    parsedItems: [resolvedItem],
                    canUndo: true
                )
            }

            var candidateNames: [String] = {
                if let firstNeed = payload.needClarification?.first, !firstNeed.options.isEmpty {
                    return firstNeed.options
                }
                if let existing = payload.pendingClarification?.candidateNames, !existing.isEmpty {
                    return existing
                }
                if let options = payload.options, !options.isEmpty {
                    return options
                }
                return catalog.filter {
                    payload.message.localizedCaseInsensitiveContains($0.name) ||
                    (!userInput.isEmpty && userInput.localizedCaseInsensitiveContains($0.name))
                }.map { $0.name }
            }()

            // If query was generic like "oil" / "tel", ensure available oils in catalog are included
            if ItemCatalogMatcher.isGenericOilQuery(userInput) || ItemCatalogMatcher.isGenericOilQuery(payload.message) {
                let allOils = catalog.filter { $0.name.localizedCaseInsensitiveContains("oil") }.map { $0.name }
                if !allOils.isEmpty {
                    candidateNames = Array(Set(candidateNames + allOils)).sorted()
                }
            }

            let pendingClarification = payload.pendingClarification ?? PendingClarification(
                query: userInput.isEmpty ? payload.message : userInput,
                quantity: 1.0,
                unit: "pc",
                candidateNames: candidateNames
            )

            ParsingDiagnosticsLogger.shared.log(
                userInput: userInput,
                rawLLMOutput: content,
                extractedJson: extractedJson,
                outcome: .clarification,
                rootCauseAnalysis: "Clarification requested: \"\(payload.message)\" (Options: \(candidateNames.joined(separator: ", ")))",
                executionMode: "AgentAtom",
                itemsParsedCount: 0
            )

            let verifiedItems: [AgentParsedItem]? = (payload.items?.isEmpty == false) ? payload.items : nil
            let summary: BillSummary? = {
                if let v = verifiedItems, !v.isEmpty {
                    return BillCalculator.computeBill(
                        from: v,
                        catalog: catalog,
                        currencySymbol: settings.currencySymbol,
                        taxRatePercent: settings.taxRatePercent
                    )
                }
                return nil
            }()

            var messageText = payload.message
            if let verified = verifiedItems, !verified.isEmpty {
                let verifiedDesc = verified.map { "\($0.quantity.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int($0.quantity))" : "\($0.quantity)") \($0.unit) \($0.itemName)" }.joined(separator: ", ")
                if !messageText.localizedCaseInsensitiveContains(verified[0].itemName) {
                    messageText = "Added \(verifiedDesc) to the bill.\n\(messageText)"
                }
            }

            return AgentMessage(
                role: .agent,
                text: messageText,
                thoughtProcess: thought ?? payload.thought ?? "Clarification requested for ambiguous item.",
                rawJsonOutput: extractedJson,
                status: .needsClarification,
                billSummary: summary,
                parsedItems: verifiedItems,
                pendingClarification: pendingClarification,
                canUndo: verifiedItems != nil
            )
        }

        // 3c. Generic Oil Ambiguity Safeguard
        if ItemCatalogMatcher.isGenericOilQuery(userInput) {
            let oilCandidates = catalog.filter { $0.name.localizedCaseInsensitiveContains("oil") }.map { $0.name }
            if !oilCandidates.isEmpty {
                var promptMsg: String
                if oilCandidates.count == 1 {
                    let single = catalog.first { $0.name == oilCandidates[0] }
                    let priceStr = single != nil ? " (\(settings.currencySymbol)\(single!.pricePerUnit)/\(single!.unitType.shortLabel))" : ""
                    promptMsg = "We have \(oilCandidates[0])\(priceStr). Did you mean \(oilCandidates[0])?"
                } else {
                    let desc = oilCandidates.map { name in
                        if let itm = catalog.first(where: { $0.name == name }) {
                            return "\(name) (\(settings.currencySymbol)\(itm.pricePerUnit)/\(itm.unitType.shortLabel))"
                        }
                        return name
                    }.joined(separator: " or ")
                    promptMsg = "Which oil would you like? We have \(desc)."
                }

                let nonOilItems: [AgentParsedItem] = (payload.items ?? []).filter {
                    !$0.itemName.localizedCaseInsensitiveContains("oil")
                }
                let verifiedItems: [AgentParsedItem]? = nonOilItems.isEmpty ? nil : nonOilItems
                let summary: BillSummary? = {
                    if let v = verifiedItems, !v.isEmpty {
                        return BillCalculator.computeBill(
                            from: v,
                            catalog: catalog,
                            currencySymbol: settings.currencySymbol,
                            taxRatePercent: settings.taxRatePercent
                        )
                    }
                    return nil
                }()

                if let verified = verifiedItems, !verified.isEmpty {
                    let verifiedDesc = verified.map { "\($0.quantity.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int($0.quantity))" : "\($0.quantity)") \($0.unit) \($0.itemName)" }.joined(separator: ", ")
                    if !promptMsg.localizedCaseInsensitiveContains(verified[0].itemName) {
                        promptMsg = "Added \(verifiedDesc) to the bill.\n\(promptMsg)"
                    }
                }

                let pending = PendingClarification(
                    query: userInput,
                    quantity: payload.items?.first(where: { $0.itemName.localizedCaseInsensitiveContains("oil") })?.quantity ?? 1.0,
                    unit: payload.items?.first(where: { $0.itemName.localizedCaseInsensitiveContains("oil") })?.unit ?? "L",
                    candidateNames: oilCandidates
                )

                ParsingDiagnosticsLogger.shared.log(
                    userInput: userInput,
                    rawLLMOutput: content,
                    extractedJson: extractedJson,
                    outcome: .clarification,
                    rootCauseAnalysis: "Generic oil query converted to clarification: \(promptMsg)",
                    executionMode: "AgentAtom",
                    itemsParsedCount: verifiedItems?.count ?? 0
                )

                return AgentMessage(
                    role: .agent,
                    text: promptMsg,
                    thoughtProcess: thought ?? "Customer requested generic oil; asking clarification between catalog oils.",
                    rawJsonOutput: extractedJson,
                    status: .needsClarification,
                    billSummary: summary,
                    parsedItems: verifiedItems,
                    pendingClarification: pending,
                    canUndo: verifiedItems != nil
                )
            }
        }

        var items = payload.items ?? []
        var wasAutoRescued = false
        if items.isEmpty {
            for catItem in catalog {
                if payload.message.localizedCaseInsensitiveContains(catItem.name) {
                    items.append(
                        AgentParsedItem(
                            itemId: catItem.id.uuidString,
                            itemName: catItem.name,
                            quantity: 1.0,
                            unit: catItem.unitType.shortLabel,
                            unitPrice: catItem.pricePerUnit
                        )
                    )
                    wasAutoRescued = true
                    break
                }
            }
        }

        guard !items.isEmpty else {
            let rootCause = "Model returned empty items array with status 'ready'."
            ParsingDiagnosticsLogger.shared.log(
                userInput: userInput,
                rawLLMOutput: content,
                extractedJson: extractedJson,
                outcome: .decodingError,
                rootCauseAnalysis: rootCause,
                executionMode: "AgentAtom",
                itemsParsedCount: 0
            )

            return AgentMessage(
                role: .agent,
                text: payload.message.isEmpty ? "Error: Model returned no items." : payload.message,
                thoughtProcess: thought ?? payload.thought ?? rootCause,
                rawJsonOutput: extractedJson,
                status: .error,
                canUndo: false
            )
        }

        // 3d. False Match / Hallucination Prevention & Mixed Multi-Item Matching
        var partialNote: String? = nil
        if let rejected = payload.rejected, !rejected.isEmpty {
            let names = rejected.map(\.item).joined(separator: ", ")
            partialNote = "Note: Requested item(s) '\(names)' not in store catalog and excluded from bill."
        }
        if !userInput.isEmpty {
            var validItems: [AgentParsedItem] = []

            for item in items {
                let matches = ItemCatalogMatcher.itemMatchesUserInput(itemName: item.itemName, userInput: userInput)
                if matches {
                    validItems.append(item)
                }
            }

            if validItems.isEmpty {
                let requestedSubject = ItemCatalogMatcher.extractRequestedItemSubject(from: userInput) ?? "item"
                let notFoundText = "No match found. Item '\(requestedSubject)' was not found in the store catalog."
                let rca = "Prevented false match: customer requested '\(requestedSubject)', model hallucinated '\(items.map(\.itemName).joined(separator: ", "))'."

                ParsingDiagnosticsLogger.shared.log(
                    userInput: userInput,
                    rawLLMOutput: content,
                    extractedJson: extractedJson,
                    outcome: .clarification,
                    rootCauseAnalysis: rca,
                    executionMode: "AgentAtom",
                    itemsParsedCount: 0
                )

                return AgentMessage(
                    role: .agent,
                    text: notFoundText,
                    thoughtProcess: thought ?? rca,
                    rawJsonOutput: extractedJson,
                    status: .notFound,
                    canUndo: false
                )
            } else if validItems.count < items.count {
                items = validItems
                partialNote = "Note: Requested item not in store catalog was excluded."
            }
        }

        // 4. Thought process
        let finalThought: String = {
            if let t = thought, !t.isEmpty { return t }
            if let pt = payload.thought, !pt.isEmpty { return pt }
            let itemDesc = items.map { "\($0.itemName) (\($0.quantity)\($0.unit))" }.joined(separator: ", ")
            return "Resolved from store catalog: \(itemDesc). Mathematical totals calculated."
        }()

        // 5. Compute financial bill summary from parsed items
        let billSummary = BillCalculator.computeBill(
            from: items,
            catalog: catalog,
            currencySymbol: settings.currencySymbol,
            taxRatePercent: settings.taxRatePercent
        )

        // 6. User-facing message
        let displayText: String = {
            let base: String
            if !payload.message.isEmpty && partialNote == nil {
                base = payload.message
            } else {
                let itemDesc = items.map { "\($0.quantity)\($0.unit.isEmpty ? "" : " " + $0.unit) \($0.itemName)" }.joined(separator: ", ")
                base = "Added \(itemDesc) to the bill."
            }
            if let note = partialNote {
                return "\(base) (\(note))"
            }
            return base
        }()

        let status: AgentResponseStatus = (payload.status == "needs_clarification") ? .needsClarification : .ready
        let hasAutoCorrection = items.contains { $0.wasAutoCorrected == true }
        if wasSyntaxAutoRepaired {
            wasAutoRescued = true
        }

        let outcome: ParsingOutcome = wasAutoRescued ? .autoRescued : .success
        let analysis: String
        if wasSyntaxAutoRepaired {
            analysis = "Auto-repaired corrupted JSON syntax and successfully parsed \(items.count) item(s): \(items.map(\.itemName).joined(separator: ", "))."
        } else if wasAutoRescued {
            analysis = "Model omitted items array; parser auto-rescued '\(items.first?.itemName ?? "")' from text confirmation."
        } else {
            analysis = "Successfully parsed \(items.count) item(s): \(items.map(\.itemName).joined(separator: ", "))."
        }

        ParsingDiagnosticsLogger.shared.log(
            userInput: userInput,
            rawLLMOutput: content,
            extractedJson: extractedJson,
            outcome: outcome,
            rootCauseAnalysis: analysis,
            executionMode: "AgentAtom",
            itemsParsedCount: items.count
        )

        return AgentMessage(
            role: .agent,
            text: displayText,
            thoughtProcess: finalThought,
            rawJsonOutput: extractedJson,
            status: status,
            billSummary: billSummary,
            parsedItems: items,
            pendingClarification: payload.pendingClarification,
            hasAutoCorrection: hasAutoCorrection,
            unitCorrectionNotes: payload.unitCorrections,
            canUndo: true
        )
    }

    private static func extractJsonCandidates(from text: String) -> [String] {
        var candidates: [String] = []

        let fencePattern = #"```(?:json)?\s*([\s\S]*?)\s*```"#
        if let regex = try? NSRegularExpression(pattern: fencePattern, options: []) {
            let nsText = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches {
                if match.numberOfRanges > 1 {
                    let range = match.range(at: 1)
                    let sub = nsText.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sub.isEmpty {
                        candidates.append(sub)
                    }
                }
            }
        }

        if let openBrace = text.firstIndex(of: "{"),
           let closeBrace = text.lastIndex(of: "}"),
           openBrace < closeBrace {
            let candidate = String(text[openBrace...closeBrace])
            if !candidates.contains(candidate) {
                candidates.append(candidate)
            }
        }

        if let openBracket = text.firstIndex(of: "["),
           let closeBracket = text.lastIndex(of: "]"),
           openBracket < closeBracket {
            let candidate = String(text[openBracket...closeBracket])
            if !candidates.contains(candidate) {
                candidates.append(candidate)
            }
        }

        if candidates.isEmpty, let fenceRange = text.range(of: "```") {
            let afterFence = text[fenceRange.upperBound...]
            var candidateStr = String(afterFence).trimmingCharacters(in: .whitespacesAndNewlines)
            if candidateStr.lowercased().hasPrefix("json") {
                candidateStr = String(candidateStr.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !candidateStr.isEmpty && (candidateStr.contains("{") || candidateStr.contains("[")) {
                candidates.append(candidateStr)
            }
        }

        if candidates.isEmpty, let openBrace = text.firstIndex(of: "{") {
            let candidate = String(text[openBrace...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty && !candidates.contains(candidate) {
                candidates.append(candidate)
            }
        }

        return candidates
    }

    private static func decodePayload(from jsonStr: String) -> (AgentJsonPayload?, String?, Bool) {
        let trimmed = jsonStr.trimmingCharacters(in: .whitespacesAndNewlines)
        let repairedStr = repairCorruptedJsonSyntax(trimmed)
        let wasModified = (repairedStr != trimmed)

        if wasModified {
            let (repairedPayload, _) = attemptDecode(from: repairedStr)
            if let repairedPayload = repairedPayload {
                return (repairedPayload, nil, true)
            }
        }

        let (directPayload, directError) = attemptDecode(from: trimmed)
        if let directPayload = directPayload {
            return (directPayload, nil, false)
        }

        return (nil, directError, false)
    }

    private static func attemptDecode(from jsonStr: String) -> (AgentJsonPayload?, String?) {
        guard let data = jsonStr.data(using: .utf8) else {
            return (nil, "Failed to encode JSON candidate as UTF-8 data.")
        }

        var lastError: String? = nil

        do {
            let payload = try JSONDecoder().decode(AgentJsonPayload.self, from: data)
            return (payload, nil)
        } catch {
            lastError = formatDecodeError(error)
        }

        if let items = try? JSONDecoder().decode([AgentParsedItem].self, from: data), !items.isEmpty {
            return (AgentJsonPayload(status: "ready", message: "Items added to bill.", items: items), nil)
        }

        if let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            var extractedItems: [AgentParsedItem] = []
            var extractedRejected: [AgentRejectedItem] = []
            var extractedClarification: [AgentClarificationNeedItem] = []

            for key in ["items", "products", "order", "item_list", "billedItems"] {
                if let rawList = dict[key] as? [[String: Any]] {
                    for itemDict in rawList {
                        if let itemData = try? JSONSerialization.data(withJSONObject: itemDict),
                           let parsedItem = try? JSONDecoder().decode(AgentParsedItem.self, from: itemData) {
                            extractedItems.append(parsedItem)
                        }
                    }
                    break
                } else if let nestedDict = dict[key] as? [String: Any] {
                    for vKey in ["verified", "accepted", "ready", "items"] {
                        if let vList = nestedDict[vKey] as? [[String: Any]] {
                            for itemDict in vList {
                                if let itemData = try? JSONSerialization.data(withJSONObject: itemDict),
                                   let parsedItem = try? JSONDecoder().decode(AgentParsedItem.self, from: itemData) {
                                    extractedItems.append(parsedItem)
                                }
                            }
                        } else if let vObj = nestedDict[vKey] as? [String: Any] {
                            for (subKey, subVal) in vObj {
                                if var subDict = subVal as? [String: Any] {
                                    if subDict["itemName"] == nil && subDict["name"] == nil {
                                        subDict["itemName"] = subKey
                                    }
                                    if let subData = try? JSONSerialization.data(withJSONObject: subDict),
                                       let parsed = try? JSONDecoder().decode(AgentParsedItem.self, from: subData) {
                                        extractedItems.append(parsed)
                                    }
                                }
                            }
                            if extractedItems.isEmpty,
                               let itemData = try? JSONSerialization.data(withJSONObject: vObj),
                               let parsed = try? JSONDecoder().decode(AgentParsedItem.self, from: itemData) {
                                extractedItems.append(parsed)
                            }
                        }
                    }

                    for rKey in ["rejected", "unlisted", "not_found"] {
                        if let rList = nestedDict[rKey] as? [[String: Any]] {
                            for rDict in rList {
                                if let rData = try? JSONSerialization.data(withJSONObject: rDict),
                                   let parsed = try? JSONDecoder().decode(AgentRejectedItem.self, from: rData) {
                                    extractedRejected.append(parsed)
                                }
                            }
                        } else if let rObj = nestedDict[rKey] as? [String: Any] {
                            for (subKey, subVal) in rObj {
                                if let subDict = subVal as? [String: Any],
                                   let subData = try? JSONSerialization.data(withJSONObject: subDict),
                                   var parsed = try? JSONDecoder().decode(AgentRejectedItem.self, from: subData) {
                                    if parsed.item.isEmpty { parsed.item = subKey }
                                    extractedRejected.append(parsed)
                                } else if let strReason = subVal as? String {
                                    extractedRejected.append(AgentRejectedItem(item: subKey, reason: strReason))
                                }
                            }
                        }
                    }

                    for cKey in ["needClarification", "need_clarification", "needsClarification"] {
                        if let cList = nestedDict[cKey] as? [[String: Any]] {
                            for cDict in cList {
                                if let cData = try? JSONSerialization.data(withJSONObject: cDict),
                                   let parsed = try? JSONDecoder().decode(AgentClarificationNeedItem.self, from: cData) {
                                    extractedClarification.append(parsed)
                                }
                            }
                        } else if let cObj = nestedDict[cKey] as? [String: Any] {
                            for (subKey, subVal) in cObj {
                                if let subDict = subVal as? [String: Any],
                                   let subData = try? JSONSerialization.data(withJSONObject: subDict),
                                   var parsed = try? JSONDecoder().decode(AgentClarificationNeedItem.self, from: subData) {
                                    if parsed.item.isEmpty { parsed.item = subKey }
                                    extractedClarification.append(parsed)
                                }
                            }
                        }
                    }
                    break
                }
            }

            if extractedItems.isEmpty && (dict["itemName"] != nil || dict["name"] != nil || dict["item"] != nil) {
                if let itemData = try? JSONSerialization.data(withJSONObject: dict),
                   let parsedItem = try? JSONDecoder().decode(AgentParsedItem.self, from: itemData) {
                    extractedItems.append(parsedItem)
                }
            }

            if !extractedItems.isEmpty || !extractedRejected.isEmpty || !extractedClarification.isEmpty {
                let status = (dict["status"] as? String) ?? (extractedClarification.isEmpty ? (extractedItems.isEmpty ? "not_found" : "ready") : "needs_clarification")
                let message = (dict["message"] as? String) ?? (dict["response"] as? String) ?? ""
                let thought = dict["thought"] as? String
                return (
                    AgentJsonPayload(
                        status: status,
                        message: message,
                        thought: thought,
                        items: extractedItems,
                        rejected: extractedRejected.isEmpty ? nil : extractedRejected,
                        needClarification: extractedClarification.isEmpty ? nil : extractedClarification
                    ),
                    nil
                )
            }
        }

        return (nil, lastError)
    }

    private static func repairCorruptedJsonSyntax(_ text: String) -> String {
        var repaired = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let trailingCommaPattern = #",\s*([\]\}])"#
        if let regex = try? NSRegularExpression(pattern: trailingCommaPattern, options: []) {
            let range = NSRange(location: 0, length: repaired.utf16.count)
            repaired = regex.stringByReplacingMatches(in: repaired, options: [], range: range, withTemplate: "$1")
        }

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

        return repaired
    }

    private static func formatDecodeError(_ error: Error) -> String {
        if let decError = error as? DecodingError {
            switch decError {
            case .keyNotFound(let key, let ctx):
                return "Missing required JSON key '\(key.stringValue)' at '\(ctx.codingPath.map(\.stringValue).joined(separator: "."))'."
            case .typeMismatch(let type, let ctx):
                return "Type mismatch for '\(type)' at '\(ctx.codingPath.map(\.stringValue).joined(separator: "."))': \(ctx.debugDescription)"
            case .valueNotFound(let type, let ctx):
                return "Missing non-null value for '\(type)' at '\(ctx.codingPath.map(\.stringValue).joined(separator: "."))'."
            case .dataCorrupted(let ctx):
                let path = ctx.codingPath.map(\.stringValue).joined(separator: ".")
                let pathPrefix = path.isEmpty ? "" : " at '\(path)'"
                let underlying = ctx.underlyingError != nil ? " (\(ctx.underlyingError!.localizedDescription))" : ""
                return "JSON syntax corrupted\(pathPrefix): \(ctx.debugDescription)\(underlying)"
            @unknown default:
                return decError.localizedDescription
            }
        }
        return error.localizedDescription
    }

    private static func reconcilePayloadWithBusinessRules(
        payload: inout AgentJsonPayload,
        catalog: [Item],
        userInput: String
    ) {
        var verifiedItems = payload.items ?? []
        var rejectedItems = payload.rejected ?? []
        var clarificationItems = payload.needClarification ?? []
        var modified = false

        // 0. Packet indivisibility check: packets cannot be divided into fractional units!
        var remainingVerified: [AgentParsedItem] = []
        for item in verifiedItems {
            let catItem: Item? = {
                if let idStr = item.itemId, let uuid = UUID(uuidString: idStr) {
                    return catalog.first(where: { $0.id == uuid })
                }
                let clean = item.itemName.lowercased().trimmingCharacters(in: .whitespaces)
                return catalog.first(where: { $0.name.lowercased() == clean })
            }()

            if let catItem = catItem, catItem.sellingType == .packet {
                if item.quantity.truncatingRemainder(dividingBy: 1.0) != 0 {
                    clarificationItems.append(
                        AgentClarificationNeedItem(
                            item: catItem.name,
                            quantity: item.quantity,
                            unit: "pkt",
                            options: [catItem.name],
                            reason: "Packets cannot be divided into fractional units. Please specify whole packets."
                        )
                    )
                    modified = true
                    continue
                }
            }
            remainingVerified.append(item)
        }
        verifiedItems = remainingVerified

        // 1. Reconcile needClarification:
        var remainingClarification: [AgentClarificationNeedItem] = []
        for clarItem in clarificationItems {
            let itemName = clarItem.item
            let cleanQuery = itemName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if ItemCatalogMatcher.isGenericOilQuery(cleanQuery) {
                remainingClarification.append(clarItem)
                continue
            }

            let matches = catalog.filter { cat in
                cat.name.lowercased() == cleanQuery ||
                cat.name.localizedCaseInsensitiveContains(cleanQuery) ||
                cleanQuery.localizedCaseInsensitiveContains(cat.name) ||
                ItemCatalogMatcher.aliases(for: cat.name).contains { alias in
                    alias.count >= 3 && (cleanQuery == alias || cleanQuery.contains(alias) || alias.contains(cleanQuery))
                }
            }

            let singleOptionMatch: Item? = {
                if clarItem.options.count == 1 {
                    return catalog.first(where: { $0.name.lowercased() == clarItem.options[0].lowercased() })
                }
                return nil
            }()

            // If packet with fractional quantity: packets cannot be divided!
            if let catItem = singleOptionMatch ?? matches.first, catItem.sellingType == .packet,
               clarItem.quantity.truncatingRemainder(dividingBy: 1.0) != 0 {
                remainingClarification.append(clarItem)
                continue
            }

            if matches.count == 1 || singleOptionMatch != nil {
                let catItem = singleOptionMatch ?? matches.first!

                var qty = clarItem.quantity
                var unit = clarItem.unit
                if qty == 1.0 && (unit.isEmpty || unit == "pc") {
                    let extracted = ItemCatalogMatcher.extractQuantityAndUnit(for: catItem, from: userInput)
                    qty = extracted.quantity
                    unit = extracted.unit
                }

                if !verifiedItems.contains(where: { $0.itemName.lowercased() == catItem.name.lowercased() }) {
                    verifiedItems.append(
                        AgentParsedItem(
                            itemId: catItem.id.uuidString,
                            itemName: catItem.name,
                            quantity: qty,
                            unit: unit.isEmpty ? catItem.unitType.shortLabel : unit,
                            unitPrice: catItem.pricePerUnit
                        )
                    )
                }
                modified = true
            } else {
                remainingClarification.append(clarItem)
            }
        }
        clarificationItems = remainingClarification

        // 2. Reconcile rejected:
        var remainingRejected: [AgentRejectedItem] = []
        for rej in rejectedItems {
            let rejName = rej.item.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if let catItem = catalog.first(where: { cat in
                cat.name.lowercased() == rejName ||
                cat.name.localizedCaseInsensitiveContains(rejName) ||
                rejName.localizedCaseInsensitiveContains(cat.name) ||
                ItemCatalogMatcher.aliases(for: cat.name).contains { alias in
                    alias.count >= 3 && (rejName == alias || rejName.contains(alias) || alias.contains(rejName))
                }
            }) {
                let extracted = ItemCatalogMatcher.extractQuantityAndUnit(for: catItem, from: userInput)
                if !verifiedItems.contains(where: { $0.itemName.lowercased() == catItem.name.lowercased() }) {
                    verifiedItems.append(
                        AgentParsedItem(
                            itemId: catItem.id.uuidString,
                            itemName: catItem.name,
                            quantity: extracted.quantity,
                            unit: extracted.unit,
                            unitPrice: catItem.pricePerUnit
                        )
                    )
                }
                modified = true
            } else {
                remainingRejected.append(rej)
            }
        }
        rejectedItems = remainingRejected

        // 3. Explicit price extraction (e.g. "1 packet milk of 30 rs")
        for i in 0..<verifiedItems.count {
            if let customPrice = ItemCatalogMatcher.extractExplicitPrice(for: verifiedItems[i].itemName, from: userInput) {
                verifiedItems[i].unitPrice = customPrice
                modified = true
            }
        }

        // Apply back to payload if modified
        if modified {
            payload.items = verifiedItems.isEmpty ? nil : verifiedItems
            payload.rejected = rejectedItems.isEmpty ? nil : rejectedItems
            payload.needClarification = clarificationItems.isEmpty ? nil : clarificationItems

            if !verifiedItems.isEmpty && clarificationItems.isEmpty {
                payload.status = "ready"
                let desc = verifiedItems.map {
                    let qtyStr = $0.quantity.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int($0.quantity))" : "\($0.quantity)"
                    return "\(qtyStr) \($0.unit) \($0.itemName)"
                }.joined(separator: ", ")
                payload.message = "Added \(desc) to the bill."
            } else if !clarificationItems.isEmpty {
                payload.status = "needs_clarification"
            }
        }
    }
}
