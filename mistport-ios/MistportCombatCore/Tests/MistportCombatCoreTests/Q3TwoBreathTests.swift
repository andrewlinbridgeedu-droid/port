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

    @Test("Fresh normal sequence cannot outrun the paired breaths", arguments: [false, true])
    func freshAutomaticSequence(mask: Bool) throws {
        var s = try freshSession(); let id = s.enemies[0].id
        var scheduler = ContinuousSkillScheduler()
        var playerReady = 0.0, basicReady = 0.0
        var playerHit: (FoolSkillID?, Double)?, enemyHit: Double?
        var maskedCycles = Set<Int>(), contacts = 0, elapsed = 0.0
        for tick in 0..<2400 where s.outcome == .inProgress {
            let now = Double(tick) * 0.05; elapsed = now
            _ = s.advanceEmeraldPoison(at: now)
            let cycle = Int(now / MPCQ3HoundTiming.cycle)
            if mask && now >= Double(cycle) * MPCQ3HoundTiming.cycle + 2.1 && !maskedCycles.contains(cycle) {
                #expect(try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: now) != nil)
                maskedCycles.insert(cycle)
            }
            if let due = enemyHit, now + 0.000001 >= due {
                enemyHit = nil; try s.endRound(actingEnemyID: id, at: now); contacts += 1
            }
            guard s.outcome == .inProgress else { break }
            if let (skill, due) = playerHit, now + 0.000001 >= due {
                playerHit = nil
                if let skill { _ = try s.useFoolSkill(skill, targetID: id, usesRealtimeCooldown: true) }
                else { _ = try s.useBasicAction(.damage, targetID: id) }
            }
            guard s.outcome == .inProgress else { break }
            if enemyHit == nil && now + 0.000001 >= MPCQ3HoundTiming.castTime(start: 0, attackIndex: s.enemies[0].intentIndex) {
                s.commitEnemyImpact(from: id)
                enemyHit = now + MPCBattleContactTiming.enemyContact(contentID: "enemy_clockwork_hound", intent: s.enemies[0].currentIntent, encounterID: s.encounter.id)
            }
            if playerHit == nil && now >= playerReady {
                if let skill = scheduler.next(in: [.sidestepStrike], at: now) {
                    scheduler.didCast(skill, at: now)
                    let duration = MPCBattleContactTiming.playerContact(skill)
                    playerHit = (skill, now + duration); playerReady = now + MPCCombatTempo.standard.skillRecovery
                } else if now >= basicReady {
                    let duration = MPCBattleContactTiming.playerContact(nil)
                    playerHit = (nil, now + duration); playerReady = now + MPCCombatTempo.standard.basicRecovery; basicReady = now + 2.4
                }
            }
        }
        #expect(contacts >= 2)
        #expect(s.outcome == (mask ? .victory : .defeat))
        if !mask { #expect(elapsed < 4.6) }
    }
}
