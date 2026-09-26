import Foundation

public enum MPCDamageType: String, Codable, Sendable {
    case standard = "STANDARD"
    case trueDamage = "TRUE"
}

public struct MPCDamageInput: Equatable, Sendable {
    public var attack: Int
    public var coefficientBP: Int
    public var targetDefense: Int
    public var outgoingBonusBP: Int
    public var armorPenetrationBP: Int
    public var flatDefenseBonus: Int
    public var flatDefensePenalty: Int
    public var damageType: MPCDamageType

    public init(
        attack: Int,
        coefficientBP: Int,
        targetDefense: Int,
        outgoingBonusBP: Int = 0,
        armorPenetrationBP: Int = 0,
        flatDefenseBonus: Int = 0,
        flatDefensePenalty: Int = 0,
        damageType: MPCDamageType = .standard
    ) {
        self.attack = attack
        self.coefficientBP = coefficientBP
        self.targetDefense = targetDefense
        self.outgoingBonusBP = outgoingBonusBP
        self.armorPenetrationBP = armorPenetrationBP
        self.flatDefenseBonus = flatDefenseBonus
        self.flatDefensePenalty = flatDefensePenalty
        self.damageType = damageType
    }
}

public struct MPCDamageResult: Equatable, Sendable {
    public let modifiedDefense: Int
    public let effectiveDefense: Int
    public let damageAfterDefense: Int
}

public enum MPCFixedPointCombatMath {
    public static let percentageScale = 10_000

    public static func damage(_ input: MPCDamageInput) -> MPCDamageResult {
        let modifiedDefense = max(
            0,
            input.targetDefense + input.flatDefenseBonus - input.flatDefensePenalty
        )
        let penetration = min(max(input.armorPenetrationBP, 0), percentageScale)
        let effectiveDefense = input.damageType == .trueDamage
            ? 0
            : modifiedDefense * (percentageScale - penetration) / percentageScale

        guard input.coefficientBP > 0 else {
            return MPCDamageResult(
                modifiedDefense: modifiedDefense,
                effectiveDefense: effectiveDefense,
                damageAfterDefense: 0
            )
        }

        let numerator = Int64(input.attack)
            * Int64(input.coefficientBP)
            * Int64(percentageScale + input.outgoingBonusBP)
            * 100
        let denominator = Int64(percentageScale)
            * Int64(percentageScale)
            * Int64(100 + effectiveDefense)
        let rounded = roundHalfUp(numerator: numerator, denominator: denominator)

        return MPCDamageResult(
            modifiedDefense: modifiedDefense,
            effectiveDefense: effectiveDefense,
            damageAfterDefense: max(1, rounded)
        )
    }

    public static func applyReduction(
        to damageAfterDefense: Int,
        reductionsBP: [Int],
        capBP: Int = 6_000
    ) -> Int {
        guard damageAfterDefense > 0 else { return 0 }
        let reduction = min(max(reductionsBP.reduce(0, +), 0), capBP)
        let numerator = Int64(damageAfterDefense) * Int64(percentageScale - reduction)
        let rounded = roundHalfUp(
            numerator: numerator,
            denominator: Int64(percentageScale)
        )
        return max(1, rounded)
    }

    static func roundHalfUp(numerator: Int64, denominator: Int64) -> Int {
        precondition(numerator >= 0)
        precondition(denominator > 0)
        return Int((numerator * 2 + denominator) / (denominator * 2))
    }
}
