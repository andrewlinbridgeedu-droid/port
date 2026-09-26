import Testing
@testable import MistportCombatCore

struct PuppetCalibrationTests {
    @Test("Puppet armor, shield calibration and staggered slams are distinct beats")
    func threeBeats() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q12_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        let puppet = session.enemies[0]
        let partnerIntent = session.enemies[1].currentIntent
        #expect(puppet.currentIntent == "fortify")
        #expect(partnerIntent == "calibrate")
        #expect(try session.useBasicAction(.damage, targetID: puppet.id) == 30)
        session.grantPlayerShield(100)
        try session.endRound(actingEnemyID: puppet.id)
        #expect(session.playerShield == 100)
        #expect(session.enemies[0].currentIntent == "slam")
        #expect(session.enemyDefenseBonusBP(for: puppet.id) == 5000)
        try session.endRound(actingEnemyID: puppet.id)
        #expect(session.playerShield == 0)
        #expect(session.playerHP == session.playerMaxHP - (puppet.attack * 2 - 100))
        #expect(session.enemies[0].currentIntent == "calibrate")
        #expect(session.enemyDefenseBonusBP(for: puppet.id) == 0)
        session.grantPlayerShield(100)
        let hpBeforeCalibration = session.playerHP
        try session.endRound(actingEnemyID: puppet.id)
        #expect(session.playerShield == 0)
        #expect(session.playerHP == hpBeforeCalibration)
        #expect(session.enemies[0].currentIntent == "slam")
        #expect(try session.useBasicAction(.damage, targetID: puppet.id) == 60)
        try session.endRound(actingEnemyID: puppet.id)
        #expect(session.playerHP == hpBeforeCalibration - puppet.attack * 2)
        #expect(session.enemies[0].currentIntent == "fortify")
        #expect(session.enemies[1].currentIntent == partnerIntent)
    }
}
