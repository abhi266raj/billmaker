import SwiftUI
import AppKit

public struct ParsingDiagnosticsView: View {
    @ObservedObject var logger = ParsingDiagnosticsLogger.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedScope: DiagnosticsScope = .thisSession
    @State private var selectedFilter: DiagnosticsFilter = .all
    @State private var expandedRecordId: UUID? = nil
    @State private var copiedId: UUID? = nil

    public enum DiagnosticsScope: String, CaseIterable, Identifiable {
        case thisSession = "This Session"
        case allHistory = "All History"

        public var id: String { rawValue }
    }

    public enum DiagnosticsFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case errorsOnly = "Errors Only"
        case clarifications = "Clarifications"
        case success = "Success"

        public var id: String { rawValue }
    }

    public init() {}

    private var scopeRecords: [ParsingDiagnosticsRecord] {
        switch selectedScope {
        case .thisSession:
            return logger.sessionRecords
        case .allHistory:
            return logger.allRecords
        }
    }

    private var filteredRecords: [ParsingDiagnosticsRecord] {
        let source = scopeRecords
        switch selectedFilter {
        case .all:
            return source
        case .errorsOnly:
            return source.filter { $0.isFailure }
        case .clarifications:
            return source.filter { $0.outcome == .clarification }
        case .success:
            return source.filter { $0.outcome == .success || $0.outcome == .autoRescued }
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            metricsBar
            Divider()

            filterBar
            Divider()

            if filteredRecords.isEmpty {
                emptyState
            } else {
                recordList
            }

            Divider()
            footerBar
        }
        .frame(minWidth: 700, minHeight: 540)
    }

    private var headerBar: some View {
        HStack {
            Image(systemName: "stethoscope")
                .foregroundColor(.accentColor)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Parsing Diagnostics & Failure Analysis")
                    .font(.headline)
                Text("Real-time telemetry and persistent audit log for Apple FM output parsing")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var metricsBar: some View {
        HStack(spacing: 16) {
            metricItem(title: "TOTAL ATTEMPTS", value: "\(scopeRecords.count)", color: .primary)
            metricItem(
                title: "SUCCESSFUL",
                value: "\(scopeRecords.filter { $0.outcome == .success || $0.outcome == .autoRescued }.count)",
                color: .green
            )
            metricItem(
                title: "PARSING FAILURES",
                value: "\(scopeRecords.filter { $0.isFailure }.count)",
                color: .red
            )
            metricItem(
                title: "CLARIFICATIONS",
                value: "\(scopeRecords.filter { $0.outcome == .clarification }.count)",
                color: .orange
            )
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
    }

    private func metricItem(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8).weight(.bold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.callout.weight(.bold))
                .foregroundColor(color)
        }
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            // Scope Picker: This Session vs All History
            Picker("Scope", selection: $selectedScope) {
                Text("This Session (\(logger.sessionRecords.count))").tag(DiagnosticsScope.thisSession)
                Text("All History (\(logger.allRecords.count))").tag(DiagnosticsScope.allHistory)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 260)

            Divider()
                .frame(height: 18)

            // Category Filter Picker
            Picker("Filter", selection: $selectedFilter) {
                ForEach(DiagnosticsFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer()

            Text("\(filteredRecords.count) of \(scopeRecords.count)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var recordList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredRecords) { record in
                    recordCard(record)
                }
            }
            .padding()
        }
    }

    private func recordCard(_ record: ParsingDiagnosticsRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                outcomeBadge(record.outcome)
                Text(record.timestamp.formatted(date: .numeric, time: .standard))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text("mode: \(record.executionMode)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)

                // Copy Full Diagnostic Entry Button
                copyRecordButton(record: record)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("USER INPUT:")
                    .font(.system(size: 9).weight(.bold))
                    .foregroundColor(.secondary)
                Text(record.userInput.isEmpty ? "(none)" : record.userInput)
                    .font(.body.weight(.medium))
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("ROOT CAUSE & ANALYSIS:")
                    .font(.system(size: 9).weight(.bold))
                    .foregroundColor(.secondary)
                Text(record.rootCauseAnalysis)
                    .font(.callout)
                    .foregroundColor(record.isFailure ? .red : .primary)
                    .textSelection(.enabled)
            }

            // Expandable details (Raw output & JSON)
            if expandedRecordId == record.id {
                VStack(alignment: .leading, spacing: 8) {
                    if let json = record.extractedJson, !json.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("EXTRACTED JSON:")
                                    .font(.system(size: 9).weight(.bold))
                                    .foregroundColor(.secondary)
                                Spacer()
                                copyButton(text: json, id: record.id)
                            }
                            Text(json)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("RAW MODEL OUTPUT:")
                                .font(.system(size: 9).weight(.bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            copyButton(text: record.rawLLMOutput, id: record.id)
                        }
                        Text(record.rawLLMOutput.isEmpty ? "(empty string)" : record.rawLLMOutput)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                    }
                }
                .padding(.top, 4)
            }

            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    expandedRecordId = (expandedRecordId == record.id) ? nil : record.id
                }
            }) {
                HStack(spacing: 4) {
                    Text(expandedRecordId == record.id ? "Hide Raw Model Telemetry" : "Inspect Raw Model Telemetry")
                    Image(systemName: expandedRecordId == record.id ? "chevron.up" : "chevron.down")
                }
                .font(.caption2.weight(.medium))
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(badgeBorderColor(record.outcome), lineWidth: 1)
        )
    }

    private func outcomeBadge(_ outcome: ParsingOutcome) -> some View {
        Text(outcome.rawValue)
            .font(.system(size: 9).weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeBgColor(outcome))
            .foregroundColor(badgeTextColor(outcome))
            .cornerRadius(4)
    }

    private func badgeBgColor(_ outcome: ParsingOutcome) -> Color {
        switch outcome {
        case .success: return Color.green.opacity(0.15)
        case .autoRescued: return Color.purple.opacity(0.15)
        case .clarification: return Color.orange.opacity(0.15)
        case .decodingError, .missingJson, .networkError: return Color.red.opacity(0.15)
        }
    }

    private func badgeTextColor(_ outcome: ParsingOutcome) -> Color {
        switch outcome {
        case .success: return .green
        case .autoRescued: return .purple
        case .clarification: return .orange
        case .decodingError, .missingJson, .networkError: return .red
        }
    }

    private func badgeBorderColor(_ outcome: ParsingOutcome) -> Color {
        switch outcome {
        case .success: return Color.green.opacity(0.2)
        case .autoRescued: return Color.purple.opacity(0.2)
        case .clarification: return Color.orange.opacity(0.2)
        case .decodingError, .missingJson, .networkError: return Color.red.opacity(0.3)
        }
    }

    private func copyButton(text: String, id: UUID) -> some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copiedId = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedId == id { copiedId = nil }
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: copiedId == id ? "checkmark" : "doc.on.doc")
                Text(copiedId == id ? "Copied" : "Copy")
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func copyRecordButton(record: ParsingDiagnosticsRecord) -> some View {
        let entryId = record.id
        return Button(action: {
            var fullSummary = """
            [DIAGNOSTICS RECORD]
            Timestamp: \(record.timestamp.formatted(date: .numeric, time: .standard))
            Outcome: \(record.outcome.rawValue)
            Mode: \(record.executionMode)
            User Input: \(record.userInput)
            Root Cause: \(record.rootCauseAnalysis)
            """
            if let json = record.extractedJson, !json.isEmpty {
                fullSummary += "\nExtracted JSON:\n\(json)"
            }
            if !record.rawLLMOutput.isEmpty {
                fullSummary += "\nRaw LLM Output:\n\(record.rawLLMOutput)"
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(fullSummary, forType: .string)
            copiedId = entryId
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedId == entryId { copiedId = nil }
            }
        }) {
            HStack(spacing: 3) {
                Image(systemName: copiedId == entryId ? "checkmark" : "doc.on.doc")
                Text(copiedId == entryId ? "Copied Entry" : "Copy Entry")
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundColor(.green.opacity(0.6))
            Text("No Diagnostics In This Filter (\(selectedScope.rawValue))")
                .font(.headline)
            Text("Generations and parsing attempts are logged here with real-time root cause analysis.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private var footerBar: some View {
        HStack {
            Button(action: { logger.openLogInFinder() }) {
                Label("Open Log File in Finder", systemImage: "folder")
                    .font(.caption)
            }

            Spacer()

            // Separate Clear menu for Session vs All History
            Menu {
                Button(role: .destructive, action: { logger.clearSessionLogs() }) {
                    Label("Clear This Session (\(logger.sessionRecords.count))", systemImage: "clock.arrow.circlepath")
                }
                Button(role: .destructive, action: { logger.clearAllLogs() }) {
                    Label("Clear All History (Disk & Memory)", systemImage: "trash")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Clear Logs...")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
