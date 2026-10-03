import Testing
@testable import MistportCombatCore

/// Tower minion packs and group cards (2026-10-03): more, smaller small monsters walk
/// in from the back, so 错步穿行 (up to three targets) and 荒谬归结 (two bystanders at
/// half damage) have several bodies to hit.
@Suite("Church tower minion packs and group cards")
struct ChurchMinionPackTests {
    typealias Catalog = MPCChurchTowerCatalog

    @Test func everyWaveCarriesItsPackWithinTheWaveLimit() {
        for floor in Catalog.floors {
            for wave in floor.waves {
                #expect(wave.count <= Catalog.maxWaveSize, "Floor \(floor.number) wave has \(wave.count) enemies")
                let minions = wave.filter { Catalog.minionSpecies.contains($0.species) }
                #expect(minions.count >= Catalog.minionPackSize(floor: floor.number), "Floor \(floor.number) pack \(minions.count)")
                for (k, minion) in minions.enumerated() {
                    // A minion never acts before it has walked to its slot.
                    #expect(minion.initialDelay >= Catalog.minionArrival(k), "Floor \(floor.number) minion \(k) acts at \(minion.initialDelay)")
                }
            }
        }
        #expect(Catalog.floor(number: 1)?.enemies.count == 1)
        #expect(Catalog.floor(number: 100)?.waves.allSatisfy { $0.filter { Catalog.minionSpecies.contains($0.species) }.count >= 6 } == true)
    }

    private func packSession(_ skills: [FoolSkillID]) throws -> MPCChapterOneEncounterSession {
        try MPCChapterOneEncounterSession.start(
            encounterID: try #require(Catalog.floor(number: 2)).id, companionIDs: [],
            loadout: .init(normalSkillIDs: skills, isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
    }

    @Test func sidestepCutsThroughThreeTargets() throws {
        var session = try packSession([.sidestepStrike])
        let alive = session.enemies.filter(\.isAlive)
        #expect(alive.count == 5)
        // Aim at a minion: the shield jaw may open behind its guard.
        let result = try session.useFoolSkill(.sidestepStrike, targetID: try #require(alive.last).id)
        #expect(result.targets.count == 3)
        #expect(Set(result.targets.map(\.targetID)).count == result.targets.count)
        // The shield jaw may still be behind its guard; every minion takes the cut.
        #expect(result.targets.filter { !Catalog.isShieldJaw($0.targetID) }.allSatisfy { $0.damage > 0 })
    }

    @Test func storyKeepsItsAuthoredReach() {
        #expect(MPCFoolGroupCards.extraTargets(encounterID: "chapter01_q02_encounter", skill: .sidestepStrike) == 1)
        #expect(MPCFoolGroupCards.extraTargets(encounterID: "chapter01_q22_encounter", skill: .absurdFinale) == 0)
        #expect(MPCFoolGroupCards.extraTargets(encounterID: "church_tower_012", skill: .absurdFinale) == 2)
    }

    @Test func finaleSplashesTwoBystandersAtHalfWithoutSpendingTheirSetup() throws {
        var session = try packSession([.absurdFinale])
        let alive = session.enemies.filter(\.isAlive)
        let main = try #require(alive.last)
        let before = session.foolStates
        let result = try session.useFoolSkill(.absurdFinale, targetID: main.id)
        #expect(result.targets.count == 3)
        #expect(result.targets[0].targetID == main.id)
        for hit in result.targets.dropFirst() {
            #expect(hit.targetID != main.id)
            #expect(Catalog.isShieldJaw(hit.targetID) || hit.damage > 0)
            // Bystanders' Fool state is read, never written: no finale is cashed on them.
            #expect(session.foolStates[hit.targetID] == before[hit.targetID])
        }
    }
}
