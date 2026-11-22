import Foundation

/// Input to Step 1: Customer order natural language query string and target languages.
public struct ParsingPlanInput: Codable, Sendable {
    public var userQuery: String
    public var languages: [String]

    public init(userQuery: String, languages: [String] = ["Hindi", "English"]) {
        self.userQuery = userQuery
        self.languages = languages
    }

    private enum CodingKeys: String, CodingKey {
        case userQuery
        case languages
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userQuery = try container.decode(String.self, forKey: .userQuery)
        self.languages = try container.decodeIfPresent([String].self, forKey: .languages) ?? ["Hindi", "English"]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userQuery, forKey: .userQuery)
        try container.encode(languages, forKey: .languages)
    }
}

/// Represents an individual item, quantity, and unit extracted from natural language or voice transcription.
public struct ExtractedOrderItem: Codable, Sendable, Equatable {
    public var name: String
    public var quantity: Double
    public var unit: String

    public init(name: String, quantity: Double = 1.0, unit: String = "") {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case item
        case itemName
        case quantity
        case unit
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Resiliently decode item name from name, item, or itemName
        if let n = try container.decodeIfPresent(String.self, forKey: .name) {
            self.name = n
        } else if let n = try container.decodeIfPresent(String.self, forKey: .item) {
            self.name = n
        } else if let n = try container.decodeIfPresent(String.self, forKey: .itemName) {
            self.name = n
        } else {
            self.name = "Unknown"
        }

        // Resiliently decode quantity as either Double or String
        if let d = try? container.decode(Double.self, forKey: .quantity) {
            self.quantity = d
        } else if let s = try? container.decode(String.self, forKey: .quantity) {
            let digitsOnly = s.replacingOccurrences(of: "[^0.0-9.]", with: "", options: .regularExpression)
            self.quantity = Double(digitsOnly) ?? 1.0
        } else {
            self.quantity = 1.0
        }

        // Resiliently decode unit
        self.unit = (try? container.decodeIfPresent(String.self, forKey: .unit)) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unit, forKey: .unit)
    }
}
