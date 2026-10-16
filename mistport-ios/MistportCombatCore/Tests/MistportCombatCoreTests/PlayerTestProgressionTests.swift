import Testing
@testable import MistportCombatCore

@Suite("Q1–Q15 earned campaign reward and unlock ledger")
struct PlayerTestProgressionTests {
    @Test func continuousEarnedCampaign() async throws {
        let campaign = try await EarnedChapterAuditFixture.run(through: 15)
        #expect(campaign.completedEncounterIDs.count == 15)
        #expect(campaign.ownedRelicIDs.contains(MPCChapterOneCatalog.usurpedLifeMedalRelicID))
        #expect(campaign.inventory["item_blank_identity"] == 1)
        #expect(campaign.loadoutSlotCapacity == 4)
        #expect(campaign.unlockedSkillIDs.contains(.namelessStage))
    }
}
