import Foundation
import Testing
@testable import MistportCombatCore

@Suite("上线的理由")
struct ReturnReasonTests {
    @Test func comingUpListsOnlyWhatIsNewByThen() {
        // Evening of day 1, Q1–Q7 cleared: tomorrow opens Q8 and four more floors.
        var facts = MPCComingUp.Facts(nowDay: 1, thenDay: 2, nextMission: (8, "不属于我的名字"), wellOpen: true, clearedFloors: 8,
                                      payoutCopper: 42, teammatesBack: ["奥黛尔"], merchantArrives: false, staminaFull: true)
        #expect(MPCComingUp.lines(facts).map(\.text) == ["第 8 关《不属于我的名字》开放", "深井新开 4 层", "到账 42 铜", "奥黛尔回来了", "体力满了"])
        let reminder = MPCComingUp.reminder(facts)
        #expect(reminder?.title == "雾港 · 新的一关" && reminder?.body == "第 8 关《不属于我的名字》开放 · 深井新开 4 层 · 到账 42 铜")
        // Q8 already open now and floors left over: neither is news, even when more floors open tomorrow.
        facts.nowDay = 2; facts.thenDay = 2; facts.clearedFloors = 3; facts.payoutCopper = 0; facts.teammatesBack = []; facts.staminaFull = false
        #expect(MPCComingUp.lines(facts).isEmpty && MPCComingUp.reminder(facts) == nil)
        facts.thenDay = 3
        #expect(MPCComingUp.lines(facts).isEmpty)
        // The well's last floors open on day 24; after the hundredth nothing more.
        facts.nowDay = 23; facts.thenDay = 24; facts.clearedFloors = 96; facts.nextMission = nil
        #expect(MPCComingUp.lines(facts).map(\.text) == ["深井新开 4 层"])
        facts.nowDay = 24; facts.thenDay = 25; facts.clearedFloors = 100
        #expect(MPCComingUp.lines(facts).isEmpty)
        for q in 8...30 { #expect(MPCComingUp.teaser(mission: q) != nil) }
        #expect(MPCComingUp.teaser(mission: 7) == nil)
    }

    @Test func merchantComesEveryFourDaysForTwo() {
        #expect((1...12).filter { MPCWanderingMerchant.isInPort(day: $0) } == [3, 4, 7, 8, 11, 12])
        #expect(MPCWanderingMerchant.leavingDay(day: 7) == 8 && MPCWanderingMerchant.leavingDay(day: 8) == 8 && MPCWanderingMerchant.leavingDay(day: 9) == nil)
        #expect(MPCWanderingMerchant.nextArrival(onOrAfter: 1) == 3 && MPCWanderingMerchant.nextArrival(onOrAfter: 5) == 7
                && MPCWanderingMerchant.nextArrival(onOrAfter: 8) == 8 && MPCWanderingMerchant.nextArrival(onOrAfter: 9) == 11)
        #expect(MPCWanderingMerchant.arrivalLine(day: 3)?.contains("明天傍晚") == true && MPCWanderingMerchant.arrivalLine(day: 5) == nil)
    }

    @Test func merchantBringsWhatTheShopDoesNotSellYet() {
        let relics = [MPCWanderingMerchant.Relic(id: "stamp", shopPrice: 360, shopMission: 9),
                      .init(id: "mirror", shopPrice: 520, shopMission: 14), .init(id: "salt", shopPrice: 120, shopMission: 4)]
        // Day 3, Q8 cleared: the stamp, half again its price.
        #expect(MPCWanderingMerchant.offer(day: 3, relics: relics, owned: ["salt"], highestMission: 8)
                == .init(relicID: "stamp", price: 540, early: true, shopMission: 9))
        #expect(MPCWanderingMerchant.offer(day: 7, relics: relics, owned: ["salt", "stamp"], highestMission: 12)?.relicID == "mirror")
        // The shop sells all of them: the dearest one still lacking, a tenth off.
        #expect(MPCWanderingMerchant.offer(day: 11, relics: relics, owned: ["salt"], highestMission: 16)
                == .init(relicID: "mirror", price: 470, early: false, shopMission: 14))
        #expect(MPCWanderingMerchant.offer(day: 11, relics: relics, owned: ["salt", "stamp", "mirror"], highestMission: 16) == nil)
        #expect(MPCWanderingMerchant.offer(day: 5, relics: relics, owned: [], highestMission: 8) == nil)
        // One relic a visit: bought on day 7, nothing more on day 8; the next visit brings the next.
        #expect(MPCWanderingMerchant.offer(day: 8, relics: relics, owned: ["salt", "stamp"], highestMission: 12, soldVisits: [7]) == nil)
        #expect(MPCWanderingMerchant.offer(day: 11, relics: relics, owned: ["salt", "stamp"], highestMission: 12, soldVisits: [7])?.relicID == "mirror")
        #expect(MPCWanderingMerchant.arrivalDay(day: 8) == 7 && MPCWanderingMerchant.arrivalDay(day: 9) == nil)
    }

    @Test func teammateErrandsGoOnceADayAndPayOnceWhenBack() throws {
        let odelle = MPCPartyErrandCatalog.odelle, norn = MPCPartyErrandCatalog.norn
        #expect(!MPCPartyErrandCatalog.isAvailable(norn, highestMission: 12, closedCases: []))
        #expect(MPCPartyErrandCatalog.isAvailable(norn, highestMission: 12, closedCases: ["b01"]))
        #expect(MPCPartyErrandCatalog.offers(odelle, highestMission: 9).map(\.id) == ["odelle-gears", "odelle-records", "odelle-soup"])
        var ledger = MPCPartyErrandLedger()
        #expect(throws: MPCPartyErrandLedger.Failure.unavailable) {
            try ledger.send("norn-night", day: 2, at: 0, highestMission: 8, closedCases: [])
        }
        let trip = try ledger.send("odelle-dock", day: 2, at: 1_000, highestMission: 8, closedCases: [])
        #expect(trip.returnsAt == 1_000 + 8 * 3_600 && !ledger.canSend(odelle, day: 2))
        #expect(throws: MPCPartyErrandLedger.Failure.notBack) { try ledger.claim(odelle, at: 2_000) }
        let reward = try ledger.claim(odelle, at: trip.returnsAt)
        #expect(reward.copper == 6 && reward.itemID == MPCTowerMaterials.hide && reward.note.contains("七针"))
        #expect(throws: MPCPartyErrandLedger.Failure.nothingToClaim) { try ledger.claim(odelle, at: trip.returnsAt) }
        // Back and claimed, but already sent today; tomorrow the same errand tells its second note.
        #expect(throws: MPCPartyErrandLedger.Failure.sentToday) {
            try ledger.send("odelle-soup", day: 2, at: 40_000, highestMission: 8, closedCases: [])
        }
        let next = try ledger.send("odelle-dock", day: 3, at: 90_000, highestMission: 8, closedCases: [])
        #expect(try ledger.claim(odelle, at: next.returnsAt).note.contains("伊恩"))
        let round = try JSONDecoder().decode(MPCPartyErrandLedger.self, from: JSONEncoder().encode(ledger))
        #expect(round == ledger)
        // Every errand's reward is small and its item a real inventory item.
        for errand in MPCPartyErrandCatalog.all {
            #expect(errand.copper <= 10 && errand.itemCount == 1 && errand.notes.count == 2)
        }
    }
}
