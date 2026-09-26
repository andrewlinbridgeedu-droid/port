import Foundation

public enum MPCHitPolicy: String, Codable, Sendable {
    case dodgeable = "DODGEABLE"
    case unavoidable = "UNAVOIDABLE"
}

public enum MPCHitResult: String, Codable, Sendable {
    case hit = "HIT"
    case dodged = "DODGED"
    case immune = "IMMUNE"
    case invalid = "INVALID"
}

public struct MPCAttackAction: Equatable, Sendable {
    public var attack: Int
    public var coefficientsBP: [Int]
    public var targetDefense: Int
    public var outgoingBonusBP: Int
    public var armorPenetrationBP: Int
    public var damageType: MPCDamageType
    public var hitPolicy: MPCHitPolicy

    public init(
        attack: Int,
        coefficientsBP: [Int],
        targetDefense: Int,
        outgoingBonusBP: Int = 0,
        armorPenetrationBP: Int = 0,
        damageType: MPCDamageType = .standard,
        hitPolicy: MPCHitPolicy = .dodgeable
    ) {
        self.attack = attack
        self.coefficientsBP = coefficientsBP
        self.targetDefense = targetDefense
        self.outgoingBonusBP = outgoingBonusBP
        self.armorPenetrationBP = armorPenetrationBP
        self.damageType = damageType
        self.hitPolicy = hitPolicy
    }
}

public struct MPCTargetDefenseState: Equatable, Sendable {
    public var evasionCharges: Int
    public var guardCharges: Int
    public var guardReductionBP: Int
    public var otherReductionsBP: [Int]
    public var shield: Int
    public var hp: Int

    public init(
        evasionCharges: Int = 0,
        guardCharges: Int = 0,
        guardReductionBP: Int = 3_500,
        otherReductionsBP: [Int] = [],
        shield: Int = 0,
        hp: Int = 1_000
    ) {
        self.evasionCharges = evasionCharges
        self.guardCharges = guardCharges
        self.guardReductionBP = guardReductionBP
        self.otherReductionsBP = otherReductionsBP
        self.shield = shield
        self.hp = hp
    }
}

public struct MPCAttackResolution: Equatable, Sendable {
    public let hitResult: MPCHitResult
    public let damageHits: [Int]
    public let defenseState: MPCTargetDefenseState
}

public enum MPCAttackActionResolver {
    public static func resolve(
        _ action: MPCAttackAction,
        against initialState: MPCTargetDefenseState
    ) -> MPCAttackResolution {
        var state = initialState

        if action.hitPolicy == .dodgeable, state.evasionCharges > 0 {
            state.evasionCharges -= 1
            return MPCAttackResolution(
                hitResult: .dodged,
                damageHits: Array(repeating: 0, count: action.coefficientsBP.count),
                defenseState: state
            )
        }

        var hits: [Int] = []
        for coefficient in action.coefficientsBP {
            let damage = MPCFixedPointCombatMath.damage(
                MPCDamageInput(
                    attack: action.attack,
                    coefficientBP: coefficient,
                    targetDefense: action.targetDefense,
                    outgoingBonusBP: action.outgoingBonusBP,
                    armorPenetrationBP: action.armorPenetrationBP,
                    damageType: action.damageType
                )
            ).damageAfterDefense

            var reductions = state.otherReductionsBP
            if state.guardCharges > 0 {
                reductions.append(state.guardReductionBP)
            }
            let reducedDamage = reductions.isEmpty
                ? damage
                : MPCFixedPointCombatMath.applyReduction(to: damage, reductionsBP: reductions)
            let absorbed = min(state.shield, reducedDamage)
            state.shield -= absorbed
            state.hp = max(0, state.hp - (reducedDamage - absorbed))
            hits.append(reducedDamage)
        }

        if state.guardCharges > 0 {
            state.guardCharges -= 1
        }

        return MPCAttackResolution(
            hitResult: .hit,
            damageHits: hits,
            defenseState: state
        )
    }
}
