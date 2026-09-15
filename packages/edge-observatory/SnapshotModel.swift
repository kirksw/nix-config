enum JSONValue: Codable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }
    func canonical() -> String {
        switch self {
        case .string(let value): return "s:" + value
        case .number(let value): return "n:" + String(value)
        case .bool(let value): return "b:" + String(value)
        case .null: return "null"
        case .array(let values): return "[" + values.map { $0.canonical() }.joined(separator: ",") + "]"
        case .object(let values): return "{" + values.keys.sorted().map { "\($0):\(values[$0]!.canonical())" }.joined(separator: ",") + "}"
        }
    }
}

struct RawWorkspace: Codable { let workspaceID: String; let label: String
    enum CodingKeys: String, CodingKey { case workspaceID = "workspace_id"; case label }
}
struct RawAgent: Codable {
    let paneID: String
    let agent: String?
    let agentStatus: String?
    let workspaceID: String?
    let focused: Bool?
    let agentSession: JSONValue?
    enum CodingKeys: String, CodingKey {
        case paneID = "pane_id", agent, agentStatus = "agent_status", workspaceID = "workspace_id"
        case focused, agentSession = "agent_session"
    }
}
struct HerdrSnapshot: Codable {
    let agents: [RawAgent]
    let workspaces: [RawWorkspace]
}
struct HerdrEnvelope: Codable {
    struct Result: Codable { let snapshot: HerdrSnapshot }
    let result: Result
}

