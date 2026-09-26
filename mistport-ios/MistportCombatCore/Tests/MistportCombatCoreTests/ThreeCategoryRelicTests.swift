import Testing
@testable import MistportCombatCore

@Suite(.enabled(if: MPCChapterOneCatalog.relicsEnabled))
struct ThreeCategoryRelicTests {
    @Test("Skill damage receives the same 20 percent bonus exactly once")
    func skillBoostOnce() throws {
        func makeSession(relics: [String]) throws -> MPCChapterOneEncounterSession {
            try .start(encounterID: "chapter01_q15_encounter", companionIDs: [],
                       loadout: .init(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false,
                                      passiveIDs: [], relicIDs: relics))
        }
        var boosted = try makeSession(relics: ["relic_unified_gear"])
        var baseline = try makeSession(relics: [])
        let target = boosted.enemies[0].id
        for category: MPCPlayerActionCategory in [.setup, .utility, .damage] {
            _ = try boosted.useBasicAction(category, targetID: target)
            _ = try baseline.useBasicAction(category, targetID: target)
        }
        let normal = try baseline.useFoolSkill(.sidestepStrike, targetID: target, usesRealtimeCooldown: true)
        let enhanced = try boosted.useFoolSkill(.sidestepStrike, targetID: target, usesRealtimeCooldown: true)
        #expect(enhanced.damage == normal.damage * 120 / 100)
        let secondNormal = try baseline.useFoolSkill(.sidestepStrike, targetID: target, usesRealtimeCooldown: true)
        let secondEnhanced = try boosted.useFoolSkill(.sidestepStrike, targetID: target, usesRealtimeCooldown: true)
        #expect(secondEnhanced.damage == secondNormal.damage)
    }

    @Test("The next basic attack gains 20 percent; a utility action does not consume it")
    func nextAttackBoost() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q15_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [],
                           relicIDs: ["relic_unified_gear"]))
        let target = session.enemies[0].id
        _ = try session.useBasicAction(.setup, targetID: target)
        _ = try session.useBasicAction(.utility, targetID: target)
        #expect(try session.useBasicAction(.damage, targetID: target) == 60)
        _ = try session.useBasicAction(.utility, targetID: target)
        #expect(try session.useBasicAction(.damage, targetID: target) == 72)
        #expect(try session.useBasicAction(.damage, targetID: target) == 60)
    }

    @Test("ABA does not count as three categories; a repeated category restarts the chain", arguments: [1_000, 2_000])
    func distinctCategories(_ maxHP: Int) throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q15_encounter",
            party: .init(playerMaxHP: maxHP), companionIDs: [],
            loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [],
                           relicIDs: ["relic_unified_gear"]))
        let target = session.enemies[0].id
        for category: MPCPlayerActionCategory in [.setup, .utility, .setup] {
            _ = try session.useBasicAction(category, targetID: target)
        }
        #expect(session.playerShield == 0)
        _ = try session.useBasicAction(.utility, targetID: target)
        #expect(session.playerShield == 0)
        _ = try session.useBasicAction(.damage, targetID: target)
        #expect(session.playerShield == maxHP / 10)
        _ = try session.useBasicAction(.utility, targetID: target)
        #expect(session.playerShield == maxHP / 10)
    }
}
