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
            _ = try s.useFoolSkill(.sidestepStrike, targetID: id)
            _ = try s.useFoolSkill(repeated ? .sidestepStrike : .identityDisplacement, targetID: id)
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
    /// Each case on the real loop (2026-10-15): the stage it opens at (never before the church's Q7), the
    /// tower gear a player on the daily pace holds then, the medal and no mask; the tower hand, the clasp or not.
    @Test func everyBountyHasLegalNoMaskVictoryRoute() async throws {
        let wins = try await RealLoop.map(MPCChurchBountyCatalog.all) { bounty -> String? in
            let stage = max(MPCChurchTowerCatalog.unlockMission, bounty.unlockMission)
            for passive in [nil, RealLoop.clasp] {
                for medal in [6.0, 14.0] {
                    let r = try RealLoop.church(bounty.encounterID, before: stage + 1, order: RealLoop.towerHand(before: stage + 1),
                                                gearThrough: RealLoop.paceFloor(after: stage), passive: passive, medalAt: medal)
                    if r.session.outcome == .victory { return "hp=\(r.session.playerHP) passive=\(passive ?? "none") medal=\(medal)" }
                }
            }
            return nil
        }
        for (bounty, win) in zip(MPCChurchBountyCatalog.all, wins) {
            print("BOUNTY_BALANCE \(bounty.id) \(win ?? "no route")")
            #expect(win != nil, "Bounty \(bounty.id)")
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
