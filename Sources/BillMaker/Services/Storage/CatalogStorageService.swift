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
            Item(name: "Potato", aliases: ["Aloo", "Batata", "Aalu", "Alu"], unitType: .kg, pricePerUnit: 30.0, category: "Vegetables"),
            Item(name: "Tomato", aliases: ["Tamatar", "Tamata"], unitType: .kg, pricePerUnit: 40.0, category: "Vegetables"),
            Item(name: "Onion", aliases: ["Pyaz", "Pyaaz", "Kanda"], unitType: .kg, pricePerUnit: 45.0, category: "Vegetables"),
            Item(name: "Cow Milk", aliases: ["Doodh", "Dudh", "Milk"], unitType: .litre, pricePerUnit: 64.0, category: "Dairy"),
            Item(name: "Curd", aliases: ["Dahi", "Yogurt"], unitType: .packet, pricePerUnit: 35.0, category: "Dairy"),
            Item(name: "Paneer", aliases: ["Cottage Cheese", "Panir"], unitType: .kg, pricePerUnit: 380.0, category: "Dairy"),
            Item(name: "Mustard Oil", aliases: ["Sarson ka tel", "Sarso tel", "Rai tel"], unitType: .litre, pricePerUnit: 160.0, category: "Oils"),
            Item(name: "Sunflower Oil", aliases: ["Refined Oil", "Fortune Oil", "Tel"], unitType: .litre, pricePerUnit: 145.0, category: "Oils"),
            Item(name: "Eggs", aliases: ["Ande", "Anda", "Egg"], unitType: .piece, pricePerUnit: 7.0, category: "Poultry"),
            Item(name: "Banana", aliases: ["Kela", "Kele"], unitType: .dozen, pricePerUnit: 60.0, category: "Fruits"),
            Item(name: "Apple", aliases: ["Seb", "Saeb"], unitType: .kg, pricePerUnit: 180.0, category: "Fruits"),
            Item(name: "Basmati Rice", aliases: ["Chawal", "Rice"], unitType: .kg, pricePerUnit: 110.0, category: "Grains"),
            Item(name: "Atta (Wheat Flour)", aliases: ["Gehu ka atta", "Flour", "Aata"], unitType: .kg, pricePerUnit: 42.0, category: "Grains"),
            Item(name: "Maggi Noodles", aliases: ["Maggi", "Maggie", "Noodles"], unitType: .packet, pricePerUnit: 14.0, category: "Packaged"),
            Item(name: "Ginger", aliases: ["Adrak", "Adrakh"], unitType: .gram, pricePerUnit: 0.20, category: "Vegetables")
        ]
    }
}
