import Foundation

@main
struct UnreadTrackerTests {
    static func main() {
        var tracker = UnreadTracker()
        let base = AgentRecord(id: "p1", agent: "worker", status: "working", workspace: "dashboard", sessionIdentity: "s:a", focused: false, unread: false)
        assert(!tracker.update([base])[0].unread)
        let done = AgentRecord(id: "p1", agent: "worker", status: "idle", workspace: "dashboard", sessionIdentity: "s:a", focused: false, unread: false)
        assert(tracker.update([done])[0].unread)
        let focused = AgentRecord(id: "p1", agent: "worker", status: "idle", workspace: "dashboard", sessionIdentity: "s:a", focused: true, unread: false)
        assert(!tracker.update([focused])[0].unread)
        print("UnreadTracker tests passed")
    }
}
