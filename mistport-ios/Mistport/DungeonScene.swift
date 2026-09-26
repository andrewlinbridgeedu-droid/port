import Observation
import MistportCombatCore
import CoreImage
import SpriteKit
import SwiftUI
import UIKit

struct DungeonQueuedTargetAssignment {
    let targetID: String
    let order: Int
    let skillName: String
}

struct DungeonCombatSnapshot: Equatable {
    var playerHealth = 100
    var maxPlayerHealth = 100
    var enemiesRemaining = 0
    var currentWave = 1
    var totalWaves = 1
    var waveTitle = "先遣清剿"
    var skillCooldowns: [DungeonSkillID: TimeInterval] = [:]
    var isVictorious = false
    var isDefeated = false
    var status = "我方回合 · 选择目标与行动"
    var turnNumber = 1
    var isPlayerTurn = true
    var feedbackToken = 0
    var bossName: String?
    var bossHealthFraction: CGFloat = 0
    var bossIsEnraged = false
    var bossIntentName: String?
    var bossIntentDamage = 0
    var bossWillpowerFraction: CGFloat = 0
    var bossControlOutcome: String?
    var playerStatusLabels: [String] = []
    var actionOrderLabels: [String] = []
    var tacticalHint: String?
    var pathResourceName: String?
    var pathResourceValue = 0
    var pathResourceMaximum = 0
    var usedRelicIDs: Set<String> = []
}

@MainActor
@Observable
final class DungeonController {
    let scene: DungeonScene
    let skills: [DungeonSkillDefinition]
    private(set) var combat: DungeonCombatSnapshot

    init(
        path: Pathway,
        level: DungeonLevel = .clockDistrict,
        skills configuredSkills: [DungeonSkillDefinition]? = nil,
        relicIDs: [String] = [],
        damageMultiplier: CGFloat = 1,
        playerSequence: Int = 9
    ) {
        skills = configuredSkills ?? DungeonSkillCatalog.skills(for: path)
        scene = DungeonScene(
            level: level,
            path: path,
            skills: skills,
            relicIDs: relicIDs,
            damageMultiplier: damageMultiplier,
            playerSequence: playerSequence
        )

        var initialCombat = DungeonCombatSnapshot()
        initialCombat.enemiesRemaining = level.enemies.filter { $0.wave == 1 }.count
        initialCombat.totalWaves = level.totalWaves
        initialCombat.waveTitle = level.waveTitle(for: 1)
        initialCombat.skillCooldowns = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, 0) })
        combat = initialCombat

        scene.onStateChange = { [weak self] snapshot in
            guard self?.combat != snapshot else { return }
            self?.combat = snapshot
        }
    }

    func attack() {
        scene.performBasicAttack()
    }

    func cast(_ skillID: DungeonSkillID) {
        scene.performSkill(skillID)
    }

    func activateRelic(_ relicID: String) {
        scene.activateRelic(relicID)
    }

    func retry() {
        scene.resetCombat()
    }

    func performAutomaticAction() {
        guard combat.isPlayerTurn, !combat.isVictorious, !combat.isDefeated else { return }
        let readySkills = skills.filter { combat.skillCooldowns[$0.id, default: 0] <= 0 }
        if let bestSkill = readySkills.max(by: { automaticScore(for: $0) < automaticScore(for: $1) }),
           automaticScore(for: bestSkill) > 28 {
            scene.performSkill(bestSkill.id)
        } else {
            scene.performBasicAttack()
        }
    }

    /// Scores the current tactical value of a skill. Auto mode deliberately
    /// saves cooldowns when a basic attack is the better play; it is not a
    /// left-to-right "cast everything that lights up" macro.
    private func automaticScore(for skill: DungeonSkillDefinition) -> Int {
        let healthPercent = combat.playerHealth * 100 / max(1, combat.maxPlayerHealth)
        let incomingDamage = combat.bossIntentDamage
        let resourceReady = combat.pathResourceMaximum > 0
            && combat.pathResourceValue >= combat.pathResourceMaximum
        let crowdBonus = max(0, combat.enemiesRemaining - 1) * 12

        switch skill.id {
        case .ward:
            return 20 + (healthPercent <= 55 ? 48 : 0) + (incomingDamage >= 18 ? 36 : 0)
        case .mobility:
            return 24 + (healthPercent <= 40 ? 42 : 0) + (incomingDamage >= 22 ? 28 : 0)
        case .control:
            let bossBreakBonus = combat.bossWillpowerFraction > 0 && combat.bossWillpowerFraction <= 0.42 ? 34 : 0
            return 30 + crowdBonus + bossBreakBonus
        case .ultimate:
            guard resourceReady else { return -100 }
            return 70 + crowdBonus + (combat.bossName == nil ? 0 : 24)
        case .strike:
            return 34 + (combat.enemiesRemaining == 1 ? 16 : 0)
        }
    }
}

private enum DungeonEnemyActionState {
    case idle
    case chasing
    case windup
    case recovering
    case hitStun
    case dead
}

private enum DungeonTurnPhase {
    case player
    case resolvingPlayer
    case enemy
    case transitioning
    case finished
}

private enum DungeonEnemyAttackStyle {
    case ranged
    case teleportMelee
}

private enum DistrictBossModifier {
    case none
    case saltFracture
    case mirrorEncore
    case returningTide
    case crownEdict
}

private enum FoolFacing: String, CaseIterable {
    case north = "N"
    case east = "E"
    case south = "S"
    case west = "W"
}

private enum FoolMotion: String, CaseIterable {
    case idle = "Idle"
    case run = "Run"
    case attack = "Attack"
    case skillStrike = "SkillStrike"
    case skillMobility = "SkillMobility"
    case skillUltimate = "SkillUltimate"
    case hit = "Hit"
    case death = "Death"

    var frameCount: Int {
        switch self {
        case .idle: 4
        case .run, .attack, .skillStrike, .skillMobility: 6
        case .skillUltimate, .death: 8
        case .hit: 3
        }
    }

    var frameTime: TimeInterval {
        switch self {
        case .idle: 0.18
        case .run: 0.09
        case .attack: 0.065
        case .skillStrike: 0.075
        case .skillMobility: 0.055
        case .skillUltimate: 0.085
        case .hit: 0.07
        case .death: 0.11
        }
    }

    var loops: Bool { self == .idle || self == .run }
}

/// Each row in `FoolSkillVFXAtlas` is a four-frame authored raster clip.
/// Keeping the clip identity separate from combat behavior prevents every
/// projectile or area skill from inheriting the same visual template.
private enum FoolSkillVFXClip: Int {
    case weaknessJudgment = 0
    case spiritualEvasion = 1
    case simpleDivination = 2
    case dangerPremonition = 3
}

/// Reusable authored spell presentation for a Fool card. Combat rules remain
/// in CombatCore; this value is the visual skill that can be reused by later
/// encounters without duplicating scene choreography in their turn logic.
struct FoolSpellVFXSkill {
    let id: FoolSkillID
    let presentationID: DungeonSkillID

    static func authored(_ id: FoolSkillID) -> FoolSpellVFXSkill {
        let presentationID: DungeonSkillID = switch id {
        case .sidestepStrike: .mobility
        case .fabricatedEvidence, .maskedWhisper: .strike
        case .paperDouble: .ward
        case .identityDisplacement, .turnTheTables: .control
        case .mirrorPursuit, .backstageChange: .mobility
        case .absurdFinale, .namelessStage: .ultimate
        }
        return FoolSpellVFXSkill(id: id, presentationID: presentationID)
    }
}

private struct DungeonEnemyAnimationClips {
    let idle: [SKTexture]
    let attack: [SKTexture]
    let hit: [SKTexture]
    let death: [SKTexture]
}

@MainActor
private final class DungeonEnemyActor {
    let spawn: DungeonEnemySpawn
    let node: SKNode
    let visualNode: SKNode
    let artworkNode: SKSpriteNode?
    let defensiveTexture: SKTexture?
    let controlSealAuraNode: SKNode?
    var animationClips: DungeonEnemyAnimationClips
    let baseAnimationClips: DungeonEnemyAnimationClips
    let shieldedAnimationClips: DungeonEnemyAnimationClips?
    let healthFill: SKShapeNode
    let willpowerFill: SKShapeNode
    let intentLabel: SKLabelNode
    let groundShadow: SKShapeNode
    let contactShadow: SKShapeNode
    let homePosition: CGPoint
    var health: Int
    var attackCooldown: TimeInterval = 0
    var state: DungeonEnemyActionState = .idle
    var stateTimer: TimeInterval = 0
    var telegraphNode: SKShapeNode?
    var skillTelegraphNode: SKNode?
    var telegraphTarget = CGPoint.zero
    var isEnraged = false
    var animationKey = ""
    var attacksPerformed = 0
    let maxWillpower: Int
    var willpower: Int
    var staggeredTurns = 0
    /// Remaining player windows that receive bonus damage after control lands.
    /// Values are deliberately longer than the skipped enemy action so a
    /// successful break always creates a usable follow-up turn.
    var exposedTurns = 0
    var displayAltitude: CGFloat = 0
    var hoverPhase: CGFloat = 0
    var usesIntegratedControlSeal = false
    /// Defensive intent holds the authored shield stance through the entire
    /// player round instead of letting the idle updater restore the body art.
    var holdsDefensivePose = false

    var isAlive: Bool { state != .dead }

    init(
        spawn: DungeonEnemySpawn,
        node: SKNode,
        visualNode: SKNode,
        artworkNode: SKSpriteNode?,
        defensiveTexture: SKTexture? = nil,
        controlSealAuraNode: SKNode? = nil,
        animationClips: DungeonEnemyAnimationClips,
        baseAnimationClips: DungeonEnemyAnimationClips? = nil,
        shieldedAnimationClips: DungeonEnemyAnimationClips? = nil,
        startsWithIntegratedControlSeal: Bool = false,
        healthFill: SKShapeNode,
        willpowerFill: SKShapeNode,
        intentLabel: SKLabelNode,
        groundShadow: SKShapeNode,
        contactShadow: SKShapeNode,
        homePosition: CGPoint
    ) {
        self.spawn = spawn
        self.node = node
        self.visualNode = visualNode
        self.artworkNode = artworkNode
        self.defensiveTexture = defensiveTexture
        self.controlSealAuraNode = controlSealAuraNode
        self.baseAnimationClips = baseAnimationClips ?? animationClips
        self.shieldedAnimationClips = shieldedAnimationClips
        self.animationClips = startsWithIntegratedControlSeal
            ? (shieldedAnimationClips ?? animationClips)
            : animationClips
        usesIntegratedControlSeal = startsWithIntegratedControlSeal
        self.healthFill = healthFill
        self.willpowerFill = willpowerFill
        self.intentLabel = intentLabel
        self.groundShadow = groundShadow
        self.contactShadow = contactShadow
        self.homePosition = homePosition
        health = spawn.maxHealth
        switch spawn.rank {
        case .normal: maxWillpower = 40
        case .elite: maxWillpower = 70
        case .boss: maxWillpower = 110
        }
        willpower = maxWillpower
    }
}

@MainActor
final class DungeonScene: SKScene {
    private var effectsOnlyOverlayEnabled = false
    private var unityClockGuardAuraHomes: [String: CGPoint] = [:]

    /// Keeps the original authored combat VFX while Unity supplies the arena
    /// and actors. Existing scene content continues updating but is invisible;
    /// newly spawned `combat-effect` nodes remain visible over the 3D view.
    func enableEffectsOnlyOverlay() {
        // The simulator export now contains an arm64 iOS-Simulator Unity
        // runtime, so it must use the same live 3D actor path as a device.
        // Leaving the former simulator fallback enabled draws an opaque
        // SpriteKit battlefield over Unity, including sampled actor frames
        // and their stale screen-space anchors.
        effectsOnlyOverlayEnabled = true
        applyEffectsOnlyOverlay()
    }

    private func applyEffectsOnlyOverlay() {
        guard effectsOnlyOverlayEnabled else { return }
        backgroundColor = .clear
        view?.allowsTransparency = true
        children.forEach { node in
            node.isHidden = !(node.name?.hasPrefix("combat-effect") ?? false)
        }
        // Move the authored shield into the transparent effects layer, but
        // keep it hidden at rest. SpriteKit and Unity cannot share a transform,
        // so the shield is now an impact-only flash instead of trying to chase
        // the moving 3D guard and visibly drifting away from it.
        for enemy in enemies {
            guard let aura = enemy.controlSealAuraNode,
                  aura.parent !== self,
                  let parent = aura.parent else { continue }
            let scenePosition = parent.convert(aura.position, to: self)
            // The seal is authored in the same local space as the native
            // fallback artwork. Preserve that artwork scale when detaching it
            // into the transparent Unity effects layer.
            let visualScale = max(0.01, enemy.visualNode.xScale)
            aura.removeFromParent()
            aura.name = "combat-effect-control-seal"
            aura.setScale(visualScale)
            if level.id.contains("chapter01_q02_encounter") {
                // Unity places the attacking guard on the right in the
                // two-enemy encounter. The hidden SpriteKit guard remains
                // centered, so its old coordinates cannot anchor this aura.
                aura.position = CGPoint(x: size.width * 0.63, y: scenePosition.y)
            } else {
                aura.position = scenePosition
            }
            unityClockGuardAuraHomes[enemy.spawn.id] = aura.position
            aura.zPosition = 19
            aura.isHidden = true
            addChild(aura)
        }
    }
    var onEnemyTapped: ((String) -> Void)?
    var onStateChange: ((DungeonCombatSnapshot) -> Void)?

    private let level: DungeonLevel
    private let path: Pathway
    private let skills: [DungeonSkillDefinition]
    private let relicIDs: [String]
    private let navigation: DungeonNavigationGrid
    private let damageMultiplier: CGFloat
    private let playerSequence: Int
    private let playerPlacement: ChapterOnePlayerPlacement
    /// When true, MistportCombatCore owns all gameplay state and this scene
    /// renders only the established cards, actor clips and combat effects.
    private let presentationOnly: Bool
    private let player = SKNode()
    private let playerVisual = SKNode()
    private var playerArtwork: SKSpriteNode?
    private let playerHealthFill = SKShapeNode()
    private let playerHealthBackground = SKShapeNode()
    private let playerHealthLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var playerFacing: FoolFacing = .north
    private var playerMotion: FoolMotion = .idle
    private var playerTextureCache: [String: [SKTexture]] = [:]
    private var foolTarotVFXTextureCache: [SKTexture]?
    private var foolSkillVFXTextureCache: [SKTexture]?
    private var clockGuardSkillVFXTextureCache: [String: SKTexture] = [:]
    private var playerUsesFallbackTexture = true
    // Routing state only. A visible magic circle under the character makes the
    // painted sprite read as if it is hovering above the arena.
    private let destinationMarker = SKNode()
    private let sceneCamera = SKCameraNode()
    private var enemies: [DungeonEnemyActor] = []
    private var route: [CGPoint] = []
    private var selectedEnemyID: String?
    private var pendingBasicAttack = false
    private var pendingSkillID: DungeonSkillID?
    private var skillCooldowns: [DungeonSkillID: TimeInterval]
    private var turnPhase: DungeonTurnPhase = .player
    private var enemyTurnQueue: [DungeonEnemyActor] = []
    private var turnNumber = 1
    private var lastUpdateTime: TimeInterval?
    private var hudPublishAccumulator: TimeInterval = 0
    private var basicAttackCooldown: TimeInterval = 0
    private var playerInvulnerability: TimeInterval = 0
    private var playerReactionCharges = 0
    private var playerGuardCharges = 0
    private var playerParryCharges = 0
    private var playerCounterCharges = 0
    private var playerOmen = 0
    private var foolUltimateOmenSpent = 0
    private var usedRelicIDs: Set<String> = []
    private var combat = DungeonCombatSnapshot()
    private var lastPublishedCombat: DungeonCombatSnapshot?
    private var didBuildScene = false
    private var combatHasStarted = false
    private var currentWave = 1
    private var isTransitioningWaves = false

    private var isAutomatedCombatPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--preview-dungeon")
            || ProcessInfo.processInfo.arguments.contains("--preview-boss")
            || ProcessInfo.processInfo.arguments.contains("--preview-elite")
            || ProcessInfo.processInfo.arguments.contains("--preview-salt-boss")
            || ProcessInfo.processInfo.arguments.contains("--preview-mirror-boss")
            || ProcessInfo.processInfo.arguments.contains("--preview-tide-boss")
            || ProcessInfo.processInfo.arguments.contains("--preview-crown-boss")
        #else
        false
        #endif
    }

    private var isWaveProgressionPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--preview-wave-progression")
        #else
        false
        #endif
    }

    private var holdsFinalWaveForPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--preview-final-wave-hold")
        #else
        false
        #endif
    }

    private var playerZone: (center: CGPoint, radius: CGFloat) {
        // A compact dodge zone centred on the bridge, clear of the bottom HUD.
        (playerPlacement.scenePoint(in: size), 48)
    }

    private var enemyZone: (center: CGPoint, radius: CGFloat) {
        // Matches the large circular arena painted into SceneClockDistrictV2.
        (CGPoint(x: size.width * 0.5, y: 520), 158)
    }

    /// Sequence 9 establishes a shared awakening language for every pathway:
    /// the attack silhouette remains pathway-specific, while its energy,
    /// bloom and contact light use one luminous spirit-blue.
    private var basicAttackVFXProfile: BasicAttackVFXProfile {
        BasicAttackVFXCatalog.profile(forSequence: playerSequence)
    }

    private var basicAttackVFXTint: UIColor {
        basicAttackVFXProfile.sharedTint.map(UIColor.init) ?? UIColor(path.tint)
    }

    private var playerAnimationTimingMultiplier: TimeInterval {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--preview-slow-animation") ? 4 : 1
        #else
        1
        #endif
    }

    private func presentationAdjustedPlayerPosition(_ position: CGPoint) -> CGPoint {
        guard presentationOnly else { return position }
        if level.id.contains("chapter01_q06") { return CGPoint(x: size.width / 2, y: max(position.y, size.height * 0.34)) }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return CGPoint(
            x: center.x + (position.x - center.x) * 1.25,
            y: center.y + (position.y - center.y) * 1.25
        )
    }

    private var bossCounterHint: String {
        switch path.id {
        case .fool:
            "第三次锁定会被纸人代身规避"
        case .priestess:
            "读取延长预警，治疗后再换位"
        case .chariot:
            "在回响落下前以意志护盾硬抗"
        case .magician:
            "结构解离对首领增伤，抢攻破阵"
        case .justice:
            "衡盾迎击落点，触发完美衡反"
        case .star:
            "连续施法压缩冷却，以星轨续航"
        }
    }

    private func configurePathVitality() {
        let maximum = path.id == .chariot ? 130 : 100
        combat.maxPlayerHealth = maximum
        combat.playerHealth = maximum
    }

    init(
        level: DungeonLevel,
        path: Pathway,
        skills: [DungeonSkillDefinition],
        relicIDs: [String] = [],
        damageMultiplier: CGFloat = 1,
        presentationOnly: Bool = false,
        playerSequence: Int = 9,
        playerPlacement: ChapterOnePlayerPlacement = .standard
    ) {
        self.level = level
        self.path = path
        self.skills = skills
        self.relicIDs = relicIDs
        self.damageMultiplier = damageMultiplier
        self.presentationOnly = presentationOnly
        self.playerSequence = playerSequence
        self.playerPlacement = playerPlacement.normalized
        navigation = DungeonNavigationGrid(level: level, columns: 18, rows: 36)
        skillCooldowns = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, 0) })
        super.init(size: level.sceneSize)
        scaleMode = .aspectFill
        anchorPoint = .zero
        backgroundColor = .black
        combat.enemiesRemaining = level.enemies.filter { $0.wave == 1 }.count
        combat.totalWaves = level.totalWaves
        combat.waveTitle = level.waveTitle(for: 1)
        combat.skillCooldowns = skillCooldowns
        configurePathVitality()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        guard !didBuildScene else { return }
        didBuildScene = true
        view.ignoresSiblingOrder = true
        buildCamera()
        buildBackground()
        buildPlayer()
        buildDestinationMarker()
        buildDistrictAtmosphere()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--preview-final-wave")
            || ProcessInfo.processInfo.arguments.contains("--preview-clock-guard") {
            currentWave = level.totalWaves
        }
        #endif
        spawnEnemies()
        // Chapter One draws one authoritative health HUD in SwiftUI so the
        // same values can sit over either SpriteKit (Simulator) or Unity
        // (device). Keep the actor art, intent and control resource in this
        // scene, but do not leave a second red bar under every model.
        suppressPresentationHealthBars()
        applyEffectsOnlyOverlay()
        if presentationOnly {
            // Chapter One uses CombatCore as the sole rules authority, but it
            // must still open like a battle rather than a static screenshot.
            run(.sequence([
                .wait(forDuration: 0.18),
                .run { [weak self] in self?.castWaveArrivalPulse() }
            ]), withKey: "chapter-one-battle-intro")
        }
        publishState("我方回合 · 选择目标与行动", force: true)

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--preview-clock-guard-target"),
           let guardActor = enemies.first(where: { $0.spawn.kind == .hollowClockGuard }) {
            // Stable capture hook for comparing the native fallback with
            // Unity's EnemyTargetSigil. Delay until SwiftUI has performed its
            // initial empty target sync, otherwise that sync immediately
            // removes the marker before a screenshot can be inspected.
            run(.sequence([
                .wait(forDuration: 0.65),
                .run { [weak self, weak guardActor] in
                    guard let self, let guardActor else { return }
                    self.showQueuedTargets([
                        DungeonQueuedTargetAssignment(
                            targetID: guardActor.spawn.id,
                            order: 1,
                            skillName: "目标标记预览"
                        )
                    ], pendingTargetIDs: [])
                }
            ]), withKey: "preview-clock-guard-target")
        }
        let previewsEnemyAttack = ProcessInfo.processInfo.arguments.contains("--preview-enemy-attack")
        let previewsSaltAttack = ProcessInfo.processInfo.arguments.contains("--preview-salt-attack")
        let previewsEnemyDeath = ProcessInfo.processInfo.arguments.contains("--preview-enemy-death")
        let previewsWillpowerBreak = ProcessInfo.processInfo.arguments.contains("--preview-willpower-break")
        let previewsGrandVFX = ProcessInfo.processInfo.arguments.contains("--preview-grand-vfx")
        let foolPreviewClip: FoolSkillVFXClip? = {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--preview-fool-weakness-vfx") { return .weaknessJudgment }
            if arguments.contains("--preview-fool-evasion-vfx") { return .spiritualEvasion }
            if arguments.contains("--preview-fool-divination-vfx") { return .simpleDivination }
            if arguments.contains("--preview-fool-danger-vfx") { return .dangerPremonition }
            return nil
        }()
        if isAutomatedCombatPreview, !previewsEnemyAttack {
            // Keep capture runs deterministic: enemy attacks are validated in their
            // own pass and must not interrupt the player VFX sequence.
            enemies.forEach { $0.attackCooldown = 999 }
        }
        if previewsEnemyAttack {
            combatHasStarted = true
            // Animation QA must keep the target alive long enough to inspect
            // every authored frame. This flag is DEBUG-only and never changes
            // production combat balance.
            playerInvulnerability = .greatestFiniteMagnitude
            let previewKind: DungeonEnemyKind
            if ProcessInfo.processInfo.arguments.contains("--preview-clock-guard") {
                previewKind = .hollowClockGuard
            } else if ProcessInfo.processInfo.arguments.contains("--preview-mirror-dungeon")
                        || ProcessInfo.processInfo.arguments.contains("--preview-mirror-boss") {
                previewKind = .mirrorShade
            } else {
                previewKind = previewsSaltAttack ? .saltWraith : .gearHound
            }
            enemies.forEach { actor in
                actor.attackCooldown = actor.spawn.kind == previewKind ? 0.12 : 999
            }
            if let previewEnemy = enemies.first(where: { $0.spawn.kind == previewKind }) {
                selectedEnemyID = previewEnemy.spawn.id
                updateSelectionRings()
                scheduleEnemyAttackPreview(previewEnemy)
            }
        }
        if previewsWillpowerBreak,
           let target = enemies.first(where: { $0.spawn.kind == .mirrorShade }) ?? enemies.first {
            combatHasStarted = true
            enemies.forEach { $0.attackCooldown = 999 }
            selectedEnemyID = target.spawn.id
            updateSelectionRings()
            run(.sequence([
                .wait(forDuration: 0.8),
                .run { [weak self, weak target] in
                    guard let self, let target else { return }
                    self.applyWillpowerDamage(target.maxWillpower, to: target)
                    self.publishState("意志击破 · 敌方下一行动延后", force: true)
                }
            ]))
        }
        if previewsEnemyDeath,
           let hound = enemies.first(where: { $0.spawn.kind == .gearHound }) {
            combatHasStarted = true
            enemies.forEach { $0.attackCooldown = 999 }
            selectedEnemyID = hound.spawn.id
            updateSelectionRings()
            run(.sequence([
                // Leave enough settled time for simulator capture and visual QA
                // before the authored collapse begins.
                .wait(forDuration: 6.0),
                .run { [weak self, weak hound] in
                    guard let self, let hound else { return }
                    self.applyDamage(hound.spawn.maxHealth + 1, to: hound, knockback: 0)
                }
            ]))
        }
        if ProcessInfo.processInfo.arguments.contains("--preview-victory") {
            enemies.forEach { $0.node.removeFromParent() }
            combat.enemiesRemaining = 0
            combat.isVictorious = true
            publishState("区域净化", feedback: true, force: true)
        } else if ProcessInfo.processInfo.arguments.contains("--preview-defeat") {
            combat.playerHealth = 0
            combat.isDefeated = true
            player.alpha = 0.25
            publishState("战斗失败", feedback: true, force: true)
        } else if let foolPreviewClip,
                  let previewTarget = selectedOrNearestEnemy() {
            // Dedicated visual QA entry points keep each Fool skill readable in
            // isolation. They deliberately skip damage and turn resolution.
            playerInvulnerability = .greatestFiniteMagnitude
            enemies.forEach { $0.attackCooldown = 999 }
            selectEnemy(previewTarget)
            run(.sequence([
                // Wait until the SwiftUI battle-entry curtain has fully cleared.
                .wait(forDuration: 4.0),
                .repeatForever(.sequence([
                    .run { [weak self, weak previewTarget] in
                        guard let self, let previewTarget else { return }
                        switch foolPreviewClip {
                        case .weaknessJudgment:
                            let tint = UIColor(self.path.tint)
                            self.spawnFoolSkillClip(.weaknessJudgment, at: previewTarget.node.position, size: 390, timePerFrame: 0.105)
                            self.spawnWeaknessScan(
                                from: self.playerCastingHandPosition(),
                                to: previewTarget.node.position,
                                color: tint
                            )
                            self.spawnWeakpointResidue(at: previewTarget.node.position, color: tint)
                        case .spiritualEvasion:
                            let tint = UIColor(red: 0.18, green: 0.84, blue: 1, alpha: 1)
                            self.spawnFoolSkillClip(.spiritualEvasion, at: self.player.position, size: 480, timePerFrame: 0.085)
                            self.spawnSpiritualAfterimages(at: self.player.position, color: tint)
                            self.spawnFoolSkillClip(.spiritualEvasion, at: previewTarget.node.position, size: 300, timePerFrame: 0.062, rotation: .pi)
                        case .simpleDivination:
                            let tint = UIColor(red: 0.98, green: 0.76, blue: 0.18, alpha: 1)
                            let radius = min(self.size.width * 0.47, CGFloat(220))
                            self.spawnFoolSkillClip(.simpleDivination, at: previewTarget.node.position, size: 590, timePerFrame: 0.09)
                            self.spawnDivinationConstellation(at: previewTarget.node.position, radius: radius, color: tint)
                        case .dangerPremonition:
                            let tint = UIColor(red: 0.90, green: 0.12, blue: 0.54, alpha: 1)
                            self.spawnDangerVeil(at: previewTarget.node.position)
                            self.spawnFoolSkillClip(.dangerPremonition, at: previewTarget.node.position, size: 640, timePerFrame: 0.07)
                            self.spawnAreaBurst(at: previewTarget.node.position, color: tint, radius: 152)
                        }
                    },
                    .wait(forDuration: 0.78)
                ]))
            ]))
        } else if previewsGrandVFX,
                  let previewTarget = selectedOrNearestEnemy() {
            // Deterministic visual QA: isolate the complete cast/impact
            // composition without turn resolution or enemy damage hiding it.
            playerInvulnerability = .greatestFiniteMagnitude
            enemies.forEach { $0.attackCooldown = 999 }
            selectEnemy(previewTarget)
            run(.sequence([
                .wait(forDuration: 4.0),
                .run { [weak self, weak previewTarget] in
                    guard let self, let previewTarget else { return }
                    self.spawnTarotCastVFX(at: self.player.position, size: 392)
                    self.spawnTargetWarning(
                        at: previewTarget.node.position,
                        color: UIColor(self.path.tint),
                        radius: 154,
                        duration: 0.34
                    )
                },
                .wait(forDuration: 0.42),
                .run { [weak self, weak previewTarget] in
                    guard let self, let previewTarget else { return }
                    self.spawnGrandArcanaSweep(
                        at: previewTarget.node.position,
                        color: UIColor(self.path.tint),
                        intensity: 1
                    )
                    self.spawnTarotImpactVFX(at: previewTarget.node.position, size: 900)
                    self.spawnImpact(at: previewTarget.node.position, color: UIColor(self.path.tint), radius: 150)
                    self.spawnResidualArcana(
                        at: previewTarget.node.position,
                        color: UIColor(self.path.tint),
                        count: 28
                    )
                }
            ]))
        } else if isAutomatedCombatPreview,
           !ProcessInfo.processInfo.arguments.contains("--static-dungeon") {
            let attackCycle = SKAction.sequence([
                .wait(forDuration: 1.15),
                .run { [weak self] in self?.performBasicAttack() }
            ])
            run(.sequence([
                // Simulator and CI captures need the first frame to settle before
                // the authored combat sequence begins.
                .wait(forDuration: 2.4),
                .run { [weak self] in self?.performBasicAttack() },
                .wait(forDuration: 1.0),
                .run { [weak self] in self?.performSkill(.strike) },
                .wait(forDuration: 1.35),
                .run { [weak self] in self?.performSkill(.mobility) },
                .wait(forDuration: 1.45),
                .run { [weak self] in self?.performSkill(.ultimate) },
                .repeat(attackCycle, count: 10)
            ]))
        }
        #endif
    }

    #if DEBUG
    /// Replays the same windup/resolve path used by a production enemy turn.
    /// Keeping this preview independent from player input makes authored frame
    /// inspection deterministic without reviving the retired real-time AI.
    private func scheduleEnemyAttackPreview(_ enemy: DungeonEnemyActor) {
        let previewCycle = SKAction.sequence([
            .wait(forDuration: 1.0),
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive,
                      enemy.state == .idle || enemy.state == .recovering else { return }
                self.beginEnemyWindup(enemy)
            },
            .wait(forDuration: 3.2)
        ])
        run(.repeatForever(previewCycle), withKey: "enemy-attack-preview")
    }
    #endif

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !combat.isVictorious, !combat.isDefeated,
              let point = touches.first?.location(in: self) else { return }

        if let enemy = enemy(at: point) {
            if presentationOnly {
                onEnemyTapped?(enemy.spawn.id)
            } else {
                selectEnemy(enemy)
                publishState("锁定 · \(enemy.spawn.title)")
            }
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let elapsed = min(1.0 / 20.0, currentTime - (lastUpdateTime ?? currentTime))
        lastUpdateTime = currentTime
        let delta = CGFloat(elapsed)

        playerInvulnerability = max(0, playerInvulnerability - elapsed)
        updateDepthScale()
        if !presentationOnly {
            updateEnemies(deltaTime: delta, elapsed: elapsed)
        }
        updatePlayerTargetFacing()

        hudPublishAccumulator += elapsed
        if hudPublishAccumulator >= 0.10 {
            hudPublishAccumulator = 0
            publishState(force: false)
        }
    }

    func performBasicAttack() {
        guard !combat.isVictorious, !combat.isDefeated, turnPhase == .player,
              let target = selectedOrNearestEnemy() else { return }
        beginPlayerAction()
        combatHasStarted = true
        selectEnemy(target)

        pendingBasicAttack = false
        facePlayer(toward: target.node.position)
        animatePlayerAttack()
        let attackTint = basicAttackVFXTint
        spawnCastSigil(at: player.position, color: attackTint, radius: 32)
        spawnTarotCastVFX(at: player.position, size: 278)
        if basicAttackVFXProfile.usesSharedBloom {
            spawnSequenceNineBasicAttackBloom(at: playerCastingHandPosition(), scale: 0.72)
        }
        spawnTargetWarning(at: target.node.position, color: attackTint, radius: 28, duration: 0.10)
        run(.sequence([
            .wait(forDuration: 0.20),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                self.launchPlayerProjectile(
                    toward: target,
                    color: attackTint,
                    size: 8,
                    duration: 0.50
                )
            },
            .wait(forDuration: 0.51),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                self.applyDamage(30, to: target, knockback: 7)
                self.applyWillpowerDamage(5, to: target)
                let center = self.enemyBodyCenter(target)
                self.spawnImpact(at: center, color: attackTint, radius: 48)
                self.spawnTarotImpactVFX(at: center, size: 236)
                self.spawnResidualArcana(at: center, color: attackTint, count: 9)
                if self.basicAttackVFXProfile.usesSharedBloom {
                    self.spawnSequenceNineBasicAttackBloom(at: center)
                }
                self.publishState("普攻 · 30", feedback: true)
                self.finishPlayerAction(after: 0.18)
            }
        ]))
    }

    func performSkill(_ skillID: DungeonSkillID) {
        guard !combat.isVictorious, !combat.isDefeated, turnPhase == .player,
              skillCooldowns[skillID, default: 0] <= 0,
              let definition = skills.first(where: { $0.id == skillID }),
              let target = selectedOrNearestEnemy() else { return }
        combatHasStarted = true
        selectEnemy(target)
        beginPlayerAction()
        cast(definition, at: target)
    }

    /// Plays an authored Fool spell without starting a second combat model.
    func presentFoolSkill(_ skillID: DungeonSkillID, extendedPresentation: Bool = false) {
        guard presentationOnly,
              let definition = skills.first(where: { $0.id == skillID }),
              let target = selectedOrNearestEnemy() else { return }
        selectEnemy(target)
        turnPhase = .player
        combat.isPlayerTurn = true
        cast(definition, at: target)
        if extendedPresentation {
            sustainFoolSpellPresentation(skillID, around: enemyBodyCenter(target), tint: UIColor(definition.tint))
        }
    }

    /// Plays a reusable card-specific visual skill. New encounters should use
    /// this entry point so expanding a card's art direction stays independent
    /// from combat sequencing.
    func presentFoolSkill(_ skill: FoolSpellVFXSkill, extendedPresentation: Bool = false) {
        // Sidestep Strike already owns a complete phase/impact sequence.
        // Scheduling the generic 0.72/1.28/1.86-second sustain waves made
        // cyan shards reappear after the card had visibly finished.
        let shouldSustain = extendedPresentation && skill.id != .sidestepStrike
        presentFoolSkill(skill.presentationID, extendedPresentation: shouldSustain)
    }

    /// A lower-rank version of the Fool's layered card burst. It keeps the
    /// authored cards, star flares and arcane fragments readable, but uses
    /// roughly sixty percent of the ultimate's footprint and density.
    func presentFoolBasicAttack() {
        guard presentationOnly,
              skills.contains(where: { $0.id == .strike }),
              let target = selectedOrNearestEnemy()
        else { return }

        selectEnemy(target)
        turnPhase = .player
        combat.isPlayerTurn = true
        animatePlayerSkill(.skillStrike)

        let tint = basicAttackVFXTint
        let center = enemyBodyCenter(target)
        spawnTargetWarning(at: center, color: tint, radius: 42, duration: 0.20)
        spawnFoolSkillClip(.weaknessJudgment, at: center, size: 220, timePerFrame: 0.09)
        if basicAttackVFXProfile.usesSharedBloom {
            spawnSequenceNineBasicAttackBloom(at: playerCastingHandPosition(), scale: 0.72)
        }

        run(.sequence([
            .wait(forDuration: 0.26),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                self.launchPlayerProjectile(
                    from: self.playerCastingHandPosition(),
                    toward: target,
                    color: tint,
                    size: 10,
                    duration: 0.28
                )
            },
            .wait(forDuration: 0.29),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                let impactCenter = self.enemyBodyCenter(target)
                self.spawnLowRankFoolBasicImpact(
                    at: impactCenter,
                    tint: tint
                )
                if self.basicAttackVFXProfile.usesSharedBloom {
                    self.spawnSequenceNineBasicAttackBloom(at: impactCenter, scale: 1.18)
                }
            }
        ]))
    }

    /// Basic defense uses a personal glass-like oval rather than the Clock
    /// Guard's violet mantle. The node is parented to the player, so it keeps
    /// covering the whole body if the actor moves during the presentation.
    func presentFoolBasicDefense() {
        guard presentationOnly else { return }
        turnPhase = .player
        combat.isPlayerTurn = true
        spawnFoolPersonalAegis()
    }

    private func enemyBodyCenter(_ enemy: DungeonEnemyActor) -> CGPoint {
        guard let artwork = enemy.artworkNode else {
            return CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 48)
        }
        return artwork.convert(
            CGPoint(x: 0, y: artwork.size.height * 0.5),
            to: self
        )
    }

    private func enemyCombatNumberAnchor(_ enemy: DungeonEnemyActor) -> CGPoint {
        guard let artwork = enemy.artworkNode else {
            return CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 112)
        }
        return artwork.convert(
            CGPoint(x: 0, y: artwork.size.height * 0.92),
            to: self
        )
    }

    private func playerCombatNumberAnchor() -> CGPoint {
        guard let artwork = playerArtwork else {
            return CGPoint(x: player.position.x, y: player.position.y + 126)
        }
        return artwork.convert(
            CGPoint(x: 0, y: artwork.size.height * 0.92),
            to: self
        )
    }

    /// Returns the real top edge of the rendered Fool in SpriteKit view
    /// coordinates. ChapterOneTestView uses this for its single SwiftUI health
    /// bar, so changing the player placement or artwork scale cannot leave the
    /// bar floating in the middle of the arena.
    func chapterOnePlayerHealthAnchorInView() -> CGPoint? {
        guard presentationOnly, view != nil, let artwork = playerArtwork else {
            return nil
        }
        let scenePoint = artwork.convert(
            CGPoint(x: 0, y: artwork.size.height),
            to: self
        )
        return convertPoint(toView: scenePoint)
    }

    /// Returns the real top edge of one rendered enemy in SpriteKit view
    /// coordinates. This deliberately follows the artwork node instead of the
    /// authored formation root because different 3D captures have different
    /// visible heights.
    func chapterOneEnemyHealthAnchorInView(for enemyID: String) -> CGPoint? {
        guard presentationOnly,
              view != nil,
              let enemy = enemies.first(where: { $0.spawn.id == enemyID }),
              let artwork = enemy.artworkNode else {
            return nil
        }
        let scenePoint = artwork.convert(
            CGPoint(x: 0, y: artwork.size.height),
            to: self
        )
        return convertPoint(toView: scenePoint)
    }

    private func sustainFoolSpellPresentation(
        _ skillID: DungeonSkillID,
        around center: CGPoint,
        tint: UIColor
    ) {
        let clip: FoolSkillVFXClip = switch skillID {
        case .strike: .weaknessJudgment
        case .mobility: .spiritualEvasion
        case .control: .simpleDivination
        case .ward: .dangerPremonition
        case .ultimate: .simpleDivination
        }
        for (index, delay) in [0.72, 1.28, 1.86].enumerated() {
            run(.sequence([
                .wait(forDuration: delay),
                .run { [weak self] in
                    guard let self else { return }
                    self.spawnResidualArcana(at: center, color: tint, count: 7 + index * 3)
                    self.spawnCastSigil(at: center, color: tint, radius: CGFloat(42 + index * 13))
                    if index == 1 {
                        self.spawnFoolSkillClip(
                            clip,
                            at: center,
                            size: skillID == .ultimate ? 650 : 380,
                            timePerFrame: 0.12
                        )
                    }
                }
            ]))
        }
    }

    /// Presents the hostile half of a turn without applying a second damage
    /// model. CombatCore has already decided damage; this scene only provides
    /// the telegraph, cast, impact and recovery a player expects to see.
    func presentChapterOneEnemyTurn(
        damage: Int,
        intents: [String],
        actingEnemyIDs: Set<String>? = nil
    ) {
        guard presentationOnly, !combat.isDefeated, !combat.isVictorious else { return }
        let attackers = enemies.filter {
            $0.isAlive && (actingEnemyIDs == nil || actingEnemyIDs?.contains($0.spawn.id) == true)
        }
        guard !attackers.isEmpty else { return }

        if attackers.allSatisfy({ $0.spawn.title.contains("记忆蛭") }) {
            for enemy in attackers { presentMemoryLeechCast(enemy) }
            return
        }

        if level.id.contains("chapter01_q06"), attackers.allSatisfy({ $0.spawn.kind == .gearHound }) {
            for enemy in attackers {
                let hunt = intents.contains("name_hunt")
                spawnFloatingText(hunt ? "循名蓄势" : "撕咬", at: enemy.node.position, color: .systemOrange)
                animateEnemyAttack(enemy, toward: player.position)
                let home = enemy.visualNode.position
                enemy.visualNode.run(.sequence([
                    .moveBy(x: 0, y: 5, duration: 0.65),
                    .moveBy(x: 0, y: -22, duration: 0.45),
                    .move(to: home, duration: 0.25)
                ]), withKey: "hound-strike")
                run(.sequence([.wait(forDuration: 1.1), .run { [weak self, weak enemy] in
                    guard let self, let enemy, enemy.isAlive else { return }
                    self.spawnGroundImpact(at: self.player.position, color: .systemOrange, radius: hunt ? 45 : 25)
                }]))
            }
            return
        }

        // The Unity hound owns its pounce. Its breath is deliberately drawn
        // in the transparent SpriteKit layer from Unity-provided anchors; the
        // old hidden-scene projectile otherwise created a second, disconnected
        // cyan hit beside the 3D dog.
        if effectsOnlyOverlayEnabled,
           attackers.allSatisfy({ $0.spawn.kind == .gearHound }) {
            return
        }

        // Judge the presentation from the authored intent, not final damage.
        // A real strike can deal zero after shielding and must still show its
        // weapon arc.
        let isDefensiveIntent = intents.contains {
            ["guard", "fortify", "recover", "calibrate", "charge"].contains($0)
        }
        if isDefensiveIntent {
            presentChapterOneNonAttackIntent(intents, enemies: attackers)
            return
        }

        attackers.forEach { enemy in
            enemy.holdsDefensivePose = false
            if enemy.spawn.kind == .hollowClockGuard, let artwork = enemy.artworkNode,
               let texture = enemy.animationClips.idle.first {
                normalizeClockGuardArtwork(artwork, texture: texture)
            }
        }
        attackers.forEach { beginEnemyWindup($0) }
        let authoredWindup = attackers.map(\.stateTimer).max() ?? 0.72
        // Q3 uses this native SpriteKit presentation while Q1/Q2 use Unity.
        // Give both routes the same action-to-contact timing instead of making
        // the third encounter keep the full generic telegraph before a strike.
        let isClockGuardStrike = attackers.contains { $0.spawn.kind == .hollowClockGuard }
        let windup: TimeInterval = isClockGuardStrike
            ? min(authoredWindup, 0.58)
            : authoredWindup
        let resolvedHostileIntent = intents.first {
            !$0.hasPrefix("下一意图：") && $0 != "delayed"
        } ?? "strike"
        // Match the 3D Clock Guard's visible contact beat: this is close to
        // the completion of the chop, just ahead of recovery. The SpriteKit
        // third encounter must not lead or lag the Unity presentation.
        let impactDelay: TimeInterval = isClockGuardStrike ? 0.56 : 1.18
        run(.sequence([
            .wait(forDuration: windup),
            .run { [weak self] in
                guard let self else { return }
                let target = self.player.position
                for enemy in attackers where enemy.isAlive {
                    enemy.telegraphNode?.removeFromParent()
                    enemy.telegraphNode = nil
                    enemy.state = .recovering
                    enemy.stateTimer = 0.38
                    enemy.intentLabel.text = enemyDisplayName(for: enemy)
                    enemy.intentLabel.fontColor = UIColor(white: 0.05, alpha: 0.62)
                    self.animateEnemyAttack(enemy, toward: target)
                    // Chapter-one presentation attacks stay on the authored
                    // combat spot. The strike frame itself supplies motion;
                    // moving the whole actor made the hit land after it had
                    // already returned home.
                    if enemy.spawn.kind == .gearHound {
                        self.run(.sequence([
                            .wait(forDuration: 0.62),
                            .run { [weak self, weak enemy] in
                                guard let self, let enemy, enemy.isAlive else { return }
                                let memoryColor = UIColor(red: 0.47, green: 0.86, blue: 1.0, alpha: 1)
                                let muzzle = CGPoint(
                                    x: enemy.node.position.x,
                                    y: enemy.node.position.y + 34
                                )
                                self.spawnAreaBurst(at: muzzle, color: memoryColor, radius: 38)
                                self.launchEnemyProjectile(
                                    from: muzzle,
                                    to: target,
                                    color: memoryColor,
                                    onImpact: { [weak self] in
                                        self?.spawnGroundImpact(at: target, color: UIColor(red: 0.61, green: 0.36, blue: 0.95, alpha: 1), radius: 82)
                                    }
                                )
                            }
                        ]), withKey: "chapter-one-hound-memory-fragment")
                    }
                }
            },
            .wait(forDuration: impactDelay),
            .run { [weak self] in
                guard let self else { return }
                let target = self.player.position
                for enemy in attackers where enemy.isAlive {
                    if enemy.spawn.kind == .gearHound {
                        let memoryColor = UIColor(red: 0.47, green: 0.86, blue: 1.0, alpha: 1)
                        self.spawnEnemySlash(at: target, color: memoryColor, radius: 92)
                        self.spawnEnemySlash(at: CGPoint(x: target.x - 16, y: target.y + 7), color: .systemPurple, radius: 74)
                        self.spawnGroundImpact(at: target, color: memoryColor, radius: 86)
                    } else if enemy.spawn.kind == .hollowClockGuard {
                        let impactPoint = CGPoint(x: target.x, y: target.y + 92)
                        self.presentClockGuardSkillVFX(
                            id: self.clockGuardSkillVFXID(
                                for: enemy,
                                intent: resolvedHostileIntent
                            ),
                            at: impactPoint
                        )
                    } else {
                        self.spawnImpact(
                            at: target,
                            color: self.enemyColor(for: enemy.spawn.kind),
                            radius: enemy.spawn.rank == .boss ? 108 : 72
                        )
                        self.spawnResidualArcana(at: target, color: .systemRed, count: 12)
                    }
                }
                // The damage number lands with the weapon impact. A long
                // delay makes the hit read as disconnected from the slash.
                self.run(.sequence([
                    .wait(forDuration: 0.03),
                    .run { [weak self] in
                        guard let self else { return }
                        if damage > 0 {
                            self.spawnCombatNumber(
                                "−\(damage)",
                                at: self.playerCombatNumberAnchor(),
                                color: .systemRed
                            )
                        }
                        // Keep the player in the authored formation pose. The
                        // impact remains readable through the damage number,
                        // camera impulse and enemy-side VFX; do not play a
                        // player recoil animation here.
                        self.shakeCamera()
                    }
                ]))
            },
            .wait(forDuration: 0.34),
            .run {
                attackers.forEach { enemy in
                    guard enemy.isAlive else { return }
                    enemy.state = .idle
                }
            }
        ]), withKey: "chapter-one-enemy-turn")
    }

    /// Shared silhouette for the hound's living mantle.
    private func hellfireTonguePath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -10))
        path.addCurve(
            to: CGPoint(x: 6, y: 0),
            control1: CGPoint(x: 6, y: -7),
            control2: CGPoint(x: 8, y: -2)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: 15),
            control1: CGPoint(x: 4, y: 6),
            control2: CGPoint(x: 2, y: 12)
        )
        path.addCurve(
            to: CGPoint(x: -6, y: 0),
            control1: CGPoint(x: -2, y: 10),
            control2: CGPoint(x: -7, y: 5)
        )
        path.closeSubpath()
        return path
    }

    /// Shows an enemy support skill after CombatCore has resolved its healing.
    /// It is deliberately separate from the health mutation so skip-animation
    /// mode can suppress every hostile VFX without suppressing the mechanic.
    func presentChapterOneEnemyHealing(
        targetID: String,
        amount: Int,
        delay: TimeInterval = 0.72
    ) {
        guard presentationOnly,
              amount > 0,
              let target = enemies.first(where: { $0.spawn.id == targetID && $0.isAlive }) else { return }

        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in
                guard let self else { return }
                target.health = min(target.spawn.maxHealth, target.health + amount)
                let fraction = CGFloat(target.health) / CGFloat(max(1, target.spawn.maxHealth))
                self.animateEnemyHealthFill(target, fraction: fraction, duration: 0.42)
            }
        ]), withKey: "chapter-one-enemy-healing-\(targetID)")
    }

    /// The combat runtime owns the defeat decision; this method only gives the
    /// SpriteKit battlefield its matching visual endpoint.
    func presentChapterOnePlayerDefeat() {
        guard presentationOnly else { return }
        animatePlayerDeath()
    }

    /// Mirrors authoritative v0.5 health into the established SpriteKit HUD.
    /// No damage is calculated here; this is strictly a presentation sync.
    func syncChapterOnePresentation(
        playerHP: Int,
        playerMaxHP: Int,
        enemyHealth: [String: (current: Int, maximum: Int)]
    ) {
        guard presentationOnly else { return }
        combat.playerHealth = playerHP
        combat.maxPlayerHealth = playerMaxHP
        let playerHealthFraction = CGFloat(max(0, playerHP)) / CGFloat(max(1, playerMaxHP))
        playerHealthFill.xScale = playerHealthFraction
        playerHealthLabel.text = "\(max(0, playerHP))/\(max(1, playerMaxHP))"
        for enemy in enemies {
            guard let health = enemyHealth[enemy.spawn.id] else { continue }
            let wasAlive = enemy.isAlive
            enemy.health = max(0, health.current)
            let fraction = CGFloat(max(0, health.current)) / CGFloat(max(1, health.maximum))
            // Health must remain legibly red for every enemy rank.  SpriteKit
            // can render the boss gradient texture as white in the simulator,
            // so keep the bar's material color explicit during every sync.
            enemy.healthFill.fillTexture = nil
            enemy.healthFill.fillColor = UIColor(red: 1.0, green: 0.06, blue: 0.10, alpha: 1)
            animateEnemyHealthFill(enemy, fraction: fraction, duration: 0.18)
            if wasAlive, health.current <= 0 {
                enemy.state = .dead
                enemy.intentLabel.isHidden = true
                enemy.telegraphNode?.removeFromParent()
                enemy.telegraphNode = nil
                playEnemyClip(enemy, textures: enemy.animationClips.death, key: "death", timePerFrame: 0.10)
                spawnEnemyDissolve(
                    at: CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 18),
                    color: enemyColor(for: enemy.spawn.kind),
                    scale: enemy.spawn.rank == .boss ? 1.65 : 1
                )
                enemy.node.run(.sequence([
                    .wait(forDuration: max(0.18, TimeInterval(enemy.animationClips.death.count) * 0.10)),
                    .fadeOut(withDuration: 0.26)
                ]))
            }
        }
        publishState(force: true)
    }

    /// Shows authoritative zero damage without mutating the presentation
    /// scene's legacy combat model.
    func presentChapterOneZeroDamage(targetID: String) {
        guard presentationOnly,
              let enemy = enemies.first(where: { $0.spawn.id == targetID && $0.isAlive }) else { return }
        let position = enemyBodyCenter(enemy)
        spawnCombatNumber("0", at: enemyCombatNumberAnchor(enemy), color: .systemRed, scale: 1.10)
        spawnImpact(at: position, color: .systemRed, radius: 42)
    }

    /// Adds state markers to the authored actor nodes. These are presentation
    /// only: CombatCore remains the source of truth for every stack and charge.
    func syncChapterOneStatuses(
        enemyStates: [String: FoolComboState],
        paperDoubleCounterReady: Bool,
        controlSealActive: Bool = false
    ) {
        guard presentationOnly else { return }

        for enemy in enemies {
            enemy.node.childNode(withName: "chapter-one-combo-state")?.removeFromParent()
            if enemy.spawn.kind == .hollowClockGuard {
                setClockGuardControlSeal(
                    controlSealActive && enemy.isAlive,
                    for: enemy
                )
            }

            guard enemy.isAlive, let state = enemyStates[enemy.spawn.id] else { continue }
            guard state.illusionStacks > 0 || state.misalignmentStacks > 0 || state.fabricatedEvidenceCharges > 0 else { continue }

            let container = SKNode()
            container.name = "chapter-one-combo-state"
            container.zPosition = 32
            let barY = enemy.healthFill.position.y

            if state.illusionStacks > 0 {
                let count = SKLabelNode(text: "误认 ×\(state.illusionStacks)")
                count.fontName = "AvenirNext-Bold"
                count.fontSize = 10
                count.fontColor = .white
                count.verticalAlignmentMode = .center
                count.position = CGPoint(x: 0, y: barY - 19)
                let plate = SKShapeNode(
                    rectOf: CGSize(width: max(58, count.frame.width + 18), height: 18),
                    cornerRadius: 9
                )
                plate.position = count.position
                plate.fillColor = UIColor(red: 0.34, green: 0.14, blue: 0.62, alpha: 0.88)
                plate.strokeColor = UIColor(red: 0.82, green: 0.68, blue: 1.0, alpha: 0.84)
                plate.lineWidth = 1
                container.addChild(plate)
                container.addChild(count)
            }

            if state.misalignmentStacks > 0 {
                let ring = SKShapeNode(ellipseOf: CGSize(width: 20, height: 10))
                ring.position = CGPoint(x: 11, y: barY + 18)
                ring.strokeColor = UIColor(red: 0.24, green: 0.84, blue: 1.0, alpha: 0.95)
                ring.lineWidth = 1.5
                ring.fillColor = .clear
                container.addChild(ring)
                let offset = SKShapeNode(ellipseOf: CGSize(width: 13, height: 7))
                offset.position = CGPoint(x: 16, y: barY + 21)
                offset.strokeColor = UIColor(red: 0.70, green: 0.96, blue: 1.0, alpha: 0.60)
                offset.lineWidth = 1
                offset.fillColor = .clear
                container.addChild(offset)
                let count = SKLabelNode(text: "错\(state.misalignmentStacks)")
                count.fontName = "AvenirNext-Bold"
                count.fontSize = 11
                count.fontColor = .white
                count.horizontalAlignmentMode = .center
                count.verticalAlignmentMode = .center
                count.position = CGPoint(x: 31, y: barY + 14)
                let countPlate = SKShapeNode(rectOf: CGSize(width: 28, height: 18), cornerRadius: 7)
                countPlate.position = count.position
                countPlate.fillColor = UIColor(red: 0.03, green: 0.12, blue: 0.20, alpha: 0.92)
                countPlate.strokeColor = UIColor(red: 0.36, green: 0.82, blue: 1.0, alpha: 0.9)
                countPlate.lineWidth = 1
                container.addChild(countPlate)
                container.addChild(count)
            }

            if state.fabricatedEvidenceCharges > 0 {
                let seal = SKShapeNode(rectOf: CGSize(width: 16, height: 13), cornerRadius: 2)
                seal.position = CGPoint(x: 0, y: barY - 18)
                seal.fillColor = UIColor(red: 0.75, green: 0.10, blue: 0.20, alpha: 0.9)
                seal.strokeColor = UIColor(red: 1.0, green: 0.75, blue: 0.45, alpha: 0.95)
                seal.lineWidth = 1
                container.addChild(seal)
                let count = SKLabelNode(text: "伪\(state.fabricatedEvidenceCharges)")
                count.fontName = "AvenirNext-Bold"
                count.fontSize = 8
                count.fontColor = .white
                count.verticalAlignmentMode = .center
                count.position = seal.position
                container.addChild(count)
            }
            enemy.node.addChild(container)
        }

        player.childNode(withName: "chapter-one-paper-double")?.removeFromParent()
        childNode(withName: "combat-effect-paper-double")?.removeFromParent()
        // Readiness belongs to the relic row, not to the battlefield. The
        // actual paper person is spawned only at the lethal-hit presentation
        // beat; rendering it here makes the player look permanently replaced.
        _ = paperDoubleCounterReady
    }

    private func makePaperDoubleOverlay() -> SKNode {
        let marker = SKNode()
        marker.name = "combat-effect-paper-double"
        marker.position = CGPoint(x: player.position.x, y: player.position.y + 25)
        marker.zPosition = 31

        let violet = UIColor(red: 0.68, green: 0.32, blue: 0.98, alpha: 1)
        let parchment = UIColor(red: 0.95, green: 0.82, blue: 0.59, alpha: 0.96)
        let gold = UIColor(red: 1.0, green: 0.78, blue: 0.31, alpha: 0.92)

        let aura = SKShapeNode(circleOfRadius: 24)
        aura.fillColor = violet.withAlphaComponent(0.08)
        aura.strokeColor = violet.withAlphaComponent(0.78)
        aura.lineWidth = 1.2
        aura.glowWidth = 8
        aura.blendMode = .add
        aura.zPosition = -2
        marker.addChild(aura)
        aura.run(.repeatForever(.sequence([
            .group([
                .scale(to: 1.12, duration: 0.82),
                .fadeAlpha(to: 0.48, duration: 0.82)
            ]),
            .group([
                .scale(to: 0.92, duration: 0.82),
                .fadeAlpha(to: 0.90, duration: 0.82)
            ])
        ])), withKey: "paper-double-aura")

        let cordPath = CGMutablePath()
        cordPath.move(to: CGPoint(x: 0, y: 31))
        cordPath.addLine(to: CGPoint(x: 0, y: 19))
        let cord = SKShapeNode(path: cordPath)
        cord.strokeColor = gold
        cord.lineWidth = 1.4
        cord.glowWidth = 2
        marker.addChild(cord)

        let head = SKShapeNode(circleOfRadius: 8)
        head.position = CGPoint(x: 0, y: 12)
        head.fillColor = parchment
        head.strokeColor = violet
        head.lineWidth = 1.2
        head.glowWidth = 2
        marker.addChild(head)

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -8, y: 5))
        bodyPath.addLine(to: CGPoint(x: -7, y: -8))
        bodyPath.addLine(to: CGPoint(x: -3, y: -14))
        bodyPath.addLine(to: CGPoint(x: 0, y: -9))
        bodyPath.addLine(to: CGPoint(x: 4, y: -14))
        bodyPath.addLine(to: CGPoint(x: 8, y: -8))
        bodyPath.addLine(to: CGPoint(x: 7, y: 5))
        bodyPath.addLine(to: CGPoint(x: 3, y: 9))
        bodyPath.addLine(to: CGPoint(x: -3, y: 9))
        bodyPath.closeSubpath()
        let body = SKShapeNode(path: bodyPath)
        body.fillColor = parchment
        body.strokeColor = violet
        body.lineWidth = 1.2
        body.glowWidth = 2
        marker.addChild(body)

        let armPath = CGMutablePath()
        armPath.move(to: CGPoint(x: -6, y: 1))
        armPath.addLine(to: CGPoint(x: -14, y: -5))
        armPath.move(to: CGPoint(x: 6, y: 1))
        armPath.addLine(to: CGPoint(x: 14, y: -5))
        let arms = SKShapeNode(path: armPath)
        arms.strokeColor = parchment
        arms.lineWidth = 3.5
        arms.lineCap = .round
        arms.glowWidth = 2
        marker.addChild(arms)

        let sigil = SKShapeNode(circleOfRadius: 4.5)
        sigil.position = CGPoint(x: 0, y: -1)
        sigil.fillColor = .clear
        sigil.strokeColor = violet
        sigil.lineWidth = 1
        sigil.glowWidth = 3
        marker.addChild(sigil)

        let sigilLinePath = CGMutablePath()
        sigilLinePath.move(to: CGPoint(x: -4.5, y: -1))
        sigilLinePath.addLine(to: CGPoint(x: 4.5, y: -1))
        sigilLinePath.move(to: CGPoint(x: 0, y: -5.5))
        sigilLinePath.addLine(to: CGPoint(x: 0, y: 3.5))
        let sigilLines = SKShapeNode(path: sigilLinePath)
        sigilLines.strokeColor = violet
        sigilLines.lineWidth = 0.9
        sigilLines.glowWidth = 2
        marker.addChild(sigilLines)

        marker.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 2.5, duration: 0.70),
            .moveBy(x: 0, y: -2.5, duration: 0.70)
        ])), withKey: "paper-double-float")
        return marker
    }

    /// Breaks the in-world paper person into light paper shards. The relic
    /// state has already been consumed by CombatCore; this method only
    /// presents that authoritative transition and never changes HP or flags.
    func presentChapterOnePaperDoubleBreak() {
        // In the hybrid battlefield Unity owns the paper body and its shards.
        // SpriteKit must not add a second, offset paper person on top of it.
        guard presentationOnly, !effectsOnlyOverlayEnabled else { return }
        let marker = childNode(withName: "combat-effect-paper-double")
        let burst = SKNode()
        burst.name = "combat-effect-paper-double-shards"
        burst.position = marker?.position
            ?? CGPoint(x: player.position.x, y: player.position.y + 25)
        burst.zPosition = 38
        addChild(burst)

        let flash = SKShapeNode(circleOfRadius: 16)
        flash.fillColor = UIColor(red: 0.82, green: 0.52, blue: 1.0, alpha: 0.34)
        flash.strokeColor = UIColor(red: 1.0, green: 0.83, blue: 0.52, alpha: 0.88)
        flash.lineWidth = 1.5
        flash.glowWidth = 15
        flash.blendMode = .add
        burst.addChild(flash)
        flash.run(.sequence([
            .group([
                .scale(to: 2.4, duration: 0.22),
                .fadeOut(withDuration: 0.22)
            ]),
            .removeFromParent()
        ]))

        for index in 0..<42 {
            let angle = CGFloat(index) / 42 * .pi * 2
            let width = CGFloat(2 + index % 4)
            let length = CGFloat(6 + (index * 5) % 12)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: length * 0.5))
            path.addLine(to: CGPoint(x: width, y: -length * 0.18))
            path.addLine(to: CGPoint(x: 0, y: -length * 0.5))
            path.addLine(to: CGPoint(x: -width, y: -length * 0.18))
            path.closeSubpath()
            let shard = SKShapeNode(path: path)
            shard.fillColor = index.isMultiple(of: 2)
                ? UIColor(red: 0.96, green: 0.83, blue: 0.67, alpha: 0.94)
                : UIColor(red: 0.63, green: 0.32, blue: 0.86, alpha: 0.86)
            shard.strokeColor = UIColor(red: 1.0, green: 0.88, blue: 0.66, alpha: 0.68)
            shard.lineWidth = 0.7
            shard.zRotation = angle + CGFloat(index % 3) * 0.18
            let radius = CGFloat(index % 4) * 1.8
            shard.position = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
            burst.addChild(shard)
            let drift = CGVector(
                dx: cos(angle) * CGFloat(34 + (index % 5) * 10),
                dy: 18 + sin(angle) * CGFloat(34 + (index % 4) * 8)
            )
            let duration = 0.64 + Double(index % 5) * 0.04
            shard.run(.group([
                .move(by: drift, duration: duration),
                .rotate(byAngle: index.isMultiple(of: 2) ? 2.8 : -3.4, duration: duration),
                .fadeOut(withDuration: duration),
                .scale(to: 0.28, duration: duration)
            ]))
        }
        marker?.removeFromParent()
        burst.run(.sequence([
            .wait(forDuration: 0.98),
            .removeFromParent()
        ]))
    }

    func presentChapterOneControlSealBreak(targetID: String) {
        guard presentationOnly,
              let enemy = enemies.first(where: { $0.spawn.id == targetID && $0.isAlive }),
              enemy.usesIntegratedControlSeal,
              let artwork = enemy.artworkNode,
              let aura = enemy.controlSealAuraNode else { return }

        enemy.animationKey = "hit"
        enemy.usesIntegratedControlSeal = false
        aura.removeAction(forKey: "control-seal-impact-flash")
        aura.isHidden = true
        // Breaking the seal removes only the visual barrier. The guard keeps
        // the current imported model stance after the control layer is torn
        // away; the barrier itself is a procedural combat effect.
        enemy.animationClips = enemy.shieldedAnimationClips ?? enemy.baseAnimationClips
        artwork.removeAllActions()
        artwork.run(.sequence([
            .colorize(with: .white, colorBlendFactor: 0.78, duration: 0.08),
            .colorize(withColorBlendFactor: 0, duration: 0.24),
            .run { [weak self, weak enemy, weak artwork] in
                guard let self, let enemy, let artwork else { return }
                enemy.animationKey = ""
                if let texture = enemy.animationClips.idle.first {
                    self.normalizeClockGuardArtwork(artwork, texture: texture)
                }
            }
        ]), withKey: "control-seal-hit")

        // The retired procedural oval also supplied a synthetic rupture
        // ellipse.  Keep it absent with the oval; the authored actor hit flash
        // above remains as the temporary seal-break acknowledgement.
    }

    private func setClockGuardControlSeal(
        _ isActive: Bool,
        for enemy: DungeonEnemyActor
    ) {
        guard enemy.spawn.kind == .hollowClockGuard,
              enemy.usesIntegratedControlSeal != isActive else { return }

        enemy.usesIntegratedControlSeal = isActive
        enemy.animationClips = enemy.shieldedAnimationClips ?? enemy.baseAnimationClips
        enemy.animationKey = ""
        if let aura = enemy.controlSealAuraNode {
            aura.removeAction(forKey: "control-seal-break")
            aura.removeAction(forKey: "control-seal-impact-flash")
            aura.isHidden = effectsOnlyOverlayEnabled || !isActive
            aura.setScale(1)
            aura.alpha = 1
        }
        if let artwork = enemy.artworkNode,
           let texture = enemy.animationClips.idle.first {
            artwork.removeAllActions()
            normalizeClockGuardArtwork(artwork, texture: texture)
        }
    }

    func activateRelic(_ relicID: String) {
        guard turnPhase == .player,
              relicIDs.contains(relicID),
              !usedRelicIDs.contains(relicID),
              !combat.isVictorious,
              !combat.isDefeated else { return }

        usedRelicIDs.insert(relicID)
        combat.usedRelicIDs = usedRelicIDs

        switch relicID {
        case "silver-lie-blade":
            playerReactionCharges += 1
            spawnFloatingText("纸人代身 · 代受伤害", at: player.position, color: .systemPurple)
            spawnTarotCastVFX(at: player.position, size: 196)
        case "paper-moon-token":
            gainOmen(2, reason: "纸月占卜")
            if let target = selectedOrNearestEnemy() {
                applyWillpowerDamage(24, to: target)
                spawnTarotImpactVFX(at: target.node.position, size: 190)
            }
        case "mirror-card-case":
            if let target = selectedOrNearestEnemy() {
                spawnTarotCastVFX(at: player.position, size: 230)
                applySkillDamage(28, skillID: .strike, to: target, knockback: 8)
                spawnTarotImpactVFX(at: target.node.position, size: 230)
            }
        case "backward-watch":
            for skillID in DungeonSkillID.allCases {
                skillCooldowns[skillID] = max(0, skillCooldowns[skillID, default: 0] - 1)
            }
            spawnFloatingText("倒走一刻 · 冷却-1", at: player.position, color: .systemOrange)
            spawnCastSigil(at: player.position, color: .systemOrange, radius: 62)
        default:
            break
        }

        publishState("遗落物发动", feedback: true, force: true)
    }

    func resetCombat() {
        route.removeAll()
        selectedEnemyID = nil
        pendingBasicAttack = false
        pendingSkillID = nil
        basicAttackCooldown = 0
        playerInvulnerability = 0
        playerReactionCharges = 0
        playerGuardCharges = 0
        playerParryCharges = 0
        playerCounterCharges = 0
        playerOmen = 0
        foolUltimateOmenSpent = 0
        usedRelicIDs.removeAll()
        combatHasStarted = false
        turnPhase = .player
        enemyTurnQueue.removeAll()
        turnNumber = 1
        isTransitioningWaves = false
        currentWave = 1
        removeAction(forKey: "wave-transition")
        skillCooldowns = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, 0) })
        combat = DungeonCombatSnapshot(
            playerHealth: path.id == .chariot ? 130 : 100,
            maxPlayerHealth: path.id == .chariot ? 130 : 100,
            enemiesRemaining: level.enemies.filter { $0.wave == 1 }.count,
            currentWave: 1,
            totalWaves: level.totalWaves,
            waveTitle: level.waveTitle(for: 1),
            skillCooldowns: skillCooldowns
        )
        combat.turnNumber = 1
        combat.isPlayerTurn = true
        lastPublishedCombat = nil
        destinationMarker.removeAllActions()
        destinationMarker.isHidden = true

        player.removeAllActions()
        playerVisual.removeAllActions()
        player.position = presentationAdjustedPlayerPosition(playerZone.center)
        player.alpha = 1
        playerVisual.alpha = 1
        player.setScale(presentationOnly ? 1.125 : 1)
        startIdleAnimation()
        sceneCamera.removeAllActions()
        sceneCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sceneCamera.setScale(presentationOnly ? 1.25 : 1)

        enemies.forEach {
            $0.telegraphNode?.removeFromParent()
            $0.node.removeFromParent()
        }
        enemies.removeAll()
        children.filter { $0.name == "combat-effect" }.forEach { $0.removeFromParent() }
        spawnEnemies()
        suppressPresentationHealthBars()
        publishState("我方回合 · 选择目标与行动", force: true)
    }

    private func cast(_ definition: DungeonSkillDefinition, at target: DungeonEnemyActor) {
        pendingSkillID = nil
        route.removeAll()
        facePlayer(toward: target.node.position)
        let presentationRecipe = PathSkillVFXCatalog.recipe(
            for: path.id,
            skillID: definition.id
        )
        skillCooldowns[definition.id] = turnCooldown(for: definition)
        applyPathCastTrait(for: definition)
        combat.skillCooldowns = skillCooldowns

        switch definition.behavior {
        case .projectile:
            castProjectileSkill(definition, at: target)
            finishPlayerAction(after: max(1.10, presentationRecipe.totalDuration))
        case .dashStrike:
            castDashSkill(definition, at: target)
            finishPlayerAction(after: max(0.78, presentationRecipe.totalDuration))
        case .areaBurst:
            castAreaSkill(definition, at: target)
            let baseDuration = max(1.20, presentationRecipe.totalDuration)
            finishPlayerAction(after: baseDuration + TimeInterval(enemies.filter(\.isAlive).count) * 0.05)
        }

        publishState(definition.name, feedback: true, force: true)
    }

    private func castProjectileSkill(_ definition: DungeonSkillDefinition, at target: DungeonEnemyActor) {
        if path.id == .fool {
            switch definition.id {
            case .strike:
                castFoolWeaknessJudgment(definition, at: target)
                return
            case .ward:
                castFoolDangerPremonition(definition, at: target)
                return
            case .mobility, .control, .ultimate:
                break
            }
        }

        animatePlayerSkill(.skillStrike)
        spawnCastSigil(at: player.position, color: UIColor(definition.tint), radius: 54)
        // Hold a large readable tarot silhouette near the caster before the
        // flight begins. This changes presentation only, not the hit radius.
        spawnTarotCastVFX(at: player.position, size: 354)
        spawnTargetWarning(at: target.node.position, color: UIColor(definition.tint), radius: 76, duration: 0.22)
        let castingHand = playerCastingHandPosition()
        let baseAngle = atan2(
            target.node.position.y - castingHand.y,
            target.node.position.x - castingHand.x
        )
        run(.sequence([
            .wait(forDuration: 0.36),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                for offset in [-0.13, 0, 0.13] {
                    let start = CGPoint(
                        x: castingHand.x + cos(baseAngle + offset) * 10,
                        y: castingHand.y + sin(baseAngle + offset) * 10
                    )
                    self.launchPlayerProjectile(
                        from: start,
                        toward: target,
                        color: UIColor(definition.tint),
                        size: offset == 0 ? 23 : 16,
                        duration: offset == 0 ? 0.62 : 0.68
                    )
                }
            },
            .wait(forDuration: 0.69),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                self.applySkillDamage(definition.damage, skillID: definition.id, to: target, knockback: 14)
                self.spawnImpact(at: target.node.position, color: UIColor(definition.tint), radius: 132)
                self.spawnTarotImpactVFX(at: target.node.position, size: 410)
                self.spawnResidualArcana(at: target.node.position, color: UIColor(definition.tint), count: 18)
                self.applyProjectilePathTrait(definition, primaryTarget: target)
            }
        ]))
    }

    private func presentChapterOneNonAttackIntent(
        _ intents: [String],
        enemies: [DungeonEnemyActor]
    ) {
        let defensive = intents.contains {
            ["guard", "fortify", "recover", "calibrate"].contains($0)
        }
        let resolvedIntent = intents.first {
            !$0.hasPrefix("下一意图：") && $0 != "delayed"
        } ?? (defensive ? "guard" : "charge")
        let tint: UIColor = defensive ? .systemCyan : .systemPurple

        for (index, enemy) in enemies.enumerated() where enemy.isAlive {
            let center = enemyBodyCenter(enemy)
            enemy.state = .windup
            enemy.stateTimer = 0.72
            run(.sequence([
                .wait(forDuration: Double(index) * 0.08),
                .run { [weak self, weak enemy] in
                    guard let self, let enemy, enemy.isAlive else { return }
                    if defensive, let artwork = enemy.artworkNode,
                       let defensiveTexture = enemy.defensiveTexture {
                        enemy.holdsDefensivePose = true
                        artwork.removeAllActions()
                        self.normalizeClockGuardDefensiveArtwork(artwork, texture: defensiveTexture)
                    }
                    if enemy.spawn.kind == .hollowClockGuard {
                        self.presentClockGuardSkillVFX(
                            id: self.clockGuardSkillVFXID(
                                for: enemy,
                                intent: resolvedIntent
                            ),
                            at: center
                        )
                    } else {
                        self.spawnCastSigil(at: center, color: tint, radius: defensive ? 68 : 54)
                        self.spawnResidualArcana(at: center, color: tint, count: defensive ? 18 : 24)
                    }
                    enemy.artworkNode?.run(.sequence([
                        .group([
                            .scale(to: defensive ? 1.04 : 1.07, duration: 0.34),
                            .colorize(with: tint, colorBlendFactor: 0.28, duration: 0.34)
                        ]),
                        .group([
                            .scale(to: 1, duration: 0.38),
                            .colorize(withColorBlendFactor: 0, duration: 0.38)
                        ])
                    ]))
                }
            ]))
        }

        run(.sequence([
            .wait(forDuration: 0.78),
            .run {
                enemies.forEach { enemy in
                    guard enemy.isAlive else { return }
                    enemy.state = .idle
                    if !defensive { enemy.holdsDefensivePose = false }
                    if !defensive, let artwork = enemy.artworkNode,
                       let texture = enemy.baseAnimationClips.idle.first {
                        self.normalizeClockGuardArtwork(artwork, texture: texture)
                    }
                }
            }
        ]))
    }

    private func castDashSkill(_ definition: DungeonSkillDefinition, at target: DungeonEnemyActor) {
        if path.id == .fool, definition.id == .mobility {
            castFoolSpiritualEvasion(definition, at: target)
            return
        }

        let anchor = playerZone.center
        playerReactionCharges = max(playerReactionCharges, 1)
        animatePlayerSkill(.skillMobility)
        spawnCastSigil(at: anchor, color: UIColor(definition.tint), radius: 48)
        spawnTarotCastVFX(at: anchor, size: 224)
        spawnFloatingText("错位准备", at: anchor, color: UIColor(definition.tint))
        player.run(.sequence([
            .wait(forDuration: 0.10),
            .run { [weak self] in
                guard let self else { return }
                self.launchPlayerProjectile(
                    from: anchor,
                    toward: target,
                    color: UIColor(definition.tint),
                    size: 14,
                    duration: 0.30
                )
            },
            .wait(forDuration: 0.31),
            .run { [weak self] in
                guard let self, target.isAlive else { return }
                self.applySkillDamage(definition.damage, skillID: definition.id, to: target, knockback: 28)
                self.spawnEnemySlash(at: target.node.position, color: UIColor(definition.tint), radius: 86)
                self.spawnImpact(at: target.node.position, color: UIColor(definition.tint), radius: 72)
                self.spawnTarotImpactVFX(at: target.node.position, size: 278)
                self.spawnResidualArcana(at: target.node.position, color: UIColor(definition.tint), count: 14)
            },
            .run { [weak self] in self?.startIdleAnimation() }
        ]), withKey: "skill-dash")
    }

    private func castAreaSkill(_ definition: DungeonSkillDefinition, at target: DungeonEnemyActor) {
        if path.id == .fool {
            switch definition.id {
            case .control:
                castFoolSimpleDivination(definition, at: target)
                return
            case .ultimate:
                castFoolOmenRecord(definition, at: target)
                return
            case .strike, .mobility, .ward:
                break
            }
        }

        animatePlayerSkill(.skillUltimate)
        let center = enemyBodyCenter(target)
        let displayRadius = min(size.width * 0.53, max(190, definition.radius * 1.55))
        spawnCastSigil(at: player.position, color: UIColor(definition.tint), radius: 82)
        spawnTarotCastVFX(at: player.position, size: 392)
        spawnTargetWarning(at: center, color: UIColor(definition.tint), radius: displayRadius, duration: 0.30)
        let victims = enemies.filter {
            $0.isAlive && distance(from: $0.node.position, to: center) <= definition.radius
        }
        for (index, enemy) in victims.enumerated() {
            let delay = 0.30 + TimeInterval(index) * 0.05
            run(.sequence([
                .wait(forDuration: delay),
                .run { [weak self, weak enemy] in
                    guard let self, let enemy else { return }
                    if index == 0 {
                        self.spawnAreaBurst(at: center, color: UIColor(definition.tint), radius: displayRadius)
                        self.spawnTarotImpactVFX(at: center, size: min(620, max(480, definition.radius * 3.4)))
                        self.spawnResidualArcana(at: center, color: UIColor(definition.tint), count: 24)
                    }
                    self.applySkillDamage(definition.damage, skillID: definition.id, to: enemy, knockback: 22)
                }
            ]))
        }
    }

    func showQueuedTargets(
        _ assignments: [DungeonQueuedTargetAssignment],
        pendingTargetIDs: Set<String>
    ) {
        if let latestTargetID = assignments.max(by: { $0.order < $1.order })?.targetID {
            selectedEnemyID = latestTargetID
        }
        children
            .filter { $0.name?.hasPrefix("combat-effect-queued-target-") == true }
            .forEach { $0.removeFromParent() }
        for enemy in enemies {
            enemy.node.childNode(withName: "queued-target-feedback")?.removeFromParent()
        }
    }

    /// Layered impact confirmation for CombatCore-driven attacks. The actor
    /// stays on its authored combat mark while material flash, restrained
    /// vibration, spectral separation and a small camera impulse sell contact.
    func presentChapterOneHitReaction(
        targetID: String,
        damage: Int,
        showsDamageNumber: Bool = true
    ) {
        guard damage >= 0,
              let enemy = enemies.first(where: { $0.spawn.id == targetID && $0.isAlive })
        else { return }

        flashClockGuardShieldOnPlayerImpact(for: enemy)
        let heavy = damage >= 100
        let origin = enemy.node.position
        if damage == 0, showsDamageNumber {
            presentChapterOneZeroDamage(targetID: targetID)
        } else if showsDamageNumber {
            spawnBigDamageNumber(damage, at: enemyCombatNumberAnchor(enemy))
        }
        let amplitude: CGFloat = heavy ? 5 : 3
        enemy.node.removeAction(forKey: "chapter-one-hit-shake")
        enemy.node.run(.sequence([
            .move(to: CGPoint(x: origin.x - amplitude, y: origin.y + 1), duration: 0.035),
            .move(to: CGPoint(x: origin.x + amplitude, y: origin.y - 1), duration: 0.045),
            .move(to: CGPoint(x: origin.x - amplitude * 0.45, y: origin.y), duration: 0.04),
            .move(to: origin, duration: 0.055)
        ]), withKey: "chapter-one-hit-shake")

        if let artwork = enemy.artworkNode {
            artwork.run(.sequence([
                .group([
                    .colorize(with: .white, colorBlendFactor: 0.88, duration: 0.035),
                    .fadeAlpha(to: 0.42, duration: 0.035)
                ]),
                .group([
                    .colorize(with: UIColor(red: 0.66, green: 0.30, blue: 1, alpha: 1), colorBlendFactor: 0.38, duration: 0.08),
                    .fadeAlpha(to: 0.78, duration: 0.08)
                ]),
                .group([
                    .colorize(withColorBlendFactor: 0, duration: 0.14),
                    .fadeAlpha(to: 1, duration: 0.14)
                ])
            ]), withKey: "chapter-one-hit-material")

            for (offset, tint) in [
                (CGPoint(x: -8, y: 2), UIColor.systemPurple),
                (CGPoint(x: 8, y: -1), UIColor.systemCyan)
            ] {
                let ghost = SKSpriteNode(texture: artwork.texture)
                ghost.size = artwork.size
                ghost.anchorPoint = artwork.anchorPoint
                ghost.position = artwork.position
                ghost.xScale = artwork.xScale
                ghost.yScale = artwork.yScale
                ghost.zRotation = artwork.zRotation
                ghost.zPosition = artwork.zPosition - 0.5
                ghost.alpha = 0.30
                ghost.color = tint
                ghost.colorBlendFactor = 0.62
                enemy.node.addChild(ghost)
                ghost.run(.sequence([
                    .group([
                        .move(by: CGVector(dx: offset.x, dy: offset.y), duration: 0.12),
                        .fadeAlpha(to: 0.14, duration: 0.12)
                    ]),
                    .group([
                        .move(by: CGVector(dx: -offset.x, dy: -offset.y), duration: 0.14),
                        .fadeOut(withDuration: 0.14)
                    ]),
                    .removeFromParent()
                ]))
            }
        }

        let cameraOrigin = sceneCamera.position
        let cameraAmplitude: CGFloat = heavy ? 3.5 : 2
        sceneCamera.removeAction(forKey: "chapter-one-camera-impact")
        sceneCamera.run(.sequence([
            .move(to: CGPoint(x: cameraOrigin.x + cameraAmplitude, y: cameraOrigin.y + 1), duration: 0.035),
            .move(to: CGPoint(x: cameraOrigin.x - cameraAmplitude * 0.7, y: cameraOrigin.y - 1), duration: 0.045),
            .move(to: cameraOrigin, duration: 0.07)
        ]), withKey: "chapter-one-camera-impact")

        spawnResidualArcana(
            at: CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 24),
            color: UIColor(red: 0.72, green: 0.36, blue: 1, alpha: 1),
            count: heavy ? 9 : 6
        )
    }

    /// Shows a secondary hit's number without replaying the full authored
    /// impact effect. Multi-target cards use one enemy as their visual anchor;
    /// this keeps the other authoritative damage result readable without
    /// creating a second effect that can outlive a defeated target.
    func presentChapterOneDamageNumber(targetID: String, damage: Int) {
        guard presentationOnly,
              damage >= 0,
              let enemy = enemies.first(where: { $0.spawn.id == targetID && $0.isAlive })
        else { return }

        if damage == 0 {
            presentChapterOneZeroDamage(targetID: targetID)
        } else {
            spawnBigDamageNumber(damage, at: enemyCombatNumberAnchor(enemy))
        }
    }

    /// The Unity actor and this SpriteKit overlay live in separate view trees,
    /// so a persistent shield cannot be transform-locked without drift. Show
    /// it only for the short contact beat of a player hit, while the enemy is
    /// stationary at its authored formation slot.
    private func flashClockGuardShieldOnPlayerImpact(for enemy: DungeonEnemyActor) {
        guard effectsOnlyOverlayEnabled,
              enemy.spawn.kind == .hollowClockGuard,
              enemy.usesIntegratedControlSeal,
              let aura = enemy.controlSealAuraNode else { return }

        aura.removeAction(forKey: "control-seal-impact-flash")
        aura.removeAction(forKey: "unity-guard-follow")
        aura.position = unityClockGuardAuraHomes[enemy.spawn.id] ?? aura.position
        aura.setScale(0.96)
        aura.alpha = 0
        aura.isHidden = false
        aura.run(.sequence([
            .group([
                .fadeAlpha(to: 0.94, duration: 0.055),
                .scale(to: 1.02, duration: 0.08)
            ]),
            .wait(forDuration: 0.14),
            .group([
                .fadeOut(withDuration: 0.18),
                .scale(to: 1.08, duration: 0.18)
            ]),
            .run { [weak aura] in
                aura?.isHidden = true
                aura?.alpha = 1
                aura?.setScale(1)
            }
        ]), withKey: "control-seal-impact-flash")
    }

    // MARK: - Fool skill presentation recipes

    /// The target is read and marked before a dense Fool-card storm tears
    /// through the revealed point. Basic attacks use this same presentation
    /// path in the Unity-backed chapter-one encounter.
    private func castFoolWeaknessJudgment(
        _ definition: DungeonSkillDefinition,
        at target: DungeonEnemyActor
    ) {
        animatePlayerSkill(.skillStrike)
        let tint = UIColor(definition.tint)
        let center = enemyBodyCenter(target)
        let castingHand = playerCastingHandPosition()
        spawnFoolSkillClip(.weaknessJudgment, at: center, size: 620, timePerFrame: 0.105)
        spawnTargetWarning(at: center, color: tint, radius: 88, duration: 0.28)
        spawnWeaknessScan(from: castingHand, to: center, color: tint)

        run(.sequence([
            .wait(forDuration: 0.34),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                self.launchPlayerProjectile(
                    from: self.playerCastingHandPosition(),
                    toward: target,
                    color: tint,
                    size: 18,
                    duration: 0.46
                )
            },
            .wait(forDuration: 0.48),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                self.applySkillDamage(definition.damage, skillID: definition.id, to: target, knockback: 10)
                let center = self.enemyBodyCenter(target)
                self.spawnLayeredFoolTarotImpact(
                    at: center,
                    requestedSize: 820,
                    maximumLayers: 8
                )
                self.spawnImpact(at: center, color: tint, radius: 82)
                self.spawnWeakpointResidue(at: center, color: tint)
                self.applyProjectilePathTrait(definition, primaryTarget: target)
            }
        ]))
    }

    /// Intensity 2.5/5: the body stays grounded while authored phase shards and
    /// unscaled texture echoes communicate a false position and counter-hit.
    private func castFoolSpiritualEvasion(
        _ definition: DungeonSkillDefinition,
        at target: DungeonEnemyActor
    ) {
        let anchor = player.position
        let tint = UIColor(red: 0.18, green: 0.84, blue: 1, alpha: 1)
        playerReactionCharges = max(playerReactionCharges, 1)
        animatePlayerSkill(.skillMobility)
        spawnFoolSkillClip(.spiritualEvasion, at: anchor, size: 480, timePerFrame: 0.085)
        spawnSpiritualAfterimages(at: anchor, color: tint)
        spawnFloatingText("灵性错位", at: anchor, color: tint)

        run(.sequence([
            .wait(forDuration: 0.38),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                let impactCenter = self.enemyBodyCenter(target)
                self.spawnFoolSkillClip(
                    .spiritualEvasion,
                    at: impactCenter,
                    size: 300,
                    timePerFrame: 0.062,
                    rotation: .pi
                )
                self.applySkillDamage(definition.damage, skillID: definition.id, to: target, knockback: 18)
                self.spawnEnemySlash(at: impactCenter, color: tint, radius: 96)
                self.spawnResidualArcana(at: impactCenter, color: tint, count: 10)
            },
            .wait(forDuration: 0.30),
            .run { [weak self] in self?.startIdleAnimation() }
        ]))
    }

    /// Intensity 3/5: a calm gold card fan becomes a divination field. Its
    /// silhouette and pacing are intentionally circular rather than explosive.
    private func castFoolSimpleDivination(
        _ definition: DungeonSkillDefinition,
        at target: DungeonEnemyActor
    ) {
        animatePlayerSkill(.skillUltimate)
        let center = enemyBodyCenter(target)
        let tint = UIColor(red: 0.98, green: 0.76, blue: 0.18, alpha: 1)
        let displayRadius = min(size.width * 0.47, max(170, definition.radius * 1.48))
        spawnFoolSkillClip(.simpleDivination, at: player.position, size: 470, timePerFrame: 0.11)
        spawnTargetWarning(at: center, color: tint, radius: displayRadius, duration: 0.38)

        let victims = enemies.filter {
            $0.isAlive && distance(from: $0.node.position, to: center) <= definition.radius
        }
        run(.sequence([
            .wait(forDuration: 0.42),
            .run { [weak self] in
                guard let self else { return }
                self.spawnFoolSkillClip(.simpleDivination, at: center, size: 590, timePerFrame: 0.09)
                self.spawnAreaBurst(at: center, color: tint, radius: displayRadius)
                self.spawnDivinationConstellation(at: center, radius: displayRadius, color: tint)
                for enemy in victims where enemy.isAlive {
                    self.applySkillDamage(definition.damage, skillID: definition.id, to: enemy, knockback: 8)
                }
            }
        ]))
    }

    /// Intensity 4/5: the danger eye closes over the enemy, converging card
    /// streaks detonate, and a smoky omen remains. It is violent but not a
    /// full-screen finisher, preserving room for the ultimate to escalate.
    private func castFoolDangerPremonition(
        _ definition: DungeonSkillDefinition,
        at target: DungeonEnemyActor
    ) {
        animatePlayerSkill(.skillStrike)
        let tint = UIColor(red: 0.90, green: 0.12, blue: 0.54, alpha: 1)
        let center = enemyBodyCenter(target)
        spawnFoolSkillClip(.dangerPremonition, at: center, size: 510, timePerFrame: 0.105)
        spawnDangerVeil(at: center)
        spawnTargetWarning(at: center, color: tint, radius: 126, duration: 0.34)

        run(.sequence([
            .wait(forDuration: 0.38),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                let starts = [
                    CGPoint(x: self.size.width * 0.14, y: center.y + 112),
                    CGPoint(x: self.size.width * 0.86, y: center.y + 112)
                ]
                for start in starts {
                    self.launchPlayerProjectile(
                        from: start,
                        toward: target,
                        color: tint,
                        size: 20,
                        duration: 0.46
                    )
                }
            },
            .wait(forDuration: 0.48),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                self.applySkillDamage(definition.damage, skillID: definition.id, to: target, knockback: 16)
                self.spawnFoolSkillClip(.dangerPremonition, at: center, size: 640, timePerFrame: 0.07)
                self.spawnAreaBurst(at: center, color: tint, radius: 152)
                self.spawnResidualArcana(at: center, color: tint, count: 20)
                self.applyProjectilePathTrait(definition, primaryTarget: target)
            }
        ]))
    }

    /// Intensity 5/5: only the ultimate owns the complete card reveal → flight
    /// → crossing battlefield arcs → white-gold detonation → long residue chain.
    private func castFoolOmenRecord(
        _ definition: DungeonSkillDefinition,
        at target: DungeonEnemyActor
    ) {
        animatePlayerSkill(.skillUltimate)
        let center = enemyBodyCenter(target)
        let tint = UIColor(definition.tint)
        let displayRadius = min(size.width * 0.58, max(220, definition.radius * 1.70))
        spawnTarotCastVFX(at: player.position, size: 460)
        spawnTargetWarning(at: center, color: tint, radius: displayRadius, duration: 0.48)

        let victims = enemies.filter {
            $0.isAlive && distance(from: $0.node.position, to: center) <= definition.radius
        }
        run(.sequence([
            .wait(forDuration: 0.46),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                let castingHand = self.playerCastingHandPosition()
                for offset in [-0.18, 0, 0.18] {
                    let start = CGPoint(x: castingHand.x + offset * 92, y: castingHand.y)
                    self.launchPlayerProjectile(
                        from: start,
                        toward: target,
                        color: tint,
                        size: offset == 0 ? 24 : 20,
                        duration: 0.48
                    )
                }
            },
            .wait(forDuration: 0.50),
            .run { [weak self] in
                guard let self else { return }
                self.spawnGrandArcanaSweep(at: center, color: tint, intensity: 1)
                self.spawnTarotImpactVFX(at: center, size: 940)
                self.spawnImpact(at: center, color: tint, radius: 172)
                self.spawnResidualArcana(at: center, color: tint, count: 30)
                for enemy in victims where enemy.isAlive {
                    self.applySkillDamage(definition.damage, skillID: definition.id, to: enemy, knockback: 22)
                }
            }
        ]))
    }

    private func applyPathCastTrait(for definition: DungeonSkillDefinition) {
        if definition.id == .ward {
            playerGuardCharges = max(playerGuardCharges, 1)
            spawnFloatingText("防护就绪", at: player.position, color: UIColor(definition.tint))
            spawnCastSigil(at: player.position, color: UIColor(definition.tint), radius: 44)
        }
        switch path.id {
        case .fool:
            switch definition.id {
            case .control:
                gainOmen(2, reason: "占卜成立")
            case .ward:
                playerReactionCharges = max(playerReactionCharges, 1)
                gainOmen(1, reason: "危险已记录")
            case .ultimate:
                foolUltimateOmenSpent = playerOmen
                playerOmen = 0
                spawnFloatingText(
                    foolUltimateOmenSpent > 0 ? "兑现预兆 ×\(foolUltimateOmenSpent)" : "记录空白",
                    at: player.position,
                    color: .systemPurple
                )
            case .strike, .mobility:
                break
            }
        case .magician:
            // In a fixed-position turn system the Magician survives by
            // rewriting the next hostile spell, not by physically dodging it.
            playerCounterCharges = max(playerCounterCharges, 1)
            spawnFloatingText("术式反写", at: player.position, color: .systemPurple)
        case .justice:
            if definition.id == .mobility {
                playerParryCharges = 1
                spawnFloatingText("衡盾架势", at: player.position, color: .systemYellow)
            }
        case .priestess:
            let healing: Int
            switch definition.id {
            case .strike: healing = 4
            case .mobility: healing = 7
            case .control: healing = 6
            case .ward: healing = 9
            case .ultimate: healing = 12
            }
            let restored = min(healing, combat.maxPlayerHealth - combat.playerHealth)
            guard restored > 0 else { return }
            combat.playerHealth += restored
            spawnFloatingText("+\(restored)", at: player.position, color: .systemGreen)
            spawnResidualArcana(at: player.position, color: .systemCyan, count: 5)
        case .chariot:
            playerGuardCharges = max(playerGuardCharges, definition.id == .ultimate ? 2 : 1)
            spawnFloatingText("意志护盾", at: player.position, color: .systemCyan)
            spawnCastSigil(at: player.position, color: UIColor(path.tint), radius: 48)
        case .star:
            for skillID in DungeonSkillID.allCases where skillID != definition.id {
                skillCooldowns[skillID] = max(0, skillCooldowns[skillID, default: 0] - 0.8)
            }
            spawnFloatingText("星轨回响", at: player.position, color: .systemCyan)
            if definition.id == .ultimate {
                let restored = min(10, combat.maxPlayerHealth - combat.playerHealth)
                combat.playerHealth += restored
                if restored > 0 {
                    spawnFloatingText("+\(restored)", at: player.position, color: .systemGreen)
                }
            }
        }
    }

    private func applyProjectilePathTrait(
        _ definition: DungeonSkillDefinition,
        primaryTarget: DungeonEnemyActor
    ) {
        let candidates = enemies
            .filter { $0.isAlive && $0 !== primaryTarget }
            .sorted {
                distance(from: $0.node.position, to: primaryTarget.node.position)
                    < distance(from: $1.node.position, to: primaryTarget.node.position)
            }

        switch path.id {
        case .fool:
            for (index, enemy) in candidates.prefix(2).enumerated() {
                chainProjectile(
                    from: primaryTarget.node.position,
                    to: enemy,
                    damage: max(1, Int(CGFloat(definition.damage) * 0.52)),
                    delay: TimeInterval(index) * 0.09,
                    color: UIColor(definition.tint)
                )
            }
        case .magician:
            let splashTargets = candidates.filter {
                distance(from: $0.node.position, to: primaryTarget.node.position) <= 82
            }
            guard !splashTargets.isEmpty else { return }
            spawnAreaBurst(at: primaryTarget.node.position, color: UIColor(definition.tint), radius: 82)
            for enemy in splashTargets {
                applySkillDamage(
                    max(1, Int(CGFloat(definition.damage) * 0.46)),
                    skillID: definition.id,
                    to: enemy,
                    knockback: 8
                )
            }
        case .star:
            guard let enemy = candidates.first else { return }
            chainProjectile(
                from: primaryTarget.node.position,
                to: enemy,
                damage: max(1, Int(CGFloat(definition.damage) * 0.68)),
                delay: 0,
                color: .systemCyan
            )
        case .priestess, .chariot, .justice:
            break
        }
    }

    private func chainProjectile(
        from origin: CGPoint,
        to target: DungeonEnemyActor,
        damage: Int,
        delay: TimeInterval,
        color: UIColor
    ) {
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                self.launchPlayerProjectile(from: origin, toward: target, color: color, size: 9, duration: 0.26)
            },
            .wait(forDuration: 0.27),
            .run { [weak self, weak target] in
                guard let self, let target, target.isAlive else { return }
                self.applySkillDamage(damage, skillID: .strike, to: target, knockback: 6)
                self.spawnImpact(at: target.node.position, color: color, radius: 30)
                self.spawnResidualArcana(at: target.node.position, color: color, count: 4)
            }
        ]))
    }

    private func applySkillDamage(
        _ baseDamage: Int,
        skillID: DungeonSkillID,
        to enemy: DungeonEnemyActor,
        knockback: CGFloat
    ) {
        var damage = baseDamage
        if path.id == .fool, skillID == .ultimate, foolUltimateOmenSpent > 0 {
            damage += foolUltimateOmenSpent * 11
        }
        if path.id == .magician, enemy.spawn.rank != .normal {
            damage = Int(CGFloat(damage) * 1.18)
            spawnFloatingText("结构解离", at: enemy.node.position, color: .systemMint)
        }
        if path.id == .justice,
           CGFloat(enemy.health) / CGFloat(enemy.spawn.maxHealth) <= 0.35 {
            damage = Int(CGFloat(baseDamage) * 1.45)
            spawnFloatingText("裁决", at: enemy.node.position, color: .systemYellow)
        }
        applyDamage(damage, to: enemy, knockback: knockback)
        let willpowerDamage: Int
        switch skillID {
        case .strike: willpowerDamage = 14
        case .mobility: willpowerDamage = 24
        case .control: willpowerDamage = 32
        case .ward: willpowerDamage = 18
        case .ultimate: willpowerDamage = 34
        }
        applyWillpowerDamage(willpowerDamage, to: enemy)
    }

    private func applyWillpowerDamage(_ amount: Int, to enemy: DungeonEnemyActor) {
        if presentationOnly { return }
        guard enemy.isAlive, enemy.staggeredTurns == 0 else { return }
        enemy.willpower = max(0, enemy.willpower - amount)
        let fraction = CGFloat(enemy.willpower) / CGFloat(enemy.maxWillpower)
        enemy.willpowerFill.run(.scaleX(to: fraction, duration: 0.16))
        guard enemy.willpower == 0 else { return }

        enemy.staggeredTurns = 1
        let breakMessage: String
        switch enemy.spawn.rank {
        case .normal:
            breakMessage = "失衡 · 跳过行动"
        case .elite:
            enemy.exposedTurns = max(enemy.exposedTurns, 3)
            breakMessage = "破绽暴露 · 2回合"
        case .boss:
            enemy.exposedTurns = max(enemy.exposedTurns, 2)
            if enemy.isEnraged {
                enemy.isEnraged = false
                enemy.visualNode.removeAction(forKey: "enraged")
            }
            breakMessage = "强攻延后 · 强化失效"
        }
        spawnFloatingText(breakMessage, at: enemy.node.position, color: .systemCyan)
        spawnResidualArcana(at: enemy.node.position, color: .systemCyan, count: 5)
        refreshEnemyIntent(enemy)
        publishState(breakMessage, feedback: true, force: true)
    }

    private func gainOmen(_ amount: Int, reason: String) {
        guard path.id == .fool, amount > 0 else { return }
        let previous = playerOmen
        playerOmen = min(6, playerOmen + amount)
        let gained = playerOmen - previous
        guard gained > 0 else { return }
        spawnFloatingText("预兆 +\(gained)", at: player.position, color: .systemPurple)
        publishState("\(reason) · 预兆 \(playerOmen)/6", feedback: true, force: true)
    }

    private func buildCamera() {
        sceneCamera.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sceneCamera.setScale(presentationOnly ? 1.25 : 1)
        camera = sceneCamera
        addChild(sceneCamera)
    }

    private func buildBackground() {
        let texture = SKTexture(imageNamed: level.artName)
        texture.filteringMode = .linear
        let background = SKSpriteNode(texture: texture)
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.zPosition = -20
        let textureSize = texture.size()
        let scale = max(size.width / textureSize.width, size.height / textureSize.height)
        let cameraCoverage: CGFloat = presentationOnly ? 1.30 : 1
        background.size = CGSize(
            width: textureSize.width * scale * cameraCoverage,
            height: textureSize.height * scale * cameraCoverage
        )
        addChild(background)

        // Presentation mode zooms the camera out, so the single background
        // and its shade both cover the larger camera footprint.
        let shadeSize = presentationOnly
            ? CGSize(width: size.width * 1.30, height: size.height * 1.30)
            : size
        let shade = SKShapeNode(rectOf: shadeSize)
        shade.position = CGPoint(x: size.width / 2, y: size.height / 2)
        shade.fillColor = UIColor.black.withAlphaComponent(0.12)
        shade.strokeColor = .clear
        shade.zPosition = -19
        addChild(shade)
    }

    private func buildPlayer() {
        player.name = "player"
        // Fixed formation anchor for turn-based combat.
        player.position = presentationAdjustedPlayerPosition(playerZone.center)
        player.setScale(presentationOnly ? 1.125 : 1)
        player.zPosition = 10

        let shadow = SKShapeNode(ellipseOf: CGSize(width: 38, height: 9))
        shadow.fillColor = UIColor.black.withAlphaComponent(0.30)
        shadow.strokeColor = .clear
        shadow.position.y = -28
        shadow.zPosition = -4
        player.addChild(shadow)

        let contactShadow = SKShapeNode(ellipseOf: CGSize(width: 22, height: 5))
        contactShadow.fillColor = UIColor.black.withAlphaComponent(0.60)
        contactShadow.strokeColor = .clear
        contactShadow.position.y = -28
        contactShadow.zPosition = -3
        player.addChild(contactShadow)

        if path.id == .fool {
            buildFoolCombatArtwork()
        } else {
            buildFallbackPlayerArtwork()
        }

        if presentationOnly {
            buildPlayerHealthHUD()
        }

        startIdleAnimation()
        player.addChild(playerVisual)
        addChild(player)
    }

    private func buildPlayerHealthHUD() {
        // Keep player and enemy health bars on one shared mid-width scale.
        let barWidth: CGFloat = 82
        let artworkTop = playerArtwork.map { $0.position.y + $0.size.height } ?? 42
        let healthBarY = artworkTop + 10

        playerHealthBackground.name = "presentation-player-health-background"
        playerHealthBackground.path = CGPath(
            roundedRect: CGRect(x: -barWidth / 2, y: -3.5, width: barWidth, height: 7),
            cornerWidth: 3,
            cornerHeight: 3,
            transform: nil
        )
        playerHealthBackground.position = CGPoint(x: 0, y: healthBarY)
        playerHealthBackground.fillColor = UIColor.black.withAlphaComponent(0.82)
        playerHealthBackground.strokeColor = UIColor.white.withAlphaComponent(0.46)
        playerHealthBackground.lineWidth = 1
        playerHealthBackground.zPosition = 40
        player.addChild(playerHealthBackground)

        playerHealthFill.name = "presentation-player-health-fill"
        playerHealthFill.path = CGPath(
            roundedRect: CGRect(x: 0, y: -3, width: barWidth - 4, height: 6),
            cornerWidth: 3,
            cornerHeight: 3,
            transform: nil
        )
        playerHealthFill.position = CGPoint(x: -(barWidth - 4) / 2, y: healthBarY)
        playerHealthFill.fillColor = UIColor(red: 1.0, green: 0.06, blue: 0.10, alpha: 1)
        playerHealthFill.strokeColor = .clear
        playerHealthFill.zPosition = 41
        playerHealthFill.xScale = 1
        player.addChild(playerHealthFill)

        playerHealthLabel.name = "presentation-player-health-label"
        playerHealthLabel.text = "\(combat.playerHealth)/\(combat.maxPlayerHealth)"
        playerHealthLabel.fontSize = 13
        playerHealthLabel.fontColor = UIColor(white: 0.04, alpha: 0.84)
        playerHealthLabel.horizontalAlignmentMode = .center
        playerHealthLabel.verticalAlignmentMode = .bottom
        playerHealthLabel.position = CGPoint(x: 0, y: healthBarY + 7)
        playerHealthLabel.zPosition = 41
        player.addChild(playerHealthLabel)
    }

    private func suppressPresentationHealthBars() {
        guard presentationOnly else { return }

        playerHealthBackground.isHidden = true
        playerHealthFill.isHidden = true
        playerHealthLabel.isHidden = true

        for enemy in enemies {
            enemy.node.childNode(withName: "presentation-enemy-health-background")?.isHidden = true
            enemy.healthFill.isHidden = true
            enemy.node.childNode(withName: "presentation-enemy-willpower-background")?.isHidden = true
            enemy.willpowerFill.isHidden = true
        }
    }

    private func buildFoolCombatArtwork() {
        let texture = normalizedTextures(imageNames: ["FoolCombatTopDownV3"]).first
            ?? SKTexture(imageNamed: "FoolCombatTopDownV3")
        let sprite = SKSpriteNode(texture: texture)
        sprite.name = "player-artwork"
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.position = CGPoint(x: 0, y: -28)
        sprite.size = fittedPlayerArtworkSize(for: texture)
        playerArtwork = sprite
        playerVisual.addChild(sprite)
        playPlayerMotion(.idle, restart: true)
    }

    private func buildFallbackPlayerArtwork() {
        addLeg(x: -6, rotation: -0.08)
        addLeg(x: 6, rotation: 0.08)

        let coatPath = CGMutablePath()
        coatPath.move(to: CGPoint(x: -11, y: 14))
        coatPath.addLine(to: CGPoint(x: 12, y: 14))
        coatPath.addLine(to: CGPoint(x: 17, y: -21))
        coatPath.addLine(to: CGPoint(x: 4, y: -15))
        coatPath.addLine(to: CGPoint(x: 0, y: -24))
        coatPath.addLine(to: CGPoint(x: -5, y: -15))
        coatPath.addLine(to: CGPoint(x: -17, y: -21))
        coatPath.closeSubpath()
        let coat = SKShapeNode(path: coatPath)
        coat.fillColor = UIColor(red: 0.09, green: 0.06, blue: 0.14, alpha: 0.98)
        coat.strokeColor = UIColor(path.tint).withAlphaComponent(0.90)
        coat.lineWidth = 1.5
        playerVisual.addChild(coat)

        let collar = SKShapeNode(rectOf: CGSize(width: 22, height: 6), cornerRadius: 2)
        collar.position.y = 11
        collar.fillColor = UIColor(path.tint).withAlphaComponent(0.62)
        collar.strokeColor = .clear
        playerVisual.addChild(collar)

        let head = SKShapeNode(circleOfRadius: 8)
        head.position.y = 24
        head.fillColor = UIColor(red: 0.68, green: 0.56, blue: 0.50, alpha: 1)
        head.strokeColor = .white.withAlphaComponent(0.72)
        head.lineWidth = 1
        playerVisual.addChild(head)

        let hair = SKShapeNode(ellipseOf: CGSize(width: 17, height: 9))
        hair.position.y = 28
        hair.fillColor = UIColor(red: 0.04, green: 0.03, blue: 0.06, alpha: 1)
        hair.strokeColor = .clear
        playerVisual.addChild(hair)

        let arcana = SKLabelNode(text: path.arcana)
        arcana.fontName = "AvenirNext-Bold"
        arcana.fontSize = 9
        arcana.fontColor = UIColor(path.tint)
        arcana.verticalAlignmentMode = .center
        arcana.position.y = 1
        playerVisual.addChild(arcana)

    }

    private func addLeg(x: CGFloat, rotation: CGFloat) {
        let leg = SKShapeNode(rectOf: CGSize(width: 7, height: 20), cornerRadius: 3)
        leg.position = CGPoint(x: x, y: -21)
        leg.zRotation = rotation
        leg.fillColor = UIColor(red: 0.06, green: 0.05, blue: 0.09, alpha: 1)
        leg.strokeColor = .clear
        playerVisual.addChild(leg)
    }

    private func buildDestinationMarker() {
        destinationMarker.isHidden = true
        addChild(destinationMarker)
    }

    private func spawnEnemies() {
        spawnWave(currentWave)
    }

    private func spawnWave(_ wave: Int) {
        let spawns = level.enemies.filter { $0.wave == wave }
        guard !spawns.isEmpty else { return }
        currentWave = wave
        combat.currentWave = wave
        combat.totalWaves = level.totalWaves
        combat.waveTitle = level.waveTitle(for: wave)
        combat.enemiesRemaining = spawns.count
        for spawn in spawns {
            let actor = makeEnemy(from: spawn)
            #if DEBUG
            if isAutomatedCombatPreview {
                actor.attackCooldown = 999
            }
            #endif
            enemies.append(actor)
            addChild(actor.node)
            actor.node.alpha = 0
            actor.node.setScale(0.78)
            actor.node.run(.group([
                .fadeIn(withDuration: 0.26),
                .scale(to: 1, duration: 0.26)
            ]))
        }
        suppressPresentationHealthBars()

        #if DEBUG
        if isWaveProgressionPreview {
            // Deterministic QA path: let the arrival animation settle, then clear
            // only the current wave. Production combat never enters this branch.
            run(.sequence([
                .wait(forDuration: 3.0),
                .run { [weak self] in
                    guard let self,
                          self.currentWave == wave,
                          !self.combat.isDefeated,
                          !self.combat.isVictorious else { return }
                    if self.holdsFinalWaveForPreview, wave == self.level.totalWaves {
                        return
                    }
                    let currentActors = self.enemies.filter {
                        $0.isAlive && $0.spawn.wave == wave
                    }
                    currentActors.forEach {
                        self.applyDamage($0.spawn.maxHealth + 1, to: $0, knockback: 0)
                    }
                }
            ]), withKey: "wave-progression-qa-\(wave)")
        }
        #endif
    }

    private func makeEnemy(from spawn: DungeonEnemySpawn) -> DungeonEnemyActor {
        let root = SKNode()
        root.name = "enemy:\(spawn.id)"
        let enemyInset: CGFloat = spawn.rank == .boss ? 66 : 52
        let waveEnemyCount = level.enemies.filter { $0.wave == spawn.wave }.count
        let isQ2ParasiteNode = presentationOnly
            && spawn.id.hasPrefix("enemy_memory_leech_node#")
            && level.id.contains("chapter01_q02_encounter")
        let usesFullClockGuardLayout = spawn.kind == .hollowClockGuard
            && presentationOnly
            && waveEnemyCount == 1
        let homePosition: CGPoint
        if usesFullClockGuardLayout {
            homePosition = enemyZone.center
        } else if isQ2ParasiteNode {
            homePosition = spawn.position
        } else {
            homePosition = constrained(spawn.position, to: enemyZone, inset: enemyInset)
        }
        root.position = homePosition
        root.zPosition = isQ2ParasiteNode ? 8 : 9

        let selectionSize: CGSize
        if spawn.kind == .gearHound || spawn.kind == .prototypeHound || spawn.kind == .saltCrystalGnawer {
            selectionSize = spawn.kind == .prototypeHound
                ? CGSize(width: 108, height: 36)
                : CGSize(width: 88, height: 30)
        } else if spawn.kind == .saltWraith {
            selectionSize = CGSize(width: 68, height: 26)
        } else if spawn.kind == .mirrorShade {
            selectionSize = CGSize(width: 104, height: 40)
        } else if [.crackedMirrorMarionette, .rustTideHookRaider, .oathScribe,
                   .saltCrystalDeacon, .stageAfterimage, .drownedMemoryGhost,
                   .facelessAttendant].contains(spawn.kind) {
            selectionSize = CGSize(width: 78, height: 30)
        } else {
            selectionSize = spawn.rank == .boss ? CGSize(width: 82, height: 34) : CGSize(width: 60, height: 25)
        }
        let groundOffsetY: CGFloat
        if spawn.kind == .gearHound || spawn.kind == .prototypeHound || spawn.kind == .saltCrystalGnawer {
            groundOffsetY = -27
        } else if spawn.kind == .saltWraith {
            groundOffsetY = -30
        } else if spawn.kind == .mirrorShade {
            groundOffsetY = -38
        } else if [.crackedMirrorMarionette, .rustTideHookRaider, .oathScribe,
                   .saltCrystalDeacon, .stageAfterimage, .drownedMemoryGhost,
                   .facelessAttendant].contains(spawn.kind) {
            groundOffsetY = -34
        } else {
            groundOffsetY = spawn.rank == .boss ? -29 : -21
        }

        let groundShadow = SKShapeNode(ellipseOf: CGSize(
            width: selectionSize.width * 0.72,
            height: max(8, selectionSize.height * 0.38)
        ))
        groundShadow.position.y = groundOffsetY
        groundShadow.fillColor = UIColor.black.withAlphaComponent(0.38)
        groundShadow.strokeColor = .clear
        groundShadow.zPosition = -4
        root.addChild(groundShadow)

        let contactShadow = SKShapeNode(ellipseOf: CGSize(
            width: selectionSize.width * 0.42,
            height: max(5, selectionSize.height * 0.20)
        ))
        contactShadow.position.y = groundOffsetY
        contactShadow.fillColor = UIColor.black.withAlphaComponent(0.64)
        contactShadow.strokeColor = .clear
        contactShadow.zPosition = -2
        root.addChild(contactShadow)

        let visual = SKNode()
        visual.name = root.name
        visual.zPosition = 1
        let bodyColor = enemyColor(for: spawn.kind)
        var artworkNode: SKSpriteNode?
        let defensiveTexture: SKTexture? = nil
        var controlSealAuraNode: SKNode?
        var animationClips = DungeonEnemyAnimationClips(idle: [], attack: [], hit: [], death: [])
        var baseAnimationClips: DungeonEnemyAnimationClips?
        var shieldedAnimationClips: DungeonEnemyAnimationClips?
        var startsWithIntegratedControlSeal = false
        if let artName = spawn.artworkOverride {
            let texture = trimmedTexture(imageNamed: artName)
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 150, height: 180))
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(idle: [texture], attack: [texture], hit: [texture], death: [texture])
        } else if spawn.kind == .gearHound || spawn.kind == .prototypeHound {
            // Fixed formation places enemies above the hero, so grounded foes
            // use an authored south-facing clip instead of mirroring side art.
            let idle: [SKTexture]
            let southAttack: [SKTexture]
            let death: [SKTexture]
            if spawn.kind == .gearHound {
                // A pre-rendered four-frame loop keeps the paws anchored while
                // the shoulders breathe and the tail flame rolls naturally.
                idle = (1...4).map { SKTexture(imageNamed: String(format: "PursuitHoundIdle%02d", $0)) }
                southAttack = (1...6).map { SKTexture(imageNamed: String(format: "PursuitHoundAttack%02d", $0)) }
                death = (1...6).map { SKTexture(imageNamed: String(format: "PursuitHoundDeath%02d", $0)) }
            } else {
                let southIdleNames = (1...4).map { String(format: "ClockHoundSouthIdleV4%02d", $0) }
                let southIdle = normalizedTextures(imageNames: southIdleNames)
                let legacyIdleNames = (1...6).map { String(format: "ClockHoundLostSecondIdleV3%02d", $0) }
                let legacyIdle = normalizedTextures(imageNames: legacyIdleNames)
                idle = southIdle.count == southIdleNames.count
                    ? southIdle
                    : (legacyIdle.count == legacyIdleNames.count
                        ? legacyIdle
                    : [trimmedTexture(imageNamed: "ClockHoundLostSecondIdle01")]
                    )
                let southAttackNames = (1...6).map { String(format: "ClockHoundSouthAttackV5%02d", $0) }
                let authoredAttack = normalizedTextures(imageNames: southAttackNames)
                southAttack = authoredAttack.count == southAttackNames.count ? authoredAttack : [idle[0]]
                death = productionEnemyClip(prefix: "ClockHoundLostSecondDeathV3", frameCount: 8, fallback: [idle[0]])
            }
            let texture = idle[0]
            animationClips = DungeonEnemyAnimationClips(
                idle: idle,
                attack: southAttack,
                hit: [texture],
                death: death
            )
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            let houndBounds = spawn.kind == .prototypeHound
                ? CGSize(width: 154, height: 126)
                : CGSize(width: 210, height: 174)
            artwork.size = fittedArtworkSize(for: texture, within: houndBounds)
            if spawn.kind == .prototypeHound {
                artwork.color = UIColor(red: 0.18, green: 0.78, blue: 0.72, alpha: 1)
                artwork.colorBlendFactor = 0.20
            }

            if spawn.kind == .gearHound && level.id.contains("chapter01_q05") {
                // A layered hellfire mantle sits behind the transparent
                // artwork, so the dog reads as fully aflame rather than as a
                // single yellow tail spark.
                let hellfireMantle = SKNode()
                hellfireMantle.zPosition = -1
                let flamePath = hellfireTonguePath()

                let flameAnchors: [(CGPoint, CGFloat)] = [
                    (CGPoint(x: -48, y: 0), 0.75), (CGPoint(x: -50, y: 20), 0.86),
                    (CGPoint(x: -36, y: 43), 0.96), (CGPoint(x: -15, y: 56), 0.90),
                    (CGPoint(x: 10, y: 58), 0.82), (CGPoint(x: 31, y: 49), 0.92),
                    (CGPoint(x: 47, y: 37), 1.12), (CGPoint(x: 49, y: 16), 1.05),
                    (CGPoint(x: 34, y: 2), 0.80), (CGPoint(x: -12, y: 3), 0.72)
                ]
                for (index, anchor) in flameAnchors.enumerated() {
                    let flame = SKShapeNode(path: flamePath)
                    flame.position = anchor.0
                    flame.zRotation = CGFloat(index % 3 - 1) * 0.16
                    flame.setScale(anchor.1)
                    flame.fillColor = (index.isMultiple(of: 3) ? UIColor.systemRed : UIColor.systemOrange)
                        .withAlphaComponent(index.isMultiple(of: 3) ? 0.44 : 0.58)
                    flame.strokeColor = UIColor.systemOrange.withAlphaComponent(0.62)
                    flame.lineWidth = 0.7
                    flame.glowWidth = 8
                    flame.blendMode = .add
                    let pulseUp = anchor.1 * (index.isMultiple(of: 2) ? 1.12 : 1.08)
                    let delay = TimeInterval(index) * 0.15
                    flame.run(.repeatForever(.sequence([
                        .wait(forDuration: delay),
                        .group([
                            .scale(to: pulseUp, duration: 0.90),
                            .fadeAlpha(to: 0.82, duration: 0.90),
                            .moveBy(x: 0, y: 1.5, duration: 0.90)
                        ]),
                        .group([
                            .scale(to: anchor.1 * 0.90, duration: 1.05),
                            .fadeAlpha(to: 0.48, duration: 1.05),
                            .moveBy(x: 0, y: -1.5, duration: 1.05)
                        ])
                    ])))
                    hellfireMantle.addChild(flame)
                }
                visual.addChild(hellfireMantle)
            }

            visual.addChild(artwork)
            artworkNode = artwork

            let furnaceGlow = SKShapeNode(circleOfRadius: 8)
            furnaceGlow.position = CGPoint(x: 5, y: 24)
            let furnaceColor: UIColor = spawn.kind == .prototypeHound ? .systemTeal : .systemRed
            furnaceGlow.fillColor = furnaceColor.withAlphaComponent(spawn.kind == .gearHound ? 0.34 : 0.18)
            furnaceGlow.strokeColor = furnaceColor
            furnaceGlow.lineWidth = 1
            furnaceGlow.glowWidth = spawn.kind == .gearHound ? 12 : 7
            furnaceGlow.blendMode = .add
            furnaceGlow.run(.repeatForever(.sequence([
                .scale(to: spawn.kind == .gearHound ? 1.24 : 1.22, duration: 0.90),
                .scale(to: spawn.kind == .gearHound ? 0.84 : 0.82, duration: 0.90)
            ])))
            visual.addChild(furnaceGlow)

            if spawn.kind == .gearHound {
                // The infernal hound has only one authored bitmap idle. Give
                // it an alive, supernatural idle without deforming the art:
                // a slow material flicker plus tail embers and a body breath.
                artwork.run(.repeatForever(.sequence([
                    .colorize(with: .systemRed, colorBlendFactor: 0.10, duration: 0.34),
                    .colorize(with: .systemOrange, colorBlendFactor: 0.16, duration: 0.22),
                    .colorize(withColorBlendFactor: 0.02, duration: 0.52)
                ])), withKey: "infernal-idle-flicker")

                for index in 0..<4 {
                    let ember = SKShapeNode(circleOfRadius: 2.4)
                    ember.position = CGPoint(x: 29 + CGFloat(index) * 5, y: 30 + CGFloat(index % 2) * 8)
                    ember.fillColor = UIColor.systemOrange.withAlphaComponent(0.9)
                    ember.strokeColor = .clear
                    ember.glowWidth = 6
                    ember.blendMode = .add
                    ember.alpha = 0
                    let delay = TimeInterval(index) * 0.18
                    ember.run(.repeatForever(.sequence([
                        .wait(forDuration: delay),
                        .group([.moveBy(x: 1 + CGFloat(index) * 0.5, y: 9, duration: 1.15), .fadeIn(withDuration: 0.24)]),
                        .fadeOut(withDuration: 0.68),
                        .moveBy(x: -(1 + CGFloat(index) * 0.5), y: -9, duration: 0.01)
                    ])))
                    visual.addChild(ember)
                }
            }
        } else if spawn.kind == .saltWraith && spawn.title.contains("记忆蛭") {
            let idle = (1...6).map { SKTexture(imageNamed: String(format: "MemoryLeechIdle%02d", $0)) }
            let artwork = SKSpriteNode(texture: idle[0])
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY - 16)
            artwork.size = CGSize(width: 166, height: 166)
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(
                idle: idle,
                attack: (1...12).map { SKTexture(imageNamed: String(format: "MemoryLeechCast%02d", $0)) },
                hit: [idle[0]],
                death: (1...16).map { SKTexture(imageNamed: String(format: "MemoryLeechDeath%02d", $0)) }
            )
        } else if spawn.kind == .saltWraith {
            let fallbackTexture = trimmedTexture(imageNamed: "SaltWraithIdle")
            let southIdleNames = (1...4).map { String(format: "SaltWraithSouthIdleV3%02d", $0) }
            let southIdle = normalizedTextures(imageNames: southIdleNames)
            let idle = southIdle.count == southIdleNames.count
                ? southIdle
                : productionEnemyClip(prefix: "SaltWraithIdleV2", frameCount: 6, fallback: [fallbackTexture])
            let texture = idle.first ?? fallbackTexture
            let southCastNames = (1...6).map { String(format: "SaltWraithSouthCastV4%02d", $0) }
            let southCast = normalizedTextures(imageNames: southCastNames)
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 104, height: 132))
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(
                idle: idle,
                attack: southCast.count == southCastNames.count ? southCast : [texture],
                hit: [texture],
                death: [texture]
            )

            let lanternGlow = SKShapeNode(circleOfRadius: 7)
            lanternGlow.position = CGPoint(x: 2, y: 31)
            lanternGlow.fillColor = UIColor.systemCyan.withAlphaComponent(0.20)
            lanternGlow.strokeColor = .systemCyan
            lanternGlow.lineWidth = 1
            lanternGlow.glowWidth = 9
            lanternGlow.blendMode = .add
            lanternGlow.run(.repeatForever(.sequence([
                .group([.scale(to: 1.28, duration: 0.65), .fadeAlpha(to: 0.48, duration: 0.65)]),
                .group([.scale(to: 0.82, duration: 0.65), .fadeAlpha(to: 1, duration: 0.65)])
            ])))
            visual.addChild(lanternGlow)
        } else if spawn.kind == .mirrorShade {
            let mirrorRing = SKShapeNode(circleOfRadius: 43)
            mirrorRing.position = CGPoint(x: 0, y: 92)
            mirrorRing.strokeColor = UIColor.systemPurple.withAlphaComponent(0.50)
            mirrorRing.fillColor = .clear
            mirrorRing.lineWidth = 2
            mirrorRing.glowWidth = 2
            mirrorRing.blendMode = .add
            mirrorRing.zPosition = -1
            mirrorRing.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 5.2)))
            visual.addChild(mirrorRing)

            let fallbackTexture = trimmedTexture(imageNamed: "MirrorShadeIdle")
            let southCast = productionEnemyClip(
                prefix: "MirrorShadeSouthCastV1",
                frameCount: 4,
                fallback: [fallbackTexture]
            )
            let texture = southCast.first ?? fallbackTexture
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 142, height: 178))
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(
                idle: [texture],
                attack: southCast,
                hit: [texture],
                death: [texture]
            )

            let coreGlow = SKShapeNode(circleOfRadius: 9)
            coreGlow.position = CGPoint(x: 0, y: 73)
            coreGlow.fillColor = UIColor.systemPurple.withAlphaComponent(0.24)
            coreGlow.strokeColor = .magenta
            coreGlow.lineWidth = 1.5
            coreGlow.glowWidth = 3
            coreGlow.blendMode = .add
            coreGlow.run(.repeatForever(.sequence([
                .group([.scale(to: 1.35, duration: 0.52), .fadeAlpha(to: 0.48, duration: 0.52)]),
                .group([.scale(to: 0.78, duration: 0.52), .fadeAlpha(to: 1, duration: 0.52)])
            ])))
            visual.addChild(coreGlow)
        } else if spawn.kind == .saltCrystalGnawer {
            let fallbackTexture = trimmedTexture(imageNamed: "SaltCrystalGnawer")
            let southAttack = productionEnemyClip(
                prefix: "SaltCrystalGnawerSouthAttackV1",
                frameCount: 4,
                fallback: [fallbackTexture]
            )
            let texture = southAttack.first ?? fallbackTexture
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            // The parasite encounter uses a tall silhouette. Keep the authored
            // vertical proportions instead of fitting it into the old crawler
            // bounds, which made the enemy read as lying sideways.
            artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 112, height: 164))
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(
                idle: [texture],
                attack: southAttack,
                hit: [texture],
                death: [texture]
            )
        } else if spawn.kind == .rustTideHookRaider {
            let fallbackTexture = trimmedTexture(imageNamed: "RustTideHookRaider")
            let southAttack = productionEnemyClip(
                prefix: "RustTideHookRaiderSouthAttackV1",
                frameCount: 4,
                fallback: [fallbackTexture]
            )
            let texture = southAttack.first ?? fallbackTexture
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 116, height: 164))
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(
                idle: [texture],
                attack: southAttack,
                hit: [texture],
                death: [texture]
            )
        } else if spawn.kind == .oathScribe {
            // The original full-face mask made every institutional enemy feel
            // anonymous. This authored south-facing strip exposes a readable
            // adult face while the half-mask remains a faction identifier.
            let fallbackTexture = trimmedTexture(imageNamed: "OathScribe")
            let southCast = productionEnemyClip(
                prefix: "OathScribeSouthCastV1",
                frameCount: 4,
                fallback: [fallbackTexture]
            )
            let texture = southCast.first ?? fallbackTexture
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 116, height: 164))
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(
                idle: [texture],
                attack: southCast,
                hit: [texture],
                death: [texture]
            )
        } else if spawn.kind == .crackedMirrorMarionette {
            // This enemy used to reuse a three-quarter portrait, so it looked
            // away from the hero. The authored south-facing strip keeps its
            // feet locked while only the fan, hands and ribbons cast.
            let fallbackTexture = trimmedTexture(imageNamed: "CrackedMirrorMarionette")
            let southCast = productionEnemyClip(
                prefix: "CrackedMirrorMarionetteSouthCastV1",
                frameCount: 4,
                fallback: [fallbackTexture]
            )
            let texture = southCast.first ?? fallbackTexture
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 112, height: 158))
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(
                idle: [texture],
                attack: southCast,
                hit: [texture],
                death: [texture]
            )
        } else if [.saltCrystalDeacon, .stageAfterimage, .drownedMemoryGhost,
                   .facelessAttendant].contains(spawn.kind) {
            // Temporary vector stand-ins keep every district readable until
            // the corresponding south-facing raster action set is authored.
            visual.addChild(makeDistrictSecondaryEnemyPlaceholder(for: spawn.kind))
        } else if let commonArtName = commonEnemyArtName(for: spawn.kind) {
            let texture = trimmedTexture(imageNamed: commonArtName)
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            let bounds = spawn.kind == .saltCrystalGnawer
                ? CGSize(width: 132, height: 110)
                : CGSize(width: 112, height: 158)
            artwork.size = fittedArtworkSize(for: texture, within: bounds)
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(idle: [texture], attack: [], hit: [], death: [])
        } else if spawn.kind == .hollowClockGuard {
            // Simulator cannot load UnityFramework, so sample the exact same
            // Shadow Iron Guardian FBX clips used by the live Animator. Idle
            // and attack frames keep the shared camera registration produced by
            // Unity. Re-centering each bitmap from its opaque silhouette would
            // move the torso whenever the axe changes sides during the turn.
            let currentTexture = trimmedTexture(imageNamed: "ClockGuardCurrent3DPreview")
            let idleNames = (1...4).map {
                String(format: "ClockGuardUnityCombatIdle%02d", $0)
            }
            let attackNames = (1...14).map {
                String(format: "ClockGuardUnityCombatAttack%02d", $0)
            }
            let sampledFrames = registeredTextures(imageNames: idleNames + attackNames)
            let idleFrames: [SKTexture]
            let attackFrames: [SKTexture]
            if sampledFrames.count == idleNames.count + attackNames.count {
                idleFrames = Array(sampledFrames.prefix(idleNames.count))
                attackFrames = Array(sampledFrames.suffix(attackNames.count))
            } else {
                idleFrames = [currentTexture]
                attackFrames = [currentTexture]
            }
            let currentClips = DungeonEnemyAnimationClips(
                idle: idleFrames,
                attack: attackFrames,
                hit: [idleFrames[0]],
                death: [idleFrames[0]]
            )
            startsWithIntegratedControlSeal = presentationOnly
            baseAnimationClips = currentClips
            shieldedAnimationClips = currentClips
            animationClips = currentClips
            let texture = idleFrames[0]

            // Keep the control-seal gameplay state, but do not substitute the
            // later procedural violet oval for the missing authored shield.
            // That draft effect was never part of the guard FBX and visibly
            // read as a floor ring at phone scale.  An empty presentation
            // anchor lets CombatCore continue to break/restore the seal while
            // the approved standalone shield asset is recovered separately.
            let aura = SKNode()
            aura.name = "clock-guard-control-seal-anchor"
            aura.position = CGPoint(x: 0, y: 66)
            aura.zPosition = -1
            aura.isHidden = true
            visual.addChild(aura)
            controlSealAuraNode = aura

            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            // Keep the current 3D silhouette subordinate to the arena
            // composition. The simulator snapshot has the same grounded
            // framing as the Unity prefab, so it cannot jump between turns.
            artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 189, height: 231))
            visual.addChild(artwork)
            artworkNode = artwork
        } else if presentationOnly, spawn.id.hasPrefix("enemy_memory_leech_node#") {
            // The parasitic clock core is a tall suspended node in the
            // presentation encounter. Do not reuse the horizontal pump-heart
            // boss art for this target.
            let texture = trimmedTexture(imageNamed: "MemoryParasiteNodeVertical")
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 112, height: 182))
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(
                idle: [texture],
                attack: [texture],
                hit: [texture],
                death: [texture]
            )
        } else if let bossArtName = bossArtName(for: spawn.kind) {
            let texture = trimmedTexture(imageNamed: bossArtName)
            let artwork = SKSpriteNode(texture: texture)
            artwork.name = root.name
            artwork.anchorPoint = CGPoint(x: 0.5, y: 0)
            artwork.position = CGPoint(x: 0, y: groundOffsetY)
            artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 286, height: 314))
            visual.addChild(artwork)
            artworkNode = artwork
            animationClips = DungeonEnemyAnimationClips(
                idle: [texture],
                attack: [],
                hit: [texture],
                death: [texture]
            )
        } else {
            let bodyRadius: CGFloat = spawn.rank == .boss ? 29 : 20

            let body = SKShapeNode(circleOfRadius: bodyRadius)
            body.name = root.name
            body.fillColor = UIColor.black.withAlphaComponent(0.88)
            body.strokeColor = bodyColor
            body.lineWidth = spawn.rank == .boss ? 3 : 2
            body.glowWidth = spawn.rank == .boss ? 9 : 5
            visual.addChild(body)

            for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 3) {
                let spike = SKShapeNode(rectOf: CGSize(width: 5, height: spawn.rank == .boss ? 24 : 17), cornerRadius: 2)
                spike.name = root.name
                let radius = spawn.rank == .boss ? 36.0 : 25.0
                spike.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius * 0.70)
                spike.zRotation = angle - .pi / 2
                spike.fillColor = bodyColor.withAlphaComponent(0.78)
                spike.strokeColor = .clear
                visual.addChild(spike)
            }

            let icon = SKLabelNode(text: enemyGlyph(for: spawn.kind))
            icon.name = root.name
            icon.fontSize = spawn.rank == .boss ? 31 : 22
            icon.fontColor = bodyColor
            icon.verticalAlignmentMode = .center
            visual.addChild(icon)
        }
        root.addChild(visual)

        // Presentation encounters use large portrait art. Scale the actor art
        // independently so it does not dominate the arena while its HUD stays
        // full-size and readable.
        let presentationArtworkScale: CGFloat
        if presentationOnly, spawn.id.hasPrefix("enemy_memory_leech_node#") {
            presentationArtworkScale = 0.72
        } else if presentationOnly, spawn.kind == .hollowClockGuard {
            // The current preview is tightly cropped around the imported 3D
            // silhouette (the raised blade reaches the top edge). The retired
            // 2D frames carried transparent margins, so their old scale made
            // this model read too tall in the portrait arena. Match the Unity
            // formation reference: the guard, including its blade, sits just
            // below the Fool's visual height.
            presentationArtworkScale = usesFullClockGuardLayout ? 0.38 : 0.36
        } else {
            presentationArtworkScale = presentationOnly ? 0.82 : 1
        }
        visual.setScale(presentationArtworkScale)

        let barWidth: CGFloat = 82
        let healthBackground = SKShapeNode(rectOf: CGSize(width: barWidth, height: 7), cornerRadius: 3)
        healthBackground.name = "presentation-enemy-health-background"
        let presetHealthBarY: CGFloat
        if spawn.kind == .gearHound || spawn.kind == .prototypeHound || spawn.kind == .saltCrystalGnawer {
            presetHealthBarY = 70
        } else if spawn.kind == .saltWraith {
            presetHealthBarY = 76
        } else if spawn.kind == .mirrorShade {
            presetHealthBarY = 116
        } else if [.crackedMirrorMarionette, .rustTideHookRaider, .oathScribe,
                   .saltCrystalDeacon, .stageAfterimage, .drownedMemoryGhost,
                   .facelessAttendant].contains(spawn.kind) {
            presetHealthBarY = 108
        } else {
            // Boss portraits are tall dialogue-quality art. Keep actor HUD
            // outside the silhouette instead of covering the face.
            presetHealthBarY = spawn.rank == .boss ? 178 : 35
        }
        let artworkTop = artworkNode.map {
            ($0.position.y + $0.size.height) * presentationArtworkScale
        } ?? 0
        // The clock guard's generated frames contain a tall axe arc. Using
        // that transparent canvas edge pushed its HUD under the chapter bar.
        let healthBarY = spawn.kind == .hollowClockGuard
            ? (usesFullClockGuardLayout ? CGFloat(140) : CGFloat(134))
            : max(presetHealthBarY, artworkTop + 8)
        healthBackground.position = CGPoint(x: 0, y: healthBarY)
        healthBackground.fillColor = UIColor.black.withAlphaComponent(0.82)
        healthBackground.strokeColor = .white.withAlphaComponent(0.28)
        healthBackground.lineWidth = 1
        healthBackground.zPosition = 12
        root.addChild(healthBackground)

        let healthFill = SKShapeNode()
        healthFill.name = "presentation-enemy-health-fill"
        healthFill.path = CGPath(
            roundedRect: CGRect(x: 0, y: -3, width: barWidth - 4, height: 6),
            cornerWidth: 3,
            cornerHeight: 3,
            transform: nil
        )
        // Anchor the fill at the left edge so damage removes health from one
        // side instead of shrinking symmetrically from the center.
        healthFill.position = CGPoint(
            x: healthBackground.position.x - (barWidth - 4) / 2,
            y: healthBackground.position.y
        )
        // Red is reserved for health. The blue bar directly below is the
        // willpower/control resource, so the two readings never blur together.
        healthFill.fillTexture = nil
        healthFill.fillColor = UIColor(red: 1.0, green: 0.06, blue: 0.10, alpha: 1)
        healthFill.strokeColor = .clear
        healthFill.zPosition = 13
        root.addChild(healthFill)

        // Control is a readable resource, never an invisible immunity flag.
        // Breaking this bar delays one hostile action; bosses then recover it.
        let willpowerBackground = SKShapeNode(
            rectOf: CGSize(width: barWidth, height: 4),
            cornerRadius: 2
        )
        willpowerBackground.name = "presentation-enemy-willpower-background"
        willpowerBackground.position = CGPoint(x: 0, y: healthBarY - 7)
        willpowerBackground.fillColor = UIColor.black.withAlphaComponent(0.72)
        willpowerBackground.strokeColor = UIColor.white.withAlphaComponent(0.18)
        willpowerBackground.lineWidth = 0.6
        willpowerBackground.zPosition = 12
        root.addChild(willpowerBackground)

        let willpowerFill = SKShapeNode()
        willpowerFill.name = "presentation-enemy-willpower-fill"
        willpowerFill.path = CGPath(
            roundedRect: CGRect(x: 0, y: -1, width: barWidth - 4, height: 2),
            cornerWidth: 1,
            cornerHeight: 1,
            transform: nil
        )
        willpowerFill.position = CGPoint(
            x: willpowerBackground.position.x - (barWidth - 4) / 2,
            y: willpowerBackground.position.y
        )
        willpowerFill.fillColor = UIColor(red: 0.24, green: 0.78, blue: 0.96, alpha: 1)
        willpowerFill.strokeColor = .clear
        willpowerFill.zPosition = 13
        root.addChild(willpowerFill)

        // Turn-based combat needs readable intent before the player commits an
        // action. Keep this as compact game information attached to the actor,
        // rather than another full-width HUD panel.
        let intentLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        intentLabel.fontSize = spawn.rank == .boss ? 17 : 15
        intentLabel.fontColor = UIColor(white: 0.04, alpha: 0.84)
        intentLabel.horizontalAlignmentMode = .center
        intentLabel.verticalAlignmentMode = .bottom
        intentLabel.position = CGPoint(x: 0, y: healthBarY + 8)
        intentLabel.zPosition = 4
        root.addChild(intentLabel)

        if spawn.rank == .boss {
            let bossLabel = SKLabelNode(text: "BOSS")
            bossLabel.fontName = "AvenirNext-Bold"
            bossLabel.fontSize = 9
            bossLabel.fontColor = UIColor(white: 0.06, alpha: 1)
            bossLabel.position = CGPoint(x: 0, y: healthBarY + 24)
            bossLabel.zPosition = 2
            root.addChild(bossLabel)
        }

        let actor = DungeonEnemyActor(
            spawn: spawn,
            node: root,
            visualNode: visual,
            artworkNode: artworkNode,
            defensiveTexture: defensiveTexture,
            controlSealAuraNode: controlSealAuraNode,
            animationClips: animationClips,
            baseAnimationClips: baseAnimationClips,
            shieldedAnimationClips: shieldedAnimationClips,
            startsWithIntegratedControlSeal: startsWithIntegratedControlSeal,
            healthFill: healthFill,
            willpowerFill: willpowerFill,
            intentLabel: intentLabel,
            groundShadow: groundShadow,
            contactShadow: contactShadow,
            homePosition: homePosition
        )
        if spawn.kind == .hollowClockGuard {
            groundShadow.isHidden = true
            contactShadow.isHidden = true
        }
        refreshEnemyIntent(actor)
        faceEnemy(actor, toward: player.position)
        // Tutorial combat intentionally waits for the player's first card
        // before `combatHasStarted` becomes true. Start authored idle clips at
        // spawn time so enemies are alive during the guided selection phase,
        // rather than remaining frozen until the first turn resolves.
        updateEnemyArtwork(actor)
        return actor
    }

    /// Builds the current guard's control seal as a procedural overlay. The
    /// guard body always comes from the current imported 3D model (or its
    /// simulator render), so no retired 2D character art is coupled to the
    /// effect. The seal is intentionally made from broken arcs and small
    /// clock-runes; a solid oval reads as a generic bubble and overwhelms the
    /// model at phone scale.
    func makeClockGuardFireShield() -> SKNode {
        let aura = SKNode()
        aura.name = "clock-guard-fire-shield"
        aura.position = CGPoint(x: 0, y: 66)
        aura.zPosition = -1

        let violet = UIColor(red: 0.56, green: 0.26, blue: 1.0, alpha: 1)
        let crimson = UIColor(red: 1.0, green: 0.10, blue: 0.20, alpha: 1)

        // A pointed, slightly irregular envelope gives the barrier a distinct
        // silhouette without covering the current black-and-red armour.
        let envelopePath = CGMutablePath()
        envelopePath.move(to: CGPoint(x: 0, y: 104))
        envelopePath.addCurve(
            to: CGPoint(x: 74, y: 34),
            control1: CGPoint(x: 28, y: 100),
            control2: CGPoint(x: 68, y: 80)
        )
        envelopePath.addCurve(
            to: CGPoint(x: 60, y: -66),
            control1: CGPoint(x: 80, y: -14),
            control2: CGPoint(x: 66, y: -50)
        )
        envelopePath.addCurve(
            to: CGPoint(x: 0, y: -98),
            control1: CGPoint(x: 40, y: -90),
            control2: CGPoint(x: 18, y: -98)
        )
        envelopePath.addCurve(
            to: CGPoint(x: -60, y: -66),
            control1: CGPoint(x: -18, y: -98),
            control2: CGPoint(x: -40, y: -90)
        )
        envelopePath.addCurve(
            to: CGPoint(x: -74, y: 34),
            control1: CGPoint(x: -66, y: -50),
            control2: CGPoint(x: -80, y: -14)
        )
        envelopePath.addCurve(
            to: CGPoint(x: 0, y: 104),
            control1: CGPoint(x: -68, y: 80),
            control2: CGPoint(x: -28, y: 100)
        )
        envelopePath.closeSubpath()

        let envelope = SKShapeNode(path: envelopePath)
        envelope.name = "clock-guard-control-seal"
        envelope.strokeColor = violet.withAlphaComponent(0.72)
        envelope.fillColor = violet.withAlphaComponent(0.03)
        envelope.lineWidth = 2.2
        envelope.glowWidth = 7
        envelope.blendMode = .add
        envelope.run(.repeatForever(.sequence([
            .group([
                .scale(to: 1.035, duration: 0.72),
                .fadeAlpha(to: 0.62, duration: 0.72)
            ]),
            .group([
                .scale(to: 0.975, duration: 0.84),
                .fadeAlpha(to: 0.92, duration: 0.84)
            ])
        ])))
        aura.addChild(envelope)

        func makeArc(
            radius: CGFloat,
            start: CGFloat,
            end: CGFloat,
            color: UIColor,
            lineWidth: CGFloat,
            glowWidth: CGFloat
        ) -> SKShapeNode {
            let path = CGMutablePath()
            path.addArc(
                center: .zero,
                radius: radius,
                startAngle: start,
                endAngle: end,
                clockwise: false
            )
            let arc = SKShapeNode(path: path)
            arc.strokeColor = color
            arc.fillColor = .clear
            arc.lineWidth = lineWidth
            arc.glowWidth = glowWidth
            arc.blendMode = .add
            arc.xScale = 0.90
            arc.yScale = 1.10
            return arc
        }

        let outerArcs: [(CGFloat, CGFloat, UIColor)] = [
            (0.16 * .pi, 0.72 * .pi, violet.withAlphaComponent(0.70)),
            (0.88 * .pi, 1.43 * .pi, crimson.withAlphaComponent(0.64)),
            (1.66 * .pi, 2.22 * .pi, violet.withAlphaComponent(0.64)),
            (2.38 * .pi, 2.92 * .pi, crimson.withAlphaComponent(0.70))
        ]
        for (index, arcDefinition) in outerArcs.enumerated() {
            let arc = makeArc(
                radius: 88,
                start: arcDefinition.0,
                end: arcDefinition.1,
                color: arcDefinition.2,
                lineWidth: 2.0,
                glowWidth: 6
            )
            arc.name = "clock-guard-control-seal-arc-\(index)"
            arc.run(.repeatForever(.sequence([
                .wait(forDuration: Double(index) * 0.11),
                .fadeAlpha(to: 0.38, duration: 0.44),
                .fadeAlpha(to: 1, duration: 0.54)
            ])))
            aura.addChild(arc)
        }

        let innerArc = makeArc(
            radius: 63,
            start: -0.16 * .pi,
            end: 0.83 * .pi,
            color: crimson.withAlphaComponent(0.74),
            lineWidth: 1.2,
            glowWidth: 4
        )
        innerArc.name = "clock-guard-control-seal-inner"
        innerArc.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 4.6)))
        aura.addChild(innerArc)

        // Eight small clock-runes make the control layer readable at a glance
        // and keep the animation alive without another large filled circle.
        for index in 0..<8 {
            let runePath = CGMutablePath()
            runePath.move(to: CGPoint(x: 0, y: 5))
            runePath.addLine(to: CGPoint(x: 2.8, y: 0))
            runePath.addLine(to: CGPoint(x: 0, y: -5))
            runePath.addLine(to: CGPoint(x: -2.8, y: 0))
            runePath.closeSubpath()
            let rune = SKShapeNode(path: runePath)
            let angle = CGFloat(index) * .pi / 4 + .pi / 8
            rune.position = CGPoint(x: cos(angle) * 74, y: sin(angle) * 86)
            rune.zRotation = angle
            rune.fillColor = .clear
            rune.strokeColor = index.isMultiple(of: 2)
                ? crimson.withAlphaComponent(0.68)
                : violet.withAlphaComponent(0.72)
            rune.lineWidth = 0.9
            rune.glowWidth = 3
            rune.blendMode = .add
            rune.run(.repeatForever(.sequence([
                .wait(forDuration: Double(index) * 0.08),
                .scale(to: 1.18, duration: 0.42),
                .fadeAlpha(to: 0.36, duration: 0.42),
                .scale(to: 0.88, duration: 0.48),
                .fadeAlpha(to: 0.96, duration: 0.48)
            ])))
            aura.addChild(rune)
        }

        let corePath = CGMutablePath()
        corePath.move(to: CGPoint(x: 0, y: 15))
        corePath.addLine(to: CGPoint(x: 10, y: 0))
        corePath.addLine(to: CGPoint(x: 0, y: -15))
        corePath.addLine(to: CGPoint(x: -10, y: 0))
        corePath.closeSubpath()
        let core = SKShapeNode(path: corePath)
        core.name = "clock-guard-control-seal-core"
        core.fillColor = crimson.withAlphaComponent(0.06)
        core.strokeColor = crimson.withAlphaComponent(0.62)
        core.lineWidth = 1.1
        core.glowWidth = 4
        core.blendMode = .add
        core.run(.repeatForever(.sequence([
            .scale(to: 1.10, duration: 0.58),
            .scale(to: 0.92, duration: 0.72)
        ])))
        aura.addChild(core)

        return aura
    }

    private func makeDistrictSecondaryEnemyPlaceholder(for kind: DungeonEnemyKind) -> SKNode {
        let container = SKNode()
        container.name = "temporary-district-enemy-art"

        func makeRobe(fill: UIColor, stroke: UIColor) -> SKShapeNode {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -9, y: 30))
            path.addLine(to: CGPoint(x: -25, y: -34))
            path.addQuadCurve(to: CGPoint(x: 25, y: -34), control: CGPoint(x: 0, y: -42))
            path.addLine(to: CGPoint(x: 9, y: 30))
            path.closeSubpath()
            let robe = SKShapeNode(path: path)
            robe.fillColor = fill
            robe.strokeColor = stroke
            robe.lineWidth = 2
            robe.glowWidth = 2
            return robe
        }

        func makeMask(fill: UIColor, stroke: UIColor) -> SKShapeNode {
            let mask = SKShapeNode(ellipseOf: CGSize(width: 19, height: 25))
            mask.position.y = 39
            mask.fillColor = fill
            mask.strokeColor = stroke
            mask.lineWidth = 1.5
            mask.glowWidth = 2
            return mask
        }

        switch kind {
        case .saltCrystalDeacon:
            let robe = makeRobe(
                fill: UIColor(red: 0.08, green: 0.24, blue: 0.29, alpha: 0.94),
                stroke: UIColor(red: 0.48, green: 0.95, blue: 0.96, alpha: 0.92)
            )
            container.addChild(robe)
            container.addChild(makeMask(fill: UIColor(white: 0.92, alpha: 1), stroke: .systemCyan))

            for index in 0..<7 {
                let crystalPath = CGMutablePath()
                crystalPath.move(to: CGPoint(x: 0, y: 9))
                crystalPath.addLine(to: CGPoint(x: 4, y: 0))
                crystalPath.addLine(to: CGPoint(x: 0, y: -9))
                crystalPath.addLine(to: CGPoint(x: -4, y: 0))
                crystalPath.closeSubpath()
                let crystal = SKShapeNode(path: crystalPath)
                let angle = CGFloat(index) / 7 * .pi * 2
                crystal.position = CGPoint(x: cos(angle) * 32, y: 11 + sin(angle) * 39)
                crystal.zRotation = angle - .pi / 2
                crystal.fillColor = UIColor(red: 0.56, green: 0.96, blue: 1, alpha: 0.78)
                crystal.strokeColor = UIColor.white.withAlphaComponent(0.70)
                crystal.lineWidth = 0.8
                crystal.glowWidth = 3
                crystal.blendMode = .add
                crystal.run(.repeatForever(.sequence([
                    .wait(forDuration: TimeInterval(index) * 0.08),
                    .fadeAlpha(to: 0.36, duration: 0.62),
                    .fadeAlpha(to: 1, duration: 0.62)
                ])))
                container.addChild(crystal)
            }

        case .stageAfterimage:
            for index in stride(from: 2, through: 0, by: -1) {
                let offset = CGFloat(index) * 7
                let echo = makeRobe(
                    fill: UIColor(red: 0.27, green: 0.06, blue: 0.38, alpha: 0.34 + CGFloat(2 - index) * 0.20),
                    stroke: UIColor(red: 0.92, green: 0.38, blue: 1, alpha: 0.38 + CGFloat(2 - index) * 0.22)
                )
                echo.position.x = offset - 7
                echo.zPosition = CGFloat(2 - index)
                echo.run(.repeatForever(.sequence([
                    .moveBy(x: index.isMultiple(of: 2) ? 3 : -3, y: 0, duration: 0.72),
                    .moveBy(x: index.isMultiple(of: 2) ? -3 : 3, y: 0, duration: 0.72)
                ])))
                container.addChild(echo)
            }
            let face = makeMask(fill: UIColor(red: 0.15, green: 0.05, blue: 0.22, alpha: 0.96), stroke: .systemPink)
            container.addChild(face)
            let mirrorLine = SKShapeNode(rectOf: CGSize(width: 52, height: 2), cornerRadius: 1)
            mirrorLine.position.y = 8
            mirrorLine.fillColor = UIColor.systemPurple.withAlphaComponent(0.82)
            mirrorLine.strokeColor = .clear
            mirrorLine.glowWidth = 5
            mirrorLine.run(.repeatForever(.sequence([
                .scaleX(to: 0.35, duration: 0.56),
                .scaleX(to: 1, duration: 0.56)
            ])))
            container.addChild(mirrorLine)

        case .drownedMemoryGhost:
            let bubble = SKShapeNode(circleOfRadius: 40)
            bubble.position.y = 7
            bubble.fillColor = UIColor(red: 0.10, green: 0.42, blue: 0.62, alpha: 0.16)
            bubble.strokeColor = UIColor(red: 0.48, green: 0.91, blue: 1, alpha: 0.78)
            bubble.lineWidth = 2
            bubble.glowWidth = 4
            bubble.blendMode = .add
            bubble.run(.repeatForever(.sequence([
                .group([.scale(to: 1.05, duration: 1.05), .fadeAlpha(to: 0.62, duration: 1.05)]),
                .group([.scale(to: 0.96, duration: 1.05), .fadeAlpha(to: 1, duration: 1.05)])
            ])))
            container.addChild(bubble)
            container.addChild(makeRobe(
                fill: UIColor(red: 0.03, green: 0.18, blue: 0.31, alpha: 0.72),
                stroke: UIColor(red: 0.32, green: 0.78, blue: 0.94, alpha: 0.68)
            ))
            container.addChild(makeMask(fill: UIColor(red: 0.62, green: 0.90, blue: 0.96, alpha: 0.48), stroke: .systemCyan))
            for index in 0..<5 {
                let mote = SKShapeNode(circleOfRadius: CGFloat(index % 2) + 1.4)
                mote.position = CGPoint(x: CGFloat(index * 11 - 22), y: CGFloat(index % 3) * 18 - 17)
                mote.fillColor = UIColor.white.withAlphaComponent(0.72)
                mote.strokeColor = .clear
                mote.alpha = 0
                mote.run(.repeatForever(.sequence([
                    .wait(forDuration: TimeInterval(index) * 0.17),
                    .group([.moveBy(x: 2, y: 56, duration: 1.15), .fadeIn(withDuration: 0.28)]),
                    .fadeOut(withDuration: 0.42),
                    .moveBy(x: -2, y: -56, duration: 0.01)
                ])))
                container.addChild(mote)
            }

        case .facelessAttendant:
            container.addChild(makeRobe(
                fill: UIColor(red: 0.10, green: 0.09, blue: 0.19, alpha: 0.96),
                stroke: UIColor(red: 0.68, green: 0.62, blue: 0.96, alpha: 0.86)
            ))
            container.addChild(makeMask(fill: UIColor(white: 0.93, alpha: 1), stroke: UIColor(red: 0.72, green: 0.65, blue: 1, alpha: 1)))
            for index in 0..<3 {
                let page = SKShapeNode(rectOf: CGSize(width: 10, height: 15), cornerRadius: 1)
                let angle = CGFloat(index) / 3 * .pi * 2
                page.position = CGPoint(x: cos(angle) * 34, y: 7 + sin(angle) * 42)
                page.fillColor = UIColor(white: 0.92, alpha: 0.76)
                page.strokeColor = UIColor.systemPurple.withAlphaComponent(0.72)
                page.lineWidth = 1
                page.zRotation = angle
                page.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 3.8 + TimeInterval(index) * 0.3)))
                container.addChild(page)
            }

        default:
            break
        }

        container.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: 2, duration: 0.92),
            .moveBy(x: 0, y: -2, duration: 0.92)
        ])))
        return container
    }

    private func enemyColor(for kind: DungeonEnemyKind) -> UIColor {
        switch kind {
        case .gearHound: UIColor(red: 0.68, green: 0.22, blue: 0.12, alpha: 1)
        case .saltWraith: UIColor(red: 0.22, green: 0.68, blue: 0.82, alpha: 1)
        case .saltCrystalDeacon: UIColor(red: 0.42, green: 0.88, blue: 0.94, alpha: 1)
        case .mirrorShade: UIColor(red: 0.56, green: 0.20, blue: 0.72, alpha: 1)
        case .stageAfterimage: UIColor(red: 0.82, green: 0.28, blue: 0.92, alpha: 1)
        case .saltCrystalGnawer: UIColor(red: 0.18, green: 0.72, blue: 0.72, alpha: 1)
        case .crackedMirrorMarionette: UIColor(red: 0.58, green: 0.26, blue: 0.78, alpha: 1)
        case .rustTideHookRaider: UIColor(red: 0.12, green: 0.56, blue: 0.58, alpha: 1)
        case .drownedMemoryGhost: UIColor(red: 0.20, green: 0.70, blue: 0.88, alpha: 1)
        case .oathScribe: UIColor(red: 0.34, green: 0.34, blue: 0.74, alpha: 1)
        case .facelessAttendant: UIColor(red: 0.66, green: 0.60, blue: 0.90, alpha: 1)
        case .hollowClockGuard: UIColor(red: 0.85, green: 0.68, blue: 0.28, alpha: 1)
        case .lampDevourer: UIColor(red: 0.20, green: 0.38, blue: 0.74, alpha: 1)
        case .prototypeHound: UIColor(red: 0.18, green: 0.66, blue: 0.62, alpha: 1)
        case .reversePumpHeart: UIColor(red: 0.20, green: 0.50, blue: 0.82, alpha: 1)
        case .seravianUnified: UIColor(red: 0.58, green: 0.30, blue: 0.72, alpha: 1)
        case .whiteTideMotherCrystal: UIColor(red: 0.28, green: 0.82, blue: 0.78, alpha: 1)
        case .firstUnderstudy: UIColor(red: 0.72, green: 0.30, blue: 0.82, alpha: 1)
        case .deepTideDisciple: UIColor(red: 0.10, green: 0.56, blue: 0.78, alpha: 1)
        case .mistCrownGovernor: UIColor(red: 0.34, green: 0.28, blue: 0.72, alpha: 1)
        }
    }

    /// Encounter data can use a narrative role as its title.  The label over
    /// the actor must identify the creature the player is targeting.
    private func enemyDisplayName(for enemy: DungeonEnemyActor) -> String {
        switch enemy.spawn.kind {
        case .gearHound:
            "失名猎犬"
        default:
            enemy.spawn.title
        }
    }

    private func enemyGlyph(for kind: DungeonEnemyKind) -> String {
        switch kind {
        case .gearHound: "⚙︎"
        case .saltWraith: "◇"
        case .saltCrystalDeacon: "⌑"
        case .mirrorShade: "◈"
        case .stageAfterimage: "◫"
        case .saltCrystalGnawer: "✧"
        case .crackedMirrorMarionette: "◩"
        case .rustTideHookRaider: "◜"
        case .drownedMemoryGhost: "◌"
        case .oathScribe: "✒︎"
        case .facelessAttendant: "□"
        case .hollowClockGuard: "◷"
        case .lampDevourer: "◉"
        case .prototypeHound: "⚙︎"
        case .reversePumpHeart: "◆"
        case .seravianUnified: "◎"
        case .whiteTideMotherCrystal: "✧"
        case .firstUnderstudy: "◈"
        case .deepTideDisciple: "≋"
        case .mistCrownGovernor: "♜"
        }
    }

    private func bossArtName(for kind: DungeonEnemyKind) -> String? {
        switch kind {
        case .hollowClockGuard: nil
        case .lampDevourer: "BossLampDevourer"
        case .prototypeHound: "BossPrototypeHound"
        case .reversePumpHeart: "BossReversePumpHeart"
        case .seravianUnified: "BossSeravianUnified"
        case .whiteTideMotherCrystal: "BossWhiteTideMotherCrystal"
        case .firstUnderstudy: "BossFirstUnderstudy"
        case .deepTideDisciple: "BossDeepTideDisciple"
        case .mistCrownGovernor: "BossMistCrownGovernor"
        case .gearHound, .saltWraith, .saltCrystalDeacon, .mirrorShade,
             .stageAfterimage, .saltCrystalGnawer, .crackedMirrorMarionette,
             .rustTideHookRaider, .drownedMemoryGhost, .oathScribe,
             .facelessAttendant: nil
        }
    }

    private func commonEnemyArtName(for kind: DungeonEnemyKind) -> String? {
        switch kind {
        case .saltCrystalGnawer: "SaltCrystalGnawer"
        case .crackedMirrorMarionette: "CrackedMirrorMarionette"
        case .rustTideHookRaider: "RustTideHookRaider"
        case .oathScribe: "OathScribe"
        case .gearHound, .saltWraith, .saltCrystalDeacon, .mirrorShade,
             .stageAfterimage, .drownedMemoryGhost, .facelessAttendant,
             .hollowClockGuard,
             .lampDevourer, .prototypeHound, .reversePumpHeart, .seravianUnified,
             .whiteTideMotherCrystal, .firstUnderstudy, .deepTideDisciple,
             .mistCrownGovernor: nil
        }
    }

    private func buildDistrictAtmosphere() {
        if level.id.hasPrefix("salt-warehouse-") {
            buildDriftingMotes(
                color: UIColor(red: 0.62, green: 0.96, blue: 0.92, alpha: 1),
                birthRate: 13,
                particleSize: CGSize(width: 2.2, height: 5.6),
                rises: true
            )
        } else if level.id.hasPrefix("mirror-theater-") {
            buildDriftingMotes(
                color: UIColor(red: 0.78, green: 0.56, blue: 1.0, alpha: 1),
                birthRate: 9,
                particleSize: CGSize(width: 2.8, height: 2.8),
                rises: true
            )
        } else if level.id.hasPrefix("tide-gate-") {
            buildRain(
                color: UIColor(red: 0.62, green: 0.88, blue: 0.94, alpha: 1),
                birthRate: 42,
                alpha: 0.24
            )
        } else if level.id.hasPrefix("mist-crown-") {
            buildDriftingMotes(
                color: UIColor(red: 0.94, green: 0.88, blue: 0.72, alpha: 1),
                birthRate: 7,
                particleSize: CGSize(width: 3.2, height: 8.0),
                rises: false
            )
        } else {
            buildRain(
                color: UIColor(red: 0.72, green: 0.86, blue: 1, alpha: 1),
                birthRate: 58,
                alpha: 0.30
            )
        }
    }

    private func buildRain(color: UIColor, birthRate: CGFloat, alpha: CGFloat) {
        guard !effectsOnlyOverlayEnabled else { return }
        let rain = SKEmitterNode()
        rain.particleBirthRate = birthRate
        rain.particleLifetime = 2.8
        rain.particlePositionRange = CGVector(dx: size.width * 1.3, dy: 20)
        rain.position = CGPoint(x: size.width / 2, y: size.height + 20)
        rain.emissionAngle = -.pi * 0.56
        rain.emissionAngleRange = 0.04
        rain.particleSpeed = 510
        rain.particleSpeedRange = 90
        rain.particleAlpha = alpha
        rain.particleScale = 0.7
        rain.particleColor = color
        rain.particleSize = CGSize(width: 1.2, height: 16)
        rain.zPosition = 30
        rain.targetNode = self
        addChild(rain)
    }

    private func buildDriftingMotes(
        color: UIColor,
        birthRate: CGFloat,
        particleSize: CGSize,
        rises: Bool
    ) {
        let motes = SKEmitterNode()
        motes.particleBirthRate = birthRate
        motes.particleLifetime = 6.2
        motes.particleLifetimeRange = 1.4
        motes.particlePositionRange = CGVector(dx: size.width * 1.1, dy: 30)
        motes.position = CGPoint(x: size.width / 2, y: rises ? 80 : size.height + 18)
        motes.emissionAngle = rises ? .pi / 2 : -.pi / 2
        motes.emissionAngleRange = 0.28
        motes.particleSpeed = rises ? 34 : 42
        motes.particleSpeedRange = 14
        motes.particleAlpha = 0.54
        motes.particleAlphaRange = 0.18
        motes.particleAlphaSpeed = -0.07
        motes.particleScale = 1
        motes.particleScaleRange = 0.42
        motes.particleRotationRange = .pi
        motes.particleRotationSpeed = rises ? 0.42 : 1.1
        motes.particleColor = color
        motes.particleColorBlendFactor = 1
        motes.particleSize = particleSize
        motes.particleBlendMode = .add
        motes.zPosition = 18
        motes.targetNode = self
        addChild(motes)
    }

    private func turnCooldown(for definition: DungeonSkillDefinition) -> TimeInterval {
        max(1, ceil(definition.cooldown))
    }

    private func beginPlayerAction() {
        turnPhase = .resolvingPlayer
        combat.isPlayerTurn = false
        route.removeAll()
        publishState("行动结算中", force: true)
    }

    private func finishPlayerAction(after delay: TimeInterval) {
        if presentationOnly {
            run(.sequence([
                .wait(forDuration: delay),
                .run { [weak self] in
                    guard let self else { return }
                    self.turnPhase = .player
                    self.combat.isPlayerTurn = true
                    self.startIdleAnimation()
                }
            ]), withKey: "finish-player-turn")
            return
        }
        run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in self?.beginEnemyTurnIfReady() }
        ]), withKey: "finish-player-turn")
    }

    private func beginEnemyTurnIfReady() {
        guard !combat.isVictorious, !combat.isDefeated else {
            turnPhase = .finished
            return
        }
        let alive = enemies.filter(\.isAlive)
        guard !alive.isEmpty else {
            turnPhase = .transitioning
            return
        }

        turnPhase = .enemy
        combat.isPlayerTurn = false
        enemyTurnQueue = alive.sorted {
            let lhsPriority = enemyTurnPriority(for: $0.spawn.rank)
            let rhsPriority = enemyTurnPriority(for: $1.spawn.rank)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            return $0.node.position.x < $1.node.position.x
        }
        publishState("敌方回合 · 观察预警", force: true)
        performNextEnemyTurn()
    }

    private func enemyTurnPriority(for rank: DungeonEnemyRank) -> Int {
        switch rank {
        case .normal: 0
        case .elite: 1
        case .boss: 2
        }
    }

    private func performNextEnemyTurn() {
        guard turnPhase == .enemy, !combat.isDefeated else { return }
        while let first = enemyTurnQueue.first, !first.isAlive {
            enemyTurnQueue.removeFirst()
        }
        guard !enemyTurnQueue.isEmpty else {
            endEnemyTurn()
            return
        }

        let enemy = enemyTurnQueue.removeFirst()
        if enemy.staggeredTurns > 0 {
            enemy.staggeredTurns -= 1
            enemy.willpower = enemy.maxWillpower
            enemy.willpowerFill.run(.scaleX(to: 1, duration: 0.22))
            spawnFloatingText(
                enemy.spawn.rank == .boss ? "意志动摇 · 行动延后" : "失衡 · 跳过行动",
                at: enemy.node.position,
                color: .systemCyan
            )
            enemy.intentLabel.text = enemyDisplayName(for: enemy)
            run(.sequence([
                .wait(forDuration: 0.55),
                .run { [weak self] in self?.performNextEnemyTurn() }
            ]), withKey: "enemy-turn-step")
            return
        }
        beginEnemyWindup(enemy)
        let actionDuration = enemy.stateTimer + (attackStyle(for: enemy.spawn.kind) == .ranged ? 0.92 : 1.12)
        run(.sequence([
            .wait(forDuration: actionDuration),
            .run { [weak self] in self?.performNextEnemyTurn() }
        ]), withKey: "enemy-turn-step")
    }

    private func endEnemyTurn() {
        guard !combat.isDefeated, !combat.isVictorious else {
            turnPhase = .finished
            return
        }
        for skillID in DungeonSkillID.allCases {
            skillCooldowns[skillID] = max(0, skillCooldowns[skillID, default: 0] - 1)
        }
        playerInvulnerability = 0
        playerReactionCharges = 0
        playerGuardCharges = 0
        playerParryCharges = 0
        playerCounterCharges = 0
        for enemy in enemies where enemy.isAlive && enemy.exposedTurns > 0 {
            enemy.exposedTurns -= 1
        }

        if path.id == .priestess {
            let recovery = combat.playerHealth < combat.maxPlayerHealth / 2 ? 7 : 4
            let restored = min(recovery, combat.maxPlayerHealth - combat.playerHealth)
            if restored > 0 {
                combat.playerHealth += restored
                spawnFloatingText("预见回生 +\(restored)", at: player.position, color: .systemGreen)
            }
        }
        turnNumber += 1
        combat.turnNumber = turnNumber
        combat.isPlayerTurn = true
        turnPhase = .player
        enemies.filter(\.isAlive).forEach(refreshEnemyIntent)
        selectedEnemyID = selectedEnemyID.flatMap { id in
            enemies.contains(where: { $0.spawn.id == id && $0.isAlive }) ? id : nil
        }
        publishState("第 \(turnNumber) 回合 · 选择行动", feedback: true, force: true)
    }

    private func updateEnemies(deltaTime: CGFloat, elapsed: TimeInterval) {
        guard combatHasStarted, !combat.isVictorious, !combat.isDefeated else { return }

        for enemy in enemies where enemy.isAlive {
            enemy.stateTimer = max(0, enemy.stateTimer - elapsed)
            switch enemy.state {
            case .windup:
                if enemy.stateTimer <= 0 { resolveEnemyAttack(enemy) }
            case .recovering:
                if enemy.stateTimer <= 0 { enemy.state = .idle }
            case .hitStun:
                if enemy.stateTimer <= 0 { enemy.state = .idle }
            case .idle, .chasing:
                enemy.state = .idle
            case .dead:
                break
            }

            updateEnemyArtwork(enemy)
            updateEnemyElevation(enemy, deltaTime: deltaTime)
            faceEnemy(enemy, toward: player.position)

            enemy.node.zPosition = 9 + (size.height - enemy.node.position.y) / size.height
        }

        if combat.playerHealth <= 0, !combat.isDefeated {
            combat.isDefeated = true
            route.removeAll()
            destinationMarker.removeAllActions()
            destinationMarker.isHidden = true
            animatePlayerDeath()
            publishState("战斗失败", feedback: true, force: true)
        }
    }

    private func updateEnemyElevation(_ enemy: DungeonEnemyActor, deltaTime: CGFloat) {
        switch enemy.spawn.kind.locomotion {
        case .grounded:
            if enemy.spawn.kind == .gearHound {
                enemy.hoverPhase += deltaTime * 1.55
                let breath = sin(enemy.hoverPhase) * 0.65
                enemy.displayAltitude = breath
                enemy.visualNode.position.y = breath
                enemy.groundShadow.setScale(0.985 - max(0, breath) * 0.012)
            } else {
                enemy.displayAltitude = 0
                enemy.visualNode.position.y = 0
                enemy.groundShadow.setScale(1)
            }
            enemy.groundShadow.alpha = 1
            enemy.contactShadow.alpha = 1
        case let .spectralHover(height, amplitude):
            enemy.hoverPhase += deltaTime * 2.4
            let windupLift: CGFloat = enemy.state == .windup ? 5 : 0
            enemy.displayAltitude = height + sin(enemy.hoverPhase) * amplitude + windupLift
            enemy.visualNode.position.y = enemy.displayAltitude

            // The shadow remains at the world-floor anchor. Its response to
            // altitude supplies depth without scaling or warping the body art.
            let normalizedHeight = min(1, enemy.displayAltitude / 24)
            enemy.groundShadow.setScale(1 - normalizedHeight * 0.22)
            enemy.groundShadow.alpha = 1 - normalizedHeight * 0.48
            enemy.contactShadow.alpha = 0.12
        }
    }

    private func updateEnemyArtwork(_ enemy: DungeonEnemyActor) {
        guard let artwork = enemy.artworkNode else { return }
        let idleTexture = enemy.spawn.kind == .hollowClockGuard
            ? (enemy.baseAnimationClips.idle.first ?? enemy.animationClips.idle.first)
            : enemy.animationClips.idle.first
        guard let idleTexture else { return }

        // An active body clip owns the texture until its SKAction completes.
        // This check must happen before Clock Guard idle normalization: doing
        // it afterwards replaced every sampled chop frame with idle on the
        // very next scene update, even though the attack action kept running.
        if ["attack", "hit", "death"].contains(enemy.animationKey),
           artwork.action(forKey: "texture-animation") != nil {
            return
        }

        if enemy.spawn.kind == .hollowClockGuard {
            if enemy.holdsDefensivePose, let defensiveTexture = enemy.defensiveTexture {
                normalizeClockGuardDefensiveArtwork(artwork, texture: defensiveTexture)
                enemy.animationKey = "defensive-hold"
                return
            }
            normalizeClockGuardArtwork(artwork, texture: idleTexture)
        }

        if enemy.state == .dead { return }

        let shouldPlayIdle = (enemy.state == .idle || enemy.state == .chasing || enemy.state == .recovering)
            && enemy.animationClips.idle.count > 1
        let nextKey = shouldPlayIdle ? "idle-loop" : "idle-hold"
        guard enemy.animationKey != nextKey else { return }
        enemy.animationKey = nextKey
        artwork.removeAction(forKey: "texture-animation")

        if shouldPlayIdle {
            let frameTime: TimeInterval = enemy.spawn.kind == .gearHound ? 0.28 : 0.18
            artwork.run(
                .repeatForever(.animate(with: enemy.animationClips.idle, timePerFrame: frameTime, resize: false, restore: false)),
                withKey: "texture-animation"
            )
        } else {
            artwork.texture = idleTexture
        }
    }

    private func beginEnemyWindup(_ enemy: DungeonEnemyActor) {
        enemy.state = .windup
        enemy.attacksPerformed += 1
        enemy.intentLabel.text = enemyDisplayName(for: enemy)
        enemy.intentLabel.fontColor = UIColor(white: 0.04, alpha: 1)
        let pathReadBonus: TimeInterval = path.id == .priestess ? 1.28 : (path.id == .fool ? 1.10 : 1)
        let baseDuration = enemy.isEnraged ? enemy.spawn.telegraphDuration * 0.62 : enemy.spawn.telegraphDuration
        enemy.stateTimer = baseDuration * pathReadBonus
        enemy.telegraphTarget = player.position
        let warning = SKShapeNode(ellipseOf: CGSize(width: 74, height: 24))
        warning.name = "combat-effect"
        warning.position = enemy.telegraphTarget
        warning.fillColor = (enemy.isEnraged ? UIColor.systemOrange : UIColor.systemRed).withAlphaComponent(0.12)
        warning.strokeColor = .clear
        warning.glowWidth = 0
        warning.zPosition = 3
        warning.setScale(0.68)
        warning.alpha = 0.30
        addChild(warning)
        warning.run(.group([
            .scale(to: 1.15, duration: enemy.stateTimer),
            .fadeAlpha(to: 0.72, duration: enemy.stateTimer)
        ]))
        enemy.telegraphNode = warning

        let castColor = enemyColor(for: enemy.spawn.kind)
        spawnEnemyCastGlyph(
            at: enemy.node.position,
            color: castColor,
            radius: enemy.spawn.rank == .boss ? 48 : 34,
            duration: enemy.stateTimer
        )

        if enemy.spawn.rank == .boss || enemy.spawn.id == selectedEnemyID {
            publishState("\(enemy.spawn.kind.primaryAbilityName) · \(enemy.spawn.kind.combatHint)")
        }
    }

    /// Skill names are an ephemeral windup effect, not a permanent second
    /// label beside the creature's name and health bars.
    private func showSkillTelegraph(
        _ skillName: String,
        for enemy: DungeonEnemyActor,
        duration: TimeInterval
    ) {
        enemy.skillTelegraphNode?.removeFromParent()

        let telegraph = SKNode()
        telegraph.name = "combat-effect"
        telegraph.position = CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 84)
        telegraph.zPosition = 19
        telegraph.alpha = 0
        telegraph.setScale(0.76)

        let text = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        text.text = skillName
        text.fontSize = enemy.spawn.rank == .boss ? 26 : 21
        text.fontColor = .white
        text.horizontalAlignmentMode = .center
        text.verticalAlignmentMode = .center
        telegraph.addChild(text)

        addChild(telegraph)
        enemy.skillTelegraphNode = telegraph
        telegraph.run(.sequence([
            .group([
                .fadeAlpha(to: 1.0, duration: 0.14),
                .scale(to: 1.04, duration: 0.14)
            ]),
            .wait(forDuration: max(1.0, duration - 0.30)),
            .fadeOut(withDuration: 0.24),
            .removeFromParent()
        ]))
    }

    private func resolveEnemyAttack(_ enemy: DungeonEnemyActor) {
        enemy.telegraphNode?.removeFromParent()
        enemy.telegraphNode = nil
        enemy.skillTelegraphNode?.removeFromParent()
        enemy.skillTelegraphNode = nil
        enemy.state = .recovering
        enemy.stateTimer = attackStyle(for: enemy.spawn.kind) == .ranged ? 0.48 : 0.78
        enemy.attackCooldown = enemy.isEnraged ? 0.82 : 1.35
        enemy.intentLabel.text = enemyDisplayName(for: enemy)
        enemy.intentLabel.fontColor = UIColor(white: 0.05, alpha: 0.62)

        let hitCenter = enemy.telegraphTarget
        let hitRadius: CGFloat
        switch enemy.spawn.kind {
        case .gearHound: hitRadius = 72
        case .saltWraith: hitRadius = 50
        case .saltCrystalDeacon: hitRadius = 58
        case .mirrorShade: hitRadius = enemy.isEnraged ? 112 : 96
        case .stageAfterimage: hitRadius = 66
        case .saltCrystalGnawer: hitRadius = 76
        case .crackedMirrorMarionette: hitRadius = 64
        case .rustTideHookRaider: hitRadius = 72
        case .drownedMemoryGhost: hitRadius = 62
        case .oathScribe: hitRadius = 58
        case .facelessAttendant: hitRadius = 60
        case .hollowClockGuard: hitRadius = enemy.isEnraged ? 118 : 98
        case .lampDevourer, .prototypeHound: hitRadius = enemy.isEnraged ? 108 : 88
        case .reversePumpHeart: hitRadius = enemy.isEnraged ? 126 : 104
        case .seravianUnified: hitRadius = enemy.isEnraged ? 132 : 110
        case .whiteTideMotherCrystal: hitRadius = enemy.isEnraged ? 136 : 112
        case .firstUnderstudy: hitRadius = enemy.isEnraged ? 128 : 104
        case .deepTideDisciple: hitRadius = enemy.isEnraged ? 132 : 108
        case .mistCrownGovernor: hitRadius = enemy.isEnraged ? 124 : 100
        }

        switch attackStyle(for: enemy.spawn.kind) {
        case .ranged:
            animateEnemyAttack(enemy, toward: hitCenter)
            presentRangedAttackSignature(enemy, at: hitCenter, radius: hitRadius)
            let resolveRangedImpact = { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                if enemy.spawn.kind == .saltWraith || enemy.spawn.kind == .saltCrystalDeacon {
                    self.spawnSaltCrystalImpact(at: hitCenter, radius: hitRadius)
                    self.spawnSaltCrystalResidue(at: hitCenter)
                } else {
                    self.spawnImpact(at: hitCenter, color: self.enemyColor(for: enemy.spawn.kind), radius: hitRadius)
                }
                self.resolveEnemyHit(enemy, at: hitCenter, radius: hitRadius)
                let modifier = self.districtBossModifier(for: enemy)
                if modifier != .none {
                    self.performDistrictBossModifier(modifier, enemy: enemy, at: hitCenter, radius: hitRadius)
                } else if enemy.spawn.kind == .mirrorShade || enemy.spawn.kind == .crackedMirrorMarionette ||
                            enemy.spawn.kind == .stageAfterimage {
                    self.performMirrorReplay(enemy, originalTarget: hitCenter, radius: hitRadius * 0.72)
                } else if enemy.spawn.kind == .drownedMemoryGhost {
                    self.performClockEcho(enemy, at: hitCenter, radius: hitRadius * 0.66)
                } else if enemy.spawn.kind == .facelessAttendant {
                    self.applyCrownEdict(from: enemy, at: hitCenter, radius: hitRadius)
                } else if enemy.spawn.kind == .seravianUnified,
                          enemy.attacksPerformed.isMultiple(of: 2) {
                    self.performClockEcho(enemy, at: hitCenter, radius: hitRadius * 0.82)
                }
            }
            if enemy.spawn.kind == .saltWraith || enemy.spawn.kind == .saltCrystalDeacon {
                launchSaltCrystalVolley(
                    from: enemy.node.position,
                    to: hitCenter,
                    onImpact: resolveRangedImpact
                )
            } else {
                launchEnemyProjectile(
                    from: enemy.node.position,
                    to: hitCenter,
                    color: enemyColor(for: enemy.spawn.kind),
                    onImpact: resolveRangedImpact
                )
            }
        case .teleportMelee:
            switch enemy.spawn.kind {
            case .gearHound, .prototypeHound:
                performHoundPounce(enemy, at: hitCenter, radius: hitRadius)
            case .saltCrystalGnawer:
                performCrystalGroundSlam(enemy, at: hitCenter, radius: hitRadius)
            case .rustTideHookRaider:
                performHookSweep(enemy, at: hitCenter, radius: hitRadius)
            case .hollowClockGuard:
                performClockGuardStrike(enemy, at: hitCenter, radius: hitRadius)
            case .lampDevourer:
                performLampDevourerLeap(enemy, at: hitCenter, radius: hitRadius)
            default:
                performTeleportStrike(enemy, at: hitCenter, radius: hitRadius)
            }
        }
    }

    private func presentRangedAttackSignature(
        _ enemy: DungeonEnemyActor,
        at target: CGPoint,
        radius: CGFloat
    ) {
        switch enemy.spawn.kind {
        case .saltCrystalDeacon:
            spawnTargetWarning(at: target, color: .systemCyan, radius: radius, duration: 0.38)
            spawnResidualArcana(at: enemy.node.position, color: .systemCyan, count: 7)
        case .stageAfterimage:
            spawnResidualArcana(at: target, color: .systemPink, count: 7)
        case .drownedMemoryGhost:
            spawnTargetWarning(at: target, color: .systemCyan, radius: radius * 0.90, duration: 0.46)
            spawnAreaBurst(at: enemy.node.position, color: .systemBlue, radius: radius * 0.46)
        case .facelessAttendant:
            spawnTargetWarning(at: target, color: .systemIndigo, radius: radius * 0.86, duration: 0.48)
            spawnResidualArcana(at: enemy.node.position, color: .systemPurple, count: 6)
        case .reversePumpHeart:
            spawnAreaBurst(at: enemy.node.position, color: .systemBlue, radius: radius * 0.55)
            spawnResidualArcana(at: enemy.node.position, color: .systemCyan, count: 10)
        case .seravianUnified:
            spawnAreaBurst(at: enemy.node.position, color: .systemIndigo, radius: radius * 0.48)
            if enemy.attacksPerformed.isMultiple(of: 2) {
                performClockEcho(enemy, at: target, radius: radius * 0.62)
            }
        case .whiteTideMotherCrystal:
            spawnTargetWarning(at: target, color: .systemTeal, radius: radius * 0.82, duration: 0.42)
            spawnResidualArcana(at: target, color: .systemCyan, count: 9)
        case .firstUnderstudy:
            spawnResidualArcana(at: target, color: .systemPurple, count: 9)
            performMirrorReplay(enemy, originalTarget: target, radius: radius * 0.58)
        case .deepTideDisciple:
            spawnTargetWarning(at: target, color: .systemBlue, radius: radius * 0.78, duration: 0.34)
            spawnResidualArcana(at: enemy.node.position, color: .systemBlue, count: 8)
        case .mistCrownGovernor:
            spawnTargetWarning(at: target, color: .systemIndigo, radius: radius * 0.90, duration: 0.52)
            spawnAreaBurst(at: enemy.node.position, color: .systemPurple, radius: radius * 0.52)
        default:
            break
        }
    }

    private func refreshEnemyIntent(_ enemy: DungeonEnemyActor) {
        guard enemy.isAlive else {
            enemy.intentLabel.isHidden = true
            return
        }
        if enemy.staggeredTurns > 0 {
            enemy.intentLabel.isHidden = false
            enemy.intentLabel.text = enemyDisplayName(for: enemy)
            enemy.intentLabel.fontColor = UIColor(white: 0.04, alpha: 1)
            return
        }
        if enemy.spawn.rank == .boss {
            // The full-width boss HUD owns this information; an actor label
            // would either cover the portrait or collide with the HUD.
            enemy.intentLabel.isHidden = true
            return
        }
        enemy.intentLabel.isHidden = false
        enemy.intentLabel.text = enemyDisplayName(for: enemy)
        enemy.intentLabel.fontColor = UIColor(white: 0.04, alpha: 1)
    }

    /// Exact next attack preview for deliberate turn-based decisions.
    private func predictedEnemyIntent(
        for enemy: DungeonEnemyActor,
        upcoming: Bool
    ) -> (name: String, damage: Int) {
        let attackNumber = upcoming ? enemy.attacksPerformed + 1 : enemy.attacksPerformed
        var name = enemy.spawn.kind.primaryAbilityName
        var damage = enemy.spawn.attackDamage + (enemy.isEnraged ? 5 : 0)

        if enemy.spawn.kind == .hollowClockGuard,
           attackNumber.isMultiple(of: 3) {
            name = "第十三敲击"
            damage += max(5, enemy.spawn.attackDamage / 2)
        }

        if enemy.spawn.kind == .seravianUnified {
            let isEcho = attackNumber.isMultiple(of: 2)
            let isEdict = attackNumber.isMultiple(of: 3)
            if isEdict {
                damage += max(7, enemy.spawn.attackDamage / 2)
            }
            switch (isEcho, isEdict) {
            case (true, true): name = "归一双响"
            case (true, false): name = "双重校时"
            case (false, true): name = "归一校时"
            case (false, false): break
            }
        }

        return (name, damage)
    }

    private func attackStyle(for kind: DungeonEnemyKind) -> DungeonEnemyAttackStyle {
        switch kind {
        case .saltWraith, .saltCrystalDeacon, .mirrorShade, .stageAfterimage,
             .crackedMirrorMarionette, .drownedMemoryGhost, .oathScribe,
             .facelessAttendant,
             .reversePumpHeart, .seravianUnified, .whiteTideMotherCrystal,
             .firstUnderstudy, .deepTideDisciple, .mistCrownGovernor:
            .ranged
        case .gearHound, .saltCrystalGnawer, .rustTideHookRaider,
             .hollowClockGuard, .lampDevourer, .prototypeHound:
            .teleportMelee
        }
    }

    private func districtBossModifier(for enemy: DungeonEnemyActor) -> DistrictBossModifier {
        guard enemy.spawn.rank == .boss else { return .none }
        if level.id.hasPrefix("salt-warehouse-") { return .saltFracture }
        if level.id.hasPrefix("mirror-theater-") { return .mirrorEncore }
        if level.id.hasPrefix("tide-gate-") { return .returningTide }
        if level.id.hasPrefix("mist-crown-") { return .crownEdict }
        return .none
    }

    private func performDistrictBossModifier(
        _ modifier: DistrictBossModifier,
        enemy: DungeonEnemyActor,
        at center: CGPoint,
        radius: CGFloat
    ) {
        switch modifier {
        case .none:
            break
        case .saltFracture:
            spawnResidualHazard(from: enemy, at: center, radius: radius * 0.62)
            publishState("盐晶裂地 · 离开残留晶区")
        case .mirrorEncore:
            performMirrorReplay(enemy, originalTarget: center, radius: radius * 0.74)
            publishState("镜幕返场 · 对称位置即将复演")
        case .returningTide:
            performClockEcho(enemy, at: center, radius: radius * 0.76)
            publishState("回潮冲刷 · 原落点将再次爆发")
        case .crownEdict:
            applyCrownEdict(from: enemy, at: center, radius: radius)
        }
    }

    private func applyCrownEdict(from enemy: DungeonEnemyActor, at center: CGPoint, radius: CGFloat) {
        guard distance(from: player.position, to: center) <= radius else { return }
        let extensionTime: TimeInterval = path.id == .star ? 0.28 : 0.62
        for skillID in DungeonSkillID.allCases {
            skillCooldowns[skillID, default: 0] += extensionTime
        }
        spawnFloatingText("禁令延长", at: player.position, color: .systemIndigo)
        spawnResidualArcana(at: player.position, color: .systemIndigo, count: 6)
        publishState(path.id == .star ? "星轨抵消部分禁令" : "雾冠禁令 · 技能冷却延长", feedback: true, force: true)
    }

    private func resolveEnemyHit(_ enemy: DungeonEnemyActor, at center: CGPoint, radius: CGFloat) {
        if distance(from: player.position, to: center) <= radius {
            if playerReactionCharges > 0 {
                playerReactionCharges -= 1
                spawnFloatingText("错位闪避", at: player.position, color: .systemCyan)
                spawnTarotImpactVFX(at: player.position, size: 112)
                spawnResidualArcana(at: player.position, color: .systemCyan, count: 5)
                gainOmen(2, reason: "预判正确")
                publishState("错位闪步 · 规避一次攻击", feedback: true, force: true)
                return
            }
            if path.id == .fool, enemy.attacksPerformed.isMultiple(of: 3) {
                spawnFloatingText("替身受击", at: player.position, color: .systemPurple)
                spawnTarotImpactVFX(at: player.position, size: 108)
                publishState("纸人代身 · 代受伤害", feedback: true, force: true)
                return
            }
            if path.id == .magician, playerCounterCharges > 0 {
                playerCounterCharges -= 1
                spawnFloatingText("术式反写", at: player.position, color: .systemPurple)
                spawnTarotImpactVFX(at: enemy.node.position, size: 124)
                applyDamage(max(14, enemy.spawn.attackDamage * 2), to: enemy, knockback: 0)
                publishState("魔术反制 · 敌方术式被改写", feedback: true, force: true)
                return
            }
            if path.id == .justice, playerParryCharges > 0 {
                playerParryCharges -= 1
                spawnFloatingText("完美衡反", at: player.position, color: .systemYellow)
                spawnAreaBurst(at: player.position, color: .systemYellow, radius: 72)
                applyDamage(max(12, enemy.spawn.attackDamage), to: enemy, knockback: 0)
                publishState("衡盾反击 · 伤害无效", feedback: true, force: true)
                return
            }
            let rageBonus = enemy.isEnraged ? 5 : 0
            var attackDamage = enemy.spawn.attackDamage + rageBonus
            if enemy.spawn.kind == .hollowClockGuard,
               enemy.attacksPerformed.isMultiple(of: 3) {
                attackDamage += max(5, enemy.spawn.attackDamage / 2)
                spawnFloatingText(
                    "第十三敲击",
                    at: CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 50),
                    color: .white,
                    holdDuration: 1.1,
                    fontSize: 20
                )
            }
            if enemy.spawn.kind == .seravianUnified,
               enemy.attacksPerformed.isMultiple(of: 3) {
                attackDamage += max(7, enemy.spawn.attackDamage / 2)
                spawnFloatingText("归一校时", at: enemy.node.position, color: .systemIndigo)
            }
            if playerGuardCharges > 0 {
                playerGuardCharges -= 1
                let retainedDamage: CGFloat = path.id == .chariot ? 0.35 : 0.58
                attackDamage = max(1, Int(CGFloat(attackDamage) * retainedDamage))
                spawnFloatingText(path.id == .chariot ? "意志承伤" : "防护抵消", at: player.position, color: .systemCyan)
                publishState(
                    path.id == .chariot ? "战车壁垒 · 大幅减伤" : "防护生效 · 本次伤害降低",
                    feedback: true,
                    force: true
                )
            }
            dealDamageToPlayer(attackDamage)
            if enemy.spawn.kind == .saltWraith {
                let erosion: TimeInterval = path.id == .star ? 0.25 : 0.75
                for skillID in DungeonSkillID.allCases {
                    skillCooldowns[skillID, default: 0] += erosion
                }
                publishState(path.id == .star ? "星轨稳定 · 抵消大部分失秒侵蚀" : "失秒侵蚀 · 技能冷却延长", feedback: true, force: true)
            } else if enemy.spawn.kind == .oathScribe {
                let edict: TimeInterval = path.id == .star ? 0.18 : 0.45
                for skillID in DungeonSkillID.allCases {
                    skillCooldowns[skillID, default: 0] += edict
                }
                publishState("禁令落款 · 技能冷却延长", feedback: true, force: true)
            } else if enemy.spawn.kind == .lampDevourer {
                let drain: TimeInterval = path.id == .star ? 0.35 : 1
                skillCooldowns[.ultimate, default: 0] += drain
                publishState(path.id == .star ? "星火未熄 · 吞光削弱" : "吞光 · 终极技能延后", feedback: true, force: true)
            } else if enemy.spawn.kind == .reversePumpHeart {
                restoreEnemyHealth(enemy, fraction: 0.06, label: "记忆回灌")
            } else if enemy.spawn.kind == .seravianUnified,
                      enemy.attacksPerformed.isMultiple(of: 3) {
                applyUnifiedEdict()
            }
        } else {
            spawnFloatingText("闪避", at: player.position, color: .systemCyan)
            publishState("闪避成功")
        }
    }

    private func applyUnifiedEdict() {
        let extensionTime: TimeInterval
        switch path.id {
        case .star:
            extensionTime = 0.22
            publishState("星轨校准 · 抵消大部分归一禁令", feedback: true, force: true)
        case .priestess:
            extensionTime = 0.42
            publishState("预见锚定 · 缩短归一禁令", feedback: true, force: true)
        case .chariot:
            extensionTime = 0.55
            publishState("意志固守 · 承受归一禁令", feedback: true, force: true)
        default:
            extensionTime = 0.85
            publishState("归一禁令 · 全部技能冷却延长", feedback: true, force: true)
        }
        for skillID in DungeonSkillID.allCases {
            skillCooldowns[skillID, default: 0] += extensionTime
        }
        spawnResidualArcana(at: player.position, color: .systemIndigo, count: 7)
    }

    private func performMirrorReplay(
        _ enemy: DungeonEnemyActor,
        originalTarget: CGPoint,
        radius: CGFloat
    ) {
        let reflected = constrained(
            CGPoint(
                x: playerZone.center.x * 2 - originalTarget.x,
                y: playerZone.center.y * 2 - originalTarget.y
            ),
            to: playerZone,
            inset: 5
        )
        let color = UIColor.systemPurple
        let warning = SKShapeNode(ellipseOf: CGSize(width: radius * 2, height: radius * 0.72))
        warning.name = "combat-effect"
        warning.position = reflected
        warning.fillColor = color.withAlphaComponent(0.14)
        warning.strokeColor = color.withAlphaComponent(0.72)
        warning.lineWidth = 1.5
        warning.zPosition = 5
        addChild(warning)
        warning.run(.sequence([
            .wait(forDuration: 0.42),
            .run { [weak self, weak enemy, weak warning] in
                guard let self, let enemy, enemy.isAlive else { return }
                warning?.removeFromParent()
                self.spawnImpact(at: reflected, color: color, radius: radius)
                self.resolveEnemyHit(enemy, at: reflected, radius: radius)
            },
            .removeFromParent()
        ]))
    }

    private func performClockEcho(_ enemy: DungeonEnemyActor, at center: CGPoint, radius: CGFloat) {
        let color = UIColor.systemOrange
        let echo = SKShapeNode(ellipseOf: CGSize(width: radius * 2, height: radius * 0.72))
        echo.name = "combat-effect"
        echo.position = center
        echo.fillColor = color.withAlphaComponent(0.10)
        echo.strokeColor = color.withAlphaComponent(0.74)
        echo.lineWidth = 2
        echo.zPosition = 5
        addChild(echo)
        echo.run(.sequence([
            .group([.scale(to: 1.12, duration: 0.58), .fadeAlpha(to: 0.82, duration: 0.58)]),
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                self.spawnGroundImpact(at: center, color: color, radius: radius)
                self.resolveEnemyHit(enemy, at: center, radius: radius)
            },
            .fadeOut(withDuration: 0.12),
            .removeFromParent()
        ]))
    }

    private func performHoundPounce(_ enemy: DungeonEnemyActor, at target: CGPoint, radius: CGFloat) {
        if presentationOnly {
            // Chapter One's portrait presentation uses the authored enemy
            // attack as a ranged/cast beat. Keep the fallback actor on its
            // formation slot so it agrees with the Unity 3D path instead of
            // revealing the old gameplay-only pounce movement.
            spawnResidualArcana(at: enemy.node.position, color: .systemOrange, count: 7)
            enemy.node.removeAction(forKey: "hound-pounce")
            enemy.node.run(.sequence([
                .run { [weak self, weak enemy] in
                    guard let self, let enemy, enemy.isAlive else { return }
                    self.animateEnemyAttack(enemy, toward: target)
                },
                .wait(forDuration: 1.08),
                .run { [weak self, weak enemy] in
                    guard let self, let enemy, enemy.isAlive else { return }
                    self.spawnEnemySlash(at: target, color: .systemOrange, radius: radius)
                    self.spawnGroundImpact(at: target, color: .systemRed, radius: radius * 0.64)
                    self.resolveEnemyHit(enemy, at: target, radius: radius)
                    if enemy.spawn.kind == .prototypeHound {
                        self.schedulePrototypeFollowup(enemy)
                    }
                },
                .wait(forDuration: 0.10)
            ]), withKey: "hound-pounce")
            return
        }

        let home = enemy.homePosition
        let vector = CGVector(dx: target.x - home.x, dy: target.y - home.y)
        let length = max(1, hypot(vector.dx, vector.dy))
        let landing = CGPoint(
            x: target.x - vector.dx / length * 42,
            y: target.y - vector.dy / length * 42
        )
        spawnResidualArcana(at: home, color: .systemOrange, count: 7)
        let crouch = SKAction.scale(to: 0.92, duration: 0.10)
        let leap = SKAction.group([
            .move(to: landing, duration: 0.24),
            .scale(to: 1.08, duration: 0.24)
        ])
        leap.timingMode = .easeIn
        enemy.node.run(.sequence([
            crouch,
            leap,
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                self.animateEnemyAttack(enemy, toward: target)
            },
            .wait(forDuration: 1.08),
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                self.spawnEnemySlash(at: target, color: .systemOrange, radius: radius)
                self.spawnGroundImpact(at: target, color: .systemRed, radius: radius * 0.64)
                self.resolveEnemyHit(enemy, at: target, radius: radius)
                if enemy.spawn.kind == .prototypeHound {
                    self.schedulePrototypeFollowup(enemy)
                }
            },
            .wait(forDuration: 0.10),
            .group([.move(to: home, duration: 0.24), .scale(to: 1, duration: 0.24)])
        ]), withKey: "hound-pounce")
    }

    private func performCrystalGroundSlam(_ enemy: DungeonEnemyActor, at target: CGPoint, radius: CGFloat) {
        spawnTargetWarning(at: target, color: .systemCyan, radius: radius, duration: 0.24)
        run(.sequence([
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                self.animateEnemyAttack(enemy, toward: target)
            },
            .wait(forDuration: 1.08),
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                self.spawnSaltCrystalImpact(at: target, radius: radius)
                self.spawnMaterialHitFragments(at: target, color: .systemCyan, heavy: true)
                self.resolveEnemyHit(enemy, at: target, radius: radius)
                self.spawnResidualHazard(from: enemy, at: target, radius: radius * 0.56)
            }
        ]))
    }

    private func performHookSweep(_ enemy: DungeonEnemyActor, at target: CGPoint, radius: CGFloat) {
        animateEnemyAttack(enemy, toward: target)
        let color = UIColor.systemBlue
        launchEnemyProjectile(from: enemy.node.position, to: target, color: color) { [weak self, weak enemy] in
            guard let self, let enemy, enemy.isAlive else { return }
            self.spawnEnemySlash(at: target, color: color, radius: radius * 1.18)
            self.resolveEnemyHit(enemy, at: target, radius: radius)
            self.performClockEcho(enemy, at: target, radius: radius * 0.70)
        }
    }

    private func performClockGuardStrike(_ enemy: DungeonEnemyActor, at target: CGPoint, radius: CGFloat) {
        spawnTargetWarning(at: target, color: .systemOrange, radius: radius, duration: 0.34)
        run(.sequence([
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                self.animateEnemyAttack(enemy, toward: target)
            },
            .wait(forDuration: 1.08),
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                self.spawnGroundImpact(at: target, color: .systemOrange, radius: radius)
                self.spawnAreaBurst(at: target, color: .systemYellow, radius: radius * 0.72)
                self.resolveEnemyHit(enemy, at: target, radius: radius)
            }
        ]))
    }

    private func performLampDevourerLeap(_ enemy: DungeonEnemyActor, at target: CGPoint, radius: CGFloat) {
        let color = UIColor.systemPurple
        spawnTeleportPortal(at: enemy.homePosition, color: color, opening: false)
        animateEnemyAttack(enemy, toward: target)
        performTeleportStrike(enemy, at: target, radius: radius)
        spawnResidualArcana(at: target, color: color, count: 10)
    }

    private func performTeleportStrike(
        _ enemy: DungeonEnemyActor,
        at target: CGPoint,
        radius: CGFloat,
        allowsFollowup: Bool = true
    ) {
        enemy.node.removeAction(forKey: "teleport-strike")
        let homePosition = enemy.homePosition
        let approachVector = CGVector(dx: homePosition.x - target.x, dy: homePosition.y - target.y)
        let approachLength = max(1, hypot(approachVector.dx, approachVector.dy))
        let strikePosition = CGPoint(
            x: target.x + approachVector.dx / approachLength * 34,
            y: target.y + approachVector.dy / approachLength * 34
        )
        let color = enemyColor(for: enemy.spawn.kind)
        spawnTeleportPortal(at: homePosition, color: color, opening: false)
        spawnTeleportPortal(at: strikePosition, color: color, opening: true)
        enemy.node.run(.sequence([
            .fadeOut(withDuration: 0.08),
            .move(to: strikePosition, duration: 0),
            .fadeIn(withDuration: 0.08),
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                self.animateEnemyAttack(enemy, toward: target)
                // Damage is intentionally resolved after the authored strike
                // reaches its impact frame, never when the unit reappears.
                self.run(.wait(forDuration: 1.08)) { [weak self, weak enemy] in
                    guard let self, let enemy, enemy.isAlive else { return }
                    self.spawnEnemySlash(at: target, color: color, radius: radius)
                    self.spawnGroundImpact(at: target, color: color, radius: radius * 0.72)
                    self.resolveEnemyHit(enemy, at: target, radius: radius)
                    let modifier = self.districtBossModifier(for: enemy)
                    if modifier != .none {
                        self.performDistrictBossModifier(modifier, enemy: enemy, at: target, radius: radius)
                    } else if enemy.spawn.kind == .lampDevourer || enemy.spawn.kind == .saltCrystalGnawer {
                        self.spawnResidualHazard(from: enemy, at: target, radius: radius * 0.58)
                    } else if enemy.spawn.kind == .rustTideHookRaider {
                        self.performClockEcho(enemy, at: target, radius: radius * 0.70)
                    } else if enemy.spawn.kind == .prototypeHound, allowsFollowup {
                        self.schedulePrototypeFollowup(enemy)
                    }
                }
            },
            // Hold at the strike point until the authored animation reaches
            // its impact frame and damage feedback has played on the hero.
            .wait(forDuration: 1.18),
            .run { [weak self] in self?.spawnTeleportPortal(at: strikePosition, color: color, opening: false) },
            .fadeOut(withDuration: 0.08),
            .move(to: homePosition, duration: 0),
            .fadeIn(withDuration: 0.10)
        ]), withKey: "teleport-strike")
    }

    private func schedulePrototypeFollowup(_ enemy: DungeonEnemyActor) {
        run(.sequence([
            .wait(forDuration: 0.34),
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                let nextTarget = self.player.position
                self.spawnTargetWarning(
                    at: nextTarget,
                    color: self.enemyColor(for: enemy.spawn.kind),
                    radius: 54,
                    duration: 0.24
                )
                self.run(.sequence([
                    .wait(forDuration: 0.24),
                    .run { [weak self, weak enemy] in
                        guard let self, let enemy, enemy.isAlive else { return }
                        self.performTeleportStrike(enemy, at: nextTarget, radius: 58, allowsFollowup: false)
                    }
                ]))
            }
        ]))
    }

    private func spawnResidualHazard(from enemy: DungeonEnemyActor, at center: CGPoint, radius: CGFloat) {
        let color = enemyColor(for: enemy.spawn.kind)
        let stain = SKShapeNode(ellipseOf: CGSize(width: radius * 2, height: radius * 0.66))
        stain.name = "combat-effect"
        stain.position = center
        stain.fillColor = color.withAlphaComponent(0.17)
        stain.strokeColor = .clear
        stain.blendMode = .add
        stain.zPosition = 3
        addChild(stain)
        spawnResidualArcana(at: center, color: color, count: 7)
        stain.run(.sequence([
            .group([.scale(to: 1.10, duration: 0.72), .fadeAlpha(to: 0.72, duration: 0.72)]),
            .run { [weak self, weak enemy] in
                guard let self, let enemy, enemy.isAlive else { return }
                self.spawnGroundImpact(at: center, color: color, radius: radius)
                self.resolveEnemyHit(enemy, at: center, radius: radius)
            },
            .fadeOut(withDuration: 0.22),
            .removeFromParent()
        ]))
    }

    private func restoreEnemyHealth(_ enemy: DungeonEnemyActor, fraction: CGFloat, label: String) {
        guard enemy.isAlive else { return }
        let amount = max(1, Int(CGFloat(enemy.spawn.maxHealth) * fraction))
        let oldHealth = enemy.health
        enemy.health = min(enemy.spawn.maxHealth, enemy.health + amount)
        let restored = enemy.health - oldHealth
        guard restored > 0 else { return }
        let healthFraction = CGFloat(enemy.health) / CGFloat(enemy.spawn.maxHealth)
        animateEnemyHealthFill(enemy, fraction: healthFraction, duration: 0.18)
        spawnFloatingText("\(label) +\(restored)", at: enemy.node.position, color: .systemRed)
        spawnResidualArcana(at: enemy.node.position, color: .systemCyan, count: 6)
    }

    private func constrained(
        _ point: CGPoint,
        to zone: (center: CGPoint, radius: CGFloat),
        inset: CGFloat
    ) -> CGPoint {
        let allowedRadius = max(0, zone.radius - inset)
        let dx = point.x - zone.center.x
        let dy = point.y - zone.center.y
        let pointDistance = hypot(dx, dy)
        guard pointDistance > allowedRadius, pointDistance > 0 else { return point }
        return CGPoint(
            x: zone.center.x + dx / pointDistance * allowedRadius,
            y: zone.center.y + dy / pointDistance * allowedRadius
        )
    }

    /// 0.72 s anticipation + 0.38 s flight. Native contact uses the same 1.10 s beat.
    private func presentMemoryLeechCast(_ enemy: DungeonEnemyActor) {
        guard enemy.isAlive else { return }
        playEnemyClip(enemy, textures: enemy.animationClips.attack, key: "attack", timePerFrame: 0.13)
        let origin = CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 35)
        let venom = UIColor(red: 0.46, green: 0.77, blue: 0.08, alpha: 1)
        let charge = SKShapeNode(ellipseOf: CGSize(width: 15, height: 10))
        charge.position = origin; charge.fillColor = venom; charge.strokeColor = .yellow
        charge.glowWidth = 5; charge.zPosition = 35; charge.setScale(0.2)
        addChild(charge)
        charge.run(.sequence([.scale(to: 1.25, duration: 0.72), .removeFromParent()]))
        run(.sequence([.wait(forDuration: 0.72), .run { [weak self, weak enemy] in
            guard let self, let enemy, enemy.isAlive else { return }
            let target = self.player.position
            for index in 0..<7 {
                let blob = SKShapeNode(ellipseOf: CGSize(width: index == 0 ? 22 : 7, height: index == 0 ? 14 : 5))
                blob.fillColor = venom; blob.strokeColor = UIColor(red: 0.77, green: 0.94, blue: 0.28, alpha: 1)
                blob.lineWidth = 1.5; blob.glowWidth = 2; blob.zPosition = 36
                blob.position = origin; self.addChild(blob)
                let delay = Double(index) * 0.014
                blob.run(.sequence([.wait(forDuration: delay), .customAction(withDuration: 0.38) { node, elapsed in
                    let t = elapsed / 0.38
                    node.position = CGPoint(x: origin.x + (target.x-origin.x)*t + CGFloat(index-3)*2*t,
                                            y: origin.y + (target.y-origin.y)*t + sin(t * .pi)*30)
                }, .removeFromParent()]))
            }
            self.run(.sequence([.wait(forDuration: 0.38), .run { [weak self] in
                guard let self else { return }
                self.spawnAreaBurst(at: target, color: venom, radius: 24)
                for i in 0..<9 {
                    let drop = SKShapeNode(ellipseOf: CGSize(width: 5, height: 9))
                    drop.fillColor = venom; drop.strokeColor = .clear; drop.position = target; drop.zPosition = 34
                    self.addChild(drop)
                    let angle = CGFloat(i) * .pi * 2 / 9
                    drop.run(.sequence([.moveBy(x: cos(angle)*24, y: sin(angle)*18, duration: 0.16),
                        .group([.moveBy(x: 0, y: -16, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
                }
            }]))
        }]))
    }

    private func animateEnemyAttack(_ enemy: DungeonEnemyActor, toward target: CGPoint) {
        faceEnemy(enemy, toward: target)
        if enemy.spawn.kind == .hollowClockGuard,
           let artwork = enemy.artworkNode,
           let idleTexture = enemy.animationClips.idle.first {
            // Shielded and unshielded clips share one 512 px canvas and one
            // bottom-center anchor, so the full authored attack can play
            // without the actor or barrier changing apparent size.
            enemy.animationKey = "attack"
            artwork.removeAction(forKey: "texture-animation")
            normalizeClockGuardArtwork(artwork, texture: idleTexture)
            let attackTextures = enemy.animationClips.attack
            if attackTextures.count > 1 {
                let frameTime = ProcessInfo.processInfo.arguments.contains("--preview-slow-animation")
                    ? 0.24
                    : 0.09
                artwork.run(.animate(
                    with: attackTextures,
                    timePerFrame: frameTime,
                    resize: false,
                    restore: true
                ), withKey: "texture-animation")
            }
            // The imported guard's charged axe animation is the attack. Do not
            // add a second whole-body rotation here: the old +/-0.1 rad
            // sequence made the actor visibly rock from side to side and was
            // especially confusing when comparing the Simulator fallback to
            // the Unity 3D clip. Keep the actor on its authored formation slot.
            return
        }
        // Keep the authored attack readable on a phone. The old 75 ms cadence
        // made a six-frame strike look like a single teleporting hit.
        let frameTime = ProcessInfo.processInfo.arguments.contains("--preview-slow-animation") ? 0.30 : 0.18
        playEnemyClip(enemy, textures: enemy.animationClips.attack, key: "attack", timePerFrame: frameTime)
    }

    private func normalizeClockGuardArtwork(_ artwork: SKSpriteNode, texture: SKTexture) {
        artwork.texture = texture
        artwork.size = fittedClockGuardArtworkSize(for: texture, height: 231)
        artwork.xScale = 1
        artwork.yScale = 1
        artwork.zRotation = 0
    }

    private func normalizeClockGuardDefensiveArtwork(_ artwork: SKSpriteNode, texture: SKTexture) {
        artwork.texture = texture
        artwork.size = fittedArtworkSize(for: texture, within: CGSize(width: 189, height: 231))
        artwork.xScale = 1
        artwork.yScale = 1
        artwork.zRotation = 0
    }

    private func fittedClockGuardArtworkSize(for texture: SKTexture, height: CGFloat) -> CGSize {
        let textureSize = texture.size()
        guard textureSize.height > 0 else { return CGSize(width: 189, height: height) }
        return CGSize(width: height * textureSize.width / textureSize.height, height: height)
    }

    private func spawnClockGuardDashAfterimages(
        _ enemy: DungeonEnemyActor,
        from origin: CGPoint,
        to strikePoint: CGPoint
    ) {
        guard let artwork = enemy.artworkNode, let texture = artwork.texture else { return }
        for index in 1...3 {
            let progress = CGFloat(index) / 4
            let echo = SKSpriteNode(texture: texture)
            echo.name = "combat-effect"
            echo.anchorPoint = artwork.anchorPoint
            echo.size = artwork.size
            echo.position = CGPoint(
                x: origin.x + (strikePoint.x - origin.x) * progress,
                y: origin.y + (strikePoint.y - origin.y) * progress + artwork.position.y
            )
            echo.color = .systemOrange
            echo.colorBlendFactor = 0.58
            echo.blendMode = .add
            echo.alpha = 0
            echo.zPosition = 18
            addChild(echo)
            echo.run(.sequence([
                .wait(forDuration: 0.16 + TimeInterval(index) * 0.075),
                .fadeAlpha(to: 0.22, duration: 0.05),
                .fadeOut(withDuration: 0.18),
                .removeFromParent()
            ]))
        }
    }

    /// Plays only authored bitmap frames. It deliberately applies no body
    /// squash, stretch, rotation or non-uniform scale to the illustration.
    private func playEnemyClip(
        _ enemy: DungeonEnemyActor,
        textures: [SKTexture],
        key: String,
        timePerFrame: TimeInterval
    ) {
        guard let artwork = enemy.artworkNode, textures.count > 1 else { return }
        enemy.animationKey = key
        artwork.removeAction(forKey: "texture-animation")
        artwork.run(.animate(
            with: textures,
            timePerFrame: timePerFrame,
            resize: false,
            restore: key != "death"
        ), withKey: "texture-animation")
    }

    /// Frontal formation clips already look toward the hero and must not be
    /// mirrored as targets move between slots. Legacy side-view art may flip,
    /// but scale and aspect ratio always remain fixed.
    private func faceEnemy(_ enemy: DungeonEnemyActor, toward target: CGPoint) {
        guard let artwork = enemy.artworkNode else { return }
        // These assets are authored as south-facing combat strips. Mirroring
        // them swaps masks, weapons and facial asymmetry even though their
        // bodies still appear frontal, causing the visible "turn around" bug.
        let hasAuthoredSouthFacingArt: Set<DungeonEnemyKind> = [
            .gearHound, .prototypeHound, .saltWraith, .mirrorShade,
            .saltCrystalGnawer, .crackedMirrorMarionette,
            .rustTideHookRaider, .oathScribe, .hollowClockGuard
        ]
        if hasAuthoredSouthFacingArt.contains(enemy.spawn.kind)
            || enemy.spawn.rank == .boss {
            artwork.xScale = 1
            return
        }
        artwork.xScale = target.x <= enemy.node.position.x ? 1 : -1
    }

    private func dealDamageToPlayer(_ damage: Int) {
        guard playerInvulnerability <= 0 else {
            spawnFloatingText("免疫", at: player.position, color: .systemCyan)
            return
        }
        let resolvedDamage = path.id == .chariot ? max(1, Int(CGFloat(damage) * 0.78)) : damage
        combat.playerHealth = max(0, combat.playerHealth - resolvedDamage)
        shakeCamera()
        spawnDamageNumber(resolvedDamage, at: playerCombatNumberAnchor(), color: .systemRed)
        publishState("受到 \(resolvedDamage) 点伤害", feedback: true, force: true)
    }

    private func applyDamage(_ damage: Int, to enemy: DungeonEnemyActor, knockback: CGFloat) {
        guard enemy.isAlive else { return }
        let exposureMultiplier: CGFloat
        if enemy.exposedTurns > 0 {
            exposureMultiplier = enemy.spawn.rank == .boss ? 1.18 : 1.25
            spawnFloatingText(
                enemy.spawn.rank == .boss ? "暴露 +18%" : "破绽 +25%",
                at: enemy.node.position,
                color: .systemCyan
            )
        } else {
            exposureMultiplier = 1
        }
        let damage = max(1, Int(CGFloat(damage) * damageMultiplier * exposureMultiplier))
        enemy.telegraphNode?.removeFromParent()
        enemy.telegraphNode = nil
        enemy.state = .hitStun
        enemy.stateTimer = enemy.spawn.rank == .boss ? 0.10 : 0.19
        if !presentationOnly {
            enemy.health = max(0, enemy.health - damage)
        }
        let fraction = CGFloat(enemy.health) / CGFloat(enemy.spawn.maxHealth)
        animateEnemyHealthFill(enemy, fraction: fraction, duration: 0.16)
        playEnemyClip(enemy, textures: enemy.animationClips.hit, key: "hit", timePerFrame: 0.07)
        if enemy.animationClips.hit.count <= 1 {
            // Safe fallback until a production hit strip exists: a material
            // flash on the authored sprite, never a warped body transform.
            enemy.artworkNode?.run(.sequence([
                .colorize(with: .white, colorBlendFactor: 0.72, duration: 0.035),
                .colorize(withColorBlendFactor: 0, duration: 0.11)
            ]), withKey: "hit-material-flash")
        }
        spawnMaterialHitFragments(
            at: CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 22),
            color: enemyColor(for: enemy.spawn.kind),
            heavy: enemy.spawn.rank != .normal
        )
        // Chapter-one CombatCore owns the authoritative hit amount and its
        // large red number. Do not emit the retired yellow legacy value.
        if !presentationOnly {
            spawnDamageNumber(damage, at: enemyCombatNumberAnchor(enemy), color: .systemYellow)
        }
        // Enemies hold authored combat positions. Physical attacks communicate
        // force through hit flash, particles and camera impulse rather than
        // moving the unit across the painted arena.

        if enemy.spawn.rank == .boss, fraction <= 0.5, !enemy.isEnraged, enemy.health > 0 {
            enrageBoss(enemy)
        }

        if enemy.health == 0 {
            defeatEnemy(enemy)
        }
    }

    /// The fill path begins at x = 0, so scaling keeps its left edge fixed and
    /// drains health from the right while the containing bar remains centered.
    private func animateEnemyHealthFill(
        _ enemy: DungeonEnemyActor,
        fraction: CGFloat,
        duration: TimeInterval
    ) {
        let clampedFraction = max(0, min(1, fraction))
        let action = SKAction.scaleX(to: clampedFraction, duration: duration)
        action.timingMode = .easeOut
        enemy.healthFill.run(action, withKey: "enemy-health-fill")
    }

    private func enrageBoss(_ enemy: DungeonEnemyActor) {
        enemy.isEnraged = true
        enemy.attackCooldown = 0.25
        spawnAreaBurst(at: enemy.node.position, color: .systemRed, radius: 126)
        enemy.visualNode.run(.repeatForever(.sequence([
            .colorize(with: .systemRed, colorBlendFactor: 0.55, duration: 0.24),
            .colorize(withColorBlendFactor: 0.08, duration: 0.24)
        ])), withKey: "enraged")
        publishState("BOSS 狂暴 · 攻速提升", feedback: true, force: true)
    }

    private func defeatEnemy(_ enemy: DungeonEnemyActor) {
        enemy.state = .dead
        enemy.intentLabel.isHidden = true
        enemy.telegraphNode?.removeFromParent()
        enemy.telegraphNode = nil
        enemy.visualNode.removeAllActions()
        enemy.artworkNode?.removeAction(forKey: "texture-animation")
        let retreats = enemy.spawn.kind == .gearHound && ["chapter01_q03", "chapter01_q04", "chapter01_q05", "chapter01_q06"].contains(where: { level.id.contains($0) })
        if retreats {
            enemy.visualNode.run(.group([.moveBy(x: 100, y: 50, duration: 0.8), .fadeOut(withDuration: 0.8)]))
        }
        let deathFrameTime = ProcessInfo.processInfo.arguments.contains("--preview-slow-animation") ? 0.22 : 0.10
        if !retreats { playEnemyClip(enemy, textures: enemy.animationClips.death, key: "death", timePerFrame: deathFrameTime) }
        let isLeech = enemy.spawn.title.contains("记忆蛭")
        let deathColor = enemyColor(for: enemy.spawn.kind)
        if !isLeech && !retreats {
        playEnemyDeathEffect(enemy, color: deathColor)
        spawnImpact(
            at: enemy.node.position,
            color: deathColor,
            radius: enemy.spawn.rank == .boss ? 88 : 48
        )
        if enemy.spawn.rank == .boss {
            spawnAreaBurst(at: enemy.node.position, color: deathColor, radius: 170)
        }
        spawnEnemyDissolve(
            at: CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 18),
            color: deathColor,
            scale: enemy.spawn.rank == .boss ? 1.65 : 1
        )
        }
        let authoredDeathDuration = enemy.animationClips.death.count > 1
            ? TimeInterval(enemy.animationClips.death.count) * deathFrameTime
            : 0
        enemy.node.run(.sequence([
            .wait(forDuration: authoredDeathDuration + (isLeech ? 3 : 0)),
            .fadeOut(withDuration: 0.28),
            .removeFromParent()
        ]))
        let aliveCount = enemies.filter(\.isAlive).count
        let futureCount = level.enemies.filter { $0.wave > currentWave }.count
        combat.enemiesRemaining = aliveCount
        if selectedEnemyID == enemy.spawn.id { selectedEnemyID = nil }

        if aliveCount == 0, futureCount > 0, !isTransitioningWaves {
            isTransitioningWaves = true
            pendingBasicAttack = false
            pendingSkillID = nil
            route.removeAll()
            let completedWave = currentWave
            let nextWave = currentWave + 1
            publishState("第 \(completedWave) 波完成 · 敌群正在接近", feedback: true, force: true)
            run(.sequence([
                .wait(forDuration: 0.82),
                .run { [weak self] in
                    guard let self, !self.combat.isDefeated, !self.combat.isVictorious else { return }
                    self.spawnWave(nextWave)
                    self.isTransitioningWaves = false
                    self.turnPhase = .player
                    self.combat.isPlayerTurn = true
                    self.selectedEnemyID = self.enemies.first(where: {
                        $0.isAlive && $0.spawn.wave == nextWave
                    })?.spawn.id
                    self.updateSelectionRings()
                    self.castWaveArrivalPulse()
                    let containsBoss = self.level.enemies.contains {
                        $0.wave == nextWave && $0.rank == .boss
                    }
                    let message = containsBoss
                        ? "首领应对 · \(self.bossCounterHint)"
                        : "第 \(nextWave) 波来袭 · \(self.combat.waveTitle)"
                    self.publishState(message, feedback: true, force: true)
                }
            ]), withKey: "wave-transition")
        } else if combat.enemiesRemaining == 0 {
            combat.isVictorious = true
            turnPhase = .finished
            combat.isPlayerTurn = false
            pendingBasicAttack = false
            pendingSkillID = nil
            route.removeAll()
            destinationMarker.removeAllActions()
            destinationMarker.isHidden = true
            castVictoryPulse()
            publishState("区域净化", feedback: true, force: true)
        } else {
            publishState("击破 · 剩余 \(combat.enemiesRemaining)", feedback: true, force: true)
        }
    }

    /// Each enemy family has a readable material-specific end state. The
    /// authored death strip, when available, runs alongside these effects;
    /// otherwise these effects keep the fallback death from reading as a
    /// generic scale/fade.
    private func playEnemyDeathEffect(_ enemy: DungeonEnemyActor, color: UIColor) {
        let origin = CGPoint(x: enemy.node.position.x, y: enemy.node.position.y + 24)
        switch enemy.spawn.kind {
        case .gearHound, .prototypeHound, .lampDevourer:
            spawnResidualArcana(at: origin, color: .systemOrange, count: 14)
            spawnMaterialHitFragments(at: origin, color: .systemRed, heavy: true)
            spawnGroundImpact(at: enemy.node.position, color: .systemOrange, radius: 74)
        case .saltWraith, .mirrorShade, .stageAfterimage, .crackedMirrorMarionette,
             .firstUnderstudy, .seravianUnified:
            spawnResidualArcana(at: origin, color: .systemPurple, count: 12)
            spawnResidualArcana(at: CGPoint(x: origin.x - 18, y: origin.y + 10), color: .systemIndigo, count: 8)
        case .saltCrystalGnawer, .saltCrystalDeacon, .whiteTideMotherCrystal, .reversePumpHeart:
            spawnMaterialHitFragments(at: origin, color: .systemTeal, heavy: true)
            spawnGroundImpact(at: enemy.node.position, color: .systemCyan, radius: 92)
            spawnResidualArcana(at: origin, color: .systemCyan, count: 10)
        case .rustTideHookRaider, .drownedMemoryGhost, .deepTideDisciple:
            spawnGroundImpact(at: enemy.node.position, color: .systemBlue, radius: 86)
            spawnResidualArcana(at: origin, color: .systemBlue, count: 12)
        case .oathScribe, .facelessAttendant, .hollowClockGuard, .mistCrownGovernor:
            spawnMaterialHitFragments(at: origin, color: color, heavy: true)
            spawnGroundImpact(at: enemy.node.position, color: color, radius: 96)
        }
    }

    private func castWaveArrivalPulse() {
        let pulse = SKShapeNode(ellipseOf: CGSize(width: 210, height: 68))
        pulse.name = "combat-effect"
        pulse.position = enemyZone.center
        pulse.fillColor = UIColor(path.tint).withAlphaComponent(0.16)
        pulse.strokeColor = .clear
        pulse.zPosition = 3
        pulse.setScale(0.45)
        pulse.run(.sequence([
            .group([.scale(to: 1.15, duration: 0.34), .fadeOut(withDuration: 0.42)]),
            .removeFromParent()
        ]))
        addChild(pulse)


    }

    private var bossHealthGradientTexture: SKTexture {
        let size = CGSize(width: 160, height: 8)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors = [
                UIColor(red: 1.0, green: 0.20, blue: 0.14, alpha: 1).cgColor,
                UIColor(red: 0.88, green: 0.05, blue: 0.23, alpha: 1).cgColor,
                UIColor(red: 0.55, green: 0.03, blue: 0.24, alpha: 1).cgColor
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 0.55, 1]
            )!
            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height / 2),
                end: CGPoint(x: size.width, y: size.height / 2),
                options: []
            )
        }
        return SKTexture(image: image)
    }

    private func foolTarotVFXFrames() -> [SKTexture] {
        if let cached = foolTarotVFXTextureCache { return cached }
        let atlas = transparentVFXAtlas(named: "FoolTarotVFXAtlas")
        atlas.filteringMode = .linear
        let columns = 4
        let rows = 4
        var frames: [SKTexture] = []
        frames.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let rect = CGRect(
                    x: CGFloat(column) / CGFloat(columns),
                    y: 1 - CGFloat(row + 1) / CGFloat(rows),
                    width: 1 / CGFloat(columns),
                    height: 1 / CGFloat(rows)
                )
                let texture = SKTexture(rect: rect, in: atlas)
                texture.filteringMode = .linear
                frames.append(texture)
            }
        }
        foolTarotVFXTextureCache = frames
        return frames
    }

    private func foolSkillVFXFrames() -> [SKTexture] {
        if let cached = foolSkillVFXTextureCache { return cached }
        let atlas = transparentVFXAtlas(named: "FoolSkillVFXAtlas")
        atlas.filteringMode = .linear
        let columns = 4
        let rows = 4
        var frames: [SKTexture] = []
        frames.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let rect = CGRect(
                    x: CGFloat(column) / CGFloat(columns),
                    y: 1 - CGFloat(row + 1) / CGFloat(rows),
                    width: 1 / CGFloat(columns),
                    height: 1 / CGFloat(rows)
                )
                let texture = SKTexture(rect: rect, in: atlas)
                texture.filteringMode = .linear
                frames.append(texture)
            }
        }
        foolSkillVFXTextureCache = frames
        return frames
    }

    /// The authored atlases use black as an additive-compositing background.
    /// SpriteKit is hosted as a transparent overlay over Unity, so blending
    /// modes alone cannot reliably hide that background. Rewrite the pixels
    /// into genuine premultiplied RGBA first: black becomes alpha zero and
    /// dark antialiased edges receive a short feather.
    private func transparentVFXAtlas(named name: String) -> SKTexture {
        guard let image = UIImage(named: name),
              let transparentImage = imageByRemovingBlackBackground(image),
              let input = CIImage(image: transparentImage) else {
            return SKTexture(imageNamed: name)
        }
        // Each atlas cell is only about 313 px. Upscale the authored atlas
        // before slicing it into textures so full-battlefield effects retain
        // smooth luminous edges instead of magnifying the source pixels.
        let upscaled = input.applyingFilter(
            "CILanczosScaleTransform",
            parameters: [
                kCIInputScaleKey: 2.0,
                kCIInputAspectRatioKey: 1.0
            ]
        )
        let context = CIContext(options: [.cacheIntermediates: false])
        guard let cgImage = context.createCGImage(upscaled, from: upscaled.extent) else {
            return SKTexture(imageNamed: name)
        }
        return SKTexture(image: UIImage(cgImage: cgImage))
    }

    private func imageByRemovingBlackBackground(_ image: UIImage) -> UIImage? {
        guard let source = image.cgImage else { return nil }
        let width = source.width
        let height = source.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue

        let output: CGImage? = pixels.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo
                  ) else {
                return nil
            }

            context.interpolationQuality = .none
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

            let channels = rawBuffer.bindMemory(to: UInt8.self)
            let transparentCutoff = 30
            let opaqueCutoff = 104
            for offset in stride(from: 0, to: channels.count, by: 4) {
                let red = Int(channels[offset])
                let green = Int(channels[offset + 1])
                let blue = Int(channels[offset + 2])
                let brightest = max(red, max(green, blue))

                let alpha: Int
                if brightest <= transparentCutoff {
                    alpha = 0
                } else if brightest >= opaqueCutoff {
                    alpha = 255
                } else {
                    alpha = (brightest - transparentCutoff) * 255
                        / (opaqueCutoff - transparentCutoff)
                }

                channels[offset] = UInt8(red * alpha / 255)
                channels[offset + 1] = UInt8(green * alpha / 255)
                channels[offset + 2] = UInt8(blue * alpha / 255)
                channels[offset + 3] = UInt8(alpha)
            }
            return context.makeImage()
        }

        guard let output else { return nil }
        return UIImage(cgImage: output, scale: image.scale, orientation: image.imageOrientation)
    }

    private func spawnFoolSkillClip(
        _ clip: FoolSkillVFXClip,
        at position: CGPoint,
        size: CGFloat,
        timePerFrame: TimeInterval,
        rotation: CGFloat = 0
    ) {
        let start = clip.rawValue * 4
        let atlasFrames = foolSkillVFXFrames()
        guard atlasFrames.count >= start + 4 else { return }
        let frames = Array(atlasFrames[start..<(start + 4)])
        let sprite = SKSpriteNode(texture: frames[0])
        sprite.name = "combat-effect"
        sprite.position = position
        sprite.size = CGSize(width: size, height: size)
        sprite.blendMode = .add
        sprite.zPosition = 27
        sprite.zRotation = rotation
        sprite.alpha = 0
        sprite.setScale(0.72)
        addChild(sprite)

        let clipDuration = timePerFrame * Double(frames.count)
        sprite.run(.sequence([
            .group([
                .fadeAlpha(to: 0.98, duration: 0.06),
                .animate(with: frames, timePerFrame: timePerFrame, resize: false, restore: false),
                .scale(to: 1.08, duration: clipDuration)
            ]),
            .wait(forDuration: clip == .simpleDivination ? 0.14 : 0.04),
            .group([
                .scale(to: 1.18, duration: 0.20),
                .fadeOut(withDuration: 0.22)
            ]),
            .removeFromParent()
        ]))
    }

    private func spawnTarotCastVFX(at position: CGPoint, size: CGFloat) {
        let frames = Array(foolTarotVFXFrames().prefix(4))
        spawnRasterVFX(frames: frames, at: position, size: size, timePerFrame: 0.07, zPosition: 22)
    }

    private func spawnTarotImpactVFX(at position: CGPoint, size: CGFloat) {
        if size < 180 {
            let impact = Array(foolTarotVFXFrames().dropFirst(8).prefix(4))
            spawnRasterVFX(
                frames: impact,
                at: position,
                size: size,
                timePerFrame: 0.055,
                zPosition: 27
            )
            return
        }
        spawnLayeredFoolTarotImpact(at: position, requestedSize: size)
    }

    /// A dense authored-card impact used by the Fool's major card attacks.
    /// Ten independently timed clips form a large spell body without relying
    /// on straight procedural beams or a single oversized bitmap.
    private func spawnLayeredFoolTarotImpact(
        at position: CGPoint,
        requestedSize: CGFloat,
        maximumLayers: Int = 10,
        compactForLiveActor: Bool = false
    ) {
        struct Layer {
            let offset: CGPoint
            let size: CGFloat
            let rotation: CGFloat
            let delay: TimeInterval
            let duration: TimeInterval
            let alpha: CGFloat
            let frameStart: Int
            let clockwise: Bool
        }

        let base = compactForLiveActor
            ? min(max(requestedSize, 180), 320)
            : min(max(requestedSize, 420), 900)
        let offsetScale = compactForLiveActor ? base / 540 : 1
        let layers: [Layer] = [
            Layer(offset: CGPoint(x: -162, y: -92), size: base * 0.72, rotation: -0.68, delay: 0.00, duration: 0.34, alpha: 0.76, frameStart: 8, clockwise: true),
            Layer(offset: CGPoint(x: 112, y: -58), size: base * 0.68, rotation: 0.42, delay: 0.04, duration: 0.36, alpha: 0.78, frameStart: 12, clockwise: false),
            Layer(offset: CGPoint(x: -72, y: 14), size: base * 0.82, rotation: -0.24, delay: 0.07, duration: 0.40, alpha: 0.88, frameStart: 4, clockwise: false),
            Layer(offset: CGPoint(x: 148, y: 72), size: base * 0.64, rotation: 0.74, delay: 0.11, duration: 0.35, alpha: 0.72, frameStart: 12, clockwise: true),
            Layer(offset: CGPoint(x: -124, y: 108), size: base * 0.70, rotation: -0.48, delay: 0.15, duration: 0.39, alpha: 0.76, frameStart: 12, clockwise: false),
            Layer(offset: CGPoint(x: 42, y: 126), size: base * 0.76, rotation: 0.16, delay: 0.18, duration: 0.42, alpha: 0.82, frameStart: 4, clockwise: true),
            Layer(offset: CGPoint(x: -182, y: 22), size: base * 0.58, rotation: -0.88, delay: 0.22, duration: 0.35, alpha: 0.66, frameStart: 12, clockwise: true),
            Layer(offset: CGPoint(x: 132, y: -4), size: base * 0.74, rotation: 0.58, delay: 0.25, duration: 0.41, alpha: 0.80, frameStart: 8, clockwise: false),
            Layer(offset: CGPoint(x: -34, y: -38), size: base * 0.90, rotation: -0.12, delay: 0.28, duration: 0.44, alpha: 0.92, frameStart: 8, clockwise: true),
            Layer(offset: .zero, size: base * 1.04, rotation: 0.05, delay: 0.32, duration: 0.50, alpha: 0.98, frameStart: 8, clockwise: false)
        ]

        let visibleLayerCount = min(max(1, maximumLayers), layers.count)
        var activeLayers = Array(layers.prefix(visibleLayerCount))
        if visibleLayerCount < layers.count, let focalLayer = layers.last {
            activeLayers[activeLayers.count - 1] = focalLayer
        }

        let tarotFrames = foolTarotVFXFrames()
        for (index, layer) in activeLayers.enumerated() {
            guard tarotFrames.count >= layer.frameStart + 4 else { continue }
            let frames = Array(tarotFrames[layer.frameStart..<(layer.frameStart + 4)])
            let sprite = SKSpriteNode(texture: frames[0])
            sprite.name = "combat-effect"
            sprite.position = CGPoint(
                x: position.x + layer.offset.x * offsetScale,
                y: position.y + layer.offset.y * offsetScale
            )
            sprite.size = CGSize(width: layer.size, height: layer.size)
            sprite.blendMode = .add
            sprite.zPosition = 25 + CGFloat(index) * 0.32
            sprite.zRotation = layer.rotation
            sprite.alpha = 0
            sprite.setScale(0.38)
            addChild(sprite)

            let spin: CGFloat = layer.clockwise ? 0.22 : -0.22
            sprite.run(.sequence([
                .wait(forDuration: layer.delay),
                .group([
                    .fadeAlpha(to: layer.alpha, duration: 0.07),
                    .animate(
                        with: frames,
                        timePerFrame: layer.duration / Double(frames.count),
                        resize: false,
                        restore: false
                    ),
                    .scale(to: 1.03, duration: layer.duration),
                    .rotate(byAngle: spin, duration: layer.duration)
                ]),
                .group([
                    .scale(to: 1.20, duration: 0.24),
                    .fadeOut(withDuration: 0.25),
                    .rotate(byAngle: spin * 0.7, duration: 0.25)
                ]),
                .removeFromParent()
            ]))
        }

        // A pair of authored skill clips supplies a moving veil and a bright
        // focal detonation, so the ten tarot layers read as one spell.
        spawnFoolSkillClip(
            .dangerPremonition,
            at: position,
            size: base * 0.96,
            timePerFrame: 0.085,
            rotation: -0.08
        )
        run(.sequence([
            .wait(forDuration: 0.18),
            .run { [weak self] in
                guard let self else { return }
                self.spawnFoolSkillClip(
                    .simpleDivination,
                    at: position,
                    size: base * 0.88,
                    timePerFrame: 0.075,
                    rotation: 0.12
                )
                self.spawnResidualArcana(
                    at: position,
                    color: UIColor(red: 0.72, green: 0.34, blue: 1, alpha: 1),
                    count: maximumLayers >= 10 ? 34 : 22
                )
            }
        ]))

        if !compactForLiveActor {
            sceneCamera.removeAction(forKey: "layered-card-impact")
            sceneCamera.run(.sequence([
                .scale(to: 0.978, duration: 0.08),
                .scale(to: 1.018, duration: 0.11),
                .scale(to: 1, duration: 0.18)
            ]), withKey: "layered-card-impact")
        }
    }

    /// Sequence 9 basic attacks should still feel magical and authored. This
    /// is the middle tier between the former full-screen finisher and the
    /// over-reduced single sparkle: five card layers, a focal spell clip,
    /// fragments and a modest impact pulse, all locked to the enemy body.
    private func spawnLowRankFoolBasicImpact(
        at position: CGPoint,
        tint: UIColor
    ) {
        spawnLayeredFoolTarotImpact(
            at: position,
            requestedSize: 540,
            maximumLayers: 5
        )
        spawnFoolSkillClip(
            .weaknessJudgment,
            at: position,
            size: 390,
            timePerFrame: 0.075,
            rotation: 0.08
        )
        spawnImpact(at: position, color: tint, radius: 62)
        spawnWeakpointResidue(at: position, color: tint)
        spawnResidualArcana(at: position, color: tint, count: 12)
    }

    private func spawnRasterVFX(
        frames: [SKTexture],
        at position: CGPoint,
        size: CGFloat,
        timePerFrame: TimeInterval,
        zPosition: CGFloat
    ) {
        guard let first = frames.first else { return }
        let sprite = SKSpriteNode(texture: first)
        sprite.name = "combat-effect"
        sprite.position = position
        let displaySize = effectsOnlyOverlayEnabled ? size * 1.48 : size
        sprite.size = CGSize(width: displaySize, height: displaySize)
        sprite.blendMode = .add
        sprite.zPosition = zPosition
        sprite.setScale(0.72)
        sprite.zRotation = -0.10
        addChild(sprite)
        sprite.run(.sequence([
            .group([
                .animate(with: frames, timePerFrame: timePerFrame, resize: false, restore: false),
                .scale(to: 1.08, duration: timePerFrame * Double(frames.count)),
                .rotate(byAngle: 0.24, duration: timePerFrame * Double(frames.count))
            ]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))
    }

    private func spawnWeaknessScan(from start: CGPoint, to end: CGPoint, color: UIColor) {
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        for (index, width) in [CGFloat(12), 4, 1.5].enumerated() {
            let ray = SKShapeNode(path: path)
            ray.name = "combat-effect"
            ray.strokeColor = index == 2 ? .white : color.withAlphaComponent(index == 0 ? 0.18 : 0.74)
            ray.lineWidth = width
            ray.glowWidth = CGFloat(7 - index * 2)
            ray.blendMode = .add
            ray.zPosition = 24 + CGFloat(index) * 0.1
            ray.alpha = 0
            addChild(ray)
            ray.run(.sequence([
                .wait(forDuration: 0.14 + TimeInterval(index) * 0.025),
                .fadeAlpha(to: 0.92, duration: 0.06),
                .wait(forDuration: 0.10),
                .fadeOut(withDuration: 0.18),
                .removeFromParent()
            ]))
        }
    }

    private func spawnWeakpointResidue(at position: CGPoint, color: UIColor) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 20))
        path.addLine(to: CGPoint(x: 14, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -20))
        path.addLine(to: CGPoint(x: -14, y: 0))
        path.closeSubpath()
        let mark = SKShapeNode(path: path)
        mark.name = "combat-effect"
        mark.position = CGPoint(x: position.x, y: position.y + 16)
        mark.strokeColor = color
        mark.fillColor = .clear
        mark.lineWidth = 3
        mark.glowWidth = 8
        mark.blendMode = .add
        mark.zPosition = 28
        mark.setScale(0.35)
        addChild(mark)
        mark.run(.sequence([
            .group([.scale(to: 1, duration: 0.14), .rotate(byAngle: .pi / 2, duration: 0.22)]),
            .wait(forDuration: 0.44 * playerAnimationTimingMultiplier),
            .group([.scale(to: 0.72, duration: 0.24), .fadeOut(withDuration: 0.24)]),
            .removeFromParent()
        ]))
    }

    private func spawnSequenceNineBasicAttackBloom(
        at position: CGPoint,
        scale: CGFloat = 1
    ) {
        let bloom = SKNode()
        bloom.name = "combat-effect-sequence-nine-basic-bloom"
        bloom.position = position
        bloom.zPosition = 30
        bloom.alpha = 0
        bloom.setScale(0.58 * scale)
        addChild(bloom)

        let haze = SKShapeNode(circleOfRadius: 30)
        haze.fillColor = UIColor(red: 0.12, green: 0.52, blue: 1, alpha: 0.13)
        haze.strokeColor = UIColor(red: 0.40, green: 0.78, blue: 1, alpha: 0.82)
        haze.lineWidth = 1.8
        haze.glowWidth = 18
        haze.blendMode = .add
        bloom.addChild(haze)

        let halo = SKShapeNode(ellipseOf: CGSize(width: 74, height: 25))
        halo.strokeColor = UIColor(red: 0.50, green: 0.84, blue: 1, alpha: 0.88)
        halo.fillColor = .clear
        halo.lineWidth = 2
        halo.glowWidth = 9
        halo.blendMode = .add
        halo.zRotation = -0.18
        bloom.addChild(halo)

        let flarePath = CGMutablePath()
        flarePath.move(to: CGPoint(x: -37, y: 0))
        flarePath.addLine(to: CGPoint(x: 37, y: 0))
        flarePath.move(to: CGPoint(x: 0, y: -24))
        flarePath.addLine(to: CGPoint(x: 0, y: 24))
        let flare = SKShapeNode(path: flarePath)
        flare.strokeColor = UIColor(white: 0.96, alpha: 0.92)
        flare.lineWidth = 2.2
        flare.glowWidth = 13
        flare.blendMode = .add
        bloom.addChild(flare)

        let core = SKShapeNode(circleOfRadius: 4.5)
        core.fillColor = .white
        core.strokeColor = UIColor(red: 0.48, green: 0.88, blue: 1, alpha: 1)
        core.lineWidth = 1
        core.glowWidth = 16
        core.blendMode = .add
        bloom.addChild(core)

        for index in 0..<8 {
            let angle = CGFloat(index) / 8 * .pi * 2
            let mote = SKShapeNode(circleOfRadius: index.isMultiple(of: 3) ? 1.8 : 1.1)
            mote.position = CGPoint(x: cos(angle) * 34, y: sin(angle) * 18)
            mote.fillColor = index.isMultiple(of: 2)
                ? UIColor.white
                : UIColor(red: 0.24, green: 0.70, blue: 1, alpha: 1)
            mote.strokeColor = .clear
            mote.glowWidth = 5
            mote.blendMode = .add
            bloom.addChild(mote)
            mote.run(.moveBy(
                x: cos(angle) * 13,
                y: sin(angle) * 8,
                duration: 0.34
            ))
        }

        halo.run(.rotate(byAngle: 0.42, duration: 0.38))
        bloom.run(.sequence([
            .group([
                .fadeAlpha(to: 1, duration: 0.07),
                .scale(to: 1.04 * scale, duration: 0.14)
            ]),
            .group([
                .scale(to: 1.22 * scale, duration: 0.28),
                .fadeOut(withDuration: 0.30)
            ]),
            .removeFromParent()
        ]))
    }

    private func spawnFoolPersonalAegis() {
        player.childNode(withName: "combat-effect-fool-personal-aegis")?.removeFromParent()

        let aegis = SKNode()
        aegis.name = "combat-effect-fool-personal-aegis"
        aegis.position = CGPoint(x: 0, y: 43)
        aegis.zPosition = 24
        aegis.alpha = 0
        aegis.setScale(0.88)
        player.addChild(aegis)

        let shell = SKShapeNode(ellipseOf: CGSize(width: 112, height: 166))
        shell.fillColor = UIColor(red: 0.38, green: 0.86, blue: 1, alpha: 0.10)
        shell.strokeColor = UIColor(red: 0.72, green: 0.94, blue: 1, alpha: 0.92)
        shell.lineWidth = 2.4
        shell.glowWidth = 12
        shell.blendMode = .add
        aegis.addChild(shell)

        let innerShell = SKShapeNode(ellipseOf: CGSize(width: 98, height: 150))
        innerShell.fillColor = UIColor(red: 1, green: 0.84, blue: 0.42, alpha: 0.035)
        innerShell.strokeColor = UIColor(red: 0.94, green: 0.82, blue: 0.48, alpha: 0.62)
        innerShell.lineWidth = 1.15
        innerShell.glowWidth = 5
        innerShell.blendMode = .add
        aegis.addChild(innerShell)

        for (index, y) in [CGFloat(-48), -16, 18, 51].enumerated() {
            let normalizedY = y / 83
            let halfWidth = sqrt(max(0, 1 - normalizedY * normalizedY)) * 53
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -halfWidth, y: y))
            path.addQuadCurve(
                to: CGPoint(x: halfWidth, y: y),
                control: CGPoint(x: 0, y: y + (index.isMultiple(of: 2) ? 7 : -7))
            )
            let current = SKShapeNode(path: path)
            current.strokeColor = index.isMultiple(of: 2)
                ? UIColor(red: 0.68, green: 0.95, blue: 1, alpha: 0.44)
                : UIColor(red: 1, green: 0.84, blue: 0.46, alpha: 0.30)
            current.lineWidth = index == 1 || index == 2 ? 1.4 : 0.8
            current.glowWidth = 4
            current.blendMode = .add
            current.alpha = 0.25
            aegis.addChild(current)
            current.run(.repeatForever(.sequence([
                .wait(forDuration: TimeInterval(index) * 0.08),
                .fadeAlpha(to: 0.72, duration: 0.22),
                .fadeAlpha(to: 0.20, duration: 0.42)
            ])))
        }

        for index in 0..<7 {
            let angle = CGFloat(index) / 7 * .pi * 2
            let mote = SKShapeNode(circleOfRadius: index.isMultiple(of: 3) ? 1.8 : 1.1)
            mote.position = CGPoint(x: cos(angle) * 49, y: sin(angle) * 73)
            mote.fillColor = index.isMultiple(of: 2) ? .white : UIColor.systemCyan
            mote.strokeColor = .clear
            mote.glowWidth = 4
            mote.blendMode = .add
            aegis.addChild(mote)
        }

        aegis.run(.sequence([
            .group([
                .fadeAlpha(to: 1, duration: 0.16),
                .scale(to: 1, duration: 0.20)
            ]),
            .group([
                .scale(to: 1.025, duration: 0.22),
                .fadeAlpha(to: 0.88, duration: 0.22)
            ]),
            .group([
                .scale(to: 0.98, duration: 0.30),
                .fadeOut(withDuration: 0.30)
            ]),
            .removeFromParent()
        ]))
    }

    private func spawnSpiritualAfterimages(at position: CGPoint, color: UIColor) {
        guard let artwork = playerArtwork, let texture = artwork.texture else { return }
        for (index, horizontalOffset) in [CGFloat(-54), 54].enumerated() {
            let echo = SKSpriteNode(texture: texture)
            echo.name = "combat-effect"
            echo.position = CGPoint(x: position.x, y: position.y + artwork.position.y)
            echo.size = artwork.size
            echo.anchorPoint = artwork.anchorPoint
            echo.color = color
            echo.colorBlendFactor = 0.74
            echo.blendMode = .add
            echo.zPosition = 20
            echo.alpha = 0
            addChild(echo)
            echo.run(.sequence([
                .wait(forDuration: TimeInterval(index) * 0.05),
                .group([
                    .fadeAlpha(to: 0.34, duration: 0.08),
                    .moveBy(x: horizontalOffset, y: 6, duration: 0.18)
                ]),
                .group([
                    .moveBy(x: horizontalOffset * 0.22, y: 5, duration: 0.22),
                    .fadeOut(withDuration: 0.22)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnDivinationConstellation(at position: CGPoint, radius: CGFloat, color: UIColor) {
        let points = 7
        for index in 0..<points {
            let angle = CGFloat(index) / CGFloat(points) * .pi * 2 - .pi / 2
            let star = SKShapeNode(circleOfRadius: index.isMultiple(of: 2) ? 3.2 : 2.1)
            star.name = "combat-effect"
            star.position = CGPoint(
                x: position.x + cos(angle) * radius * 0.68,
                y: position.y + sin(angle) * radius * 0.42
            )
            star.fillColor = index.isMultiple(of: 3) ? .white : color
            star.strokeColor = .clear
            star.glowWidth = 5
            star.blendMode = .add
            star.zPosition = 26
            star.alpha = 0
            addChild(star)
            star.run(.sequence([
                .wait(forDuration: TimeInterval(index) * 0.035),
                .group([.fadeIn(withDuration: 0.08), .scale(to: 1.45, duration: 0.14)]),
                .wait(forDuration: 0.46),
                .group([.fadeOut(withDuration: 0.30), .moveBy(x: 0, y: 16, duration: 0.30)]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnDangerVeil(at position: CGPoint) {
        let veil = SKSpriteNode(
            color: UIColor(red: 0.16, green: 0.01, blue: 0.19, alpha: 0.26),
            size: CGSize(width: size.width * 1.20, height: min(size.height * 0.46, 430))
        )
        veil.name = "combat-effect"
        veil.position = CGPoint(x: size.width / 2, y: position.y + 10)
        veil.zPosition = 19
        veil.alpha = 0
        addChild(veil)
        veil.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.12),
            .wait(forDuration: 0.46),
            .fadeOut(withDuration: 0.36),
            .removeFromParent()
        ]))
    }

    private func launchPlayerProjectile(
        from start: CGPoint? = nil,
        toward enemy: DungeonEnemyActor,
        color: UIColor,
        size projectileSize: CGFloat,
        duration: TimeInterval
    ) {
        let flightFrames = Array(foolTarotVFXFrames().dropFirst(4).prefix(4))
        let projectile = SKSpriteNode(texture: flightFrames.first)
        projectile.name = "combat-effect"
        projectile.position = start ?? playerCastingHandPosition()
        projectile.size = CGSize(width: projectileSize * 15.0, height: projectileSize * 15.0)
        projectile.color = color
        projectile.colorBlendFactor = 0.08
        projectile.blendMode = .add
        projectile.zPosition = 25
        projectile.setScale(0.68)
        addChild(projectile)

        let origin = projectile.position
        let destination = enemy.node.position
        projectile.zRotation = atan2(destination.y - origin.y, destination.x - origin.x) - .pi / 2
        spawnProjectileTrail(from: origin, to: destination, color: color, duration: duration)
        if !flightFrames.isEmpty {
            projectile.run(.repeatForever(.animate(with: flightFrames, timePerFrame: duration / 4, resize: false, restore: false)), withKey: "raster-vfx")
        }
        projectile.run(.sequence([
            .group([
                .move(to: destination, duration: duration),
                // A restrained turn reads as a physical card. A full spin
                // turns the authored face into an indistinct glowing disc.
                .rotate(byAngle: .pi * 0.28, duration: duration),
                .sequence([
                    .scale(to: 1.18, duration: duration * 0.32),
                    .scale(to: 1.04, duration: duration * 0.68)
                ])
            ]),
            .fadeOut(withDuration: 0.06),
            .removeFromParent()
        ]))
    }

    /// World-space anchor for cards and spell bolts held by the Fool.
    /// The artwork is bottom-anchored at the actor's feet, so `player.position`
    /// is a ground/contact point rather than a valid projectile origin.
    private func playerCastingHandPosition() -> CGPoint {
        guard let artwork = playerArtwork else {
            return CGPoint(x: player.position.x + 28, y: player.position.y + 46)
        }
        let localHand = CGPoint(
            x: artwork.size.width * 0.28,
            y: artwork.size.height * 0.56
        )
        return artwork.convert(localHand, to: self)
    }

    private func spawnProjectileTrail(
        from start: CGPoint,
        to end: CGPoint,
        color: UIColor,
        duration: TimeInterval
    ) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        // A few faint motes support the raster projectile without becoming the
        // projectile itself.  The authored PNG frames remain the visual focus.
        for index in 1...4 {
            let progress = CGFloat(index) / 5
            let mote = SKShapeNode(circleOfRadius: index.isMultiple(of: 2) ? 1.8 : 1.2)
            mote.name = "combat-effect"
            mote.position = CGPoint(x: start.x + dx * progress, y: start.y + dy * progress)
            mote.fillColor = color.withAlphaComponent(0.34)
            mote.strokeColor = .clear
            mote.glowWidth = 2
            mote.zPosition = 23
            mote.alpha = 0
            addChild(mote)
            mote.run(.sequence([
                .wait(forDuration: duration * TimeInterval(progress) * 0.72),
                .fadeIn(withDuration: 0.025),
                .group([.fadeOut(withDuration: 0.12), .moveBy(x: 0, y: 4, duration: 0.12)]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnTargetWarning(
        at position: CGPoint,
        color: UIColor,
        radius: CGFloat,
        duration: TimeInterval
    ) {
        let warning = SKShapeNode(ellipseOf: CGSize(width: max(38, radius * 1.4), height: max(14, radius * 0.42)))
        warning.name = "combat-effect"
        warning.position = CGPoint(x: position.x, y: position.y - 24)
        warning.fillColor = color.withAlphaComponent(0.13)
        warning.strokeColor = .clear
        warning.glowWidth = 0
        warning.zPosition = 18
        warning.setScale(0.82)
        addChild(warning)
        warning.run(.sequence([
            .group([.scale(to: 1.12, duration: duration), .fadeAlpha(to: 0.52, duration: duration)]),
            .fadeOut(withDuration: 0.08),
            .removeFromParent()
        ]))
    }

    private func spawnCastSigil(at position: CGPoint, color: UIColor, radius: CGFloat) {
        let sigil = SKShapeNode(ellipseOf: CGSize(width: radius * 1.9, height: radius * 0.58))
        sigil.name = "combat-effect"
        sigil.position = CGPoint(x: position.x, y: position.y - 28)
        sigil.fillColor = color.withAlphaComponent(0.16)
        sigil.strokeColor = .clear
        sigil.glowWidth = 0
        sigil.zPosition = 18
        sigil.setScale(0.72)
        addChild(sigil)
        sigil.run(.sequence([
            .group([.fadeAlpha(to: 0.52, duration: 0.20), .scale(to: 1.18, duration: 0.34)]),
            .fadeOut(withDuration: 0.12),
            .removeFromParent()
        ]))
    }

    private func spawnResidualArcana(at position: CGPoint, color: UIColor, count: Int = 12) {
        for index in 0..<count {
            let angle = CGFloat(index) / CGFloat(max(1, count)) * .pi * 2
            let mote = SKShapeNode(circleOfRadius: index.isMultiple(of: 3) ? 3 : 2)
            mote.name = "combat-effect"
            mote.position = position
            mote.fillColor = color
            mote.strokeColor = .white.withAlphaComponent(0.65)
            mote.glowWidth = 4
            mote.zPosition = 26
            addChild(mote)
            mote.run(.sequence([
                .wait(forDuration: TimeInterval(index % 4) * 0.025),
                .group([
                    .moveBy(x: cos(angle) * 58, y: sin(angle) * 58 + 18, duration: 0.48),
                    .fadeOut(withDuration: 0.48),
                    .scale(to: 0.35, duration: 0.48)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnEnemyCastGlyph(
        at position: CGPoint,
        color: UIColor,
        radius: CGFloat,
        duration: TimeInterval
    ) {
        let glyph = SKShapeNode(ellipseOf: CGSize(width: radius * 1.65, height: radius * 0.48))
        glyph.name = "combat-effect"
        glyph.position = CGPoint(x: position.x, y: position.y - 20)
        glyph.strokeColor = .clear
        glyph.fillColor = color.withAlphaComponent(0.12)
        glyph.glowWidth = 0
        glyph.zPosition = 4
        glyph.alpha = 0.28
        glyph.setScale(0.76)
        addChild(glyph)
        let motion = SKAction.group([.scale(to: 1.12, duration: duration), .fadeAlpha(to: 0.58, duration: duration)])
        glyph.run(.sequence([motion, .fadeOut(withDuration: 0.12), .removeFromParent()]))
    }

    private func spawnTeleportPortal(at position: CGPoint, color: UIColor, opening: Bool) {
        let portal = SKShapeNode(ellipseOf: CGSize(width: 72, height: 24))
        portal.name = "combat-effect"
        portal.position = CGPoint(x: position.x, y: position.y - 26)
        portal.strokeColor = .clear
        portal.fillColor = color.withAlphaComponent(0.16)
        portal.glowWidth = 0
        portal.zPosition = 5
        portal.setScale(opening ? 0.25 : 1)
        addChild(portal)
        portal.run(.sequence([
            .group([
                .scale(to: opening ? 1 : 0.25, duration: 0.16),
                .fadeAlpha(to: opening ? 0.96 : 0.18, duration: 0.16)
            ]),
            .fadeOut(withDuration: 0.12),
            .removeFromParent()
        ]))
    }

    private func spawnGroundImpact(at position: CGPoint, color: UIColor, radius: CGFloat) {
        let shock = SKShapeNode(ellipseOf: CGSize(width: radius * 2, height: radius * 0.72))
        shock.name = "combat-effect"
        shock.position = CGPoint(x: position.x, y: position.y - 22)
        shock.strokeColor = .clear
        shock.fillColor = color.withAlphaComponent(0.15)
        shock.glowWidth = 0
        shock.zPosition = 6
        shock.setScale(0.26)
        addChild(shock)
        shock.run(.sequence([
            .group([.scale(to: 1, duration: 0.18), .fadeAlpha(to: 0.92, duration: 0.18)]),
            .group([.scale(to: 1.32, duration: 0.16), .fadeOut(withDuration: 0.16)]),
            .removeFromParent()
        ]))
    }

    private func launchEnemyProjectile(
        from start: CGPoint,
        to end: CGPoint,
        color: UIColor,
        onImpact: @escaping () -> Void
    ) {
        let projectile = SKShapeNode(circleOfRadius: 8)
        projectile.name = "combat-effect"
        projectile.position = start
        projectile.fillColor = color
        projectile.strokeColor = .systemRed
        projectile.lineWidth = 2
        projectile.glowWidth = 8
        projectile.zPosition = 24
        addChild(projectile)
        spawnProjectileTrail(from: start, to: end, color: color, duration: 0.30)
        projectile.setScale(0.45)
        projectile.run(.sequence([
            .group([
                .move(to: end, duration: 0.30),
                .scale(to: 1.15, duration: 0.30),
                .rotate(byAngle: .pi * 1.5, duration: 0.30)
            ]),
            .run(onImpact),
            .scale(to: 2.2, duration: 0.07),
            .fadeOut(withDuration: 0.11),
            .removeFromParent()
        ]))
    }

    private func launchSaltCrystalVolley(
        from start: CGPoint,
        to end: CGPoint,
        onImpact: @escaping () -> Void
    ) {
        let travelDuration: TimeInterval = 0.34
        let offsets: [CGFloat] = [-18, 0, 18]
        for (index, offset) in offsets.enumerated() {
            let shardPath = CGMutablePath()
            shardPath.move(to: CGPoint(x: 0, y: 13))
            shardPath.addLine(to: CGPoint(x: 6, y: 0))
            shardPath.addLine(to: CGPoint(x: 0, y: -13))
            shardPath.addLine(to: CGPoint(x: -6, y: 0))
            shardPath.closeSubpath()

            let shard = SKShapeNode(path: shardPath)
            shard.name = "combat-effect"
            shard.position = CGPoint(x: start.x + offset * 0.32, y: start.y + 8)
            shard.fillColor = UIColor(red: 0.18, green: 0.72, blue: 0.96, alpha: index == 1 ? 0.90 : 0.72)
            shard.strokeColor = UIColor.white.withAlphaComponent(0.46)
            shard.lineWidth = 1
            shard.glowWidth = index == 1 ? 4 : 2
            shard.zPosition = 25
            shard.zRotation = atan2(end.y - start.y, end.x - start.x) - .pi / 2
            shard.setScale(index == 1 ? 1.05 : 0.78)
            addChild(shard)

            let destination = CGPoint(x: end.x + offset, y: end.y + abs(offset) * 0.12)
            let delay = TimeInterval(index) * 0.045
            shard.run(.sequence([
                .wait(forDuration: delay),
                .group([
                    .move(to: destination, duration: travelDuration),
                    .rotate(byAngle: index == 1 ? .pi : -.pi * 0.7, duration: travelDuration),
                    .sequence([
                        .scale(to: index == 1 ? 1.22 : 0.92, duration: travelDuration * 0.62),
                        .scale(to: 0.58, duration: travelDuration * 0.38)
                    ])
                ]),
                index == offsets.count - 1 ? .run(onImpact) : .wait(forDuration: 0),
                .fadeOut(withDuration: 0.08),
                .removeFromParent()
            ]))

            for trailIndex in 0..<5 {
                let mote = SKShapeNode(circleOfRadius: trailIndex.isMultiple(of: 2) ? 2.4 : 1.6)
                mote.name = "combat-effect"
                mote.position = shard.position
                mote.fillColor = UIColor(red: 0.42, green: 0.88, blue: 1, alpha: 0.66)
                mote.strokeColor = .clear
                mote.blendMode = .add
                mote.zPosition = 23
                addChild(mote)
                let progress = CGFloat(trailIndex + 1) / 6
                let moteEnd = CGPoint(
                    x: shard.position.x + (destination.x - shard.position.x) * progress,
                    y: shard.position.y + (destination.y - shard.position.y) * progress
                )
                mote.run(.sequence([
                    .wait(forDuration: delay + TimeInterval(trailIndex) * 0.035),
                    .group([
                        .move(to: moteEnd, duration: travelDuration * 0.70),
                        .fadeOut(withDuration: travelDuration * 0.70),
                        .scale(to: 0.25, duration: travelDuration * 0.70)
                    ]),
                    .removeFromParent()
                ]))
            }
        }
    }

    private func spawnSaltCrystalImpact(at position: CGPoint, radius: CGFloat) {
        let flash = SKShapeNode(ellipseOf: CGSize(width: radius * 1.25, height: radius * 0.46))
        flash.name = "combat-effect"
        flash.position = CGPoint(x: position.x, y: position.y - 12)
        flash.fillColor = UIColor(red: 0.25, green: 0.82, blue: 1, alpha: 0.22)
        flash.strokeColor = .clear
        flash.blendMode = .add
        flash.zPosition = 22
        flash.setScale(0.32)
        addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 1, duration: 0.12), .fadeAlpha(to: 0.82, duration: 0.12)]),
            .group([.scale(to: 1.28, duration: 0.22), .fadeOut(withDuration: 0.22)]),
            .removeFromParent()
        ]))

        for index in 0..<12 {
            let angle = CGFloat(index) / 12 * .pi * 2 + CGFloat(index % 2) * 0.11
            let shardPath = CGMutablePath()
            shardPath.move(to: CGPoint(x: 0, y: 7))
            shardPath.addLine(to: CGPoint(x: 3, y: 0))
            shardPath.addLine(to: CGPoint(x: 0, y: -7))
            shardPath.addLine(to: CGPoint(x: -3, y: 0))
            shardPath.closeSubpath()
            let shard = SKShapeNode(path: shardPath)
            shard.name = "combat-effect"
            shard.position = CGPoint(x: position.x, y: position.y - 4)
            shard.zRotation = angle - .pi / 2
            shard.fillColor = index.isMultiple(of: 3)
                ? UIColor.white.withAlphaComponent(0.72)
                : UIColor(red: 0.25, green: 0.82, blue: 1, alpha: 0.78)
            shard.strokeColor = .clear
            shard.glowWidth = 2
            shard.blendMode = .add
            shard.zPosition = 25
            addChild(shard)
            let distance = radius * (index.isMultiple(of: 2) ? 0.84 : 0.62)
            shard.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * distance, y: sin(angle) * distance * 0.62 + 8, duration: 0.28),
                    .rotate(byAngle: index.isMultiple(of: 2) ? 1.2 : -1.0, duration: 0.28),
                    .sequence([.scale(to: 1.18, duration: 0.10), .scale(to: 0.35, duration: 0.18)]),
                    .fadeOut(withDuration: 0.28)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnSaltCrystalResidue(at position: CGPoint) {
        let offsets: [CGPoint] = [
            CGPoint(x: -24, y: -15), CGPoint(x: -11, y: 6), CGPoint(x: 5, y: -9),
            CGPoint(x: 19, y: 8), CGPoint(x: 29, y: -13), CGPoint(x: -31, y: 3)
        ]
        for (index, offset) in offsets.enumerated() {
            let crystalPath = CGMutablePath()
            crystalPath.move(to: CGPoint(x: 0, y: 8))
            crystalPath.addLine(to: CGPoint(x: 3.5, y: 0))
            crystalPath.addLine(to: CGPoint(x: 0, y: -8))
            crystalPath.addLine(to: CGPoint(x: -3.5, y: 0))
            crystalPath.closeSubpath()
            let crystal = SKShapeNode(path: crystalPath)
            crystal.name = "combat-effect"
            crystal.position = CGPoint(x: position.x + offset.x, y: position.y + offset.y - 16)
            crystal.fillColor = index.isMultiple(of: 3)
                ? UIColor(red: 0.66, green: 0.94, blue: 1, alpha: 0.66)
                : UIColor(red: 0.22, green: 0.72, blue: 0.94, alpha: 0.58)
            crystal.strokeColor = UIColor.white.withAlphaComponent(0.18)
            crystal.lineWidth = 0.6
            crystal.glowWidth = 1
            crystal.blendMode = .add
            crystal.zPosition = 7
            crystal.alpha = 0
            crystal.setScale(0.18)
            addChild(crystal)
            crystal.run(.sequence([
                .wait(forDuration: TimeInterval(index) * 0.025),
                .group([.fadeIn(withDuration: 0.10), .scale(to: 0.72, duration: 0.14)]),
                .wait(forDuration: 0.52),
                .group([.fadeOut(withDuration: 0.30), .scale(to: 0.55, duration: 0.30)]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnImpact(at position: CGPoint, color: UIColor, radius: CGFloat) {
        let ring = SKShapeNode(circleOfRadius: 12)
        ring.name = "combat-effect"
        ring.position = position
        ring.strokeColor = color
        ring.lineWidth = 3
        ring.glowWidth = 8
        ring.zPosition = 24
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: radius / 12, duration: 0.24), .fadeOut(withDuration: 0.28)]),
            .removeFromParent()
        ]))

        for index in 0..<8 {
            let angle = CGFloat(index) / 8 * .pi * 2
            let spark = SKShapeNode(rectOf: CGSize(width: 3, height: 16), cornerRadius: 1.5)
            spark.name = "combat-effect"
            spark.position = position
            spark.zRotation = angle - .pi / 2
            spark.fillColor = color
            spark.strokeColor = .clear
            spark.zPosition = 25
            addChild(spark)
            spark.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * radius, y: sin(angle) * radius, duration: 0.24),
                    .fadeOut(withDuration: 0.24)
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// Small material fragments supply impact depth without scaling, skewing,
    /// or rotating the painted body sprite itself.
    private func spawnMaterialHitFragments(at position: CGPoint, color: UIColor, heavy: Bool) {
        let count = heavy ? 11 : 7
        for index in 0..<count {
            let angle = -.pi * 0.10 + CGFloat(index) / CGFloat(max(1, count - 1)) * .pi * 1.20
            let distance = CGFloat.random(in: heavy ? 24...52 : 18...38)
            let path = CGMutablePath()
            let width = CGFloat.random(in: 2.5...4.5)
            let height = CGFloat.random(in: 7...13)
            path.move(to: CGPoint(x: 0, y: height / 2))
            path.addLine(to: CGPoint(x: width / 2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -height / 2))
            path.addLine(to: CGPoint(x: -width / 2, y: 0))
            path.closeSubpath()

            let fragment = SKShapeNode(path: path)
            fragment.name = "combat-effect"
            fragment.position = position
            fragment.fillColor = index.isMultiple(of: 3) ? .white : color
            fragment.strokeColor = .clear
            fragment.alpha = index.isMultiple(of: 3) ? 0.78 : 0.90
            fragment.blendMode = .add
            fragment.zPosition = 25
            addChild(fragment)
            fragment.run(.sequence([
                .wait(forDuration: TimeInterval(index % 3) * 0.012),
                .group([
                    .moveBy(x: cos(angle) * distance, y: sin(angle) * distance + 10, duration: 0.24),
                    .rotate(byAngle: CGFloat.random(in: -1.3...1.3), duration: 0.24),
                    .fadeOut(withDuration: 0.25)
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// A layered upward dissolution reads as the foe losing physical cohesion;
    /// the illustration keeps its authored proportions until it fades away.
    private func spawnEnemyDissolve(at position: CGPoint, color: UIColor, scale: CGFloat) {
        let moteCount = Int(16 * scale)
        for index in 0..<moteCount {
            let mote = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.2...3.2) * scale)
            mote.name = "combat-effect"
            mote.position = CGPoint(
                x: position.x + CGFloat.random(in: -34...34) * scale,
                y: position.y + CGFloat.random(in: -10...62) * scale
            )
            mote.fillColor = index.isMultiple(of: 4) ? .white : color
            mote.strokeColor = .clear
            mote.alpha = 0
            mote.blendMode = .add
            mote.zPosition = 24
            addChild(mote)

            let delay = TimeInterval(index % 6) * 0.035
            mote.run(.sequence([
                .wait(forDuration: delay),
                .fadeAlpha(to: CGFloat.random(in: 0.56...0.92), duration: 0.07),
                .group([
                    .moveBy(
                        x: CGFloat.random(in: -18...18) * scale,
                        y: CGFloat.random(in: 34...82) * scale,
                        duration: 0.48
                    ),
                    .scale(to: 0.18, duration: 0.48),
                    .fadeOut(withDuration: 0.48)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnDashTrail(from start: CGPoint, to end: CGPoint, color: UIColor) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        for index in 0..<5 {
            let progress = CGFloat(index) / 5
            let echo = SKShapeNode(ellipseOf: CGSize(width: 34, height: 52))
            echo.name = "combat-effect"
            echo.position = CGPoint(x: start.x + dx * progress, y: start.y + dy * progress)
            echo.fillColor = color.withAlphaComponent(0.06)
            echo.strokeColor = color.withAlphaComponent(0.58)
            echo.lineWidth = 2
            echo.zPosition = 19
            addChild(echo)
            echo.run(.sequence([
                .wait(forDuration: TimeInterval(index) * 0.025),
                .group([.scale(to: 1.5, duration: 0.24), .fadeOut(withDuration: 0.24)]),
                .removeFromParent()
            ]))
        }
    }

    /// A large, short-lived battlefield composition sits behind the authored
    /// raster tarot explosion. It gives important Fool skills the broad sweep
    /// and exposure change of a commercial mobile-game finisher without ever
    /// stretching the character or monster artwork.
    private func spawnGrandArcanaSweep(
        at position: CGPoint,
        color: UIColor,
        intensity: CGFloat
    ) {
        // Important skills are composed around the battlefield, rather than
        // only around one enemy. Keep the lower HUD clear while letting the
        // visible spell body fill nearly the full width of the arena.
        let center = CGPoint(x: size.width / 2, y: position.y + 18)
        let flash = SKSpriteNode(
            color: UIColor.systemYellow.withAlphaComponent(0.22 * intensity),
            size: CGSize(width: size.width * 1.75, height: min(size.height * 0.58, 510))
        )
        flash.name = "combat-effect"
        flash.position = center
        flash.blendMode = .add
        flash.zPosition = 21
        flash.alpha = 0
        addChild(flash)
        flash.run(.sequence([
            .fadeAlpha(to: 1, duration: 0.075),
            .wait(forDuration: 0.10),
            .fadeOut(withDuration: 0.42),
            .removeFromParent()
        ]))

        // Three readable cards open like a hand before the detonation. The
        // atlas is authored raster art, so the player can identify this as a
        // Fool-path card spell instead of a generic particle flash.
        let castFrames = foolTarotVFXFrames()
        let cardFrameIndices = [1, 2, 3]
        let cardOffsets: [(CGFloat, CGFloat, CGFloat)] = [
            (-92, -0.30, -16),
            (0, 0, 30),
            (92, 0.30, -16)
        ]
        for (slot, frameIndex) in cardFrameIndices.enumerated() {
            guard castFrames.indices.contains(frameIndex) else { continue }
            let card = SKSpriteNode(texture: castFrames[frameIndex])
            card.name = "combat-effect"
            card.position = CGPoint(x: center.x, y: center.y - 34)
            let cardSize = 348 * intensity
            card.size = CGSize(width: cardSize, height: cardSize)
            card.blendMode = .add
            card.zPosition = 26 + CGFloat(slot) * 0.1
            card.alpha = 0
            card.setScale(0.22)
            addChild(card)

            let layout = cardOffsets[slot]
            let destination = CGPoint(x: center.x + layout.0, y: center.y + layout.2)
            card.run(.sequence([
                .wait(forDuration: TimeInterval(slot) * 0.035),
                .group([
                    .fadeAlpha(to: 0.96, duration: 0.10),
                    .scale(to: 1, duration: 0.23),
                    .move(to: destination, duration: 0.23),
                    .rotate(toAngle: layout.1, duration: 0.23, shortestUnitArc: true)
                ]),
                .wait(forDuration: 0.15),
                .group([
                    .scale(to: 1.28, duration: 0.20),
                    .fadeOut(withDuration: 0.22),
                    .moveBy(x: layout.0 * 0.16, y: 28, duration: 0.22)
                ]),
                .removeFromParent()
            ]))
        }

        // Broad curved bands frame the raster impact. The pale core makes the
        // sweep readable in daylight; purple and gold edges preserve the Fool
        // palette instead of becoming a generic white flash.
        let sweepPath = CGMutablePath()
        sweepPath.move(to: CGPoint(x: -size.width * 0.92, y: -112))
        sweepPath.addCurve(
            to: CGPoint(x: size.width * 0.92, y: 92),
            control1: CGPoint(x: -size.width * 0.28, y: 128),
            control2: CGPoint(x: size.width * 0.30, y: -82)
        )

        let bands: [(UIColor, CGFloat, CGFloat, TimeInterval)] = [
            (.systemYellow.withAlphaComponent(0.78), 52, 26, 0.18),
            (color.withAlphaComponent(0.96), 30, 21, 0.205),
            (.white.withAlphaComponent(0.98), 10, 13, 0.23)
        ]
        for (bandColor, width, glow, delay) in bands {
            let sweep = SKShapeNode(path: sweepPath)
            sweep.name = "combat-effect"
            sweep.position = center
            sweep.strokeColor = bandColor
            sweep.lineWidth = width * intensity
            sweep.glowWidth = glow * intensity
            sweep.blendMode = .add
            sweep.zPosition = 28
            sweep.alpha = 0
            sweep.setScale(0.78)
            addChild(sweep)
            sweep.run(.sequence([
                .wait(forDuration: delay),
                .group([.fadeAlpha(to: 1, duration: 0.08), .scale(to: 1.06, duration: 0.20)]),
                .wait(forDuration: 0.06),
                .group([
                    .scale(to: 1.20, duration: 0.30),
                    .fadeOut(withDuration: 0.30),
                    .moveBy(x: 18, y: 24, duration: 0.30)
                ]),
                .removeFromParent()
            ]))
        }

        // A crossing sweep adds depth and prevents the effect reading as one
        // flat line laid on top of the arena.
        let crossingPath = CGMutablePath()
        crossingPath.move(to: CGPoint(x: -size.width * 0.88, y: 132))
        crossingPath.addCurve(
            to: CGPoint(x: size.width * 0.88, y: -88),
            control1: CGPoint(x: -size.width * 0.22, y: -48),
            control2: CGPoint(x: size.width * 0.26, y: 72)
        )
        let crossing = SKShapeNode(path: crossingPath)
        crossing.name = "combat-effect"
        crossing.position = center
        crossing.strokeColor = UIColor.systemYellow.withAlphaComponent(0.76)
        crossing.lineWidth = 28 * intensity
        crossing.glowWidth = 22 * intensity
        crossing.blendMode = .add
        crossing.zPosition = 27
        crossing.alpha = 0
        addChild(crossing)
        crossing.run(.sequence([
            .wait(forDuration: 0.25),
            .group([.fadeIn(withDuration: 0.07), .scale(to: 1.08, duration: 0.18)]),
            .wait(forDuration: 0.05),
            .group([.fadeOut(withDuration: 0.30), .scale(to: 1.24, duration: 0.30)]),
            .removeFromParent()
        ]))

        sceneCamera.removeAction(forKey: "arcana-impact")
        sceneCamera.run(.sequence([
            .scale(to: 0.985, duration: 0.07),
            .scale(to: 1.012, duration: 0.10),
            .scale(to: 1, duration: 0.16)
        ]), withKey: "arcana-impact")
    }

    private func spawnAreaBurst(at position: CGPoint, color: UIColor, radius: CGFloat) {
        for index in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: 22)
            ring.name = "combat-effect"
            ring.position = position
            ring.fillColor = color.withAlphaComponent(index == 0 ? 0.16 : 0.04)
            ring.strokeColor = color.withAlphaComponent(0.92)
            ring.lineWidth = CGFloat(4 - index)
            ring.glowWidth = 10
            ring.zPosition = 20 + CGFloat(index)
            addChild(ring)
            ring.run(.sequence([
                .wait(forDuration: TimeInterval(index) * 0.08),
                .group([
                    .scale(to: radius / 22, duration: 0.42),
                    .fadeOut(withDuration: 0.46),
                    .rotate(byAngle: index.isMultiple(of: 2) ? .pi : -.pi, duration: 0.42)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnEnemySlash(at position: CGPoint, color: UIColor, radius: CGFloat) {
        let slashPath = CGMutablePath()
        slashPath.addArc(
            center: position,
            radius: radius * 0.72,
            startAngle: -.pi * 0.15,
            endAngle: .pi * 0.72,
            clockwise: false
        )
        let slash = SKShapeNode(path: slashPath)
        slash.name = "combat-effect"
        slash.strokeColor = color
        slash.lineWidth = 10
        slash.glowWidth = 15
        slash.zPosition = 23
        slash.alpha = 0
        addChild(slash)
        slash.run(.sequence([
            .group([.scale(to: 1.08, duration: 0.08), .fadeIn(withDuration: 0.06)]),
            .wait(forDuration: 0.15),
            .group([.scale(to: 1.28, duration: 0.28), .fadeOut(withDuration: 0.28)]),
            .removeFromParent()
        ]))
    }

    private func clockGuardSkillVFXID(
        for enemy: DungeonEnemyActor,
        intent: String
    ) -> String {
        let contentID = enemy.spawn.id
            .split(separator: "#", maxSplits: 1)
            .first
            .map(String.init) ?? enemy.spawn.id
        let authoredVFXID = MPCChapterOneCatalog.enemies
            .first(where: { $0.id == contentID })?
            .skills
            .first(where: { $0.intent == intent })?
            .vfxID
        if let authoredVFXID, !authoredVFXID.isEmpty {
            return authoredVFXID
        }
        switch intent {
        case "guard":
            return "clock_guard_violet_mantle"
        case "thirteenth_charge", "thirteenth_bell":
            return "clock_guard_thirteenth_bell"
        default:
            return "clock_guard_crimson_crescent"
        }
    }

    private func presentClockGuardSkillVFX(id: String, at position: CGPoint) {
        switch id {
        case "clock_guard_violet_mantle":
            // In the Unity-backed encounters the authored full-body shield
            // cannot share the moving model transform and reads as a detached
            // remnant after Sidestep breaks the parasite seal. The shield is
            // therefore reserved for the short player-impact flash.
            if !effectsOnlyOverlayEnabled {
                spawnClockGuardShieldPulse(at: position)
            }
        case "clock_guard_thirteenth_bell":
            spawnClockGuardThirteenthBell(at: position)
        default:
            spawnClockGuardCrimsonSlash(at: position)
        }
    }

    /// A full-bodied curved sword wave. The high-resolution raster texture
    /// keeps its blade silhouette at phone scale, while two faint delayed
    /// echoes supply motion without turning the hit into a mechanical fan.
    private func spawnClockGuardCrimsonSlash(at position: CGPoint) {
        let texture = clockGuardSkillVFXTexture(id: "clock_guard_crimson_crescent")
        let layers: [(size: CGFloat, rotation: CGFloat, delay: TimeInterval, alpha: CGFloat)] = [
            (610, -0.15, 0.00, 0.34),
            (565, -0.09, 0.045, 0.58),
            (530, -0.04, 0.085, 1.00)
        ]

        for (index, layer) in layers.enumerated() {
            let slash = SKSpriteNode(texture: texture)
            slash.name = "combat-effect-clock-guard-crimson-crescent"
            slash.position = position
            slash.size = CGSize(width: layer.size, height: layer.size)
            slash.zRotation = layer.rotation
            slash.blendMode = .add
            slash.zPosition = 29 + CGFloat(index) * 0.4
            slash.alpha = 0
            slash.setScale(0.42)
            addChild(slash)
            slash.run(.sequence([
                .wait(forDuration: layer.delay),
                .group([
                    .fadeAlpha(to: layer.alpha, duration: 0.055),
                    .scale(to: 1.02, duration: 0.16),
                    .rotate(byAngle: 0.10, duration: 0.16)
                ]),
                .group([
                    .scale(to: 1.14, duration: 0.24),
                    .moveBy(x: -18, y: 12, duration: 0.24),
                    .fadeOut(withDuration: 0.25)
                ]),
                .removeFromParent()
            ]))
        }

        spawnResidualArcana(
            at: position,
            color: UIColor(red: 1, green: 0.14, blue: 0.12, alpha: 1),
            count: 18
        )
        spawnGroundImpact(
            at: CGPoint(x: position.x, y: position.y - 78),
            color: UIColor(red: 0.72, green: 0.02, blue: 0.06, alpha: 1),
            radius: 96
        )
    }

    private func spawnClockGuardShieldPulse(at position: CGPoint) {
        let pulse = makeClockGuardFireShield()
        pulse.name = "combat-effect-clock-guard-violet-mantle"
        pulse.position = position
        pulse.zPosition = 27
        pulse.alpha = 0
        pulse.setScale(0.72)
        addChild(pulse)
        pulse.run(.sequence([
            .group([
                .fadeAlpha(to: 0.82, duration: 0.24),
                .scale(to: 0.88, duration: 0.52)
            ]),
            .group([
                .scale(to: 0.96, duration: 0.64),
                .fadeOut(withDuration: 0.64)
            ]),
            .removeFromParent()
        ]))
    }

    private func spawnClockGuardThirteenthBell(at position: CGPoint) {
        let texture = clockGuardSkillVFXTexture(id: "clock_guard_thirteenth_bell")
        for (index, delay) in [0.0, 0.08].enumerated() {
            let strike = SKSpriteNode(texture: texture)
            strike.name = "combat-effect-clock-guard-thirteenth-bell"
            strike.position = position
            strike.size = CGSize(width: index == 0 ? 690 : 620, height: index == 0 ? 690 : 620)
            strike.blendMode = .add
            strike.zPosition = 30 + CGFloat(index)
            strike.alpha = 0
            strike.setScale(index == 0 ? 0.48 : 0.66)
            strike.zRotation = index == 0 ? -0.08 : 0.05
            addChild(strike)
            strike.run(.sequence([
                .wait(forDuration: delay),
                .group([
                    .fadeAlpha(to: index == 0 ? 0.72 : 1, duration: 0.08),
                    .scale(to: 1.04, duration: 0.22)
                ]),
                .wait(forDuration: 0.06),
                .group([
                    .scale(to: 1.18, duration: 0.32),
                    .fadeOut(withDuration: 0.32)
                ]),
                .removeFromParent()
            ]))
        }
        spawnAreaBurst(
            at: position,
            color: UIColor(red: 1, green: 0.24, blue: 0.12, alpha: 1),
            radius: 154
        )
    }

    private func clockGuardSkillVFXTexture(id: String) -> SKTexture {
        if let cached = clockGuardSkillVFXTextureCache[id] {
            return cached
        }

        let canvas = CGSize(width: 1_024, height: 1_024)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.setLineJoin(.round)
            context.setLineCap(.round)

            if id == "clock_guard_thirteenth_bell" {
                drawClockGuardThirteenthBell(in: context)
            } else {
                drawClockGuardCrimsonCrescent(in: context)
            }
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        clockGuardSkillVFXTextureCache[id] = texture
        return texture
    }

    private func drawClockGuardCrimsonCrescent(in context: CGContext) {
        let blade = CGMutablePath()
        blade.move(to: CGPoint(x: 78, y: 788))
        blade.addCurve(
            to: CGPoint(x: 930, y: 176),
            control1: CGPoint(x: 314, y: 474),
            control2: CGPoint(x: 690, y: 184)
        )
        blade.addCurve(
            to: CGPoint(x: 842, y: 282),
            control1: CGPoint(x: 916, y: 218),
            control2: CGPoint(x: 880, y: 258)
        )
        blade.addCurve(
            to: CGPoint(x: 126, y: 844),
            control1: CGPoint(x: 604, y: 324),
            control2: CGPoint(x: 282, y: 572)
        )
        blade.closeSubpath()

        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: 54,
            color: UIColor(red: 1, green: 0.02, blue: 0.04, alpha: 0.92).cgColor
        )
        context.addPath(blade)
        context.setFillColor(UIColor(red: 0.92, green: 0.01, blue: 0.035, alpha: 0.86).cgColor)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(blade)
        context.clip()
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor(red: 0.26, green: 0.0, blue: 0.02, alpha: 0.25).cgColor,
                UIColor(red: 0.98, green: 0.025, blue: 0.06, alpha: 0.94).cgColor,
                UIColor(red: 1.0, green: 0.84, blue: 0.38, alpha: 1).cgColor,
                UIColor.white.cgColor
            ] as CFArray,
            locations: [0.0, 0.48, 0.82, 1.0]
        )
        if let gradient {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 128, y: 830),
                end: CGPoint(x: 904, y: 184),
                options: []
            )
        }
        context.restoreGState()

        let edge = CGMutablePath()
        edge.move(to: CGPoint(x: 112, y: 800))
        edge.addCurve(
            to: CGPoint(x: 924, y: 184),
            control1: CGPoint(x: 352, y: 482),
            control2: CGPoint(x: 708, y: 198)
        )
        context.addPath(edge)
        context.setStrokeColor(UIColor(red: 1, green: 0.93, blue: 0.72, alpha: 0.98).cgColor)
        context.setLineWidth(11)
        context.setShadow(offset: .zero, blur: 20, color: UIColor.white.cgColor)
        context.strokePath()

        for index in 0..<15 {
            let t = CGFloat(index) / 14
            let x = 132 + t * 704
            let y = 810 - t * 548 + sin(t * .pi * 4) * 28
            let ember = CGRect(
                x: x,
                y: y,
                width: 7 + CGFloat(index % 3) * 4,
                height: 28 + CGFloat(index % 4) * 8
            )
            context.setFillColor(
                UIColor(red: 1, green: 0.19 + t * 0.48, blue: 0.08, alpha: 0.78).cgColor
            )
            context.fillEllipse(in: ember)
        }
    }

    private func drawClockGuardThirteenthBell(in context: CGContext) {
        let center = CGPoint(x: 512, y: 512)
        context.setShadow(
            offset: .zero,
            blur: 34,
            color: UIColor(red: 0.82, green: 0.06, blue: 0.10, alpha: 0.88).cgColor
        )
        context.setStrokeColor(UIColor(red: 1, green: 0.48, blue: 0.16, alpha: 0.82).cgColor)
        context.setLineWidth(10)
        context.strokeEllipse(in: CGRect(x: 196, y: 196, width: 632, height: 632))

        for index in 0..<13 {
            let angle = CGFloat(index) / 13 * .pi * 2 - .pi / 2
            let inner = CGPoint(
                x: center.x + cos(angle) * 250,
                y: center.y + sin(angle) * 250
            )
            let outer = CGPoint(
                x: center.x + cos(angle) * (index == 12 ? 344 : 298),
                y: center.y + sin(angle) * (index == 12 ? 344 : 298)
            )
            context.move(to: inner)
            context.addLine(to: outer)
            context.setLineWidth(index == 12 ? 20 : 7)
            context.strokePath()
        }

        let hand = CGMutablePath()
        hand.move(to: CGPoint(x: 470, y: 790))
        hand.addLine(to: CGPoint(x: 502, y: 156))
        hand.addLine(to: CGPoint(x: 548, y: 156))
        hand.addLine(to: CGPoint(x: 568, y: 790))
        hand.addLine(to: CGPoint(x: 520, y: 896))
        hand.closeSubpath()
        context.addPath(hand)
        context.setFillColor(UIColor(red: 0.86, green: 0.01, blue: 0.04, alpha: 0.92).cgColor)
        context.fillPath()

        context.move(to: CGPoint(x: 522, y: 874))
        context.addLine(to: CGPoint(x: 522, y: 170))
        context.setStrokeColor(UIColor(red: 1, green: 0.94, blue: 0.72, alpha: 1).cgColor)
        context.setLineWidth(12)
        context.strokePath()
    }

    private func castVictoryPulse() {
        spawnAreaBurst(at: player.position, color: .systemYellow, radius: 210)
    }

    private func spawnDamageNumber(_ damage: Int, at position: CGPoint, color: UIColor) {
        spawnCombatNumber("−\(damage)", at: position, color: color)
    }

    private func spawnBigDamageNumber(_ damage: Int, at position: CGPoint) {
        spawnCombatNumber("−\(damage)", at: position, color: .systemRed, scale: 1.10)
    }

    private func spawnCombatNumber(
        _ text: String,
        at position: CGPoint,
        color: UIColor,
        scale: CGFloat = 1
    ) {
        let label = SKLabelNode(text: text)
        label.name = "combat-effect"
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 50
        label.fontColor = color
        label.position = CGPoint(x: position.x, y: position.y + 14)
        label.zPosition = 44
        label.setScale(0.82 * scale)
        label.alpha = 0
        addChild(label)
        label.run(.sequence([
            .group([.fadeIn(withDuration: 0.06), .scale(to: 1.16, duration: 0.13)]),
            .wait(forDuration: 0.24),
            .group([
                .moveBy(x: 0, y: 128, duration: 1.05),
                .fadeOut(withDuration: 1.05),
                .scale(to: 0.96, duration: 1.05)
            ]),
            .removeFromParent()
        ]))
    }

    private func spawnFloatingText(
        _ text: String,
        at position: CGPoint,
        color: UIColor,
        holdDuration: TimeInterval = 0,
        fontSize: CGFloat? = nil
    ) {
        let label = SKLabelNode(text: text)
        label.name = "combat-effect"
        label.fontName = "AvenirNext-Bold"
        label.fontSize = fontSize ?? (text.first == "-" ? 18 : 14)
        label.fontColor = color
        label.position = CGPoint(x: position.x, y: position.y + 44)
        label.zPosition = 40
        addChild(label)
        label.run(.sequence([
            .fadeIn(withDuration: 0.08),
            .wait(forDuration: holdDuration),
            .group([.moveBy(x: 0, y: 30, duration: 0.52), .fadeOut(withDuration: 0.52)]),
            .removeFromParent()
        ]))
    }

    private func shakeCamera() {
        sceneCamera.removeAction(forKey: "shake")
        sceneCamera.run(.sequence([
            .moveBy(x: -5, y: 2, duration: 0.035),
            .moveBy(x: 9, y: -4, duration: 0.045),
            .moveBy(x: -7, y: 3, duration: 0.045),
            .moveBy(x: 3, y: -1, duration: 0.035)
        ]), withKey: "shake")
    }

    private func animatePlayerAttack() {
        playerVisual.removeAction(forKey: "idle")
        playerVisual.removeAction(forKey: "walk")
        playPlayerMotion(.attack, restart: true)
        playerVisual.run(.sequence([
            // Six sampled FBX frames need their full contact beat before idle
            // takes ownership again. The old 250 ms reset cut the cast in half
            // and made the protagonist look static beside the projectile.
            .wait(forDuration: 0.44),
            .run { [weak self] in self?.startIdleAnimation() }
        ]), withKey: "attack")
    }

    private func animatePlayerSkill(_ motion: FoolMotion) {
        playerVisual.removeAction(forKey: "idle")
        playerVisual.removeAction(forKey: "walk")
        playPlayerMotion(motion, restart: true)
        playerVisual.run(.sequence([
            .wait(forDuration: 0.48 * playerAnimationTimingMultiplier),
            .run { [weak self] in self?.startIdleAnimation() }
        ]), withKey: "cast")
    }

    private func selectedOrNearestEnemy() -> DungeonEnemyActor? {
        if let selected = selectedEnemy(), selected.isAlive { return selected }
        return enemies.filter(\.isAlive).min {
            distance(from: player.position, to: $0.node.position) <
            distance(from: player.position, to: $1.node.position)
        }
    }

    private func selectedEnemy() -> DungeonEnemyActor? {
        guard let selectedEnemyID else { return nil }
        return enemies.first { $0.spawn.id == selectedEnemyID }
    }

    private func selectEnemy(_ enemy: DungeonEnemyActor) {
        selectedEnemyID = enemy.spawn.id
        facePlayer(toward: enemy.node.position)
        updateSelectionRings()
    }

    private func updateSelectionRings() {
        enemies.forEach { enemy in
            // A white selection stroke turns a thin red health fill pale.
            // Keep the fill materially red; target selection is already
            // communicated by the enemy's ground ring.
            enemy.healthFill.glowWidth = 0
            enemy.healthFill.strokeColor = .clear
            enemy.healthFill.lineWidth = 0
        }
    }

    private func enemy(at point: CGPoint) -> DungeonEnemyActor? {
        enemies.filter(\.isAlive).min {
            distance(from: $0.node.position, to: point) < distance(from: $1.node.position, to: point)
        }.flatMap {
            let hitRadius: CGFloat = $0.spawn.rank == .boss ? 68 : 54
            return distance(from: $0.node.position, to: point) < hitRadius ? $0 : nil
        }
    }

    private func updateDepthScale() {
        // Fixed formation means a fixed readable scale. Perspective shrinking
        // made the hero look undersized even though the source art was sharp.
        player.setScale(1.05)
        player.zPosition = 10 + (size.height - player.position.y) / size.height
    }

    private func startIdleAnimation() {
        guard playerVisual.action(forKey: "idle") == nil else { return }
        playerVisual.removeAction(forKey: "walk")
        playerVisual.removeAction(forKey: "attack")
        playerVisual.removeAction(forKey: "cast")
        playerVisual.position.y = 0
        playerVisual.zRotation = 0
        playerVisual.setScale(1)
        playPlayerMotion(.idle)
        playerVisual.run(.repeatForever(.wait(forDuration: 1)), withKey: "idle")
    }

    private func startWalkingAnimation() {
        guard playerVisual.action(forKey: "walk") == nil else { return }
        playerVisual.removeAction(forKey: "idle")
        playerVisual.removeAction(forKey: "attack")
        playerVisual.removeAction(forKey: "cast")
        playerVisual.position.y = 0
        playerVisual.zRotation = 0
        playerVisual.setScale(1)
        playPlayerMotion(.run)
        playerVisual.run(.repeatForever(.wait(forDuration: 1)), withKey: "walk")
    }

    private func facePlayer(toward point: CGPoint) {
        // The hero stands in a fixed turn-based formation below every enemy.
        // Never let lateral target slots turn the full-body illustration away
        // from the arena; attack/hit clips must preserve this north-facing pose.
        setPlayerFacing(.north)
    }

    private func updatePlayerFacing(dx: CGFloat, dy: CGFloat) {
        guard hypot(dx, dy) > 1.5 else { return }
        let facing: FoolFacing
        if abs(dx) > abs(dy) {
            facing = dx >= 0 ? .east : .west
        } else {
            facing = dy >= 0 ? .north : .south
        }
        setPlayerFacing(facing)
    }

    private func setPlayerFacing(_ facing: FoolFacing) {
        guard facing != playerFacing else { return }
        playerFacing = facing
        playPlayerMotion(playerMotion, restart: true)
    }

    private func updatePlayerTargetFacing() {
        guard !combat.isDefeated,
              route.isEmpty,
              playerVisual.action(forKey: "attack") == nil,
              playerVisual.action(forKey: "cast") == nil,
              playerVisual.action(forKey: "death") == nil,
              let enemy = selectedEnemy(), enemy.isAlive else { return }
        facePlayer(toward: enemy.node.position)
    }

    private func playPlayerMotion(_ motion: FoolMotion, restart: Bool = false) {
        guard path.id == .fool, let artwork = playerArtwork else { return }
        if !restart, motion == playerMotion, artwork.action(forKey: "frame-animation") != nil { return }

        playerMotion = motion
        artwork.removeAction(forKey: "frame-animation")
        let textures = playerTextures(for: motion, facing: playerFacing)
        guard let first = textures.first else { return }
        artwork.texture = first
        artwork.size = fittedPlayerArtworkSize(for: first)

        if playerUsesFallbackTexture {
            artwork.xScale = playerFacing == .west ? -1 : 1
            return
        }

        artwork.xScale = playerFacing == .west ? -1 : 1
        let animation = SKAction.animate(
            with: textures,
            timePerFrame: motion.frameTime * playerAnimationTimingMultiplier,
            resize: false,
            restore: false
        )
        artwork.run(motion.loops ? .repeatForever(animation) : animation, withKey: "frame-animation")
    }

    private func fittedPlayerArtworkSize(for texture: SKTexture) -> CGSize {
        let source = texture.size()
        guard source.width > 0, source.height > 0 else {
            return CGSize(width: 136, height: 136)
        }
        let bounds = CGSize(width: 136, height: 136)
        let scale = min(bounds.width / source.width, bounds.height / source.height)
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

    private func fittedArtworkSize(for texture: SKTexture, within bounds: CGSize) -> CGSize {
        let source = texture.size()
        guard source.width > 0, source.height > 0 else { return bounds }
        let scale = min(bounds.width / source.width, bounds.height / source.height)
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

    /// Production enemy clips use a stable prefix plus two-digit frame index.
    /// The clip is accepted only when every frame exists, preventing a partially
    /// generated strip from producing jumps or changing the character model.
    private func productionEnemyClip(
        prefix: String,
        frameCount: Int,
        fallback: [SKTexture] = []
    ) -> [SKTexture] {
        let names = (1...frameCount).map { String(format: "%@%02d", prefix, $0) }
        let textures = normalizedTextures(imageNames: names)
        return textures.count == frameCount ? textures : fallback
    }

    /// Removes transparent margins while keeping every frame in a clip on one
    /// shared canvas. This preserves a common scale and bottom-center foot anchor,
    /// preventing generated 512 px frames from shrinking or floating mid-action.
    private func normalizedTextures(imageNames: [String]) -> [SKTexture] {
        let images = imageNames.compactMap(UIImage.init(named:))
        guard images.count == imageNames.count else { return [] }

        let frames = images.compactMap { image -> (image: UIImage, bounds: CGRect)? in
            guard let bounds = opaquePixelBounds(in: image) else { return nil }
            return (image, bounds)
        }
        guard frames.count == images.count else { return [] }

        let padding: CGFloat = 8
        let contentWidth = frames.map(\.bounds.width).max() ?? 1
        let contentHeight = frames.map(\.bounds.height).max() ?? 1
        let canvasSize = CGSize(
            width: ceil(contentWidth + padding * 2),
            height: ceil(contentHeight + padding * 2)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return frames.map { frame in
            let normalized = renderer.image { _ in
                let origin = CGPoint(
                    x: padding + (contentWidth - frame.bounds.width) * 0.5 - frame.bounds.minX,
                    y: canvasSize.height - padding - frame.bounds.maxY
                )
                frame.image.draw(at: origin)
            }
            let texture = SKTexture(image: normalized)
            texture.filteringMode = .linear
            return texture
        }
    }

    /// Crops a pre-registered render sequence with one shared source rectangle.
    /// Unlike `normalizedTextures`, this never centers individual silhouettes:
    /// a weapon may cross the body without moving the actor's world-space root.
    private func registeredTextures(imageNames: [String]) -> [SKTexture] {
        let images = imageNames.compactMap(UIImage.init(named:))
        guard images.count == imageNames.count else { return [] }

        let bounds = images.compactMap(opaquePixelBounds(in:))
        guard bounds.count == images.count,
              let firstBounds = bounds.first else { return [] }

        let contentBounds = bounds.dropFirst().reduce(firstBounds) { partial, next in
            partial.union(next)
        }
        let padding: CGFloat = 8
        let canvasSize = CGSize(
            width: ceil(contentBounds.width + padding * 2),
            height: ceil(contentBounds.height + padding * 2)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return images.map { image in
            let registered = renderer.image { _ in
                image.draw(at: CGPoint(
                    x: padding - contentBounds.minX,
                    y: padding - contentBounds.minY
                ))
            }
            let texture = SKTexture(image: registered)
            texture.filteringMode = .linear
            return texture
        }
    }

    private func trimmedTexture(imageNamed name: String) -> SKTexture {
        if let texture = normalizedTextures(imageNames: [name]).first {
            return texture
        }
        let texture = SKTexture(imageNamed: name)
        texture.filteringMode = .linear
        return texture
    }

    private func opaquePixelBounds(in image: UIImage) -> CGRect? {
        guard let source = image.cgImage else { return nil }
        let width = source.width
        let height = source.height
        guard width > 0, height > 0 else { return nil }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * bytesPerRow + x * bytesPerPixel + 3] > 8 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }

    private func playerTextures(for motion: FoolMotion, facing: FoolFacing) -> [SKTexture] {
        let cacheKey = "\(motion.rawValue)-\(facing.rawValue)"
        if let cached = playerTextureCache[cacheKey] {
            playerUsesFallbackTexture = cached.count == 1
            return cached
        }

        // UnityFramework is device-only. In the Simulator, Chapter One uses
        // SpriteKit as its visual compatibility layer, so sample the exact same
        // Fool FBX clips into transparent frames instead of holding an unrelated
        // static portrait whenever the live Animator would have cast a spell.
        if presentationOnly, facing == .north {
            let sampled3DNames: [String]
            switch motion {
            case .idle:
                sampled3DNames = (1...4).map {
                    String(format: "FoolUnityCombatIdleN%02d", $0)
                }
            case .attack, .skillStrike, .skillMobility, .skillUltimate:
                sampled3DNames = (1...6).map {
                    String(format: "FoolUnityCombatCastN%02d", $0)
                }
            case .run, .hit, .death:
                sampled3DNames = []
            }
            if !sampled3DNames.isEmpty {
                let sampled3DTextures = normalizedTextures(imageNames: sampled3DNames)
                if sampled3DTextures.count == sampled3DNames.count {
                    playerTextureCache[cacheKey] = sampled3DTextures
                    playerUsesFallbackTexture = false
                    return sampled3DTextures
                }
            }
        }

        // `FoolRun*` and `FoolAttack*` are archived as historical prototypes.
        // They use a different model, projection and costume, so playing them
        // makes the hero appear to morph. Commercial clips must enter through
        // this approved skin-specific namespace.
        let sourceFacing = facing == .west ? FoolFacing.east.rawValue : facing.rawValue
        let names = (1...motion.frameCount).map { index in
            String(format: "FoolBrightCombat%@%@%02d", motion.rawValue, sourceFacing, index)
        }
        let approvedTextures = normalizedTextures(imageNames: names)
        let textures: [SKTexture]

        if approvedTextures.count == motion.frameCount {
            textures = approvedTextures
        } else {
            // Missing action art must not fall back to the old front-facing
            // prototype. That caused the hero to appear to turn around for a
            // single attack or hit frame. Hold the approved same-skin,
            // north-facing idle pose and let combat VFX sell the action until
            // a production action strip is supplied.
            let idleNames = (1...FoolMotion.idle.frameCount).map { index in
                String(format: "FoolBrightCombatIdleN%02d", index)
            }
            let idleTextures = normalizedTextures(imageNames: idleNames)
            textures = idleTextures.first.map { [$0] }
                ?? [trimmedTexture(imageNamed: "FoolCombatTopDownV3")]
        }

        playerTextureCache[cacheKey] = textures
        playerUsesFallbackTexture = textures.count == 1
        return textures
    }

    private func animatePlayerDeath() {
        guard player.action(forKey: "player-death-shatter") == nil else { return }
        playerVisual.removeAllActions()
        playPlayerMotion(.death, restart: true)
        let shatterOrigin: CGPoint
        if let artwork = playerArtwork {
            shatterOrigin = artwork.convert(
                CGPoint(x: 0, y: artwork.size.height * 0.44),
                to: self
            )
        } else {
            shatterOrigin = player.convert(CGPoint(x: 0, y: 10), to: self)
        }

        spawnPlayerDeathShards()
        spawnPlayerDeathEmbers(at: shatterOrigin)

        // The character holds for one readable beat, then vanishes behind the
        // outward-moving art shards. This avoids the old flat fade-out.
        let collapseScale = max(0.01, player.xScale * 0.90)
        player.run(.sequence([
            .wait(forDuration: 0.06),
            .group([
                .fadeOut(withDuration: 0.24),
                .scale(to: collapseScale, duration: 0.24)
            ])
        ]), withKey: "player-death-shatter")
    }

    private func spawnPlayerDeathShards() {
        guard let artwork = playerArtwork,
              let sourceTexture = artwork.texture,
              artwork.size.width > 0,
              artwork.size.height > 0 else { return }

        // Split the actual combat portrait into deterministic texture tiles,
        // so the player disperses as recognisable pieces of their own model.
        let columns = 4
        let rows = 4
        let tileWidth = artwork.size.width / CGFloat(columns)
        let tileHeight = artwork.size.height / CGFloat(rows)

        for row in 0..<rows {
            for column in 0..<columns {
                let sourceRect = CGRect(
                    x: CGFloat(column) / CGFloat(columns),
                    y: CGFloat(row) / CGFloat(rows),
                    width: 1 / CGFloat(columns),
                    height: 1 / CGFloat(rows)
                )
                let fragmentTexture = SKTexture(rect: sourceRect, in: sourceTexture)
                let fragment = SKSpriteNode(texture: fragmentTexture)
                fragment.name = "combat-effect-player-death-shard"
                fragment.size = CGSize(width: tileWidth, height: tileHeight)
                fragment.position = artwork.convert(
                    CGPoint(
                        x: -artwork.size.width * 0.5 + (CGFloat(column) + 0.5) * tileWidth,
                        y: (CGFloat(row) + 0.5) * tileHeight
                    ),
                    to: self
                )
                fragment.zPosition = 46
                fragment.blendMode = .alpha
                addChild(fragment)

                let index = row * columns + column
                let angle = CGFloat(index) / CGFloat(columns * rows) * .pi * 2
                let distance = CGFloat(28 + (index % 4) * 15)
                let verticalKick = CGFloat(18 + (row % 3) * 14)
                let destination = CGVector(
                    dx: cos(angle) * distance,
                    dy: sin(angle) * distance + verticalKick
                )
                let duration = TimeInterval(0.42 + Double(index % 4) * 0.06)
                fragment.run(.sequence([
                    .group([
                        .move(by: destination, duration: duration),
                        .rotate(byAngle: CGFloat(index.isMultiple(of: 2) ? 1 : -1) * .pi * 0.72, duration: duration),
                        .scale(to: 0.46, duration: duration),
                        .fadeOut(withDuration: duration)
                    ]),
                    .removeFromParent()
                ]))
            }
        }
    }

    private func spawnPlayerDeathEmbers(at origin: CGPoint) {
        let diamond = CGMutablePath()
        diamond.move(to: CGPoint(x: 0, y: 5))
        diamond.addLine(to: CGPoint(x: 3, y: 0))
        diamond.addLine(to: CGPoint(x: 0, y: -5))
        diamond.addLine(to: CGPoint(x: -3, y: 0))
        diamond.closeSubpath()

        for index in 0..<18 {
            let ember = SKShapeNode(path: diamond)
            ember.name = "combat-effect-player-death-ember"
            ember.position = origin
            ember.fillColor = index.isMultiple(of: 3)
                ? UIColor(red: 0.97, green: 0.72, blue: 0.25, alpha: 0.95)
                : UIColor(red: 0.61, green: 0.28, blue: 1.0, alpha: 0.90)
            ember.strokeColor = .clear
            ember.glowWidth = 4
            ember.zPosition = 47
            ember.setScale(index.isMultiple(of: 2) ? 0.78 : 0.54)
            addChild(ember)

            let angle = CGFloat(index) / 18 * .pi * 2
            let distance = CGFloat(38 + (index % 5) * 12)
            let duration = TimeInterval(0.34 + Double(index % 4) * 0.08)
            ember.run(.sequence([
                .group([
                    .moveBy(
                        x: cos(angle) * distance,
                        y: sin(angle) * distance + CGFloat(18 + index % 3 * 12),
                        duration: duration
                    ),
                    .rotate(byAngle: angle + .pi, duration: duration),
                    .fadeOut(withDuration: duration),
                    .scale(to: 0.08, duration: duration)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func publishState(
        _ status: String? = nil,
        feedback: Bool = false,
        force: Bool = true
    ) {
        if let status { combat.status = status }
        if feedback { combat.feedbackToken += 1 }
        combat.skillCooldowns = skillCooldowns
        combat.usedRelicIDs = usedRelicIDs

        if path.id == .fool {
            combat.pathResourceName = "预兆"
            combat.pathResourceValue = playerOmen
            combat.pathResourceMaximum = 6
        } else {
            combat.pathResourceName = nil
            combat.pathResourceValue = 0
            combat.pathResourceMaximum = 0
        }

        combat.playerStatusLabels = [
            playerReactionCharges > 0 ? "闪避×\(playerReactionCharges)" : nil,
            playerGuardCharges > 0 ? "防护×\(playerGuardCharges)" : nil,
            playerParryCharges > 0 ? "衡反×\(playerParryCharges)" : nil,
            playerCounterCharges > 0 ? "反写×\(playerCounterCharges)" : nil
        ].compactMap { $0 }

        let upcomingEnemies: [DungeonEnemyActor] = enemies
            .filter { $0.isAlive }
            .sorted { lhs, rhs in
                let lhsPriority = enemyTurnPriority(for: lhs.spawn.rank)
                let rhsPriority = enemyTurnPriority(for: rhs.spawn.rank)
                if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
                return lhs.node.position.x < rhs.node.position.x
            }
        combat.actionOrderLabels = upcomingEnemies.prefix(3).map { enemy in
            let intent = predictedEnemyIntent(for: enemy, upcoming: enemy.state != .windup)
            return "\(enemy.spawn.title) · \(intent.name) \(intent.damage)"
        }

        if let boss = upcomingEnemies.first(where: { $0.spawn.rank == .boss }),
           boss.willpower <= max(1, boss.maxWillpower / 3) {
            combat.tacticalHint = "控制窗口：击破意志可延后首领强攻"
        } else if upcomingEnemies.count >= 2 {
            combat.tacticalHint = "敌群聚集：群体技能收益更高"
        } else if let nextEnemy = upcomingEnemies.first {
            let intent = predictedEnemyIntent(for: nextEnemy, upcoming: nextEnemy.state != .windup)
            combat.tacticalHint = intent.damage >= 18
                ? "高伤预警：先用防护、闪避或反制"
                : "读取预警：保留克制技能应对下一击"
        } else {
            combat.tacticalHint = nil
        }

        if let boss = enemies.first(where: { $0.spawn.rank == .boss && $0.isAlive }) {
            let intent = predictedEnemyIntent(for: boss, upcoming: boss.state != .windup)
            combat.bossName = boss.spawn.title
            combat.bossHealthFraction = CGFloat(boss.health) / CGFloat(boss.spawn.maxHealth)
            combat.bossIsEnraged = boss.isEnraged
            combat.bossIntentName = intent.name
            combat.bossIntentDamage = intent.damage
            combat.bossWillpowerFraction = CGFloat(boss.willpower) / CGFloat(boss.maxWillpower)
            if boss.staggeredTurns > 0 {
                combat.bossControlOutcome = "已击破：下一行动延后"
            } else if boss.exposedTurns > 0 {
                combat.bossControlOutcome = "暴露窗口：受到伤害提高"
            } else {
                combat.bossControlOutcome = "击破结果：强攻延后并失去强化"
            }
        } else {
            combat.bossName = nil
            combat.bossHealthFraction = 0
            combat.bossIsEnraged = false
            combat.bossIntentName = nil
            combat.bossIntentDamage = 0
            combat.bossWillpowerFraction = 0
            combat.bossControlOutcome = nil
        }

        guard force || combat != lastPublishedCombat else { return }
        lastPublishedCombat = combat
        onStateChange?(combat)
    }
}
