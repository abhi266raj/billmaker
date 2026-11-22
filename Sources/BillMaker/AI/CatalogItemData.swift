import Foundation

/// Codable data representation of a catalog item passed to the AI layer.
public struct CatalogItemData: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let price: Double
    public let unit: String
    public let type: String          // "loose" or "packet"
    public let packetSize: String?

    public init(
        id: String,
        name: String,
        price: Double,
        unit: String,
        type: String,
        packetSize: String? = nil
    ) {
        self.id = id
        self.name = name
        self.price = price
        self.unit = unit
        self.type = type
        self.packetSize = packetSize
    }

    public init(from item: Item, index: Int? = nil) {
        self.id = index != nil ? "\(index!)" : item.id
        self.name = item.name
        self.price = item.pricePerUnit
        self.unit = item.unitType.shortLabel
        self.type = item.sellingType.rawValue
        self.packetSize = item.packetSize
    }
}
