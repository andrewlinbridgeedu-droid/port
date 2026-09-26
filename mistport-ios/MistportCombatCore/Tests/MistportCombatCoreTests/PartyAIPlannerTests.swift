import Testing
@testable import MistportCombatCore

@Suite("Party AI contract P01–P15")
struct PartyAIPlannerTests {
    @Test("A single unlocked companion can plan independently")
    func singleCompanionPlan() throws {
        let state = MPCPartyBattleState(playerUnitID: "player", units: [
            MPCPartyUnitState(id: "player", side: .party, hp: 1_000, maxHP: 1_000),
            MPCPartyUnitState(id: "ally", side: .party, hp: 800, maxHP: 800),
            MPCPartyUnitState(id: "enemy", side: .enemy, hp: 500, maxHP: 500)
        ])
        let action = MPCAIActionCandidate(
            actorUnitID: "ally", skillID: "strike", skillPriority: 1,
            targetUnitID: "enemy", kind: .damage, magnitude: 100
        )
        let plan = try #require(MPCPartyAIPlanner.chooseActions(
            state: state, candidatesByActor: ["ally": [action]], actorOrder: ["ally"]
        ))
        #expect(plan.actions == [action])
    }
    @Test("P01/P14: AI cannot consume player-reserved status")
    func reservedStatusIsFiltered() {
        let status = MPCPartyStatus(id: "misalignment", ownerUnitID: "player", reservedForCombo: true, alliesCanConsume: false)
        let state = makeState(enemyStatuses: [status])
        let candidate = damage(actor: "allyA", skill: "consume", target: "enemy", consumes: "misalignment")
        #expect(MPCPartyAIPlanner.legalCandidates([candidate], state: state).isEmpty)
    }

    @Test("P02: protector prevents a lethal announced hit")
    func protectorChoosesProtection() throws {
        var state = makeState(playerHP: 200)
        state.enemyIntent = MPCKnownEnemyIntent(targetUnitID: "player", expectedDamage: 300)
        let selected = try #require(plan(
            state: state,
            a: [protect(actor: "allyA", target: "player", prevention: 300), damage(actor: "allyA", skill: "poke", target: "enemy", amount: 100)],
            b: [damage(actor: "allyB", skill: "poke", target: "enemy", amount: 100)]
        ))
        #expect(selected.actions[0].kind == .protect)
    }

    @Test("P03: healer does not heal a full-health player")
    func noFullHealthHealing() {
        let state = makeState(playerHP: 1_000, playerShield: 300)
        let heal = action(actor: "allyB", skill: "heal", target: "player", kind: .heal, magnitude: 300)
        #expect(MPCPartyAIPlanner.legalCandidates([heal], state: state).isEmpty)
    }

    @Test("P04: damage ultimate is illegal against invulnerable boss")
    func noUltimateIntoInvulnerability() {
        let state = makeState(enemyInvulnerable: true)
        let ultimate = damage(actor: "allyA", skill: "ultimate", target: "enemy", amount: 999, ultimate: true)
        #expect(MPCPartyAIPlanner.legalCandidates([ultimate], state: state).isEmpty)
    }

    @Test("P05: second ally revalidates after first ally heals")
    func avoidOverhealAfterFirstAction() throws {
        let state = makeState(playerHP: 500)
        let healA = action(actor: "allyA", skill: "healA", target: "player", kind: .heal, magnitude: 500)
        let healB = action(actor: "allyB", skill: "healB", target: "player", kind: .heal, magnitude: 500)
        let attackB = damage(actor: "allyB", skill: "attackB", target: "enemy", amount: 100)
        let selected = try #require(plan(state: state, a: [healA], b: [healB, attackB]))
        #expect(selected.actions.map(\.skillID) == ["healA", "attackB"])
    }

    @Test("P06: a living ally revives the downed player")
    func revivePlayer() throws {
        let state = makeState(playerHP: 0)
        let revive = action(actor: "allyA", skill: "revive", target: "player", kind: .revive)
        let selected = try #require(plan(
            state: state,
            a: [revive, damage(actor: "allyA", skill: "attack", target: "enemy")],
            b: [damage(actor: "allyB", skill: "attack", target: "enemy")]
        ))
        #expect(selected.actions.contains { $0.kind == .revive })
    }

    @Test("P07: second ally cannot attack a target killed by first ally")
    func retargetAfterKill() throws {
        var state = makeState(enemyHP: 100)
        state.units["enemy2"] = MPCPartyUnitState(id: "enemy2", side: .enemy, hp: 500, maxHP: 500)
        let kill = damage(actor: "allyA", skill: "kill", target: "enemy", amount: 100)
        let stale = damage(actor: "allyB", skill: "stale", target: "enemy", amount: 100)
        let retarget = damage(actor: "allyB", skill: "retarget", target: "enemy2", amount: 100)
        let selected = try #require(plan(state: state, a: [kill], b: [stale, retarget]))
        #expect(selected.actions[1].targetUnitID == "enemy2")
    }

    @Test("P08: certain boss kill beats nonlethal defense")
    func certainBossKill() throws {
        let state = makeState(enemyHP: 100, enemyBoss: true)
        let kill = damage(actor: "allyA", skill: "finish", target: "enemy", amount: 100)
        let protect = protect(actor: "allyA", target: "player", prevention: 200)
        let selected = try #require(plan(
            state: state,
            a: [protect, kill],
            b: [action(actor: "allyB", skill: "support", target: "player", kind: .support)]
        ))
        #expect(selected.actions[0].skillID == "finish")
    }

    @Test("P09: equal scores use skill priority then target slot")
    func deterministicTieBreak() throws {
        let state = makeState()
        let lowerPriority = damage(actor: "allyA", skill: "z", target: "enemy", amount: 100, priority: 1, slot: 1)
        let higherPriority = damage(actor: "allyA", skill: "a", target: "enemy", amount: 100, priority: 0, slot: 2)
        let selected = try #require(plan(
            state: state,
            a: [lowerPriority, higherPriority],
            b: [action(actor: "allyB", skill: "support", target: "player", kind: .support)]
        ))
        #expect(selected.actions[0].skillID == "a")
    }

    @Test("P10: joint plans are pruned to 128")
    func planLimit() throws {
        let state = makeState(enemyHP: 10_000)
        let a = (0..<20).map { damage(actor: "allyA", skill: "a\($0)", target: "enemy", amount: $0 + 1, priority: $0) }
        let b = (0..<20).map { damage(actor: "allyB", skill: "b\($0)", target: "enemy", amount: $0 + 1, priority: $0) }
        let selected = try #require(MPCPartyAIPlanner.chooseActions(
            state: state,
            candidatesByActor: ["allyA": a, "allyB": b],
            actorOrder: ["allyA", "allyB"],
            configuration: MPCPartyAIConfiguration(maxCandidatesPerAI: 20, maxJointPlans: 128)
        ))
        #expect(selected.generatedPlanCount == 128)
    }

    @Test("P11: hard budget returns the current best plan")
    func hardBudgetFallback() throws {
        let state = makeState()
        let selected = try #require(MPCPartyAIPlanner.chooseActions(
            state: state,
            candidatesByActor: [
                "allyA": [damage(actor: "allyA", skill: "a1", target: "enemy"), damage(actor: "allyA", skill: "a2", target: "enemy")],
                "allyB": [damage(actor: "allyB", skill: "b1", target: "enemy"), damage(actor: "allyB", skill: "b2", target: "enemy")]
            ],
            actorOrder: ["allyA", "allyB"],
            configuration: MPCPartyAIConfiguration(hardBudgetMilliseconds: 0)
        ))
        #expect(selected.evaluatedPlanCount == 1)
        #expect(selected.timedOut)
    }

    @Test("P12: CONSERVE rejects ultimates and long cooldowns")
    func conserveMode() {
        var state = makeState()
        state.tacticMode = .conserve
        let candidates = [
            damage(actor: "allyA", skill: "ultimate", target: "enemy", ultimate: true),
            action(actor: "allyA", skill: "long", target: "player", kind: .support, longCooldown: true),
            damage(actor: "allyA", skill: "basic", target: "enemy")
        ]
        #expect(MPCPartyAIPlanner.legalCandidates(candidates, state: state).map(\.skillID) == ["basic"])
    }

    @Test("P13: an explicitly ally-consumable status may be used")
    func allyConsumableStatus() {
        let status = MPCPartyStatus(id: "armor_break", ownerUnitID: "player", reservedForCombo: true, alliesCanConsume: true)
        let state = makeState(enemyStatuses: [status])
        let candidate = damage(actor: "allyA", skill: "consume", target: "enemy", consumes: "armor_break")
        #expect(MPCPartyAIPlanner.legalCandidates([candidate], state: state) == [candidate])
    }

    @Test("P15: same state produces identical actions 100 times")
    func repeatedDeterminism() throws {
        let state = makeState()
        let a = [damage(actor: "allyA", skill: "a2", target: "enemy"), damage(actor: "allyA", skill: "a1", target: "enemy")]
        let b = [damage(actor: "allyB", skill: "b2", target: "enemy"), damage(actor: "allyB", skill: "b1", target: "enemy")]
        let baseline = try #require(plan(state: state, a: a, b: b)).actions
        for _ in 0..<100 {
            #expect(plan(state: state, a: a, b: b)?.actions == baseline)
        }
    }

    private func makeState(
        playerHP: Int = 1_000,
        playerShield: Int = 0,
        enemyHP: Int = 1_000,
        enemyInvulnerable: Bool = false,
        enemyBoss: Bool = false,
        enemyStatuses: [MPCPartyStatus] = []
    ) -> MPCPartyBattleState {
        MPCPartyBattleState(playerUnitID: "player", units: [
            MPCPartyUnitState(id: "player", side: .party, hp: playerHP, maxHP: 1_000, shield: playerShield),
            MPCPartyUnitState(id: "allyA", side: .party, hp: 800, maxHP: 800),
            MPCPartyUnitState(id: "allyB", side: .party, hp: 800, maxHP: 800),
            MPCPartyUnitState(
                id: "enemy", side: .enemy, hp: enemyHP, maxHP: max(1_000, enemyHP),
                isInvulnerable: enemyInvulnerable, statuses: enemyStatuses, isBoss: enemyBoss
            )
        ])
    }

    private func plan(
        state: MPCPartyBattleState,
        a: [MPCAIActionCandidate],
        b: [MPCAIActionCandidate]
    ) -> MPCAIJointPlan? {
        MPCPartyAIPlanner.chooseActions(
            state: state,
            candidatesByActor: ["allyA": a, "allyB": b],
            actorOrder: ["allyA", "allyB"]
        )
    }

    private func damage(
        actor: String,
        skill: String,
        target: String,
        amount: Int = 100,
        ultimate: Bool = false,
        priority: Int = 0,
        slot: Int = 0,
        consumes: String? = nil
    ) -> MPCAIActionCandidate {
        action(
            actor: actor, skill: skill, target: target, slot: slot, kind: .damage,
            magnitude: amount, ultimate: ultimate, priority: priority, consumes: consumes
        )
    }

    private func protect(actor: String, target: String, prevention: Int) -> MPCAIActionCandidate {
        action(actor: actor, skill: "protect", target: target, kind: .protect, magnitude: prevention, prevents: prevention)
    }

    private func action(
        actor: String,
        skill: String,
        target: String,
        slot: Int = 0,
        kind: MPCAIActionKind,
        magnitude: Int = 0,
        ultimate: Bool = false,
        longCooldown: Bool = false,
        priority: Int = 0,
        consumes: String? = nil,
        prevents: Int = 0
    ) -> MPCAIActionCandidate {
        MPCAIActionCandidate(
            actorUnitID: actor,
            skillID: skill,
            skillPriority: priority,
            targetUnitID: target,
            targetSlot: slot,
            kind: kind,
            magnitude: magnitude,
            isUltimate: ultimate,
            isLongCooldown: longCooldown,
            consumesStatusID: consumes,
            preventsKnownDamage: prevents
        )
    }
}
