import Testing
@testable import MistportCombatCore

@Suite("Q3 paired breath and manual mask cadence")
struct Q3TwoBreathTests {
    private func freshSession() throws -> MPCChapterOneEncounterSession {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.grantHoundTutorialCard()
        var loadout = campaign.loadout(forMissionID: "chapter01_q03")
        loadout.normalSkillIDs = [.sidestepStrike]
        return try .start(encounterID: "chapter01_q03_encounter", party: campaign.party,
            consumables: ["consumable_pain_salve": 1, "consumable_mirror_salve": 1], companionIDs: [], loadout: loadout)
    }

    @Test func pairFitsOneMaskAndLeavesCooldownReactionRoom() {
        let first = MPCQ3HoundTiming.castTime(start: 0, attackIndex: 0) + 1.1
        let second = MPCQ3HoundTiming.castTime(start: 0, attackIndex: 1) + 1.1
        let next = MPCQ3HoundTiming.castTime(start: 0, attackIndex: MPCQ3HoundTiming.intents.count) + 1.1
        #expect(second - first < MPCChapterOneEncounterSession.ownedManualMaskDuration)
        #expect(next - first >= MPCChapterOneEncounterSession.ownedManualMaskCooldown + 1.9)
    }

    @Test func healingAndMaximumShieldCannotReplaceMask() throws {
        var s = try freshSession(); let id = s.enemies[0].id
        s.grantPlayerShield(s.playerMaxHP)
        try s.endRound(actingEnemyID: id, at: 3.1)
        if s.outcome == .inProgress {
            try s.useConsumable("consumable_pain_salve")
            try s.useConsumable("consumable_mirror_salve")
            try s.endRound(actingEnemyID: id, at: 4.5)
        }
        #expect(s.outcome == .defeat)
    }

    @Test func oneMaskAbsorbsBothAndIsReadyBeforeNextPair() throws {
        var s = try freshSession(); let id = s.enemies[0].id; let hp = s.playerHP
        for cycle in 0..<3 {
            let start = Double(cycle) * MPCQ3HoundTiming.cycle
            #expect(try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: start + 2.1) != nil)
            try s.endRound(actingEnemyID: id, at: start + 3.1)
            #expect(s.masqueradeCharges == 1)
            try s.endRound(actingEnemyID: id, at: start + 4.5)
            #expect(s.masqueradeCharges == 0 && s.playerHP == hp)
            // Advance the real bite beats to reach the next pair; shield the
            // fixture so this test isolates mask duration and cooldown.
            for slot in 2..<MPCQ3HoundTiming.intents.count {
                s.grantPlayerShield(s.playerMaxHP)
                try s.endRound(actingEnemyID: id,
                    at: MPCQ3HoundTiming.castTime(start: start, attackIndex: slot) + 1.1)
            }
        }
    }

    @Test func ordinaryBitesFillTheCooldownAndDamageTheHero() throws {
        var s = try freshSession(); let id = s.enemies[0].id
        #expect(s.enemies[0].intentPattern == MPCQ3HoundTiming.intents)
        #expect(try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: 2.1) != nil)
        try s.endRound(actingEnemyID: id, at: 3.1)
        try s.endRound(actingEnemyID: id, at: 4.5)
        let before = s.playerHP
        #expect(s.enemies[0].currentIntent == "bite")
        try s.endRound(actingEnemyID: id, at: 7.1)
        #expect(s.playerHP < before && s.lastEnemyActionResolutions.first?.intent == "bite")
        let times = (0...MPCQ3HoundTiming.intents.count).map { MPCQ3HoundTiming.castTime(start: 0, attackIndex: $0) }
        #expect(zip(times.dropFirst(), times).allSatisfy { $0 - $1 <= 4.000001 })
    }

    @Test("Actual two-card opening cannot outrun the paired breaths", arguments: [false, true])
    func freshAutomaticSequence(mask: Bool) throws {
        let loadout = MPCChapterOneLoadout(normalSkillIDs: [.fabricatedEvidence, .sidestepStrike])
        var game = try MPCStoryBattleStepper(encounterID: "chapter01_q03_encounter", loadout: loadout,
            mask: .init(owned: true, teachingLoan: true))
        while !game.isFinished {
            let view = game.view
            let imminentBreath = view.session.enemies.contains { enemy in
                guard enemy.currentIntent == "memory_breath", let deadline = view.incoming[enemy.id] else { return false }
                return deadline - view.tick <= 6
            }
            let inputs: [MPCBattleInput] = mask && imminentBreath && game.maskIsReady(at: view.now)
                ? [.init(tick: view.tick, kind: .mask)] : []
            _ = try game.step(inputs)
        }
        #expect(game.session.outcome == (mask ? .victory : .defeat))
        if !mask { #expect(game.now >= 4.5 && game.now < 4.7) }
        print("Q3_EARLY mask=\(mask) result=\(game.session.outcome) seconds=\(game.now) hp=\(game.session.playerHP)")
    }
}
