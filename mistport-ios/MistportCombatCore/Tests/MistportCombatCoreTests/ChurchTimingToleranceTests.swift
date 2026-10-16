import Testing
@testable import MistportCombatCore

/// The finale floor and the hard bounties under timing noise, on the real loop (2026-10-15): the stage
/// they open at, the tower gear held then on the daily pace, the tower hand, the clasp and the medal.
@Suite("Church timing tolerance")
struct ChurchTimingToleranceTests {
    @Test func finaleAndHardBountiesTolerateInputAndContactVariation() async throws {
        struct Run: Sendable { let id: String; let stage: Int; let gear: Int; let jitter: Double; let seed: UInt64 }
        let cases = [("church_tower_100", MPCChurchTowerCatalog.paceMission(floor: 100), 99), ("church_bounty_b05", 27, RealLoop.paceFloor(after: 27)),
                     ("church_bounty_b06", 26, RealLoop.paceFloor(after: 26))]
        let runs = cases.flatMap { c in [0.35, 0.7].flatMap { j in (UInt64(1)...16).map { Run(id: c.0, stage: c.1, gear: c.2, jitter: j, seed: $0) } } }
        let won = try await RealLoop.map(runs) { r in
            try RealLoop.church(r.id, before: r.stage + 1, order: RealLoop.towerHand(before: r.stage + 1), gearThrough: r.gear,
                                passive: RealLoop.clasp, jitter: r.jitter, seed: r.seed).session.outcome == .victory
        }
        for c in cases {
            for jitter in [0.35, 0.7] {
                let wins = zip(runs, won).filter { $0.0.id == c.0 && $0.0.jitter == jitter && $0.1 }.count
                print("CHURCH_JITTER id=\(c.0) jitter=\(jitter) wins=\(wins)/16")
                #expect(wins >= 12, "\(c.0) ±\(jitter)s tolerates fewer than 75% of seeded timing samples")
            }
        }
    }
}
