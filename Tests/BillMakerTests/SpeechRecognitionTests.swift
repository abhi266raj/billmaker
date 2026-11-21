import XCTest
import Speech
@testable import BillMaker

final class SpeechRecognitionTests: XCTestCase {
    @MainActor
    func testSpeechRecognitionServiceInitialization() {
        let service = SpeechRecognitionService()
        XCTAssertFalse(service.isRecording)
        XCTAssertTrue(service.transcribedText.isEmpty)
        XCTAssertNil(service.errorMessage)
    }

    @MainActor
    func testStopRecordingResetsState() {
        let service = SpeechRecognitionService()
        service.stopRecording()
        XCTAssertFalse(service.isRecording)
        XCTAssertTrue(service.transcribedText.isEmpty)
    }

    func testAppSettingsVoiceSettings() {
        var settings = AppSettings.defaultSettings
        XCTAssertEqual(settings.speechLocaleIdentifier, "en-IN")

        settings.speechLocaleIdentifier = "hi-IN"
        XCTAssertEqual(settings.speechLocaleIdentifier, "hi-IN")
    }

    func testAppSettingsDecodingWithVoiceSettings() throws {
        let jsonWithoutVoice = """
        {
            "currencySymbol": "₹",
            "taxRatePercent": 0.0,
            "enableHapticFeedback": true,
            "showThoughtProcessByDefault": true
        }
        """

        let data = jsonWithoutVoice.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        // Backwards compatibility fallback to default
        XCTAssertEqual(decoded.speechLocaleIdentifier, "en-IN")
        XCTAssertEqual(decoded.audioLanguage, .englishIndia)
    }

    func testAudioRecognitionLanguageSelectionInConfig() {
        var settings = AppSettings.defaultSettings

        // Selection in config: Switch between English and Hindi
        XCTAssertEqual(settings.audioLanguage, .englishIndia)
        XCTAssertEqual(settings.audioLanguage.shortLabel, "EN (IN)")

        // Select Hindi
        settings.audioLanguage = .hindi
        XCTAssertEqual(settings.speechLocaleIdentifier, "hi-IN")
        XCTAssertEqual(settings.audioLanguage.displayName, "Hindi (हिन्दी)")
        XCTAssertEqual(settings.audioLanguage.shortLabel, "HI (हिन्दी)")

        // Select US English
        settings.audioLanguage = .englishUS
        XCTAssertEqual(settings.speechLocaleIdentifier, "en-US")

        // Select UK English
        settings.audioLanguage = .englishUK
        XCTAssertEqual(settings.speechLocaleIdentifier, "en-GB")
    }
}
