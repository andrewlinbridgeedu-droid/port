import Foundation

// Mission challenges (2026-10-18, user: 打过的每一关加三个挑战……每颗星只给一次技能粉尘，用来升级技能).
// Every story mission Q1–Q30 carries three stars. A star is judged from one won battle and pays its
// skill dust once, ever. Thresholds come from the real-loop model (MissionChallengeTests,
// docs/development/MISSION_CHALLENGES_20261018.md), not from guesses.

/// What one star asks for.
public enum MPCMissionChallengeKind: Equatable, Sendable {
    /// Win within this many seconds of battle time.
    case timeLimit(seconds: Int)
    /// Lose at most this share of the health you entered with (the medal's own settlement does not count).
    case damageTakenAtMost(percent: Int)
    /// A named combo from `MPCChapterOneCatalog.combos`: its four cards in a row on one enemy.
    case combo(id: String)
    /// These cards in a row on one enemy (missions before the four-card combos exist).
    case chain([FoolSkillID])
    /// The ownerless mask takes at least this many blows.
    case maskCatches(Int)
    /// Take at least this many counter chances.
    case counters(Int)
    /// Every enemy of this kind falls before any other enemy does (tap it to target it).
    case defeatFirst(contentID: String)
    /// Win without raising the ownerless mask or the usurped-life medal.
    case withoutActiveRelic
    /// Win without 我叫无人.
    case withoutUltimate
    /// Q28–Q30: win without spending the party's revive.
    case withoutRevive
}

public struct MPCMissionChallenge: Identifiable, Equatable, Sendable {
    public let mission: Int
    /// 1...3, the star's position.
    public let star: Int
    public let kind: MPCMissionChallengeKind
    /// Ledger key, stable across versions: "q07.2".
    public var id: String { String(format: "q%02d.%d", mission, star) }

    public init(mission: Int, star: Int, kind: MPCMissionChallengeKind) {
        self.mission = mission; self.star = star; self.kind = kind
    }

    /// Player-facing line (plain Chinese).
    public var title: String {
        switch kind {
        case .timeLimit(let seconds): return "\(seconds) 秒内打完"
        case .damageTakenAtMost(let percent):
            return percent == 50 ? "受伤不超过一半" : "受伤不超过生命的 \(percent)%"
        case .combo(let id):
            return "打出连招『\(MPCChapterOneCatalog.combos.first { $0.id == id }?.name ?? id)』"
        case .chain(let cards):
            return "对同一个敌人连续打出 " + cards.map(MPCMissionChallengeCatalog.cardName).joined(separator: " → ")
        case .maskCatches(let count): return "用无主假面接下 \(count) 次攻击"
        case .counters(let count): return "反击 \(count) 次"
        case .defeatFirst(let contentID): return "先打倒\(MPCMissionChallengeCatalog.enemyName(contentID))"
        case .withoutActiveRelic: return "不用假面和勋章打赢"
        case .withoutUltimate: return "不用『我叫无人』打赢"
        case .withoutRevive: return "不用复活打赢"
        }
    }

    /// One more line for the challenge sheet: how it is counted.
    public var detail: String {
        switch kind {
        case .timeLimit: return "从开战算到最后一击。"
        case .damageTakenAtMost: return "按进场时的生命上限算，护盾挡下的不算；僭命勋章结束时交出的生命不算。"
        case .combo(let id):
            let combo = MPCChapterOneCatalog.combos.first { $0.id == id }
            return "\(combo?.sequence ?? "")：四张牌按这个顺序接连出手，打在同一个敌人身上。"
        case .chain: return "按这个顺序接连出手，中间不插别的牌，打在同一个敌人身上。"
        case .maskCatches: return "假面每替你挡下一次攻击算一次。"
        case .counters: return "敌人重击被接下后，3 秒内点反击算一次。"
        case .defeatFirst(let contentID):
            return "点它把它设为目标。所有\(MPCMissionChallengeCatalog.enemyName(contentID))都倒下之前，别的敌人一个也不能先倒。"
        case .withoutActiveRelic: return "整场不戴起无主假面，也不发动僭命勋章；被动遗落物照常生效。"
        case .withoutUltimate: return "整场不放终极技。"
        case .withoutRevive: return "队伍的那次复活留着不用。"
        }
    }

    public func isMet(by stats: MPCMissionBattleStats) -> Bool {
        guard stats.won, stats.mission == mission else { return false }
        switch kind {
        case .timeLimit(let seconds): return stats.seconds <= Double(seconds)
        case .damageTakenAtMost(let percent): return stats.damageTaken * 100 <= percent * max(1, stats.enteringMaxHP)
        case .combo(let id):
            guard let cards = MPCMissionChallengeCatalog.comboCards(id) else { return false }
            return stats.landedChain(cards)
        case .chain(let cards): return stats.landedChain(cards)
        case .maskCatches(let count): return stats.maskCatches >= count
        case .counters(let count): return stats.counters >= count
        case .defeatFirst(let contentID):
            guard let last = stats.defeatOrder.lastIndex(of: contentID) else { return false }
            return stats.defeatOrder[...last].allSatisfy { $0 == contentID }
        case .withoutActiveRelic: return stats.activeRelicUses == 0
        case .withoutUltimate: return !stats.ultimateUsed
        case .withoutRevive: return stats.revivesUsed == 0
        }
    }
}

/// What a finished story battle reports for the stars. Fill it with `MPCMissionChallengeRecorder`.
public struct MPCMissionBattleStats: Codable, Equatable, Sendable {
    public struct Cast: Codable, Equatable, Sendable {
        public let skill: FoolSkillID
        public let targetID: String?
        public init(skill: FoolSkillID, targetID: String?) { self.skill = skill; self.targetID = targetID }
    }
    public var mission: Int
    public var won: Bool
    /// Battle time (not wall time) when the outcome was decided.
    public var seconds: Double
    public var enteringMaxHP: Int
    /// Health lost during the battle (shields excluded; the medal's settlement excluded).
    public var damageTaken: Int
    /// Every card, the ultimate and the mask in cast order (`session.executedSkills`).
    public var casts: [Cast]
    public var ultimateUsed: Bool
    public var maskCatches: Int
    public var counters: Int
    public var medicinesUsed: Int
    public var revivesUsed: Int
    /// Times the ownerless mask was raised plus times the medal was set off.
    public var activeRelicUses: Int
    /// Content IDs of the enemies in the order they fell (or left the field).
    public var defeatOrder: [String]

    public init(mission: Int, won: Bool, seconds: Double, enteringMaxHP: Int, damageTaken: Int, casts: [Cast] = [],
                ultimateUsed: Bool = false, maskCatches: Int = 0, counters: Int = 0, medicinesUsed: Int = 0, revivesUsed: Int = 0,
                activeRelicUses: Int = 0, defeatOrder: [String] = []) {
        self.mission = mission; self.won = won; self.seconds = seconds; self.enteringMaxHP = enteringMaxHP
        self.damageTaken = damageTaken; self.casts = casts; self.ultimateUsed = ultimateUsed; self.maskCatches = maskCatches
        self.counters = counters; self.medicinesUsed = medicinesUsed; self.revivesUsed = revivesUsed
        self.activeRelicUses = activeRelicUses; self.defeatOrder = defeatOrder
    }

    public var damageTakenPercent: Double { Double(damageTaken) * 100 / Double(max(1, enteringMaxHP)) }

    /// `cards` back to back among the ordinary card casts (the ultimate and the mask are not cards
    /// in the loop and neither break nor join a chain), every one on the same enemy.
    public func landedChain(_ cards: [FoolSkillID]) -> Bool {
        guard !cards.isEmpty else { return false }
        let ordinary = casts.filter { $0.skill.isOrderedOrdinary }
        guard ordinary.count >= cards.count else { return false }
        for start in 0...(ordinary.count - cards.count) {
            let window = ordinary[start..<(start + cards.count)]
            if window.map(\.skill) == cards, let target = window.first?.targetID,
               window.allSatisfy({ $0.targetID == target }) { return true }
        }
        return false
    }
}

/// Watches a story battle once per rule tick and reports `MPCMissionBattleStats` at the end.
/// Read-only: it never changes the session. The App calls `observe` after each
/// `advanceContinuousCombat(at:)` (live and fast-forward alike) and `stats` when the battle ends.
public struct MPCMissionChallengeRecorder: Sendable {
    public private(set) var enteringMaxHP = 0
    public private(set) var damageTaken = 0
    public private(set) var medicinesUsed = 0
    public private(set) var revivesUsed = 0
    public private(set) var activeRelicUses = 0
    public private(set) var defeatOrder: [String] = []
    /// Battle time at which the outcome stopped being in progress.
    public private(set) var decidedAt: TimeInterval?
    public private(set) var lastSeen: TimeInterval = 0
    private var started = false
    private var lastHP = 0
    private var lastSettledMedal: UUID?
    private var lastConsumables: [String: Int] = [:]
    private var lastRevives = 0
    private var lastMaskReadyAt: TimeInterval = 0
    private var lastMedal: UUID?
    private var fallen: Set<String> = []

    public init() {}

    /// Call before the first tick (optional; the first `observe` does the same from a full-health start).
    public mutating func begin(_ session: MPCChapterOneEncounterSession) {
        started = true
        enteringMaxHP = session.playerBaseMaxHP
        lastHP = session.playerHP
        lastSettledMedal = session.usurpedLifeMedalSettledActivationID
        lastConsumables = session.consumables
        lastRevives = session.sharedReviveCharges
        lastMaskReadyAt = session.ownedManualMaskReadyAt
        lastMedal = session.usurpedLifeMedalActivationID
    }

    public mutating func observe(_ session: MPCChapterOneEncounterSession, at now: TimeInterval) {
        if !started {
            begin(session)
            lastHP = session.playerBaseMaxHP // story battles always start at full health
            lastSettledMedal = nil
        }
        lastSeen = now
        let hp = session.playerHP
        if session.usurpedLifeMedalSettledActivationID != lastSettledMedal {
            // The medal hands back half the health left: (h + 1) / 2. Count only what fell beyond that.
            damageTaken += max(0, lastHP - 2 * hp)
            lastSettledMedal = session.usurpedLifeMedalSettledActivationID
        } else {
            damageTaken += max(0, lastHP - hp)
        }
        lastHP = hp
        for (item, count) in lastConsumables where session.consumables[item, default: 0] < count {
            medicinesUsed += count - session.consumables[item, default: 0]
        }
        lastConsumables = session.consumables
        if session.sharedReviveCharges < lastRevives { revivesUsed += lastRevives - session.sharedReviveCharges }
        lastRevives = session.sharedReviveCharges
        // Each raise of the mask pushes its ready time on; each medal activation has a new ID.
        if session.ownedManualMaskReadyAt > lastMaskReadyAt { activeRelicUses += 1 }
        lastMaskReadyAt = session.ownedManualMaskReadyAt
        if let medal = session.usurpedLifeMedalActivationID, medal != lastMedal { activeRelicUses += 1 }
        lastMedal = session.usurpedLifeMedalActivationID
        for enemy in session.enemies where !enemy.isAlive && !fallen.contains(enemy.id) {
            fallen.insert(enemy.id); defeatOrder.append(enemy.contentID)
        }
        if decidedAt == nil, session.outcome != .inProgress { decidedAt = now }
    }

    public func stats(for session: MPCChapterOneEncounterSession) -> MPCMissionBattleStats {
        .init(mission: session.chapterMissionNumber, won: session.outcome == .victory, seconds: decidedAt ?? lastSeen,
              enteringMaxHP: max(1, enteringMaxHP == 0 ? session.playerBaseMaxHP : enteringMaxHP), damageTaken: damageTaken,
              casts: session.executedSkills.map { .init(skill: $0.skillID, targetID: $0.targetID) },
              ultimateUsed: session.foolUltimateUsed,
              maskCatches: session.triggeredEffects.filter { $0.hasPrefix("幻影：承接") }.count,
              counters: session.triggeredEffects.filter { $0.hasPrefix("反击：") }.count,
              medicinesUsed: medicinesUsed, revivesUsed: revivesUsed, activeRelicUses: activeRelicUses, defeatOrder: defeatOrder)
    }
}

/// Stars already paid, by challenge id. Codable so the App keeps it with the campaign.
public struct MPCMissionChallengeLedger: Codable, Equatable, Sendable {
    public private(set) var claimedIDs: Set<String>
    /// Each story mission's best won battle (2026-10-22, the "really got stronger" read-out): the fastest
    /// time and the least health lost, kept separately. Optional so ledgers written before it decode.
    public private(set) var records: [String: MPCMissionRecord]?
    public init(claimedIDs: Set<String> = []) { self.claimedIDs = claimedIDs }

    public struct Claim: Equatable, Sendable {
        /// Stars this battle earned for the first time.
        public let newlyEarned: [MPCMissionChallenge]
        /// Stars this battle met that were already paid.
        public let alreadyEarned: [MPCMissionChallenge]
        public let dust: Int
        /// The mission's record before this battle (nil the first time it is won).
        public var previous: MPCMissionRecord? = nil
        /// The record after it.
        public var record: MPCMissionRecord? = nil
    }

    public func hasEarned(_ challenge: MPCMissionChallenge) -> Bool { claimedIDs.contains(challenge.id) }
    public func stars(mission: Int) -> Int {
        MPCMissionChallengeCatalog.challenges(for: mission).filter(hasEarned).count
    }
    public var totalStars: Int { claimedIDs.count }
    public func record(mission: Int) -> MPCMissionRecord? { records?[Self.recordKey(mission)] }
    static func recordKey(_ mission: Int) -> String { String(format: "q%02d", mission) }

    /// Records the stars a won battle met and returns the dust to add, once per star, ever.
    /// Calling it again with the same stats pays nothing. A won battle also updates the mission's record.
    public mutating func claim(_ stats: MPCMissionBattleStats) -> Claim {
        let met = MPCMissionChallengeCatalog.challenges(for: stats.mission).filter { $0.isMet(by: stats) }
        let fresh = met.filter { !claimedIDs.contains($0.id) }
        for challenge in fresh { claimedIDs.insert(challenge.id) }
        var claim = Claim(newlyEarned: fresh, alreadyEarned: met.filter { !fresh.contains($0) },
                          dust: fresh.count * MPCMissionChallengeCatalog.dustPerStar(mission: stats.mission))
        if stats.won {
            let key = Self.recordKey(stats.mission)
            claim.previous = records?[key]
            var record = claim.previous ?? MPCMissionRecord(seconds: stats.seconds, damagePercent: stats.damageTakenPercent, wins: 0)
            record.seconds = min(record.seconds, stats.seconds)
            record.damagePercent = min(record.damagePercent, stats.damageTakenPercent)
            record.wins += 1
            records = (records ?? [:]).merging([key: record]) { $1 }
            claim.record = record
        }
        return claim
    }
}

/// A story mission's best won battle: fastest time and least health lost (not necessarily the same battle).
public struct MPCMissionRecord: Codable, Equatable, Sendable {
    public var seconds: Double
    public var damagePercent: Double
    public var wins: Int
    public init(seconds: Double, damagePercent: Double, wins: Int) {
        self.seconds = seconds; self.damagePercent = damagePercent; self.wins = wins
    }
}

public enum MPCMissionChallengeCatalog {
    public static let dustItemID = "material_skill_dust"

    /// Dust per star. Upgrades cost 30/60/90/120 (`MPCSkillGrowth`); later stars pay more as the cards
    /// that matter climb the dearer levels. All 90 stars pay 900, plus the 60 from Q9 and Q14: a quarter of
    /// the 3300 that maxes every card, enough for one four-card hand at Lv4 (720) by the end of the chapter.
    public static func dustPerStar(mission: Int) -> Int {
        switch mission {
        case 1...10: 5
        case 11...20: 10
        case 21...30: 15
        default: 0
        }
    }

    /// The four cards of a named combo, read from its authored sequence text.
    public static func comboCards(_ id: String) -> [FoolSkillID]? {
        guard let combo = MPCChapterOneCatalog.combos.first(where: { $0.id == id }) else { return nil }
        let cards = combo.sequence.components(separatedBy: " → ").map { name in
            MPCChapterOneCatalog.skills.first { $0.name == name }?.id
        }
        return cards.contains(nil) ? nil : cards.compactMap { $0 }
    }

    static func enemyName(_ contentID: String) -> String {
        MPCChapterOneCatalog.enemies.first { $0.id == contentID }?.name ?? "敌人"
    }

    static func cardName(_ id: FoolSkillID) -> String {
        MPCChapterOneCatalog.skills.first { $0.id == id }?.name ?? id.rawValue
    }

    public static func challenges(for mission: Int) -> [MPCMissionChallenge] {
        guard let kinds = table[mission] else { return [] }
        return kinds.enumerated().map { .init(mission: mission, star: $0.offset + 1, kind: $0.element) }
    }

    public static var all: [MPCMissionChallenge] { (1...30).flatMap(challenges(for:)) }

    /// Stars a battle met (empty for a loss).
    public static func earned(_ stats: MPCMissionBattleStats) -> [MPCMissionChallenge] {
        challenges(for: stats.mission).filter { $0.isMet(by: stats) }
    }

    /// Three stars per mission (2026-10-19). Star 1 most first clears get, star 2 about half, star 3 asks for
    /// a deliberate hand (a combo, a chain, the cores first, no relic). Every star has a proof route in
    /// MissionChallengeTests; the model behind the numbers is docs/development/MISSION_CHALLENGES_20261018.md.
    static let table: [Int: [MPCMissionChallengeKind]] = [
        1: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 20), .damageTakenAtMost(percent: 25)],
        2: [.timeLimit(seconds: 45), .chain([.fabricatedEvidence, .sidestepStrike]), .timeLimit(seconds: 37)],
        3: [.timeLimit(seconds: 45), .maskCatches(4), .timeLimit(seconds: 40)],
        4: [.damageTakenAtMost(percent: 50), .counters(4), .timeLimit(seconds: 85)],
        5: [.timeLimit(seconds: 45), .withoutActiveRelic, .chain([.fabricatedEvidence, .sidestepStrike])],
        6: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 40), .chain([.fabricatedEvidence, .turnTheTables])],
        7: [.damageTakenAtMost(percent: 60), .timeLimit(seconds: 40), .chain([.stolenTempo, .sidestepStrike])],
        8: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 35), .chain([.fabricatedEvidence, .identityDisplacement])],
        9: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 40), .defeatFirst(contentID: "enemy_memory_leech_node")],
        10: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 25), .combo(id: "O05")],
        11: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 23), .combo(id: "O01")],
        12: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 28), .combo(id: "O04")],
        13: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 25), .combo(id: "O03")],
        14: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 27), .combo(id: "O02")],
        15: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 30), .defeatFirst(contentID: "enemy_memory_leech_node")],
        16: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 18), .combo(id: "O01")],
        17: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 18), .combo(id: "O04")],
        18: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 26), .combo(id: "O03")],
        19: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 14), .combo(id: "O02")],
        20: [.timeLimit(seconds: 30), .withoutActiveRelic, .combo(id: "O05")],
        21: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 21), .defeatFirst(contentID: "enemy_memory_leech_node")],
        22: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 28), .combo(id: "O01")],
        23: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 16), .combo(id: "O03")],
        24: [.damageTakenAtMost(percent: 75), .timeLimit(seconds: 22), .combo(id: "O05")],
        25: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 21), .combo(id: "O02")],
        26: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 25), .combo(id: "O01")],
        27: [.damageTakenAtMost(percent: 50), .timeLimit(seconds: 20), .combo(id: "O03")],
        28: [.withoutRevive, .damageTakenAtMost(percent: 50), .combo(id: "O04")],
        29: [.withoutRevive, .timeLimit(seconds: 80), .combo(id: "O01")],
        30: [.withoutRevive, .timeLimit(seconds: 65), .combo(id: "O02")],
    ]
}
