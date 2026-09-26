/// Approved chapter-one strengthening. Status counts, timing and relic contracts
/// deliberately do not participate in this multiplier.
public enum MPCSkillGrowth {
    public static let maximumLevel = 5

    public static func clampedLevel(_ level: Int) -> Int {
        min(maximumLevel, max(1, level))
    }

    public static func upgradeCost(from level: Int) -> Int? {
        let level = clampedLevel(level)
        return level < maximumLevel ? level * 30 : nil
    }

    public static func multiplierBasisPoints(for level: Int) -> Int {
        10_000 + (clampedLevel(level) - 1) * 1_000
    }

    /// Round down once, after the skill's existing damage modifiers.
    public static func scaledAmount(_ amount: Int, level: Int) -> Int {
        max(0, amount) * multiplierBasisPoints(for: level) / 10_000
    }

    /// These cards have an authored numerical effect eligible for strengthening.
    /// Pure status cards must not charge dust for a level with no combat benefit.
    public static func canUpgrade(_ skillID: FoolSkillID) -> Bool {
        switch skillID {
        case .sidestepStrike, .maskedWhisper, .identityDisplacement,
             .fabricatedEvidence, .mirrorPursuit, .absurdFinale: true
        case .paperDouble, .turnTheTables, .backstageChange, .namelessStage: false
        }
    }
}
