import Foundation
import SwiftUI
import Combine

public enum DuplicateItemPolicy: String, CaseIterable, Identifiable {
    case addToQuantity = "add"
    case replaceQuantity = "replace"

    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .addToQuantity: return "Add to Quantity"
        case .replaceQuantity: return "Replace Quantity"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    @Published public var catalog: [Item] = []
    @Published public var messages: [AgentMessage] = []
    @Published public var currentBill: BillSummary? = nil
    @Published public var settings: AppSettings = .defaultSettings
    @Published public var duplicatePolicy: DuplicateItemPolicy = .addToQuantity
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

        self.settings = settingsStorage.loadSettings()
        self.catalog = catalogStorage.loadCatalog()
        setupWelcomeMessage()
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
                        replaceExisting: self.duplicatePolicy == .replaceQuantity
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

    public func clearConversation() {
        messages.removeAll()
        setupWelcomeMessage()
    }

    public func resetBill() {
        billHistory.removeAll()
        canUndo = false
        currentBill = nil
    }

    // MARK: - Catalog Management

    public func addItem(_ item: Item) {
        catalog.append(item)
        catalogStorage.saveCatalog(catalog)
    }

    public func updateItem(_ item: Item) {
        if let idx = catalog.firstIndex(where: { $0.id == item.id }) {
            catalog[idx] = item
            catalogStorage.saveCatalog(catalog)
        }
    }

    public func deleteItem(at offsets: IndexSet) {
        catalog.remove(atOffsets: offsets)
        catalogStorage.saveCatalog(catalog)
    }

    public func deleteItem(_ item: Item) {
        catalog.removeAll(where: { $0.id == item.id })
        catalogStorage.saveCatalog(catalog)
    }

    public func resetCatalogToDefaults() {
        catalog = catalogStorage.loadDefaultCatalog()
        catalogStorage.saveCatalog(catalog)
    }

    // MARK: - Settings Management

    public func saveSettings() {
        settingsStorage.saveSettings(settings)
    }
}
