import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Four-slot real-time skill rules")
struct OrderedSkillRulesTests {
    private func session(_ cards: [FoolSkillID]) throws -> MPCChapterOneEncounterSession {
        try .start(encounterID: "chapter01_q11_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: cards, isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
    }

    @discardableResult
    private func cast(_ skill: FoolSkillID, at now: Double, in s: inout MPCChapterOneEncounterSession) throws -> MPCFoolSkillEncounterResolution {
        _ = s.advanceRelicClock(at: now)
        let target = try #require(s.enemies.first(where: \.isAlive)?.id)
        let prepared = s.prepareOrderedSkill(skill, targetID: target, at: now)
        let timing = try #require(prepared)
        _ = s.advanceRelicClock(at: timing.firstImpactAt)
        return try s.useFoolSkill(skill, targetID: target)
    }

    @Test func speedExpiresDuringWorkAndNeverShortensCooldown() {
        #expect(abs(MPCOrderedSkillRules.finishWork(start: 3, work: 1, hasteUntil: 3.2) - 3.8) < 0.000_001)
        #expect(MPCOrderedSkillRules.ordinarySkills.allSatisfy { ContinuousSkillScheduler.duration(for: $0) == 7 })
    }

    @Test func hasteReallyDoublesBarrageContacts() throws {
        var normal = try session([.mirrorBarrage])
        _ = try cast(.mirrorBarrage, at: 0, in: &normal)
        _ = normal.advanceRelicClock(at: 1.8)
        #expect(normal.drainOrderedSkillImpacts().count + 1 == 3)
        var fast = try session([.stolenTempo, .mirrorBarrage])
        _ = try cast(.stolenTempo, at: 0, in: &fast)
        let begin = fast.orderedCastReadyAt
        _ = try cast(.mirrorBarrage, at: begin, in: &fast)
        _ = fast.advanceRelicClock(at: begin + 1.8)
        #expect(fast.drainOrderedSkillImpacts().count + 1 == 6)
    }

    @Test func sameFourCardsHaveDifferentDamageWhenReordered() throws {
        let cards: [FoolSkillID] = [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .absurdFinale]
        func damage(_ order: [FoolSkillID]) throws -> Int {
            var s = try session(order)
            var now = 0.0, damage = 0
            for skill in order {
                damage += try cast(skill, at: now, in: &s).targets.reduce(0) { $0 + $1.damage }
                now = s.orderedCastReadyAt
                _ = s.advanceRelicClock(at: now)
                damage += s.drainOrderedSkillImpacts().flatMap(\.targets).reduce(0) { $0 + $1.damage }
            }
            return damage
        }
        let ordered = try damage(cards), scrambled = try damage([.absurdFinale, .mirrorPursuit, .identityDisplacement, .fabricatedEvidence])
        #expect(ordered > scrambled * 3, "ordered \(ordered), scrambled \(scrambled)")
    }

    @Test func expiredIllusionCannotConvertAndRewriteCannotReviveIt() throws {
        var s = try session([.fabricatedEvidence, .backstageChange, .identityDisplacement])
        _ = try cast(.fabricatedEvidence, at: 0, in: &s)
        _ = try cast(.backstageChange, at: 5, in: &s)
        _ = try cast(.identityDisplacement, at: 6, in: &s)
        #expect(s.foolStates.values.allSatisfy { $0.misalignmentStacks == 0 })
    }

    @Test func signatureCountsActualSubsequentHits() throws {
        var s = try session([.stolenTempo, .delayedSignature, .mirrorBarrage])
        _ = try cast(.stolenTempo, at: 0, in: &s)
        _ = try cast(.delayedSignature, at: s.orderedCastReadyAt, in: &s)
        _ = try cast(.mirrorBarrage, at: s.orderedCastReadyAt, in: &s)
        _ = s.advanceRelicClock(at: 5)
        #expect(s.triggeredEffects.contains("附言：兑现6次命中"))
    }

    @Test func eligibilityMigrationPreservesPlayerPropertyAndOrder() {
        var s = MPCChapterOneCampaignState.chapterStartState
        s.inventory["currency_copper"] = 347
        s.loadout.normalSkillIDs = [.sidestepStrike, .fabricatedEvidence]
        s.unlockedSkillIDs = [.sidestepStrike, .fabricatedEvidence]
        let originalInventory = s.inventory, originalRelics = s.ownedRelicIDs
        s.unlockOrderedSkills(availableThrough: 12)
        #expect(s.unlockedSkillIDs.filter(\.isOrderedOrdinary).count == 10)
        #expect(s.loadoutSlotCapacity == 4 && s.loadout.normalSkillIDs.count == 4)
        #expect(s.loadout.normalSkillIDs.prefix(2) == [.sidestepStrike, .fabricatedEvidence])
        #expect(s.inventory == originalInventory && s.ownedRelicIDs == originalRelics && s.completedMissionIDs.isEmpty)
        let once = s
        s.unlockOrderedSkills(availableThrough: 12)
        #expect(s == once)
    }
    @Test func laterBarrageContactsKeepTheCastsAlternationBonus() throws {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [.stolenTempo, .mirrorBarrage], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        loadout.talents = .restored(["trickery.0", "trickery.1", "trickery.2"], budget: 3)
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q11_encounter", companionIDs: [], loadout: loadout)
        _ = try cast(.stolenTempo, at: 0, in: &s)
        let start = s.orderedCastReadyAt
        let first = try cast(.mirrorBarrage, at: start, in: &s).damage
        _ = s.advanceRelicClock(at: start + 1.8)
        let later = s.drainOrderedSkillImpacts().flatMap(\.targets).map(\.damage)
        #expect(later.count == 5 && later.allSatisfy { $0 == first })
    }

    @Test func movingAReadyCardStartsAFullCooldownButNoopDoesNot() {
        var scheduler = ContinuousSkillScheduler()
        let original: [FoolSkillID] = [.stolenTempo, .mirrorBarrage, .delayedSignature, .sidestepStrike]
        scheduler.didCast(.stolenTempo, at: 0)
        #expect(scheduler.didReorder(from: original, to: original, at: 6.95).isEmpty)
        #expect(scheduler.readyAt[.stolenTempo] == 7)
        var reordered = original; reordered.swapAt(0, 1)
        #expect(scheduler.didReorder(from: original, to: reordered, at: 6.95) == [.stolenTempo, .mirrorBarrage])
        #expect(abs((scheduler.readyAt[.stolenTempo] ?? 0) - 13.95) < 0.00001)
        #expect(scheduler.next(in: reordered, at: 7) == nil)
    }

    @Test func hasteEndingMidChannelDoesNotGrantSixInstantHits() throws {
        var s = try session([.stolenTempo, .mirrorBarrage])
        _ = try cast(.stolenTempo, at: 0, in: &s)
        let begin = s.orderedHasteUntil - 0.31
        _ = try cast(.mirrorBarrage, at: begin, in: &s)
        _ = s.advanceRelicClock(at: begin + 1.8)
        #expect(s.drainOrderedSkillImpacts().count + 1 == 3)
    }

    @Test func swappingHasteAndBarrageChangesARealMissionOutcome() throws {
        func play(_ order: [FoolSkillID]) throws -> MPCEncounterOutcome {
            var loadout = MPCChapterOneLoadout(normalSkillIDs: order, isUltimateUnlocked: false, passiveIDs: [], relicIDs: [MPCChapterOneCatalog.returnGiftClaspRelicID])
            loadout.churchGear = EarnedChapterAuditFixture.wallGear(beforeOrAt: 12)
            loadout.bountyRelicID = EarnedChapterAuditFixture.wallRelic(12)
            loadout.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID
            let budget = (1..<12).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for: $0)?.talentPoints }.reduce(0, +)
            loadout.talents = .restored((0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" }, budget: budget)
            var game = try MPCStoryBattleStepper(encounterID: "chapter01_q12_encounter", loadout: loadout)
            while !game.isFinished {
                var trial = game.view.session
                let input: [MPCBattleInput] = game.now >= 6 && trial.outcome == .inProgress && trial.activateUsurpedLifeMedal(isOwned: true, at: game.now)
                    ? [.init(tick: game.tick, kind: .medal)] : []
                _ = try game.step(input)
            }
            return game.session.outcome
        }
        #expect(try play([.stolenTempo, .mirrorBarrage, .sidestepStrike, .fabricatedEvidence]) == .victory)
        #expect(try play([.mirrorBarrage, .stolenTempo, .sidestepStrike, .fabricatedEvidence]) == .defeat)
    }

    @Test func delayedDamageCannotLeakIntoTheNextWave() throws {
        let floor = try #require(MPCChurchTowerCatalog.floors.first { $0.waves.count > 1 })
        var s = try MPCChapterOneEncounterSession.start(encounterID: floor.id, companionIDs: [],
            loadout: .init(normalSkillIDs: [.delayedSignature], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        _ = try cast(.delayedSignature, at: 0, in: &s)
        for enemy in s.enemies where enemy.isAlive {
            // Keep this fixture focused on wave ownership rather than true-shield rules.
            try s.endRound(actingEnemyID: enemy.id, at: 0.6)
            _ = try s.applyPartyDamage(1_000_000, to: enemy.id)
        }
        _ = s.advanceRelicClock(at: 1.8)
        try #require(s.waveIndex == 1)
        let health = s.enemies.map(\.hp)
        _ = s.advanceRelicClock(at: 4)
        #expect(s.enemies.map(\.hp) == health)
        #expect(s.drainOrderedSkillImpacts().isEmpty)
    }

}


extension OrderedSkillRulesTests {
    @Test("The stronger Q2 ghosts still reward the legal two-card set-up order")
    func strongerGhostsRewardSetUpOrder() throws {
        func play(_ order: [FoolSkillID]) throws -> MPCStoryBattleStepper {
            var game = try MPCStoryBattleStepper(encounterID: "chapter01_q02_encounter",
                loadout: .init(normalSkillIDs: order), mask: .init(owned: false))
            while !game.isFinished { _ = try game.step() }
            return game
        }
        let setUp = try play([.fabricatedEvidence, .sidestepStrike])
        let reversed = try play([.sidestepStrike, .fabricatedEvidence])
        #expect(setUp.session.outcome == .victory)
        #expect(reversed.session.outcome == .defeat || setUp.tick < reversed.tick)
        print("Q2_EARLY setUp=\(setUp.session.outcome) hp=\(setUp.session.playerHP) seconds=\(setUp.now); reversed=\(reversed.session.outcome) hp=\(reversed.session.playerHP) seconds=\(reversed.now)")
    }
}
