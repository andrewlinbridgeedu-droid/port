import Testing
@testable import MistportCombatCore

@Suite("Encore Bell prototype combat contract")
struct EncoreBellPrototypeTests {
    private func makeSession() throws -> MPCChapterOneEncounterSession {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q05_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.sidestepStrike], relicIDs: ["relic_paper_raincoat"]))
        s.prepareEncoreBellPrototype()
        return s
    }

    @Test func playerStillActsDuringDeferralAndAttackIsUnchanged() throws {
        var s = try makeSession()
        #expect(!s.q5PaperRelicReady)
        #expect(!s.loadout.relicIDs.contains("relic_paper_raincoat"))
        let id = s.enemies[0].id
        var bell = MPCEncoreBellState()
        bell.beginCharge(enemyID: id, startedAt: 0, windupDeadline: 3)
        let rang = bell.ring(at: 2)
        #expect(rang)
        let enemyHP = s.enemies[0].hp
        _ = try s.useBasicAction(.damage, targetID: id)
        _ = try s.useFoolSkill(.sidestepStrike, targetID: id, usesRealtimeCooldown: true)
        #expect(s.enemies[0].hp < enemyHP)
        #expect(s.enemies[0].currentIntent == "charge")
        let early = bell.consumeReleaseIfDue(at: 5.99)
        #expect(!early)
        let released = bell.consumeReleaseIfDue(at: 6)
        #expect(released)
        try s.endRound(actingEnemyID: id)
        #expect(s.lastEnemyActionResolutions[0].playerDamage == 0)
        #expect(s.enemies[0].currentIntent == "memory_breath")
        s.commitEnemyImpact(from: id)
        try s.endRound(actingEnemyID: id)
        let returnedDamage = s.advanceEmeraldPoison(at: 9)
        var baseline = try makeSession()
        try baseline.endRound(actingEnemyID: id)
        baseline.commitEnemyImpact(from: id)
        try baseline.endRound(actingEnemyID: id)
        let baselineDamage = baseline.advanceEmeraldPoison(at: 9)
        #expect(returnedDamage == baselineDamage)
        #expect(returnedDamage > 0)
        let twice = bell.consumeReleaseIfDue(at: 7)
        #expect(!twice)
    }

    @Test func killingUnlaunchedDebtWinsButLaunchedProjectileStillLands() throws {
        var deferred = try makeSession()
        let id = deferred.enemies[0].id
        var bell = MPCEncoreBellState()
        bell.beginCharge(enemyID: id, startedAt: 0, windupDeadline: 3)
        bell.ring(at: 2)
        _ = try deferred.applyPartyDamage(100_000, to: id)
        #expect(deferred.outcome == .victory)
        bell.enemyDied(id)
        #expect(bell.phase == .spent)
        #expect(!bell.isReleaseDue(at: 10))

        var launched = try makeSession()
        // The second spell is the direct burst; its committed contact still lands.
        try launched.endRound(actingEnemyID: id)
        try launched.endRound(actingEnemyID: id)
        try launched.endRound(actingEnemyID: id)
        launched.commitEnemyImpact(from: id)
        _ = try launched.applyPartyDamage(100_000, to: id)
        #expect(launched.outcome == .inProgress)
        let hp = launched.playerHP
        try launched.endRound(actingEnemyID: id)
        #expect(launched.playerHP < hp)
        #expect(launched.outcome == .victory)
    }
}
