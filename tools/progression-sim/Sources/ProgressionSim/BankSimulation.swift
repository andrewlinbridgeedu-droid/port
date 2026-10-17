import Foundation
import MistportCombatCore

// Candidate design experiment, deliberately outside the shipping combat rules.
// Combat, eligibility, loot and ritual consumption use CombatCore. The earning candidate
// applies an explicit purchase-price delta without editing the shipping material catalog.
struct BankScenario: Codable {
    var name: String
    var protectBudget = false
    var deposit = 0
    var depositBonusPer20 = 1
    var depositDays = 3
    var forceEarlyExit = false
    var riskTarget = 0
    var riskReturnPercent = 105
    var riskDays = 7
    var riskStartMission = 5
    var unsafeInvestment = false
    var cashShockDay = 0
    var cashShock = 0
    var skipEvery = 0
    var dailyMinutes = 0
    var advancementPrices = [260, 340, 480, 280]
    var cashRecovery = true
    var housing: HousingConfig? = nil
    var ordinary = 0
    var ordinaryProfitMultiplier = 1
    var ordinaryEarlyExit = false

    static func candidates(version: String) -> [BankScenario] {
        let protected = version != "original"
        let bonus = Int(ProcessInfo.processInfo.environment["BANK_BONUS"] ?? "") ?? (protected ? 4 : 1)
        let days = Int(ProcessInfo.processInfo.environment["BANK_DAYS"] ?? "") ?? 3
        func make(_ name: String, deposit: Int = 0, risk: Int = 0, returns: Int = 105,
                  riskDays: Int = 7, start: Int = 5, unsafe: Bool = false, early: Bool = false,
                  shock: Int = 0, skip: Int = 0, minutes: Int? = nil) -> BankScenario {
            .init(name: "\(version)_\(name)", protectBudget: protected, deposit: deposit,
                  depositBonusPer20: bonus, depositDays: days, forceEarlyExit: early,
                  riskTarget: risk, riskReturnPercent: returns, riskDays: riskDays,
                  riskStartMission: start, unsafeInvestment: unsafe, cashShockDay: shock > 0 ? 16 : 0,
                  cashShock: shock, skipEvery: skip, dailyMinutes: minutes ?? (protected ? 90 : 0))
        }
        var scenarios = [make("none"), make("deposit20", deposit: 20), make("deposit60", deposit: 60),
                make("early_exit", deposit: 60, early: true),
                make("risk80_profit", deposit: 60, risk: 80),
                make("risk80_delay", deposit: 60, risk: 80, riskDays: 10),
                make("risk80_loss20pct", deposit: 60, risk: 80, returns: 80),
                make("risk80_total_loss", deposit: 60, risk: 80, returns: 0),
                make("risk160_total_loss", deposit: 60, risk: 160, returns: 0, start: 16),
                make("unsafe160_loss", deposit: 60, risk: 160, returns: 0, start: 16, unsafe: true),
                make("shock_none", shock: 60),
                make("shock_risk80_loss", deposit: 60, risk: 80, returns: 0, shock: 60),
                make("intermittent_none", skip: 4),
                make("intermittent_risk80_loss", deposit: 60, risk: 80, returns: 0, skip: 4),
                make("time45_none", minutes: 45),
                make("time45_risk80_loss", deposit: 60, risk: 80, returns: 0, minutes: 45),
                make("time120_none", minutes: 120),
                make("time120_risk80_loss", deposit: 60, risk: 80, returns: 0, minutes: 120)]
        if version == "earning" {
            let prices = (ProcessInfo.processInfo.environment["ADV_COSTS"] ?? "500,650,950,300").split(separator: ",").compactMap { Int($0) }
            precondition(prices.count == 4 && zip(prices, [260, 340, 480, 280]).allSatisfy { $0 >= $1 })
            for i in scenarios.indices { scenarios[i].advancementPrices = prices; scenarios[i].cashRecovery = false }
        }
        if ProcessInfo.processInfo.environment["BANK_TERM_STUDY"] == "1" {
            let base = scenarios.first { $0.name == "\(version)_deposit60" }!
            for rate in [1, 2, 3] {
                var term = base; term.name = "\(version)_term\(rate)"; term.ordinary = 60; term.ordinaryProfitMultiplier = rate
                scenarios.append(term)
            }
            var early = base; early.name = "\(version)_term_early"; early.ordinary = 60; early.ordinaryEarlyExit = true
            scenarios.append(early)
            var large = base; large.name = "\(version)_term120"; large.ordinary = 120
            scenarios.append(large)
            var loss = scenarios.first { $0.name == "\(version)_unsafe160_loss" }!
            loss.name = "\(version)_term_loss"; loss.ordinary = 60
            scenarios.append(loss)
        }
        return scenarios
    }
}

struct SimBankContract: Codable {
    let kind: String
    let principal: Int
    let signedHour: Double
    let maturityHour: Double
    let repayment: Int
}
struct BankEvent: Codable {
    let day: Int
    let mission: Int
    let hour: Double
    let action: String
    let amount: Int
    let cash: Int
    let principalLocked: Int
}
struct BankDay: Codable {
    let day: Int
    let mission: Int
    let cash: Int
    let liquid: Int
    let principalLocked: Int
    let advancementSpent: Int
    let minimumCash: Int
}
struct BankRunSummary: Codable {
    let scenario: BankScenario
    let storyDay: Int?
    let ritualDay: Int?
    let advancementSpent: Int
    let materialDays: [String: Int]
    let liquid: Int
    let outstandingPrincipal: Int
    let minimumCash: Int
    let livingPaid: Int
    let reliefDays: Int
    let depositPrincipal: Int
    let depositProfit: Int
    let earlyRedemptions: Int
    let riskPrincipal: Int
    let riskProfit: Int
    let firstRiskDay: Int?
    let rejectedRiskChecks: Int
    let remainingAdvancementCost: Int
    let events: [BankEvent]
    let days: [BankDay]
    let ordinarySigned: Int
    let ordinaryProfit: Int
    let ordinaryEarlyExits: Int
}
struct BankSimulationState {
    var contracts: [SimBankContract] = []
    var events: [BankEvent] = []
    var days: [BankDay] = []
    var depositUsed = false, riskUsed = false, shocked = false
    var depositPrincipal = 0, depositProfit = 0, earlyRedemptions = 0
    var riskPrincipal = 0, riskProfit = 0, rejectedRiskChecks = 0
    var firstRiskDay: Int?
    var ingredients: Set<String> = []
    var materialDays: [String: Int] = [:]
    var advancementSpent = 0, livingPaid = 0, reliefDays = 0
    var ritual: MPCSequenceEightRitual.Receipt?
    var storyDay: Int?, ritualDay: Int?
    var openedDay = 0
    var termLedger = MPCCityEconomy()
    var ordinarySigned = 0, ordinaryProfit = 0, ordinaryEarlyExits = 0
}

extension Campaign {
    var bankHasTime: Bool {
        guard let s = bankScenario, s.dailyMinutes > 0 else { return true }
        return dayMinutes[day] < Double(s.dailyMinutes)
    }
    var bankHour: Double { housingEnabled ? housingClock / 3600 : Double(day * 24) + dayMinutes[day] / 60 }
    var bankPrincipal: Int { bankState.contracts.reduce(0) { $0 + $1.principal } + bankState.termLedger.outstanding }
    var bankLiquid: Int { copper + bankState.contracts.filter { $0.kind == "deposit" }.reduce(0) { $0 + $1.principal } + bankState.termLedger.outstanding }
    var bankEligibleAssets: Int { bankScenario == nil ? copper : copper + bankPrincipal }
    var bankAdvancementPrices: [Int] { bankScenario?.advancementPrices ?? [260, 340, 480, 280] }
    var bankAdvancementTotal: Int { bankAdvancementPrices.reduce(0, +) }
    var bankRemainingAdvancement: Int { bankAdvancementTotal - bankState.advancementSpent }
    func bankMaterialPrice(_ id: String) -> Int {
        let index = MPCAdvancementMaterialMarket.offers.firstIndex { $0.id == id }!
        return bankAdvancementPrices[index]
    }
    var bankPlannedSaving: Int {
        guard bankScenario?.cashRecovery == false else { return bankAdvancementTotal * q / 30 }
        // Save toward the next purchase milestone, without locking the entire later bill at Q1.
        let gates = [17, 20, 23, 30]
        var total = 0, previous = 0
        for (gate, price) in zip(gates, bankAdvancementPrices) {
            if q < gate { return total + price * max(0, q - previous) / (gate - previous) }
            total += price; previous = gate
        }
        return total
    }
    var bankReserve: Int {
        guard let scenario = bankScenario else { return 0 }
        let nextMaterial = MPCAdvancementMaterialMarket.offers.first { !bankState.materialDays.keys.contains($0.id) && q >= $0.unlockMission }.map { bankMaterialPrice($0.id) } ?? 0
        let saving = scenario.protectBudget ? max(0, bankPlannedSaving - bankState.advancementSpent) : nextMaterial
        let earlyRelics = Shop.passives.filter { $0.unlock == 4 && !passives.contains($0.id) }.reduce(0) { $0 + $1.price }
        return 36 + salvePrice + max(nextMaterial, saving) + (q >= 4 ? earlyRelics : 0)
    }
    func bankLog(_ action: String, _ amount: Int) {
        bankState.events.append(.init(day: dayNumber, mission: q, hour: bankHour, action: action,
                                     amount: amount, cash: copper, principalLocked: bankPrincipal))
    }
    func bankTick() {
        let before = bankState.termLedger.bankBonusPaid
        bankState.termLedger.settle(now: bankHour * 3600, coins: &copper)
        let earned = bankState.termLedger.bankBonusPaid - before
        if earned > 0 {
            // Rate 1 is the actual production ledger. Higher candidates apply
            // an explicit payout adapter, keeping the same principal/clock.
            let profit = earned * (bankScenario?.ordinaryProfitMultiplier ?? 1)
            copper += profit - earned
            bankState.ordinaryProfit += profit
            bankLog("mature_ordinary", profit)
        }
        let ready = bankState.contracts.filter { $0.maturityHour <= bankHour }
        bankState.contracts.removeAll { $0.maturityHour <= bankHour }
        for c in ready {
            copper += c.repayment
            if c.kind == "deposit" { bankState.depositProfit += c.repayment - c.principal }
            else { bankState.riskProfit += c.repayment - c.principal }
            bankLog("mature_\(c.kind)", c.repayment)
        }
    }
    func bankRedeemIfNeeded(_ cost: Int) {
        if copper < cost, let index = bankState.contracts.firstIndex(where: { $0.kind == "deposit" }) {
            let c = bankState.contracts.remove(at: index)
            copper += c.principal; bankState.earlyRedemptions += 1
            bankLog("redeem_deposit", c.principal)
        }
        if copper < cost, let term = bankState.termLedger.termDeposit, !term.closed {
            try! bankState.termLedger.redeemTermDeposit(now: bankHour * 3600, coins: &copper)
            bankState.ordinaryEarlyExits += 1; bankLog("redeem_ordinary", term.principal)
        }
    }
    func bankBuyAdvancement() {
        for offer in MPCAdvancementMaterialMarket.offers where q >= offer.unlockMission && !bankState.materialDays.keys.contains(offer.id) {
            let price = bankMaterialPrice(offer.id)
            guard bankLiquid >= price + 36 + (q < 30 ? salvePrice : 0) else { continue }
            bankRedeemIfNeeded(price + 36)
            guard let receipt = MPCAdvancementMaterialMarket.purchase(offer.id, completedMissionNumbers: completedMissions,
                          coins: copper, ownedIDs: bankState.ingredients) else { continue }
            copper = receipt.coins - (price - offer.price); bankState.ingredients = receipt.ownedIDs
            bankState.materialDays[offer.id] = dayNumber; bankState.advancementSpent += price
            bankLog("material_\(offer.id)", -price)
        }
        let ritualPrice = bankAdvancementPrices[3]
        let ritualReserve = bankScenario?.protectBudget == true ? 36 : 0
        guard q >= 30, bankState.ritual == nil, bankLiquid >= ritualPrice + ritualReserve else { return }
        bankRedeemIfNeeded(ritualPrice + ritualReserve)
        if let receipt = try? MPCSequenceEightRitual.perform(id: "simulation-ritual", completedMissions: completedMissions,
                    coins: &copper, ingredients: &bankState.ingredients, inventory: inventory, existing: bankState.ritual) {
            copper -= ritualPrice - receipt.fee
            bankState.ritual = receipt; bankState.ritualDay = dayNumber
            bankState.advancementSpent += ritualPrice
            bankLog("ritual", -ritualPrice)
        }
    }
    func bankInvest() {
        bankInvestOriginal()
        guard let s = bankScenario, s.ordinary > 0, q >= 1, q < 30 else { return }
        let now = bankHour * 3600
        if s.ordinaryEarlyExit, bankState.ordinaryEarlyExits == 0,
           let term = bankState.termLedger.termDeposit, !term.closed, now >= term.openedAt + 86_400 {
            try! bankState.termLedger.redeemTermDeposit(now: now, coins: &copper)
            bankState.ordinaryEarlyExits += 1; bankLog("redeem_ordinary", term.principal)
        }
        let premiumReserve = housingEnabled ? max(0, housingConfig.costs[housingState.tier] * 3 - 36) : 0
        let reserve = bankReserve + premiumReserve
        guard bankPrincipal + s.ordinary <= (q >= 16 ? 160 : q >= 5 ? 100 : 60),
              copper - s.ordinary >= reserve,
              bankState.termLedger.termDeposit == nil || bankState.termLedger.termDeposit!.closed else { return }
        do {
            try bankState.termLedger.openTermDeposit(s.ordinary, completed: Set(1...q), liquidReserve: reserve, now: now, coins: &copper)
            bankState.ordinarySigned += 1; bankLog("subscribe_ordinary", -s.ordinary); busy("bank", 90)
        } catch { preconditionFailure("valid ordinary deposit rejected: \(error)") }
    }
    func bankInvestOriginal() {
        guard let s = bankScenario, q < 30 else { return }
        let premiumReserve = housingEnabled ? max(0, housingConfig.costs[housingState.tier] * 3 - 36) : 0
        if !bankState.depositUsed, s.deposit > 0, q >= 1, copper >= s.deposit + bankReserve + premiumReserve {
            let c = SimBankContract(kind: "deposit", principal: s.deposit, signedHour: bankHour,
                           maturityHour: bankHour + Double(s.depositDays * 24),
                           repayment: s.deposit + s.deposit / 20 * s.depositBonusPer20)
            copper -= c.principal; bankState.contracts.append(c)
            bankState.depositUsed = true; bankState.depositPrincipal = c.principal
            bankLog("subscribe_deposit", -c.principal); busy("bank", 90)
        }
        if s.forceEarlyExit && dayNumber >= 2, bankState.contracts.contains(where: { $0.kind == "deposit" }) {
            bankRedeemIfNeeded(copper + 1)
        }
        guard !bankState.riskUsed, s.riskTarget > 0, q >= s.riskStartMission else { return }
        let ceiling = q >= 16 ? 160 : 100
        let reserve = s.unsafeInvestment ? 0 : bankReserve
        let available = min(ceiling - bankPrincipal, copper - reserve)
        let amount = min(s.riskTarget, max(0, available / 20 * 20))
        // Sample the requested exposure, instead of labelling a 20-copper loss as an 80-copper test.
        guard amount == s.riskTarget else { bankState.rejectedRiskChecks += 1; return }
        let c = SimBankContract(kind: "risk", principal: amount, signedHour: bankHour,
                               maturityHour: bankHour + Double(s.riskDays * 24), repayment: amount * s.riskReturnPercent / 100)
        copper -= amount; bankState.contracts.append(c); bankState.riskUsed = true
        bankState.riskPrincipal = amount; bankState.firstRiskDay = dayNumber
        bankLog("subscribe_risk", -amount); busy("bank", 120)
    }
    func bankAfterMission() {
        bankTick(); bankBuyAdvancement(); bankInvest()
        if q == 30 { bankState.storyDay = dayNumber }
    }
    func bankBeginDay() {
        guard let s = bankScenario, bankState.openedDay != dayNumber else { return }
        bankState.openedDay = dayNumber
        if housingEnabled { housingState.sessionOffset = 0 }
        bankTick()
        if s.cashShockDay == dayNumber && !bankState.shocked {
            bankRedeemIfNeeded(s.cashShock)
            let paid = min(copper, s.cashShock)
            copper -= paid; bankState.shocked = true; bankLog("extra_failure_cost", -paid)
        }
        if s.skipEvery > 0 && dayNumber % s.skipEvery == 0 {
            bankLog("offline_no_living_charge", 0)
            day += 1; dayMinutes.append(0); bankBeginDay(); return
        }
        if housingEnabled {
            housingBeginDay(); bankBuyAdvancement(); bankInvest(); return
        }
        bankRedeemIfNeeded(12)
        // Basic shelter/soup are available at zero copper; count aid, never silently skip food.
        let livingPayment = copper >= 12 ? 12 : 0
        if copper >= 12 { copper -= 12; bankState.livingPaid += 12; basketsBought += 1; housingDays["12", default: 0] += 1 }
        else { bankState.reliefDays += 1; basketsMissed += 1; housingDays["0", default: 0] += 1 }
        staminaLeft = 100 // hard capacity 100; higher recovery is not a 120-point stock.
        bankLog("day_open", -livingPayment)
        bankBuyAdvancement(); bankInvest()
    }
    func bankEndDay() {
        housingEndDay(); housingCaptureChapter()
        // The revised planner offers one already-authorized recovery job on a deficit day.
        // It consumes actual work time and stamina and obeys the aggregate-asset means test.
        if bankScenario?.protectBudget == true, bankRemainingAdvancement > 0 {
            _ = postal(upTo: bankScenario?.cashRecovery == false ? bankReserve : min(bankReserve, recoveryLine + 40))
        }
        bankTick(); bankBuyAdvancement(); bankInvest()
        bankState.days.removeAll { $0.day == dayNumber }
        bankState.days.append(.init(day: dayNumber, mission: q, cash: copper, liquid: bankLiquid,
                   principalLocked: bankPrincipal, advancementSpent: bankState.advancementSpent, minimumCash: bankMinimumCash))
    }
    func bankFinish() {
        guard bankScenario != nil else { return }
        bankTick(); bankBuyAdvancement()
        while q >= 30 && bankState.ritual == nil && dayNumber < 60 {
            if bankScenario?.cashRecovery == false && !usesDailyContent { break }
            _ = postal(upTo: bankRemainingAdvancement + 36)
            bankBuyAdvancement()
            if bankState.ritual != nil { break }
            nextDay()
        }
        bankEndDay()
    }
    var bankSummary: BankRunSummary {
        .init(scenario: bankScenario!, storyDay: bankState.storyDay, ritualDay: bankState.ritualDay,
              advancementSpent: bankState.advancementSpent, materialDays: bankState.materialDays,
              liquid: bankLiquid, outstandingPrincipal: bankPrincipal, minimumCash: bankMinimumCash,
              livingPaid: bankState.livingPaid, reliefDays: bankState.reliefDays,
              depositPrincipal: bankState.depositPrincipal, depositProfit: bankState.depositProfit,
              earlyRedemptions: bankState.earlyRedemptions, riskPrincipal: bankState.riskPrincipal,
              riskProfit: bankState.riskProfit, firstRiskDay: bankState.firstRiskDay,
              rejectedRiskChecks: bankState.rejectedRiskChecks, remainingAdvancementCost: bankRemainingAdvancement,
              events: bankState.events, days: bankState.days,
              ordinarySigned: bankState.ordinarySigned, ordinaryProfit: bankState.ordinaryProfit,
              ordinaryEarlyExits: bankState.ordinaryEarlyExits)
    }
}

enum BankReport {
    static func run(destination: URL, offsets: [Int], version: String) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let start = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 12))!
        var runs: [RunResult] = []
        let wanted = ProcessInfo.processInfo.environment["BANK_CASES"]?.split(separator: ",").map(String.init)
        for scenario in BankScenario.candidates(version: version) where wanted == nil || wanted!.contains(scenario.name) {
            for policy in [Policy.all, .completionist, .hinted] {
                for (i, profile) in Profile.all.enumerated() {
                    for offset in offsets {
                        var assumptions = Assumptions()
                        assumptions.pace = HumanPace.all[i]
                        assumptions.loopScale = 0.15; assumptions.sharedJ0 = true
                        assumptions.housing = false; assumptions.basketCost = 12; assumptions.stamina = true
                        let automated = Profile(name: profile.name, actionDelay: HumanPace.all[i].battleActionDelay,
                            priorityCore: profile.priorityCore)
                        let result = Campaign(policy: policy, profile: automated, assumptions: assumptions,
                              startDate: start, startOffset: offset, bankScenario: scenario).run()
                        runs.append(result)
                        let b = result.bankExperiment!
                        print("\(scenario.name) \(policy.rawValue) \(profile.name) +\(offset): Q\(result.finalMission) story=\(b.storyDay ?? -1) ritual=\(b.ritualDay ?? -1) cash=\(result.copper) invest=\(b.riskPrincipal) aid=\(b.reliefDays)")
                    }
                }
            }
            try encoder.encode(runs).write(to: destination.appendingPathComponent("runs.json"), options: .atomic)
        }
    }
}
