import Foundation

// MARK: - Stable identifiers

struct TBCombatantID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct TBSkillID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

struct TBStatusID: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - Configuration

enum TBCombatSide: String, Codable, Sendable {
    case player
    case enemy
}

enum TBSkillSlot: String, Codable, Sendable {
    case active
    case core
}

enum TBTargetRule: String, Codable, Sendable {
    case selfOnly
    case singleEnemy
    case allEnemies
}

enum TBEffectKind: String, Codable, Sendable {
    case damage
    case willDamage
    case armor
    case veil
    case omen
    case cleanse
    case evadeAnnouncedAttack
    case revealIntent
}

enum TBEffectRecipient: String, Codable, Sendable {
    case skillTargets
    case source
}

struct TBEffectDefinition: Hashable, Codable, Sendable {
    let kind: TBEffectKind
    let magnitude: Int
    let duration: Int
    let recipient: TBEffectRecipient

    init(
        kind: TBEffectKind,
        magnitude: Int,
        duration: Int = 0,
        recipient: TBEffectRecipient = .skillTargets
    ) {
        self.kind = kind
        self.magnitude = magnitude
        self.duration = duration
        self.recipient = recipient
    }
}

struct TBSkillDefinition: Identifiable, Hashable, Codable, Sendable {
    let id: TBSkillID
    let name: String
    let slot: TBSkillSlot
    let targetRule: TBTargetRule
    let cooldown: Int
    let omenCost: Int
    let effects: [TBEffectDefinition]
}

struct TBLoadout: Hashable, Codable, Sendable {
    let activeSkillIDs: [TBSkillID]
    let coreSkillID: TBSkillID
    let passiveIDs: [String]
    let relicIDs: [String]
    let preparationID: String

    func validationErrors(knownSkills: [TBSkillID: TBSkillDefinition]) -> [String] {
        var errors: [String] = []

        if activeSkillIDs.count != 4 {
            errors.append("必须装备 4 个普通主动技能")
        }
        if Set(activeSkillIDs).count != activeSkillIDs.count {
            errors.append("普通主动技能不能重复")
        }
        if passiveIDs.count != 2 {
            errors.append("必须装备 2 个被动")
        }
        if relicIDs.count != 2 {
            errors.append("必须装备 2 件遗器")
        }
        if preparationID.isEmpty {
            errors.append("必须选择 1 项战前准备")
        }

        for id in activeSkillIDs {
            guard let skill = knownSkills[id] else {
                errors.append("未知主动技能：\(id.rawValue)")
                continue
            }
            if skill.slot != .active {
                errors.append("核心技能不能装入普通主动槽：\(skill.name)")
            }
        }

        if let coreSkill = knownSkills[coreSkillID] {
            if coreSkill.slot != .core {
                errors.append("普通主动技能不能装入核心槽：\(coreSkill.name)")
            }
        } else {
            errors.append("未知核心技能：\(coreSkillID.rawValue)")
        }

        return errors
    }
}

// MARK: - Runtime state

enum TBIntentKind: String, Codable, Sendable {
    case attack
    case heavyAttack
    case defend
    case strengthen
    case heal
    case hideInformation
}

struct TBEnemyIntent: Hashable, Codable, Sendable {
    let kind: TBIntentKind
    let sourceID: TBCombatantID
    let targetID: TBCombatantID?
    let magnitude: Int
    let remainingActions: Int
    let isFatal: Bool
    let isRevealed: Bool
}

struct TBStatusState: Identifiable, Hashable, Codable, Sendable {
    var id: TBStatusID
    var stacks: Int
    var remainingRounds: Int
    let sourceID: TBCombatantID?
    let isCoreRule: Bool
}

struct TBCombatantState: Identifiable, Hashable, Codable, Sendable {
    let id: TBCombatantID
    let side: TBCombatSide
    let name: String
    let maxHealth: Int
    var health: Int
    var armor: Int
    let maxWill: Int
    var will: Int
    var omen: Int
    var statuses: [TBStatusState]
    var cooldowns: [TBSkillID: Int]
    var nextIntent: TBEnemyIntent?

    var isDefeated: Bool { health <= 0 }
    var isWillBroken: Bool { maxWill > 0 && will <= 0 }
}

enum TBCombatOutcome: String, Codable, Sendable {
    case ongoing
    case victory
    case defeat
}

struct TBBattleState: Hashable, Codable, Sendable {
    var round: Int
    var actionIndex: Int
    var combatants: [TBCombatantID: TBCombatantState]
    var timeline: [TBCombatantID]
    var outcome: TBCombatOutcome

    var player: TBCombatantState? {
        combatants.values.first(where: { $0.side == .player })
    }

    var livingEnemies: [TBCombatantState] {
        combatants.values
            .filter { $0.side == .enemy && !$0.isDefeated }
            .sorted { $0.id.rawValue < $1.id.rawValue }
    }
}

// MARK: - Event pipeline

enum TBPipelineStage: Int, CaseIterable, Codable, Sendable {
    case roundStart
    case actionDeclared
    case targetSelected
    case effectDetermined
    case awaitingResolution
    case resultApplied
    case aftermathTriggered
    case roundEnd
}

enum TBRuleTag: String, Hashable, Codable, Sendable {
    case cannotCopy
    case cannotDelayAgain
    case cannotTransfer
    case oncePerRound
    case cannotTriggerSelf
    case bossCoreRule
    case partiallyModifiable
    case immutable
}

enum TBEventPayload: Hashable, Codable, Sendable {
    case damage(Int)
    case willDamage(Int)
    case armor(Int)
    case veil(Int)
    case omen(Int)
    case cleanse(Int)
    case revealIntent(Int)
    case evadeAnnouncedAttack
}

struct TBCombatEvent: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    var stage: TBPipelineStage
    let sourceID: TBCombatantID
    let targetIDs: [TBCombatantID]
    let skillID: TBSkillID?
    var payload: TBEventPayload
    var tags: Set<TBRuleTag>
}

struct TBCombatLogEntry: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let round: Int
    let stage: TBPipelineStage
    let message: String
    let sourceID: TBCombatantID?
    let targetID: TBCombatantID?
}

struct TBActionSelection: Hashable, Codable, Sendable {
    let actorID: TBCombatantID
    let skillID: TBSkillID
    let targetIDs: [TBCombatantID]
}

struct TBActionPreview: Hashable, Codable, Sendable {
    let selection: TBActionSelection
    let events: [TBCombatEvent]
    let projectedState: TBBattleState
    let warnings: [String]
}

// MARK: - First vertical-slice catalog

enum OldClockCombatCatalog {
    static let weakPointJudgment = TBSkillDefinition(
        id: TBSkillID(rawValue: "veil.weak-point-judgment"),
        name: "弱点判断",
        slot: .active,
        targetRule: .singleEnemy,
        cooldown: 1,
        omenCost: 0,
        effects: [
            TBEffectDefinition(kind: .damage, magnitude: 14),
            TBEffectDefinition(kind: .willDamage, magnitude: 18)
        ]
    )

    static let spiritualEvasion = TBSkillDefinition(
        id: TBSkillID(rawValue: "veil.spiritual-evasion"),
        name: "灵性闪避",
        slot: .active,
        targetRule: .selfOnly,
        cooldown: 3,
        omenCost: 0,
        effects: [TBEffectDefinition(kind: .evadeAnnouncedAttack, magnitude: 1, duration: 1)]
    )

    static let simpleDivination = TBSkillDefinition(
        id: TBSkillID(rawValue: "veil.simple-divination"),
        name: "简易占卜",
        slot: .active,
        targetRule: .singleEnemy,
        cooldown: 2,
        omenCost: 0,
        effects: [
            TBEffectDefinition(kind: .revealIntent, magnitude: 1),
            TBEffectDefinition(kind: .omen, magnitude: 1, recipient: .source)
        ]
    )

    static let dangerPremonition = TBSkillDefinition(
        id: TBSkillID(rawValue: "veil.danger-premonition"),
        name: "危险预感",
        slot: .active,
        targetRule: .selfOnly,
        cooldown: 2,
        omenCost: 0,
        effects: [TBEffectDefinition(kind: .veil, magnitude: 12, duration: 1)]
    )

    static let omenRecord = TBSkillDefinition(
        id: TBSkillID(rawValue: "veil.omen-record"),
        name: "预兆记录",
        slot: .core,
        targetRule: .singleEnemy,
        cooldown: 0,
        omenCost: 3,
        effects: [
            TBEffectDefinition(kind: .damage, magnitude: 28),
            TBEffectDefinition(kind: .willDamage, magnitude: 24)
        ]
    )

    static let skills: [TBSkillDefinition] = [
        weakPointJudgment,
        spiritualEvasion,
        simpleDivination,
        dangerPremonition,
        omenRecord
    ]

    static let skillLookup = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0) })

    static let firstLoadout = TBLoadout(
        activeSkillIDs: [
            weakPointJudgment.id,
            spiritualEvasion.id,
            simpleDivination.id,
            dangerPremonition.id
        ],
        coreSkillID: omenRecord.id,
        passiveIDs: ["veil.calm-observer", "veil.correct-response"],
        relicIDs: ["old-clock.late-second-watch", "old-clock.rain-listener"],
        preparationID: "old-clock.field-notes"
    )
}
