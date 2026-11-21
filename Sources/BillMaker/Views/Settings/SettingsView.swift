import SwiftUI

public struct SettingsView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Form {
            Section(header: Text("AI Engine")) {
                HStack(spacing: 14) {
                    Image(systemName: "apple.intelligence")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 34, height: 34)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Apple Foundation Models (Background Server)")
                            .font(.headline)
                        Text("Dedicated prewarmed background server on port 9876. Holds continuous model sessions in memory to provide ultra-fast, low-latency parsing.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)

                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Server Status: 127.0.0.1:9876 (Prewarmed & Continuous Session Active)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Re-warm Session") {
                        appState.prewarmEngine()
                    }
                    .font(.caption)
                }
            }

            Section(header: Text("Currency & Billing Preferences")) {
                HStack {
                    Text("Currency Symbol:")
                    Spacer()
                    Picker("", selection: $appState.settings.currencySymbol) {
                        Text("₹ (INR)").tag("₹")
                        Text("$ (USD)").tag("$")
                        Text("€ (EUR)").tag("€")
                        Text("£ (GBP)").tag("£")
                    }
                    .frame(width: 140)
                    .onChange(of: appState.settings.currencySymbol) { _ in appState.saveSettings() }
                }

                HStack {
                    Text("Tax Rate (%):")
                    Spacer()
                    TextField("0.0", value: $appState.settings.taxRatePercent, format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: appState.settings.taxRatePercent) { _ in appState.saveSettings() }
                }
            }

            Section(header: Text("Voice & Speech Recognition Configuration")) {
                HStack {
                    Text("Audio Recognition Language:")
                    Spacer()
                    Picker("", selection: $appState.settings.audioLanguage) {
                        ForEach(AudioRecognitionLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .frame(width: 220)
                    .onChange(of: appState.settings.audioLanguage) { _ in
                        appState.saveSettings()
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.blue)
                    Text("Supports continuous voice dictation in Indian English, Hinglish, and Hindi.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }

            Section(header: Text("Display Preferences")) {
                Toggle("Show Thought Process by Default", isOn: $appState.settings.showThoughtProcessByDefault)
                    .onChange(of: appState.settings.showThoughtProcessByDefault) { _ in appState.saveSettings() }

                Toggle("Haptic / Audio Feedback", isOn: $appState.settings.enableHapticFeedback)
                    .onChange(of: appState.settings.enableHapticFeedback) { _ in appState.saveSettings() }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 400)
    }
}
