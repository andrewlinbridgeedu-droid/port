import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Stamina, lodging and meals")
struct HousingStaminaTests {
    typealias H = MPCHousingCatalog

    @Test("stamina spends on the daily loop, never on story or church battles, and recovers to a cap")
    func staminaSpendsAndRecovers() throws {
        var s = MPCStaminaState(at: 0)
        #expect(s.available(at: 0) == 100)
        #expect(MPCStamina.cost(.storyOrChurch) == 0)
        try s.spend(.remnant, receiptID: "r-1", at: 0)
        #expect(try s.spend(.remnant, receiptID: "r-1", at: 0) == false, "a retried request spends once")
        #expect(s.available(at: 0) == 80)
        #expect(throws: MPCStaminaState.Failure.self) {
            var t = s
            for i in 0..<5 { try t.spend(.eventBattle, receiptID: "e-\(i)", at: 0) }
            try t.spend(.eventBattle, receiptID: "e-5", at: 0)
        }
        // 100 a day: 20 points take 4.8 hours; after a day it is full, not more.
        #expect(abs(s.secondsUntil(100, at: 0) - 4.8 * 3600) < 1)
        #expect(s.available(at: 86_400 * 3) == 100)
    }

    @Test("better lodging and meals recover faster, capped at +20; the basic basket is 12 copper")
    func recoveryByTier() {
        #expect(H.recoveryPerDay(lodgingID: "dock_bunk", mealID: "soup_shed") == 100)
        #expect(H.lodging("dock_bunk")!.copperPerDay + H.meal("soup_shed")!.copperPerDay == 12)
        #expect(H.recoveryPerDay(lodgingID: "canal_house", mealID: "bakery") == 109)
        #expect(H.recoveryPerDay(lodgingID: "highland_house", mealID: "house_kitchen") == 120)
        var s = MPCStaminaState(at: 0)
        try? s.spend(.cityCommission, receiptID: "c", at: 0)
        s.setRecovery(perDay: 120, at: 0)
        #expect(abs(s.secondsUntil(100, at: 0) - 35.0 / 120 * 86_400) < 1)
    }

    @Test("leases: limited rooms, the kitchen only with a highland house, the shelter is never leased")
    func leases() throws {
        var h = MPCHousingLedger()
        #expect(throws: MPCHousingLedger.Failure.noRoom) { try h.sign(lodgingID: "bell_loft", mealID: "cafe", day: 1, roomsLeft: 0) }
        #expect(throws: MPCHousingLedger.Failure.notAllowed) { try h.sign(lodgingID: "canal_house", mealID: "house_kitchen", day: 1, roomsLeft: 5) }
        #expect(throws: MPCHousingLedger.Failure.notAllowed) { try h.sign(lodgingID: "shelter", mealID: "church_soup", day: 1, roomsLeft: nil) }
        try h.sign(lodgingID: "canal_house", mealID: "bakery", day: 1, roomsLeft: 3)
        #expect(h.leaseEndsDay == 7)
        // Renewing one's own room does not need a free room.
        try h.sign(lodgingID: "canal_house", mealID: "cafe", day: 5, roomsLeft: 0)
    }

    @Test("the day's payment downgrades instead of going into debt, and the shelter is free below the line")
    func dailyPayment() throws {
        var h = MPCHousingLedger()
        try h.sign(lodgingID: "canal_house", mealID: "cafe", day: 1, roomsLeft: 3)
        var cash = 1_000
        let full = h.payDay(1, cash: &cash, completedMissions: 5)
        #expect(full.copper == 26 && !full.downgraded && cash == 974)
        #expect(h.payDay(1, cash: &cash, completedMissions: 5).copper == 26 && cash == 974, "one payment a day")
        // 200 cash, recovery line 180: keeps 90; 26 fits.
        cash = 200
        #expect(h.payDay(2, cash: &cash, completedMissions: 5).copper == 26)
        // Below the recovery line: the basic basket if it leaves half the line, else the free shelter.
        cash = 120
        let basic = h.payDay(3, cash: &cash, completedMissions: 5)
        #expect(basic.lodgingID == "dock_bunk" && basic.copper == 12 && basic.downgraded)
        cash = 60
        let shelter = h.payDay(4, cash: &cash, completedMissions: 5)
        #expect(shelter.lodgingID == "shelter" && shelter.copper == 0 && cash == 60)
        // After the lease ends: the basics.
        cash = 1_000
        #expect(h.payDay(9, cash: &cash, completedMissions: 5).lodgingID == "dock_bunk")
    }

    @Test("highland errands need a highland house paid for today")
    func highlandAccess() throws {
        var h = MPCHousingLedger()
        try h.sign(lodgingID: "highland_house", mealID: "house_kitchen", day: 30, roomsLeft: 1)
        var cash = 2_000
        #expect(!h.canTakeHighlandErrands(day: 30))
        h.payDay(30, cash: &cash, completedMissions: 30)
        #expect(h.canTakeHighlandErrands(day: 30) && cash == 1_950)
        var poor = 150
        h.payDay(31, cash: &poor, completedMissions: 30)
        #expect(!h.canTakeHighlandErrands(day: 31), "a day that could not pay the house loses highland access")
    }

    @Test("changing meals preserves lease dates and today's paid receipt")
    func mealChangePreservesLease() throws {
        var ledger = MPCHousingLedger()
        try ledger.sign(lodgingID: "canal_house", mealID: "bakery", day: 4, roomsLeft: 1)
        var cash = 1_000
        let payment = ledger.payDay(4, cash: &cash, completedMissions: 5)
        let expiry = ledger.leaseEndsDay
        try ledger.chooseMeal("cafe")
        #expect(ledger.leaseEndsDay == expiry && ledger.mealID == "cafe")
        #expect(ledger.payDay(4, cash: &cash, completedMissions: 5) == payment && cash == 976)
        #expect(throws: MPCHousingLedger.Failure.notAllowed) { try ledger.chooseMeal("house_kitchen") }
        #expect(ledger.mealID == "cafe")
        #expect(ledger.payDay(5, cash: &cash, completedMissions: 5).copper == 26)
    }

    @Test("stamina replaces count-based copper decay, preserving merit and receipt limits")
    func staminaReplacesPayDecay() {
        var ledger = MPCDailyWorkLedger()
        for n in 1...9 {
            let pay = ledger.settle(receiptID: "stamina-\(n)", day: 1, copper: 40, merit: 6, usesStamina: true)
            #expect(pay.copper == 40 && pay.percent == 100 && pay.merit == (n <= 2 ? 6 : 0))
            #expect(ledger.settle(receiptID: "stamina-\(n)", day: 1, copper: 999, merit: 999, usesStamina: true) == pay)
        }
        #expect(ledger.jobsToday == 9 && ledger.preview(day: 1, copper: 40, usesStamina: true) == 40)
    }
}
