import Foundation
import Testing
@testable import MistportCombatCore

@Suite("City contribution: capped sources, four tiers, one-time migration")
struct CityContributionTests {
    typealias C = MPCCityContribution

    @Test func tiersAreOrderedAndEveryFeatureHasOne() {
        #expect(C.tiers.map(\.threshold) == C.tiers.map(\.threshold).sorted())
        #expect(C.tiers.first?.threshold == 0)
        for feature in C.Feature.allCases { #expect(C.tiers.filter { $0.opens.contains(feature) }.count == 1) }
        #expect(C.tier(points: 0).level == 1 && C.tier(points: 119).level == 1 && C.tier(points: 120).level == 2)
        #expect(C.tier(points: 300).level == 4 && C.nextTier(points: 300) == nil)
        #expect(!C.isOpen(.cityCommission, points: 299) && C.isOpen(.cityCommission, points: 300))
    }

    @Test func receiptsPayOnceAndCappedSourcesStopForTheDay() {
        var ledger = MPCCityContributionLedger()
        let awards: [(String, MPCCityContribution.Source, Int)] = [
            ("errand-1", .errand, 3), ("errand-1", .errand, 3),
            ("post-1", .post, 3), ("post-2", .post, 3), ("post-3", .post, 3),
            // A new day counts again.
            ("post-4", .post, 4),
            ("event-1", .eventBattle, 4), ("event-2", .eventBattle, 4), ("event-3", .eventBattle, 4),
            ("bounty-b07", .bounty, 4),
        ]
        var added: [Int] = []
        for (id, source, day) in awards { added.append(ledger.record(receiptID: id, source: source, day: day)) }
        #expect(added == [2, 0, 1, 1, 0, 1, 1, 1, 0, 10])
        #expect(ledger.points == 17)
    }

    @Test func migrationConvertsOldProgressOnce() throws {
        var ledger = MPCCityContributionLedger()
        let first = ledger.migrate(completedMissions: 12, closedBounties: 2, completedErrands: 5)
        #expect(first && ledger.points == 12 * 2 + 2 * 10 + 5 * 2 && ledger.migratedPoints == 54)
        let second = ledger.migrate(completedMissions: 30, closedBounties: 10, completedErrands: 50)
        #expect(!second)
        #expect(ledger.points == 54 && ledger.tier.level == 1)
        let stored = try JSONDecoder().decode(MPCCityContributionLedger.self, from: JSONEncoder().encode(ledger))
        #expect(stored == ledger)
    }

    @Test func progressTextNamesTheNextTier() {
        #expect(C.progressText(points: 12) == "城市贡献度 12／120 · 新来的，下一档“熟面孔”")
        #expect(C.progressText(points: 310) == "城市贡献度 310 · 雾港的帮手")
    }
}
