import CoreGraphics
import SwiftUI

/// Debug-only authoring input for the portrait battle actor. Coordinates use
/// the visible battle viewport: x is left-to-right and yFromTop is top-to-
/// bottom. Keeping this as data lets the same placement drive SpriteKit,
/// Unity, and the test panel without tuning against screenshot pixels.
struct ChapterOnePlayerPlacement: Codable, Equatable {
    var x: Double
    var yFromTop: Double

    /// The existing authored formation. Its y value corresponds to the
    /// previous SpriteKit player anchor at y = 240 in a 932-point scene.
    static let standard = ChapterOnePlayerPlacement(
        x: 0.50,
        yFromTop: 1.0 - (240.0 / 932.0)
    )

    var normalized: ChapterOnePlayerPlacement {
        ChapterOnePlayerPlacement(
            x: min(max(x, 0.20), 0.80),
            yFromTop: min(max(yFromTop, 0.42), 0.90)
        )
    }

    func scenePoint(in size: CGSize) -> CGPoint {
        let value = normalized
        return CGPoint(
            x: size.width * value.x,
            y: size.height * (1.0 - value.yFromTop)
        )
    }
}

enum CombatPresentationMode {
    /// Portrait-friendly 2.5D combat. Units move on a logical lane/depth plane and
    /// are projected toward the top of the screen. Used by repeatable missions.
    case verticalAdvance
    /// Free movement on a painted arena. Used by each district's team dungeon.
    case freeArena
}

struct ForwardCombatProjection {
    let nearY: CGFloat
    let farY: CGFloat
    let nearHalfWidth: CGFloat
    let farHalfWidth: CGFloat
    let nearScale: CGFloat
    let farScale: CGFloat

    static let portrait = ForwardCombatProjection(
        nearY: 250,
        farY: 780,
        nearHalfWidth: 178,
        farHalfWidth: 82,
        nearScale: 1.08,
        farScale: 0.42
    )

    /// `lane` is -1...1 and `depth` is 0...1, where 1 is farther away.
    func point(lane: CGFloat, depth: CGFloat, sceneWidth: CGFloat) -> CGPoint {
        let clampedDepth = min(max(depth, 0), 1)
        let halfWidth = nearHalfWidth + (farHalfWidth - nearHalfWidth) * clampedDepth
        return CGPoint(
            x: sceneWidth * 0.5 + min(max(lane, -1), 1) * halfWidth,
            y: nearY + (farY - nearY) * clampedDepth
        )
    }

    func scale(at depth: CGFloat) -> CGFloat {
        let clampedDepth = min(max(depth, 0), 1)
        return nearScale + (farScale - nearScale) * clampedDepth
    }
}

enum CharacterAttachmentSlot: String, CaseIterable {
    case body
    case face
    case hairBack
    case hairFront
    case innerTop
    case outerCoatBack
    case outerCoatFront
    case gloves
    case trousers
    case boots
    case weaponBack
    case weaponFront
    case accessory
}

/// A skin replaces attachments without replacing the shared skeleton or clips.
struct CharacterSkinDefinition: Identifiable {
    let id: String
    let title: String
    let attachments: [CharacterAttachmentSlot: String]
    let spellPalette: [String]
}

enum SpellEffectPhase: String, CaseIterable {
    case telegraph
    case cast
    case travel
    case impact
    case residue
}

struct SpellEffectCue {
    let phase: SpellEffectPhase
    let assetName: String
    let duration: TimeInterval
    let anchorSlot: CharacterAttachmentSlot?
    let additiveBlend: Bool
    let cameraImpulse: CGFloat
}

struct PathSkillVFXKey: Hashable {
    let pathwayID: Pathway.ID
    let skillID: DungeonSkillID
}

enum SkillVFXIntensity: Int, Comparable {
    case restrained = 1
    case focused
    case field
    case spectacular
    case ultimate

    static func < (lhs: SkillVFXIntensity, rhs: SkillVFXIntensity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Visual timing is data-driven so a skin or pathway can replace presentation
/// without changing damage, hit detection or cooldown code.
struct SpellEffectRecipe: Identifiable {
    let id: String
    let key: PathSkillVFXKey
    let title: String
    let intensity: SkillVFXIntensity
    let cues: [SpellEffectCue]

    var totalDuration: TimeInterval {
        cues.reduce(0) { $0 + $1.duration }
    }

    func cue(for phase: SpellEffectPhase) -> SpellEffectCue? {
        cues.first { $0.phase == phase }
    }
}

struct BasicAttackVFXProfile {
    let sequence: Int
    let sharedTint: Color?
    let usesSharedBloom: Bool
    let bloomTitle: String
}

/// Basic attacks keep each pathway's own weapon, projectile and motion
/// silhouette. Sequence milestones may add a shared awakening layer without
/// replacing that pathway-specific choreography.
enum BasicAttackVFXCatalog {
    static func profile(forSequence sequence: Int) -> BasicAttackVFXProfile {
        if sequence == 9 {
            return BasicAttackVFXProfile(
                sequence: sequence,
                sharedTint: Color(red: 0.24, green: 0.68, blue: 1),
                usesSharedBloom: true,
                bloomTitle: "序列9 · 神兵蓝泛光"
            )
        }
        return BasicAttackVFXProfile(
            sequence: sequence,
            sharedTint: nil,
            usesSharedBloom: false,
            bloomTitle: "路径本色"
        )
    }
}

enum DungeonSkillID: String, CaseIterable, Identifiable {
    case strike
    case mobility
    case control
    case ward
    case ultimate

    var id: String { rawValue }
}

/// Presentation data is keyed by pathway and skill rather than by button slot.
/// Future sequence skills can add new keys without sharing another pathway's
/// silhouettes, timing, colour language, or impact grammar.
enum PathSkillVFXCatalog {
    static func recipe(for pathwayID: Pathway.ID, skillID: DungeonSkillID) -> SpellEffectRecipe {
        recipes[PathSkillVFXKey(pathwayID: pathwayID, skillID: skillID)]
            ?? genericRecipe(pathwayID: pathwayID, skillID: skillID)
    }

    static let recipes: [PathSkillVFXKey: SpellEffectRecipe] = {
        let foolRecipes = [
            makeFoolRecipe(
                skillID: .strike,
                title: "弱点判断",
                intensity: .focused,
                assets: ["weakness-eye", "tarot-cast", "precision-card", "weakpoint-impact", "weakpoint-residue"],
                durations: [0.20, 0.14, 0.46, 0.12, 0.18]
            ),
            makeFoolRecipe(
                skillID: .mobility,
                title: "灵性闪避",
                intensity: .focused,
                assets: ["phase-warning", "spiritual-shards", "false-echo", "counter-slash", "cyan-afterimage"],
                durations: [0.12, 0.18, 0.20, 0.18, 0.16]
            ),
            makeFoolRecipe(
                skillID: .control,
                title: "简易占卜",
                intensity: .field,
                assets: ["gold-compass", "tarot-fan", "constellation-lines", "divination-field", "gold-stardust"],
                durations: [0.18, 0.24, 0.18, 0.24, 0.22]
            ),
            makeFoolRecipe(
                skillID: .ward,
                title: "危险预感",
                intensity: .spectacular,
                assets: ["omen-eye", "magenta-veil", "converging-cards", "omen-detonation", "smoky-omen"],
                durations: [0.20, 0.18, 0.46, 0.20, 0.30]
            ),
            makeFoolRecipe(
                skillID: .ultimate,
                title: "预兆记录",
                intensity: .ultimate,
                assets: ["grand-card-reveal", "arcana-cast", "three-card-flight", "full-screen-cross", "grand-residue"],
                durations: [0.22, 0.24, 0.50, 0.42, 0.40]
            )
        ]
        return Dictionary(uniqueKeysWithValues: foolRecipes.map { ($0.key, $0) })
    }()

    private static func makeFoolRecipe(
        skillID: DungeonSkillID,
        title: String,
        intensity: SkillVFXIntensity,
        assets: [String],
        durations: [TimeInterval]
    ) -> SpellEffectRecipe {
        let phases = SpellEffectPhase.allCases
        let cues = zip(phases, zip(assets, durations)).map { phase, payload in
            SpellEffectCue(
                phase: phase,
                assetName: payload.0,
                duration: payload.1,
                anchorSlot: phase == .cast ? .weaponFront : nil,
                additiveBlend: phase != .telegraph,
                cameraImpulse: phase == .impact ? CGFloat(intensity.rawValue) * 0.65 : 0
            )
        }
        let key = PathSkillVFXKey(pathwayID: .fool, skillID: skillID)
        return SpellEffectRecipe(
            id: "fool.\(skillID.rawValue)",
            key: key,
            title: title,
            intensity: intensity,
            cues: cues
        )
    }

    private static func genericRecipe(
        pathwayID: Pathway.ID,
        skillID: DungeonSkillID
    ) -> SpellEffectRecipe {
        let key = PathSkillVFXKey(pathwayID: pathwayID, skillID: skillID)
        let theme: String
        switch pathwayID {
        case .fool: theme = "arcana"
        case .priestess: theme = "moon-tide"
        case .chariot: theme = "iron-banner"
        case .magician: theme = "alchemy-sigil"
        case .justice: theme = "oath-scale"
        case .star: theme = "constellation"
        }
        let intensity: SkillVFXIntensity
        switch skillID {
        case .strike: intensity = .restrained
        case .mobility: intensity = .focused
        case .control: intensity = .field
        case .ward: intensity = .spectacular
        case .ultimate: intensity = .ultimate
        }
        let durations: [TimeInterval] = [0.12, 0.16, 0.34, 0.18, 0.16]
        let cues = zip(SpellEffectPhase.allCases, durations).map { phase, duration in
            SpellEffectCue(
                phase: phase,
                assetName: "\(theme)-\(skillID.rawValue)-\(phase.rawValue)",
                duration: duration,
                anchorSlot: phase == .cast ? .weaponFront : nil,
                additiveBlend: phase == .travel || phase == .impact,
                cameraImpulse: phase == .impact ? CGFloat(intensity.rawValue) * 0.55 : 0
            )
        }
        return SpellEffectRecipe(
            id: "\(pathwayID.rawValue).\(skillID.rawValue)",
            key: key,
            title: skillID.rawValue,
            intensity: intensity,
            cues: cues
        )
    }

    #if DEBUG
    static var validationErrors: [String] {
        var errors: [String] = []
        for recipe in recipes.values {
            if recipe.cues.map(\.phase) != SpellEffectPhase.allCases {
                errors.append("\(recipe.id): phases must be telegraph → cast → travel → impact → residue")
            }
            if recipe.cues.contains(where: { $0.duration <= 0 }) {
                errors.append("\(recipe.id): cue duration must be positive")
            }
        }
        let ladder = DungeonSkillID.allCases.map { recipe(for: .fool, skillID: $0).intensity }
        if zip(ladder, ladder.dropFirst()).contains(where: { pair in pair.0 > pair.1 }) {
            errors.append("fool: VFX intensity must not decrease across the skill ladder")
        }
        return errors
    }
    #endif
}

enum DungeonSkillBehavior {
    case projectile
    case dashStrike
    case areaBurst
}

struct DungeonSkillDefinition: Identifiable {
    let id: DungeonSkillID
    let name: String
    let symbol: String
    /// Turn-based cooldown. A value of 3 means the skill becomes available
    /// after three complete enemy turns.
    let cooldown: TimeInterval
    let damage: Int
    let range: CGFloat
    let radius: CGFloat
    let behavior: DungeonSkillBehavior
    let tint: Color
}

enum DungeonSkillCatalog {
    static func skills(for path: Pathway) -> [DungeonSkillDefinition] {
        let names: [(String, String)]
        switch path.id {
        case .fool:
            names = [("弱点判断", "eye.fill"), ("灵性闪避", "figure.run"), ("简易占卜", "sparkles"), ("危险预感", "exclamationmark.triangle.fill"), ("预兆记录", "moon.stars.fill")]
        case .priestess:
            names = [("潮听针", "moon.stars.fill"), ("月相游步", "moonphase.waxing.crescent"), ("静潮封缄", "drop.triangle.fill"), ("月幕回护", "moon.fill"), ("灵潮震荡", "wave.3.up")]
        case .chariot:
            names = [("裂阵矢", "arrow.up.right"), ("铁壁突进", "shield.lefthalf.filled"), ("断势号令", "flag.fill"), ("不退壁垒", "shield.fill"), ("战意风暴", "tornado")]
        case .magician:
            names = [("盐晶弹", "diamond.fill"), ("炼成跃迁", "wand.and.stars"), ("术式拆解", "point.3.connected.trianglepath.dotted"), ("等价屏障", "hexagon.fill"), ("等价爆破", "sparkles")]
        case .justice:
            names = [("誓刃", "scalemass.fill"), ("衡盾突进", "shield.fill"), ("罪证钉锁", "pin.fill"), ("守誓反击", "checkmark.shield.fill"), ("裁决领域", "circle.hexagongrid.fill")]
        case .star:
            names = [("星矢", "sparkle"), ("星渡", "location.north.fill"), ("轨迹偏折", "arrow.trianglehead.branch"), ("星幕祝祷", "star.circle.fill"), ("可能坠落", "meteor.fill")]
        }

        return [
            DungeonSkillDefinition(
                id: .strike,
                name: names[0].0,
                symbol: names[0].1,
                cooldown: 2,
                damage: 52,
                range: 180,
                radius: 0,
                behavior: .projectile,
                tint: path.tint
            ),
            DungeonSkillDefinition(
                id: .mobility,
                name: names[1].0,
                symbol: names[1].1,
                cooldown: 3,
                damage: 64,
                range: 160,
                radius: 54,
                behavior: .dashStrike,
                tint: path.tint.opacity(0.90)
            ),
            DungeonSkillDefinition(
                id: .control,
                name: names[2].0,
                symbol: names[2].1,
                cooldown: 4,
                damage: 38,
                range: 190,
                radius: 92,
                behavior: .areaBurst,
                tint: .cyan
            ),
            DungeonSkillDefinition(
                id: .ward,
                name: names[3].0,
                symbol: names[3].1,
                cooldown: 5,
                damage: 44,
                range: 170,
                radius: 0,
                behavior: .projectile,
                tint: .mint
            ),
            DungeonSkillDefinition(
                id: .ultimate,
                name: names[4].0,
                symbol: names[4].1,
                cooldown: 6,
                damage: 86,
                range: 145,
                radius: 150,
                behavior: .areaBurst,
                tint: .yellow
            )
        ]
    }
}

enum DungeonEnemyKind: String {
    case gearHound
    case saltWraith
    case saltCrystalDeacon
    case mirrorShade
    case stageAfterimage
    case saltCrystalGnawer
    case crackedMirrorMarionette
    case rustTideHookRaider
    case drownedMemoryGhost
    case oathScribe
    case facelessAttendant
    case hollowClockGuard
    case lampDevourer
    case prototypeHound
    case reversePumpHeart
    case seravianUnified
    case whiteTideMotherCrystal
    case firstUnderstudy
    case deepTideDisciple
    case mistCrownGovernor

    /// Most enemies are grounded. Permanent altitude is reserved for enemies
    /// whose fiction and silhouette are genuinely incorporeal.
    var locomotion: DungeonEnemyLocomotion {
        switch self {
        case .drownedMemoryGhost:
            .spectralHover(height: 12, amplitude: 3)
        case .saltWraith:
            .grounded
        case .gearHound, .saltCrystalDeacon, .mirrorShade, .stageAfterimage,
             .saltCrystalGnawer, .crackedMirrorMarionette, .rustTideHookRaider,
             .oathScribe, .facelessAttendant,
             .hollowClockGuard, .lampDevourer,
             .prototypeHound, .reversePumpHeart, .seravianUnified,
             .whiteTideMotherCrystal, .firstUnderstudy, .deepTideDisciple,
             .mistCrownGovernor:
            .grounded
        }
    }

    var primaryAbilityName: String {
        switch self {
        case .gearHound: "冥火扑杀"
        case .saltWraith: "失秒弹"
        case .saltCrystalDeacon: "封存钳击"
        case .mirrorShade: "回拨标记"
        case .stageAfterimage: "复演残响"
        case .saltCrystalGnawer: "盐晶裂地"
        case .crackedMirrorMarionette: "碎镜复演"
        case .rustTideHookRaider: "回潮钩袭"
        case .drownedMemoryGhost: "沉默水泡"
        case .oathScribe: "禁令落款"
        case .facelessAttendant: "一致表决"
        case .hollowClockGuard: "第十三敲击"
        case .lampDevourer: "吞光跃袭"
        case .prototypeHound: "连锁追猎"
        case .reversePumpHeart: "记忆回灌"
        case .seravianUnified: "归一校时"
        case .whiteTideMotherCrystal: "白潮晶裂"
        case .firstUnderstudy: "首席返场"
        case .deepTideDisciple: "深潮回卷"
        case .mistCrownGovernor: "雾冠禁令"
        }
    }

    var combatHint: String {
        switch self {
        case .gearHound: "低伏蓄势后猛扑；暗火会暴露落点"
        case .saltWraith: "远程命中会延长技能冷却"
        case .saltCrystalDeacon: "封存钳会暂时锁住一张技能牌"
        case .mirrorShade: "攻击会在镜像位置复演"
        case .stageAfterimage: "只在复演瞬间显形，残响会复制最近一次行动"
        case .saltCrystalGnawer: "扑地后盐晶会延迟二次爆裂"
        case .crackedMirrorMarionette: "碎镜弹会在对称位置复演"
        case .rustTideHookRaider: "钩袭落点会被回潮再次冲刷"
        case .drownedMemoryGhost: "沉默水泡可被攻击击破，命中前持续追踪"
        case .oathScribe: "命中会追加禁令，延长技能冷却"
        case .facelessAttendant: "三名侍从同步施法，击破一名即可制造缺口"
        case .hollowClockGuard: "长蓄力重击，可闪避或格挡"
        case .lampDevourer: "从暗区跃袭并留下危险残光"
        case .prototypeHound: "连续追猎同一目标"
        case .reversePumpHeart: "周期释放大范围逆流脉冲"
        case .seravianUnified: "轮换复演本区已学机制"
        case .whiteTideMotherCrystal: "落点会结晶并延迟二次爆裂"
        case .firstUnderstudy: "每次攻击都会在对称位置返场"
        case .deepTideDisciple: "原落点会被回潮再次冲刷"
        case .mistCrownGovernor: "命中会颁布禁令，延长全部冷却"
        }
    }
}

enum DungeonEnemyLocomotion {
    case grounded
    case spectralHover(height: CGFloat, amplitude: CGFloat)
}

enum DungeonEnemyRank {
    case normal
    case elite
    case boss
}

struct DungeonEnemySpawn: Identifiable {
    let artworkOverride: String?
    let id: String
    let title: String
    let kind: DungeonEnemyKind
    let position: CGPoint
    let maxHealth: Int
    let attackDamage: Int
    let movementSpeed: CGFloat
    let attackRange: CGFloat
    let telegraphDuration: TimeInterval
    let rank: DungeonEnemyRank
    /// Enemies in later waves are created only after the current wave is cleared.
    let wave: Int

    init(
        id: String,
        title: String,
        kind: DungeonEnemyKind,
        position: CGPoint,
        maxHealth: Int,
        attackDamage: Int,
        movementSpeed: CGFloat,
        attackRange: CGFloat,
        telegraphDuration: TimeInterval,
        rank: DungeonEnemyRank,
        wave: Int = 1,
        artworkOverride: String? = nil
    ) {
        self.artworkOverride = artworkOverride
        self.id = id
        self.title = title
        self.kind = kind
        self.position = position
        self.maxHealth = maxHealth
        self.attackDamage = attackDamage
        self.movementSpeed = movementSpeed
        self.attackRange = attackRange
        self.telegraphDuration = telegraphDuration
        self.rank = rank
        self.wave = wave
    }
}

/// A level owns gameplay coordinates only. Art, navigation and story state stay independent.
struct DungeonLevel {
    let id: String
    let title: String
    let subtitle: String
    let artName: String
    let sceneSize: CGSize
    let spawnPoint: CGPoint
    let walkablePolygon: [CGPoint]
    let obstacles: [CGRect]
    let enemies: [DungeonEnemySpawn]

    var totalWaves: Int {
        max(1, enemies.map(\.wave).max() ?? 1)
    }

    func waveTitle(for wave: Int) -> String {
        let waveEnemies = enemies.filter { $0.wave == wave }
        if waveEnemies.contains(where: { $0.rank == .boss }) {
            return "首领阶段"
        }
        if waveEnemies.contains(where: { $0.rank == .elite }) {
            return "精英阶段"
        }
        if waveEnemies.contains(where: { $0.title.contains("护卫") }) {
            return "护卫阶段"
        }
        if waveEnemies.contains(where: { $0.title.contains("护从") || $0.title.contains("近卫") }) {
            return "增援阶段"
        }
        return wave == 1 ? "先遣清剿" : "增援清剿"
    }

    static func waveValidationErrors(for districts: [ChapterDistrict]) -> [String] {
        var errors: [String] = []

        for district in districts {
            let expectedMissionCount = district.id == "old-clock" ? 30 : 20
            if district.missions.count != expectedMissionCount {
                errors.append("\(district.name) 应有 \(expectedMissionCount) 个任务，当前为 \(district.missions.count)")
            }

            for mission in district.missions {
                let level = clockDistrict.scaled(for: mission)
                let waves = Set(level.enemies.map(\.wave))
                let expectedWaves = mission.battleWaveCount

                if level.totalWaves != expectedWaves {
                    errors.append("\(mission.id) 应有 \(expectedWaves) 波，当前为 \(level.totalWaves)")
                }
                if waves != Set(1...level.totalWaves) {
                    errors.append("\(mission.id) 波次不连续：\(waves.sorted())")
                }
                if Set(level.enemies.map(\.id)).count != level.enemies.count {
                    errors.append("\(mission.id) 存在重复敌人 ID")
                }

                let firstWave = level.enemies.filter { $0.wave == 1 }
                let finalWave = level.enemies.filter { $0.wave == level.totalWaves }
                if firstWave.isEmpty || finalWave.isEmpty {
                    errors.append("\(mission.id) 存在空波次")
                }
                if mission.kind == .elite,
                   (!firstWave.allSatisfy({ $0.rank == .normal }) || !finalWave.contains(where: { $0.rank == .elite })) {
                    errors.append("\(mission.id) 必须先清杂兵，再出现精英")
                }
                if mission.kind == .boss,
                   (firstWave.contains(where: { $0.rank == .boss }) || !finalWave.contains(where: { $0.rank == .boss })) {
                    errors.append("\(mission.id) 必须先打护卫，再进入首领阶段")
                }
                if mission.kind == .combat,
                   level.enemies.contains(where: { $0.rank != .normal }) {
                    errors.append("\(mission.id) 普通关不应混入精英或首领标签")
                }
                if district.id != "old-clock",
                   level.enemies.contains(where: { $0.kind == .gearHound || $0.kind == .prototypeHound }) {
                    errors.append("\(mission.id) 不应出现旧城区专属失名猎犬")
                }
                if district.id != "old-clock", level.artName == clockDistrict.artName {
                    errors.append("\(mission.id) 不应复用旧城区战场美术")
                }

                let allowedNormalKinds: [DungeonEnemyKind] = switch district.id {
                case "salt-warehouse": [.saltCrystalGnawer, .saltCrystalDeacon]
                case "mirror-theater": [.crackedMirrorMarionette, .stageAfterimage]
                case "tide-gate": [.rustTideHookRaider, .drownedMemoryGhost]
                case "mist-crown": [.oathScribe, .facelessAttendant]
                default: [.gearHound, .saltWraith]
                }
                let foreignNormalKinds = level.enemies
                    .filter { $0.rank == .normal && !allowedNormalKinds.contains($0.kind) }
                    .map(\.kind.rawValue)
                if !foreignNormalKinds.isEmpty {
                    errors.append("\(mission.id) 混入非本区普通敌人：\(foreignNormalKinds.joined(separator: ", "))")
                }

                let expectedDistrictKind: DungeonEnemyKind = switch district.id {
                case "salt-warehouse": .saltCrystalGnawer
                case "mirror-theater": .crackedMirrorMarionette
                case "tide-gate": .rustTideHookRaider
                case "mist-crown": .oathScribe
                default: .gearHound
                }
                if !firstWave.contains(where: { $0.kind == expectedDistrictKind }) {
                    errors.append("\(mission.id) 首波缺少本区标志敌人 \(expectedDistrictKind.rawValue)")
                }
                for wave in 1...level.totalWaves {
                    let count = level.enemies.filter { $0.wave == wave }.count
                    if count < 1 || count > 4 {
                        errors.append("\(mission.id) 第 \(wave) 波敌人数应为 1...4，当前为 \(count)")
                    }
                }
                if mission.kind == .combat {
                    let openingCount = firstWave.count
                    let expectedOpeningCount = switch mission.number {
                    case 1...2: 1
                    case 3...10: 2
                    default: 3
                    }
                    if openingCount != expectedOpeningCount {
                        errors.append("\(mission.id) 首波应有 \(expectedOpeningCount) 名敌人，当前为 \(openingCount)")
                    }
                }
            }
        }

        return errors
    }

    static let clockDistrict = DungeonLevel(
        id: "clock-district-alley",
        title: "旧城区·失名者",
        subtitle: "雨夜巷口 · 战斗区域",
        artName: "SceneClockDistrictV2",
        sceneSize: CGSize(width: 430, height: 932),
        // The protagonist starts on the visual centre line of the bridge.
        spawnPoint: CGPoint(x: 215, y: 270),
        walkablePolygon: [
            CGPoint(x: 24, y: 128),
            CGPoint(x: 406, y: 128),
            CGPoint(x: 330, y: 585),
            CGPoint(x: 54, y: 432)
        ],
        obstacles: [
            CGRect(x: 38, y: 292, width: 62, height: 104),
            CGRect(x: 298, y: 340, width: 50, height: 116)
        ],
        enemies: [
            DungeonEnemySpawn(
                id: "gear-hound",
                title: "失名猎犬",
                kind: .gearHound,
                position: CGPoint(x: 148, y: 525),
                maxHealth: 90,
                attackDamage: 7,
                movementSpeed: 35,
                attackRange: 68,
                telegraphDuration: 0.62,
                rank: .normal
            ),
            DungeonEnemySpawn(
                id: "salt-wraith",
                title: "盐雾怨灵",
                kind: .saltWraith,
                position: CGPoint(x: 282, y: 540),
                maxHealth: 110,
                attackDamage: 9,
                movementSpeed: 26,
                attackRange: 150,
                telegraphDuration: 0.86,
                rank: .elite
            ),
            DungeonEnemySpawn(
                id: "mirror-shade",
                title: "镜潮幽影",
                kind: .mirrorShade,
                position: CGPoint(x: 215, y: 580),
                maxHealth: 260,
                attackDamage: 14,
                movementSpeed: 24,
                attackRange: 92,
                telegraphDuration: 1.0,
                rank: .boss
            )
        ]
    )

    func isWalkable(_ point: CGPoint) -> Bool {
        guard walkablePolygon.contains(point) else { return false }
        return !obstacles.contains { $0.insetBy(dx: -10, dy: -10).contains(point) }
    }

    func scaled(for mission: DistrictMission) -> DungeonLevel {
        let progress = CGFloat(mission.globalOrder - 1) / 99
        let bossMultiplier: CGFloat = mission.kind == .boss ? 1.16 : 1
        let healthMultiplier = (1 + progress * 0.85) * bossMultiplier
        let damageMultiplier = (1 + progress * 0.55) * bossMultiplier
        let speedMultiplier = 1 + progress * 0.22
        let telegraphMultiplier = max(0.72, 1 - progress * 0.28)
        let districtArtName: String = switch mission.districtID {
        case "salt-warehouse": "SceneSaltRitual"
        case "mirror-theater": "SceneMirrorTheater"
        case "tide-gate": "RainwaterDrainsTileV1"
        case "mist-crown": "MirrorTideManorTileV1"
        default: artName
        }

        let meleeTemplate = enemies.first(where: { $0.kind == .gearHound }) ?? enemies[0]
        let rangedTemplate = enemies.first(where: { $0.kind == .saltWraith }) ?? enemies[0]
        let leaderTemplate = enemies.first(where: { $0.rank == .boss }) ?? enemies[0]

        // Visual identity is tied to the district, not merely renamed. The
        // clockwork hound is a corrupted Old Clock patrol and never appears in
        // the other four districts.
        let districtEnemyKinds: (melee: DungeonEnemyKind, ranged: DungeonEnemyKind) = switch mission.districtID {
        case "salt-warehouse": (.saltCrystalGnawer, .saltCrystalDeacon)
        case "mirror-theater": (.crackedMirrorMarionette, .stageAfterimage)
        case "tide-gate": (.rustTideHookRaider, .drownedMemoryGhost)
        case "mist-crown": (.oathScribe, .facelessAttendant)
        default: (.gearHound, .saltWraith)
        }

        let districtEnemyNames: (melee: String, ranged: String) = switch mission.districtID {
        case "salt-warehouse": ("盐晶噬兽", "盐晶执事")
        case "mirror-theater": ("裂镜舞偶", "舞台残像")
        case "tide-gate": ("锈潮钩客", "溺忆幽灵")
        case "mist-crown": ("誓约执笔官", "无面侍从")
            default: ("失名猎犬", "雾钟怨灵")
        }

        let districtEliteName: String = switch mission.districtID {
        case "salt-warehouse": "盐晶执事"
        case "mirror-theater": "镜幕替身"
        case "tide-gate": "沉潮领航者"
        case "mist-crown": "议会裁决官"
        default: "逆时追猎者"
        }

        let districtEliteKind: DungeonEnemyKind = switch mission.districtID {
        case "salt-warehouse": .saltCrystalGnawer
        case "mirror-theater": .crackedMirrorMarionette
        case "tide-gate": .rustTideHookRaider
        case "mist-crown": .oathScribe
        default: .prototypeHound
        }

        let bossIdentity: (title: String, kind: DungeonEnemyKind) = switch mission.districtID {
        case "salt-warehouse": switch mission.number {
            case 1...5: ("结晶仓监工", .hollowClockGuard)
            case 6...10: ("噬盐母兽", .lampDevourer)
            case 11...15: ("地下盐脉心", .reversePumpHeart)
            default: ("白潮母晶", .whiteTideMotherCrystal)
        }
        case "mirror-theater": switch mission.number {
            case 1...5: ("无面领座", .hollowClockGuard)
            case 6...10: ("镜幕吞噬者", .lampDevourer)
            case 11...15: ("锚镜之心", .reversePumpHeart)
            default: ("首席替身", .firstUnderstudy)
        }
        case "tide-gate": switch mission.number {
            case 1...5: ("逆潮船长", .hollowClockGuard)
            case 6...10: ("噬灯海兽", .lampDevourer)
            case 11...15: ("潮闸泵心", .reversePumpHeart)
            default: ("深潮门徒", .deepTideDisciple)
        }
        case "mist-crown": switch mission.number {
            case 1...5: ("档案监察官", .hollowClockGuard)
            case 6...10: ("无面宴主", .lampDevourer)
            case 11...15: ("誓约法令核", .reversePumpHeart)
            default: ("雾冠执政官", .mistCrownGovernor)
        }
        default: switch mission.number {
            case 1...5: ("空壳守卫", .hollowClockGuard)
            case 6...10: ("吞灯兽", .lampDevourer)
            case 11...15: ("逆流泵心", .reversePumpHeart)
            default: ("归一档案库 · 瑟维安", .seravianUnified)
        }
        }

        func makeSpawn(
            from template: DungeonEnemySpawn,
            id: String,
            title: String,
            kind: DungeonEnemyKind? = nil,
            position: CGPoint,
            rank: DungeonEnemyRank,
            wave: Int,
            healthFactor: CGFloat = 1,
            damageFactor: CGFloat = 1
        ) -> DungeonEnemySpawn {
            DungeonEnemySpawn(
                id: id,
                title: title,
                kind: kind ?? template.kind,
                position: position,
                maxHealth: max(1, Int(CGFloat(template.maxHealth) * healthFactor)),
                attackDamage: max(1, Int(CGFloat(template.attackDamage) * damageFactor)),
                movementSpeed: template.movementSpeed,
                attackRange: template.attackRange,
                telegraphDuration: template.telegraphDuration,
                rank: rank,
                wave: wave
            )
        }

        // Keep silhouettes readable on phone: two-wide formations occupy the
        // arena flanks, while a third unit forms the rear point of a triangle.
        let left = CGPoint(x: 118, y: 535)
        let right = CGPoint(x: 312, y: 535)
        let center = CGPoint(x: 215, y: 580)
        let rearCenter = CGPoint(x: 215, y: 625)
        let forwardCenter = CGPoint(x: 215, y: 515)

        let missionEnemies: [DungeonEnemySpawn]
        switch mission.kind {
        case .combat:
            let openingCount = switch mission.number {
            case 1...2: 1
            case 3...10: 2
            default: 3
            }
            var waves = [makeSpawn(
                from: meleeTemplate,
                id: "vanguard-melee",
                title: districtEnemyNames.melee,
                kind: districtEnemyKinds.melee,
                position: openingCount == 1 ? center : left,
                rank: .normal,
                wave: 1
            )]
            if openingCount >= 2 {
                waves.append(makeSpawn(
                    from: rangedTemplate,
                    id: "vanguard-ranged",
                    title: districtEnemyNames.ranged,
                    kind: districtEnemyKinds.ranged,
                    position: right,
                    rank: .normal,
                    wave: 1
                ))
            }
            if openingCount >= 3 {
                waves.append(makeSpawn(
                    from: meleeTemplate,
                    id: "vanguard-flanker",
                    title: "侧袭·\(districtEnemyNames.melee)",
                    kind: districtEnemyKinds.melee,
                    position: rearCenter,
                    rank: .normal,
                    wave: 1,
                    healthFactor: 0.88,
                    damageFactor: 1.08
                ))
            }
            if mission.battleWaveCount >= 2 {
                waves += [
                    makeSpawn(from: rangedTemplate, id: "reinforcement-ranged", title: "增援·\(districtEnemyNames.ranged)", kind: districtEnemyKinds.ranged, position: left, rank: .normal, wave: 2, healthFactor: 1.08),
                    makeSpawn(from: meleeTemplate, id: "reinforcement-melee", title: "增援·\(districtEnemyNames.melee)", kind: districtEnemyKinds.melee, position: right, rank: .normal, wave: 2, healthFactor: 1.08)
                ]
                if mission.number >= 11 {
                    waves.append(makeSpawn(from: meleeTemplate, id: "reinforcement-flanker", title: "侧袭·\(districtEnemyNames.melee)", kind: districtEnemyKinds.melee, position: forwardCenter, rank: .normal, wave: 2, healthFactor: 0.82, damageFactor: 1.08))
                }
            }
            if mission.battleWaveCount >= 3 {
                waves += [
                    makeSpawn(from: meleeTemplate, id: "assault-left", title: "强化·\(districtEnemyNames.melee)", kind: districtEnemyKinds.melee, position: left, rank: .normal, wave: 3, healthFactor: 1.18, damageFactor: 1.10),
                    makeSpawn(from: rangedTemplate, id: "assault-right", title: "强化·\(districtEnemyNames.ranged)", kind: districtEnemyKinds.ranged, position: right, rank: .normal, wave: 3, healthFactor: 1.18, damageFactor: 1.10),
                    makeSpawn(from: meleeTemplate, id: "assault-center", title: "突击·\(districtEnemyNames.melee)", kind: districtEnemyKinds.melee, position: rearCenter, rank: .normal, wave: 3, healthFactor: 0.94, damageFactor: 1.16)
                ]
            }
            missionEnemies = waves
        case .elite:
            let eliteWave = mission.battleWaveCount
            var waves = [
                makeSpawn(from: meleeTemplate, id: "elite-guard-melee", title: "\(districtEliteName)护从", kind: districtEnemyKinds.melee, position: left, rank: .normal, wave: 1),
                makeSpawn(from: rangedTemplate, id: "elite-guard-ranged", title: "\(districtEliteName)护从", kind: districtEnemyKinds.ranged, position: right, rank: .normal, wave: 1)
            ]
            if eliteWave == 3 {
                waves += [
                    makeSpawn(from: rangedTemplate, id: "elite-reinforcement-ranged", title: "精英增援", kind: districtEnemyKinds.ranged, position: left, rank: .normal, wave: 2, healthFactor: 1.12),
                    makeSpawn(from: meleeTemplate, id: "elite-reinforcement-melee", title: "精英增援", kind: districtEnemyKinds.melee, position: right, rank: .normal, wave: 2, healthFactor: 1.12),
                    makeSpawn(from: meleeTemplate, id: "elite-reinforcement-flanker", title: "精英侧卫", kind: districtEnemyKinds.melee, position: forwardCenter, rank: .normal, wave: 2, healthFactor: 0.86, damageFactor: 1.12)
                ]
            }
            waves.append(makeSpawn(
                from: leaderTemplate,
                id: "district-elite",
                title: districtEliteName,
                kind: districtEliteKind,
                position: center,
                rank: .elite,
                wave: eliteWave,
                healthFactor: 0.68,
                damageFactor: 0.86
            ))
            missionEnemies = waves
        case .boss:
            let bossWave = mission.battleWaveCount
            var waves = [
                makeSpawn(from: meleeTemplate, id: "boss-guard-melee", title: "\(bossIdentity.title)护卫", kind: districtEnemyKinds.melee, position: left, rank: .normal, wave: 1, healthFactor: 1.12),
                makeSpawn(from: rangedTemplate, id: "boss-guard-ranged", title: "\(bossIdentity.title)护卫", kind: districtEnemyKinds.ranged, position: right, rank: .normal, wave: 1, healthFactor: 1.12)
            ]
            if mission.number >= 10 {
                waves.append(makeSpawn(from: meleeTemplate, id: "boss-guard-flanker", title: "\(bossIdentity.title)护卫", kind: districtEnemyKinds.melee, position: forwardCenter, rank: .normal, wave: 1, healthFactor: 0.88, damageFactor: 1.10))
            }
            if bossWave == 3 {
                waves += [
                    makeSpawn(from: leaderTemplate, id: "boss-captain", title: "\(bossIdentity.title)近卫", kind: districtEliteKind, position: center, rank: .elite, wave: 2, healthFactor: 0.58, damageFactor: 0.82),
                    makeSpawn(from: rangedTemplate, id: "boss-captain-aide", title: "近卫术士", kind: districtEnemyKinds.ranged, position: right, rank: .normal, wave: 2, healthFactor: 1.15, damageFactor: 1.10)
                ]
            }
            waves.append(makeSpawn(
                from: leaderTemplate,
                id: "district-boss",
                title: bossIdentity.title,
                kind: bossIdentity.kind,
                position: center,
                rank: .boss,
                wave: bossWave,
                healthFactor: mission.number == 20 ? 1.22 : 1,
                damageFactor: mission.number == 20 ? 1.14 : 1
            ))
            missionEnemies = waves
        }

        let scaledEnemies = missionEnemies.map { enemy in
            DungeonEnemySpawn(
                id: "\(enemy.id)-\(mission.id)",
                title: enemy.title,
                kind: enemy.kind,
                position: enemy.position,
                maxHealth: max(1, Int(CGFloat(enemy.maxHealth) * healthMultiplier)),
                attackDamage: max(1, Int(CGFloat(enemy.attackDamage) * damageMultiplier)),
                movementSpeed: enemy.movementSpeed * speedMultiplier,
                attackRange: enemy.attackRange,
                telegraphDuration: enemy.telegraphDuration * telegraphMultiplier,
                rank: enemy.rank,
                wave: enemy.wave
            )
        }

        return DungeonLevel(
            id: mission.id,
            title: mission.districtName,
            subtitle: "任务 \(mission.number) · \(mission.title)",
            artName: districtArtName,
            sceneSize: sceneSize,
            spawnPoint: spawnPoint,
            walkablePolygon: walkablePolygon,
            obstacles: obstacles,
            enemies: scaledEnemies
        )
    }
}

struct DungeonGridCell: Hashable {
    let column: Int
    let row: Int
}

/// Small A* grid used by the prototype. A production level can load the same data from LDtk/Tiled JSON.
struct DungeonNavigationGrid {
    let level: DungeonLevel
    let columns: Int
    let rows: Int

    private var cellSize: CGSize {
        CGSize(
            width: level.sceneSize.width / CGFloat(columns),
            height: level.sceneSize.height / CGFloat(rows)
        )
    }

    func route(from start: CGPoint, to requestedEnd: CGPoint) -> [CGPoint] {
        guard let startCell = nearestWalkableCell(to: start),
              let endCell = nearestWalkableCell(to: requestedEnd) else {
            return []
        }

        if startCell == endCell {
            return [level.isWalkable(requestedEnd) ? requestedEnd : point(for: endCell)]
        }

        var frontier = PriorityQueue()
        frontier.insert(startCell, priority: 0)
        var cameFrom: [DungeonGridCell: DungeonGridCell] = [:]
        var costSoFar: [DungeonGridCell: CGFloat] = [startCell: 0]

        while let current = frontier.popLowest() {
            if current == endCell { break }

            for next in neighbors(of: current) {
                let diagonal = next.column != current.column && next.row != current.row
                let newCost = (costSoFar[current] ?? 0) + (diagonal ? 1.414 : 1)
                if newCost < costSoFar[next, default: .greatestFiniteMagnitude] {
                    costSoFar[next] = newCost
                    let priority = newCost + heuristic(from: next, to: endCell)
                    frontier.insert(next, priority: priority)
                    cameFrom[next] = current
                }
            }
        }

        guard cameFrom[endCell] != nil else { return [] }

        var cells = [endCell]
        var current = endCell
        while current != startCell, let previous = cameFrom[current] {
            cells.append(previous)
            current = previous
        }

        var points = cells.reversed().dropFirst().map(point(for:))
        if level.isWalkable(requestedEnd) {
            points.append(requestedEnd)
        }
        return simplify(points: points)
    }

    private func nearestWalkableCell(to targetPoint: CGPoint) -> DungeonGridCell? {
        let proposed = cell(containing: targetPoint)
        if isWalkable(proposed) { return proposed }

        return allWalkableCells().min {
            distanceSquared(targetPoint, point(for: $0)) < distanceSquared(targetPoint, point(for: $1))
        }
    }

    private func allWalkableCells() -> [DungeonGridCell] {
        (0..<rows).flatMap { row in
            (0..<columns).compactMap { column in
                let cell = DungeonGridCell(column: column, row: row)
                return isWalkable(cell) ? cell : nil
            }
        }
    }

    private func neighbors(of cell: DungeonGridCell) -> [DungeonGridCell] {
        (-1...1).flatMap { rowOffset in
            (-1...1).compactMap { columnOffset in
                guard rowOffset != 0 || columnOffset != 0 else { return nil }
                let candidate = DungeonGridCell(
                    column: cell.column + columnOffset,
                    row: cell.row + rowOffset
                )
                guard isWalkable(candidate) else { return nil }

                if rowOffset != 0, columnOffset != 0 {
                    let horizontal = DungeonGridCell(column: cell.column + columnOffset, row: cell.row)
                    let vertical = DungeonGridCell(column: cell.column, row: cell.row + rowOffset)
                    guard isWalkable(horizontal), isWalkable(vertical) else { return nil }
                }
                return candidate
            }
        }
    }

    private func cell(containing point: CGPoint) -> DungeonGridCell {
        DungeonGridCell(
            column: max(0, min(columns - 1, Int(point.x / cellSize.width))),
            row: max(0, min(rows - 1, Int(point.y / cellSize.height)))
        )
    }

    private func point(for cell: DungeonGridCell) -> CGPoint {
        CGPoint(
            x: (CGFloat(cell.column) + 0.5) * cellSize.width,
            y: (CGFloat(cell.row) + 0.5) * cellSize.height
        )
    }

    private func isWalkable(_ cell: DungeonGridCell) -> Bool {
        guard (0..<columns).contains(cell.column), (0..<rows).contains(cell.row) else { return false }
        return level.isWalkable(point(for: cell))
    }

    private func heuristic(from lhs: DungeonGridCell, to rhs: DungeonGridCell) -> CGFloat {
        CGFloat(abs(lhs.column - rhs.column) + abs(lhs.row - rhs.row))
    }

    private func simplify(points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        var result = [points[0]]

        for index in 1..<(points.count - 1) {
            let previous = result.last ?? points[index - 1]
            let current = points[index]
            let next = points[index + 1]
            let firstDirection = direction(from: previous, to: current)
            let secondDirection = direction(from: current, to: next)
            if firstDirection != secondDirection {
                result.append(current)
            }
        }
        result.append(points[points.count - 1])
        return result
    }

    private func direction(from start: CGPoint, to end: CGPoint) -> DungeonGridCell {
        DungeonGridCell(
            column: sign(end.x - start.x),
            row: sign(end.y - start.y)
        )
    }

    private func sign(_ value: CGFloat) -> Int {
        if abs(value) < 0.1 { return 0 }
        return value > 0 ? 1 : -1
    }

    private func distanceSquared(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        let dx = lhs.x - rhs.x
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }
}

private struct PriorityQueue {
    private var values: [(cell: DungeonGridCell, priority: CGFloat)] = []

    mutating func insert(_ cell: DungeonGridCell, priority: CGFloat) {
        if let index = values.firstIndex(where: { $0.cell == cell }) {
            if priority < values[index].priority {
                values[index].priority = priority
            }
        } else {
            values.append((cell, priority))
        }
    }

    mutating func popLowest() -> DungeonGridCell? {
        guard let index = values.indices.min(by: { values[$0].priority < values[$1].priority }) else {
            return nil
        }
        return values.remove(at: index).cell
    }
}

private extension Array where Element == CGPoint {
    func contains(_ point: CGPoint) -> Bool {
        guard count > 2 else { return false }
        var isInside = false
        var previousIndex = count - 1

        for index in indices {
            let current = self[index]
            let previous = self[previousIndex]
            let crosses = (current.y > point.y) != (previous.y > point.y)
            if crosses {
                let intersectionX = (previous.x - current.x) * (point.y - current.y) /
                    (previous.y - current.y) + current.x
                if point.x < intersectionX { isInside.toggle() }
            }
            previousIndex = index
        }
        return isInside
    }
}
