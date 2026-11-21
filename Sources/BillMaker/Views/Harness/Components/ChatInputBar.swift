import SwiftUI

public struct ChatInputBar: View {
    @Binding var text: String
    let isProcessing: Bool
    var isRecording: Bool = false
    var errorMessage: String? = nil
    var selectedAudioLanguage: AudioRecognitionLanguage = .englishIndia
    var onSelectAudioLanguage: ((AudioRecognitionLanguage) -> Void)? = nil
    var onToggleMic: (() -> Void)? = nil
    let onSend: () -> Void
    @FocusState.Binding var isFocused: Bool

    @State private var pulseAnimation: Bool = false

    public init(
        text: Binding<String>,
        isProcessing: Bool,
        isRecording: Bool = false,
        errorMessage: String? = nil,
        selectedAudioLanguage: AudioRecognitionLanguage = .englishIndia,
        onSelectAudioLanguage: ((AudioRecognitionLanguage) -> Void)? = nil,
        onToggleMic: (() -> Void)? = nil,
        onSend: @escaping () -> Void,
        isFocused: FocusState<Bool>.Binding
    ) {
        self._text = text
        self.isProcessing = isProcessing
        self.isRecording = isRecording
        self.errorMessage = errorMessage
        self.selectedAudioLanguage = selectedAudioLanguage
        self.onSelectAudioLanguage = onSelectAudioLanguage
        self.onToggleMic = onToggleMic
        self.onSend = onSend
        self._isFocused = isFocused
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Live Listening Animation Banner
            if isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(pulseAnimation ? 1.3 : 0.8)
                        .opacity(pulseAnimation ? 1.0 : 0.4)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseAnimation)

                    Text("Listening in \(selectedAudioLanguage.shortLabel)... Speak items in English or Hindi (e.g. \"2 kilo aloo aur 1L tel\" or \"२ किलो आलू\")")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.red)

                    Spacer()

                    Text("Press Enter or click Stop when done")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.08))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.25), lineWidth: 1))
                .onAppear { pulseAnimation = true }
                .onDisappear { pulseAnimation = false }
            }

            // Dictation Error Banner (if permissions denied or mic unavailable)
            if let err = errorMessage, !err.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(err)
                        .font(.caption2)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }

            HStack(spacing: 8) {
                // Voice Dictation Microphone Button
                if let toggleMic = onToggleMic {
                    Button(action: toggleMic) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red.opacity(0.18) : Color.secondary.opacity(0.1))
                                .frame(width: 32, height: 32)

                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(isRecording ? .red : .accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(isRecording ? "Stop voice dictation" : "Speak items to bill (Voice Dictation)")
                }

                // Audio Language Quick Selector Menu (English / Hindi)
                if let onSelectLang = onSelectAudioLanguage {
                    Menu {
                        ForEach(AudioRecognitionLanguage.allCases) { lang in
                            Button(action: { onSelectLang(lang) }) {
                                HStack {
                                    Text(lang.displayName)
                                    if selectedAudioLanguage == lang {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "globe")
                                .font(.system(size: 10))
                            Text(selectedAudioLanguage.shortLabel)
                                .font(.system(size: 10).weight(.semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundColor(.primary)
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                    .help("Audio recognition language selection: English or Hindi")
                }

                TextField("Enter or speak items (e.g. '2kg aloo aur 1L sarso tel')...", text: $text)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit {
                        onSend()
                    }
                    .padding(9)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isRecording ? Color.red.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(text.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary.opacity(0.5) : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)
                .help("Add items to live bill")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}
