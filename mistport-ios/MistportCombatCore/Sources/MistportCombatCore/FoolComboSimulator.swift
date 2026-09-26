import Foundation

public enum FoolSkillID: String, Codable, CaseIterable, Sendable {
    case sidestepStrike = "fool_skill_01"
    case maskedWhisper = "fool_skill_02"
    case paperDouble = "fool_skill_03"
    case identityDisplacement = "fool_skill_04"
    case fabricatedEvidence = "fool_skill_05"
    case mirrorPursuit = "fool_skill_06"
    case absurdFinale = "fool_skill_07"
    case turnTheTables = "fool_skill_08"
    case backstageChange = "fool_skill_09"
    case namelessStage = "fool_skill_10"
}

public struct FoolComboState: Equatable, Sendable {
    public var attack: Int
    public var targetDefense: Int
    public var illusionStacks: Int
    public var misalignmentStacks: Int
    public var fabricatedEvidenceCharges: Int
    public var finaleReady: Bool

    public init(
        attack: Int = 100,
        targetDefense: Int = 20,
        illusionStacks: Int = 0,
        misalignmentStacks: Int = 0,
        fabricatedEvidenceCharges: Int = 0,
        finaleReady: Bool = false
    ) {
        self.attack = attack
        self.targetDefense = targetDefense
        self.illusionStacks = illusionStacks
        self.misalignmentStacks = misalignmentStacks
        self.fabricatedEvidenceCharges = fabricatedEvidenceCharges
        self.finaleReady = finaleReady
    }
}

public struct FoolSkillResolution: Equatable, Sendable {
    public let skillID: FoolSkillID
    public let damageHits: [Int]
    public let state: FoolComboState

    public var totalDamage: Int { damageHits.reduce(0, +) }
}

public enum FoolComboError: Error, Equatable {
    case unsupportedSkill(FoolSkillID)
    case requiresFourIllusions
}

public enum FoolComboSimulator {
    public static func resolve(
        skillID: FoolSkillID,
        from initialState: FoolComboState
    ) throws -> FoolSkillResolution {
        var state = initialState
        let fabricatedBonus = state.fabricatedEvidenceCharges > 0 ? 1_500 : 0
        // 「误认」 is a target vulnerability in the rebuilt Fool loop. The
        // combat core stores it as a fixed-point outgoing modifier so the
        // same deterministic math is shared by Swift and the presentation
        // bridge.
        let illusionBonus = state.illusionStacks * 400
        let damageHits: [Int]
        let consumesFabricatedEvidence: Bool

        switch skillID {
        case .maskedWhisper:
            damageHits = [damage(
                coefficientBP: 6_000,
                outgoingBonusBP: illusionBonus + fabricatedBonus,
                state: state
            )]
            state.illusionStacks = min(4, state.illusionStacks + 2)
            consumesFabricatedEvidence = state.fabricatedEvidenceCharges > 0

        case .fabricatedEvidence:
            damageHits = [damage(
                coefficientBP: 7_000,
                outgoingBonusBP: illusionBonus + fabricatedBonus,
                state: state
            )]
            state.illusionStacks = min(4, state.illusionStacks + 1)
            state.fabricatedEvidenceCharges = 2
            consumesFabricatedEvidence = false

        case .identityDisplacement:
            if state.illusionStacks < 4 {
                damageHits = [damage(
                    coefficientBP: 8_000,
                    outgoingBonusBP: illusionBonus + fabricatedBonus,
                    state: state
                )]
                state.illusionStacks = min(4, state.illusionStacks + 1)
            } else {
                damageHits = [damage(
                    coefficientBP: 8_000,
                    outgoingBonusBP: illusionBonus + fabricatedBonus,
                    state: state
                )]
                state.illusionStacks = 0
                state.misalignmentStacks = 2
            }
            consumesFabricatedEvidence = state.fabricatedEvidenceCharges > 0

        case .mirrorPursuit:
            let empowered = state.misalignmentStacks > 0
            damageHits = [
                damage(
                    coefficientBP: 6_500,
                    outgoingBonusBP: illusionBonus + fabricatedBonus,
                    state: state
                ),
                damage(
                    coefficientBP: empowered ? 9_750 : 6_500,
                    outgoingBonusBP: illusionBonus + fabricatedBonus,
                    state: state
                )
            ]
            if empowered {
                state.misalignmentStacks -= 1
            }
            consumesFabricatedEvidence = state.fabricatedEvidenceCharges > 0

        case .sidestepStrike:
            // The opening tutorial pair must form a real combo: Masked Whisper
            // supplies illusion and Curtain Step immediately cashes it in. Later
            // builds can still create the stronger, persistent misalignment setup
            // through Identity Displacement.
            let hasSetup = state.illusionStacks > 0 || state.misalignmentStacks > 0
            damageHits = [damage(
                coefficientBP: hasSetup ? 13_750 : 11_000,
                outgoingBonusBP: illusionBonus + fabricatedBonus,
                state: state
            )]
            if hasSetup {
                state.finaleReady = true
            }
            consumesFabricatedEvidence = state.fabricatedEvidenceCharges > 0

        case .absurdFinale:
            let coefficient = 15_000
                + (state.misalignmentStacks > 0 ? 8_000 : 0)
                + (state.finaleReady ? 2_500 : 0)
            damageHits = [damage(
                coefficientBP: coefficient,
                outgoingBonusBP: illusionBonus + fabricatedBonus,
                armorPenetrationBP: 3_000,
                state: state
            )]
            state.misalignmentStacks = 0
            if state.finaleReady {
                state.finaleReady = false
            }
            consumesFabricatedEvidence = state.fabricatedEvidenceCharges > 0

        case .paperDouble, .turnTheTables, .backstageChange, .namelessStage:
            throw FoolComboError.unsupportedSkill(skillID)
        }

        if consumesFabricatedEvidence {
            state.fabricatedEvidenceCharges = max(0, state.fabricatedEvidenceCharges - 1)
        }

        return FoolSkillResolution(skillID: skillID, damageHits: damageHits, state: state)
    }

    public static func standardCombo(targetDefense: Int) throws -> [FoolSkillResolution] {
        let sequence: [FoolSkillID] = [
            .maskedWhisper,
            .fabricatedEvidence,
            .identityDisplacement,
            .mirrorPursuit,
            .sidestepStrike,
            .absurdFinale
        ]
        var state = FoolComboState(targetDefense: targetDefense)
        return try sequence.map { skillID in
            let result = try resolve(skillID: skillID, from: state)
            state = result.state
            return result
        }
    }

    private static func damage(
        coefficientBP: Int,
        outgoingBonusBP: Int,
        armorPenetrationBP: Int = 0,
        state: FoolComboState
    ) -> Int {
        MPCFixedPointCombatMath.damage(
            MPCDamageInput(
                attack: state.attack,
                coefficientBP: coefficientBP,
                targetDefense: state.targetDefense,
                outgoingBonusBP: outgoingBonusBP,
                armorPenetrationBP: armorPenetrationBP
            )
        ).damageAfterDefense
    }
}
