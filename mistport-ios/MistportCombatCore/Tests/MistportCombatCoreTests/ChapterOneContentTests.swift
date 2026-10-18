import Testing
@testable import MistportCombatCore

@Suite("Chapter one complete content contract")
struct ChapterOneContentTests {
    @Test("Natural mission rewards never equip more cards than earned slots")
    func earnedSlotsAcrossTwentyMissions() throws {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        for mission in MPCChapterOneCatalog.missions {
            let encounter = try #require(MPCChapterOneCatalog.encounters.first { $0.id == mission.encounterID })
            campaign.claimVictory(for: encounter)
            #expect(campaign.loadout.normalSkillIDs.count <= campaign.loadoutSlotCapacity)
            #expect(campaign.loadoutSlotCapacity == (mission.number < 6 ? 2 : mission.number < 9 ? 3 : 4))
            for skill in mission.permanentSkillIDs {
                #expect(campaign.unlockedSkillIDs.contains(skill))
            }
        }
        #expect(campaign.completedMissionIDs.count == 30)
        #expect(campaign.loadout.isUltimateUnlocked)
    }

    @Test("Q1 through Q30 route to their authored mission encounters")
    func q1ThroughQ30MissionRouting() {
        #expect(MPCChapterOneCatalog.missions.map(\.number) == Array(1...30))
        #expect(MPCChapterOneCatalog.missions.map(\.encounterID) == (1...30).compactMap {
            MPCChapterOneCatalog.encounterID(forOldClockMissionNumber: $0)
        })
        #expect(Set(MPCChapterOneCatalog.missions.map(\.encounterID)).count == 30)
    }

    @Test("The sixth main-map node stays in the old-district authored route")
    func sixthMainMapMissionRouting() {
        #expect(MPCChapterOneCatalog.encounterID(forOldClockMissionNumber: 6) == "chapter01_q06_encounter")
        #expect(MPCChapterOneCatalog.encounterID(forOldClockMissionNumber: 10) == "chapter01_q10_encounter")
        #expect(MPCChapterOneCatalog.encounterID(forOldClockMissionNumber: 20) == "chapter01_q20_encounter")
    }

    @Test("The four later districts expose twenty authored Fool encounters each")
    func laterDistrictMissionRouting() {
        let districts = ["salt-warehouse", "mirror-theater", "tide-gate", "mist-crown"]
        for districtID in districts {
            let encounterIDs = (1...20).compactMap {
                MPCChapterOneCatalog.encounterID(forDistrictID: districtID, missionNumber: $0)
            }
            #expect(encounterIDs.count == 20)
            #expect(Set(encounterIDs).count == 20)
            #expect(encounterIDs.allSatisfy { $0.hasPrefix("\(districtID)-q") })
        }

        #expect(MPCChapterOneCatalog.encounters.first { $0.id == "salt-warehouse-q20_encounter" }?.firstClearRelicID == (MPCChapterOneCatalog.relicsEnabled ? "relic_cracked_monocle" : nil))
        #expect(MPCChapterOneCatalog.encounters.first { $0.id == "mirror-theater-q20_encounter" }?.firstClearRelicID == (MPCChapterOneCatalog.relicsEnabled ? "relic_blank_ticket" : nil))
        #expect(MPCChapterOneCatalog.encounters.first { $0.id == "tide-gate-q20_encounter" }?.firstClearRelicID == (MPCChapterOneCatalog.relicsEnabled ? "relic_returning_route" : nil))
        #expect(MPCChapterOneCatalog.encounters.first { $0.id == "mist-crown-q20_encounter" }?.firstClearRelicID == (MPCChapterOneCatalog.relicsEnabled ? "relic_errata_clip" : nil))
    }

    @Test("All chapter-one content references resolve")
    func referencesResolve() {
        #expect(MPCChapterOneCatalog.validationErrors().isEmpty)
    }

    @Test("The Fool test character exposes every frozen skill")
    func allFoolSkillsExist() {
        #expect(Set(MPCChapterOneCatalog.skills.map(\.id)) == Set(FoolSkillID.allCases.filter { $0 != .paperDouble }))
        #expect(MPCChapterOneCatalog.skills.count == 12)
        #expect(MPCChapterOneCatalog.skills.filter(\.isUltimate).map(\.id) == [.namelessStage])
    }

    @Test("Ten distinct ordinary cards plus separate mask and ultimate")
    func orderedCardNames() {
        #expect(MPCChapterOneCatalog.skills.map(\.name) == [
            "侧身刺", "污名记", "急板", "燃镜", "重绘", "突转",
            "错认喜剧", "双星追猎", "归谬法", "附言", "假面", "我叫无人"
        ])
        // Every card says where its name comes from (2026-10-18).
        #expect(MPCChapterOneCatalog.skills.allSatisfy { !$0.origin.isEmpty })
        #expect(MPCChapterOneCatalog.combos.count == 5)
        #expect(!MPCChapterOneCatalog.combos.contains { $0.id == "K07" })
        #expect(MPCChapterOneCatalog.combos.first?.name == "急板终曲")
        #expect(MPCChapterOneCatalog.combos.last?.name == "快板过场")
    }

    @Test("Q1–Q5 content is present alongside reusable prototype content")
    func requiredCounts() {
        #expect(MPCChapterOneCatalog.passives.count == 6)
        #expect(MPCChapterOneCatalog.relics.count >= 20)
        #expect(MPCChapterOneCatalog.items.count >= 16)
        #expect(MPCChapterOneCatalog.companions.count >= 4)
        #expect(MPCChapterOneCatalog.enemies.filter { $0.rank == .normal }.count >= 9)
        #expect(MPCChapterOneCatalog.enemies.filter { $0.rank == .elite }.count == 5)
        #expect(MPCChapterOneCatalog.enemies.filter { $0.rank == .boss }.count >= 2)
        #expect(MPCChapterOneCatalog.encounters.count >= 13)
        #expect(MPCChapterOneCatalog.investigations.count >= 9)
    }

    @Test("Only the final boss's three meetings bring the fixed two-ally party")
    func q1ThroughQ5PartyOrder() {
        let slots = MPCChapterOneCatalog.missions.compactMap { mission in
            MPCChapterOneCatalog.encounters.first(where: { $0.id == mission.encounterID })?.companionSlots
        }
        #expect(slots == Array(repeating: 0, count: 27) + [2, 2, 2])
    }

    @Test("Each authored Q mission owns one fixed encounter and reward flow")
    func qMissionShape() {
        for mission in MPCChapterOneCatalog.missions {
            #expect(MPCChapterOneCatalog.mission(forEncounterID: mission.encounterID)?.id == mission.id)
            let encounter = MPCChapterOneCatalog.encounters.first { $0.id == mission.encounterID }
            #expect(!mission.rewardItemIDs.isEmpty || encounter?.firstClearRelicID != nil || (!MPCChapterOneCatalog.relicsEnabled && mission.number == 5))
        }
    }

    @Test("Legacy Q5 Encore Bell delivery", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
    func q5EncoreBellRelic() {
        let mission = MPCChapterOneCatalog.mission(forOldClockMissionNumber: 5)
        #expect(mission?.trialSkillID == nil)
        #expect(mission?.permanentSkillIDs.isEmpty == true)
        #expect(MPCChapterOneCatalog.relics.first?.id == "relic_encore_bell")
        #expect(MPCChapterOneCatalog.relics.first?.name == "不肯落幕的铃")
        #expect(MPCChapterOneCatalog.encounters.first(where: { $0.id == "chapter01_q05_encounter" })?.firstClearRelicID == "relic_encore_bell")
    }

    @Test("Q3 introduces the hound before the phantom and relic lessons")
    func earlyEnemyVariety() throws {
        let q2 = try #require(MPCChapterOneCatalog.encounters.first {
            $0.id == "chapter01_q02_encounter"
        })
        let q3 = try #require(MPCChapterOneCatalog.encounters.first {
            $0.id == "chapter01_q03_encounter"
        })
        let q4 = try #require(MPCChapterOneCatalog.encounters.first {
            $0.id == "chapter01_q04_encounter"
        })
        let q5 = try #require(MPCChapterOneCatalog.encounters.first {
            $0.id == "chapter01_q05_encounter"
        })

        #expect(q2.waves.map(\.enemyIDs) == [[
            "enemy_resonant_clock_guard_q2",
            "enemy_resonant_clock_guard_q2"
        ]])
        #expect(q3.waves.map(\.enemyIDs) == [["enemy_clockwork_hound"]])
        #expect(q2.waves.map(\.enemyIDs) != q3.waves.map(\.enemyIDs))
        #expect(q4.waves.map(\.enemyIDs) == [["enemy_clockwork_hound"]])
        #expect(q5.waves.map(\.enemyIDs) == [["enemy_emerald_revenant"]])
    }

    @Test("Every relic declares mechanism, cost, build direction, and story")
    func relicDesignCompleteness() {
        #expect(MPCChapterOneCatalog.relics.allSatisfy {
            !$0.mechanism.isEmpty && !$0.cost.isEmpty && !$0.buildDirection.isEmpty && !$0.story.isEmpty
        })
    }

    @Test("All three AI roles are available")
    func companionRoles() {
        #expect(Set(MPCChapterOneCatalog.companions.map(\.role)) == [.protector, .healer, .construct])
        #expect(MPCChapterOneCatalog.companions.allSatisfy { $0.normalSkillIDs.count == 3 && $0.maxHP > 0 })
        // The final-boss party: protector 诺恩 and the clinic healer 奥黛尔, unlocked before Q28.
        let party = MPCChapterOneCatalog.finalBossPartyIDs.compactMap { id in MPCChapterOneCatalog.companions.first { $0.id == id } }
        #expect(party.map(\.role) == [.protector, .healer])
        #expect(party.last?.name == "奥黛尔·芬" && party.last?.pathName == "诊所医生")
        #expect(party.allSatisfy { $0.unlockStage <= .investigationFour && $0.maxHP > 800 })
    }

    @Test("Story-critical rewards are fixed, not random")
    func fixedStoryRewards() {
        let fixedRewards = Set(MPCChapterOneCatalog.encounters.flatMap(\.fixedRewardItemIDs))
        #expect(fixedRewards.contains("key_thirteenth_recording"))
        #expect(fixedRewards.contains("key_old_clock_attestation"))
        #expect(fixedRewards.contains("key_authority_echo"))
    }
}
