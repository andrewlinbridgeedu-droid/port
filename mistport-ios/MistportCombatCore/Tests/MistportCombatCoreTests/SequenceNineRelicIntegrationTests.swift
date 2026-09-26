import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Sequence nine relic runtime integration")
struct SequenceNineRelicIntegrationTests {
    private func session(_ q: Int = 7, passive: String? = nil, active: String? = nil,
                         skills: [FoolSkillID] = [.sidestepStrike, .fabricatedEvidence, .identityDisplacement]) throws -> MPCChapterOneEncounterSession {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: skills, isUltimateUnlocked: false,
                                          passiveIDs: [], relicIDs: passive.map { [$0] } ?? [])
        loadout.selectedActiveRelicID = active
        return try .start(encounterID: String(format: "chapter01_q%02d_encounter", q), party: .init(),
                          consumables: ["consumable_pain_salve": 2], companionIDs: [], loadout: loadout)
    }

    @Test func stampDefersOnlyOnePacketAndDoesNotBoostTwice() throws {
        var plain = try session(active: MPCChapterOneCatalog.usurpedLifeMedalRelicID)
        var stamped = try session(passive: "relic_deferred_stamp", active: MPCChapterOneCatalog.usurpedLifeMedalRelicID)
        let target = stamped.enemies[0].id
        let accepted1 = plain.activateUsurpedLifeMedal(isOwned: true, at: 0)
        #expect(accepted1)
        let accepted2 = stamped.activateUsurpedLifeMedal(isOwned: true, at: 0)
        #expect(accepted2)
        let ordinary = try plain.useFoolSkill(.sidestepStrike, targetID: target)
        let deferred = try stamped.useFoolSkill(.sidestepStrike, targetID: target)
        let ticket = try #require(stamped.sequenceNineRelics.deferredDamage)
        let matching = try #require(ordinary.targets.first { $0.targetID == ticket.targetID })
        #expect(ticket.amount == matching.damage + min(matching.damage * 40 / 100, 150))
        #expect(deferred.targets.count == 2)
        #expect(deferred.targets.filter { $0.damage > 0 }.count == 1)
        let before = try #require(stamped.enemies.first { $0.id == ticket.targetID }).hp
        _ = stamped.advanceRelicClock(at: 3)
        let after = try #require(stamped.enemies.first { $0.id == ticket.targetID }).hp
        #expect(before - after == min(before, ticket.amount))
        #expect(stamped.relicDamageEvents.count == 1)
        _ = stamped.advanceRelicClock(at: 4)
        #expect(stamped.relicDamageEvents.count == 1)
    }

    @Test func deferredTicketVoidsAtTrueImmunity() throws {
        var s = try session(6, passive: "relic_deferred_stamp")
        let enemy = s.enemies[0].id
        try s.endRound(actingEnemyID: enemy, at: 0) // opens
        _ = try s.useFoolSkill(.sidestepStrike, targetID: enemy)
        #expect(s.sequenceNineRelics.deferredDamage != nil)
        try s.endRound(actingEnemyID: enemy, at: 1) // slam -> recovery
        try s.endRound(actingEnemyID: enemy, at: 2) // recovery -> true ward
        let before = s.enemies[0].hp
        _ = s.advanceRelicClock(at: 3)
        #expect(s.enemies[0].hp == before)
        #expect(s.sequenceNineRelics.deferredDamage == nil)
        #expect(s.relicDamageEvents.isEmpty)
    }

    @Test func mirrorPaysActualHealingBeforeReflectingOtherEnemy() throws {
        var s = try session(passive: "relic_reflecting_ink_mirror")
        let recipient = s.enemies[0].id, attacker = s.enemies[1].id
        _ = try s.applyPartyDamage(220, to: recipient)
        s.updateRelicTarget(recipient, at: 0)
        _ = s.advanceRelicClock(at: 2)
        let before = s.enemies[0].hp
        let accepted3 = try s.useBasicAction(.damage, targetID: recipient) == 0
        #expect(accepted3)
        #expect(s.enemies[0].hp == before + 60)
        #expect(s.relicHealingEvents.last?.damage == 60)
        let playerBefore = s.playerHP, targetBefore = s.enemies[0].hp
        try s.endRound(actingEnemyID: attacker, at: 2.1)
        let event = try #require(s.relicDamageEvents.last)
        #expect(event.targetID == recipient && event.damage > 0)
        #expect(targetBefore - s.enemies[0].hp == event.damage)
        #expect(s.playerHP == playerBefore) // this guard's entire hit is below the cap
        #expect(s.sequenceNineRelics.mirrorTargetID == nil)
    }

    @Test func mirrorCannotChargeItsGiftOnFullOrSingleEnemy() throws {
        var full = try session(passive: "relic_reflecting_ink_mirror")
        let id = full.enemies[0].id
        full.updateRelicTarget(id, at: 0)
        _ = full.advanceRelicClock(at: 2)
        let accepted4 = try full.useBasicAction(.damage, targetID: id) > 0
        #expect(accepted4)
        #expect(full.relicHealingEvents.isEmpty)
        var single = try session(8, passive: "relic_reflecting_ink_mirror")
        let sole = single.enemies[0].id
        _ = try single.applyPartyDamage(100, to: sole)
        single.updateRelicTarget(sole, at: 0)
        _ = single.advanceRelicClock(at: 2)
        let accepted5 = try single.useBasicAction(.damage, targetID: sole) > 0
        #expect(accepted5)
        #expect(single.relicHealingEvents.isEmpty)
    }

    @Test func paperweightSealsFixedThirdSlotIncludingStatusAndPaysCooldown() throws {
        var s = try session(18, passive: "relic_sealed_paperweight")
        let id = s.enemies[0].id
        #expect(!s.willSealPreparedSkill(.sidestepStrike, at: 0))
        #expect(s.willSealPreparedSkill(.identityDisplacement, at: 0))
        let hp = s.enemies[0].hp, illusions = s.foolStates[id]?.illusionStacks
        let sealed = try s.useFoolSkill(.identityDisplacement, targetID: id)
        #expect(sealed.damage == 0 && s.enemies[0].hp == hp)
        #expect(s.foolStates[id]?.illusionStacks == illusions)
        #expect(s.sequenceNineRelics.paperweightCapacity == 350)
        #expect(s.sequenceNineRelics.paperweightExpiresAt == 4)
        #expect(s.sequenceNineRelics.paperweightReadyAt == 18)
        #expect(s.remainingCooldownActions(for: .identityDisplacement) > 0)
    }

    @Test func paperweightCastSnapshotSurvivesNextSequenceEdit() throws {
        var s = try session(18, passive: "relic_sealed_paperweight")
        let id = s.enemies[0].id
        let sealsAtStart = s.willSealPreparedSkill(.identityDisplacement, at: 0)
        s.setContinuousSkillSequence([.identityDisplacement, .sidestepStrike, .fabricatedEvidence])
        let before = s.foolStates[id]?.illusionStacks
        _ = try s.useFoolSkill(.identityDisplacement, targetID: id, sealedByPaperweight: sealsAtStart)
        #expect(s.foolStates[id]?.illusionStacks == before)
        #expect(s.sequenceNineRelics.paperweightCapacity == 350)
        var normal = try session(18, passive: "relic_sealed_paperweight")
        _ = try normal.useFoolSkill(.identityDisplacement, targetID: normal.enemies[0].id, sealedByPaperweight: false)
        #expect(normal.sequenceNineRelics.paperweightCapacity == 0)
    }

    @Test func needleSplitsOneRealHealAndBlockedMedicineIsNotConsumed() throws {
        var s = try session(passive: "relic_ownership_severing_needle")
        let recipient = s.enemies[0].id, attacker = s.enemies[1].id
        let healer = try #require(s.enemies.first { $0.contentID == "enemy_memory_leech_node" }).id
        _ = try s.applyPartyDamage(300, to: recipient)
        try s.endRound(actingEnemyID: attacker, at: 0)
        s.updateRelicTarget(recipient, at: 0)
        let playerBefore = s.playerHP, targetBefore = s.enemies[0].hp
        try s.endRound(actingEnemyID: healer, at: 1)
        let selfHealing = s.playerHP - playerBefore, enemyHealing = s.enemies[0].hp - targetBefore
        #expect(selfHealing > 0 && selfHealing + enemyHealing == 180)
        #expect(s.lastRelicPlayerHealing == selfHealing)
        #expect(s.sequenceNineRelics.needleUses == 1)
        try s.endRound(actingEnemyID: attacker, at: 2)
        let stock = s.consumables["consumable_pain_salve"]
        #expect(throws: MPCEncounterRuntimeError.noHealingNeeded) { try s.useConsumable("consumable_pain_salve") }
        #expect(s.consumables["consumable_pain_salve"] == stock)
        _ = s.advanceRelicClock(at: 7)
        try s.useConsumable("consumable_pain_salve")
        #expect(s.consumables["consumable_pain_salve"] == (stock ?? 0) - 1)
    }

    @Test func blankCardBlocksOnlyBoundPairAndStillAppliesControl() throws {
        var s = try session(active: "relic_blank_name_card")
        let bound = s.enemies[0].id, other = s.enemies[1].id
        let accepted6 = s.activateBlankNameCard(isOwned: true, targetID: bound, at: 0)
        #expect(accepted6)
        let before = s.enemies[0].hp
        _ = try s.useFoolSkill(.identityDisplacement, targetID: bound)
        #expect(s.enemies[0].hp == before)
        #expect((s.foolStates[bound]?.illusionStacks ?? 0) > 0)
        let hp = s.playerHP
        s.commitEnemyImpact(from: bound)
        try s.endRound(actingEnemyID: bound, at: 1)
        #expect(s.playerHP == hp)
        try s.endRound(actingEnemyID: other, at: 2)
        #expect(s.playerHP < hp)
        #expect(s.remainingCooldownActions(for: .identityDisplacement) > 0)
    }

    @Test func blankCardCannotBeSwappedOutDuringActiveContractAndDoesNotStopPoison() throws {
        var s = try session(5, active: "relic_blank_name_card")
        let id = s.enemies[0].id
        let accepted7 = s.activateBlankNameCard(isOwned: true, targetID: id, at: 0)
        #expect(accepted7)
        let accepted8 = !s.selectActiveRelic(MPCChapterOneCatalog.usurpedLifeMedalRelicID, isOwned: true)
        #expect(accepted8)
        try s.endRound(actingEnemyID: id, at: 0)
        #expect(s.isEmeraldPoisonActive)
        let hp = s.playerHP
        _ = s.advanceRelicClock(at: 3)
        #expect(s.playerHP < hp)
        var poison = try session(5, active: "relic_blank_name_card")
        let caster = poison.enemies[0].id
        try poison.endRound(actingEnemyID: caster, at: 0)
        let activatedDuringMist = poison.activateBlankNameCard(isOwned: true, targetID: caster, at: 1)
        #expect(activatedDuringMist)
        let beforeActivePoison = poison.playerHP
        _ = poison.advanceRelicClock(at: 3)
        #expect(poison.sequenceNineRelics.blankCardExpiresAt > 3)
        #expect(poison.playerHP < beforeActivePoison)

    }
    @Test func deferredDeathDoesNotRetargetAnotherLivingEnemy() throws {
        var s = try session(passive: "relic_deferred_stamp")
        let first = s.enemies[0].id
        _ = try s.useFoolSkill(.sidestepStrike, targetID: first)
        let ticket = try #require(s.sequenceNineRelics.deferredDamage)
        _ = try s.applyPartyDamage(100_000, to: ticket.targetID)
        let livingBefore = Dictionary(uniqueKeysWithValues: s.enemies.filter(\.isAlive).map { ($0.id, $0.hp) })
        _ = s.advanceRelicClock(at: 3)
        for enemy in s.enemies where enemy.isAlive { #expect(enemy.hp == livingBefore[enemy.id]) }
        #expect(s.relicDamageEvents.isEmpty)
        #expect(s.sequenceNineRelics.deferredDamage == nil)
    }

    @Test func paperweightNeedsThreePreparedCardsAndSealsOnlyOnceDuringCooldown() throws {
        var short = try session(18, passive: "relic_sealed_paperweight", skills: [.identityDisplacement])
        let id = short.enemies[0].id
        #expect(!short.willSealPreparedSkill(.identityDisplacement, at: 0))
        _ = try short.useFoolSkill(.identityDisplacement, targetID: id)
        #expect(short.sequenceNineRelics.paperweightCapacity == 0)
        var full = try session(18, passive: "relic_sealed_paperweight")
        let target = full.enemies[0].id
        _ = try full.useFoolSkill(.identityDisplacement, targetID: target)
        _ = full.advanceRelicClock(at: 4)
        #expect(!full.willSealPreparedSkill(.identityDisplacement, at: 4))
        _ = try full.useFoolSkill(.identityDisplacement, targetID: target, usesRealtimeCooldown: true)
        #expect((full.foolStates[target]?.illusionStacks ?? 0) > 0)
        #expect(full.sequenceNineRelics.paperweightReadyAt == 18)
    }

    @Test func mirrorTargetSwitchCancelsPaidPreparationWithoutRefund() throws {
        var s = try session(passive: "relic_reflecting_ink_mirror")
        let first = s.enemies[0].id, second = s.enemies[1].id
        _ = try s.applyPartyDamage(200, to: first)
        s.updateRelicTarget(first, at: 0)
        _ = s.advanceRelicClock(at: 2)
        _ = try s.useBasicAction(.damage, targetID: first)
        let hpAfterGift = s.enemies[0].hp
        s.updateRelicTarget(second, at: 2.1)
        #expect(s.sequenceNineRelics.mirrorTargetID == nil)
        #expect(s.sequenceNineRelics.mirrorReadyAt == 10)
        #expect(s.enemies[0].hp == hpAfterGift)
        let player = s.playerHP
        try s.endRound(actingEnemyID: second, at: 2.2)
        #expect(s.playerHP < player && s.relicDamageEvents.isEmpty)
    }

    @Test func anchorGroupsOnlyRealPairedExecutorSegments() throws {
        var plain = try session(17)
        var anchored = try session(17, passive: "relic_countertide_anchor")
        let enemy = anchored.enemies[0].id
        try plain.endRound(actingEnemyID: enemy, at: 0)
        try anchored.endRound(actingEnemyID: enemy, at: 0)
        let p0 = plain.playerHP, a0 = anchored.playerHP
        try plain.endRound(actingEnemyID: enemy, at: 1)
        try anchored.endRound(actingEnemyID: enemy, at: 1)
        #expect(a0 - anchored.playerHP == p0 - plain.playerHP + 50)
        let p1 = plain.playerHP, a1 = anchored.playerHP
        try plain.endRound(actingEnemyID: enemy, at: 2)
        try anchored.endRound(actingEnemyID: enemy, at: 2)
        #expect(a1 - anchored.playerHP == max(0, p1 - plain.playerHP - 350))
        #expect(anchored.sequenceNineRelics.anchorSegments == 1)
    }

}
