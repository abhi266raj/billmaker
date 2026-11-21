import Foundation

public protocol CatalogStorage {
    func loadCatalog() -> [Item]
    func saveCatalog(_ items: [Item])
    func loadDefaultCatalog() -> [Item]
}

public final class CatalogStorageService: CatalogStorage {
    private let storageKey = "BillMaker_Catalog_Items_V3"
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
        var candidateURLs: [URL] = []
        #if SWIFT_PACKAGE
        if let moduleURL = Bundle.module.url(forResource: "DefaultCatalog", withExtension: "json") {
            candidateURLs.append(moduleURL)
        }
        #endif
        if let mainURL = Bundle.main.url(forResource: "DefaultCatalog", withExtension: "json") {
            candidateURLs.append(mainURL)
        }
        if let classURL = Bundle(for: CatalogStorageService.self).url(forResource: "DefaultCatalog", withExtension: "json") {
            candidateURLs.append(classURL)
        }

        for url in candidateURLs {
            if let data = try? Data(contentsOf: url),
               let items = try? JSONDecoder().decode([Item].self, from: data),
               !items.isEmpty {
                return items
            }
        }

        return []
    }
}
