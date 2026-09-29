import Testing
import Foundation
@testable import MistportCombatCore

@Suite("Home street task targets")
struct StreetTaskTargetTests {
    @Test func unacceptedAndClosedCasesNeverSummonCitizens() throws {
        var ledger = MPCChurchBountyLedger()
        #expect(MPCStreetTaskCatalog.bountyTargets(ledger).isEmpty)
        var closed = MPCChurchBountyProgress(); closed.accepted = true; closed.claimed = true
        ledger = try fixture(closed)
        #expect(MPCStreetTaskCatalog.bountyTargets(ledger).isEmpty)
    }
    @Test func investigationExposesOnlyRuleEligibleSteps() throws {
        var ledger = MPCChurchBountyLedger()
        var progress = MPCChurchBountyProgress(); progress.accepted = true
        ledger = try fixture(progress)
        let initial = MPCStreetTaskCatalog.bountyTargets(ledger)
        #expect(initial.contains { $0.id == "b07:witness" })
        #expect(initial.contains { $0.id == "b07:wound" })
        #expect(!initial.contains { $0.id == "b07:identity" })
        progress.evidenceIDs = ["witness", "wound", "exclude", "compare"]
        ledger = try fixture(progress)
        #expect(MPCStreetTaskCatalog.bountyTargets(ledger).contains { $0.placeID == "b07" })
    }
    @Test func victoryPointsToTurnInWithoutAnotherReward() throws {
        var ledger = MPCChurchBountyLedger()
        var progress = MPCChurchBountyProgress(); progress.accepted = true; progress.victoriousBattleID = "settled"
        ledger = try fixture(progress)
        let before = ledger
        #expect(MPCStreetTaskCatalog.bountyTargets(ledger).map(\.placeID) == ["church"])
        #expect(ledger == before)
    }
    @Test(arguments: [("b04", "witness", "cityhall"), ("b04", "wound", "cityhall"),
                      ("b08", "witness", "cityhall"), ("b09", "witness", "cityhall"),
                      ("b10", "witness", "church"), ("b02", "wound", "church"),
                      ("b01", "exclude", "police")])
    func publicCountersRemainReachable(caseID: String, nodeID: String, placeID: String) throws {
        var progress = MPCChurchBountyProgress(); progress.accepted = true
        if nodeID == "exclude" { progress.evidenceIDs = ["witness", "wound"] }
        let ledger = try JSONDecoder().decode(MPCChurchBountyLedger.self, from: JSONEncoder().encode(["cases": [caseID: progress]]))
        let target = try #require(MPCStreetTaskCatalog.bountyTargets(ledger).first { $0.id == caseID + ":" + nodeID })
        #expect(target.personID == nil)
        #expect(target.placeID == placeID)
    }
    private func fixture(_ progress: MPCChurchBountyProgress) throws -> MPCChurchBountyLedger {
        try JSONDecoder().decode(MPCChurchBountyLedger.self, from: JSONEncoder().encode(["cases": ["b07": progress]]))
    }

}
