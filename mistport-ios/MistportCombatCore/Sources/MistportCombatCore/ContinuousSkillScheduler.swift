import Foundation

/// Serial casts: every pass follows the selected positions, including after the opening.
/// Time is supplied by the caller so pausing and tests never depend on a wall clock.
public struct ContinuousSkillScheduler: Sendable {
    public private(set) var used: Set<FoolSkillID> = []
    public private(set) var startedAt: [FoolSkillID: TimeInterval] = [:]
    public private(set) var readyAt: [FoolSkillID: TimeInterval] = [:]
    public private(set) var lastOrdinarySkill: FoolSkillID?
    public init() {}

    public static func duration(for skill: FoolSkillID) -> TimeInterval {
        if skill.isOrderedOrdinary { return MPCOrderedSkillRules.cooldown }
        return switch skill {
        case .sidestepStrike: 4
        case .maskedWhisper: 12
        case .fabricatedEvidence, .mirrorPursuit: 6
        case .paperDouble, .identityDisplacement: 8
        case .turnTheTables: 10
        case .absurdFinale, .backstageChange: 12
        case .namelessStage: 20
        case .stolenTempo, .mirrorBarrage, .delayedSignature: MPCOrderedSkillRules.cooldown
        }
    }

    /// `sealed` cards (the final boss's 夺名代签, `sealedFoolSkillIDs(at:)`) are passed over
    /// until the seal lifts; the rest of the loop keeps its order.
    public func next(in sequence: [FoolSkillID], at now: TimeInterval, skipping sealed: Set<FoolSkillID> = []) -> FoolSkillID? {
        guard !sequence.isEmpty else { return nil }
        let start = lastOrdinarySkill.flatMap { sequence.firstIndex(of: $0) }.map { ($0 + 1) % sequence.count } ?? 0
        for offset in 0..<sequence.count {
            let skill = sequence[(start + offset) % sequence.count]
            guard !sealed.contains(skill) else { continue }
            return readyAt[skill, default: 0] <= now ? skill : nil
        }
        return nil
    }

    /// Repositioned cards start a full cooldown, including cards not yet cast.
    /// Unchanged positions and a cancelled/no-op drag keep their deadlines.
    @discardableResult
    public mutating func didReorder(from old: [FoolSkillID], to new: [FoolSkillID], at now: TimeInterval) -> Set<FoolSkillID> {
        guard now.isFinite, old != new else { return [] }
        let moved = Set(new.enumerated().compactMap { index, skill in
            old.firstIndex(of: skill) == index ? nil : skill
        })
        for skill in moved {
            used.insert(skill); startedAt[skill] = now; readyAt[skill] = now + Self.duration(for: skill)
        }
        lastOrdinarySkill = nil
        return moved
    }

    public mutating func didCast(_ skill: FoolSkillID, at now: TimeInterval) {
        used.insert(skill)
        startedAt[skill] = now
        readyAt[skill] = now + Self.duration(for: skill)
        if skill != .namelessStage && skill != .maskedWhisper { lastOrdinarySkill = skill }
    }
}
