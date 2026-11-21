import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

/// State machine states for the Master Billing Orchestrator.
public enum OrchestratorState: Sendable, Equatable {
    case initial
    case clarification(PendingClarification)
}

/// Master Orchestrator that transitions between `BillingSpec` and `ClarificationSpec`,
/// verifies genuine clarifications vs non-clarifications, and acts as the strict guardian of retail business rules.
public final class MasterBillingOrchestrator: @unchecked Sendable {
    public static let shared = MasterBillingOrchestrator()

    private let stateQueue = DispatchQueue(label: "com.billmaker.orchestrator.state")
    private var _state: OrchestratorState = .initial

    public var state: OrchestratorState {
        get { stateQueue.sync { _state } }
        set { stateQueue.sync { _state = newValue } }
    }

    public init() {}

    /// Resets orchestrator state to initial.
    public func resetState() {
        self.state = .initial
    }

    /// Primary entry point: manages transitions, verifies clarifications, and enforces business rules.
    public func process(
        userInput: String,
        conversationHistory: [AgentMessage],
        catalog: [Item],
        settings: AppSettings
    ) async throws -> AgentMessage {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Determine active state
        var currentState = self.state
        if case .initial = currentState {
            // Check if last agent message was awaiting clarification
            if let lastAgent = conversationHistory.last(where: { $0.role == .agent }),
               lastAgent.status == .needsClarification,
               let pending = lastAgent.pendingClarification {
                currentState = .clarification(pending)
                self.state = currentState
            }
        }

        // 2. State-driven execution
        switch currentState {
        case .clarification(let pending):
            // Verification step: verify whether user input is a REAL clarification or a new request
            let verification = await verifyClarification(
                userInput: trimmed,
                pending: pending,
                catalog: catalog,
                settings: settings
            )

            if verification.isRealClarification, let chosenName = verification.selectedItemName {
                // Resolved clarification: find catalog item
                if let catalogItem = catalog.first(where: { $0.name.localizedCaseInsensitiveContains(chosenName) || chosenName.localizedCaseInsensitiveContains($0.name) }) {
                    let qty = verification.resolvedQuantity ?? pending.quantity
                    let unit = verification.resolvedUnit ?? (catalogItem.unitType.shortLabel)

                    let parsedItem = AgentParsedItem(
                        itemId: catalogItem.id.uuidString,
                        itemName: catalogItem.name,
                        quantity: qty,
                        unit: unit,
                        unitPrice: catalogItem.pricePerUnit
                    )

                    let summary = BillCalculator.computeBill(
                        from: [parsedItem],
                        catalog: catalog,
                        currencySymbol: settings.currencySymbol,
                        taxRatePercent: settings.taxRatePercent
                    )

                    // Transition state back to initial
                    self.state = .initial

                    return AgentMessage(
                        role: .agent,
                        text: "Added \(formatQty(qty)) \(unit) \(catalogItem.name) to the bill.",
                        thoughtProcess: "Verified clarification resolved choice '\(catalogItem.name)' for '\(pending.query)'.",
                        status: .ready,
                        billSummary: summary,
                        parsedItems: [parsedItem],
                        canUndo: true
                    )
                }
            }

            // If it is NOT a real clarification (e.g. user requested a completely new item or rejected):
            // Fall back to initial billing state with the new input!
            self.state = .initial

            return try await executeInitialBilling(
                userInput: trimmed,
                conversationHistory: conversationHistory,
                catalog: catalog,
                settings: settings
            )

        case .initial:
            return try await executeInitialBilling(
                userInput: trimmed,
                conversationHistory: conversationHistory,
                catalog: catalog,
                settings: settings
            )
        }
    }

    /// Verifies whether the user's response actually clarifies the pending item.
    private func verifyClarification(
        userInput: String,
        pending: PendingClarification,
        catalog: [Item],
        settings: AppSettings
    ) async -> ClarificationOutput {
        // Deterministic business rule check first
        if let deterministic = ItemCatalogMatcher.resolveClarificationChoice(userInput: userInput, pending: pending, catalog: catalog) {
            return ClarificationOutput(
                thought: "Deterministic match found in candidate options.",
                isRealClarification: true,
                selectedItemName: deterministic.item.name,
                resolvedQuantity: deterministic.quantity,
                resolvedUnit: deterministic.unit,
                reason: "Matched candidate option '\(deterministic.item.name)'",
                fallbackToInitial: false
            )
        }

        // If user input matches a completely different catalog item that was NOT in the candidate list,
        // it's a new request, NOT a clarification!
        let otherCatalogMatches = catalog.filter { cat in
            !pending.candidateNames.contains(cat.name) &&
            (cat.name.localizedCaseInsensitiveContains(userInput) || userInput.localizedCaseInsensitiveContains(cat.name))
        }
        if !otherCatalogMatches.isEmpty {
            return ClarificationOutput(
                thought: "User requested a different catalog item outside pending options.",
                isRealClarification: false,
                reason: "User changed request to '\(otherCatalogMatches[0].name)'",
                fallbackToInitial: true
            )
        }

        // AI-powered ModelledSpec verification using ClarificationSpec
        let catalogSummary = catalog.map { "- \($0.name): \(settings.currencySymbol)\($0.pricePerUnit)/\($0.unitType.shortLabel)" }.joined(separator: "\n")
        let input = ClarificationInput(
            userInput: userInput,
            pendingQuery: pending.query,
            pendingQuantity: pending.quantity,
            pendingUnit: pending.unit,
            candidateOptions: pending.candidateNames,
            catalogSummary: catalogSummary
        )

        let spec = ClarificationSpec(input: input)
        let session = AgentAtomSession(
            configuration: AgentAtomSession.Configuration(
                catalog: catalog,
                settings: settings,
                conversationHistory: []
            )
        )
        let operation = AgenticOperation(spec: spec, session: session)
        let result = await operation.execute()

        switch result {
        case .success(let rawOutput):
            if let data = rawOutput.data(using: .utf8),
               let output = try? JSONDecoder().decode(ClarificationOutput.self, from: data) {
                return output
            }
            // Lenient check if raw output mentions candidate
            for cand in pending.candidateNames {
                if rawOutput.localizedCaseInsensitiveContains(cand) {
                    return ClarificationOutput(
                        thought: "Extracted candidate name from response.",
                        isRealClarification: true,
                        selectedItemName: cand,
                        resolvedQuantity: pending.quantity,
                        resolvedUnit: pending.unit,
                        reason: "Option resolved",
                        fallbackToInitial: false
                    )
                }
            }
        case .failure:
            break
        }

        return ClarificationOutput(
            thought: "Unable to verify clarification; falling back to initial billing.",
            isRealClarification: false,
            fallbackToInitial: true
        )
    }

    /// Executes the primary billing spec and enforces guardian business rules.
    private func executeInitialBilling(
        userInput: String,
        conversationHistory: [AgentMessage],
        catalog: [Item],
        settings: AppSettings
    ) async throws -> AgentMessage {
        let previousContext = conversationHistory.suffix(4).map { "\($0.role.rawValue.capitalized): \($0.text)" }.joined(separator: "\n")
        let input = BillingInput(
            request: userInput,
            catalog: catalog,
            currencySymbol: settings.currencySymbol,
            previousContext: previousContext.isEmpty ? nil : previousContext
        )
        let spec = BillingSpec(input: input)

        let session = AgentAtomSession(
            configuration: AgentAtomSession.Configuration(
                catalog: catalog,
                settings: settings,
                conversationHistory: conversationHistory
            )
        )
        let operation = AgenticOperation(spec: spec, session: session)
        let result = await operation.execute()

        switch result {
        case .success(let rawOutput):
            let parsed = BillingOutput.parse(
                content: rawOutput,
                catalog: catalog,
                settings: settings,
                userInput: userInput
            )

            // Guardian of Business Rules:
            // If the parsed message indicates clarification is needed, transition to clarification state!
            if parsed.status == .needsClarification, let pending = parsed.pendingClarification {
                self.state = .clarification(pending)
            } else {
                self.state = .initial
            }

            return parsed

        case .failure(let error):
            let errMsg = error.localizedDescription
            ParsingDiagnosticsLogger.shared.log(
                userInput: userInput,
                rawLLMOutput: "",
                outcome: .networkError,
                rootCauseAnalysis: "Master Orchestrator execution error: \(errMsg)",
                executionMode: "AgentAtom",
                itemsParsedCount: 0
            )

            return AgentMessage(
                role: .agent,
                text: "Error generating response: \(errMsg)",
                thoughtProcess: "Master Orchestrator caught error: \(errMsg)",
                status: .error
            )
        }
    }

    private func formatQty(_ qty: Double) -> String {
        qty.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(qty))" : String(format: "%.2f", qty)
    }
}
