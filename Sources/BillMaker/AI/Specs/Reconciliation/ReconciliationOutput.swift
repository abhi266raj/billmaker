import Foundation

/// The reconciliation result for a single found item's quantity.
public struct ReconciledQuantityResult: Codable, Sendable, Equatable {
    public var catalogId: String
    public var catalogName: String
    public var requestedQuantity: Double
    public var requestedUnit: String
    public var validity: String // "valid" or "invalid"
    public var verifiedQuantity: Double?
    public var verifiedUnit: String?
    public var unitPrice: Double
    public var invalidReason: String?
    public var alternativeQuantity: Double?
    public var alternativeUnit: String?

    public init(
        catalogId: String,
        catalogName: String,
        requestedQuantity: Double,
        requestedUnit: String,
        validity: String,
        verifiedQuantity: Double? = nil,
        verifiedUnit: String? = nil,
        unitPrice: Double = 0.0,
        invalidReason: String? = nil,
        alternativeQuantity: Double? = nil,
        alternativeUnit: String? = nil
    ) {
        self.catalogId = catalogId
        self.catalogName = catalogName
        self.requestedQuantity = requestedQuantity
        self.requestedUnit = requestedUnit
        self.validity = validity
        self.verifiedQuantity = verifiedQuantity
        self.verifiedUnit = verifiedUnit
        self.unitPrice = unitPrice
        self.invalidReason = invalidReason
        self.alternativeQuantity = alternativeQuantity
        self.alternativeUnit = alternativeUnit
    }
}

/// Output from Step 3: Array of quantity reconciliation results.
public struct ReconciliationPlanOutput: Codable, Sendable {
    public var reconciledItems: [ReconciledQuantityResult]
    public var summary: String

    public init(reconciledItems: [ReconciledQuantityResult] = [], summary: String = "") {
        self.reconciledItems = reconciledItems
        self.summary = summary
    }
}
