import XCTest
@testable import BillMaker

/// Mock AI Engine for testing live harness orchestration, cumulative bill states, and undo flows.
final class MockAIAgentEngine: @unchecked Sendable, AgentEngine {
    var responseToReturn: AgentMessage?

    init(responseToReturn: AgentMessage? = nil) {
        self.responseToReturn = responseToReturn
    }

    func processMessage(
        userInput: String,
        conversationHistory: [AgentMessage],
        catalog: [Item],
        settings: AppSettings
    ) async throws -> AgentMessage {
        if let response = responseToReturn {
            return response
        }

        // Default mock response: returns 2kg Potato
        let parsed = AgentParsedItem(itemName: "Potato", quantity: 2.0, unit: "kg", unitPrice: 30.0)
        return AgentMessage(
            role: .agent,
            text: "Added 2 kg Potato.",
            thoughtProcess: "<thought>Parsed 2kg potato via AI</thought>",
            status: .ready,
            parsedItems: [parsed]
        )
    }
}

final class BillCalculationTests: XCTestCase {
    var sampleCatalog: [Item] = []

    override func setUp() {
        super.setUp()
        sampleCatalog = [
            Item(name: "Potato", unitType: .kg, pricePerUnit: 30.0),
            Item(name: "Tomato", unitType: .kg, pricePerUnit: 40.0),
            Item(name: "Mustard Oil", unitType: .litre, pricePerUnit: 160.0),
            Item(name: "Paneer", unitType: .kg, pricePerUnit: 380.0),
            Item(name: "Eggs", unitType: .piece, pricePerUnit: 7.0),
            Item(name: "Banana", unitType: .dozen, pricePerUnit: 60.0)
        ]
    }

    func testBillCalculatorSingleItemCalculation() {
        let parsed = AgentParsedItem(itemName: "Potato", quantity: 2.0, unit: "kg", unitPrice: 30.0)
        let billed = BillCalculator.computeSingleItem(parsed: parsed, catalog: sampleCatalog)

        XCTAssertEqual(billed.name, "Potato")
        XCTAssertEqual(billed.quantity, 2.0)
        XCTAssertEqual(billed.unitPrice, 30.0)
        XCTAssertEqual(billed.subtotal, 60.0)
        XCTAssertEqual(billed.weightInKg, 2.0)
    }

    func testBillCalculatorSubunitScalingGramsToKg() {
        // User specifies 500g for an item sold per kg
        let parsed = AgentParsedItem(itemName: "Paneer", quantity: 500.0, unit: "gram", unitPrice: 380.0)
        let billed = BillCalculator.computeSingleItem(parsed: parsed, catalog: sampleCatalog)

        XCTAssertEqual(billed.quantity, 0.5) // 500g -> 0.5kg
        XCTAssertEqual(billed.unitPrice, 380.0)
        XCTAssertEqual(billed.subtotal, 190.0) // 0.5 * 380 = 190
        XCTAssertEqual(billed.weightInKg, 0.5)
    }

    func testBillCalculatorSubunitScalingMlToLitres() {
        // User specifies 500ml for Mustard Oil sold per litre
        let parsed = AgentParsedItem(itemName: "Mustard Oil", quantity: 500.0, unit: "ml", unitPrice: 160.0)
        let billed = BillCalculator.computeSingleItem(parsed: parsed, catalog: sampleCatalog)

        XCTAssertEqual(billed.quantity, 0.5) // 500ml -> 0.5 L
        XCTAssertEqual(billed.subtotal, 80.0) // 0.5 * 160 = 80
        XCTAssertNil(billed.weightInKg) // Volume items do not count toward weight
    }

    func testBillCalculatorComputeBillSummaryWithTax() {
        let items = [
            AgentParsedItem(itemName: "Potato", quantity: 2.0, unit: "kg", unitPrice: 30.0), // 60
            AgentParsedItem(itemName: "Tomato", quantity: 1.0, unit: "kg", unitPrice: 40.0)  // 40
        ]

        let bill = BillCalculator.computeBill(
            from: items,
            catalog: sampleCatalog,
            currencySymbol: "₹",
            taxRatePercent: 5.0 // 5% tax
        )

        XCTAssertEqual(bill.items.count, 2)
        XCTAssertEqual(bill.subtotal, 100.0)
        XCTAssertEqual(bill.taxAmount, 5.0)
        XCTAssertEqual(bill.grandTotal, 105.0)
        XCTAssertEqual(bill.totalWeightKg, 3.0)
    }

    func testCumulativeBillMergingAddToQuantity() {
        let item1 = AgentParsedItem(itemName: "Potato", quantity: 1.0, unit: "kg", unitPrice: 30.0)
        let bill1 = BillCalculator.mergeIntoBill(
            existingBill: nil,
            newParsedItems: [item1],
            catalog: sampleCatalog,
            replaceExisting: false
        )
        XCTAssertEqual(bill1.items.count, 1)
        XCTAssertEqual(bill1.items[0].quantity, 1.0)
        XCTAssertEqual(bill1.grandTotal, 30.0)

        // Customer adds 2kg more potato in a subsequent message
        let item2 = AgentParsedItem(itemName: "Potato", quantity: 2.0, unit: "kg", unitPrice: 30.0)
        let bill2 = BillCalculator.mergeIntoBill(
            existingBill: bill1,
            newParsedItems: [item2],
            catalog: sampleCatalog,
            replaceExisting: false
        )
        XCTAssertEqual(bill2.items.count, 1)
        XCTAssertEqual(bill2.items[0].quantity, 3.0) // 1.0 + 2.0 = 3.0 kg
        XCTAssertEqual(bill2.grandTotal, 90.0)
    }

    func testCumulativeBillMergingReplaceQuantity() {
        let item1 = AgentParsedItem(itemName: "Potato", quantity: 1.0, unit: "kg", unitPrice: 30.0)
        let bill1 = BillCalculator.mergeIntoBill(
            existingBill: nil,
            newParsedItems: [item1],
            catalog: sampleCatalog
        )
        XCTAssertEqual(bill1.items[0].quantity, 1.0)

        // Customer corrects quantity with replace policy enabled: 5kg Potato
        let item2 = AgentParsedItem(itemName: "Potato", quantity: 5.0, unit: "kg", unitPrice: 30.0)
        let bill2 = BillCalculator.mergeIntoBill(
            existingBill: bill1,
            newParsedItems: [item2],
            catalog: sampleCatalog,
            replaceExisting: true
        )
        XCTAssertEqual(bill2.items.count, 1)
        XCTAssertEqual(bill2.items[0].quantity, 5.0) // Replaced with 5.0 kg
        XCTAssertEqual(bill2.grandTotal, 150.0)
    }

    func testJSONPayloadDecoding() throws {
        let sampleJson = """
        {
          "status": "ready",
          "message": "Added 2kg potato",
          "thought": "Matched potato from catalog",
          "items": [
            {
              "itemId": "11111111-1111-1111-1111-111111111101",
              "itemName": "Potato",
              "matchedAlias": "aloo",
              "quantity": 2.0,
              "unit": "kg",
              "unitPrice": 30.0
            }
          ]
        }
        """

        let data = sampleJson.data(using: .utf8)!
        let payload = try JSONDecoder().decode(AgentJsonPayload.self, from: data)

        XCTAssertEqual(payload.status, "ready")
        XCTAssertEqual(payload.items?.count, 1)
        XCTAssertEqual(payload.items?.first?.itemName, "Potato")
        XCTAssertEqual(payload.items?.first?.quantity, 2.0)
    }

    @MainActor
    func testAppStateLiveHarnessWorkflowAndConversationalUndo() async throws {
        let mockEngine = MockAIAgentEngine()
        let appState = AppState(agentEngine: mockEngine)
        appState.catalog = sampleCatalog

        // User speaks / enters "2kg potato"
        appState.processInput("2kg potato")
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(appState.currentBill)
        XCTAssertEqual(appState.currentBill?.grandTotal, 60.0)
        XCTAssertTrue(appState.canUndo)

        // User types conversational "undo"
        appState.processInput("undo")

        XCTAssertNil(appState.currentBill)
        XCTAssertFalse(appState.canUndo)
        XCTAssertEqual(appState.messages.last?.text, "Undid last action. Bill restored to previous state.")
    }
}
