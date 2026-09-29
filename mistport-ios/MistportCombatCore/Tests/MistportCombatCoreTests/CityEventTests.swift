import Foundation
import Testing
@testable import MistportCombatCore

@Suite("City events: four local weeks, capped by the calendar")
struct CityEventTests {
    typealias C = MPCCityEventCatalog
    let strap = MPCCraftingCatalog.strapID, salve = MPCCraftingCatalog.salveID

    /// Wins one counted battle on `day` with a real runtime session.
    func win(_ ledger: inout MPCCityEventLedger, _ eventID: String, day: Int, ticket: String, coins: inout Int) throws {
        let encounter = try ledger.beginBattle(ticket: ticket, eventID: eventID, day: day)
        let session = try playStreet(encounter, to: .victory)
        #expect(session.outcome == .victory)
        try ledger.settleBattle(ticket: ticket, session: session, day: day, coins: &coins)
    }

    @Test func fourEventsFillDaysFourToTwentyEight() {
        #expect(C.all.map(\.title) == ["伤患潮", "泵站修复", "港口封锁", "蒸汽工坊奠基"])
        #expect(C.running(day: 3) == nil && C.running(day: 29) == nil)
        for day in 4...28 { #expect(C.running(day: day) != nil, "day \(day)") }
        #expect(C.all.map(\.firstDay) == [4, 11, 18, 25] && C.all.map(\.lastDay) == [10, 17, 24, 28])
        for event in C.all {
            // One win a day is enough; nobody can finish the battles in one day.
            #expect(event.battlesNeeded <= event.lastDay - event.firstDay + 1 && event.battlesNeeded > C.countedWinsPerDay)
            for need in event.deliveries { #expect(need.price < MPCWorkshopOrderBoard.prices[need.itemID]!, "\(event.id) \(need.itemID)") }
            #expect(event.escrow <= 160, "\(event.id) \(event.escrow)")
        }
    }

    @Test func deliveriesTakeOnlyWhatTheEventStillNeeds() throws {
        var ledger = MPCCityEventLedger(), coins = 0, inventory = [strap: 20, salve: 1]
        #expect(throws: MPCCityEventLedger.Failure.notRunning) {
            try ledger.deliver(id: "early", eventID: "casualty-wave", itemID: strap, count: 1, day: 3, coins: &coins, inventory: &inventory)
        }
        let straps = try ledger.deliver(id: "s1", eventID: "casualty-wave", itemID: strap, count: 20, day: 4, coins: &coins, inventory: &inventory)
        #expect(straps == 9 && coins == 45 && inventory[strap] == 11)
        let replay = try ledger.deliver(id: "s1", eventID: "casualty-wave", itemID: strap, count: 20, day: 4, coins: &coins, inventory: &inventory)
        #expect(replay == 9 && coins == 45 && inventory[strap] == 11)
        #expect(throws: MPCCityEventLedger.Failure.notNeeded) {
            try ledger.deliver(id: "s2", eventID: "casualty-wave", itemID: strap, count: 1, day: 4, coins: &coins, inventory: &inventory)
        }
        #expect(throws: MPCCityEventLedger.Failure.notNeeded) {
            try ledger.deliver(id: "p1", eventID: "casualty-wave", itemID: MPCCraftingCatalog.patchID, count: 1, day: 4, coins: &coins, inventory: &inventory)
        }
        #expect(throws: MPCCityEventLedger.Failure.conflict) {
            try ledger.deliver(id: "s1", eventID: "casualty-wave", itemID: salve, count: 1, day: 4, coins: &coins, inventory: &inventory)
        }
        let salves = try ledger.deliver(id: "v1", eventID: "casualty-wave", itemID: salve, count: 4, day: 5, coins: &coins, inventory: &inventory)
        #expect(salves == 1 && coins == 57 && ledger.progress["casualty-wave"]?.paid == 57)
    }

    @Test func onlyTwoWinsADayCount() throws {
        var ledger = MPCCityEventLedger(), coins = 0
        try win(&ledger, "casualty-wave", day: 4, ticket: "t1", coins: &coins)
        // A lost battle closes its ticket and counts nothing.
        let lost = try ledger.beginBattle(ticket: "t2", eventID: "casualty-wave", day: 4)
        #expect(throws: MPCCityEventLedger.Failure.pending) { try ledger.beginBattle(ticket: "t9", eventID: "casualty-wave", day: 4) }
        let defeat = try playStreet(lost, to: .defeat)
        let settled = try ledger.settleBattle(ticket: "t2", session: defeat, day: 4, coins: &coins)
        let again = try ledger.settleBattle(ticket: "t2", session: defeat, day: 4, coins: &coins)
        #expect(settled && !again && defeat.outcome == .defeat)
        try win(&ledger, "casualty-wave", day: 4, ticket: "t3", coins: &coins)
        #expect(throws: MPCCityEventLedger.Failure.dailyLimit) { try ledger.beginBattle(ticket: "t4", eventID: "casualty-wave", day: 4) }
        #expect(throws: MPCCityEventLedger.Failure.conflict) { try ledger.beginBattle(ticket: "t1", eventID: "casualty-wave", day: 5) }
        try win(&ledger, "casualty-wave", day: 5, ticket: "t4", coins: &coins)
        #expect(ledger.progress["casualty-wave"]?.wins == 3 && coins == 3 * C.battlePay)
        // A retreat closes the ticket too.
        _ = try ledger.beginBattle(ticket: "t5", eventID: "casualty-wave", day: 5)
        ledger.abandonBattle(ticket: "t5")
        #expect(ledger.activeTicket == nil && ledger.progress["casualty-wave"]?.wins == 3)
    }

    @Test func settlementRejectsAnotherBattle() throws {
        var ledger = MPCCityEventLedger(), coins = 0
        _ = try ledger.beginBattle(ticket: "t1", eventID: "casualty-wave", day: 4)
        let tower = try playStreet(MPCChurchTowerCatalog.floor(number: 1)!.id, to: .victory)
        #expect(throws: MPCCityEventLedger.Failure.invalidBattle) {
            try ledger.settleBattle(ticket: "t1", session: tower, day: 4, coins: &coins)
        }
        #expect(ledger.activeTicket == "t1" && coins == 0)
    }

    @Test func successChangesTheCityForTheChapter() throws {
        var ledger = MPCCityEventLedger(), coins = 0, inventory = [strap: 9, salve: 4]
        try ledger.deliver(id: "s", eventID: "casualty-wave", itemID: strap, count: 9, day: 4, coins: &coins, inventory: &inventory)
        try ledger.deliver(id: "v", eventID: "casualty-wave", itemID: salve, count: 4, day: 4, coins: &coins, inventory: &inventory)
        var ticket = 0
        for day in 4...6 { for _ in 0..<2 { ticket += 1; try win(&ledger, "casualty-wave", day: day, ticket: "w\(ticket)", coins: &coins) } }
        #expect(ledger.status("casualty-wave", day: 6) == .succeeded && ledger.progress["casualty-wave"]?.completedDay == 6)
        #expect(coins == C.event("casualty-wave")!.escrow)
        #expect(throws: MPCCityEventLedger.Failure.notRunning) { try ledger.beginBattle(ticket: "extra", eventID: "casualty-wave", day: 7) }
        #expect(ledger.effects(day: 5) == .init())
        #expect(ledger.effects(day: 7) == .init(orderBudgetBonus: 10) && ledger.effects(day: 12) == .init(orderBudgetBonus: 10))
        // Later weeks left undone add their own costs on top of the clinic's lasting change.
        #expect(ledger.effects(day: 28) == .init(orderBudgetBonus: 10 - 20))
        #expect(ledger.flags == ["clinic_buys_remedies"])
    }

    @Test func failureCostsOneWeekAndNoGate() {
        let ledger = MPCCityEventLedger()
        #expect(ledger.status("casualty-wave", day: 10) == .running && ledger.status("casualty-wave", day: 11) == .failed)
        #expect(ledger.effects(day: 11) == .init(salveSurcharge: 10))
        #expect(ledger.effects(day: 17) == .init(salveSurcharge: 10))
        #expect(ledger.effects(day: 18) == .init(craftSurcharge: 2))  // the pump station's week, not the clinic's
        #expect(ledger.effects(day: 25) == .init(orderBudgetBonus: -20))
        #expect(ledger.effects(day: 32) == .init() && ledger.flags.isEmpty)
    }

    @Test func cityEffectsReachTheWorkshop() throws {
        var board = MPCWorkshopOrderBoard()
        board.open(day: 1, bonus: 10)
        #expect(board.budget == 70)
        board.open(day: 9, bonus: -20)
        #expect(board.budget == 120)
        var crafting = MPCCraftingLedger(), gear = MPCChurchGearLedger()
        var coins = 13, inventory = [MPCTowerMaterials.hide: 2]
        #expect(throws: MPCCraftingLedger.Failure.funds) {
            try crafting.craft(receiptID: "a", recipeID: "recipe_repair_strap", day: 3, completedMissions: [5], coins: &coins,
                               inventory: &inventory, gear: &gear, surcharge: 2)
        }
        try crafting.craft(receiptID: "b", recipeID: "recipe_repair_strap", day: 3, completedMissions: [5], coins: &coins,
                           inventory: &inventory, gear: &gear, surcharge: -2)
        #expect(coins == 2 && inventory[strap] == 3)
    }

    @Test func eventBattlesUseAuthoredBodiesOnTheShippedPath() throws {
        for event in C.all {
            let id = C.encounterID(eventID: event.id, ticket: "abc-1")
            let encounter = try #require(try expectStreetEncounterShips(id), "\(event.id)")
            #expect(encounter.name == event.battleTitle && encounter.waves.count == event.waves.count)
            let species = encounter.waves.map { $0.enemyIDs.map { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0)!.species } }
            #expect(species == event.waves)
        }
        #expect(MPCChurchMaintenanceCatalog.encounter(id: C.prefix + "casualty-wave_bad id") == nil)
        #expect(MPCChurchMaintenanceCatalog.encounter(id: C.prefix + "no-such-event_abc") == nil)
    }

    @Test func codableRoundTrip() throws {
        var ledger = MPCCityEventLedger(), coins = 0, inventory = [strap: 3]
        try ledger.deliver(id: "s", eventID: "casualty-wave", itemID: strap, count: 3, day: 4, coins: &coins, inventory: &inventory)
        try win(&ledger, "casualty-wave", day: 4, ticket: "w1", coins: &coins)
        let decoded = try JSONDecoder().decode(MPCCityEventLedger.self, from: JSONEncoder().encode(ledger))
        #expect(decoded == ledger)
    }
}
