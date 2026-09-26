import Foundation

/// One battle's anomaly ledger. No state is refreshed by changing target or entering a wave.
public struct MPCSequenceNineRelicState: Equatable, Sendable {
    public struct DeferredDamage: Equatable, Sendable {
        public let targetID: String
        public let amount: Int
        public let dueAt: TimeInterval
    }
    public private(set) var selectedTargetID: String?
    public private(set) var selectedSince: TimeInterval = 0
    public private(set) var deferredDamage: DeferredDamage?
    public private(set) var stampReadyAt: TimeInterval = 0
    public private(set) var mirrorTargetID: String?
    public private(set) var mirrorExpiresAt: TimeInterval = 0
    public private(set) var mirrorReadyAt: TimeInterval = 0
    public private(set) var paperweightExpiresAt: TimeInterval = 0
    public private(set) var paperweightCapacity: Int = 0
    public private(set) var paperweightReadyAt: TimeInterval = 0
    public private(set) var anchorSourceID: String?
    public private(set) var anchorActionID: String?
    public private(set) var anchorExpiresAt: TimeInterval = 0
    public private(set) var anchorSegments: Int = 0
    public private(set) var anchorCapacity: Int = 0
    public private(set) var anchorReadyAt: TimeInterval = 0
    public private(set) var needleUses: Int = 0
    public private(set) var needleReadyAt: TimeInterval = 0
    public private(set) var healingBlockedUntil: TimeInterval = 0
    public private(set) var blankCardTargetID: String?
    public private(set) var blankCardExpiresAt: TimeInterval = 0
    public private(set) var blankCardReadyAt: TimeInterval = 0

    public init() {}
    public mutating func select(_ targetID: String?, at now: TimeInterval) {
        guard now.isFinite, targetID != selectedTargetID else { return }
        selectedTargetID = targetID
        selectedSince = now
        mirrorTargetID = nil
    }
    /// D already includes the cast's snapshot and ordinary mitigation. Only one
    /// direct target packet is delayed, not an entire AoE's statuses or animation.
    public mutating func deferSkillDamage(_ damage: Int, targetID: String, baseHP: Int, at now: TimeInterval) -> Bool {
        guard damage > 0, now.isFinite, deferredDamage == nil, now >= stampReadyAt else { return false }
        deferredDamage = .init(targetID: targetID, amount: damage + min(damage * 40 / 100, baseHP * 15 / 100), dueAt: now + 3)
        stampReadyAt = now + 12
        return true
    }
    public mutating func takeDueDamage(at now: TimeInterval) -> DeferredDamage? {
        guard let ticket = deferredDamage, now >= ticket.dueAt else { return nil }
        deferredDamage = nil
        return ticket
    }
    public mutating func offerMirrorGift(basicDamage: Int, targetID: String, targetMissingHP: Int,
                                        targetCanTakeDamage: Bool, livingEnemies: Int, baseHP: Int, at now: TimeInterval) -> Int {
        guard now >= mirrorReadyAt, targetID == selectedTargetID, now - selectedSince >= 2,
              livingEnemies >= 2, targetMissingHP > 0, targetCanTakeDamage else { return 0 }
        let gift = min(max(0, basicDamage), baseHP / 10, targetMissingHP)
        guard gift > 0 else { return 0 }
        mirrorTargetID = targetID
        mirrorExpiresAt = now + 4
        mirrorReadyAt = now + 8
        return gift
    }
    public mutating func reflectDirectDamage(_ damage: Int, sourceID: String, targetIsValid: Bool,
                                             baseHP: Int, at now: TimeInterval) -> (target: String, amount: Int)? {
        guard let target = mirrorTargetID else { return nil }
        guard targetIsValid, now < mirrorExpiresAt else { mirrorTargetID = nil; return nil }
        guard sourceID != target, damage > 0 else { return nil }
        mirrorTargetID = nil
        return (target, min(damage, baseHP / 5))
    }
    /// Slot is zero-based and fixed by preparation, not by the number of actual casts.
    public func shouldSeal(slot: Int, preparedCount: Int, at now: TimeInterval) -> Bool {
        preparedCount >= 3 && slot == 2 && now >= paperweightReadyAt
    }
    public mutating func establishPaperweight(baseHP: Int, at now: TimeInterval) {
        paperweightCapacity = baseHP * 35 / 100
        paperweightExpiresAt = now + 4
        paperweightReadyAt = now + 18
    }
    public mutating func containWithPaperweight(_ damage: Int, at now: TimeInterval) -> Int {
        guard damage > 0, now < paperweightExpiresAt, paperweightCapacity > 0 else { return 0 }
        let captured = min(damage, paperweightCapacity)
        paperweightCapacity = 0
        return captured
    }
    /// Input is a real, unblocked direct hit from one immutable authored attack ID.
    public mutating func anchorDamage(_ damage: Int, sourceID: String, actionID: String, baseHP: Int, at now: TimeInterval) -> Int {
        guard damage > 0 else { return 0 }
        if now < anchorExpiresAt, sourceID == anchorSourceID, actionID == anchorActionID, anchorSegments > 0 {
            let captured = min(damage, anchorCapacity)
            anchorCapacity -= captured; anchorSegments -= 1
            return damage - captured
        }
        guard now >= anchorReadyAt else { return damage }
        anchorSourceID = sourceID; anchorActionID = actionID
        anchorExpiresAt = now + 2; anchorSegments = 2; anchorCapacity = baseHP * 35 / 100
        anchorReadyAt = now + 10
        return damage + baseHP / 20
    }
    public mutating func interceptHealing(_ amount: Int, recipientID: String, healerID: String,
                                          playerMissingHP: Int, baseHP: Int, at now: TimeInterval) -> Int {
        guard needleUses < 2, now >= needleReadyAt, now >= healingBlockedUntil,
              recipientID == selectedTargetID, healerID != recipientID, amount > 0, playerMissingHP > 0 else { return 0 }
        let taken = min(amount, baseHP / 5, playerMissingHP)
        needleUses += 1; needleReadyAt = now + 12; healingBlockedUntil = now + 6
        return taken
    }
    public mutating func activateBlankCard(targetID: String, at now: TimeInterval) -> Bool {
        guard now.isFinite, now >= blankCardReadyAt else { return false }
        blankCardTargetID = targetID; blankCardExpiresAt = now + 3; blankCardReadyAt = now + 18
        return true
    }
    public func blankCardBlocks(_ counterpartID: String, at now: TimeInterval) -> Bool {
        now < blankCardExpiresAt && counterpartID == blankCardTargetID
    }
}
