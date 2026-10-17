import Foundation
import MistportCombatCore

// Isolated lodging experiment. No production catalog or player preferences are changed.
struct HousingConfig: Codable {
    var strategy = "basic"
    var fixedTier = 0
    var costs = [12, 18, 26, 30, 50]
    var recovery = true
    var reserve = true
    var battleRest = true
    var maintenance = true
    var maintenanceCredit = false
    var meetings = true
    var poorMeeting = false
    var splitSession = false
    var horizon = 42
    var customerBudget = 400
    var privateGross = [40, 40, 60, 60, 96]
    var privateInputs = [20, 20, 30, 30, 50]
}
struct HousingDay: Codable {
    // cost is the selected catalog quote; actual payment (including zero for aid)
    // is the matching BankEvent.day_open receipt, used by all financial checks.
    let day: Int, tier: Int, cost: Int, cash: Int, advancementPaid: Int
    let stamina: Double, reserve: Double
}
struct HousingContract: Codable {
    let id: String
    let gross: Int, inputs: Int, dueDay: Int, tier: Int
}
struct HousingSummary: Codable {
    let config: HousingConfig
    let chapterCash: Int?, chapterLiving: Int?, chapterAdvancementPaid: Int?, chapterIncome: [String: Int]?, chapterSpending: [String: Int]?
    let housingPaid: Int, premiumPaid: Int, meetingPaid: Int
    let contractGross: Int, contractInputs: Int, contractNet: Int, customerRemaining: Int, customerEscrow: Int
    let meetings: Int, meetingsFailed: Int, contracts: Int, pendingContracts: Int
    let repairSaved: Int, restBattles: Int, restExtraHP: Int, downgradedDays: Int
    let recovered: Double, bonusRecovered: Double, reserveEarned: Double, reserveUsed: Double
    let staminaSpent: Int, maxStamina: Double, maxReserve: Double
    let failedEconomicActions: Int, butlerMinutesSaved: Double
    let days: [HousingDay]
}
struct HousingState {
    var tier = 0, leaseTier = 0, leaseEnd = 0
    var stamina = 100.0, reserve = 0.0, clock = 0.0, rateBonus = 0
    var paidUntil = 0.0, recovered = 0.0, bonusRecovered = 0.0, reserveEarned = 0.0, reserveUsed = 0.0
    var staminaSpent = 0, maxStamina = 100.0, maxReserve = 0.0
    var housingPaid = 0, premiumPaid = 0, meetingPaid = 0, contractGross = 0, contractInputs = 0
    var customerRemaining = 400, customerEscrow = 0
    var meetings = 0, meetingsFailed = 0, contracts = 0, repairSaved = 0, restBattles = 0, restExtraHP = 0
    var downgradedDays = 0, failedEconomicActions = 0, maintenanceDay = 0, restDay = 0
    var lastMeetingWeek = -1, lastContractWeek = -1
    var pending: [HousingContract] = [], days: [HousingDay] = []
    var chapterCash: Int?, chapterLiving: Int?, chapterAdvancementPaid: Int?, chapterIncome: [String: Int]?, chapterSpending: [String: Int]?
    var sessionOffset = 0.0, splitDay = 0
    var butlerMinutesSaved = 0.0
}

extension Campaign {
    var housingEnabled: Bool { bankScenario?.housing != nil }
    var housingConfig: HousingConfig { bankScenario!.housing! }
    var housingClock: Double { Double(day)*86400 + dayMinutes[day]*60 + housingState.sessionOffset }
    var housingBonus: Int { [0,6,11,15,20][housingState.tier] }
    var housingUnlockedTier: Int { q >= 30 ? 4 : q >= 20 ? 3 : q >= 13 ? 2 : q >= 5 ? 1 : 0 }
    func housingAccrue(to now: Double) {
        guard housingEnabled else { return }
        let start = housingState.clock
        guard now > start else { return }
        let paidEnd = min(now, housingState.paidUntil)
        func add(_ seconds: Double, _ bonus: Int) {
            guard seconds > 0 else { return }
            let rate = Double(100+bonus)/86400
            let active = min(seconds, max(0,100-housingState.stamina)/rate)
            housingState.stamina += active*rate
            housingState.recovered += active*rate
            housingState.bonusRecovered += active*Double(bonus)/86400
            if housingConfig.reserve && bonus > 0 {
                let overflow = (seconds-active)*Double(bonus)/86400
                let earned = min(overflow,max(0,Double(bonus)-housingState.reserve))
                housingState.reserve += earned; housingState.reserveEarned += earned
            }
        }
        if paidEnd > start { add(paidEnd-start, housingConfig.recovery ? housingState.rateBonus : 0) }
        add(now-max(start,paidEnd),0)
        housingState.clock = now
        housingState.stamina = min(100,housingState.stamina)
        housingState.maxStamina = max(housingState.maxStamina,housingState.stamina)
        housingState.maxReserve = max(housingState.maxReserve,housingState.reserve)
        staminaLeft = Int(housingState.stamina.rounded(.down))
    }
    func housingSpend(_ cost: Int) -> Bool {
        housingAccrue(to: housingClock)
        if housingState.stamina + 1e-8 < Double(cost), housingState.reserve > 0 {
            let used = min(housingState.reserve,100-housingState.stamina)
            housingState.reserve -= used; housingState.reserveUsed += used; housingState.stamina += used
            busy("home_rest",60)
            housingAccrue(to: housingClock)
        }
        guard housingState.stamina + 1e-8 >= Double(cost) else {
            staminaShort += 1; housingState.failedEconomicActions += 1; return false
        }
        housingState.stamina -= Double(cost); housingState.staminaSpent += cost
        staminaLeft = Int(housingState.stamina.rounded(.down)); return true
    }
    func housingRefund(_ cost: Int) {
        guard housingEnabled else { staminaLeft += cost; return }
        housingState.stamina = min(100,housingState.stamina+Double(cost)); housingState.staminaSpent -= cost
        staminaLeft = Int(housingState.stamina.rounded(.down))
    }
    func housingBeginDay() {
        housingState.sessionOffset = 0
        housingAccrue(to: housingClock)
        housingSettleContracts()
        let cfg = housingConfig
        var wanted = cfg.strategy == "fixed" ? min(cfg.fixedTier,housingUnlockedTier)
                   : cfg.strategy == "basic" ? 0 : housingUnlockedTier
        if cfg.strategy == "budget" {
            while wanted > 0 && bankLiquid < bankReserve + 7*cfg.costs[wanted] { wanted -= 1 }
        }
        // Moving is allowed; an existing 7-day lease never refreshes earned benefits.
        if wanted != housingState.leaseTier || dayNumber >= housingState.leaseEnd {
            housingState.leaseTier = wanted; housingState.leaseEnd = dayNumber+7
        }
        let preferred = wanted
        while wanted > 0 && bankLiquid < cfg.costs[wanted]+36 { wanted -= 1 }
        if wanted < preferred { housingState.downgradedDays += 1 }
        housingState.tier = wanted
        let cost = bankLiquid >= cfg.costs[wanted] ? cfg.costs[wanted] : 0
        bankRedeemIfNeeded(cost)
        copper -= cost; bankState.livingPaid += cost; housingState.housingPaid += cost
        housingState.premiumPaid += max(0,cost-12)
        if cost == 0 { bankState.reliefDays += 1; basketsMissed += 1; housingState.tier = 0 }
        else { basketsBought += 1 }
        housingDays["\(cost)",default:0] += 1
        housingState.rateBonus = cost > 0 ? housingBonus : 0
        housingState.paidUntil = Double(day+1)*86400
        bankLog("day_open",-cost)
    }
    func housingSettleContracts() {
        guard housingEnabled else { return }
        let due = housingState.pending.filter { $0.dueDay <= dayNumber }
        housingState.pending.removeAll { $0.dueDay <= dayNumber }
        for c in due {
            copper += c.gross; earned["housing_contract",default:0] += c.gross
            housingState.contractGross += c.gross; housingState.customerEscrow -= c.gross
            let saving = housingState.tier == 4 ? 60.0 : 0
            busy("housing_collection",90-saving); housingState.butlerMinutesSaved += saving/60
            bankLog("housing_contract_delivery",c.gross)
        }
    }
    func housingSocial() {
        guard housingEnabled, housingConfig.meetings, q >= 13, bankHasTime else { return }
        let week = (dayNumber-1)/7
        let tier = housingState.tier
        if housingState.lastMeetingWeek != week {
            let fee = [2,2,4,6,10][tier]
            let reserve = housingConfig.strategy == "budget" ? bankReserve : 36
            guard bankLiquid >= fee + reserve, useStamina(10) else { return }
            bankRedeemIfNeeded(fee+reserve); copper -= fee; housingState.meetingPaid += fee
            housingState.lastMeetingWeek = week; housingState.meetings += 1
            busy(tier >= 2 ? "private_meeting" : "public_meeting",480)
            bankLog(tier >= 2 ? "private_meeting" : "public_meeting",-fee)
            if housingConfig.poorMeeting { housingState.meetingsFailed += 1; return }
        }
        guard !housingConfig.poorMeeting, housingState.lastContractWeek != week else { return }
        let gross = housingConfig.privateGross[tier], inputs = housingConfig.privateInputs[tier]
        let reserve = housingConfig.strategy == "budget" ? bankReserve : 36
        guard housingState.customerRemaining >= gross, bankLiquid >= inputs + reserve,
              useStamina(tier >= 4 ? 25 : tier >= 2 ? 20 : 15) else { return }
        bankRedeemIfNeeded(inputs+reserve); copper -= inputs; housingState.contractInputs += inputs
        housingState.customerRemaining -= gross; housingState.customerEscrow += gross
        housingState.contracts += 1; housingState.lastContractWeek = week
        let contract = HousingContract(id:"housing-\(week)",gross:gross,inputs:inputs,dueDay:dayNumber+1,tier:tier)
        housingState.pending.append(contract)
        busy("housing_contract",Double(tier >= 4 ? 12 : tier >= 2 ? 10 : 8)*60)
        bankLog("housing_contract_inputs",-inputs)
    }
    func housingBattleLoadout(_ input: MPCChapterOneLoadout, target: String) -> MPCChapterOneLoadout {
        guard housingEnabled, housingConfig.battleRest, housingState.tier >= 2,
              housingState.restDay != dayNumber else { return input }
        // Only prepare for story/bounty, not the first trivial tower fight of the day.
        guard target == "main" || target == "bounty" else { return input }
        let percentage = housingState.tier >= 3 ? 5 : 3
        var output = input
        let extra = (1000+input.churchGear.maxHP)*percentage/100
        output.churchGear.maxHP += extra
        housingState.restDay = dayNumber; housingState.restBattles += 1; housingState.restExtraHP += extra
        busy("battle_rest",60); bankLog("battle_rest",extra)
        return output
    }
    func housingRepairSaving(_ cost: Int) -> Int {
        guard housingEnabled, housingConfig.maintenance, housingState.tier >= 2,
              housingState.maintenanceDay != dayNumber else { return 0 }
        let tier = housingState.tier
        // Fixed point rounding: cheap maintenance really may save zero copper.
        let revised = housingConfig.maintenanceCredit
        let saved = revised ? min([0,0,1,2,3][tier],cost/2) : min([0,0,3,5,8][tier],cost*[0,0,10,15,20][tier]/100)
        if saved > 0 { housingState.maintenanceDay = dayNumber; housingState.repairSaved += saved }
        return saved
    }
    func housingEndDay() {
        guard housingEnabled else { return }
        housingSocial(); housingAccrue(to:housingClock)
        housingState.days.removeAll { $0.day == dayNumber }
        housingState.days.append(.init(day:dayNumber,tier:housingState.tier,cost:housingConfig.costs[housingState.tier],
              cash:copper,advancementPaid:bankState.advancementSpent,stamina:housingState.stamina,reserve:housingState.reserve))
    }
    func housingSecondSession() {
        guard housingEnabled, housingConfig.splitSession, housingState.splitDay != dayNumber else { return }
        housingState.sessionOffset = 43200
        housingState.splitDay = dayNumber
        housingAccrue(to:housingClock)
    }
    func housingCaptureChapter() {
        guard housingEnabled, housingState.chapterCash == nil, q == 30 else { return }
        housingState.chapterCash = copper; housingState.chapterLiving = bankState.livingPaid; housingState.chapterAdvancementPaid = bankState.advancementSpent; housingState.chapterIncome = earned
        housingState.chapterSpending = ["meeting":housingState.meetingPaid,"contract_inputs":housingState.contractInputs,"maintenance_saved":housingState.repairSaved]
    }
    func housingFinish() {
        guard housingEnabled else { return }
        housingCaptureChapter()
        while q == 30 && dayNumber < housingConfig.horizon {
            nextDay(); bankBuyAdvancement(); housingCaptureChapter()
        }
        housingSettleContracts()
        // bankFinish has already recorded the first final day; later final day has not.
        if bankState.days.last?.day != dayNumber { bankEndDay() }
    }
    var housingSummary: HousingSummary {
        .init(config:housingConfig,chapterCash:housingState.chapterCash,chapterLiving:housingState.chapterLiving,chapterAdvancementPaid:housingState.chapterAdvancementPaid,
          chapterIncome:housingState.chapterIncome,chapterSpending:housingState.chapterSpending,housingPaid:housingState.housingPaid,premiumPaid:housingState.premiumPaid,
          meetingPaid:housingState.meetingPaid,contractGross:housingState.contractGross,contractInputs:housingState.contractInputs,
          contractNet:housingState.contractGross-housingState.contractInputs-housingState.meetingPaid,
          customerRemaining:housingState.customerRemaining,customerEscrow:housingState.customerEscrow,
          meetings:housingState.meetings,meetingsFailed:housingState.meetingsFailed,contracts:housingState.contracts,
          pendingContracts:housingState.pending.count,repairSaved:housingState.repairSaved,restBattles:housingState.restBattles,
          restExtraHP:housingState.restExtraHP,downgradedDays:housingState.downgradedDays,recovered:housingState.recovered,
          bonusRecovered:housingState.bonusRecovered,reserveEarned:housingState.reserveEarned,reserveUsed:housingState.reserveUsed,
          staminaSpent:housingState.staminaSpent,maxStamina:housingState.maxStamina,maxReserve:housingState.maxReserve,
          failedEconomicActions:housingState.failedEconomicActions,butlerMinutesSaved:housingState.butlerMinutesSaved,days:housingState.days)
    }
}

enum HousingReport {
    static func run(destination:URL, offsets:[Int], version:String) throws {
        let start = Calendar(identifier:.gregorian).date(from:DateComponents(year:2026,month:9,day:28,hour:12))!
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        let only = ProcessInfo.processInfo.environment["HOUSING_CASES"]?.split(separator:",").map(String.init)
        let banks = ProcessInfo.processInfo.environment["HOUSING_BANKS"]?.split(separator:",").map(String.init) ?? ["none","risk80_total_loss","unsafe160_loss"]
        var modes:[(String,HousingConfig)] = [("basic",.init(strategy:"basic")),("budget",.init(strategy:"budget")),("greedy",.init(strategy:"greedy")),("arcade",.init(strategy:"fixed",fixedTier:1)),("canal",.init(strategy:"fixed",fixedTier:2)),("loft",.init(strategy:"fixed",fixedTier:3)),("highland",.init(strategy:"fixed",fixedTier:4))]
        var basicNoGuests = HousingConfig(strategy:"basic"); basicNoGuests.meetings = false
        var noReserve = HousingConfig(strategy:"budget"); noReserve.reserve = false
        var noBuff = HousingConfig(strategy:"budget"); noBuff.battleRest = false
        var noMaintenance = HousingConfig(strategy:"budget"); noMaintenance.maintenance = false
        var noSocial = HousingConfig(strategy:"budget"); noSocial.meetings = false
        var failedSocial = HousingConfig(strategy:"budget"); failedSocial.poorMeeting = true
        var rentOnly = HousingConfig(strategy:"greedy"); rentOnly.reserve = false; rentOnly.recovery = false; rentOnly.battleRest = false; rentOnly.maintenance = false; rentOnly.meetings = false
        var split = HousingConfig(strategy:"budget"); split.splitSession = true
        modes += [("basic_no_meeting",basicNoGuests),("no_reserve",noReserve),("no_buff",noBuff),("no_maintenance",noMaintenance),("no_meeting",noSocial),("meeting_failed",failedSocial),("rent_only",rentOnly),("split",split)]
        var runs:[RunResult] = []
        for (mode,var cfg) in modes where only == nil || only!.contains(mode) {
            cfg.maintenanceCredit = version == "adjusted" || ProcessInfo.processInfo.environment["HOUSING_MAINTENANCE"] == "credit"
            if let prices = ProcessInfo.processInfo.environment["HOUSING_COSTS"] {
                cfg.costs = prices.split(separator:",").compactMap { Int($0) }; precondition(cfg.costs.count==5 && cfg.costs[0]==12)
            }
            if let h = ProcessInfo.processInfo.environment["HOUSING_HORIZON"].flatMap(Int.init) { cfg.horizon = h }
            for bank in BankScenario.candidates(version:"earning") where banks.contains(bank.name.replacingOccurrences(of:"earning_",with:"")) {
                var scenario = bank; scenario.name = "\(version)_\(mode)_\(bank.name.replacingOccurrences(of:"earning_",with:""))"; scenario.housing = cfg
                if let minutes = ProcessInfo.processInfo.environment["HOUSING_MINUTES"].flatMap(Int.init) { scenario.dailyMinutes = minutes }
                if let skip = ProcessInfo.processInfo.environment["HOUSING_SKIP"].flatMap(Int.init) { scenario.skipEvery = skip }
                let wantedPolicies = ProcessInfo.processInfo.environment["SIM_POLICIES"]?.split(separator: ",").map(String.init)
                let wantedProfiles = ProcessInfo.processInfo.environment["SIM_PROFILES"]?.split(separator: ",").map(String.init)
                for policy in [Policy.all,.completionist,.hinted] where wantedPolicies == nil || wantedPolicies!.contains(policy.rawValue) {
                    for (i,profile) in Profile.all.enumerated() where wantedProfiles == nil || wantedProfiles!.contains(profile.name) { for offset in offsets {
                        var a = Assumptions(); a.pace = HumanPace.all[i]; a.loopScale = 0.15; a.sharedJ0 = true; a.stamina = true
                        let automated = Profile(name: profile.name, actionDelay: HumanPace.all[i].battleActionDelay,
                            priorityCore: profile.priorityCore)
                        let run = Campaign(policy:policy,profile:automated,assumptions:a,startDate:start,startOffset:offset,bankScenario:scenario).run()
                        runs.append(run)
                        print("\(scenario.name) \(policy.rawValue) \(profile.name) +\(offset) Q\(run.finalMission) rite=\(run.bankExperiment!.ritualDay ?? -1) cash=\(run.copper) housing=\(run.housingExperiment!.housingPaid)")
                    } }
                }
            }
            try encoder.encode(runs).write(to:destination.appendingPathComponent("runs.json"),options:.atomic)
        }
    }
}
