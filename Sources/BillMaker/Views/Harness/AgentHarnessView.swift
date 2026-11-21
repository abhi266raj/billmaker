import SwiftUI

public struct AgentHarnessView: View {
    @ObservedObject var appState: AppState
    @StateObject private var speechService = SpeechRecognitionService()
    @State private var inputText: String = ""
    @State private var inspectingJson: String? = nil
    @FocusState private var isInputFocused: Bool

    private let samplePrompts = [
        "2kg aloo aur 1L sarso tel",
        "500g paneer, 3 eggs, aur 1 pkt maggi",
        "dedh kilo aalu aur aadha kilo tamatar",
        "1 dozen kela aur 2kg seb",
        "oil aur dahi"
    ]

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        HSplitView {
            chatColumn
                .frame(minWidth: 420)

            LiveInvoiceView(
                bill: appState.currentBill,
                duplicatePolicy: $appState.duplicatePolicy,
                canUndo: appState.canUndo,
                onUndo: { appState.undo() },
                onReset: { appState.resetBill() },
                onInspectJson: {
                    if let rawJson = appState.messages.last(where: { $0.rawJsonOutput != nil })?.rawJsonOutput {
                        inspectingJson = rawJson
                    }
                }
            )
            .frame(minWidth: 340, maxWidth: 440)
        }
        .sheet(item: Binding(
            get: { inspectingJson.map { IdentifiableString(value: $0) } },
            set: { inspectingJson = $0?.value }
        )) { item in
            JSONInspectorView(jsonText: item.value)
        }
        .onAppear {
            isInputFocused = true
        }
    }

    private var chatColumn: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            messagesScrollView
            Divider()

            PromptSuggestionBar(samplePrompts: samplePrompts) { prompt in
                inputText = prompt
                sendMessage()
            }
            Divider()

            ChatInputBar(
                text: $inputText,
                isProcessing: appState.isProcessing,
                isRecording: speechService.isRecording,
                errorMessage: speechService.errorMessage,
                selectedAudioLanguage: appState.settings.audioLanguage,
                onSelectAudioLanguage: { newLang in
                    appState.settings.audioLanguage = newLang
                    appState.saveSettings()
                },
                onToggleMic: toggleMicRecording,
                onSend: sendMessage,
                isFocused: $isInputFocused
            )
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Agent Harness")
                        .font(.title3.bold())
                    engineBadge
                }
                Text("Context: \(appState.catalog.count) catalog items active")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { appState.clearConversation() }) {
                Label("Clear Chat", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(appState.messages) { message in
                        ChatMessageBubble(
                            message: message,
                            onInspectJson: { json in
                                inspectingJson = json
                            },
                            onUndo: {
                                appState.undo()
                            }
                        )
                        .id(message.id)
                    }

                    if appState.isProcessing {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Agent is analyzing input & calculating...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.leading, 44)
                        .id("thinking_indicator")
                    }
                }
                .padding()
            }
            .onChange(of: appState.messages.count) { _ in
                if let lastId = appState.messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var engineBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "apple.intelligence")
                .font(.caption2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Apple Foundation Models")
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.purple.opacity(0.12))
        .cornerRadius(5)
    }

    private func toggleMicRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            speechService.startRecording(localeIdentifier: appState.settings.speechLocaleIdentifier) { transcribed in
                inputText = transcribed
            }
        }
    }

    private func sendMessage() {
        if speechService.isRecording {
            speechService.stopRecording()
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        appState.processInput(text)
    }
}

private struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}
