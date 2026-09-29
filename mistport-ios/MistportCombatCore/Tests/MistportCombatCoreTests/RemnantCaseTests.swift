import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Nameless remnants: one small case a day after a bounty closes")
struct RemnantCaseTests {
    typealias R = MPCRemnantCatalog

    @Test func everyBountyCaseHasTwoFairLeads() {
        #expect(R.all.map(\.id) == MPCChurchBountyCatalog.all.map(\.id))
        var correctSlots = Set<String>()
        for remnant in R.all {
            #expect(remnant.leads.count == 2 && !remnant.area.isEmpty && remnant.title.hasPrefix("无名残余 · "))
            for lead in remnant.leads {
                #expect(lead.choices.count == 3 && Set(lead.choices.map(\.id)).count == 3)
                #expect(lead.choices.contains { $0.id == lead.correctChoiceID })
                #expect(lead.choices.allSatisfy { !$0.text.isEmpty && !$0.explanation.isEmpty })
                correctSlots.insert(lead.correctChoiceID)
            }
            #expect([10, 30, 50, 70, 90].contains(remnant.maxFloor))
        }
        #expect(correctSlots == ["a", "b", "c"])
    }

    @Test func oneCaseADayRotatesOverClosedCases() throws {
        #expect(R.today(day: 5, closedCaseIDs: []) == nil)
        let closed: Set<String> = ["b07", "b01"]
        let days = (1...4).compactMap { R.today(day: $0, closedCaseIDs: closed) }.map { "\($0.remnant.id):\($0.lead)" }
        #expect(days == ["b07:0", "b01:1", "b07:1", "b01:0"])
        var ledger = MPCRemnantLedger()
        #expect(throws: MPCRemnantLedger.Failure.noCase) { try ledger.accept(day: 1, closedCaseIDs: [], highestTowerFloor: 4) }
        let first = try ledger.accept(day: 1, closedCaseIDs: closed, highestTowerFloor: 4)
        let again = try ledger.accept(day: 1, closedCaseIDs: ["b09"], highestTowerFloor: 90)
        #expect(first == again && first.caseID == "b07" && first.band == 10)
    }

    @Test func bandFollowsTheCaseAndTheClearedFloors() {
        let b09 = R.remnant("b09")!
        #expect(R.band(b09, highestTowerFloor: 3) == 10)
        #expect(R.band(b09, highestTowerFloor: 23) == 20)
        #expect(R.band(b09, highestTowerFloor: 95) == 70)
    }

    @Test func aFinishedCasePaysOnceThroughTheTaper() throws {
        var ledger = MPCRemnantLedger(), work = MPCDailyWorkLedger(), coins = 0, inventory: [String: Int] = [:]
        let job = try ledger.accept(day: 2, closedCaseIDs: ["b09"], highestTowerFloor: 40)
        let lead = job.remnant!.leads[job.lead]
        #expect(throws: MPCRemnantLedger.Failure.unsolved) { try ledger.beginBattle(day: 2, ticket: "t1") }
        let wrong = lead.choices.first { $0.id != lead.correctChoiceID }!.id
        let missed = try ledger.answer(day: 2, choiceID: wrong)
        #expect(!missed && ledger.job(day: 2)!.excludedChoiceIDs == [wrong])
        #expect(throws: MPCRemnantLedger.Failure.invalidChoice) { try ledger.answer(day: 2, choiceID: wrong) }
        let solved = try ledger.answer(day: 2, choiceID: lead.correctChoiceID)
        #expect(solved)
        #expect(throws: MPCRemnantLedger.Failure.unsolved) {
            try ledger.claim(day: 2, today: 2, work: &work, coins: &coins, inventory: &inventory)
        }
        // A loss leaves the case open; a new ticket tries again.
        let lostID = try ledger.beginBattle(day: 2, ticket: "t1")
        let lost = try playStreet(lostID, to: .defeat)
        try ledger.settleBattle(day: 2, ticket: "t1", session: lost)
        let wonID = try ledger.beginBattle(day: 2, ticket: "t2")
        #expect(wonID == R.encounterID(caseID: "b09", band: 40, ticket: "t2"))
        let won = try playStreet(wonID, to: .victory)
        let settled = try ledger.settleBattle(day: 2, ticket: "t2", session: won)
        let replayed = try ledger.settleBattle(day: 2, ticket: "t2", session: won)
        #expect(settled && !replayed)
        // Three jobs already done today: the remnant is the fourth and pays half.
        for n in 1...3 { work.settle(receiptID: "postal-\(n)", day: 3, copper: 40, merit: 0) }
        let payout = try ledger.claim(day: 2, today: 3, work: &work, coins: &coins, inventory: &inventory)
        #expect(payout == .init(copper: 15, merit: 0, percent: 50))
        #expect(coins == 15 && inventory[MPCTowerMaterials.scale] == 2)
        let twice = try ledger.claim(day: 2, today: 3, work: &work, coins: &coins, inventory: &inventory)
        #expect(twice == nil && coins == 15 && inventory[MPCTowerMaterials.scale] == 2)
    }

    @Test func untakenDaysDoNotBankUp() throws {
        var ledger = MPCRemnantLedger()
        try ledger.accept(day: 1, closedCaseIDs: ["b01"], highestTowerFloor: 4)
        try ledger.accept(day: 5, closedCaseIDs: ["b01"], highestTowerFloor: 20)
        #expect(ledger.jobs.count == 2 && ledger.job(day: 3) == nil)
        try ledger.accept(day: 20, closedCaseIDs: ["b01"], highestTowerFloor: 80)
        #expect(ledger.jobs.keys.sorted() == ["d20"])
    }

    @Test func remnantFightsUseAuthoredBodiesOnTheShippedPath() throws {
        for remnant in R.all {
            for band in Set([10, remnant.maxFloor]) {
                let id = R.encounterID(caseID: remnant.id, band: band, ticket: "abc-1")
                let encounter = try #require(try expectStreetEncounterShips(id), "\(id)")
                let species = encounter.waves.map { $0.enemyIDs.map { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0)!.species } }
                #expect(species == remnant.waves && encounter.name == remnant.title)
            }
        }
        #expect(R.encounter(id: R.prefix + "b01-f20_abc") == nil)
        #expect(R.encounter(id: R.prefix + "b09-f25_abc") == nil)
        #expect(R.encounter(id: R.prefix + "b99-f10_abc") == nil)
    }

    @Test func codableRoundTrip() throws {
        var ledger = MPCRemnantLedger()
        let job = try ledger.accept(day: 4, closedCaseIDs: ["b07"], highestTowerFloor: 16)
        try ledger.answer(day: 4, choiceID: job.remnant!.leads[job.lead].correctChoiceID)
        _ = try ledger.beginBattle(day: 4, ticket: "t1")
        let decoded = try JSONDecoder().decode(MPCRemnantLedger.self, from: JSONEncoder().encode(ledger))
        #expect(decoded == ledger)
    }
}
