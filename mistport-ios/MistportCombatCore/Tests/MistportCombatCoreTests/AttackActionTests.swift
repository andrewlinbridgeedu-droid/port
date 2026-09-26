import Testing
@testable import MistportCombatCore

@Suite("Deterministic attack action")
struct AttackActionTests {
    @Test("T13: ordinary attack hits deterministically")
    func deterministicHit() {
        let result = resolve(coefficients: [10_000])
        #expect(result.hitResult == .hit)
        #expect(result.damageHits == [83])
    }

    @Test("T14/T15: one evasion charge dodges the whole action", arguments: [
        [10_000],
        [7_000, 13_300]
    ])
    func evasionCoversWholeAction(coefficients: [Int]) {
        let result = resolve(coefficients: coefficients, evasion: 1, shield: 50)
        #expect(result.hitResult == .dodged)
        #expect(result.damageHits == Array(repeating: 0, count: coefficients.count))
        #expect(result.defenseState.evasionCharges == 0)
        #expect(result.defenseState.guardCharges == 0)
        #expect(result.defenseState.shield == 50)
        #expect(result.defenseState.hp == 1_000)
    }

    @Test("T16: unavoidable attack does not consume evasion")
    func unavoidableAttack() {
        let result = resolve(coefficients: [10_000], policy: .unavoidable, evasion: 1)
        #expect(result.hitResult == .hit)
        #expect(result.damageHits == [83])
        #expect(result.defenseState.evasionCharges == 1)
    }

    @Test("T17: guard applies once to the complete action")
    func guardReduction() {
        let result = resolve(coefficients: [10_000], guardCharges: 1)
        #expect(result.damageHits == [54])
        #expect(result.defenseState.guardCharges == 0)
    }

    @Test("T18: shield absorbs after guard")
    func shieldAfterGuard() {
        let result = resolve(coefficients: [10_000], guardCharges: 1, shield: 50)
        #expect(result.damageHits == [54])
        #expect(result.defenseState.shield == 0)
        #expect(result.defenseState.hp == 996)
    }

    @Test("T19: stage guard and active guard stack")
    func stackedReduction() {
        let result = resolve(
            coefficients: [10_000],
            guardCharges: 1,
            otherReductions: [1_500]
        )
        #expect(result.damageHits == [42])
    }

    private func resolve(
        coefficients: [Int],
        policy: MPCHitPolicy = .dodgeable,
        evasion: Int = 0,
        guardCharges: Int = 0,
        shield: Int = 0,
        otherReductions: [Int] = []
    ) -> MPCAttackResolution {
        MPCAttackActionResolver.resolve(
            MPCAttackAction(
                attack: 100,
                coefficientsBP: coefficients,
                targetDefense: 20,
                hitPolicy: policy
            ),
            against: MPCTargetDefenseState(
                evasionCharges: evasion,
                guardCharges: guardCharges,
                otherReductionsBP: otherReductions,
                shield: shield,
                hp: 1_000
            )
        )
    }
}
