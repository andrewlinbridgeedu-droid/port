import Testing
@testable import MistportCombatCore

@Suite("Please do not claim story integration")
struct ClaimStoryIntegrationTests {
    @Test func evidenceMigrationOnlyBackfillsEarnedEvidence() {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.inventory["currency_copper"] = 731
        campaign.inventory["consumable_pain_salve"] = 2
        campaign.masqueradeCrackCount = 7
        let first = campaign.restoreClaimStoryEvidence(completedMissionNumbers: [5, 9, 10])
        #expect(first)
        #expect(campaign.inventory["evidence_delivery_stub"] == 1)
        #expect(campaign.inventory["evidence_testimony_versions"] == 1)
        #expect(campaign.inventory["evidence_missing_register"] == 1)
        #expect(campaign.inventory["evidence_family_dossier"] == nil)
        let inventory = campaign.inventory
        let second = campaign.restoreClaimStoryEvidence(completedMissionNumbers: [5, 9, 10])
        #expect(!second)
        #expect(campaign.inventory == inventory)
        #expect(campaign.inventory["currency_copper"] == 731)
        #expect(campaign.inventory["consumable_pain_salve"] == 2)
        #expect(campaign.masqueradeCrackCount == 7)
        #expect(campaign.unlockedSkillIDs.isEmpty)
    }

    @Test func firstClearGrantsEvidenceWithoutMakingItConsumable() throws {
        for q in [5, 9, 10, 11, 12, 14, 15] {
            let mission = try #require(MPCChapterOneCatalog.mission(forOldClockMissionNumber: q))
            let encounter = try #require(MPCChapterOneCatalog.encounters.first { $0.id == mission.encounterID })
            var campaign = MPCChapterOneCampaignState.chapterStartState
            campaign.claimVictory(for: encounter)
            let ids = mission.rewardItemIDs.filter { $0.hasPrefix("evidence_") }
            #expect(ids.count == 1)
            for id in ids {
                let item = try #require(MPCChapterOneCatalog.items.first { $0.id == id })
                #expect(item.kind == .keyItem)
                #expect(campaign.inventory[id] == 1)
            }
            campaign.claimVictory(for: encounter)
            for id in ids { #expect(campaign.inventory[id] == 1) }
        }
    }

    @Test func namedSurvivorsDoNotChangeCoreOrOtherActorsDeath() {
        #expect(MPCChapterOneBattleIdentity.defeatPresentation(contentID: "elite_clock_chaser", encounterID: "chapter01_q13_encounter") == "subdued")
        #expect(MPCChapterOneBattleIdentity.defeatPresentation(contentID: "enemy_hollow_clockmaker", encounterID: "chapter01_q15_encounter") == "subdued")
        #expect(MPCChapterOneBattleIdentity.defeatPresentation(contentID: "enemy_memory_leech_node", encounterID: "chapter01_q13_encounter") == "hidden")
        #expect(MPCChapterOneBattleIdentity.defeatPresentation(contentID: "enemy_memory_leech_node", encounterID: "chapter01_q15_encounter") == "hidden")
        #expect(MPCChapterOneBattleIdentity.defeatPresentation(contentID: "enemy_clockwork_hound", encounterID: "chapter01_q04_encounter") == "retreat")
        #expect(MPCChapterOneBattleIdentity.defeatPresentation(contentID: "enemy_clockwork_hound", encounterID: "chapter01_q16_encounter") == "hidden")
    }
}
