import Foundation
#if canImport(AgentAtomSource)
import AgentAtomSource
#elseif canImport(AgentAtom)
import AgentAtom
#endif

/// AgentAtom Session conforming to `AgenticSessionProtocol` providing execution
/// via Apple Foundation Models CLI `fm respond` or mock injection without persistent server ports.
public final class AgentAtomSession: AgenticSessionProtocol, @unchecked Sendable {
    public struct Configuration: Sendable {
        public var catalog: [Item]
        public var settings: AppSettings

        public init(catalog: [Item] = [], settings: AppSettings = .defaultSettings) {
            self.catalog = catalog
            self.settings = settings
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

        #if canImport(FoundationModels)
        if let nativeSession = AppleIntelligenceSession() {
            let nativeResult = await nativeSession.respond(to: input, instructions: instructions, schema: schema, for: operation)
            if case .success(let text) = nativeResult, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .success(text)
            }
        }
        #endif

        // Standalone CLI execution via Apple Foundation Models CLI `fm respond`
        return await executeCLIRespond(input: input, instructions: instructions, schema: schema)
    }

    private func executeCLIRespond(input: String, instructions: String, schema: JSONString? = nil) async -> Result<String, AgenticError> {
        let fmPaths = ["/usr/bin/fm", "/usr/local/bin/fm", "/opt/homebrew/bin/fm"]
        guard let fmPath = fmPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return .failure(.operationFailed(reason: "Apple Foundation Models CLI 'fm' not found on system."))
        }

        var promptInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if promptInput.hasPrefix("\"") && promptInput.hasSuffix("\"") && promptInput.count >= 2 {
            let inner = String(promptInput.dropFirst().dropLast())
            promptInput = inner.replacingOccurrences(of: "\\\"", with: "\"")
                               .replacingOccurrences(of: "\\n", with: "\n")
                               .replacingOccurrences(of: "\\\\", with: "\\")
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: fmPath)
                process.arguments = ["respond", promptInput, "--instructions", instructions]
                process.standardInput = FileHandle.nullDevice

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                let group = DispatchGroup()
                var outData = Data()
                var errData = Data()

                group.enter()
                DispatchQueue.global().async {
                    outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                group.enter()
                DispatchQueue.global().async {
                    errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                    group.wait()

                    let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if process.terminationStatus == 0 && !output.isEmpty {
                        continuation.resume(returning: .success(output))
                    } else {
                        let errStr = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(returning: .failure(.operationFailed(reason: errStr.isEmpty ? "Empty output" : errStr)))
                    }
                } catch {
                    continuation.resume(returning: .failure(.operationFailed(reason: error.localizedDescription)))
                }
            }
        }
    }
}
