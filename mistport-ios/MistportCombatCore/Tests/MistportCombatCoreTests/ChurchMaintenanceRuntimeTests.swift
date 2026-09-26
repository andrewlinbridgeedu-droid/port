import Testing
@testable import MistportCombatCore

@Suite("Three-site maintenance runtime")
struct ChurchMaintenanceRuntimeTests {
    @Test func patrolSupportsOwnedRelicAndClonesAuthoredStats() throws {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        loadout.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_maintenance_j1_s1_runtime", companionIDs: [], loadout: loadout)
        #expect(s.isChurchCombat && s.encounter.waves.count == 2 && s.encounter.fixedRewardItemIDs.isEmpty)
        let raw = MPCChurchTowerCatalog.floor(number: 1)!.enemies[0]
        #expect(s.enemies[0].maxHP == raw.hp && s.enemies[0].attack == raw.attack)
        let accepted = s.activateUsurpedLifeMedal(isOwned: true, at: 0)
        #expect(accepted)
    }
    @Test func repairSiteKeepsBattleAndHPThroughAllThreeWaves() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_maintenance_j2_f10_s1_runtime", companionIDs: [])
        let settlement = s.settlementID
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0)
        s.commitEnemyImpact(from: id)
        _ = try s.applyPartyDamage(10000, to: id)
        try s.endRound(actingEnemyID: id, at: 1)
        let hp = s.playerHP
        #expect(s.isAwaitingTowerWave)
        s.advanceChurchTowerEffects(at: 2)
        #expect(s.waveIndex == 1 && s.playerHP == hp && s.settlementID == settlement)
        let second = s.enemies[0].id
        try s.endRound(actingEnemyID: second, at: 2) // guard opens
        _ = try s.applyPartyDamage(10000, to: second)
        s.advanceChurchTowerEffects(at: 3)
        #expect(s.waveIndex == 2 && s.settlementID == settlement)
        #expect(s.encounter.fixedRewardItemIDs.isEmpty)
    }
}
