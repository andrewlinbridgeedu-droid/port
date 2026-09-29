import Testing
@testable import MistportCombatCore

struct MasqueradeTests {
    @Test func twoHitsAreSharedAcrossEnemiesAndThirdDealsDamage() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q02_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.maskedWhisper], passiveIDs: [], relicIDs: []))
        let ids = session.enemies.filter(\.isAlive).map(\.id)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: ids[0], usesRealtimeCooldown: true)
        let hp = session.playerHP
        for (index, id) in ids.enumerated() {
            try session.endRound(actingEnemyID: id)
            #expect(session.playerHP == hp)
            #expect(session.masqueradeCharges == 1 - index)
            #expect(session.lastEnemyActionResolutions.first?.playerDamage == 0)
        }
        try session.endRound(actingEnemyID: ids[0])
        #expect(session.playerHP < hp)
        #expect(session.masqueradeCharges == 0)
    }
    @Test func tutorialGivesManualRelicBeforeCombatAndPreservesExistingOrder() throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.loadout.normalSkillIDs = [.sidestepStrike]
        campaign.grantHoundTutorialCard()
        #expect(campaign.ownsManualMask)
        #expect(!campaign.unlockedSkillIDs.contains(.maskedWhisper))
        #expect(campaign.loadout.normalSkillIDs == [.sidestepStrike])
        #expect(campaign.loadoutSlotCapacity >= 2)
        campaign.loadout.normalSkillIDs = [.sidestepStrike, .maskedWhisper]
        campaign.grantHoundTutorialCard()
        #expect(campaign.loadout.normalSkillIDs == [.sidestepStrike])
        var session = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q03_encounter", companionIDs: [], loadout: campaign.effectiveLoadout)
        let id = session.enemies[0].id
        let activation = try session.useOwnedManualMasquerade(targetID: id, isOwned: campaign.ownsManualMask, at: 0)
        #expect(activation != nil)
        #expect(session.loadout.normalSkillIDs == [.sidestepStrike])
        let hp = session.playerHP
        try session.endRound(actingEnemyID: id)
        try session.endRound(actingEnemyID: id)
        #expect(session.playerHP == hp)
        try session.endRound(actingEnemyID: id)
        #expect(session.playerHP == hp - MPCProgressionWalls.q3BreathDamage)
    }
    @Test func recastingRefreshesInsteadOfStacking() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q02_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.maskedWhisper], passiveIDs: [], relicIDs: []))
        let id = session.enemies[0].id
        _ = try session.useFoolSkill(.maskedWhisper, targetID: id, usesRealtimeCooldown: true)
        try session.endRound(actingEnemyID: id)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: id, usesRealtimeCooldown: true)
        #expect(session.masqueradeCharges == 2)
        var scheduler = ContinuousSkillScheduler()
        scheduler.didCast(.maskedWhisper, at: 10)
        #expect(scheduler.next(in: [.maskedWhisper], at: 21.99) == nil)
        #expect(scheduler.next(in: [.maskedWhisper], at: 22) == .maskedWhisper)
    }
}
