import Testing
@testable import MistportCombatCore

@Suite("Approved skill strengthening")
struct SkillGrowthTests {
    private func session(level: Int = 1, encounter: String = "chapter01_q15_encounter", talents: HermitTalentAllocation = .init(), relics: [String] = []) throws -> MPCChapterOneEncounterSession {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike, .maskedWhisper, .identityDisplacement, .fabricatedEvidence, .mirrorPursuit], passiveIDs: [], relicIDs: relics)
        loadout.skillLevels = Dictionary(uniqueKeysWithValues: FoolSkillID.allCases.map { ($0, level) })
        loadout.talents = talents
        return try .start(encounterID: encounter, consumables: ["consumable_mirror_salve": 1], companionIDs: [], loadout: loadout)
    }

    @Test func policyAndLegacyDefaults() {
        #expect(MPCChapterOneLoadout().skillLevel(for: .sidestepStrike) == 1)
        #expect(MPCSkillGrowth.clampedLevel(-5) == 1)
        #expect(MPCSkillGrowth.clampedLevel(99) == 5)
        #expect((1...4).map { MPCSkillGrowth.upgradeCost(from: $0) } == [30, 60, 90, 120])
        #expect(MPCSkillGrowth.upgradeCost(from: 5) == nil)
        #expect(MPCSkillGrowth.multiplierBasisPoints(for: 5) == 14_000)
        #expect(!MPCSkillGrowth.canUpgrade(.namelessStage))
        #expect(!MPCSkillGrowth.canUpgrade(.turnTheTables))
        #expect(!MPCSkillGrowth.canUpgrade(.backstageChange))
    }

    @Test(arguments: [FoolSkillID.sidestepStrike, .maskedWhisper, .identityDisplacement, .fabricatedEvidence, .mirrorPursuit, .absurdFinale])
    func allDirectDamageCardsScaleOnce(skill: FoolSkillID) throws {
        var base = try session()
        var raised = try session(level: 5)
        base.setContinuousSkillSequence([skill])
        raised.setContinuousSkillSequence([skill])
        let a = try base.useFoolSkill(skill, targetID: base.enemies[0].id)
        let b = try raised.useFoolSkill(skill, targetID: raised.enemies[0].id)
        #expect(b.damage == a.damage * 140 / 100)
        #expect(base.foolStates == raised.foolStates)
        #expect(base.remainingCooldownActions(for: skill) == raised.remainingCooldownActions(for: skill))
        #expect(base.masqueradeCharges == raised.masqueradeCharges)
    }

    @Test func bothTargetsScaleExactlyOnceWithTalentAndRelic() throws {
        let talents = HermitTalentAllocation.restored(["trickery.0"], budget: 1)
        var base = try session(encounter: "chapter01_q02_encounter", talents: talents, relics: ["relic_cracked_monocle"])
        var raised = try session(level: 5, encounter: "chapter01_q02_encounter", talents: talents, relics: ["relic_cracked_monocle"])
        let a = try base.useFoolSkill(.sidestepStrike, targetID: base.enemies[0].id)
        let b = try raised.useFoolSkill(.sidestepStrike, targetID: raised.enemies[0].id)
        #expect(a.targets.count == 2)
        #expect(b.targets.map(\.damage) == a.targets.map { $0.damage * 140 / 100 })
    }

    @Test func shieldFromSkillScalesButPhantomCountDoesNot() throws {
        let talents = HermitTalentAllocation.restored(["phantom.0"], budget: 1)
        var raised = try session(level: 5, talents: talents)
        _ = try raised.useFoolSkill(.maskedWhisper, targetID: raised.enemies[0].id)
        #expect(raised.playerShield == 42)
        #expect(raised.masqueradeCharges == 2)
    }

    @Test func basicAttackAndConsumableShieldStayUnchanged() throws {
        var base = try session()
        var raised = try session(level: 5)
        let a = try base.useBasicAction(.damage, targetID: base.enemies[0].id)
        let b = try raised.useBasicAction(.damage, targetID: raised.enemies[0].id)
        #expect(a == b)
        try base.useConsumable("consumable_mirror_salve")
        try raised.useConsumable("consumable_mirror_salve")
        #expect(base.playerShield == 100)
        #expect(raised.playerShield == 100)
    }

    @Test func utilityCardsDoNotGainDamageShieldOrLayers() throws {
        for skill in [FoolSkillID.turnTheTables, .backstageChange, .namelessStage] {
            var base = try session()
            var raised = try session(level: 5)
            if skill != .namelessStage {
                base.setContinuousSkillSequence([skill])
                raised.setContinuousSkillSequence([skill])
            }
            let a = try base.useFoolSkill(skill, targetID: base.enemies[0].id)
            let b = try raised.useFoolSkill(skill, targetID: raised.enemies[0].id)
            #expect(a.damage == 0 && b.damage == 0)
            #expect(base.playerShield == raised.playerShield)
            #expect(base.foolStates == raised.foolStates)
        }
    }

    @Test func freshEncounterRetainsLevelsWithoutTemporaryEffects() throws {
        var raised = try session(level: 3, talents: .restored(["phantom.0"], budget: 1))
        _ = try raised.useFoolSkill(.maskedWhisper, targetID: raised.enemies[0].id)
        let fresh = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q15_encounter", companionIDs: [], loadout: raised.loadout)
        #expect(fresh.loadout.skillLevel(for: .maskedWhisper) == 3)
        #expect(fresh.playerShield == 0)
        #expect(fresh.masqueradeCharges == 0)
    }

    @Test(.enabled(if: MPCChapterOneCatalog.relicsEnabled)) func bellPoisonBurstAndRelicShieldIgnoreSkillLevels() throws {
        var raised = try session(level: 5, encounter: "chapter01_q05_encounter", relics: ["relic_encore_bell"])
        let marked = raised.markEncoreDebt(enemyID: raised.enemies[0].id)
        #expect(marked)
        try raised.endRound(at: 1)
        try raised.endRound(at: 2)
        #expect(raised.emeraldPoisonDamagePerTick == 99)
        let poisonDamage = raised.advanceEmeraldPoison(at: 11)
        #expect(poisonDamage == 297)
        try raised.endRound(at: 12)
        let hp = raised.playerHP
        try raised.endRound(at: 13)
        #expect(hp - raised.playerHP == 198)

        var ring = try session(level: 5, relics: ["relic_unified_gear"])
        _ = try ring.useBasicAction(.setup)
        _ = try ring.useBasicAction(.control)
        _ = try ring.useBasicAction(.utility)
        #expect(ring.playerShield == 100)
        #expect(ring.ringExposurePending)
    }
}
