import Testing
@testable import MistportCombatCore
@Suite("Confirmed enemy impact identities") struct EnemyImpactIdentityTests {
    func victims() throws -> [MPCRuntimeEnemy] {
        try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q02_encounter", companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])).enemies
    }
    @Test func onlyPositiveActualVictims() throws {
        let e = try victims()
        #expect(MPCChapterOneBattleIdentity.impactAction(skill: .sidestepStrike, hits: [(e[0].id, 100), (e[1].id, 200)], enemies: e) == "enemy-impact:fool_skill_01:clock-guard-primary,clock-guard-secondary")
        #expect(MPCChapterOneBattleIdentity.impactAction(skill: .backstageChange, hits: [(e[0].id, 0), (e[1].id, -10)], enemies: e) == nil)
        #expect(MPCChapterOneBattleIdentity.impactAction(skill: nil, hits: [("absent", 100)], enemies: e) == nil)
    }
    @Test func lethalAndRepeatedHitsKeepOriginalIdentity() throws {
        var e = try victims(); e[0].hp = 0
        #expect(MPCChapterOneBattleIdentity.impactAction(skill: .namelessStage, hits: [(e[0].id, 1000), (e[0].id, 1000), (e[1].id, 0)], enemies: e) == "enemy-impact:fool_skill_10:clock-guard-primary")
        #expect(MPCChapterOneBattleIdentity.impactAction(skill: nil, hits: [(e[1].id, 30)], enemies: e) == "enemy-impact:basic:clock-guard-secondary")
    }
}
