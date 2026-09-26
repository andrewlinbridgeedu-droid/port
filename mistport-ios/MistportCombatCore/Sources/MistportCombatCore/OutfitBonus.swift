/// Small, freely switchable pre-battle bonuses. A session snapshots the outfit
/// so changing clothes in the city cannot alter a battle already in progress.
public struct MPCOutfitBonus: Equatable, Sendable {
    public let luckDodgeBP: Int
    public let attackBP: Int
    public let damageReductionBP: Int

    public static let none = Self(luckDodgeBP: 0, attackBP: 0, damageReductionBP: 0)

    public init(luckDodgeBP: Int, attackBP: Int, damageReductionBP: Int) {
        self.luckDodgeBP = luckDodgeBP
        self.attackBP = attackBP
        self.damageReductionBP = damageReductionBP
    }
}

public enum MPCOutfit: String, CaseIterable, Sendable {
    case mistportNight = "mistport-night"
    case starlightMagician = "starlight-magician"
    case midnightCarnival = "midnight-carnival"

    public var bonus: MPCOutfitBonus {
        switch self {
        case .mistportNight: .init(luckDodgeBP: 200, attackBP: 100, damageReductionBP: 100)
        case .starlightMagician: .init(luckDodgeBP: 300, attackBP: 100, damageReductionBP: 0)
        case .midnightCarnival: .init(luckDodgeBP: 100, attackBP: 200, damageReductionBP: 100)
        }
    }

    /// Stable per authored attack: retrying the same encounter cannot reroll
    /// luck, while a higher luck percentage includes every lower-tier success.
    public func dodgesDirectHit(
        encounterID: String,
        enemyID: String,
        intent: String,
        wave: Int,
        actionIndex: Int
    ) -> Bool {
        let chance = bonus.luckDodgeBP
        guard chance > 0 else { return false }
        let key = "\(encounterID)|\(enemyID)|\(intent)|\(wave)|\(actionIndex)"
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return hash % 10_000 < UInt64(chance)
    }
}
