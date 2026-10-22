import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Institutions: finite money, contracts and lodging preparation")
struct CityEconomyTests {
    @Test("repeat term: exact seven days, reserve, no double interest, free early exit", arguments: [60, 120])
    func repeatTerm(_ amount: Int) throws {
        var ledger = MPCCityEconomy(), cash = 1_000
        let completed = Set(1...16)
        #expect(throws: MPCCityEconomy.Failure.funds) {
            try ledger.openTermDeposit(amount, completed: completed, liquidReserve: 1_001 - amount, now: 0, coins: &cash)
        }
        #expect(cash == 1_000 && ledger.termDeposit == nil && ledger.bankBonusBudget == 240)
        try ledger.openTermDeposit(amount, completed: completed, liquidReserve: 1_000 - amount, now: 0, coins: &cash)
        #expect(throws: MPCCityEconomy.Failure.limit) {
            try ledger.openTermDeposit(amount, completed: completed, liquidReserve: 0, now: 1, coins: &cash)
        }
        let id = ledger.termDeposit?.id
        ledger = try JSONDecoder().decode(MPCCityEconomy.self, from: JSONEncoder().encode(ledger))
        ledger.settle(now: 7 * 86_400 - 1, coins: &cash); #expect(cash == 1_000 - amount)
        ledger.settle(now: 7 * 86_400, coins: &cash); ledger.settle(now: 7 * 86_400, coins: &cash)
        #expect(cash == 1_000 + amount / 60 && ledger.outstanding == 0)
        try ledger.openTermDeposit(amount, completed: completed, liquidReserve: 0, now: 7 * 86_400, coins: &cash)
        #expect(ledger.termDeposit?.id != id)
        try ledger.redeemTermDeposit(now: 8 * 86_400, coins: &cash)
        ledger.settle(now: 100 * 86_400, coins: &cash)
        #expect(cash == 1_000 + amount / 60 && ledger.bankBonusBudget + ledger.bankBonusPaid == 240)
    }
    @Test("money that arrives on its own is listed once for the morning paper")
    func arrivals() throws {
        var ledger = MPCCityEconomy(), cash = 1_000
        try ledger.openTermDeposit(60, completed: Set(1...16), liquidReserve: 0, now: 0, coins: &cash)
        try ledger.openProject(kind: .invoice, amount: 40, completed: [1, 5], day: 1, now: 0, coins: &cash)
        let id = try #require(ledger.projects.first?.id)
        try ledger.inspectProject(id, originalSeal: true, now: 1); try ledger.deliverProject(id, now: 2)
        ledger.settle(now: 6 * 86_400, coins: &cash)
        #expect(ledger.arrivals(after: 0).isEmpty)
        ledger.settle(now: 7 * 86_400, coins: &cash); ledger.settle(now: 7 * 86_400 + 5, coins: &cash)
        let arrived = ledger.arrivals(after: 6 * 86_400)
        #expect(arrived.map(\.coins).sorted() == [42, 61])
        #expect(arrived.map(\.coins).reduce(0, +) == cash - (1_000 - 100))
        #expect(ledger.arrivals(after: 7 * 86_400).isEmpty)
        // A ledger written before arrivals existed decodes with none.
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
        object.removeValue(forKey: "arrivals")
        let restored = try JSONDecoder().decode(MPCCityEconomy.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(restored.arrivals == nil && restored.arrivals(after: 0).isEmpty && restored.outstanding == 0)
    }
    @Test("old bank ledger retains money, welcome receipt and investments when term field absent")
    func oldLedger() throws {
        var ledger = MPCCityEconomy(), cash = 1_000
        try ledger.save(20, coins: &cash)
        try ledger.openDeposit(60, completed: [1], now: 0, coins: &cash)
        try ledger.openProject(kind: .invoice, amount: 40, completed: [1, 5], day: 1, now: 0, coins: &cash)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
        object.removeValue(forKey: "termDeposit")
        let restored = try JSONDecoder().decode(MPCCityEconomy.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(restored == ledger && restored.outstanding == 100 && cash == 880)
    }
    @Test("industries require both mission and reputation; escrow pays only accepted delivery", arguments: [MPCCityEconomy.ProjectKind.bicycle, .shipping])
    func industries(_ kind: MPCCityEconomy.ProjectKind) throws {
        var ledger = MPCCityEconomy(), cash = 1_000
        #expect(throws: MPCCityEconomy.Failure.locked) {
            try ledger.openProject(kind: kind, amount: kind.minimum, completed: [1], reputation: 999, day: 1, now: 0, coins: &cash)
        }
        #expect(throws: MPCCityEconomy.Failure.locked) {
            try ledger.openProject(kind: kind, amount: kind.minimum, completed: Set(1...kind.mission), reputation: kind.reputation - 1, day: 1, now: 0, coins: &cash)
        }
        try ledger.openProject(kind: kind, amount: kind.minimum, completed: Set(1...kind.mission), reputation: kind.reputation, day: 1, now: 0, coins: &cash)
        let project = try #require(ledger.projects.first)
        if kind == .bicycle {
            let slip = try #require(project.bicycle?.correctSlip)
            try ledger.bicycleIssueParts(project.id, slip: slip, now: 1)
            try ledger.bicycleSourceHub(project.id, hireRunner: false, now: 1, coins: &cash)
            try ledger.bicycleTestRide(project.id, replaceRivets: false, now: 1, coins: &cash)
            try ledger.bicycleAnswerExpansion(project.id, accept: false, completed: Set(1...kind.mission), now: 1, coins: &cash)
            try ledger.bicycleDeliver(project.id, now: 2)
        } else {
            try ledger.inspectProject(project.id, originalSeal: true, now: 1)
            try ledger.deliverProject(project.id, now: 2)
        }
        ledger.settle(now: Double(kind.days) * 86_400 - 1, coins: &cash)
        #expect(cash == 1_000 - kind.minimum)
        ledger.settle(now: Double(kind.days) * 86_400, coins: &cash)
        ledger.settle(now: Double(kind.days) * 86_400, coins: &cash)
        #expect(cash == 1_000 + kind.repayment(kind.minimum) - kind.minimum)
        #expect(ledger.customerBudget + ledger.contractPaid == 2_400)
    }
    @Test("one lifetime deposit, exact 72h, principal safely exits", arguments: [20, 40, 60])
    func deposit(_ amount: Int) throws {
        var ledger = MPCCityEconomy(), cash = 180
        try ledger.openDeposit(amount, completed: [1], now: 100, coins: &cash)
        ledger.settle(now: 100 + 72 * 3_600 - 1, coins: &cash)
        #expect(cash == 180 - amount)
        let restored = try JSONDecoder().decode(MPCCityEconomy.self, from: JSONEncoder().encode(ledger))
        ledger = restored
        ledger.settle(now: 100 + 72 * 3_600, coins: &cash)
        #expect(cash == 180 + amount / 20 * 4)
        ledger.settle(now: 999_999, coins: &cash)
        #expect(cash == 180 + amount / 20 * 4)
        #expect(throws: MPCCityEconomy.Failure.limit) { try ledger.openDeposit(20, completed: [1], now: 999_999, coins: &cash) }
        var early = MPCCityEconomy(), earlyCash = 180
        try early.openDeposit(amount, completed: [1], now: 0, coins: &earlyCash)
        try early.redeemDeposit(now: 71 * 3_600, coins: &earlyCash)
        #expect(earlyCash == 180 && early.bankBonusBudget == 240 && early.bankBonusPaid == 0)
    }
    @Test("risk principal lost on bad acceptance or missed deadline; no added debt", arguments: [0, 1, 2])
    func project(_ path: Int) throws {
        var ledger = MPCCityEconomy(), cash = 180
        try ledger.openProject(kind: .invoice, amount: 40, completed: [5], day: 3, now: 0, coins: &cash)
        let id = try #require(ledger.projects.first?.id)
        if path != 2 {
            try ledger.inspectProject(id, originalSeal: path == 0, now: 50)
            try ledger.deliverProject(id, now: 60)
        }
        ledger.settle(now: 7 * 86_400, coins: &cash)
        if path == 0 { #expect(cash == 182) }
        else if path == 1 { #expect(cash == 140) }
        else { #expect(cash == 140 && ledger.projects[0].settled == false) }
        ledger.settle(now: 10 * 86_400 + 1, coins: &cash)
        #expect(cash == (path == 0 ? 182 : 140))
        #expect(ledger.outstanding == 0 && ledger.projectInputs == 40)
        ledger.settle(now: 99 * 86_400, coins: &cash)
        #expect(cash == (path == 0 ? 182 : 140))
        #expect(ledger.customerBudget + ledger.contractPaid == 2_400)
    }
    @Test("ordinary home can earn a contract; escrow spends only after actual delivery")
    func publicContract() throws {
        var ledger = MPCCityEconomy(), cash = 180
        try ledger.invite(privateRoom: false, lodgingID: "dock_bunk", completed: Set(1...13), now: 0, coins: &cash)
        #expect(cash == 178)
        #expect(throws: MPCCityEconomy.Failure.evidence) { try ledger.verifyMeeting(evidence: ["delivery_receipt", "anonymous_rumor"]) }
        try ledger.verifyMeeting(evidence: ["delivery_receipt", "original_seal"])
        #expect(throws: MPCCityEconomy.Failure.terms) { try ledger.contract(inspectFirst: false, payOnDelivery: true, limitedLiability: true, now: 5, coins: &cash) }
        #expect(cash == 178 && ledger.meetingEscrow.isEmpty)
        try ledger.contract(inspectFirst: true, payOnDelivery: true, limitedLiability: true, now: 5, coins: &cash)
        #expect(cash == 158 && ledger.customerBudget == 2_360)
        #expect(throws: MPCCityEconomy.Failure.stage) { try ledger.deliverGoods(now: 10) }
        try ledger.collectGoods(now: 10); try ledger.sealGoods(original: true, now: 20); try ledger.deliverGoods(now: 30)
        ledger.settle(now: 86_429, coins: &cash); #expect(cash == 158)
        ledger.settle(now: 86_430, coins: &cash); #expect(cash == 198)
        ledger.settle(now: 999_999, coins: &cash); #expect(cash == 198)
        #expect(ledger.customerBudget + ledger.contractPaid == 2_400)
        #expect(throws: MPCCityEconomy.Failure.limit) { try ledger.invite(privateRoom: false, lodgingID: "dock_bunk", completed: Set(1...13), now: 100_000, coins: &cash) }
    }
    @Test("private eligibility and cancelled inputs do not return fabricated copper")
    func cancelContract() throws {
        var ledger = MPCCityEconomy(), cash = 180
        #expect(throws: MPCCityEconomy.Failure.locked) { try ledger.invite(privateRoom: true, lodgingID: "dock_bunk", completed: Set(1...13), now: 0, coins: &cash) }
        try ledger.invite(privateRoom: true, lodgingID: "canal_house", completed: Set(1...13), now: 0, coins: &cash)
        try ledger.verifyMeeting(evidence: ["delivery_receipt", "original_seal"])
        try ledger.contract(inspectFirst: true, payOnDelivery: true, limitedLiability: true, now: 1, coins: &cash)
        try ledger.cancelMeeting()
        #expect(cash == 146 && ledger.customerBudget == 2_400)
        #expect(ledger.supplierReceipts == 30 && ledger.hostingReceipts == 4)
    }
    @Test("only bonus overflow is banked, no double count; downgrade keeps earned reserve")
    func reserve() throws {
        var stamina = MPCStaminaState(at: 0, recoveryPerDay: 120)
        #expect(stamina.reserve(at: 86_400) == 20)
        try stamina.spend(points: 35, receiptID: "task", at: 86_400)
        #expect(stamina.value == 65 && stamina.restReserve == 20)
        stamina.returnHome(at: 86_400)
        #expect(stamina.value == 85 && stamina.restReserve == 0)
        #expect(stamina.reserve(at: 2 * 86_400) == 17.5)
        stamina.setRecovery(perDay: 100, at: 2 * 86_400)
        #expect(stamina.reserve(at: 10 * 86_400) == 17.5)
        let old = Data(#"{"value":60,"settledAt":0,"recoveryPerDay":100,"receipts":["old"]}"#.utf8)
        let restored = try JSONDecoder().decode(MPCStaminaState.self, from: old)
        #expect(restored.restReserve == 0 && restored.receipts == ["old"])
    }
    @Test("preparation once per day, no rent-switch refresh, failure consumes and no permanent gear")
    func rest() throws {
        var ledger = MPCCityEconomy()
        try ledger.prepareRest(day: 10, lodgingID: "canal_house")
        #expect(ledger.restBonus(day: 10) == 300 && ledger.restBonus(day: 11) == 0)
        #expect(ledger.consumeRest(battleID: "battle", day: 10) == 300)
        #expect(ledger.consumeRest(battleID: "battle", day: 10) == 300)
        #expect(ledger.consumeRest(battleID: "retry", day: 10) == 0)
        #expect(throws: MPCCityEconomy.Failure.limit) { try ledger.prepareRest(day: 10, lodgingID: "highland_house") }
        #expect(ledger.maintenanceCredit(day: 10, lodgingID: "canal_house", fee: 6) == 1)
        #expect(ledger.maintenanceCredit(day: 10, lodgingID: "highland_house", fee: 10) == 0)
        var loadout = MPCChapterOneLoadout(); loadout.housingRestBP = 300
        let session = try MPCChapterOneEncounterSession.start(encounterID: "encounter_rain_01", loadout: loadout)
        #expect(session.playerBaseMaxHP == 1_030 && loadout.churchGear.maxHP == 0)
    }
    @Test("chapter copper total preserved; earned materials and ritual remain mandatory")
    func progression() throws {
        #expect((1...30).compactMap(MPCChapterOneThirtyMissionContract.firstClear(for:)).map(\.copper).reduce(0,+) == 2_280)
        #expect(MPCAdvancementMaterialMarket.offers.map(\.price).reduce(0,+) + MPCSequenceEightRitual.fee == 2_400)
        var cash = 2_399, materials: Set<String> = []
        for offer in MPCAdvancementMaterialMarket.offers {
            let purchase = try #require(MPCAdvancementMaterialMarket.purchase(offer.id, completedMissionNumbers: Set(1...30), coins: cash, ownedIDs: materials))
            cash = purchase.coins; materials = purchase.ownedIDs
        }
        #expect(cash == 299)
        #expect(throws: MPCSequenceEightRitual.Failure.funds) {
            try MPCSequenceEightRitual.perform(id: "rite", completedMissions: Set(1...30), coins: &cash, ingredients: &materials,
                inventory: Dictionary(uniqueKeysWithValues: MPCSequenceEightRitual.proofIDs.map { ($0, 1) }), existing: nil)
        }
        #expect(materials.count == 3 && cash == 299)
    }

    // MARK: 自行车厂首批订单

    private func signedBicycle(_ cash: inout Int, amount: Int = 60) throws -> (MPCCityEconomy, String, Int) {
        var ledger = MPCCityEconomy()
        try ledger.openProject(kind: .bicycle, amount: amount, completed: Set(1...16), reputation: 120, day: 1, now: 0, coins: &cash)
        let project = try #require(ledger.projects.first)
        return (ledger, project.id, try #require(project.bicycle?.correctSlip))
    }

    @Test("bicycle order: three bikes, right slip, fetched hub, tightened brakes -> 69 at term")
    func bicycleHappyPath() throws {
        var cash = 1_000
        var (ledger, id, slip) = try signedBicycle(&cash)
        #expect(ledger.projects[0].bicycle?.bikes == 3 && ledger.outstanding == 60)
        #expect(throws: MPCCityEconomy.Failure.stage) { try ledger.inspectProject(id, originalSeal: true, now: 1) }
        #expect(throws: MPCCityEconomy.Failure.stage) { try ledger.bicycleDeliver(id, now: 1) }
        try ledger.bicycleIssueParts(id, slip: slip, now: 1)
        try ledger.bicycleSourceHub(id, hireRunner: false, now: 1, coins: &cash)
        #expect(try ledger.bicycleTestRide(id, replaceRivets: false, now: 1, coins: &cash))
        #expect(throws: MPCCityEconomy.Failure.terms) { try ledger.bicycleDeliver(id, now: 1) }
        try ledger.bicycleAnswerExpansion(id, accept: false, completed: Set(1...16), now: 1, coins: &cash)
        #expect(throws: MPCCityEconomy.Failure.duplicate) { try ledger.bicycleAnswerExpansion(id, accept: true, completed: Set(1...16), now: 1, coins: &cash) }
        try ledger.bicycleDeliver(id, now: 2)
        ledger = try JSONDecoder().decode(MPCCityEconomy.self, from: JSONEncoder().encode(ledger))
        ledger.settle(now: 10 * 86_400 - 1, coins: &cash); #expect(cash == 940)
        ledger.settle(now: 10 * 86_400, coins: &cash); ledger.settle(now: 11 * 86_400, coins: &cash)
        #expect(cash == 1_009 && ledger.outstanding == 0)
        #expect(ledger.customerBudget + ledger.contractPaid == 2_400)
    }

    @Test("bicycle order: the wrong slip's iron rivets fail every test until replaced (6 copper)")
    func bicycleWrongSlip() throws {
        var cash = 1_000
        var (ledger, id, slip) = try signedBicycle(&cash)
        try ledger.bicycleIssueParts(id, slip: 1 - slip, now: 1)
        try ledger.bicycleSourceHub(id, hireRunner: true, now: 1, coins: &cash)
        #expect(cash == 936)
        #expect(try ledger.bicycleTestRide(id, replaceRivets: false, now: 1, coins: &cash) == false)
        #expect(try ledger.bicycleTestRide(id, replaceRivets: false, now: 1, coins: &cash) == false)
        #expect(ledger.projects[0].bicycle?.stage == .testing && ledger.projects[0].bicycle?.failedTests == 2)
        #expect(try ledger.bicycleTestRide(id, replaceRivets: true, now: 1, coins: &cash))
        try ledger.bicycleAnswerExpansion(id, accept: false, completed: Set(1...16), now: 1, coins: &cash)
        try ledger.bicycleDeliver(id, now: 1)
        ledger.settle(now: 10 * 86_400, coins: &cash)
        // 60 + 4 runner + 6 rivets spent, 69 back: three copper left of the nine.
        #expect(cash == 1_000 - 70 + 69 && ledger.projects[0].bicycle?.extraCosts == 10)
        #expect(ledger.supplierReceipts == 10 && ledger.customerBudget + ledger.contractPaid == 2_400)
    }

    @Test("bicycle expansion: a fourth bike, 20 more in, 23 more escrowed -> 92 for 80")
    func bicycleExpansion() throws {
        var cash = 1_000
        var (ledger, id, slip) = try signedBicycle(&cash)
        try ledger.bicycleIssueParts(id, slip: slip, now: 1)
        try ledger.bicycleSourceHub(id, hireRunner: false, now: 1, coins: &cash)
        try ledger.bicycleTestRide(id, replaceRivets: false, now: 1, coins: &cash)
        try ledger.bicycleAnswerExpansion(id, accept: true, completed: Set(1...16), now: 1, coins: &cash)
        #expect(cash == 920 && ledger.outstanding == 80 && ledger.projects[0].bicycle?.bikes == 4)
        #expect(throws: MPCCityEconomy.Failure.stage) { try ledger.bicycleDeliver(id, now: 1) }
        try ledger.bicycleAssembleExtra(id, now: 1)
        try ledger.bicycleDeliver(id, now: 1)
        ledger.settle(now: 10 * 86_400, coins: &cash)
        #expect(cash == 1_012 && ledger.customerBudget + ledger.contractPaid == 2_400)
    }

    @Test("bicycle expansion respects the outstanding limit; refused offers change nothing")
    func bicycleExpansionLimit() throws {
        var cash = 1_000
        var (ledger, id, slip) = try signedBicycle(&cash, amount: 100)
        try ledger.bicycleIssueParts(id, slip: slip, now: 1)
        try ledger.bicycleSourceHub(id, hireRunner: false, now: 1, coins: &cash)
        try ledger.bicycleTestRide(id, replaceRivets: false, now: 1, coins: &cash)
        // Before Q16 the limit is 100: no room for another 20.
        #expect(throws: MPCCityEconomy.Failure.limit) {
            try ledger.bicycleAnswerExpansion(id, accept: true, completed: Set(1...13), now: 1, coins: &cash)
        }
        #expect(cash == 900 && ledger.projects[0].bicycle?.expansion == .open && ledger.outstanding == 100)
    }

    @Test("bicycle order missed past its three-day grace: committed capital lost, escrow back to the buyer")
    func bicycleMissed() throws {
        var cash = 1_000
        var (ledger, id, slip) = try signedBicycle(&cash)
        try ledger.bicycleIssueParts(id, slip: slip, now: 1)
        #expect(throws: MPCCityEconomy.Failure.deadline) {
            try ledger.bicycleSourceHub(id, hireRunner: false, now: 13 * 86_400 + 1, coins: &cash)
        }
        ledger.settle(now: 13 * 86_400 + 1, coins: &cash)
        #expect(cash == 940 && ledger.projects[0].settled && ledger.outstanding == 0)
        #expect(ledger.customerBudget == 2_400)
    }

    @Test("bicycle orders signed before the fulfilment flow keep inspect-and-deliver")
    func bicycleLegacyOrder() throws {
        var cash = 1_000
        var (ledger, _, _) = try signedBicycle(&cash)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
        var projects = try #require(object["projects"] as? [[String: Any]])
        projects[0].removeValue(forKey: "bicycle")
        object["projects"] = projects
        ledger = try JSONDecoder().decode(MPCCityEconomy.self, from: JSONSerialization.data(withJSONObject: object))
        let id = ledger.projects[0].id
        #expect(ledger.projects[0].bicycle == nil)
        try ledger.inspectProject(id, originalSeal: true, now: 1)
        try ledger.deliverProject(id, now: 2)
        ledger.settle(now: 10 * 86_400, coins: &cash)
        #expect(cash == 1_009)
    }
}
