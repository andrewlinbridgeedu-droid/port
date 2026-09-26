import Testing
@testable import MistportCombatCore

@Suite("Generic combat status clock")
struct CombatStatusClockTests {
    private let illusion = MPCStatusDefinition(
        id: "illusion",
        clock: .playerActionEnd,
        baseDuration: 3,
        stackRule: .add,
        maxStacks: 4,
        refreshRule: .refreshToBase
    )

    @Test("A newly applied status does not tick at its first matching boundary")
    func newStatusDoesNotTickImmediately() throws {
        var timeline = MPCStatusTimeline()
        timeline.apply(illusion, stacks: 2)

        timeline.advance(.playerActionEnd)
        #expect(try #require(timeline["illusion"]).remainingDuration == 3)

        timeline.advance(.playerActionEnd)
        #expect(try #require(timeline["illusion"]).remainingDuration == 2)
    }

    @Test("Only the matching clock advances a status")
    func clocksAreIndependent() throws {
        var timeline = MPCStatusTimeline()
        timeline.apply(illusion)
        timeline.advance(.enemyActionEnd)
        timeline.advance(.roundEnd)
        timeline.advance(.chargeOnly)
        #expect(try #require(timeline["illusion"]).remainingDuration == 3)
    }

    @Test("Duration expires after the configured number of subsequent boundaries")
    func durationExpires() {
        var timeline = MPCStatusTimeline()
        timeline.apply(illusion)
        for _ in 0..<4 {
            timeline.advance(.playerActionEnd)
        }
        #expect(timeline["illusion"] == nil)
    }

    @Test("ADD stacking caps and refreshes duration")
    func addAndRefresh() throws {
        var timeline = MPCStatusTimeline()
        timeline.apply(illusion, stacks: 2)
        timeline.advance(.playerActionEnd)
        timeline.advance(.playerActionEnd)
        timeline.apply(illusion, stacks: 3)
        let refreshed = try #require(timeline["illusion"])
        #expect(refreshed.stacks == 4)
        #expect(refreshed.remainingDuration == 3)
    }

    @Test("Stack rules produce deterministic values", arguments: [
        (MPCStatusStackRule.setMax, 2),
        (.replace, 1),
        (.noStack, 2)
    ])
    func stackRules(rule: MPCStatusStackRule, expected: Int) throws {
        let definition = MPCStatusDefinition(
            id: "test",
            clock: .roundEnd,
            baseDuration: 2,
            stackRule: rule,
            maxStacks: 4
        )
        var timeline = MPCStatusTimeline()
        timeline.apply(definition, stacks: 2)
        timeline.apply(definition, stacks: 1)
        #expect(try #require(timeline["test"]).stacks == expected)
    }

    @Test("CHARGE_ONLY status expires only when its charge is consumed")
    func chargeOnly() {
        let evasion = MPCStatusDefinition(
            id: "evasion",
            clock: .chargeOnly,
            baseDuration: 0,
            stackRule: .replace,
            maxStacks: 1,
            refreshRule: .noRefresh
        )
        var timeline = MPCStatusTimeline()
        timeline.apply(evasion, charges: 1)
        for clock in MPCStatusClock.allCases {
            timeline.advance(clock)
        }
        #expect(timeline["evasion"] != nil)
        let consumed = timeline.consumeCharge(for: "evasion")
        #expect(consumed)
        #expect(timeline["evasion"] == nil)
    }

    @Test("Death clears all statuses")
    func deathCleanup() {
        var timeline = MPCStatusTimeline()
        timeline.apply(illusion)
        timeline.clearOnDeath()
        #expect(timeline.statuses.isEmpty)
    }
}
