import Testing
@testable import MistportCombatCore

@Suite("Q4 two flame contract")
struct Q4TwoFlameTests {
    private var tutorialLoadout: MPCChapterOneLoadout {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.grantHoundTutorialCard()
        var loadout = campaign.loadout(forMissionID: "chapter01_q04")
        loadout.normalSkillIDs = [.maskedWhisper, .sidestepStrike]
        return loadout
    }

    @Test("Only two actual mask interceptions grant a timed 50 percent opening", arguments: [0, 1, 2])
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
        #expect(damage == (remaining == 2 ? 30 : 20))
        s.advanceQ4Clock(at: 12.10)
        #expect(!s.isQ4OpeningActive)
        #expect(try s.applyPartyDamage(20, to: id) == 20)
    }
    @Test("Cleanup removes the opening, and Q3 keeps its old attack")
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
        #expect(before - q3.playerHP - q3.playerShield == MPCProgressionWalls.q3BreathDamage)
    }
    @Test("Three accurate manual masks win during the third opening", arguments: [6.2, 7.2, 8.4], [0.05, 1.0 / 30.0])
    func threeRounds(maskOffset: Double, tickDuration: Double) throws {
        let result = try simulate(maskOffset: maskOffset, tickDuration: tickDuration)
        #expect(result.outcome == .victory)
        #expect(result.heavyContacts == 6)
        #expect(result.elapsed >= 49.1 && result.elapsed < 56.1)
    }

    @Test("Early, late or omitted mask in any round loses", arguments: [0, 1, 2], [0.0, 8.6, 1000.0])
    func missedRound(round: Int, badOffset: Double) throws {
        let result = try simulate(maskOffset: 6.2, badRound: round, badOffset: badOffset)
        #expect(result.outcome == .defeat)
        #expect(result.heavyContacts == round * 2 + 1)
        #expect(result.elapsed < Double(round) * 20 + 9.2)
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

    private func simulate(maskOffset: Double, badRound: Int? = nil, badOffset: Double = 0, tickDuration: Double = 0.05) throws
        -> (outcome: MPCEncounterOutcome, heavyContacts: Int, elapsed: Double) {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.grantHoundTutorialCard()
        var loadout = campaign.loadout(forMissionID: "chapter01_q04")
        loadout.normalSkillIDs = [.sidestepStrike]
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q04_encounter", party: campaign.party, companionIDs: [], loadout: loadout)
        let id = s.enemies[0].id
        #expect(s.enemies[0].maxHP == 2200)
        var scheduler = ContinuousSkillScheduler()
        var ready = 0.0, basicReady = 0.0
        var pending: (FoolSkillID?, Double)?
        var cycle = 0.0, heavyContacts = 0, elapsed = 0.0
        var usedRounds: Set<Int> = []
        for tick in 0..<1600 {
            let now = Double(tick) * tickDuration
            elapsed = now
            s.advanceQ4Clock(at: now)
            if s.outcome != .inProgress { break }
            let round = Int(cycle / 20)
            let offset = badRound == round ? badOffset : maskOffset
            if !usedRounds.contains(round), now >= cycle + offset {
                let result = try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: now)
                #expect((result != nil) == !(badRound == round && badOffset == 0 && round > 0))
                #expect(s.loadout.normalSkillIDs == [.sidestepStrike])
                usedRounds.insert(round)
            }
            if let impact = pending, now >= impact.1 {
                pending = nil
                if let skill = impact.0 { _ = try s.useFoolSkill(skill, targetID: id, usesRealtimeCooldown: true) }
                else { _ = try s.useBasicAction(.damage, targetID: id) }
            }
            if s.outcome != .inProgress { break }
            let intent = s.enemies[0].currentIntent
            let deadline = cycle + (intent == "q4_probe" ? 2.45 : intent == "charge" ? 8 : intent == "q4_flame_first" ? 8.45 : 9.10)
            if now >= deadline {
                try s.endRound(actingEnemyID: id, at: now)
                if intent.hasPrefix("q4_flame") { heavyContacts += 1 }
                if intent == "q4_flame_second" { cycle += 20 }
            }
            if s.outcome != .inProgress { break }
            if now >= ready && pending == nil {
                if let skill = scheduler.next(in: [.sidestepStrike], at: now) {
                    scheduler.didCast(skill, at: now); ready = now + 1.75; pending = (skill, now + 0.6192)
                } else if now >= basicReady {
                    basicReady = now + 2.4; ready = now + 1.65; pending = (nil, now + 0.58)
                }
            }
        }
        print("Q4 offset=\(maskOffset) badRound=\(String(describing: badRound)) badOffset=\(badOffset) duration=\(elapsed) hp=\(s.playerHP) contacts=\(heavyContacts)")
        return (s.outcome, heavyContacts, elapsed)
    }
}
