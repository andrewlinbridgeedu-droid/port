import Foundation

public enum MPCPartyTacticMode: String, Codable, CaseIterable, Sendable {
    case balanced = "BALANCED"
    case focusFire = "FOCUS_FIRE"
    case defensive = "DEFENSIVE"
    case comboSupport = "COMBO_SUPPORT"
    case conserve = "CONSERVE"
}

public enum MPCAIActionKind: String, Codable, Sendable {
    case damage
    case heal
    case shield
    case protect
    case cleanse
    case revive
    case support
}

public enum MPCPartyUnitSide: String, Codable, Sendable {
    case party
    case enemy
}

public struct MPCPartyUnitState: Equatable, Sendable {
    public let id: String
    public let side: MPCPartyUnitSide
    public var hp: Int
    public let maxHP: Int
    public var shield: Int
    public var isInvulnerable: Bool
    public var hasCleansableStatus: Bool
    public var statuses: [MPCPartyStatus]
    public var isBoss: Bool
    public var isElite: Bool

    public var isDowned: Bool { hp <= 0 }
    public var isAlive: Bool { hp > 0 }

    public init(
        id: String,
        side: MPCPartyUnitSide,
        hp: Int,
        maxHP: Int,
        shield: Int = 0,
        isInvulnerable: Bool = false,
        hasCleansableStatus: Bool = false,
        statuses: [MPCPartyStatus] = [],
        isBoss: Bool = false,
        isElite: Bool = false
    ) {
        self.id = id
        self.side = side
        self.hp = hp
        self.maxHP = maxHP
        self.shield = shield
        self.isInvulnerable = isInvulnerable
        self.hasCleansableStatus = hasCleansableStatus
        self.statuses = statuses
        self.isBoss = isBoss
        self.isElite = isElite
    }
}

public struct MPCPartyStatus: Equatable, Sendable {
    public let id: String
    public let ownerUnitID: String
    public let reservedForCombo: Bool
    public let alliesCanConsume: Bool

    public init(id: String, ownerUnitID: String, reservedForCombo: Bool, alliesCanConsume: Bool) {
        self.id = id
        self.ownerUnitID = ownerUnitID
        self.reservedForCombo = reservedForCombo
        self.alliesCanConsume = alliesCanConsume
    }
}

public struct MPCKnownEnemyIntent: Equatable, Sendable {
    public let targetUnitID: String?
    public let expectedDamage: Int
    public let isLethalBossMechanic: Bool

    public init(targetUnitID: String? = nil, expectedDamage: Int = 0, isLethalBossMechanic: Bool = false) {
        self.targetUnitID = targetUnitID
        self.expectedDamage = expectedDamage
        self.isLethalBossMechanic = isLethalBossMechanic
    }
}

public struct MPCAIActionCandidate: Equatable, Sendable {
    public let actorUnitID: String
    public let skillID: String
    public let skillPriority: Int
    public let targetUnitID: String
    public let targetSlot: Int
    public let kind: MPCAIActionKind
    public let magnitude: Int
    public let isUltimate: Bool
    public let isLongCooldown: Bool
    public let consumesStatusID: String?
    public let preventsKnownDamage: Int
    public let supportsPlayerCombo: Bool
    public let advancesOwnCombo: Bool

    public init(
        actorUnitID: String,
        skillID: String,
        skillPriority: Int,
        targetUnitID: String,
        targetSlot: Int = 0,
        kind: MPCAIActionKind,
        magnitude: Int = 0,
        isUltimate: Bool = false,
        isLongCooldown: Bool = false,
        consumesStatusID: String? = nil,
        preventsKnownDamage: Int = 0,
        supportsPlayerCombo: Bool = false,
        advancesOwnCombo: Bool = false
    ) {
        self.actorUnitID = actorUnitID
        self.skillID = skillID
        self.skillPriority = skillPriority
        self.targetUnitID = targetUnitID
        self.targetSlot = targetSlot
        self.kind = kind
        self.magnitude = magnitude
        self.isUltimate = isUltimate
        self.isLongCooldown = isLongCooldown
        self.consumesStatusID = consumesStatusID
        self.preventsKnownDamage = preventsKnownDamage
        self.supportsPlayerCombo = supportsPlayerCombo
        self.advancesOwnCombo = advancesOwnCombo
    }
}

public struct MPCPartyBattleState: Equatable, Sendable {
    public let playerUnitID: String
    public var units: [String: MPCPartyUnitState]
    public var tacticMode: MPCPartyTacticMode
    public var sharedReviveCharges: Int
    public var focusTargetUnitID: String?
    public var reserveAllyUltimates: Bool
    public var enemyIntent: MPCKnownEnemyIntent

    public init(
        playerUnitID: String,
        units: [MPCPartyUnitState],
        tacticMode: MPCPartyTacticMode = .balanced,
        sharedReviveCharges: Int = 1,
        focusTargetUnitID: String? = nil,
        reserveAllyUltimates: Bool = false,
        enemyIntent: MPCKnownEnemyIntent = MPCKnownEnemyIntent()
    ) {
        self.playerUnitID = playerUnitID
        self.units = Dictionary(uniqueKeysWithValues: units.map { ($0.id, $0) })
        self.tacticMode = tacticMode
        self.sharedReviveCharges = sharedReviveCharges
        self.focusTargetUnitID = focusTargetUnitID
        self.reserveAllyUltimates = reserveAllyUltimates
        self.enemyIntent = enemyIntent
    }
}

public struct MPCAIJointPlan: Equatable, Sendable {
    public let actions: [MPCAIActionCandidate]
    public let score: Int
    public let evaluatedPlanCount: Int
    public let generatedPlanCount: Int
    public let timedOut: Bool
    public let reasons: [String]
}

public struct MPCPartyAIConfiguration: Equatable, Sendable {
    public var maxCandidatesPerAI: Int
    public var maxJointPlans: Int
    public var hardBudgetNanoseconds: UInt64

    public init(maxCandidatesPerAI: Int = 8, maxJointPlans: Int = 128, hardBudgetMilliseconds: Int = 30) {
        self.maxCandidatesPerAI = maxCandidatesPerAI
        self.maxJointPlans = maxJointPlans
        self.hardBudgetNanoseconds = UInt64(max(0, hardBudgetMilliseconds)) * 1_000_000
    }
}

public enum MPCPartyAIPlanner {
    public static func chooseActions(
        state: MPCPartyBattleState,
        candidatesByActor: [String: [MPCAIActionCandidate]],
        actorOrder: [String],
        configuration: MPCPartyAIConfiguration = MPCPartyAIConfiguration(),
        nowNanoseconds: @Sendable () -> UInt64 = { DispatchTime.now().uptimeNanoseconds }
    ) -> MPCAIJointPlan? {
        guard (1...2).contains(actorOrder.count) else { return nil }
        let start = nowNanoseconds()
        let candidatesA = legalCandidates(
            candidatesByActor[actorOrder[0], default: []], state: state
        ).prefix(configuration.maxCandidatesPerAI)
        let plans: [[MPCAIActionCandidate]]
        if actorOrder.count == 1 {
            plans = candidatesA.map { [$0] }
        } else {
            let candidatesB = legalCandidates(
                candidatesByActor[actorOrder[1], default: []], state: state
            ).prefix(configuration.maxCandidatesPerAI)
            plans = Array(candidatesA.flatMap { first in candidatesB.map { [first, $0] } })
        }
        let boundedPlans = Array(plans.prefix(configuration.maxJointPlans))
        guard !boundedPlans.isEmpty else { return nil }

        var best: (actions: [MPCAIActionCandidate], score: Int, reasons: [String])?
        var evaluated = 0
        var timedOut = false

        for pair in boundedPlans {
            if evaluated > 0, nowNanoseconds() - start >= configuration.hardBudgetNanoseconds {
                timedOut = true
                break
            }
            guard let result = evaluateSequential(pair, initialState: state) else { continue }
            evaluated += 1
            if let current = best {
                if isBetter(score: result.score, actions: result.actions, than: current) {
                    best = result
                }
            } else {
                best = result
            }
        }

        guard let best else { return nil }
        return MPCAIJointPlan(
            actions: best.actions,
            score: best.score,
            evaluatedPlanCount: evaluated,
            generatedPlanCount: boundedPlans.count,
            timedOut: timedOut,
            reasons: best.reasons
        )
    }

    public static func legalCandidates(
        _ candidates: [MPCAIActionCandidate],
        state: MPCPartyBattleState
    ) -> [MPCAIActionCandidate] {
        candidates.filter { candidate in
            guard let actor = state.units[candidate.actorUnitID], actor.isAlive,
                  let target = state.units[candidate.targetUnitID] else { return false }
            if state.reserveAllyUltimates, candidate.isUltimate { return false }
            if state.tacticMode == .conserve, candidate.isUltimate || candidate.isLongCooldown { return false }
            if candidate.kind == .damage, target.side != .enemy || !target.isAlive || target.isInvulnerable { return false }
            if candidate.kind == .heal, target.side != .party || !target.isAlive || target.hp >= target.maxHP { return false }
            if candidate.kind == .shield, target.side != .party || !target.isAlive { return false }
            if candidate.kind == .cleanse, !target.hasCleansableStatus { return false }
            if candidate.kind == .revive {
                if target.id != state.playerUnitID || !target.isDowned || state.sharedReviveCharges <= 0 { return false }
            }
            if let statusID = candidate.consumesStatusID {
                guard let status = target.statuses.first(where: { $0.id == statusID }) else { return false }
                if status.reservedForCombo, status.ownerUnitID == state.playerUnitID, !status.alliesCanConsume {
                    return false
                }
            }
            return true
        }.sorted(by: deterministicCandidateOrder)
    }

    private static func evaluateSequential(
        _ pair: [MPCAIActionCandidate],
        initialState: MPCPartyBattleState
    ) -> (actions: [MPCAIActionCandidate], score: Int, reasons: [String])? {
        var state = initialState
        var chosen: [MPCAIActionCandidate] = []
        var score = 0
        var reasons: [String] = []

        for proposed in pair {
            let legal = legalCandidates([proposed], state: state)
            guard let action = legal.first else { return nil }
            let result = apply(action, to: &state)
            chosen.append(action)
            score += result.score
            reasons.append(result.reason)
        }

        if let player = state.units[state.playerUnitID], player.isDowned,
           state.sharedReviveCharges > 0,
           !chosen.contains(where: { $0.kind == .revive }) {
            return nil
        }

        if wouldPartyWipe(state) { score -= 5_000 }
        return (chosen, score, reasons)
    }

    private static func apply(
        _ action: MPCAIActionCandidate,
        to state: inout MPCPartyBattleState
    ) -> (score: Int, reason: String) {
        guard var target = state.units[action.targetUnitID] else { return (Int.min / 4, "目标无效") }
        var score = 0
        var reason = action.kind.rawValue

        switch action.kind {
        case .damage:
            let effective = min(target.hp, max(0, action.magnitude))
            target.hp -= effective
            score += effective
            if target.hp == 0 {
                score += target.isBoss ? 2_200 : (target.isElite ? 1_000 : 600)
                reason = target.isBoss ? "确定击杀首领" : "击杀目标"
            }
            if state.tacticMode == .focusFire, target.id == state.focusTargetUnitID { score += 120 }
        case .heal:
            let missing = target.maxHP - target.hp
            let effective = min(missing, max(0, action.magnitude))
            target.hp += effective
            score += effective - max(0, action.magnitude - effective)
            reason = "恢复\(effective)生命"
        case .shield:
            target.shield += max(0, action.magnitude)
            score += max(0, action.magnitude)
            reason = "获得\(action.magnitude)护盾"
        case .protect:
            score += max(action.preventsKnownDamage, action.magnitude)
            if target.id == state.playerUnitID,
               state.enemyIntent.targetUnitID == target.id,
               state.enemyIntent.expectedDamage >= target.hp + target.shield {
                score += 3_000
                reason = "阻止主角倒地"
            } else {
                reason = "抵御已知伤害"
            }
        case .cleanse:
            target.hasCleansableStatus = false
            score += 150
            reason = "净化危险状态"
        case .revive:
            target.hp = max(1, target.maxHP * 3 / 10)
            state.sharedReviveCharges -= 1
            score += 4_000
            reason = "复活玩家主角"
        case .support:
            score += 80
            reason = "提供连段支援"
        }

        if action.supportsPlayerCombo { score += 150 }
        if action.advancesOwnCombo { score += 80 }
        if action.isUltimate { score -= 250 }
        if action.isLongCooldown { score -= state.tacticMode == .conserve ? 100 : 40 }
        state.units[target.id] = target
        return (score, reason)
    }

    private static func wouldPartyWipe(_ state: MPCPartyBattleState) -> Bool {
        let party = state.units.values.filter { $0.side == .party }
        guard !party.isEmpty else { return true }
        let targetID = state.enemyIntent.targetUnitID
        return party.allSatisfy { unit in
            if unit.isDowned { return true }
            guard unit.id == targetID else { return false }
            return state.enemyIntent.expectedDamage >= unit.hp + unit.shield
        }
    }

    private static func isBetter(
        score: Int,
        actions: [MPCAIActionCandidate],
        than current: (actions: [MPCAIActionCandidate], score: Int, reasons: [String])
    ) -> Bool {
        if score != current.score { return score > current.score }
        return actions.lexicographicallyPrecedes(current.actions, by: deterministicCandidateOrder)
    }

    private static func deterministicCandidateOrder(_ lhs: MPCAIActionCandidate, _ rhs: MPCAIActionCandidate) -> Bool {
        if lhs.skillPriority != rhs.skillPriority { return lhs.skillPriority < rhs.skillPriority }
        if lhs.targetSlot != rhs.targetSlot { return lhs.targetSlot < rhs.targetSlot }
        if lhs.skillID != rhs.skillID { return lhs.skillID < rhs.skillID }
        return lhs.targetUnitID < rhs.targetUnitID
    }
}
