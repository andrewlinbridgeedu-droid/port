import Testing
@testable import MistportCombatCore

@Suite("Chapter one encounter runtime")
struct ChapterOneEncounterRuntimeTests {
    @Test("Battle relics require current ownership and remain excluded when depleted", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func battleRelicOwnership() {
        let watch = "relic_late_second_watch"
        let anchor = "relic_mist_anchor_shard"
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.loadout.relicIDs = [watch, anchor, watch]
        #expect(campaign.effectiveLoadout.relicIDs.isEmpty)

        campaign.ownedRelicIDs.insert(watch)
        #expect(campaign.effectiveLoadout.relicIDs == [watch])
        campaign.ownedRelicIDs.insert(anchor)
        #expect(campaign.effectiveLoadout.relicIDs == [watch, anchor])

        campaign.depletedRelicIDs.insert(watch)
        #expect(campaign.effectiveLoadout.relicIDs == [anchor])
        campaign.ownedRelicIDs.remove(anchor)
        #expect(campaign.effectiveLoadout.relicIDs.isEmpty)
        // Filtering a battle configuration does not erase the saved selection.
        #expect(campaign.loadout.relicIDs == [watch, anchor, watch])
    }

    @Test("Q1 and Q2 retain one card; Q3 grants the second card slot")
    func progressiveChapterStart() throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        #expect(campaign.unlockedSkillIDs.isEmpty)
        #expect(campaign.loadout.normalSkillIDs.isEmpty)
        #expect(!campaign.loadout.isUltimateUnlocked)
        #expect(campaign.unlockedPassiveIDs.isEmpty)
        #expect(campaign.ownedRelicIDs.isEmpty)
        #expect(Set(campaign.inventory.keys) == ["currency_copper"])

        let first = try #require(MPCChapterOneCatalog.encounters.first { $0.id == "chapter01_q01_encounter" })
        campaign.claimVictory(for: first)
        #expect(campaign.unlockedSkillIDs == [.sidestepStrike])
        #expect(campaign.loadout.normalSkillIDs == [.sidestepStrike])
        #expect(campaign.loadoutSlotCapacity == 1)
        #expect(!campaign.loadout.normalSkillIDs.contains(.paperDouble))
        #expect(campaign.inventory["item_old_clock_pass"] == 1)
        #expect(campaign.inventory["consumable_pain_salve"] == 1)

        let second = try #require(MPCChapterOneCatalog.encounters.first { $0.id == "chapter01_q02_encounter" })
        campaign.claimVictory(for: second)
        #expect(campaign.unlockedSkillIDs == [.sidestepStrike])
        #expect(campaign.loadout.normalSkillIDs == [.sidestepStrike])
        #expect(campaign.currentMissionID == "chapter01_q03")

        let third = try #require(MPCChapterOneCatalog.encounters.first { $0.id == "chapter01_q03_encounter" })
        campaign.claimVictory(for: third)
        #expect(campaign.unlockedSkillIDs == [.sidestepStrike])
        #expect(campaign.ownsManualMask)
        #expect(campaign.loadout.normalSkillIDs == [.sidestepStrike])
        #expect(campaign.loadoutSlotCapacity == 2)
        #expect(campaign.currentMissionID == "chapter01_q04")
    }

    @Test("Q2 spawns two guards and Sidestep damages both")
    func q2DualGuardSidestep() throws {
        let loadout = MPCChapterOneCampaignState.fullyUnlockedTestState
            .loadout(forMissionID: "chapter01_q02")
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q02_encounter",
            companionIDs: [],
            loadout: loadout
        )
        let targets = session.enemies.filter(\.isAlive)
        #expect(targets.count == 2)
        #expect(targets.allSatisfy { $0.contentID == "enemy_resonant_clock_guard_q2" })

        let result = try session.useFoolSkill(.sidestepStrike, targetID: targets[0].id)

        #expect(result.targets.count == 2)
        #expect(Set(result.targets.map(\.targetID)) == Set(targets.map(\.id)))
        #expect(session.enemies.allSatisfy { $0.hp < $0.maxHP })
    }

    @Test("Q1 trial card is granted to the active session at intervention")
    func q1TrialCardCanBeGrantedWithoutCampaignUnlock() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q01_encounter",
            companionIDs: [],
            loadout: MPCChapterOneLoadout(
                normalSkillIDs: [],
                isUltimateUnlocked: false,
                passiveIDs: [],
                relicIDs: []
            )
        )

        #expect(session.loadout.normalSkillIDs.isEmpty)
        let granted = session.grantTrialSkill(.sidestepStrike)
        #expect(granted)
        #expect(session.loadout.normalSkillIDs == [.sidestepStrike])
        let duplicateGrant = session.grantTrialSkill(.sidestepStrike)
        #expect(!duplicateGrant)
    }

    @Test("Q2 turn cooldown permits repeated one-card actions through the split")
    func q2SingleCardAutomationCanFinish() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q02_encounter",
            // This test advances every living enemy per player action to exercise
            // turn cooldowns. Real-time survivability is covered by progression.
            party: .init(playerHP: 3000, playerMaxHP: 3000),
            companionIDs: [],
            loadout: MPCChapterOneLoadout(
                normalSkillIDs: [.sidestepStrike],
                isUltimateUnlocked: false,
                passiveIDs: [],
                relicIDs: []
            )
        )
        var actions = 0

        while session.outcome == .inProgress, actions < 20 {
            let targetID = try #require(session.enemies.first(where: \.isAlive)?.id)
            if session.canUseFoolSkill(.sidestepStrike) {
                _ = try session.useFoolSkill(.sidestepStrike, targetID: targetID)
            } else {
                _ = try session.useBasicAction(.damage, targetID: targetID)
            }
            actions += 1
            if session.outcome == .inProgress { try session.endRound() }
        }

        #expect(session.outcome == .victory)
        #expect(actions <= 20)
    }

    @Test("Q1 seal absorbs the probe, then the enemy dies no later than round ten")
    func q1SealAndCombatPacing() throws {
        let loadout = MPCChapterOneCampaignState.chapterStartState
            .loadout(forMissionID: "chapter01_q01")
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q01_encounter",
            companionIDs: [],
            loadout: loadout
        )
        let targetID = try #require(session.enemies.first?.id)
        let openingHP = try #require(session.enemies.first?.hp)

        #expect(openingHP == 240)
        #expect(session.controlSealActive)
        for _ in 0..<3 {
            #expect(try session.useBasicAction(.damage, targetID: targetID) == 0)
            #expect(session.enemies.first?.hp == openingHP)
            try session.endRound()
        }

        let sealBreak = try session.useFoolSkill(.sidestepStrike, targetID: targetID)
        #expect(sealBreak.damage == 0)
        #expect(!session.controlSealActive)
        #expect(session.enemies.first?.hp == openingHP)
        #expect(session.remainingCooldownActions(for: .sidestepStrike) == 1)
        try session.endRound()

        while session.outcome == .inProgress, session.round <= 10 {
            _ = try session.useBasicAction(.damage, targetID: targetID)
            if session.outcome == .inProgress { try session.endRound() }
        }
        #expect(session.outcome == .victory)
        #expect(session.round <= 10)
    }

    @Test("Q3 hound attacks independently before the phantom card is awarded")
    func q3HoundPressure() throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q03_encounter", companionIDs: [], loadout: .init(normalSkillIDs: [.sidestepStrike], passiveIDs: [], relicIDs: []))
        #expect(session.enemies.map(\.contentID) == ["enemy_clockwork_hound"])
        let hp = session.playerHP
        try session.endRound(actingEnemyID: session.enemies[0].id)
        #expect(session.playerHP < hp)
        #expect(session.masqueradeCharges == 0)
    }

    @Test("敌方治疗优先选择损失生命百分比最多的敌人，施法者也可被治疗")
    func enemySupportTargetsGreatestPercentageWound() throws {
        let enemies = [
            MPCRuntimeEnemy(
                id: "core", contentID: "core", name: "钟核", maxHP: 360, hp: 108,
                attack: 46, defense: 10, intentPattern: ["transfer"], intentIndex: 0, delayedRounds: 0
            ),
            MPCRuntimeEnemy(
                id: "guard", contentID: "guard", name: "钟卫", maxHP: 900, hp: 630,
                attack: 118, defense: 24, intentPattern: ["strike"], intentIndex: 0, delayedRounds: 0
            ),
            MPCRuntimeEnemy(
                id: "hound", contentID: "hound", name: "魔犬", maxHP: 400, hp: 200,
                attack: 98, defense: 12, intentPattern: ["bite"], intentIndex: 0, delayedRounds: 0
            )
        ]

        let targetIndex = try #require(
            MPCChapterOneEncounterSession.lowestHealthEnemyIndex(in: enemies)
        )
        #expect(enemies[targetIndex].id == "core")
    }

    @Test("Q5 and later nodes follow the active unlock schedule")
    func authoredSkillUnlocks() throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        let q5 = try #require(MPCChapterOneCatalog.encounters.first { $0.id == "chapter01_q05_encounter" })
        campaign.acceptEncoreBellDelivery()
        campaign.claimVictory(for: q5)
        #expect(campaign.skillUnlockStates[.paperDouble] == nil)
        #expect(campaign.ownedRelicIDs.contains("relic_encore_bell") == MPCChapterOneCatalog.relicsEnabled)
        #expect(campaign.inventory["item_sealed_transfer"] == nil)
        #expect(campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 5) == nil)
        #expect(campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 8) == .identityDisplacement)
        #expect(campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 9) == .fabricatedEvidence)
        #expect(campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 10) == .mirrorPursuit)
        #expect(campaign.loadoutSlotCapacity == 4)
        #expect(campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 11) == .absurdFinale)
        #expect(campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 12) == .turnTheTables)
        #expect(campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 13) == .namelessStage)
        #expect(campaign.applyChapterMissionProgress(districtID: "salt-warehouse", missionNumber: 15) == nil)
        #expect(campaign.applyChapterMissionProgress(districtID: "mist-crown", missionNumber: 20) == nil)
        #expect(campaign.loadoutSlotCapacity == 4)
    }

    @Test("Every new chapter encounter restores the player to full health")
    func encounterStartsAtFullHealth() throws {
        let session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q04_encounter",
            party: MPCPartyPersistentState(
                playerHP: 1,
                playerMaxHP: 1_200,
                sharedReviveCharges: 0
            )
        )

        #expect(session.playerHP == 1_200)
        #expect(session.playerMaxHP == 1_200)
    }

    @Test("Enemy actions do not reduce the acting enemies' health")
    func enemyTurnDoesNotDamageEnemies() throws {
        let loadout = MPCChapterOneCampaignState.fullyUnlockedTestState
            .loadout(forMissionID: "chapter01_q02")
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q02_encounter",
            companionIDs: [],
            loadout: loadout
        )
        let healthBefore = session.enemies.map(\.hp)

        try session.endRound()

        #expect(session.enemies.map(\.hp) == healthBefore)
    }

    @Test("Q2 records both guards as separate ordered attacks")
    func q2EnemyActionLedgerKeepsActorsSeparate() throws {
        let loadout = MPCChapterOneCampaignState.fullyUnlockedTestState
            .loadout(forMissionID: "chapter01_q02")
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q02_encounter",
            companionIDs: [],
            loadout: loadout
        )
        let expectedEnemyIDs = session.enemies.filter(\.isAlive).map(\.id)

        try session.endRound()

        let actions = session.lastEnemyActionResolutions
        #expect(actions.map(\.enemyID) == expectedEnemyIDs)
        #expect(Set(actions.map(\.enemyID)).count == 2)
        #expect(actions.allSatisfy { $0.playerDamage > 0 })
        #expect(actions.allSatisfy { $0.healedTargetID == nil })
    }

    @Test("Q3 action ledger identifies the hunting hound")
    func q3EnemyActionLedgerKeepsActorsSeparate() throws {
        let loadout = MPCChapterOneCampaignState.fullyUnlockedTestState
            .loadout(forMissionID: "chapter01_q03")
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q03_encounter",
            companionIDs: [],
            loadout: loadout
        )
        let expectedEnemyIDs = session.enemies.map(\.id)

        try session.endRound()

        let actions = session.lastEnemyActionResolutions
        #expect(actions.map(\.enemyID) == expectedEnemyIDs)
        #expect(Set(actions.map(\.enemyID)).count == expectedEnemyIDs.count)
        #expect(actions.allSatisfy { $0.playerDamage >= 0 })
    }

    @Test("Q4 stays ranged and probes before two charged fireballs")
    func q4NormalHoundDealsDamage() throws {
        let loadout = MPCChapterOneLoadout(
            normalSkillIDs: [.sidestepStrike, .maskedWhisper],
            passiveIDs: [],
            relicIDs: []
        )
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q04_encounter",
            companionIDs: [],
            loadout: loadout
        )
        let targetID = try #require(session.enemies.first?.id)
        let playerHPBefore = session.playerHP

        _ = try session.useFoolSkill(.sidestepStrike, targetID: targetID)
        try session.endRound()

        #expect(session.playerHP == playerHPBefore - 80)
        #expect(session.lastEnemyActionResolutions.first?.intent == "q4_probe")
        try session.endRound()
        #expect(session.lastEnemyActionResolutions.first?.intent == "charge")
        #expect(session.lastEnemyActionResolutions.first?.playerDamage == 0)
        try session.endRound()
        #expect(session.lastEnemyActionResolutions.first?.intent == "q4_flame_first")
        #expect(session.lastEnemyActionResolutions.first?.playerDamage == (session.playerMaxHP * 110 + 99) / 100)
        #expect(session.outcome == .defeat)
        #expect(session.playerHP == 0)

    }

    @Test("Q4 finishes through actual damage, without a forced fourth-beat kill")
    func q4ActualDamage() throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q04_encounter", companionIDs: [], loadout: .init(normalSkillIDs: [.maskedWhisper, .sidestepStrike], passiveIDs: [], relicIDs: []))
        let id = session.enemies[0].id
        let before = session.enemies[0].hp
        _ = try session.applyPartyDamage(1, to: id)
        #expect(session.enemies[0].hp == before - 1)
        for _ in 0..<4 {
            _ = try session.applyPartyDamage(1, to: id)
        }
        #expect(session.outcome == .inProgress)
        #expect(session.enemies[0].hp == before - 5)
    }

    @Test("Retired paper relic cannot rescue the player or reset a defeat")
    func paperRelicOneUse() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q05_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.sidestepStrike], passiveIDs: [], relicIDs: ["relic_paper_raincoat"]))
        var count = 0
        while session.outcome == .inProgress && count < 100 {
            try session.endRound()
            count += 1
        }
        #expect(session.playerHP == 0)
        #expect(!session.q5PaperRelicTriggered)
        #expect(session.outcome == .defeat)
        session.resolveQ5MaraIntervention()
        #expect(session.outcome == .defeat)
        #expect(session.playerHP == 0)
    }

    @Test("Every chapter encounter starts with valid enemies", arguments: MPCChapterOneCatalog.encounters.map(\.id))
    func everyEncounterStarts(_ encounterID: String) throws {
        let session = try MPCChapterOneEncounterSession.start(encounterID: encounterID)
        #expect(session.outcome == .inProgress)
        #expect(!session.enemies.isEmpty)
        #expect(!session.announcedIntents.isEmpty)
    }

    @Test("Every chapter encounter can progress through all waves to victory", arguments: MPCChapterOneCatalog.encounters.map(\.id))
    func everyEncounterCanFinish(_ encounterID: String) throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: encounterID,
            party: .init(playerHP: 100_000, playerMaxHP: 100_000), companionIDs: [])
        // Damage cannot bypass true wards, extraction objectives or five-cycle boss authority.
        for step in 0..<200 where session.outcome == .inProgress {
            for enemy in session.enemies.filter(\.isAlive) {
                _ = try session.applyPartyDamage(99_999, to: enemy.id)
                if session.outcome == .inProgress, session.enemies.contains(where: { $0.id == enemy.id && $0.isAlive }) {
                    session.commitEnemyImpact(from: enemy.id)
                    try session.endRound(actingEnemyID: enemy.id, at: Double(step))
                }
            }
        }
        #expect(session.outcome == .victory)
    }

    @Test("Story rewards are granted once while repeat materials remain repeatable")
    func rewardRules() throws {
        let encounter = try #require(MPCChapterOneCatalog.encounters.first { $0.id == "encounter_midnight_02" })
        var campaign = MPCChapterOneCampaignState()
        campaign.claimVictory(for: encounter)
        campaign.claimVictory(for: encounter)
        #expect(campaign.inventory["key_old_clock_attestation"] == 1)
        #expect(campaign.inventory["key_authority_echo"] == 1)
        #expect(campaign.ownedRelicIDs.contains("relic_unified_gear") == MPCChapterOneCatalog.relicsEnabled)
    }

    @Test("A new encounter starts full and persistent state clears combat shield")
    func persistentDungeonState() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            party: MPCPartyPersistentState(playerHP: 500, sharedReviveCharges: 0)
        )
        session.grantPlayerShield(200)
        let persistent = session.persistentPartyState()
        #expect(persistent.playerHP == 1_000)
        #expect(persistent.sharedReviveCharges == 0)
        var campaign = MPCChapterOneCampaignState(party: persistent)
        campaign.applyPostEncounterRecovery()
        #expect(campaign.party.playerHP == 1_000)
    }

    @Test("Boss moves through all three phases by HP threshold")
    func bossPhases() throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: "encounter_midnight_02")
        let boss = try #require(session.enemies.first)
        try session.applyPartyDamage(1_700, to: boss.id, category: .damage)
        #expect(session.bossPhase == .unifiedMoment)
        try session.applyPartyDamage(1_600, to: boss.id, category: .control)
        #expect(session.bossPhase == .thirteenthBell)
    }

    @Test("Repeated action categories empower unified-moment boss")
    func bossPunishesRepeatedCategory() throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: "encounter_midnight_02")
        let boss = try #require(session.enemies.first)
        try session.applyPartyDamage(1_700, to: boss.id, category: .damage)
        try session.applyPartyDamage(1, to: boss.id, category: .damage)
        #expect(session.bossEmpowermentStacks == 1)
    }

    @Test("The thirteenth bell has four valid responses", arguments: [
        MPCBossMechanicResponse.evasion,
        .protection,
        .willBreak,
        .fullFinisher
    ])
    func bossResponses(_ response: MPCBossMechanicResponse) throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: "encounter_midnight_02")
        let boss = try #require(session.enemies.first)
        try session.applyPartyDamage(3_300, to: boss.id, category: .control)
        for _ in 0..<3 { try session.endRound(response: .protection) }
        let hpBefore = session.playerHP
        try session.endRound(response: response)
        #expect(session.outcome != .defeat)
        if response != .protection { #expect(session.playerHP == hpBefore) }
    }

    @Test("Missing the lethal mechanic produces an actionable defeat report")
    func defeatAnalysis() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_midnight_02",
            companionIDs: [], loadout: .init(relicIDs: [])
        )
        let boss = try #require(session.enemies.first)
        try session.applyPartyDamage(3_300, to: boss.id, category: .damage)
        for _ in 0..<3 { try session.endRound(response: .protection) }
        try session.endRound(response: .none)
        #expect(session.outcome == .defeat)
        let analysis = try #require(session.defeatAnalysis())
        #expect(analysis.criticalRound > 0)
        #expect(analysis.recommendations.contains { $0.contains("第十三声") })
    }

    @Test("A living AI automatically spends the shared revive on a downed player")
    func sharedRevive() throws {
        let party = MPCPartyPersistentState(
            playerHP: 50,
            playerMaxHP: 50,
            allyHP: ["allyA": 800],
            allyMaxHP: ["allyA": 800],
            sharedReviveCharges: 1
        )
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01", party: party,
            loadout: MPCChapterOneLoadout(passiveIDs: [], relicIDs: [])
        )
        try session.endRound()
        #expect(session.playerHP == 15)
        #expect(session.sharedReviveCharges == 0)
    }

    @Test("Encounter skill execution preserves the Fool combo state")
    func foolComboExecution() throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: "encounter_rain_01")
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        _ = try session.useFoolSkill(.fabricatedEvidence, targetID: target.id)
        #expect(session.foolState(for: target.id)?.illusionStacks == 4)
        _ = try session.useFoolSkill(.identityDisplacement, targetID: target.id)
        #expect(session.foolState(for: target.id)?.illusionStacks == 0)
        #expect(session.foolState(for: target.id)?.misalignmentStacks == 2)
        #expect(session.log.contains { entry in
            entry.message.contains("fool_skill_04")
                && entry.message.contains("基础命中")
                && entry.message.contains("最终伤害")
                && !entry.message.contains("剩余冷却")
        })
    }

    @Test("Paper double and nameless stage execute through the encounter session")
    func utilitySkills() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_stolen_01",
            loadout: MPCChapterOneLoadout(
                normalSkillIDs: [.paperDouble, .maskedWhisper], passiveIDs: [], relicIDs: []
            )
        )
        _ = try session.useFoolSkill(.paperDouble, targetID: nil)
        #expect(session.playerShield == 0)
        #expect(session.paperDoubleCounterCharges == 1)
        _ = try session.useFoolSkill(.namelessStage, targetID: nil)
        #expect(session.enemies.allSatisfy { session.foolState(for: $0.id)?.illusionStacks == 4 })
        #expect(throws: FoolBattleError.ultimateAlreadyUsed) {
            try session.useFoolSkill(.namelessStage, targetID: nil)
        }
    }

    @Test("Paper double counter applies two illusion stacks after the enemy actually lands a hit")
    func paperDoubleCounterTiming() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            loadout: MPCChapterOneLoadout(normalSkillIDs: [.paperDouble, .maskedWhisper], passiveIDs: [], relicIDs: [])
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.paperDouble, targetID: nil)
        #expect(session.paperDoubleCounterCharges == 1)
        try session.endRound(response: .none)
        #expect(session.paperDoubleCounterCharges == 0)
        #expect(session.foolState(for: target.id)?.illusionStacks == 2)
        #expect(session.behaviorTags.contains(.applyIllusion))
    }

    @Test("Fully unlocked test campaign owns every unlock and usable item")
    func fullyUnlockedCampaign() {
        let campaign = MPCChapterOneCampaignState.fullyUnlockedTestState
        #expect(campaign.unlockedSkillIDs == Set(MPCChapterOneCatalog.skills.map(\.id)))
        #expect(campaign.unlockedPassiveIDs == Set(MPCChapterOneCatalog.passives.map(\.id)))
        #expect(campaign.ownedRelicIDs == Set(MPCChapterOneCatalog.relics.map(\.id)))
        #expect(MPCChapterOneCatalog.items.allSatisfy { campaign.inventory[$0.id, default: 0] > 0 })
        #expect(MPCChapterOneCatalog.items.allSatisfy { item in
            campaign.inventory[item.id] == (item.kind == .keyItem ? 1 : item.maxStack)
        })
        #expect(campaign.loadout.normalSkillIDs.count == 4)
        #expect(campaign.loadout.passiveIDs.count == 2)
        #expect(campaign.loadout.relicIDs == ["relic_late_second_watch"])
        #expect(campaign.loadout.battleSkillIDs.count == 5)
    }

    @Test("Fully unlocked test inventory can be refilled after consumption")
    func refillTestInventory() {
        var campaign = MPCChapterOneCampaignState.fullyUnlockedTestState
        campaign.inventory["consumable_clock_key"] = 0
        campaign.inventory["currency_copper"] = 0
        campaign.refillAllTestItems()
        #expect(campaign.inventory["consumable_clock_key"] == 3)
        #expect(campaign.inventory["currency_copper"] == 99_999)
    }

    @Test("Loadout clamps every formal prebattle slot")
    func loadoutSlots() {
        let loadout = MPCChapterOneLoadout(
            normalSkillIDs: FoolSkillID.allCases,
            passiveIDs: MPCChapterOneCatalog.passives.map(\.id),
            relicIDs: MPCChapterOneCatalog.relics.map(\.id)
        )
        #expect(loadout.normalSkillIDs.count == 5)
        #expect(!loadout.normalSkillIDs.contains(.namelessStage))
        #expect(Set(loadout.normalSkillIDs).count == 5)
        #expect(loadout.passiveIDs.count == 2)
        #expect(loadout.relicIDs.count == 2)
    }

    @Test("Loadout removes duplicate normal skills before applying the five-slot limit")
    func loadoutDeduplicatesSkills() {
        let loadout = MPCChapterOneLoadout(normalSkillIDs: [
            .maskedWhisper, .maskedWhisper, .fabricatedEvidence,
            .identityDisplacement, .mirrorPursuit, .sidestepStrike,
            .absurdFinale, .turnTheTables,
        ])
        #expect(loadout.normalSkillIDs == [
            .maskedWhisper, .fabricatedEvidence, .identityDisplacement,
            .mirrorPursuit, .sidestepStrike,
        ])
    }

    @Test("Equipped passives, relic, and ritual alter encounter rules")
    func equippedEffects() throws {
        let loadout = MPCChapterOneLoadout(
            normalSkillIDs: [.maskedWhisper, .paperDouble, .fabricatedEvidence, .identityDisplacement],
            passiveIDs: ["fool_passive_01", "fool_passive_02"],
            relicIDs: ["relic_paper_raincoat"],
            ritual: .paperWard
        )
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01", loadout: loadout
        )
        #expect(session.playerShield == 150)
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        #expect(session.foolState(for: target.id)?.illusionStacks == 3)
        _ = try session.useFoolSkill(.paperDouble, targetID: nil)
        #expect(session.playerShield == 150)
        #expect(session.paperDoubleCounterCharges == 1)
    }

    @Test("Borrowed-second legacy ritual does not create an ordinary-card cooldown")
    func borrowedSecondRitual() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            loadout: MPCChapterOneLoadout(ritual: .borrowedSecond)
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        #expect(session.remainingCooldownActions(for: .maskedWhisper) == 2)
        #expect(!session.borrowedSecondAvailable)
    }

    @Test("Late applause empowers the next single-hit skill")
    func lateApplause() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_midnight_02",
            loadout: MPCChapterOneLoadout(normalSkillIDs: [.identityDisplacement, .mirrorPursuit, .sidestepStrike], passiveIDs: ["fool_passive_04"], relicIDs: [])
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.namelessStage, targetID: nil)
        _ = try session.useFoolSkill(.identityDisplacement, targetID: target.id)
        _ = try session.useFoolSkill(.mirrorPursuit, targetID: target.id)
        let strike = try session.useFoolSkill(.sidestepStrike, targetID: target.id)
        #expect(strike.damage > 100)
        #expect(session.triggeredEffects.contains { $0.contains("迟到的掌声") })
    }

    @Test("Unwritten ending grants and consumes a low-health evasion")
    func unwrittenEnding() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            // Chapter encounters start at full health. Use a smaller test
            // max HP so the 90%-scaled 赤弧斩 still crosses the 30% trigger.
            party: MPCPartyPersistentState(playerHP: 80, playerMaxHP: 80),
            companionIDs: [],
            loadout: MPCChapterOneLoadout(passiveIDs: ["fool_passive_06"], relicIDs: [])
        )
        try session.endRound()
        #expect(session.freeEvasionCharges == 1)
        try session.endRound()
        let hpBefore = session.playerHP
        try session.endRound()
        #expect(session.playerHP == hpBefore)
        #expect(session.freeEvasionCharges == 0)
    }

    @Test("Unified gear rewards three different action categories", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func unifiedGear() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_midnight_02",
            loadout: MPCChapterOneLoadout(
                normalSkillIDs: [.maskedWhisper, .paperDouble, .sidestepStrike],
                passiveIDs: [], relicIDs: ["relic_unified_gear"]
            )
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        _ = try session.useFoolSkill(.paperDouble, targetID: nil)
        _ = try session.useFoolSkill(.sidestepStrike, targetID: target.id)
        #expect(session.playerShield == 100)
        #expect(session.ringExposurePending)
    }

    @Test("Mist anchor shard adds shield after shared revive", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func mistAnchorRevive() throws {
        let party = MPCPartyPersistentState(
            playerHP: 50, playerMaxHP: 50,
            allyHP: ["allyA": 800], allyMaxHP: ["allyA": 800], sharedReviveCharges: 1
        )
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01", party: party,
            loadout: MPCChapterOneLoadout(passiveIDs: [], relicIDs: ["relic_mist_anchor_shard"])
        )
        try session.endRound()
        #expect(session.playerHP == 15)
        #expect(session.playerShield == 5)
        #expect(session.mistAnchorWasConsumed)
        let enemy = try #require(session.enemies.first(where: { $0.isAlive }))
        try session.applyPartyDamage(99_999, to: enemy.id)

        var campaign = MPCChapterOneCampaignState.fullyUnlockedTestState
        campaign.loadout = MPCChapterOneLoadout(
            passiveIDs: [], relicIDs: ["relic_mist_anchor_shard"]
        )
        campaign.completeEncounter(session)
        #expect(campaign.depletedRelicIDs.contains("relic_mist_anchor_shard"))
        #expect(!campaign.effectiveLoadout.relicIDs.contains("relic_mist_anchor_shard"))
        campaign.restoreAllTestRelics()
        #expect(campaign.effectiveLoadout.relicIDs.contains("relic_mist_anchor_shard"))
    }

    @Test("Clock-chaser spur rewards holding a ready skill for two actions", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func clockChaserSpur() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_midnight_02",
            loadout: MPCChapterOneLoadout(passiveIDs: [], relicIDs: ["relic_clock_chaser_spur"])
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.sidestepStrike, targetID: target.id)
        _ = try session.useBasicAction(.damage, targetID: target.id)
        _ = try session.useFoolSkill(.sidestepStrike, targetID: target.id)
        let whisper = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        #expect(whisper.damage > 40)
        #expect(session.remainingCooldownActions(for: .maskedWhisper) == 2)
        #expect(session.triggeredEffects.contains { $0.contains("追钟人断刺") })
    }

    @Test("Trimmed nameplate reacts to an enemy dispel intent", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func trimmedNameplate() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_midnight_01",
            loadout: MPCChapterOneLoadout(passiveIDs: [], relicIDs: ["relic_trimmed_nameplate"])
        )
        let trimmer = try #require(session.enemies.first)
        session.grantPlayerShield(100)
        try session.endRound()
        #expect(session.foolState(for: trimmer.id)?.illusionStacks == 2)
        #expect(session.triggeredEffects.contains { $0.contains("裁去的名牌") })
    }

    @Test("Blank ticket preserves one expired finale setup", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func blankTicket() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_midnight_02",
            loadout: MPCChapterOneLoadout(
                normalSkillIDs: [.maskedWhisper, .paperDouble, .turnTheTables],
                passiveIDs: [], relicIDs: ["relic_blank_ticket"]
            )
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.namelessStage, targetID: nil)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        _ = try session.useFoolSkill(.paperDouble, targetID: nil)
        _ = try session.useFoolSkill(.turnTheTables, targetID: target.id)
        #expect(session.foolState(for: target.id)?.finaleReady == true)
        #expect(session.triggeredEffects.contains { $0.contains("空白戏票") })
    }

    @Test("Unequipped skills cannot bypass the six-slot loadout")
    func unequippedSkillRejected() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            loadout: MPCChapterOneLoadout(normalSkillIDs: [.maskedWhisper])
        )
        #expect(throws: MPCEncounterRuntimeError.skillNotEquipped(.paperDouble)) {
            try session.useFoolSkill(.paperDouble, targetID: nil)
        }
    }

    @Test("Memory leech enhanced setup adds one illusion and pays its first cleanse cost", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func memoryLeechEnhancedSetup() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            loadout: MPCChapterOneLoadout(
                normalSkillIDs: [.backstageChange, .maskedWhisper],
                passiveIDs: [], relicIDs: ["relic_memory_leech_vial"]
            )
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.backstageChange, targetID: nil)
        #expect(session.playerHP == 960)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        #expect(session.foolState(for: target.id)?.illusionStacks == 3)
    }

    @Test("Thirteenth record previews the next intent every third round", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func thirteenthRecordPreview() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            loadout: MPCChapterOneLoadout(passiveIDs: [], relicIDs: ["relic_thirteenth_record"])
        )
        try session.endRound()
        try session.endRound()
        #expect(session.round == 3)
        #expect(session.announcedIntents.contains { $0.intent.hasPrefix("下一意图：") })
    }

    @Test("Borrowed bell only triggers once per round from the construct armor break", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func borrowedBellOncePerRound() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_stolen_01",
            companionIDs: ["ally_alchemy_construct"],
            loadout: MPCChapterOneLoadout(passiveIDs: [], relicIDs: ["relic_borrowed_bell"])
        )
        _ = session.performCompanionActions()
        #expect(session.playerShield == 50)
        _ = session.performCompanionActions()
        #expect(session.playerShield == 50)
    }

    @Test("Late-second watch rewards only a correct response to an announced strong attack", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func lateSecondWatchRequiresCorrectResponse() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_02",
            loadout: MPCChapterOneLoadout(
                normalSkillIDs: [.maskedWhisper], passiveIDs: [], relicIDs: ["relic_late_second_watch"]
            )
        )
        let target = try #require(session.enemies.first)
        #expect(session.announcedIntents.contains { $0.intent == "charge" })
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        #expect(session.remainingCooldownActions(for: .maskedWhisper) == 2)

        try session.endRound(response: .evasion) // charge is not an attack
        #expect(session.announcedIntents.contains { $0.intent == "pounce" })
        #expect(session.remainingCooldownActions(for: .maskedWhisper) == 2)
        #expect(!session.triggeredEffects.contains { $0.contains("迟秒怀表") })

        try session.endRound(response: .protection) // pounce is the announced strong attack
        #expect(session.remainingCooldownActions(for: .maskedWhisper) == 0)
        #expect(session.triggeredEffects.contains { $0.contains("迟秒怀表") })
    }

    @Test("Cracked monocle uses five-percent armor penetration instead of final damage amplification", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func crackedMonocleArmorPenetration() throws {
        let loadout = MPCChapterOneLoadout(
            normalSkillIDs: [.maskedWhisper], passiveIDs: [], relicIDs: ["relic_cracked_monocle"]
        )
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_midnight_02", loadout: loadout
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.namelessStage, targetID: nil)
        let result = try session.useFoolSkill(.maskedWhisper, targetID: target.id)

        var expectedState = FoolComboState(targetDefense: target.defense * 95 / 100, illusionStacks: 4)
        let expected = try FoolComboSimulator.resolve(skillID: .maskedWhisper, from: expectedState)
        #expect(result.damage == expected.totalDamage)
        #expect(session.foolState(for: target.id)?.targetDefense == target.defense)

        var noIllusion = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_midnight_02", loadout: loadout
        )
        let freshTarget = try #require(noIllusion.enemies.first)
        let penalized = try noIllusion.useFoolSkill(.maskedWhisper, targetID: freshTarget.id)
        expectedState = FoolComboState(targetDefense: freshTarget.defense)
        let unpenalized = try FoolComboSimulator.resolve(skillID: .maskedWhisper, from: expectedState)
        #expect(penalized.damage == unpenalized.totalDamage * 97 / 100)
    }

    @Test("Unreliable narrator triggers once per round and increases that round's incoming damage")
    func unreliableNarratorRisk() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            loadout: MPCChapterOneLoadout(
                normalSkillIDs: [.maskedWhisper, .fabricatedEvidence, .sidestepStrike],
                passiveIDs: ["fool_passive_02"], relicIDs: []
            )
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        #expect(session.foolState(for: target.id)?.illusionStacks == 3)
        _ = try session.useFoolSkill(.fabricatedEvidence, targetID: target.id)
        #expect(session.foolState(for: target.id)?.illusionStacks == 4)
        _ = try session.useFoolSkill(.sidestepStrike, targetID: target.id)
        try session.endRound()
        #expect(session.playerHP == 1000) // The new phantom intercepts this hit before incoming modifiers.
        #expect(session.masqueradeCharges == 1)

        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        #expect(session.triggeredEffects.filter { $0.contains("不可靠叙述者") }.count == 2)
    }

    @Test("Ordinary encounter cards respect action-index cooldowns")
    func cooldownAndClockKey() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_midnight_02",
            consumables: ["consumable_clock_key": 1]
        )
        let target = try #require(session.enemies.first)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        #expect(session.remainingCooldownActions(for: .maskedWhisper) == 2)
        _ = try session.useBasicAction(.damage, targetID: target.id)
        _ = try session.useBasicAction(.damage, targetID: target.id)
        _ = try session.useFoolSkill(.maskedWhisper, targetID: target.id)
        try session.useConsumable("consumable_clock_key")
        #expect(session.remainingCooldownActions(for: .maskedWhisper) == 2)
    }

    @Test("Battle consumables apply their effects and are consumed")
    func consumables() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_rain_01",
            party: MPCPartyPersistentState(playerHP: 500),
            consumables: ["consumable_salt_tea": 1, "consumable_mirror_salve": 1],
            loadout: MPCChapterOneLoadout(passiveIDs: [], relicIDs: [])
        )
        try session.endRound()
        try session.useConsumable("consumable_salt_tea")
        try session.useConsumable("consumable_mirror_salve")
        #expect(session.playerHP == 1_000)
        #expect(session.playerShield == 100)
        #expect(session.consumables["consumable_salt_tea"] == 0)
    }

    @Test("Encounter activates its declared companion slots", arguments: [
        ("encounter_rain_01", 0), ("encounter_stolen_01", 1), ("encounter_thirteenth_01", 2)
    ])
    func companionSlots(encounterID: String, expectedCount: Int) throws {
        let session = try MPCChapterOneEncounterSession.start(encounterID: encounterID)
        #expect(session.activeCompanionIDs.count == expectedCount)
    }

    @Test("Unlocked companions perform deterministic planned actions")
    func companionActions() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "encounter_thirteenth_01",
            companionIDs: ["ally_chariot_warden", "ally_alchemy_construct"]
        )
        let hpBefore = session.enemies.map(\.hp).reduce(0, +)
        let actions = session.performCompanionActions(focusTargetID: session.enemies.first?.id)
        let hpAfter = session.enemies.map(\.hp).reduce(0, +)
        #expect(actions.count == 2)
        #expect(hpAfter < hpBefore)
    }
}
