import Testing
@testable import MistportCombatCore

@Suite("Approved Q15 and Q20 relic contracts")
struct ApprovedRelicContractTests {
    private func session(_ relics: [String], encounter: String = "chapter01_q05_encounter") throws -> MPCChapterOneEncounterSession {
        try .start(encounterID: encounter, companionIDs: [], loadout: .init(
            normalSkillIDs: [.maskedWhisper, .identityDisplacement, .sidestepStrike],
            passiveIDs: [], relicIDs: relics))
    }
    private func triggerRing(_ s: inout MPCChapterOneEncounterSession) throws {
        _ = try s.useBasicAction(.setup)
        _ = try s.useBasicAction(.control)
        _ = try s.useBasicAction(.utility)
    }

    @Test(.enabled(if: MPCChapterOneCatalog.relicsEnabled)) func ringShieldAndHealthReceiveExactlyOneAmplifiedHit() throws {
        var s = try session(["relic_unified_gear"], encounter: "chapter01_q04_encounter")
        try triggerRing(&s)
        #expect(s.playerShield == 100)
        #expect(s.ringExposurePending)
        let damage = try s.useBasicAction(.damage, targetID: s.enemies[0].id)
        #expect(damage == 72)
        try s.endRound()
        #expect(s.ringExposurePending)
        try s.endRound()
        #expect(s.lastEnemyActionResolutions[0].playerDamage == 325)
        #expect(s.playerShield == 0)
        #expect(s.playerHP == 775)
        #expect(!s.ringExposurePending)
        try s.endRound()
        try s.endRound()
        #expect(s.lastEnemyActionResolutions[0].playerDamage == 260)
    }

    @Test(.enabled(if: MPCChapterOneCatalog.relicsEnabled)) func ringRefreshDoesNotMultiplyExposureAndMaskDoesNotConsumeIt() throws {
        var s = try session(["relic_unified_gear"])
        try triggerRing(&s)
        try triggerRing(&s)
        #expect(s.playerShield == 200)
        _ = try s.useFoolSkill(.maskedWhisper, targetID: s.enemies[0].id, usesRealtimeCooldown: true)
        for _ in 0..<4 { try s.endRound() }
        #expect(s.masqueradeCharges == 0)
        #expect(s.ringExposurePending)
        #expect(s.playerShield == 200)
        try s.endRound()
        try s.endRound()
        #expect(s.emeraldPoisonTicksRemaining == 3)
        #expect(s.ringExposurePending)
        #expect(s.lastEnemyActionResolutions[0].playerDamage == 0)
        try s.endRound()
        try s.endRound()
        #expect(s.lastEnemyActionResolutions[0].playerDamage == 247)
        #expect(s.playerShield == 0)
        #expect(s.playerHP == 953)
        #expect(!s.ringExposurePending)
        let retry = try session(["relic_unified_gear"])
        #expect(!retry.ringExposurePending)
        let next = try session(["relic_unified_gear"], encounter: "chapter01_q06_encounter")
        #expect(!next.ringExposurePending)
    }

    @Test(.enabled(if: MPCChapterOneCatalog.relicsEnabled)) func ringExposureSurvivesShieldDispel() throws {
        var s = try session(["relic_unified_gear"], encounter: "chapter01_q12_encounter")
        var normal = try session([], encounter: "chapter01_q12_encounter")
        let id = s.enemies[0].id
        try triggerRing(&s)
        try s.endRound(actingEnemyID: id)
        try normal.endRound(actingEnemyID: id)
        try s.endRound(actingEnemyID: id)
        try normal.endRound(actingEnemyID: id)
        #expect(s.playerShield == 0)
        #expect(s.ringExposurePending)
        try s.endRound(actingEnemyID: id)
        try normal.endRound(actingEnemyID: id)
        let base = normal.lastEnemyActionResolutions[0].playerDamage
        #expect(base > 0)
        #expect(s.lastEnemyActionResolutions[0].playerDamage == base * 125 / 100)
        #expect(!s.ringExposurePending)
    }

    @Test(.enabled(if: MPCChapterOneCatalog.relicsEnabled)) func sealReducesUltimateThenPreservesOneSuccessfulConversion() throws {
        var s = try session(["relic_nameless_seal"])
        let id = s.enemies[0].id
        _ = try s.useFoolSkill(.namelessStage, targetID: nil)
        #expect(s.foolState(for: id)?.illusionStacks == 2)
        #expect(s.foolState(for: id)?.finaleReady == true)
        #expect(s.foolUltimateUsed)
        #expect(s.sealConversionReady)
        for expected in [3, 4] {
            _ = try s.useFoolSkill(.identityDisplacement, targetID: id, usesRealtimeCooldown: true)
            #expect(s.foolState(for: id)?.illusionStacks == expected)
            #expect(s.sealConversionReady)
        }
        _ = try s.useFoolSkill(.identityDisplacement, targetID: id, usesRealtimeCooldown: true)
        #expect(s.foolState(for: id)?.illusionStacks == 4)
        #expect(s.foolState(for: id)?.misalignmentStacks == 2)
        #expect(!s.sealConversionReady)
        _ = try s.useFoolSkill(.identityDisplacement, targetID: id, usesRealtimeCooldown: true)
        #expect(s.foolState(for: id)?.illusionStacks == 0)
        #expect(!s.sealConversionReady)
        let retry = try session(["relic_nameless_seal"])
        #expect(!retry.sealConversionReady)
        let next = try session(["relic_nameless_seal"], encounter: "chapter01_q06_encounter")
        #expect(!next.sealConversionReady)
    }

    @Test func unequippedSealLeavesUltimateAndConversionUnchanged() throws {
        var s = try session([])
        let id = s.enemies[0].id
        _ = try s.useFoolSkill(.namelessStage, targetID: nil)
        #expect(s.foolState(for: id)?.illusionStacks == 4)
        #expect(!s.sealConversionReady)
        _ = try s.useFoolSkill(.identityDisplacement, targetID: id, usesRealtimeCooldown: true)
        #expect(s.foolState(for: id)?.illusionStacks == 0)
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.ownedRelicIDs = ["relic_unified_gear", "relic_nameless_seal"]
        #expect(campaign.effectiveLoadout.relicIDs.isEmpty)
    }
}
