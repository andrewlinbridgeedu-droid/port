import Testing
@testable import MistportCombatCore

@Suite("Q19 external recipient cycle")
struct ChapterOneExecutionPairTests {
    private func start() throws -> MPCChapterOneEncounterSession {
        try .start(encounterID: "chapter01_q19_encounter", party: .init(playerHP: 10000, playerMaxHP: 10000), companionIDs: [],
                   loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
    }

    @Test("Q19 has one independent revenant and no retired execution pair")
    func authoredBody() throws {
        let s = try start()
        try #require(s.enemies.count == 1)
        #expect(s.enemies[0].contentID == "enemy_emerald_revenant")
        #expect(s.enemies[0].intentPattern == ["memory_breath", "charge", "emerald_burst", "recover"])
    }

    @Test("Only a positive direct strike consumes a phantom; poison does not")
    func poisonAndDirectBoundary() throws {
        var s = try start()
        let id = try #require(s.enemies.first?.id)
        _ = try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: 0)
        try s.endRound(actingEnemyID: id, at: 0)
        #expect(s.masqueradeCharges == 2)
        try s.endRound(actingEnemyID: id, at: 1)
        #expect(s.masqueradeCharges == 2)
        try s.endRound(actingEnemyID: id, at: 2)
        #expect(s.masqueradeCharges == 1)
    }

    @Test("Recovery resets the accumulating mist instead of escalating forever")
    func recoveryResetsPressure() throws {
        var s = try start()
        let id = try #require(s.enemies.first?.id)
        try s.endRound(actingEnemyID: id, at: 0)
        _ = s.advanceEmeraldPoison(at: 9)
        #expect(s.emeraldPoisonIntensity > 1)
        try s.endRound(actingEnemyID: id, at: 9)
        try s.endRound(actingEnemyID: id, at: 10)
        try s.endRound(actingEnemyID: id, at: 11)
        #expect(s.emeraldPoisonIntensity == 1)
    }

    @Test("Defeating Q19 ends this body and grants its unique evidence")
    func realSettlement() throws {
        var s = try start()
        let id = try #require(s.enemies.first?.id)
        _ = try s.applyPartyDamage(100000, to: id)
        #expect(s.outcome == .victory)
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.completeEncounter(s)
        let expected = try #require(MPCChapterOneThirtyMissionContract.firstClear(for: 19))
        for item in expected.itemIDs { #expect(campaign.inventory[item] == 1) }
        #expect(campaign.completedMissionIDs.contains("chapter01_q19"))
    }
}
