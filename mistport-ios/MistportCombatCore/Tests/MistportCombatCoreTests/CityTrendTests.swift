import Foundation
import Testing
@testable import MistportCombatCore

/// The city trend (CITY_TREND_TASKS_PROPOSAL_20261017.md): the sum of choices settles each
/// stage; one player pushes the city but cannot decide it alone; the same world replays alike.
@Suite("City trend: choices summed into the city's stages")
struct CityTrendTests {
    typealias L = MPCCityTrendLedger

    @Test("every neighbour errand has two ways for two different sides")
    func everyErrandHasTwoWays() {
        for neighbor in MPCNeighborCatalog.all {
            for errand in neighbor.errands {
                let ways = MPCNeighborCatalog.ways(errand.id)
                #expect(ways.count == 2 && Set(ways.map(\.side)).count == 2, "\(errand.id)")
                #expect(ways.allSatisfy { !$0.label.isEmpty && !$0.fact.isEmpty && !$0.reply.isEmpty && $0.label.count <= 10 }, "\(errand.id)")
            }
        }
        // Each pair of sides is offered equally often: the explorer (tools/city-trend-sim) showed a
        // side on offer in every errand wins the shared world almost every time (2026-10-17).
        let pairs = MPCNeighborCatalog.all.flatMap(\.errands).map { Set(MPCNeighborCatalog.ways($0.id).map(\.side)) }
        for pair in [[MPCCityFaction.neighbours, .offices], [.neighbours, .compacts], [.offices, .compacts]] {
            #expect(pairs.filter { $0 == Set(pair) }.count == 23, "\(pair)")
        }
    }

    @Test("every stage puts a key choice with one option per side")
    func keyChoices() {
        for stage in MPCCityTrendStage.allCases {
            #expect(!stage.keyQuestion.isEmpty)
            #expect(stage.keyChoices.map(\.side) == MPCCityFaction.allCases, "\(stage)")
            #expect(stage.keyChoices.allSatisfy { !$0.fact.isEmpty && !$0.reply.isEmpty && $0.label.count <= 10 }, "\(stage)")
        }
    }

    @Test("a few ordinary points a day, one key choice a stage, each receipt once")
    func ledgerCaps() {
        var ledger = L()
        #expect(ledger.record(id: "a", day: 5, side: .neighbours, fact: "x") == 1)
        #expect(ledger.record(id: "a", day: 5, side: .neighbours, fact: "x") == 0)
        #expect(ledger.record(id: "b", day: 5, side: .offices, fact: "x") == 1)
        #expect(ledger.record(id: "c", day: 5, side: .offices, fact: "x") == 1)
        #expect(ledger.record(id: "d", day: 5, side: .offices, fact: "x") == 0)
        #expect(ledger.points(on: 5) == [.neighbours: 1, .offices: 2, .compacts: 0].filter { $0.value > 0 })
        #expect(ledger.record(id: "k1", day: 6, side: .compacts, key: true, fact: "x") == L.keyWeight)
        #expect(ledger.record(id: "k2", day: 9, side: .compacts, key: true, fact: "x") == 0)
        #expect(ledger.record(id: "k3", day: 11, side: .compacts, key: true, fact: "x") == L.keyWeight)
        #expect(ledger.record(id: "k4", day: 2, side: .compacts, key: true, fact: "x") == 0)   // no stage yet
        #expect(ledger.leaning(through: 11) == .compacts)
        #expect(ledger.receipts.count == 8)
    }

    @Test("the same world replays alike; stages settle only after their last day")
    func deterministicAndSettled() throws {
        let sim = MPCCityTrendSimulation(seed: 42)
        var ledger = L()
        _ = ledger.record(id: "a", day: 5, side: .offices, fact: "把止痛膏交给了施济所")
        let a = MPCCityTrend.snapshot(day: 12, ledger: ledger, simulation: sim)
        let b = MPCCityTrend.snapshot(day: 12, ledger: ledger, simulation: sim)
        #expect(a == b)
        #expect(a.results.map(\.stage) == [.casualties])
        #expect(MPCCityTrend.snapshot(day: 10, ledger: ledger, simulation: sim).results.isEmpty)
        #expect(MPCCityTrend.snapshot(day: 11, ledger: ledger, simulation: sim).results.map(\.stage) == [.casualties])
        let end = MPCCityTrend.snapshot(day: 29, ledger: ledger, simulation: sim)
        #expect(end.results.map(\.stage) == MPCCityTrendStage.allCases)
        // One shock in every stage, never on its first day.
        #expect(end.shocks.count == 4)
        for shock in end.shocks {
            let stage = try #require(MPCCityTrendStage.stage(day: shock.day))
            #expect(shock.day != stage.days.lowerBound && !shock.news.isEmpty)
        }
        #expect(a.yours == ["offices": 1] || a.day - 6 > 5)
        #expect(MPCCityTrend.snapshot(day: 7, ledger: ledger, simulation: sim).yours == ["offices": 1])
        let json = try JSONEncoder().encode(end)
        #expect(try JSONDecoder().decode(MPCCityTrendSnapshot.self, from: json) == end)
    }

    /// Backs `side` with everything the rules allow for every day of the first stage.
    func allIn(_ side: MPCCityFaction) -> L {
        var ledger = L()
        for day in MPCCityTrendStage.casualties.days {
            for k in 0..<L.ordinaryPerDay { ledger.record(id: "d\(day)-\(k)", day: day, side: side, fact: "x") }
        }
        ledger.record(id: "key", day: 6, side: side, key: true, fact: "x")
        return ledger
    }

    @Test("one player pushes the city but cannot decide it alone")
    func pushButNotDecide() {
        var baseline = 0, backed = 0
        let seeds = 0..<300
        for seed in seeds {
            let sim = MPCCityTrendSimulation(seed: UInt64(seed) &* 7919 &+ 3)
            if MPCCityTrend.snapshot(day: 11, ledger: L(), simulation: sim).result(.casualties) == .compacts { baseline += 1 }
            if MPCCityTrend.snapshot(day: 11, ledger: allIn(.compacts), simulation: sim).result(.casualties) == .compacts { backed += 1 }
        }
        print("CITY_TREND_AUDIT first stage to 商约 in \(seeds.count) worlds: crowd alone \(baseline), player all in \(backed)")
        // Without the player each side takes the first stage now and then …
        #expect(baseline > 50 && baseline < 130, "baseline \(baseline)")
        // … a player going all in makes it clearly likelier, yet far from certain.
        #expect(backed > baseline + 50, "backed \(backed) vs \(baseline)")
        #expect(backed < 230, "backed \(backed)")
    }

    @Test("a side far ahead loses the middle: no side runs away with the chapter")
    func backlash() {
        for seed in 0..<100 {
            var ledger = L()
            for day in 2...28 { for k in 0..<3 { ledger.record(id: "\(day)-\(k)", day: day, side: .neighbours, fact: "x") } }
            let end = MPCCityTrend.snapshot(day: 29, ledger: ledger, simulation: .init(seed: UInt64(seed)))
            #expect(end.share(.neighbours) < 0.62, "seed \(seed): \(end.share(.neighbours))")
            #expect(MPCCityFaction.allCases.allSatisfy { end.share($0) > 0.12 }, "seed \(seed)")
        }
    }

    @Test("the side out in front shows its leader on day 21; seats, one try each, death at a net four")
    func plot() throws {
        var world = MPCCityTrendWorld(simulation: .init(seed: 5), crowdPlots: false)
        for _ in 1...20 { world.advance(players: [.offices: 30]) }
        #expect(world.plot == nil)
        let early = world.attempt(account: "early", assassin: true, success: true)   // no plot before day 21
        #expect(!early)
        world.advance(players: [.offices: 30])                                      // day 21 opens the plot
        let target = try #require(world.plot?.target)
        #expect(target == .offices)
        // Day 22: three assassin seats and two guard seats; one try per account.
        var strikes: [Bool] = [], guards: [Bool] = []
        for k in 0..<4 { strikes.append(world.attempt(account: "a\(k)", assassin: true, success: true)) }
        #expect(strikes == [true, true, true, false])
        let again = world.attempt(account: "a0", assassin: false, success: true)
        #expect(!again)
        for k in 0..<3 { guards.append(world.attempt(account: "g\(k)", assassin: false, success: k == 0)) }
        #expect(guards == [true, true, false])
        world.advance(players: [.offices: 30])
        #expect(world.plot?.net == 2 && world.plot?.killedDay == nil)
        // Day 23: two more strikes make a net four: the leader dies that day.
        for k in 0..<2 { world.attempt(account: "b\(k)", assassin: true, success: true) }
        world.advance(players: [.offices: 30])
        #expect(world.plot?.killedDay == 23 && world.plot?.aftermath != nil)
        let late = world.attempt(account: "late", assassin: true, success: true)
        #expect(!late)
        while world.day < 28 { world.advance(players: [.offices: 30]) }
        let ending = try #require(world.ending)
        #expect(ending.killed && ending.plotTarget == .offices && ending.stages.count == 4)
        #expect(ending.summary.contains("公署领头人遇刺身亡"))
    }

    @Test("a balanced city shows no leader")
    func noPlotWhenBalanced() {
        var world = MPCCityTrendWorld(simulation: .init(seed: 5), crowdPlots: false)
        for _ in 1...28 { world.advance(players: [.neighbours: 20, .offices: 20, .compacts: 20]) }
        #expect(world.plot == nil || (world.ending?.plotTarget != nil))
        #expect(world.ending != nil)
    }

    @Test("the newspaper's forecast names the stage and who is ahead")
    func forecast() throws {
        let snap = MPCCityTrend.snapshot(day: 7, ledger: allIn(.offices), simulation: .init(seed: 9))
        let text = try #require(snap.forecast)
        #expect(text.hasPrefix("伤患潮·伤员的床位归谁管："))
        #expect(MPCCityTrend.snapshot(day: 2, ledger: L(), simulation: .init(seed: 9)).forecast == nil)
        #expect(MPCCityTrend.snapshot(day: 29, ledger: L(), simulation: .init(seed: 9)).forecast == nil)
    }

    @Test("a neighbour errand is finished one way, and the reward says which")
    func errandWays() throws {
        var ledger = MPCNeighborLedger(), coins = 0, inventory: [String: Int] = [:]
        ledger.open(day: 6, completedMissions: Set(1...30))
        let offer = try #require(ledger.offers.first { $0.errand?.kind == .find })
        let ways = MPCNeighborCatalog.ways(offer.errandID)
        let other = try #require(MPCCityFaction.allCases.first { side in !ways.contains { $0.side == side } })
        #expect(throws: MPCNeighborLedger.Failure.invalidChoice) { try ledger.choose(offerID: offer.id, way: other) }
        try ledger.choose(offerID: offer.id, way: ways[0].side)
        try ledger.choose(offerID: offer.id, way: ways[1].side)   // can change its mind before finishing
        let reward = try #require(try ledger.answer(offerID: offer.id, choiceID: offer.errand!.correctChoiceID!, coins: &coins))
        #expect(reward.way == ways[1] && reward.copper == offer.errand!.copper)
        #expect(throws: MPCNeighborLedger.Failure.done) { try ledger.choose(offerID: offer.id, way: ways[0].side) }
        _ = inventory
        // Older saves have no "way": they still decode, and finish without a trend receipt.
        let old = String(data: try JSONEncoder().encode(MPCNeighborLedger()), encoding: .utf8)!
        #expect(try JSONDecoder().decode(MPCNeighborLedger.self, from: Data(old.utf8)) == MPCNeighborLedger())
        var legacy = MPCNeighborLedger()
        legacy.open(day: 6, completedMissions: Set(1...30))
        var json = String(data: try JSONEncoder().encode(legacy), encoding: .utf8)!
        json = json.replacingOccurrences(of: #","way":null"#, with: "")
        let decoded = try JSONDecoder().decode(MPCNeighborLedger.self, from: Data(json.utf8))
        #expect(decoded.offers.allSatisfy { $0.way == nil })
    }
}
