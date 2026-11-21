import Foundation
import Speech
import AVFoundation

@MainActor
public protocol SpeechService: ObservableObject {
    var isRecording: Bool { get }
    var transcribedText: String { get }
    var errorMessage: String? { get }
    var authorizationStatus: SFSpeechRecognizerAuthorizationStatus { get }
    func startRecording(localeIdentifier: String?, onTranscription: @escaping (String) -> Void)
    func stopRecording()
}

@MainActor
public final class SpeechRecognitionService: NSObject, ObservableObject, SpeechService, SFSpeechRecognizerDelegate {
    @Published public var isRecording: Bool = false
    @Published public var transcribedText: String = ""
    @Published public var errorMessage: String? = nil
    @Published public var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentTranscriptionHandler: ((String) -> Void)?

    public override init() {
        super.init()
        self.authorizationStatus = SFSpeechRecognizer.authorizationStatus()
    }

    public func requestPermissions() async -> Bool {
        // 1. Microphone access
        let micGranted: Bool = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micGranted else {
            self.errorMessage = "Microphone access denied. Please allow microphone permissions in macOS System Settings > Privacy & Security."
            return false
        }

        // 2. Speech recognition permission
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        self.authorizationStatus = speechStatus

        guard speechStatus == .authorized else {
            self.errorMessage = "Speech recognition permission denied. Please enable Speech Recognition in macOS System Settings > Privacy & Security."
            return false
        }

        return true
    }

    public func startRecording(localeIdentifier: String? = nil, onTranscription: @escaping (String) -> Void) {
        stopRecording()
        self.errorMessage = nil
        self.transcribedText = ""
        self.currentTranscriptionHandler = onTranscription

        Task { [weak self] in
            guard let self = self else { return }
            let authorized = await self.requestPermissions()
            guard authorized else { return }

            let locale: Locale
            if let id = localeIdentifier, !id.isEmpty {
                locale = Locale(identifier: id)
            } else {
                locale = Locale(identifier: "en-IN")
            }

            self.speechRecognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
            self.speechRecognizer?.delegate = self

            guard let recognizer = self.speechRecognizer, recognizer.isAvailable else {
                self.errorMessage = "Speech recognizer is not available for locale \(locale.identifier)."
                return
            }

            do {
                let engine = AVAudioEngine()
                self.audioEngine = engine
                let inputNode = engine.inputNode

                let recordingFormat = inputNode.outputFormat(forBus: 0)
                guard recordingFormat.sampleRate > 0 && recordingFormat.channelCount > 0 else {
                    self.errorMessage = "No active audio input device detected. Please verify microphone connection in macOS Sound Settings."
                    return
                }

                let request = SFSpeechAudioBufferRecognitionRequest()
                request.shouldReportPartialResults = true
                self.recognitionRequest = request

                self.recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                    Task { @MainActor in
                        guard let self = self else { return }

                        if let result = result {
                            let text = result.bestTranscription.formattedString
                            self.transcribedText = text
                            self.currentTranscriptionHandler?(text)

                            if result.isFinal {
                                self.stopRecording()
                            }
                        }

                        if let error = error {
                            let nsError = error as NSError
                            // Code 216 is recognition cancelled intentionally
                            if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                                return
                            }
                            if self.isRecording {
                                self.errorMessage = error.localizedDescription
                                self.stopRecording()
                            }
                        }
                    }
                }

                let recRequest = self.recognitionRequest
                inputNode.removeTap(onBus: 0)
                inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                    recRequest?.append(buffer)
                }

                engine.prepare()
                try engine.start()
                self.isRecording = true
            } catch {
                self.errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
                self.stopRecording()
            }
        }
    }

    public func stopRecording() {
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        audioEngine = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isRecording = false
        currentTranscriptionHandler = nil
    }

    public nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available && self.isRecording {
                self.errorMessage = "Speech recognition service became unavailable."
                self.stopRecording()
            }
        }
    }
}
