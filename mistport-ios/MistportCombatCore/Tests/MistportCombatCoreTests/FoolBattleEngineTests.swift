import Testing
@testable import MistportCombatCore

@Suite("Fool battle rules T08–T12 and T20")
struct FoolBattleEngineTests {
    @Test("T08: shield absorbs before HP")
    func shieldOrder() {
        var player = FoolPlayerState(shield: 200)
        FoolBattleEngine.applyIncomingDamage(150, to: &player)
        #expect(player.hp == 1_000)
        #expect(player.shield == 50)
        FoolBattleEngine.applyIncomingDamage(100, to: &player)
        #expect(player.hp == 950)
        #expect(player.shield == 0)
    }

    @Test("T09: paper double redirects one hit without consuming shield")
    func paperDoubleCounter() {
        var player = FoolPlayerState(shield: 200, paperDoubleCounterCharges: 1, paperDoubleCounterDurationRounds: 1)
        var attacker = FoolEnemyState()
        FoolBattleEngine.resolveDirectEnemyHit(damage: 50, player: &player, attacker: &attacker)
        #expect(player.shield == 200)
        #expect(player.hp == 1_000)
        #expect(attacker.illusionStacks == 2)
        #expect(player.paperDoubleCounterCharges == 0)
    }

    @Test("T10: ordinary cards enter action-index cooldowns")
    func cooldownIndex() {
        var cooldown = FoolCooldownState(currentPlayerActionIndex: 1)
        cooldown.startCooldown(.maskedWhisper, reuseDelayActions: 2)
        #expect(cooldown.nextAvailable[.maskedWhisper] == 3)
        cooldown.currentPlayerActionIndex = 1
        #expect(!cooldown.isAvailable(.maskedWhisper))
        cooldown.currentPlayerActionIndex = 2
        #expect(!cooldown.isAvailable(.maskedWhisper))
        cooldown.currentPlayerActionIndex = 3
        #expect(cooldown.isAvailable(.maskedWhisper))
        cooldown.currentPlayerActionIndex = 4
        #expect(cooldown.isAvailable(.maskedWhisper))
    }

    @Test("T11: ultimate prepares every living enemy without cooldown resets")
    func namelessStage() throws {
        var state = FoolBattleState(
            enemies: Array(repeating: FoolEnemyState(), count: 3),
            cooldowns: FoolCooldownState(currentPlayerActionIndex: 10)
        )
        try FoolBattleEngine.useNamelessStage(state: &state)
        #expect(state.enemies.allSatisfy { $0.illusionStacks == 4 })
        #expect(state.cooldowns.nextAvailable.isEmpty)
        #expect(state.player.finaleReadyDurationActions == 3)
        #expect(state.player.stageGuardDurationRounds == 3)
    }

    @Test("T12: a boss receives resistant disorientation, never a skipped action")
    func bossResistance() {
        var enemy = FoolEnemyState(rank: .boss, illusionStacks: 4)
        let result = FoolBattleEngine.identityDisplacementControl(on: &enemy)
        #expect(!result.skipNextAction)
        #expect(enemy.misalignmentStacks == 2)
        #expect(result.resistantDisorientation)
        #expect(result.nextDamageReductionBP == 2_500)
        #expect(result.suppressSecondaryEffects)
    }

    @Test("T20: dodge prevents on-hit state and ordinary card remains available")
    func dodgedFabricatedEvidence() throws {
        var state = FoolBattleState(
            enemies: [FoolEnemyState(illusionStacks: 2, evasionCharges: 1)],
            cooldowns: FoolCooldownState(currentPlayerActionIndex: 2)
        )
        let result = try FoolBattleEngine.useFabricatedEvidence(state: &state, targetIndex: 0)
        #expect(result.hitResult == .dodged)
        #expect(result.damageHits == [0])
        #expect(state.enemies[0].illusionStacks == 2)
        #expect(state.enemies[0].evasionCharges == 0)
        #expect(state.cooldowns.isAvailable(.fabricatedEvidence))
    }

    @Test("Skill 8 dispels by priority; skill 9 cleanses by priority")
    func utilityPriority() {
        var player = FoolPlayerState(debuffs: [.dot, .stun, .damageDown])
        var enemy = FoolEnemyState(dispellableBuffs: [.regen, .attackUp, .defenseUp])
        FoolBattleEngine.useTurnTheTables(player: &player, enemy: &enemy)
        #expect(player.copiedBuff == .attackUp)
        #expect(enemy.dispellableBuffs == [.regen, .defenseUp])
        #expect(enemy.misalignmentStacks == 1)

        var state = FoolBattleState(
            player: player,
            cooldowns: FoolCooldownState(
                currentPlayerActionIndex: 6,
                nextAvailable: [.maskedWhisper: 10, .identityDisplacement: 7, .fabricatedEvidence: 12]
            )
        )
        FoolBattleEngine.useBackstageChange(state: &state)
        #expect(state.player.debuffs == [.dot, .damageDown])
        #expect(state.player.enhancedSetupCharges == 1)
        #expect(state.cooldowns.nextAvailable[.maskedWhisper] == 10)
        #expect(state.cooldowns.nextAvailable[.identityDisplacement] == 7)
        #expect(state.cooldowns.nextAvailable[.fabricatedEvidence] == 12)
    }
}
