import Testing
@testable import MistportCombatCore

@Suite("Chapter one presentation identity")
struct ChapterOneBattleIdentityTests {
    @Test("Executor template has independent art and stable multi-instance contacts")
    func executorTemplate() throws {
        let enemies = ["executor-A", "executor-B"].map { id in
            MPCRuntimeEnemy(id: id, contentID: "enemy_codex_executor", name: "Executor", maxHP: 100, hp: 100, attack: 10, defense: 0, intentPattern: ["attack"], intentIndex: 0, delayedRounds: 0)
        }
        #expect(MPCChapterOneBattleIdentity.visualDescriptor(for: enemies[0].id, in: enemies, encounterID: "chapter01_q17_encounter") == "clock-guard-primary@executor")
        #expect(MPCChapterOneBattleIdentity.visualDescriptor(for: enemies[1].id, in: enemies, encounterID: "chapter01_q24_encounter") == "clock-guard-secondary@executor")
        var changed = enemies
        changed[0].hp = 0
        #expect(MPCChapterOneBattleIdentity.battleID(for: enemies[1].id, in: changed) == "clock-guard-secondary")
        let old = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q06_encounter", companionIDs: [], loadout: .init())
        #expect(MPCChapterOneBattleIdentity.visualDescriptor(for: old.enemies[0].id, in: old.enemies, encounterID: old.encounter.id) == "clock-guard-primary@archivist")
    }
    @Test("Every enemy in missions 1–20 has a distinct identity", arguments: Array(1...20))
    func distinctIdentity(_ number: Int) throws {
        let mission = try #require(MPCChapterOneCatalog.missions.first { $0.number == number })
        let session = try MPCChapterOneEncounterSession.start(encounterID: mission.encounterID, companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        let ids = try session.enemies.map { try #require(MPCChapterOneBattleIdentity.battleID(for: $0.id, in: session.enemies)) }
        #expect(Set(ids).count == session.enemies.count)
    }

    @Test("Death does not rename the surviving leech or core", arguments: [11, 15])
    func stableAfterDeath(_ number: Int) throws {
        let mission = try #require(MPCChapterOneCatalog.missions.first { $0.number == number })
        let session = try MPCChapterOneEncounterSession.start(encounterID: mission.encounterID, companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        var enemies = session.enemies
        let family = number == 11 ? "memory-leech" : "clock-core"
        let siblings = enemies.indices.filter { MPCChapterOneBattleIdentity.family(for: enemies[$0].contentID) == family }
        #expect(siblings.count == 2)
        let survivor = enemies[siblings[1]].id
        #expect(MPCChapterOneBattleIdentity.battleID(for: survivor, in: enemies) == family + "-secondary")
        enemies[siblings[0]].hp = 0
        #expect(MPCChapterOneBattleIdentity.battleID(for: survivor, in: enemies) == family + "-secondary")
    }
    @Test("Story art is scoped without changing stable target IDs", arguments: [6, 7, 9, 10, 12, 13, 14, 19])
    func storyArt(_ number: Int) throws {
        let mission = try #require(MPCChapterOneCatalog.missions.first { $0.number == number })
        let session = try MPCChapterOneEncounterSession.start(encounterID: mission.encounterID, companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        for enemy in session.enemies {
            let id = try #require(MPCChapterOneBattleIdentity.battleID(for: enemy.id, in: session.enemies))
            let art = try #require(MPCChapterOneBattleIdentity.visualDescriptor(for: enemy.id, in: session.enemies, encounterID: mission.encounterID))
            #expect(art.split(separator: "@").first.map(String.init) == id)
            if [9, 12, 14].contains(number), enemy.contentID == "enemy_calibration_puppet" {
                #expect(art == id + "@scribe")
            } else if number == 13, enemy.contentID == "elite_clock_chaser" {
                #expect(art == id + "@rescue")
            } else {
                #expect(!art.contains("@scribe") && !art.contains("@rescue"))
            }
        }
    }
}
