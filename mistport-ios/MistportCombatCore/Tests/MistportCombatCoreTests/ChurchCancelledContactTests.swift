import Testing
@testable import MistportCombatCore

@Suite("Church cancelled contact lifecycle")
struct ChurchCancelledContactTests {
    @Test func confirmedCancelledDeadContactUnblocksNextWaveWithoutDamage() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_014", companionIDs: [])
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0)
        try s.endRound(actingEnemyID: id, at: 0) // actual slam is now committed
        s.commitEnemyImpact(from: id)
        _ = try s.applyPartyDamage(10000, to: id)
        // F14 now has two small escorts beside the major. Clear them as well;
        // the wave must still wait for the major's committed contact.
        for escortID in s.enemies.map(\.id) where escortID != id {
            _ = try s.applyPartyDamage(10000, to: escortID)
        }
        let hp = s.playerHP
        #expect(s.waveIndex == 0 && !s.isAwaitingTowerWave)
        let cancelled = s.cancelCommittedEnemyImpact(enemyID: id, at: 2)
        #expect(cancelled && s.playerHP == hp && s.committedEnemyImpacts.isEmpty)
        #expect(s.isAwaitingTowerWave && s.waveIndex == 0)
        let duplicate = s.cancelCommittedEnemyImpact(enemyID: id, at: 2.5)
        #expect(!duplicate)
        s.advanceChurchTowerEffects(at: 2.99)
        #expect(s.waveIndex == 0)
        s.advanceChurchTowerEffects(at: 3)
        #expect(s.waveIndex == 1 && s.playerHP == hp && s.outcome == .inProgress)
    }
    @Test func lastCancelledContactFinishesButLivingAndMainMissionContactsCannotBeDiscarded() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_001", companionIDs: [])
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0) // shield opens before lethal test hit
        s.commitEnemyImpact(from: id)
        let living = s.cancelCommittedEnemyImpact(enemyID: id, at: 0)
        #expect(!living)
        #expect(s.committedEnemyImpacts.contains(id))
        _ = try s.applyPartyDamage(10000, to: id)
        let cancelled = s.cancelCommittedEnemyImpact(enemyID: id, at: 1)
        #expect(cancelled && s.outcome == .victory)
        var main = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q03_encounter", companionIDs: [])
        let dog = main.enemies[0].id
        main.commitEnemyImpact(from: dog)
        _ = try main.applyPartyDamage(10000, to: dog)
        let mainCancelled = main.cancelCommittedEnemyImpact(enemyID: dog, at: 1)
        #expect(!mainCancelled)
        #expect(main.committedEnemyImpacts.contains(dog) && main.outcome == .inProgress)
    }
    @Test func travellingProjectileStillLandsWhenNoCancellationWasConfirmed() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_014", companionIDs: [])
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0)
        try s.endRound(actingEnemyID: id, at: 0) // actual slam is now committed
        s.commitEnemyImpact(from: id)
        _ = try s.applyPartyDamage(10000, to: id)
        for escortID in s.enemies.map(\.id) where escortID != id {
            _ = try s.applyPartyDamage(10000, to: escortID)
        }
        let durability = s.playerHP + s.playerShield
        s.advanceChurchTowerEffects(at: 50)
        #expect(s.waveIndex == 0 && s.committedEnemyImpacts.contains(id))
        try s.endRound(actingEnemyID: id, at: 50)
        #expect(s.playerHP + s.playerShield < durability && s.isAwaitingTowerWave)
    }
    @Test func liveHealerCancelsMissingFrozenRecipientOnceWithoutRetargeting() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_023", companionIDs: [])
        let healer = s.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .backSac }!.id
        let target = s.enemies.first { $0.id != healer }!.id
        _ = try s.applyPartyDamage(100, to: target)
        try s.endRound(actingEnemyID: healer, at: 0)
        s.commitEnemyImpact(from: healer)
        let premature = s.cancelTargetedSupport(enemyID: healer, at: 1)
        #expect(!premature && s.committedEnemyImpacts.contains(healer))
        _ = try s.applyPartyDamage(10000, to: target)
        let health = s.enemies.map(\.hp), playerHP = s.playerHP
        let cancelled = s.cancelTargetedSupport(enemyID: healer, at: 2)
        #expect(cancelled && !s.committedEnemyImpacts.contains(healer))
        #expect(s.enemies.first { $0.id == healer }?.currentIntent == "tower_short_pounce")
        #expect(s.enemies.map(\.hp) == health && s.playerHP == playerHP)
        let again = s.cancelTargetedSupport(enemyID: healer, at: 3)
        #expect(!again)
    }
    @Test func liveCrownCancelsMissingRecipientWithoutGrantingBuff() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_041", companionIDs: [])
        let crown = s.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .crown }!.id
        let target = s.enemies.first { $0.id != crown }!.id
        try s.endRound(actingEnemyID: target, at: 0) // open the recipient's true shield
        try s.endRound(actingEnemyID: crown, at: 0)
        s.commitEnemyImpact(from: crown)
        _ = try s.applyPartyDamage(10000, to: target)
        let hp = s.playerHP
        let cancelled = s.cancelTargetedSupport(enemyID: crown, at: 1)
        #expect(cancelled && s.towerEmpoweredEnemyIDs.isEmpty && s.playerHP == hp)
        #expect(s.enemies.first { $0.id == crown }?.currentIntent == "tower_sound_arrow")
    }

}
