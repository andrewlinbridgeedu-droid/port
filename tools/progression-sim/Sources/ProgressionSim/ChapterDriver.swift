// Copied from output/chapter1-audit-20260925/progression (Codex, 2026-09-25); renamed only.
import Foundation
import MistportCombatCore

/// Deterministic scheduler contract model, not a Unity animation or device-play test.
/// Native dispatch deadlines and separate committed impacts are preserved.
/// Enemy callback delays use sampled Unity timing (30 fps); player contacts use
/// the authored VFX contact constants. A 50 ms step is a model, not device input.
enum ChapterDriver {
    static let trace = ProcessInfo.processInfo.environment["TRACE"] != nil
    /// `BLESSINGS=lamp_wick,salt_crust`: the Q30 离场祝福 pair (hero, sovereign) applied at the start,
    /// as the App does after its roll; unset, no blessing. Other missions ignore it.
    static let farewell: MPCFarewellBlessings? = {
        guard let text = ProcessInfo.processInfo.environment["BLESSINGS"], !text.isEmpty else { return nil }
        let parts = text.split(separator: ",").map(String.init)
        guard parts.count == 2, let hero = MPCFarewellBlessings.Hero(rawValue: parts[0]),
              let sovereign = MPCFarewellBlessings.Sovereign(rawValue: parts[1]) else { fatalError("BLESSINGS=<hero>,<sovereign>, got \(text)") }
        return .init(hero: hero, sovereign: sovereign)
    }()
    struct Report {
        let session: MPCChapterOneEncounterSession
        let seconds: Double
        let medicinesUsed: Int
        let maskUses: Int
        var tempoStats = MPCTempoStats()
    }
    static func playerContact(_ skill: FoolSkillID) -> Double { MPCChurchBattleDriver.playerContact(skill) }
    /// Since story-battle-v1 the battle is `MPCStoryBattleStepper` (the App's rules); this
    /// keeps the audit's choices as player inputs: target the memory core (Q27 the hound,
    /// Q29 anything but the sovereign), the mask by mission (Q4 hound cycle, Q5 bursts,
    /// otherwise just before a hit lands when `precise`), the medal from `medalOffset`,
    /// a pain salve under 400 HP and a mirror salve under 300 HP, the ultimate once.
    static func run(q: Int, sequence: [FoolSkillID], mask: Bool = true,
                    talents: HermitTalentAllocation = .init(), consumables: [String:Int] = [:],
                    priorityCore: Bool = true, maskOffset: Double = 2,
                    ultimate: Bool = false, loadout suppliedLoadout: MPCChapterOneLoadout? = nil,
                    party: MPCPartyPersistentState = .init(), medalOffset: Double? = nil, skipQ4Cycle: Int? = nil, precise: Bool = false, relicBalance: MPCSequenceNineRelicBalance = .init(), actionDelay: Double = 0, tempo: MPCTempoChoice = .automatic) throws -> Report {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: sequence, isUltimateUnlocked: ultimate, passiveIDs: [], relicIDs: [])
        loadout.talents = talents
        if let suppliedLoadout { loadout = suppliedLoadout }
        if medalOffset != nil { loadout.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID }
        let encounterID = String(format: "chapter01_q%02d_encounter", q)
        // Q28–Q30 are party fights (2026-10-10): forward the mission's allies as the App does.
        var stepper = try MPCStoryBattleStepper(encounterID: encounterID, loadout: loadout, consumables: consumables, party: party,
                                                companionIDs: MPCChapterOneCatalog.mission(forEncounterID: encounterID)?.companionIDs ?? [],
                                                mask: mask ? .init(owned: true, teachingLoan: q == 3 || q == 4) : nil,
                                                tuning: .init(actionDelay: actionDelay, tempo: tempo)) {
            $0.relicBalance = relicBalance
            if let farewell { $0.applyFarewellBlessings(farewell) }
        }
        var stats = MPCTempoStats()
        var used = 0, ultimateAsked = false
        let quiet: Set<String> = ["guard", "fortify", "calibrate", "recover", "repair_guard", "charge"]
        while !stepper.isFinished {
            let view = stepper.view
            guard view.session.outcome == .inProgress else { _ = try stepper.step(); continue }
            var trial = view.session
            let now = view.now
            var out: [MPCBattleInput] = []
            let alive = trial.enemies.filter(\.isAlive)
            if let target = (priorityCore ? alive.first { $0.contentID == "enemy_memory_leech_node" } : nil)
                ?? (q == 27 ? alive.first { $0.contentID == "enemy_clockwork_hound" } : nil)
                ?? (q == 29 ? alive.first { $0.contentID != "boss_chronarch_sovereign" } : nil) ?? alive.first {
                if target.id != view.target { out.append(.init(tick: view.tick, kind: .target, enemyID: target.id)) }
                if let medalOffset, now >= medalOffset, trial.activateUsurpedLifeMedal(isOwned: true, at: now) {
                    out.append(.init(tick: view.tick, kind: .medal))
                }
                if mask, q >= 3, stepper.maskIsReady(at: now) {
                    let wants: Bool
                    if q == 4, let cycle = stepper.q4CycleStart { wants = now >= cycle + 7.8 && now < cycle + 8.4 && skipQ4Cycle != Int(cycle / 20) }
                    else if q == 5 { wants = alive.contains { $0.currentIntent == "emerald_burst" || ($0.currentIntent == "charge" && $0.intentIndex % 4 == 2) } }
                    else if precise {
                        wants = view.incoming.contains { id, landsAt in
                            let left = Double(landsAt - view.tick) * MPCChurchBattleDriver.step
                            return left <= 0.3 && left >= 0 && !quiet.contains(trial.enemies.first { $0.id == id }?.currentIntent ?? "")
                        }
                    } else { wants = now >= maskOffset }
                    if wants { out.append(.init(tick: view.tick, kind: .mask)) }
                }
            }
            if trial.playerHP <= 400, trial.consumables["consumable_pain_salve", default: 0] > 0, (try? trial.useConsumable("consumable_pain_salve")) != nil {
                out.append(.init(tick: view.tick, kind: .consumable, itemID: "consumable_pain_salve")); used += 1
            }
            if trial.playerHP <= 300, trial.consumables["consumable_mirror_salve", default: 0] > 0, (try? trial.useConsumable("consumable_mirror_salve")) != nil {
                out.append(.init(tick: view.tick, kind: .consumable, itemID: "consumable_mirror_salve")); used += 1
            }
            if ultimate, !ultimateAsked, loadout.isUltimateUnlocked, trial.canUseFoolSkill(.namelessStage) {
                ultimateAsked = true
                out.append(.init(tick: view.tick, kind: .ultimate))
            }
            do {
                let events = try stepper.step(out)
                stats.record(events, session: stepper.session)
                if trace { printTrace(events, stepper.session, at: now) }
            }
            catch MPCChurchBattleDriver.Failure.refused {
                // A choice the rules refuse at this step (for example the mask after the
                // medal): drop it and step without inputs, as a client would.
                if out.contains(where: { $0.kind == .consumable }) { used -= out.filter { $0.kind == .consumable }.count }
                stats.record(try stepper.step([]), session: stepper.session)
            }
        }
        return .init(session: stepper.session, seconds: max(0, stepper.now - MPCChurchBattleDriver.step),
                     medicinesUsed: used, maskUses: stepper.maskUses, tempoStats: stats)
    }

    /// TRACE=1: every enemy action that resolved this step, with the party's health.
    static func printTrace(_ events: MPCChurchBattleStepper.Events, _ s: MPCChapterOneEncounterSession, at now: Double) {
        if events.landed != nil, ProcessInfo.processInfo.environment["TRACE"] == "2" {
            for a in s.lastCompanionActions { print(String(format: "%6.2fs", now) + "    ally \(a.message)") }
        }
        for id in events.enemyResolved {
            for r in s.lastEnemyActionResolutions where r.enemyID == id {
                let enemy = s.enemies.first { $0.id == id }
                var parts = [String(format: "%6.2fs", now), r.intent.padding(toLength: 17, withPad: " ", startingAt: 0),
                             "hero -\(r.playerDamage) → \(s.playerHP)/\(s.playerMaxHP)", "boss \(enemy?.hp ?? 0)"]
                if !r.allyDamage.isEmpty { parts.append("allies " + r.allyDamage.sorted { $0.key < $1.key }.map { "\($0.key.dropFirst(5))-\($0.value)" }.joined(separator: " ")) }
                if let by = r.interceptedBy { parts.append("intercept \(by.dropFirst(5))") }
                if let skill = r.sealedSkillID { parts.append("seal \(skill.rawValue)") }
                if let ally = r.sealedAllyID { parts.append("seal \(ally.dropFirst(5))") }
                if !s.activeCompanionIDs.isEmpty { parts.append("[" + s.activeCompanionIDs.map { "\($0.dropFirst(5)) \(s.allyHP[$0, default: 0])" }.joined(separator: ", ") + "] revive \(s.sharedReviveCharges)") }
                print(parts.joined(separator: "  "))
            }
        }
    }
}
