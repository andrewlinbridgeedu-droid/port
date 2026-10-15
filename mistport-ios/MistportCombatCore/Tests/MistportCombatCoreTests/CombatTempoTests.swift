import Testing
@testable import MistportCombatCore

/// Combat tempo samples (COMBAT_TEMPO_PLAN_20261001.md, user-approved 2026-10-01).
@Suite("Combat tempo: light attacks, parry, lighter authored hits, faster basics")
struct CombatTempoTests {
    @Test func onlyTheThreeSamplesUseIt() {
        for id in ["chapter01_q04_encounter", "church_tower_001", "church_bounty_b01"] { #expect(MPCCombatTempo.profile(encounterID: id) != nil) }
        for id in ["chapter01_q05_encounter", "church_tower_002", "church_bounty_b02"] { #expect(MPCCombatTempo.profile(encounterID: id) == nil) }
        #expect(MPCTempoChoice.off.resolve(encounterID: "church_tower_001") == nil)
    }

    @Test func thePhantomParriesLightHitsWithoutSpendingACharge() throws {
        var s = try MPCChapterOneEncounterSession.start(encounterID: "encounter_rain_01",
            loadout: MPCChapterOneLoadout(normalSkillIDs: [.maskedWhisper], passiveIDs: [], relicIDs: []))
        s.adoptTempo(.standard)
        let enemy = try #require(s.enemies.first)
        let first = s.resolveLightAttack(enemyID: enemy.id, at: 1)
        let open = try #require(first)
        #expect(!open.parried && open.damage == enemy.attack * 15 / 100)
        _ = try s.useFoolSkill(.maskedWhisper, targetID: enemy.id)
        let charges = s.masqueradeCharges
        #expect(charges > 0)
        let second = s.resolveLightAttack(enemyID: enemy.id, at: 2)
        let parried = try #require(second)
        #expect(parried.parried && parried.damage == max(1, enemy.attack * 15 / 100 * 50 / 100))
        #expect(s.masqueradeCharges == charges, "light hits never spend the phantom")
        #expect(s.triggeredEffects.contains { $0.hasPrefix("招架") })
    }

    @Test func authoredHitsAndBasicsAreScaled() throws {
        func session(_ tempo: MPCCombatTempo?) throws -> MPCChapterOneEncounterSession {
            var s = try MPCChapterOneEncounterSession.start(encounterID: "encounter_rain_01",
                loadout: MPCChapterOneLoadout(normalSkillIDs: [], passiveIDs: [], relicIDs: []))
            s.adoptTempo(tempo)
            return s
        }
        var before = try session(nil), after = try session(.standard)
        let target = try #require(before.enemies.first).id
        let basicBefore = try before.useBasicAction(.damage, targetID: target)
        let basicAfter = try after.useBasicAction(.damage, targetID: target)
        #expect(basicBefore > 0 && abs(basicAfter * 2 - basicBefore) <= 2)
        let start = (before.playerHP, after.playerHP)
        try before.endRound(); try after.endRound()
        let takenBefore = start.0 - before.playerHP, takenAfter = start.1 - after.playerHP
        #expect(takenBefore > 0)
        #expect(abs(takenAfter - takenBefore * 70 / 100) <= 1)
    }

    @Test func noLightAttackDuringACharge() throws {
        let floor = try #require(MPCChurchTowerCatalog.floor(number: 1))
        var st = try MPCChurchBattleStepper(encounterID: floor.id, loadout: MPCChurchTowerVerificationRunner.recommendedLoadout(for: floor))
        var lights = 0
        while !st.isFinished {
            let events = try st.step()
            for attack in events.lightAttacks {
                lights += 1
                let intent = st.session.enemies.first { $0.id == attack.enemyID }?.currentIntent ?? ""
                #expect(!intent.contains("charge"), "a charge telegraph stays clean")
            }
        }
        #expect(lights >= 5 && st.session.outcome == .victory)
    }

    @Test("a hound killed mid-charge ends Q4 instead of stalling it")
    func deadChargerEndsTheBattle() throws {
        let loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        var st = try MPCStoryBattleStepper(encounterID: "chapter01_q04_encounter", loadout: loadout, mask: .init(owned: true, teachingLoan: true))
        while !st.isFinished && st.now < 120 {
            var out: [MPCBattleInput] = []
            if st.maskIsReady(at: st.now), let c = st.q4CycleStart, st.now >= c + 7.8, st.now < c + 8.4 { out.append(.init(tick: st.tick, kind: .mask)) }
            _ = try st.step(out)
        }
        #expect(st.session.outcome == .victory)
        #expect(st.now < 70)
    }
}
