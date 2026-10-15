import Foundation
import Testing
@testable import MistportCombatCore

// Test-only cadence adapted from TowerHundredSimulator. Existing content, no
// artificial HP/damage, no victories forced, no real saves. This is not device
// telemetry and does not validate the new campaign NPCs or human difficulty.
enum CampaignCombatProbe {
    static func run(encounterID: String, mission q: Int, offset: Double, passive: String? = nil, gearFloor: Int = 30, medicines: Int = 0, useMedal: Bool = true, jitter: Double = 0, seed: UInt64 = 1, onFinished: ((Double) -> Void)? = nil) throws -> MPCChapterOneEncounterSession {
        var randomState = seed
        func variation() -> Double {
            randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
            return (Double((randomState >> 32) % 10001) / 5000 - 1) * jitter
        }
        var nextMedalAt = max(0, offset + variation())
        let sequence: [FoolSkillID] = q < 8 ? [.sidestepStrike] : q < 9 ? [.identityDisplacement, .sidestepStrike] : q < 11 ? [.fabricatedEvidence, .identityDisplacement, .sidestepStrike] : q < 12 ? [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .sidestepStrike] : [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .absurdFinale]
        var loadout = MPCChapterOneLoadout(normalSkillIDs: sequence, isUltimateUnlocked: false, passiveIDs: [], relicIDs: passive.map { [$0] } ?? [])
        loadout.selectedActiveRelicID = useMedal ? MPCChapterOneCatalog.usurpedLifeMedalRelicID : nil
        var earnedGear = MPCChurchGearLedger()
        for cleared in 1...gearFloor {
            if let drop = MPCChurchGearCatalog.towerDrop(floor: cleared) { earnedGear.grant(drop.id) }
        }
        loadout.churchGear = earnedGear.stats
        let budget = (1...q).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for: $0)?.talentPoints }.reduce(0, +)
        loadout.talents = HermitTalentAllocation.restored((0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" }, budget: budget)
        var s = try MPCChapterOneEncounterSession.start(encounterID: encounterID, consumables: ["consumable_pain_salve": medicines], companionIDs: [], loadout: loadout)
        var scheduler = ContinuousSkillScheduler(), playerAt = 0.0, basicAt = 0.0
        var hit: (FoolSkillID?, String, Double)?
        var ready: [String: Double] = [:], pending: [String: Double] = [:]
        var elapsed = 0.0
        for tick in 0..<7200 where s.outcome == .inProgress {
            let now = Double(tick) * 0.05
            elapsed = now
            _ = s.advanceEmeraldPoison(at: now)
            guard s.outcome == .inProgress else { break }
            if s.playerHP * 2 < s.playerNormalMaxHP, s.consumables["consumable_pain_salve", default: 0] > 0 {
                do { try s.useConsumable("consumable_pain_salve") }
                catch MPCEncounterRuntimeError.noHealingNeeded { /* Actual temporary healing block. */ }
            }
            let alive = s.enemies.filter(\.isAlive)
            // Target selection is a supported player action, with support-first priority.
            let target = alive.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .backSac }
                ?? alive.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .crown }
                ?? alive.first { $0.contentID.hasPrefix("bounty_b03_escort_") }
                ?? alive.first { $0.currentIntent != "guard" } ?? alive.first
            if let target {
                s.updateRelicTarget(target.id, at: now)
                if useMedal && now >= nextMedalAt && target.currentIntent != "guard" {
                    if s.activateUsurpedLifeMedal(isOwned: true, at: now) { nextMedalAt = s.usurpedLifeMedalReadyAt + max(0, variation()) }
                }
            }
            if let p = hit, now >= p.2 {
                hit = nil
                if s.enemies.contains(where: { $0.id == p.1 && $0.isAlive }) {
                    if let skill = p.0 { _ = try s.useFoolSkill(skill, targetID: p.1, usesRealtimeCooldown: true) }
                    else { _ = try s.useBasicAction(.damage, targetID: p.1) }
                }
            }
            guard s.outcome == .inProgress else { break }
            for id in pending.keys.sorted() where now >= pending[id]! {
                pending[id] = nil
                guard s.enemies.contains(where: { $0.id == id }) else { continue }
                try s.endRound(actingEnemyID: id, at: now)
                ready[id] = now
                if s.outcome != .inProgress { break }
            }
            guard s.outcome == .inProgress else { break }
            for enemy in s.enemies.filter(\.isAlive) {
                if ready[enemy.id] == nil { ready[enemy.id] = now + (MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID)?.initialDelay ?? 3) }
                guard now >= ready[enemy.id]!, pending[enemy.id] == nil else { continue }
                // One active high-threat preparation at a time; ordinary contacts
                // still use their own deadlines and are never silently skipped.
                let preparation = s.authoredPreparationDuration(for: enemy.id)
                if s.churchPreparationMustWait(enemyID: enemy.id, pendingEnemyIDs: Set(pending.keys)) { continue }
                if s.consumeEnemyDelay(for: enemy.id) { ready[enemy.id] = now + 3.2 * enemy.attackIntervalMultiplier; continue }
                let contact = MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID) == nil ? 1.0 : MPCChurchTowerCatalog.contactDuration(contentID: enemy.contentID, intent: enemy.currentIntent)
                s.commitEnemyImpact(from: enemy.id)
                pending[enemy.id] = now + (preparation ?? max(0.15, contact + variation()))
            }
            guard let target, s.enemies.contains(where: { $0.id == target.id && $0.isAlive }), now >= playerAt, hit == nil else { continue }
            if let skill = scheduler.next(in: sequence, at: now) {
                scheduler.didCast(skill, at: now); playerAt = now + 1.75 + max(0, variation())
                hit = (skill, target.id, now + max(0.15, NewMaskBalanceSimulator.playerContact(skill) + variation()))
            } else if now >= basicAt {
                basicAt = now + 2.4; playerAt = now + 1.65 + max(0, variation())
                hit = (nil, target.id, now + max(0.15, 0.58 + variation()))
            }
        }
        onFinished?(elapsed)
        return s
    }
}

@Suite("Campaign preparation probe using real combat rules")
struct CampaignCombatProbeTests {
    @Test func compareLoadoutsSuppliesAndWear() throws {
        for encounter in ["church_bounty_b03", "church_bounty_b06", "church_tower_090"] {
            for gear in [30, 100] {
                for passive in [nil, "relic_return_gift_clasp", "relic_sealed_paperweight", "relic_salt_sealed_breathing_bag"] as [String?] {
                    for medicines in [0, 3] {
                        for useMedal in [false, true] {
                        for seed: UInt64 in [101, 211, 307] {
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
