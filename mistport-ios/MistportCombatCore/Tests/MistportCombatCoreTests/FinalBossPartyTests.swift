import Foundation
import Testing
@testable import MistportCombatCore

/// Q28–Q30 final-boss party (2026-10-10, user): the hero plus AI 诺恩 (protector) and
/// 奥黛尔 (healer) against the sovereign. Rules only; tuning lives in the balance suites.
@Suite("Final-boss party")
struct FinalBossPartyTests {
    typealias Session = MPCChapterOneEncounterSession
    let norn = "ally_norn_kade", odelle = "ally_odelle_finn"
    let hero = Session.partyPlayerUnitID
    let loop: [FoolSkillID] = [.sidestepStrike, .fabricatedEvidence, .mirrorPursuit, .absurdFinale]

    func session(_ q: Int, hp: Int = 1_000, loop: [FoolSkillID]? = nil,
                 party: MPCPartyPersistentState? = nil) throws -> Session {
        var loadout = MPCChapterOneLoadout(normalSkillIDs: loop ?? self.loop, isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        loadout.churchGear = .init(towerDepth: 100) // the Q30 tower check met, no extra stats
        return try .start(encounterID: String(format: "chapter01_q%02d_encounter", q),
                          party: party ?? .init(playerHP: hp, playerMaxHP: hp),
                          companionIDs: MPCChapterOneCatalog.finalBossPartyIDs, loadout: loadout)
    }
    func boss(_ s: Session) -> MPCRuntimeEnemy { s.enemies.first { $0.contentID == "boss_chronarch_sovereign" }! }
    /// One sovereign beat. `shielded` raises a full (40%-capped) shield first, so a lone hero
    /// survives phase two's health-share blows while the test walks the loop.
    func act(_ s: inout Session, at time: TimeInterval, shielded: Bool = false) throws {
        let id = boss(s).id
        if shielded { s.grantPlayerShield(s.playerMaxHP) }
        s.commitEnemyImpact(from: id)
        try s.endRound(actingEnemyID: id, at: time)
    }
    func allies(at time: TimeInterval, _ s: inout Session) -> [MPCCompanionActionResolution] {
        _ = s.advanceRelicClock(at: time)
        return s.performCompanionActions(focusTargetID: boss(s).id)
    }

    @Test func partyStartsFullWithOneReviveWhateverThePersistentPartySays() throws {
        let worn = MPCPartyPersistentState(playerHP: 300, playerMaxHP: 1_000, allyHP: [norn: 5, odelle: 0, "allyA": 800],
                                           allyMaxHP: [norn: 1_600], sharedReviveCharges: 0)
        for q in 28...30 {
            let s = try session(q, party: worn)
            #expect(s.isPartyBossEncounter)
            #expect(s.activeCompanionIDs == [norn, odelle])
            #expect(s.allyHP == [norn: 1_600, odelle: 1_200] && s.allyMaxHP == s.allyHP)
            #expect(s.sharedReviveCharges == 1 && s.playerHP == 1_000)
        }
    }

    @Test func alliesNeverDamageTheQ28AndQ29SovereignBody() throws {
        var q28 = try session(28)
        for step in 0..<20 { _ = allies(at: Double(step) * 2, &q28) }
        #expect(boss(q28).hp == boss(q28).maxHP && q28.outcome == .inProgress)
        #expect(q28.damageBySource[norn, default: 0] == 0 && q28.damageBySource[odelle, default: 0] == 0)

        var q29 = try session(29)
        let escortsBefore = q29.enemies.filter { $0.contentID != "boss_chronarch_sovereign" }.map(\.hp).reduce(0, +)
        for step in 0..<20 { _ = allies(at: Double(step) * 2, &q29) }
        let escortsAfter = q29.enemies.filter { $0.contentID != "boss_chronarch_sovereign" }.map(\.hp).reduce(0, +)
        #expect(boss(q29).hp == boss(q29).maxHP)
        #expect(escortsAfter < escortsBefore)
        #expect(q29.damageBySource[norn, default: 0] + q29.damageBySource[odelle, default: 0] == escortsBefore - escortsAfter)
    }

    @Test func slamHitsEveryStandingAlly() throws {
        var s = try session(28, hp: 100_000)
        var time = 0.0
        while boss(s).currentIntent != "slam" { try act(&s, at: time); time += 1 }
        try act(&s, at: time)
        let beat = try #require(s.lastEnemyActionResolutions.first)
        let share = MPCProgressionWalls.partySlamAllyPercent
        #expect(beat.intent == "slam" && beat.playerDamage == MPCProgressionWalls.finalBossEarlyBlows["slam"])
        #expect(beat.allyDamage == [norn: 1_600 * share / 100, odelle: 1_200 * share / 100])
        #expect(s.allyHP == [norn: 1_600 - 1_600 * share / 100, odelle: 1_200 - 1_200 * share / 100])
    }

    @Test func protectorTakesTheThirteenthBlowOncePerLoop() throws {
        var s = try session(30)
        try act(&s, at: 0); try act(&s, at: 3)
        #expect(boss(s).currentIntent == "thirteenth_charge" && s.playerHP == 1_000 - 2 * 320)
        let actions = allies(at: 5, &s)
        #expect(s.armedInterceptAllyID == norn)
        #expect(actions.contains { $0.companionID == odelle && $0.targetID == hero && $0.amount > 0 })
        let hpBefore = s.playerHP
        try act(&s, at: 6)
        let beat = try #require(s.lastEnemyActionResolutions.first)
        let blow = 1_000 * MPCProgressionWalls.q30ChargeHealthPercent / 100
        #expect(beat.interceptedBy == norn && beat.playerDamage == 0 && s.playerHP == hpBefore)
        #expect(beat.allyDamage == [norn: blow * MPCProgressionWalls.partyInterceptPercent / 100])
        #expect(s.armedInterceptAllyID == nil)
        // The loop's one intercept is spent: nothing arms again before the next loop's blow.
        _ = allies(at: 9, &s)
        #expect(s.armedInterceptAllyID == nil)
    }

    @Test func aFallenProtectorStopsActingAndLosesTheSealTurn() throws {
        var s = try session(30, hp: 10_000)
        try act(&s, at: 0); try act(&s, at: 3)
        _ = allies(at: 5, &s)
        try act(&s, at: 6) // 60% of a 5200 blow: more than 诺恩's 1600
        #expect(s.lastEnemyActionResolutions.first?.allyDamage == [norn: 1_600])
        #expect(!s.isAllyStanding(norn) && s.isAllyStanding(odelle))
        let actions = allies(at: 10, &s)
        #expect(!actions.isEmpty && actions.allSatisfy { $0.companionID == odelle })
        #expect(s.nextNameSealTargetID == hero)
    }

    @Test func nameSealHoldsTheHerosNextCardUntilTheHealerLiftsIt() throws {
        var s = try session(30)
        _ = try s.applyPartyDamage(boss(s).maxHP * 45 / 100, to: boss(s).id)
        try act(&s, at: 0) // the phase-one strike lands, then the loop changes
        #expect(s.finalBossPhase == 2 && boss(s).currentIntent == "name_seal")
        #expect(s.nextNameSealTargetID == hero)
        try act(&s, at: 3)
        let beat = try #require(s.lastEnemyActionResolutions.first)
        #expect(beat.sealedSkillID == .sidestepStrike && beat.sealedAllyID == nil && beat.playerDamage == 120)
        #expect(s.sealedFoolSkillIDs(at: 3) == [.sidestepStrike] && !s.canUseFoolSkill(.sidestepStrike))
        #expect(ContinuousSkillScheduler().next(in: loop, at: 3, skipping: s.sealedFoolSkillIDs(at: 3)) == .fabricatedEvidence)
        #expect(s.sealedFoolSkillIDs(at: 3 + Double(MPCProgressionWalls.partySealSeconds)).isEmpty)
        let actions = allies(at: 4, &s)
        #expect(actions.contains { $0.companionID == odelle && $0.skillID == "ally_odelle_cleanse" && $0.targetID == hero })
        #expect(s.sealedFoolSkillIDs(at: 4).isEmpty && s.canUseFoolSkill(.sidestepStrike))
    }

    @Test func backstageChangeAlsoStrikesOutTheHerosSeal() throws {
        var s = try session(30, loop: [.sidestepStrike, .backstageChange])
        _ = try s.applyPartyDamage(boss(s).maxHP * 45 / 100, to: boss(s).id)
        try act(&s, at: 0); try act(&s, at: 3)
        #expect(s.sealedFoolSkillIDs(at: 3) == [.sidestepStrike])
        _ = try s.useFoolSkill(.backstageChange, targetID: nil)
        #expect(s.sealedFoolSkillIDs(at: 3).isEmpty)
        #expect(s.triggeredEffects.contains { $0.contains("夺名封印") })
    }

    @Test func nameSealOnTheProtectorHoldsHimToHisLanternUntilCleansed() throws {
        var s = try session(30)
        _ = try s.applyPartyDamage(boss(s).maxHP * 45 / 100, to: boss(s).id)
        // Beats three seconds apart: the hero's six-second seal has lifted by the next loop.
        var time = 0.0
        try act(&s, at: time, shielded: true) // phase one strike → phase two
        try act(&s, at: time + 3, shielded: true); time += 6 // the first seal lands on the hero
        while boss(s).currentIntent != "name_seal" { try act(&s, at: time, shielded: true); time += 3 }
        #expect(s.nextNameSealTargetID == norn && s.outcome == .inProgress && s.sealedFoolSkillIDs(at: time).isEmpty)
        try act(&s, at: time, shielded: true)
        let beat = try #require(s.lastEnemyActionResolutions.first)
        #expect(beat.sealedAllyID == norn && beat.playerDamage == 0)
        #expect(beat.allyDamage == [norn: 1_600 * MPCProgressionWalls.q30SealHealthPercent / 100])
        #expect(s.isAllySealed(norn))
        // Next comes a strike, then the slam, then the thirteenth blow. Held to his basic
        // attack, 诺恩 lifts his lantern; 奥黛尔 lifts the seal in the same beat.
        let actions = allies(at: time + 0.5, &s)
        #expect(actions.contains { $0.companionID == norn && $0.skillID == "ally_armor_break" && $0.targetID == boss(s).id })
        #expect(actions.contains { $0.companionID == odelle && $0.skillID == "ally_odelle_cleanse" && $0.targetID == norn })
        #expect(!s.isAllySealed(norn))
    }

    @Test func aSealedProtectorCannotArmTheIntercept() throws {
        var s = try session(30)
        _ = try s.applyPartyDamage(boss(s).maxHP * 45 / 100, to: boss(s).id)
        var time = 0.0
        try act(&s, at: time, shielded: true); try act(&s, at: time + 1, shielded: true); time += 2
        while boss(s).currentIntent != "name_seal" { try act(&s, at: time, shielded: true); time += 1 }
        try act(&s, at: time, shielded: true) // 诺恩 sealed
        while boss(s).currentIntent != "thirteenth_charge" { time += 1; try act(&s, at: time, shielded: true) }
        #expect(s.isAllySealed(norn) && s.outcome == .inProgress)
        _ = allies(at: time + 0.5, &s) // candidates are fixed before 奥黛尔's cleanse resolves
        #expect(s.armedInterceptAllyID == nil)
        let hp = s.playerHP
        try act(&s, at: time + 1)
        #expect(s.lastEnemyActionResolutions.first?.interceptedBy == nil && s.playerHP < hp)
    }

    @Test func q30LoopFollowsTheSovereignsHealth() throws {
        var s = try session(30, hp: 100_000)
        #expect(s.finalBossPhase == 1 && boss(s).intentPattern == ["strike", "strike", "thirteenth_charge", "recover"])
        _ = try s.applyPartyDamage(boss(s).maxHP * 41 / 100, to: boss(s).id)
        #expect(boss(s).intentPattern.count == 4) // the loop changes only when the sovereign acts
        try act(&s, at: 0)
        #expect(s.finalBossPhase == 2)
        #expect(boss(s).intentPattern == ["name_seal", "strike", "slam", "thirteenth_charge", "recover"])
        #expect(boss(s).intentIndex.isMultiple(of: 5) && boss(s).currentIntent == "name_seal")
        let before = boss(s).intentIndex
        _ = try s.applyPartyDamage(boss(s).maxHP * 30 / 100, to: boss(s).id)
        try act(&s, at: 1)
        #expect(s.finalBossPhase == 3)
        #expect(boss(s).intentPattern == ["slam", "name_seal", "thirteenth_charge", "strike"])
        #expect(boss(s).intentIndex > before && boss(s).currentIntent == "slam")
        #expect(s.triggeredEffects.contains { $0.contains("狂暴") })
    }

    @Test func aFallenHeroWaitsForTheHealersReviveWhileTheProtectorFightsOn() throws {
        var s = try session(30, hp: 100)
        var time = 0.0
        while !s.playerIsDown { try act(&s, at: time); time += 1 } // strike, strike, thirteenth blow
        let down = time - 1
        #expect(s.outcome == .inProgress && s.playerHP == 0 && s.sharedReviveCharges == 1)
        #expect(s.heroReviveAt == down + Double(MPCProgressionWalls.partyReviveTenths) / 10)
        #expect(throws: MPCEncounterRuntimeError.playerDown) { try s.useBasicAction(.damage, targetID: boss(s).id) }
        #expect(throws: MPCEncounterRuntimeError.playerDown) { try s.useFoolSkill(.sidestepStrike, targetID: boss(s).id) }
        // Blows meant for the hero land on the protector at the same share of his health.
        while boss(s).currentIntent != "strike" { try act(&s, at: time); time += 1 }
        try act(&s, at: time)
        let share = MPCProgressionWalls.q30StrikeHealthPercent
        #expect(s.lastEnemyActionResolutions.first?.playerDamage == 0)
        #expect(s.lastEnemyActionResolutions.first?.allyDamage == [norn: 1_600 * share / 100])
        // The allies' clock runs without any hero hit; the healer only channels.
        let bossHP = boss(s).hp
        let actions = s.advanceCompanions(at: time + 0.5, focusTargetID: boss(s).id)
        #expect(!actions.isEmpty && actions.allSatisfy { $0.companionID == norn })
        #expect(boss(s).hp < bossHP && s.playerIsDown)
        _ = s.advanceCompanions(at: s.heroReviveAt!, focusTargetID: boss(s).id)
        #expect(!s.playerIsDown && s.playerHP == 100 * MPCProgressionWalls.partyReviveHealthPercent / 100)
        #expect(s.sharedReviveCharges == 0 && s.heroReviveAt == nil)
        #expect(s.triggeredEffects.contains { $0.contains("唤回主角") })
    }

    @Test func theAlliesCanFinishTheSovereignWhileTheHeroIsDown() throws {
        var s = try session(30, hp: 100)
        _ = try s.applyPartyDamage(boss(s).hp - 60, to: boss(s).id)
        var time = 0.0
        while !s.playerIsDown { try act(&s, at: time); time += 1 }
        _ = s.advanceCompanions(at: time, focusTargetID: boss(s).id)
        #expect(s.outcome == .victory && s.playerHP == 0)
        #expect(s.damageBySource[norn, default: 0] > 0)
    }

    @Test func thePartyLosesOnlyWhenAllThreeAreDown() throws {
        var s = try session(30, hp: 100)
        var time = 0.0
        while !s.playerIsDown { try act(&s, at: time); time += 1 }
        // No ally clock runs here, so the hero stays down and the blows fall on the allies.
        while s.outcome == .inProgress, time < 200 {
            #expect(s.isAllyStanding(norn) || s.isAllyStanding(odelle))
            try act(&s, at: time); time += 1
        }
        #expect(s.outcome == .defeat)
        #expect(!s.isAllyStanding(norn) && !s.isAllyStanding(odelle) && s.playerHP == 0)
    }

    @Test func withNoAllyStandingAFallenHeroLoses() throws {
        // Q28 without its allies (an explicit empty list): nobody stands for the hero.
        var s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q28_encounter", party: .init(playerMaxHP: 100),
                                                        companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        var time = 0.0
        while s.outcome == .inProgress, time < 40 { try act(&s, at: time); time += 1 }
        #expect(s.outcome == .defeat && !s.playerIsDown)
    }

    @Test func thePartyNeverLeaksIntoTheNextBattle() throws {
        var campaign = MPCChapterOneCampaignState.fullyUnlockedTestState
        campaign.party = .init(playerHP: 700, playerMaxHP: 1_000, sharedReviveCharges: 1)
        let before = campaign.party
        var s = try session(30, party: campaign.party)
        try act(&s, at: 0); try act(&s, at: 3)
        _ = allies(at: 5, &s)
        try act(&s, at: 6)  // 诺恩 takes the thirteenth blow
        try act(&s, at: 9)  // recovery
        while !s.playerIsDown { try act(&s, at: 10) }
        _ = s.advanceCompanions(at: 13, focusTargetID: boss(s).id) // 奥黛尔's revive channel completes
        #expect(s.allyHP[norn, default: 0] < 1_600 && s.sharedReviveCharges == 0 && s.playerHP > 0 && s.outcome == .inProgress)
        _ = try s.applyPartyDamage(1_000_000, to: boss(s).id)
        #expect(s.outcome == .victory)
        campaign.completeEncounter(s)
        #expect(campaign.completedMissionIDs.contains("chapter01_q30"))
        #expect(campaign.party == before)

        let tower = try Session.start(encounterID: "church_tower_001", party: campaign.party, companionIDs: [])
        #expect(tower.activeCompanionIDs.isEmpty && tower.allyHP.isEmpty)
        #expect(tower.sharedReviveCharges == before.sharedReviveCharges && !tower.isPartyBossEncounter)
    }

    // MARK: Q30 离场祝福 (2026-10-10, user: a small easter egg)
    typealias Blessings = MPCFarewellBlessings
    typealias W = MPCProgressionWalls
    func blessed(_ hero: Blessings.Hero, _ sovereign: Blessings.Sovereign, hp: Int = 1_000,
                 party: MPCPartyPersistentState? = nil) throws -> Session {
        var s = try session(30, hp: hp, party: party)
        let applied = s.applyFarewellBlessings(.init(hero: hero, sovereign: sovereign))
        #expect(applied)
        return s
    }
    private struct SplitMix: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9; z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    @Test func farewellBlessingsAreQ30OnlyOnceAndBeforeTheFight() throws {
        let pair = Blessings(hero: .featherShelter, sovereign: .saltCrust)
        for q in [28, 29] {
            var s = try session(q)
            let effects = s.triggeredEffects
            let applied = s.applyFarewellBlessings(pair)
            #expect(!applied)
            #expect(s.farewellBlessings == nil && s.sharedReviveCharges == 1 && s.triggeredEffects == effects)
        }
        var tower = try Session.start(encounterID: "church_tower_001", companionIDs: [])
        let towerApplied = tower.applyFarewellBlessings(pair)
        #expect(!towerApplied && tower.farewellBlessings == nil)

        var s = try session(30)
        let effects = s.triggeredEffects
        #expect(s.farewellBlessings == nil)
        let applied = s.applyFarewellBlessings(pair)
        #expect(applied)
        #expect(s.farewellBlessings == pair && s.sharedReviveCharges == 1 + W.q30FeatherRevives)
        #expect(s.triggeredEffects == effects + ["伊莱娅的祝福：羽翼庇护", "追索者的赠礼：黑盐外壳"])
        let again = s.applyFarewellBlessings(.init(hero: .lampWick, sovereign: .coldBell))
        #expect(!again)
        #expect(s.farewellBlessings == pair && s.sharedReviveCharges == 1 + W.q30FeatherRevives && s.triggeredEffects.count == effects.count + 2)

        var started = try session(30)
        _ = try started.useBasicAction(.damage, targetID: boss(started).id)
        let late = started.applyFarewellBlessings(pair)
        #expect(!late && started.farewellBlessings == nil)
    }

    @Test func rollDrawsOneFromEachPoolWithTheCallersGenerator() {
        var a = SplitMix(state: 7), b = SplitMix(state: 7)
        var seen: Set<String> = []
        for _ in 0..<200 {
            let roll = Blessings.roll(using: &a), same = Blessings.roll(using: &b)
            #expect(roll == same)
            seen.insert(roll.hero.rawValue + "," + roll.sovereign.rawValue)
        }
        #expect(seen.count == 9)
        for hero in Blessings.Hero.allCases { #expect(hero.summary.hasPrefix(hero.name + "：")) }
        for gift in Blessings.Sovereign.allCases { #expect(gift.summary.hasPrefix(gift.name + "：")) }
        #expect(Blessings.Hero.lampWick.summary == "灯芯长明：你对瑟维安的伤害 +\(W.q30LampWickPercent)%")
    }

    @Test func lampWickRaisesOnlyTheHerosOwnDamageOnTheSovereign() throws {
        var plain = try session(30), lit = try blessed(.lampWick, .coldBell)
        for step in 0..<6 { _ = allies(at: Double(step) * 2.5, &plain); _ = allies(at: Double(step) * 2.5, &lit) }
        #expect(plain.damageBySource[norn, default: 0] > 0)
        #expect(lit.damageBySource[norn] == plain.damageBySource[norn] && lit.damageBySource[odelle] == plain.damageBySource[odelle])
        #expect(boss(lit).hp == boss(plain).hp)
        let plainHit = try plain.applyPartyDamage(1_000, to: boss(plain).id)
        let litHit = try lit.applyPartyDamage(1_000, to: boss(lit).id)
        #expect(plainHit == 1_000 && litHit == 1_000 * (100 + W.q30LampWickPercent) / 100)
    }

    @Test func saltCrustCutsEverySourceOnTheSovereign() throws {
        var plain = try session(30), crusted = try blessed(.nameLight, .saltCrust)
        let cut = { (damage: Int) in damage * (100 - W.q30SaltCrustPercent) / 100 }
        var allyHits = 0
        for step in 0..<6 {
            let a = allies(at: Double(step) * 2.5, &plain), b = allies(at: Double(step) * 2.5, &crusted)
            #expect(a.map(\.skillID) == b.map(\.skillID))
            for (x, y) in zip(a, b) where x.targetID == boss(plain).id && x.amount > 0 {
                allyHits += 1
                #expect(y.amount == cut(x.amount))
            }
        }
        #expect(allyHits > 0)
        let hit = try crusted.applyPartyDamage(1_000, to: boss(crusted).id)
        #expect(hit == cut(1_000))
    }

    @Test func featherShelterGivesASecondReviveAtItsOwnShare() throws {
        var s = try blessed(.featherShelter, .coldBell, hp: 100)
        #expect(s.sharedReviveCharges == 2 && s.persistentPartyState().sharedReviveCharges == 1)
        var time = 0.0
        for (revive, share) in [W.partyReviveHealthPercent, W.q30FeatherReviveHealthPercent].enumerated() {
            while !s.playerIsDown { try act(&s, at: time); time += 1 }
            let due = try #require(s.heroReviveAt)
            #expect(due == time - 1 + Double(W.partyReviveTenths) / 10) // her normal channel
            _ = s.advanceCompanions(at: due - 0.5, focusTargetID: boss(s).id) // their tick, so none lands on the revive
            _ = s.advanceCompanions(at: due, focusTargetID: boss(s).id)
            #expect(!s.playerIsDown && s.playerHP == 100 * share / 100)
            #expect(s.sharedReviveCharges == 1 - revive && s.persistentPartyState().sharedReviveCharges == 0)
            time = due + 1
        }
        #expect(s.triggeredEffects.filter { $0.contains("唤回主角") }.count == 2)
    }

    @Test func nameLightShortensEverySealForTheHeroAndTheAllies() throws {
        var s = try blessed(.nameLight, .coldBell)
        let seal = TimeInterval(W.q30NameLightSealSeconds)
        _ = try s.applyPartyDamage(boss(s).maxHP * 45 / 100, to: boss(s).id)
        try act(&s, at: 0, shielded: true) // phase-one strike, then the loop changes
        try act(&s, at: 3, shielded: true)
        #expect(s.lastEnemyActionResolutions.first?.sealedSkillID == .sidestepStrike)
        #expect(s.heroSealExpiresAt == 3 + seal && seal < TimeInterval(W.partySealSeconds))
        #expect(!s.sealedFoolSkillIDs(at: 3 + seal - 0.1).isEmpty && s.sealedFoolSkillIDs(at: 3 + seal).isEmpty)
        #expect(s.triggeredEffects.contains("夺名代签：\(FoolSkillID.sidestepStrike.rawValue)被封\(Int(seal))秒"))
        var time = 6.0
        while boss(s).currentIntent != "name_seal" { try act(&s, at: time, shielded: true); time += 3 }
        #expect(s.nextNameSealTargetID == norn)
        try act(&s, at: time, shielded: true)
        #expect(s.lastEnemyActionResolutions.first?.sealedAllyID == norn)
        #expect(s.allySealExpiresAt[norn] == time + seal)
        #expect(s.triggeredEffects.contains("夺名代签：诺恩·凯德\(Int(seal))秒内只能普攻"))
    }

    @Test func coldBellHitsHarderAndTheProtectorTakesHisShareOfIt() throws {
        let plainBlow = 1_000 * W.q30ChargeHealthPercent / 100
        let bellBlow = plainBlow * (100 + W.q30ColdBellPercent) / 100
        // Unguarded: behind a full shield the hero takes the bigger blow.
        var hit = try blessed(.nameLight, .coldBell)
        try act(&hit, at: 0, shielded: true); try act(&hit, at: 3, shielded: true)
        #expect(boss(hit).currentIntent == "thirteenth_charge")
        try act(&hit, at: 6, shielded: true)
        #expect(hit.playerHP == 1_000 - (bellBlow - 400))
        // 诺恩's intercept takes his 60% of the bigger blow.
        var guarded = try blessed(.nameLight, .coldBell)
        try act(&guarded, at: 0); try act(&guarded, at: 3)
        _ = allies(at: 5, &guarded)
        #expect(guarded.armedInterceptAllyID == norn)
        try act(&guarded, at: 6)
        let beat = try #require(guarded.lastEnemyActionResolutions.first)
        #expect(beat.interceptedBy == norn && beat.playerDamage == 0)
        #expect(beat.allyDamage == [norn: bellBlow * W.partyInterceptPercent / 100])
    }

    @Test func mistMendHealsOncePerPhaseEntryAndNeverRunsTheLoopBack() throws {
        var s = try blessed(.nameLight, .mistMend, hp: 100_000)
        let full = boss(s).maxHP, heal = full * W.q30MistMendPercent / 100
        let mends = { (s: Session) in s.triggeredEffects.filter { $0.hasPrefix("雾中续命") }.count }
        _ = try s.applyPartyDamage(full * 41 / 100, to: boss(s).id)
        #expect(boss(s).hp == full * 59 / 100 && mends(s) == 0) // the loop changes only when it acts
        try act(&s, at: 0, shielded: true)
        #expect(boss(s).hp == full * 59 / 100 + heal && boss(s).hp * 100 >= full * W.q30PhaseTwoBelowPercent)
        #expect(s.finalBossPhase == 2 && boss(s).intentPattern == Session.q30Pattern(phase: 2) && mends(s) == 1)
        #expect(s.triggeredEffects.contains("雾中续命：瑟维安回复\(heal)生命"))
        // Back above 60% it stays in phase two and does not heal again.
        try act(&s, at: 1, shielded: true); try act(&s, at: 2, shielded: true)
        #expect(boss(s).intentPattern == Session.q30Pattern(phase: 2) && boss(s).hp == full * 59 / 100 + heal && mends(s) == 1)
        _ = try s.applyPartyDamage(boss(s).hp - full * 29 / 100, to: boss(s).id)
        try act(&s, at: 3, shielded: true)
        #expect(boss(s).hp == full * 29 / 100 + heal && s.finalBossPhase == 3)
        #expect(boss(s).intentPattern == Session.q30Pattern(phase: 3) && mends(s) == 2)
        // Healed back above 30%, it stays enraged: the slam still takes the enraged share.
        let hp = s.playerHP
        try act(&s, at: 4, shielded: true)
        #expect(hp - s.playerHP == 100_000 * W.q30EnragedBlowHealthPercent / 100 - 40_000)
        for step in 5..<8 { try act(&s, at: Double(step), shielded: true) }
        #expect(boss(s).intentPattern == Session.q30Pattern(phase: 3) && mends(s) == 2)
        // Without the gift the same health runs exactly as before.
        var plain = try session(30, hp: 100_000)
        _ = try plain.applyPartyDamage(full * 41 / 100, to: boss(plain).id)
        try act(&plain, at: 0, shielded: true)
        #expect(boss(plain).hp == full * 59 / 100 && plain.finalBossPhase == 2)
    }

    @Test func farewellBlessingsNeverLeakIntoTheNextBattle() throws {
        var campaign = MPCChapterOneCampaignState.fullyUnlockedTestState
        campaign.party = .init(playerHP: 700, playerMaxHP: 1_000, sharedReviveCharges: 1)
        let before = campaign.party
        var s = try blessed(.featherShelter, .saltCrust, party: campaign.party)
        #expect(s.sharedReviveCharges == 2 && s.persistentPartyState().sharedReviveCharges == 1)
        _ = try s.applyPartyDamage(10_000_000, to: boss(s).id)
        #expect(s.outcome == .victory)
        campaign.completeEncounter(s)
        #expect(campaign.party == before)
        let again = try session(30, party: campaign.party)
        #expect(again.farewellBlessings == nil && again.sharedReviveCharges == 1 && !again.triggeredEffects.contains { $0.hasPrefix("伊莱娅") })
        let tower = try Session.start(encounterID: "church_tower_001", party: campaign.party, companionIDs: [])
        #expect(tower.farewellBlessings == nil && tower.sharedReviveCharges == before.sharedReviveCharges)
    }
}
