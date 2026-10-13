import Testing
@testable import MistportCombatCore

@Suite("Q4 two flame contract")
struct Q4TwoFlameTests {
    private var tutorialLoadout: MPCChapterOneLoadout {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.grantHoundTutorialCard()
        var loadout = campaign.loadout(forMissionID: "chapter01_q04")
        loadout.normalSkillIDs = [.maskedWhisper, .fabricatedEvidence, .sidestepStrike]
        return loadout
    }

    @Test("Only two actual mask interceptions earn one manual counter", arguments: [0, 1, 2])
    func actualInterceptions(remaining: Int) throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q04_encounter", companionIDs: [], loadout: tutorialLoadout)
        let id = s.enemies[0].id
        #expect(s.enemies[0].intentPattern == ["q4_probe", "charge", "q4_flame_first", "q4_flame_second"])
        if remaining == 1 { _ = try s.useFoolSkill(.maskedWhisper, targetID: id) }
        let hp = s.playerHP + s.playerShield
        try s.endRound(actingEnemyID: id, at: 2.45)
        #expect(hp - s.playerHP - s.playerShield == (remaining == 1 ? 0 : 80))
        try s.endRound(actingEnemyID: id, at: 8)
        if remaining == 2 { _ = try s.useFoolSkill(.maskedWhisper, targetID: id) }
        let before = s.playerHP + s.playerShield
        try s.endRound(actingEnemyID: id, at: 8.45)
        #expect(!s.isQ4OpeningActive)
        if s.outcome == .inProgress { try s.endRound(actingEnemyID: id, at: 9.10) }
        #expect(before - s.playerHP - s.playerShield == min(before, (2 - remaining) * ((s.playerMaxHP * 110 + 99) / 100)))
        if remaining < 2 {
            #expect(s.outcome == .defeat)
            #expect(!s.isQ4OpeningActive)
            return
        }
        #expect(s.isQ4OpeningActive == (remaining == 2))
        let damage = try s.applyPartyDamage(20, to: id)
        #expect(damage == 5) // No automatic bonus: the player must tap.
        #expect(s.canRequestCounter)
        let counterCheck1 = s.requestCounter(at: 9.2)
        #expect(counterCheck1)
        let counterCheck2 = !s.requestCounter(at: 9.2)
        #expect(counterCheck2)
        let counterCheck3 = s.activateCounter(at: 9.3)
        #expect(counterCheck3)
        #expect(try s.applyPartyDamage(20, to: id) == 50)
        s.advanceQ4Clock(at: 12.30)
        #expect(!s.isQ4OpeningActive && !s.isCounterActive)
        #expect(try s.applyPartyDamage(20, to: id) == 5)
    }
    @Test("Cleanup removes the Q4 opening; Q3 also requires its manual mask")
    func cleanupAndQ3() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q04_encounter", companionIDs: [], loadout: tutorialLoadout)
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 2)
        try s.endRound(actingEnemyID: id, at: 8)
        _ = try s.useFoolSkill(.maskedWhisper, targetID: id)
        try s.endRound(actingEnemyID: id, at: 8.45)
        try s.endRound(actingEnemyID: id, at: 9.10)
        #expect(s.isQ4OpeningActive)
        s.clearQ4HoundState()
        #expect(!s.isQ4OpeningActive)
        var q3 = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q03_encounter", companionIDs: [])
        #expect(!q3.enemies[0].intentPattern.contains("q4_probe"))
        let before = q3.playerHP + q3.playerShield
        try q3.endRound(actingEnemyID: q3.enemies[0].id, at: 2)
        #expect(before - q3.playerHP - q3.playerShield == min(before, (q3.playerBaseMaxHP * MPCProgressionWalls.q3BreathHealthPercent + 99) / 100))
        try q3.endRound(actingEnemyID: q3.enemies[0].id, at: 3.4)
        #expect(q3.outcome == .defeat)
    }
    @Test("Actual two-card battle needs manual counter and rewards set-up first")
    func twoCardCounter() throws {
        let correct = try play([.fabricatedEvidence, .sidestepStrike], masks: true, counters: true)
        let unattended = try play([.fabricatedEvidence, .sidestepStrike], masks: true, counters: false)
        let reverse = try play([.sidestepStrike, .fabricatedEvidence], masks: true, counters: true)
        let noMask = try play([.fabricatedEvidence, .sidestepStrike], masks: false, counters: true)
        #expect(correct.session.outcome == .victory)
        #expect(unattended.session.outcome == .defeat)
        #expect(noMask.session.outcome == .defeat)
        #expect(reverse.session.outcome == .defeat || correct.tick < reverse.tick)
        #expect(correct.inputs.contains { $0.kind == .counter })
        let result = try MPCChurchBattleDriver.replayStory(correct.log, loadout: correct.loadout,
            mask: .init(owned: true, teachingLoan: true))
        #expect(result.0.outcome == correct.session.outcome && result.0.ticks == correct.tick)
        #expect(result.0.playerHP == correct.session.playerHP)
        for (label, game) in [("counter", correct), ("maskOnly", unattended), ("reverse", reverse), ("noMask", noMask)] {
            print("Q4_COUNTER \(label) outcome=\(game.session.outcome) seconds=\(game.now) hp=\(game.session.playerHP)")
        }
    }

    @Test("A full heal plus 100 shield cannot absorb one missed large fireball")
    func medicineCannotReplaceMask() throws {
        let loadout = tutorialLoadout
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q04_encounter", consumables: ["consumable_pain_salve": 1, "consumable_mirror_salve": 1], companionIDs: [], loadout: loadout)
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 2.45)
        try s.useConsumable("consumable_pain_salve")
        try s.useConsumable("consumable_mirror_salve")
        #expect(s.playerHP == s.playerMaxHP)
        #expect(s.playerShield == 100)
        try s.endRound(actingEnemyID: id, at: 8)
        try s.endRound(actingEnemyID: id, at: 8.45)
        #expect(s.outcome == .defeat)
    }

    private func play(_ cards: [FoolSkillID], masks: Bool, counters: Bool) throws -> MPCStoryBattleStepper {
        var game = try MPCStoryBattleStepper(encounterID: "chapter01_q04_encounter",
            loadout: .init(normalSkillIDs: cards), mask: .init(owned: true, teachingLoan: true))
        while !game.isFinished {
            let view = game.view
            var inputs: [MPCBattleInput] = []
            if masks, game.maskIsReady(at: view.now), view.session.enemies.contains(where: { e in
                (e.currentIntent == "q4_flame_first" || e.currentIntent == "q4_flame_second")
                    && (view.incoming[e.id].map { $0 - view.tick <= 6 } ?? false)
            }) { inputs.append(.init(tick: view.tick, kind: .mask)) }
            if counters, view.session.canRequestCounter { inputs.append(.init(tick: view.tick, kind: .counter)) }
            _ = try game.step(inputs)
        }
        return game
    }
}
