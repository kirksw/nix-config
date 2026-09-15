import AppKit
import Darwin
import EventKit
import Foundation
import CoreLocation
import WebKit

@_silgen_name("EdgeTouchRuntimeCreateAndStart")
private func EdgeTouchRuntimeCreateAndStart() -> UnsafeMutableRawPointer?
@_silgen_name("EdgeTouchRuntimeStop")
private func EdgeTouchRuntimeStop(_ handle: UnsafeMutableRawPointer?)

private let targetDisplayName = "XENEON EDGE"
private let targetCalendarName = "kisw@lunar.app"
private let dashboardTitle = "EDGE / Observatory"

private struct AgentPayload: Codable {
    let status: String
    let updatedAt: String
    let agents: [AgentRecord]
}
private struct CalendarEvent: Codable {
    let title: String
    let start: String
    let end: String
    let allDay: Bool
}
private struct CalendarPayload: Codable {
    let status: String
    let message: String
    let updatedAt: String
    let events: [CalendarEvent]
}

private struct ConversationMessage: Codable {
    let role: String
    let text: String
}

private struct ConversationPayload: Codable {
    let id: String
    let status: String
    let messages: [ConversationMessage]
}

private struct CostWindowsPayload: Codable {
    let status: String
    let updatedAt: String
    let costs: [String: Double]
}

private struct WeatherPayload: Codable {
    let status: String
    let message: String
    let temperature: Double?
    let weatherCode: Int?
    let high: Double?
    let low: Double?
    let days: [WeatherDay]
}

private struct WeatherDay: Codable { let date: String; let code: Int; let high: Double; let low: Double }
private struct OpenMeteoResponse: Decodable {
    struct Current: Decodable { let temperature_2m: Double; let weather_code: Int }
    struct Daily: Decodable { let time: [String]; let weather_code: [Int]; let temperature_2m_max: [Double]; let temperature_2m_min: [Double] }
    let current: Current; let daily: Daily
}

private final class NativeBridge: NSObject, WKScriptMessageHandler, CLLocationManagerDelegate {
    weak var webView: WKWebView?
    private var tracker = UnreadTracker()
    private var agentsPending = false
    private var outputPending = false
    private let outputQueue = DispatchQueue(label: "local.edge-observatory.output", qos: .utility)
    private var sessionPaths: [String: String] = [:]
    private var statisticsCache: [String: (date: Date, cost: Double?, tokens: Int?)] = [:]
    private var costsPending = false
    private var costWindowsCache: (date: Date, costs: [String: Double])?
    private let costQueue = DispatchQueue(label: "local.edge-observatory.costs", qos: .utility)
    private let isoFormatter = ISO8601DateFormatter()
    private let sessionTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let agentQueue = DispatchQueue(label: "local.edge-observatory.agents", qos: .utility)
    private let calendarQueue = DispatchQueue(label: "local.edge-observatory.calendar", qos: .utility)
    private let brightnessQueue = DispatchQueue(label: "local.edge-observatory.brightness", qos: .utility)
    private let temperatureQueue = DispatchQueue(label: "local.edge-observatory.temperature", qos: .utility)
    private var brightnessPending = false
    private var queuedBrightness: Int?
    private var temperaturePending = false
    private var weatherPending = false
    private let locationManager = CLLocationManager()
    private let eventStore = EKEventStore()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              message.name == "agents" || message.name == "calendar" || message.name == "agentMessages" || message.name == "weather" || message.name == "costWindows" || message.name == "brightness" || message.name == "temperature",
              let index = Bundle.main.url(forResource: "index", withExtension: "html"),
              message.frameInfo.request.url == index else { return }
        if message.name == "brightness" {
            let action = (message.body as? [String: Any])?["action"] as? String ?? "read"
            let value = (message.body as? [String: Any])?["value"] as? Int
            requestBrightness(action: action, value: value)
        } else if message.name == "temperature" {
            let preset = (message.body as? [String: Any])?["preset"] as? String ?? "read"
            requestTemperature(preset: preset)
        } else if message.name == "agentMessages" {
            guard let body = message.body as? [String: String], let id = body["id"],
                  id.range(of: "^w[A-Za-z0-9]+:p[0-9]+$", options: .regularExpression) != nil,
                  id.count <= 64, !outputPending, let sessionPath = sessionPaths[id] else { return }
            outputPending = true
            outputQueue.async { [weak self] in
                guard let self else { return }
                defer { DispatchQueue.main.async { self.outputPending = false } }
                self.send("agentMessages", self.readMessages(id: id, sessionPath: sessionPath))
            }
        } else if message.name == "agents" { requestAgents() } else if message.name == "calendar" { requestCalendar() } else if message.name == "weather" { requestWeather() } else { requestCostWindows() }
    }

    private func send<T: Encodable>(_ name: String, _ payload: T) {
        guard let data = try? JSONEncoder().encode(payload),
              let object = try? JSONSerialization.jsonObject(with: data) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, let webView = self.webView else { return }
            webView.callAsyncJavaScript("window.edgeNativeReceive(name, payload)",
                arguments: ["name": name, "payload": object], in: nil, in: .page) { _ in }
        }
    }

    private func sendError(_ name: String, _ message: String) {
        if name == "agents" { send(name, AgentPayload(status: "disconnected", updatedAt: isoFormatter.string(from: Date()), agents: [])) }
        else { send(name, CalendarPayload(status: "disconnected", message: message, updatedAt: isoFormatter.string(from: Date()), events: [])) }
    }

    private func herdrURL() -> URL? {
        let user = NSUserName()
        let paths = ["/run/current-system/sw/bin/herdr", "/etc/profiles/per-user/\(user)/bin/herdr",
                     "\(NSHomeDirectory())/.local/bin/herdr", "/opt/homebrew/bin/herdr", "/usr/local/bin/herdr"]
        return paths.lazy.map(URL.init(fileURLWithPath:)).first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func requestTemperature(preset: String) {
        guard !temperaturePending, ["read", "warm", "neutral", "cool", "restore"].contains(preset) else { return }
        temperaturePending = true
        temperatureQueue.async { [weak self] in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.temperaturePending = false } }
            let payload: TemperaturePayload
            switch preset {
            case "warm", "neutral", "cool": payload = XeneonGamma.set(preset)
            case "restore": payload = XeneonGamma.restore()
            default: payload = XeneonGamma.read()
            }
            self.send("temperature", payload)
        }
    }

    private func requestBrightness(action: String, value: Int?) {
        guard action == "read" || action == "restore" || (action == "set" && value != nil) else { return }
        if action == "set" {
            // Keep only the newest slider position while one DDC transaction is in flight.
            queuedBrightness = value
            startBrightnessWorkerIfNeeded()
            return
        }
        guard !brightnessPending else { return }
        brightnessPending = true
        brightnessQueue.async { [weak self] in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.brightnessPending = false } }
            self.send("brightness", action == "restore" ? XeneonDdc.restore() : XeneonDdc.read())
        }
    }

    private func startBrightnessWorkerIfNeeded() {
        guard !brightnessPending else { return }
        brightnessPending = true
        brightnessQueue.async { [weak self] in
            guard let self else { return }
            while let target = DispatchQueue.main.sync(execute: { () -> Int? in
                let value = self.queuedBrightness
                self.queuedBrightness = nil
                return value
            }) {
                self.send("brightness", XeneonDdc.set(target))
            }
            DispatchQueue.main.async {
                self.brightnessPending = false
                // A slider event can land after the last dequeue but before this reset.
                self.startBrightnessWorkerIfNeeded()
            }
        }
    }

    private func requestCostWindows() {
        if let cached = costWindowsCache, Date().timeIntervalSince(cached.date) < 300 {
            send("costWindows", CostWindowsPayload(status: "connected", updatedAt: isoFormatter.string(from: cached.date), costs: cached.costs))
            return
        }
        guard !costsPending else { return }
        costsPending = true
        costQueue.async { [weak self] in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.costsPending = false } }
            let costs = self.collectCostWindows()
            self.costWindowsCache = (Date(), costs)
            self.send("costWindows", CostWindowsPayload(status: "connected", updatedAt: self.isoFormatter.string(from: Date()), costs: costs))
        }
    }

    private func collectCostWindows() -> [String: Double] {
        let now = Date().timeIntervalSince1970 * 1000
        let windows: [(String, Double)] = [("1d", 86_400_000), ("3d", 259_200_000), ("7d", 604_800_000), ("30d", 2_592_000_000)]
        var totals = Dictionary(uniqueKeysWithValues: windows.map { ($0.0, 0.0) })
        let root = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/share/nix-agents/pi/sessions")
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { return totals }
        while let file = enumerator.nextObject() as? URL {
            guard file.pathExtension == "jsonl",
                  let attributes = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = attributes.contentModificationDate,
                  now - modified.timeIntervalSince1970 * 1000 <= 2_592_000_000 else { continue }
            guard let data = try? Data(contentsOf: file), data.count <= 16_000_000 else { continue }
            for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
                guard let item = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                      let timestamp = item["timestamp"],
                      let message = item["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any],
                      let rawCost = usage["cost"] as? [String: Any],
                      let cost = rawCost["total"] as? Double else { continue }
                let recordTime: Double
                if let numeric = timestamp as? Double {
                    // Pi timestamps are milliseconds, but tolerate seconds-only records.
                    recordTime = numeric > 10_000_000_000 ? numeric : numeric * 1000
                } else if let value = timestamp as? String, let date = sessionTimestampFormatter.date(from: value) {
                    recordTime = date.timeIntervalSince1970 * 1000
                } else { continue }
                for (name, duration) in windows where now - recordTime <= duration && now >= recordTime {
                    totals[name, default: 0] += cost
                }
            }
        }
        return totals
    }

    private func costStatistics(sessionPath: String) -> (cost: Double?, tokens: Int?) {
        if let cached = statisticsCache[sessionPath], Date().timeIntervalSince(cached.date) < 30 {
            return (cached.cost, cached.tokens)
        }
        let base = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/share/nix-agents/pi/sessions").standardizedFileURL.path + "/"
        let file = URL(fileURLWithPath: sessionPath).standardizedFileURL
        guard sessionPath.hasPrefix(base), file.pathExtension == "jsonl",
              let handle = try? FileHandle(forReadingFrom: file),
              let data = try? handle.readToEnd(), data.count <= 16_000_000 else { return (nil, nil) }
        defer { try? handle.close() }
        var cost = 0.0
        var tokens = 0
        var sawCost = false
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            guard let item = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let message = item["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }
            if let value = usage["totalTokens"] as? Int { tokens += value }
            if let rawCost = usage["cost"] as? [String: Any], let value = rawCost["total"] as? Double {
                cost += value
                sawCost = true
            }
        }
        let result = (sawCost ? cost : nil, tokens > 0 ? tokens : nil)
        statisticsCache[sessionPath] = (Date(), result.0, result.1)
        return result
    }

    private func readMessages(id: String, sessionPath: String) -> ConversationPayload {
        let base = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/share/nix-agents/pi/sessions").standardizedFileURL.path + "/"
        let file = URL(fileURLWithPath: sessionPath).standardizedFileURL
        guard sessionPath.hasPrefix(base), file.pathExtension == "jsonl",
              let handle = try? FileHandle(forReadingFrom: file),
              let data = try? handle.readToEnd(), data.count <= 16_000_000 else {
            return ConversationPayload(id: id, status: "disconnected", messages: [])
        }
        defer { try? handle.close() }
        var messages: [ConversationMessage] = []
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n").suffix(500) {
            guard let item = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  item["type"] as? String == "message", let message = item["message"] as? [String: Any],
                  let role = message["role"] as? String, role == "user" || role == "assistant",
                  let parts = message["content"] as? [[String: Any]] else { continue }
            let text = parts.compactMap { part -> String? in
                guard part["type"] as? String == "text", let value = part["text"] as? String else { return nil }
                return value
            }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { messages.append(ConversationMessage(role: role, text: String(text.prefix(4000)))) }
        }
        return ConversationPayload(id: id, status: "connected", messages: Array(messages.suffix(10)))
    }

    private func requestAgents() {
        guard !agentsPending else { return }
        agentsPending = true
        agentQueue.async { [weak self] in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.agentsPending = false } }
            guard let executable = self.herdrURL(),
                  let result = BoundedProcess.run(executableURL: executable, arguments: ["api", "snapshot"]) else {
                self.sendError("agents", "Herdr is unavailable. Retrying automatically."); return
            }
            guard result.status == 0, !result.timedOut, !result.truncated,
                  let envelope = try? JSONDecoder().decode(HerdrEnvelope.self, from: result.output) else {
                self.sendError("agents", "Herdr is unavailable. Retrying automatically."); return
            }
            let workspaces = Dictionary(uniqueKeysWithValues: envelope.result.snapshot.workspaces.map { ($0.workspaceID, String($0.label.prefix(128))) })
            self.sessionPaths = Dictionary(uniqueKeysWithValues: envelope.result.snapshot.agents.compactMap { raw in
                guard let value = raw.agentSession?.value else { return nil }
                return (raw.paneID, value)
            })
            let records = envelope.result.snapshot.agents.map { raw in
                let sessionPath = raw.agentSession?.value
                let statistics = sessionPath.map { self.costStatistics(sessionPath: $0) }
                return AgentRecord(id: String(raw.paneID.prefix(256)), agent: String((raw.agent ?? "unknown").prefix(128)),
                            status: String((raw.agentStatus ?? "unknown").prefix(32)),
                            workspace: String((workspaces[raw.workspaceID ?? ""] ?? "Unknown workspace").prefix(128)),
                            sessionIdentity: sessionPath, focused: raw.focused ?? false, cost: statistics?.cost, tokens: statistics?.tokens, unread: false)
            }
            let marked = self.tracker.update(records)
            self.send("agents", AgentPayload(status: "connected", updatedAt: self.isoFormatter.string(from: Date()), agents: marked))
        }
    }

    private func requestWeather() {
        guard !weatherPending else { return }
        weatherPending = true
        switch locationManager.authorizationStatus {
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways: locationManager.requestLocation()
        default:
            weatherPending = false
            send("weather", WeatherPayload(status: "permission_required", message: "Allow location access for local weather.", temperature: nil, weatherCode: nil, high: nil, low: nil, days: []))
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
        else if manager.authorizationStatus != .notDetermined {
            weatherPending = false
            send("weather", WeatherPayload(status: "permission_required", message: "Allow location access for local weather.", temperature: nil, weatherCode: nil, high: nil, low: nil, days: []))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        weatherPending = false
        send("weather", WeatherPayload(status: "unavailable", message: "Location is unavailable.", temperature: nil, weatherCode: nil, high: nil, low: nil, days: []))
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(location.coordinate.latitude)&longitude=\(location.coordinate.longitude)&current=temperature_2m,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=3&timezone=auto")!
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }
            defer { DispatchQueue.main.async { self.weatherPending = false } }
            guard let data, let response = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data),
                  response.daily.time.count >= 1, response.daily.weather_code.count >= 1,
                  response.daily.temperature_2m_max.count >= 1, response.daily.temperature_2m_min.count >= 1 else {
                self.send("weather", WeatherPayload(status: "unavailable", message: "Weather service is unavailable.", temperature: nil, weatherCode: nil, high: nil, low: nil, days: [])); return
            }
            let days = zip(zip(response.daily.time, response.daily.weather_code), zip(response.daily.temperature_2m_max, response.daily.temperature_2m_min)).prefix(3).map { WeatherDay(date: $0.0.0, code: $0.0.1, high: $0.1.0, low: $0.1.1) }
            self.send("weather", WeatherPayload(status: "connected", message: "Open-Meteo / laptop location", temperature: response.current.temperature_2m, weatherCode: response.current.weather_code, high: days[0].high, low: days[0].low, days: Array(days)))
        }.resume()
    }

    private func requestCalendar() {
        calendarQueue.async { [weak self] in
            guard let self else { return }
            let status = EKEventStore.authorizationStatus(for: .event)
            guard status == .fullAccess else {
                self.send("calendar", CalendarPayload(status: "permission_required", message: "Allow calendar access for EDGE Observatory in System Settings.", updatedAt: self.isoFormatter.string(from: Date()), events: []))
                if status == .notDetermined { self.eventStore.requestFullAccessToEvents { _, _ in } }
                return
            }
            let calendars = self.eventStore.calendars(for: .event).filter { $0.title == targetCalendarName }
            guard calendars.count == 1 else {
                self.send("calendar", CalendarPayload(status: "calendar_not_found", message: calendars.isEmpty ? "Selected calendar is not available in Apple Calendar yet." : "Multiple calendars have this name.", updatedAt: self.isoFormatter.string(from: Date()), events: [])); return
            }
            let now = Date(); let end = Calendar.current.date(byAdding: .day, value: 2, to: Calendar.current.startOfDay(for: now))!
            let events = self.eventStore.events(matching: self.eventStore.predicateForEvents(withStart: now, end: end, calendars: calendars)).filter { $0.endDate > now && $0.status != .canceled }.sorted { $0.startDate < $1.startDate }.prefix(32).map {
                CalendarEvent(title: String(($0.title ?? "Untitled event").prefix(512)), start: self.isoFormatter.string(from: $0.startDate), end: self.isoFormatter.string(from: $0.endDate), allDay: $0.isAllDay)
            }
            self.send("calendar", CalendarPayload(status: "connected", message: "Apple Calendar / today and tomorrow", updatedAt: self.isoFormatter.string(from: Date()), events: Array(events)))
        }
    }
}

private final class DashboardWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class ObservatoryController: NSObject, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    private var window: NSWindow?
    private var bridge: NativeBridge?
    private var statusItem: NSStatusItem?
    private var touchRuntime: UnsafeMutableRawPointer?
    private var quitItem: NSMenuItem?
    private var fullscreenTransition = false

    func start() {
        NSApp.mainMenu = makeMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "EDGE"
        statusItem?.menu = makeMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        showOnTargetIfPresent()
    }
    private func makeMenu() -> NSMenu {
        let menu = NSMenu(); let app = NSMenuItem(); menu.addItem(app)
        let submenu = NSMenu(); app.submenu = submenu
        submenu.addItem(withTitle: "Quit EDGE Observatory", action: #selector(quit), keyEquivalent: "q").target = self
        quitItem = submenu.items.last; return menu
    }
    @objc private func quit() { _ = XeneonGamma.restore(); NSApp.terminate(nil) }
    @objc private func screensChanged() { showOnTargetIfPresent() }
    private func showOnTargetIfPresent() {
        guard let screen = NSScreen.screens.first(where: { $0.localizedName == targetDisplayName }) else {
            // Discard the old native fullscreen Space; it cannot be reused after hotplug.
            window?.orderOut(nil)
            window?.delegate = nil
            window?.close()
            window = nil
            bridge = nil
            _ = XeneonGamma.restore()
            fullscreenTransition = false
            EdgeTouchRuntimeStop(touchRuntime)
            touchRuntime = nil
            return
        }
        if window == nil {
            let content = WKUserContentController(); let newBridge = NativeBridge(); let configuration = WKWebViewConfiguration(); configuration.userContentController = content
            content.add(newBridge, name: "agents"); content.add(newBridge, name: "calendar"); content.add(newBridge, name: "agentMessages"); content.add(newBridge, name: "weather"); content.add(newBridge, name: "costWindows"); content.add(newBridge, name: "brightness"); content.add(newBridge, name: "temperature")
            let webView = WKWebView(frame: .zero, configuration: configuration); newBridge.webView = webView; webView.navigationDelegate = self; webView.uiDelegate = self; webView.setValue(false, forKey: "drawsBackground")
            window = DashboardWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false); window?.title = dashboardTitle; window?.contentView = webView; window?.delegate = self; window?.isReleasedWhenClosed = false; window?.isOpaque = true; window?.backgroundColor = NSColor(calibratedWhite: 0.07, alpha: 1); window?.level = .normal; window?.collectionBehavior = [.fullScreenPrimary]; window?.isMovable = false; window?.acceptsMouseMovedEvents = true
            window?.makeFirstResponder(webView); bridge = newBridge
            if let index = Bundle.main.url(forResource: "index", withExtension: "html"), let root = Bundle.main.resourceURL { webView.loadFileURL(index, allowingReadAccessTo: root) }
            touchRuntime = EdgeTouchRuntimeCreateAndStart()
        }
        guard let window else { return }
        if !window.styleMask.contains(.fullScreen) && !fullscreenTransition {
            window.setFrame(screen.frame, display: true)
            window.makeKeyAndOrderFront(nil)
            fullscreenTransition = true
            window.toggleFullScreen(nil)
        }
    }
    func windowDidEnterFullScreen(_ notification: Notification) { fullscreenTransition = false }
    func windowDidExitFullScreen(_ notification: Notification) { fullscreenTransition = false }
    func windowDidFailToEnterFullScreen(_ window: NSWindow) { fullscreenTransition = false }
    func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions) -> NSApplication.PresentationOptions {
        var options = proposedOptions
        options.remove(.hideMenuBar)
        options.remove(.hideDock)
        options.insert([.autoHideMenuBar, .autoHideDock])
        return options
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { false }
    deinit { _ = XeneonGamma.restore(); EdgeTouchRuntimeStop(touchRuntime); if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) } }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url, url.isFileURL, let root = Bundle.main.resourceURL, url.path == root.appendingPathComponent("index.html").path else { decisionHandler(.cancel); return }; decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { webView.evaluateJavaScript("document.documentElement.setAttribute('data-native','1')") }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = ObservatoryController()
    func applicationDidFinishLaunching(_ notification: Notification) { _ = notification; NSApp.setActivationPolicy(.accessory); controller.start() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main struct ObservatoryMain {
    static func main() { let app = NSApplication.shared; let delegate = AppDelegate(); app.delegate = delegate; app.run() }
}
