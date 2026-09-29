import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Neighbour errands: two or three small favours a day")
struct NeighborErrandTests {
    typealias N = MPCNeighborCatalog
    let workshop: Set<Int> = Set(1...5)

    @Test func rosterIsTheHarbourMapsCitizens() throws {
        let map = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Mistport/WisteriaMap/harbor-pedestrians.json")
        struct Map: Decodable { struct Citizen: Decodable { let id: String; let name: String }; let citizens: [Citizen] }
        let citizens = try JSONDecoder().decode(Map.self, from: Data(contentsOf: map)).citizens
        #expect(Set(N.all.map(\.id)) == Set(citizens.map(\.id)) && N.all.count == citizens.count)
        for neighbor in N.all { #expect(neighbor.name == citizens.first { $0.id == neighbor.id }?.name, "\(neighbor.id)") }
    }

    @Test func everyNeighbourIsWritten() {
        #expect(N.written.count == 23 && N.all.count == 23 && Set(N.rotation).count == 23)
        let errands = N.all.flatMap(\.errands)
        #expect(Set(errands.map(\.id)).count == errands.count && errands.allSatisfy { !$0.id.contains("_") })
        for neighbor in N.written {
            #expect(neighbor.errands.count == 3 && neighbor.stories.count == N.storyAffinity.count, "\(neighbor.id)")
            #expect(Set(neighbor.errands.map(\.kind)).count == 3, "\(neighbor.id) repeats a kind")
        }
        for errand in errands {
            #expect(!errand.request.isEmpty && !errand.thanks.isEmpty)
            switch errand.kind {
            case .deliver:
                #expect(MPCWorkshopOrderBoard.prices[errand.itemID!] != nil && errand.count > 0)
                #expect(errand.copper == errand.count * MPCWorkshopOrderBoard.prices[errand.itemID!]! + 5)
            case .find:
                #expect(errand.choices.count == 3 && errand.choices.contains { $0.id == errand.correctChoiceID })
            case .pest:
                #expect(!errand.pests.isEmpty && errand.pests.count <= 2)
            case .message:
                let recipient = N.errand(errand.id)!.neighbor.id
                #expect(N.neighbor(errand.recipientID!) != nil && errand.recipientID != recipient && errand.reply?.isEmpty == false)
            }
        }
    }

    @Test func twoOrThreeRequestsADayFromDayTwo() {
        var ledger = MPCNeighborLedger()
        #expect(ledger.open(day: 1, completedMissions: [1, 2, 3]).isEmpty)
        let day2 = ledger.open(day: 2, completedMissions: [1, 2, 3])
        #expect(day2.count == 2 && day2.allSatisfy { $0.errand!.kind != .deliver })
        let day3 = ledger.open(day: 3, completedMissions: workshop)
        #expect(day3.count == 3 && Set(day3.map(\.neighborID)).count == 3 && day3.allSatisfy { $0.day == 3 })
        // Opening the same day again changes nothing; a clock moved back neither.
        #expect(ledger.open(day: 3, completedMissions: workshop) == day3 && ledger.open(day: 2, completedMissions: workshop) == day3)
        let chapter = (2...28).map { N.askers(day: $0).count }
        #expect(chapter.allSatisfy { (2...3).contains($0) })
        // Everyone takes turns: two or three times by day 28, three times by day 31 (both stories).
        for neighbor in N.all {
            let asks = { (last: Int) in (2...last).filter { N.askers(day: $0).contains(neighbor) }.count }
            #expect((2...3).contains(asks(28)) && asks(31) >= 3, "\(neighbor.id)")
        }
        let musicianDay = (2...28).first(where: { day in N.askers(day: day).contains { $0.id == "musician" } })
        #expect(musicianDay == 7)
    }

    /// Completes whatever the offer asks, with a real fight for pests.
    func finish(_ ledger: inout MPCNeighborLedger, _ offer: MPCNeighborLedger.Offer, coins: inout Int,
                inventory: inout [String: Int]) throws -> MPCNeighborLedger.Reward? {
        let errand = offer.errand!
        switch errand.kind {
        case .deliver: return try ledger.deliver(offerID: offer.id, coins: &coins, inventory: &inventory)
        case .find: return try ledger.answer(offerID: offer.id, choiceID: errand.correctChoiceID!, coins: &coins)
        case .message: return try ledger.relay(offerID: offer.id, to: errand.recipientID!, coins: &coins)
        case .pest:
            let ticket = "pest-\(offer.id)"
            let id = try ledger.beginPest(offerID: offer.id, ticket: ticket)
            return try ledger.settlePest(offerID: offer.id, ticket: ticket, session: playStreet(id, to: .victory), coins: &coins)
        }
    }

    @Test func affinityUnlocksTheStoriesAtTwoAndThree() throws {
        var ledger = MPCNeighborLedger(), coins = 0
        var inventory = [MPCCraftingCatalog.strapID: 99, MPCCraftingCatalog.clothID: 99, MPCCraftingCatalog.salveID: 99, MPCCraftingCatalog.patchID: 99]
        var told: [Int: String] = [:], days: [Int] = []
        for day in 2...28 {
            guard let offer = ledger.open(day: day, completedMissions: workshop).first(where: { $0.neighborID == "postman" }) else { continue }
            let reward = try #require(try finish(&ledger, offer, coins: &coins, inventory: &inventory))
            days.append(day)
            if let story = reward.story { told[reward.affinity] = story }
        }
        #expect(days == [2, 12, 21] && ledger.affinity["postman"] == 3)
        #expect(told == [2: N.neighbor("postman")!.stories[0], 3: N.neighbor("postman")!.stories[1]])
        #expect(ledger.stories("postman") == N.neighbor("postman")!.stories && ledger.stories("baker").isEmpty)
    }

    @Test func eachKindPaysOnce() throws {
        var ledger = MPCNeighborLedger(), coins = 0, inventory: [String: Int] = [:]
        // Day 2: the postman's letter for the old-street registrar.
        let message = ledger.open(day: 2, completedMissions: workshop).first { $0.neighborID == "postman" }!
        #expect(message.errand!.kind == .message)
        #expect(throws: MPCNeighborLedger.Failure.wrongRecipient) { try ledger.relay(offerID: message.id, to: "baker", coins: &coins) }
        #expect(throws: MPCNeighborLedger.Failure.wrongKind) { try ledger.deliver(offerID: message.id, coins: &coins, inventory: &inventory) }
        let relayed = try ledger.relay(offerID: message.id, to: "west-lane", coins: &coins)
        #expect(relayed.copper == 8 && coins == 8 && relayed.affinity == 1 && relayed.story == nil)
        #expect(throws: MPCNeighborLedger.Failure.done) { try ledger.relay(offerID: message.id, to: "west-lane", coins: &coins) }
        // Day 3: the east-side lamplighter wants two filter cloths.
        let cloth = ledger.open(day: 3, completedMissions: workshop).first { $0.neighborID == "east-houses" }!
        #expect(cloth.errand!.kind == .deliver)
        #expect(throws: MPCNeighborLedger.Failure.stock) { try ledger.deliver(offerID: cloth.id, coins: &coins, inventory: &inventory) }
        inventory[MPCCraftingCatalog.clothID] = 2
        let delivered = try ledger.deliver(offerID: cloth.id, coins: &coins, inventory: &inventory)
        #expect(delivered.copper == 21 && coins == 29 && inventory[MPCCraftingCatalog.clothID] == 0)
        // Day 5: the florist's first errand is a find; a wrong answer is struck out at no cost.
        let find = ledger.open(day: 5, completedMissions: workshop).first { $0.neighborID == "florist" }!
        let errand = find.errand!
        let wrong = errand.choices.first { $0.id != errand.correctChoiceID }!.id
        let miss = try ledger.answer(offerID: find.id, choiceID: wrong, coins: &coins)
        #expect(miss == nil && coins == 29)
        #expect(throws: MPCNeighborLedger.Failure.invalidChoice) { try ledger.answer(offerID: find.id, choiceID: wrong, coins: &coins) }
        let hit = try ledger.answer(offerID: find.id, choiceID: errand.correctChoiceID!, coins: &coins)
        #expect(hit?.copper == 12 && coins == 41)
        // Day 7: the musician's first errand is a pest; a lost fight leaves it open.
        let pest = ledger.open(day: 7, completedMissions: workshop).first { $0.neighborID == "musician" }!
        #expect(pest.errand!.kind == .pest)
        let id = try ledger.beginPest(offerID: pest.id, ticket: "p1")
        #expect(throws: MPCNeighborLedger.Failure.pending) { try ledger.beginPest(offerID: pest.id, ticket: "p2") }
        let lost = try ledger.settlePest(offerID: pest.id, ticket: "p1", session: playStreet(id, to: .defeat), coins: &coins)
        #expect(lost == nil && coins == 41)
        let again = try ledger.beginPest(offerID: pest.id, ticket: "p2")
        let won = try ledger.settlePest(offerID: pest.id, ticket: "p2", session: playStreet(again, to: .victory), coins: &coins)
        #expect(won?.copper == 15 && coins == 56 && ledger.completedErrands == 4)
    }

    @Test func requestsLapseOvernight() throws {
        var ledger = MPCNeighborLedger(), coins = 0
        let old = ledger.open(day: 4, completedMissions: workshop)
        ledger.open(day: 5, completedMissions: workshop)
        #expect(throws: MPCNeighborLedger.Failure.notOffered) {
            try ledger.relay(offerID: old[0].id, to: old[0].errand!.recipientID ?? "", coins: &coins)
        }
    }

    @Test func pestFightsUseSmallAuthoredBodies() throws {
        for errand in N.all.flatMap(\.errands) where errand.kind == .pest {
            let id = N.encounterID(errandID: errand.id, ticket: "abc-1")
            let encounter = try #require(try expectStreetEncounterShips(id), "\(errand.id)")
            #expect(encounter.waves.count == 1 && encounter.waves[0].enemyIDs.count == errand.pests.count)
        }
        #expect(N.encounter(id: N.encounterID(errandID: "postman-letter", ticket: "abc")) == nil)
        #expect(N.encounter(id: N.encounterID(errandID: "nobody-pest", ticket: "abc")) == nil)
    }

    @Test func codableRoundTrip() throws {
        var ledger = MPCNeighborLedger(), coins = 0
        let offers = ledger.open(day: 2, completedMissions: workshop)
        _ = try ledger.relay(offerID: offers[0].id, to: offers[0].errand!.recipientID!, coins: &coins)
        let decoded = try JSONDecoder().decode(MPCNeighborLedger.self, from: JSONEncoder().encode(ledger))
        #expect(decoded == ledger)
    }
}

extension NeighborErrandTests {
    @Test func abandonedPestTicketCannotRewardButNewAttemptCan() throws {
        var ledger = MPCNeighborLedger(), coins = 0
        let offer = ledger.open(day: 7, completedMissions: workshop).first { $0.errand?.kind == .pest }!
        let old = try ledger.beginPest(offerID: offer.id, ticket: "abandoned")
        ledger.abandonPest(offerID: offer.id, ticket: "wrong-ticket")
        #expect(ledger.offers.first { $0.id == offer.id }?.activeTicket == "abandoned")
        ledger.abandonPest(offerID: offer.id, ticket: "abandoned")
        ledger.abandonPest(offerID: offer.id, ticket: "abandoned")
        #expect(try ledger.settlePest(offerID: offer.id, ticket: "abandoned", session: playStreet(old, to: .victory), coins: &coins) == nil)
        #expect(coins == 0)
        let retry = try ledger.beginPest(offerID: offer.id, ticket: "retry")
        ledger.open(day: 8, completedMissions: workshop)
        let reward = try ledger.settlePest(offerID: offer.id, ticket: "retry", session: playStreet(retry, to: .victory), coins: &coins)
        #expect(reward?.copper == 15 && coins == 15)
    }
}
