import MistportCombatCore
import SpriteKit
import SwiftUI

private extension DungeonSkillID {
    var artName: String {
        switch self {
        case .strike: "IconSkillWeakness"
        case .mobility: "IconSkillSpiritualDodge"
        case .control: "IconSkillDivination"
        case .ward: "IconSkillDangerPremonition"
        case .ultimate: "IconSkillOmenRecord"
        }
    }
}

private extension CharacterWeaponDefinition {
    var artName: String {
        switch id {
        case "silver-lie-blade": "IconRelicOwnerlessMask"
        case "paper-moon-token": "IconRelicPaperMoon"
        case "mirror-card-case": "IconRelicMirrorCase"
        case "backward-watch": "IconRelicBackwardWatch"
        default: "IconRelicOwnerlessMask"
        }
    }
}

struct DungeonPrototypeView: View {
    @AppStorage(GameSettingsKeys.hapticsEnabled, store: .standard) private var hapticsEnabled = true
    let path: Pathway
    let mission: DistrictMission?
    let combatPower: Int
    let playerSequence: Int
    let isFirstClear: Bool
    let coinReward: Int
    let materialReward: Int
    let equippedRelicIDs: [String]
    let onExit: () -> Void
    let onVictory: () -> Void
    @State private var controller: DungeonController
    @State private var entranceStage = 0
    @State private var entranceIsVisible = true
    @State private var autoBattleEnabled = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }

    init(
        path: Pathway?,
        mission: DistrictMission? = nil,
        combatPower: Int = 100,
        playerSequence: Int = 9,
        configuredSkills: [DungeonSkillDefinition]? = nil,
        isFirstClear: Bool = true,
        coinReward: Int = 30,
        materialReward: Int = 1,
        equippedRelicIDs: [String] = ["silver-lie-blade", "paper-moon-token"],
        onExit: @escaping () -> Void,
        onVictory: @escaping () -> Void
    ) {
        let resolvedPath = path ?? GameContent.pathways[0]
        let level = mission.map { DungeonLevel.clockDistrict.scaled(for: $0) } ?? .clockDistrict
        self.path = resolvedPath
        self.mission = mission
        self.combatPower = combatPower
        self.playerSequence = playerSequence
        self.isFirstClear = isFirstClear
        self.coinReward = coinReward
        self.materialReward = materialReward
        self.equippedRelicIDs = equippedRelicIDs
        self.onExit = onExit
        self.onVictory = onVictory
        let damageMultiplier = 1 + CGFloat(max(0, combatPower - 100)) / 2_500
        _controller = State(initialValue: DungeonController(
            path: resolvedPath,
            level: level,
            skills: configuredSkills,
            relicIDs: equippedRelicIDs,
            damageMultiplier: damageMultiplier,
            playerSequence: playerSequence
        ))
    }

    var body: some View {
        ZStack {
            Group {
                SpriteView(
                    scene: controller.scene,
                    preferredFramesPerSecond: 60,
                    options: [.ignoresSiblingOrder]
                )
                .ignoresSafeArea()

                LinearGradient(
                    colors: [.black.opacity(0.52), .clear, .clear, .black.opacity(0.50)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(spacing: 8) {
                DungeonHeader(
                    title: mission?.districtName ?? "旧城区",
                    subtitle: mission.map { "任务 \($0.number) · \($0.kind.title) · \($0.difficultyLabel)" } ?? "动态清剿",
                    enemiesRemaining: controller.combat.enemiesRemaining,
                    currentWave: controller.combat.currentWave,
                    totalWaves: controller.combat.totalWaves,
                    waveTitle: controller.combat.waveTitle,
                    onExit: onExit
                )

                if let bossName = controller.combat.bossName {
                    BossHealthView(
                        name: bossName,
                        fraction: controller.combat.bossHealthFraction,
                        isEnraged: controller.combat.bossIsEnraged,
                        intentName: controller.combat.bossIntentName,
                        intentDamage: controller.combat.bossIntentDamage,
                        willpowerFraction: controller.combat.bossWillpowerFraction,
                        controlOutcome: controller.combat.bossControlOutcome
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                CombatDock(
                    path: path,
                    combat: controller.combat,
                    skills: controller.skills,
                    mission: mission,
                    isFirstClear: isFirstClear,
                    coinReward: coinReward,
                    materialReward: materialReward,
                    relicIDs: equippedRelicIDs,
                    usedRelicIDs: controller.combat.usedRelicIDs,
                    autoBattleEnabled: autoBattleEnabled,
                    onAttack: controller.attack,
                    onSkill: controller.cast,
                    onRelic: controller.activateRelic,
                    onToggleAutoBattle: { autoBattleEnabled.toggle() },
                    onRetry: retryBattle,
                    onVictory: onVictory
                )
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .brightness(entranceStage >= 2 ? 0 : -0.42)
            .saturation(entranceStage >= 2 ? 1 : 0.35)
            .animation(.easeOut(duration: reduceMotion ? 0.01 : 0.55), value: entranceStage)

            if entranceIsVisible {
                BattleEntranceOverlay(
                    stage: entranceStage,
                    districtName: mission?.districtName ?? "旧城区",
                    encounterName: mission.map { "任务 \($0.number) · \($0.title)" } ?? "迷雾清剿",
                    tint: path.tint,
                    reduceMotion: reduceMotion,
                    dockReservedHeight: 350
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sensoryFeedback(.impact(weight: .medium), trigger: controller.combat.feedbackToken) { _, _ in hapticsEnabled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(mission?.districtName ?? "旧城区")动态战斗副本")
        .task {
            await playEntranceSequence()
        }
        .task(id: autoBattleTurnKey) {
            await performAutomaticTurnIfNeeded()
        }
    }

    private var autoBattleTurnKey: String {
        let combat = controller.combat
        return "\(autoBattleEnabled)-\(entranceIsVisible)-\(combat.currentWave)-\(combat.turnNumber)-\(combat.isPlayerTurn)-\(combat.enemiesRemaining)"
    }

    @MainActor
    private func performAutomaticTurnIfNeeded() async {
        #if DEBUG
        // Static and authored-VFX previews must not be consumed by the normal
        // auto-battle loop while simulator capture is still settling.
        if ProcessInfo.processInfo.arguments.contains("--static-dungeon") {
            return
        }
        #endif
        guard autoBattleEnabled,
              !entranceIsVisible,
              controller.combat.isPlayerTurn,
              !controller.combat.isVictorious,
              !controller.combat.isDefeated else { return }

        try? await Task.sleep(for: .milliseconds(720))
        guard !Task.isCancelled,
              autoBattleEnabled,
              controller.combat.isPlayerTurn,
              !controller.combat.isVictorious,
              !controller.combat.isDefeated else { return }
        controller.performAutomaticAction()
    }

    @MainActor
    private func playEntranceSequence() async {
        entranceStage = 0
        entranceIsVisible = true
        if reduceMotion {
            entranceStage = 2
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            beginBattle()
            return
        }

        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.42)) { entranceStage = 1 }

        try? await Task.sleep(for: .milliseconds(620))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { entranceStage = 2 }

        // Let the seal finish its final reveal, then enter combat without
        // requiring a redundant confirmation tap.
        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        beginBattle()
    }

    @MainActor
    private func beginBattle() {
        withAnimation(.easeInOut(duration: 0.36)) {
            entranceStage = 3
            entranceIsVisible = false
        }
    }

    @MainActor
    private func retryBattle() {
        autoBattleEnabled = false
        controller.retry()
    }
}

struct BattleEntranceOverlay: View {
    let stage: Int
    let districtName: String
    let encounterName: String
    let tint: Color
    let reduceMotion: Bool
    let dockReservedHeight: CGFloat
    var showsTitle = true

    var body: some View {
        GeometryReader { geometry in
            let usableHeight = max(360, geometry.size.height - dockReservedHeight)
            let presentationCenterY = min(usableHeight * 0.59, geometry.size.height * 0.46)
            ZStack {
                Color.black
                    .opacity(
                        showsTitle
                            ? (stage == 0 ? 0.94 : stage == 1 ? 0.76 : 0.28)
                            : (stage == 0 ? 1.0 : stage == 1 ? 0.98 : 0.94)
                    )

                RadialGradient(
                    colors: [tint.opacity(stage >= 1 ? 0.42 : 0), .clear],
                    center: UnitPoint(
                        x: 0.5,
                        y: max(0.18, min(0.62, (presentationCenterY - 38) / geometry.size.height))
                    ),
                    startRadius: 4,
                    endRadius: min(geometry.size.width, geometry.size.height) * 0.56
                )
                .blendMode(.screen)

                BattleClockSeal(tint: tint, isLit: stage >= 1)
                    .frame(width: 210, height: 210)
                    .scaleEffect(stage == 0 ? 0.5 : stage == 1 ? 1 : 1.12)
                    .rotationEffect(.degrees(stage >= 2 && !reduceMotion ? 18 : 0))
                    .opacity(stage >= 2 ? 0.34 : (stage >= 1 ? 1 : 0))
                    .shadow(color: tint.opacity(stage >= 2 ? 0.18 : 0.75), radius: stage >= 2 ? 12 : 12)
                    .position(x: geometry.size.width * 0.5, y: presentationCenterY - 38)

                if showsTitle {
                    VStack(spacing: 8) {
                        Text(districtName)
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .tracking(5)
                            .foregroundStyle(.white.opacity(0.72))

                        Text("战斗开始")
                            .font(.system(size: 35, weight: .black, design: .serif))
                            .foregroundStyle(.white)
                            .shadow(color: tint, radius: 12)

                        Text(encounterName)
                            .font(.caption.bold())
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)

                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, tint, .white, tint, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: stage >= 2 ? 270 : 0, height: 2)
                            .shadow(color: tint, radius: 8)
                    }
                    .frame(width: geometry.size.width - 56)
                    .position(x: geometry.size.width * 0.5, y: presentationCenterY + 104)
                    .opacity(stage >= 2 ? 1 : 0)
                    .offset(y: stage >= 2 ? 0 : 18)
                }
            }
            .animation(.easeOut(duration: reduceMotion ? 0.01 : 0.5), value: stage)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(showsTitle ? "\(districtName)，\(encounterName)，战斗开始" : "战斗转场")
    }
}

private struct BattleClockSeal: View {
    let tint: Color
    let isLit: Bool

    var body: some View {
        Image("BattleRitualSeal")
            .resizable()
            .scaledToFit()
            .brightness(isLit ? 0.04 : 0)
            .shadow(color: tint.opacity(isLit ? 0.4 : 0), radius: 8)
            .accessibilityHidden(true)
    }
}

private struct DiamondSeal: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

private struct DungeonHeader: View {
    let title: String
    let subtitle: String
    let enemiesRemaining: Int
    let currentWave: Int
    let totalWaves: Int
    let waveTitle: String
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.headline.bold())
                    .frame(width: 34, height: 34)
                    .background(.black.opacity(0.56), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("退出副本")

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.bold())
                Text("\(subtitle) · 闪避红圈")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("第 \(currentWave)/\(totalWaves) 波")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.yellow)
                    .contentTransition(.numericText())
                Text("\(waveTitle) · 剩余 \(enemiesRemaining)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("第 \(currentWave) 波，共 \(totalWaves) 波，\(waveTitle)，剩余怪物 \(enemiesRemaining) 只")
        }
        .foregroundStyle(.white)
        .padding(10)
        .background(.black.opacity(0.58), in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.16), lineWidth: 1) }
    }
}

private struct BossHealthView: View {
    let name: String
    let fraction: CGFloat
    let isEnraged: Bool
    let intentName: String?
    let intentDamage: Int
    let willpowerFraction: CGFloat
    let controlOutcome: String?

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Label("BOSS · \(name)", systemImage: "crown.fill")
                    .font(.caption.bold())
                Spacer()
                if isEnraged {
                    Text("狂暴")
                        .font(.caption2.bold())
                        .foregroundStyle(.yellow)
                }
            }
            if let intentName {
                HStack(spacing: 5) {
                    Text("下一击")
                        .foregroundStyle(.white.opacity(0.58))
                    Text(intentName)
                        .foregroundStyle(isEnraged ? .yellow : .orange)
                    Spacer()
                    Text("伤害 \(intentDamage)")
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.82))
                }
                .font(.caption2.bold())
            }
            CombatProgressBar(
                fraction: fraction,
                colors: isEnraged ? [.orange, .red] : [.purple, .red]
            )
            HStack(spacing: 7) {
                Text("意志")
                    .foregroundStyle(.cyan)
                CombatProgressBar(
                    fraction: willpowerFraction,
                    colors: [.cyan, .blue]
                )
                if let controlOutcome {
                    Text(controlOutcome)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.white.opacity(0.68))
                }
            }
            .font(.caption2.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.64), in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke((isEnraged ? Color.orange : .purple).opacity(0.66), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.18), value: fraction)
        .animation(.easeOut(duration: 0.18), value: isEnraged)
        .accessibilityElement(children: .combine)
        .accessibilityValue("生命值 \(Int(fraction * 100)) 百分比")
    }
}

private struct CombatDock: View {
    let path: Pathway
    let combat: DungeonCombatSnapshot
    let skills: [DungeonSkillDefinition]
    let mission: DistrictMission?
    let isFirstClear: Bool
    let coinReward: Int
    let materialReward: Int
    let relicIDs: [String]
    let usedRelicIDs: Set<String>
    let autoBattleEnabled: Bool
    let onAttack: () -> Void
    let onSkill: (DungeonSkillID) -> Void
    let onRelic: (String) -> Void
    let onToggleAutoBattle: () -> Void
    let onRetry: () -> Void
    let onVictory: () -> Void
    @State private var selectedSkillID: DungeonSkillID?
    @State private var selectedRelicID: String?

    var body: some View {
        VStack(spacing: 9) {
            PlayerHealthView(
                health: combat.playerHealth,
                maximum: combat.maxPlayerHealth,
                resourceName: combat.pathResourceName,
                resourceValue: combat.pathResourceValue,
                resourceMaximum: combat.pathResourceMaximum
            )

            if combat.isVictorious {
                BattleVictoryPanel(
                    mission: mission,
                    isFirstClear: isFirstClear,
                    coinReward: coinReward,
                    materialReward: materialReward,
                    onClaim: onVictory
                )
            } else if combat.isDefeated {
                Button(action: onRetry) {
                    Label("重新挑战", systemImage: "arrow.clockwise")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.red.opacity(0.88), in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    Text(combat.status)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)

                    Button(action: onToggleAutoBattle) {
                        Text(autoBattleEnabled ? "已自动" : "自动")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(autoBattleEnabled ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(autoBattleEnabled ? Color.yellow : Color.white.opacity(0.12), in: Capsule())
                            .overlay { Capsule().stroke(.yellow.opacity(0.8), lineWidth: 1) }
                    }
                    .buttonStyle(CombatPressButtonStyle())
                    .accessibilityLabel(autoBattleEnabled ? "关闭自动战斗" : "开启自动战斗")
                }

                TacticalReadout(combat: combat, tint: path.tint)

                if MPCChapterOneCatalog.relicsEnabled {
                CombatRelicStrip(
                    relicIDs: relicIDs,
                    usedRelicIDs: usedRelicIDs,
                    selectedRelicID: $selectedRelicID,
                    isPlayerTurn: combat.isPlayerTurn,
                    onActivate: onRelic
                )
                }

                if let selectedSkill = skills.first(where: { $0.id == selectedSkillID }) {
                    CombatSkillDetail(
                        skill: selectedSkill,
                        remaining: combat.skillCooldowns[selectedSkill.id, default: 0],
                        isPlayerTurn: combat.isPlayerTurn,
                        onCast: {
                            selectedSkillID = nil
                            onSkill(selectedSkill.id)
                        },
                        onClose: { selectedSkillID = nil }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                CombatActionBar(
                    skills: skills,
                    cooldowns: combat.skillCooldowns,
                    isPlayerTurn: combat.isPlayerTurn,
                    selectedSkillID: selectedSkillID,
                    onSkill: { skillID in
                        withAnimation(.snappy(duration: 0.24)) {
                            selectedSkillID = selectedSkillID == skillID ? nil : skillID
                        }
                    },
                    onAttack: onAttack
                )
            }
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(path.tint.opacity(0.42), lineWidth: 1) }
        .animation(.easeOut(duration: 0.2), value: combat.isVictorious)
        .animation(.easeOut(duration: 0.2), value: combat.isDefeated)
        .padding(.bottom, 14)
    }
}

private struct TacticalReadout: View {
    let combat: DungeonCombatSnapshot
    let tint: Color

    var body: some View {
        VStack(spacing: 5) {
            if !combat.actionOrderLabels.isEmpty {
                HStack(spacing: 5) {
                    Text("行动")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.yellow)

                    ForEach(Array(combat.actionOrderLabels.enumerated()), id: \.offset) { index, label in
                        Text("\(index + 1)  \(label)")
                            .font(.system(size: 8, weight: .bold))
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(.white.opacity(index == 0 ? 0.15 : 0.07), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 5) {
                if let hint = combat.tacticalHint {
                    Text(hint)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                ForEach(combat.playerStatusLabels, id: \.self) { status in
                    Text(status)
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(tint.opacity(0.72), in: Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("战术提示")
    }
}

private struct BattleVictoryPanel: View {
    let mission: DistrictMission?
    let isFirstClear: Bool
    let coinReward: Int
    let materialReward: Int
    let onClaim: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("战斗胜利")
                        .font(.title3.bold())
                    Text(isFirstClear ? "首次净化 · 战利品已确认" : "回响重演 · 声望不重复计算")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                if let milestone = mission?.growthMilestone, isFirstClear {
                    Text(milestone.title)
                        .font(.caption2.bold())
                        .foregroundStyle(.yellow)
                }
            }

            HStack(spacing: 8) {
                LootSeal(artName: "RewardCoin", value: "+\(coinReward)", label: "雾港铜币")
                LootSeal(artName: "RewardMaterial", value: "+\(materialReward)", label: "晋阶辅材")
                    .opacity(materialReward > 0 ? 1 : 0.34)
                LootSeal(
                    artName: "RewardReputation",
                    value: isFirstClear ? "+\(mission?.reputationReward ?? ChapterDistrict.reputationPerMission)" : "+0",
                    label: "区域声望"
                )
            }

            MistportPlaqueButton(title: "收取战利品", action: onClaim)
        }
    }
}

private struct LootSeal: View {
    let artName: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Image(artName)
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .shadow(color: .black.opacity(0.34), radius: 5, y: 3)

            Text(value)
                .font(.caption.bold().monospacedDigit())
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.56))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PlayerHealthView: View {
    let health: Int
    let maximum: Int
    let resourceName: String?
    let resourceValue: Int
    let resourceMaximum: Int

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            CombatProgressBar(
                fraction: CGFloat(health) / CGFloat(max(1, maximum)),
                colors: [.red, .orange]
            )
            Text("\(health)/\(maximum)")
                .font(.caption.bold().monospacedDigit())
                .frame(width: 58, alignment: .trailing)
                .contentTransition(.numericText())
            if let resourceName, resourceMaximum > 0 {
                Text("\(resourceName) \(resourceValue)/\(resourceMaximum)")
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(.purple.opacity(0.92))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.88), in: Capsule())
                    .contentTransition(.numericText())
            }
        }
        .animation(.easeOut(duration: 0.16), value: health)
        .animation(.easeOut(duration: 0.16), value: resourceValue)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("玩家生命值")
        .accessibilityValue(
            resourceName.map { "\(health) / \(maximum) 点，\($0) \(resourceValue) / \(resourceMaximum)" }
                ?? "\(health) / \(maximum) 点"
        )
    }
}

private struct CombatProgressBar: View {
    let fraction: CGFloat
    let colors: [Color]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.14))
                Capsule()
                    .fill(.linearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 8)
    }
}

private struct CombatRelicStrip: View {
    let relicIDs: [String]
    let usedRelicIDs: Set<String>
    @Binding var selectedRelicID: String?
    let isPlayerTurn: Bool
    let onActivate: (String) -> Void

    var body: some View {
        HStack(spacing: 7) {
            Text("遗落物")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.yellow)

            ForEach(relicIDs, id: \.self) { relicID in
                if let relic = CharacterLoadoutCatalog.weapon(id: relicID) {
                    Button {
                        selectedRelicID = selectedRelicID == relicID ? nil : relicID
                    } label: {
                        HStack(spacing: 5) {
                            Image(relic.artName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            VStack(alignment: .leading, spacing: 0) {
                                Text(relic.name)
                                    .font(.system(size: 9, weight: .bold))
                                Text(usedRelicIDs.contains(relicID) ? "本场已发动" : "点击查看")
                                    .font(.system(size: 7, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(.white.opacity(selectedRelicID == relicID ? 0.16 : 0.07), in: Capsule())
                        .overlay { Capsule().stroke(relic.color.opacity(0.72), lineWidth: 1) }
                    }
                    .buttonStyle(CombatPressButtonStyle())
                }
            }

            Spacer(minLength: 0)
        }

        if let selectedRelicID,
           let relic = CharacterLoadoutCatalog.weapon(id: selectedRelicID) {
            HStack(spacing: 8) {
                Text(relic.effect)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Spacer(minLength: 4)
                MistportPlaqueButton(
                    title: "发动",
                    compact: true,
                    expands: false,
                    isEnabled: !usedRelicIDs.contains(selectedRelicID) && isPlayerTurn,
                    action: {
                        onActivate(selectedRelicID)
                        self.selectedRelicID = nil
                    }
                )
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 10))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

private struct CombatSkillDetail: View {
    let skill: DungeonSkillDefinition
    let remaining: TimeInterval
    let isPlayerTurn: Bool
    let onCast: () -> Void
    let onClose: () -> Void

    private var typeName: String {
        switch skill.behavior {
        case .projectile: "远程 · 单体弹射"
        case .dashStrike: "应变 · 错位反击"
        case .areaBurst: "秘术 · 范围爆发"
        }
    }

    private var description: String {
        switch skill.id {
        case .strike: "以放大的秘仪牌锁定弱点。命中造成伤害并削减意志，愚者牌会向附近目标弹射。"
        case .mobility: "预先留下错误位置。下一次敌方攻击可由替身承受，同时对目标发动反击。"
        case .control: "解读敌方意图并制造破绽；高额削减意志，击破后延后敌方行动。"
        case .ward: "记录即将到来的危险，获得一次防护，并积累可由终结技兑现的预兆。"
        case .ultimate: "将全部预兆写入牌阵，对范围内敌人造成爆发伤害；每层预兆都会提高伤害。"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(skill.id.artName)
                .resizable()
                .scaledToFill()
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .overlay { RoundedRectangle(cornerRadius: 11).stroke(skill.tint, lineWidth: 2) }
                .shadow(color: skill.tint.opacity(0.7), radius: 8)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(skill.name)
                        .font(.subheadline.bold())
                    Text(typeName)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(skill.tint)
                }
                Text(description)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)
                Text("伤害 \(skill.damage) · 冷却 \(Int(ceil(skill.cooldown))) 回合")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(.yellow)
            }

            VStack(spacing: 6) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .frame(width: 26, height: 26)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                MistportPlaqueButton(
                    title: "释放",
                    compact: true,
                    expands: false,
                    isEnabled: remaining <= 0 && isPlayerTurn,
                    action: onCast
                )
            }
        }
        .padding(9)
        .background(.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(skill.tint.opacity(0.7), lineWidth: 1) }
    }
}

private struct CombatActionBar: View {
    let skills: [DungeonSkillDefinition]
    let cooldowns: [DungeonSkillID: TimeInterval]
    let isPlayerTurn: Bool
    let selectedSkillID: DungeonSkillID?
    let onSkill: (DungeonSkillID) -> Void
    let onAttack: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(skills) { skill in
                SkillCooldownButton(
                    skill: skill,
                    remaining: cooldowns[skill.id, default: 0],
                    isPlayerTurn: isPlayerTurn,
                    isSelected: selectedSkillID == skill.id,
                    action: { onSkill(skill.id) }
                )
            }

            Spacer(minLength: 1)

            Button(action: onAttack) {
                VStack(spacing: 1) {
                    Image("IconBasicAttackFool")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 58, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                    Text("普攻")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(width: 64, height: 72)
                .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.orange.opacity(isPlayerTurn ? 1 : 0.28), lineWidth: 3)
                }
                .shadow(color: .purple.opacity(isPlayerTurn ? 0.58 : 0), radius: 10)
                .saturation(isPlayerTurn ? 1 : 0.3)
                .opacity(isPlayerTurn ? 1 : 0.48)
            }
            .buttonStyle(CombatPressButtonStyle())
            .disabled(!isPlayerTurn)
            .accessibilityLabel("普通攻击")
            .accessibilityValue(isPlayerTurn ? "可以使用" : "等待敌方行动结束")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("战斗技能栏")
    }
}

private struct SkillCooldownButton: View {
    let skill: DungeonSkillDefinition
    let remaining: TimeInterval
    let isPlayerTurn: Bool
    let isSelected: Bool
    let action: () -> Void

    private var cooldownTurns: TimeInterval {
        max(1, ceil(skill.cooldown))
    }

    private var cooldownFraction: CGFloat {
        max(0, min(1, remaining / cooldownTurns))
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(.black.opacity(0.62))
                    Image(skill.id.artName)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .saturation(remaining > 0 || !isPlayerTurn ? 0.28 : 1)
                        .opacity(remaining > 0 || !isPlayerTurn ? 0.48 : 1)

                    RoundedRectangle(cornerRadius: 9)
                        .trim(from: 0, to: cooldownFraction)
                        .stroke(.black.opacity(0.78), style: StrokeStyle(lineWidth: 7, lineCap: .butt))
                        .rotationEffect(.degrees(-90))

                    if remaining > 0 {
                        Text("\(Int(ceil(remaining)))")
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 48, height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(isSelected ? Color.white : skill.tint, lineWidth: isSelected ? 3 : 2)
                }
                .shadow(color: isSelected ? skill.tint.opacity(0.9) : .clear, radius: 8)

                Text(skill.name)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(remaining > 0 || !isPlayerTurn ? 0.42 : 0.82))
                    .lineLimit(1)
                    .frame(width: 47)
            }
        }
        .buttonStyle(CombatPressButtonStyle())
        .disabled(!isPlayerTurn)
        .accessibilityLabel(skill.name)
        .accessibilityValue(
            !isPlayerTurn
                ? "等待敌方行动结束"
                : (remaining > 0 ? "冷却剩余 \(Int(ceil(remaining))) 回合" : "可以释放")
        )
        .accessibilityHint("造成 \(skill.damage) 点伤害")
    }
}

private struct CombatPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1)
            .brightness(configuration.isPressed ? 0.12 : 0)
            .animation(.bouncy(duration: 0.18), value: configuration.isPressed)
    }
}

#if DEBUG
#Preview {
    DungeonPrototypeView(
        path: GameContent.pathways[0],
        mission: GameContent.chapterOneDistricts[0].missions[0],
        onExit: {},
        onVictory: {}
    )
}
#endif
