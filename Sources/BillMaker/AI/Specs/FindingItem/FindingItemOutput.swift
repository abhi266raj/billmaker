import Foundation

/// The status object resulting from searching a single extracted item in the store catalog.
public struct ItemFindingResult: Codable, Sendable, Equatable {
    public var requestedItem: ExtractedOrderItem
    public var status: String // "found", "duplicate", or "notFound"
    /// Matches list:
    /// - For 'found': exactly 1 item.
    /// - For 'duplicate': multiple items (candidate options).
    /// - For 'notFound': empty list.
    public var matchedCatalogItems: [CatalogItemData]
    public var note: String?

    public init(
        requestedItem: ExtractedOrderItem,
        status: String,
        matchedCatalogItems: [CatalogItemData] = [],
        note: String? = nil
    ) {
        self.requestedItem = requestedItem
        self.status = status
        self.matchedCatalogItems = matchedCatalogItems
        self.note = note
    }
}

/// Output containing status objects for all evaluated items.
public struct FindingItemPlanOutput: Codable, Sendable {
    public var results: [ItemFindingResult]
    public var summary: String

    public init(results: [ItemFindingResult] = [], summary: String = "") {
        self.results = results
        self.summary = summary
    }
}
