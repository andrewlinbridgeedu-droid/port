import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Bounty relics: mechanic counters in the separate bounty slot")
struct BountyRelicTests {
    func session(_ q: Int, relic: String?) throws -> MPCChapterOneEncounterSession {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        loadout.bountyRelicID = relic
        return try MPCChapterOneEncounterSession.start(encounterID: String(format: "chapter01_q%02d_encounter", q),
                                                       companionIDs: [], loadout: loadout)
    }

    func act(_ s: inout MPCChapterOneEncounterSession, _ enemyID: String, at time: TimeInterval) throws {
        s.commitEnemyImpact(from: enemyID)
        try s.endRound(actingEnemyID: enemyID, at: time)
    }

    @Test func everyCaseHasOneRelicAndOnlyWallRelicsWorkYet() {
        let cases = MPCChurchBountyCatalog.all.map(\.id).sorted()
        #expect(MPCBountyRelicCatalog.all.map(\.caseID).sorted() == cases)
        #expect(Set(MPCBountyRelicCatalog.all.filter(\.hasEffect).map(\.id))
                == [MPCBountyRelicCatalog.brokenSword, MPCBountyRelicCatalog.reverseSeal, MPCBountyRelicCatalog.lifeLedger])
    }

    @Test func retiringBountyGearKeepsTowerPiecesAndRewearsTheStrongest() throws {
        var ledger = MPCChurchGearLedger()
        for id in ["tower-f08-joint-guard", "tower-f10-anchor-blade", "bounty-b05-red-shears", "bounty-b06-dark-lantern"] { ledger.grant(id) }
        #expect(ledger.equippedWeaponID == "bounty-b05-red-shears" && ledger.equippedArmorID == "bounty-b06-dark-lantern")
        #expect(ledger.retireBountyGear() == ["bounty-b05-red-shears", "bounty-b06-dark-lantern"])
        #expect(ledger.ownedIDs == ["tower-f08-joint-guard", "tower-f10-anchor-blade"])
        #expect(ledger.equippedWeaponID == "tower-f10-anchor-blade" && ledger.equippedArmorID == "tower-f08-joint-guard")
        #expect(ledger.stats == MPCChurchGearStats(attackBP: 3_600, maxHP: 270, damageReductionBP: 1_100))
        #expect(ledger.retireBountyGear().isEmpty)
    }

    @Test func reverseSealCountsEachCalibrationHitTwice() throws {
        for relic in [nil, MPCBountyRelicCatalog.reverseSeal] {
            var s = try session(22, relic: relic)
            let clockmaker = s.enemies.first { $0.contentID == "enemy_hollow_clockmaker" }!
            #expect(clockmaker.currentIntent == "calibration")
            _ = try s.useBasicAction(.damage, targetID: clockmaker.id)
            try act(&s, clockmaker.id, at: 4.2)
            #expect(s.chapterVerificationFailed == (relic == nil))
        }
    }

    @Test func brokenSwordBreaksAFortifiedPuppetOncePerCooldown() throws {
        var losses: [Int] = []
        for relic in [nil, MPCBountyRelicCatalog.brokenSword] {
            var s = try session(12, relic: relic)
            let puppet = s.enemies.first { $0.currentIntent == "fortify" }!
            try act(&s, puppet.id, at: 3)
            let before = s.enemies.first { $0.id == puppet.id }!.hp
            _ = try s.useBasicAction(.damage, targetID: puppet.id)
            _ = try s.useBasicAction(.damage, targetID: puppet.id)
            losses.append(before - s.enemies.first { $0.id == puppet.id }!.hp)
            #expect(s.triggeredEffects.filter { $0.hasPrefix("七号缺齿剑") }.count == (relic == nil ? 0 : 1))
        }
        #expect(losses[1] > losses[0])
    }

    @Test func lifeLedgerStopsTheEnrageAndHealsEachCycle() throws {
        var taken: [Int] = []
        for relic in [nil, MPCBountyRelicCatalog.lifeLedger] {
            var s = try session(30, relic: relic)
            let boss = s.enemies.first { $0.contentID == "boss_chronarch_sovereign" }!
            while let hp = s.enemies.first(where: { $0.id == boss.id })?.hp, hp * 3 >= boss.maxHP {
                _ = try s.useBasicAction(.damage, targetID: boss.id)
            }
            let hp = s.playerHP
            try act(&s, boss.id, at: 2)
            taken.append(hp - s.playerHP)
            for step in 1...3 { try act(&s, boss.id, at: 2 + Double(step) * 3) }
            #expect(s.completedBossCycles == 1)
            #expect(s.triggeredEffects.contains { $0.hasPrefix("绯月寿账签") } == (relic != nil))
        }
        #expect(taken[0] > taken[1])
    }
}
