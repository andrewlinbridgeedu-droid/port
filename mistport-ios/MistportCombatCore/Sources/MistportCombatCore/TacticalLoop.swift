public enum MPCTacticalLoopError: Error, Equatable, Sendable {
    case emptyRing
    case tooManySkills(maximum: Int)
    case invalidCardsPerAct
}

public enum MPCSequenceRank: Int, Codable, CaseIterable, Sendable {
    case sequence9 = 9
    case sequence8 = 8
}

public struct MPCTacticalAct: Equatable, Sendable {
    public let cycle: Int
    public let skillIDs: [FoolSkillID]

    public init(cycle: Int, skillIDs: [FoolSkillID]) {
        self.cycle = cycle
        self.skillIDs = skillIDs
    }
}

/// Deterministic executor for the prebattle tactical ring.
///
/// Every equipped ordinary card executes exactly once per round, in the saved
/// order. Sequence rank remains progression data, but it never truncates the
/// number of cards executed in a round.
public struct MPCTacticalLoop: Equatable, Sendable {
    public static let maximumSkillCount = 6

    public let skillIDs: [FoolSkillID]
    /// Kept under the old public name for source compatibility. It now means
    /// the number of equipped cards executed in a complete round.
    public let cardsPerAct: Int
    public private(set) var cursor: Int
    public private(set) var cycle: Int

    public init(
        skillIDs: [FoolSkillID],
        cardsPerAct: Int? = nil,
        cursor: Int = 0,
        cycle: Int = 1
    ) throws {
        guard skillIDs.isEmpty == false else { throw MPCTacticalLoopError.emptyRing }
        guard skillIDs.count <= Self.maximumSkillCount else {
            throw MPCTacticalLoopError.tooManySkills(maximum: Self.maximumSkillCount)
        }
        if let cardsPerAct, cardsPerAct != skillIDs.count {
            throw MPCTacticalLoopError.invalidCardsPerAct
        }

        self.skillIDs = skillIDs
        self.cardsPerAct = skillIDs.count
        self.cursor = min(max(0, cursor), skillIDs.count - 1)
        self.cycle = max(1, cycle)
    }

    public init(skillIDs: [FoolSkillID], rank: MPCSequenceRank) throws {
        // Rank progression no longer changes the number of cards per round.
        try self.init(skillIDs: skillIDs)
    }

    public mutating func nextAct() -> MPCTacticalAct {
        let act = MPCTacticalAct(cycle: cycle, skillIDs: skillIDs)
        cursor = 0
        cycle += 1
        return act
    }
}

public enum MPCTacticalTargetRule: String, Codable, CaseIterable, Sendable {
    case frontmost
    case rearmost
    case lowestHP
    case supportFirst
    case bossFirst
    case previousTarget
}

public struct MPCTacticalTarget: Equatable, Sendable {
    public let id: String
    public let currentHP: Int
    public let maximumHP: Int
    public let formationOrder: Int
    public let isSupport: Bool
    public let isBoss: Bool
    public let isAlive: Bool

    public init(
        id: String,
        currentHP: Int,
        maximumHP: Int,
        formationOrder: Int,
        isSupport: Bool = false,
        isBoss: Bool = false,
        isAlive: Bool = true
    ) {
        self.id = id
        self.currentHP = currentHP
        self.maximumHP = maximumHP
        self.formationOrder = formationOrder
        self.isSupport = isSupport
        self.isBoss = isBoss
        self.isAlive = isAlive && currentHP > 0
    }
}

public enum MPCTacticalTargetResolver {
    public static func resolve(
        rule: MPCTacticalTargetRule,
        targets: [MPCTacticalTarget],
        previousTargetID: String? = nil,
        fallbackRule: MPCTacticalTargetRule = .frontmost
    ) -> String? {
        let alive = targets.filter(\.isAlive)
        guard alive.isEmpty == false else { return nil }

        if rule == .previousTarget,
           let previousTargetID,
           alive.contains(where: { $0.id == previousTargetID }) {
            return previousTargetID
        }

        let effectiveRule = rule == .previousTarget ? fallbackRule : rule
        return sorted(alive, for: effectiveRule).first?.id
    }

    private static func sorted(
        _ targets: [MPCTacticalTarget],
        for rule: MPCTacticalTargetRule
    ) -> [MPCTacticalTarget] {
        targets.sorted { lhs, rhs in
            let lhsPriority = priority(lhs, for: rule)
            let rhsPriority = priority(rhs, for: rule)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.formationOrder != rhs.formationOrder {
                return lhs.formationOrder < rhs.formationOrder
            }
            return lhs.id < rhs.id
        }
    }

    private static func priority(
        _ target: MPCTacticalTarget,
        for rule: MPCTacticalTargetRule
    ) -> Int {
        switch rule {
        case .frontmost, .previousTarget:
            target.formationOrder
        case .rearmost:
            -target.formationOrder
        case .lowestHP:
            target.currentHP * 10_000 / max(1, target.maximumHP)
        case .supportFirst:
            target.isSupport ? 0 : 1
        case .bossFirst:
            target.isBoss ? 0 : 1
        }
    }
}
