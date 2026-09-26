import Testing
@testable import MistportCombatCore

@Suite("Q1–Q10 earned campaign and purchased relics")
struct FirstEightProgressionTests {
    @Test func continuousEarnedCampaign() throws {
        let campaign = try EarnedChapterAuditFixture.run(through: 10)
        #expect(campaign.completedEncounterIDs.count == 10)
        #expect(campaign.ownedRelicIDs.contains(MPCChapterOneCatalog.usurpedLifeMedalRelicID))
        #expect(campaign.inventory["item_blank_identity"] == 1)
        #expect(campaign.loadoutSlotCapacity == 4)
    }
}
