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
        // One or two majors plus the floor's walking minion pack, spread over the floor's
        // waves since 2026-10-12: minions first, majors close the floor.
        #expect(floors.dropFirst().allSatisfy { floor in
            let pack = MPCChurchTowerCatalog.minionPackSize(floor: floor.number)
            return (pack + 1...pack + 2).contains(floor.waves.flatMap { $0 }.count)
        })
        #expect(floors.dropFirst().allSatisfy { $0.waves.flatMap { $0 }.filter { [.copperback, .crimsonBrute, .veilOracle, .goldenThroat, .moonfang].contains($0.species) }.count >= 2 })
        #expect(floors.flatMap { $0.waves.flatMap { $0 } }.allSatisfy { $0.hp > 0 && $0.attack > 0 && $0.interval > 0 })
        #expect(floors.last?.waves.last?.contains { $0.elite && $0.species == .shieldJaw } == true)
        for floor in floors { #expect(Set(floor.waves.joined().map(\.initialDelay)).count >= min(2, floor.waves.joined().count)) }
    }
    @Test func runtimeIdentityShieldAndSeparateFireballs() throws {
        // Majors close their floors after the minion waves (2026-10-12); pick them by species.
        var (jaw, jawNow) = try startChurchTower(2, containing: [.shieldJaw], loadout: MPCChapterOneLoadout())
        let id = try #require(jaw.enemies.first { towerSpecies($0) == .shieldJaw }).id
        func jawState() -> MPCRuntimeEnemy? { jaw.enemies.first { $0.id == id } }
        // The slot name follows the jaw's place behind its minion; the stonehide body is the identity.
        let slot = try #require(MPCChapterOneBattleIdentity.battleID(for: id, in: jaw.enemies))
        #expect(MPCChapterOneBattleIdentity.visualDescriptor(for: id, in: jaw.enemies, encounterID: jaw.encounter.id) == slot + "@stonehide")
        let hp = try #require(jawState()).hp
        _ = try jaw.applyPartyDamage(10000, to: id)
        #expect(jawState()?.hp == hp)
        try jaw.endRound(actingEnemyID: id, at: jawNow + 3)
        #expect(jawState()?.currentIntent == "charge")
        _ = try jaw.applyPartyDamage(100, to: id)
        #expect((jawState()?.hp ?? .max) < hp)
        var (hound, houndNow) = try startChurchTower(31, containing: [.scissor])
        let dog = try #require(hound.enemies.first { towerSpecies($0) == .scissor }).id
        try hound.endRound(actingEnemyID: dog, at: houndNow + 2)
        let before = hound.playerHP
        try hound.endRound(actingEnemyID: dog, at: houndNow + 3)
        let afterFirst = hound.playerHP
        try hound.endRound(actingEnemyID: dog, at: houndNow + 4)
        #expect(before > afterFirst && afterFirst > hound.playerHP)
    }
    @Test func q7HandMedalNoMaskNoConsumablesClearsEveryFloor() throws {
        for floor in MPCChurchTowerCatalog.floors.prefix(10) {
            // Clearing Q7 opens a three-card hand (2026-10-12 schedule); sidestep alone is no longer the Q7 kit.
            let hand = MPCChurchTowerVerificationRunner.recommendedLoadout(for: floor).normalSkillIDs
            #expect(hand.count == MPCOrderedSkillRules.slotCapacity(availableThrough: 8))
            var loadout = MPCChapterOneLoadout(normalSkillIDs: hand, isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
            loadout.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID
            var earnedGear = MPCChurchGearLedger()
            if floor.number > 1 {
                for cleared in 1..<floor.number {
                    if let drop = MPCChurchGearCatalog.towerDrop(floor: cleared) { earnedGear.grant(drop.id) }
                }
            }
            loadout.churchGear = earnedGear.stats
            // The App's rules through MPCChurchBattleStepper: waves advance through their fades.
            let battle = try MPCChurchTowerVerificationRunner.run(number: floor.number, medalOffset: 6, suppliedLoadout: loadout).session
            print("TOWER_BALANCE floor=\(floor.number) outcome=\(battle.outcome) hp=\(battle.playerHP)")
            #expect(battle.outcome == .victory, "floor \(floor.number)")
        }
    }

    @Test func towerMaskBlocksTwoContactsWithFourSecondWindowAndEighteenSecondCooldown() throws {
        var (s, now) = try startChurchTower(31, containing: [.scissor])
        let dog = try #require(s.enemies.first { towerSpecies($0) == .scissor }).id
        try s.endRound(actingEnemyID: dog, at: now) // charge -> first fireball
        let accepted = try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, lifetimeCracks: 0, at: now + 1)
        #expect(accepted != nil && accepted?.damage == 0)
        #expect(s.ownedManualMaskExpiresAt == now + 5 && s.ownedManualMaskReadyAt == now + 19)
        let hp = s.playerHP
        try s.endRound(actingEnemyID: dog, at: now + 2)
        try s.endRound(actingEnemyID: dog, at: now + 2.8)
        #expect(s.playerHP == hp && s.masqueradeCharges == 0)
        #expect(try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: now + 18.99) == nil)
        #expect(try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: now + 19) != nil)
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
