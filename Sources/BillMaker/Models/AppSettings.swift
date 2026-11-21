import Foundation

/// Spoken audio recognition language options.
public enum AudioRecognitionLanguage: String, Codable, CaseIterable, Identifiable {
    case englishIndia = "en-IN"
    case hindi = "hi-IN"
    case englishUS = "en-US"
    case englishUK = "en-GB"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .englishIndia:
            return "English (India) / Hinglish"
        case .hindi:
            return "Hindi (हिन्दी)"
        case .englishUS:
            return "English (US)"
        case .englishUK:
            return "English (UK)"
        }
    }

    public var shortLabel: String {
        switch self {
        case .englishIndia: return "EN (IN)"
        case .hindi: return "HI (हिन्दी)"
        case .englishUS: return "EN (US)"
        case .englishUK: return "EN (UK)"
        }
    }
}

/// Application settings including store billing preferences and voice dictation configuration.
/// Powered 100% on-device by Apple Foundation Models (Apple Intelligence).
public struct AppSettings: Codable {
    public var currencySymbol: String
    public var taxRatePercent: Double
    public var enableHapticFeedback: Bool
    public var showThoughtProcessByDefault: Bool
    public var speechLocaleIdentifier: String

    public var audioLanguage: AudioRecognitionLanguage {
        get { AudioRecognitionLanguage(rawValue: speechLocaleIdentifier) ?? .englishIndia }
        set { speechLocaleIdentifier = newValue.rawValue }
    }

    public init(
        currencySymbol: String = "₹",
        taxRatePercent: Double = 0.0,
        enableHapticFeedback: Bool = true,
        showThoughtProcessByDefault: Bool = true,
        speechLocaleIdentifier: String = "en-IN"
    ) {
        self.currencySymbol = currencySymbol
        self.taxRatePercent = taxRatePercent
        self.enableHapticFeedback = enableHapticFeedback
        self.showThoughtProcessByDefault = showThoughtProcessByDefault
        self.speechLocaleIdentifier = speechLocaleIdentifier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.currencySymbol = try container.decodeIfPresent(String.self, forKey: .currencySymbol) ?? "₹"
        self.taxRatePercent = try container.decodeIfPresent(Double.self, forKey: .taxRatePercent) ?? 0.0
        self.enableHapticFeedback = try container.decodeIfPresent(Bool.self, forKey: .enableHapticFeedback) ?? true
        self.showThoughtProcessByDefault = try container.decodeIfPresent(Bool.self, forKey: .showThoughtProcessByDefault) ?? true
        self.speechLocaleIdentifier = try container.decodeIfPresent(String.self, forKey: .speechLocaleIdentifier) ?? "en-IN"
    }

    public static let defaultSettings = AppSettings()
}
