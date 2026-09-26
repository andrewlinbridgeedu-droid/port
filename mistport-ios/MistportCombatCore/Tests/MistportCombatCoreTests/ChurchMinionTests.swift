import Testing
@testable import MistportCombatCore

@Suite("Church five additional minion contracts")
struct ChurchMinionTests {
    let entries: [(MPCChurchTowerCatalog.Species, Int, String)] = [
        (.copperback, 2, "copperback"), (.goldenThroat, 4, "golden-throat"),
        (.crimsonBrute, 8, "crimson-brute"), (.moonfang, 6, "moonfang"), (.veilOracle, 10, "veil-oracle")
    ]
    @Test func introductionRecurrenceBudgetsAndIdentities() throws {
        for (species, first, variant) in entries {
            let floors = MPCChurchTowerCatalog.floors.filter { $0.waves.joined().contains { $0.species == species } }
            #expect(floors.first?.number == first)
            for decade in ((first - 1) / 10)...9 {
                #expect(floors.contains { ($0.number - 1) / 10 == decade })
            }
            for floor in floors {
                for wave in floor.waves.indices {
                    for slot in floor.waves[wave].indices where floor.waves[wave][slot].species == species {
                        let enemy = floor.waves[wave][slot]
                        #expect(!enemy.elite)
                        if floor.number <= 10 {
                            #expect((180...235).contains(enemy.hp))
                            #expect((18...23).contains(enemy.attack))
                        } else {
                            let band = (floor.number - 11) / 10
                            let authoredReplacement = enemy.hp == 600 + (floor.waves.count == 1 ? 140 : 0) && enemy.attack == 45
                            let smallEscort = enemy.hp == 210 + band * 19 && enemy.attack == 20 + band * 2
                            #expect(authoredReplacement || smallEscort)
                        }
                        let id = floor.enemyID(wave: wave, slot: slot)
                        let content = try #require(MPCChurchTowerCatalog.enemyDefinition(id: id))
                        let runtime = MPCRuntimeEnemy(id: id, contentID: id, name: content.name, maxHP: enemy.hp, hp: enemy.hp, attack: enemy.attack, defense: 8, intentPattern: content.intentPattern, intentIndex: 0, delayedRounds: 0)
                        #expect(MPCChapterOneBattleIdentity.visualDescriptor(for: runtime.id, in: [runtime], encounterID: floor.id) == "clock-guard-primary@" + variant)
                    }
                }
            }
        }
        #expect(Set(MPCChurchTowerCatalog.floors.flatMap { $0.waves.flatMap { $0.map(\.species) } }).count == 11)
    }
    @Test func independentDirectContactsAndPreparationGate() throws {
        for (species, floor, _) in entries {
            var session = try MPCChapterOneEncounterSession.start(encounterID: MPCChurchTowerCatalog.floor(number: floor)!.id, companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
            let enemy = try #require(session.enemies.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species == species })
            for step in 0..<5 {
                let hp = session.playerHP
                #expect(session.isChurchHighThreatPreparation(enemyID: enemy.id) == (step == 0 || step == 2))
                if step == 0 || step == 2 {
                    #expect(session.authoredPreparationDuration(for: enemy.id) == (step == 0 ? 2.2 : 2.8))
                }
                if step == 1 || step == 3 {
                    #expect(MPCChurchTowerCatalog.contactDuration(contentID: enemy.contentID, intent: session.enemies.first { $0.id == enemy.id }!.currentIntent) == 0.5)
                }
                try session.endRound(actingEnemyID: enemy.id, at: Double(step))
                #expect(hp - session.playerHP == (step == 1 || step == 3 ? enemy.attack : 0))
            }
        }
    }
}
