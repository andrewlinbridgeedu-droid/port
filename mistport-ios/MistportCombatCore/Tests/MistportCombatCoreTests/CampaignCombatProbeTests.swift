import Foundation
import Testing
@testable import MistportCombatCore

// The church stepper (the App's loop, 2026-10-15) with the stage hand after Q`mission`, a pain salve under
// half health and the medal on its cooldown. Existing content, no artificial HP/damage, no victories forced,
// no real saves. This is not device telemetry and does not validate the new campaign NPCs or human difficulty.
enum CampaignCombatProbe {
    static func run(encounterID: String, mission q: Int, offset: Double, passive: String? = nil, gearFloor: Int = 30, medicines: Int = 0, useMedal: Bool = true, jitter: Double = 0, seed: UInt64 = 1, onFinished: ((Double) -> Void)? = nil) throws -> MPCChapterOneEncounterSession {
        var loadout = MPCStageLoadout.loadout(before: q + 1, order: RealLoop.towerHand(before: q + 1), gear: MPCStageLoadout.towerGear(through: gearFloor),
                                              passive: passive, activeRelic: RealLoop.medal)
        if !useMedal { loadout.selectedActiveRelicID = nil }
        var stepper = try MPCChurchBattleStepper(encounterID: encounterID, loadout: loadout, consumables: ["consumable_pain_salve": medicines],
                                                 tuning: .init(jitter: jitter, seed: seed))
        var nextMedalAt = offset
        while !stepper.isFinished {
            let view = stepper.view
            guard view.session.outcome == .inProgress else { _ = try stepper.step(); continue }
            var trial = view.session, out: [MPCBattleInput] = []
            if useMedal, view.now >= nextMedalAt, trial.activateUsurpedLifeMedal(isOwned: true, at: view.now) {
                out.append(.init(tick: view.tick, kind: .medal)); nextMedalAt = trial.usurpedLifeMedalReadyAt
            }
            if trial.playerHP * 2 < trial.playerNormalMaxHP, trial.consumables["consumable_pain_salve", default: 0] > 0,
               (try? trial.useConsumable("consumable_pain_salve")) != nil {
                out.append(.init(tick: view.tick, kind: .consumable, itemID: "consumable_pain_salve"))
            }
            do { _ = try stepper.step(out) } catch MPCChurchBattleDriver.Failure.refused { _ = try stepper.step() }
        }
        onFinished?(stepper.now)
        return stepper.session
    }
}

@Suite("Campaign preparation probe using real combat rules")
struct CampaignCombatProbeTests {
    /// The full grid (288 church battles) with MISTPORT_CAMPAIGN_PROBE=1; by default one seed, one stock of salves.
    @Test func compareLoadoutsSuppliesAndWear() throws {
        let full = ProcessInfo.processInfo.environment["MISTPORT_CAMPAIGN_PROBE"] != nil
        for encounter in ["church_bounty_b03", "church_bounty_b06", "church_tower_090"] {
            for gear in [30, 100] {
                for passive in [nil, "relic_return_gift_clasp", "relic_sealed_paperweight", "relic_salt_sealed_breathing_bag"] as [String?] {
                    for medicines in full ? [0, 3] : [3] {
                        for useMedal in [false, true] {
                        for seed: UInt64 in full ? [101, 211, 307] : [101] {
                            var duration = 0.0
                            let s = try CampaignCombatProbe.run(encounterID: encounter, mission: 30, offset: 6,
                                passive: passive, gearFloor: gear, medicines: medicines, useMedal: useMedal,
                                jitter: 0.25, seed: seed, onFinished: { duration = $0 })
                            let used = medicines - s.consumables["consumable_pain_salve", default: 0]
                            #expect((0...medicines).contains(used))
                            #expect(s.playerHP >= 0)
                            var ledger = MPCChurchOwnedRelicLedger()
                            let ids: [String] = passive.map { [$0] } ?? []
                            try ledger.beginBattle(battleID: "probe", equippedRelicIDs: ids, ownedRelicIDs: Set(ids))
                            let outcome: MPCChurchBattleOutcome = s.outcome == .victory ? .victory : s.outcome == .defeat ? .defeat : .retreat
                            try ledger.settleBattle(battleID: "probe", outcome: outcome)
                            let repair = try ids.reduce(0) { try $0 + ledger.repairCost($1, ownedRelicIDs: Set(ids)) }
                            let row: [String: Any] = ["encounter": encounter, "gear_floor": gear, "passive": passive ?? "none",
                                "active_medal": useMedal, "carried_medicine": medicines, "seed": seed, "outcome": s.outcome.rawValue,
                                "seconds": duration, "hp": s.playerHP, "medicine_used": used, "repair_copper": repair]
                            let data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
                            print("CAMPAIGN_PROBE " + String(decoding: data, as: UTF8.self))
                        }
                        }
                    }
                }
            }
        }
    }
}
