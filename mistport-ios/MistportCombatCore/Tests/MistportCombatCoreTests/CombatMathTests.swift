import Testing
@testable import MistportCombatCore

@Suite("v0.5 fixed-point combat math")
struct CombatMathTests {
    @Test(
        "Standard Fool combo remains exact across defense values",
        arguments: [
            (0, [50, 66, 108, 81, 153, 168, 360], 986),
            (10, [45, 60, 98, 73, 139, 153, 336], 904),
            (15, [43, 57, 94, 70, 133, 146, 327], 870),
            (20, [42, 55, 90, 67, 127, 140, 316], 837),
            (25, [40, 53, 86, 64, 122, 134, 308], 807)
        ]
    )
    func standardCombo(targetDefense: Int, expectedHits: [Int], expectedTotal: Int) {
        let parameters = [
            (5_000, 0, 0),
            (6_000, 1_000, 0),
            (8_000, 3_500, 0),
            (7_000, 1_500, 0),
            (13_300, 1_500, 0),
            (16_800, 0, 0),
            (36_000, 0, 3_000)
        ]
        let hits = parameters.map { coefficient, bonus, penetration in
            MPCFixedPointCombatMath.damage(
                MPCDamageInput(
                    attack: 100,
                    coefficientBP: coefficient,
                    targetDefense: targetDefense,
                    outgoingBonusBP: bonus,
                    armorPenetrationBP: penetration
                )
            ).damageAfterDefense
        }

        #expect(hits == expectedHits)
        #expect(hits.reduce(0, +) == expectedTotal)
    }

    @Test("Configuration loads the rebuilt Fool values")
    func configurationLoads() throws {
        let configuration = try FoolCombatConfigurationLoader.bundled()

        #expect(configuration.schemaVersion == "1.1.0")
        #expect(configuration.rounding == "HALF_UP_PER_HIT")
        #expect(configuration.percentageScale == 10_000)
        #expect(configuration.player.maxHP == 1_000)
        #expect(configuration.player.normalSkillSlots == 4)
        #expect(configuration.skills.count == 9)
        #expect(configuration.enemyTemplates.count == 6)
    }
}
