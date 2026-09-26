import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Chapter thirty objective runtime")
struct ChapterThirtyRuntimeTests {
    func session(_ q: Int) throws -> MPCChapterOneEncounterSession {
        try .start(encounterID: String(format:"chapter01_q%02d_encounter",q), party: .init(playerMaxHP:10000), companionIDs:[], loadout:.init(normalSkillIDs:[],isUltimateUnlocked:false,passiveIDs:[],relicIDs:[]))
    }
    @Test func bossMustCompleteFiveCyclesAndExternalShieldAbsorbsBodyDamage() throws {
        var s = try session(28)
        let boss = s.enemies[0].id
        let damage = try s.applyPartyDamage(100000, to: boss)
        #expect(damage == 0 && s.enemies[0].hp == s.enemies[0].maxHP && s.outcome == .inProgress)
        #expect(s.enemies[0].currentIntent == "calibration")
        for i in 0..<4 { s.commitEnemyImpact(from: boss); try s.endRound(actingEnemyID: boss, at: Double(i)) }
        #expect(s.completedBossCycles == 1 && s.outcome == .inProgress)
        for i in 4..<19 { s.commitEnemyImpact(from: boss); try s.endRound(actingEnemyID: boss, at: Double(i)) }
        #expect(s.completedBossCycles == 4 && s.outcome == .inProgress)
        s.commitEnemyImpact(from:boss); try s.endRound(actingEnemyID:boss,at:19)
        #expect(s.completedBossCycles == 5 && s.outcome == .victory)
        #expect(s.enemies[0].hasDeparted && s.enemies[0].hp == s.enemies[0].maxHP)
    }
    @Test func secondMeetingStillRequiresEscortsAfterBossDeparts() throws {
        var s = try session(29)
        let boss = s.enemies[0].id
        for i in 0..<20 { s.commitEnemyImpact(from:boss); try s.endRound(actingEnemyID:boss,at:Double(i)) }
        #expect(s.completedBossCycles == 5 && s.outcome == .inProgress)
        for e in s.enemies.filter(\.isAlive) { _ = try s.applyPartyDamage(100000,to:e.id) }
        #expect(s.outcome == .victory && s.enemies[0].hasDeparted)
    }
    @Test func protectedBossCanPayReturnGiftDebtWithoutTakingBodyDamage() throws {
        let loadout = MPCChapterOneLoadout(normalSkillIDs: [], isUltimateUnlocked: false,
                                           passiveIDs: [], relicIDs: ["relic_return_gift_clasp"])
        var s = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q28_encounter", party: .init(playerMaxHP: 10000),
            companionIDs: [], loadout: loadout
        )
        let boss = s.enemies[0].id
        for i in 0..<2 {
            s.commitEnemyImpact(from: boss)
            try s.endRound(actingEnemyID: boss, at: Double(i))
        }
        #expect(s.enemyGiftShields[boss, default: 0] > 0)
        let damage = try s.applyPartyDamage(100000, to: boss)
        #expect(damage == 0)
        #expect(s.enemyGiftShields[boss, default: 0] == 0)
        #expect(s.enemies[0].hp == s.enemies[0].maxHP)
    }
    @Test func fifthReturnCannotWinAfterItsLastAttackDefeatsThePlayer() throws {
        var s = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q28_encounter", party: .init(playerMaxHP: 735),
            companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false,
                                              passiveIDs: [], relicIDs: [])
        )
        let boss = s.enemies[0].id
        for i in 0..<20 where s.outcome == .inProgress {
            s.commitEnemyImpact(from: boss)
            try s.endRound(actingEnemyID: boss, at: Double(i))
        }
        #expect(s.outcome == .defeat)
        #expect(s.completedBossCycles == 4)
    }
    @Test func trueDeathWaitsForLaunchedAttackAndMutualDeathFails() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID:"chapter01_q30_encounter",party:.init(playerMaxHP:1),companionIDs:[],loadout:.init(normalSkillIDs:[],isUltimateUnlocked:false,passiveIDs:[],relicIDs:[]))
        let boss = s.enemies[0].id
        s.commitEnemyImpact(from:boss)
        _ = try s.applyPartyDamage(100000,to:boss)
        #expect(s.outcome == .inProgress)
        try s.endRound(actingEnemyID:boss,at:1)
        #expect(s.outcome == .defeat && s.playerHP == 0)
    }
    @Test func convoyAndVoluntarySeverUseObjectiveInsteadOfKillingBody() throws {
        for q in [20,25] {
            var s = try session(q)
            let target = s.enemies[0].id
            while !["calibration","recover"].contains(s.enemies[0].currentIntent) { try s.endRound(actingEnemyID:target,at:0) }
            let hp = s.enemies[0].hp
            _ = try s.applyPartyDamage(100000,to:target)
            #expect(s.chapterObjectiveProgress == s.chapterObjectiveRequired)
            #expect(s.enemies[0].hp == hp && s.enemies[0].hasDeparted)
            #expect(s.outcome == .victory)
        }
    }
    @Test func escortPowerIsARealPrecedingBudget() throws {
        var s = try session(26)
        let target = s.enemies[0].id, hp = s.enemies[0].hp
        _ = try s.applyPartyDamage(500,to:target)
        #expect(s.chapterSupplyRemaining == 400 && s.enemies[0].hp == hp)
        _ = try s.applyPartyDamage(500,to:target)
        #expect(s.chapterSupplyRemaining == 0 && s.enemies[0].hp == hp - 100)
    }
    @Test func q24HasOneMotherAndExactlyTwoNonRecursiveChildren() throws {
        var s = try session(24)
        let parent = try #require(s.enemies.first { $0.contentID == "enemy_resonant_clock_guard_q2" })
        _ = try s.applyPartyDamage(100000,to:parent.id)
        #expect(s.enemies.filter { $0.isAlive && $0.contentID == "enemy_resonant_clock_guard_q2_split" }.count == 2)
    }
}
