import Foundation
import Testing
@testable import MistportCombatCore

struct FoolCombatVectorDocument: Decodable, Sendable {
    let version: String
    let cases: [FoolCombatVector]
}

struct FoolCombatVector: Decodable, Sendable, CustomTestStringConvertible {
    let id: String
    let description: String
    let input: Input
    let expected: Expected

    var testDescription: String { "\(id): \(description)" }

    struct Input: Decodable, Sendable {
        let attack: Int?
        let skill: String?
        let skills: [Int]?
        let targetDefense: Int?
        let illusion: Int?
        let targetIllusion: Int?
        let misalignment: Int?
        let fabricatedEvidenceCharges: Int?
        let finaleReady: Bool?
        let hp: Int?
        let shield: Int?
        let playerShield: Int?
        let incomingDamage: Int?
        let incomingDamageSequence: [Int]?
        let incomingDamageAfterDefense: Int?
        let paperDoubleCounter: Bool?
        let currentPlayerActionIndex: Int?
        let reuseDelayActions: Int?
        let livingEnemies: Int?
        let enemyRank: String?
        let coefficientBP: Int?
        let hitCoefficientsBP: [Int]?
        let hitPolicy: String?
        let evasionCharges: Int?
        let guardCharges: Int?
        let guardReductionBP: Int?
        let stageGuardReductionBP: Int?

        enum CodingKeys: String, CodingKey {
            case attack, skill, skills, illusion, misalignment, hp, shield
            case targetDefense = "target_defense"
            case targetIllusion = "target_illusion"
            case fabricatedEvidenceCharges = "fabricated_evidence_charges"
            case finaleReady = "finale_ready"
            case playerShield = "player_shield"
            case incomingDamage = "incoming_damage"
            case incomingDamageSequence = "incoming_damage_sequence"
            case incomingDamageAfterDefense = "incoming_damage_after_defense"
            case paperDoubleCounter = "paper_double_counter"
            case currentPlayerActionIndex = "current_player_action_index"
            case reuseDelayActions = "reuse_delay_actions"
            case livingEnemies = "living_enemies"
            case enemyRank = "enemy_rank"
            case coefficientBP = "coefficient_bp"
            case hitCoefficientsBP = "hit_coefficients_bp"
            case hitPolicy = "hit_policy"
            case evasionCharges = "evasion_charges"
            case guardCharges = "guard_charges"
            case guardReductionBP = "guard_reduction_bp"
            case stageGuardReductionBP = "stage_guard_reduction_bp"
        }
    }

    struct Expected: Decodable, Sendable {
        let damageHits: [Int]?
        let totalDamage: Int?
        let illusionAfter: Int?
        let targetIllusionAfter: Int?
        let misalignmentAfter: Int?
        let fabricatedEvidenceCharges: Int?
        let fabricatedEvidenceChargesAfter: Int?
        let finaleReady: Bool?
        let finaleReadyAfter: Bool?
        let afterFirst: VitalState?
        let afterSecond: VitalState?
        let playerShieldAfter: Int?
        let attackerIllusionAfter: Int?
        let paperDoubleCounterAfter: Bool?
        let nextAvailableActionIndex: Int?
        let unavailableOn: [Int]?
        let availableOn: Int?
        let skillsNextAvailable: [String: Int]?
        let allEnemyIllusion: Int?
        let finaleReadyDuration: Int?
        let stageGuardDurationRounds: Int?
        let skipNextAction: Bool?
        let resistantDisorientation: Bool?
        let nextDamageReductionBP: Int?
        let suppressSecondaryEffects: Bool?
        let hitResult: String?
        let evasionChargesAfter: Int?
        let guardChargesAfter: Int?
        let shieldAfter: Int?
        let hpAfter: Int?
        let combinedReductionBP: Int?

        enum CodingKeys: String, CodingKey {
            case damageHits = "damage_hits"
            case totalDamage = "total_damage"
            case illusionAfter = "illusion_after"
            case targetIllusionAfter = "target_illusion_after"
            case misalignmentAfter = "misalignment_after"
            case fabricatedEvidenceCharges = "fabricated_evidence_charges"
            case fabricatedEvidenceChargesAfter = "fabricated_evidence_charges_after"
            case finaleReady = "finale_ready"
            case finaleReadyAfter = "finale_ready_after"
            case afterFirst = "after_first"
            case afterSecond = "after_second"
            case playerShieldAfter = "player_shield_after"
            case attackerIllusionAfter = "attacker_illusion_after"
            case paperDoubleCounterAfter = "paper_double_counter_after"
            case nextAvailableActionIndex = "next_available_action_index"
            case unavailableOn = "unavailable_on"
            case availableOn = "available_on"
            case skillsNextAvailable = "skills_next_available"
            case allEnemyIllusion = "all_enemy_illusion"
            case finaleReadyDuration = "finale_ready_duration"
            case stageGuardDurationRounds = "stage_guard_duration_rounds"
            case skipNextAction = "skip_next_action"
            case resistantDisorientation = "resistant_disorientation"
            case nextDamageReductionBP = "next_damage_reduction_bp"
            case suppressSecondaryEffects = "suppress_secondary_effects"
            case hitResult = "hit_result"
            case evasionChargesAfter = "evasion_charges_after"
            case guardChargesAfter = "guard_charges_after"
            case shieldAfter = "shield_after"
            case hpAfter = "hp_after"
            case combinedReductionBP = "combined_reduction_bp"
        }

        struct VitalState: Decodable, Sendable {
            let hp: Int
            let shield: Int
        }
    }
}

enum FoolCombatVectorLoader {
    static let document: FoolCombatVectorDocument = {
        let url = Bundle.module.url(
            forResource: "fool_combat_test_vectors.v1.1",
            withExtension: "json"
        )!
        return try! JSONDecoder().decode(FoolCombatVectorDocument.self, from: Data(contentsOf: url))
    }()
}

@Suite("Executable fool combat JSON contract")
struct FoolCombatVectorTests {
    @Test("Vector document version is frozen")
    func version() {
        #expect(FoolCombatVectorLoader.document.version == "1.2.0")
        #expect(FoolCombatVectorLoader.document.cases.count == 24)
    }

    @Test(
        "Execute JSON combat vector",
        arguments: FoolCombatVectorLoader.document.cases
    )
    func execute(_ vector: FoolCombatVector) throws {
        switch vector.id {
        case "T01"..."T06":
            try executeSkill(vector)
        case "T07", "T07A", "T07B", "T07C", "T07D":
            try executeCombo(vector)
        case "T08":
            try executeShieldSequence(vector)
        case "T09":
            executePaperDouble(vector)
        case "T10":
            try executeCooldown(vector)
        case "T11":
            try executeUltimate(vector)
        case "T12":
            try executeControl(vector)
        case "T13"..."T19":
            try executeAttack(vector)
        case "T20":
            try executeDodgedSkill(vector)
        default:
            Issue.record("No executor for vector \(vector.id)")
        }
    }

    private func executeSkill(_ vector: FoolCombatVector) throws {
        let skill = try #require(vector.input.skill.flatMap(FoolSkillID.init(rawValue:)))
        let result = try FoolComboSimulator.resolve(
            skillID: skill,
            from: FoolComboState(
                attack: vector.input.attack ?? 100,
                targetDefense: vector.input.targetDefense ?? 20,
                illusionStacks: vector.input.illusion ?? 0,
                misalignmentStacks: vector.input.misalignment ?? 0,
                fabricatedEvidenceCharges: vector.input.fabricatedEvidenceCharges ?? 0,
                finaleReady: vector.input.finaleReady ?? false
            )
        )
        assertResolution(result, expected: vector.expected)
    }

    private func executeCombo(_ vector: FoolCombatVector) throws {
        let results = try FoolComboSimulator.standardCombo(targetDefense: vector.input.targetDefense ?? 20)
        let hits = results.flatMap(\.damageHits)
        if let expectedHits = vector.expected.damageHits { #expect(hits == expectedHits) }
        #expect(hits.reduce(0, +) == vector.expected.totalDamage)
    }

    private func executeShieldSequence(_ vector: FoolCombatVector) throws {
        var player = FoolPlayerState(hp: vector.input.hp ?? 1_000, shield: vector.input.shield ?? 0)
        let damage = try #require(vector.input.incomingDamageSequence)
        FoolBattleEngine.applyIncomingDamage(damage[0], to: &player)
        #expect(player.hp == vector.expected.afterFirst?.hp)
        #expect(player.shield == vector.expected.afterFirst?.shield)
        FoolBattleEngine.applyIncomingDamage(damage[1], to: &player)
        #expect(player.hp == vector.expected.afterSecond?.hp)
        #expect(player.shield == vector.expected.afterSecond?.shield)
    }

    private func executePaperDouble(_ vector: FoolCombatVector) {
        var player = FoolPlayerState(
            shield: vector.input.playerShield ?? 0,
            paperDoubleCounterCharges: vector.input.paperDoubleCounter == true ? 1 : 0,
            paperDoubleCounterDurationRounds: 2
        )
        var attacker = FoolEnemyState()
        FoolBattleEngine.resolveDirectEnemyHit(
            damage: vector.input.incomingDamage ?? 0,
            player: &player,
            attacker: &attacker
        )
        #expect(player.shield == vector.expected.playerShieldAfter)
        #expect(attacker.illusionStacks == vector.expected.attackerIllusionAfter)
        #expect((player.paperDoubleCounterCharges > 0) == vector.expected.paperDoubleCounterAfter)
    }

    private func executeCooldown(_ vector: FoolCombatVector) throws {
        var cooldown = FoolCooldownState(currentPlayerActionIndex: vector.input.currentPlayerActionIndex ?? 0)
        cooldown.startCooldown(.maskedWhisper, reuseDelayActions: vector.input.reuseDelayActions ?? 0)
        #expect(cooldown.nextAvailable[.maskedWhisper] == vector.expected.nextAvailableActionIndex)
        for index in vector.expected.unavailableOn ?? [] {
            cooldown.currentPlayerActionIndex = index
            #expect(!cooldown.isAvailable(.maskedWhisper))
        }
        cooldown.currentPlayerActionIndex = try #require(vector.expected.availableOn)
        #expect(cooldown.isAvailable(.maskedWhisper))
    }

    private func executeUltimate(_ vector: FoolCombatVector) throws {
        var state = FoolBattleState(
            enemies: Array(repeating: FoolEnemyState(), count: vector.input.livingEnemies ?? 0),
            cooldowns: FoolCooldownState(currentPlayerActionIndex: vector.input.currentPlayerActionIndex ?? 0)
        )
        try FoolBattleEngine.useNamelessStage(state: &state)
        #expect(state.enemies.allSatisfy { $0.illusionStacks == vector.expected.allEnemyIllusion })
        for (rawID, expectedIndex) in vector.expected.skillsNextAvailable ?? [:] {
            let skill = try #require(FoolSkillID(rawValue: rawID))
            #expect(state.cooldowns.nextAvailable[skill] == expectedIndex)
        }
        #expect(state.player.finaleReadyDurationActions == vector.expected.finaleReadyDuration)
        #expect(state.player.stageGuardDurationRounds == vector.expected.stageGuardDurationRounds)
    }

    private func executeControl(_ vector: FoolCombatVector) throws {
        let rank = try #require(vector.input.enemyRank.flatMap(MPCEnemyRank.init(rawValue:)))
        var enemy = FoolEnemyState(rank: rank, illusionStacks: vector.input.illusion ?? 0)
        let result = FoolBattleEngine.identityDisplacementControl(on: &enemy)
        #expect(result.skipNextAction == vector.expected.skipNextAction)
        #expect(enemy.misalignmentStacks == vector.expected.misalignmentAfter)
        #expect(result.resistantDisorientation == vector.expected.resistantDisorientation)
        #expect(result.nextDamageReductionBP == vector.expected.nextDamageReductionBP)
        #expect(result.suppressSecondaryEffects == vector.expected.suppressSecondaryEffects)
    }

    private func executeAttack(_ vector: FoolCombatVector) throws {
        if vector.id == "T18" {
            let reduced = MPCFixedPointCombatMath.applyReduction(
                to: try #require(vector.input.incomingDamageAfterDefense),
                reductionsBP: [vector.input.guardReductionBP ?? 3_500]
            )
            var player = FoolPlayerState(hp: vector.input.hp ?? 1_000, shield: vector.input.shield ?? 0)
            FoolBattleEngine.applyIncomingDamage(reduced, to: &player)
            #expect(player.shield == vector.expected.shieldAfter)
            #expect(player.hp == vector.expected.hpAfter)
            return
        }

        let coefficients: [Int]
        if let multiple = vector.input.hitCoefficientsBP {
            coefficients = multiple
        } else {
            coefficients = [try #require(vector.input.coefficientBP)]
        }
        let policy = vector.input.hitPolicy.flatMap(MPCHitPolicy.init(rawValue:)) ?? .dodgeable
        let guardReduction = vector.input.guardReductionBP ?? (vector.id == "T18" ? 3_500 : 3_500)
        let result = MPCAttackActionResolver.resolve(
            MPCAttackAction(
                attack: vector.input.attack ?? 100,
                coefficientsBP: coefficients,
                targetDefense: vector.input.targetDefense ?? 20,
                hitPolicy: policy
            ),
            against: MPCTargetDefenseState(
                evasionCharges: vector.input.evasionCharges ?? 0,
                guardCharges: vector.input.guardCharges ?? (vector.input.guardReductionBP == nil ? 0 : 1),
                guardReductionBP: guardReduction,
                otherReductionsBP: vector.input.stageGuardReductionBP.map { [$0] } ?? [],
                shield: vector.input.shield ?? 0,
                hp: vector.input.hp ?? 1_000
            )
        )
        if let hit = vector.expected.hitResult { #expect(result.hitResult.rawValue == hit) }
        if let hits = vector.expected.damageHits { #expect(result.damageHits == hits) }
        if let total = vector.expected.totalDamage { #expect(result.damageHits.reduce(0, +) == total) }
        if let value = vector.expected.evasionChargesAfter { #expect(result.defenseState.evasionCharges == value) }
        if let value = vector.expected.guardChargesAfter { #expect(result.defenseState.guardCharges == value) }
        if let value = vector.expected.shieldAfter { #expect(result.defenseState.shield == value) }
        if let value = vector.expected.hpAfter { #expect(result.defenseState.hp == value) }
    }

    private func executeDodgedSkill(_ vector: FoolCombatVector) throws {
        var state = FoolBattleState(
            enemies: [FoolEnemyState(
                illusionStacks: vector.input.targetIllusion ?? 0,
                evasionCharges: vector.input.evasionCharges ?? 0
            )],
            cooldowns: FoolCooldownState(currentPlayerActionIndex: vector.input.currentPlayerActionIndex ?? 0)
        )
        let result = try FoolBattleEngine.useFabricatedEvidence(state: &state, targetIndex: 0)
        #expect(result.hitResult.rawValue == vector.expected.hitResult)
        #expect(result.damageHits.reduce(0, +) == vector.expected.totalDamage)
        #expect(state.enemies[0].illusionStacks == vector.expected.targetIllusionAfter)
        #expect(state.enemies[0].evasionCharges == vector.expected.evasionChargesAfter)
        #expect(state.cooldowns.nextAvailable[.fabricatedEvidence] == vector.expected.nextAvailableActionIndex)
    }

    private func assertResolution(_ result: FoolSkillResolution, expected: FoolCombatVector.Expected) {
        if let hits = expected.damageHits { #expect(result.damageHits == hits) }
        if let total = expected.totalDamage { #expect(result.totalDamage == total) }
        if let value = expected.illusionAfter { #expect(result.state.illusionStacks == value) }
        if let value = expected.misalignmentAfter { #expect(result.state.misalignmentStacks == value) }
        if let value = expected.fabricatedEvidenceCharges { #expect(result.state.fabricatedEvidenceCharges == value) }
        if let value = expected.fabricatedEvidenceChargesAfter { #expect(result.state.fabricatedEvidenceCharges == value) }
        if let value = expected.finaleReady { #expect(result.state.finaleReady == value) }
        if let value = expected.finaleReadyAfter { #expect(result.state.finaleReady == value) }
    }
}
