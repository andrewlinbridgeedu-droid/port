import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Church hundred floor contracts")
struct ChurchTowerHundredTests {
    @Test func authoredWavesGatesSpeciesAndTotals() throws {
        let floors = MPCChurchTowerCatalog.floors
        #expect(floors.map(\.number) == Array(1...100))
        #expect(floors.reduce(0) { $0 + $1.firstClearReward.coins } == 1700)
        #expect(floors.reduce(0) { $0 + $1.firstClearReward.merit } == 320)
        #expect(Set(floors.map(\.id)).count == 100)
        var ids = Set<String>()
        for f in floors {
            #expect(f.number == 1 ? f.waves.count == 1 : (3...5).contains(f.waves.count))
            #expect(f.waves.flatMap { $0 }.filter { $0.species == .backSac }.count <= 1)
            for w in f.waves.indices {
                #expect((1...MPCChurchTowerCatalog.maxWaveSize).contains(f.waves[w].count))
                #expect(f.waves[w].filter { $0.species == .saltSac }.count <= 1)
                #expect(f.number >= 51 || !f.waves[w].contains { $0.species == .boneclaw })
                for slot in f.waves[w].indices {
                    let id = f.enemyID(wave: w, slot: slot)
                    #expect(ids.insert(id).inserted)
                    #expect(MPCChurchTowerCatalog.enemyDefinition(id: id) != nil)
                }
            }
            let p = MPCChurchTowerProgress(clearedFloors: Set(1..<f.number))
            #expect(p.canEnter(f.number, completedMissionNumbers: Set(1...30)))
            if f.requiredMission > 0 { #expect(!p.canEnter(f.number, completedMissionNumbers: Set(1..<f.requiredMission))) }
        }
    }
    @Test func hundredRewardsCannotBeReclaimedAfterEncoding() throws {
        var progress = MPCChurchTowerProgress()
        var coins = 0, merit = 0
        for n in 1...100 {
            let reward = progress.claimVictory(floor: n, completedMissionNumbers: Set(1...30))
            coins += reward?.coins ?? 0; merit += reward?.merit ?? 0
        }
        var restored = try JSONDecoder().decode(MPCChurchTowerProgress.self, from: JSONEncoder().encode(progress))
        for n in 1...100 { #expect(restored.claimVictory(floor: n, completedMissionNumbers: Set(1...30)) == nil) }
        #expect(coins == 1700 && merit == 320 && restored.nextFloor == nil)
    }
    func start(_ n: Int) throws -> MPCChapterOneEncounterSession {
        let floor = try #require(MPCChurchTowerCatalog.floor(number: n))
        return try .start(encounterID: floor.id, companionIDs: [], loadout: bareTowerLoadout)
    }
    @Test func allChurchPreparationFamiliesShareAnExclusiveGate() throws {
        let families: [(Int, MPCChurchTowerCatalog.Species)] = [
            (1, .shieldJaw), (6, .saltSac), (11, .saltSac), (21, .backSac),
            (31, .scissor), (41, .crown), (51, .boneclaw)
        ]
        for (n, species) in families {
            var (s, now) = try startChurchTower(n, containing: [species])
            let id = try #require(s.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == species }).id
            if species == .shieldJaw {
                #expect(!s.isChurchHighThreatPreparation(enemyID: id)) // guard precedes charge
                try s.endRound(actingEnemyID: id, at: now)
            }
            #expect(s.isChurchHighThreatPreparation(enemyID: id))
            #expect(!s.churchPreparationMustWait(enemyID: id, pendingEnemyIDs: [id]))
            try s.endRound(actingEnemyID: id, at: now)
            #expect(!s.isChurchHighThreatPreparation(enemyID: id))
        }
        // F12 introduces Copperback; F13 retains the shield/poison pair after its minions.
        var (s, now) = try startChurchTower(13, containing: [.shieldJaw, .saltSac])
        let hound = try #require(s.enemies.first { MPCChurchTowerCatalog.isShieldJaw($0.contentID) }).id
        let poison = try #require(s.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .saltSac }).id
        try s.endRound(actingEnemyID: hound, at: now)
        #expect(s.churchPreparationMustWait(enemyID: hound, pendingEnemyIDs: [poison]))
        try s.endRound(actingEnemyID: poison, at: now)
        #expect(!s.churchPreparationMustWait(enemyID: hound, pendingEnemyIDs: [poison]))
    }
    @Test func poisonHasThreeTicksDoesNotStackAndDiesWithSource() throws {
        var (s, now) = try startChurchTower(11, containing: [.saltSac])
        let id = try #require(s.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .saltSac }).id
        try s.endRound(actingEnemyID: id, at: now)
        try s.endRound(actingEnemyID: id, at: now + 1)
        #expect(s.churchFinitePoisonActive)
        let poisonSource = try #require(s.enemies.first { $0.id == id })
        #expect(!poisonSource.intentPattern.contains("tower_poison"))
        let before = s.playerHP
        _ = s.advanceEmeraldPoison(at: now + 10)
        let after = s.playerHP
        #expect(!s.churchFinitePoisonActive)
        #expect(before - after == 3 * (poisonSource.attack / 2))
        _ = s.advanceEmeraldPoison(at: now + 100)
        #expect(s.playerHP == after)
        // A second cast by this same body cannot restart a carpet.
        for _ in 0..<4 { try s.endRound(actingEnemyID: id, at: now + 101) }
        let afterAttack = s.playerHP
        _ = s.advanceEmeraldPoison(at: now + 120)
        #expect(s.playerHP == afterAttack)
        var (death, deathNow) = try startChurchTower(12, containing: [.saltSac])
        let poison = try #require(death.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .saltSac }).id
        try death.endRound(actingEnemyID: poison, at: deathNow); try death.endRound(actingEnemyID: poison, at: deathNow + 1)
        _ = try death.applyPartyDamage(10000, to: poison)
        #expect(!death.churchFinitePoisonActive)
        let hp = death.playerHP
        _ = death.advanceEmeraldPoison(at: deathNow + 20)
        #expect(death.playerHP == hp)
    }
    @Test func repairFreezesRecipientNoRetargetAndNoSelfHeal() throws {
        var (s, now) = try startChurchTower(23, containing: [.backSac], minimumEnemies: 3)
        let healer = try #require(s.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .backSac }).id
        let recipients = s.enemies.filter { $0.id != healer }
        try #require(recipients.count >= 2)
        _ = try s.applyPartyDamage(100, to: recipients[0].id)
        try s.endRound(actingEnemyID: healer, at: now)
        s.commitEnemyImpact(from: healer)
        #expect(s.repairTargetID(for: healer) == recipients[0].id)
        _ = try s.applyPartyDamage(10000, to: recipients[0].id)
        _ = try s.applyPartyDamage(100, to: recipients[1].id)
        let hp = try #require(s.enemies.first { $0.id == recipients[1].id }).hp
        try s.endRound(actingEnemyID: healer, at: now + 1)
        #expect(s.enemies.first { $0.id == recipients[1].id }?.hp == hp)
        #expect(s.lastEnemyActionResolutions.last?.healing == 0)
    }
    @Test func crownEmpowersOneAttackCycleThenDisappearsAndDeathCancels() throws {
        var (s, now) = try startChurchTower(41, containing: [.crown, .shieldJaw])
        let crown = try #require(s.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .crown }).id
        let dog = try #require(s.enemies.first { MPCChurchTowerCatalog.isShieldJaw($0.contentID) }).id
        // Crown chooses the first living recipient. Clear the minion escort
        // so this contract still measures the shield-jaw's full attack cycle.
        for escort in s.enemies.filter({ $0.id != crown && $0.id != dog }) {
            _ = try s.applyPartyDamage(10000, to: escort.id)
        }
        #expect(s.towerEmpowerTargetID(for: crown) == dog)
        try s.endRound(actingEnemyID: crown, at: now)
        s.commitEnemyImpact(from: crown)
        try s.endRound(actingEnemyID: crown, at: now + 1)
        #expect(s.towerEmpoweredEnemyIDs.contains(dog))
        try s.endRound(actingEnemyID: dog, at: now + 2)
        try s.endRound(actingEnemyID: dog, at: now + 2.5)
        let hp = s.playerHP, attack = try #require(s.enemies.first { $0.id == dog }).attack
        try s.endRound(actingEnemyID: dog, at: now + 3)
        #expect(hp - s.playerHP == attack * 2 * 125 / 100)
        try s.endRound(actingEnemyID: dog, at: now + 4)
        try s.endRound(actingEnemyID: dog, at: now + 5)
        while let e = s.enemies.first(where: { $0.id == dog }), e.intentIndex < e.intentPattern.count {
            try s.endRound(actingEnemyID: dog, at: now + 5)
        }
        #expect(!s.towerEmpoweredEnemyIDs.contains(dog))
        for _ in 0..<4 { try s.endRound(actingEnemyID: crown, at: now + 6) }
        #expect(s.towerEmpoweredEnemyIDs.contains(dog))
        _ = try s.applyPartyDamage(10000, to: crown)
        #expect(s.towerEmpoweredEnemyIDs.isEmpty)
    }
    @Test func waveWaitsForCommittedContactsThenFadeAndKeepsHealth() throws {
        var s = try start(14); let old = s.enemies[0].id
        for escort in s.enemies.dropFirst().map(\.id) {
            _ = try s.applyPartyDamage(10000, to: escort)
        }
        try s.endRound(actingEnemyID: old, at: 0)
        try s.endRound(actingEnemyID: old, at: 0)
        s.commitEnemyImpact(from: old)
        _ = try s.applyPartyDamage(10000, to: old)
        #expect(s.waveIndex == 0 && !s.isAwaitingTowerWave)
        try s.endRound(actingEnemyID: old, at: 1)
        #expect(s.isAwaitingTowerWave && s.waveIndex == 0)
        let hp = s.playerHP
        s.advanceChurchTowerEffects(at: 1.99)
        #expect(s.waveIndex == 0)
        s.advanceChurchTowerEffects(at: 2)
        #expect(s.waveIndex == 1 && s.playerHP == hp && !s.enemies.contains { $0.id == old })
    }
}

/// Tower calibration on the real loop (2026-10-15, user: 塔重新校准难度). Each floor opens at its pace stage
/// (`MPCChurchTowerCatalog.paceMission`: F1–10 Q7, F11–30 Q10, F50 Q15, F70 Q20, F90 Q25, F100 Q27); the
/// recommended loadout of that stage wins every floor with the gear below it (ChurchTowerSixCompletionTests).
/// These are the other side of the curve.
@Suite("Church hundred floor legal realtime balance")
struct ChurchTowerHundredBalanceTests {
    /// The user's case: a Q7 hand, no tower gear, no input at all used to clear F100 (13/60 arrangements).
    /// Every decade's closing floor: `OrderedChapterBalanceAuditTests.towerAudit`.
    @Test(arguments: [100]) func q7HandWithoutGearOrInputCannotClimb(_ floor: Int) async throws {
        let wins = try await RealLoop.map(MPCStageLoadout.orders(before: 7)) { order -> Bool in
            var game = try MPCChurchBattleStepper(encounterID: MPCChurchTowerCatalog.floor(number: floor)!.id,
                                                  loadout: MPCStageLoadout.loadout(before: 7, order: order, passive: nil))
            while !game.isFinished { _ = try game.step() }
            return game.session.outcome == .victory
        }
        #expect(!wins.contains(true), "F\(floor): \(wins.filter { $0 }.count)/60")
    }

    /// Floor progress follows tower gear: with no tower gear at all, even the recommended hand loses the
    /// closing floors from F60 (it wins every floor with the gear below, ChurchTowerSixCompletionTests).
    /// The strongest hand needs little gear before that (F50 without any): reported 2026-10-15.
    @Test(arguments: [60, 70, 80, 90, 100]) func closingFloorsNeedTowerGear(_ n: Int) throws {
        var bare = MPCChurchTowerVerificationRunner.recommendedLoadout(for: try #require(MPCChurchTowerCatalog.floor(number: n)))
        bare.churchGear = .init()
        #expect(try MPCChurchTowerVerificationRunner.run(number: n, suppliedLoadout: bare).session.outcome == .defeat)
    }

    /// Floor progress follows the chapter: F20 and F30 are lost three missions before their pace stage (Q7's
    /// three cards). From Q10 on four slots, so F40/F50 depend on gear and the daily gate more than on cards.
    @Test(arguments: [20, 30]) func closingFloorsNeedTheirStage(_ n: Int) async throws {
        let stage = MPCChurchTowerCatalog.paceMission(floor: n) - 3
        let wins = try await RealLoop.map(MPCStageLoadout.orders(before: stage + 1)) {
            try RealLoop.church(MPCChurchTowerCatalog.floor(number: n)!.id, before: stage + 1, order: $0, gearThrough: n - 1).session.outcome == .victory
        }
        #expect(wins.filter { $0 }.count * 10 <= wins.count, "F\(n) at Q\(stage): \(wins.filter { $0 }.count)/\(wins.count)")
    }

    /// F12 at Q10 power no longer ends at full health.
    @Test func floorTwelveCostsHealthAtItsStage() throws {
        let r = try MPCChurchTowerVerificationRunner.run(number: 12)
        #expect(r.session.outcome == .victory && r.session.playerHP < r.session.playerNormalMaxHP * 3 / 4)
    }
}
