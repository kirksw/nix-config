import Foundation
import Darwin

struct ProcessResult { let status: Int32; let output: Data; let timedOut: Bool; let truncated: Bool }

enum BoundedProcess {
    static func run(executableURL: URL, arguments: [String], timeout: TimeInterval = 4,
                    outputLimit: Int = 1_048_576) -> ProcessResult? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        defer { try? pipe.fileHandleForReading.close(); try? pipe.fileHandleForWriting.close() }
        do { try process.run() } catch { return nil }
        try? pipe.fileHandleForWriting.close()
        let fd = pipe.fileHandleForReading.fileDescriptor
        _ = fcntl(fd, F_SETFL, O_NONBLOCK)
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var output = Data()
        var timedOut = false
        var truncated = false
        var buffer = [UInt8](repeating: 0, count: 16384)
        // Drain without waiting for EOF: a descendant may inherit the write descriptor.
        repeat {
            let count = read(fd, &buffer, buffer.count)
            if count > 0 {
                let remaining = max(0, outputLimit - output.count)
                output.append(contentsOf: buffer.prefix(min(count, remaining)))
                truncated = truncated || count > remaining
            } else if !process.isRunning { break }
            if ProcessInfo.processInfo.systemUptime >= deadline {
                timedOut = true
                break
            }
            if count <= 0 { usleep(5000) }
        } while true
        if process.isRunning {
            process.terminate()
            let grace = ProcessInfo.processInfo.systemUptime + 0.5
            while process.isRunning && ProcessInfo.processInfo.systemUptime < grace { usleep(5000) }
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
        process.waitUntilExit()
        return ProcessResult(status: process.terminationStatus, output: output, timedOut: timedOut, truncated: truncated)
    }
}
