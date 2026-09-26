import Testing
@testable import MistportCombatCore

@Suite("Church timing tolerance")
struct ChurchTimingToleranceTests {
    @Test func finaleAndHardBountiesTolerateInputAndContactVariation() throws {
        for (id, mission) in [("church_tower_100", 30), ("church_bounty_b05", 27), ("church_bounty_b06", 26)] {
            for jitter in [0.35, 0.7] {
                var wins = 0, minimum = 1000
                for seed in UInt64(1)...16 {
                    let s = try TowerHundredSimulator.run(encounterID: id, mission: mission, offset: 6, passive: "relic_return_gift_clasp", jitter: jitter, seed: seed)
                    if s.outcome == .victory { wins += 1; minimum = min(minimum, s.playerHP) }
                }
                print("CHURCH_JITTER id=\(id) jitter=\(jitter) wins=\(wins)/16 minHP=\(minimum)")
                #expect(wins >= 12, "\(id) ±\(jitter)s tolerates fewer than 75% of seeded timing samples")
            }
        }
    }
}
