// Copied from output/chapter1-audit-20260925/progression (Codex, 2026-09-25); renamed only.
import Foundation
import MistportCombatCore

/// Deterministic scheduler contract model, not a Unity animation or device-play test.
/// Native dispatch deadlines and separate committed impacts are preserved.
/// Enemy callback delays use sampled Unity timing (30 fps); player contacts use
/// the authored VFX contact constants. A 50 ms step is a model, not device input.
enum ChapterDriver {
    struct Report {
        let session: MPCChapterOneEncounterSession
        let seconds: Double
        let medicinesUsed: Int
        let maskUses: Int
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
                    party: MPCPartyPersistentState = .init(), medalOffset: Double? = nil, skipQ4Cycle: Int? = nil, precise: Bool = false, relicBalance: MPCSequenceNineRelicBalance = .init(), actionDelay: Double = 0) throws -> Report {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: sequence, isUltimateUnlocked: ultimate, passiveIDs: [], relicIDs: [])
        loadout.talents = talents
        if let suppliedLoadout { loadout = suppliedLoadout }
        if medalOffset != nil { loadout.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID }
        var s = try MPCChapterOneEncounterSession.start(encounterID: String(format: "chapter01_q%02d_encounter", q), party: party, consumables: consumables, companionIDs: [], loadout: loadout)
        s.relicBalance = relicBalance
        var scheduler = ContinuousSkillScheduler()
        var ready: [String:Double] = [:], pending: [String:Double] = [:], born: [String:Double] = [:]
        var playerReady = 0.0, basicReady = 0.0, maskReady = 0.0, cycle = 0.0, time = 0.0
        var hit: (FoolSkillID?,String,Double)?
        var maskUses = 0
        var used = 0, usedUltimate = false, tutorialBasics = 0
        for tick in 0..<3600 where s.outcome == .inProgress {
            let now = Double(tick) * 0.05; time = now
            s.advanceQ4Clock(at: now); _ = s.advanceEmeraldPoison(at: now)
            guard s.outcome == .inProgress else { break }
            let alive = s.enemies.filter(\.isAlive)
            guard let target = (priorityCore ? alive.first { $0.contentID == "enemy_memory_leech_node" } : nil) ?? (q == 27 ? alive.first { $0.contentID == "enemy_clockwork_hound" } : nil) ?? (q == 29 ? alive.first { $0.contentID != "boss_chronarch_sovereign" } : nil) ?? alive.first ?? s.enemies.first else { break }
            s.updateRelicTarget(target.id, at: now)
            for e in alive where born[e.id] == nil { born[e.id] = now }
            if let medalOffset, now >= medalOffset, now >= s.usurpedLifeMedalReadyAt {
                _ = s.activateUsurpedLifeMedal(isOwned: true, at: now)
            }
            if mask && q >= 3 && target.isAlive && now >= maskReady {
                let wants: Bool
                if q == 4 { wants = now >= cycle + 7.8 && now < cycle + 8.4 && skipQ4Cycle != Int(cycle / 20) }
                else if q == 5 { wants = alive.contains { $0.currentIntent == "emerald_burst" || ($0.currentIntent == "charge" && $0.intentIndex % 4 == 2) } }
                else if precise { wants = pending.contains { entry in entry.value - now <= 0.3 && entry.value >= now && !["guard","fortify","calibrate","recover","repair_guard","charge"].contains(s.enemies.first { $0.id == entry.key }?.currentIntent ?? "") } }
                else { wants = now >= maskOffset }
                if wants { if try s.useOwnedManualMasquerade(targetID: target.id, isOwned: true, at: now) != nil { maskUses += 1 }; maskReady = now + 18 }
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
                if let delay = s.authoredRecoveryDelay(after: e.currentIntent, enemyID: id) { ready[id] = now + delay }
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
                if q == 6 && ["guard","recover"].contains(e.currentIntent) { duration = e.currentIntent == "recover" ? MPCChapterOneEncounterSession.archiveRecoveryDuration : 3 }
                if e.currentIntent == "charge" && [4,5,8].contains(q) { duration = q == 5 ? 3 : 2 }
                if let authored = s.authoredPreparationDuration(for: e.id) { duration = authored }
                s.commitEnemyImpact(from: e.id); pending[e.id] = now + duration
            }
            let revealingGhost = s.enemies.contains { $0.isAlive && $0.contentID == "enemy_resonant_clock_guard_q2_split" && now < born[$0.id,default:now] + 1 }
            guard !revealingGhost, target.isAlive, now >= playerReady, hit == nil else { continue }
            if ultimate && !usedUltimate { usedUltimate = true; scheduler.didCast(.namelessStage, at:now); playerReady=now+1.75+actionDelay; hit=(.namelessStage,target.id,now+playerContact(.namelessStage)) }
            else if (q != 1 || tutorialBasics >= 3), let skill = scheduler.next(in: sequence, at: now) { scheduler.didCast(skill,at:now); playerReady=now+1.75+actionDelay; hit=(skill,target.id,now+playerContact(skill)) }
            else if now >= basicReady { basicReady=now+2.4; playerReady=now+1.65+actionDelay; hit=(nil,target.id,now+0.58) }
        }
        return .init(session:s,seconds:time,medicinesUsed:used,maskUses:maskUses)
    }
}


