import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Church tower released first section")
struct ChurchTowerTests {
    @Test func opensAfterQ7ButNoFutureFloors() {
        let progress = MPCChurchTowerProgress()
        #expect(!progress.canEnter(1, completedMissionNumbers: []))
        #expect(!progress.canEnter(1, completedMissionNumbers: Set(1...6)))
        #expect(progress.canEnter(1, completedMissionNumbers: [7]))
        #expect(progress.canEnter(1, completedMissionNumbers: [16]))
        #expect(!progress.canEnter(2, completedMissionNumbers: [7]))
        #expect(!progress.canEnter(0, completedMissionNumbers: [7]))
        #expect(!progress.canEnter(11, completedMissionNumbers: Set(1...30)))
    }
    @Test func sequentialVictoriesAndReplayAreIdempotent() throws {
        var progress = MPCChurchTowerProgress()
        var coins = 0, merit = 0
        for floor in 1...10 {
            #expect(progress.nextFloor == floor)
            let claimed = progress.claimVictory(floor: floor, completedMissionNumbers: [7])
            let reward = try #require(claimed)
            coins += reward.coins; merit += reward.merit
            #expect(progress.claimVictory(floor: floor, completedMissionNumbers: [7]) == nil)
            #expect(progress.canEnter(floor, completedMissionNumbers: [7]))
        }
        #expect(coins == 80 && merit == 20)
        #expect(progress.nextFloor == 11)
        #expect(progress.canEnter(11, completedMissionNumbers: Set(1...30)))
    }
    @Test func failedOrInvalidAttemptsLeaveProgressUnchanged() {
        var progress = MPCChurchTowerProgress(clearedFloors: [1])
        let before = progress
        #expect(progress.claimVictory(floor: 3, completedMissionNumbers: [7]) == nil)
        #expect(progress.claimVictory(floor: 11, completedMissionNumbers: []) == nil)
        #expect(progress == before)
        #expect(progress.canEnter(2, completedMissionNumbers: [7]))
    }
    @Test func roundTripPreservesClearLedgerAndFutureEntitlements() throws {
        let progress = MPCChurchTowerProgress(clearedFloors: [1, 2, 11])
        let restored = try JSONDecoder().decode(MPCChurchTowerProgress.self, from: JSONEncoder().encode(progress))
        #expect(restored == progress)
        #expect(restored.nextFloor == 3)
        #expect(!restored.canEnter(11, completedMissionNumbers: [7]))
    }
    @Test func uniqueAuthoredFloorsMatchOpeningSpeciesAndBudget() {
        let floors = Array(MPCChurchTowerCatalog.floors.prefix(10))
        #expect(floors.map(\.number) == Array(1...10))
        #expect(Set(floors.map(\.id)).count == 10)
        #expect(floors[0].enemies.count == 1)
        #expect(floors.dropFirst().allSatisfy { (3...4).contains($0.enemies.count) })
        #expect(floors.dropFirst().allSatisfy { $0.enemies.filter { [.copperback, .crimsonBrute, .veilOracle, .goldenThroat, .moonfang].contains($0.species) }.count >= 2 })
        #expect(floors.flatMap(\.enemies).allSatisfy { $0.hp > 0 && $0.attack > 0 && $0.interval > 0 })
        #expect(floors.last?.enemies[1].elite == true)
        #expect(floors.last?.enemies[1].species == .shieldJaw)
        for floor in floors { #expect(Set(floor.enemies.map(\.initialDelay)).count >= min(2, floor.enemies.count)) }
    }
    @Test func runtimeIdentityShieldAndSeparateFireballs() throws {
        var jaw = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_002", companionIDs: [])
        let id = jaw.enemies[0].id
        #expect(MPCChapterOneBattleIdentity.visualDescriptor(for: id, in: jaw.enemies, encounterID: jaw.encounter.id) == "clock-guard-primary@stonehide")
        let hp = jaw.enemies[0].hp
        _ = try jaw.applyPartyDamage(10000, to: id)
        #expect(jaw.enemies[0].hp == hp)
        try jaw.endRound(actingEnemyID: id, at: 3)
        #expect(jaw.enemies[0].currentIntent == "charge")
        _ = try jaw.applyPartyDamage(100, to: id)
        #expect(jaw.enemies[0].hp < hp)
        var hound = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_031", companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        let dog = hound.enemies[0].id
        try hound.endRound(actingEnemyID: dog, at: 2)
        let before = hound.playerHP
        try hound.endRound(actingEnemyID: dog, at: 3)
        let afterFirst = hound.playerHP
        try hound.endRound(actingEnemyID: dog, at: 4)
        #expect(before > afterFirst && afterFirst > hound.playerHP)
    }
    @Test func q7SidestepMedalNoMaskNoConsumablesClearsEveryFloor() throws {
        for floor in MPCChurchTowerCatalog.floors.prefix(10) {
            var loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
            loadout.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID
            var earnedGear = MPCChurchGearLedger()
            if floor.number > 1 {
                for cleared in 1..<floor.number {
                    if let drop = MPCChurchGearCatalog.towerDrop(floor: cleared) { earnedGear.grant(drop.id) }
                }
            }
            loadout.churchGear = earnedGear.stats
            var battle = try MPCChapterOneEncounterSession.start(encounterID: floor.id, companionIDs: [], loadout: loadout)
            var due = Dictionary(uniqueKeysWithValues: battle.enemies.map { ($0.id, MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)!.initialDelay) })
            var basicAt = 0.0, playerAt = 0.0
            var scheduler = ContinuousSkillScheduler()
            var contact: (FoolSkillID?, String, Double)?
            for tick in 0..<2400 where battle.outcome == .inProgress {
                let now = Double(tick) * 0.05
                _ = battle.advanceUsurpedLifeMedal(at: now)
                let living = battle.enemies.filter(\.isAlive)
                guard let target = living.first(where: { $0.currentIntent != "guard" }) ?? living.first else { break }
                if now >= 6 && target.currentIntent != "guard" { _ = battle.activateUsurpedLifeMedal(isOwned: true, at: now) }
                if let hit = contact, now >= hit.2 {
                    contact = nil
                    if battle.enemies.contains(where: { $0.id == hit.1 && $0.isAlive }) {
                        if let skill = hit.0 { _ = try battle.useFoolSkill(skill, targetID: hit.1, usesRealtimeCooldown: true) }
                        else { _ = try battle.useBasicAction(.damage, targetID: hit.1) }
                    }
                }
                if battle.outcome != .inProgress { break }
                if now >= playerAt && contact == nil {
                    if let skill = scheduler.next(in: [.sidestepStrike], at: now) {
                        scheduler.didCast(skill, at: now); playerAt = now + 1.75
                        contact = (skill, target.id, now + 0.6192)
                    } else if now >= basicAt {
                        basicAt = now + 2.4; playerAt = now + 1.65
                        contact = (nil, target.id, now + 0.58)
                    }
                }
                for enemy in battle.enemies.filter(\.isAlive) where now >= due[enemy.id, default: 0] {
                    try battle.endRound(actingEnemyID: enemy.id, at: now)
                    if battle.outcome != .inProgress { break }
                    let updated = battle.enemies.first { $0.id == enemy.id }!
                    due[enemy.id] = now + (MPCChurchTowerCatalog.preparationDuration(contentID: updated.contentID, intent: updated.currentIntent) ?? (updated.currentIntent == "tower_flame_second" ? 0.8 : 1.0))
                }
            }
            print("TOWER_BALANCE floor=\(floor.number) outcome=\(battle.outcome) hp=\(battle.playerHP)")
            #expect(battle.outcome == .victory, "floor \(floor.number)")
        }
    }

    @Test func towerMaskBlocksTwoContactsWithFourSecondWindowAndEighteenSecondCooldown() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_031", companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        let dog = s.enemies[0].id
        try s.endRound(actingEnemyID: dog, at: 0) // charge -> first fireball
        let accepted = try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, lifetimeCracks: 0, at: 1)
        #expect(accepted != nil && accepted?.damage == 0)
        #expect(s.ownedManualMaskExpiresAt == 5 && s.ownedManualMaskReadyAt == 19)
        let hp = s.playerHP
        try s.endRound(actingEnemyID: dog, at: 2)
        try s.endRound(actingEnemyID: dog, at: 2.8)
        #expect(s.playerHP == hp && s.masqueradeCharges == 0)
        #expect(try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: 18.99) == nil)
        #expect(try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: 19) != nil)
    }
    @Test func towerMaskConsumesPermanentCrackIncludingTenthAndRetryDoesNotRestoreIt() throws {
        var campaign = MPCChapterOneCampaignState(masqueradeCrackCount: 9)
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_001", companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        #expect(try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, lifetimeCracks: campaign.masqueradeCrackCount, at: 0) != nil)
        let registered = campaign.registerMasqueradeUse(encounterID: s.encounter.id)
        #expect(registered && campaign.masqueradeCrackCount == 10)
        #expect(s.masqueradeCharges == 2)
        #expect(try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, lifetimeCracks: campaign.masqueradeCrackCount, at: 18) == nil)
        var retry = try MPCChapterOneEncounterSession.start(encounterID: s.encounter.id, companionIDs: [])
        #expect(try retry.useOwnedManualMasquerade(targetID: nil, isOwned: true, lifetimeCracks: campaign.masqueradeCrackCount, at: 0) == nil)
        #expect(retry.masqueradeCharges == 0 && campaign.masqueradeCrackCount == 10)
        var ordinary = MPCChapterOneCampaignState(masqueradeCrackCount: 0)
        let normalUse = ordinary.registerMasqueradeUse(encounterID: s.encounter.id)
        #expect(normalUse && ordinary.masqueradeCrackCount == 1)
    }

}
