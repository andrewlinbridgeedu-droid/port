import Testing
@testable import MistportCombatCore

@Suite("Formal Q5 Encore Bell", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
struct EncoreBellFormalTests {
    private func session(relics: [String] = ["relic_encore_bell"]) throws -> MPCChapterOneEncounterSession {
        try .start(encounterID: "chapter01_q05_encounter", companionIDs: [],
                   loadout: .init(normalSkillIDs: [.maskedWhisper], passiveIDs: [], relicIDs: relics))
    }

    @Test func handoffAndMigrationPreserveProgressWithoutEquipping() {
        var fresh = MPCChapterOneCampaignState.chapterStartState
        let mutationResult1 = fresh.acceptEncoreBellDelivery()
        #expect(mutationResult1)
        let mutationResult2 = fresh.acceptEncoreBellDelivery()
        #expect(!mutationResult2)
        #expect(fresh.loadout.relicIDs.isEmpty)
        var legacy = MPCChapterOneCampaignState(
            currentMissionID: "chapter01_q06", completedMissionIDs: ["chapter01_q05"],
            completedEncounterIDs: ["chapter01_q05_encounter"], inventory: ["currency_copper": 123],
            ownedRelicIDs: ["relic_paper_raincoat"], depletedRelicIDs: ["relic_paper_raincoat"],
            loadout: .init(relicIDs: ["relic_paper_raincoat"]))
        let mutationResult3 = legacy.migrateLegacyPaperRelicToEncoreBell()
        #expect(mutationResult3)
        let migrated = legacy
        let mutationResult4 = legacy.migrateLegacyPaperRelicToEncoreBell()
        #expect(!mutationResult4)
        #expect(legacy == migrated)
        #expect(legacy.ownedRelicIDs == ["relic_encore_bell"])
        #expect(legacy.loadout.relicIDs.isEmpty)
        #expect(legacy.depletedRelicIDs.isEmpty)
        #expect(legacy.completedMissionIDs == ["chapter01_q05"])
        #expect(legacy.completedEncounterIDs == ["chapter01_q05_encounter"])
        #expect(legacy.inventory == ["currency_copper": 123])
        #expect(legacy.currentMissionID == "chapter01_q06")
        var untouched = MPCChapterOneCampaignState.chapterStartState
        let mutationResult5 = untouched.migrateLegacyPaperRelicToEncoreBell()
        #expect(mutationResult5)
        #expect(untouched.ownedRelicIDs.isEmpty)
    }

    @Test func q5FirstClearAndReplayDoNotRegrantUniqueRelic() throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.acceptEncoreBellDelivery()
        let q5 = try #require(MPCChapterOneCatalog.encounters.first { $0.id == "chapter01_q05_encounter" })
        campaign.claimVictory(for: q5)
        let firstInventory = campaign.inventory
        campaign.claimVictory(for: q5)
        #expect(campaign.ownedRelicIDs == ["relic_encore_bell"])
        #expect(campaign.loadout.relicIDs.isEmpty)
        #expect(campaign.inventory["item_sealed_transfer"] == firstInventory["item_sealed_transfer"])
        #expect(campaign.completedEncounterIDs == [q5.id])
    }

    @Test func equippedOnlyAndFormalMaskUnchanged() throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.acceptEncoreBellDelivery()
        var unequipped = try session(relics: campaign.effectiveLoadout.relicIDs)
        #expect(unequipped.isEncoreEncounter)
        #expect(!unequipped.canUseEncoreBell)
        let mutationResult6 = unequipped.markEncoreDebt(enemyID: unequipped.enemies[0].id)
        #expect(!mutationResult6)
        campaign.loadout.relicIDs = ["relic_encore_bell"]
        var equipped = try session(relics: campaign.effectiveLoadout.relicIDs)
        #expect(equipped.canUseEncoreBell)
        let mutationResult7 = equipped.activateTimedMasquerade(at: 0)
        #expect(!mutationResult7)
        _ = try equipped.useFoolSkill(.maskedWhisper, targetID: equipped.enemies[0].id, usesRealtimeCooldown: true)
        #expect(equipped.masqueradeCharges > 0)
        #expect(equipped.timedMasqueradeExpiresAt == nil)
        #expect(!equipped.q5PaperRelicReady)
        let stale = try session(relics: ["relic_paper_raincoat"])
        #expect(!stale.q5PaperRelicReady)
        #expect(stale.loadout.relicIDs.isEmpty)
        campaign.ownedRelicIDs.removeAll()
        #expect(campaign.effectiveLoadout.relicIDs.isEmpty)
    }

    @Test func debtAppliesOnceAndRetryResets() throws {
        var amplified = try session()
        var ordinary = try session()
        let id = amplified.enemies[0].id
        let mutationResult8 = amplified.markEncoreDebt(enemyID: id)
        #expect(mutationResult8)
        #expect(!amplified.canUseEncoreBell)
        try amplified.endRound()
        try ordinary.endRound()
        #expect(amplified.pendingEncoreDebtEnemyID == id)
        try amplified.endRound()
        try ordinary.endRound()
        amplified.advanceEmeraldPoison(at: 9)
        ordinary.advanceEmeraldPoison(at: 9)
        let ordinaryDamage = ordinary.playerMaxHP - ordinary.playerHP
        #expect(ordinaryDamage == 198)
        #expect(amplified.playerMaxHP - amplified.playerHP == ordinaryDamage * 150 / 100)
        #expect(amplified.pendingEncoreDebtEnemyID == nil)
        let beforeA = amplified.playerHP
        let beforeO = ordinary.playerHP
        try amplified.endRound()
        try ordinary.endRound()
        let mutationResult9 = amplified.markEncoreDebt(enemyID: id)
        #expect(!mutationResult9)
        try amplified.endRound()
        try ordinary.endRound()
        #expect(beforeA - amplified.playerHP == beforeO - ordinary.playerHP)
        let retry = try session()
        #expect(retry.canUseEncoreBell)
        #expect(retry.pendingEncoreDebtEnemyID == nil)
    }

    @Test func earnedEquippedBellWorksOnEarlierStageReplay() throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.acceptEncoreBellDelivery()
        campaign.loadout.relicIDs = ["relic_encore_bell"]
        var replay = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q04_encounter", companionIDs: [], loadout: campaign.effectiveLoadout)
        #expect(replay.canUseEncoreBell)
        let marked = replay.markEncoreDebt(enemyID: replay.enemies[0].id)
        #expect(marked)
        #expect(replay.pendingEncoreDebtEnemyID == replay.enemies[0].id)

        var fresh = MPCChapterOneCampaignState.chapterStartState
        fresh.loadout.relicIDs = ["relic_encore_bell"]
        let unowned = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q04_encounter", companionIDs: [], loadout: fresh.effectiveLoadout)
        #expect(!unowned.canUseEncoreBell)
        #expect(unowned.loadout.relicIDs.isEmpty)
    }

    @Test func casterDeathCancelsDebt() throws {
        var battle = try session()
        let id = battle.enemies[0].id
        let mutationResult10 = battle.markEncoreDebt(enemyID: id)
        #expect(mutationResult10)
        _ = try battle.applyPartyDamage(100_000, to: id, category: .damage)
        #expect(battle.pendingEncoreDebtEnemyID == nil)
        #expect(!battle.canUseEncoreBell)
    }
}
