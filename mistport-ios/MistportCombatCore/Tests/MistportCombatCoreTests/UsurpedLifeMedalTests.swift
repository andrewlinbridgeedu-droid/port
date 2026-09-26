import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Usurped life medal contract")
struct UsurpedLifeMedalTests {
    func session(_ q: Int = 6, hp: Int = 1000) throws -> MPCChapterOneEncounterSession {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        loadout.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID
        return try .start(encounterID: String(format: "chapter01_q%02d_encounter", q), party: .init(playerHP: hp, playerMaxHP: hp), companionIDs: [], loadout: loadout)
    }
    @Test func naturalExpiryCooldownAndIdempotentSettlement() throws {
        var s = try session(hp: 800)
        let check13 = s.activateUsurpedLifeMedal(isOwned: true, at: 2)
        #expect(check13)
        #expect(s.playerHP == 1200 && s.playerMaxHP == 1200)
        let check15 = !s.activateUsurpedLifeMedal(isOwned: true, at: 3)
        #expect(check15)
        let check16 = !s.advanceUsurpedLifeMedal(at: 9.999)
        #expect(check16)
        let check17 = s.advanceUsurpedLifeMedal(at: 10)
        #expect(check17)
        #expect(s.playerHP == 600 && s.playerMaxHP == 800)
        let check19 = !s.settleUsurpedLifeMedal()
        #expect(check19)
        let check20 = !s.activateUsurpedLifeMedal(isOwned: true, at: 25.999)
        #expect(check20)
        let check21 = s.activateUsurpedLifeMedal(isOwned: true, at: 26)
        #expect(check21)
        #expect(s.playerHP == 900)
        let check23 = s.settleUsurpedLifeMedal()
        #expect(check23)
        #expect(s.playerHP == 450)
    }
    @Test func attackInputDoesNotCompoundAndMaskIsExclusive() throws {
        var plain = try session(7), boosted = plain
        let check28 = boosted.activateUsurpedLifeMedal(isOwned: true, at: 0)
        #expect(check28)
        let check29 = try boosted.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: 0) == nil
        #expect(check29)
        let target = plain.enemies[0].id
        let a = try plain.useFoolSkill(.sidestepStrike, targetID: target, usesRealtimeCooldown: true)
        let b = try boosted.useFoolSkill(.sidestepStrike, targetID: target, usesRealtimeCooldown: true)
        #expect(b.damage > a.damage)
        #expect(b.targets.count == 2)
        #expect(boosted.foolStates[target]?.attack == 100)
        _ = boosted.settleUsurpedLifeMedal()
        #expect(boosted.foolStates[target]?.attack == 100)
        let check38 = !boosted.selectActiveRelic(MPCChapterOneCatalog.ownerlessMaskRelicID, isOwned: false)
        #expect(check38)
    }
    @Test func victorySettlesBeforePersistenceAndDoesNotDoubleCharge() throws {
        var s = try session()
        let check42 = s.activateUsurpedLifeMedal(isOwned: true, at: 0)
        #expect(check42)
        let id = s.enemies[0].id
        // Q6 guard is truly immune; resolve guard then attack through the open phase.
        try s.endRound(actingEnemyID: id, at: 1)
        _ = try s.applyPartyDamage(100000, to: id, category: .damage)
        #expect(s.outcome == .victory)
        #expect(s.playerHP == 750 && s.playerMaxHP == 1000)
        let check49 = !s.settleUsurpedLifeMedal()
        #expect(check49)
        #expect(s.persistentPartyState().playerMaxHP == 1000)
    }
    @Test func directHitAndPoisonUseBaseHPAndDeathStaysDead() throws {
        var plain = try session(5), boosted = plain
        let check54 = boosted.activateUsurpedLifeMedal(isOwned: true, at: 0)
        #expect(check54)
        let id = plain.enemies[0].id
        try plain.endRound(actingEnemyID: id, at: 0)
        try boosted.endRound(actingEnemyID: id, at: 0)
        #expect(plain.emeraldPoisonDamagePerTick == boosted.emeraldPoisonDamagePerTick)
        #expect(plain.advanceEmeraldPoison(at: 3) == boosted.advanceEmeraldPoison(at: 3))
        for i in 1...30 where boosted.outcome == .inProgress {
            try boosted.endRound(actingEnemyID: id, at: Double(i))
            _ = boosted.advanceEmeraldPoison(at: Double(i))
        }
        #expect(boosted.outcome == .defeat)
        #expect(boosted.playerHP == 0)
        #expect(!boosted.isUsurpedLifeMedalActive)
        #expect(boosted.playerMaxHP == 1000)
    }
    @Test func entitlementAndTeachingBoundary() throws {
        var campaign = MPCChapterOneCampaignState()
        #expect(!campaign.ownsUsurpedLifeMedal)
        _ = campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 4)
        #expect(campaign.ownsUsurpedLifeMedal)
        let check74 = !campaign.grantUsurpedLifeMedalAfterQ4()
        #expect(check74)
        #expect(campaign.loadout.selectedActiveRelicID == nil)
        var s = try session(4)
        let check77 = !s.activateUsurpedLifeMedal(isOwned: true, at: 0)
        #expect(check77)
        let check78 = !s.selectActiveRelic(MPCChapterOneCatalog.usurpedLifeMedalRelicID, isOwned: true)
        #expect(check78)
    }
    @Test func lowHPNeverCreatesNetHealingAndRetreatOnlySettlesOnce() throws {
        for hp in 1...100 {
            var s = try session(hp: hp)
            let check83 = s.activateUsurpedLifeMedal(isOwned: true, at: 0)
            #expect(check83)
            let check84 = s.settleUsurpedLifeMedal()
            #expect(check84)
            #expect(s.playerHP >= 1 && s.playerHP <= hp)
            let settled = s.playerHP
            let check87 = !s.settleUsurpedLifeMedal()
            #expect(check87)
            #expect(s.playerHP == settled)
        }
    }
    @Test func usersExactThousandMaximumEightHundredCurrentExample() throws {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        loadout.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q06_encounter", consumables: ["consumable_salt_tea": 1], companionIDs: [], loadout: loadout)
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0) // guard
        try s.endRound(actingEnemyID: id, at: 1) // 1000 - 400
        try s.useConsumable("consumable_salt_tea") // +200
        #expect(s.playerMaxHP == 1000 && s.playerHP == 800)
        let activated = s.activateUsurpedLifeMedal(isOwned: true, at: 2)
        #expect(activated && s.playerMaxHP == 1500 && s.playerHP == 1200)
        try s.endRound(actingEnemyID: id, at: 3) // recover
        try s.endRound(actingEnemyID: id, at: 4) // guard
        try s.endRound(actingEnemyID: id, at: 5) // another 400
        #expect(s.playerHP == 800)
        let expired = s.advanceUsurpedLifeMedal(at: 10)
        #expect(expired && s.playerHP == 400 && s.playerMaxHP == 1000)
    }

    @Test func damageBeforeSettlementIsHalvedWithoutRemovingBorrowedBlock() throws {
        var s = try session()
        let activated = s.activateUsurpedLifeMedal(isOwned: true, at: 0)
        #expect(activated)
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 1) // guard ends
        try s.endRound(actingEnemyID: id, at: 2) // 400 direct hit
        #expect(s.playerHP == 1100)
        let settled = s.settleUsurpedLifeMedal()
        #expect(settled && s.playerHP == 550 && s.playerMaxHP == 1000)
    }

    @Test func trueShieldRejectsBoostedDamageAndContactSettlesExpiry() throws {
        var s = try session()
        let activated = s.activateUsurpedLifeMedal(isOwned: true, at: 0)
        #expect(activated)
        let id = s.enemies[0].id
        let basic = try s.useBasicAction(.damage, targetID: id)
        let skill = try s.useFoolSkill(.sidestepStrike, targetID: id, usesRealtimeCooldown: true)
        #expect(basic == 0 && skill.damage == 0)
        #expect(s.enemies[0].hp == s.enemies[0].maxHP)
        try s.endRound(actingEnemyID: id, at: 8)
        #expect(!s.isUsurpedLifeMedalActive && s.playerHP == 750)
    }

    @Test func initialQ5Q6TimingSamples() throws {
        for q in [5,6] {
            for offset in [0.0,3,6,9,12] {
                let result = try NewMaskBalanceSimulator.run(q: q, sequence: [.sidestepStrike], mask: false, medalOffset: offset)
                print("MEDAL_SAMPLE Q\(q) offset=\(offset) outcome=\(result.session.outcome) seconds=\(result.seconds) hp=\(result.session.playerHP) enemy=\(result.session.enemies.map(\.hp))")
                #expect(result.session.outcome != .inProgress)
            }
        }
    }
}
