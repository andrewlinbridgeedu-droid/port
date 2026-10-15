import Foundation
import MistportCombatCore

enum BankChecks {
    static func run() {
        let start = Date(timeIntervalSince1970: 0)
        func campaign(_ s: BankScenario) -> Campaign {
            var a = Assumptions(); a.sharedJ0 = true; a.stamina = true
            return Campaign(policy: .hinted, profile: Profile.all[0], assumptions: a,
                            startDate: start, startOffset: 0, bankScenario: s)
        }
        func time(_ c: Campaign, _ hour: Double) {
            c.day = Int(hour / 24); c.dayMinutes = Array(repeating: 0, count: c.day + 1)
            c.dayMinutes[c.day] = (hour - Double(c.day * 24)) * 60
        }
        for amount in [20, 40, 60] {
            let c = campaign(.init(name: "check", protectBudget: true, deposit: amount, depositBonusPer20: 4))
            c.q = 1; c.bankInvest()
            precondition(c.copper == 180 - amount && c.bankEligibleAssets == 180)
            time(c, 71.999); c.bankTick()
            precondition(c.bankPrincipal == amount && c.bankState.depositProfit == 0)
            time(c, 72); c.bankTick(); c.bankTick(); c.bankInvest()
            precondition(c.copper == 180 + amount / 20 * 4 && c.bankPrincipal == 0)
            precondition(c.bankState.depositPrincipal == amount)
        }
        print("PASS full 72-hour term, three denominations, idempotent maturity and lifetime limit")
        let early = campaign(.init(name: "early", deposit: 60, depositBonusPer20: 4))
        early.q = 1; early.bankInvest(); early.bankRedeemIfNeeded(180); early.bankInvest()
        time(early, 100); early.bankTick()
        precondition(early.copper == 180 && early.bankState.depositProfit == 0 && early.bankState.earlyRedemptions == 1)
        print("PASS free early redemption consumes the single welcome offer")
        let risk = campaign(.init(name: "risk", protectBudget: true, riskTarget: 80, riskReturnPercent: 0))
        risk.q = 5; risk.copper = 100; risk.bankInvest()
        precondition(risk.bankPrincipal == 0 && risk.bankState.rejectedRiskChecks == 1)
        risk.copper = 1000; risk.bankInvest()
        precondition(risk.bankPrincipal == 80 && risk.copper == 920)
        risk.copper = 140
        precondition(!risk.postal(upTo: 200) && risk.postalJobs == 0) // 140 wallet + 80 claim = end of taper
        time(risk, 168); risk.bankTick(); risk.bankTick()
        precondition(risk.bankPrincipal == 0 && risk.bankState.riskProfit == -80)
        _ = risk.postal(upTo: 200); _ = risk.postal(upTo: 200)
        precondition(risk.copper == 180 && risk.postalJobs == 1)
        print("PASS reserve protection, locked assets in aid test, total loss and once-daily recovery")
        var previous = 0
        for assets in 175...225 {
            let c = campaign(.init(name: "taper", protectBudget: true))
            c.q = 5; c.copper = assets
            _ = c.postal(upTo: 1000)
            precondition(c.copper == assets + min(40, max(0, 220 - assets)))
            precondition(c.copper >= previous)
            previous = c.copper
        }
        print("PASS recovery taper: earning another copper never removes an entire 40-copper payment")
        let cap = campaign(.init(name: "cap", deposit: 60, riskTarget: 80))
        cap.q = 5; cap.copper = 1000; cap.bankInvest()
        precondition(cap.bankPrincipal == 60 && cap.bankState.riskPrincipal == 0)
        time(cap, 72); cap.bankTick(); cap.bankInvest()
        precondition(cap.bankPrincipal == 80)
        print("PASS the deposit and risk investment share the stage exposure ceiling")
        let rite = campaign(.init(name: "rite", protectBudget: true))
        rite.q = 30; rite.copper = 2000
        for q in 1...30 {
            for id in MPCChapterOneThirtyMissionContract.firstClear(for: q)?.itemIDs ?? [] { rite.inventory[id, default: 0] += 1 }
        }
        precondition(rite.recoveryLine == 600)
        rite.bankBuyAdvancement(); rite.bankBuyAdvancement()
        precondition(rite.copper == 640 && rite.bankState.advancementSpent == 1360 && rite.bankState.ritual != nil)
        precondition(rite.recoveryLine == 400)
        print("PASS actual three material purchases and qualification ritual, no duplicate fee, correct recovery transition")
        let poor = campaign(.init(name: "poor", protectBudget: true))
        poor.copper = 0; poor.bankBeginDay(); poor.bankBeginDay()
        precondition(poor.copper == 0 && poor.bankState.reliefDays == 1 && poor.bankState.livingPaid == 0 && poor.staminaLeft == 100)
        precondition(poor.bankState.events.last?.amount == 0)
        print("PASS zero-copper in-kind shelter/food, one charge per active day and stamina cap")
        var earningScenario = BankScenario(name: "earning-check", protectBudget: true)
        earningScenario.advancementPrices = [500, 650, 950, 300]
        earningScenario.cashRecovery = false
        let earning = campaign(earningScenario)
        earning.copper = 0; earning.q = 30
        _ = earning.postal(upTo: 5000); earning.bankBeginDay(); earning.bankEndDay()
        precondition(earning.copper == 0 && earning.postalJobs == 0 && earning.bankState.ritual == nil)
        earning.copper = 2436
        for q in 1...30 {
            for id in MPCChapterOneThirtyMissionContract.firstClear(for: q)?.itemIDs ?? [] { earning.inventory[id, default: 0] += 1 }
        }
        earning.bankBuyAdvancement(); earning.bankBuyAdvancement()
        precondition(earning.copper == 36 && earning.bankState.advancementSpent == 2400 && earning.bankState.ritual != nil)
        precondition(earning.bankRemainingAdvancement == 0 && earning.bankState.ingredients.isEmpty)
        print("PASS candidate 2400-copper price adapter, real proof/material consumption, no cash relief and no duplicate charge")

    }
}
