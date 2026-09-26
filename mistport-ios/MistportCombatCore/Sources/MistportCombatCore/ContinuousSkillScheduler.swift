import Foundation

/// Serial casts: one opening pass in loadout order, then oldest ready deadline.
/// Time is supplied by the caller so pausing and tests never depend on a wall clock.
public struct ContinuousSkillScheduler: Sendable {
    public private(set) var used: Set<FoolSkillID> = []
    public private(set) var startedAt: [FoolSkillID: TimeInterval] = [:]
    public private(set) var readyAt: [FoolSkillID: TimeInterval] = [:]
    public init() {}

    public static func duration(for skill: FoolSkillID) -> TimeInterval {
        switch skill {
        case .sidestepStrike: 4
        case .maskedWhisper: 12
        case .fabricatedEvidence, .mirrorPursuit: 6
        case .paperDouble, .identityDisplacement: 8
        case .turnTheTables: 10
        case .absurdFinale, .backstageChange: 12
        case .namelessStage: 20
        }
    }

    public func next(in sequence: [FoolSkillID], at now: TimeInterval) -> FoolSkillID? {
        if let first = sequence.first(where: { !used.contains($0) }) { return first }
        return sequence.enumerated()
            .filter { readyAt[$0.element, default: 0] <= now }
            .min {
                let a = readyAt[$0.element, default: 0]
                let b = readyAt[$1.element, default: 0]
                return a == b ? $0.offset < $1.offset : a < b
            }?.element
    }

    public mutating func didCast(_ skill: FoolSkillID, at now: TimeInterval) {
        used.insert(skill)
        startedAt[skill] = now
        readyAt[skill] = now + Self.duration(for: skill)
    }
}
