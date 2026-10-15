import Foundation
import Testing
@testable import MistportCombatCore

@Suite struct CombatCounterTests {
    @Test func oneOpportunityExpiresAndCannotStackOrRefreshItself() {
        var c = MPCCombatCounter()
        let counterCheck1 = c.offer(at: 1)
        #expect(counterCheck1)
        let counterCheck2 = !c.offer(at: 1.65) && c.availableUntil == 4
        #expect(counterCheck2)
        let counterCheck3 = !c.request(at: 4)
        #expect(counterCheck3)
        let counterCheck4 = c.offer(at: 19)
        #expect(counterCheck4)
        let counterCheck5 = c.request(at: 19.1)
        #expect(counterCheck5)
        let counterCheck6 = !c.request(at: 19.1) && !c.offer(at: 19.1)
        #expect(counterCheck6)
        let counterCheck7 = c.activate(at: 20)
        #expect(counterCheck7)
        let counterCheck8 = !c.activate(at: 20) && c.isActive(at: 22.99) && !c.isActive(at: 23)
        #expect(counterCheck8)
        let counterCheck9 = !c.offer(at: 23) && c.offer(at: 37)
        #expect(counterCheck9)
        c.clearWindow()
        #expect(!c.isAvailable(at: 37) && !c.queued && !c.isActive(at: 37))
    }

    @Test func restartPreservesMaskUltimateAndDragPenalty() {
        var scheduler = ContinuousSkillScheduler()
        let cards: [FoolSkillID] = [.fabricatedEvidence, .sidestepStrike]
        for card in cards + [.maskedWhisper, .namelessStage] { scheduler.didCast(card, at: 1) }
        let mask = scheduler.readyAt[.maskedWhisper], ultimate = scheduler.readyAt[.namelessStage]
        scheduler.restartForCounter(sequence: cards + [.maskedWhisper, .namelessStage], at: 2)
        #expect(scheduler.next(in: cards, at: 2) == cards[0])
        #expect(scheduler.readyAt[.maskedWhisper] == mask && scheduler.readyAt[.namelessStage] == ultimate)
        scheduler.didReorder(from: cards, to: Array(cards.reversed()), at: 2)
        #expect(scheduler.next(in: Array(cards.reversed()), at: 8.95) == nil)
        #expect(scheduler.next(in: Array(cards.reversed()), at: 9) == cards[1])
    }

    @Test("Later heavy attacks use the same opportunity; plain hits and Q3 do not", arguments: [6, 13, 30])
    func laterEncounter(q: Int) throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: String(format: "chapter01_q%02d_encounter", q),
            companionIDs: [], loadout: .init(normalSkillIDs: [.fabricatedEvidence, .sidestepStrike]))
        let id = s.enemies[0].id
        var time = 0.0
        while !MPCCombatCounter.isHeavy(s.enemies[0].currentIntent) {
            s.grantPlayerShield(s.playerMaxHP)
            try s.endRound(actingEnemyID: id, at: time)
            #expect(!s.canRequestCounter)
            time += 1
            try #require(time < 10)
        }
        _ = try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: time)
        try s.endRound(actingEnemyID: id, at: time + 0.1)
        #expect(s.canRequestCounter)
        let counterCheck10 = s.requestCounter(at: time + 0.2)
        #expect(counterCheck10)
        let counterCheck11 = s.activateCounter(at: time + 0.3)
        #expect(counterCheck11)
        #expect(s.isCounterActive)
        s.finishRelicBattle()
        #expect(!s.canRequestCounter && !s.counter.queued && !s.isCounterActive)
    }

    @Test func q3NeverGrantsCounter() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q03_encounter",
            companionIDs: [], loadout: .init(normalSkillIDs: [.fabricatedEvidence, .sidestepStrike]))
        let id = s.enemies[0].id
        _ = try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: 2.1)
        try s.endRound(actingEnemyID: id, at: 3.1)
        try s.endRound(actingEnemyID: id, at: 4.5)
        let counterCheck12 = !s.canRequestCounter && !s.requestCounter(at: 4.6)
        #expect(counterCheck12)
    }

    @Test func deferredStampDoesNotApplyCounterBonusTwice() throws {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [.fabricatedEvidence, .sidestepStrike],
            relicIDs: ["relic_deferred_stamp"])
        loadout.selectedActiveRelicID = MPCChapterOneCatalog.ownerlessMaskRelicID
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q13_encounter", companionIDs: [], loadout: loadout)
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0)
        _ = try s.useOwnedManualMasquerade(targetID: id, isOwned: true, at: 1)
        try s.endRound(actingEnemyID: id, at: 1.1)
        let requested = s.requestCounter(at: 1.2)
        let activated = s.activateCounter(at: 1.2)
        #expect(requested && activated)
        let prepared = s.prepareOrderedSkill(.sidestepStrike, targetID: id, at: 1.2)
        let timing = try #require(prepared)
        _ = s.advanceRelicClock(at: timing.firstImpactAt)
        _ = try s.useFoolSkill(.sidestepStrike, targetID: id, usesRealtimeCooldown: true)
        let ticket = try #require(s.sequenceNineRelics.deferredDamage)
        let hp = try #require(s.enemies.first { $0.id == ticket.targetID }).hp
        _ = s.advanceRelicClock(at: ticket.dueAt)
        let remaining = try #require(s.enemies.first { $0.id == ticket.targetID }).hp
        #expect(hp - remaining == min(hp, ticket.amount))
    }

    @Test func gradualSlotsAndUnlocksDoNotReplayRewards() {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        let inventory = campaign.inventory
        for q in 1...3 { _ = campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: q) }
        #expect(campaign.loadoutSlotCapacity == 2)
        #expect(campaign.unlockedSkillIDs.filter(\.isOrderedOrdinary).count == 2)
        #expect(campaign.effectiveLoadout.normalSkillIDs.count == 2)
        for q in 4...6 { _ = campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: q) }
        #expect(campaign.loadoutSlotCapacity == 3)
        for q in 7...9 { _ = campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: q) }
        #expect(campaign.loadoutSlotCapacity == 4)
        for q in 10...11 { _ = campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: q) }
        #expect(campaign.unlockedSkillIDs.filter(\.isOrderedOrdinary).count == 10)
        #expect(campaign.inventory == inventory)
    }
}
