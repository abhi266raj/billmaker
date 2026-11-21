import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

// Typealiases for backwards compatibility and seamless spec adoption
public typealias AgentAtomBillingOutput = BillingOutput
public typealias AgentAtomItemsContainer = BillingItemsContainer
public typealias AgentAtomVerifiedItem = BillingVerifiedItem
public typealias AgentAtomRejectedItem = BillingRejectedItem
public typealias AgentAtomClarificationItem = BillingClarificationItem
public typealias AgentAtomBillingSpec = BillingSpec
public typealias BillingAgentInput = BillingInput

/// AgentAtom Session conforming to `AgenticSessionProtocol` providing provider execution
/// via Apple Intelligence / fm respond without persistent background server ports.
public final class AgentAtomSession: AgenticSessionProtocol, @unchecked Sendable {
    public struct Configuration: Sendable {
        public var catalog: [Item]
        public var settings: AppSettings
        public var conversationHistory: [AgentMessage]

        public init(catalog: [Item] = [], settings: AppSettings = .defaultSettings, conversationHistory: [AgentMessage] = []) {
            self.catalog = catalog
            self.settings = settings
            self.conversationHistory = conversationHistory
        }
    }

    /// Optional test responder for unit tests or mocked workflows to run deterministically and instantaneously.
    public static var testResponder: (@Sendable (_ input: String, _ instructions: String) async -> String?)? = nil

    public let configuration: Configuration
    public var executionMetadata: [AgenticExecutionMetadata] = []

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func respond(
        to input: String, instructions: String, schema: JSONString, for operation: ObjectIdentifier
    ) async -> Result<String, AgenticError> {
        // Fast path for unit tests or mock injection
        if let responder = Self.testResponder, let mockedOutput = await responder(input, instructions) {
            return .success(mockedOutput)
        }

        #if canImport(FoundationModels) && (os(macOS) || os(iOS))
        if #available(macOS 26, iOS 26, *) {
            if let nativeSession = AppleIntelligenceSession() {
                let nativeResult = await nativeSession.respond(to: input, instructions: instructions, schema: schema, for: operation)
                if case .success(let text) = nativeResult, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return .success(text)
                }
            }
        }
        #endif

        // Standalone CLI execution via Apple Foundation Models CLI `fm respond`
        return await executeCLIRespond(input: input, instructions: instructions)
    }

    private func executeCLIRespond(input: String, instructions: String) async -> Result<String, AgenticError> {
        let fmPaths = ["/usr/bin/fm", "/usr/local/bin/fm", "/opt/homebrew/bin/fm"]
        guard let fmPath = fmPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return .failure(.operationFailed(reason: "Apple Foundation Models CLI 'fm' not found on system."))
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: fmPath)
                process.arguments = ["respond", input, "--instructions", instructions]
                process.standardInput = FileHandle.nullDevice

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()

                    let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if process.terminationStatus == 0 && !output.isEmpty {
                        continuation.resume(returning: .success(output))
                    } else {
                        let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(returning: .failure(.operationFailed(reason: errStr)))
                    }
                } catch {
                    continuation.resume(returning: .failure(.operationFailed(reason: error.localizedDescription)))
                }
            }
        }
    }
}

/// AI Agent Engine that integrates AgentAtom (https://github.com/abhi266raj/AgentAtom)
/// as the unified agentic operation, schema, and specification engine managed by `MasterBillingOrchestrator`.
public final class AgentAtomBillingEngine: AgentEngine, @unchecked Sendable {
    public init() {}

    public func prewarm(catalog: [Item], settings: AppSettings) {
        // Fast prewarm: verify fm CLI availability or warm session
    }

    public func resetSession(catalog: [Item], settings: AppSettings) {
        MasterBillingOrchestrator.shared.resetState()
    }

    public func processMessage(
        userInput: String,
        conversationHistory: [AgentMessage],
        catalog: [Item],
        settings: AppSettings
    ) async throws -> AgentMessage {
        return try await MasterBillingOrchestrator.shared.process(
            userInput: userInput,
            conversationHistory: conversationHistory,
            catalog: catalog,
            settings: settings
        )
    }
}
