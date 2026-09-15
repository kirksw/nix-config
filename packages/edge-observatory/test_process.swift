import Foundation

@main struct ProcessTests {
    static func main() {
        let shell = URL(fileURLWithPath: "/bin/sh")
        let large = BoundedProcess.run(executableURL: shell, arguments: ["-c", "yes x | head -c 200000"], outputLimit: 300000)!
        assert(large.status == 0 && large.output.count == 200000 && !large.truncated)
        let capped = BoundedProcess.run(executableURL: shell, arguments: ["-c", "yes x | head -c 200000"], outputLimit: 1000)!
        assert(capped.truncated && capped.output.count == 1000)
        let start = Date()
        let hung = BoundedProcess.run(executableURL: shell, arguments: ["-c", "trap '' TERM; while :; do :; done"], timeout: 0.2)!
        assert(hung.timedOut && Date().timeIntervalSince(start) < 2)
        let descendant = BoundedProcess.run(executableURL: shell, arguments: ["-c", "sleep 2 & echo ok"], timeout: 0.2)!
        assert(descendant.output.count == 3)
        print("Process output, cap, TERM-resistant timeout, and inherited-pipe tests passed")
    }
}
