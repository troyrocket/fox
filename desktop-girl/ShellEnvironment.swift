import Foundation

class ShellEnvironment {
    private static var cachedEnvironment: [String: String]?

    static func resolve(completion: @escaping ([String: String]?) -> Void) {
        if let cached = cachedEnvironment { completion(cached); return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
        proc.arguments = ["-l", "-i", "-c", "echo '---ENV_START---' && env && echo '---ENV_END---'"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        proc.terminationHandler = { _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                if let s = output.range(of: "---ENV_START---\n"),
                   let e = output.range(of: "\n---ENV_END---") {
                    var env: [String: String] = [:]
                    for line in String(output[s.upperBound..<e.lowerBound]).components(separatedBy: "\n") {
                        if let eq = line.range(of: "=") {
                            env[String(line[..<eq.lowerBound])] = String(line[eq.upperBound...])
                        }
                    }
                    cachedEnvironment = env
                    completion(env)
                } else { completion(nil) }
            }
        }
        do { try proc.run() } catch { completion(nil) }
    }

    static func findBinary(name: String, fallbackPaths: [String], completion: @escaping (String?) -> Void) {
        resolve { env in
            if let shellPath = env?["PATH"] {
                for dir in shellPath.components(separatedBy: ":") {
                    let candidate = "\(dir)/\(name)"
                    if FileManager.default.isExecutableFile(atPath: candidate) {
                        completion(candidate); return
                    }
                }
            }
            for fallback in fallbackPaths {
                if FileManager.default.isExecutableFile(atPath: fallback) {
                    completion(fallback); return
                }
            }
            completion(nil)
        }
    }

    static func processEnvironment() -> [String: String] {
        var env = cachedEnvironment ?? ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let essentialPaths = ["\(home)/.local/bin", "/usr/local/bin", "/opt/homebrew/bin"]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        let missing = essentialPaths.filter { !currentPath.contains($0) }
        if !missing.isEmpty { env["PATH"] = (missing + [currentPath]).joined(separator: ":") }
        env["TERM"] = "dumb"
        env.removeValue(forKey: "CLAUDECODE")
        env.removeValue(forKey: "CLAUDE_CODE_ENTRYPOINT")
        return env
    }
}
