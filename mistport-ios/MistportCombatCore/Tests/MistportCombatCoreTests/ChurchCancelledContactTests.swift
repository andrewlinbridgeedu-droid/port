import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Church cancelled contact lifecycle")
struct ChurchCancelledContactTests {
    /// F14's shield-jaw closes a later wave (2026-10-12 wave split); its minion waves come first.
    func floor14ShieldJaw() throws -> (session: MPCChapterOneEncounterSession, now: TimeInterval, id: String, wave: Int) {
        let (s, now) = try startChurchTower(14, containing: [.shieldJaw], loadout: MPCChapterOneLoadout())
        let id = try #require(s.enemies.first { towerSpecies($0) == .shieldJaw }).id
        return (s, now, id, s.waveIndex)
    }
    @Test func confirmedCancelledDeadContactUnblocksNextWaveWithoutDamage() throws {
        var (s, now, id, wave) = try floor14ShieldJaw()
        try s.endRound(actingEnemyID: id, at: now)
        try s.endRound(actingEnemyID: id, at: now) // actual slam is now committed
        s.commitEnemyImpact(from: id)
        _ = try s.applyPartyDamage(10000, to: id)
        // F14 now has two small escorts beside the major. Clear them as well;
        // the wave must still wait for the major's committed contact.
        for escortID in s.enemies.map(\.id) where escortID != id {
            _ = try s.applyPartyDamage(10000, to: escortID)
        }
        let hp = s.playerHP
        #expect(s.waveIndex == wave && !s.isAwaitingTowerWave)
        let cancelled = s.cancelCommittedEnemyImpact(enemyID: id, at: now + 2)
        #expect(cancelled && s.playerHP == hp && s.committedEnemyImpacts.isEmpty)
        #expect(s.isAwaitingTowerWave && s.waveIndex == wave)
        let duplicate = s.cancelCommittedEnemyImpact(enemyID: id, at: now + 2.5)
        #expect(!duplicate)
        s.advanceChurchTowerEffects(at: now + 2.99)
        #expect(s.waveIndex == wave)
        s.advanceChurchTowerEffects(at: now + 3)
        #expect(s.waveIndex == wave + 1 && s.playerHP == hp && s.outcome == .inProgress)
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
        var (s, now, id, wave) = try floor14ShieldJaw()
        try s.endRound(actingEnemyID: id, at: now)
        try s.endRound(actingEnemyID: id, at: now) // actual slam is now committed
        s.commitEnemyImpact(from: id)
        _ = try s.applyPartyDamage(10000, to: id)
        for escortID in s.enemies.map(\.id) where escortID != id {
            _ = try s.applyPartyDamage(10000, to: escortID)
        }
        let durability = s.playerHP + s.playerShield
        s.advanceChurchTowerEffects(at: now + 50)
        #expect(s.waveIndex == wave && s.committedEnemyImpacts.contains(id))
        try s.endRound(actingEnemyID: id, at: now + 50)
        #expect(s.playerHP + s.playerShield < durability && s.isAwaitingTowerWave)
    }
    @Test func liveHealerCancelsMissingFrozenRecipientOnceWithoutRetargeting() throws {
        // F23's back sac and its recipients close the floor after the minion waves.
        var (s, now) = try startChurchTower(23, containing: [.backSac], minimumEnemies: 2, loadout: MPCChapterOneLoadout())
        let healer = try #require(s.enemies.first { towerSpecies($0) == .backSac }).id
        let target = try #require(s.enemies.first { $0.id != healer }).id
        _ = try s.applyPartyDamage(100, to: target)
        try s.endRound(actingEnemyID: healer, at: now)
        s.commitEnemyImpact(from: healer)
        let premature = s.cancelTargetedSupport(enemyID: healer, at: now + 1)
        #expect(!premature && s.committedEnemyImpacts.contains(healer))
        _ = try s.applyPartyDamage(10000, to: target)
        let health = s.enemies.map(\.hp), playerHP = s.playerHP
        let cancelled = s.cancelTargetedSupport(enemyID: healer, at: now + 2)
        #expect(cancelled && !s.committedEnemyImpacts.contains(healer))
        #expect(s.enemies.first { $0.id == healer }?.currentIntent == "tower_short_pounce")
        #expect(s.enemies.map(\.hp) == health && s.playerHP == playerHP)
        let again = s.cancelTargetedSupport(enemyID: healer, at: now + 3)
        #expect(!again)
    }
    @Test func liveCrownCancelsMissingRecipientWithoutGrantingBuff() throws {
        // F41's crown and shield-jaw close the floor; the crown picks the first living recipient.
        var (s, now) = try startChurchTower(41, containing: [.crown, .shieldJaw], loadout: MPCChapterOneLoadout())
        let crown = try #require(s.enemies.first { towerSpecies($0) == .crown }).id
        let target = try #require(s.enemies.first { towerSpecies($0) == .shieldJaw }).id
        for escort in s.enemies.filter({ $0.id != crown && $0.id != target }) {
            _ = try s.applyPartyDamage(10000, to: escort.id)
        }
        #expect(s.towerEmpowerTargetID(for: crown) == target)
        try s.endRound(actingEnemyID: target, at: now) // open the recipient's true shield
        try s.endRound(actingEnemyID: crown, at: now)
        s.commitEnemyImpact(from: crown)
        _ = try s.applyPartyDamage(10000, to: target)
        let hp = s.playerHP
        let cancelled = s.cancelTargetedSupport(enemyID: crown, at: now + 1)
        #expect(cancelled && s.towerEmpoweredEnemyIDs.isEmpty && s.playerHP == hp)
        #expect(s.enemies.first { $0.id == crown }?.currentIntent == "tower_sound_arrow")
    }

}
