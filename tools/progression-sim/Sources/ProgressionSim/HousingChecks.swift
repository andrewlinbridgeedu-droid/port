import Foundation
import MistportCombatCore

enum HousingChecks {
    static func run() {
        func make(_ cfg:HousingConfig) -> Campaign {
            var s=BankScenario(name:"housing-check",protectBudget:true);s.housing=cfg;s.cashRecovery=false;s.advancementPrices=[500,650,950,300]
            var a=Assumptions();a.stamina=true
            return Campaign(policy:.all,profile:Profile.all[0],assumptions:a,startDate:Date(timeIntervalSince1970:0),startOffset:0,bankScenario:s)
        }
        let c=make(.init(strategy:"greedy"));c.q=30;c.copper=10000;c.bankBeginDay()
        precondition(c.housingState.tier==4 && c.copper==7850) // all material/ritual eligibility is still checked; absent proofs means no ritual
        c.housingState.stamina=100;c.housingAccrue(to:86400)
        precondition(abs(c.housingState.reserve-20)<1e-8 && c.housingState.stamina==100)
        c.housingAccrue(to:86400);precondition(abs(c.housingState.reserve-20)<1e-8)
        precondition(c.housingSpend(100));precondition(c.housingSpend(20))
        precondition(c.housingState.stamina<1 && c.housingState.reserve<1e-8 && abs(c.housingState.reserveUsed-20)<1e-8)
        let used=c.housingState.reserveUsed;c.housingAccrue(to:86400*2)
        precondition(c.housingState.reserve<1e-8 && c.housingState.reserveUsed==used) // unbilled day has no paid recovery
        print("PASS continuous recovery, 100-point ceiling, only paid bonus overflow stored, no duplicate accrual or unpaid accumulation")
        let r=make(.init(strategy:"greedy"));r.q=20;r.copper=10000;r.bankBeginDay()
        let l=loadout(mission:22,gear:r.stats,passive:nil,sequence:cards(forMission:22)[0])
        let once=r.housingBattleLoadout(l,target:"main"),twice=r.housingBattleLoadout(l,target:"main")
        precondition(once.churchGear.maxHP==l.churchGear.maxHP+50 && twice==l && r.housingState.restBattles==1)
        precondition(r.housingBattleLoadout(l,target:"tower")==l)
        print("PASS next battle HP applied through actual loadout once/day, including losses; no tower or repeated-rest stacking")
        var cfg = HousingConfig(strategy:"basic"); cfg.splitSession = true
        let split = make(cfg)
        split.bankState.contracts = [.init(kind:"deposit",principal:60,signedHour:0,maturityHour:30,repayment:72)]
        split.housingState.sessionOffset = 43200; split.day = 1; split.dayMinutes.append(0)
        split.bankBeginDay()
        precondition(split.bankPrincipal == 60 && split.bankHour == 24 && split.housingState.sessionOffset == 0)
        print("PASS second-session offset resets before next-day bank maturity; no 12-hour early payment")

        var bad=HousingConfig(strategy:"basic");bad.poorMeeting=true
        let p=make(bad);p.q=13;p.copper=1000;p.bankBeginDay();let before=p.copper
        p.housingSocial();p.housingSocial()
        precondition(p.copper==before-2 && p.housingState.meetingsFailed==1 && p.housingState.contracts==0)
        let good=make(.init(strategy:"basic"));good.q=13;good.copper=1000;good.bankBeginDay();good.housingSocial();good.housingSocial()
        precondition(good.housingState.contracts==1 && good.housingState.customerEscrow==40 && good.housingState.customerRemaining==360)
        good.day=1;good.dayMinutes.append(0);good.housingSettleContracts();let paid=good.copper;good.housingSettleContracts()
        precondition(good.copper==paid && good.housingState.customerEscrow==0 && good.housingState.contractGross==40)
        print("PASS public meeting alternative, failed talk yields no money, finite client escrow, input cost and once-only next-day delivery")
    }
}
