import AppKit
import Darwin
import EventKit
import Foundation
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

private final class NativeBridge: NSObject, WKScriptMessageHandler {
    weak var webView: WKWebView?
    private var tracker = UnreadTracker()
    private var agentsPending = false
    private let isoFormatter = ISO8601DateFormatter()
    private let agentQueue = DispatchQueue(label: "local.edge-observatory.agents", qos: .utility)
    private let calendarQueue = DispatchQueue(label: "local.edge-observatory.calendar", qos: .utility)
    private let eventStore = EKEventStore()

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              message.name == "agents" || message.name == "calendar",
              let index = Bundle.main.url(forResource: "index", withExtension: "html"),
              message.frameInfo.request.url == index else { return }
        if message.name == "agents" { requestAgents() } else { requestCalendar() }
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
            let records = envelope.result.snapshot.agents.map { raw in
                AgentRecord(id: String(raw.paneID.prefix(256)), agent: String((raw.agent ?? "unknown").prefix(128)),
                            status: String((raw.agentStatus ?? "unknown").prefix(32)),
                            workspace: String((workspaces[raw.workspaceID ?? ""] ?? "Unknown workspace").prefix(128)),
                            sessionIdentity: raw.agentSession?.canonical(), focused: raw.focused ?? false, unread: false)
            }
            let marked = self.tracker.update(records)
            self.send("agents", AgentPayload(status: "connected", updatedAt: self.isoFormatter.string(from: Date()), agents: marked))
        }
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
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func screensChanged() { showOnTargetIfPresent() }
    private func showOnTargetIfPresent() {
        guard let screen = NSScreen.screens.first(where: { $0.localizedName == targetDisplayName }) else { window?.orderOut(nil); return }
        if window == nil {
            let content = WKUserContentController(); let newBridge = NativeBridge(); let configuration = WKWebViewConfiguration(); configuration.userContentController = content
            content.add(newBridge, name: "agents"); content.add(newBridge, name: "calendar")
            let webView = WKWebView(frame: .zero, configuration: configuration); newBridge.webView = webView; webView.navigationDelegate = self; webView.uiDelegate = self; webView.setValue(false, forKey: "drawsBackground")
            window = DashboardWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false); window?.title = dashboardTitle; window?.contentView = webView; window?.delegate = self; window?.isOpaque = true; window?.backgroundColor = NSColor(calibratedWhite: 0.07, alpha: 1); window?.level = .normal; window?.collectionBehavior = [.fullScreenPrimary]; window?.isMovable = false; window?.acceptsMouseMovedEvents = true
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
    deinit { EdgeTouchRuntimeStop(touchRuntime); if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) } }
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
