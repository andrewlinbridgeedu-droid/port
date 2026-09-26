import Testing
@testable import MistportCombatCore

@Suite("Q1–Q30 reward and save boundaries")
struct Levels20RewardsRegressionTests {
    /// Isolates settlement with public player attacks and no enemy clock.
    /// Combat difficulty is covered by the independent real-time simulations;
    /// this fixture must not depend on Q4 percentage damage or mask timing.
    private func win(_ encounterID: String) throws -> MPCChapterOneEncounterSession {
        let party = MPCPartyPersistentState(
            playerHP: 100_000,
            playerMaxHP: 100_000,
            sharedReviveCharges: 3
        )
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: encounterID,
            party: party,
            companionIDs: [],
            loadout: MPCChapterOneLoadout(
                normalSkillIDs: FoolSkillID.allCases.filter { $0 != .paperDouble && $0 != .namelessStage },
                isUltimateUnlocked: true,
                passiveIDs: [],
                relicIDs: []
            )
        )

        // Advance real objective/immune phases, not a fabricated victory flag.
        for step in 0..<200 where session.outcome == .inProgress {
            for enemy in session.enemies.filter(\.isAlive) {
                _ = try session.applyPartyDamage(99_999, to: enemy.id)
                if session.outcome == .inProgress, session.enemies.contains(where: { $0.id == enemy.id && $0.isAlive }) {
                    session.commitEnemyImpact(from: enemy.id)
                    try session.endRound(actingEnemyID: enemy.id, at: Double(step))
                }
            }
        }
        return session
    }

    @Test("A real Q1 victory settles its reward once across repeated save callbacks")
    func q1RewardIsIdempotent() throws {
        let session = try win("chapter01_q01_encounter")
        try #require(session.outcome == .victory)

        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.completeEncounter(session)
        let inventoryAfterFirst = campaign.inventory
        let skillsAfterFirst = campaign.unlockedSkillIDs
        let encountersAfterFirst = campaign.completedEncounterIDs
        let missionsAfterFirst = campaign.completedMissionIDs

        campaign.completeEncounter(session)
        #expect(campaign.inventory == inventoryAfterFirst)
        #expect(campaign.unlockedSkillIDs == skillsAfterFirst)
        #expect(campaign.completedEncounterIDs == encountersAfterFirst)
        #expect(campaign.completedMissionIDs == missionsAfterFirst)
        #expect(campaign.inventory["item_old_clock_pass"] == 1)
        #expect(campaign.inventory["consumable_pain_salve"] == 1)

        let replay = try win("chapter01_q01_encounter")
        #expect(replay.outcome == .victory)
        #expect(replay.settlementID != session.settlementID)
        campaign.completeEncounter(replay)
        #expect(campaign.inventory["consumable_pain_salve"] == 1)
        #expect(campaign.inventory["item_old_clock_pass"] == 1)
        campaign.completeEncounter(replay)
        #expect(campaign.inventory["consumable_pain_salve"] == 1)
    }

    @Test("Real Q11–Q13 victories unlock exactly their authored skills")
    func q11ThroughQ13Unlocks() throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        for (number, skill) in [(11, FoolSkillID.absurdFinale), (12, FoolSkillID.turnTheTables), (13, FoolSkillID.namelessStage)] {
            let mission = try #require(MPCChapterOneCatalog.mission(forOldClockMissionNumber: number))
            let encounter = try #require(MPCChapterOneCatalog.encounters.first { encounter in
                encounter.id == mission.encounterID
            })
            let session = try win(encounter.id)
            try #require(session.outcome == .victory)
            campaign.claimVictory(for: encounter)
            #expect(campaign.unlockedSkillIDs.contains(skill))
            #expect(campaign.completedMissionIDs.contains("chapter01_q\(String(format: "%02d", number))"))
        }
        #expect(campaign.loadout.isUltimateUnlocked)
    }

    @Test("Sequential Q1–Q30 settlements preserve the authored card and slot milestones")
    func sequentialProgression() throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        let milestones: [Int: FoolSkillID] = [
            1: .sidestepStrike, 8: .identityDisplacement,
            9: .fabricatedEvidence, 10: .mirrorPursuit, 11: .absurdFinale,
            12: .turnTheTables, 13: .namelessStage,
        ]
        var expectedSkills = Set<FoolSkillID>()
        for number in 1...30 {
            let mission = try #require(MPCChapterOneCatalog.mission(forOldClockMissionNumber: number))
            let session = try win(mission.encounterID)
            try #require(session.outcome == .victory)
            campaign.completeEncounter(session)
            if let skill = milestones[number] { expectedSkills.insert(skill) }
            #expect(campaign.unlockedSkillIDs == expectedSkills)
            #expect(campaign.ownsManualMask == (number >= 3))
            #expect(!campaign.unlockedSkillIDs.contains(.maskedWhisper))
            #expect(campaign.loadoutSlotCapacity == (number < 3 ? 1 : number < 10 ? 2 : 4))
            #expect(campaign.loadout.isUltimateUnlocked == (number >= 13))
            #expect(campaign.completedMissionIDs.count == number)
            let inventory = campaign.inventory
            campaign.completeEncounter(session)
            #expect(campaign.inventory == inventory)
            #expect(campaign.completedMissionIDs.count == number)
        }
    }

    @Test("A real Q20 rescue records completion and transport evidence")
    func q20Completion() throws {
        let encounter = try #require(MPCChapterOneCatalog.encounters.first { $0.id == "chapter01_q20_encounter" })
        let session = try win(encounter.id)
        try #require(session.outcome == .victory)

        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.completeEncounter(session)
        #expect(campaign.completedEncounterIDs.contains(encounter.id))
        #expect(campaign.completedMissionIDs.contains("chapter01_q20"))
        #expect(campaign.inventory["chapter30_e28"] == 1)
        #expect(campaign.inventory["key_authority_echo"] == nil)
    }
}
