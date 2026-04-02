import Foundation

let CHARACTER_NAME = "Jessica"

/// Loads all .md files from persona/ directory and combines them into a system prompt
func loadPersonaPrompt() -> String {
    let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
    let personaDir = execDir.appendingPathComponent("persona")

    guard let files = try? FileManager.default.contentsOfDirectory(atPath: personaDir.path) else {
        return "You are \(CHARACTER_NAME), a helpful AI desktop companion."
    }

    let mdFiles = files.filter { $0.hasSuffix(".md") }.sorted()
    var sections: [String] = []

    for file in mdFiles {
        let path = personaDir.appendingPathComponent(file).path
        if let content = try? String(contentsOfFile: path, encoding: .utf8) {
            sections.append(content.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    if sections.isEmpty {
        return "You are \(CHARACTER_NAME), a helpful AI desktop companion."
    }

    return "You are \(CHARACTER_NAME). Here is your character profile:\n\n" + sections.joined(separator: "\n\n")
}

let CHARACTER_SYSTEM_PROMPT = loadPersonaPrompt()
