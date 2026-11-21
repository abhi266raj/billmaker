import Foundation

/// Manages the system-level Apple Foundation Models background daemon (`fm serve` on port 1976).
///
/// Provides:
/// - Auto-start and health check of `fm serve --port 1976`.
/// - Direct OpenAI-compatible chat completion dispatch.
/// - Fallback to in-app embedded engine if the daemon is unavailable.
public final class AppleFMServerManager: @unchecked Sendable {
    public static let shared = AppleFMServerManager()
    public static let daemonPort: UInt16 = 1976

    private var daemonProcess: Process?
    private let lock = NSLock()

    private init() {}

    /// Checks if the `fm serve` daemon is currently listening on port 1976.
    public func isDaemonOnline() -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(Self.daemonPort)/health") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5

        let semaphore = DispatchSemaphore(value: 0)
        var online = false

        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                online = true
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 0.6)
        return online
    }

    /// Ensures `fm serve` is active and running in the background.
    public func ensureDaemonRunning(catalog: [Item], currencySymbol: String) {
        if isDaemonOnline() { return }

        lock.lock()
        defer { lock.unlock() }
        if daemonProcess != nil && isDaemonOnline() { return }

        guard FileManager.default.fileExists(atPath: "/usr/bin/fm") else { return }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/fm")
        p.arguments = ["serve", "--port", "\(Self.daemonPort)"]
        p.standardOutput = nil
        p.standardError = nil

        do {
            try p.run()
            self.daemonProcess = p

            // Wait a brief moment and warm up the daemon
            Task.detached(priority: .userInitiated) {
                try? await Task.sleep(nanoseconds: 300_000_000)
                _ = try? await self.queryDaemon(
                    userInput: "warmup",
                    conversationHistory: [],
                    catalog: catalog,
                    currencySymbol: currencySymbol
                )
            }
        } catch {
            print("[AppleFMServerManager] Failed to launch fm serve daemon: \(error)")
        }
    }

    /// Queries the `fm serve` completions endpoint (`/v1/chat/completions`).
    public func queryDaemon(
        userInput: String,
        conversationHistory: [AgentMessage],
        catalog: [Item],
        currencySymbol: String
    ) async throws -> String {
        guard let url = URL(string: "http://127.0.0.1:\(Self.daemonPort)/v1/chat/completions") else {
            throw NSError(domain: "AppleFMServerManager", code: -1)
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 20.0

        let systemPrompt = LLMPromptBuilder.buildSystemPrompt(catalog: catalog, currencySymbol: currencySymbol)
        var messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Optimization: Live billing items are stateless and accumulated in Swift.
        // We only retain conversation history if the previous turn requested a clarification
        // (so the customer's reply resolves the ambiguous item). Otherwise, each item addition starts with fresh context.
        let isClarificationPending: Bool = {
            guard let lastMsg = conversationHistory.last(where: { $0.role == .agent }) else { return false }
            return lastMsg.status == .needsClarification || lastMsg.pendingClarification != nil
        }()

        if isClarificationPending,
           let lastAgentMsg = conversationHistory.last(where: { $0.role == .agent }),
           let lastUserMsg = conversationHistory.last(where: { $0.role == .user && $0.text != userInput }) {
            messages.append(["role": "user", "content": lastUserMsg.text])
            let assistantPayload = lastAgentMsg.rawJsonOutput ?? "```json\n{\"status\":\"needs_clarification\",\"message\":\"\(lastAgentMsg.text)\"}\n```"
            messages.append(["role": "assistant", "content": assistantPayload])

            let pendingInfo = lastAgentMsg.pendingClarification
            let qtyStr = pendingInfo != nil ? "\(pendingInfo!.quantity) \(pendingInfo!.unit)" : ""
            let qStr = pendingInfo?.query ?? "item"
            let promptContext = "[Context: Customer previously requested \(qtyStr) '\(qStr)'. Now customer chose: '\(userInput)'. Bill the selected item with quantity \(qtyStr.isEmpty ? "1.0" : qtyStr) using FORMAT A (Status 'ready').]\nCustomer: \(userInput)"
            messages.append(["role": "user", "content": promptContext])
        } else {
            messages.append(["role": "user", "content": userInput])
        }

        let body: [String: Any] = [
            "model": "system",
            "stream": false,
            "temperature": 0.0,
            "max_tokens": 180,
            "messages": messages
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw NSError(domain: "AppleFMServerManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Daemon returned HTTP error."])
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let msg = first["message"] as? [String: Any],
                  let rawContent = msg["content"] as? String else {
                throw NSError(domain: "AppleFMServerManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unexpected response format from daemon."])
            }

            let cleanContent = rawContent
                .replacingOccurrences(of: "<start_of_turn>model", with: "")
                .replacingOccurrences(of: "<start_of_turn>", with: "")
                .replacingOccurrences(of: "<end_of_turn>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return cleanContent
        } catch {
            // Fallback to in-app embedded server if daemon times out or fails
            return try await AppleFMBackgroundServer.shared.processDirect(
                userInput: userInput,
                catalog: catalog,
                currencySymbol: currencySymbol
            )
        }
    }
}
