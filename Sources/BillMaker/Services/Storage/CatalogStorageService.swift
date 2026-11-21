import Foundation

public protocol CatalogStorage {
    func loadCatalog() -> [Item]
    func saveCatalog(_ items: [Item])
    func loadDefaultCatalog() -> [Item]
}

public final class CatalogStorageService: CatalogStorage {
    private let storageKey = "BillMaker_Catalog_Items_V2"
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func loadCatalog() -> [Item] {
        if let data = userDefaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Item].self, from: data),
           !saved.isEmpty {
            return saved
        }
        return loadDefaultCatalog()
    }

    public func saveCatalog(_ items: [Item]) {
        if let encoded = try? JSONEncoder().encode(items) {
            userDefaults.set(encoded, forKey: storageKey)
        }
    }

    public func loadDefaultCatalog() -> [Item] {
        if let url = Bundle.main.url(forResource: "DefaultCatalog", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let items = try? JSONDecoder().decode([Item].self, from: data) {
            return items
        }

        return [
            Item(name: "Potato", unitType: .kg, pricePerUnit: 30.0, category: "Vegetables", sellingType: .loose),
            Item(name: "Tomato", unitType: .kg, pricePerUnit: 40.0, category: "Vegetables", sellingType: .loose),
            Item(name: "Onion", unitType: .kg, pricePerUnit: 35.0, category: "Vegetables", sellingType: .loose),
            Item(name: "Ginger", unitType: .gram, pricePerUnit: 0.20, category: "Vegetables", sellingType: .loose),
            Item(name: "Cow Milk", unitType: .litre, pricePerUnit: 64.0, category: "Dairy", sellingType: .loose),
            Item(name: "Packet Milk", unitType: .packet, pricePerUnit: 30.0, category: "Dairy", sellingType: .packet, packetSize: "500ml"),
            Item(name: "Packet Milk (1L)", unitType: .packet, pricePerUnit: 60.0, category: "Dairy", sellingType: .packet, packetSize: "1L"),
            Item(name: "Curd", unitType: .packet, pricePerUnit: 35.0, category: "Dairy", sellingType: .packet, packetSize: "400g"),
            Item(name: "Paneer", unitType: .kg, pricePerUnit: 380.0, category: "Dairy", sellingType: .loose),
            Item(name: "Amul Butter", unitType: .packet, pricePerUnit: 56.0, category: "Dairy", sellingType: .packet, packetSize: "100g"),
            Item(name: "Mustard Oil", unitType: .litre, pricePerUnit: 160.0, category: "Oils & Spices", sellingType: .loose),
            Item(name: "Sunflower Oil", unitType: .litre, pricePerUnit: 145.0, category: "Oils & Spices", sellingType: .loose),
            Item(name: "Basmati Rice", unitType: .kg, pricePerUnit: 110.0, category: "Pantry & Grains", sellingType: .loose),
            Item(name: "Atta (Wheat Flour)", unitType: .kg, pricePerUnit: 42.0, category: "Pantry & Grains", sellingType: .loose),
            Item(name: "Sugar", unitType: .kg, pricePerUnit: 44.0, category: "Pantry & Grains", sellingType: .loose),
            Item(name: "Tata Salt", unitType: .packet, pricePerUnit: 28.0, category: "Pantry & Grains", sellingType: .packet, packetSize: "1kg"),
            Item(name: "Maggi Noodles", unitType: .packet, pricePerUnit: 14.0, category: "Packaged Food", sellingType: .packet, packetSize: "70g"),
            Item(name: "Bread", unitType: .packet, pricePerUnit: 40.0, category: "Packaged Food", sellingType: .packet, packetSize: "medium"),
            Item(name: "Chai Patti (Tea)", unitType: .packet, pricePerUnit: 120.0, category: "Beverages", sellingType: .packet, packetSize: "250g"),
            Item(name: "Eggs", unitType: .piece, pricePerUnit: 7.0, category: "Poultry & Eggs", sellingType: .loose),
            Item(name: "Banana", unitType: .dozen, pricePerUnit: 60.0, category: "Fruits", sellingType: .loose),
            Item(name: "Apple", unitType: .kg, pricePerUnit: 180.0, category: "Fruits", sellingType: .loose)
        ]
    }
}
