import Foundation

/// Tuning changes quantities only; all anomaly costs and event ordering are invariant.
public struct MPCSequenceNineRelicBalance: Equatable, Sendable {
    public let poisonCapturePercent: Int
    public let poisonCapacityPercent: Int
    public let giftShieldPercent: Int
    public init(poisonCapturePercent: Int = 60, poisonCapacityPercent: Int = 100, giftShieldPercent: Int = 50) {
        self.poisonCapturePercent = min(70, max(50, poisonCapturePercent))
        self.poisonCapacityPercent = min(150, max(75, poisonCapacityPercent))
        self.giftShieldPercent = min(50, max(25, giftShieldPercent))
    }
}

public enum MPCSequenceNineRelicIDs {
    public static let passives: Set<String> = ["relic_salt_sealed_breathing_bag", "relic_return_gift_clasp", "relic_deferred_stamp", "relic_reflecting_ink_mirror", "relic_sealed_paperweight", "relic_countertide_anchor", "relic_ownership_severing_needle"]
}
public struct MPCRelicDamageEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let targetID: String
    public let damage: Int
    public init(targetID: String, damage: Int) { self.id = UUID(); self.targetID = targetID; self.damage = damage }
}

struct MPCTimedRelicDamage: Equatable, Sendable {
    let source: String
    let damage: Int
    let dueAt: TimeInterval
    let remaining: Int
}
