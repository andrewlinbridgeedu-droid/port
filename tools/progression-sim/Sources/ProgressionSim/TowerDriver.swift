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
    public static func playerContact(_ skill: FoolSkillID) -> Double { MPCChurchBattleDriver.playerContact(skill) }
    /// Since church-battle-v2 every church battle runs through the rules library's
    /// stepper (the App's rules) via the tower verification runner; this keeps the
    /// simulator's call sites and report type.
    public static func run(number: Int, route: Route = .medal, medalOffset: Double = 22, jitter: Double = 0, seed: UInt64 = 1, passive: String? = nil, suppliedLoadout: MPCChapterOneLoadout? = nil, actionDelay: Double = 0, encounterID: String? = nil) throws -> Report {
        let floor = MPCChurchTowerCatalog.floor(number: number)!
        var loadout = recommendedLoadout(for: floor, route: route)
        if let passive { loadout.relicIDs = [passive] }
        if let suppliedLoadout { loadout = suppliedLoadout }
        let r = try MPCChurchTowerVerificationRunner.run(number: number, route: MPCChurchTowerVerificationRunner.Route(rawValue: route.rawValue)!,
                                                          medalOffset: medalOffset, jitter: jitter, seed: seed,
                                                          suppliedLoadout: loadout, actionDelay: actionDelay, encounterID: encounterID)
        return .init(floor: number, mission: mission(for: floor), route: route, session: r.session, seconds: r.seconds,
                     waveEntryHP: r.waveEntryHP, rosterDescriptors: r.rosterDescriptors, skillCasts: r.skillCasts, medalUses: r.medalUses)
    }
}
