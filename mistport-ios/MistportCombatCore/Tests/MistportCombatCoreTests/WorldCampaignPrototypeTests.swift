import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Isolated world campaign: irreversible facts and conserved assets")
struct WorldCampaignPrototypeTests {
    typealias World = MPCWorldCampaignPrototype
    func world() throws -> World {
        try .init(definition: .init(id: "fixture", actionStart: 10, actionEnd: 30, grace: 2,
                                  ticketLifetime: 10, supplyTarget: 2, perimeterWins: 1),
                  accounts: ["p": .init(copper: 100), "p2": .init(copper: 0), "s": .init(copper: 100),
                             "seller": .init(copper: 0, tradeableKits: 4, boundMedicine: 99),
                             "boundOnly": .init(copper: 0, boundMedicine: 99)], treasury: 200)
    }
    /// Direct damage is a settlement fixture, never a gameplay balance measurement.
    func win(_ input: World.Battle) throws -> World.Battle {
        var b = input
        for _ in 0..<50 where b.session.outcome == .inProgress {
            for enemy in b.session.enemies.filter(\.isAlive) {
                _ = try b.session.applyPartyDamage(1_000_000, to: enemy.id)
            }
            if b.session.outcome == .inProgress {
                for enemy in b.session.enemies.filter(\.isAlive) {
                    try b.session.endRound(actingEnemyID: enemy.id, at: 0)
                }
            }
        }
        try #require(b.session.outcome == .victory)
        return b
    }
    func prepared() throws -> World {
        var w = try world()
        try w.join(accountID: "p", faction: .pumps, now: 0)
        try w.join(accountID: "p2", faction: .pumps, now: 0)
        try w.join(accountID: "s", faction: .shipping, now: 0)
        try w.sellKits(id: "goods-p", seller: "seller", faction: .pumps, quantity: 2, now: 1)
        try w.sellKits(id: "goods-s", seller: "seller", faction: .shipping, quantity: 2, now: 1)
        return w
    }
    func open(_ faction: World.Faction, world w: inout World) throws {
        let b = try w.beginBattle(accountID: faction == .pumps ? "p" : "s", route: .perimeter, loadout: .init(), now: 10)
        _ = try w.settleBattle(win(b), now: 11)
    }
    @Test func investmentsAndPurchasesAreAtomicTransfersWithSourceRestrictions() throws {
        var w = try world()
        let opening = w
        #expect(throws: World.Failure.funds) { try w.invest(id: "bad", accountID: "p", faction: .pumps, amount: 101, now: 0) }
        #expect(w == opening)
        try w.invest(id: "deposit", accountID: "p", faction: .pumps, amount: 50, now: 1)
        let funded = w
        #expect(try !w.invest(id: "deposit", accountID: "p", faction: .pumps, amount: 50, now: 2))
        #expect(w == funded)
        #expect(throws: World.Failure.conflict) { try w.invest(id: "deposit", accountID: "p", faction: .pumps, amount: 49, now: 2) }
        #expect(throws: World.Failure.conflict) { try w.join(accountID: "p", faction: .shipping, now: 2) }
        #expect(throws: World.Failure.stock) { try w.sellKits(id: "bound", seller: "boundOnly", faction: .pumps, quantity: 1, now: 2) }
        #expect(w == funded)
        try w.sellKits(id: "goods", seller: "seller", faction: .pumps, quantity: 2, now: 2)
        #expect(try !w.sellKits(id: "goods", seller: "seller", faction: .pumps, quantity: 2, now: 3))
        #expect(w.money == w.openingMoney && w.accountedKits == w.openingKits)
        #expect(w.accounts["seller"]?.copper == 32)
        #expect(w.accounts["seller"]?.boundMedicine == 99)
        let full = w
        #expect(throws: World.Failure.closed) { try w.sellKits(id: "extra", seller: "seller", faction: .pumps, quantity: 1, now: 3) }
        #expect(w == full)
    }
    @Test func simultaneousCoreVictoriesKillOnceAndPublishOnlyCommittedFacts() throws {
        var w = try prepared()
        #expect(throws: World.Failure.locked) { try w.beginBattle(accountID: "p", route: .core, loadout: .init(), now: 10) }
        try open(.pumps, world: &w)
        let first = try w.beginBattle(accountID: "p", route: .core, loadout: .init(), now: 12)
        let second = try w.beginBattle(accountID: "p2", route: .core, loadout: .init(), now: 12)
        let a = try win(first), b = try win(second)
        #expect(try w.settleBattle(a, now: 13).changedWorld)
        #expect(try !w.settleBattle(b, now: 14).changedWorld)
        let after = w
        #expect(try w.settleBattle(a, now: 15).changedWorld) // original receipt, not a second side effect
        #expect(w == after)
        #expect(w.news.filter { $0.kind == .death }.count == 1)
        #expect(w.projects[.shipping]?.successorRequired == true)
        #expect(w.projects[.pumps]?.consumedForBreach == 2)
        #expect(w.accountedKits == w.openingKits)
        #expect(throws: World.Failure.locked) { try w.beginBattle(accountID: "p", route: .core, loadout: .init(), now: 15) }
        let settlement = try w.finish(now: 33)
        #expect(settlement.winner == .pumps)
        #expect(settlement.retainedKits[.shipping] == 2)
        #expect(w.money == w.openingMoney)
        #expect(Set(w.news.map(\.id)).count == w.news.count)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        print("CAMPAIGN_FLOW " + String(decoding: try encoder.encode(w), as: UTF8.self))
    }
    @Test func doubleDeathHasSuccessorsAndNeverTwoExclusiveContracts() throws {
        var w = try prepared()
        // Open both routes without rewinding the host clock.
        let p = try w.beginBattle(accountID: "p", route: .perimeter, loadout: .init(), now: 10)
        let s = try w.beginBattle(accountID: "s", route: .perimeter, loadout: .init(), now: 10)
        _ = try w.settleBattle(win(p), now: 11); _ = try w.settleBattle(win(s), now: 11)
        let pc = try w.beginBattle(accountID: "p", route: .core, loadout: .init(), now: 12)
        let sc = try w.beginBattle(accountID: "s", route: .core, loadout: .init(), now: 12)
        _ = try w.settleBattle(win(pc), now: 13); _ = try w.settleBattle(win(sc), now: 13)
        #expect(try w.finish(now: 33).winner == nil)
        #expect(w.news.filter { $0.kind == .death }.count == 2)
        #expect(w.projects.values.allSatisfy { $0.successorRequired })
        #expect(w.money == w.openingMoney && w.accountedKits == w.openingKits)
    }
    @Test func frozenGraceWindowAndReloadKeepLateResultsConsistent() throws {
        var w = try prepared(); try open(.pumps, world: &w)
        let b = try win(w.beginBattle(accountID: "p", route: .core, loadout: .init(), now: 29))
        w = try JSONDecoder().decode(World.self, from: JSONEncoder().encode(w))
        #expect(throws: World.Failure.closed) { try w.finish(now: 31) }
        #expect(throws: World.Failure.closed) { try w.beginBattle(accountID: "s", route: .perimeter, loadout: .init(), now: 30) }
        _ = try w.settleBattle(b, now: 32)
        #expect(try w.finish(now: 33).winner == .pumps)
        let final = w
        #expect(try w.finish(now: 100) == final.settlement)
        #expect(w == final)
    }
    @Test func expiredAndUnfinishedBattlesHaveNoSideEffects() throws {
        var w = try prepared()
        let b = try w.beginBattle(accountID: "p", route: .perimeter, loadout: .init(), now: 10)
        let before = w
        #expect(throws: World.Failure.unverified) { try w.settleBattle(b, now: 11) }
        #expect(throws: World.Failure.expired) { try w.settleBattle(win(b), now: 23) }
        #expect(w == before)
        #expect(w.projects[.pumps]?.perimeterVictories == 0)
    }
    @Test func refundsDoNotInventInterestOrDestroyUnsoldAssets() throws {
        var w = try world()
        try w.invest(id: "p-invest", accountID: "p", faction: .pumps, amount: 100, now: 1)
        try w.sellKits(id: "goods", seller: "seller", faction: .pumps, quantity: 2, now: 2)
        // 168 remaining / 200 capital: investor 84, treasury 84. Other project returns 100.
        let result = try w.finish(now: 33)
        #expect(result.refunds["p"] == 84 && result.treasuryReturned == 184)
        #expect(result.retainedKits[.pumps] == 2)
        #expect(result.winner == nil)
        #expect(w.money == 400 && w.accountedKits == 4)
        #expect(try !w.invest(id: "p-invest", accountID: "p", faction: .pumps, amount: 100, now: 34))
    }
}
