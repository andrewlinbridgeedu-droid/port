import Foundation
@testable import MistportCombatCore

/// Plays a street fight on the real runtime to the requested end, as the lights event tests do.
func playStreet(_ encounterID: String, to outcome: MPCEncounterOutcome) throws -> MPCChapterOneEncounterSession {
    let win = outcome == .victory
    var s = try MPCChapterOneEncounterSession.start(
        encounterID: encounterID,
        party: MPCPartyPersistentState(playerHP: win ? 100_000 : 1, playerMaxHP: win ? 100_000 : 1, sharedReviveCharges: 0),
        companionIDs: [])
    for step in 0..<400 where s.outcome == .inProgress {
        if s.isAwaitingTowerWave {  // church waves enter after a one-second clock gap
            let now = Double(step) * 2 + 10
            _ = s.advanceRelicClock(at: now)
            s.advanceChurchTowerEffects(at: now)
        }
        for enemy in s.enemies.filter(\.isAlive) where s.outcome == .inProgress {
            if win { _ = try s.applyPartyDamage(99_999, to: enemy.id) }
            if s.outcome == .inProgress, s.enemies.contains(where: { $0.id == enemy.id && $0.isAlive }) || !win {
                s.commitEnemyImpact(from: enemy.id)
                try? s.endRound(actingEnemyID: enemy.id, at: Double(step))
            }
        }
    }
    return s
}

/// Every street fight must resolve through the shipped lookups and start on the real runtime.
func expectStreetEncounterShips(_ encounterID: String) throws -> MPCEncounterContent? {
    guard let encounter = MPCChurchMaintenanceCatalog.encounter(id: encounterID),
          encounter.waves.flatMap(\.enemyIDs).allSatisfy({ MPCChurchTowerCatalog.enemyConfiguration(contentID: $0) != nil }),
          Set(encounter.waves.flatMap(\.enemyIDs)).count == encounter.waves.flatMap(\.enemyIDs).count,
          MPCChapterOneBattleIdentity.supportsUnity(encounterID: encounterID) else { return nil }
    _ = try MPCChapterOneEncounterSession.start(encounterID: encounterID, companionIDs: [], loadout: MPCChapterOneLoadout())
    return encounter
}
