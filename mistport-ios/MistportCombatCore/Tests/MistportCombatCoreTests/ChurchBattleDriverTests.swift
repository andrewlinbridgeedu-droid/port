import Foundation
import Testing
@testable import MistportCombatCore

/// The tower verification runner's choices, expressed as player inputs.
private func runnerPolicy(floors: Int? = nil, medalOffset: Double = 22, salveBelow: Int? = nil) -> (MPCChurchBattleDriver.View) -> [MPCBattleInput] {
    var nextMedalAt = medalOffset
    var ultimateAsked = false
    return { view in
        var out: [MPCBattleInput] = []
        let s = view.session
        // A client only sends inputs the rules accept: try each one on a copy first.
        var trial = s
        let alive = s.enemies.filter(\.isAlive)
        let species = { (e: MPCRuntimeEnemy) in MPCChurchTowerCatalog.enemyConfiguration(contentID: e.contentID)?.species }
        let preferred = alive.first { species($0) == .backSac } ?? alive.first { species($0) == .crown }
            ?? alive.first { $0.contentID.contains("escort") || $0.contentID.contains("life_vessel") }
            ?? alive.first { $0.currentIntent != "guard" } ?? alive.first
        guard let preferred else { return out }
        if preferred.id != view.target { out.append(.init(tick: view.tick, kind: .target, enemyID: preferred.id)) }
        if view.now >= nextMedalAt, preferred.currentIntent != "guard", trial.activateUsurpedLifeMedal(isOwned: true, at: view.now) {
            out.append(.init(tick: view.tick, kind: .medal))
            nextMedalAt = trial.usurpedLifeMedalReadyAt
        }
        if let salveBelow, trial.playerHP < salveBelow, (try? trial.useConsumable("consumable_pain_salve")) != nil {
            out.append(.init(tick: view.tick, kind: .consumable, itemID: "consumable_pain_salve"))
        }
        if let floors, !ultimateAsked, view.loadout.isUltimateUnlocked, s.waveIndex == floors - 1, view.now >= 12, s.canUseFoolSkill(.namelessStage) {
            ultimateAsked = true
            out.append(.init(tick: view.tick, kind: .ultimate))
        }
        return out
    }
}

private func floorLoadout(_ number: Int) -> (MPCChurchTowerCatalog.Floor, MPCChapterOneLoadout) {
    let floor = MPCChurchTowerCatalog.floor(number: number)!
    return (floor, MPCChurchTowerVerificationRunner.recommendedLoadout(for: floor))
}

@Suite("Church battle driver: recorded inputs replay to the same battle")
struct ChurchBattleDriverTests {
    @Test("a recorded tower battle replays to the same outcome, time, HP and item use", arguments: [5, 12, 30])
    func replayMatchesRecording(number: Int) throws {
        let (floor, loadout) = floorLoadout(number)
        let (recorded, log) = try MPCChurchBattleDriver.record(encounterID: floor.id, loadout: loadout,
                                                               consumables: ["consumable_pain_salve": 2],
                                                               policy: runnerPolicy(floors: floor.waves.count, salveBelow: 500))
        let replayed = try MPCChurchBattleDriver.replay(log, loadout: loadout, consumables: ["consumable_pain_salve": 2])
        #expect(recorded.outcome != .inProgress)
        #expect(replayed.outcome == recorded.outcome)
        #expect(replayed.ticks == recorded.ticks)
        #expect(replayed.playerHP == recorded.playerHP)
        #expect(replayed.consumablesUsed == recorded.consumablesUsed)
        #expect(replayed.inputsApplied == log.inputs.count)
        let data = try JSONEncoder().encode(log)
        let decoded = try JSONDecoder().decode(MPCBattleInputLog.self, from: data)
        let again = try MPCChurchBattleDriver.replay(decoded, loadout: loadout, consumables: ["consumable_pain_salve": 2])
        #expect(again.ticks == recorded.ticks && again.playerHP == recorded.playerHP)
    }

    @Test("same model as the tower verification runner used for balance", arguments: [3, 10, 20])
    func matchesVerificationRunner(number: Int) throws {
        let (floor, loadout) = floorLoadout(number)
        let runner = try MPCChurchTowerVerificationRunner.run(number: number)
        let (driver, _) = try MPCChurchBattleDriver.record(encounterID: floor.id, loadout: loadout,
                                                           policy: runnerPolicy(floors: floor.waves.count))
        #expect(driver.outcome == runner.session.outcome)
        #expect(abs(driver.seconds - runner.seconds) <= 1.0)
    }

    @Test("the lights public target is winnable and replays")
    func lightsPublicTarget() throws {
        let (_, loadout) = floorLoadout(10)
        let id = MPCLightsPublicTarget.encounterID(side: .pumps, ticket: "t-1")
        let (recorded, log) = try MPCChurchBattleDriver.record(encounterID: id, loadout: loadout, policy: runnerPolicy())
        #expect(recorded.outcome == .victory)
        let replayed = try MPCChurchBattleDriver.replay(log, loadout: loadout)
        #expect(replayed.outcome == .victory && replayed.ticks == recorded.ticks)
    }

    @Test("a replay uses the loadout it is given, not the one the client played with")
    func serverLoadoutDecides() throws {
        let (floor, strong) = floorLoadout(30)
        let (recorded, log) = try MPCChurchBattleDriver.record(encounterID: floor.id, loadout: strong,
                                                               policy: runnerPolicy(floors: floor.waves.count))
        #expect(recorded.outcome == .victory)
        // The server only holds a floor-1 character: the same inputs do not win for it,
        // or are refused because it has no medal.
        let (_, weak) = floorLoadout(1)
        let replayed = try? MPCChurchBattleDriver.replay(log, loadout: weak)
        #expect(replayed?.outcome != .victory)
    }

    @Test("refused, out-of-order, late and wrong-version logs are rejected")
    func rejectsIllegalLogs() throws {
        let (floor, loadout) = floorLoadout(12)
        let (_, log) = try MPCChurchBattleDriver.record(encounterID: floor.id, loadout: loadout,
                                                        consumables: ["consumable_pain_salve": 1],
                                                        policy: runnerPolicy(floors: floor.waves.count, medalOffset: 2, salveBelow: 10_000))
        let medal = try #require(log.inputs.firstIndex { $0.kind == .medal })

        var doubled = log
        doubled.inputs.insert(.init(tick: log.inputs[medal].tick, kind: .medal), at: medal + 1)
        #expect(throws: MPCChurchBattleDriver.Failure.self) { try MPCChurchBattleDriver.replay(doubled, loadout: loadout, consumables: ["consumable_pain_salve": 1]) }

        var extraSalve = log
        let salve = try #require(log.inputs.firstIndex { $0.kind == .consumable })
        extraSalve.inputs.insert(.init(tick: log.inputs[salve].tick + 20, kind: .consumable, itemID: "consumable_pain_salve"), at: salve + 1)
        extraSalve.inputs.sort { $0.tick < $1.tick }
        #expect(throws: MPCChurchBattleDriver.Failure.self) { try MPCChurchBattleDriver.replay(extraSalve, loadout: loadout, consumables: ["consumable_pain_salve": 1]) }

        var unordered = log
        unordered.inputs = [.init(tick: 40, kind: .medal), .init(tick: 10, kind: .medal)]
        #expect(throws: MPCChurchBattleDriver.Failure.unordered(index: 1)) { try MPCChurchBattleDriver.replay(unordered, loadout: loadout) }

        var late = log
        late.inputs.append(.init(tick: MPCChurchBattleDriver.maxTicks - 1, kind: .medal))
        #expect(throws: MPCChurchBattleDriver.Failure.self) { try MPCChurchBattleDriver.replay(late, loadout: loadout, consumables: ["consumable_pain_salve": 1]) }

        var version = log
        version.version = "church-battle-v0"
        #expect(throws: MPCChurchBattleDriver.Failure.version("church-battle-v0")) { try MPCChurchBattleDriver.replay(version, loadout: loadout) }

        let story = MPCBattleInputLog(encounterID: "chapter01_q05_encounter", inputs: [])
        #expect(throws: MPCChurchBattleDriver.Failure.unsupportedEncounter) { try MPCChurchBattleDriver.replay(story, loadout: loadout) }
    }

    @Test("bounties, city-event, remnant and street battles also record and replay identically")
    func otherChurchBattles() throws {
        let (_, loadout) = floorLoadout(60)
        var ids = MPCChurchBountyCatalog.all.map(\.encounterID)
        ids.append(MPCCityEventCatalog.encounterID(eventID: MPCCityEventCatalog.all[0].id, ticket: "t-1"))
        ids.append(MPCRemnantCatalog.encounterID(caseID: MPCRemnantCatalog.all[0].id, band: 10, ticket: "t-1"))
        for id in ids {
            let (recorded, log) = try MPCChurchBattleDriver.record(encounterID: id, loadout: loadout, policy: runnerPolicy())
            let replayed = try MPCChurchBattleDriver.replay(log, loadout: loadout)
            #expect(recorded.outcome != .inProgress, "\(id)")
            #expect(replayed.outcome == recorded.outcome && replayed.ticks == recorded.ticks && replayed.playerHP == recorded.playerHP, "\(id)")
        }
    }

    @Test("stepping by hand, as the App will, gives the same battle, log and presentation events")
    func stepperMatchesRecording() throws {
        let (floor, loadout) = floorLoadout(12)
        let (recorded, log) = try MPCChurchBattleDriver.record(encounterID: floor.id, loadout: loadout, policy: runnerPolicy(floors: floor.waves.count))
        let policy = runnerPolicy(floors: floor.waves.count)
        var stepper = try MPCChurchBattleStepper(encounterID: floor.id, loadout: loadout)
        var casts: [MPCChurchBattleStepper.Events.Cast] = []
        var landed = 0, attacks = 0, resolved = 0
        while !stepper.isFinished {
            let view = stepper.view, tick = stepper.tick
            let events = try stepper.step(view.session.outcome == .inProgress ? policy(view) : [])
            if let cast = events.cast { #expect(cast.landsAtTick > tick); casts.append(cast) }
            if let hit = events.landed { #expect(casts.contains(hit)); landed += 1 }
            for attack in events.enemyAttacks { #expect(attack.landsAtTick > tick) }
            attacks += events.enemyAttacks.count; resolved += events.enemyResolved.count
        }
        #expect(stepper.result.outcome == recorded.outcome && stepper.result.ticks == recorded.ticks && stepper.log == log)
        #expect(landed > 0 && attacks > 0 && resolved > 0)
        var after = stepper
        #expect(try after.step([.init(tick: 0, kind: .medal)]) == .init(), "a finished battle ignores further steps")
    }

    @Test("with no inputs the battle is still decided by the rules, the same way every time")
    func emptyLogIsDeterministic() throws {
        let (floor, loadout) = floorLoadout(20)
        let log = MPCBattleInputLog(encounterID: floor.id, inputs: [])
        let a = try MPCChurchBattleDriver.replay(log, loadout: loadout)
        let b = try MPCChurchBattleDriver.replay(log, loadout: loadout)
        #expect(a.outcome != .inProgress && a.outcome == b.outcome && a.ticks == b.ticks && a.playerHP == b.playerHP)
    }
}
