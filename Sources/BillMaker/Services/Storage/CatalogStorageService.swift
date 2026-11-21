import Foundation

public protocol CatalogStorage {
    func loadCatalog() -> [Item]
    func saveCatalog(_ items: [Item])
    func loadDefaultCatalog() -> [Item]
}

public final class CatalogStorageService: CatalogStorage {
    private let storageKey = "BillMaker_Catalog_Items_V1"
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
            Item(name: "Potato", unitType: .kg, pricePerUnit: 30.0, category: "Vegetables"),
            Item(name: "Tomato", unitType: .kg, pricePerUnit: 40.0, category: "Vegetables"),
            Item(name: "Onion", unitType: .kg, pricePerUnit: 45.0, category: "Vegetables"),
            Item(name: "Cow Milk", unitType: .litre, pricePerUnit: 64.0, category: "Dairy"),
            Item(name: "Curd", unitType: .packet, pricePerUnit: 35.0, category: "Dairy"),
            Item(name: "Paneer", unitType: .kg, pricePerUnit: 380.0, category: "Dairy"),
            Item(name: "Mustard Oil", unitType: .litre, pricePerUnit: 160.0, category: "Oils"),
            Item(name: "Sunflower Oil", unitType: .litre, pricePerUnit: 145.0, category: "Oils"),
            Item(name: "Eggs", unitType: .piece, pricePerUnit: 7.0, category: "Poultry"),
            Item(name: "Banana", unitType: .dozen, pricePerUnit: 60.0, category: "Fruits"),
            Item(name: "Apple", unitType: .kg, pricePerUnit: 180.0, category: "Fruits"),
            Item(name: "Basmati Rice", unitType: .kg, pricePerUnit: 110.0, category: "Grains"),
            Item(name: "Atta (Wheat Flour)", unitType: .kg, pricePerUnit: 42.0, category: "Grains"),
            Item(name: "Maggi Noodles", unitType: .packet, pricePerUnit: 14.0, category: "Packaged"),
            Item(name: "Ginger", unitType: .gram, pricePerUnit: 0.20, category: "Vegetables")
        ]
    }
}
