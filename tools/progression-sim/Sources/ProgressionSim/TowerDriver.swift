// Copied from output/chapter1-audit-20260925/progression (Codex, 2026-09-25); renamed only.
import Foundation
import MistportCombatCore

/// Deterministic driver of the shipping combat core. Never injects damage,
/// healing, HP or unlocks. Native presentation verification is a separate pass.
public enum TowerDriver {
    public enum Route: String, CaseIterable, Sendable { case medal, counter, blankCard, unprepared }
    public struct Report: Sendable {
        public let floor: Int
        public let mission: Int
        public let route: Route
        public let session: MPCChapterOneEncounterSession
        public let seconds: Double
        public let waveEntryHP: [Int]
        public let rosterDescriptors: [[String]]
        public let skillCasts: [String: Int]
        public let medalUses: Int
    }
    public static func mission(for floor: MPCChurchTowerCatalog.Floor) -> Int { max(7, floor.requiredMission) }
    public static func recommendedLoadout(for floor: MPCChurchTowerCatalog.Floor, route: Route = .medal) -> MPCChapterOneLoadout {
        let q = mission(for: floor)
        let cards: [FoolSkillID]
        if route == .unprepared { cards = [] }
        else if q < 8 { cards = [.sidestepStrike] }
        else if q < 11 { cards = [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .sidestepStrike] }
        else if route == .counter { cards = [.turnTheTables, .fabricatedEvidence, .identityDisplacement, .absurdFinale] }
        else { cards = [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .absurdFinale] }
        var loadout = MPCChapterOneLoadout(normalSkillIDs: cards, isUltimateUnlocked: q >= 13 && route != .unprepared, passiveIDs: [], relicIDs: [])
        if route != .unprepared { loadout.selectedActiveRelicID = route == .blankCard && q >= 17 ? "relic_blank_name_card" : MPCChapterOneCatalog.usurpedLifeMedalRelicID }
        let budget = (1...q).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for: $0)?.talentPoints }.reduce(0, +)
        loadout.talents = HermitTalentAllocation.restored((0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" }, budget: budget)
        // Spend only earned chapter dust: Q9 grants 30; Q14 grants another 30.
        // These are two genuine level-1 -> level-2 upgrades, not free levels.
        if q >= 10 { loadout.skillLevels[.mirrorPursuit] = 2 }
        if q >= 14 { loadout.skillLevels[.absurdFinale] = 2 }
        var earnedGear = MPCChurchGearLedger()
        if floor.number > 1 {
            for cleared in 1..<floor.number {
                if let drop = MPCChurchGearCatalog.towerDrop(floor: cleared) { earnedGear.grant(drop.id) }
            }
        }
        loadout.churchGear = earnedGear.stats
        return loadout
    }
    public static func playerContact(_ skill: FoolSkillID) -> Double {
        switch skill {
        case .sidestepStrike: 0.6192
        case .identityDisplacement: 0.441
        case .fabricatedEvidence: 0.543
        case .mirrorPursuit, .backstageChange: 0.705
        case .absurdFinale: 0.885
        case .turnTheTables: 0.63
        case .namelessStage: 0.96
        default: 0.38
        }
    }
    public static func run(number: Int, route: Route = .medal, medalOffset: Double = 22, jitter: Double = 0, seed: UInt64 = 1, passive: String? = nil, suppliedLoadout: MPCChapterOneLoadout? = nil, actionDelay: Double = 0, encounterID: String? = nil) throws -> Report {
        let floor = MPCChurchTowerCatalog.floor(number: number)!
        var loadout = recommendedLoadout(for: floor, route: route)
        if let passive { loadout.relicIDs = [passive] }
        if let suppliedLoadout { loadout = suppliedLoadout }
        let sequence = loadout.normalSkillIDs
        var s = try MPCChapterOneEncounterSession.start(encounterID: encounterID ?? floor.id, companionIDs: [], loadout: loadout)
        var randomState = seed
        func variation() -> Double {
            randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
            return (Double((randomState >> 32) % 10001) / 5000 - 1) * jitter
        }
        var nextMedalAt = max(0, medalOffset + variation())
        var scheduler = ContinuousSkillScheduler(), playerAt = 0.0, basicAt = 0.0
        var hit: (FoolSkillID?, String, Double)?
        var ready: [String: Double] = [:], pending: [String: Double] = [:]
        var elapsed = 0.0, wave = -1, waveHP: [Int] = [], rosters: [[String]] = []
        var casts: [String: Int] = [:], medals = 0
        var ultimateRequested = false
        for tick in 0..<12000 where s.outcome == .inProgress {
            let now = Double(tick) * 0.05
            elapsed = now
            _ = s.advanceEmeraldPoison(at: now)
            guard s.outcome == .inProgress else { break }
            if wave != s.waveIndex {
                wave = s.waveIndex; waveHP.append(s.playerHP)
                rosters.append(s.enemies.compactMap { MPCChapterOneBattleIdentity.visualDescriptor(for: $0.id, in: s.enemies, encounterID: s.encounter.id) })
            }
            let alive = s.enemies.filter(\.isAlive)
            let target = alive.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .backSac }
                ?? alive.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .crown }
                ?? alive.first { $0.contentID.contains("escort") || $0.contentID.contains("life_vessel") }
                ?? alive.first { $0.currentIntent != "guard" } ?? alive.first
            if let target {
                s.updateRelicTarget(target.id, at: now)
                if route == .blankCard && mission(for: floor) >= 17,
                   let incoming = pending.keys.sorted().first(where: { id in
                       pending[id]! - now <= 0.25 && s.enemies.contains { $0.id == id && ["archive_slam", "tower_heavy_cut", "tower_piercing_claw", "tower_heavy_claw", "tower_cut_first"].contains($0.currentIntent) }
                   }) {
                    _ = s.activateBlankNameCard(isOwned: true, targetID: incoming, at: now)
                }
                if loadout.selectedActiveRelicID == MPCChapterOneCatalog.usurpedLifeMedalRelicID && now >= nextMedalAt && target.currentIntent != "guard" {
                    if s.activateUsurpedLifeMedal(isOwned: true, at: now) { medals += 1; nextMedalAt = s.usurpedLifeMedalReadyAt + max(0, variation()) }
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
                let preparation = s.authoredPreparationDuration(for: enemy.id)
                if s.churchPreparationMustWait(enemyID: enemy.id, pendingEnemyIDs: Set(pending.keys)) { continue }
                if s.consumeEnemyDelay(for: enemy.id) { ready[enemy.id] = now + 3.2 * enemy.attackIntervalMultiplier; continue }
                let contact = MPCChurchTowerCatalog.contactDuration(contentID: enemy.contentID, intent: enemy.currentIntent)
                s.commitEnemyImpact(from: enemy.id)
                pending[enemy.id] = now + (preparation ?? max(0.15, contact + variation()))
            }
            guard let target, s.enemies.contains(where: { $0.id == target.id && $0.isAlive }), now >= playerAt, hit == nil else { continue }
            // A legal once-per-floor ultimate, saved for the final wave.
            // The real skill implementation handles target state and damage.
            if !ultimateRequested && loadout.isUltimateUnlocked && s.waveIndex == floor.waves.count - 1 && now >= 12 && s.canUseFoolSkill(.namelessStage) {
                ultimateRequested = true
                playerAt = now + 1.75 + actionDelay
                hit = (.namelessStage, target.id, now + playerContact(.namelessStage))
                casts[FoolSkillID.namelessStage.rawValue, default: 0] += 1
            } else if let skill = scheduler.next(in: sequence, at: now) {
                scheduler.didCast(skill, at: now); playerAt = now + 1.75 + actionDelay + max(0, variation())
                hit = (skill, target.id, now + max(0.15, playerContact(skill) + variation()))
                casts[skill.rawValue, default: 0] += 1
            } else if now >= basicAt {
                basicAt = now + 2.4; playerAt = now + 1.65 + actionDelay + max(0, variation())
                hit = (nil, target.id, now + max(0.15, 0.58 + variation()))
                casts["basic", default: 0] += 1
            }
        }
        return .init(floor: number, mission: mission(for: floor), route: route, session: s, seconds: elapsed, waveEntryHP: waveHP, rosterDescriptors: rosters, skillCasts: casts, medalUses: medals)
    }
}
