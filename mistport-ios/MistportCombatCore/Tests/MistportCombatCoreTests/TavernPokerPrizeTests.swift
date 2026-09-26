import Testing
@testable import MistportCombatCore

@Suite("Tavern featured stakes")
struct TavernPokerPrizeTests {
    @Test func stableOfferAndNoEarlyUnlock() {
        #expect(MPCTavernPrizeRotation.offer(dayOrdinal: 20260925, completedMissions: [],
            ownedRelicIDs: [], ownedMaterialIDs: []) == nil)
        let first = MPCTavernPrizeRotation.offer(dayOrdinal: 20260925, completedMissions: [9],
            ownedRelicIDs: [], ownedMaterialIDs: [])
        #expect(first?.itemID == "relic_deferred_stamp")
        #expect(first == MPCTavernPrizeRotation.offer(dayOrdinal: 20260925, completedMissions: [9],
            ownedRelicIDs: [], ownedMaterialIDs: []))
        #expect(MPCTavernPrizeRotation.offer(dayOrdinal: 20260925, completedMissions: [9],
            ownedRelicIDs: ["relic_deferred_stamp"], ownedMaterialIDs: []) == nil)
    }

    @Test func materialRequiresMissionAndNeverDuplicates() {
        let offer = MPCTavernPrizeRotation.offer(dayOrdinal: 20260925, completedMissions: [17],
            ownedRelicIDs: Set(MPCChurchLoanOffer.all.map(\.relicID)), ownedMaterialIDs: [])
        #expect(offer?.itemID == "mirrorMothScale")
        #expect(offer?.kind == .advancementMaterial)
        #expect(MPCTavernPrizeRotation.offer(dayOrdinal: 20260925, completedMissions: [17],
            ownedRelicIDs: Set(MPCChurchLoanOffer.all.map(\.relicID)),
            ownedMaterialIDs: ["mirrorMothScale"]) == nil)
        #expect(MPCTavernPrizeRotation.offer(dayOrdinal: 20260926, completedMissions: [17],
            ownedRelicIDs: [], ownedMaterialIDs: []) == nil)
    }
}
