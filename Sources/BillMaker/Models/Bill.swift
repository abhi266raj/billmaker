import Foundation

public struct BilledItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var itemId: UUID?
    public var name: String
    public var matchedAlias: String?
    public var quantity: Double
    public var unit: UnitType
    public var unitPrice: Double
    public var subtotal: Double
    public var weightInKg: Double?

    public init(
        id: UUID = UUID(),
        itemId: UUID? = nil,
        name: String,
        matchedAlias: String? = nil,
        quantity: Double,
        unit: UnitType,
        unitPrice: Double,
        subtotal: Double? = nil,
        weightInKg: Double? = nil
    ) {
        self.id = id
        self.itemId = itemId
        self.name = name
        self.matchedAlias = matchedAlias
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.subtotal = subtotal ?? (quantity * unitPrice)

        if let weight = weightInKg {
            self.weightInKg = weight
        } else if unit == .kg {
            self.weightInKg = quantity
        } else if unit == .gram {
            self.weightInKg = quantity / 1000.0
        } else {
            self.weightInKg = nil
        }
    }
}

public struct BillSummary: Identifiable, Codable, Hashable {
    public var id: UUID
    public var items: [BilledItem]
    public var subtotal: Double
    public var taxRatePercent: Double
    public var taxAmount: Double
    public var discountAmount: Double
    public var grandTotal: Double
    public var totalWeightKg: Double
    public var totalPieceCount: Double
    public var totalItemsCount: Int
    public var currencySymbol: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        items: [BilledItem] = [],
        taxRatePercent: Double = 0.0,
        discountAmount: Double = 0.0,
        currencySymbol: String = "₹",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.items = items
        self.currencySymbol = currencySymbol
        self.createdAt = createdAt
        self.taxRatePercent = taxRatePercent
        self.discountAmount = discountAmount

        let computedSubtotal = items.reduce(0.0) { $0 + $1.subtotal }
        self.subtotal = computedSubtotal

        let computedTax = (computedSubtotal * taxRatePercent) / 100.0
        self.taxAmount = computedTax

        self.grandTotal = max(0.0, (computedSubtotal + computedTax) - discountAmount)

        self.totalWeightKg = items.reduce(0.0) { sum, item in
            sum + (item.weightInKg ?? 0.0)
        }

        self.totalPieceCount = items.filter { $0.unit == .piece || $0.unit == .packet || $0.unit == .dozen }.reduce(0.0) { sum, item in
            if item.unit == .dozen {
                return sum + (item.quantity * 12.0)
            }
            return sum + item.quantity
        }

        self.totalItemsCount = items.count
    }
}
