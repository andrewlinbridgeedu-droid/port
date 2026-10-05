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

    @Test("Q16 independent actor timing with earned cards")
    func q16IndependentTiming() throws {
        let cards: [FoolSkillID] = [.fabricatedEvidence, .sidestepStrike, .mirrorPursuit, .absurdFinale]
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q16_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: cards, isUltimateUnlocked: false, passiveIDs: [], relicIDs: [MPCChapterOneCatalog.ownerlessMaskRelicID])
        )
        var scheduler = ContinuousSkillScheduler()
        var playerReady = 0.0
        var basicReady = 0.0
        var impact: (skill: FoolSkillID?, target: String, time: Double)?
        var enemyReady: [String: Double] = [:]
        var enemyImpact: [String: Double] = [:]
        var elapsed = 0.0
        // Native fallback timings from ChapterOneTestView. This verifies core
        // scheduling, not Unity animation contact delivery or visual accuracy.
        for tick in 0..<2400 where session.outcome == .inProgress {
            let now = Double(tick) * 0.05
            elapsed = now
            if now >= session.ownedManualMaskReadyAt {
                _ = try session.useOwnedManualMasquerade(targetID: session.enemies.first(where: { $0.isAlive })?.id, isOwned: true, at: now)
            }
            if let hit = impact, now >= hit.time {
                impact = nil
                if session.enemies.contains(where: { $0.id == hit.target && $0.isAlive }) {
                    if let skill = hit.skill {
                        _ = try session.useFoolSkill(skill, targetID: hit.target, usesRealtimeCooldown: true)
                    } else { _ = try session.useBasicAction(.damage, targetID: hit.target) }
                }
            }
            if session.outcome != .inProgress { break }
            for enemy in session.enemies where enemy.isAlive {
                if let deadline = enemyImpact[enemy.id], now >= deadline {
                    enemyImpact.removeValue(forKey: enemy.id)
                    try session.endRound(actingEnemyID: enemy.id)
                    if session.outcome != .inProgress { break }
                }
            }
            if session.outcome != .inProgress { break }
            for (index, enemy) in session.enemies.enumerated() where enemy.isAlive {
                let hound = enemy.contentID == "enemy_clockwork_hound"
                if enemyReady[enemy.id] == nil { enemyReady[enemy.id] = hound ? now : now + 2.4 + Double(index) * 0.35 }
                if now >= enemyReady[enemy.id, default: .infinity], enemyImpact[enemy.id] == nil {
                    enemyReady[enemy.id] = now + (hound ? 3 : 3.2)
                    enemyImpact[enemy.id] = now + (hound ? 1.1 : 0.65)
                }
            }
            if now >= playerReady, impact == nil, let target = session.enemies.first(where: { $0.isAlive }) {
                if let skill = scheduler.next(in: cards, at: now) {
                    scheduler.didCast(skill, at: now)
                    playerReady = now + 1.75
                    impact = (skill, target.id, now + 0.78)
                } else if now >= basicReady {
                    basicReady = now + 2.4
                    playerReady = now + 1.65
                    impact = (nil, target.id, now + 0.58)
                }
            }
        }
        print("Q16_TIMING: \(session.outcome), seconds=\(elapsed), hp=\(session.playerHP)")
        #expect(session.outcome == .victory)
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
