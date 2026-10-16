import Foundation
import Testing
@testable import MistportCombatCore

/// Probe on the real loop (2026-10-15): a player whose mask is spent plays Q5–Q15 with the medal and
/// the audit's first arrangement; outcomes are printed, every battle must finish.
@Suite("Mask exhaustion balance probe 20260916")
struct MaskExhaustionBalance20260916Tests {
    @Test func exhaustedMaskEarnedBuildProbe() async throws {
        let rows = try await RealLoop.map(Array(5...15)) { q in (q, try RealLoop.noMask(q, MPCStageLoadout.orders(before: q)[0], medal: 6)) }
        for (q, r) in rows {
            #expect(r.session.outcome != .inProgress)
            print("EXHAUSTED_MASK q=\(q) outcome=\(r.session.outcome) time=\(r.seconds) hp=\(r.session.playerHP)")
        }
    }
}
