// Copied from output/chapter1-audit-20260925/progression (Codex, 2026-09-25); renamed only.
import Foundation
import MistportCombatCore

/// Deterministic scheduler contract model, not a Unity animation or device-play test.
/// Native dispatch deadlines and separate committed impacts are preserved.
/// Enemy callback delays use sampled Unity timing (30 fps); player contacts use
/// the authored VFX contact constants. A 50 ms step is a model, not device input.
enum ChapterDriver {
    static let trace = ProcessInfo.processInfo.environment["TRACE"] != nil
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
        var stepper = try MPCStoryBattleStepper(encounterID: encounterID, loadout: loadout, consumables: consumables, party: party,
                                                mask: mask ? .init(owned: true, teachingLoan: q == 3 || q == 4) : nil,
                                                tuning: .init(actionDelay: actionDelay, tempo: tempo)) { $0.relicBalance = relicBalance }
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
            do { stats.record(try stepper.step(out), session: stepper.session) }
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
}
