import Foundation
import Testing
@testable import MistportCombatCore

/// Deterministic scheduler contract model, not a Unity animation or device-play test.
/// Native dispatch deadlines and separate committed impacts are preserved.
/// Enemy callback delays use sampled Unity timing (30 fps); player contacts use
/// the authored VFX contact constants. A 50 ms step is a model, not device input.
enum ProgressionBalanceSimulator {
    struct Report {
        let session: MPCChapterOneEncounterSession
        let seconds: Double
        let medicinesUsed: Int
    }
    static func playerContact(_ skill: FoolSkillID) -> Double {
        switch skill {
        case .sidestepStrike: 0.6192
        case .identityDisplacement: 0.441
        case .fabricatedEvidence: 0.543
        case .mirrorPursuit: 0.705
        case .absurdFinale: 0.885
        case .turnTheTables: 0.63
        case .backstageChange: 0.705
        case .namelessStage: 0.96
        default: 0.38
        }
    }
    static func run(q: Int, sequence: [FoolSkillID], mask: Bool = true,
                    talents: HermitTalentAllocation = .init(), consumables: [String:Int] = [:],
                    priorityCore: Bool = true, maskOffset: Double = 2,
                    ultimate: Bool = false, loadout suppliedLoadout: MPCChapterOneLoadout? = nil,
                    party: MPCPartyPersistentState = .init()) throws -> Report {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: sequence, isUltimateUnlocked: ultimate, passiveIDs: [], relicIDs: [])
        loadout.talents = talents
        if let suppliedLoadout { loadout = suppliedLoadout }
        var s = try MPCChapterOneEncounterSession.start(encounterID: String(format: "chapter01_q%02d_encounter", q), party: party, consumables: consumables, companionIDs: [], loadout: loadout)
        var scheduler = ContinuousSkillScheduler()
        var ready: [String:Double] = [:], pending: [String:Double] = [:], born: [String:Double] = [:]
        var playerReady = 0.0, basicReady = 0.0, maskReady = 0.0, cycle = 0.0, time = 0.0
        var hit: (FoolSkillID?,String,Double)?
        var used = 0, usedUltimate = false, tutorialBasics = 0
        for tick in 0..<3600 where s.outcome == .inProgress {
            let now = Double(tick) * 0.05; time = now
            s.advanceQ4Clock(at: now); _ = s.advanceEmeraldPoison(at: now)
            guard s.outcome == .inProgress else { break }
            let alive = s.enemies.filter(\.isAlive)
            guard let target = (priorityCore ? alive.first { $0.contentID == "enemy_memory_leech_node" } : nil) ?? (q == 10 ? alive.first { $0.contentID == "enemy_calibration_puppet" } : nil) ?? alive.first ?? s.enemies.first else { break }
            for e in alive where born[e.id] == nil { born[e.id] = now }
            if mask && q >= 3 && target.isAlive && now >= maskReady {
                let wants: Bool
                if q == 4 { wants = now >= cycle + 7.8 && now < cycle + 8.4 }
                else if q == 5 { wants = alive.contains { $0.currentIntent == "emerald_burst" || ($0.currentIntent == "charge" && $0.intentIndex % 4 == 2) } }
                else { wants = now >= maskOffset && pending.contains { entry in
                    entry.value >= now && entry.value - now <= 0.3 &&
                    !["guard","fortify","calibrate","recover","repair_guard","charge"].contains(alive.first { $0.id == entry.key }?.currentIntent ?? "")
                } }
                if wants { _ = try s.useOwnedManualMasquerade(targetID: target.id, isOwned: true, at: now); maskReady = now + MPCChapterOneEncounterSession.ownedManualMaskCooldown }
            }
            if s.playerHP <= 400, s.consumables["consumable_pain_salve", default: 0] > 0 {
                try s.useConsumable("consumable_pain_salve"); used += 1
            }
            if s.playerHP <= 300, s.consumables["consumable_mirror_salve", default: 0] > 0 {
                try s.useConsumable("consumable_mirror_salve"); used += 1
            }
            if let p = hit, now >= p.2 {
                hit = nil
                if s.enemies.contains(where: { $0.id == p.1 && $0.isAlive }) {
                    if let skill = p.0 { _ = try s.useFoolSkill(skill, targetID: p.1, usesRealtimeCooldown: true) }
                    else { _ = try s.useBasicAction(.damage, targetID: p.1); tutorialBasics += 1 }
                }
            }
            guard s.outcome == .inProgress else { break }
            for id in pending.keys.sorted() where now >= pending[id]! {
                pending[id] = nil
                guard let e = s.enemies.first(where: { $0.id == id }) else { continue }
                try s.endRound(actingEnemyID: id, at: now)
                if q == 4 && e.currentIntent == "q4_flame_second" { cycle += 20 }
                if q == 6 { ready[id] = now }
                if q == 5 && e.currentIntent == "charge" { ready[id] = now }
                if q == 8 { ready[id] = now + (e.currentIntent == "parasite" ? (e.intentIndex % 5 < 2 ? 1.9 : 0.9) : e.currentIntent == "charge" ? 0.9 : 2.9) }
                if s.outcome != .inProgress { break }
            }
            guard s.outcome == .inProgress else { break }
            for (index,e) in s.enemies.enumerated() where e.isAlive {
                let split = e.contentID == "enemy_resonant_clock_guard_q2_split"
                if split && now < born[e.id,default:now] + 1 { continue }
                let ghost = e.contentID.contains("resonant_clock_guard_q2")
                let hound = ["enemy_clockwork_hound","enemy_emerald_revenant"].contains(e.contentID)
                let core = e.contentID == "enemy_memory_leech_node"
                if ready[e.id] == nil { ready[e.id] = q == 6 || hound ? now : now + (q == 8 ? 2.9 : split ? 0.5 + Double(index % 2) * 0.25 : 2.4 + Double(index) * 0.35) }
                if q == 4 { ready[e.id] = cycle + (e.currentIntent == "q4_probe" ? 2 : e.currentIntent == "charge" ? 6 : e.currentIntent == "q4_flame_first" ? 8 : 8.65) }
                guard now >= ready[e.id]!, pending[e.id] == nil else { continue }
                ready[e.id] = now + (q == 7 ? (core ? 4 : 4.8) : ghost ? (index.isMultiple(of: 2) ? 4 : 4.8) : hound ? 3 : core ? 5 : 3.2) * e.attackIntervalMultiplier
                if s.consumeEnemyDelay(for: e.id) { if q == 8 { ready[e.id] = now + 4 }; continue }
                var duration = q == 4 ? 0.45 : e.contentID.contains("memory_leech") && !core ? 1.1 : ghost ? (split ? 0.68 : 0.94) : hound ? 1.1 : 0.65
                // Standalone Unity timing capture, 2026-09-15: guards .967,
                // cores .833, leeches 1.067, signature actors 2.067 seconds.
                if !hound && !ghost && !core && !e.contentID.contains("memory_leech") { duration = 0.967 }
                if core { duration = e.currentIntent == "repair_guard" ? 0.85 : 0.833 }
                if e.contentID.contains("memory_leech") && !core { duration = 1.067 }
                if q == 6 || q == 10 || (q == 15 && !core) { duration = 2.067 }
                if ["guard","fortify","calibrate","calibration"].contains(e.currentIntent) && !core { duration = 0.65 }
                if q == 13 && e.currentIntent == "thirteenth_charge" { duration = 2.04 }
                if q == 13 && e.currentIntent == "recover" { duration = 0.65 }
                if q == 6 && ["guard","recover"].contains(e.currentIntent) { duration = 3 }
                if e.currentIntent == "charge" && [4,5,8].contains(q) { duration = q == 5 ? 3 : 2 }
                s.commitEnemyImpact(from: e.id); pending[e.id] = now + duration
            }
            let revealingGhost = s.enemies.contains { $0.isAlive && $0.contentID == "enemy_resonant_clock_guard_q2_split" && now < born[$0.id,default:now] + 1 }
            guard !revealingGhost, target.isAlive, now >= playerReady, hit == nil else { continue }
            if ultimate && !usedUltimate { usedUltimate = true; scheduler.didCast(.namelessStage, at:now); playerReady=now+1.75; hit=(.namelessStage,target.id,now+playerContact(.namelessStage)) }
            else if (q != 1 || tutorialBasics >= 3), let skill = scheduler.next(in: sequence, at: now) { scheduler.didCast(skill,at:now); playerReady=now+1.75; hit=(skill,target.id,now+playerContact(skill)) }
            else if now >= basicReady { basicReady=now+2.4; playerReady=now+1.65; hit=(nil,target.id,now+0.58) }
        }
        return .init(session:s,seconds:time,medicinesUsed:used)
    }
}

@Suite("Progression balance 20260915")
struct ProgressionBalance20260915Tests {
    @Test func earlyRetriesNeverRequireExhaustedMedicine() throws {
        let q2 = try ProgressionBalanceSimulator.run(q:2,sequence:[.sidestepStrike],mask:false,consumables:[:])
        print("RETRY_MATH q=2 hp=\(q2.session.playerHP) seconds=\(q2.seconds) outcome=\(q2.session.outcome)")
        #expect(q2.session.outcome == .victory)
        #expect(q2.session.playerHP >= 100)
        #expect(q2.medicinesUsed == 0)
        let q3 = try ProgressionBalanceSimulator.run(q:3,sequence:[.sidestepStrike],mask:true,consumables:[:],maskOffset:2)
        print("RETRY_MATH q=3 hp=\(q3.session.playerHP) seconds=\(q3.seconds) outcome=\(q3.session.outcome)")
        #expect(q3.session.outcome == .victory)
        #expect(q3.medicinesUsed == 0)
    }
    @Test func independentRepairCastersFreezeNilAndLivingRecipientSeparately() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID:"chapter01_q15_encounter",companionIDs:[])
        let cores = s.enemies.filter { $0.contentID == "enemy_memory_leech_node" }
        let body = try #require(s.enemies.first { $0.contentID != "enemy_memory_leech_node" })
        let emptyCaster = try #require(cores.first { $0.currentIntent == "repair_guard" })
        let nextCaster = try #require(cores.first { $0.currentIntent == "memory_strike" })
        s.commitEnemyImpact(from:emptyCaster.id)
        #expect(s.repairTargetID(for:emptyCaster.id) == nil)
        try s.endRound(actingEnemyID:nextCaster.id)
        _ = try s.applyPartyDamage(400,to:body.id)
        s.commitEnemyImpact(from:nextCaster.id)
        #expect(s.repairTargetID(for:nextCaster.id) == body.id)
        #expect(s.repairTargetID(for:emptyCaster.id) == nil)
        let before = s.enemies.first { $0.id == body.id }!.hp
        try s.endRound(actingEnemyID:emptyCaster.id)
        #expect(s.enemies.first { $0.id == body.id }!.hp == before)
        try s.endRound(actingEnemyID:nextCaster.id)
        #expect(s.enemies.first { $0.id == body.id }!.hp == before + body.maxHP * 12 / 100)
    }
    @Test func anotherEnemyCannotEraseFortifyCounterWindow() throws {
        let loadout = MPCChapterOneLoadout(normalSkillIDs:[.turnTheTables],isUltimateUnlocked:false,passiveIDs:[],relicIDs:[])
        var s = try MPCChapterOneEncounterSession.start(encounterID:"chapter01_q14_encounter",companionIDs:[],loadout:loadout)
        let puppet = try #require(s.enemies.first { $0.contentID == "enemy_calibration_puppet" })
        let leech = try #require(s.enemies.first { $0.contentID == "enemy_memory_leech" })
        try s.endRound(actingEnemyID:puppet.id)
        #expect(s.enemyDefenseBonusBP(for:puppet.id) == 5000)
        try s.endRound(actingEnemyID:leech.id)
        #expect(s.enemyDefenseBonusBP(for:puppet.id) == 5000)
        _ = try s.useFoolSkill(.turnTheTables,targetID:puppet.id,usesRealtimeCooldown:true)
        #expect(s.enemyDefenseBonusBP(for:puppet.id) == 0)
        #expect(s.foolState(for:puppet.id)?.misalignmentStacks == 1)
    }
    @Test func finaleTargetPriorityChangesSurvival() throws {
        let skills: [FoolSkillID] = [.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.absurdFinale]
        let talents = HermitTalentAllocation.restored(["trickery.0","trickery.1","trickery.2","trickery.3"],budget:4)
        let supportFirst = try ProgressionBalanceSimulator.run(q:15,sequence:skills,talents:talents,priorityCore:true,ultimate:true)
        let bodyFirst = try ProgressionBalanceSimulator.run(q:15,sequence:skills,talents:talents,priorityCore:false,ultimate:true)
        #expect(supportFirst.session.outcome == .victory)
        #expect(bodyFirst.session.outcome == .defeat)
    }
    @Test func legalGrowthAndThreeBranches() throws {
        for q in 10...15 {
            for branch in ["trickery", "phantom", "omen"] {
                for upgrade in [false,true] {
                    let seq: [FoolSkillID] = q == 10 ? [.sidestepStrike,.identityDisplacement] : q == 11 ? [.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.sidestepStrike] : [.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.absurdFinale]
                    var loadout = MPCChapterOneLoadout(normalSkillIDs:seq,isUltimateUnlocked:q>=14,passiveIDs:[],relicIDs:[])
                    loadout.talents = .restored((0...3).map { "\(branch).\($0)" },budget:4)
                    loadout.churchGear = EarnedChapterAuditFixture.wallGear(beforeOrAt: q)
                    loadout.bountyRelicID = EarnedChapterAuditFixture.wallRelic(q)
                    #expect(loadout.talents.learned.count == 4)
                    if upgrade {
                        // Q9 earns 30 dust: one Lv2. Q14 earns the next 30:
                        // two different Lv2 cards, never an unaffordable Lv3.
                        #expect(MPCSkillGrowth.upgradeCost(from:1) == 30)
                        loadout.skillLevels[.identityDisplacement] = 2
                        if q == 15 { loadout.skillLevels[.mirrorPursuit] = 2 }
                    }
                    var victories = 0
                    let alternatives: [[FoolSkillID]] = q == 10 ? [seq, [.fabricatedEvidence,.sidestepStrike]] : q >= 12 ? [seq, [.sidestepStrike,.fabricatedEvidence,.mirrorPursuit,.absurdFinale], [.fabricatedEvidence,.mirrorPursuit,.turnTheTables,.absurdFinale]] : [seq]
                    for chosenCards in alternatives where q >= 13 || !chosenCards.contains(.turnTheTables) {
                    loadout.normalSkillIDs = chosenCards
                    // Each branch retains a legal route, not a guarantee for arbitrary timing.
                    for passive in ["relic_salt_sealed_breathing_bag", "relic_return_gift_clasp"] {
                        loadout.relicIDs = [passive]
                        for offset in [6.0, 14.0] {
                            let r = try NewMaskBalanceSimulator.run(q:q,sequence:chosenCards,mask:false,
                                consumables:["consumable_pain_salve":1],ultimate:q>=14,
                                loadout:loadout,medalOffset:offset)
                            if r.session.outcome == .victory { victories += 1 }
                            #expect(r.maskUses == 0 && r.medicinesUsed <= 1)
                        }
                    }
                    }
                    #expect(victories > 0, "Q\(q) \(branch) upgrade=\(upgrade) has no legal route")
                }
            }
        }
    }
    @Test func laterStrategySensitivity() throws {
        for q in 9...15 {
            let seq: [FoolSkillID] = q <= 10 ? [.sidestepStrike,.identityDisplacement] : q == 11 ? [.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.sidestepStrike] : [.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.absurdFinale]
            let talents: HermitTalentAllocation = q >= 10 ? .restored(["trickery.0","trickery.1","trickery.2","trickery.3"],budget:4) : .init()
            for policy in 0...2 {
                let result = try ProgressionBalanceSimulator.run(q:q,sequence:policy == 2 ? [.sidestepStrike] : seq,mask:policy != 2,talents:talents,priorityCore:policy == 0,ultimate:q>=14 && policy != 2)
                print("STRATEGY_MATH q=\(q) policy=\(policy) outcome=\(result.session.outcome) time=\(result.seconds) hp=\(result.session.playerHP)")
            }
        }
    }
    @Test func earnedBuildsAndInventoryLedger() throws {
        var copper = 180, jobs = 0, items = ["consumable_pain_salve": 1]
        for q in 1...15 {
            if q == 5 { copper -= 280 } // Purchase both alternative passives once.
            if q >= 5, items["consumable_pain_salve", default:0] == 0 {
                // Core ledger assumes completed J0 work; it does not exercise its native UI.
                while copper < 30 { copper += 40; jobs += 1 }
                #expect(copper >= 30)
                copper -= 30; items["consumable_pain_salve"] = 1
            }
            let seq: [FoolSkillID] = q < 8 ? [.sidestepStrike] : q <= 10 ? [.sidestepStrike,.identityDisplacement] : q == 11 ? [.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.sidestepStrike] : [.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.absurdFinale]
            var candidates: [NewMaskBalanceSimulator.Report] = []
            let options: [[FoolSkillID]] = q >= 12 ? [seq, [.sidestepStrike,.fabricatedEvidence,.mirrorPursuit,.absurdFinale]] : [seq]
            for chosen in options {
            for relic in q >= 5 ? ["relic_salt_sealed_breathing_bag", "relic_return_gift_clasp"] : [""] {
                for offset in q >= 5 ? [6.0,14.0] : [0.0] {
                    var loadout = MPCChapterOneLoadout(normalSkillIDs:chosen,isUltimateUnlocked:q>=14,passiveIDs:[],relicIDs:relic.isEmpty ? [] : [relic])
                    if q >= 10 { loadout.talents = .restored((0...3).map { "trickery.\($0)" },budget:4) }
                    loadout.churchGear = EarnedChapterAuditFixture.wallGear(beforeOrAt: q)
                    loadout.bountyRelicID = EarnedChapterAuditFixture.wallRelic(q)
                    candidates.append(try NewMaskBalanceSimulator.run(q:q,sequence:chosen,mask:q<=4,
                        consumables:items,ultimate:q>=14,loadout:loadout,medalOffset:q>=5 ? offset : nil,precise:true))
                }
            }
            }
            let result = try #require(candidates.filter { $0.session.outcome == .victory }.min { $0.medicinesUsed < $1.medicinesUsed }, "No earned route at Q\(q)")
            #expect(result.seconds < 65)
            items = result.session.consumables
            copper += try #require(MPCChapterOneThirtyMissionContract.firstClear(for:q)).copper
            #expect(copper >= 0 && items.values.allSatisfy { $0 >= 0 })
        }
        #expect(jobs <= 4)
        print("Q1–15 ledger completed J0 jobs=\(jobs), copper=\(copper)")
    }

}

@Suite("Q6 true ward balance")
struct Q6TrueWardBalanceTests {
    @Test func earnedReturnClaspAndMedalTimingRoutes() throws {
        for offset in [6.0, 14.0] {
            let loadout = MPCChapterOneLoadout(normalSkillIDs:[.sidestepStrike],isUltimateUnlocked:false,passiveIDs:[],relicIDs:["relic_return_gift_clasp"])
            let r = try NewMaskBalanceSimulator.run(q:6,sequence:[.sidestepStrike],mask:false,
                consumables:["consumable_pain_salve":1],loadout:loadout,medalOffset:offset)
            #expect(r.session.outcome == .victory && r.seconds < 65)
            #expect(r.maskUses == 0 && r.medicinesUsed <= 1)
        }
        let unprotected = try NewMaskBalanceSimulator.run(q:6,sequence:[.sidestepStrike],mask:false)
        #expect(unprotected.session.outcome == .defeat)
    }
}
