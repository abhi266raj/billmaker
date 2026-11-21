import Foundation

public enum AgentRole: String, Codable {
    case user
    case agent
    case system
}

public enum AgentResponseStatus: String, Codable {
    case ready               // All items resolved, bill computed
    case needsClarification  // Missing weight/quantity, multiple matches, or ambiguous item
    case thinking            // In-flight
    case error               // Parsing or connection error
    case info                // General system notice
}

public struct PendingClarification: Codable, Hashable {
    public var query: String
    public var quantity: Double
    public var unit: String
    public var candidateNames: [String]

    public init(query: String, quantity: Double, unit: String, candidateNames: [String]) {
        self.query = query
        self.quantity = quantity
        self.unit = unit
        self.candidateNames = candidateNames
    }
}

public struct AgentMessage: Identifiable, Codable, Hashable {
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
public struct AgentParsedItem: Codable, Hashable {
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
}

public struct AgentJsonPayload: Codable {
    public var status: String // "success" or "needs_clarification"
    public var message: String
    public var thought: String?
    public var totalAmount: Double?
    public var totalWeightKg: Double?
    public var items: [AgentParsedItem]?
    public var questions: [String]?
    public var pendingClarification: PendingClarification?
    public var unitCorrections: [String]?

    public init(
        status: String,
        message: String,
        thought: String? = nil,
        totalAmount: Double? = nil,
        totalWeightKg: Double? = nil,
        items: [AgentParsedItem]? = nil,
        questions: [String]? = nil,
        pendingClarification: PendingClarification? = nil,
        unitCorrections: [String]? = nil
    ) {
        self.status = status
        self.message = message
        self.thought = thought
        self.totalAmount = totalAmount
        self.totalWeightKg = totalWeightKg
        self.items = items
        self.questions = questions
        self.pendingClarification = pendingClarification
        self.unitCorrections = unitCorrections
    }
}
