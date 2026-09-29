import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Workshop: tower materials, basic goods, tiered gear and finite orders")
struct CraftingTests {
    typealias M = MPCTowerMaterials
    let early: Set<Int> = Set(1...5)
    let late: Set<Int> = Set(1...20)

    @Test func everyWinDropsOneMaterialPerBody() {
        #expect(M.drops(floor: 1) == [M.hide: 1])
        #expect(M.drops(floor: 6)[M.gland, default: 0] >= 1)
        #expect(M.drops(floor: 31)[M.chitin, default: 0] >= 1)
        #expect(M.drops(floor: 41)[M.silk, default: 0] >= 1)
        #expect(M.drops(floor: 51)[M.talon, default: 0] >= 1)
        #expect(M.drops(floor: 101).isEmpty)
        for floor in MPCChurchTowerCatalog.floors {
            let bodies = floor.waves.reduce(0) { $0 + $1.count }
            #expect(M.drops(floor: floor.number).values.reduce(0, +) == bodies)
        }
    }

    @Test func workshopOpensAfterQ5() {
        #expect(!MPCCraftingCatalog.isUnlocked(completedMissions: [1, 2, 3, 4]))
        #expect(MPCCraftingCatalog.isUnlocked(completedMissions: early))
        #expect(MPCCraftingCatalog.isUnlocked(completedMissions: [16]))
        #expect(MPCLocalWorkshopLedger.isUnlocked(completedMissions: early))
    }

    @Test func basicCraftIsAtomicAndPaidOnce() throws {
        var ledger = MPCCraftingLedger(), gear = MPCChurchGearLedger()
        var coins = 12, inventory = [M.hide: 1]
        let before = (ledger, coins, inventory)
        #expect(throws: MPCCraftingLedger.Failure.funds) {
            try ledger.craft(receiptID: "a", recipeID: "recipe_repair_strap", day: 3, completedMissions: early,
                             coins: &coins, inventory: &inventory, gear: &gear)
        }
        #expect(ledger == before.0 && coins == before.1 && inventory == before.2)
        coins = 13
        let crafted = try ledger.craft(receiptID: "a", recipeID: "recipe_repair_strap", day: 3, completedMissions: early,
                                       coins: &coins, inventory: &inventory, gear: &gear)
        #expect(crafted)
        #expect(coins == 0 && inventory[M.hide] == 0 && inventory[MPCCraftingCatalog.strapID] == 3)
        #expect(ledger.points(.leather) == 1)
        let again = try ledger.craft(receiptID: "a", recipeID: "recipe_repair_strap", day: 3, completedMissions: early,
                                     coins: &coins, inventory: &inventory, gear: &gear)
        #expect(!again && inventory[MPCCraftingCatalog.strapID] == 3)
        #expect(throws: MPCCraftingLedger.Failure.locked) {
            try ledger.craft(receiptID: "b", recipeID: "recipe_pain_salve", day: 3, completedMissions: [1, 2, 3, 4],
                             coins: &coins, inventory: &inventory, gear: &gear)
        }
    }

    @Test func proficiencyGrowsOnlyFromTheDaysFirstFiveCrafts() throws {
        var ledger = MPCCraftingLedger(), gear = MPCChurchGearLedger()
        var coins = 1_000, inventory = [M.scale: 40]
        for n in 1...7 {
            try ledger.craft(receiptID: "d3-\(n)", recipeID: "recipe_armor_patch", day: 3, completedMissions: early,
                             coins: &coins, inventory: &inventory, gear: &gear)
        }
        #expect(ledger.points(.metal) == 5)
        try ledger.craft(receiptID: "d4-1", recipeID: "recipe_armor_patch", day: 4, completedMissions: early,
                         coins: &coins, inventory: &inventory, gear: &gear)
        #expect(ledger.points(.metal) == 6)
        #expect(inventory[MPCCraftingCatalog.patchID] == 16)
    }

    @Test func gearRecipesFollowTheStoryAndProficiency() throws {
        var ledger = MPCCraftingLedger(), gear = MPCChurchGearLedger()
        var coins = 1_000, inventory = [M.scale: 20, M.membrane: 10, M.hide: 10]
        #expect(throws: MPCCraftingLedger.Failure.locked) {
            try ledger.craft(receiptID: "t30", recipeID: "recipe_craft-t30-blade", day: 9, completedMissions: Set(1...9),
                             coins: &coins, inventory: &inventory, gear: &gear)
        }
        #expect(throws: MPCCraftingLedger.Failure.proficiency) {
            try ledger.craft(receiptID: "t30", recipeID: "recipe_craft-t30-blade", day: 9, completedMissions: late,
                             coins: &coins, inventory: &inventory, gear: &gear)
        }
        try ledger.craft(receiptID: "t10", recipeID: "recipe_craft-t10-blade", day: 5, completedMissions: early,
                         coins: &coins, inventory: &inventory, gear: &gear)
        #expect(gear.ownedIDs.contains("craft-t10-blade") && gear.equippedWeaponID == nil)
        #expect(throws: MPCCraftingLedger.Failure.owned) {
            try ledger.craft(receiptID: "t10-again", recipeID: "recipe_craft-t10-blade", day: 5, completedMissions: early,
                             coins: &coins, inventory: &inventory, gear: &gear)
        }
    }

    @Test func workshopGearIsAnotherBuildNeverALead() throws {
        for tier in MPCChurchGearCatalog.craftTiers {
            for slot in [MPCChurchGearItem.Slot.weapon, .armor] {
                let piece = try #require(MPCChurchGearCatalog.craftedPiece(tier: tier, slot: slot))
                let tower = MPCChurchGearCatalog.bestTowerPiece(slot, atOrBelow: tier)
                #expect(piece.strength == tower.strength - 100, "\(piece.id) vs \(tower.id)")
                #expect(piece.stats != tower.stats)
                #expect(piece.depth == tier && piece.towerFloor == nil)
            }
        }
    }

    @Test func wearingNeedsTheFloorAndCountsForTheTowerCheck() {
        var gear = MPCChurchGearLedger()
        for f in 1...10 { if let drop = MPCChurchGearCatalog.towerDrop(floor: f) { gear.grant(drop.id) } }
        gear.grant("craft-t50-mail")
        #expect(gear.equippedArmorID == "tower-f08-joint-guard")
        let plain = gear.equip("craft-t50-mail")
        let early = gear.equip("craft-t50-mail", highestTowerFloor: 49)
        #expect(!plain && !early)
        #expect(!MPCProgressionWalls.meetsTowerFloor(mission: 18, gear: gear.stats))
        let deepEnough = gear.equip("craft-t50-mail", highestTowerFloor: 50)
        #expect(deepEnough)
        #expect(gear.stats.towerDepth == 50)
        #expect(MPCProgressionWalls.meetsTowerFloor(mission: 18, gear: gear.stats))
        // Tower blade plus workshop mail add up.
        let mail = MPCChurchGearCatalog.item("craft-t50-mail")!.stats
        #expect(gear.stats.attackBP == 3_600 && gear.stats.maxHP == mail.maxHP && gear.stats.damageReductionBP == mail.damageReductionBP)
    }

    @Test func workshopGearWearsBreaksAndIsMended() throws {
        var gear = MPCChurchGearLedger()
        gear.grant("craft-t10-mail")
        let worn = gear.equip("craft-t10-mail", highestTowerFloor: 10)
        let first = gear.wear(battleID: "b1", outcome: .defeat)
        let replay = gear.wear(battleID: "b1", outcome: .defeat)
        #expect(worn && first && !replay)
        #expect(gear.durability("craft-t10-mail") == 95)
        for n in 0..<19 { gear.wear(battleID: "x\(n)", outcome: .defeat) }
        #expect(gear.durability("craft-t10-mail") == 0)
        #expect(gear.stats.maxHP == 0 && gear.stats.towerDepth == 0)
        var inventory: [String: Int] = [:]
        #expect(throws: MPCChurchGearLedger.RepairFailure.noKit) { try gear.repair("craft-t10-mail", inventory: &inventory) }
        inventory[MPCCraftingCatalog.strapID] = 2
        try gear.repair("craft-t10-mail", inventory: &inventory)
        #expect(gear.durability("craft-t10-mail") == 25 && inventory[MPCCraftingCatalog.strapID] == 1)
        #expect(gear.stats.towerDepth == 10)
        #expect(throws: MPCChurchGearLedger.RepairFailure.notCrafted) {
            try gear.repair("tower-f10-anchor-blade", inventory: &inventory)
        }
    }

    @Test func savesFromBeforeWorkshopGearStillLoad() throws {
        let old = #"{"ownedIDs":["tower-f02-jaw-edge"],"equippedWeaponID":"tower-f02-jaw-edge"}"#
        let gear = try JSONDecoder().decode(MPCChurchGearLedger.self, from: Data(old.utf8))
        #expect(gear.equippedWeaponID == "tower-f02-jaw-edge" && gear.craftedDurability.isEmpty)
        #expect(gear.stats.attackBP == 1_500 && gear.stats.towerDepth == 2)
        let round = try JSONDecoder().decode(MPCChurchGearLedger.self, from: JSONEncoder().encode(gear))
        #expect(round == gear)
    }

    @Test func ordersPayFromAFiniteDailyBudget() throws {
        var board = MPCWorkshopOrderBoard()
        var coins = 0, inventory = [MPCCraftingCatalog.salveID: 10, MPCCraftingCatalog.strapID: 30]
        board.open(day: 3)
        #expect(board.budget == 180)
        let salves = try board.sell(receiptID: "s1", itemID: MPCCraftingCatalog.salveID, count: 10, day: 3,
                                    coins: &coins, inventory: &inventory)
        #expect(salves == 7 && coins == 168 && board.budget == 12 && inventory[MPCCraftingCatalog.salveID] == 3)
        let replayed = try board.sell(receiptID: "s1", itemID: MPCCraftingCatalog.salveID, count: 10, day: 3,
                                      coins: &coins, inventory: &inventory)
        #expect(replayed == 7)
        #expect(coins == 168)
        #expect(throws: MPCWorkshopOrderBoard.Failure.budget) {
            try board.sell(receiptID: "s2", itemID: MPCCraftingCatalog.salveID, count: 1, day: 3, coins: &coins, inventory: &inventory)
        }
        #expect(throws: MPCWorkshopOrderBoard.Failure.notBought) {
            try board.sell(receiptID: "x", itemID: M.hide, count: 1, day: 3, coins: &coins, inventory: &inventory)
        }
        // A new day adds 60; ten idle days still carry at most three days' worth.
        let straps = try board.sell(receiptID: "d4", itemID: MPCCraftingCatalog.strapID, count: 30, day: 4,
                                    coins: &coins, inventory: &inventory)
        #expect(straps == 8 && board.budget == 0)
        board.open(day: 14)
        #expect(board.budget == 180 && board.paid == 168 + 72)
    }
}
