import Darwin
import Foundation

struct BrightnessPayload: Codable {
    let status: String
    let message: String
    let current: Int?
    let original: Int?
}

enum XeneonDdc {
    private static let edid = "0E5800ED-0000-0000-1715-0104B5221478"
    private static let displayName = "XENEON EDGE"
    private static let m1ddc = URL(fileURLWithPath: "/opt/homebrew/bin/m1ddc")
    private static let stateURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".local/state/edge-observatory/brightness.json")
    private static let lockURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".local/state/edge-observatory/brightness.lock")
    private static let allowedRange = 0...100
    private static let minimumBrightness = 5

    private struct SavedBrightness: Codable { let original: Int }

    static func read() -> BrightnessPayload {
        withLock {
            guard verifyDisplay() else { return unavailable("The pinned XENEON EDGE display is unavailable.") }
            guard let current = readBrightness() else { return unavailable("Could not read EDGE brightness.") }
            return BrightnessPayload(status: "connected", message: "EDGE brightness is ready.", current: current, original: savedBrightness())
        }
    }

    static func set(_ target: Int) -> BrightnessPayload {
        withLock {
            guard allowedRange.contains(target), target >= minimumBrightness else {
                return unavailable("Brightness must be between \(minimumBrightness) and 100.")
            }
            guard verifyDisplay() else { return unavailable("The pinned XENEON EDGE display is unavailable.") }
            guard let current = readBrightness() else { return unavailable("Could not read EDGE brightness.") }
            guard current != target else {
                return BrightnessPayload(status: "connected", message: "EDGE brightness is already \(target).", current: current, original: savedBrightness())
            }
            guard saveOriginalBrightnessIfNeeded(current) else {
                return unavailable("Could not save the current brightness for restore.")
            }
            guard run(["display", "edid=\(edid)", "set", "luminance", String(target)]) else {
                return unavailable("EDGE did not accept the brightness change.")
            }
            guard let verified = readBrightness(), verified == target else {
                return unavailable("EDGE brightness could not be verified after the change.")
            }
            return BrightnessPayload(status: "connected", message: "EDGE brightness set to \(target).", current: verified, original: savedBrightness())
        }
    }

    static func restore() -> BrightnessPayload {
        withLock {
            guard let original = savedBrightness() else {
                return unavailable("No saved EDGE brightness is available to restore.")
            }
            guard verifyDisplay() else { return unavailable("The pinned XENEON EDGE display is unavailable.") }
            guard let current = readBrightness() else { return unavailable("Could not read EDGE brightness.") }
            if current != original {
                guard run(["display", "edid=\(edid)", "set", "luminance", String(original)]),
                      let verified = readBrightness(), verified == original else {
                    return unavailable("EDGE brightness could not be restored.")
                }
            }
            try? FileManager.default.removeItem(at: stateURL)
            return BrightnessPayload(status: "connected", message: "EDGE brightness restored to \(original).", current: original, original: nil)
        }
    }

    private static func unavailable(_ message: String) -> BrightnessPayload {
        BrightnessPayload(status: "unavailable", message: message, current: nil, original: savedBrightness())
    }

    private static func verifyDisplay() -> Bool {
        guard let result = BoundedProcess.run(executableURL: m1ddc, arguments: ["display", "list", "detailed"], timeout: 3, outputLimit: 32_768),
              result.status == 0, !result.timedOut, !result.truncated else { return false }
        let description = String(decoding: result.output, as: UTF8.self)
        return description.contains(displayName) && description.localizedCaseInsensitiveContains(edid)
    }

    private static func readBrightness() -> Int? {
        guard let result = BoundedProcess.run(executableURL: m1ddc, arguments: ["display", "edid=\(edid)", "get", "luminance"], timeout: 3, outputLimit: 128),
              result.status == 0, !result.timedOut, !result.truncated,
              let value = Int(String(decoding: result.output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)),
              allowedRange.contains(value) else { return nil }
        return value
    }

    private static func run(_ arguments: [String]) -> Bool {
        guard let result = BoundedProcess.run(executableURL: m1ddc, arguments: arguments, timeout: 4, outputLimit: 4_096) else { return false }
        return result.status == 0 && !result.timedOut && !result.truncated
    }

    private static func savedBrightness() -> Int? {
        guard let data = try? Data(contentsOf: stateURL), let state = try? JSONDecoder().decode(SavedBrightness.self, from: data), allowedRange.contains(state.original) else { return nil }
        return state.original
    }

    private static func saveOriginalBrightnessIfNeeded(_ brightness: Int) -> Bool {
        guard savedBrightness() == nil else { return true }
        do {
            try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(SavedBrightness(original: brightness))
            try data.write(to: stateURL, options: .atomic)
            return true
        } catch { return false }
    }

    private static func withLock<T>(_ body: () -> T) -> T {
        let directory = lockURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return body() }
        defer { close(descriptor) }
        _ = flock(descriptor, LOCK_EX)
        defer { _ = flock(descriptor, LOCK_UN) }
        return body()
    }
}
