import Foundation

/// Output from Step 1: Array of all extracted items and total extraction summary.
public struct ParsingPlanOutput: Codable, Sendable {
    public var extractedItems: [ExtractedOrderItem]
    public var summary: String

    public init(extractedItems: [ExtractedOrderItem] = [], summary: String = "") {
        self.extractedItems = extractedItems
        self.summary = summary
    }

    private enum CodingKeys: String, CodingKey {
        case extractedItems
        case items
        case summary
    }

    public init(from decoder: Decoder) throws {
        // 1. Try decoding from a top-level JSON object
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let items: [ExtractedOrderItem] = {
                if let list = try? container.decode([ExtractedOrderItem].self, forKey: .extractedItems) {
                    return list
                }
                if let list = try? container.decode([ExtractedOrderItem].self, forKey: .items) {
                    return list
                }
                return []
            }()
            self.extractedItems = items
            self.summary = (try? container.decodeIfPresent(String.self, forKey: .summary)) ?? "Extracted \(items.count) item(s)"
            return
        }

        // 2. Try decoding directly from a top-level JSON array [ExtractedOrderItem]
        if let singleContainer = try? decoder.singleValueContainer(),
           let array = try? singleContainer.decode([ExtractedOrderItem].self) {
            self.extractedItems = array
            self.summary = "Extracted \(array.count) item(s)"
            return
        }

        self.extractedItems = []
        self.summary = "Extracted 0 items"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(extractedItems, forKey: .extractedItems)
        try container.encode(summary, forKey: .summary)
    }
}
