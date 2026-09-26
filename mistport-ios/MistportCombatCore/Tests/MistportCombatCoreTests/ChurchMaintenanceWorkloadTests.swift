import Testing
@testable import MistportCombatCore

@Suite("Maintenance full-contract earned build workload")
struct ChurchMaintenanceWorkloadTests {
    @Test func everyThreeSiteContractHasLegalVictoryAndMeasuredWork() throws {
        let contracts: [(String, Int)] = [("church_maintenance_j1", 9)] + (1...10).map { band in
            let end = band * 10
            return ("church_maintenance_j2_f\(end)", max(4, MPCChurchTowerCatalog.floor(number: end)!.requiredMission))
        }
        for (prefix, mission) in contracts {
            var seconds = 0.0
            for site in 1...3 {
                var won = false
                for (offset, passive) in [(6.0, Optional<String>.none), (14.0, nil), (6.0, "relic_return_gift_clasp"), (14.0, "relic_return_gift_clasp")] {
                    var time = 0.0
                    let s = try TowerHundredSimulator.run(encounterID: "\(prefix)_s\(site)_workload", mission: mission, offset: offset, passive: passive, onFinished: { time = $0 })
                    if s.outcome == .victory {
                        won = true; seconds += time
                        print("MAINT_SITE id=\(prefix) site=\(site) seconds=\(time) hp=\(s.playerHP) passive=\(passive ?? "none")")
                        break
                    }
                }
                #expect(won, "\(prefix) site \(site) has no legal route")
            }
            print("MAINT_CONTRACT id=\(prefix) combatSeconds=\(seconds)")
        }
    }
    @Test func earliestContractsTolerateInputAndContactVariation() throws {
        for (prefix, mission) in [("church_maintenance_j1", 9), ("church_maintenance_j2_f10", 4)] {
            for site in 1...3 {
                var wins = 0
                var lowest = 1000
                for seed in 1...16 {
                    let s = try TowerHundredSimulator.run(encounterID: "\(prefix)_s\(site)_jitter", mission: mission, offset: 6, passive: "relic_return_gift_clasp", jitter: 0.7, seed: UInt64(seed))
                    if s.outcome == .victory { wins += 1; lowest = min(lowest, s.playerHP) }
                }
                print("MAINT_JITTER id=\(prefix) site=\(site) wins=\(wins)/16 minHP=\(lowest)")
                #expect(wins >= 14, "Routine work should tolerate imperfect contact/input timing")
            }
        }
    }

}
