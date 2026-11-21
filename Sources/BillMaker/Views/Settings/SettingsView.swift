import SwiftUI

public struct SettingsView: View {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some View {
        Form {
            Section(header: Text("Apple Foundation Models Engine")) {
                Picker("Execution Mode", selection: $appState.settings.executionMode) {
                    ForEach(AppleFMExecutionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: appState.settings.executionMode) { _ in
                    appState.saveSettings()
                }

                Text(appState.settings.executionMode.shortDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)

                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(appState.settings.executionMode == .backgroundDaemon
                             ? "Daemon Active: 127.0.0.1:1976 (Apple Neural Engine Pinned)"
                             : "In-App Active: Port 9876 (Continuous Session Prewarmed)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Re-warm Engine") {
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

            Section(header: Text("Live Bill Item Handling Policy")) {
                Picker("When Item is Re-entered", selection: $appState.settings.duplicateItemPolicy) {
                    ForEach(DuplicateItemPolicy.allCases) { policy in
                        Text(policy.displayName).tag(policy)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: appState.settings.duplicateItemPolicy) { newPolicy in
                    appState.duplicatePolicy = newPolicy
                    appState.saveSettings()
                }

                Text(appState.settings.duplicateItemPolicy.descriptionText)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        .frame(minWidth: 520, minHeight: 440)
    }
}
