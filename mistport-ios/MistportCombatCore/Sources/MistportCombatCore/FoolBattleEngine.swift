import Foundation

public enum MPCEnemyRank: String, Codable, Sendable {
    case normal = "NORMAL"
    case elite = "ELITE"
    case boss = "BOSS"
}

public enum MPCBuffCategory: Int, CaseIterable, Codable, Sendable {
    case other = 0
    case regen = 1
    case damageReduction = 2
    case defenseUp = 3
    case attackUp = 4
}

public enum MPCDebuffCategory: Int, CaseIterable, Codable, Sendable {
    case other = 0
    case dot = 1
    case defenseDown = 2
    case damageDown = 3
    case silence = 4
    case stun = 5
}

public struct FoolEnemyState: Equatable, Sendable {
    public var rank: MPCEnemyRank
    public var illusionStacks: Int
    public var misalignmentStacks: Int
    public var evasionCharges: Int
    public var dispellableBuffs: [MPCBuffCategory]
    public var resistantDisorientationCharges: Int
    public var normalDisorientationDuration: Int

    public init(
        rank: MPCEnemyRank = .normal,
        illusionStacks: Int = 0,
        misalignmentStacks: Int = 0,
        evasionCharges: Int = 0,
        dispellableBuffs: [MPCBuffCategory] = [],
        resistantDisorientationCharges: Int = 0,
        normalDisorientationDuration: Int = 0
    ) {
        self.rank = rank
        self.illusionStacks = illusionStacks
        self.misalignmentStacks = misalignmentStacks
        self.evasionCharges = evasionCharges
        self.dispellableBuffs = dispellableBuffs
        self.resistantDisorientationCharges = resistantDisorientationCharges
        self.normalDisorientationDuration = normalDisorientationDuration
    }
}

public struct FoolPlayerState: Equatable, Sendable {
    public var hp: Int
    public var maxHP: Int
    public var shield: Int
    public var paperDoubleCounterCharges: Int
    public var paperDoubleCounterDurationRounds: Int
    public var finaleReadyDurationActions: Int
    public var stageGuardDurationRounds: Int
    public var enhancedSetupCharges: Int
    public var debuffs: [MPCDebuffCategory]
    public var copiedBuff: MPCBuffCategory?

    public init(
        hp: Int = 1_000,
        maxHP: Int = 1_000,
        shield: Int = 0,
        paperDoubleCounterCharges: Int = 0,
        paperDoubleCounterDurationRounds: Int = 0,
        finaleReadyDurationActions: Int = 0,
        stageGuardDurationRounds: Int = 0,
        enhancedSetupCharges: Int = 0,
        debuffs: [MPCDebuffCategory] = [],
        copiedBuff: MPCBuffCategory? = nil
    ) {
        self.hp = hp
        self.maxHP = maxHP
        self.shield = shield
        self.paperDoubleCounterCharges = paperDoubleCounterCharges
        self.paperDoubleCounterDurationRounds = paperDoubleCounterDurationRounds
        self.finaleReadyDurationActions = finaleReadyDurationActions
        self.stageGuardDurationRounds = stageGuardDurationRounds
        self.enhancedSetupCharges = enhancedSetupCharges
        self.debuffs = debuffs
        self.copiedBuff = copiedBuff
    }
}

public struct FoolCooldownState: Equatable, Sendable {
    public var currentPlayerActionIndex: Int
    public var nextAvailable: [FoolSkillID: Int]

    public init(currentPlayerActionIndex: Int = 0, nextAvailable: [FoolSkillID: Int] = [:]) {
        self.currentPlayerActionIndex = currentPlayerActionIndex
        self.nextAvailable = nextAvailable
    }

    public func isAvailable(_ skillID: FoolSkillID) -> Bool {
        remainingActions(for: skillID) == 0
    }

    public func remainingActions(for skillID: FoolSkillID) -> Int {
        max(0, nextAvailable[skillID, default: 0] - currentPlayerActionIndex)
    }

    public mutating func startCooldown(_ skillID: FoolSkillID, reuseDelayActions: Int) {
        // A reuse delay counts future player actions. The caller advances the
        // action index before starting the cooldown, so a delay of one skips
        // exactly the next player action.
        nextAvailable[skillID] = currentPlayerActionIndex + max(0, reuseDelayActions)
    }

    public mutating func reduceCooldown(_ skillID: FoolSkillID) {
        nextAvailable[skillID] = currentPlayerActionIndex
    }
}

public struct FoolBattleState: Equatable, Sendable {
    public var player: FoolPlayerState
    public var enemies: [FoolEnemyState]
    public var cooldowns: FoolCooldownState
    public var ultimateUsed: Bool

    public init(
        player: FoolPlayerState = FoolPlayerState(),
        enemies: [FoolEnemyState] = [],
        cooldowns: FoolCooldownState = FoolCooldownState(),
        ultimateUsed: Bool = false
    ) {
        self.player = player
        self.enemies = enemies
        self.cooldowns = cooldowns
        self.ultimateUsed = ultimateUsed
    }
}

public struct FoolControlResolution: Equatable, Sendable {
    public let skipNextAction: Bool
    public let resistantDisorientation: Bool
    public let nextDamageReductionBP: Int
    public let suppressSecondaryEffects: Bool
}

public enum FoolBattleError: Error, Equatable {
    case invalidTarget
    case ultimateAlreadyUsed
}

public enum FoolBattleEngine {
    public static func applyIncomingDamage(_ damage: Int, to player: inout FoolPlayerState) {
        let absorbed = min(player.shield, damage)
        player.shield -= absorbed
        player.hp = max(0, player.hp - (damage - absorbed))
    }

    public static func usePaperDouble(on player: inout FoolPlayerState) {
        player.paperDoubleCounterCharges = 1
        player.paperDoubleCounterDurationRounds = 1
    }

    public static func resolveDirectEnemyHit(
        damage: Int,
        player: inout FoolPlayerState,
        attacker: inout FoolEnemyState,
        hitResult: MPCHitResult = .hit
    ) {
        guard hitResult == .hit else { return }
        if player.paperDoubleCounterCharges > 0 {
            attacker.illusionStacks = min(4, attacker.illusionStacks + 2)
            player.paperDoubleCounterCharges = 0
            player.paperDoubleCounterDurationRounds = 0
            return
        }
        applyIncomingDamage(damage, to: &player)
    }

    public static func identityDisplacementControl(on enemy: inout FoolEnemyState) -> FoolControlResolution {
        enemy.illusionStacks = 0
        enemy.misalignmentStacks = 2
        if enemy.rank == .normal {
            enemy.normalDisorientationDuration = 1
            return FoolControlResolution(
                skipNextAction: true,
                resistantDisorientation: false,
                nextDamageReductionBP: 0,
                suppressSecondaryEffects: false
            )
        }
        enemy.resistantDisorientationCharges = 1
        return FoolControlResolution(
            skipNextAction: false,
            resistantDisorientation: true,
            nextDamageReductionBP: 2_500,
            suppressSecondaryEffects: true
        )
    }

    public static func useTurnTheTables(
        player: inout FoolPlayerState,
        enemy: inout FoolEnemyState
    ) {
        if let selected = enemy.dispellableBuffs.max(by: { $0.rawValue < $1.rawValue }),
           let index = enemy.dispellableBuffs.firstIndex(of: selected) {
            enemy.dispellableBuffs.remove(at: index)
            enemy.misalignmentStacks = max(enemy.misalignmentStacks, 1)
            player.copiedBuff = selected
        } else {
            enemy.illusionStacks = min(4, enemy.illusionStacks + 2)
            player.shield = min(player.maxHP * 4 / 10, player.shield + 100)
        }
    }

    public static func useBackstageChange(state: inout FoolBattleState) {
        if let selected = state.player.debuffs.max(by: { $0.rawValue < $1.rawValue }),
           let index = state.player.debuffs.firstIndex(of: selected) {
            state.player.debuffs.remove(at: index)
        }
        state.player.enhancedSetupCharges = 1
    }

    public static func useNamelessStage(state: inout FoolBattleState) throws {
        guard !state.ultimateUsed else { throw FoolBattleError.ultimateAlreadyUsed }
        for index in state.enemies.indices {
            state.enemies[index].illusionStacks = 4
        }
        state.player.finaleReadyDurationActions = 3
        state.player.stageGuardDurationRounds = 3
        state.ultimateUsed = true
    }

    public static func useFabricatedEvidence(
        state: inout FoolBattleState,
        targetIndex: Int,
        targetDefense: Int = 20
    ) throws -> MPCAttackResolution {
        guard state.enemies.indices.contains(targetIndex) else { throw FoolBattleError.invalidTarget }
        let target = state.enemies[targetIndex]
        let resolution = MPCAttackActionResolver.resolve(
            MPCAttackAction(
                attack: 100,
                coefficientsBP: [7_000],
                targetDefense: targetDefense,
                outgoingBonusBP: target.illusionStacks * 500
            ),
            against: MPCTargetDefenseState(evasionCharges: target.evasionCharges)
        )
        state.enemies[targetIndex].evasionCharges = resolution.defenseState.evasionCharges
        if resolution.hitResult == .hit {
            let extra = state.player.enhancedSetupCharges > 0 ? 1 : 0
            state.enemies[targetIndex].illusionStacks = min(4, target.illusionStacks + 1 + extra)
            state.player.enhancedSetupCharges = 0
        }
        return resolution
    }
}
