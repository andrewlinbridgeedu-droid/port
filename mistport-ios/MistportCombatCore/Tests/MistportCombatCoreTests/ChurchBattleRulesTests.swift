import Foundation
import Testing
@testable import MistportCombatCore

/// One battle played step by step, keeping every step's events and the session after it.
private struct Trace {
    var steps: [(tick: Int, events: MPCChurchBattleStepper.Events, session: MPCChapterOneEncounterSession)] = []
    var result: MPCChurchBattleDriver.Result
    var log: MPCBattleInputLog
}

private func play(_ encounterID: String, loadout: MPCChapterOneLoadout,
                  policy: (MPCChurchBattleDriver.View) -> [MPCBattleInput] = { _ in [] }) throws -> Trace {
    var stepper = try MPCChurchBattleStepper(encounterID: encounterID, loadout: loadout)
    var steps: [(Int, MPCChurchBattleStepper.Events, MPCChapterOneEncounterSession)] = []
    while !stepper.isFinished {
        let view = stepper.view, tick = stepper.tick
        let events = try stepper.step(view.session.outcome == .inProgress ? policy(view) : [])
        steps.append((tick, events, stepper.session))
    }
    return Trace(steps: steps, result: stepper.result, log: stepper.log)
}

private func floorLoadout(_ number: Int) -> MPCChapterOneLoadout {
    MPCChurchTowerVerificationRunner.recommendedLoadout(for: MPCChurchTowerCatalog.floor(number: number)!)
}

/// Targets the first living enemy that is not guarding and fires the medal when ready,
/// so battles end and enemies die with attacks in flight.
private func aggressive(_ view: MPCChurchBattleDriver.View) -> [MPCBattleInput] {
    var trial = view.session
    var out: [MPCBattleInput] = []
    if let t = trial.enemies.first(where: { $0.isAlive && $0.currentIntent != "guard" }), t.id != view.target {
        out.append(.init(tick: view.tick, kind: .target, enemyID: t.id))
    }
    if trial.activateUsurpedLifeMedal(isOwned: true, at: view.now) { out.append(.init(tick: view.tick, kind: .medal)) }
    return out
}

@Suite("Church battle rules moved in from the App (church-battle-v2)")
struct ChurchBattleRulesTests {
    @Test("the log carries the new rule version and old logs are refused")
    func version() throws {
        #expect(MPCBattleInputLog.currentVersion == "church-battle-v2")
        let old = MPCBattleInputLog(version: "church-battle-v1", encounterID: MPCChurchTowerCatalog.floor(number: 5)!.id, inputs: [])
        #expect(throws: MPCChurchBattleDriver.Failure.version("church-battle-v1")) { try MPCChurchBattleDriver.replay(old, loadout: floorLoadout(5)) }
    }

    @Test("rule 1: a dead enemy's attack never resolves; it is cancelled", arguments: [12, 30, 55, 80])
    func deadEnemiesDoNotHit(number: Int) throws {
        let trace = try play(MPCChurchTowerCatalog.floor(number: number)!.id, loadout: floorLoadout(number), policy: aggressive)
        var before = try MPCChapterOneEncounterSession.start(encounterID: MPCChurchTowerCatalog.floor(number: number)!.id, companionIDs: [], loadout: floorLoadout(number))
        var cancelledDead = 0
        for step in trace.steps {
            for id in step.events.enemyResolved {
                // The resolving enemy was alive when this step began.
                #expect(before.enemies.contains { $0.id == id && $0.isAlive } || step.events.newWave != nil, "floor \(number) tick \(step.tick) \(id)")
            }
            for id in step.events.enemyCancelled where !(step.session.enemies.first { $0.id == id }?.isAlive ?? false) { cancelledDead += 1 }
            before = step.session
        }
        #expect(trace.result.outcome != .inProgress)
        #expect(cancelledDead > 0, "floor \(number): enemies died with attacks in flight")
    }

    @Test("rule 2: a mend or empower whose recipient died is cancelled and the caster acts again")
    func orphanedSupportIsCancelled() throws {
        var cancelledSupport = 0
        for number in 20...30 {
            let floor = MPCChurchTowerCatalog.floor(number: number)!
            guard floor.waves.flatMap({ $0 }).contains(where: { [.backSac, .crown].contains($0.species) }) else { continue }
            let trace = try play(floor.id, loadout: floorLoadout(number))
            var before: MPCChapterOneEncounterSession?
            for step in trace.steps {
                for id in step.events.enemyCancelled {
                    guard let caster = step.session.enemies.first(where: { $0.id == id }), caster.isAlive else { continue }
                    cancelledSupport += 1
                    let intent = before?.enemies.first { $0.id == id }?.currentIntent
                    #expect(intent == "tower_mend" || intent == "tower_empower", "floor \(number) \(id) \(intent ?? "-")")
                }
                before = step.session
            }
        }
        #expect(cancelledSupport > 0, "floors 21–30 lose support recipients mid-cast")
    }

    @Test("rule 3: attacks committed in one wave never resolve in the next")
    func wavesStartClean() throws {
        for number in [15, 40, 70] {
            let trace = try play(MPCChurchTowerCatalog.floor(number: number)!.id, loadout: floorLoadout(number), policy: aggressive)
            var committed = Set<String>(), waves = 0
            for step in trace.steps {
                if step.events.newWave != nil { waves += 1; committed.removeAll() }
                for id in step.events.enemyResolved where step.events.newWave == nil {
                    #expect(committed.contains(id), "floor \(number) tick \(step.tick) \(id) resolved without a same-wave attack")
                    committed.remove(id)
                }
                for attack in step.events.enemyAttacks { committed.insert(attack.enemyID) }
            }
            #expect(waves == MPCChurchTowerCatalog.floor(number: number)!.waves.count - 1 || trace.result.outcome == .defeat)
        }
    }

    @Test("rules 4 and 5: casts land at the authored contact; enemies may act again as soon as they resolve")
    func timings() throws {
        let trace = try play(MPCChurchTowerCatalog.floor(number: 30)!.id, loadout: floorLoadout(30))
        var immediateRepeat = false
        for step in trace.steps {
            if let cast = step.events.cast {
                let expected = Int(((Double(step.tick) * MPCChurchBattleDriver.step + MPCChurchBattleDriver.playerContact(cast.skill))
                                    / MPCChurchBattleDriver.step).rounded(.up))
                #expect(cast.landsAtTick == expected)
            }
            if !Set(step.events.enemyResolved).isDisjoint(with: step.events.enemyAttacks.map(\.enemyID)) { immediateRepeat = true }
        }
        #expect(immediateRepeat, "an enemy that resolves can start its next attack in the same step")
        #expect(abs(MPCChurchBattleDriver.playerContact(.fabricatedEvidence) - 0.5426) < 0.001)
        #expect(MPCChurchBattleDriver.playerContact(.paperDouble) == 0.78)
    }

    @Test("rule 5: skills sealed by the paperweight are flagged, land on time and replay")
    func sealedPaperweight() throws {
        var loadout = floorLoadout(30)
        loadout.relicIDs = ["relic_sealed_paperweight"]
        let trace = try play(MPCChurchTowerCatalog.floor(number: 30)!.id, loadout: loadout)
        #expect(trace.steps.contains { $0.events.cast?.sealed == true })
        let replayed = try MPCChurchBattleDriver.replay(trace.log, loadout: loadout)
        #expect(replayed.ticks == trace.result.ticks && replayed.playerHP == trace.result.playerHP)
    }

    @Test("rule 8: bounty enemies without a tower configuration open 2.4 s + 0.35 s per slot in")
    func bountyOpening() throws {
        let bounty = MPCChurchBountyCatalog.all.first { $0.id == "b07" }!
        let trace = try play(bounty.encounterID, loadout: floorLoadout(30))
        let start = try MPCChapterOneEncounterSession.start(encounterID: bounty.encounterID, companionIDs: [], loadout: floorLoadout(30))
        for (index, enemy) in start.enemies.enumerated() where MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID) == nil {
            let first = trace.steps.first { $0.events.enemyAttacks.contains { $0.enemyID == enemy.id } }?.tick
            let opens = Int(((2.4 + 0.35 * Double(index)) / MPCChurchBattleDriver.step).rounded(.up))
            #expect(first == nil || first! >= opens - 1, "\(enemy.id) first attack \(first ?? -1) before \(opens)")
        }
    }

    @Test("model tuning changes timing but a live replay of a tuned recording is not trusted")
    func tuningIsModelOnly() throws {
        let floor = MPCChurchTowerCatalog.floor(number: 20)!
        let (live, _) = try MPCChurchBattleDriver.record(encounterID: floor.id, loadout: floorLoadout(20)) { _ in [] }
        let (slow, _) = try MPCChurchBattleDriver.record(encounterID: floor.id, loadout: floorLoadout(20),
                                                        tuning: .init(actionDelay: 0.4)) { _ in [] }
        #expect(slow.ticks != live.ticks || slow.playerHP != live.playerHP)
    }

    @Test("a refused input leaves the stepper exactly as it was")
    func refusedStepIsVoid() throws {
        var stepper = try MPCChurchBattleStepper(encounterID: MPCChurchTowerCatalog.floor(number: 5)!.id, loadout: floorLoadout(5))
        for _ in 0..<10 { _ = try stepper.step() }
        let tick = stepper.tick, hp = stepper.session.playerHP
        #expect(throws: MPCChurchBattleDriver.Failure.self) { try stepper.step([.init(tick: 0, kind: .target, enemyID: "nobody")]) }
        #expect(stepper.tick == tick && stepper.session.playerHP == hp && stepper.inputs.isEmpty)
    }
}
