import Testing
@testable import MistportCombatCore

/// 后手改写 works without any relic (user decision 2026-09-30): it strikes out one
/// enemy-applied damage over time and writes one extra misread into the next setup card.
@Suite("后手改写: cleanse and enhanced setup")
struct BackstageChangeTests {
    @Test func enhancesTheNextSetupWithoutARelic() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            loadout: MPCChapterOneLoadout(normalSkillIDs: [.backstageChange, .maskedWhisper], passiveIDs: [], relicIDs: [])
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.backstageChange, targetID: nil)
        #expect(session.playerHP == session.playerMaxHP, "no cost without the vial")
        #expect(session.triggeredEffects.contains { $0.contains("无可净化") }, "the setup bonus applies with nothing to cleanse")
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        #expect(session.foolState(for: target.id)?.illusionStacks == 3)
        #expect(session.triggeredEffects.contains { $0.contains("强化铺垫：额外施加1层误认") })
    }

    @Test func thinsTheEmeraldFogButDoesNotEndIt() throws {
        var battle = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q05_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.backstageChange, .maskedWhisper], passiveIDs: [], relicIDs: []))
        try battle.endRound(at: 10)
        _ = battle.advanceEmeraldPoison(at: 22)
        #expect(battle.emeraldPoisonIntensity == 5 && battle.emeraldPoisonDamagePerTick == 40)
        _ = try battle.useFoolSkill(.backstageChange, targetID: nil)
        #expect(battle.isEmeraldPoisonActive)
        #expect(battle.emeraldPoisonIntensity == 1 && battle.emeraldPoisonDamagePerTick == 20)
        #expect(battle.triggeredEffects.contains { $0.contains("划去毒雾浓度") })
    }
}
