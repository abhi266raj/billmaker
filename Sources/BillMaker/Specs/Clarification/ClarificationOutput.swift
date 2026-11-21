import Foundation

/// Output payload from ClarificationSpec determining whether the user input
/// resolves the pending clarification, or if it is not a real clarification.
public struct ClarificationOutput: Codable, Sendable {
    public var thought: String
    public var isRealClarification: Bool
    public var selectedItemName: String?
    public var resolvedQuantity: Double?
    public var resolvedUnit: String?
    public var reason: String
    public var fallbackToInitial: Bool

    public init(
        thought: String = "",
        isRealClarification: Bool = false,
        selectedItemName: String? = nil,
        resolvedQuantity: Double? = nil,
        resolvedUnit: String? = nil,
        reason: String = "",
        fallbackToInitial: Bool = false
    ) {
        self.thought = thought
        self.isRealClarification = isRealClarification
        self.selectedItemName = selectedItemName
        self.resolvedQuantity = resolvedQuantity
        self.resolvedUnit = resolvedUnit
        self.reason = reason
        self.fallbackToInitial = fallbackToInitial
    }
}
