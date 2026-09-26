import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Chapter thirty early relic integration")
struct ChapterThirtyEarlyRelicTests {
    func session(_ q: Int, passive: String, hp: Int = 1000, medal: Bool = false) throws -> MPCChapterOneEncounterSession {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [passive])
        if medal { loadout.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID }
        return try .start(encounterID: String(format: "chapter01_q%02d_encounter", q), party: .init(playerHP: hp, playerMaxHP: 1000), companionIDs: [], loadout: loadout)
    }
    @Test func poisonPartiallyContainedNeverDoubleChargesLowHealth() throws {
        var s = try session(5, passive: "relic_salt_sealed_breathing_bag", hp: 400)
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0)
        try s.endRound(actingEnemyID: id, at: 0.1)
        try s.endRound(actingEnemyID: id, at: 0.2) // actual 500 hit; now below cap
        _ = s.advanceRelicClock(at: 3)
        #expect(s.saltBreathingBagStored == 12)
        #expect(s.playerHP == 492)
        #expect(s.playerMaxHP == 999)
        s.finishRelicBattle()
        #expect(s.playerHP == 492 && s.playerMaxHP == 1000)
    }
    @Test func coarseFrameDoesNotMoveEarlierPoisonAfterMedalExpiry() throws {
        var coarse = try session(5, passive: "relic_salt_sealed_breathing_bag", medal: true)
        let activated = coarse.activateUsurpedLifeMedal(isOwned: true, at: 0)
        #expect(activated)
        try coarse.endRound(actingEnemyID: coarse.enemies[0].id, at: 0)
        var fine = coarse
        for i in 1...100 { _ = fine.advanceRelicClock(at: Double(i) / 10) }
        _ = coarse.advanceRelicClock(at: 10)
        #expect(coarse.playerHP == fine.playerHP)
        #expect(coarse.saltBreathingBagStored == fine.saltBreathingBagStored)
        #expect(coarse.playerMaxHP == fine.playerMaxHP)
        #expect(!coarse.isUsurpedLifeMedalActive)
    }
    @Test func giftShieldCannotExpireOrBeBrokenThroughTrueImmunity() throws {
        var s = try session(6, passive: "relic_return_gift_clasp")
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0) // guard -> strike
        try s.endRound(actingEnemyID: id, at: 2) // strike -> recover
        #expect(s.playerHP == 900)
        #expect(s.enemyGiftShields[id] == 150)
        try s.endRound(actingEnemyID: id, at: 3) // recover -> guard
        _ = s.advanceRelicClock(at: 20)
        #expect(!s.returnGiftClaspIsReady)
        let blocked = try s.applyPartyDamage(10000, to: id)
        #expect(blocked == 0 && s.enemyGiftShields[id] == 150)
        try s.endRound(actingEnemyID: id, at: 20) // open
        let healthDamage = try s.applyPartyDamage(200, to: id)
        #expect(healthDamage == 50)
        #expect(s.enemyGiftShields[id] == 0 && s.returnGiftClaspIsReady)
    }
    @Test func balanceMatrix() throws {
        for q in [5,6] {
            let passive = q == 5 ? "relic_salt_sealed_breathing_bag" : "relic_return_gift_clasp"
            for offset in [0.0, 6, 12, 14, 16] {
                let loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [passive])
                let r = try NewMaskBalanceSimulator.run(q: q, sequence: [.sidestepStrike], mask: false, loadout: loadout, medalOffset: offset, relicBalance: .init(giftShieldPercent: 50))
                print("CH30_RELIC Q\(q) offset=\(offset) outcome=\(r.session.outcome) time=\(r.seconds) hp=\(r.session.playerHP) enemy=\(r.session.enemies.map(\.hp))")
                #expect(r.session.outcome != .inProgress)
            }
        }
    }
}
