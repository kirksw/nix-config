import AppKit
import EventKit
import Foundation

let store = EKEventStore()
let target = "kisw@lunar.app"
let directory = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Caches/edge-dashboard", isDirectory: true)
let output = directory.appendingPathComponent("calendar.json")
let formatter = ISO8601DateFormatter()

func publish(_ status: String, _ message: String, events: [[String: Any]] = []) {
    let payload: [String: Any] = ["status": status, "message": message,
        "updatedAt": formatter.string(from: Date()), "events": events]
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        let data = try JSONSerialization.data(withJSONObject: payload)
        try data.write(to: output, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: output.path)
    } catch {
        // Do not log calendar contents or event titles.
        NSLog("EDGE calendar: unable to write local snapshot")
    }
}

func refresh() {
    guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
        publish("permission_required", "Allow calendar access for EDGE Calendar in System Settings.")
        return
    }
    let calendars = store.calendars(for: .event).filter { $0.title == target }
    guard calendars.count == 1 else {
        publish("calendar_not_found", calendars.isEmpty
            ? "Selected calendar is not available in Apple Calendar yet."
            : "Multiple calendars have this name. Select a unique calendar before continuing.")
        return
    }
    let now = Date()
    let end = Calendar.current.date(byAdding: .day, value: 1,
        to: Calendar.current.startOfDay(for: now))!
    let predicate = store.predicateForEvents(withStart: now, end: end, calendars: calendars)
    let events = store.events(matching: predicate)
        .filter { $0.endDate > now && $0.status != .canceled }
        .sorted { $0.startDate < $1.startDate }
        .prefix(8).map { event -> [String: Any] in
            ["title": event.title ?? "Untitled event", "start": formatter.string(from: event.startDate),
             "end": formatter.string(from: event.endDate), "allDay": event.isAllDay]
        }
    publish("connected", "Apple Calendar / remaining today", events: events)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
if EKEventStore.authorizationStatus(for: .event) == .notDetermined {
    publish("permission_required", "Waiting for macOS calendar permission.")
    store.requestFullAccessToEvents { _, _ in DispatchQueue.main.async { refresh() } }
} else {
    refresh()
}
let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in refresh() }
app.run()
