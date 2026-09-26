import Testing
@testable import MistportCombatCore

@Suite("Manual mask relic migration")
struct MaskRelicMigrationTests {
    @Test func legacyMigrationIsIdempotentAndPreservesProgress() {
        var state = MPCChapterOneCampaignState.chapterStartState
        state.unlockedSkillIDs.insert(.maskedWhisper)
        state.skillUnlockStates[.maskedWhisper] = .permanent
        state.loadout.normalSkillIDs = [.sidestepStrike, .maskedWhisper]
        state.loadout.skillLevels[.maskedWhisper] = 3
        state.completedMissionIDs = ["chapter01_q03"]
        state.inventory["currency_copper"] = 222
        let firstMigration = state.migrateLegacyMaskCardToRelic()
        #expect(firstMigration)
        let repeatMigration = state.migrateLegacyMaskCardToRelic()
        #expect(!repeatMigration)
        #expect(state.ownsManualMask)
        #expect(!state.unlockedSkillIDs.contains(.maskedWhisper))
        #expect(state.skillUnlockStates[.maskedWhisper] == nil)
        #expect(state.loadout.normalSkillIDs == [.sidestepStrike])
        #expect(state.loadout.skillLevels[.maskedWhisper] == 3)
        #expect(state.inventory["currency_copper"] == 222)
        #expect(state.completedMissionIDs == ["chapter01_q03"])
    }
    @Test func freshHandoffGrantsRelicWithoutSelectingCardOrOtherRelics() {
        var state = MPCChapterOneCampaignState.chapterStartState
        let repeatMigration = state.migrateLegacyMaskCardToRelic()
        #expect(!repeatMigration)
        #expect(!state.ownsManualMask)
        state.grantHoundTutorialCard()
        state.grantHoundTutorialCard()
        #expect(state.ownedRelicIDs == [MPCChapterOneCatalog.ownerlessMaskRelicID])
        #expect(state.loadout.normalSkillIDs.isEmpty)
        #expect(state.effectiveLoadout.relicIDs == [MPCChapterOneCatalog.ownerlessMaskRelicID])
        #expect(!state.unlockedSkillIDs.contains(.maskedWhisper))
    }
    @Test func pausedRelicsStayHiddenAndInactive() {
        var state = MPCChapterOneCampaignState.chapterStartState
        state.ownedRelicIDs = ["relic_encore_bell", MPCChapterOneCatalog.ownerlessMaskRelicID]
        state.loadout.relicIDs = ["relic_encore_bell"]
        #expect(!MPCChapterOneCatalog.relicsEnabled)
        #expect(!MPCChapterOneCatalog.isRelicEnabled("relic_encore_bell"))
        #expect(state.effectiveLoadout.relicIDs == [MPCChapterOneCatalog.ownerlessMaskRelicID])
        #expect(!MPCChapterOneCatalog.visibleSkills.contains { $0.id == .maskedWhisper })
        #expect(MPCChapterOneCatalog.mission(forOldClockMissionNumber: 3)?.permanentSkillIDs.isEmpty == true)
    }
}
