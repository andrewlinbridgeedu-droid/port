import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Daily bounty issue and defeat stakes")
struct DailyBountyBoardTests {
    @Test func issueIsStableDiverseAndBetweenThreeAndSix() {
        let ids = MPCChurchBountyCatalog.all.map(\.id)
        for day in [20260925, 20260926, 20260927, 20260928, 20260929, 20260930,
                    20261001, 20261002, 20261003, 20261004, 20261005] {
            let first = MPCDailyBountyRotation.issue(dayOrdinal: day, eligibleIDs: ids)
            let reopened = MPCDailyBountyRotation.issue(dayOrdinal: day, eligibleIDs: ids.reversed())
            #expect(first == reopened)
            #expect((3...6).contains(first.offerIDs.count))
            #expect(Set(first.offerIDs).count == first.offerIDs.count)
            #expect(Set(first.offerIDs).isSubset(of: Set(ids)))
            #expect(!Set(first.offerIDs).isDisjoint(with: ["b01", "b07", "b08"]))
            #expect(!Set(first.offerIDs).isDisjoint(with: ["b02", "b03", "b04", "b09"]))
            #expect(!Set(first.offerIDs).isDisjoint(with: ["b05", "b06", "b10"]))
        }
        let next = MPCDailyBountyRotation.issue(dayOrdinal: 20260926, eligibleIDs: ids)
        #expect(MPCDailyBountyRotation.issue(dayOrdinal: 20260925, eligibleIDs: ids) != next)
    }

    @Test func issueNeverResurrectsClosedOrAcceptedSuspects() {
        let remaining = ["b02", "b05", "b09", "b10"]
        let issue = MPCDailyBountyRotation.issue(dayOrdinal: 20260925, eligibleIDs: remaining)
        #expect(Set(issue.offerIDs).isSubset(of: Set(remaining)))
        #expect((3...4).contains(issue.offerIDs.count))
        #expect(MPCDailyBountyRotation.issue(dayOrdinal: 20260925, eligibleIDs: []).offerIDs.isEmpty)
    }

    @Test func defeatLossIsBoundedRepeatableAndOnlyCostsCopper() {
        var sawCopper = false
        var sawNeither = false
        for index in 0..<1_000 {
            let battleID = "bounty-risk-\(index)"
            let loss = MPCBountyDefeatRisk.loss(battleID: battleID, availableCopper: 1_000,
                                                carriedOrdinaryRelicIDs: ["ordinary-a"])
            #expect(loss == MPCBountyDefeatRisk.loss(battleID: battleID, availableCopper: 1_000,
                                                      carriedOrdinaryRelicIDs: ["ordinary-a"]))
            #expect(loss.copper == 0 || loss.copper == 60)
            #expect(loss.relicID == nil)
            sawCopper = sawCopper || loss.copper > 0
            sawNeither = sawNeither || loss.copper == 0
        }
        #expect(sawCopper && sawNeither)
        let empty = MPCBountyDefeatRisk.loss(battleID: "empty", availableCopper: 0,
                                             carriedOrdinaryRelicIDs: [])
        #expect(empty.copper == 0 && empty.relicID == nil)
    }

    @Test func investigationNoLongerRequiresChapterMission() throws {
        var ledger = MPCChurchBountyLedger()
        let bounty = try #require(MPCChurchBountyCatalog.bounty(id: "b10"))
        _ = try ledger.visit(bounty.id, location: "教会", completedMissions: [])
        #expect(try ledger.accept(bounty.id, completedMissions: []))
        _ = try ledger.visit(bounty.id, location: bounty.nodes[0].location, completedMissions: [])
        _ = try ledger.investigate(bounty.id, nodeID: bounty.nodes[0].id, completedMissions: [])
        #expect(ledger.cases[bounty.id]?.evidenceIDs.contains("witness") == true)
    }
}
