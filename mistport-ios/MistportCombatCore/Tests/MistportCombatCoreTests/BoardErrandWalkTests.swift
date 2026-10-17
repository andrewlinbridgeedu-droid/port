import Foundation
import Testing
@testable import MistportCombatCore

/// The board errands as the player meets them (user 2026-10-17: people should appear, not
/// keep saying a request lapsed, and a tap should carry the errand on, sometimes over a few
/// trips). Every errand of days 1–40 is walked through its lit targets only: whoever the home
/// map lights is the one the next action is done at.
@Suite("Board errands walked through the home map's lit targets")
struct BoardErrandWalkTests {
    typealias C = MPCStreetTaskCatalog

    /// People the home map can draw: the harbour citizens plus the bounty witnesses the App adds
    /// (HomeCitizenCatalog.people); places are the layout's buildings and street spots.
    static let mapPeople: Set<String> = {
        let file = repoFile("Mistport/WisteriaMap/harbor-pedestrians.json")
        struct Map: Decodable { struct Citizen: Decodable { let id: String }; let citizens: [Citizen] }
        let citizens = try! JSONDecoder().decode(Map.self, from: Data(contentsOf: file)).citizens.map(\.id)
        return Set(citizens + ["mohr", "old-sailor", "odelle", "vera", "archivist", "norn", "harbor-officer", "ilya"])
    }()
    static let mapPlaces: Set<String> = {
        struct Layout: Decodable { struct Item: Decodable { let id: String }; let buildings: [Item]; let streetSpots: [Item] }
        let layout = try! JSONDecoder().decode(Layout.self, from: Data(contentsOf: repoFile("Mistport/WisteriaMap/home-map-layout.json")))
        return Set(layout.buildings.map(\.id) + layout.streetSpots.map(\.id))
    }()
    static func repoFile(_ path: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(path)
    }
    static let goods = Set(MPCCraftingCatalog.basics.map(\.output) + MPCWorkshopOrderBoard.prices.keys
        + [MPCCraftingCatalog.salveID, MPCCraftingCatalog.clothID, MPCCraftingCatalog.strapID, MPCCraftingCatalog.patchID])
    func isOnMap(_ target: MPCStreetTaskTarget) -> Bool {
        if let person = target.personID { return Self.mapPeople.contains(person) }
        return target.placeID.map(Self.mapPlaces.contains) ?? false
    }
    func win(_ encounterID: String) throws -> MPCChapterOneEncounterSession {
        let loadout = MPCChurchTowerVerificationRunner.recommendedLoadout(for: MPCChurchTowerCatalog.floor(number: 40)!)
        let (result, _) = try MPCChurchBattleDriver.record(encounterID: encounterID, loadout: loadout) { _ in [] }
        try #require(result.outcome == .victory)
        return result.session
    }

    @Test("every neighbour errand of days 1–40 is finished at the people the map lights")
    func neighbourErrands() throws {
        var ledger = MPCNeighborLedger(), coins = 0, inventory: [String: Int] = [:]
        var finished = 0
        for day in 1...40 {
            ledger.open(day: day, completedMissions: Set(1...30))
            for item in Self.goods { inventory[item] = 20 }
            var heard: Set<String> = []
            for offer in ledger.offers where offer.day == day {
                let errand = try #require(offer.errand)
                let lit = { C.neighborTargets(ledger, heardMessages: heard, today: day).filter { $0.taskID == offer.id } }
                let asker = try #require(lit().first, "day \(day) \(offer.id) is not lit")
                #expect(asker.personID == offer.neighborID && isOnMap(asker), "day \(day) \(offer.id)")
                let reward: MPCNeighborLedger.Reward?
                switch errand.kind {
                case .deliver: reward = try ledger.deliver(offerID: offer.id, coins: &coins, inventory: &inventory)
                case .find: reward = try ledger.answer(offerID: offer.id, choiceID: errand.correctChoiceID!, coins: &coins)
                case .pest:
                    let ticket = "walk-\(offer.id)"
                    let id = try ledger.beginPest(offerID: offer.id, ticket: ticket)
                    reward = try ledger.settlePest(offerID: offer.id, ticket: ticket, session: playStreet(id, to: .victory), coins: &coins)
                case .message:
                    // Second trip: once taken on at the asker, the recipient is lit instead.
                    heard.insert(offer.id)
                    let recipient = try #require(lit().first, "day \(day) \(offer.id) recipient is not lit")
                    #expect(recipient.personID == errand.recipientID && isOnMap(recipient), "day \(day) \(offer.id)")
                    reward = try ledger.relay(offerID: offer.id, to: recipient.personID!, coins: &coins)
                }
                #expect(reward?.copper == errand.copper, "day \(day) \(offer.id)")
                #expect(lit().isEmpty, "day \(day) \(offer.id) stays lit after it is done")
                finished += 1
            }
        }
        #expect(finished == (1...40).map { MPCNeighborCatalog.askers(day: $0).count }.reduce(0, +))
    }

    @Test("every street task of days 1–40 is taken at its poster and finished step by step at the lit target")
    func streetTasks() throws {
        var ledger = MPCStreetTaskLedger(), coins = 0, inventory: [String: Int] = [:]
        var kinds: [MPCStreetTask.Kind: Int] = [:]
        var trips: Set<Int> = []
        for day in 1...40 {
            ledger.open(day: day, contributionPoints: 400)
            for item in Self.goods { inventory[item] = 20 }
            for offer in ledger.offers where offer.postedDay == day {
                let task = try #require(offer.task)
                let lit = { C.streetTargets(ledger, today: day).filter { $0.taskID == offer.id } }
                let poster = try #require(lit().first, "day \(day) \(offer.id) is not posted")
                #expect(poster.id.hasSuffix(":post") && isOnMap(poster), "day \(day) \(offer.id)")
                try ledger.accept(offerID: offer.id)
                var places: [String] = []
                for (index, step) in task.steps.enumerated() {
                    let target = try #require(lit().first, "day \(day) \(offer.id) step \(index) is not lit")
                    let here = try #require(target.personID ?? target.placeID)
                    #expect(here == step.target && isOnMap(target), "day \(day) \(offer.id) step \(index): lit \(here), step at \(step.target)")
                    places.append(here)
                    let progress: MPCStreetTaskLedger.Progress?
                    switch step.action {
                    case .talk: progress = try ledger.talk(offerID: offer.id, at: here, coins: &coins)
                    case .handOver: progress = try ledger.handOver(offerID: offer.id, at: here, coins: &coins, inventory: &inventory)
                    case .answer:
                        let wrong = try #require(step.choices.first { $0.id != step.correctChoiceID })
                        #expect(try ledger.answer(offerID: offer.id, at: here, choiceID: wrong.id, coins: &coins) == nil)
                        progress = try ledger.answer(offerID: offer.id, at: here, choiceID: step.correctChoiceID!, coins: &coins)
                    case .battle:
                        let ticket = "walk-\(offer.id)-\(index)"
                        let id = try ledger.beginBattle(offerID: offer.id, ticket: ticket)
                        progress = try ledger.settleBattle(offerID: offer.id, ticket: ticket, session: win(id), coins: &coins)
                    }
                    #expect((progress?.reward != nil) == (index == task.steps.count - 1), "day \(day) \(offer.id) step \(index)")
                }
                #expect(lit().isEmpty, "day \(day) \(offer.id) stays lit after it is done")
                kinds[task.kind, default: 0] += 1
                trips.insert(Set(places).count)
            }
        }
        // Urgent errands from day 2, joint errands every third day, the two commissions a week apart.
        #expect(kinds[.urgent, default: 0] == 39 && kinds[.joint, default: 0] == 13 && kinds[.commission, default: 0] == 2)
        // A task is a few trips: always more than one place, never all steps in one spot.
        #expect(trips.min()! >= 2)
    }

    @Test("at midnight yesterday's people go dark before the ledger opens the new day")
    func lapsedAskersAreNotLit() throws {
        var neighbors = MPCNeighborLedger(), street = MPCStreetTaskLedger()
        neighbors.open(day: 6, completedMissions: Set(1...30))
        street.open(day: 6, contributionPoints: 400)
        try street.accept(offerID: "urgent-d6")
        #expect(!C.neighborTargets(neighbors, today: 6).isEmpty && C.neighborTargets(neighbors, today: 7).isEmpty)
        // The urgent errand ended with day 6; the joint errand posted on day 6 runs to day 7.
        #expect(Set(C.streetTargets(street, today: 6).map(\.taskID)) == ["urgent-d6", "joint-d6", "commission-d6"])
        #expect(Set(C.streetTargets(street, today: 7).map(\.taskID)) == ["joint-d6", "commission-d6"])
        // Without `today` the old behaviour holds (the ledger's own day).
        #expect(C.neighborTargets(neighbors) == C.neighborTargets(neighbors, today: 6))
    }

    @Test("the countdown ends at the local midnight after the day")
    func countdown() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 9))!
        let record = MPCDailyPacingStart(start: start, origin: .newSave, recordedAt: start)
        let end = record.end(ofDay: 5, calendar: calendar)
        #expect(end == calendar.date(from: DateComponents(year: 2026, month: 10, day: 18)))
        #expect(record.day(now: end.addingTimeInterval(-1), calendar: calendar) == 5)
        #expect(record.day(now: end, calendar: calendar) == 6)
        #expect(MPCDailyPacing.remainingText(seconds: 3 * 3600 + 25 * 60) == "还剩 3 小时 25 分")
        #expect(MPCDailyPacing.remainingText(seconds: 2 * 3600) == "还剩 2 小时")
        #expect(MPCDailyPacing.remainingText(seconds: 7 * 60 + 5) == "还剩 8 分")
        #expect(MPCDailyPacing.remainingText(seconds: 2) == "还剩 1 分")
        #expect(MPCDailyPacing.remainingText(seconds: 6 * 86_400 + 5 * 3600) == "还剩 6 天 5 小时")
    }
}
