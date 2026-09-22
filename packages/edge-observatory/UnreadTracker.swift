import Foundation

/// Tracks completion transitions while keeping session identity private to native code.
struct UnreadTracker {
    private struct State { var status: String; var unread: Bool }
    private var states: [String: State] = [:]

    mutating func update(_ agents: [AgentRecord]) -> [AgentRecord] {
        var current: [String: State] = [:]
        var marked: [AgentRecord] = []
        for agent in agents {
            let previous = states[agent.sessionIdentity ?? agent.id]
            var unread = previous?.unread ?? false
            if (previous?.status == "working" && agent.status == "idle") ||
                (agent.status == "done" && previous?.status != "done") { unread = true }
            if agent.focused { unread = false }
            let identity = agent.sessionIdentity ?? agent.id
            current[identity] = State(status: agent.status, unread: unread)
            var result = agent; result.unread = unread; marked.append(result)
        }
        states = current
        return marked
    }
}

struct AgentRecord: Codable {
    let id: String
    let agent: String
    let status: String
    let workspace: String
    let sessionIdentity: String?
    var profile: String? = nil
    let focused: Bool
    let cost: Double?
    let tokens: Int?
    var unread: Bool

    enum CodingKeys: String, CodingKey {
        case id, agent, status, workspace, profile, focused, cost, tokens, unread
    }

    init(id: String, agent: String, status: String, workspace: String,
         sessionIdentity: String?, profile: String? = nil, focused: Bool, cost: Double?, tokens: Int?, unread: Bool) {
        self.id = id
        self.agent = agent
        self.status = status
        self.workspace = workspace
        self.sessionIdentity = sessionIdentity
        self.profile = profile
        self.focused = focused
        self.cost = cost
        self.tokens = tokens
        self.unread = unread
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        agent = try values.decode(String.self, forKey: .agent)
        status = try values.decode(String.self, forKey: .status)
        workspace = try values.decode(String.self, forKey: .workspace)
        focused = try values.decode(Bool.self, forKey: .focused)
        cost = try values.decodeIfPresent(Double.self, forKey: .cost)
        tokens = try values.decodeIfPresent(Int.self, forKey: .tokens)
        unread = try values.decode(Bool.self, forKey: .unread)
        sessionIdentity = nil
        profile = try values.decodeIfPresent(String.self, forKey: .profile)
    }
}
