import Testing
@testable import MistportCombatCore

@Suite("Sequence nine anomaly contracts")
struct SequenceNineRelicStateTests {
    @Test func stampIsOneTicketAndNoSecondMultiplication() {
        var s = MPCSequenceNineRelicState()
        let first = s.deferSkillDamage(200, targetID: "a", baseHP: 1000, at: 0)
        let second = s.deferSkillDamage(900, targetID: "b", baseHP: 1000, at: 1)
        #expect(first && !second)
        let early = s.takeDueDamage(at: 2.999)
        #expect(early == nil)
        let due = s.takeDueDamage(at: 3)
        #expect(due?.targetID == "a" && due?.amount == 280)
        let repeatTicket = s.takeDueDamage(at: 4)
        #expect(repeatTicket == nil)
    }
    @Test func mirrorRequiresRealGiftOtherEnemyAndCostsItsWindow() {
        var s = MPCSequenceNineRelicState()
        s.select("a", at: 0)
        let single = s.offerMirrorGift(basicDamage: 60, targetID: "a", targetMissingHP: 300, targetCanTakeDamage: true, livingEnemies: 1, baseHP: 1000, at: 3)
        #expect(single == 0)
        let gift = s.offerMirrorGift(basicDamage: 60, targetID: "a", targetMissingHP: 30, targetCanTakeDamage: true, livingEnemies: 2, baseHP: 1000, at: 3)
        #expect(gift == 30 && s.mirrorReadyAt == 11)
        let same = s.reflectDirectDamage(400, sourceID: "a", targetIsValid: true, baseHP: 1000, at: 4)
        #expect(same == nil)
        let other = s.reflectDirectDamage(400, sourceID: "b", targetIsValid: true, baseHP: 1000, at: 5)
        #expect(other?.amount == 200)
        #expect(s.mirrorTargetID == nil)
    }
    @Test func paperweightIsFixedSlotAndOneContact() {
        var s = MPCSequenceNineRelicState()
        #expect(!s.shouldSeal(slot: 1, preparedCount: 4, at: 0))
        #expect(!s.shouldSeal(slot: 2, preparedCount: 2, at: 0))
        #expect(s.shouldSeal(slot: 2, preparedCount: 4, at: 0))
        s.establishPaperweight(baseHP: 1000, at: 1)
        let captured = s.containWithPaperweight(100, at: 2)
        let second = s.containWithPaperweight(400, at: 2.1)
        #expect(captured == 100 && second == 0)
        #expect(!s.shouldSeal(slot: 2, preparedCount: 4, at: 18.99))
        #expect(s.shouldSeal(slot: 2, preparedCount: 4, at: 19))
    }
    @Test func anchorDoesNotMistakeAnotherEnemyOrActionForSecondSegment() {
        var s = MPCSequenceNineRelicState()
        let first = s.anchorDamage(100, sourceID: "a", actionID: "a1", baseHP: 1000, at: 0)
        let other = s.anchorDamage(100, sourceID: "b", actionID: "b1", baseHP: 1000, at: 0.1)
        let newAction = s.anchorDamage(100, sourceID: "a", actionID: "a2", baseHP: 1000, at: 0.2)
        let second = s.anchorDamage(200, sourceID: "a", actionID: "a1", baseHP: 1000, at: 0.3)
        let third = s.anchorDamage(200, sourceID: "a", actionID: "a1", baseHP: 1000, at: 0.4)
        #expect(first == 150 && other == 100 && newAction == 100 && second == 0 && third == 50)
    }
    @Test func needleConservesHealingAndCannotFarmFullHealth() {
        var s = MPCSequenceNineRelicState()
        s.select("a", at: 0)
        let full = s.interceptHealing(300, recipientID: "a", healerID: "b", playerMissingHP: 0, baseHP: 1000, at: 0)
        #expect(full == 0 && s.needleUses == 0)
        let taken = s.interceptHealing(300, recipientID: "a", healerID: "b", playerMissingHP: 80, baseHP: 1000, at: 0)
        #expect(taken == 80 && 300 - taken == 220 && s.healingBlockedUntil == 6)
        let second = s.interceptHealing(300, recipientID: "a", healerID: "b", playerMissingHP: 500, baseHP: 1000, at: 12)
        let third = s.interceptHealing(300, recipientID: "a", healerID: "b", playerMissingHP: 500, baseHP: 1000, at: 24)
        #expect(second == 200 && third == 0 && s.needleUses == 2)
    }
    @Test func blankCardBindingCannotMoveWithSelectionAndExpiryIsHalfOpen() {
        var s = MPCSequenceNineRelicState()
        let started = s.activateBlankCard(targetID: "a", at: 0)
        s.select("b", at: 1)
        #expect(started && s.blankCardBlocks("a", at: 2.999))
        #expect(!s.blankCardBlocks("b", at: 1) && !s.blankCardBlocks("a", at: 3))
    }
}
