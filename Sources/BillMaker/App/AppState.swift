import Foundation
import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    @Published public var catalog: [Item] = []
    @Published public var messages: [AgentMessage] = []
    @Published public var currentBill: BillSummary? = nil
    @Published public var settings: AppSettings = .defaultSettings
    @Published public var duplicatePolicy: DuplicateItemPolicy = .createDuplicate
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var canUndo: Bool = false

    private var billHistory: [BillSummary?] = []

    private let catalogStorage: CatalogStorage
    private let settingsStorage: SettingsStorage
    private let agentEngine: AgentEngine

    public init(
        catalogStorage: CatalogStorage = CatalogStorageService(),
        settingsStorage: SettingsStorage = SettingsStorageService(),
        agentEngine: AgentEngine = AppleFMAgentEngine()
    ) {
        self.catalogStorage = catalogStorage
        self.settingsStorage = settingsStorage
        self.agentEngine = agentEngine

        let loadedSettings = settingsStorage.loadSettings()
        self.settings = loadedSettings
        self.duplicatePolicy = loadedSettings.duplicateItemPolicy
        self.catalog = catalogStorage.loadCatalog()
        setupWelcomeMessage()
        prewarmEngine()
    }

    /// Prewarms the AI engine so first input responds with zero cold-start delay.
    public func prewarmEngine() {
        agentEngine.prewarm(catalog: catalog, settings: settings)
    }

    /// Prewarms the continuous session with typing or voice prefixes as they arrive.
    public func prewarmPrefix(_ prefix: String) {
        AppleFMBackgroundServer.shared.prewarmPrefix(prefix)
    }

    private func setupWelcomeMessage() {
        if messages.isEmpty {
            messages.append(
                AgentMessage(
                    role: .agent,
                    text: "Namaste! Ready to bill. Tell me your items via voice or text (e.g. \"2kg potato, 1L mustard oil, 500g paneer\"). Powered on-device by Apple Foundation Models.",
                    thoughtProcess: "Initialized Live Bill Harness with Apple Foundation Models.",
                    status: .info
                )
            )
        }
    }

    // MARK: - Agent Interaction

    /// Directly resolves a pending clarification when the user taps an option pill.
    public func selectClarificationOption(_ optionName: String) {
        let trimmed = optionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Find the pending clarification from the last agent message
        let pending = messages.last(where: { $0.role == .agent && $0.status == .needsClarification })?.pendingClarification

        // Record the user's choice in conversation
        messages.append(AgentMessage(role: .user, text: trimmed))

        // Match the item in catalog
        guard let catalogItem = catalog.first(where: {
            $0.name.localizedCaseInsensitiveContains(trimmed) || trimmed.localizedCaseInsensitiveContains($0.name)
        }) else {
            // Fallback to normal processing if item not in catalog
            processInput(trimmed)
            return
        }

        let qty = pending?.quantity ?? 1.0
        let unit = pending?.unit.isEmpty == false ? pending!.unit : catalogItem.unitType.shortLabel

        let parsedItem = AgentParsedItem(
            itemId: catalogItem.id.uuidString,
            itemName: catalogItem.name,
            quantity: qty,
            unit: unit,
            unitPrice: catalogItem.pricePerUnit
        )

        let billSummary = BillCalculator.computeBill(
            from: [parsedItem],
            catalog: catalog,
            currencySymbol: settings.currencySymbol,
            taxRatePercent: settings.taxRatePercent
        )

        let response = AgentMessage(
            role: .agent,
            text: "Added \(qty) \(unit) \(catalogItem.name) to the bill.",
            thoughtProcess: "Resolved option '\(catalogItem.name)' selected from clarification with quantity \(qty) \(unit).",
            status: .ready,
            billSummary: billSummary,
            parsedItems: [parsedItem],
            canUndo: true
        )

        messages.append(response)

        // Merge into current bill
        billHistory.append(self.currentBill)
        canUndo = true
        currentBill = BillCalculator.mergeIntoBill(
            existingBill: self.currentBill,
            newParsedItems: [parsedItem],
            catalog: self.catalog,
            currencySymbol: self.settings.currencySymbol,
            taxRatePercent: self.settings.taxRatePercent,
            policy: self.duplicatePolicy
        )
    }

    public func processInput(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMsg = AgentMessage(role: .user, text: trimmed)
        messages.append(userMsg)

        // Conversational Undo command support
        let lower = trimmed.lowercased()
        if lower == "undo" || lower == "undo last" || lower == "revert" || lower == "cancel last" || lower == "wapas" {
            self.undo()
            return
        }

        // Conversational Clarification Answer Resolution:
        // If the user is replying to a pending clarification question with a candidate name, ordinal, or affirmation
        if let lastAgent = messages.dropLast().last(where: { $0.role == .agent }),
           lastAgent.status == .needsClarification,
           let pending = lastAgent.pendingClarification,
           let resolvedChoice = ItemCatalogMatcher.resolveClarificationChoice(userInput: trimmed, pending: pending, catalog: catalog) {

            let parsedItem = AgentParsedItem(
                itemId: resolvedChoice.item.id.uuidString,
                itemName: resolvedChoice.item.name,
                quantity: resolvedChoice.quantity,
                unit: resolvedChoice.unit,
                unitPrice: resolvedChoice.item.pricePerUnit
            )

            let billSummary = BillCalculator.computeBill(
                from: [parsedItem],
                catalog: catalog,
                currencySymbol: settings.currencySymbol,
                taxRatePercent: settings.taxRatePercent
            )

            let response = AgentMessage(
                role: .agent,
                text: "Added \(resolvedChoice.quantity) \(resolvedChoice.unit) \(resolvedChoice.item.name) to the bill.",
                thoughtProcess: "Resolved choice '\(resolvedChoice.item.name)' for previous query '\(pending.query)' with quantity \(resolvedChoice.quantity) \(resolvedChoice.unit).",
                status: .ready,
                billSummary: billSummary,
                parsedItems: [parsedItem],
                canUndo: true
            )

            messages.append(response)

            // Merge into current bill
            billHistory.append(self.currentBill)
            canUndo = true
            currentBill = BillCalculator.mergeIntoBill(
                existingBill: self.currentBill,
                newParsedItems: [parsedItem],
                catalog: self.catalog,
                currencySymbol: self.settings.currencySymbol,
                taxRatePercent: self.settings.taxRatePercent,
                policy: self.duplicatePolicy
            )
            return
        }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let response = try await self.agentEngine.processMessage(
                    userInput: trimmed,
                    conversationHistory: self.messages,
                    catalog: catalog,
                    settings: settings
                )

                self.messages.append(response)

                // Accumulate items into live bill & save undo snapshot
                if let newItems = response.parsedItems, !newItems.isEmpty {
                    self.billHistory.append(self.currentBill)
                    self.canUndo = true

                    self.currentBill = BillCalculator.mergeIntoBill(
                        existingBill: self.currentBill,
                        newParsedItems: newItems,
                        catalog: self.catalog,
                        currencySymbol: self.settings.currencySymbol,
                        taxRatePercent: self.settings.taxRatePercent,
                        policy: self.duplicatePolicy
                    )
                }

                self.isProcessing = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.messages.append(
                    AgentMessage(
                        role: .agent,
                        text: "Error processing request: \(error.localizedDescription)",
                        thoughtProcess: "Exception caught during engine processing.",
                        status: .error
                    )
                )
                self.isProcessing = false
            }
        }
    }

    public func undo() {
        guard !billHistory.isEmpty else {
            self.messages.append(
                AgentMessage(
                    role: .agent,
                    text: "Nothing to undo. The bill is already at its initial state.",
                    thoughtProcess: "Undo requested but history stack is empty.",
                    status: .info
                )
            )
            return
        }
        self.currentBill = billHistory.removeLast()
        self.canUndo = !billHistory.isEmpty
        self.messages.append(
            AgentMessage(
                role: .agent,
                text: "Undid last action. Bill restored to previous state.",
                thoughtProcess: "Reverted live bill state using history stack.",
                status: .info
            )
        )
    }

    // MARK: - Live Bill Line-Item Editing & Deletion

    /// Updates the quantity of a specific billed item in the active invoice.
    public func updateItemQuantity(itemId: UUID, newQuantity: Double) {
        guard var bill = currentBill else { return }
        guard let idx = bill.items.firstIndex(where: { $0.id == itemId }) else { return }

        if newQuantity <= 0 {
            removeItem(itemId: itemId)
            return
        }

        self.billHistory.append(self.currentBill)
        self.canUndo = true

        var updatedItem = bill.items[idx]
        updatedItem.quantity = newQuantity
        updatedItem.subtotal = newQuantity * updatedItem.unitPrice
        if updatedItem.unit == .kg {
            updatedItem.weightInKg = newQuantity
        } else if updatedItem.unit == .gram {
            updatedItem.weightInKg = newQuantity / 1000.0
        }
        bill.items[idx] = updatedItem

        self.currentBill = BillCalculator.recalculateBill(
            items: bill.items,
            currencySymbol: settings.currencySymbol,
            taxRatePercent: settings.taxRatePercent,
            existingId: bill.id,
            createdAt: bill.createdAt
        )
    }

    /// Removes a specific billed line item from the active invoice.
    public func removeItem(itemId: UUID) {
        guard var bill = currentBill else { return }
        self.billHistory.append(self.currentBill)
        self.canUndo = true

        bill.items.removeAll(where: { $0.id == itemId })
        if bill.items.isEmpty {
            self.currentBill = nil
        } else {
            self.currentBill = BillCalculator.recalculateBill(
                items: bill.items,
                currencySymbol: settings.currencySymbol,
                taxRatePercent: settings.taxRatePercent,
                existingId: bill.id,
                createdAt: bill.createdAt
            )
        }
    }

    public func clearConversation() {
        messages.removeAll()
        setupWelcomeMessage()
        agentEngine.resetSession(catalog: catalog, settings: settings)
    }

    public func resetBill() {
        billHistory.removeAll()
        canUndo = false
        currentBill = nil
        agentEngine.resetSession(catalog: catalog, settings: settings)
    }

    // MARK: - Catalog Management

    public func addItem(_ item: Item) {
        catalog.append(item)
        catalogStorage.saveCatalog(catalog)
        prewarmEngine()
    }

    public func updateItem(_ item: Item) {
        if let idx = catalog.firstIndex(where: { $0.id == item.id }) {
            catalog[idx] = item
            catalogStorage.saveCatalog(catalog)
            prewarmEngine()
        }
    }

    public func deleteItem(at offsets: IndexSet) {
        catalog.remove(atOffsets: offsets)
        catalogStorage.saveCatalog(catalog)
        prewarmEngine()
    }

    public func deleteItem(_ item: Item) {
        catalog.removeAll(where: { $0.id == item.id })
        catalogStorage.saveCatalog(catalog)
        prewarmEngine()
    }

    public func resetCatalogToDefaults() {
        catalog = catalogStorage.loadDefaultCatalog()
        catalogStorage.saveCatalog(catalog)
        prewarmEngine()
    }

    // MARK: - Settings Management

    public func saveSettings() {
        settings.duplicateItemPolicy = duplicatePolicy
        settingsStorage.saveSettings(settings)
        prewarmEngine()
    }
}
