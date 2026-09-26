import Testing
@testable import MistportCombatCore

@Suite("Nameplate healing downside", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
struct NameplateHealingPenaltyTests {
    @Test("Only a real shield dispel triggers the nameplate", arguments: [false, true])
    func actualDispel(_ hasShield: Bool) throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q17_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [],
                           relicIDs: ["relic_trimmed_nameplate"]))
        let enemy = session.enemies[0]
        if hasShield { session.grantPlayerShield(100) }
        try session.endRound(actingEnemyID: enemy.id)
        #expect(session.playerShield == 0)
        #expect(session.playerHP == session.playerMaxHP - enemy.attack * 3 / 4)
        #expect(session.foolState(for: enemy.id)?.illusionStacks == (hasShield ? 2 : 0))
        #expect(session.triggeredEffects.contains { $0.contains("裁去的名牌") } == hasShield)
    }

    @Test("The next salve loses 30 percent at different maximum HP, then expires", arguments: [1_000, 2_000])
    func percentageAndExpiry(_ maxHP: Int) throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q17_encounter",
            party: .init(playerHP: maxHP / 2, playerMaxHP: maxHP),
            consumables: ["consumable_pain_salve": 2], companionIDs: [],
            loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [],
                           relicIDs: ["relic_trimmed_nameplate"]))
        let trimmer = try #require(session.enemies.first { $0.contentID == "elite_memory_trimmer" })
        let guardEnemy = try #require(session.enemies.first { $0.contentID == "enemy_hollow_clockmaker" })
        // Chapter encounters intentionally start full; create missing HP via
        // real hostile contacts rather than relying on persistent party HP.
        while session.playerHP > maxHP / 2 {
            try session.endRound(actingEnemyID: guardEnemy.id)
        }
        session.grantPlayerShield(100)
        try session.endRound(actingEnemyID: trimmer.id)
        let before = session.playerHP
        try session.useConsumable("consumable_pain_salve")
        #expect(session.playerHP - before == maxHP * 20 / 100 * 70 / 100)
        let afterFirst = session.playerHP
        try session.useConsumable("consumable_pain_salve")
        #expect(session.playerHP - afterFirst == maxHP * 20 / 100)
    }
}
