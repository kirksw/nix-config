import AppKit
import CoreGraphics
import Foundation

struct TemperaturePayload: Codable {
    let status: String
    let message: String
    let preset: String
}

enum XeneonGamma {
    private static let edgeName = "XENEON EDGE"
    private static let edgeEdid = "0E5800ED-0000-0000-1715-0104B5221478"
    private static let m1ddc = URL(fileURLWithPath: "/opt/homebrew/bin/m1ddc")
    private static let stateURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".local/state/edge-observatory/temperature.json")
    private static let lockURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".local/state/edge-observatory/temperature.lock")
    private static let tableSize = 256

    private struct TransferState: Codable {
        let red: [Double]
        let green: [Double]
        let blue: [Double]
        let preset: String
    }

    static func read() -> TemperaturePayload {
        withLock {
            guard targetDisplay() != nil else { return unavailable("The pinned XENEON EDGE display is unavailable.") }
            return TemperaturePayload(status: "connected", message: "Display-only color temperature is ready.", preset: savedState()?.preset ?? "neutral")
        }
    }

    static func set(_ preset: String) -> TemperaturePayload {
        withLock {
            guard ["warm", "neutral", "cool"].contains(preset) else { return unavailable("Unknown color-temperature preset.") }
            guard let display = targetDisplay() else { return unavailable("The pinned XENEON EDGE display is unavailable.") }
            let original: TransferState
            if let state = savedState() {
                original = state
            } else if let captured = captureTransfer(for: display) {
                original = captured
            } else {
                return unavailable("Could not capture the EDGE color transform.")
            }
            guard apply(preset: preset, original: original, to: display) else { return unavailable("Could not apply EDGE color temperature.") }
            guard save(TransferState(red: original.red, green: original.green, blue: original.blue, preset: preset)) else {
                return unavailable("Could not save the EDGE color restore state.")
            }
            return TemperaturePayload(status: "connected", message: "EDGE color temperature set to \(preset).", preset: preset)
        }
    }

    static func restore() -> TemperaturePayload {
        withLock {
            guard let state = savedState() else {
                return TemperaturePayload(status: "connected", message: "EDGE color temperature is already restored.", preset: "neutral")
            }
            guard let display = targetDisplay() else { return unavailable("The pinned XENEON EDGE display is unavailable.") }
            guard setTransfer(state, for: display) else { return unavailable("Could not restore the EDGE color transform.") }
            try? FileManager.default.removeItem(at: stateURL)
            return TemperaturePayload(status: "connected", message: "EDGE color temperature restored.", preset: "neutral")
        }
    }

    private static func unavailable(_ message: String) -> TemperaturePayload {
        TemperaturePayload(status: "unavailable", message: message, preset: savedState()?.preset ?? "neutral")
    }

    private static func targetDisplay() -> CGDirectDisplayID? {
        guard displayIsPinned(),
              let screen = NSScreen.screens.first(where: { $0.localizedName == edgeName }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
        return CGDirectDisplayID(number.uint32Value)
    }

    private static func displayIsPinned() -> Bool {
        guard let result = BoundedProcess.run(executableURL: m1ddc, arguments: ["display", "list", "detailed"], timeout: 3, outputLimit: 32_768),
              result.status == 0, !result.timedOut, !result.truncated else { return false }
        let description = String(decoding: result.output, as: UTF8.self)
        return description.contains(edgeName) && description.localizedCaseInsensitiveContains(edgeEdid)
    }

    private static func captureTransfer(for display: CGDirectDisplayID) -> TransferState? {
        var red = [CGGammaValue](repeating: 0, count: tableSize)
        var green = [CGGammaValue](repeating: 0, count: tableSize)
        var blue = [CGGammaValue](repeating: 0, count: tableSize)
        var count: UInt32 = 0
        guard CGGetDisplayTransferByTable(display, UInt32(tableSize), &red, &green, &blue, &count) == .success,
              count > 1, count <= UInt32(tableSize) else { return nil }
        let length = Int(count)
        return TransferState(red: red.prefix(length).map(Double.init), green: green.prefix(length).map(Double.init), blue: blue.prefix(length).map(Double.init), preset: "neutral")
    }

    private static func apply(preset: String, original: TransferState, to display: CGDirectDisplayID) -> Bool {
        let scales: (Double, Double, Double)
        switch preset {
        case "warm": scales = (1.0, 0.86, 0.68)
        case "cool": scales = (0.72, 0.88, 1.0)
        default: return setTransfer(original, for: display)
        }
        let adjusted = TransferState(
            red: original.red.map { min(1, $0 * scales.0) },
            green: original.green.map { min(1, $0 * scales.1) },
            blue: original.blue.map { min(1, $0 * scales.2) },
            preset: preset
        )
        return setTransfer(adjusted, for: display)
    }

    private static func setTransfer(_ state: TransferState, for display: CGDirectDisplayID) -> Bool {
        guard state.red.count == state.green.count, state.red.count == state.blue.count,
              state.red.count > 1, state.red.count <= tableSize else { return false }
        let red = state.red.map { CGGammaValue($0) }
        let green = state.green.map { CGGammaValue($0) }
        let blue = state.blue.map { CGGammaValue($0) }
        return red.withUnsafeBufferPointer { redBuffer in
            green.withUnsafeBufferPointer { greenBuffer in
                blue.withUnsafeBufferPointer { blueBuffer in
                    CGSetDisplayTransferByTable(display, UInt32(red.count), redBuffer.baseAddress!, greenBuffer.baseAddress!, blueBuffer.baseAddress!) == .success
                }
            }
        }
    }

    private static func savedState() -> TransferState? {
        guard let data = try? Data(contentsOf: stateURL), let state = try? JSONDecoder().decode(TransferState.self, from: data),
              state.red.count == state.green.count, state.red.count == state.blue.count, state.red.count > 1, state.red.count <= tableSize,
              state.red.allSatisfy({ (0...1).contains($0) }), state.green.allSatisfy({ (0...1).contains($0) }), state.blue.allSatisfy({ (0...1).contains($0) }) else { return nil }
        return state
    }

    private static func save(_ state: TransferState) -> Bool {
        do {
            try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
            return true
        } catch { return false }
    }

    private static func withLock<T>(_ body: () -> T) -> T {
        try? FileManager.default.createDirectory(at: lockURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return body() }
        defer { close(descriptor) }
        _ = flock(descriptor, LOCK_EX)
        defer { _ = flock(descriptor, LOCK_UN) }
        return body()
    }
}
