import Foundation

public enum HermitBranch: String, CaseIterable, Sendable {
    case trickery, phantom, omen
    public var title: String { switch self { case .trickery: "诡术"; case .phantom: "幻身"; case .omen: "秘兆" } }
    public var summary: String { switch self {
    case .trickery: "错步破防 · 交替连击"
    case .phantom: "幻影承伤 · 蓄势反击"
    case .omen: "误认铺垫 · 满层兑现"
    } }
}

public struct HermitTalent: Identifiable, Sendable {
    public let id: String
    public let branch: HermitBranch
    public let index: Int
    public let title: String
    public let detail: String
    public let symbol: String
    public var prerequisites: [String] {
        let prefix = branch.rawValue
        return switch index {
        case 0: []
        case 1, 2: ["\(prefix).0"]
        case 3: ["\(prefix).1"]
        case 4: ["\(prefix).2"]
        default: ["\(prefix).3", "\(prefix).4"]
        }
    }
    public static let all: [Self] = {
        let rows: [(HermitBranch, [(String, String, String)])] = [
            (.trickery, [
                ("利落开场", "错步穿行伤害提高 10%。", "suit.spade.fill"),
                ("窥隙", "错步穿行计算伤害时忽略目标 15% 防御。", "scope"),
                ("换手", "与上一次技能不同的伤害技能，伤害提高 12%。", "arrow.triangle.swap"),
                ("追幕", "错步之后的下一个非错步伤害技能，伤害提高 20%。", "bolt.fill"),
                ("收场", "对生命不高于 35% 的目标，技能伤害提高 18%。", "suit.diamond.fill"),
                ("无间戏法", "每第三次命中的伤害技能提高 35% 伤害；多目标只计一次。", "crown.fill")]),
            (.phantom, [
                ("余蜡", "施放假面谕令时获得 30 护盾。", "shield.fill"),
                ("护幕", "幻影承受攻击时，主角获得 20 护盾。", "shield.lefthalf.filled"),
                ("回声", "幻影承受攻击后，下一个伤害技能提高 15%；不可叠加。", "waveform"),
                ("缝影", "幻影承受攻击时，恢复 20 生命，不超过生命上限。", "heart.fill"),
                ("藏锋", "施放假面后的下一个伤害技能提高 20%；不可叠加。", "moon.fill"),
                ("镜幕反奏", "最后一次幻影承伤后，下一个伤害技能提高 40%；不可叠加。", "sparkles")]),
            (.omen, [
                ("留痕", "伪证烙印额外施加 1 层误认，上限仍为 4。", "eye.fill"),
                ("读兆", "命中前每层误认使该次技能伤害提高 4%。", "book.closed.fill"),
                ("借势", "命中前有误认时，伤害技能同时获得 15 护盾。", "diamond.fill"),
                ("深证", "对满 4 层误认目标，技能伤害计算忽略 20% 防御。", "seal.fill"),
                ("伏笔", "伪证烙印后的下一个伤害技能提高 20%。", "pencil.tip"),
                ("预言兑现", "对命中前满 4 层误认的目标，荒谬归结伤害提高 45%。", "star.fill")])
        ]
        return rows.flatMap { branch, entries in entries.enumerated().map { index, entry in
            Self(id: "\(branch.rawValue).\(index)", branch: branch, index: index, title: entry.0, detail: entry.1, symbol: entry.2)
        } }
    }()
}

public struct HermitTalentAllocation: Equatable, Codable, Sendable {
    public private(set) var learned: Set<String> = []
    public init() {}
    public func has(_ id: String) -> Bool { learned.contains(id) }
    public func canLearn(_ id: String, budget: Int) -> Bool {
        guard let node = HermitTalent.all.first(where: { $0.id == id }), !has(id), learned.count < budget else { return false }
        return node.prerequisites.allSatisfy(has)
    }
    @discardableResult public mutating func learn(_ id: String, budget: Int) -> Bool {
        guard canLearn(id, budget: budget) else { return false }
        learned.insert(id); return true
    }
    public mutating func reset() { learned.removeAll() }
    public static func restored(_ ids: [String], budget: Int) -> Self {
        var result = Self()
        for _ in 0..<6 { for node in HermitTalent.all where ids.contains(node.id) { result.learn(node.id, budget: budget) } }
        return result
    }
}
