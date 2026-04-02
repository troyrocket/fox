import Foundation

class SlapDetector {
    var onSlap: ((Double) -> Void)?
    private var process: Process?

    func start() {
        let execDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let helperPath = execDir.appendingPathComponent("accel-helper").path

        guard FileManager.default.isExecutableFile(atPath: helperPath) else {
            print("SlapDetector: accel-helper not found at \(helperPath)")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: helperPath)

        let outPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = Pipe()

        proc.terminationHandler = { [weak self] p in
            print("SlapDetector: helper exited with code \(p.terminationStatus)")
            // Retry after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.start()
            }
        }

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.components(separatedBy: "\n") {
                if line.hasPrefix("SLAP:") {
                    let forceStr = String(line.dropFirst(5))
                    if let force = Double(forceStr) {
                        DispatchQueue.main.async { self?.onSlap?(force) }
                    }
                } else if line == "READY" {
                    print("SlapDetector: Accelerometer monitoring started")
                }
            }
        }

        do {
            try proc.run()
            process = proc
            print("SlapDetector: Helper launched (PID \(proc.processIdentifier))")
        } catch {
            print("SlapDetector: Failed to launch helper: \(error)")
        }
    }

    func stop() {
        process?.terminate()
        process = nil
    }
}
