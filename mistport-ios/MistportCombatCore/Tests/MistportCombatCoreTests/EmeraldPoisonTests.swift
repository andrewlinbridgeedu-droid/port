import Testing
@testable import MistportCombatCore

@Suite("Emerald persistent mist and heavy burst")
struct EmeraldPoisonTests {
    private func session() throws -> MPCChapterOneEncounterSession {
        try .start(encounterID: "chapter01_q05_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.maskedWhisper], passiveIDs: [], relicIDs: []))
    }

    @Test func firstActionCreatesPersistentEscalatingMistWithoutAdvancingTurns() throws {
        var battle = try session()
        #expect(battle.enemies[0].currentIntent == "memory_breath")
        try battle.endRound(at: 10)
        #expect(battle.playerHP == battle.playerMaxHP)
        #expect(battle.isEmeraldPoisonActive)
        #expect(battle.emeraldPoisonIntensity == 1)
        let round = battle.round
        let before = battle.advanceEmeraldPoison(at: 12.99)
        #expect(before == 0)
        let first = battle.advanceEmeraldPoison(at: 13)
        #expect(first == 20)
        let duplicate = battle.advanceEmeraldPoison(at: 13)
        #expect(duplicate == 0)
        let catchup = battle.advanceEmeraldPoison(at: 22)
        #expect(catchup == 25 + 30 + 35)
        #expect(battle.round == round)
        #expect(battle.isEmeraldPoisonActive)
        #expect(battle.emeraldPoisonIntensity == 5)
        #expect(battle.emeraldPoisonDamagePerTick == 40)
    }

    @Test func mistAndTicksPreserveMaskForHeavyBurst() throws {
        var battle = try session()
        _ = try battle.useFoolSkill(.maskedWhisper, targetID: battle.enemies[0].id, usesRealtimeCooldown: true)
        let charges = battle.masqueradeCharges
        #expect(charges > 0)
        try battle.endRound(at: 1)
        #expect(battle.isEmeraldPoisonActive)
        #expect(battle.masqueradeCharges == charges)
        _ = battle.advanceEmeraldPoison(at: 4)
        #expect(battle.masqueradeCharges == charges)
        try battle.endRound(at: 5)
        #expect(battle.enemies[0].currentIntent == "emerald_burst")
        let hp = battle.playerHP
        try battle.endRound(at: 6)
        #expect(battle.playerHP == hp)
        #expect(battle.masqueradeCharges == charges - 1)
        #expect(battle.enemies[0].currentIntent == "charge")
        #expect(battle.isEmeraldPoisonActive)
    }

    @Test func twoUnblockedHeavyBurstsDefeatFullHealthPlayer() throws {
        var battle = try session()
        try battle.endRound(at: 1)
        try battle.endRound(at: 2)
        try battle.endRound(at: 3)
        #expect(battle.playerHP == battle.playerMaxHP / 2)
        try battle.endRound(at: 4)
        try battle.endRound(at: 5)
        #expect(battle.outcome == .defeat)
        #expect(!battle.isEmeraldPoisonActive)
        #expect(battle.emeraldPoisonIntensity == 0)
    }

    @Test func laterAttackCycleDoesNotReapplyOrResetCloud() throws {
        var battle = try session()
        try battle.endRound(at: 1)
        _ = battle.advanceEmeraldPoison(at: 4)
        try battle.endRound(at: 5)
        try battle.endRound(at: 6)
        #expect(battle.enemies[0].currentIntent == "charge")
        #expect(battle.emeraldPoisonIntensity == 2)
        #expect(battle.emeraldPoisonDamagePerTick == 25)
        let next = battle.advanceEmeraldPoison(at: 7)
        #expect(next == 25)
    }

    @Test func shieldAbsorbsMistAndCancelOrRetryStartsClean() throws {
        var battle = try session()
        try battle.endRound(at: 1)
        battle.grantPlayerShield(25)
        let first = battle.advanceEmeraldPoison(at: 4)
        #expect(first == 0)
        #expect(battle.playerShield == 5)
        let second = battle.advanceEmeraldPoison(at: 7)
        #expect(second == 20)
        battle.clearEmeraldPoison()
        let afterCancel = battle.advanceEmeraldPoison(at: 100)
        #expect(afterCancel == 0)
        #expect(!battle.isEmeraldPoisonActive)
        #expect(battle.emeraldPoisonDamagePerTick == 0)
        let retry = try session()
        #expect(!retry.isEmeraldPoisonActive)
        #expect(retry.emeraldPoisonIntensity == 0)
    }

    @Test func victoryClearsMist() throws {
        var battle = try session()
        try battle.endRound(at: 1)
        _ = try battle.applyPartyDamage(99_999, to: battle.enemies[0].id, category: .damage)
        #expect(battle.outcome == .victory)
        #expect(!battle.isEmeraldPoisonActive)
        let damage = battle.advanceEmeraldPoison(at: 100)
        #expect(damage == 0)
    }
    @Test func pausedRelicsPreserveRecordsButCannotEquipOrGrant() throws {
        var campaign = MPCChapterOneCampaignState()
        campaign.ownedRelicIDs = ["relic_encore_bell", "relic_paper_raincoat"]
        campaign.depletedRelicIDs = ["relic_paper_raincoat"]
        campaign.loadout.relicIDs = ["relic_encore_bell"]
        let beforeOwned = campaign.ownedRelicIDs
        let beforeDepleted = campaign.depletedRelicIDs
        #expect(campaign.effectiveLoadout.relicIDs.isEmpty)
        let migrated = campaign.migrateLegacyPaperRelicToEncoreBell()
        #expect(!migrated)
        #expect(campaign.ownedRelicIDs == beforeOwned)
        #expect(campaign.depletedRelicIDs == beforeDepleted)
        let battle = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q05_encounter",
            loadout: .init(relicIDs: ["relic_encore_bell"]))
        #expect(battle.loadout.relicIDs.isEmpty)
        #expect(!battle.canUseEncoreBell)
        var fresh = MPCChapterOneCampaignState()
        let granted = fresh.acceptEncoreBellDelivery()
        #expect(!granted)
        fresh.claimVictory(for: battle.encounter)
        #expect(fresh.ownedRelicIDs.isEmpty)
        #expect(fresh.completedEncounterIDs.contains(battle.encounter.id))
    }

    @Test func queuedMaskCanLandLateInThreeSecondCharge() throws {
        var battle = try session()
        // Initial mist lands at1.1; the next charge starts at3.0. A2.4-second
        // input/cast delay still allows mask contact before charge release at6.0.
        try battle.endRound(at: 1.1)
        _ = battle.advanceEmeraldPoison(at: 5.4)
        _ = try battle.useFoolSkill(.maskedWhisper, targetID: battle.enemies[0].id,
                                   usesRealtimeCooldown: true)
        let charges = battle.masqueradeCharges
        try battle.endRound(at: 6.0)
        _ = battle.advanceEmeraldPoison(at: 7.1)
        #expect(battle.masqueradeCharges == charges)
        let hp = battle.playerHP
        try battle.endRound(at: 7.1)
        #expect(battle.playerHP == hp)
        #expect(battle.masqueradeCharges == charges - 1)
    }

}
