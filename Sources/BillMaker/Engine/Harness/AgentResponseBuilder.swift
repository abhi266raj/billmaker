import Foundation

/// Builds standardized, user-facing agent responses and structured JSON payloads.
///
/// Ensures consistent message formatting across all parsing workflows:
/// - Generates concise, 1-sentence shopkeeper responses.
/// - Appends parenthetical notes for typo auto-corrections: `(Auto-corrected: 'potaoe' → Potato)`.
/// - Appends notes for unit mismatch corrections: `(Note: Potato is sold by weight (kg), not litre; data entry corrected to 2 kg)`.
/// - Encodes the complete payload into pretty-printed JSON conforming to `AgentJsonPayload`.
public struct AgentResponseBuilder {
    /// Assembles an `AgentMessage` containing formatted conversational text, reasoning logs, and structured JSON.
    ///
    /// - Parameters:
    ///   - recognizedItems: Successfully resolved items ready for billing.
    ///   - clarificationQuestions: Questions if ambiguity or missing information was detected.
    ///   - unrecognizedTerms: Terms not found in the catalog.
    ///   - autoCorrections: Tuple pairs of original spelling and corrected catalog name.
    ///   - unitCorrections: Human-readable explanations of corrected unit mismatches.
    ///   - pendingClarification: Active pending state if asking back (e.g. "Which tel?").
    ///   - thoughtLog: Compiled step-by-step reasoning string from `ThoughtLogger`.
    ///   - catalog: Active store inventory items.
    ///   - settings: Active user preferences.
    /// - Returns: A complete `AgentMessage` ready for display and harness integration.
    public static func buildResponse(
        recognizedItems: [AgentParsedItem],
        clarificationQuestions: [String],
        unrecognizedTerms: [String],
        autoCorrections: [(original: String, corrected: String)],
        unitCorrections: [String] = [],
        pendingClarification: PendingClarification? = nil,
        thoughtLog: String,
        catalog: [Item],
        settings: AppSettings
    ) -> AgentMessage {
        let status: AgentResponseStatus
        let humanMessage: String
        var bill: BillSummary? = nil
        let hasCorrections = !autoCorrections.isEmpty
        let correctionNote: String? = {
            if hasCorrections {
                let list = autoCorrections.map { "'\($0.original)' → \($0.corrected)" }.joined(separator: ", ")
                return "Auto-corrected: \(list)"
            }
            return nil
        }()

        if !clarificationQuestions.isEmpty && recognizedItems.isEmpty {
            status = .needsClarification
            humanMessage = clarificationQuestions.first ?? "Which item would you prefer?"
        } else if !recognizedItems.isEmpty {
            status = .ready
            bill = BillCalculator.computeBill(
                from: recognizedItems,
                catalog: catalog,
                currencySymbol: settings.currencySymbol,
                taxRatePercent: settings.taxRatePercent
            )

            let itemSummary = recognizedItems.map {
                "\($0.quantity.cleanFormatted) \($0.unit) \($0.itemName)"
            }.joined(separator: ", ")

            let prefix = recognizedItems.count > 1 ? "Verified & added \(recognizedItems.count) items:" : "Added"
            var messageParts: [String] = ["\(prefix) \(itemSummary)."]

            if let note = correctionNote {
                messageParts.append("(\(note))")
            }

            if !unitCorrections.isEmpty {
                let unitNote = unitCorrections.joined(separator: "; ")
                messageParts.append("(Note: \(unitNote)).")
            }

            if !clarificationQuestions.isEmpty {
                messageParts.append(clarificationQuestions.first!)
            }

            if !unrecognizedTerms.isEmpty {
                let unrecStr = unrecognizedTerms.joined(separator: ", ")
                messageParts.append("(Note: '\(unrecStr)' was not in catalog).")
            }

            humanMessage = messageParts.joined(separator: " ")
        } else {
            status = .needsClarification
            let terms = unrecognizedTerms.joined(separator: ", ")
            humanMessage = "Could not find \(terms.isEmpty ? "those items" : "'\(terms)'") in the catalog."
        }

        // Build Structured JSON Payload for the billing harness
        let payload = AgentJsonPayload(
            status: status == .ready ? "success" : "needs_clarification",
            message: humanMessage,
            thought: thoughtLog,
            totalAmount: bill?.grandTotal,
            totalWeightKg: bill?.totalWeightKg,
            items: recognizedItems.isEmpty ? nil : recognizedItems,
            questions: clarificationQuestions.isEmpty ? nil : clarificationQuestions,
            pendingClarification: pendingClarification,
            unitCorrections: unitCorrections.isEmpty ? nil : unitCorrections
        )

        let jsonString: String? = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(payload),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
            return nil
        }()

        return AgentMessage(
            role: .agent,
            text: humanMessage,
            thoughtProcess: thoughtLog,
            rawJsonOutput: jsonString,
            status: status,
            billSummary: bill,
            parsedItems: recognizedItems.isEmpty ? nil : recognizedItems,
            pendingClarification: pendingClarification,
            hasAutoCorrection: hasCorrections,
            autoCorrectionNote: correctionNote,
            unitCorrectionNotes: unitCorrections.isEmpty ? nil : unitCorrections,
            canUndo: true
        )
    }
}
