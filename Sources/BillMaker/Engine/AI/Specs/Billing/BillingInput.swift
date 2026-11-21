import Foundation

/// Input specification payload for BillingSpec.
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

    /// Convenience initializer directly from catalog items (formats as JSON string or catalog lines).
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
            let simpleItems = catalog.map { [
                "name": $0.name,
                "price": "\($0.pricePerUnit)",
                "unit": $0.unitType.shortLabel
            ] }
            if let data = try? JSONSerialization.data(withJSONObject: simpleItems, options: [.sortedKeys]),
               let jsonString = String(data: data, encoding: .utf8) {
                self.catalogSummary = jsonString
            } else {
                self.catalogSummary = catalog.map { "- \($0.name): \(currencySymbol)\($0.pricePerUnit)/\($0.unitType.shortLabel)" }.joined(separator: "\n")
            }
        } else {
            self.catalogSummary = catalog.map { "- \($0.name): \(currencySymbol)\($0.pricePerUnit)/\($0.unitType.shortLabel)" }.joined(separator: "\n")
        }
    }
}
