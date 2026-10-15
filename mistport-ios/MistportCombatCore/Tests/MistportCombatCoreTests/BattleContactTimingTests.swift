import Testing
@testable import MistportCombatCore

@Suite("Shared watched and skipped contact timing")
struct BattleContactTimingTests {
    @Test func sameContentIDKeepsItsEncounterSpecificChoreography() {
        let scribe = MPCBattleContactTiming.enemyContact(contentID: "enemy_calibration_puppet", intent: "attack", encounterID: "chapter01_q12_encounter")
        let archivist = MPCBattleContactTiming.enemyContact(contentID: "enemy_calibration_puppet", intent: "attack", encounterID: "chapter01_q10_encounter")
        #expect(scribe == 1)
        #expect(archivist == 2.05)
        #expect(MPCBattleContactTiming.enemyContact(contentID: "enemy_archive_gatekeeper", intent: "archive_slam", encounterID: "chapter01_q06_encounter") == archivist)
    }

    @Test func ghostSplitDoesNotChangeTheSharedSpellDeadline() {
        let original = MPCBattleContactTiming.enemyContact(contentID: "enemy_resonant_clock_guard_q2", intent: "attack", encounterID: "chapter01_q02_encounter")
        let split = MPCBattleContactTiming.enemyContact(contentID: "enemy_resonant_clock_guard_q2_split", intent: "attack", encounterID: "chapter01_q02_encounter")
        #expect(original == 0.9)
        #expect(split == original)
    }

    @Test func coreRepairAndAttackRetainDifferentCommittedDeadlines() {
        let repair = MPCBattleContactTiming.enemyContact(contentID: "enemy_memory_leech_node", intent: "repair_guard", encounterID: "chapter01_q07_encounter")
        let strike = MPCBattleContactTiming.enemyContact(contentID: "enemy_memory_leech_node", intent: "attack", encounterID: "chapter01_q07_encounter")
        #expect(repair == 0.85)
        #expect(strike == 0.82)
    }

    @Test func everyTowerWaveUsesTheSameAuthoredContactContract() {
        for floor in MPCChurchTowerCatalog.floors {
            for wave in floor.waves.indices {
                for slot in floor.waves[wave].indices {
                    let contentID = floor.enemyID(wave: wave, slot: slot)
                    for intent in ["tower_cut_first", "tower_cut_second", "tower_mend", "tower_empower", "tower_strike"] {
                        let contact = MPCBattleContactTiming.enemyContact(contentID: contentID, intent: intent, encounterID: floor.id)
                        #expect(contact == MPCChurchTowerCatalog.contactDuration(contentID: contentID, intent: intent))
                        #expect(contact.isFinite && contact > 0)
                    }
                }
            }
        }
    }

    @Test func playerCardsShareTheExistingServerContactContract() {
        for skill in MPCChapterOneCatalog.visibleSkills.map(\.id) {
            #expect(MPCBattleContactTiming.playerContact(skill) == MPCChurchBattleDriver.playerContact(skill))
        }
        #expect(MPCBattleContactTiming.playerContact(nil) == 0.58)
    }

    /// This proves batching preserves a complete rules-engine snapshot. The App
    /// adapter still needs its own device check: it has separate presentation state.
    @Test("a mid-battle snapshot settles identically one tick or 200 ticks at a time", arguments: [false, true])
    func batchingPreservesAnInFlightBattle(expectDefeat: Bool) throws {
        let firstFloor = try #require(MPCChurchTowerCatalog.floor(number: 1))
        let floor = try #require(MPCChurchTowerCatalog.floor(number: expectDefeat ? 100 : 1))
        let loadout = MPCChurchTowerVerificationRunner.recommendedLoadout(for: firstFloor)
        var snapshot = try MPCChurchBattleStepper(encounterID: floor.id, loadout: loadout)
        let target = try #require(snapshot.session.enemies.first?.id)
        _ = try snapshot.step([.init(tick: 0, kind: .target, enemyID: target)])
        // A quarter-second prefix leaves a committed player impact and active
        // cooldowns in flight; a new battle/replayed loadout would lose both.
        for _ in 0..<5 { _ = try snapshot.step() }
        #expect(snapshot.tick == 6)
        #expect(!snapshot.isFinished)
        var watched = snapshot
        var skipped = snapshot
        var watchedEvents: [MPCChurchBattleStepper.Events] = []
        var skippedEvents: [MPCChurchBattleStepper.Events] = []
        while !watched.isFinished { watchedEvents.append(try watched.step()) }
        while !skipped.isFinished {
            for _ in 0..<200 {
                guard !skipped.isFinished else { break }
                skippedEvents.append(try skipped.step())
            }
        }
        #expect(watched.session.outcome == (expectDefeat ? .defeat : .victory))
        #expect(skipped.session == watched.session)
        #expect(skipped.tick == watched.tick)
        #expect(skipped.log == watched.log)
        #expect(skipped.consumablesUsed == watched.consumablesUsed)
        #expect(skippedEvents == watchedEvents)
    }
}
