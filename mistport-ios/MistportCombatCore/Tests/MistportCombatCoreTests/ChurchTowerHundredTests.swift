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
            #expect((1...3).contains(f.waves.count))
            #expect(f.waves.flatMap { $0 }.filter { $0.species == .backSac }.count <= 1)
            for w in f.waves.indices {
                #expect((1...4).contains(f.waves[w].count))
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
        try .start(encounterID: MPCChurchTowerCatalog.floor(number: n)!.id, companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
    }
    @Test func allChurchPreparationFamiliesShareAnExclusiveGate() throws {
        for n in [6, 11, 21, 31, 41, 51] {
            var s = try start(n)
            let id = s.enemies[0].id
            #expect(s.isChurchHighThreatPreparation(enemyID: id))
            #expect(!s.churchPreparationMustWait(enemyID: id, pendingEnemyIDs: [id]))
            try s.endRound(actingEnemyID: id, at: 0)
            #expect(!s.isChurchHighThreatPreparation(enemyID: id))
        }
        var s = try start(13) // F12 now introduces Copperback; F13 retains the shield/poison pair.
        let hound = s.enemies.first { MPCChurchTowerCatalog.isShieldJaw($0.contentID) }!.id
        let poison = s.enemies.first { $0.id != hound }!.id
        try s.endRound(actingEnemyID: hound, at: 0)
        #expect(s.churchPreparationMustWait(enemyID: hound, pendingEnemyIDs: [poison]))
        try s.endRound(actingEnemyID: poison, at: 0)
        #expect(!s.churchPreparationMustWait(enemyID: hound, pendingEnemyIDs: [poison]))
    }
    @Test func poisonHasThreeTicksDoesNotStackAndDiesWithSource() throws {
        var s = try start(11); let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0)
        try s.endRound(actingEnemyID: id, at: 1)
        #expect(s.churchFinitePoisonActive)
        #expect(!s.enemies[0].intentPattern.contains("tower_poison"))
        let before = s.playerHP
        _ = s.advanceEmeraldPoison(at: 10)
        let after = s.playerHP
        #expect(!s.churchFinitePoisonActive)
        #expect(before - after == 3 * (s.enemies[0].attack / 2))
        _ = s.advanceEmeraldPoison(at: 100)
        #expect(s.playerHP == after)
        // A second cast by this same body cannot restart a carpet.
        for _ in 0..<4 { try s.endRound(actingEnemyID: id, at: 101) }
        let afterAttack = s.playerHP
        _ = s.advanceEmeraldPoison(at: 120)
        #expect(s.playerHP == afterAttack)
        var death = try start(12)
        let poison = death.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .saltSac }!.id
        try death.endRound(actingEnemyID: poison, at: 0); try death.endRound(actingEnemyID: poison, at: 1)
        _ = try death.applyPartyDamage(10000, to: poison)
        #expect(!death.churchFinitePoisonActive)
        let hp = death.playerHP
        _ = death.advanceEmeraldPoison(at: 20)
        #expect(death.playerHP == hp)
    }
    @Test func repairFreezesRecipientNoRetargetAndNoSelfHeal() throws {
        var s = try start(23)
        let healer = s.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .backSac }!.id
        let recipients = s.enemies.filter { $0.id != healer }
        _ = try s.applyPartyDamage(100, to: recipients[0].id)
        try s.endRound(actingEnemyID: healer, at: 0)
        s.commitEnemyImpact(from: healer)
        #expect(s.repairTargetID(for: healer) == recipients[0].id)
        _ = try s.applyPartyDamage(10000, to: recipients[0].id)
        _ = try s.applyPartyDamage(100, to: recipients[1].id)
        let hp = s.enemies.first { $0.id == recipients[1].id }!.hp
        try s.endRound(actingEnemyID: healer, at: 1)
        #expect(s.enemies.first { $0.id == recipients[1].id }!.hp == hp)
        #expect(s.lastEnemyActionResolutions.last?.healing == 0)
    }
    @Test func crownEmpowersOneAttackCycleThenDisappearsAndDeathCancels() throws {
        var s = try start(41)
        let crown = s.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .crown }!.id
        let dog = s.enemies.first { $0.id != crown }!.id
        try s.endRound(actingEnemyID: crown, at: 0)
        s.commitEnemyImpact(from: crown)
        try s.endRound(actingEnemyID: crown, at: 1)
        #expect(s.towerEmpoweredEnemyIDs.contains(dog))
        try s.endRound(actingEnemyID: dog, at: 2)
        try s.endRound(actingEnemyID: dog, at: 2.5)
        let hp = s.playerHP, attack = s.enemies.first { $0.id == dog }!.attack
        try s.endRound(actingEnemyID: dog, at: 3)
        #expect(hp - s.playerHP == attack * 2 * 125 / 100)
        try s.endRound(actingEnemyID: dog, at: 4)
        try s.endRound(actingEnemyID: dog, at: 5)
        while let e = s.enemies.first(where: { $0.id == dog }), e.intentIndex < e.intentPattern.count {
            try s.endRound(actingEnemyID: dog, at: 5)
        }
        #expect(!s.towerEmpoweredEnemyIDs.contains(dog))
        for _ in 0..<4 { try s.endRound(actingEnemyID: crown, at: 6) }
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

/// Shares the native serial player cadence and committed hit lifecycle. This is
/// a deterministic contract test; it does not stand in for device art validation.
enum TowerHundredSimulator {
    static func run(floor: MPCChurchTowerCatalog.Floor, offset: Double, passive: String? = nil) throws -> MPCChapterOneEncounterSession {
        try run(encounterID: floor.id, mission: max(7, floor.requiredMission), offset: offset, passive: passive)
    }
    static func run(encounterID: String, mission q: Int, offset: Double, passive: String? = nil, jitter: Double = 0, seed: UInt64 = 1, onFinished: ((Double) -> Void)? = nil) throws -> MPCChapterOneEncounterSession {
        var randomState = seed
        func variation() -> Double {
            randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
            return (Double((randomState >> 32) % 10001) / 5000 - 1) * jitter
        }
        var nextMedalAt = max(0, offset + variation())
        let sequence: [FoolSkillID] = q < 8 ? [.sidestepStrike] : q < 11 ? [.identityDisplacement, .sidestepStrike] : q < 12 ? [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .sidestepStrike] : [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .absurdFinale]
        var loadout = MPCChapterOneLoadout(normalSkillIDs: sequence, isUltimateUnlocked: false, passiveIDs: [], relicIDs: passive.map { [$0] } ?? [])
        loadout.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID
        var earnedGear = MPCChurchGearLedger()
        if let number = Int(encounterID.suffix(3)), number > 1 {
            for cleared in 1..<number {
                if let drop = MPCChurchGearCatalog.towerDrop(floor: cleared) { earnedGear.grant(drop.id) }
            }
        }
        loadout.churchGear = earnedGear.stats
        let budget = (1...q).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for: $0)?.talentPoints }.reduce(0, +)
        loadout.talents = HermitTalentAllocation.restored((0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" }, budget: budget)
        var s = try MPCChapterOneEncounterSession.start(encounterID: encounterID, companionIDs: [], loadout: loadout)
        var scheduler = ContinuousSkillScheduler(), playerAt = 0.0, basicAt = 0.0
        var hit: (FoolSkillID?, String, Double)?
        var ready: [String: Double] = [:], pending: [String: Double] = [:]
        var elapsed = 0.0
        for tick in 0..<7200 where s.outcome == .inProgress {
            let now = Double(tick) * 0.05
            elapsed = now
            _ = s.advanceEmeraldPoison(at: now)
            guard s.outcome == .inProgress else { break }
            let alive = s.enemies.filter(\.isAlive)
            // Target selection is a supported player action, with support-first priority.
            let target = alive.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .backSac }
                ?? alive.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == .crown }
                ?? alive.first { $0.contentID.hasPrefix("bounty_b03_escort_") }
                ?? alive.first { $0.currentIntent != "guard" } ?? alive.first
            if let target {
                s.updateRelicTarget(target.id, at: now)
                if now >= nextMedalAt && target.currentIntent != "guard" {
                    if s.activateUsurpedLifeMedal(isOwned: true, at: now) { nextMedalAt = s.usurpedLifeMedalReadyAt + max(0, variation()) }
                }
            }
            if let p = hit, now >= p.2 {
                hit = nil
                if s.enemies.contains(where: { $0.id == p.1 && $0.isAlive }) {
                    if let skill = p.0 { _ = try s.useFoolSkill(skill, targetID: p.1, usesRealtimeCooldown: true) }
                    else { _ = try s.useBasicAction(.damage, targetID: p.1) }
                }
            }
            guard s.outcome == .inProgress else { break }
            for id in pending.keys.sorted() where now >= pending[id]! {
                pending[id] = nil
                guard s.enemies.contains(where: { $0.id == id }) else { continue }
                try s.endRound(actingEnemyID: id, at: now)
                ready[id] = now
                if s.outcome != .inProgress { break }
            }
            guard s.outcome == .inProgress else { break }
            for enemy in s.enemies.filter(\.isAlive) {
                if ready[enemy.id] == nil { ready[enemy.id] = now + (MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID)?.initialDelay ?? 3) }
                guard now >= ready[enemy.id]!, pending[enemy.id] == nil else { continue }
                // One active high-threat preparation at a time; ordinary contacts
                // still use their own deadlines and are never silently skipped.
                let preparation = s.authoredPreparationDuration(for: enemy.id)
                if s.churchPreparationMustWait(enemyID: enemy.id, pendingEnemyIDs: Set(pending.keys)) { continue }
                if s.consumeEnemyDelay(for: enemy.id) { ready[enemy.id] = now + 3.2 * enemy.attackIntervalMultiplier; continue }
                let contact = MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID) == nil ? 1.0 : MPCChurchTowerCatalog.contactDuration(contentID: enemy.contentID, intent: enemy.currentIntent)
                s.commitEnemyImpact(from: enemy.id)
                pending[enemy.id] = now + (preparation ?? max(0.15, contact + variation()))
            }
            guard let target, s.enemies.contains(where: { $0.id == target.id && $0.isAlive }), now >= playerAt, hit == nil else { continue }
            if let skill = scheduler.next(in: sequence, at: now) {
                scheduler.didCast(skill, at: now); playerAt = now + 1.75 + max(0, variation())
                hit = (skill, target.id, now + max(0.15, NewMaskBalanceSimulator.playerContact(skill) + variation()))
            } else if now >= basicAt {
                basicAt = now + 2.4; playerAt = now + 1.65 + max(0, variation())
                hit = (nil, target.id, now + max(0.15, 0.58 + variation()))
            }
        }
        onFinished?(elapsed)
        return s
    }
}

@Suite("Church hundred floor legal realtime balance")
struct ChurchTowerHundredBalanceTests {
    @Test func eachFloorHasAnEarnedBuildRouteWithoutConsumableOrMaskGrinding() throws {
        for floor in MPCChurchTowerCatalog.floors {
            var won = false
            var lastHP = 0
            let routes: [(Double, String?)] = [(6, nil), (14, nil), (22, nil)] + (floor.requiredMission >= 20 ? [(6, "relic_sealed_paperweight"), (14, "relic_sealed_paperweight"), (6, "relic_return_gift_clasp"), (14, "relic_return_gift_clasp"), (22, "relic_return_gift_clasp")] : [])
            for (offset, passive) in routes {
                let session = try TowerHundredSimulator.run(floor: floor, offset: offset, passive: passive)
                lastHP = session.playerHP
                if session.outcome == .victory {
                    print("TOWER100_BALANCE floor=\(floor.number) offset=\(offset) hp=\(lastHP) waves=\(floor.waves.count) passive=\(passive ?? "none")")
                    won = true; break
                }
            }
            #expect(won, "Floor \(floor.number) has no tested earned build victory, HP \(lastHP)")
        }
    }
}
