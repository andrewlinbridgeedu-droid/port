import Testing
@testable import MistportCombatCore

/// Maintenance on the real loop (2026-10-15): a contract for floor f opens once f is cleared, so it is
/// played at f's pace stage with the gear through f; the patrol (J1) at the church's Q7 with no tower gear.
@Suite("Maintenance full-contract earned build workload")
struct ChurchMaintenanceWorkloadTests {
    static let contracts: [(String, Int, Int)] = [("church_maintenance_j1", MPCChurchTowerCatalog.unlockMission, 0)]
        + (1...10).map { band in ("church_maintenance_j2_f\(band * 10)", MPCChurchTowerCatalog.paceMission(floor: band * 10), band * 10) }

    @Test func everyThreeSiteContractHasLegalVictoryAndMeasuredWork() async throws {
        struct Site: Sendable { let prefix: String; let stage: Int; let gear: Int; let site: Int }
        let sites = Self.contracts.flatMap { c in (1...3).map { Site(prefix: c.0, stage: c.1, gear: c.2, site: $0) } }
        let results = try await RealLoop.map(sites) { s -> Double? in
            for (medal, passive) in [(6.0, Optional<String>.none), (14.0, nil), (6.0, RealLoop.clasp), (14.0, RealLoop.clasp)] {
                let r = try RealLoop.church("\(s.prefix)_s\(s.site)_workload", before: s.stage + 1, order: RealLoop.towerHand(before: s.stage + 1),
                                            gearThrough: s.gear, passive: passive, medalAt: medal)
                if r.session.outcome == .victory { return r.seconds }
            }
            return nil
        }
        for (s, seconds) in zip(sites, results) {
            print("MAINT_SITE id=\(s.prefix) site=\(s.site) seconds=\(seconds ?? -1)")
            #expect(seconds != nil, "\(s.prefix) site \(s.site) has no legal route")
        }
    }

    @Test func earliestContractsTolerateInputAndContactVariation() async throws {
        struct Run: Sendable { let prefix: String; let stage: Int; let gear: Int; let site: Int; let seed: UInt64 }
        let runs = Self.contracts.prefix(2).flatMap { c in (1...3).flatMap { site in (1...16).map { Run(prefix: c.0, stage: c.1, gear: c.2, site: site, seed: UInt64($0)) } } }
        let won = try await RealLoop.map(runs) { r in
            try RealLoop.church("\(r.prefix)_s\(r.site)_jitter", before: r.stage + 1, order: RealLoop.towerHand(before: r.stage + 1),
                                gearThrough: r.gear, passive: RealLoop.clasp, jitter: 0.7, seed: r.seed).session.outcome == .victory
        }
        for c in Self.contracts.prefix(2) {
            for site in 1...3 {
                let wins = zip(runs, won).filter { $0.0.prefix == c.0 && $0.0.site == site && $0.1 }.count
                print("MAINT_JITTER id=\(c.0) site=\(site) wins=\(wins)/16")
                #expect(wins >= 14, "Routine work should tolerate imperfect contact/input timing")
            }
        }
    }
}
