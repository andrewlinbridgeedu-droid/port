import Foundation
import Testing
@testable import MistportCombatCore

struct NeighborReplayTests {
    @Test func bakerReplayKeepsTheOriginalPayoutAndOtherOffers() throws {
        var ledger = MPCNeighborLedger()
        ledger.open(day: 3, completedMissions: Set(1...5))
        let baker = try #require(ledger.offers.first { $0.neighborID == "baker" })
        var coins = 100, inventory = [MPCCraftingCatalog.salveID: 2]
        let first = try ledger.deliver(offerID: baker.id, coins: &coins, inventory: &inventory)
        let paidCoins = coins, paidAffinity = ledger.affinity, paidCount = ledger.completedErrands
        let otherOffers = ledger.offers.filter { $0.id != baker.id }
        #expect(first.copper > 0)
        #expect(try ledger.reopenCompletedOfferForReplay(baker.id))
        #expect(!ledger.offers.first { $0.id == baker.id }!.done)
        #expect(ledger.offers.filter { $0.id != baker.id } == otherOffers)
        #expect(coins == paidCoins && ledger.affinity == paidAffinity && ledger.completedErrands == paidCount)
        ledger = try JSONDecoder().decode(MPCNeighborLedger.self, from: JSONEncoder().encode(ledger))
        let replay = try ledger.deliver(offerID: baker.id, coins: &coins, inventory: &inventory)
        #expect(replay.copper == 0 && replay.story == nil)
        #expect(coins == paidCoins && ledger.affinity == paidAffinity && ledger.completedErrands == paidCount)
        #expect(inventory[MPCCraftingCatalog.salveID] == 0)
        #expect(try !ledger.reopenCompletedOfferForReplay(baker.id))
        #expect(throws: MPCNeighborLedger.Failure.done) {
            try ledger.deliver(offerID: baker.id, coins: &coins, inventory: &inventory)
        }
    }

    @Test func legacyCompletedOfferCanBeRetriedButAnUnpaidOneCannotBeReset() throws {
        var ledger = MPCNeighborLedger()
        ledger.open(day: 3, completedMissions: Set(1...5))
        let baker = try #require(ledger.offers.first { $0.neighborID == "baker" })
        #expect(try !ledger.reopenCompletedOfferForReplay(baker.id))
        var coins = 0, inventory = [MPCCraftingCatalog.salveID: 1]
        _ = try ledger.deliver(offerID: baker.id, coins: &coins, inventory: &inventory)
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
        var offers = try #require(legacy["offers"] as? [[String: Any]])
        for i in offers.indices { offers[i].removeValue(forKey: "replayWithoutReward") }
        legacy["offers"] = offers
        ledger = try JSONDecoder().decode(MPCNeighborLedger.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(try ledger.reopenCompletedOfferForReplay(baker.id))
    }
}
