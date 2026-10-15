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
        try ledger.inspectProject(project.id, originalSeal: true, now: 1)
        try ledger.deliverProject(project.id, now: 2)
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
}
