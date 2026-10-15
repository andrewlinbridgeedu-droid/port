import Testing
@testable import MistportCombatCore

/// Tower minion packs and group cards (2026-10-03): more, smaller small monsters walk
/// in from the back, so 错步穿行 (up to three targets) has several bodies to hit.
/// 荒谬归结's tower splash belonged to the manual card mode, removed 2026-10-15.
@Suite("Church tower minion packs and group cards")
struct ChurchMinionPackTests {
    typealias Catalog = MPCChurchTowerCatalog

    @Test func everyWaveCarriesItsPackWithinTheWaveLimit() {
        for floor in Catalog.floors {
            for wave in floor.waves {
                #expect(wave.count <= Catalog.maxWaveSize, "Floor \(floor.number) wave has \(wave.count) enemies")
                let minions = wave.filter { Catalog.minionSpecies.contains($0.species) }
                for (k, minion) in minions.enumerated() {
                    // A minion never acts before it has walked to its slot.
                    #expect(minion.initialDelay >= Catalog.minionArrival(k), "Floor \(floor.number) minion \(k) acts at \(minion.initialDelay)")
                }
            }
            // The pack is spread over the floor's waves since 2026-10-12; the floor keeps it whole.
            let pack = floor.waves.joined().filter { Catalog.minionSpecies.contains($0.species) }.count
            #expect(pack >= Catalog.minionPackSize(floor: floor.number), "Floor \(floor.number) pack \(pack)")
        }
        #expect(Catalog.floor(number: 1)?.enemies.count == 1)
        let top = Catalog.floor(number: 100)
        #expect((top?.waves.joined().filter { Catalog.minionSpecies.contains($0.species) }.count ?? 0) >= 6)
        #expect(top?.waves.allSatisfy { $0.contains { Catalog.minionSpecies.contains($0.species) } } == true)
    }

    @Test func sidestepCutsThroughThreeTargets() throws {
        // F20's closing wave holds two minions and two majors (2026-10-12 wave split).
        var (session, _) = try startChurchTower(20, containing: [], minimumEnemies: 4,
            loadout: .init(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        let alive = session.enemies.filter(\.isAlive)
        #expect(alive.count >= 4)
        // Aim at a minion: the shield jaw may open behind its guard.
        let minion = try #require(alive.first { Catalog.minionSpecies.contains(towerSpecies($0) ?? .shieldJaw) })
        let result = try session.useFoolSkill(.sidestepStrike, targetID: minion.id)
        #expect(result.targets.count == 3 && result.targets.first?.targetID == minion.id)
        #expect(Set(result.targets.map(\.targetID)).count == result.targets.count)
        // The shield jaw may still be behind its guard; every other body takes the cut.
        #expect(result.targets.filter { !Catalog.isShieldJaw($0.targetID) }.allSatisfy { $0.damage > 0 })
    }
}
