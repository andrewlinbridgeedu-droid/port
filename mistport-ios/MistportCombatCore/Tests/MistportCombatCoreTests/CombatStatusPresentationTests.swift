import Testing
@testable import MistportCombatCore

@Suite("Combat status ownership and lifetime")
struct CombatStatusPresentationTests {
    @Test func enemyStacksStayOnTheirOwner() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q08_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.sidestepStrike, .identityDisplacement], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        let id = s.enemies[0].id
        _ = try s.useFoolSkill(.identityDisplacement, targetID: id)
        #expect(s.enemyCombatStatuses(enemyID: id, at: 0).first { $0.id == "illusion" }?.count == s.foolStates[id]?.illusionStacks)
        #expect(s.enemyCombatStatuses(enemyID: "missing", at: 0).isEmpty)
        #expect(!s.playerCombatStatuses(at: 0).contains { $0.id == "illusion" })
    }
    @Test func expiredMaskIsHiddenEvenBeforeNextSimulationTick() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q04_encounter", companionIDs: [])
        _ = try s.useOwnedManualMasquerade(targetID: s.enemies[0].id, isOwned: true, at: 6)
        #expect(s.playerCombatStatuses(at: 6).first { $0.id == "mask" }?.count == 2)
        #expect(!s.playerCombatStatuses(at: 10).contains { $0.id == "mask" })
    }
    @Test func towerPacksHaveSequentialUniqueWaves() {
        for floor in MPCChurchTowerCatalog.floors where floor.number > 1 {
            #expect((3...5).contains(floor.waves.count))
            #expect(floor.waves.allSatisfy { !$0.isEmpty && $0.count <= MPCChurchTowerCatalog.maxWaveSize })
            let ids = floor.waves.indices.flatMap { wave in floor.waves[wave].indices.map { floor.enemyID(wave: wave, slot: $0) } }
            #expect(Set(ids).count == ids.count)
            #expect(floor.encounter.waves.count == floor.waves.count)
        }
    }
    @Test func reorderResetsLastFractionAndUnusedCardsButNotUnchangedCards() {
        var scheduler = ContinuousSkillScheduler()
        scheduler.didCast(.sidestepStrike, at: 0)
        scheduler.didCast(.fabricatedEvidence, at: 0)
        let old: [FoolSkillID] = [.sidestepStrike, .identityDisplacement, .fabricatedEvidence]
        let new: [FoolSkillID] = [.identityDisplacement, .sidestepStrike, .fabricatedEvidence]
        scheduler.didReorder(from: old, to: new, at: 6.95)
        #expect(scheduler.readyAt[.sidestepStrike] == 13.95)
        #expect(scheduler.readyAt[.identityDisplacement] == 13.95)
        #expect(scheduler.readyAt[.fabricatedEvidence] == 7)
        #expect(scheduler.next(in: new, at: 7) == nil)
        let deadlines = scheduler.readyAt
        scheduler.didReorder(from: new, to: new, at: 8)
        #expect(scheduler.readyAt == deadlines)
    }

    @Test func clearingPackWaitsThenContinuesWithoutWinningOrRefreshingMask() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: MPCChurchTowerCatalog.floor(number: 2)!.id, companionIDs: [])
        _ = try s.useOwnedManualMasquerade(targetID: s.enemies[0].id, isOwned: true, at: 1)
        let hp = s.playerHP
        for id in s.enemies.map(\.id) { _ = try s.applyPartyDamage(100_000, to: id) }
        #expect(s.outcome == .inProgress)
        #expect(s.isAwaitingTowerWave)
        s.advanceChurchTowerEffects(at: 1.99)
        #expect(s.waveIndex == 0)
        s.advanceChurchTowerEffects(at: 2)
        #expect(s.waveIndex == 1)
        #expect(s.playerHP == hp)
        #expect(s.masqueradeCharges == 2)
        #expect(s.ownedManualMaskExpiresAt == 5)
        #expect(s.outcome == .inProgress)
    }

}
