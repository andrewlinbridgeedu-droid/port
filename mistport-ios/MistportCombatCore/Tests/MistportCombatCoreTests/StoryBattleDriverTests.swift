import Foundation
import Testing
@testable import MistportCombatCore

/// Cards unlocked by mission `q` (the last four), a tower-floor gear set and the ultimate from Q14.
private func storyLoadout(_ q: Int) -> MPCChapterOneLoadout {
    let cards = MPCChapterOneCatalog.missions.filter { $0.number <= q }.flatMap(\.permanentSkillIDs)
        .filter { $0 != .namelessStage && $0 != .backstageChange }
    var seen = Set<FoolSkillID>()
    let unique = cards.filter { seen.insert($0).inserted }
    let floor = MPCChurchTowerCatalog.floor(number: min(100, max(1, q * 3)))!
    var loadout = MPCChurchTowerVerificationRunner.recommendedLoadout(for: floor)
    loadout.normalSkillIDs = Array(unique.suffix(4))
    loadout.isUltimateUnlocked = q >= 14
    if q < 5 { loadout.selectedActiveRelicID = nil }
    return loadout
}

/// Targets the first living enemy, raises the mask before hits, drinks a salve when low.
private func storyPolicy(_ stepper: MPCStoryBattleStepper) -> [MPCBattleInput] {
    let view = stepper.view
    var trial = view.session
    var out: [MPCBattleInput] = []
    if let t = trial.enemies.first(where: \.isAlive), t.id != view.target { out.append(.init(tick: view.tick, kind: .target, enemyID: t.id)) }
    if stepper.maskIsReady(at: view.now), view.incoming.values.contains(where: { $0 - view.tick <= 6 }) {
        out.append(.init(tick: view.tick, kind: .mask))
    }
    if trial.activateUsurpedLifeMedal(isOwned: true, at: view.now) { out.append(.init(tick: view.tick, kind: .medal)) }
    if trial.playerHP < 400, (try? trial.useConsumable("consumable_pain_salve")) != nil {
        out.append(.init(tick: view.tick, kind: .consumable, itemID: "consumable_pain_salve"))
    }
    return out
}

private func record(_ q: Int, mask: MPCStoryBattleStepper.Mask? = .init(owned: true), activeRelic: String?? = .none) throws -> (MPCStoryBattleStepper, [MPCStoryBattleStepper.Events]) {
    var loadout = storyLoadout(q)
    if case .some(let relic) = activeRelic { loadout.selectedActiveRelicID = relic }
    var stepper = try MPCStoryBattleStepper(encounterID: String(format: "chapter01_q%02d_encounter", q), loadout: loadout,
                                            consumables: ["consumable_pain_salve": 2], mask: mask)
    var events: [MPCStoryBattleStepper.Events] = []
    while !stepper.isFinished {
        let inputs = stepper.view.session.outcome == .inProgress ? storyPolicy(stepper) : []
        do { events.append(try stepper.step(inputs)) }
        catch MPCChurchBattleDriver.Failure.refused { events.append(try stepper.step()) }
    }
    return (stepper, events)
}

@Suite("Story battles Q1–Q30: recorded inputs replay on the server")
struct StoryBattleDriverTests {
    @Test("every chapter-one mission records and replays to the same battle", arguments: Array(1...30))
    func replayMatches(q: Int) throws {
        let (played, _) = try record(q)
        #expect(played.result.outcome != .inProgress, "Q\(q) never ended")
        let (replayed, cracks) = try MPCChurchBattleDriver.replayStory(played.log, loadout: storyLoadout(q),
                                                                       consumables: ["consumable_pain_salve": 2], mask: .init(owned: true))
        #expect(replayed.outcome == played.result.outcome && replayed.ticks == played.result.ticks
                && replayed.playerHP == played.result.playerHP && replayed.consumablesUsed == played.result.consumablesUsed, "Q\(q)")
        #expect(cracks == played.maskCracksAdded)
        #expect(played.log.version == MPCBattleInputLog.storyVersion)
    }

    @Test("the chapter is winnable with these loadouts")
    func mostMissionsAreWon() throws {
        let wins = try (1...30).filter { try record($0).0.result.outcome == .victory }
        #expect(wins.count >= 20, "won \(wins)")
    }

    @Test("Q1: three basic attacks, then Mara intervenes and the trial card joins the loop")
    func q1Intervention() throws {
        let (played, events) = try record(1)
        let at = try #require(events.firstIndex { $0.intervention })
        let before = events[..<at].compactMap(\.cast)
        #expect(before.count >= 3 && before.allSatisfy { $0.skill == nil }, "only basic attacks before Mara")
        #expect(events[at...].contains { $0.cast?.skill == .sidestepStrike })
        #expect(played.session.loadout.normalSkillIDs.contains(.sidestepStrike))
    }

    @Test("the mask adds a lifetime crack per use unless lent for teaching, and is refused at ten")
    func maskCracks() throws {
        // The mask is the manual relic only when it, not the medal, is the active relic.
        let (owned, _) = try record(12, mask: .init(owned: true, cracks: 0), activeRelic: .some(MPCChapterOneCatalog.ownerlessMaskRelicID))
        #expect(owned.maskUses > 0 && owned.maskCracksAdded == owned.maskUses)
        let (lent, _) = try record(3, mask: .init(owned: true, teachingLoan: true))
        #expect(lent.maskUses > 0 && lent.maskCracksAdded == 0)
        var broken = try MPCStoryBattleStepper(encounterID: "chapter01_q12_encounter", loadout: storyLoadout(12), mask: .init(owned: true, cracks: 10))
        #expect(throws: MPCChurchBattleDriver.Failure.self) { try broken.step([.init(tick: 0, kind: .mask)]) }
        var none = try MPCStoryBattleStepper(encounterID: "chapter01_q12_encounter", loadout: storyLoadout(12))
        #expect(throws: MPCChurchBattleDriver.Failure.self) { try none.step([.init(tick: 0, kind: .mask)]) }
    }

    @Test("the loop can be reordered with owned cards only")
    func sequenceInput() throws {
        let loadout = storyLoadout(12)
        var stepper = try MPCStoryBattleStepper(encounterID: "chapter01_q12_encounter", loadout: loadout)
        let reversed = loadout.normalSkillIDs.reversed().map(\.rawValue).joined(separator: ",")
        _ = try stepper.step([.init(tick: 0, kind: .sequence, itemID: reversed)])
        #expect(stepper.session.loadout.normalSkillIDs == Array(loadout.normalSkillIDs.reversed()))
        #expect(throws: MPCChurchBattleDriver.Failure.self) {
            try stepper.step([.init(tick: 0, kind: .sequence, itemID: FoolSkillID.namelessStage.rawValue)])
        }
    }

    @Test("story and church logs are not interchangeable")
    func versions() throws {
        let (played, _) = try record(5)
        var wrong = played.log
        wrong.version = MPCBattleInputLog.currentVersion
        #expect(throws: MPCChurchBattleDriver.Failure.version(MPCBattleInputLog.currentVersion)) {
            try MPCChurchBattleDriver.replayStory(wrong, loadout: storyLoadout(5))
        }
        #expect(throws: MPCChurchBattleDriver.Failure.unsupportedEncounter) {
            try MPCStoryBattleStepper(encounterID: MPCChurchTowerCatalog.floor(number: 1)!.id, loadout: storyLoadout(5))
        }
        #expect(throws: MPCChurchBattleDriver.Failure.self) {
            var church = try MPCChurchBattleStepper(encounterID: MPCChurchTowerCatalog.floor(number: 5)!.id, loadout: storyLoadout(5))
            _ = try church.step([.init(tick: 0, kind: .mask)])
        }
    }

    @Test("the encore bell is not in the enabled relic set yet, so ringing it is refused")
    func encoreBellIsOff() throws {
        var loadout = storyLoadout(5)
        loadout.relicIDs = ["relic_encore_bell"]
        var stepper = try MPCStoryBattleStepper(encounterID: "chapter01_q05_encounter", loadout: loadout)
        #expect(!stepper.session.canUseEncoreBell)
        var refused = 0
        while !stepper.isFinished && stepper.tick < 400 {
            let view = stepper.view
            if view.session.enemies.contains(where: { $0.isAlive && $0.currentIntent == "charge" && view.incoming[$0.id] != nil }) {
                do { _ = try stepper.step([.init(tick: view.tick, kind: .bell)]) } catch { refused += 1; _ = try stepper.step() }
            } else { _ = try stepper.step() }
        }
        #expect(refused > 0, "Q5's revenant charges, and every ring is refused")
    }
}
