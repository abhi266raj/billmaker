import Foundation

/// Input specification payload for BillingSpec.
public struct BillingInput: Codable, Sendable {
    public let request: String
    public let catalogSummary: String
    public let currencySymbol: String

    public init(request: String, catalogSummary: String, currencySymbol: String) {
        self.request = request
        self.catalogSummary = catalogSummary
        self.currencySymbol = currencySymbol
    }
}
