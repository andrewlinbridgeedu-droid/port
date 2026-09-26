import Testing
@testable import MistportCombatCore

@Suite("Chapter thirty authored procurement")
struct ChapterThirtyProcurementTests {
    @Test func exactLegacyIDsPricesAndUnlocks() {
        #expect(MPCAdvancementMaterialMarket.offers.map(\.id) == ["mirrorMothScale", "reverseClockEssence", "ownerlessMaskWax"])
        #expect(MPCAdvancementMaterialMarket.offers.map(\.price) == [260, 340, 480])
        #expect(MPCAdvancementMaterialMarket.offers.map(\.unlockMission) == [17, 20, 23])
        #expect(MPCAdvancementMaterialMarket.offers.reduce(0) { $0 + $1.price } == 1080)
    }
    @Test func EachOfferRequiresActualAuthoredMissionAndEnoughMoney() throws {
        for offer in MPCAdvancementMaterialMarket.offers {
            #expect(MPCAdvancementMaterialMarket.purchase(offer.id, completedMissionNumbers: [offer.unlockMission - 1], coins: 2000, ownedIDs: []) == nil)
            #expect(MPCAdvancementMaterialMarket.purchase(offer.id, completedMissionNumbers: [offer.unlockMission + 1], coins: 2000, ownedIDs: []) == nil)
            #expect(MPCAdvancementMaterialMarket.purchase(offer.id, completedMissionNumbers: [offer.unlockMission], coins: offer.price - 1, ownedIDs: []) == nil)
            let receipt = try #require(MPCAdvancementMaterialMarket.purchase(offer.id, completedMissionNumbers: [offer.unlockMission], coins: offer.price, ownedIDs: []))
            #expect(receipt.coins == 0 && receipt.ownedIDs == [offer.id])
            #expect(MPCAdvancementMaterialMarket.purchase(offer.id, completedMissionNumbers: [offer.unlockMission], coins: 2000, ownedIDs: receipt.ownedIDs) == nil)
        }
    }
    @Test func oldEntitlementsReducePriceWithoutRemovingAnyOwnership() throws {
        let old: Set<String> = ["mirrorMothScale", "reverseClockEssence"]
        #expect(MPCAdvancementMaterialMarket.purchase("mirrorMothScale", completedMissionNumbers: [17], coins: 480, ownedIDs: old) == nil)
        let final = try #require(MPCAdvancementMaterialMarket.purchase("ownerlessMaskWax", completedMissionNumbers: [23], coins: 480, ownedIDs: old))
        #expect(final.coins == 0)
        #expect(final.ownedIDs == Set(MPCAdvancementMaterialMarket.offers.map(\.id)))
        #expect(MPCAdvancementMaterialMarket.purchase("unknown", completedMissionNumbers: Set(1...30), coins: 10000, ownedIDs: []) == nil)
    }
    @Test func q18ActuallyGrantsPaperweightOnceWithoutAutoEquipping() throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        let encounter = try #require(MPCChapterOneCatalog.encounters.first { $0.id == "chapter01_q18_encounter" })
        campaign.claimVictory(for: encounter)
        #expect(campaign.ownedRelicIDs.contains("relic_sealed_paperweight"))
        #expect(!campaign.loadout.relicIDs.contains("relic_sealed_paperweight"))
        let coins = campaign.inventory["currency_copper"], relics = campaign.ownedRelicIDs
        campaign.claimVictory(for: encounter)
        #expect(campaign.ownedRelicIDs == relics && campaign.inventory["currency_copper"] == coins)
    }
    @Test func completedQ18MigrationRestoresOnlyEntitlementNotCurrency() {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        let coins = campaign.inventory["currency_copper"]
        _ = campaign.restoreClaimStoryEvidence(completedMissionNumbers: [18])
        #expect(campaign.ownedRelicIDs.contains("relic_sealed_paperweight"))
        #expect(!campaign.loadout.relicIDs.contains("relic_sealed_paperweight"))
        #expect(campaign.inventory["currency_copper"] == coins)
        let restored = campaign
        _ = campaign.restoreClaimStoryEvidence(completedMissionNumbers: [18])
        #expect(campaign.inventory == restored.inventory && campaign.ownedRelicIDs == restored.ownedRelicIDs)
    }
}
