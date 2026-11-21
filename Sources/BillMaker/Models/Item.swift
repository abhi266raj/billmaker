import Foundation

public enum SellingType: String, Codable, CaseIterable, Identifiable, Sendable {
    case loose = "loose"
    case packet = "packet"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .loose: return "Loose"
        case .packet: return "Packet"
        }
    }
}

public enum UnitType: String, Codable, CaseIterable, Identifiable, Sendable {
    case kg = "kg"
    case gram = "gram"
    case piece = "piece"
    case packet = "packet"
    case litre = "litre"
    case ml = "ml"
    case dozen = "dozen"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .kg: return "Kilogram (kg)"
        case .gram: return "Gram (g)"
        case .piece: return "Piece / Unit (pc)"
        case .packet: return "Packet (pkt)"
        case .litre: return "Litre (L)"
        case .ml: return "Millilitre (ml)"
        case .dozen: return "Dozen (12 pcs)"
        }
    }

    public var shortLabel: String {
        switch self {
        case .kg: return "kg"
        case .gram: return "g"
        case .piece: return "pc"
        case .packet: return "pkt"
        case .litre: return "L"
        case .ml: return "ml"
        case .dozen: return "doz"
        }
    }

    public var isWeightBased: Bool {
        return self == .kg || self == .gram
    }

    public var isVolumeBased: Bool {
        return self == .litre || self == .ml
    }

    public var isCountBased: Bool {
        return self == .piece || self == .packet || self == .dozen
    }
}

public struct Item: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var unitType: UnitType
    public var pricePerUnit: Double
    public var category: String
    public var notes: String
    public var inStock: Bool
    public var sellingType: SellingType
    public var packetSize: String?

    public init(
        id: UUID = UUID(),
        name: String,
        unitType: UnitType = .kg,
        pricePerUnit: Double,
        category: String = "General",
        notes: String = "",
        inStock: Bool = true,
        sellingType: SellingType? = nil,
        packetSize: String? = nil
    ) {
        self.id = id
        self.name = name
        self.unitType = unitType
        self.pricePerUnit = pricePerUnit
        self.category = category
        self.notes = notes
        self.inStock = inStock
        self.sellingType = sellingType ?? (unitType == .packet ? .packet : .loose)
        self.packetSize = packetSize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.unitType = try container.decode(UnitType.self, forKey: .unitType)
        self.pricePerUnit = try container.decode(Double.self, forKey: .pricePerUnit)
        self.category = try container.decodeIfPresent(String.self, forKey: .category) ?? "General"
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.inStock = try container.decodeIfPresent(Bool.self, forKey: .inStock) ?? true
        let decodedSellingType = try container.decodeIfPresent(SellingType.self, forKey: .sellingType)
        self.sellingType = decodedSellingType ?? (unitType == .packet ? .packet : .loose)
        self.packetSize = try container.decodeIfPresent(String.self, forKey: .packetSize)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, unitType, pricePerUnit, category, notes, inStock, sellingType, packetSize
    }

    public var allSearchTerms: [String] {
        var terms = [name.lowercased()]
        if !category.isEmpty {
            terms.append(category.lowercased())
        }
        if let size = packetSize, !size.isEmpty {
            terms.append(size.lowercased())
        }
        return terms.filter { !$0.isEmpty }
    }
}
