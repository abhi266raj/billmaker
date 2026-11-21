import Foundation

public protocol SettingsStorage {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
}

public final class SettingsStorageService: SettingsStorage {
    private let storageKey = "BillMaker_AppSettings_V1"
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func loadSettings() -> AppSettings {
        if let data = userDefaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return saved
        }
        return .defaultSettings
    }

    public func saveSettings(_ settings: AppSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: storageKey)
        }
    }
}
