import Testing
@testable import MistportCombatCore

@Suite("Hermit talent allocation and combat")
struct HermitTalentTests {
    @Test(arguments: Array(10...20))
    func earnedFourPointBuildAffectsLaterBattles(mission: Int) throws {
        let allocation = HermitTalentAllocation.restored(
            ["trickery.0", "trickery.1", "phantom.0", "phantom.1"], budget: 4)
        #expect(allocation.learned.count == 4)
        #expect(!allocation.canLearn("trickery.2", budget: 4))
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike, .maskedWhisper], passiveIDs: [], relicIDs: [])
        let encounter = "chapter01_q\(mission)_encounter"
        var baseline = try MPCChapterOneEncounterSession.start(encounterID: encounter, companionIDs: [], loadout: loadout)
        loadout.talents = allocation
        var improved = try MPCChapterOneEncounterSession.start(encounterID: encounter, companionIDs: [], loadout: loadout)
        let target = improved.enemies[0].id
        if mission == 20 {
            while baseline.enemies[0].currentIntent != "recover" {
                try baseline.endRound(actingEnemyID: target)
                try improved.endRound(actingEnemyID: target)
            }
        }
        let ordinary = try baseline.useFoolSkill(.sidestepStrike, targetID: target, usesRealtimeCooldown: true)
        let enhanced = try improved.useFoolSkill(.sidestepStrike, targetID: target, usesRealtimeCooldown: true)
        if mission == 20 { #expect(improved.chapterObjectiveProgress > baseline.chapterObjectiveProgress) }
        else { #expect(enhanced.damage > ordinary.damage) }
        _ = try improved.useFoolSkill(.maskedWhisper, targetID: target, usesRealtimeCooldown: true)
        #expect(improved.playerShield == 30)
        #expect(improved.masqueradeCharges == 2)
        // A new encounter carries the allocation, but not the previous shield
        // or temporary phantom charges.
        let fresh = try MPCChapterOneEncounterSession.start(encounterID: encounter, companionIDs: [], loadout: loadout)
        #expect(fresh.loadout.talents == allocation)
        #expect(fresh.playerShield == 0)
        #expect(fresh.masqueradeCharges == 0)
    }

    @Test func allocationConstraintsAndRestore() {
        var value = HermitTalentAllocation()
        let learned1 = !value.learn("trickery.5", budget: 9)
        #expect(learned1)
        let learned2 = !value.learn("invalid", budget: 9)
        #expect(learned2)
        let learned3 = value.learn("trickery.0", budget: 1)
        #expect(learned3)
        let learned4 = !value.learn("trickery.0", budget: 9)
        #expect(learned4)
        let learned5 = !value.learn("phantom.0", budget: 1)
        #expect(learned5)
        let recovered = HermitTalentAllocation.restored(["trickery.5", "trickery.0", "phantom.0", "bad"], budget: 9)
        #expect(recovered.learned == ["trickery.0", "phantom.0"])
        value.reset()
        #expect(value.learned.isEmpty)
        for node in HermitTalent.all { value.learn(node.id, budget: 9) }
        #expect(value.learned.count == 9)
        #expect(value.has("trickery.5"))
    }

    func session(_ branch: HermitBranch? = nil) throws -> MPCChapterOneEncounterSession {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike, .maskedWhisper, .fabricatedEvidence, .absurdFinale], passiveIDs: [], relicIDs: [])
        if let branch { loadout.talents = .restored(HermitTalent.all.filter { $0.branch == branch }.map(\.id), budget: 9) }
        return try .start(encounterID: "chapter01_q03_encounter", companionIDs: [], loadout: loadout)
    }

    @Test func trickeryBoostsBothTargets() throws {
        var baseline = try session()
        var improved = try session(.trickery)
        let a = try baseline.useFoolSkill(.sidestepStrike, targetID: baseline.enemies[0].id, usesRealtimeCooldown: true)
        let b = try improved.useFoolSkill(.sidestepStrike, targetID: improved.enemies[0].id, usesRealtimeCooldown: true)
        #expect(b.damage > a.damage)
        // Q2 uses the same per-target modifiers and must preserve independent HP.
        var loadout = improved.loadout
        loadout.normalSkillIDs = [.sidestepStrike]
        var dual = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q02_encounter", companionIDs: [], loadout: loadout)
        let result = try dual.useFoolSkill(.sidestepStrike, targetID: dual.enemies[0].id)
        #expect(result.targets.count == 2)
        for hit in result.targets { let enemy = try #require(dual.enemies.first { $0.id == hit.targetID }); #expect(enemy.hp == max(0, enemy.maxHP - hit.damage)) }
    }

    @Test func phantomWaitsForActualEnemyResolution() throws {
        var value = try session(.phantom)
        _ = try value.useFoolSkill(.maskedWhisper, targetID: value.enemies[0].id, usesRealtimeCooldown: true)
        #expect(value.playerShield == 30)
        #expect(value.masqueradeCharges == 2)
        let hp = value.playerHP
        try value.endRound()
        #expect(value.playerHP == hp)
        #expect(value.playerShield == 50)
        #expect(value.masqueradeCharges == 1)
        let enhanced = try value.useFoolSkill(.sidestepStrike, targetID: value.enemies[0].id, usesRealtimeCooldown: true)
        var base = try session()
        _ = try base.useFoolSkill(.maskedWhisper, targetID: base.enemies[0].id, usesRealtimeCooldown: true)
        try base.endRound()
        let ordinary = try base.useFoolSkill(.sidestepStrike, targetID: base.enemies[0].id, usesRealtimeCooldown: true)
        #expect(enhanced.damage > ordinary.damage)
    }

    @Test func omenCapsStacksAndGrantsShieldOnDamagingHit() throws {
        var value = try session(.omen)
        let id = value.enemies[0].id
        _ = try value.useFoolSkill(.fabricatedEvidence, targetID: id, usesRealtimeCooldown: true)
        #expect((value.foolStates[id]?.illusionStacks ?? 0) > 0)
        let shield = value.playerShield
        _ = try value.useFoolSkill(.sidestepStrike, targetID: id, usesRealtimeCooldown: true)
        #expect(value.playerShield == shield + 15)
        #expect((value.foolStates[id]?.illusionStacks ?? 0) <= 4)
    }
}
