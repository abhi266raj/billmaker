import Foundation

/// Input payload for ClarificationSpec to verify and resolve ambiguous items.
public struct ClarificationInput: Codable, Sendable {
    public let userInput: String
    public let pendingQuery: String
    public let pendingQuantity: Double
    public let pendingUnit: String
    public let candidateOptions: [String]
    public let catalogSummary: String

    public init(
        userInput: String,
        pendingQuery: String,
        pendingQuantity: Double = 1.0,
        pendingUnit: String = "pc",
        candidateOptions: [String] = [],
        catalogSummary: String = ""
    ) {
        self.userInput = userInput
        self.pendingQuery = pendingQuery
        self.pendingQuantity = pendingQuantity
        self.pendingUnit = pendingUnit
        self.candidateOptions = candidateOptions
        self.catalogSummary = catalogSummary
    }
}
