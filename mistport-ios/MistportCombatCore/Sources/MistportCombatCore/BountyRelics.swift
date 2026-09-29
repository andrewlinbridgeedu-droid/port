import Foundation

/// Bounty rewards from 2026-09-28: each closed case gives a relic for the separate
/// bounty slot that counters one enemy mechanic, instead of weapon or armor numbers.
/// The three wall relics have effects; the other seven arrive in the second batch.
public enum MPCBountyRelicCatalog {
    public struct Relic: Equatable, Sendable, Identifiable {
        public let id: String
        public let caseID: String
        public let name: String
        public let detail: String
        public let hasEffect: Bool
    }

    public static let brokenSword = "bounty_relic_b01_broken_sword"
    public static let reverseSeal = "bounty_relic_b04_reverse_seal"
    public static let lifeLedger = "bounty_relic_b10_life_ledger"

    public static let all: [Relic] = [
        .init(id: brokenSword, caseID: "b01", name: "七号缺齿剑",
              detail: "命中处于强化或守势的敌人时，打破它身上全部强化，这一击也不受守势减伤。每个敌人8秒一次。", hasEffect: true),
        .init(id: "bounty_relic_b02_backframe", caseID: "b02", name: "收尸人外锁架", detail: "克制记忆节点的修复。效果随后开放。", hasEffect: false),
        .init(id: "bounty_relic_b03_tide_anchor", caseID: "b03", name: "溺钟潮锚", detail: "克制记忆吐息的持续伤害。效果随后开放。", hasEffect: false),
        .init(id: reverseSeal, caseID: "b04", name: "伪造者倒签笔",
              detail: "敌人校准期间，每次命中算作两次校验；校验失败时，下一击最多只加伤20%。", hasEffect: true),
        .init(id: "bounty_relic_b05_red_shears", caseID: "b05", name: "赤丝银剪", detail: "克制护送与保护链。效果随后开放。", hasEffect: false),
        .init(id: "bounty_relic_b06_dark_lantern", caseID: "b06", name: "无灯舱甲", detail: "克制押运车的守势。效果随后开放。", hasEffect: false),
        .init(id: "bounty_relic_b07_bell_throat", caseID: "b07", name: "金喉铃护", detail: "克制分裂体。效果随后开放。", hasEffect: false),
        .init(id: "bounty_relic_b08_mirror_rapier", caseID: "b08", name: "借脸镜刺", detail: "克制吞名与寄生。效果随后开放。", hasEffect: false),
        .init(id: "bounty_relic_b09_copper_shell", caseID: "b09", name: "吞契铜背甲", detail: "克制蓄力重击。效果随后开放。", hasEffect: false),
        .init(id: lifeLedger, caseID: "b10", name: "绯月寿账签",
              detail: "总签官狂暴时不再加伤；它每完成一个循环，回复5%入场生命。", hasEffect: true),
    ]

    public static func relic(_ id: String) -> Relic? { all.first { $0.id == id } }
    public static func relic(forCase caseID: String) -> Relic? { all.first { $0.caseID == caseID } }
}

/// The bounty slot: relics earned from closed cases and the one being worn.
public struct MPCBountyRelicLedger: Codable, Equatable, Sendable {
    public private(set) var ownedIDs: Set<String> = []
    public private(set) var equippedID: String?
    /// Bounty weapons and armor removed when the save moved to relics; nil until then.
    public private(set) var retiredGearIDs: [String]?
    public init() {}

    public var hasMigrated: Bool { retiredGearIDs != nil }

    /// Idempotent per case. The first relic a player earns is worn automatically.
    @discardableResult public mutating func grant(caseID: String) -> String? {
        guard let relic = MPCBountyRelicCatalog.relic(forCase: caseID), ownedIDs.insert(relic.id).inserted else { return nil }
        if equippedID == nil { equippedID = relic.id }
        return relic.id
    }
    /// `nil` takes the relic off.
    @discardableResult public mutating func equip(_ id: String?) -> Bool {
        guard id.map(ownedIDs.contains) ?? true else { return false }
        equippedID = id
        return true
    }
    /// One-time move for saves from before 2026-09-28: bounty gear is removed and
    /// every closed case pays its relic instead. Copper and merit are not paid again.
    @discardableResult public mutating func migrate(gear: inout MPCChurchGearLedger, claimedCaseIDs: [String]) -> Bool {
        guard !hasMigrated else { return false }
        retiredGearIDs = gear.retireBountyGear()
        for caseID in claimedCaseIDs.sorted() { grant(caseID: caseID) }
        return true
    }
}

/// Story hard walls agreed 2026-09-28 (PROGRESSION_WALLS_AND_BOUNTY_RELICS_20260928.md).
/// Values are tuned with tools/progression-sim; change them here, not at call sites.
/// They are `var` only so the simulator can sweep them (`WALLS=` in tools/progression-sim);
/// the game never writes them.
public enum MPCProgressionWalls {
    // Wall enemies. Each value applies only in its own mission.
    nonisolated(unsafe) public static var q8LeechHP = 1900
    nonisolated(unsafe) public static var q8LeechAttack = 100
    nonisolated(unsafe) public static var q8ParasiteDamage = 110
    /// Name devour hits for start% of base health, +step% each time, up to max%.
    nonisolated(unsafe) public static var q8DevourPercent = (start: 45, step: 10, max: 85)
    nonisolated(unsafe) public static var q12PuppetHP = 1200
    nonisolated(unsafe) public static var q12PuppetAttack = 60
    /// Q12: every fortify leaves a stack that does not fade; each cuts all damage the
    /// puppet takes by this percentage, up to the cap. The broken sword clears them.
    nonisolated(unsafe) public static var q12FortifyStackPercent = 50
    nonisolated(unsafe) public static var q12FortifyMaxPercent = 90
    nonisolated(unsafe) public static var q18AdjudicatorHP = 2400
    nonisolated(unsafe) public static var q18AdjudicatorAttack = 112
    /// Q18 thirteenth blow and Q26 slam, percent of attack.
    nonisolated(unsafe) public static var q18ChargePercent = 200
    nonisolated(unsafe) public static var q22ClockmakerHP = 3500
    /// Q22: a failed verification without the reverse seal hits for this share of base health.
    nonisolated(unsafe) public static var q22FailedBlowHealthPercent = 110
    nonisolated(unsafe) public static var q26ConvoyHP = 3200
    nonisolated(unsafe) public static var q26ConvoyAttack = 120
    nonisolated(unsafe) public static var q26SlamPercent = 200
    nonisolated(unsafe) public static var q30SovereignHP = 5200
    /// Q30: the sovereign enrages below this share of its health.
    nonisolated(unsafe) public static var q30EnrageBelowPercent = 67
    /// Q30: while enraged (below a third), each blow takes at least this share of base health.
    nonisolated(unsafe) public static var q30EnragedBlowHealthPercent = 70
    /// Q17/Q22: hits needed while the enemy calibrates, and the failed blow's multiplier.
    nonisolated(unsafe) public static var verificationHitsRequired: [Int: Int] = [17: 2, 22: 5]
    nonisolated(unsafe) public static var verificationFailPercent: [Int: Int] = [17: 180, 22: 160]
    /// The reverse seal's cap on a failed-verification blow.
    nonisolated(unsafe) public static var reverseSealFailPercent = 120
    /// Q30: the sovereign's damage below a third of its health.
    nonisolated(unsafe) public static var q30EnragePercent = 125
    /// The life ledger heals this share of entry health per completed boss cycle.
    nonisolated(unsafe) public static var lifeLedgerCycleHealPercent = 5
    /// Broken-sword cooldown per enemy, in seconds.
    public static let brokenSwordCooldown: TimeInterval = 8

    public struct Wall: Equatable, Sendable {
        public let mission: Int
        /// Highest tower floor that should be cleared first, if any.
        public let towerFloor: Int?
        /// Bounty case whose relic counters the wall's mechanic, if any.
        public let caseID: String?
        /// What beat the player, in their words.
        public let cause: String
    }
    public static let walls: [Wall] = [
        .init(mission: 8, towerFloor: 10, caseID: nil, cause: "吞名一次比一次痛，拖得越久越难撑。"),
        .init(mission: 12, towerFloor: nil, caseID: "b01", cause: "校准人偶的强化层层叠加，越打越打不动。"),
        .init(mission: 18, towerFloor: 50, caseID: nil, cause: "裁定者的第十三击太重。"),
        .init(mission: 22, towerFloor: nil, caseID: "b04", cause: "钟匠校准时命中不够，校验失败的重击扛不住。"),
        .init(mission: 26, towerFloor: 70, caseID: nil, cause: "押运车太硬，猛砸太重。"),
        .init(mission: 30, towerFloor: 90, caseID: "b10", cause: "总签官掉到三分之二血后狂暴，每一击都按你的生命算。"),
    ]
    public static func wall(mission: Int) -> Wall? { walls.first { $0.mission == mission } }

    /// The case the daily board must carry while the player stands at a mechanism
    /// wall without its relic, so nobody waits days for a random draw.
    public static func guaranteedCase(nextMission: Int, ownedRelicIDs: Set<String>) -> String? {
        guard let caseID = wall(mission: nextMission)?.caseID,
              let relic = MPCBountyRelicCatalog.relic(forCase: caseID),
              !ownedRelicIDs.contains(relic.id) else { return nil }
        return caseID
    }

    /// Shown after losing a wall mission while its requirement is still unmet.
    public static func defeatHint(mission: Int, highestTowerFloor: Int, equippedRelicID: String?,
                                  ownedRelicIDs: Set<String>, caseTitle: (String) -> String?) -> String? {
        guard let wall = wall(mission: mission) else { return nil }
        var steps: [String] = []
        if let floor = wall.towerFloor, highestTowerFloor < floor {
            steps.append("去教会塔打到第 \(floor) 层，换上那里的装备")
        }
        if let caseID = wall.caseID, let relic = MPCBountyRelicCatalog.relic(forCase: caseID), equippedRelicID != relic.id {
            if ownedRelicIDs.contains(relic.id) {
                steps.append("在通缉栏换上\(relic.name)")
            } else {
                steps.append("接通缉“\(caseTitle(caseID) ?? caseID.uppercased())”，结案得\(relic.name)，装进通缉栏")
            }
        }
        guard !steps.isEmpty else { return nil }
        return wall.cause + steps.joined(separator: "；") + "，再来。"
    }
}
