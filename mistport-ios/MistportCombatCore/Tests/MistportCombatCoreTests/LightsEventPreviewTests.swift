import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Lights event preview: facts pick the articles, contract table")
struct LightsEventPreviewTests {
    typealias P = MPCLightsEventPreview
    let done = P.Ledger(raised: 1200, investors: 10, installedKits: 12, orderedKits: 0, publicScore: 30, successfulAccounts: 5)

    func ledger(score: Int, qualified: Bool = true) -> P.Ledger {
        P.Ledger(raised: 1200, investors: 10, installedKits: qualified ? 12 : 11, orderedKits: 0,
                 publicScore: score, successfulAccounts: 5)
    }

    @Test func everyFixtureIsConsistentAndLabelled() throws {
        #expect(Set(P.fixtures.map(\.id)).count == P.fixtures.count)
        for fixture in P.fixtures { try fixture.validate() }
        let settled = P.fixtures.filter { $0.phase == .settled }
        #expect(settled.allSatisfy { P.articles(for: $0).map(\.id) == ["L01", "L02", "L03", "L04", "L05", "L06", "L07", "L08"] })
    }

    @Test func articlesFollowTheCalendar() {
        let ids = P.fixtures.map { P.articles(for: $0).map(\.id).last! }
        #expect(ids == ["L03", "L05", "L06", "L08", "L08", "L08"])
        let core = P.Snapshot(id: "core", label: "", phase: .core, pumps: done, shipping: done)
        #expect(P.articles(for: core).last?.id == "L07")
    }

    // The eight contract cases the event design requires.
    @Test(arguments: [
        (40, 30, true, true, false, false, "pumps"),
        (30, 40, true, true, false, false, "shipping"),
        (35, 35, true, true, false, false, "interim-tie"),
        (40, 30, true, true, true, false, "shipping"),
        (30, 40, true, true, false, true, "pumps"),
        (40, 30, true, true, true, true, "interim-bothDead"),
        (40, 30, false, true, false, false, "shipping"),
        (40, 30, false, false, false, false, "interim-noneQualified"),
    ])
    func contractTable(pScore: Int, sScore: Int, pq: Bool, sq: Bool, aida: Bool, rowan: Bool, expected: String) throws {
        let result = try P.contract(pumps: ledger(score: pScore, qualified: pq), shipping: ledger(score: sScore, qualified: sq),
                                    aidaDead: aida, rowanDead: rowan)
        let label: String = switch result {
        case .awarded(let f): f.rawValue
        case .interim(let r): "interim-\(r.rawValue)"
        }
        #expect(label == expected)
    }

    @Test func unreachableDeathsAreRefused() {
        #expect(throws: P.Failure.unreachableOutcome) {
            try P.contract(pumps: ledger(score: 1, qualified: false), shipping: ledger(score: 1, qualified: false), aidaDead: true, rowanDead: false)
        }
        #expect(throws: P.Failure.unreachableOutcome) {
            try P.contract(pumps: ledger(score: 1), shipping: ledger(score: 1, qualified: false), aidaDead: true, rowanDead: true)
        }
        let early = P.Snapshot(id: "x", label: "", phase: .publicAction(day: 8), pumps: done, shipping: done, aidaDead: true)
        #expect(throws: P.Failure.unreachableOutcome) { try early.validate() }
    }

    @Test func deadSideWithoutSurvivorQualificationGoesInterim() throws {
        let result = try P.contract(pumps: ledger(score: 40), shipping: ledger(score: 10, qualified: false), aidaDead: true, rowanDead: false)
        #expect(result == .interim(.noneQualified))
    }

    @Test func orderArticleNeverPromisesUnfundedOrders() {
        let broke = P.Ledger(raised: 120, investors: 1, installedKits: 2, orderedKits: 0)
        let funded = P.Ledger(raised: 600, investors: 5, installedKits: 3, orderedKits: 4)
        let s = P.Snapshot(id: "o", label: "", phase: .preparation(day: 3), pumps: funded, shipping: broke)
        let l03 = P.articles(for: s).first { $0.id == "L03" }!
        #expect(l03.variant == "有资金 / 预算不足")
        #expect(l03.paragraphs.contains { $0.contains("过滤布8件") })
        #expect(l03.paragraphs.contains { $0.contains("灰帆联营项目：尚无可付款的新订单") })
        #expect(funded.cash == 600 - 180 - 240 && funded.fundableKits == 3)
    }

    @Test func ledgerRejectsOverspendAndOverCap() {
        #expect(!P.Ledger(raised: 100, investors: 1, installedKits: 2, orderedKits: 0).isConsistent)
        #expect(!P.Ledger(raised: 1300, investors: 20, installedKits: 0, orderedKits: 0).isConsistent)
        #expect(!P.Ledger(raised: 240, investors: 1, installedKits: 0, orderedKits: 0).isConsistent)
        #expect(!P.Ledger(raised: 1200, investors: 10, installedKits: 10, orderedKits: 3).isConsistent)
    }

    @Test func coreOpportunitiesFollowQualificationAndScore() {
        #expect(P.coreOpportunities(pumps: ledger(score: 9), shipping: ledger(score: 3)) == [.pumps: 6, .shipping: 4])
        #expect(P.coreOpportunities(pumps: ledger(score: 3), shipping: ledger(score: 3)) == [.pumps: 5, .shipping: 5])
        #expect(P.coreOpportunities(pumps: ledger(score: 1, qualified: false), shipping: ledger(score: 0)) == [.pumps: 0, .shipping: 6])
    }
}
