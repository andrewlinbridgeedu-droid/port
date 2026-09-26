import Foundation

public struct S9TalentNode: Identifiable, Sendable {
    public let code: String
    public let name: String
    public let symbol: String
    public let template: String
    public let values: [Double]
    public let secondary: [Double]
    public let conditions: String
    public let story: String
    public var id: String { "hermit/sequence9/\(code)" }
    public var tree: String { String(code.prefix(1)) }
    public var index: Int { Int(code.dropFirst())! - 1 }
    public var parent: String? { index < 2 ? nil : "hermit/sequence9/\(tree)\(index - 1)" }
    public var threshold: Int { index < 2 ? 0 : index < 4 ? 5 : 10 }
    public var combatImplemented: Bool { false }
    public func effect(rank: Int) -> String {
        guard (1...5).contains(rank) else { return rank == 0 ? "尚未投入" : "等级无效" }
        func format(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(v) }
        return template.replacingOccurrences(of: "{a}", with: format(values[rank - 1]))
            .replacingOccurrences(of: "{b}", with: secondary.isEmpty ? "" : format(secondary[rank - 1]))
    }
    public static let all: [Self] = [
        .init(code: "T1", name: "异手开局", symbol: "suit.spade.fill", template: "揭幕消费1戏势，主击增伤 {a}%。", values: [10,14,18,22,26], secondary: [], conditions: "设局与揭幕在5秒内交替，获得1戏势；最多3层，持续8秒。先消费旧资源，再获得新资源。", story: ""),
        .init(code: "T2", name: "错步追缝", symbol: "scope", template: "不同攻击技能消费接缝，追加 {a} 伤害。", values: [24,32,40,48,56], secondary: [], conditions: "对错位主目标挂接缝，持续4秒；消费当次不重挂，同技能不刷新。", story: ""),
        .init(code: "T3", name: "留白换手", symbol: "arrow.triangle.swap", template: "交替窗口 {a} 秒；戏势持续 {b} 秒。", values: [6,7,8,9,10], secondary: [9,10,11,12,13], conditions: "扩大已有资源的有效窗口；普攻不刷新，不额外产生戏势。", story: ""),
        .init(code: "T4", name: "借势错拍", symbol: "clock", template: "消费接缝后，尝试延后敌方起手 {a} 秒。", values: [0.15,0.2,0.25,0.3,0.35], secondary: [], conditions: "每目标内部CD4秒；已起手则失败，与其他来源共用滚动延后上限。", story: ""),
        .init(code: "T5", name: "连场", symbol: "bolt.fill", template: "消费戏势的揭幕追加 {a} 追击伤害。", values: [24,32,40,48,56], secondary: [], conditions: "0.35秒后命中；内部CD1.5秒。与镜像追击合包，派生追击不产生资源。", story: ""),
        .init(code: "T6", name: "撬锁手", symbol: "key.fill", template: "消费戏势或接缝的揭幕额外削盾 {a}。", values: [20,35,50,65,80], secondary: [], conditions: "每施法一次，只削护盾，不溢出到生命，不触发命中监听。", story: ""),
        .init(code: "P1", name: "余响", symbol: "waveform", template: "揭幕消费全部余响，每层反击 {a} 伤害。", values: [8,11,14,17,20], secondary: [], conditions: "幻影承接原生攻击才获得；最多3层，持续8秒，反击延迟0.3秒。", story: "假面谕令"),
        .init(code: "P2", name: "密缝", symbol: "shield.fill", template: "下次假面消费针脚，每层增加 {a} 耐久。", values: [12,18,24,30,36], secondary: [], conditions: "一次实际分担≥80才获针脚；最多2层，持续6秒。依赖待定的耐久版假面。", story: "假面谕令"),
        .init(code: "P3", name: "留影", symbol: "moon.fill", template: "余响持续 {a} 秒；破幕后一次减伤 {b}%。", values: [10,12,14,16,18], secondary: [8,11,14,17,20], conditions: "真实承伤耗尽后留1.5秒余幕，内部CD3秒；不保护触发它的同一击。", story: "假面谕令"),
        .init(code: "P4", name: "引客", symbol: "theatermasks.fill", template: "揭幕命中诱敌目标，削弱其下一次攻击 {a}%。", values: [6,9,12,15,18], secondary: [], conditions: "首次承接诱敌6秒，限1名，内部CD3秒；消费后减伤限6秒或一次攻击。", story: "假面谕令"),
        .init(code: "P5", name: "镜后藏针", symbol: "diamond.fill", template: "消费余响时，每个真实层数获得 {a} 护盾。", values: [8,11,14,17,20], secondary: [], conditions: "护盾持续4秒，内部CD3秒；不计算遗落物虚拟加伤，遵循总护盾上限。", story: "假面谕令"),
        .init(code: "P6", name: "空席", symbol: "sparkles", template: "幻影耐久提前耗尽，结算后获得 {a} 护盾。", values: [40,55,70,85,100], secondary: [], conditions: "须仍有承接次数；持续2秒，内部CD6秒。依赖待定的耐久版假面。", story: "假面谕令"),
        .init(code: "S1", name: "旁证", symbol: "eye.fill", template: "设局命中误认目标额外取证1份，内部CD {a} 秒。", values: [3,2.75,2.5,2.25,2], secondary: [], conditions: "伪造证据除外；只算原生主目标命中，假面与敛息不触发。", story: "误认来源"),
        .init(code: "S2", name: "耐心笔录", symbol: "book.closed.fill", template: "自动封卷期限 {a} 秒，每份伤害 {b}。", values: [7,7.5,8,8.5,9], secondary: [34,38,42,46,50], conditions: "新台账建立时定期限，继续取证不重置；不改变终幕系数。", story: "证据来源"),
        .init(code: "S3", name: "交叉讯问", symbol: "seal.fill", template: "揭幕主击命中误认目标，取证1份；内部CD {a} 秒。", values: [5,4.5,4,3.5,3], secondary: [], conditions: "每施法一次，派生不触发；终幕先取走旧证据再为新台账取证。", story: "误认来源"),
        .init(code: "S4", name: "预支判词", symbol: "pencil.tip", template: "预言让下次设局额外取证 {a} 份，保留 {b} 秒。", values: [1,1,2,2,3], secondary: [6,8,8,10,10], conditions: "封卷≥4份获预言；最多1枚，获取内部CD8秒；先正常取证，再消费预言。", story: "证据来源"),
        .init(code: "S5", name: "旁页移交", symbol: "envelope.fill", template: "误认目标死亡，移交最多 {a} 份未封卷证据。", values: [1,2,3,4,5], secondary: [], conditions: "内部CD1秒；收件人须误认，每份最多移交一次，保留更早截止时间。", story: "误认来源"),
        .init(code: "S6", name: "迟到的判决", symbol: "star.fill", template: "案卷遇盾延后 {a} 秒，基础案伤提高 {b}%。", values: [1,1.5,2,2.5,3], secondary: [10,15,20,25,30], conditions: "内部CD6秒；同包只延后一次，再次遇盾正常结算，不复制案卷。", story: "证据来源")
    ]
}

public enum S9TalentError: Error, LocalizedError {
    case invalid, budget, prerequisite, stale, newer, corrupt
    public var errorDescription: String? { switch self {
    case .invalid: "节点或等级无效"
    case .budget: "已投入超过当前已得点数"
    case .prerequisite: "前置门槛或剧情条件未满足"
    case .stale: "状态已变化，请重新打开或计算后再操作"
    case .newer: "存档来自不同规则版本，已阻止覆盖"
    case .corrupt: "存档未通过校验，原文件已保留"
    } }
}

public enum S9TalentRules {
    public static let version = "s9.tree.1"
    public static let ids = Set(S9TalentNode.all.map(\.id))
    public static func prefix(_ target: [String: Int], unlocked: Set<String>) throws -> [String: Int] {
        guard Set(target.keys).isSubset(of: ids), target.values.allSatisfy({ (0...5).contains($0) }) else { throw S9TalentError.invalid }
        var result: [String: Int] = [:]
        var progress = true
        while progress {
            progress = false
            for node in S9TalentNode.all where unlocked.contains(node.id) && result[node.id, default: 0] < target[node.id, default: 0] {
                if let parent = node.parent, result[parent, default: 0] < 1 { continue }
                let other = S9TalentNode.all.filter { $0.tree == node.tree && $0.id != node.id }.reduce(0) { $0 + result[$1.id, default: 0] }
                guard other >= node.threshold else { continue }
                result[node.id, default: 0] += 1; progress = true
            }
        }
        return result
    }
    public static func validate(_ ranks: [String: Int], earned: Int, unlocked: Set<String>) throws {
        guard Set(ranks.keys).isSubset(of: ids), ranks.values.allSatisfy({ (0...5).contains($0) }) else { throw S9TalentError.invalid }
        guard (0...30).contains(earned), ranks.values.reduce(0,+) <= earned else { throw S9TalentError.budget }
        let reachable = try prefix(ranks, unlocked: unlocked)
        guard reachable == ranks.filter({ $0.value != 0 }) else { throw S9TalentError.prerequisite }
    }
}

public struct S9Removal: Equatable, Sendable {
    public let node: String
    public let revision: Int
    public let refunds: [String: Int]
    public var total: Int { refunds.values.reduce(0,+) }
}

public struct S9TalentDraft: Sendable {
    public private(set) var committed: [String: Int]
    public private(set) var ranks: [String: Int]
    public private(set) var revision = 0
    public private(set) var saveRevision: Int
    public let earned: Int
    public let unlocked: Set<String>
    public var spent: Int { ranks.values.reduce(0,+) }
    public var remaining: Int { earned - spent }
    public var dirty: Bool { ranks != committed }
    public init(ranks: [String: Int] = [:], earned: Int, unlocked: Set<String> = S9TalentRules.ids, saveRevision: Int = 0) throws {
        try S9TalentRules.validate(ranks, earned: earned, unlocked: unlocked)
        guard saveRevision >= 0 else { throw S9TalentError.invalid }
        self.ranks = ranks.filter { $0.value > 0 }; committed = self.ranks
        self.earned = earned; self.unlocked = unlocked; self.saveRevision = saveRevision
    }
    public mutating func add(_ id: String) throws {
        var proposed = ranks; proposed[id, default: 0] += 1
        try S9TalentRules.validate(proposed, earned: earned, unlocked: unlocked)
        ranks = proposed; revision += 1
    }
    public func removal(_ id: String) throws -> S9Removal {
        guard ranks[id, default: 0] > 0 else { throw S9TalentError.invalid }
        var proposed = ranks; proposed[id]! -= 1
        let retained = try S9TalentRules.prefix(proposed, unlocked: unlocked)
        let refunds = ranks.reduce(into: [String: Int]()) { result, pair in
            let delta = pair.value - retained[pair.key, default: 0]
            if delta > 0 { result[pair.key] = delta }
        }
        return S9Removal(node: id, revision: revision, refunds: refunds)
    }
    public mutating func confirm(_ preview: S9Removal) throws {
        guard preview.revision == revision, try removal(preview.node) == preview else { throw S9TalentError.stale }
        var proposed = ranks
        for (id, amount) in preview.refunds { proposed[id, default: 0] -= amount }
        try S9TalentRules.validate(proposed, earned: earned, unlocked: unlocked)
        ranks = proposed.filter { $0.value > 0 }; revision += 1
    }
    public mutating func reset(tree: String? = nil) {
        ranks = ranks.filter { id, _ in tree != nil && S9TalentNode.all.first(where: { $0.id == id })?.tree != tree }
        revision += 1
    }
    public mutating func cancel() { ranks = committed; revision += 1 }
    public mutating func didSave(_ newRevision: Int) { committed = ranks; saveRevision = newRevision }
}

public struct S9TalentSave: Codable, Equatable, Sendable {
    public var saveSchemaVersion = 2
    public var talentRulesVersion = S9TalentRules.version
    public var sequence = 9
    public var saveRevision: Int
    public var nodes: [String: Int]
    public init(revision: Int = 0, nodes: [String: Int] = [:]) { saveRevision = revision; self.nodes = nodes }
}

/// Separate P0 store: never written into the currently active combat allocation.
@MainActor public final class S9TalentFileStore {
    public let url: URL
    public init(url: URL) { self.url = url }
    public func load(earned: Int, unlocked: Set<String>) throws -> S9TalentSave {
        guard FileManager.default.fileExists(atPath: url.path) else { return .init() }
        let data = try Data(contentsOf: url)
        guard let header = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schema = header["saveSchemaVersion"] as? Int else { throw S9TalentError.corrupt }
        guard schema <= 2 else { throw S9TalentError.newer }
        let save = try JSONDecoder().decode(S9TalentSave.self, from: data)
        guard save.saveSchemaVersion == 2, save.sequence == 9, save.talentRulesVersion == S9TalentRules.version else { throw S9TalentError.newer }
        guard save.saveRevision >= 0 else { throw S9TalentError.corrupt }
        try S9TalentRules.validate(save.nodes, earned: earned, unlocked: unlocked)
        return save
    }
    public func commit(_ draft: S9TalentDraft) throws -> Int {
        let disk = try load(earned: draft.earned, unlocked: draft.unlocked)
        guard disk.saveRevision == draft.saveRevision else { throw S9TalentError.stale }
        try S9TalentRules.validate(draft.ranks, earned: draft.earned, unlocked: draft.unlocked)
        let save = S9TalentSave(revision: disk.saveRevision + 1, nodes: draft.ranks)
        let bytes = try JSONEncoder().encode(save)
        let manager = FileManager.default
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let staging = url.appendingPathExtension("staging-" + UUID().uuidString)
        defer { try? manager.removeItem(at: staging) }
        try bytes.write(to: staging, options: .atomic)
        guard try JSONDecoder().decode(S9TalentSave.self, from: Data(contentsOf: staging)) == save else { throw S9TalentError.corrupt }
        if manager.fileExists(atPath: url.path) {
            try Data(contentsOf: url).write(to: url.appendingPathExtension("backup"), options: .atomic)
        }
        // Foundation's atomic write uses a sibling temporary file and rename.
        try Data(contentsOf: staging).write(to: url, options: .atomic)
        return save.saveRevision
    }
}
