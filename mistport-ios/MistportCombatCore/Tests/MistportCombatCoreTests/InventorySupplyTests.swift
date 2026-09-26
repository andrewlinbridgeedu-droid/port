import Testing
@testable import MistportCombatCore

@Suite("Inventory supplies")
struct InventorySupplyTests {
    let salve = "consumable_pain_salve"

    @Test func fullHealthDoesNotSpendSupply() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q02_encounter", consumables: [salve: 1], companionIDs: [])
        #expect(throws: MPCEncounterRuntimeError.noHealingNeeded) { try session.useConsumable(salve) }
        #expect(session.consumables[salve] == 1)
    }

    @Test func healingAndRetryRespectSpentInventory() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q10_encounter", consumables: [salve: 1], companionIDs: [])
        let original = session
        try session.endRound(actingEnemyID: session.enemies[0].id)
        let before = session.playerHP
        try session.useConsumable(salve)
        #expect(session.playerHP == min(session.playerMaxHP, before + session.playerMaxHP / 5))
        #expect(session.consumables[salve] == 0)
        #expect(throws: MPCEncounterRuntimeError.noConsumableRemaining) { try session.useConsumable(salve) }
        var retry = original
        retry.limitConsumables(to: [salve: 0])
        #expect(retry.consumables[salve] == 0)
        retry.limitConsumables(to: [salve: 50])
        #expect(retry.consumables[salve] == 0)
    }

    @Test func victoryAddsRewardAfterConsumedSnapshot() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q01_encounter", consumables: [salve: 0], companionIDs: [])
        for enemy in session.enemies {
            try session.applyPartyDamage(100_000, to: enemy.id)
        }
        #expect(session.outcome == .victory)
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.completeEncounter(session)
        #expect(campaign.inventory[salve] == 1)
        #expect(throws: MPCEncounterRuntimeError.encounterFinished) { try session.useConsumable(salve) }
    }
}
