import Foundation

/// Input to evaluate a single extracted order item against the full store catalog.
public struct SingleItemFindingInput: Codable, Sendable {
    public var item: ExtractedOrderItem
    public var catalog: [CatalogItemData]

    public init(item: ExtractedOrderItem, catalog: [CatalogItemData]) {
        self.item = item
        self.catalog = catalog
    }

    public init(item: ExtractedOrderItem, catalog: [Item]) {
        self.item = item
        self.catalog = catalog.enumerated().map { CatalogItemData(from: $0.element, index: $0.offset + 1) }
    }
}

/// Input to evaluate a batch of extracted items against the store catalog.
public struct FindingItemPlanInput: Codable, Sendable {
    public var extractedItems: [ExtractedOrderItem]
    public var catalog: [CatalogItemData]

    public init(extractedItems: [ExtractedOrderItem], catalog: [CatalogItemData]) {
        self.extractedItems = extractedItems
        self.catalog = catalog
    }

    public init(extractedItems: [ExtractedOrderItem], catalog: [Item]) {
        self.extractedItems = extractedItems
        self.catalog = catalog.enumerated().map { CatalogItemData(from: $0.element, index: $0.offset + 1) }
    }
}
