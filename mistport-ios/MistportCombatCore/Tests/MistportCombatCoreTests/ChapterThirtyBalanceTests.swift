import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Thirty mission legal loadout balance")
struct ChapterThirtyBalanceTests {
    private var firstTenTowerGear: MPCChurchGearStats {
        var gear = MPCChurchGearLedger()
        for floor in [2, 4, 6, 8, 10] {
            if let drop = MPCChurchGearCatalog.towerDrop(floor: floor) { gear.grant(drop.id) }
        }
        return gear.stats
    }

    @Test func q27RequiresEarnedEquipmentOnThePlayerAuditRoute() throws {
        let sequence: [FoolSkillID] = [.fabricatedEvidence, .identityDisplacement,
                                       .mirrorPursuit, .absurdFinale]
        let talents = HermitTalentAllocation.restored((0...3).map { "trickery.\($0)" }, budget: 4)
        var loadout = MPCChapterOneLoadout(normalSkillIDs: sequence, isUltimateUnlocked: true,
                                           passiveIDs: [], relicIDs: ["relic_return_gift_clasp"])
        loadout.talents = talents
        let before = try NewMaskBalanceSimulator.run(q: 27, sequence: sequence, mask: false,
            consumables: ["consumable_pain_salve": 1], loadout: loadout, medalOffset: 6)
        loadout.churchGear = firstTenTowerGear
        let after = try NewMaskBalanceSimulator.run(q: 27, sequence: sequence, mask: false,
            consumables: ["consumable_pain_salve": 1], loadout: loadout, medalOffset: 6)
        print("Q27_GROWTH unearned=\(before.session.outcome) hp=\(before.session.playerHP) earned=\(after.session.outcome) hp=\(after.session.playerHP)")
        #expect(before.session.outcome == .defeat)
        #expect(after.session.outcome == .victory)
    }

    @Test func playerAuditFourTalentRoute() throws {
        let sequence: [FoolSkillID] = [.fabricatedEvidence, .identityDisplacement,
                                       .mirrorPursuit, .absurdFinale]
        let talents = HermitTalentAllocation.restored(
            (0...3).map { "trickery.\($0)" }, budget: 4
        )
        for q in 27...30 {
            var loadout = MPCChapterOneLoadout(normalSkillIDs: sequence, isUltimateUnlocked: true,
                                               passiveIDs: [], relicIDs: ["relic_return_gift_clasp"])
            loadout.talents = talents
            loadout.churchGear = firstTenTowerGear
            for offset in [6.0, 14.0] {
                let result = try NewMaskBalanceSimulator.run(
                    q: q, sequence: sequence, mask: false,
                    consumables: ["consumable_pain_salve": 1], loadout: loadout,
                    medalOffset: offset
                )
                print("CH30_AUDIT_BUILD Q\(q) medal=\(offset) outcome=\(result.session.outcome) HP=\(result.session.playerHP) cycles=\(result.session.completedBossCycles) time=\(result.seconds)")
                #expect(result.session.outcome == .victory)
                #expect(result.session.playerHP >= 100)
                if q == 28 || q == 29 { #expect(result.session.completedBossCycles == 5) }
            }
        }
    }

    @Test func finalApproachHasARecoverableNoMaskRoute() throws {
        let sequence: [FoolSkillID] = [.fabricatedEvidence, .identityDisplacement,
                                       .mirrorPursuit, .absurdFinale]
        for (q, minimumRemainingHP) in [(27, 220), (29, 250)] {
            let budget = (1..<q).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for: $0)?.talentPoints }.reduce(0, +)
            let talents = HermitTalentAllocation.restored(
                (0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" }, budget: budget
            )
            var loadout = MPCChapterOneLoadout(normalSkillIDs: sequence, isUltimateUnlocked: true,
                                               passiveIDs: [], relicIDs: ["relic_return_gift_clasp"])
            loadout.talents = talents
            loadout.churchGear = firstTenTowerGear
            let result = try NewMaskBalanceSimulator.run(
                q: q, sequence: sequence, mask: false,
                consumables: ["consumable_pain_salve": 1], loadout: loadout, medalOffset: 6
            )
            #expect(result.session.outcome == .victory)
            #expect(result.session.playerHP >= minimumRemainingHP)
        }
    }

    @Test func legalBuildSweep() throws {
        for q in 5...30 {
            let sequences: [[FoolSkillID]]
            switch q {
            case 5...7: sequences = [[.sidestepStrike]]
            case 8...9: sequences = [[.identityDisplacement,.sidestepStrike],[.sidestepStrike,.identityDisplacement]]
            case 10: sequences = [[.fabricatedEvidence,.sidestepStrike],[.identityDisplacement,.sidestepStrike]]
            case 11: sequences = [[.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.sidestepStrike]]
            case 12: sequences = [[.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.absurdFinale],[.sidestepStrike,.fabricatedEvidence,.mirrorPursuit,.absurdFinale]]
            default: sequences = [[.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.absurdFinale],[.sidestepStrike,.fabricatedEvidence,.mirrorPursuit,.absurdFinale],[.fabricatedEvidence,.mirrorPursuit,.turnTheTables,.absurdFinale]]
            }
            let budget = (1..<q).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for:$0)?.talentPoints }.reduce(0,+)
            let talents = HermitTalentAllocation.restored((0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" }, budget:budget)
            var passives = ["relic_salt_sealed_breathing_bag","relic_return_gift_clasp"]
            if q >= 10 { passives += ["relic_deferred_stamp"] }
            if q >= 15 { passives += ["relic_reflecting_ink_mirror"] }
            if q >= 19 { passives += ["relic_sealed_paperweight"] }
            if q >= 21 { passives += ["relic_countertide_anchor"] }
            if q >= 27 { passives += ["relic_ownership_severing_needle"] }
            var wins: [String] = [], bestRemaining = Int.max
            for (index, sequence) in sequences.enumerated() {
                for passive in passives {
                    for offset in [6.0,14.0] {
                        var loadout = MPCChapterOneLoadout(normalSkillIDs:sequence,isUltimateUnlocked:q>=14,passiveIDs:[],relicIDs:[passive])
                        loadout.talents = talents
                        if q >= 27 { loadout.churchGear = firstTenTowerGear }
                        let r = try NewMaskBalanceSimulator.run(q:q,sequence:sequence,mask:false,consumables:["consumable_pain_salve":1],loadout:loadout,medalOffset:offset)
                        bestRemaining = min(bestRemaining,r.session.enemies.filter(\.isAlive).reduce(0) {$0+$1.hp})
                        if r.session.outcome == .victory { wins.append("seq\(index):\(passive):\(offset):\(Int(r.seconds))s:\(r.session.playerHP)HP") }
                    }
                }
            }
            print("CH30_BALANCE Q\(q) wins=\(wins.count) bestEnemy=\(bestRemaining) samples=\(wins.prefix(3))")
            // All Q gates must have at least one legal no-mask-exhaustion recovery route.
            #expect(!wins.isEmpty, "Q\(q) no legal tested victory")
        }
    }
}
