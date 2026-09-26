import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Ten church bounty evidence and settlement chains")
struct ChurchBountiesTests {
    private func go(_ ledger: inout MPCChurchBountyLedger, _ b: MPCChurchBounty, _ location: String) throws {
        _ = try ledger.visit(b.id,location:location,completedMissions:[b.unlockMission])
    }
    private func observe(_ ledger: inout MPCChurchBountyLedger, _ b: MPCChurchBounty, _ id: String) throws {
        let node = try #require(b.nodes.first(where:{$0.id == id}))
        try go(&ledger,b,node.location)
        _ = try ledger.investigate(b.id,nodeID:id,completedMissions:[b.unlockMission])
    }
    private func prepareBattle(_ ledger: inout MPCChurchBountyLedger, _ b: MPCChurchBounty) throws {
        try go(&ledger,b,MPCChurchBountyLedger.churchLocation)
        _ = try ledger.accept(b.id,completedMissions:[b.unlockMission])
        try observe(&ledger,b,"wound")
        try observe(&ledger,b,"witness")
        if b.id == "b03" || b.id == "b08" {
            try go(&ledger,b,b.id == "b03" ? "沉船档案柜" : "港务登记处")
            _ = try ledger.inspectAlternativeLead(b.id,completedMissions:[b.unlockMission])
        }
        try observe(&ledger,b,"compare")
        let compare = try #require(MPCChurchBountyCatalog.challenge(caseID:b.id,nodeID:"compare"))
        _ = try ledger.answer(b.id,nodeID:"compare",choiceID:compare.correctChoiceID,completedMissions:[b.unlockMission])
        try observe(&ledger,b,"identity")
        _ = try ledger.inspectSiteFeature(b.id,featureID:"appearance",completedMissions:[b.unlockMission])
        _ = try ledger.inspectSiteFeature(b.id,featureID:"conduct",completedMissions:[b.unlockMission])
        let identity = try #require(MPCChurchBountyCatalog.challenge(caseID:b.id,nodeID:"identity"))
        _ = try ledger.answer(b.id,nodeID:"identity",choiceID:identity.correctChoiceID,completedMissions:[b.unlockMission])
        _ = try ledger.presentWarrant(b.id,suspectID:b.enemyID,supportingEvidenceIDs:["witness","wound"])
    }
    @Test func allCasesHaveIndependentIdentityAndExactRewardBudget() throws {
        #expect(MPCChurchBountyCatalog.all.count == 10)
        #expect(Set(MPCChurchBountyCatalog.all.map(\.enemyID)).count == 10)
        #expect(MPCChurchBountyCatalog.all.reduce(0) {$0+$1.copper} == 1060)
        #expect(MPCChurchBountyCatalog.all.reduce(0) {$0+$1.merit} == 222)
        for b in MPCChurchBountyCatalog.all {
            #expect(b.nodes.count == 5)
            #expect(b.enemyID.hasPrefix("bounty_"))
            #expect(MPCChurchBountyCatalog.encounter(id:b.encounterID)?.fixedRewardItemIDs.isEmpty == true)
            let enemy = try #require(MPCChurchBountyCatalog.enemyDefinition(id:b.enemyID))
            #expect(!enemy.skills.isEmpty)
            var ledger = MPCChurchBountyLedger()
            try prepareBattle(&ledger,b)
            #expect(ledger.cases[b.id]?.evidenceIDs.contains("exclude") == false)
            let encounter = try ledger.beginBattle(b.id,battleID:"run-"+b.id)
            #expect(encounter == b.encounterID)
            _ = try ledger.settleBattle(b.id,battleID:"run-"+b.id,outcome:.victory)
            #expect(ledger.cases[b.id]?.pendingTurnIn == true)
            #expect(throws:MPCChurchBountyError.wrongLocation) { try ledger.claim(b.id) }
            try go(&ledger,b,MPCChurchBountyLedger.tavernLocation)
            let reward = try #require(try ledger.claim(b.id))
            #expect(reward.copper == b.copper && reward.merit == b.merit)
            #expect(try ledger.claim(b.id) == nil)
            #expect(throws:MPCChurchBountyError.alreadyClosed) { try ledger.beginBattle(b.id,battleID:"respawn") }
        }
    }
    @Test func missingEvidenceNeverAllowsAttackAndMisleadingBranchIsPersistent() throws {
        var ledger = MPCChurchBountyLedger()
        #expect(throws:MPCChurchBountyError.wrongLocation) { try ledger.accept("b01",completedMissions:[]) }
        let b = try #require(MPCChurchBountyCatalog.bounty(id:"b01"))
        try go(&ledger,b,MPCChurchBountyLedger.churchLocation)
        _ = try ledger.accept("b01",completedMissions:[])
        #expect(throws:MPCChurchBountyError.wrongLocation) { try ledger.investigate("b01",nodeID:"identity",completedMissions:[7]) }
        try observe(&ledger,b,"identity")
        #expect(ledger.cases["b01"]?.evidenceIDs.contains("identity") == false)
        #expect(throws:MPCChurchBountyError.unverifiedIdentity) { try ledger.beginBattle("b01",battleID:"attack") }
        try observe(&ledger,b,"exclude")
        #expect(ledger.cases["b01"]?.evidenceIDs.contains("exclude") == false)
        try observe(&ledger,b,"witness")
        try observe(&ledger,b,"wound")
        ledger = try JSONDecoder().decode(MPCChurchBountyLedger.self,from:JSONEncoder().encode(ledger))
        #expect(ledger.cases["b01"]?.evidenceIDs.contains("exclude") == true)
        try observe(&ledger,b,"exclude")
        #expect(ledger.cases["b01"]?.evidenceIDs.count == 3)
        #expect(ledger.cases["b01"]?.visitedLocations.contains("巡逻值房") == true)
    }
    @Test func interruptionRetreatRetryAndRewardCannotBeForged() throws {
        var ledger = MPCChurchBountyLedger()
        let b = MPCChurchBountyCatalog.all[0]
        try prepareBattle(&ledger,b)
        _ = try ledger.beginBattle(b.id,battleID:"first")
        ledger = try JSONDecoder().decode(MPCChurchBountyLedger.self,from:JSONEncoder().encode(ledger))
        #expect(try ledger.beginBattle(b.id,battleID:"first") == b.encounterID)
        #expect(throws:MPCChurchBountyError.battlePending) { try ledger.beginBattle(b.id,battleID:"second") }
        _ = try ledger.settleBattle(b.id,battleID:"first",outcome:.retreat)
        let duplicate = try ledger.settleBattle(b.id,battleID:"first",outcome:.victory)
        #expect(!duplicate)
        #expect(throws:MPCChurchBountyError.invalidBattle) { try ledger.claim(b.id) }
        #expect(throws:MPCChurchBountyError.invalidBattle) { try ledger.beginBattle(b.id,battleID:"first") }
        _ = try ledger.beginBattle(b.id,battleID:"second")
        _ = try ledger.settleBattle(b.id,battleID:"second",outcome:.defeat)
        #expect(throws:MPCChurchBountyError.invalidBattle) { try ledger.claim(b.id) }
        _ = try ledger.beginBattle(b.id,battleID:"third")
        _ = try ledger.settleBattle(b.id,battleID:"third",outcome:.victory)
        try go(&ledger,b,MPCChurchBountyLedger.churchLocation)
        let reward = try ledger.claim(b.id)
        #expect(reward?.copper == 60)
    }
    @Test func wrongWarrantDoesNotEraseSourcesOrOpenBattle() throws {
        let b = try #require(MPCChurchBountyCatalog.bounty(id:"b07"))
        var ledger = MPCChurchBountyLedger()
        try go(&ledger,b,MPCChurchBountyLedger.churchLocation)
        _ = try ledger.accept(b.id,completedMissions:[b.unlockMission])
        try observe(&ledger,b,"witness")
        try observe(&ledger,b,"wound")
        try observe(&ledger,b,"compare")
        let compare = try #require(MPCChurchBountyCatalog.challenge(caseID:b.id,nodeID:"compare"))
        let wrong = try ledger.answer(b.id,nodeID:"compare",choiceID:compare.choices[1].id,completedMissions:[b.unlockMission])
        #expect(!wrong)
        #expect(ledger.cases[b.id]?.evidenceIDs.contains("compare") == false)
        #expect(ledger.cases[b.id]?.observations["witness"]?.source == "夜班邮差")
        _ = try ledger.answer(b.id,nodeID:"compare",choiceID:compare.correctChoiceID,completedMissions:[b.unlockMission])
        try observe(&ledger,b,"identity")
        _ = try ledger.inspectSiteFeature(b.id,featureID:"appearance",completedMissions:[b.unlockMission])
        let identity = try #require(MPCChurchBountyCatalog.challenge(caseID:b.id,nodeID:"identity"))
        #expect(throws:MPCChurchBountyError.missingEvidence) {
            try ledger.answer(b.id,nodeID:"identity",choiceID:identity.correctChoiceID,completedMissions:[b.unlockMission])
        }
        _ = try ledger.inspectSiteFeature(b.id,featureID:"conduct",completedMissions:[b.unlockMission])
        _ = try ledger.answer(b.id,nodeID:"identity",choiceID:identity.correctChoiceID,completedMissions:[b.unlockMission])
        #expect(throws:MPCChurchBountyError.invalidWarrant) {
            try ledger.presentWarrant(b.id,suspectID:"innocent_worker",supportingEvidenceIDs:["witness","wound"])
        }
        #expect(throws:MPCChurchBountyError.warrantRequired) { try ledger.beginBattle(b.id,battleID:"forged") }
        #expect(ledger.cases[b.id]?.evidenceIDs.contains("identity") == true)
        #expect(throws:MPCChurchBountyError.invalidWarrant) {
            try ledger.presentWarrant(b.id,suspectID:b.enemyID,supportingEvidenceIDs:["witness","compare"])
        }
        _ = try ledger.presentWarrant(b.id,suspectID:b.enemyID,supportingEvidenceIDs:["witness","wound"])
        try go(&ledger,b,MPCChurchBountyLedger.churchLocation)
        #expect(throws:MPCChurchBountyError.wrongLocation) { try ledger.beginBattle(b.id,battleID:"remote") }
        try go(&ledger,b,b.nodes.first(where:{$0.id == "identity"})!.location)
        #expect(try ledger.beginBattle(b.id,battleID:"real") == b.encounterID)
    }
    @Test func optionalPokerCanLoseRetryOrUsePublicRecords() throws {
        for id in ["b03","b08"] {
            let b = try #require(MPCChurchBountyCatalog.bounty(id:id))
            var ledger = MPCChurchBountyLedger()
            try go(&ledger,b,MPCChurchBountyLedger.tavernLocation)
            _ = try ledger.accept(id,completedMissions:[b.unlockMission])
            try observe(&ledger,b,"wound")
            try observe(&ledger,b,"witness")
            try observe(&ledger,b,"compare")
            let challenge = try #require(MPCChurchBountyCatalog.challenge(caseID:id,nodeID:"compare"))
            #expect(throws:MPCChurchBountyError.missingLead) {
                try ledger.answer(id,nodeID:"compare",choiceID:challenge.correctChoiceID,completedMissions:[b.unlockMission])
            }
            try go(&ledger,b,id == "b03" ? "码头" : MPCChurchBountyLedger.tavernLocation)
            #expect(try ledger.playPoker(id,won:false,completedMissions:[b.unlockMission]) == false)
            #expect(ledger.cases[id]?.pokerLosses == 1)
            ledger = try JSONDecoder().decode(MPCChurchBountyLedger.self,from:JSONEncoder().encode(ledger))
            #expect(try ledger.playPoker(id,won:true,completedMissions:[b.unlockMission]) == true)
            try go(&ledger,b,b.nodes.first(where:{$0.id == "compare"})!.location)
            #expect(try ledger.answer(id,nodeID:"compare",choiceID:challenge.correctChoiceID,completedMissions:[b.unlockMission]))

            var archive = MPCChurchBountyLedger()
            try go(&archive,b,MPCChurchBountyLedger.churchLocation)
            _ = try archive.accept(id,completedMissions:[b.unlockMission])
            try observe(&archive,b,"witness")
            try observe(&archive,b,"wound")
            try go(&archive,b,id == "b03" ? "沉船档案柜" : "港务登记处")
            _ = try archive.inspectAlternativeLead(id,completedMissions:[b.unlockMission])
            try observe(&archive,b,"compare")
            #expect(try archive.answer(id,nodeID:"compare",choiceID:challenge.correctChoiceID,completedMissions:[b.unlockMission]))
        }
    }
    @Test func preCityClaimedAndRunningSavesMigrateWithoutSecondReward() throws {
        let oldClaimed = Data(#"{"cases":{"b07":{"accepted":true,"evidenceIDs":["witness","wound","compare","identity"],"excludedChoiceIDs":[],"victoriousBattleID":"old-win","settledBattleIDs":["old-win"],"claimed":true}}}"#.utf8)
        var paid = try JSONDecoder().decode(MPCChurchBountyLedger.self,from:oldClaimed)
        #expect(paid.cases["b07"]?.claimed == true)
        #expect(try paid.claim("b07") == nil)
        let oldRunning = Data(#"{"cases":{"b07":{"accepted":true,"evidenceIDs":["witness","wound","compare","identity"],"excludedChoiceIDs":[],"activeBattleID":"old-run","settledBattleIDs":[],"claimed":false}}}"#.utf8)
        var running = try JSONDecoder().decode(MPCChurchBountyLedger.self,from:oldRunning)
        #expect(running.cases["b07"]?.warrantPresented == true)
        #expect(try running.beginBattle("b07",battleID:"old-run") == "church_bounty_b07")
        _ = try running.settleBattle("b07",battleID:"old-run",outcome:.victory)
        #expect(running.cases["b07"]?.pendingTurnIn == true)
        _ = try running.visit("b07",location:"教会",completedMissions:[5])
        #expect(try running.claim("b07")?.receiptID == "bounty-close-b07")
        running = try JSONDecoder().decode(MPCChurchBountyLedger.self,from:JSONEncoder().encode(running))
        #expect(try running.claim("b07") == nil)
    }
}
