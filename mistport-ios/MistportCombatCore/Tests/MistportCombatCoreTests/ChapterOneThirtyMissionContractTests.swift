import Testing
@testable import MistportCombatCore

@Suite("Thirty mission story contract")
struct ChapterOneThirtyMissionContractTests {
    @Test func completeCatalog() throws {
        #expect(MPCChapterOneCatalog.missions.map(\.number) == Array(1...30))
        #expect(MPCChapterOneCatalog.validationErrors().isEmpty)
        for mission in MPCChapterOneCatalog.missions {
            let encounter = try #require(MPCChapterOneCatalog.encounters.first { $0.id == mission.encounterID })
            #expect(encounter.name == mission.name)
            #expect(encounter.companionSlots == 0)
            #expect(MPCChapterOneThirtyMissionContract.actors(for: mission.number).map(\.contentID) == encounter.waves.first?.enemyIDs)
            #expect(encounter.fixedRewardItemIDs == mission.rewardItemIDs)
            #expect(mission.rewardItemIDs == MPCChapterOneThirtyMissionContract.firstClear(for: mission.number)?.itemIDs)
        }
    }

    @Test func fixedEconomyAndProofs() throws {
        let rewards = try (1...30).map { try #require(MPCChapterOneThirtyMissionContract.firstClear(for: $0)) }
        #expect(rewards.map(\.copper).reduce(0, +) == 2280)
        #expect(rewards.map(\.merit).reduce(0, +) == 100)
        #expect(rewards.map(\.talentPoints).reduce(0, +) == 30)
        #expect(rewards.map(\.skillDust).reduce(0, +) == 60)
        #expect(rewards.allSatisfy { $0.experience == 0 })
        let evidence = MPCChapterOneThirtyMissionContract.evidenceByMission.values.flatMap { $0 }
        #expect(evidence.count == 44)
        #expect(Set(evidence).count == 44)
        for id in evidence {
            let item = try #require(MPCChapterOneCatalog.items.first { $0.id == id })
            #expect(item.kind == .keyItem)
            #expect(!item.isTradable)
        }
    }

    @Test func firstClearAndLegacyMigrationNeverDuplicateRewards() throws {
        var fresh = MPCChapterOneCampaignState.chapterStartState
        for mission in MPCChapterOneCatalog.missions {
            let encounter = try #require(MPCChapterOneCatalog.encounters.first { $0.id == mission.encounterID })
            fresh.claimVictory(for: encounter)
            let once = fresh
            fresh.claimVictory(for: encounter)
            #expect(fresh == once)
        }
        #expect(fresh.inventory["currency_copper"] == 2460)
        #expect(fresh.inventory["material_skill_dust"] == 60)
        #expect(fresh.lifetimeChurchMerit == 100)
        #expect(fresh.spendableChurchMerit == 100)
        #expect(fresh.chapterTalentPointsEarned == 30)
        var legacy = MPCChapterOneCampaignState(inventory: ["currency_copper": 387, "material_skill_dust": 12, "consumable_pain_salve": 0])
        let changed = legacy.restoreClaimStoryEvidence(completedMissionNumbers: Set(1...15))
        #expect(changed)
        let migrated = legacy
        let changedAgain = legacy.restoreClaimStoryEvidence(completedMissionNumbers: Set(1...15))
        #expect(!changedAgain)
        for mission in MPCChapterOneCatalog.missions.prefix(15) {
            legacy.claimVictory(for: try #require(MPCChapterOneCatalog.encounters.first { $0.id == mission.encounterID }))
        }
        #expect(legacy == migrated)
        #expect(legacy.inventory["currency_copper"] == 387)
        #expect(legacy.inventory["material_skill_dust"] == 12)
        #expect(legacy.inventory["consumable_pain_salve"] == 0)
        #expect(legacy.lifetimeChurchMerit == 0)
        #expect(legacy.chapterTalentPointsEarned == 0)
        #expect(legacy.inventory["chapter30_e20"] == 1)
    }

    @Test func bossCyclesAndSurvival() {
        let contract = MPCChapterOneThirtyMissionContract.self
        #expect(!contract.objectiveSatisfied(mission: 28, playerAlive: true, enemiesRemaining: 1, bossCyclesCompleted: 4))
        #expect(contract.objectiveSatisfied(mission: 28, playerAlive: true, enemiesRemaining: 1, bossCyclesCompleted: 5))
        #expect(!contract.objectiveSatisfied(mission: 28, playerAlive: false, enemiesRemaining: 1, bossCyclesCompleted: 5))
        #expect(!contract.objectiveSatisfied(mission: 29, playerAlive: true, enemiesRemaining: 0, bossCyclesCompleted: 4, escortsRemaining: 0))
        #expect(!contract.objectiveSatisfied(mission: 29, playerAlive: true, enemiesRemaining: 1, bossCyclesCompleted: 5, escortsRemaining: 1))
        #expect(contract.objectiveSatisfied(mission: 29, playerAlive: true, enemiesRemaining: 0, bossCyclesCompleted: 5, escortsRemaining: 0))
        #expect(!contract.objectiveSatisfied(mission: 30, playerAlive: false, enemiesRemaining: 0, bossDefeated: true))
    }

    @Test func noDeathToFakeEscape() {
        let contract = MPCChapterOneThirtyMissionContract.self
        #expect(!contract.objectiveSatisfied(mission: 20, playerAlive: true, enemiesRemaining: 0))
        #expect(contract.objectiveSatisfied(mission: 20, playerAlive: true, enemiesRemaining: 1, rescueCompleted: true))
        #expect(!contract.objectiveSatisfied(mission: 25, playerAlive: true, enemiesRemaining: 0))
        #expect(contract.objectiveSatisfied(mission: 25, playerAlive: true, enemiesRemaining: 1, voluntaryContractSevered: true))
        #expect(contract.actors(for: 3).first?.entityID == contract.actors(for: 16).first?.entityID)
        #expect(contract.actors(for: 20).first?.entityID == contract.actors(for: 26).first?.entityID)
        #expect(contract.actors(for: 17).first?.entityID != contract.actors(for: 29).dropFirst().first?.entityID)
        #expect(Set([28, 29, 30].compactMap { contract.actors(for: $0).first?.entityID }) == ["BOSS01"])
        #expect(MPCChapterOneBattleIdentity.supportsUnity(encounterID: "chapter01_q30_encounter"))
        #expect(!MPCChapterOneBattleIdentity.supportsUnity(encounterID: "chapter01_q31_encounter"))
    }
}
