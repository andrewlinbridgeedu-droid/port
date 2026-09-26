import Testing
@testable import MistportCombatCore

@Suite("Outfit bonuses in real encounters")
struct OutfitBonusTests {
    private func bareLoadout() -> MPCChapterOneLoadout {
        .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
    }

    @Test func threeOutfitsHaveSmallDistinctBonusesWithoutChangingBareFixtures() {
        #expect(MPCChapterOneLoadout().outfitBonus == .none)
        #expect(MPCOutfit.allCases.count == 3)
        #expect(MPCOutfit.mistportNight.bonus == .init(luckDodgeBP: 200, attackBP: 100, damageReductionBP: 100))
        #expect(MPCOutfit.starlightMagician.bonus == .init(luckDodgeBP: 300, attackBP: 100, damageReductionBP: 0))
        #expect(MPCOutfit.midnightCarnival.bonus == .init(luckDodgeBP: 100, attackBP: 200, damageReductionBP: 100))
    }

    @Test func luckIsStableAcrossRetriesAndHigherLuckContainsLowerLuckSuccesses() {
        var lowCount = 0
        var highCount = 0
        for action in 0..<2_000 {
            let low = MPCOutfit.midnightCarnival.dodgesDirectHit(
                encounterID: "chapter01_q08_encounter", enemyID: "test-enemy", intent: "strike",
                wave: 0, actionIndex: action
            )
            let high = MPCOutfit.starlightMagician.dodgesDirectHit(
                encounterID: "chapter01_q08_encounter", enemyID: "test-enemy", intent: "strike",
                wave: 0, actionIndex: action
            )
            #expect(!low || high)
            #expect(high == MPCOutfit.starlightMagician.dodgesDirectHit(
                encounterID: "chapter01_q08_encounter", enemyID: "test-enemy", intent: "strike",
                wave: 0, actionIndex: action
            ))
            if low { lowCount += 1 }
            if high { highCount += 1 }
        }
        #expect(lowCount > 0)
        #expect(highCount > lowCount)
    }

    @Test func outfitAttackAndReductionAreAppliedToBattleResults() throws {
        let bare = bareLoadout()
        var dressed = bare
        dressed.outfit = .midnightCarnival
        var baseAttack = try MPCChapterOneEncounterSession.start(
            encounterID: "church_tower_011", companionIDs: [], loadout: bare
        )
        var dressedAttack = try MPCChapterOneEncounterSession.start(
            encounterID: "church_tower_011", companionIDs: [], loadout: dressed
        )
        let target = baseAttack.enemies[0].id
        let baseDamage = try baseAttack.useBasicAction(.damage, targetID: target)
        let outfitDamage = try dressedAttack.useBasicAction(.damage, targetID: target)
        #expect(outfitDamage > baseDamage)
        #expect(dressedAttack.loadout.outfit == .midnightCarnival)

        var baseDefense = try MPCChapterOneEncounterSession.start(
            encounterID: "church_tower_001", companionIDs: [], loadout: bare
        )
        var dressedDefense = try MPCChapterOneEncounterSession.start(
            encounterID: "church_tower_001", companionIDs: [], loadout: dressed
        )
        let attacker = baseDefense.enemies[0].id
        for tick in 0...2 {
            try baseDefense.endRound(actingEnemyID: attacker, at: Double(tick))
            try dressedDefense.endRound(actingEnemyID: attacker, at: Double(tick))
        }
        #expect(dressedDefense.playerMaxHP - dressedDefense.playerHP < baseDefense.playerMaxHP - baseDefense.playerHP)
    }

    @Test func luckyOutfitActuallyDodgesARealTowerStrike() throws {
        let party = MPCPartyPersistentState(playerHP: 100_000, playerMaxHP: 100_000)
        let bare = bareLoadout()
        var lucky = bare
        lucky.outfit = .starlightMagician // zero reduction isolates the dodge result
        var base = try MPCChapterOneEncounterSession.start(
            encounterID: "church_tower_004", party: party, companionIDs: [], loadout: bare
        )
        var dressed = try MPCChapterOneEncounterSession.start(
            encounterID: "church_tower_004", party: party, companionIDs: [], loadout: lucky
        )
        let attacker = try #require(base.enemies.first { MPCChurchTowerCatalog.isShieldJaw($0.contentID) })
        var observedDodge = false
        for tick in 0..<1_000 {
            let enemy = try #require(dressed.enemies.first { $0.id == attacker.id })
            let wouldDodge = MPCOutfit.starlightMagician.dodgesDirectHit(
                encounterID: dressed.encounter.id, enemyID: enemy.id,
                intent: enemy.currentIntent, wave: dressed.waveIndex, actionIndex: enemy.intentIndex
            )
            try base.endRound(actingEnemyID: attacker.id, at: Double(tick))
            try dressed.endRound(actingEnemyID: attacker.id, at: Double(tick))
            let bareDamage = try #require(base.lastEnemyActionResolutions.first?.playerDamage)
            let dressedDamage = try #require(dressed.lastEnemyActionResolutions.first?.playerDamage)
            if wouldDodge, bareDamage > 0 {
                #expect(dressedDamage == 0)
                observedDodge = true
                break
            }
            #expect(dressedDamage == bareDamage)
        }
        #expect(observedDodge)
    }

    @Test func luckDoesNotBypassPoisonOrQ4TeachingHits() throws {
        let bare = bareLoadout()
        var lucky = bare
        lucky.outfit = .starlightMagician // no damage reduction, so teaching damage must match exactly

        var basePoison = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q05_encounter", companionIDs: [], loadout: bare
        )
        var luckyPoison = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q05_encounter", companionIDs: [], loadout: lucky
        )
        try basePoison.endRound(at: 10)
        try luckyPoison.endRound(at: 10)
        #expect(basePoison.isEmeraldPoisonActive)
        #expect(luckyPoison.isEmeraldPoisonActive)
        #expect(basePoison.advanceEmeraldPoison(at: 13) == luckyPoison.advanceEmeraldPoison(at: 13))

        var baseTutorial = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q04_encounter", companionIDs: [], loadout: bare
        )
        var luckyTutorial = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q04_encounter", companionIDs: [], loadout: lucky
        )
        for tick in 0...2 {
            try baseTutorial.endRound(at: Double(tick))
            try luckyTutorial.endRound(at: Double(tick))
            #expect(luckyTutorial.playerHP == baseTutorial.playerHP)
            #expect(luckyTutorial.lastEnemyActionResolutions == baseTutorial.lastEnemyActionResolutions)
        }
    }
}
