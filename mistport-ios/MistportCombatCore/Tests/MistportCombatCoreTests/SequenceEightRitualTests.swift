import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Sequence 8 ritual: qualification only, spent once")
struct SequenceEightRitualTests {
    let story = Set(1...30)
    let proofs = Dictionary(uniqueKeysWithValues: MPCSequenceEightRitual.proofIDs.map { ($0, 1) })
    let materials = Set(MPCSequenceEightRitual.ingredientIDs)

    @Test func beforeBlackSaltShoreNothingIsSpent() {
        var coins = 1000, ingredients = materials
        #expect(throws: MPCSequenceEightRitual.Failure.locked) {
            try MPCSequenceEightRitual.perform(id: "a", completedMissions: Set(1...29), coins: &coins,
                                               ingredients: &ingredients, inventory: proofs, existing: nil)
        }
        #expect(coins == 1000 && ingredients == materials)
    }

    @Test(arguments: ["material", "proof", "copper"])
    func anyShortfallSpendsNothing(missing: String) {
        var coins = missing == "copper" ? 279 : 1000
        var ingredients = missing == "material" ? materials.subtracting(["ownerlessMaskWax"]) : materials
        let before = (coins, ingredients)
        var inventory = proofs
        if missing == "proof" { inventory["chapter30_p05_paradox_proof"] = 0 }
        let expected: MPCSequenceEightRitual.Failure = missing == "material" ? .materials : missing == "proof" ? .proofs : .funds
        #expect(throws: expected) {
            try MPCSequenceEightRitual.perform(id: "a", completedMissions: story, coins: &coins,
                                               ingredients: &ingredients, inventory: inventory, existing: nil)
        }
        #expect(coins == before.0 && ingredients == before.1)
    }

    @Test func ritualSpendsOnceAndKeepsProofs() throws {
        var coins = 1000, ingredients = materials.union(["unrelated_material"])
        let receipt = try MPCSequenceEightRitual.perform(id: "ritual", completedMissions: story, coins: &coins,
                                                         ingredients: &ingredients, inventory: proofs, existing: nil)
        #expect(coins == 720 && ingredients == ["unrelated_material"])
        #expect(receipt.fee == 280 && receipt.coinsBefore == 1000 && receipt.coinsAfter == 720)
        #expect(Set(receipt.consumedIngredientIDs) == materials && receipt.verifiedProofIDs == MPCSequenceEightRitual.proofIDs)
        #expect(throws: MPCSequenceEightRitual.Failure.completed) {
            try MPCSequenceEightRitual.perform(id: "again", completedMissions: story, coins: &coins,
                                               ingredients: &ingredients, inventory: proofs, existing: receipt)
        }
        #expect(coins == 720)
        let decoded = try JSONDecoder().decode(MPCSequenceEightRitual.Receipt.self, from: JSONEncoder().encode(receipt))
        #expect(decoded == receipt)
    }
}
