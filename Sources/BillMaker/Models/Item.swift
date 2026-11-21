import Foundation

public enum UnitType: String, Codable, CaseIterable, Identifiable {
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
        case .kg: return "Per Kilogram (kg)"
        case .gram: return "Per Gram (g)"
        case .piece: return "Per Piece / Unit"
        case .packet: return "Per Packet"
        case .litre: return "Per Litre (L)"
        case .ml: return "Per Millilitre (ml)"
        case .dozen: return "Per Dozen (12 pcs)"
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

public struct Item: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var aliases: [String]
    public var unitType: UnitType
    public var pricePerUnit: Double
    public var category: String
    public var notes: String
    public var inStock: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        aliases: [String] = [],
        unitType: UnitType = .kg,
        pricePerUnit: Double,
        category: String = "General",
        notes: String = "",
        inStock: Bool = true
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.unitType = unitType
        self.pricePerUnit = pricePerUnit
        self.category = category
        self.notes = notes
        self.inStock = inStock
    }

    public var allSearchTerms: [String] {
        var terms = [name.lowercased()]
        terms.append(contentsOf: aliases.map { $0.lowercased().trimmingCharacters(in: .whitespaces) })
        return terms.filter { !$0.isEmpty }
    }

    public var aliasesFormatted: String {
        aliases.joined(separator: ", ")
    }
}
