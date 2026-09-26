import Testing
@testable import MistportCombatCore

@Suite("Church bounty runtime differences")
struct ChurchBountyRuntimeTests {
    @Test func captainIsProtectedOnlyWhileSeparateEscortsLive() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_bounty_b03", companionIDs: [])
        let captain = s.enemies.first { $0.contentID == "bounty_b03_drowned_captain" }!.id
        #expect(s.churchEscortedCaptainIDs == [captain])
        let before = s.enemies.first { $0.id == captain }!.hp
        _ = try s.applyPartyDamage(10000, to: captain)
        #expect(s.enemies.first { $0.id == captain }!.hp == before)
        for e in s.enemies.filter({ $0.contentID.hasPrefix("bounty_b03_escort_") }) { _ = try s.applyPartyDamage(10000, to: e.id) }
        #expect(s.churchEscortedCaptainIDs.isEmpty)
        _ = try s.applyPartyDamage(100, to: captain)
        #expect(s.enemies.first { $0.id == captain }!.hp < before)
    }
    @Test func bindLeavesFiniteDamageEvenWhenDirectHitIsMasked() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_bounty_b02", companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        let id = s.enemies[0].id
        try s.endRound(actingEnemyID: id, at: 0)
        _ = try s.useOwnedManualMasquerade(targetID: nil, isOwned: true, at: 1)
        let hp = s.playerHP
        try s.endRound(actingEnemyID: id, at: 1)
        #expect(s.playerHP == hp && s.masqueradeCharges == 1)
        #expect(s.churchBindingSourceIDs == [id])
        #expect(!s.churchSpittleActive)
        _ = s.advanceEmeraldPoison(at: 7)
        #expect(s.playerHP < hp)
        #expect(s.churchBindingSourceIDs.isEmpty)
        let after = s.playerHP
        _ = s.advanceEmeraldPoison(at: 50)
        #expect(s.playerHP == after)
    }
    @Test func overwritePunishesRepeatedActualSpellsAndShipmasterExposesAfterShield() throws {
        func incoming(repeated: Bool) throws -> Int {
            var s = try MPCChapterOneEncounterSession.start(encounterID: "church_bounty_b04", companionIDs: [], loadout: .init(normalSkillIDs: [.sidestepStrike, .identityDisplacement], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
            let id = s.enemies[0].id
            _ = try s.useFoolSkill(.sidestepStrike, targetID: id, usesRealtimeCooldown: true)
            _ = try s.useFoolSkill(repeated ? .sidestepStrike : .identityDisplacement, targetID: id, usesRealtimeCooldown: true)
            // Control can delay an action; consume that actual delay before advancing.
            while s.consumeEnemyDelay(for: id) {}
            while s.enemies[0].currentIntent != "bounty_overwrite" { try s.endRound(actingEnemyID: id, at: 0) }
            let hp = s.playerHP
            try s.endRound(actingEnemyID: id, at: 1)
            return hp - s.playerHP
        }
        #expect(try incoming(repeated: true) > incoming(repeated: false))
        var ship = try MPCChapterOneEncounterSession.start(encounterID: "church_bounty_b06", companionIDs: [])
        let id = ship.enemies[0].id, hp = ship.enemies[0].hp
        _ = try ship.applyPartyDamage(100, to: id)
        #expect(ship.enemies[0].hp == hp)
        for _ in 0..<3 { try ship.endRound(actingEnemyID: id, at: 0) }
        #expect(ship.enemies[0].currentIntent == "recover")
        _ = try ship.applyPartyDamage(100, to: id)
        #expect(ship.enemies[0].hp == hp - 175)
    }
    @Test func everyBountyHasLegalNoMaskVictoryRoute() throws {
        for bounty in MPCChurchBountyCatalog.all {
            var wins = false
            let routes: [(Double, String?)] = [(6, nil), (14, nil), (6, "relic_return_gift_clasp"), (14, "relic_return_gift_clasp")]
            for (offset, passive) in routes {
                let s = try TowerHundredSimulator.run(encounterID: bounty.encounterID, mission: bounty.unlockMission, offset: offset, passive: passive)
                if s.outcome == .victory {
                    print("BOUNTY_BALANCE \(bounty.id) hp=\(s.playerHP) passive=\(passive ?? "none")")
                    wins = true; break
                }
            }
            #expect(wins, "Bounty \(bounty.id)")
        }
    }
    @Test func belltoadLeavesFinitePoisonThatEndsWithItsDeath() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_bounty_b07", companionIDs: [])
        let id = s.enemies[0].id
        for step in 0..<3 { try s.endRound(actingEnemyID: id, at: Double(step)) }
        #expect(s.churchSpittleActive)
        #expect(s.churchBindingSourceIDs.isEmpty)
        let hp = s.playerHP
        _ = s.advanceEmeraldPoison(at: 6)
        #expect(s.playerHP < hp)
        _ = try s.applyPartyDamage(10000, to: id)
        #expect(!s.churchSpittleActive)
    }
    @Test func mirenHasSeparateDefeatableDecoysAndTrueBody() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_bounty_b08", companionIDs: [])
        #expect(s.enemies.count == 3)
        let trueID = s.enemies.first { $0.contentID == "bounty_b08_miren" }!.id
        for echo in s.enemies.filter({ $0.contentID.hasPrefix("bounty_b08_mirror_") }) {
            _ = try s.applyPartyDamage(10000, to: echo.id)
        }
        #expect(s.outcome == .inProgress)
        #expect(s.enemies.first { $0.id == trueID }!.isAlive)
        _ = try s.applyPartyDamage(10000, to: trueID)
        #expect(s.outcome == .victory)
    }
    @Test func copperbackArmorAbsorbsDamageAndCanBeBroken() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_bounty_b09", companionIDs: [])
        let id = s.enemies[0].id
        let hp = s.enemies[0].hp
        try s.endRound(actingEnemyID: id, at: 0)
        #expect(s.enemyGiftShields[id, default: 0] > 0)
        _ = try s.applyPartyDamage(100, to: id)
        #expect(s.enemies[0].hp == hp)
        _ = try s.applyPartyDamage(1000, to: id)
        #expect(s.enemyGiftShields[id, default: 0] == 0)
        #expect(s.enemies[0].hp < hp)
    }
    @Test func lifeVesselTransfersOnlyToLivingOracle() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "church_bounty_b10", companionIDs: [])
        let oracle = s.enemies.first { $0.contentID == "bounty_b10_life_oracle" }!.id
        let vessel = s.enemies.first { $0.contentID == "bounty_b10_life_vessel" }!.id
        _ = try s.applyPartyDamage(500, to: oracle)
        let wounded = s.enemies.first { $0.id == oracle }!.hp
        try s.endRound(actingEnemyID: vessel, at: 0)
        try s.endRound(actingEnemyID: vessel, at: 1)
        let healed = s.enemies.first { $0.id == oracle }!.hp
        #expect(healed > wounded && healed - wounded <= 240)
        _ = try s.applyPartyDamage(10000, to: vessel)
        for step in 2..<6 { try s.endRound(actingEnemyID: oracle, at: Double(step)) }
        #expect(s.enemies.first { $0.id == oracle }!.hp == healed)
    }
}
