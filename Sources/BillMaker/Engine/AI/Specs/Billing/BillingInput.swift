import Foundation

public struct CatalogItemData: Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let price: Double
    public let unit: String
    public let type: String
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

/// Fully JSON input specification payload for BillingSpec under AgentAtom.
public struct BillingInput: Codable, Sendable {
    public let request: String
    public let currencySymbol: String
    public let catalog: [CatalogItemData]
    public let previousContext: String?
    private let asJSON: Bool

    public init(
        request: String,
        catalog: [CatalogItemData],
        currencySymbol: String = "₹",
        previousContext: String? = nil,
        asJSON: Bool = true
    ) {
        self.request = request
        self.catalog = catalog
        self.currencySymbol = currencySymbol
        self.previousContext = previousContext
        self.asJSON = asJSON
    }

    public init(
        request: String,
        catalogSummary: String,
        currencySymbol: String = "₹",
        previousContext: String? = nil
    ) {
        self.request = request
        self.currencySymbol = currencySymbol
        self.previousContext = previousContext
        self.catalog = []
        self.asJSON = true
    }

    public init(
        request: String,
        catalog: [Item],
        currencySymbol: String = "₹",
        previousContext: String? = nil,
        asJSON: Bool = true
    ) {
        self.request = request
        self.currencySymbol = currencySymbol
        self.previousContext = previousContext
        self.asJSON = asJSON
        self.catalog = catalog.enumerated().map { index, item in
            CatalogItemData(from: item, index: index + 1)
        }
    }

    public var catalogSummary: String {
        if asJSON {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(catalog),
               let str = String(data: data, encoding: .utf8) {
                return str
            }
        }
        return catalog.map { item in
            let sizeStr = (item.packetSize != nil && !item.packetSize!.isEmpty) ? ", size: \(item.packetSize!)" : ""
            let typeStr = item.type == "packet" ? "[type: packet\(sizeStr)]" : "[type: loose]"
            return "\(item.id). \(item.name): \(currencySymbol)\(item.price)/\(item.unit) \(typeStr)"
        }.joined(separator: "\n")
    }

    public static func formatCatalogLines(catalog: [Item], currencySymbol: String = "₹") -> String {
        return catalog.enumerated().map { index, item in
            let id = index + 1
            let typeStr = item.sellingType == .packet
                ? (item.packetSize != nil ? "[type: packet, size: \(item.packetSize!)]" : "[type: packet]")
                : "[type: loose]"
            return "\(id). \(item.name): \(currencySymbol)\(item.pricePerUnit)/\(item.unitType.shortLabel) \(typeStr)"
        }.joined(separator: "\n")
    }
}
