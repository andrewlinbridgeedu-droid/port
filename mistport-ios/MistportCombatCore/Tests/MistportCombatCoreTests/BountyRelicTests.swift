import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Bounty relics: mechanic counters in the separate bounty slot")
struct BountyRelicTests {
    func session(_ q: Int, relic: String?) throws -> MPCChapterOneEncounterSession {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        loadout.bountyRelicID = relic
        // Tower checks met without extra stats, so these tests isolate the relics.
        loadout.churchGear = .init(towerDepth: 100)
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
        #expect(ledger.stats == MPCChurchGearStats(attackBP: 3_600, maxHP: 270, damageReductionBP: 1_100, towerDepth: 10))
        #expect(ledger.retireBountyGear().isEmpty)
    }

    @Test func reverseSealCountsEachCalibrationHitTwice() throws {
        for relic in [nil, MPCBountyRelicCatalog.reverseSeal] {
            var s = try session(22, relic: relic)
            let clockmaker = s.enemies.first { $0.contentID == "enemy_hollow_clockmaker" }!
            #expect(clockmaker.currentIntent == "calibration")
            // Six hits: short of the twelve the Q22 wall asks for (2026-10-15), unless each counts twice.
            for _ in 0..<6 { _ = try s.useBasicAction(.damage, targetID: clockmaker.id) }
            try act(&s, clockmaker.id, at: 4.2)
            #expect(s.chapterVerificationFailed == (relic == nil))
            #expect(s.enemies.first { $0.id == clockmaker.id }!.currentIntent == "strike")
            let hp = s.playerHP
            try act(&s, clockmaker.id, at: 5.2)
            // Without the seal the failed blow takes a share of health that no gear outgrows.
            if relic == nil { #expect(s.playerHP <= max(0, hp - s.playerBaseMaxHP * MPCProgressionWalls.q22FailedBlowHealthPercent / 100 + s.playerMaxHP / 2)) }
            else { #expect(hp - s.playerHP < s.playerBaseMaxHP / 4) }
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
            while let hp = s.enemies.first(where: { $0.id == boss.id })?.hp,
                  hp * 100 >= boss.maxHP * MPCProgressionWalls.q30EnrageBelowPercent {
                _ = try s.useBasicAction(.damage, targetID: boss.id)
            }
            let hp = s.playerHP
            try act(&s, boss.id, at: 2)
            taken.append(hp - s.playerHP)
            guard relic != nil else {
                // Enraged blows take a share of health, not of the boss's attack.
                #expect(taken[0] >= min(hp, s.playerBaseMaxHP * MPCProgressionWalls.q30EnragedBlowHealthPercent / 100 * 3 / 4))
                continue
            }
            // Below the enrage line the loop is phase three's four beats (no recovery), entered
            // at the sovereign's next action; shields keep this solo hero standing through it.
            #expect(s.finalBossPhase == 3 && s.enemies.first { $0.id == boss.id }?.intentPattern == ["slam", "name_seal", "thirteenth_charge", "strike"])
            for step in 1...4 { s.grantPlayerShield(s.playerMaxHP); try act(&s, boss.id, at: 2 + Double(step) * 3) }
            #expect(s.outcome == .inProgress)
            #expect(s.completedBossCycles == 1)
            #expect(s.triggeredEffects.contains { $0.hasPrefix("绯月寿账签") })
        }
        #expect(taken[0] > taken[1])
    }

    /// Q30 arrangements that broke through before 2026-10-15: 37 won without the ledger at F100 (phase three's
    /// 70% blows), ten more with F80 gear (the 140% slam and a revive). The exhaustive check is the env audit.
    static let q30Breakers = ["11,12,04,07", "11,07,12,04", "12,04,11,07", "12,04,07,11", "04,07,11,12", "07,11,12,04", "05,04,06,07",
        "05,04,07,06", "05,06,04,07", "04,06,07,05", "04,07,05,06", "04,07,06,05", "06,05,04,07", "06,05,07,04", "06,04,07,05",
        "06,07,05,04", "07,05,04,06", "07,05,06,04", "07,06,05,04", "08,07,06,09", "06,07,09,08", "05,04,07,09", "05,04,09,07",
        "05,09,04,07", "04,05,09,07", "04,07,05,09", "04,07,09,05", "04,09,05,07", "04,09,07,05", "07,05,04,09", "07,05,09,04",
        "07,09,05,04", "07,09,04,05", "09,05,04,07", "09,04,05,07", "09,04,07,05", "09,07,05,04", "04,11,07,12", "08,07,09,06",
        "07,09,08,06"].map(RealLoop.line)
    static func wallLines(_ q: Int) -> [[FoolSkillID]] { q == 30 ? q30Breakers : MPCStageLoadout.orders(before: q) }

    /// The three mechanism walls on the real loop (2026-10-15, user: 让“必须带遗落物”重新成立): without the
    /// wall's relic every audit arrangement loses, even wearing all the tower open then (Q12 F30, Q22 F80,
    /// Q30 F100); wearing it with the floors earlier walls ask for wins often. Outfits and slower reaction
    /// profiles: `OrderedChapterBalanceAuditTests.wallAudit`.
    @Test(arguments: [(12, 30), (22, 80), (30, 100)]) func mechanismWallsNeedTheirRelic(_ q: Int, _ openFloor: Int) async throws {
        let orders = Self.wallLines(q)
        let bare = try await RealLoop.map(orders) { try RealLoop.story(q, $0, gear: MPCStageLoadout.towerGear(through: openFloor), relic: .some(nil)).won }
        #expect(!bare.contains(true), "Q\(q) falls without its relic: \(bare.filter { $0 }.count) lines")
        let worn = try await RealLoop.map(orders) { try RealLoop.story(q, $0).won }.filter { $0 }.count
        #expect(worn * 6 >= orders.count, "Q\(q) wears its relic but wins only \(worn)/\(orders.count)")
        if q == 22 { // The blank card cannot hold a failed check's blow, and 错认喜剧 cannot delay it.
            let carded = try await RealLoop.map(orders) { try RealLoop.story(22, $0, gear: MPCStageLoadout.towerGear(through: 80), relic: .some(nil), active: "relic_blank_name_card").won }
            #expect(!carded.contains(true))
        }
    }

    @Test func towerDepthComesFromTheDeepestWornPiece() {
        var ledger = MPCChurchGearLedger()
        #expect(ledger.stats.towerDepth == 0)
        for f in 1...50 { if let drop = MPCChurchGearCatalog.towerDrop(floor: f) { ledger.grant(drop.id) } }
        #expect(ledger.stats.towerDepth == 50)
        let equipped = ledger.equip("tower-f10-anchor-blade")
        #expect(equipped)
        #expect(ledger.stats.towerDepth == 40)
        #expect(MPCChurchGearCatalog.item("bounty-b01-broken-sword")?.towerFloor == nil)
        #expect(MPCProgressionWalls.meetsTowerFloor(mission: 18, gear: .init(towerDepth: 50)))
        #expect(!MPCProgressionWalls.meetsTowerFloor(mission: 18, gear: .init(towerDepth: 40)))
        #expect(MPCProgressionWalls.meetsTowerFloor(mission: 8, gear: .init()))
    }

    /// The tower-checked walls on the real loop: gear from a decade short of the floor loses at every audit
    /// arrangement (Q30: its former breakers), the wall's relic worn; the floor's gear wins often (2026-10-15).
    @Test(arguments: [18, 26, 30]) func towerWallsNeedTheirFloor(_ q: Int) async throws {
        let floor = try #require(MPCProgressionWalls.wall(mission: q)?.towerFloor)
        let orders = Self.wallLines(q)
        let short = try await RealLoop.map(orders) { try RealLoop.story(q, $0, gear: MPCStageLoadout.towerGear(through: floor - 10)).won }
        #expect(!short.contains(true), "Q\(q) falls to F\(floor - 10) gear: \(short.filter { $0 }.count) lines")
        let deep = try await RealLoop.map(orders) { try RealLoop.story(q, $0, gear: MPCStageLoadout.towerGear(through: floor)).won }.filter { $0 }.count
        #expect(deep * 6 >= orders.count, "Q\(q) with F\(floor) gear wins only \(deep)/\(orders.count)")
    }
}
