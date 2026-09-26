import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Mask exhaustion balance probe 20260916")
struct MaskExhaustionBalance20260916Tests {
    @Test func exhaustedMaskEarnedBuildProbe() throws {
        for q in 5...15 {
            let seq: [FoolSkillID] = q < 8 ? [.sidestepStrike] : q <= 10 ? [.sidestepStrike,.identityDisplacement] : q == 11 ? [.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.sidestepStrike] : [.fabricatedEvidence,.identityDisplacement,.mirrorPursuit,.absurdFinale]
            let talents: HermitTalentAllocation = q >= 10 ? .restored(["trickery.0","trickery.1","trickery.2","trickery.3"],budget:4) : .init()
            let r = try ProgressionBalanceSimulator.run(q:q,sequence:seq,mask:false,talents:talents,ultimate:q>=14)
            #expect(r.session.outcome != .inProgress)
            print("EXHAUSTED_MASK q=\(q) outcome=\(r.session.outcome) time=\(r.seconds) hp=\(r.session.playerHP)")
        }
    }
}
