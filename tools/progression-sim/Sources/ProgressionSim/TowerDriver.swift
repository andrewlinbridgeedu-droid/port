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
    /// The pace stage and its loadout, as the rules library's tower runner plays them (2026-10-15).
    public static func mission(for floor: MPCChurchTowerCatalog.Floor) -> Int { MPCChurchTowerVerificationRunner.mission(for: floor) }
    public static func recommendedLoadout(for floor: MPCChurchTowerCatalog.Floor, route: Route = .medal) -> MPCChapterOneLoadout {
        MPCChurchTowerVerificationRunner.recommendedLoadout(for: floor, route: MPCChurchTowerVerificationRunner.Route(rawValue: route.rawValue)!)
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
