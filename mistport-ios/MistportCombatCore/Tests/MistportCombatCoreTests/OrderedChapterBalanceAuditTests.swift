import Foundation
import Testing
@testable import MistportCombatCore

@Suite(.serialized)
struct OrderedChapterBalanceAuditTests {
    @Test func productionAudit() throws {
        guard let output = ProcessInfo.processInfo.environment["MISTPORT_ORDER_AUDIT"] else { return }
        func permutations(_ cards: [FoolSkillID]) -> [[FoolSkillID]] {
            guard cards.count > 1 else { return [cards] }
            return cards.flatMap { first in permutations(cards.filter { $0 != first }).map { [first] + $0 } }
        }
        let families: [[FoolSkillID]] = [
            [.stolenTempo, .mirrorBarrage, .sidestepStrike, .fabricatedEvidence],
            [.stolenTempo, .mirrorBarrage, .identityDisplacement, .absurdFinale],
            [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .absurdFinale],
            [.stolenTempo, .delayedSignature, .mirrorBarrage, .backstageChange],
            [.turnTheTables, .mirrorPursuit, .absurdFinale, .backstageChange],
            [.stolenTempo, .sidestepStrike, .backstageChange, .mirrorBarrage],
            [.fabricatedEvidence, .identityDisplacement, .absurdFinale, .backstageChange]
        ]
        let missions = (ProcessInfo.processInfo.environment["MISTPORT_ORDER_MISSIONS"] ?? "4,8,12,18,30").split(separator: ",").compactMap { Int($0) }
        var rows: [[String: Any]] = []
        for q in missions {
            let available = MPCOrderedSkillRules.ordinarySkills.filter { (MPCOrderedSkillRules.unlockMission($0) ?? 99) <= q }
            var tried = Set<String>()
            var wins: [[String: Any]] = [], losses: [[String: Any]] = []
            for family in families {
                var deck = family.filter { available.contains($0) }
                deck += available.filter { !deck.contains($0) }.prefix(max(0, min(4, available.count) - deck.count))
                for order in permutations(deck) {
                    let key = order.map(\.rawValue).joined(separator: ",")
                    guard tried.insert(key).inserted else { continue }
                    var loadout = MPCChapterOneLoadout(normalSkillIDs: order, isUltimateUnlocked: q >= 14, passiveIDs: [], relicIDs: [])
                    loadout.churchGear = EarnedChapterAuditFixture.wallGear(beforeOrAt: q)
                    loadout.bountyRelicID = EarnedChapterAuditFixture.wallRelic(q)
                    loadout.selectedActiveRelicID = q <= 4 ? MPCChapterOneCatalog.ownerlessMaskRelicID : MPCChapterOneCatalog.usurpedLifeMedalRelicID
                    if q >= 5 { loadout.relicIDs = [MPCChapterOneCatalog.returnGiftClaspRelicID] }
                    let budget = (1..<q).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for: $0)?.talentPoints }.reduce(0, +)
                    loadout.talents = .restored((0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" }, budget: budget)
                    if q >= 10 { loadout.skillLevels[.mirrorPursuit] = 2 }
                    if q >= 15 { loadout.skillLevels[.absurdFinale] = 2 }
                    var game = try MPCStoryBattleStepper(encounterID: String(format: "chapter01_q%02d_encounter", q), loadout: loadout,
                        companionIDs: q >= 28 ? MPCChapterOneCatalog.finalBossPartyIDs : [], mask: .init(owned: true, teachingLoan: q <= 4))
                    var requestedUltimate = false
                    while !game.isFinished {
                        let view = game.view
                        var inputs: [MPCBattleInput] = []
                        var trial = view.session
                        let imminentHeavy = view.session.enemies.contains { enemy in
                            guard let deadline = view.incoming[enemy.id], deadline - view.tick <= 6 else { return false }
                            if q == 3 { return enemy.currentIntent == "memory_breath" }
                            return q != 4 || enemy.currentIntent == "q4_flame_first" || enemy.currentIntent == "q4_flame_second"
                        }
                        if !view.session.playerIsDown, view.session.outcome == .inProgress, game.maskIsReady(at: view.now), imminentHeavy {
                            inputs.append(.init(tick: view.tick, kind: .mask))
                        }
                        if q >= 5, view.session.outcome == .inProgress, view.now >= 6,
                           trial.activateUsurpedLifeMedal(isOwned: true, at: view.now) { inputs.append(.init(tick: view.tick, kind: .medal)) }
                        if q >= 14, !requestedUltimate, view.session.outcome == .inProgress, !view.session.playerIsDown, !view.session.foolUltimateUsed, view.now >= 1 {
                            inputs.append(.init(tick: view.tick, kind: .ultimate)); requestedUltimate = true
                        }
                        do { _ = try game.step(inputs) }
                        catch MPCChurchBattleDriver.Failure.refused { _ = try game.step() }
                    }
                    let result: [String: Any] = ["order": order.map(\.rawValue), "hp": game.session.playerHP,
                        "ticks": game.tick, "remaining": game.session.enemies.reduce(0) { $0 + $1.hp }]
                    if game.session.outcome == .victory { wins.append(result) } else { losses.append(result) }
                }
            }
            #expect(!wins.isEmpty, "Q\(q) needs an earned winning arrangement")
            rows.append(["mission": q, "tested": tried.count, "wins": wins, "losses": losses])
            print("ORDER_AUDIT Q\(q) wins=\(wins.count)/\(tried.count)")
            let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: output))
        }
    }
}
