import Foundation

/// Shared timings for the live client, deterministic replay and instant settlement.
/// Haste changes work performed per second, never the battle clock or cooldown.
public enum MPCOrderedSkillRules {
    public static let cooldown: TimeInterval = 7
    public static let hasteDuration: TimeInterval = 3.2
    public static let markDuration: TimeInterval = 4
    public static let signatureDelay: TimeInterval = 2.6
    public static let ordinarySkills: [FoolSkillID] = [.sidestepStrike, .fabricatedEvidence, .stolenTempo,
        .mirrorBarrage, .backstageChange, .turnTheTables, .identityDisplacement, .mirrorPursuit, .absurdFinale, .delayedSignature]

    public static func timing(_ skill: FoolSkillID) -> (cast: TimeInterval, recovery: TimeInterval) {
        switch skill {
        case .sidestepStrike: (0.85, 0.35)
        case .fabricatedEvidence: (0.55, 0.35)
        case .stolenTempo: (0.45, 0.25)
        case .mirrorBarrage: (1.8, 0.30)
        case .backstageChange: (0.65, 0.30)
        case .turnTheTables: (0.65, 0.40)
        case .identityDisplacement: (0.95, 0.40)
        case .mirrorPursuit: (1.15, 0.40)
        case .absurdFinale: (1.80, 0.55)
        case .delayedSignature: (0.55, 0.25)
        case .maskedWhisper, .paperDouble, .namelessStage: (0.96, 0.14)
        }
    }

    public static func finishWork(start: TimeInterval, work: TimeInterval, hasteUntil: TimeInterval) -> TimeInterval {
        guard start < hasteUntil else { return start + work }
        let accelerated = min(work, (hasteUntil - start) * 2)
        return start + accelerated / 2 + work - accelerated
    }

    /// The enemy's visible escalating assault prevents indefinite sustain from erasing order choices.
    /// Tutorial breaths and the two survive-five-action encounters retain their authored rules.
    public static func pressureStart(mission: Int) -> TimeInterval? {
        let deadlines: [Int: Double] = [5: 30, 6: 26, 7: 25, 8: 17, 9: 19, 10: 9,
            11: 17, 12: 16, 13: 16, 14: 19, 15: 21, 16: 6, 17: 6, 18: 22,
            19: 6, 21: 4, 22: 18, 23: 5, 24: 8, 25: 6, 26: 21, 27: 10]
        return deadlines[mission]
    }

    public static func pressureLayers(mission: Int, at now: TimeInterval) -> Int {
        guard let start = pressureStart(mission: mission), now >= start else { return 0 }
        return min(8, 1 + Int((now - start) / 4))
    }

    public static func slotCapacity(availableThrough mission: Int) -> Int {
        mission >= 10 ? 4 : mission >= 7 ? 3 : mission >= 2 ? 2 : 1
    }

    /// Skill available before this mission; daily access remains a separate gate.
    public static func unlockMission(_ skill: FoolSkillID) -> Int? {
        switch skill {
        case .sidestepStrike: 1
        case .fabricatedEvidence: 2
        case .stolenTempo: 7
        case .mirrorBarrage: 9
        case .backstageChange: 5
        case .turnTheTables: 6
        case .identityDisplacement: 8
        case .mirrorPursuit: 10
        case .absurdFinale: 11
        case .delayedSignature: 12
        case .maskedWhisper, .paperDouble, .namelessStage: nil
        }
    }
}

extension FoolSkillID {
    public var isOrderedOrdinary: Bool { MPCOrderedSkillRules.ordinarySkills.contains(self) }
    public var orderedCardAssetName: String { "FoolOrderedCard\(rawValue.suffix(2))20261012" }
}

public struct MPCOrderedCastTiming: Equatable, Sendable {
    public let firstImpactAt: TimeInterval
    public let lastImpactAt: TimeInterval
    public let readyAt: TimeInterval
}

struct MPCOrderedPreparedCast: Equatable, Sendable {
    var skill: FoolSkillID
    var target: String
    var start: TimeInterval
    var timing: MPCOrderedCastTiming
    var empowered: Bool
}

struct MPCOrderedDamageContext: Equatable, Sendable {
    var waveIndex: Int
    var actionBonusPercent: Int
    var multiplierBP: Int
}

struct MPCOrderedPendingHit: Equatable, Sendable {
    enum Kind: Equatable, Sendable { case mirror, barrage(end: TimeInterval), signature(hits: Int) }
    var at: TimeInterval
    var skill: FoolSkillID
    var target: String
    var kind: Kind
    var empowered = false
    var damageContext: MPCOrderedDamageContext? = nil
}

public struct MPCOrderedSkillImpact: Equatable, Sendable {
    public let skill: FoolSkillID
    public let at: TimeInterval
    public let targets: [MPCFoolSkillTargetResolution]
}
