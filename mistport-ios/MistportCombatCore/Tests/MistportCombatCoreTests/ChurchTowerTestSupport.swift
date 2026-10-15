import Foundation
import Testing
@testable import MistportCombatCore

/// No cards, ultimate, passives or relics: tower contract tests measure the enemies alone.
let bareTowerLoadout = MPCChapterOneLoadout(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])

func towerSpecies(_ enemy: MPCRuntimeEnemy) -> MPCChurchTowerCatalog.Species? {
    MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID)?.species
}

/// Reach the authored threat through the preceding minion waves (majors close later waves
/// since 2026-10-12's `sequentialMinionWaves`). Keep the same session and advance its clock
/// through each real one-second fade. Pick enemies by species, never by index.
func startChurchTower(_ n: Int, containing species: [MPCChurchTowerCatalog.Species], minimumEnemies: Int = 1,
                      loadout: MPCChapterOneLoadout = bareTowerLoadout, party: MPCPartyPersistentState = .init()) throws -> (session: MPCChapterOneEncounterSession, now: TimeInterval) {
    let floor = try #require(MPCChurchTowerCatalog.floor(number: n))
    let targetWave = try #require(floor.waves.firstIndex { wave in
        wave.count >= minimumEnemies && species.allSatisfy { requested in
            wave.contains { $0.species == requested }
        }
    }, "Floor \(n) must retain the required threat composition")
    var session = try MPCChapterOneEncounterSession.start(encounterID: floor.id, party: party, companionIDs: [], loadout: loadout)
    var now: TimeInterval = 0
    for wave in 0..<targetWave {
        try #require(session.waveIndex == wave && session.outcome == .inProgress)
        for enemy in session.enemies.filter(\.isAlive) {
            // A guarding shield-jaw ignores damage until its own next beat drops the guard.
            for _ in 0..<4 where session.enemies.contains(where: { $0.id == enemy.id && $0.isAlive }) {
                _ = try session.applyPartyDamage(10000, to: enemy.id)
                if session.enemies.contains(where: { $0.id == enemy.id && $0.isAlive }) {
                    try session.endRound(actingEnemyID: enemy.id, at: now)
                }
            }
        }
        try #require(session.isAwaitingTowerWave)
        now += 1
        _ = session.advanceEmeraldPoison(at: now)
        try #require(session.waveIndex == wave + 1 && session.outcome == .inProgress)
    }
    return (session, now)
}
