import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Owned ordinary relic wear never changes ownership")
struct ChurchOwnedRelicLedgerTests {
    let salt = "relic_salt_sealed_breathing_bag"
    let card = "relic_blank_name_card"
    @Test func legacyDefaultsAndActualSlotsExcludeBorrowedAndBoundRelics() throws {
        var ledger = MPCChurchOwnedRelicLedger()
        let owned: Set<String> = [salt,card,MPCChapterOneCatalog.ownerlessMaskRelicID,MPCChapterOneCatalog.usurpedLifeMedalRelicID]
        #expect(ledger.currentDurability(salt) == 100 && ledger.canUse(salt,ownedRelicIDs:owned))
        _ = try ledger.beginBattle(battleID:"one",equippedRelicIDs:Array(owned),ownedRelicIDs:owned,borrowedRelicIDs:[salt])
        _ = try ledger.settleBattle(battleID:"one",outcome:.defeat)
        #expect(ledger.currentDurability(card) == 95)
        #expect(ledger.durability[salt] == nil)
        #expect(ledger.durability[MPCChapterOneCatalog.ownerlessMaskRelicID] == nil)
        #expect(ledger.durability[MPCChapterOneCatalog.usurpedLifeMedalRelicID] == nil)
        #expect(owned.count == 4)
    }
    @Test func pendingSurvivesReloadAndCannotRefreshOrRepairMidBattle() throws {
        var ledger = MPCChurchOwnedRelicLedger()
        _ = try ledger.beginBattle(battleID:"running",equippedRelicIDs:[salt],ownedRelicIDs:[salt])
        ledger = try JSONDecoder().decode(MPCChurchOwnedRelicLedger.self,from:JSONEncoder().encode(ledger))
        let repeated = try ledger.beginBattle(battleID:"running",equippedRelicIDs:[salt],ownedRelicIDs:[salt])
        #expect(!repeated)
        #expect(throws:MPCChurchOwnedRelicError.battlePending) { try ledger.beginBattle(battleID:"new",equippedRelicIDs:[salt],ownedRelicIDs:[salt]) }
        #expect(throws:MPCChurchOwnedRelicError.battlePending) { try ledger.repair(salt,ownedRelicIDs:[salt],availableCoins:1000) }
        _ = try ledger.settleBattle(battleID:"running",outcome:.retreat)
        let second = try ledger.settleBattle(battleID:"running",outcome:.victory)
        #expect(!second && ledger.currentDurability(salt) == 97)
        #expect(throws:MPCChurchOwnedRelicError.invalidBattle) { try ledger.beginBattle(battleID:"running",equippedRelicIDs:[salt],ownedRelicIDs:[salt]) }
    }
    @Test func allOutcomesWearExactlyOnceAndZeroCannotUse() throws {
        var ledger = MPCChurchOwnedRelicLedger()
        for (i,result) in [MPCChurchBattleOutcome.victory,.defeat,.retreat].enumerated() {
            _ = try ledger.beginBattle(battleID:"test\(i)",equippedRelicIDs:[salt],ownedRelicIDs:[salt])
            _ = try ledger.settleBattle(battleID:"test\(i)",outcome:result)
        }
        #expect(ledger.currentDurability(salt) == 90)
        for i in 0..<18 {
            _ = try ledger.beginBattle(battleID:"wear\(i)",equippedRelicIDs:[salt],ownedRelicIDs:[salt])
            _ = try ledger.settleBattle(battleID:"wear\(i)",outcome:.defeat)
        }
        #expect(ledger.currentDurability(salt) == 0 && !ledger.canUse(salt,ownedRelicIDs:[salt]))
        #expect(throws:MPCChurchOwnedRelicError.exhausted) { try ledger.beginBattle(battleID:"spent",equippedRelicIDs:[salt],ownedRelicIDs:[salt]) }
        let receipt = try ledger.repair(salt,ownedRelicIDs:[salt],availableCoins:60)
        #expect(receipt.copperCost == 60 && receipt.restoredDurability == 100)
        #expect(ledger.canUse(salt,ownedRelicIDs:[salt]))
        let repeated = try ledger.repair(salt,ownedRelicIDs:[salt],availableCoins:0)
        #expect(repeated.copperCost == 0 && repeated.restoredDurability == 0)
    }
    @Test func rejectedMutationIsAtomicAndOwnershipRequired() throws {
        var ledger = MPCChurchOwnedRelicLedger()
        let before = ledger
        #expect(throws:MPCChurchOwnedRelicError.notOwned) { try ledger.beginBattle(battleID:"invalid",equippedRelicIDs:[salt,card],ownedRelicIDs:[salt]) }
        #expect(ledger == before)
        #expect(throws:MPCChurchOwnedRelicError.notOwned) { try ledger.repair(salt,ownedRelicIDs:[],availableCoins:1000) }
        #expect(throws:MPCChurchOwnedRelicError.unavailable) { try ledger.repair(MPCChapterOneCatalog.ownerlessMaskRelicID,ownedRelicIDs:[MPCChapterOneCatalog.ownerlessMaskRelicID],availableCoins:1000) }
        _ = try ledger.beginBattle(battleID:"damage",equippedRelicIDs:[card],ownedRelicIDs:[card])
        _ = try ledger.settleBattle(battleID:"damage",outcome:.victory)
        #expect(try ledger.repairCost(card,ownedRelicIDs:[card]) == 7)
        let damaged = ledger
        #expect(throws:MPCChurchOwnedRelicError.insufficientFunds) { try ledger.repair(card,ownedRelicIDs:[card],availableCoins:6) }
        #expect(ledger == damaged)
    }
    @Test func lostOrdinaryCopyCanBeReplacedAtFullCondition() throws {
        var ledger = MPCChurchOwnedRelicLedger()
        _ = try ledger.beginBattle(battleID: "loss", equippedRelicIDs: [salt], ownedRelicIDs: [salt])
        ledger.retireLostCopy(salt)
        #expect(ledger.currentDurability(salt) == 100)
        _ = try ledger.settleBattle(battleID: "loss", outcome: .defeat)
        #expect(ledger.currentDurability(salt) == 95)
        ledger.retireLostCopy(salt)
        #expect(ledger.currentDurability(salt) == 100)
    }
}
