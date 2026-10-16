import Foundation
import Testing
@testable import MistportCombatCore

/// Story contracts on the real loop (2026-10-15): the production story stepper, the audit's arrangements
/// (`MPCStageLoadout.orders`) and stage-legal loadouts. Replaces NewMaskBalanceSimulator and
/// ProgressionBalanceSimulator, which kept the old cadence and hands.
@Suite("Story balance on the real loop")
struct RealLoopStoryBalanceTests {
    @Test func everyMissionStillHasAWinningArrangement() async throws {
        let wins = try await RealLoop.map(Array(1...30)) { q in
            try RealLoop.orders(before: q).first { try MPCStoryVerificationRunner.audit(mission: q, order: $0).won }
        }
        for (q, order) in zip(1...30, wins) { #expect(order != nil, "Q\(q) has no winning arrangement on the real loop") }
    }

    /// User 2026-10-15: Q3 is won only with good mask play (1 of 2 orders), Q7 by 1 of 60. Do not loosen.
    @Test func earlyMarginsStayTight() async throws {
        let q3 = MPCStageLoadout.orders(before: 3), q7 = MPCStageLoadout.orders(before: 7)
        #expect(q3.count == 2 && q7.count == 60)
        let q3Wins = try await RealLoop.map(q3) { try MPCStoryVerificationRunner.audit(mission: 3, order: $0).won }.filter { $0 }.count
        let q3Unmasked = try await RealLoop.map(q3) { try MPCStoryVerificationRunner.audit(mission: 3, order: $0, policy: .init(mask: false)).won }.filter { $0 }.count
        let q7Wins = try await RealLoop.map(q7) { try MPCStoryVerificationRunner.audit(mission: 7, order: $0).won }.filter { $0 }.count
        #expect(q3Wins == 1 && q3Unmasked == 0)
        #expect(q7Wins == 1)
    }

    /// The same four cards, rearranged, still decide the outcome (Q12's 抢拍/碎镜连弹 swap is in OrderedSkillRulesTests):
    /// the hand of the first winning line loses in some other order.
    @Test(arguments: [8, 18, 22, 26]) func cardOrderStillDecides(_ q: Int) async throws {
        let orders = MPCStageLoadout.orders(before: q)
        let first = try #require(try await RealLoop.firstWin(RealLoop.orders(before: q)) { try MPCStoryVerificationRunner.audit(mission: q, order: $0).won })
        let hand = orders.filter { Set($0) == Set(first) }
        let won = try await RealLoop.map(hand) { try MPCStoryVerificationRunner.audit(mission: q, order: $0).won }
        #expect(won.contains(false), "Q\(q): \(RealLoop.name(first)) wins in every order")
    }

    @Test func earlyRetriesNeverRequireMedicine() throws {
        let q2 = try RealLoop.story(2, RealLoop.line("05,01"))
        #expect(q2.won && q2.medicinesUsed == 0 && q2.session.playerHP >= 100)
        let q3 = try RealLoop.story(3, RealLoop.line("05,01"))
        #expect(q3.won && q3.medicinesUsed == 0 && q3.maskUses > 0)
    }

    /// Q4: two flames each cycle; the mask must take both, every cycle, until the hound falls.
    @Test func q4NeedsEveryMaskWindow() throws {
        for order in MPCStageLoadout.orders(before: 4) {
            let good = try RealLoop.story(4, order)
            #expect(good.won, "Q4 \(RealLoop.name(order))")
            let cycles = Int(good.seconds / 20)
            for missed in 0..<min(3, cycles) {
                let bad = try RealLoop.story(4, order, policy: .init(skipQ4Cycle: missed))
                #expect(bad.session.outcome == .defeat, "Q4 \(RealLoop.name(order)) survives a missed cycle \(missed + 1)")
            }
        }
    }

    /// From Q5 the medal replaces the mask: each mission keeps a no-mask, no-medicine route with the clasp.
    @Test(arguments: Array(5...9)) func noMaskRouteFromQ5(_ q: Int) async throws {
        let tries = RealLoop.orders(before: q).flatMap { order in [6.0, 14.0].map { (order, $0) } }
        let win = try await RealLoop.firstWin(tries) { try RealLoop.noMask(q, $0.0, medal: $0.1).won }
        #expect(win != nil, "Q\(q) has no no-mask route")
        if let (order, medal) = win { #expect(try RealLoop.noMask(q, order, medal: medal).maskUses == 0) }
    }

    /// Q6's true ward: the clasp carries it at either medal time; with neither clasp nor medal it is lost.
    @Test func q6NeedsTheClaspOrLoses() async throws {
        let orders = MPCStageLoadout.orders(before: 6)
        for medal in [6.0, 14.0] {
            #expect(try await RealLoop.firstWin(orders) { try RealLoop.noMask(6, $0, medal: medal).won } != nil, "Q6 medal \(medal)")
        }
        let bare = try await RealLoop.map(orders) { try RealLoop.noMask(6, $0, medal: 999, passive: nil).won }
        #expect(!bare.contains(true))
    }

    /// Q10–Q15: every talent branch keeps a legal route, with or without the earned Lv2 cards.
    @Test func legalGrowthAndThreeBranches() async throws {
        struct Case: Sendable { let q: Int; let branch: String; let upgrade: Bool }
        let cases = (10...15).flatMap { q in ["trickery", "phantom", "omen"].flatMap { b in [false, true].map { Case(q: q, branch: b, upgrade: $0) } } }
        let found = try await RealLoop.map(cases) { c -> Bool in
            for order in RealLoop.orders(before: c.q) {
                for passive in [RealLoop.clasp, RealLoop.bag] {
                    for medal in [6.0, 14.0] {
                        let r = try RealLoop.noMask(c.q, order, medal: medal, passive: passive, salve: true,
                                                    talents: RealLoop.branch(c.branch), levels: c.upgrade)
                        if r.won, r.maskUses == 0, r.medicinesUsed <= 1 { return true }
                    }
                }
            }
            return false
        }
        for (c, ok) in zip(cases, found) { #expect(ok, "Q\(c.q) \(c.branch) upgrade=\(c.upgrade) has no legal route") }
    }

    /// Q15: who you hit first decides some fights (cores before 维娅 or her first).
    @Test func q15TargetPriorityChangesSurvival() async throws {
        var coresOnly = false, viaOnly = false
        for chunk in stride(from: 0, to: 168, by: 21) where !(coresOnly && viaOnly) {
            let orders = Array(MPCStageLoadout.orders(before: 15)[chunk..<min(168, chunk + 21)])
            let support = try await RealLoop.map(orders) { try RealLoop.story(15, $0, policy: .init(target: .supportFirst)).won }
            let body = try await RealLoop.map(orders) { try RealLoop.story(15, $0, policy: .init(target: .bodyFirst)).won }
            coresOnly = coresOnly || zip(support, body).contains { $0 && !$1 }
            viaOnly = viaOnly || zip(support, body).contains { !$0 && $1 }
        }
        #expect(coresOnly, "no arrangement survives only when the cores go first")
        #expect(viaOnly, "no arrangement survives only when 维娅 goes first")
    }
}
