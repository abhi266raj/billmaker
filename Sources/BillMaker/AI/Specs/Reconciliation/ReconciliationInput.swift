import Foundation

/// Represents a found item paired with its matched catalog item, passed to Step 3.
public struct FoundItemForReconciliation: Codable, Sendable, Equatable {
    public var requestedItem: ExtractedOrderItem
    public var catalogItem: CatalogItemData

    public init(requestedItem: ExtractedOrderItem, catalogItem: CatalogItemData) {
        self.requestedItem = requestedItem
        self.catalogItem = catalogItem
    }
}

/// Input to Step 3: Contains ONLY items that were successfully FOUND in the store catalog.
public struct ReconciliationPlanInput: Codable, Sendable {
    public var foundItems: [FoundItemForReconciliation]

    public init(foundItems: [FoundItemForReconciliation]) {
        self.foundItems = foundItems
    }
}
