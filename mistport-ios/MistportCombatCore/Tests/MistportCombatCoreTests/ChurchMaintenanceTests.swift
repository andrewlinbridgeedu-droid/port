import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Church maintenance requires three independently settled sites")
struct ChurchMaintenanceTests {
    @Test func everyMaintenanceSiteUsesOnlySixDemonsAlreadyIntroduced() throws {
        for floor in stride(from: 10, through: 100, by: 10) {
            let seen = Set(MPCChurchTowerCatalog.floors.filter { $0.number <= floor }.flatMap { $0.waves.flatMap { $0.map(\.species) } })
            for site in 1...3 {
                let encounter = try #require(MPCChurchMaintenanceCatalog.encounter(id: "church_maintenance_j2_f\(floor)_s\(site)_six"))
                for id in encounter.waves.flatMap(\.enemyIDs) {
                    let enemy = try #require(MPCChurchTowerCatalog.enemyConfiguration(contentID: id))
                    #expect(enemy.species != .riftHound && seen.contains(enemy.species))
                }
            }
        }
        for site in 1...3 {
            let encounter = try #require(MPCChurchMaintenanceCatalog.encounter(id: "church_maintenance_j1_s\(site)_six"))
            #expect(encounter.waves.flatMap(\.enemyIDs).allSatisfy {
                let species = MPCChurchTowerCatalog.enemyConfiguration(contentID: $0)?.species
                return species == .shieldJaw || species == .saltSac
            })
        }
    }
    func prepared(_ kind: MPCChurchMaintenanceKind, id: String = "work") throws -> MPCChurchMaintenanceLedger {
        var ledger = MPCChurchMaintenanceLedger()
        let job = try ledger.accept(kind: kind, floor: 10, completedMissions: [9], clearedTowerFloors: Set(1...10), jobID: id)
        for objective in job.objectives {
            let wrong = try ledger.verify(jobID: id, objectiveID: objective.id, choiceID: objective.choices[1].id)
            #expect(!wrong)
            _ = try ledger.verify(jobID: id, objectiveID: objective.id, choiceID: objective.correctChoiceID)
        }
        return ledger
    }
    func finish(_ ledger: inout MPCChurchMaintenanceLedger, id: String = "work") throws {
        while !ledger.jobs[id]!.allSitesComplete {
            let site = ledger.jobs[id]!.currentSite
            let battleID = "\(id)-site-\(site)"
            _ = try ledger.beginBattle(jobID: id, battleID: battleID)
            _ = try ledger.settleBattle(jobID: id, battleID: battleID, outcome: .victory)
            if site < 3 { #expect(try ledger.claim(jobID: id) == nil) }
        }
    }
    @Test func entryGatesAndNoButtonOnlyPayout() throws {
        var ledger = MPCChurchMaintenanceLedger()
        #expect(throws: MPCChurchMaintenanceError.locked) { try ledger.accept(kind: .patrol, completedMissions: [8], clearedTowerFloors: []) }
        #expect(throws: MPCChurchMaintenanceError.invalidFloor) { try ledger.accept(kind: .towerMaintenance, floor: 1, completedMissions: [30], clearedTowerFloors: Set(1...100)) }
        #expect(throws: MPCChurchMaintenanceError.invalidFloor) { try ledger.accept(kind: .towerMaintenance, floor: 20, completedMissions: [30], clearedTowerFloors: [10,20]) }
        let job = try ledger.accept(kind: .patrol, completedMissions: [9], clearedTowerFloors: [], jobID: "gate")
        #expect(throws: MPCChurchMaintenanceError.missingObjective) { try ledger.beginBattle(jobID: job.id, battleID: "early") }
        #expect(try ledger.claim(jobID: job.id) == nil)
    }
    @Test func allThreeSitesRequiredAndTotalRewardUnchanged() throws {
        for kind in MPCChurchMaintenanceKind.allCases {
            var ledger = try prepared(kind)
            var encounters = Set<String>(), enemies = Set<String>()
            var count = 0
            for site in 1...3 {
                #expect(ledger.jobs["work"]!.currentSite == site)
                let id = try ledger.beginBattle(jobID: "work", battleID: "fight\(site)")
                let e = try #require(MPCChurchMaintenanceCatalog.encounter(id: id))
                encounters.insert(id)
                #expect(e.waves.count == (kind == .patrol ? 2 : 3))
                for w in e.waves { count += w.enemyIDs.count; for eid in w.enemyIDs { #expect(enemies.insert(eid).inserted); #expect(MPCChurchTowerCatalog.enemyDefinition(id: eid) != nil) } }
                #expect(e.fixedRewardItemIDs.isEmpty && e.firstClearRelicID == nil)
                _ = try ledger.settleBattle(jobID: "work", battleID: "fight\(site)", outcome: .victory)
                if site < 3 { #expect(try ledger.claim(jobID: "work") == nil); #expect(ledger.jobs["work"]!.successfulBattleID == nil) }
            }
            #expect(encounters.count == 3 && count == (kind == .patrol ? 9 : 12))
            let result = try ledger.claim(jobID: "work")
            let reward = try #require(result)
            #expect(reward.copper == (kind == .patrol ? 60 : 80) && reward.merit == (kind == .patrol ? 6 : 8))
            #expect(try ledger.claim(jobID: "work") == nil)
        }
    }
    @Test func retreatCannotAdvanceAndPartialSuccessSurvivesReload() throws {
        var ledger = try prepared(.patrol)
        _ = try ledger.beginBattle(jobID: "work", battleID: "retreat")
        _ = try ledger.settleBattle(jobID: "work", battleID: "retreat", outcome: .retreat)
        let duplicate = try ledger.settleBattle(jobID: "work", battleID: "retreat", outcome: .victory)
        #expect(!duplicate && ledger.jobs["work"]!.currentSite == 1)
        _ = try ledger.beginBattle(jobID: "work", battleID: "first")
        _ = try ledger.settleBattle(jobID: "work", battleID: "first", outcome: .victory)
        ledger = try JSONDecoder().decode(MPCChurchMaintenanceLedger.self, from: JSONEncoder().encode(ledger))
        #expect(ledger.jobs["work"]!.completedSites == [1] && ledger.jobs["work"]!.currentSite == 2)
        #expect(try ledger.claim(jobID: "work") == nil)
        #expect(throws: MPCChurchMaintenanceError.invalidBattle) { try ledger.beginBattle(jobID: "work", battleID: "first") }
        try finish(&ledger)
        #expect(try ledger.claim(jobID: "work")?.copper == 60)
    }
    @Test func newContractRequiresFreshObjectivesAndBattleIDs() throws {
        var ledger = try prepared(.towerMaintenance)
        try finish(&ledger); _ = try ledger.claim(jobID: "work")
        let next = try ledger.accept(kind: .towerMaintenance, floor: 10, completedMissions: [], clearedTowerFloors: Set(1...10), jobID: "next")
        #expect(next.completedSites.isEmpty && next.completedObjectiveIDs.isEmpty)
        #expect(throws: MPCChurchMaintenanceError.missingObjective) { try ledger.beginBattle(jobID: "next", battleID: "new") }
        for o in next.objectives { _ = try ledger.verify(jobID: next.id, objectiveID: o.id, choiceID: o.correctChoiceID) }
        #expect(throws: MPCChurchMaintenanceError.invalidBattle) { try ledger.beginBattle(jobID: "next", battleID: "work-site-1") }
        try finish(&ledger, id: "next")
        #expect(try ledger.claim(jobID: "next")?.merit == 8)
    }
    @Test func malformedSiteAndUnreleasedSectorAreRejected() {
        #expect(MPCChurchMaintenanceCatalog.encounter(id: "church_maintenance_j2_f101_s1_bad") == nil)
        #expect(MPCChurchMaintenanceCatalog.encounter(id: "church_maintenance_j1_s4_bad") == nil)
        #expect(MPCChurchMaintenanceCatalog.encounter(id: "church_maintenance_j2_f1_s1_bad") == nil)
    }
    @Test func oldSingleFloorJobRemainsPlayableWithoutGrantingFutureSpecies() throws {
        let data = Data(#"{"id":"old","kind":"towerMaintenance","floor":1,"successfulBattleID":"old-win","claimed":false}"#.utf8)
        let job = try JSONDecoder().decode(MPCChurchMaintenanceJob.self, from: data)
        #expect(job.completedSites == [1] && job.currentSite == 2 && job.successfulBattleID == nil)
        let encounter = try #require(MPCChurchMaintenanceCatalog.encounter(id: job.encounterID))
        #expect(encounter.waves.count == 3)
        for id in encounter.waves.flatMap(\.enemyIDs) {
            #expect(MPCChurchTowerCatalog.enemyConfiguration(contentID: id)?.species == .shieldJaw)
        }
    }

}
