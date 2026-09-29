import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Local workshop: real inventory and finite order")
struct LocalWorkshopTests {
    let missions: Set<Int> = [16]
    func funded() throws -> MPCLocalWorkshopLedger {
        var ledger = MPCLocalWorkshopLedger()
        try ledger.learnBasics(completedMissions: missions)
        return ledger
    }
    @Test func noFixtureWealthOrMaterialAndLockedRecipe() throws {
        var ledger = MPCLocalWorkshopLedger(), coins = 0
        var inventory: [String: Int] = [:]
        #expect(!ledger.learnedBasics && ledger.proficiency == 0)
        #expect(ledger.procurementCopper == 18 && ledger.order == .offered)
        #expect(throws: MPCLocalWorkshopLedger.Failure.locked) { try ledger.learnBasics(completedMissions: [15]) }
        #expect(throws: MPCLocalWorkshopLedger.Failure.locked) {
            try ledger.craft(id: "a", completedMissions: missions, coins: &coins, inventory: &inventory)
        }
        #expect(coins == 0 && inventory.isEmpty)
    }
    @Test func finiteSaleInstallAndReloadAreConserved() throws {
        var ledger = try funded(), coins = 71
        var inventory = [MPCLocalWorkshopLedger.hideID: 1, "consumable_pain_salve": 2, "evidence_existing": 1]
        _ = try ledger.craft(id: "batch", completedMissions: missions, coins: &coins, inventory: &inventory)
        #expect(coins == 58 && inventory[MPCLocalWorkshopLedger.strapID] == 3 && ledger.proficiency == 1)
        _ = try ledger.deliver(id: "sale", completedMissions: missions, coins: &coins, inventory: &inventory)
        #expect(coins == 76 && ledger.procurementCopper == 0 && ledger.projectStraps == 2)
        #expect(inventory[MPCLocalWorkshopLedger.strapID] == 1)
        ledger = try JSONDecoder().decode(MPCLocalWorkshopLedger.self, from: JSONEncoder().encode(ledger))
        let replay = try ledger.deliver(id: "sale", completedMissions: missions, coins: &coins, inventory: &inventory)
        #expect(!replay && coins == 76)
        #expect(throws: MPCLocalWorkshopLedger.Failure.exhausted) {
            try ledger.deliver(id: "another-sale", completedMissions: missions, coins: &coins, inventory: &inventory)
        }
        _ = try ledger.install(id: "fit", completedMissions: missions)
        #expect(ledger.order == .installed && ledger.projectStraps == 0)
        #expect(coins + ledger.procurementCopper + ledger.externalPayments == 71 + 18)
        #expect(inventory["consumable_pain_salve"] == 2 && inventory["evidence_existing"] == 1)
        let installReplay = try ledger.install(id: "fit", completedMissions: missions)
        #expect(!installReplay)
    }
    @Test(arguments: [0, 12]) func insufficientFundsCannotConsumeMaterials(coins initial: Int) throws {
        var ledger = try funded(), coins = initial
        var inventory = [MPCLocalWorkshopLedger.hideID: 1]
        let before = ledger
        #expect(throws: MPCLocalWorkshopLedger.Failure.funds) {
            try ledger.craft(id: "batch", completedMissions: missions, coins: &coins, inventory: &inventory)
        }
        #expect(coins == initial && inventory[MPCLocalWorkshopLedger.hideID] == 1 && ledger == before)
    }
    @Test func staleCommandConflictCannotChangeOtherInventory() throws {
        var ledger = try funded(), coins = 26
        var inventory = [MPCLocalWorkshopLedger.hideID: 2]
        _ = try ledger.craft(id: "same", completedMissions: missions, coins: &coins, inventory: &inventory)
        let repeatCraft = try ledger.craft(id: "same", completedMissions: missions, coins: &coins, inventory: &inventory)
        #expect(!repeatCraft && coins == 13 && ledger.proficiency == 1)
        #expect(throws: MPCLocalWorkshopLedger.Failure.conflict) {
            try ledger.deliver(id: "same", completedMissions: missions, coins: &coins, inventory: &inventory)
        }
        #expect(ledger.order == .offered && inventory[MPCLocalWorkshopLedger.strapID] == 3)
    }
    @Test func realTowerVictoryMustMatchIssuedTicket() throws {
        var ledger = MPCLocalWorkshopLedger(), inventory: [String: Int] = [:]
        let win = try MPCChurchTowerVerificationRunner.run(number: 1).session
        try #require(win.outcome == .victory)
        #expect(throws: MPCLocalWorkshopLedger.Failure.locked) {
            try ledger.claimTower(id: "missing", floor: 1, session: win, inventory: &inventory)
        }
        try ledger.beginTower(id: "before16", floor: 1, completedMissions: [15])
        #expect(ledger.towerTickets.isEmpty)
        try ledger.beginTower(id: "a", floor: 1, completedMissions: missions)
        #expect(throws: MPCLocalWorkshopLedger.Failure.locked) {
            try ledger.claimTower(id: "a", floor: 2, session: win, inventory: &inventory)
        }
        ledger.abandonTower(id: "a")
        #expect(throws: MPCLocalWorkshopLedger.Failure.locked) {
            try ledger.claimTower(id: "a", floor: 1, session: win, inventory: &inventory)
        }
        try ledger.beginTower(id: "b", floor: 1, completedMissions: missions)
        _ = try ledger.claimTower(id: "b", floor: 1, session: win, inventory: &inventory)
        ledger = try JSONDecoder().decode(MPCLocalWorkshopLedger.self, from: JSONEncoder().encode(ledger))
        let repeatClaim = try ledger.claimTower(id: "b", floor: 1, session: win, inventory: &inventory)
        #expect(!repeatClaim && inventory[MPCLocalWorkshopLedger.hideID] == 1)
        #expect(throws: MPCLocalWorkshopLedger.Failure.conflict) {
            try ledger.beginTower(id: "b", floor: 1, completedMissions: missions)
        }
    }
}
