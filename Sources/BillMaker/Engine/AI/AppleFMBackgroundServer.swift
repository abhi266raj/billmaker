import Foundation
import Network
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, *)
private actor FMContinuousSessionActor {
    private var session: LanguageModelSession?
    private var isPrewarmed: Bool = false
    private var cachedFingerprint: Int = 0

    func prewarm(catalog: [Item], currencySymbol: String) async {
        let systemPrompt = LLMPromptBuilder.buildSystemPrompt(
            catalog: catalog,
            currencySymbol: currencySymbol
        )
        let s = LanguageModelSession {
            systemPrompt
        }
        s.prewarm(promptPrefix: Prompt(""))

        self.session = s
        self.isPrewarmed = true
    }

    func prewarmPrefix(_ prefix: String) {
        if !prefix.isEmpty {
            session?.prewarm(promptPrefix: Prompt(prefix))
        }
    }

    func process(userInput: String, catalog: [Item], currencySymbol: String) async throws -> String {
        if session == nil {
            await prewarm(catalog: catalog, currencySymbol: currencySymbol)
        }
        guard let s = session else {
            throw NSError(domain: "AppleFMServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "FM Session could not be initialized."])
        }
        let options = GenerationOptions(temperature: 0.1, maximumResponseTokens: 250)
        let res = try await s.respond(to: userInput, options: options)
        return res.content
    }

    func reset(catalog: [Item], currencySymbol: String) async {
        await prewarm(catalog: catalog, currencySymbol: currencySymbol)
    }

    func getStatus() -> (isReady: Bool, isPrewarmed: Bool) {
        return (session != nil, isPrewarmed)
    }
}
#endif

/// Background Server managing the persistent, continuous Apple Foundation Models process.
///
/// Features:
/// 1. **Continuous Session**: Maintains context across conversation turns in memory.
/// 2. **Prewarmed Execution**: Loads model weights & prompt prefixes before user input arrives.
/// 3. **Dual Transport**: Direct in-memory actor invocation for sub-second responses, plus local HTTP listener on port 9876.
/// 4. **Apple `fm serve` / CLI Fallback**: Seamless fallback to system `/usr/bin/fm` or `fm serve` on port 1976.
public final class AppleFMBackgroundServer: @unchecked Sendable {
    public static let shared = AppleFMBackgroundServer()
    public static let defaultPort: UInt16 = 9876

    private var listener: NWListener?
    private let statusLock = NSLock()
    private var _isRunning: Bool = false
    private var _isPrewarmed: Bool = false

    #if canImport(FoundationModels)
    private var _sessionActor: Any?
    #endif

    public var isRunning: Bool {
        statusLock.lock()
        defer { statusLock.unlock() }
        return _isRunning
    }

    public var isPrewarmed: Bool {
        statusLock.lock()
        defer { statusLock.unlock() }
        return _isPrewarmed
    }

    private init() {}

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func getActor() -> FMContinuousSessionActor {
        statusLock.lock()
        defer { statusLock.unlock() }
        if let existing = _sessionActor as? FMContinuousSessionActor {
            return existing
        }
        let actor = FMContinuousSessionActor()
        _sessionActor = actor
        return actor
    }
    #endif

    /// Starts the background server and eagerly prewarms the continuous session.
    public func start(port: UInt16 = AppleFMBackgroundServer.defaultPort, catalog: [Item], currencySymbol: String) {
        statusLock.lock()
        if _isRunning {
            statusLock.unlock()
            prewarm(catalog: catalog, currencySymbol: currencySymbol)
            return
        }
        statusLock.unlock()

        do {
            let nwPort = NWEndpoint.Port(rawValue: port) ?? NWEndpoint.Port(integerLiteral: AppleFMBackgroundServer.defaultPort)
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let listener = try NWListener(using: params, on: nwPort)

            listener.stateUpdateHandler = { [weak self] (state: NWListener.State) in
                guard let self = self else { return }
                self.statusLock.lock()
                switch state {
                case .ready:
                    self._isRunning = true
                case .failed, .cancelled:
                    self._isRunning = false
                default:
                    break
                }
                self.statusLock.unlock()
            }

            listener.newConnectionHandler = { [weak self] conn in
                self?.handleConnection(conn, catalog: catalog, currencySymbol: currencySymbol)
            }

            listener.start(queue: .global(qos: .userInitiated))
            self.listener = listener

            statusLock.lock()
            self._isRunning = true
            statusLock.unlock()

            // Prewarm session immediately
            prewarm(catalog: catalog, currencySymbol: currencySymbol)
        } catch {
            print("[AppleFMBackgroundServer] Error starting server on port \(port): \(error)")
        }
    }

    public func prewarm(catalog: [Item], currencySymbol: String) {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let actor = getActor()
            Task.detached(priority: .userInitiated) { [weak self] in
                await actor.prewarm(catalog: catalog, currencySymbol: currencySymbol)
                self?.markPrewarmed(true)
            }
        }
        #endif
    }

    public func prewarmPrefix(_ prefix: String) {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let actor = getActor()
            Task {
                await actor.prewarmPrefix(prefix)
            }
        }
        #endif
    }

    public func reset(catalog: [Item], currencySymbol: String) {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let actor = getActor()
            Task.detached(priority: .userInitiated) {
                await actor.reset(catalog: catalog, currencySymbol: currencySymbol)
            }
        }
        #endif
    }

    public func processDirect(userInput: String, catalog: [Item], currencySymbol: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let actor = getActor()
            return try await actor.process(userInput: userInput, catalog: catalog, currencySymbol: currencySymbol)
        }
        #endif

        // Fallback: Check if fm serve on port 1976 is reachable
        if let fmServeResponse = try? await queryFmServe(userInput: userInput, catalog: catalog, currencySymbol: currencySymbol) {
            return fmServeResponse
        }

        // Final fallback: Spawn /usr/bin/fm respond CLI
        return try spawnCliRespond(userInput: userInput, catalog: catalog, currencySymbol: currencySymbol)
    }

    private func queryFmServe(userInput: String, catalog: [Item], currencySymbol: String) async throws -> String {
        guard let url = URL(string: "http://127.0.0.1:1976/v1/chat/completions") else {
            throw NSError(domain: "FMServe", code: -1)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10.0

        let systemPrompt = LLMPromptBuilder.buildSystemPrompt(catalog: catalog, currencySymbol: currencySymbol)
        let body: [String: Any] = [
            "model": "system",
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userInput]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let msg = first["message"] as? [String: Any],
              let content = msg["content"] as? String else {
            throw NSError(domain: "FMServe", code: -2)
        }
        return content
    }

    private func spawnCliRespond(userInput: String, catalog: [Item], currencySymbol: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/fm")
        let systemPrompt = LLMPromptBuilder.buildSystemPrompt(catalog: catalog, currencySymbol: currencySymbol)
        process.arguments = ["respond", "-g", "--no-stream", "-i", systemPrompt, userInput]

        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func markPrewarmed(_ prewarmed: Bool) {
        statusLock.lock()
        _isPrewarmed = prewarmed
        statusLock.unlock()
    }

    private func handleConnection(_ conn: NWConnection, catalog: [Item], currencySymbol: String) {
        conn.start(queue: .global(qos: .userInitiated))
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, ctx, isComplete, err in
            guard let self = self, let data = data, let reqStr = String(data: data, encoding: .utf8) else {
                conn.cancel()
                return
            }

            Task {
                await self.routeRequest(reqStr: reqStr, conn: conn, catalog: catalog, currencySymbol: currencySymbol)
            }
        }
    }

    private func routeRequest(reqStr: String, conn: NWConnection, catalog: [Item], currencySymbol: String) async {
        let lines = reqStr.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(statusCode: 400, body: "{\"error\":\"Bad Request\"}", conn: conn)
            return
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendResponse(statusCode: 400, body: "{\"error\":\"Bad Request\"}", conn: conn)
            return
        }

        let method = String(parts[0])
        let path = String(parts[1])

        if method == "GET" && path == "/health" {
            let body = "{\"status\":\"ready\",\"isPrewarmed\":\(isPrewarmed)}"
            sendResponse(statusCode: 200, body: body, conn: conn)
            return
        }

        if method == "POST" && path == "/process" {
            if let bodyRange = reqStr.range(of: "\r\n\r\n") {
                let jsonBody = String(reqStr[bodyRange.upperBound...])
                if let jsonData = jsonBody.data(using: .utf8),
                   let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let userInput = dict["userInput"] as? String {
                    do {
                        let result = try await self.processDirect(userInput: userInput, catalog: catalog, currencySymbol: currencySymbol)
                        let respObj = ["status": "ok", "content": result]
                        if let respData = try? JSONSerialization.data(withJSONObject: respObj),
                           let respStr = String(data: respData, encoding: .utf8) {
                            sendResponse(statusCode: 200, body: respStr, conn: conn)
                            return
                        }
                    } catch {
                        sendResponse(statusCode: 500, body: "{\"error\":\"\(error.localizedDescription)\"}", conn: conn)
                        return
                    }
                }
            }
            sendResponse(statusCode: 400, body: "{\"error\":\"Invalid payload\"}", conn: conn)
            return
        }

        if method == "POST" && path == "/reset" {
            self.reset(catalog: catalog, currencySymbol: currencySymbol)
            sendResponse(statusCode: 200, body: "{\"status\":\"reset_acknowledged\"}", conn: conn)
            return
        }

        sendResponse(statusCode: 404, body: "{\"error\":\"Not Found\"}", conn: conn)
    }

    private func sendResponse(statusCode: Int, body: String, conn: NWConnection) {
        let statusText = statusCode == 200 ? "OK" : (statusCode == 404 ? "Not Found" : "Error")
        let response = "HTTP/1.1 \(statusCode) \(statusText)\r\nContent-Type: application/json\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        conn.send(content: response.data(using: .utf8), completion: .contentProcessed({ _ in
            conn.cancel()
        }))
    }
}
