import Foundation

/// Input specification payload for BillingSpec.
/// Contains default item IDs (1, 2, 3...), selling types (loose vs packet), and packet sizes.
public struct BillingInput: Codable, Sendable {
    public let request: String
    public let catalogSummary: String
    public let currencySymbol: String
    public let previousContext: String?

    public init(
        request: String,
        catalogSummary: String,
        currencySymbol: String = "₹",
        previousContext: String? = nil
    ) {
        self.request = request
        self.catalogSummary = catalogSummary
        self.currencySymbol = currencySymbol
        self.previousContext = previousContext
    }

    /// Convenience initializer directly from catalog items (formats with ID 1, 2, 3... and loose/packet type).
    public init(
        request: String,
        catalog: [Item],
        currencySymbol: String = "₹",
        previousContext: String? = nil,
        asJSON: Bool = false
    ) {
        self.request = request
        self.currencySymbol = currencySymbol
        self.previousContext = previousContext

        if asJSON {
            let simpleItems: [[String: Any]] = catalog.enumerated().map { index, item in
                var dict: [String: Any] = [
                    "id": index + 1,
                    "name": item.name,
                    "price": item.pricePerUnit,
                    "unit": item.unitType.shortLabel,
                    "type": item.sellingType.rawValue
                ]
                if let size = item.packetSize, !size.isEmpty {
                    dict["packetSize"] = size
                }
                return dict
            }
            if let data = try? JSONSerialization.data(withJSONObject: simpleItems, options: [.sortedKeys]),
               let jsonString = String(data: data, encoding: .utf8) {
                self.catalogSummary = jsonString
            } else {
                self.catalogSummary = BillingInput.formatCatalogLines(catalog: catalog, currencySymbol: currencySymbol)
            }
        } else {
            self.catalogSummary = BillingInput.formatCatalogLines(catalog: catalog, currencySymbol: currencySymbol)
        }
    }

    public static func formatCatalogLines(catalog: [Item], currencySymbol: String = "₹") -> String {
        return catalog.enumerated().map { index, item in
            let id = index + 1
            let typeStr: String
            if item.sellingType == .packet {
                if let size = item.packetSize, !size.isEmpty {
                    typeStr = "[type: packet, size: \(size)]"
                } else {
                    typeStr = "[type: packet]"
                }
            } else {
                typeStr = "[type: loose]"
            }
            return "\(id). \(item.name): \(currencySymbol)\(item.pricePerUnit)/\(item.unitType.shortLabel) \(typeStr)"
        }.joined(separator: "\n")
    }
}
