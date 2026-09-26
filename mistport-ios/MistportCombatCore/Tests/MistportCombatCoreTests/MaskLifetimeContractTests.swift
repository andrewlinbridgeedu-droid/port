import Testing
@testable import MistportCombatCore

@Suite("Permanent mask contract")
struct MaskLifetimeContractTests {
    private func session(_ q: Int) throws -> MPCChapterOneEncounterSession {
        try .start(encounterID: "chapter01_q0\(q)_encounter", companionIDs: [],
                   loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
    }

    @Test func manualDefenseHasNoAttackOrStacksAndUsesRealtimeCooldown() throws {
        var s = try session(6)
        let enemies = s.enemies
        let states = s.foolStates
        let accepted = try s.useOwnedManualMasquerade(targetID: s.enemies[0].id, isOwned: true, at: 1)
        let result = try #require(accepted)
        #expect(result.damage == 0 && result.targets.isEmpty)
        #expect(s.enemies == enemies && s.foolStates == states)
        #expect(s.loadout.normalSkillIDs.isEmpty)
        #expect(s.masqueradeCharges == 2)
        #expect(s.ownedManualMaskExpiresAt == 5)
        #expect(s.ownedManualMaskReadyAt == 19)
        #expect(try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: 18.99) == nil)
        #expect(try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: 19) != nil)
    }

    @Test func contactExpiresProtectionWithoutPresentationTick() throws {
        var s = try session(6)
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0) // guard -> slam
        _ = try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: 1)
        let hp = s.playerHP
        try s.endRound(actingEnemyID: id, at: 5)
        #expect(s.masqueradeCharges == 0)
        #expect(s.playerHP < hp)
    }

    @Test func directContactIsBlockedBeforeExpiry() throws {
        var s = try session(6)
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0)
        _ = try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: 1)
        let hp = s.playerHP
        try s.endRound(actingEnemyID: id, at: 4.99)
        #expect(s.masqueradeCharges == 1 && s.playerHP == hp)
    }

    @Test func poisonBypassesProtectionWithoutConsumingIt() throws {
        var s = try session(5)
        let id = s.enemies[0].id
        for _ in 0..<4 where !s.isEmeraldPoisonActive { try s.endRound(actingEnemyID: id, at: 0) }
        #expect(s.isEmeraldPoisonActive)
        _ = try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: 1)
        let hp = s.playerHP
        _ = s.advanceEmeraldPoison(at: 3)
        #expect(s.playerHP < hp)
        #expect(s.masqueradeCharges == 2)
    }

    @Test func tenthUseWorksThenPermanentExhaustionAndTeachingLoan() throws {
        var campaign = MPCChapterOneCampaignState(masqueradeCrackCount: 9)
        var s = try session(6)
        #expect(try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, lifetimeCracks: campaign.masqueradeCrackCount, at: 0) != nil)
        let registered = campaign.registerMasqueradeUse(encounterID: s.encounter.id)
        #expect(registered)
        #expect(campaign.masqueradeCrackCount == 10 && s.masqueradeCharges == 2)
        #expect(try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, lifetimeCracks: campaign.masqueradeCrackCount, at: 18) == nil)
        let exhausted = campaign.registerMasqueradeUse(encounterID: s.encounter.id)
        #expect(!exhausted)
        for q in [3, 4] {
            var teaching = try session(q)
            #expect(try teaching.useOwnedManualMasquerade(targetID: nil, isOwned: true, lifetimeCracks: 10, at: 0) != nil)
            let loan = campaign.registerMasqueradeUse(encounterID: teaching.encounter.id)
            #expect(loan)
            #expect(campaign.masqueradeCrackCount == 10)
        }
        let retry = try session(6)
        #expect(retry.masqueradeCharges == 0)
        #expect(campaign.masqueradeCrackCount == 10)
    }
}
