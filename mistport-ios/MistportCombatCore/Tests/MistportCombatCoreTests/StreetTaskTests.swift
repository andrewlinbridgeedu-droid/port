import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Street tasks: urgent errands, joint errands and city commissions")
struct StreetTaskTests {
    typealias C = MPCStreetTaskCatalog
    typealias L = MPCStreetTaskLedger

    /// Plays a street fight to a win with a strong loadout through the rules driver.
    func win(_ encounterID: String) throws -> MPCChapterOneEncounterSession {
        let loadout = MPCChurchTowerVerificationRunner.recommendedLoadout(for: MPCChurchTowerCatalog.floor(number: 40)!)
        let (result, _) = try MPCChurchBattleDriver.record(encounterID: encounterID, loadout: loadout) { _ in [] }
        try #require(result.outcome == .victory)
        return result.session
    }

    /// Does the current step of an offer, whatever it is.
    func doStep(_ ledger: inout L, _ offerID: String, coins: inout Int, inventory: inout [String: Int], ticket: String) throws -> L.Progress? {
        let step = try #require(ledger.offers.first { $0.id == offerID }?.step)
        switch step.action {
        case .talk: return try ledger.talk(offerID: offerID, at: step.target, coins: &coins)
        case .handOver: return try ledger.handOver(offerID: offerID, at: step.target, coins: &coins, inventory: &inventory)
        case .answer:
            for choice in step.choices where choice.id != step.correctChoiceID {
                #expect(try ledger.answer(offerID: offerID, at: step.target, choiceID: choice.id, coins: &coins) == nil)
            }
            return try ledger.answer(offerID: offerID, at: step.target, choiceID: step.correctChoiceID!, coins: &coins)
        case .battle:
            let id = try ledger.beginBattle(offerID: offerID, ticket: ticket)
            return try ledger.settleBattle(offerID: offerID, ticket: ticket, session: try win(id), coins: &coins)
        }
    }

    @Test("every place a step points to is on the home map")
    func placesAreOnTheHomeMap() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Mistport/WisteriaMap/home-map-layout.json")
        struct Layout: Decodable { struct Item: Decodable { let id: String }; let buildings: [Item]; let streetSpots: [Item] }
        let layout = try JSONDecoder().decode(Layout.self, from: Data(contentsOf: file))
        #expect(C.places == Set(layout.buildings.map(\.id) + layout.streetSpots.map(\.id)))
        for task in C.streetTasks {
            for step in task.steps { #expect(step.isPerson || C.places.contains(step.target), "\(task.id): \(step.target)") }
        }
    }

    @Test("23 urgent errands, one per neighbour, three steps starting at the poster")
    func urgentErrands() {
        #expect(C.urgentErrands.count == 23)
        #expect(Set(C.urgentErrands.map(\.giverID)) == Set(MPCNeighborCatalog.all.map(\.id)))
        for task in C.urgentErrands {
            #expect(task.kind == .urgent && task.steps.count == 3 && task.copper == 15, "\(task.id)")
            #expect(task.steps.first?.target == task.giverID && task.neighbors == [task.giverID], "\(task.id)")
        }
    }

    @Test("joint errands chain two or three neighbours in four or five steps")
    func jointErrands() {
        #expect(C.jointErrands.count == 8)
        for task in C.jointErrands {
            #expect(task.kind == .joint && (4...5).contains(task.steps.count) && task.copper == 30, "\(task.id)")
            #expect((2...3).contains(task.neighbors.count) && task.steps.first?.target == task.giverID, "\(task.id)")
            let targets = Set(task.steps.map(\.target))
            for neighbor in task.neighbors { #expect(targets.contains(neighbor), "\(task.id): \(neighbor)") }
        }
    }

    @Test("two city commissions, one per painted scene")
    func cityCommissions() {
        #expect(C.cityCommissions.map(\.sceneID) == ["fountain", "yard"])
        for task in C.cityCommissions {
            #expect(task.kind == .commission && (5...6).contains(task.steps.count) && task.copper == 60, "\(task.id)")
            #expect(C.places.contains(task.giverID) && task.steps.first?.target == task.giverID && task.contributionSource == nil)
        }
    }

    @Test("questions have three choices, goods are known, fights start")
    func stepsAreWellFormed() throws {
        let goods: Set<String> = [C.strap, C.cloth, C.patch, C.salve]
        #expect(Set(C.streetTasks.map(\.id)).count == C.streetTasks.count)
        for task in C.streetTasks {
            for (index, step) in task.steps.enumerated() {
                switch step.action {
                case .answer:
                    #expect(step.choices.count == 3 && step.choices.contains { $0.id == step.correctChoiceID } && step.question != nil, "\(task.id)")
                case .handOver:
                    #expect(!step.items.isEmpty && step.items.keys.allSatisfy(goods.contains), "\(task.id)")
                case .battle:
                    #expect(!step.pests.isEmpty)
                    let id = C.streetEncounterID(taskID: task.id, step: index, ticket: "t-1")
                    let session = try MPCChapterOneEncounterSession.start(encounterID: id, companionIDs: [])
                    #expect(session.encounter.id == id && session.isChurchCombat)
                case .talk:
                    break
                }
                #expect(!step.goal.isEmpty && !step.line.isEmpty)
            }
        }
    }

    @Test("the day's urgent poster is never one of the day's neighbour askers")
    func urgentPosterIsNotAnAsker() {
        for day in 2...60 {
            let askers = Set(MPCNeighborCatalog.askers(day: day).map(\.id))
            #expect(!askers.contains(C.urgentErrand(day: day).giverID), "day \(day)")
        }
    }

    @Test("offers follow the contribution tier and lapse at the end of their window")
    func schedule() {
        var ledger = L()
        #expect(ledger.open(day: 3, contributionPoints: 100).isEmpty)
        #expect(ledger.open(day: 6, contributionPoints: 120).map(\.id) == ["urgent-d6"], "tier 2: urgent only, even on a third day")
        #expect(ledger.open(day: 7, contributionPoints: 125).map(\.id) == ["urgent-d7"], "yesterday's urgent errand is gone")
        #expect(ledger.open(day: 15, contributionPoints: 225).map(\.id) == ["urgent-d15", "joint-d15"])
        #expect(ledger.open(day: 16, contributionPoints: 230).map(\.id) == ["joint-d15", "urgent-d16"], "a joint errand keeps a second day")
        #expect(ledger.open(day: 20, contributionPoints: 300).map(\.id) == ["urgent-d20", "commission-d20"])
        #expect(ledger.offers.first { $0.id == "commission-d20" }?.lastDay == 26)
        #expect(ledger.open(day: 26, contributionPoints: 320).map(\.id).contains("commission-d20"))
        #expect(ledger.open(day: 27, contributionPoints: 330).map(\.id) == ["urgent-d27", "joint-d27", "commission-d27"],
                "not done in its week: the same commission is posted again")
        #expect(ledger.offers.first { $0.id == "commission-d27" }?.taskID == "commission-fountain")
    }

    @Test("a task is done step by step and pays once; commissions change the painting once")
    func playThrough() throws {
        var ledger = L(), coins = 0
        var inventory = [C.strap: 9, C.cloth: 9, C.patch: 9, C.salve: 9]
        ledger.open(day: 21, contributionPoints: 400)
        let commission = try #require(ledger.offers.first { $0.id.hasPrefix("commission") })
        #expect(throws: L.Failure.notAccepted) { try ledger.talk(offerID: commission.id, at: "cityhall", coins: &coins) }
        try ledger.accept(offerID: commission.id)
        #expect(throws: L.Failure.wrongTarget) { try ledger.talk(offerID: commission.id, at: "harbor", coins: &coins) }
        var last: L.Progress?
        var ticket = 0
        while ledger.offers.first(where: { $0.id == commission.id })?.done == false {
            ticket += 1
            last = try doStep(&ledger, commission.id, coins: &coins, inventory: &inventory, ticket: "t-\(ticket)")
        }
        let reward = try #require(last?.reward)
        #expect(reward.copper == 60 && reward.sceneID == "fountain" && reward.contributionReceipt == nil && coins == 60)
        #expect(ledger.scenes == ["fountain"] && inventory[C.cloth] == 7)
        #expect(throws: L.Failure.done) { try ledger.talk(offerID: commission.id, at: "cityhall", coins: &coins) }

        // The urgent errand the same day: a contribution receipt and the poster's affinity.
        let urgent = try #require(ledger.offers.first { $0.id == "urgent-d21" })
        try ledger.accept(offerID: urgent.id)
        var result: L.Progress?
        while ledger.offers.first(where: { $0.id == urgent.id })?.done == false {
            ticket += 1
            result = try doStep(&ledger, urgent.id, coins: &coins, inventory: &inventory, ticket: "t-\(ticket)")
        }
        #expect(result?.reward?.contributionReceipt == "street-urgent-d21" && result?.reward?.neighbors == [urgent.task!.giverID])
        #expect(coins == 75)

        // Next week the yard commission follows; the fountain is not posted again.
        ledger.open(day: 28, contributionPoints: 420)
        #expect(ledger.offers.contains { $0.taskID == "commission-yard" } && !ledger.offers.contains { $0.taskID == "commission-fountain" })
    }

    @Test("goods must be on hand, and a street fight settles once")
    func stockAndFights() throws {
        var ledger = L(), coins = 0, inventory: [String: Int] = [:]
        ledger.open(day: 21, contributionPoints: 400)
        let offer = try #require(ledger.offers.first { $0.id.hasPrefix("commission") })
        try ledger.accept(offerID: offer.id)
        _ = try ledger.talk(offerID: offer.id, at: "cityhall", coins: &coins)
        _ = try ledger.talk(offerID: offer.id, at: "industry", coins: &coins)
        _ = try ledger.talk(offerID: offer.id, at: "florist", coins: &coins)
        #expect(throws: L.Failure.stock) { try ledger.handOver(offerID: offer.id, at: "cafe_keeper", coins: &coins, inventory: &inventory) }
        inventory[C.cloth] = 2
        _ = try ledger.handOver(offerID: offer.id, at: "cafe_keeper", coins: &coins, inventory: &inventory)
        #expect(throws: L.Failure.wrongAction) { try ledger.talk(offerID: offer.id, at: "board", coins: &coins) }
        let id = try ledger.beginBattle(offerID: offer.id, ticket: "fight-1")
        #expect(throws: L.Failure.pending) { try ledger.beginBattle(offerID: offer.id, ticket: "fight-2") }
        let session = try win(id)
        let first = try ledger.settleBattle(offerID: offer.id, ticket: "fight-1", session: session, coins: &coins)
        #expect(first?.reward == nil && first?.line.isEmpty == false)
        #expect(try ledger.settleBattle(offerID: offer.id, ticket: "fight-1", session: session, coins: &coins) == nil)
        #expect(ledger.offers.first { $0.id == offer.id }?.stepIndex == 5)
    }

    @Test("targets light the poster first, then each step's person or place")
    func targets() throws {
        var ledger = L(), coins = 0
        ledger.open(day: 21, contributionPoints: 400)
        let before = C.streetTargets(ledger)
        #expect(before.contains { $0.kind == .commission && $0.placeID == "cityhall" })
        #expect(before.contains { $0.kind == .urgentErrand && $0.placeID == "board" })
        let urgent = try #require(ledger.offers.first { $0.id == "urgent-d21" })
        try ledger.accept(offerID: urgent.id)
        #expect(C.streetTargets(ledger).contains { $0.taskID == urgent.id && $0.personID == urgent.task!.giverID })
        _ = try ledger.talk(offerID: urgent.id, at: urgent.task!.giverID, coins: &coins)
        let second = urgent.task!.steps[1]
        #expect(C.streetTargets(ledger).contains { $0.taskID == urgent.id && ($0.personID ?? $0.placeID) == second.target })
    }

    @Test("the ledger survives a save")
    func codable() throws {
        var ledger = L(), coins = 0
        ledger.open(day: 21, contributionPoints: 400)
        try ledger.accept(offerID: "urgent-d21")
        _ = try ledger.talk(offerID: "urgent-d21", at: ledger.offers.first { $0.id == "urgent-d21" }!.task!.giverID, coins: &coins)
        let decoded = try JSONDecoder().decode(L.self, from: JSONEncoder().encode(ledger))
        #expect(decoded == ledger)
    }

    @Test("neighbour errands light the asker, then the recipient of a heard message")
    func neighborTargets() throws {
        var neighbors = MPCNeighborLedger(), coins = 0
        let offers = neighbors.open(day: 2, completedMissions: Set(1...5))
        let targets = C.neighborTargets(neighbors)
        #expect(targets.count == offers.count && !targets.isEmpty)
        #expect(targets.allSatisfy { $0.kind == .neighbor && $0.placeID == nil })
        #expect(Set(targets.compactMap(\.personID)) == Set(offers.map(\.neighborID)))
        let message = try #require(offers.first { $0.errand?.kind == .message })
        let recipient = try #require(message.errand?.recipientID)
        let heard = C.neighborTargets(neighbors, heardMessages: [message.id]).filter { $0.taskID == message.id }
        #expect(heard.map(\.personID) == [recipient])
        _ = try neighbors.relay(offerID: message.id, to: recipient, coins: &coins)
        #expect(!C.neighborTargets(neighbors, heardMessages: [message.id]).contains { $0.taskID == message.id })
        neighbors.open(day: 3, completedMissions: Set(1...5))
        #expect(C.neighborTargets(neighbors).allSatisfy { $0.taskID.hasPrefix("d3-") })
    }

    @Test("street tasks raise neighbour affinity and can unlock a story")
    func affinity() {
        var neighbors = MPCNeighborLedger()
        #expect(neighbors.raiseAffinity("baker") == nil)
        #expect(neighbors.raiseAffinity("baker") == MPCNeighborCatalog.neighbor("baker")?.stories.first)
        #expect(neighbors.raiseAffinity("nobody") == nil)
    }
}
