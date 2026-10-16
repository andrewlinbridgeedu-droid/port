import Testing
@testable import MistportCombatCore

@Suite("Chapter one earned-loadout combat audit")
struct ChapterOneNaturalCombatTests {
    @Test("Later hound breath uses authored multiplier, not tutorial damage")
    func laterHoundDamage() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q16_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        )
        let hound = try #require(session.enemies.first { $0.contentID == "enemy_clockwork_hound" })
        let hp = session.playerHP
        try session.endRound(actingEnemyID: hound.id)
        #expect(hp - session.playerHP == hound.attack * 1_500 / 1_000)
    }

    /// The App's loop (MPCStoryBattleStepper, 2026-10-15): the hound keeps its own clock while the ordered
    /// cards run theirs; a legal Q16 arrangement with the stage loadout wins.
    @Test("Q16 independent actor timing with earned cards")
    func q16IndependentTiming() async throws {
        let win = try await RealLoop.firstWin(RealLoop.orders(before: 16)) { try MPCStoryVerificationRunner.audit(mission: 16, order: $0).won }
        let order = try #require(win)
        let r = try MPCStoryVerificationRunner.audit(mission: 16, order: order)
        print("Q16_TIMING: \(RealLoop.name(order)) seconds=\(r.seconds), hp=\(r.session.playerHP)")
        #expect(r.won)
    }

    @Test("Earned card selection and manual mask stay separate in Q6–Q20", arguments: Array(6...20))
    func earnedLoadoutCombat(_ number: Int) throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        for mission in MPCChapterOneCatalog.missions where mission.number < number {
            let encounter = try #require(MPCChapterOneCatalog.encounters.first { $0.id == mission.encounterID })
            campaign.claimVictory(for: encounter)
        }
        // Prior wins are reward fixtures. Real-time victory is tested separately;
        // a one-player-action / all-enemy-actions round cannot model this game.
        let mission = try #require(MPCChapterOneCatalog.mission(forOldClockMissionNumber: number))
        if number == 8 { _ = campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 8) }
        let candidates: [FoolSkillID] = [.fabricatedEvidence, .sidestepStrike, .mirrorPursuit, .absurdFinale]
        let selected = Array(candidates.filter { campaign.unlockedSkillIDs.contains($0) }.prefix(campaign.loadoutSlotCapacity))
        #expect(!selected.isEmpty)
        #expect(selected.count <= campaign.loadoutSlotCapacity)
        #expect(!selected.contains(.maskedWhisper))
        #expect(campaign.ownsManualMask)
        campaign.loadout.normalSkillIDs = selected
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: mission.encounterID, companionIDs: [], loadout: campaign.effectiveLoadout)
        #expect(session.loadout.normalSkillIDs == selected)
        let target = try #require(session.enemies.first(where: { $0.isAlive }))
        let activation = try session.useOwnedManualMasquerade(targetID: target.id, isOwned: campaign.ownsManualMask, at: 0)
        #expect(activation != nil)
        #expect(session.loadout.normalSkillIDs == selected)
        #expect(session.masqueradeCharges == 2)
        if number == 6 {
            // Damage-source checks occur after the fully immune guard phase.
            try session.endRound(actingEnemyID: target.id)
            #expect(session.enemies[0].currentIntent == "archive_slam")
        }
        if number == 20 {
            while session.enemies[0].currentIntent != "recover" { try session.endRound(actingEnemyID: target.id) }
            let hp = session.enemies[0].hp
            _ = try session.useBasicAction(.damage, targetID: target.id)
            #expect(session.chapterObjectiveProgress > 0)
            #expect(session.enemies[0].hp == hp) // Break transport, never injure its body.
        } else {
            let hp = session.enemies.reduce(0) { $0 + $1.hp }
            _ = try session.useBasicAction(.damage, targetID: target.id)
            #expect(session.enemies.reduce(0) { $0 + $1.hp } < hp)
            #expect(session.damageBySource["basic", default: 0] > 0)
        }
    }
}
