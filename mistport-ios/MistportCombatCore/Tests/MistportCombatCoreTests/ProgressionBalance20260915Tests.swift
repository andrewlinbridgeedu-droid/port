import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Progression balance 20260915")
struct ProgressionBalance20260915Tests {
    @Test func independentRepairCastersFreezeNilAndLivingRecipientSeparately() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID:"chapter01_q15_encounter",companionIDs:[])
        let cores = s.enemies.filter { $0.contentID == "enemy_memory_leech_node" }
        let body = try #require(s.enemies.first { $0.contentID != "enemy_memory_leech_node" })
        let emptyCaster = try #require(cores.first { $0.currentIntent == "repair_guard" })
        let nextCaster = try #require(cores.first { $0.currentIntent == "memory_strike" })
        s.commitEnemyImpact(from:emptyCaster.id)
        #expect(s.repairTargetID(for:emptyCaster.id) == nil)
        try s.endRound(actingEnemyID:nextCaster.id)
        _ = try s.applyPartyDamage(400,to:body.id)
        s.commitEnemyImpact(from:nextCaster.id)
        #expect(s.repairTargetID(for:nextCaster.id) == body.id)
        #expect(s.repairTargetID(for:emptyCaster.id) == nil)
        let before = s.enemies.first { $0.id == body.id }!.hp
        try s.endRound(actingEnemyID:emptyCaster.id)
        #expect(s.enemies.first { $0.id == body.id }!.hp == before)
        try s.endRound(actingEnemyID:nextCaster.id)
        #expect(s.enemies.first { $0.id == body.id }!.hp == before + body.maxHP * 12 / 100)
    }
    @Test func anotherEnemyCannotEraseFortifyCounterWindow() throws {
        let loadout = MPCChapterOneLoadout(normalSkillIDs:[.turnTheTables],isUltimateUnlocked:false,passiveIDs:[],relicIDs:[])
        var s = try MPCChapterOneEncounterSession.start(encounterID:"chapter01_q14_encounter",companionIDs:[],loadout:loadout)
        let puppet = try #require(s.enemies.first { $0.contentID == "enemy_calibration_puppet" })
        let leech = try #require(s.enemies.first { $0.contentID == "enemy_memory_leech" })
        try s.endRound(actingEnemyID:puppet.id)
        #expect(s.enemyDefenseBonusBP(for:puppet.id) == 5000)
        try s.endRound(actingEnemyID:leech.id)
        #expect(s.enemyDefenseBonusBP(for:puppet.id) == 5000)
        _ = try s.useFoolSkill(.turnTheTables,targetID:puppet.id)
        #expect(s.enemyDefenseBonusBP(for:puppet.id) == 0)
        // 突转's dispel grants 2 错位 since the ten-card redesign (2026-10-12).
        #expect(s.foolState(for:puppet.id)?.misalignmentStacks == 2)
    }
    /// Q1–Q15 on the real loop with a paid salve ledger: each mission's route that spends the fewest salves,
    /// the medal from Q5 (no mask cracks), at most four J0 jobs to keep a salve in the bag.
    @Test func earnedBuildsAndInventoryLedger() async throws {
        var copper = 180, jobs = 0, items = ["consumable_pain_salve": 1]
        for q in 1...15 {
            if q == 5 { copper -= 280 } // Purchase both alternative passives once.
            if q >= 5, items["consumable_pain_salve", default: 0] == 0 {
                // Core ledger assumes completed J0 work; it does not exercise its native UI.
                while copper < 30 { copper += 40; jobs += 1 }
                copper -= 30; items["consumable_pain_salve"] = 1
            }
            struct Try: Sendable { let order: [FoolSkillID]; let passive: String?; let medal: Double?; let salve: Bool }
            let tries = [false, true].flatMap { salve in RealLoop.orders(before: q).flatMap { order in
                (q >= 5 ? [RealLoop.bag, RealLoop.clasp] : [nil]).flatMap { passive in (q >= 5 ? [6.0, 14.0] : [nil]).map {
                    Try(order: order, passive: passive, medal: $0, salve: salve) } } } }
            let stock = items
            @Sendable func play(_ t: Try) throws -> MPCStoryVerificationRunner.Report {
                try RealLoop.story(q, t.order, passive: t.passive, active: q >= 5 ? RealLoop.medal : nil,
                                   policy: .init(medalFrom: t.medal, salveBelow: t.salve ? 400 : nil), consumables: stock)
            }
            let chosen = try #require(try await RealLoop.firstWin(tries) { try play($0).won }, "No earned route at Q\(q)")
            let result = try play(chosen)
            // Q4 is paced by its 20 s hound cycles (four to six on the real loop), not by damage: no time bound.
            if q != 4 { #expect(result.seconds < 65, "Q\(q) took \(result.seconds) s") }
            if q >= 5 { #expect(result.maskUses == 0) }
            items = result.session.consumables
            copper += try #require(MPCChapterOneThirtyMissionContract.firstClear(for: q)).copper
            #expect(copper >= 0 && items.values.allSatisfy { $0 >= 0 })
        }
        #expect(jobs <= 4)
        print("Q1–15 ledger completed J0 jobs=\(jobs), copper=\(copper)")
    }
}
