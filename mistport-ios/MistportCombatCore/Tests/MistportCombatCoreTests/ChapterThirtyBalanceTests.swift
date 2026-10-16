import Foundation
import Testing
@testable import MistportCombatCore

/// Q27–Q30 on the real loop (2026-10-15): the production stepper with the party, the audit's
/// arrangements and the stage loadout (all talents earned so far, the walls' floors and relic).
@Suite("Thirty mission legal loadout balance")
struct ChapterThirtyBalanceTests {
    static let auditRoute = RealLoop.line("05,04,06,07") // 伪证→张冠李戴→双影→荒谬, the old player-audit route
    static let fourTalents = RealLoop.branch("trickery")

    /// Earned tower gear is growth that counts: four talents and no gear win Q27 rarely, the first ten floors more often.
    @Test func q27EarnedEquipmentMatters() async throws {
        let orders = MPCStageLoadout.orders(before: 27).enumerated().filter { $0.offset % 4 == 0 }.map(\.element) // a quarter of the lines
        let bare = try await RealLoop.map(orders) { try RealLoop.story(27, $0, gear: .init(), talents: Self.fourTalents).won }.filter { $0 }.count
        let earned = try await RealLoop.map(orders) { try RealLoop.story(27, $0, gear: MPCStageLoadout.towerGear(through: 10), talents: Self.fourTalents).won }.filter { $0 }.count
        #expect(earned > 2 * bare, "Q27 wins: \(bare) without gear, \(earned) with F10")
    }

    /// Q28/Q29 (survive five loops) with four talents at every medal time; the loops complete.
    @Test(arguments: [28, 29]) func fourTalentsSurviveTheEarlyMeetings(_ q: Int) throws {
        for medal in [6.0, 14.0] {
            let r = try RealLoop.story(q, Self.auditRoute, talents: Self.fourTalents, policy: .init(medalFrom: medal))
            #expect(r.won && r.session.playerHP >= 100, "Q\(q) medal \(medal)")
            #expect(r.session.completedBossCycles >= 5)
        }
    }

    /// Q30 (2026-10-10, user): won only with a good relic; spending the chapter's talents opens it.
    @Test func q30TalentsAndRelics() async throws {
        for medal in [6.0, 14.0] {
            #expect(try RealLoop.story(30, Self.auditRoute, policy: .init(medalFrom: medal)).won, "Q30 full talents medal \(medal)")
        }
        let orders = BountyRelicTests.q30Breakers // the strongest arrangements; every line: env audit
        let full = try await RealLoop.map(orders) { try MPCStoryVerificationRunner.audit(mission: 30, order: $0).won }.filter { $0 }.count
        let four = try await RealLoop.map(orders) { try RealLoop.story(30, $0, talents: Self.fourTalents).won }.filter { $0 }.count
        #expect(full > four, "Q30 talent growth: \(four)/\(orders.count) lines with four talents, \(full) with the chapter's")
        // The old simulator lost the four-talent clasp route; the real loop wins it (592 HP at medal 6) and
        // 33/168 arrangements with it. Q30 and its blessing tuning are fixed by the user; reported, not retuned.
        let fourWins = try RealLoop.story(30, Self.auditRoute, talents: Self.fourTalents).won
        withKnownIssue("Q30 four talents plus the clasp win on the real loop; user decision") { #expect(!fourWins) }
    }

    /// The last approach keeps a recoverable no-mask route with health to spare.
    @Test func finalApproachHasARecoverableNoMaskRoute() async throws {
        for (q, gear, minimum) in [(27, MPCStageLoadout.towerGear(through: 10), 220), (29, MPCStageLoadout.wallGear(beforeOrAt: 29), 250)] {
            let route = try await RealLoop.firstWin(RealLoop.orders(before: q)) { order in
                let r = try RealLoop.story(q, order, gear: gear); return r.won && r.session.playerHP >= minimum
            }
            #expect(route != nil, "Q\(q) has no line ending with \(minimum) HP")
        }
    }
}
