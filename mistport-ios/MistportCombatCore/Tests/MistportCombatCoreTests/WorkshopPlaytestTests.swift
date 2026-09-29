import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Playable workshop slice, actual combat and finite accounting")
struct WorkshopPlaytestTests {
    func play(_ trial: inout MPCWorkshopPlaytest) throws {
        for tick in 1...3600 {
            guard let prior = trial.battle, !prior.isComplete else { break }
            try trial.advance(to: Double(tick)/20)
            guard let battle = trial.battle, !battle.isComplete else { break }
            let alive = battle.session.enemies.filter(\.isAlive)
            let target = alive.first { !$0.contentID.hasSuffix("_core") && $0.currentIntent != "guard" }
                ?? alive.first { $0.currentIntent != "guard" } ?? alive.first
            if let target { trial.target(target.id) }
            if battle.session.playerHP * 2 < battle.session.playerNormalMaxHP { _ = trial.useMedicine() }
            if let skill = battle.scheduler.next(in: battle.session.loadout.normalSkillIDs, at: battle.time) { _ = trial.cast(skill) }
            else { _ = trial.cast(nil) }
        }
        #expect(trial.canSettleBattle)
        try trial.settleBattle()
    }
    func stocked() throws -> MPCWorkshopPlaytest {
        var t = MPCWorkshopPlaytest(); try t.choose(.pumps); try t.begin(.tower)
        try play(&t)
        #expect(t.battles.last?.won == true)
        _ = try t.claimHide(id: "loot-1")
        return t
    }
    @Test func completeActualLoopAndConservation() throws {
        var t = try stocked()
        #expect(t.copper == 48 && t.hide == 1 && t.moneyConserved)
        #expect(t.battles[0].encounter == "church_tower_001")
        #expect(t.battles[0].initialEnemyIDs.allSatisfy { $0.hasPrefix("church_d01_") })
        _ = try t.craft(id: "batch-1")
        #expect(t.hide == 0 && t.straps == 3 && t.proficiency == 1 && t.copper == 35)
        _ = try t.sell(id: "sale-1", quantity: 2)
        #expect(t.straps == 1 && t.copper == 53 && t.projectCash == 480 && t.installed == 11)
        _ = try t.install(id: "install-1")
        #expect(t.projectStraps == 0 && t.installed == 12 && t.moneyConserved)
        try t.begin(.ordinary); try play(&t)
        #expect(t.battles.last?.won == true && t.publicPoints == 1)
        try t.close()
        #expect(t.winner == .pumps && t.straps == 1 && t.moneyConserved)
        let data = try JSONEncoder().encode(t.snapshots)
        #expect(try JSONDecoder().decode(MPCWorkshopPlaytest.Snapshot.self, from: data) == t.snapshots)
        print("WORKSHOP_FLOW " + String(decoding: data, as: UTF8.self))
    }
    @Test func towerVictoryAndUniqueReceiptRequired() throws {
        var t = MPCWorkshopPlaytest();try t.choose(.shipping)
        #expect(throws: MPCWorkshopPlaytest.Failure.locked) { try t.claimHide(id: "fake") }
        try t.begin(.tower)
        #expect(throws: MPCWorkshopPlaytest.Failure.unfinished) { try t.settleBattle() }
        try t.settleBattle(retreat: true)
        #expect(t.hide == 0 && !t.pendingHide && t.copper == 48)
        try t.begin(.tower);try play(&t)
        #expect(throws: MPCWorkshopPlaytest.Failure.locked) { try t.close() }
        let first = try t.claimHide(id: "once"), replay = try t.claimHide(id: "once")
        #expect(first && !replay && t.hide == 1)
        #expect(throws: MPCWorkshopPlaytest.Failure.locked) { try t.claimHide(id: "twice") }
        #expect(throws: MPCWorkshopPlaytest.Failure.conflict) { try t.craft(id: "once") }
    }
    @Test func failedCommandsAndDuplicatePaymentAreAtomic() throws {
        var t = try stocked()
        #expect(throws: MPCWorkshopPlaytest.Failure.locked) { try t.craft(id: "advanced", advanced: true) }
        _ = try t.craft(id: "craft")
        let after = t.snapshots
        #expect(try t.craft(id: "craft") == false)
        #expect(throws: MPCWorkshopPlaytest.Failure.stock) { try t.craft(id: "no-hide") }
        #expect(throws: MPCWorkshopPlaytest.Failure.closed) { try t.sell(id: "excess", quantity: 3) }
        #expect(t.snapshots == after)
        _ = try t.sell(id: "sale", quantity: 2)
        let paid = t.snapshots
        #expect(try t.sell(id: "sale", quantity: 2) == false)
        #expect(throws: MPCWorkshopPlaytest.Failure.conflict) { try t.sell(id: "sale", quantity: 1) }
        #expect(throws: MPCWorkshopPlaytest.Failure.closed) { try t.sell(id: "extra", quantity: 1) }
        #expect(t.snapshots == paid)
        _ = try t.install(id: "install")
        #expect(try t.install(id: "install") == false)
        #expect(throws: MPCWorkshopPlaytest.Failure.stock) { try t.install(id: "install2") }
        #expect(t.installed == 12 && t.moneyConserved)
    }
    @Test func medicinePurchaseIsTransferConsumptionIsActualAndNoSecondPublicTry() throws {
        var t = try stocked();_ = try t.craft(id: "craft");_ = try t.sell(id: "sale", quantity: 2);_ = try t.install(id: "install")
        _ = try t.buyMedicine(id: "m1")
        #expect(t.copper == 44 && t.supplierCash == 711 && t.external == 13)
        #expect(try t.buyMedicine(id: "m1") == false)
        try t.begin(.hard)
        let fullHPDose = t.useMedicine()
        #expect(!fullHPDose) // full HP does not consume
        for tick in 1...250 { try t.advance(to: Double(tick)/20) }
        let dose = t.useMedicine()
        let emptyDose = t.useMedicine()
        #expect(dose && !emptyDose)
        try t.settleBattle(retreat: true)
        #expect(t.medicines == 0 && t.battles.last?.medicineUsed == 1 && t.publicPoints == 0)
        #expect(throws: MPCWorkshopPlaytest.Failure.locked) { try t.begin(.ordinary) }
        try t.close();#expect(t.winner == .shipping && t.moneyConserved)
        #expect(throws: MPCWorkshopPlaytest.Failure.closed) { try t.craft(id: "after-close") }
    }
    @Test func busyCannotCraftPurchaseSwitchOrFakeSettle() throws {
        var t = MPCWorkshopPlaytest();try t.choose(.pumps);try t.begin(.tower)
        #expect(throws: MPCWorkshopPlaytest.Failure.busy) { try t.buyMedicine(id: "mid") }
        #expect(throws: MPCWorkshopPlaytest.Failure.busy) { try t.choose(.shipping) }
        #expect(throws: MPCWorkshopPlaytest.Failure.busy) { try t.begin(.tower) }
        #expect(throws: MPCWorkshopPlaytest.Failure.unfinished) { try t.settleBattle() }
        #expect(t.moneyConserved)
    }
    @Test func towerDriverStopsAtTimeoutAndUsesAuthoredTiming() throws {
        var a = try MPCCampaignBattleDriver(towerFloor: 1)
        var b = a
        try a.advance(to: 12)
        for i in 1...240 { try b.advance(to: Double(i)/20) }
        #expect(a.session == b.session)
        #expect(a.session.campaignPrototype == nil)
        try a.advance(to: 180)
        #expect(a.isComplete && !a.canAct && !a.canUseMedicine && !a.cast(nil))
    }
}
