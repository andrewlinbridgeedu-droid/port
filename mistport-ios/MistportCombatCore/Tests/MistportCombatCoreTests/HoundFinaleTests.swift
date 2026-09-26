import Testing
@testable import MistportCombatCore

@Suite("Archive street progression")
struct ArchiveStreetProgressionTests {
    private func session(_ q: Int) throws -> MPCChapterOneEncounterSession {
        try .start(encounterID: "chapter01_q0\(q)_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.sidestepStrike, .identityDisplacement], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
    }
    @Test func gatekeeperOpeningRewardsTimingAndMaskProtects() throws {
        var s = try session(6)
        #expect(s.enemies.map(\.contentID) == ["enemy_archive_gatekeeper"])
        let id = s.enemies[0].id
        let guarded = try s.useBasicAction(.damage, targetID: id)
        #expect(guarded == 0)
        let wardHP = s.enemies[0].hp
        let blockedSkill = try s.useFoolSkill(.sidestepStrike, targetID: id)
        #expect(blockedSkill.targets.allSatisfy { $0.damage == 0 })
        #expect(s.enemies[0].hp == wardHP)
        #expect(try s.applyPartyDamage(10000, to: id, defenseIgnoreBP: 10000) == 0)
        try s.endRound(actingEnemyID: id)
        #expect(s.enemies[0].currentIntent == "archive_slam")
        #expect(try s.applyPartyDamage(100, to: id) == 100)
        let hp = s.playerHP
        try s.endRound(actingEnemyID: id)
        #expect(s.playerHP < hp)
        #expect(s.enemies[0].currentIntent == "recover")
        let opening = try s.useBasicAction(.damage, targetID: id)
        #expect(opening > 0)
        #expect(try s.applyPartyDamage(100, to: id) == 175)
        try s.endRound(actingEnemyID: id)
        #expect(s.enemies[0].currentIntent == "guard")
    }
    @Test func coreRepairsGuardButCannotRepairItselfOrDeadGuard() throws {
        var s = try session(7)
        let core = try #require(s.enemies.first { $0.contentID == "enemy_memory_leech_node" })
        let guards = s.enemies.filter { $0.contentID == "enemy_hollow_clockmaker" }
        #expect(guards.count == 2)
        _ = try s.applyPartyDamage(250, to: guards[0].id)
        _ = try s.applyPartyDamage(300, to: core.id)
        try s.endRound(actingEnemyID: core.id)
        #expect(s.enemies.first { $0.id == guards[0].id }?.hp == guards[0].maxHP - 70)
        #expect(s.enemies.first { $0.id == core.id }?.hp == core.maxHP - 300)
        _ = try s.applyPartyDamage(10000, to: core.id)
        let before = s.enemies.first { $0.id == guards[0].id }!.hp
        try s.endRound(actingEnemyID: core.id)
        #expect(s.enemies.first { $0.id == guards[0].id }?.hp == before)
    }
    @Test func coreFirstRequiresLessDamageThanIgnoringRepair() throws {
        func run(coreFirst: Bool) throws -> Int {
            var s = try session(7)
            var damage = 0
            for step in 0..<80 where s.outcome == .inProgress {
                let living = s.enemies.filter(\.isAlive)
                let target = (coreFirst ? living.first { $0.contentID == "enemy_memory_leech_node" } : living.first { $0.contentID == "enemy_hollow_clockmaker" }) ?? living[0]
                damage += try s.applyPartyDamage(120, to: target.id)
                if s.outcome == .inProgress, step % 2 == 0,
                   let core = s.enemies.first(where: { $0.contentID == "enemy_memory_leech_node" && $0.isAlive }) {
                    try s.endRound(actingEnemyID: core.id)
                }
            }
            #expect(s.outcome == .victory)
            return damage
        }
        #expect(try run(coreFirst: false) > run(coreFirst: true))
    }
    @Test func devourEscalatesAndFourStacksDelayInsteadOfCancelCommittedHit() throws {
        var s = try session(8)
        #expect(s.enemies.map(\.contentID) == ["enemy_memory_leech"])
        let id = s.enemies[0].id
        // Four earned identity casts create four stacks; the mask no longer grants misrecognition.
        for _ in 0..<4 { _ = try s.useFoolSkill(.identityDisplacement, targetID: id, usesRealtimeCooldown: true) }
        try s.endRound(actingEnemyID: id)
        try s.endRound(actingEnemyID: id)
        try s.endRound(actingEnemyID: id)
        try s.endRound(actingEnemyID: id)
        #expect(s.enemies[0].currentIntent == "name_devour")
        _ = try s.useFoolSkill(.identityDisplacement, targetID: id, usesRealtimeCooldown: true)
        let hp = s.playerHP
        try s.endRound(actingEnemyID: id)
        #expect(s.nameDevourCount == 0)
        #expect(s.playerHP == hp)
        #expect(s.enemies[0].currentIntent == "name_devour")
        try s.endRound(actingEnemyID: id)
        #expect(s.nameDevourCount == 1)
        #expect(s.masqueradeCharges == 0)
    }
    @Test func earnedQ8TimelineControlBuysTime() throws {
        var controlled = try session(8)
        var ordinary = try session(8)
        let id = controlled.enemies[0].id
        // Four deliberate identity casts build misidentification; mask no longer adds it.
        for _ in 0..<4 {
            _ = try controlled.useFoolSkill(.identityDisplacement, targetID: id, usesRealtimeCooldown: true)
        }
        for clock in 0..<4 {
            try controlled.endRound(actingEnemyID: id, at: Double(clock))
            try ordinary.endRound(actingEnemyID: ordinary.enemies[0].id, at: Double(clock))
        }
        _ = try controlled.useFoolSkill(.identityDisplacement, targetID: id, usesRealtimeCooldown: true)
        let delayed = controlled.consumeEnemyDelay(for: id)
        #expect(delayed)
        let ordinaryDelayed = ordinary.consumeEnemyDelay(for: ordinary.enemies[0].id)
        #expect(!ordinaryDelayed)
        #expect(controlled.nameDevourCount == 0)
        try ordinary.endRound(actingEnemyID: ordinary.enemies[0].id, at: 5)
        #expect(ordinary.nameDevourCount == 1)
        #expect(controlled.playerHP > ordinary.playerHP)
    }

    @Test(arguments: [6, 7]) func archiveBattlesWithEarnedRealtimeActions(_ q: Int) throws {
        let loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false,
            passiveIDs: [], relicIDs: [MPCChapterOneCatalog.returnGiftClaspRelicID])
        let report = try NewMaskBalanceSimulator.run(q: q, sequence: [.sidestepStrike], mask: false,
            consumables: ["consumable_pain_salve": 1], loadout: loadout, medalOffset: 6)
        #expect(report.session.outcome == .victory)
        #expect(report.maskUses == 0)
    }

    @Test func repairTargetIsFrozenAndNeverRevives() throws {
        var s = try session(7)
        let core = try #require(s.enemies.first { $0.contentID == "enemy_memory_leech_node" })
        let guards = s.enemies.filter { $0.contentID == "enemy_hollow_clockmaker" }
        _ = try s.applyPartyDamage(100, to: guards[0].id)
        s.commitEnemyImpact(from: core.id)
        #expect(s.q7RepairTargetID == guards[0].id)
        _ = try s.applyPartyDamage(500, to: guards[1].id)
        #expect(s.q7RepairTargetID == guards[0].id)
        _ = try s.applyPartyDamage(10000, to: guards[0].id)
        try s.endRound(actingEnemyID: core.id)
        #expect(s.enemies.first { $0.id == guards[0].id }?.hp == 0)
        #expect(s.enemies.first { $0.id == guards[1].id }?.hp == 150)
    }
    @Test func committedDevourSurvivesLateControl() throws {
        var s = try session(8)
        let id = s.enemies[0].id
        for _ in 0..<4 { _ = try s.useFoolSkill(.identityDisplacement, targetID: id, usesRealtimeCooldown: true) }
        for _ in 0..<4 { try s.endRound(actingEnemyID: id) }
        s.commitEnemyImpact(from: id)
        _ = try s.useFoolSkill(.identityDisplacement, targetID: id, usesRealtimeCooldown: true)
        let hp = s.playerHP
        try s.endRound(actingEnemyID: id)
        #expect(s.nameDevourCount == 1)
        #expect(hp - s.playerHP == 450)
        #expect(s.enemies[0].delayedRounds == 1)
    }

}
