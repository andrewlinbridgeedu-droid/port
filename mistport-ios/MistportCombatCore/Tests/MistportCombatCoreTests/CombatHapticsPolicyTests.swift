import Testing
@testable import MistportCombatCore

@Suite("Confirmed combat haptic policy")
struct CombatHapticsPolicyTests {
    @Test func outgoingRequiresActualDamageExceptSuccessfulDefenseActions() {
        #expect(MPCCombatHapticCue.outgoing(skillID: nil, damage: 30) == .basic)
        #expect(MPCCombatHapticCue.outgoing(skillID: nil, damage: 0) == nil)
        #expect(MPCCombatHapticCue.outgoing(skillID: "fool_skill_01", damage: 200) == .sidestep)
        #expect(MPCCombatHapticCue.outgoing(skillID: "fool_skill_01", damage: 0) == nil)
        #expect(MPCCombatHapticCue.outgoing(skillID: "fool_skill_03", damage: 100) == nil)
        #expect(MPCCombatHapticCue.outgoing(skillID: "fool_skill_09", damage: 0) == .defense)
        #expect(MPCCombatHapticCue.outgoing(skillID: "fool_skill_02", damage: 0) == .maskActivate)
        #expect(MPCCombatHapticCue.outgoing(skillID: "unknown", damage: 100) == nil)
    }

    @Test func actualIncomingDamagePriorityAndThresholds() {
        func incoming(_ hp: Int, shield: Int = 0, blocked: Bool = false) -> MPCCombatHapticCue? {
            .incoming(hpLoss: hp, shieldLoss: shield, blocked: blocked, maxHP: 1000, isDefeated: false)
        }
        #expect(incoming(0) == nil)
        #expect(incoming(1) == .hurtLight)
        #expect(incoming(99) == .hurtLight)
        #expect(incoming(100) == .hurtMedium)
        #expect(incoming(300) == .hurtMedium)
        #expect(incoming(301) == .hurtHeavy)
        #expect(incoming(10, shield: 100, blocked: true) == .hurtLight)
        #expect(incoming(0, shield: 100, blocked: true) == .maskBlock)
        #expect(incoming(0, shield: 100) == .shield)
        #expect(MPCCombatHapticCue.incoming(hpLoss: 40, shieldLoss: 0, blocked: false, maxHP: 1000, isDefeated: false, isPeriodic: true) == nil)
        #expect(MPCCombatHapticCue.incoming(hpLoss: 40, shieldLoss: 0, blocked: false, maxHP: 1000, isDefeated: true, isPeriodic: true) == .defeat)
    }

    @Test func multipleVictimsAndDuplicateCallbacksOnlyPlayOnce() {
        var gate = MPCCombatHapticGate()
        let accepted1 = gate.allows(eventID: "cast-4", cue: .sidestep, at: 0)
        #expect(accepted1)
        let accepted2 = !gate.allows(eventID: "cast-4", cue: .sidestep, at: 0.01)
        #expect(accepted2)
        let accepted3 = !gate.allows(eventID: "cast-4", cue: .sidestep, at: 2)
        #expect(accepted3)
    }

    @Test func priorityPreemptionAndDroppedEventsNeverQueue() {
        var gate = MPCCombatHapticGate()
        let accepted4 = gate.allows(eventID: "a", cue: .basic, at: 0)
        #expect(accepted4)
        let accepted5 = !gate.allows(eventID: "b", cue: .basic, at: 0.1)
        #expect(accepted5)
        let accepted6 = gate.allows(eventID: "c", cue: .maskBlock, at: 0.11)
        #expect(accepted6)
        let accepted7 = !gate.allows(eventID: "d", cue: .ultimate, at: 0.12)
        #expect(accepted7)
        let accepted8 = !gate.allows(eventID: "b", cue: .basic, at: 2)
        #expect(accepted8)
    }

    @Test func rollingBudgetAndDefeatOverride() {
        var gate = MPCCombatHapticGate()
        let accepted9 = gate.allows(eventID: "a", cue: .basic, at: 0)
        #expect(accepted9)
        let accepted10 = gate.allows(eventID: "b", cue: .basic, at: 0.2)
        #expect(accepted10)
        let accepted11 = gate.allows(eventID: "c", cue: .basic, at: 0.4)
        #expect(accepted11)
        let accepted12 = !gate.allows(eventID: "d", cue: .hurtHeavy, at: 0.6)
        #expect(accepted12)
        let accepted13 = gate.allows(eventID: "e", cue: .defeat, at: 0.61)
        #expect(accepted13)
        let accepted14 = !gate.allows(eventID: "e", cue: .defeat, at: 0.62)
        #expect(accepted14)
        let accepted15 = !gate.allows(eventID: "f", cue: .basic, at: 1.0)
        #expect(accepted15)
        let accepted16 = gate.allows(eventID: "g", cue: .basic, at: 1.21)
        #expect(accepted16)
    }

    @Test func fourthEncounterSeparateInterceptionsAndReset() {
        var gate = MPCCombatHapticGate()
        let accepted17 = gate.allows(eventID: "fire-1", cue: .maskBlock, at: 8.45)
        #expect(accepted17)
        let accepted18 = gate.allows(eventID: "fire-2", cue: .maskBlock, at: 9.10)
        #expect(accepted18)
        gate.reset()
        let accepted19 = gate.allows(eventID: "fire-1", cue: .maskBlock, at: 0)
        #expect(accepted19)
        let accepted20 = !gate.allows(eventID: "invalid", cue: .basic, at: .nan)
        #expect(accepted20)
    }
}
