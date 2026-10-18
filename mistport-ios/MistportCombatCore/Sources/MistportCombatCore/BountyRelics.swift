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
    /// Q3 teaches the manual mask: two unblocked breaths defeat a fresh hero.
    nonisolated(unsafe) public static var q3BreathHealthPercent = 90
    nonisolated(unsafe) public static var q3HoundHP = 1500
    /// Q10 is not a wall either. With the authored 150% breath and 1050/1200 health the
    /// three-card hand only won at the fastest cadence (1.75 s per card); Q9 still wins
    /// at 2.5 s. These values let a 3 s cadence with the mask and one salve finish
    /// the puppet (sim 2026-10-05, playtest lost Q10 three times on 169.95).
    nonisolated(unsafe) public static var q10HoundBreathPercent = 100
    nonisolated(unsafe) public static var q10HoundHP = 800
    nonisolated(unsafe) public static var q10PuppetHP = 900
    // Wall enemies. Each value applies only in its own mission.
    nonisolated(unsafe) public static var q8LeechHP = 1900
    nonisolated(unsafe) public static var q8LeechAttack = 100
    nonisolated(unsafe) public static var q8ParasiteDamage = 110
    /// Name devour hits for start% of base health, +step% each time, up to max%.
    nonisolated(unsafe) public static var q8DevourPercent = (start: 45, step: 10, max: 85)
    nonisolated(unsafe) public static var q12PuppetHP = 1300
    nonisolated(unsafe) public static var q12PuppetAttack = 55
    /// Q12: every fortify leaves a stack that does not fade; each cuts all damage the
    /// puppet takes by this percentage, up to the cap. The broken sword clears them.
    nonisolated(unsafe) public static var q12FortifyStackPercent = 50
    nonisolated(unsafe) public static var q12FortifyMaxPercent = 95
    /// Q12 puppets enter with this many stacks (2026-10-15, user: 让“必须带遗落物”重新成立): with the
    /// ordered cards a 伪证→错认喜剧→荒谬 burst, its delay pushing the first fortify back, killed a puppet
    /// before it ever fortified (27/168 audit lines won without the sword at F30; now 0, sword lines 77/168).
    nonisolated(unsafe) public static var q12OpeningFortifyStacks = 1
    nonisolated(unsafe) public static var q18AdjudicatorHP = 5200
    nonisolated(unsafe) public static var q18AdjudicatorAttack = 140
    /// Q18 thirteenth blow and Q26 slam, percent of attack.
    nonisolated(unsafe) public static var q18ChargePercent = 200
    /// Q18 thirteenth blow, Q26 convoy slam and Q30 sovereign slam: without a worn piece
    /// from the wall's tower floor or deeper, the blow takes this share of base health. 140 → 300 (2026-10-15):
    /// the medal's 150% health, the clasp and armor let one 140% blow through, and 错认喜剧's delay held the next
    /// one back until the boss died (F40 won Q18 9/168 audit lines, F60 Q26 21/168, F80 Q30 10/168; now 0).
    /// Fights with the floor's gear never see this blow, so the Q30 blessing tuning at F90 is untouched.
    nonisolated(unsafe) public static var towerCheckBlowHealthPercent: [Int: Int] = [18: 300, 26: 300, 30: 300]
    nonisolated(unsafe) public static var q22ClockmakerHP = 5000
    /// Q22: a failed verification without the reverse seal hits for this share of base health, before the
    /// clasp's 30% and armor (2026-10-15: 140 → 300, so the medal's 150% health and F80 armor no longer
    /// carry it; with 12 hits and the blow undelayable and unblockable, 0/168 audit lines win without the seal).
    nonisolated(unsafe) public static var q22FailedBlowHealthPercent = 300
    nonisolated(unsafe) public static var q26ConvoyHP = 5600
    nonisolated(unsafe) public static var q26ConvoyAttack = 150
    nonisolated(unsafe) public static var q26SlamPercent = 200
    /// Q30 is a three-person fight in three phases (2026-10-10, user: 18000–20000 health,
    /// winnable only with good relics).
    nonisolated(unsafe) public static var q30SovereignHP = 20_000
    /// Q30 phase two (name seal and slam join the loop) starts below this share of health.
    nonisolated(unsafe) public static var q30PhaseTwoBelowPercent = 60
    /// Q30: phase three, the enrage, below this share of its health.
    nonisolated(unsafe) public static var q30EnrageBelowPercent = 30
    /// Q30: while enraged, each blow takes at least this share of base health. Only a fight without the life
    /// ledger enrages, so the blessing tuning (F90 + ledger) never sees it. 70 → 300 (2026-10-15, user: Q30 must
    /// need its relic): on the real loop 37/168 audit lines won without the ledger, their bursts outrunning a
    /// phase three that the medal, the clasp and the shared revive absorbed; now 0 (with the enraged ally slam).
    nonisolated(unsafe) public static var q30EnragedBlowHealthPercent = 300
    /// Q30 blows at their target, percent of the hero's base health before any defence;
    /// name seal on an ally takes its share of that ally's health instead.
    nonisolated(unsafe) public static var q30StrikeHealthPercent = 32
    nonisolated(unsafe) public static var q30ChargeHealthPercent = 52
    nonisolated(unsafe) public static var q30SlamHealthPercent = 42
    nonisolated(unsafe) public static var q30SealHealthPercent = 12
    /// Q30 离场祝福 (2026-10-10, user: a small easter egg, `MPCFarewellBlessings`). 伊莱娅's
    /// blessing: 灯芯长明 adds this percent to the hero's own damage on the sovereign, 羽翼庇护
    /// adds shared revives (each bringing the hero back at this share of health), 照名之光
    /// makes every 夺名代签 last this many seconds.
    /// Sim 10-10 (9 pairs × 3 profiles): the first draft (10%, a full 30% revive, crust 10%,
    /// bell 20%) let the four ordinary relics win at F90 + life ledger, since their near misses
    /// end 255–900 short of 20000. These keep them at 0, the clasp ≥ 3/8 at high and medium,
    /// and no-ledger / F80 at 0; one step off lamp 9, crust 14 or mend 4 breaks a pair again.
    nonisolated(unsafe) public static var q30LampWickPercent = 8
    nonisolated(unsafe) public static var q30FeatherRevives = 1
    nonisolated(unsafe) public static var q30FeatherReviveHealthPercent = 10
    nonisolated(unsafe) public static var q30NameLightSealSeconds = 3
    /// The pursuer's gift: 黑盐外壳 cuts all damage the sovereign takes by this percent, 冷钟
    /// adds this percent to the thirteenth blow (below ~28% 诺恩's intercept swallows it),
    /// 雾中续命 heals this share of its health on entering phases two and three.
    nonisolated(unsafe) public static var q30SaltCrustPercent = 15
    nonisolated(unsafe) public static var q30ColdBellPercent = 32
    nonisolated(unsafe) public static var q30MistMendPercent = 5
    /// Q28/Q29, the sovereign's survive-five-loops meetings (no wall): flat blows at the hero,
    /// about 1.4× the Q30 shares at day-28 health, so the party's mend does not erase them.
    nonisolated(unsafe) public static var finalBossEarlyBlows: [String: Int] = ["strike": 700, "thirteenth_charge": 1_130, "slam": 920]
    /// Final-boss party (Q28–Q30): the slam also hits each standing ally for this share of
    /// its health, more while enraged.
    nonisolated(unsafe) public static var partySlamAllyPercent = 18
    /// Enraged (no life ledger) 30 → 100 (2026-10-15): the allies no longer finish the sovereign after its blow.
    nonisolated(unsafe) public static var partySlamAllyEnragedPercent = 100
    /// The protector's intercept takes this share of the thirteenth blow; the hero takes none.
    nonisolated(unsafe) public static var partyInterceptPercent = 60
    /// 夺名代签 holds one card of the hero, or an ally to its basic attack, this long.
    nonisolated(unsafe) public static var partySealSeconds = 6
    /// Each ally acts at most once per this many tenths of a second of combat time.
    nonisolated(unsafe) public static var partyAllyActionTenths = 25
    /// The healer's mend and its cooldown (tenths of a second; vials in between), the
    /// protector's guard shield when nothing can be hit, and ally health as a percent of the
    /// catalog value.
    nonisolated(unsafe) public static var partyHealAmount = 180
    nonisolated(unsafe) public static var partyHealCooldownTenths = 50
    nonisolated(unsafe) public static var partyGuardShield = 60
    nonisolated(unsafe) public static var partyAllyHPPercent = 100
    /// A fallen hero (2026-10-10, user: the party loses only when all three are down): the
    /// healer, standing and unsealed, spends the shared revive after this channel (tenths of
    /// a second), bringing the hero back at this share of health.
    nonisolated(unsafe) public static var partyReviveTenths = 30
    nonisolated(unsafe) public static var partyReviveHealthPercent = 30
    /// The allies' clock in party fights: they act on combat time, not only after the hero's hits.
    nonisolated(unsafe) public static var partyCompanionTickTenths = 10
    /// Q17/Q22: hits needed while the enemy calibrates, and the failed blow's multiplier. Q22 5 → 12
    /// (2026-10-15): 燃镜's six hits under 抢拍 passed every check; the seal's double count needs six.
    nonisolated(unsafe) public static var verificationHitsRequired: [Int: Int] = [17: 2, 22: 12]
    nonisolated(unsafe) public static var verificationFailPercent: [Int: Int] = [17: 180, 22: 160]
    /// The reverse seal's cap on a failed-verification blow.
    nonisolated(unsafe) public static var reverseSealFailPercent = 120
    /// Q30: the sovereign's damage while enraged (phase three).
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
        .init(mission: 18, towerFloor: 50, caseID: nil, cause: "裁定者的第十三击要够深的深井装备才扛得住。"),
        .init(mission: 22, towerFloor: nil, caseID: "b04", cause: "钟匠校准时命中不够，校验失败的重击扛不住。"),
        .init(mission: 26, towerFloor: 70, caseID: nil, cause: "押运车的猛砸要够深的深井装备才扛得住。"),
        .init(mission: 30, towerFloor: 90, caseID: "b10", cause: "总签官的猛砸要够深的深井装备才扛得住；血掉到三成后还会狂暴，每一击都按你的生命算。"),
    ]
    public static func wall(mission: Int) -> Wall? { walls.first { $0.mission == mission } }

    /// Tower-checked walls (Q18, Q26, Q30) let their heavy blow through at normal
    /// strength only when a worn piece comes from the wall's floor or deeper.
    /// Q8 is not checked: it stays a plain damage race.
    public static func meetsTowerFloor(mission: Int, gear: MPCChurchGearStats) -> Bool {
        guard towerCheckBlowHealthPercent[mission] != nil, let floor = wall(mission: mission)?.towerFloor else { return true }
        return gear.towerDepth >= floor
    }

    /// The relic a mechanism wall checks (Q12 b01, Q22 b04, Q30 b10), if any.
    public static func wallRelic(mission: Int) -> MPCBountyRelicCatalog.Relic? {
        wall(mission: mission)?.caseID.flatMap(MPCBountyRelicCatalog.relic(forCase:))
    }

    /// Mechanism walls let their lethal mechanic through unless the wall's relic is worn in the
    /// bounty slot. The runtime's Q22 and Q30 checks call this; Q12's counter is the broken
    /// sword's own effect, which fires for the same relic id.
    public static func wearsWallRelic(mission: Int, bountyRelicID: String?) -> Bool {
        guard let relic = wallRelic(mission: mission) else { return true }
        return bountyRelicID == relic.id
    }

    /// One wall requirement a loadout does not meet.
    public enum Requirement: Equatable, Sendable {
        /// A worn piece from this tower floor or deeper (MPCChurchGearStats.towerDepth).
        case towerGear(floor: Int)
        /// This relic worn in the bounty slot.
        case bountyRelic(MPCBountyRelicCatalog.Relic)

        public var label: String {
            switch self {
            case .towerGear(let floor): "教会塔第 \(floor) 层或更深的装备"
            case .bountyRelic(let relic): "通缉遗落物「\(relic.name)」"
            }
        }
    }

    /// What `loadout` lacks for the mission's wall, with the predicates the fight uses
    /// (`meetsTowerFloor`, `wearsWallRelic`), so the warning and the fight never disagree.
    public static func unmetRequirements(mission: Int, loadout: MPCChapterOneLoadout) -> [Requirement] {
        var unmet: [Requirement] = []
        if let floor = wall(mission: mission)?.towerFloor, !meetsTowerFloor(mission: mission, gear: loadout.churchGear) {
            unmet.append(.towerGear(floor: floor))
        }
        if let relic = wallRelic(mission: mission), !wearsWallRelic(mission: mission, bountyRelicID: loadout.bountyRelicID) {
            unmet.append(.bountyRelic(relic))
        }
        return unmet
    }

    /// Shown before a wall fight whose requirement is unmet (2026-10-15, user: keep the walls
    /// lethal, but say what the mission needs first). A warning only; entering stays allowed.
    public static func prebattleHint(mission: Int, loadout: MPCChapterOneLoadout) -> String? {
        let unmet = unmetRequirements(mission: mission, loadout: loadout)
        guard !unmet.isEmpty else { return nil }
        return "这一关需要：" + unmet.map(\.label).joined(separator: "、")
    }

    /// The case the daily board must carry while the player stands at a mechanism
    /// wall without its relic, so nobody waits days for a random draw.
    public static func guaranteedCase(nextMission: Int, ownedRelicIDs: Set<String>) -> String? {
        guard let caseID = wall(mission: nextMission)?.caseID,
              let relic = MPCBountyRelicCatalog.relic(forCase: caseID),
              !ownedRelicIDs.contains(relic.id) else { return nil }
        return caseID
    }

    /// Shown after losing a wall mission while its requirement is still unmet.
    /// `wornTowerDepth` (MPCChurchGearStats.towerDepth) lets a tower-checked wall ask
    /// for deeper gear when the floor is cleared but shallower pieces are worn.
    public static func defeatHint(mission: Int, highestTowerFloor: Int, equippedRelicID: String?,
                                  ownedRelicIDs: Set<String>, wornTowerDepth: Int? = nil,
                                  caseTitle: (String) -> String?) -> String? {
        guard let wall = wall(mission: mission) else { return nil }
        var steps: [String] = []
        if let floor = wall.towerFloor, highestTowerFloor < floor {
            steps.append("去教会塔打到第 \(floor) 层，换上那里的装备")
        } else if let floor = wall.towerFloor, let depth = wornTowerDepth,
                  !meetsTowerFloor(mission: mission, gear: .init(towerDepth: depth)) {
            steps.append("换上深井第 \(floor) 层或更深的装备")
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
