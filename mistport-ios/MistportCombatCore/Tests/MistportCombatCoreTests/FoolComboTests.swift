import Testing
@testable import MistportCombatCore

@Suite("Fool skills T01–T07")
struct FoolComboTests {
    @Test("T01: masked whisper base damage")
    func maskedWhisper() throws {
        let result = try FoolComboSimulator.resolve(
            skillID: .maskedWhisper,
            from: FoolComboState()
        )
        #expect(result.damageHits == [50])
        #expect(result.state.illusionStacks == 2)
    }

    @Test("T02: fabricated evidence uses existing illusion bonus")
    func fabricatedEvidence() throws {
        let result = try FoolComboSimulator.resolve(
            skillID: .fabricatedEvidence,
            from: FoolComboState(illusionStacks: 2)
        )
        #expect(result.damageHits == [63])
        #expect(result.state.illusionStacks == 3)
        #expect(result.state.fabricatedEvidenceCharges == 2)
    }

    @Test("T03: identity displacement converts illusion to misalignment")
    func identityDisplacement() throws {
        let result = try FoolComboSimulator.resolve(
            skillID: .identityDisplacement,
            from: FoolComboState(illusionStacks: 4, fabricatedEvidenceCharges: 2)
        )
        #expect(result.damageHits == [87])
        #expect(result.state.illusionStacks == 0)
        #expect(result.state.misalignmentStacks == 2)
        #expect(result.state.fabricatedEvidenceCharges == 1)
    }

    @Test("T04: mirror pursuit rounds both hits independently")
    func mirrorPursuit() throws {
        let result = try FoolComboSimulator.resolve(
            skillID: .mirrorPursuit,
            from: FoolComboState(misalignmentStacks: 2, fabricatedEvidenceCharges: 1)
        )
        #expect(result.damageHits == [62, 93])
        #expect(result.state.misalignmentStacks == 1)
        #expect(result.state.fabricatedEvidenceCharges == 0)
    }

    @Test("T05: sidestep strike prepares finale without consuming misalignment")
    func sidestepStrike() throws {
        let result = try FoolComboSimulator.resolve(
            skillID: .sidestepStrike,
            from: FoolComboState(misalignmentStacks: 1)
        )
        #expect(result.damageHits == [115])
        #expect(result.state.misalignmentStacks == 1)
        #expect(result.state.finaleReady)
    }

    @Test("T05A: masked whisper illusion immediately empowers sidestep strike")
    func illusionEmpowersSidestepStrike() throws {
        let result = try FoolComboSimulator.resolve(
            skillID: .sidestepStrike,
            from: FoolComboState(illusionStacks: 2)
        )
        #expect(result.damageHits.first == 124)
        #expect(result.state.illusionStacks == 2)
        #expect(result.state.finaleReady)
    }

    @Test("T06: absurd finale consumes setup and penetrates armor")
    func absurdFinale() throws {
        let result = try FoolComboSimulator.resolve(
            skillID: .absurdFinale,
            from: FoolComboState(misalignmentStacks: 1, finaleReady: true)
        )
        #expect(result.damageHits == [224])
        #expect(result.state.misalignmentStacks == 0)
        #expect(result.state.finaleReady == false)
    }

    @Test(
        "T07/T07A–D: complete combo matches the rebuilt Fool loop",
        arguments: [(0, 771), (10, 705), (15, 678), (20, 651), (25, 627)]
    )
    func completeCombo(targetDefense: Int, expectedTotal: Int) throws {
        let results = try FoolComboSimulator.standardCombo(targetDefense: targetDefense)
        let hits = results.flatMap(\.damageHits)
        #expect(hits.reduce(0, +) == expectedTotal)
        if targetDefense == 20 {
            #expect(hits == [50, 63, 85, 71, 71, 133, 178])
        }
    }
}
