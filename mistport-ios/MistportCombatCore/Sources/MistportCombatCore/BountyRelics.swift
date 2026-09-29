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
              detail: "命中处于强化或守势的敌人时，打破它这次的强化，这一击也不受守势减伤。每个敌人8秒一次。", hasEffect: true),
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

/// Story hard walls agreed 2026-09-28 (PROGRESSION_WALLS_AND_BOUNTY_RELICS_20260928.md).
/// Values are tuned with tools/progression-sim; change them here, not at call sites.
public enum MPCProgressionWalls {
    /// Q12: while a puppet is fortified, all damage it takes is reduced by this percentage.
    public static let q12FortifyReductionPercent = 0
    /// Q17/Q22: hits needed while the enemy calibrates, and the failed blow's multiplier.
    public static let verificationHitsRequired = 2
    public static let verificationFailPercent: [Int: Int] = [17: 180, 22: 160]
    /// The reverse seal's cap on a failed-verification blow.
    public static let reverseSealFailPercent = 120
    /// Q30: the sovereign's damage below a third of its health.
    public static let q30EnragePercent = 125
    /// The life ledger heals this share of entry health per completed boss cycle.
    public static let lifeLedgerCycleHealPercent = 5
    /// Broken-sword cooldown per enemy, in seconds.
    public static let brokenSwordCooldown: TimeInterval = 8
}
