import Testing
@testable import MistportCombatCore

@Suite("Prebattle tactical loop")
struct TacticalLoopTests {
    private let sixSkills: [FoolSkillID] = [
        .maskedWhisper,
        .fabricatedEvidence,
        .identityDisplacement,
        .mirrorPursuit,
        .sidestepStrike,
        .absurdFinale
    ]

    @Test("Sequence rank does not cap the equipped cards in a round")
    func sequence9Ring() throws {
        var loop = try MPCTacticalLoop(skillIDs: sixSkills, rank: .sequence9)

        #expect(loop.cardsPerAct == sixSkills.count)
        #expect(loop.nextAct().skillIDs == sixSkills)
        #expect(loop.nextAct().skillIDs == sixSkills)
    }

    @Test("Sequence 8 also executes every equipped card")
    func sequence8Ring() throws {
        var loop = try MPCTacticalLoop(skillIDs: sixSkills, rank: .sequence8)

        #expect(loop.nextAct().skillIDs == sixSkills)
        #expect(loop.nextAct().skillIDs == sixSkills)
    }

    @Test("A shorter loadout executes all equipped cards and restarts next round")
    func ringBoundary() throws {
        let skills = Array(sixSkills.prefix(4))
        var loop = try MPCTacticalLoop(skillIDs: skills, rank: .sequence8)

        let first = loop.nextAct()
        let second = loop.nextAct()
        let third = loop.nextAct()

        #expect(first.skillIDs == skills)
        #expect(first.cycle == 1)
        #expect(second.skillIDs == skills)
        #expect(second.cycle == 2)
        #expect(third.skillIDs == skills)
        #expect(third.cycle == 3)
    }

    @Test("Invalid tactical rings are rejected")
    func invalidRings() {
        #expect(throws: MPCTacticalLoopError.emptyRing) {
            _ = try MPCTacticalLoop(skillIDs: [], cardsPerAct: 2)
        }
        #expect(throws: MPCTacticalLoopError.tooManySkills(maximum: 6)) {
            _ = try MPCTacticalLoop(skillIDs: sixSkills + [.paperDouble], cardsPerAct: 2)
        }
        #expect(throws: MPCTacticalLoopError.invalidCardsPerAct) {
            _ = try MPCTacticalLoop(skillIDs: sixSkills, cardsPerAct: 2)
        }
    }

    @Test("Target rules are deterministic", arguments: [
        (MPCTacticalTargetRule.frontmost, "front"),
        (MPCTacticalTargetRule.rearmost, "support"),
        (MPCTacticalTargetRule.lowestHP, "wounded"),
        (MPCTacticalTargetRule.supportFirst, "support"),
        (MPCTacticalTargetRule.bossFirst, "boss")
    ])
    func targetRules(input: (rule: MPCTacticalTargetRule, expected: String)) {
        #expect(MPCTacticalTargetResolver.resolve(rule: input.rule, targets: targets) == input.expected)
    }

    @Test("Previous target falls back when it is dead")
    func deadPreviousTargetFallback() {
        let resolved = MPCTacticalTargetResolver.resolve(
            rule: .previousTarget,
            targets: targets,
            previousTargetID: "dead",
            fallbackRule: .supportFirst
        )

        #expect(resolved == "support")
    }

    private var targets: [MPCTacticalTarget] {
        [
            .init(id: "front", currentHP: 900, maximumHP: 1_000, formationOrder: 0),
            .init(id: "wounded", currentHP: 100, maximumHP: 1_000, formationOrder: 1),
            .init(id: "boss", currentHP: 2_000, maximumHP: 2_000, formationOrder: 2, isBoss: true),
            .init(id: "support", currentHP: 700, maximumHP: 700, formationOrder: 3, isSupport: true),
            .init(id: "dead", currentHP: 0, maximumHP: 500, formationOrder: 4, isSupport: true)
        ]
    }
}
