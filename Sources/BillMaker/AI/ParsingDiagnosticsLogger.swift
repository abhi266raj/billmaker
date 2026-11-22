import Foundation
import AppKit

public enum ParsingOutcome: String, Codable, CaseIterable {
    case success = "SUCCESS"
    case clarification = "CLARIFICATION"
    case autoRescued = "AUTO_RESCUED"
    case decodingError = "DECODING_ERROR"
    case missingJson = "MISSING_JSON"
    case networkError = "NETWORK_ERROR"
}

public struct ParsingDiagnosticsRecord: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let userInput: String
    public let rawLLMOutput: String
    public let extractedJson: String?
    public let outcome: ParsingOutcome
    public let rootCauseAnalysis: String
    public let executionMode: String
    public let itemsParsedCount: Int
    public let requestSent: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        userInput: String,
        rawLLMOutput: String,
        extractedJson: String? = nil,
        outcome: ParsingOutcome,
        rootCauseAnalysis: String,
        executionMode: String = "AgentAtom",
        itemsParsedCount: Int = 0,
        requestSent: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.userInput = userInput
        self.rawLLMOutput = rawLLMOutput
        self.extractedJson = extractedJson
        self.outcome = outcome
        self.rootCauseAnalysis = rootCauseAnalysis
        self.executionMode = executionMode
        self.itemsParsedCount = itemsParsedCount
        self.requestSent = requestSent
    }

    public var isFailure: Bool {
        outcome == .decodingError || outcome == .missingJson || outcome == .networkError
    }
}

extension ParsingDiagnosticsRecord: CustomDebugStringConvertible {
    public var debugDescription: String {
        """
        [ParsingDiagnosticsRecord]
        ID: \(id.uuidString.prefix(8))
        Time: \(timestamp.formatted())
        Outcome: \(outcome.rawValue)
        Input: "\(userInput)"
        Items: \(itemsParsedCount)
        Analysis: \(rootCauseAnalysis)
        """
    }
}

/// Persistent and in-memory logger for tracking and analyzing AI model output parsing diagnostics.
public final class ParsingDiagnosticsLogger: ObservableObject, @unchecked Sendable {
    public static let shared = ParsingDiagnosticsLogger()

    @Published public private(set) var sessionRecords: [ParsingDiagnosticsRecord] = []
    @Published public private(set) var allRecords: [ParsingDiagnosticsRecord] = []
    @Published public private(set) var recentRecords: [ParsingDiagnosticsRecord] = []
    private let queue = DispatchQueue(label: "com.billmaker.diagnostics.logger", qos: .utility)
    private let maxInMemoryRecords = 100

    private var logDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("BillMaker/Logs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public var logFileURL: URL {
        return logDirectoryURL.appendingPathComponent("parsing_diagnostics.jsonl")
    }

    private init() {
        loadPersistedRecords()
    }

    /// Records a generation parsing attempt with root cause analysis.
    public func log(
        userInput: String,
        rawLLMOutput: String,
        extractedJson: String? = nil,
        outcome: ParsingOutcome,
        rootCauseAnalysis: String,
        executionMode: String = "AgentAtom",
        itemsParsedCount: Int = 0,
        requestSent: String? = nil
    ) {
        let record = ParsingDiagnosticsRecord(
            userInput: userInput,
            rawLLMOutput: rawLLMOutput,
            extractedJson: extractedJson,
            outcome: outcome,
            rootCauseAnalysis: rootCauseAnalysis,
            executionMode: executionMode,
            itemsParsedCount: itemsParsedCount,
            requestSent: requestSent
        )

        let updateInMemory = { [weak self] in
            guard let self = self else { return }
            self.sessionRecords.insert(record, at: 0)
            if self.sessionRecords.count > self.maxInMemoryRecords {
                self.sessionRecords.removeLast()
            }
            self.allRecords.insert(record, at: 0)
            if self.allRecords.count > self.maxInMemoryRecords {
                self.allRecords.removeLast()
            }
            self.recentRecords = self.allRecords
        }

        if Thread.isMainThread {
            updateInMemory()
        } else {
            DispatchQueue.main.sync(execute: updateInMemory)
        }

        queue.async { [weak self] in
            guard let self = self else { return }
            self.appendToFile(record: record)
        }
    }

    private func appendToFile(record: ParsingDiagnosticsRecord) {
        guard let data = try? JSONEncoder().encode(record),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"

        guard let lineData = line.data(using: .utf8) else { return }
        let url = logFileURL

        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(lineData)
            }
        } else {
            try? lineData.write(to: url, options: .atomic)
        }
    }

    private func loadPersistedRecords() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let url = self.logFileURL
            guard FileManager.default.fileExists(atPath: url.path),
                  let content = try? String(contentsOf: url, encoding: .utf8) else { return }

            let lines = content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            var loaded: [ParsingDiagnosticsRecord] = []

            for line in lines.suffix(self.maxInMemoryRecords) {
                if let data = line.data(using: .utf8),
                   let rec = try? JSONDecoder().decode(ParsingDiagnosticsRecord.self, from: data) {
                    loaded.append(rec)
                }
            }

            DispatchQueue.main.async {
                var combined = self.sessionRecords
                for rec in loaded.reversed() {
                    if !combined.contains(where: { $0.id == rec.id }) {
                        combined.append(rec)
                    }
                }
                if combined.count > self.maxInMemoryRecords {
                    combined = Array(combined.prefix(self.maxInMemoryRecords))
                }
                self.allRecords = combined
                self.recentRecords = combined
            }
        }
    }

    /// Clears only records accumulated during the current app run.
    public func clearSessionLogs() {
        let update: () -> Void = { [weak self] in
            self?.sessionRecords.removeAll()
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.sync(execute: update)
        }
    }

    /// Clears all logs across disk and memory.
    public func clearAllLogs() {
        let update: () -> Void = { [weak self] in
            self?.sessionRecords.removeAll()
            self?.allRecords.removeAll()
            self?.recentRecords.removeAll()
        }
        if Thread.isMainThread {
            update()
        } else {
            DispatchQueue.main.sync(execute: update)
        }
        queue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.logFileURL)
        }
    }

    /// Clears both in-memory and disk logs (backwards compatibility).
    public func clearLogs() {
        clearAllLogs()
    }

    /// Reveals the diagnostics log file in macOS Finder.
    public func openLogInFinder() {
        let url = logFileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
