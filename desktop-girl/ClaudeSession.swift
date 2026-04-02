import Foundation

class ClaudeSession {
    private var process: Process?
    private var inputPipe: Pipe?
    private var lineBuffer = ""
    private var currentResponseText = ""
    private var pendingMessages: [String] = []
    private(set) var isRunning = false
    private(set) var isBusy = false
    private static var binaryPath: String?

    var onText: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onToolUse: ((String, String) -> Void)?
    var onToolResult: ((String, Bool) -> Void)?
    var onTurnComplete: (() -> Void)?

    func start() {
        if let cached = Self.binaryPath { launchProcess(binaryPath: cached); return }

        let home = FileManager.default.homeDirectoryForCurrentUser.path

        var candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude"
        ]

        // Add nvm paths
        let nvmDir = "\(home)/.nvm/versions/node"
        if let nodes = try? FileManager.default.contentsOfDirectory(atPath: nvmDir) {
            for node in nodes {
                candidates.append("\(nvmDir)/\(node)/bin/claude")
            }
        }

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                print("Claude CLI found at: \(path)")
                Self.binaryPath = path
                launchProcess(binaryPath: path)
                return
            }
        }

        onError?("Claude CLI not found.\n\nInstall: curl -fsSL https://claude.ai/install.sh | sh")
    }

    private func launchProcess(binaryPath: String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binaryPath)
        proc.arguments = [
            "-p",
            "--output-format", "stream-json",
            "--input-format", "stream-json",
            "--verbose",
            "--append-system-prompt", CHARACTER_SYSTEM_PROMPT
        ]
        // Set working directory to the project root
        let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let projectDir = execDir.deletingLastPathComponent()
        proc.currentDirectoryURL = projectDir
        proc.environment = ShellEnvironment.processEnvironment()

        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        proc.standardInput = inPipe
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { self?.isRunning = false; self?.isBusy = false }
        }
        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { self?.processOutput(text) }
        }
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            print("Claude stderr: \(text)")
            DispatchQueue.main.async { self?.onError?(text) }
        }

        do {
            try proc.run()
            process = proc; inputPipe = inPipe; isRunning = true
            print("Claude CLI launched: PID \(proc.processIdentifier)")
            print("Claude CLI path: \(binaryPath)")
            print("Claude CLI args: \(proc.arguments ?? [])")
            for msg in pendingMessages { writeMessage(msg) }
            pendingMessages.removeAll()
        } catch {
            print("Claude CLI FAILED: \(error.localizedDescription)")
            onError?("Failed to launch Claude CLI: \(error.localizedDescription)")
        }
    }

    func send(message: String) {
        print("Claude send: isRunning=\(isRunning) message=\(message.prefix(50))")
        guard isRunning else { pendingMessages.append(message); print("Claude: queued (not running)"); return }
        writeMessage(message)
    }

    private func writeMessage(_ message: String) {
        guard let pipe = inputPipe else { print("Claude: no input pipe!"); return }
        isBusy = true; currentResponseText = ""
        let payload: [String: Any] = ["type": "user", "message": ["role": "user", "content": message]]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonStr = String(data: data, encoding: .utf8) else { print("Claude: JSON encode failed"); return }
        print("Claude writing: \(jsonStr.prefix(100))")
        pipe.fileHandleForWriting.write((jsonStr + "\n").data(using: .utf8)!)
    }

    func terminate() { process?.terminate(); isRunning = false }

    // MARK: - NDJSON Parsing

    private func processOutput(_ text: String) {
        lineBuffer += text
        while let nl = lineBuffer.range(of: "\n") {
            let line = String(lineBuffer[..<nl.lowerBound])
            lineBuffer = String(lineBuffer[nl.upperBound...])
            if !line.isEmpty { parseLine(line) }
        }
    }

    private func parseLine(_ line: String) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let type = json["type"] as? String ?? ""
        switch type {
        case "assistant":
            if let msg = json["message"] as? [String: Any],
               let content = msg["content"] as? [[String: Any]] {
                for block in content {
                    let bt = block["type"] as? String ?? ""
                    if bt == "text", let t = block["text"] as? String {
                        currentResponseText += t; onText?(t)
                    } else if bt == "tool_use" {
                        let name = block["name"] as? String ?? "Tool"
                        let input = block["input"] as? [String: Any] ?? [:]
                        let summary = formatToolSummary(name, input)
                        onToolUse?(name, summary)
                    }
                }
            }
        case "user":
            if let msg = json["message"] as? [String: Any],
               let content = msg["content"] as? [[String: Any]] {
                for block in content {
                    if block["type"] as? String == "tool_result" {
                        let isErr = block["is_error"] as? Bool ?? false
                        let summary = (block["content"] as? String).map { String($0.prefix(80)) } ?? ""
                        onToolResult?(summary, isErr)
                    }
                }
            }
        case "result":
            isBusy = false; currentResponseText = ""; onTurnComplete?()
        default: break
        }
    }

    private func formatToolSummary(_ name: String, _ input: [String: Any]) -> String {
        switch name {
        case "Bash": return input["command"] as? String ?? ""
        case "Read", "Edit", "Write": return input["file_path"] as? String ?? ""
        case "Glob", "Grep": return input["pattern"] as? String ?? ""
        default: return input["description"] as? String ?? input.keys.prefix(3).joined(separator: ", ")
        }
    }
}
