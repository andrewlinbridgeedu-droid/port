import Testing
@testable import MistportCombatCore

@Suite("Victory waits for committed contacts")
struct CommittedImpactTests {
    @Test func defeatedCasterStillHitsBeforeVictory() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q06_encounter", companionIDs: [])
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id) // Finish the guard stance before committing the slam.
        s.commitEnemyImpact(from: id)
        let hp = s.playerHP
        _ = try s.applyPartyDamage(100_000, to: id)
        #expect(s.outcome == .inProgress)
        #expect(!s.enemies[0].isAlive)
        try s.endRound(actingEnemyID: id)
        #expect(s.playerHP < hp)
        #expect(s.committedEnemyImpacts.isEmpty)
        #expect(s.outcome == .victory)
        #expect(throws: MPCEncounterRuntimeError.self) { try s.endRound(actingEnemyID: id) }
    }
    @Test func lastContactCanCauseDefeat() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q04_encounter", companionIDs: [])
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id) // Probe.
        try s.endRound(actingEnemyID: id) // Telegraph; first heavy remains in flight.
        s.commitEnemyImpact(from: id)
        _ = try s.applyPartyDamage(100_000, to: id)
        #expect(s.outcome == .inProgress)
        try s.endRound(actingEnemyID: id)
        #expect(s.outcome == .defeat)
    }
    @Test func noCommittedThreatFinishesImmediately() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q06_encounter", companionIDs: [])
        try s.endRound(actingEnemyID: s.enemies[0].id) // Shield lowered; slam has not been committed.
        #expect(s.enemies[0].currentIntent == "archive_slam")
        _ = try s.applyPartyDamage(100_000, to: s.enemies[0].id)
        #expect(s.outcome == .victory)
    }
}
