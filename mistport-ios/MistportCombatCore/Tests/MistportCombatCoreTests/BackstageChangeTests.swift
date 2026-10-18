import Testing
@testable import MistportCombatCore

/// 重绘 works without any relic (user decision 2026-09-30): it strikes out one
/// enemy-applied damage over time. Since the ten-card redesign (2026-10-12) it also raises a
/// 240 ward for 4 s instead of seeding the next setup card (that belonged to the manual mode).
@Suite("重绘: cleanse and ward")
struct BackstageChangeTests {
    @Test func wardsWithoutARelicEvenWithNothingToCleanse() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            loadout: MPCChapterOneLoadout(normalSkillIDs: [.backstageChange], passiveIDs: [], relicIDs: [])
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.backstageChange, targetID: target.id)
        #expect(session.playerHP == session.playerMaxHP, "no cost without the vial")
        #expect(session.triggeredEffects.contains { $0.contains("无可净化") }, "the ward applies with nothing to cleanse")
        #expect(session.playerCombatStatuses(at: 0).contains { $0.id == "ordered-shield" && $0.count == 240 })
        #expect(!session.playerCombatStatuses(at: 4).contains { $0.id == "ordered-shield" })
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
