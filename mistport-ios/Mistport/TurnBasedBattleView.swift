import SwiftUI

struct TurnBasedBattleView: View {
    @State private var model = TurnBasedBattleViewModel()
    @State private var enemyAttackPulse = 0
    @State private var inspectedSkill: TBSkillDefinition?

    let onExit: () -> Void

    var body: some View {
        ZStack {
            Image(decorative: "SceneClockDistrictV2")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.24), .black.opacity(0.05), .black.opacity(0.72)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }

            VStack(spacing: 10) {
                battleHeader
                intentTimeline
                battlefield
                playerStatus
                skillBar
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .overlay(alignment: .center) {
            if case .finished(let outcome) = model.phase {
                outcomeOverlay(outcome)
            }
        }
        .sensoryFeedback(.selection, trigger: model.selectedSkillID)
        .sensoryFeedback(.impact, trigger: model.battle.actionIndex)
        .onChange(of: model.battle.actionIndex) {
            enemyAttackPulse += 1
        }
        .sheet(item: $inspectedSkill) { skill in
            SkillDetailSheet(skill: skill)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var battleHeader: some View {
        HStack(spacing: 12) {
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.headline.bold())
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.54), in: .circle)
            }
            .tint(.white)
            .accessibilityLabel("退出战斗")

            VStack(alignment: .leading, spacing: 2) {
                Text("调查一 · 雨夜醒钟")
                    .font(.headline)
                Text("第 \(model.battle.round) 回合 · 观察教学")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 6)

            Label("\(model.player.omen)/6", systemImage: "sparkles")
                .font(.subheadline.bold())
                .foregroundStyle(.yellow)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.56), in: .capsule)
                .accessibilityLabel("预兆 \(model.player.omen)，上限 6")
        }
        .foregroundStyle(.white)
    }

    private var intentTimeline: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("行动时间轴", systemImage: "clock.arrow.circlepath")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.82))
                Spacer()
                Text(model.message)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                timelineToken(title: "你", detail: "选择行动", tint: .cyan, isFatal: false)
                ForEach(model.enemies) { enemy in
                    let intent = enemy.nextIntent
                    timelineToken(
                        title: enemy.name,
                        detail: intentTitle(intent),
                        tint: intent?.isFatal == true ? .red : .orange,
                        isFatal: intent?.isFatal == true
                    )
                }
            }
        }
        .padding(10)
        .background(.black.opacity(0.62), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.yellow.opacity(0.34), lineWidth: 1)
        }
    }

    private var battlefield: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 8) {
                VStack(spacing: 4) {
                    Image(decorative: "PathFoolMale")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 210)
                        .clipShape(.rect(cornerRadius: 12))
                        .shadow(color: .cyan.opacity(0.34), radius: 16)

                    Text(model.player.name)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                }
                .frame(width: proxy.size.width * 0.36)

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(model.enemies) { enemy in
                        EnemyBattleFigure(
                            enemy: enemy,
                            attackPulse: enemyAttackPulse,
                            isSelected: model.selectedEnemyID == enemy.id,
                            action: { model.selectEnemy(enemy.id) }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: proxy.size.width * 0.62)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(maxHeight: .infinity)
    }

    private var playerStatus: some View {
        VStack(spacing: 7) {
            HStack {
                statBar(
                    title: "生命",
                    value: model.player.health,
                    maximum: model.player.maxHealth,
                    tint: .red
                )
                statBar(
                    title: "护幕",
                    value: model.player.armor,
                    maximum: 30,
                    tint: .cyan
                )
            }

            if let preview = model.preview {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("预计结果")
                            .font(.caption.bold())
                            .foregroundStyle(.yellow)
                        Text(previewSummary(preview))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.76))
                            .lineLimit(2)
                        if let warning = preview.warnings.first {
                            Text(warning)
                                .font(.caption2.bold())
                                .foregroundStyle(.orange)
                                .lineLimit(2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button("取消", action: model.cancelPreview)
                        .buttonStyle(.bordered)
                    Button("确认结算", action: model.confirmSelection)
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                        .foregroundStyle(.black)
                }
                .padding(9)
                .background(.black.opacity(0.72), in: .rect(cornerRadius: 12))
            } else if let error = model.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var skillBar: some View {
        HStack(spacing: 7) {
            ForEach(model.skills) { skill in
                BattleSkillButton(
                    skill: skill,
                    cooldown: model.cooldown(for: skill),
                    omen: model.player.omen,
                    isSelected: model.selectedSkillID == skill.id,
                    isEnabled: model.canSelect(skill),
                    action: { model.selectSkill(skill.id) },
                    inspect: { inspectedSkill = skill }
                )
            }
        }
        .padding(8)
        .background(.black.opacity(0.78), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.yellow.opacity(0.34), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("战斗技能")
    }

    private func timelineToken(
        title: String,
        detail: String,
        tint: Color,
        isFatal: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2.bold())
                .lineLimit(1)
            HStack(spacing: 3) {
                if isFatal {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                Text(detail)
                    .lineLimit(1)
            }
            .font(.caption2)
        }
        .foregroundStyle(isFatal ? Color.white : tint)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(tint.opacity(isFatal ? 0.72 : 0.18), in: .rect(cornerRadius: 9))
        .accessibilityElement(children: .combine)
    }

    private func statBar(
        title: String,
        value: Int,
        maximum: Int,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(title) \(value)/\(maximum)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
            ProgressView(value: Double(value), total: Double(max(1, maximum)))
                .tint(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 3)
    }

    private func intentTitle(_ intent: TBEnemyIntent?) -> String {
        guard let intent, intent.isRevealed else { return "未知意图" }
        return switch intent.kind {
        case .attack: "攻击 \(intent.magnitude)"
        case .heavyAttack: "蓄力强攻 \(intent.magnitude)"
        case .defend: "防御"
        case .strengthen: "强化"
        case .heal: "修复"
        case .hideInformation: "吞没信息"
        }
    }

    private func previewSummary(_ preview: TBActionPreview) -> String {
        preview.events.map { event in
            switch event.payload {
            case .damage(let amount): "伤害 \(amount)"
            case .willDamage(let amount): "削减意志 \(amount)"
            case .armor(let amount): "护甲 +\(amount)"
            case .veil(let amount): "护幕 +\(amount)"
            case .omen(let amount): "预兆 +\(amount)"
            case .cleanse: "净化状态"
            case .revealIntent: "读取意图"
            case .evadeAnnouncedAttack: "闪避已预告攻击"
            }
        }
        .joined(separator: " · ")
    }

    private func outcomeOverlay(_ outcome: TBCombatOutcome) -> some View {
        VStack(spacing: 12) {
            Text(outcome == .victory ? "调查推进" : "观测失败")
                .font(.largeTitle.bold())
                .foregroundStyle(outcome == .victory ? .yellow : .red)
            Text(outcome == .victory
                 ? "你读懂了雨夜中的第一次敌意。"
                 : "回看敌方意图，尝试为蓄力强攻保留防护。")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            Button("重新演练", action: model.restart)
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
            Button("退出", action: onExit)
                .buttonStyle(.bordered)
        }
        .padding(28)
        .background(.black.opacity(0.9), in: .rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .stroke(.yellow.opacity(0.7), lineWidth: 1)
        }
        .padding(28)
    }
}

private struct EnemyBattleFigure: View {
    let enemy: TBCombatantState
    let attackPulse: Int
    let isSelected: Bool
    let action: () -> Void
    @State private var attackFrame = 0

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(decorative: currentArtName)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 150)
                        .offset(x: lungeOffset)
                        .scaleEffect(lungeScale, anchor: .bottom)
                        .shadow(color: isSelected ? .yellow.opacity(0.8) : .black, radius: 12)
                    if isHound && attackFrame > 0 {
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { index in
                                Capsule()
                                    .fill(Color.red.opacity(0.76 - Double(index) * 0.16))
                                    .frame(width: 3, height: 27)
                                    .rotationEffect(.degrees(-28))
                            }
                        }
                        .offset(x: 16, y: 82)
                        .transition(.opacity)
                    }
                    if enemy.nextIntent?.isFatal == true {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red, .white)
                            .padding(4)
                    }
                }

                Text(enemy.name)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                ProgressView(value: Double(enemy.health), total: Double(enemy.maxHealth))
                    .tint(.red)
                ProgressView(value: Double(enemy.will), total: Double(max(1, enemy.maxWill)))
                    .tint(.cyan)
            }
            .padding(7)
            .background(.black.opacity(0.42), in: .rect(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .stroke(isSelected ? .yellow : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .task(id: attackPulse) {
            guard attackPulse > 0 else { return }
            attackFrame = 0
            let frameCount = max(attackFrames.count, isHound ? 5 : 1)
            for frame in 0..<frameCount {
                try? await Task.sleep(for: .milliseconds(90))
                guard !Task.isCancelled else { return }
                withAnimation(.linear(duration: 0.04)) {
                    attackFrame = frame
                }
            }
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            attackFrame = 0
        }
        .accessibilityLabel("\(enemy.name)，生命 \(enemy.health)，意志 \(enemy.will)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var artName: String {
        isHound
            ? "HellHoundIdleV401"
            : "ClockGuardCurrent3DPreview"
    }

    private var isHound: Bool { enemy.id.rawValue.contains("hound") }

    private var attackFrames: [String] {
        isHound
            ? []
            : ["ClockGuardCurrent3DPreview"]
    }

    private var currentArtName: String {
        guard attackFrame > 0, !attackFrames.isEmpty else { return artName }
        return attackFrames[min(attackFrame - 1, attackFrames.count - 1)]
    }

    private var lungeOffset: CGFloat {
        guard isHound else { return 0 }
        return attackFrame == 0 ? 0 : CGFloat(min(attackFrame, 4)) * 7
    }

    private var lungeScale: CGFloat {
        guard isHound else { return 1 }
        return attackFrame == 0 ? 1 : 1.0 + CGFloat(min(attackFrame, 4)) * 0.035
    }
}

private struct BattleSkillButton: View {
    let skill: TBSkillDefinition
    let cooldown: Int
    let omen: Int
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    let inspect: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(skill.slot == .core ? Color.yellow.opacity(0.2) : Color.indigo.opacity(0.34))
                    Image(systemName: symbolName)
                        .font(.headline)
                        .foregroundStyle(skill.slot == .core ? .yellow : .white)
                    if cooldown > 0 {
                        Text("\(cooldown)")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.black.opacity(0.72), in: .circle)
                    }
                    Button(action: inspect) {
                        Image(systemName: "viewfinder.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white, .black.opacity(0.72))
                            .shadow(color: .black.opacity(0.7), radius: 3)
                    }
                    .buttonStyle(.plain)
                    .offset(x: 20, y: -22)
                    .accessibilityLabel("查看 (skill.name) 详情")
                }
                .frame(width: 42, height: 42)

                Text(skill.name)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                if skill.omenCost > 0 {
                    Text("预兆 \(skill.omenCost)")
                        .font(.caption2)
                        .foregroundStyle(omen >= skill.omenCost ? .yellow : .red)
                } else {
                    Text("CD \(skill.cooldown)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .padding(.vertical, 5)
            .background(isSelected ? Color.yellow.opacity(0.2) : .clear, in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? .yellow : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
        .accessibilityLabel("\(skill.name)，\(skill.slot == .core ? "核心技能" : "普通技能")")
        .accessibilityValue(cooldown > 0 ? "冷却剩余 \(cooldown) 回合" : "可以使用")
        .accessibilityHint("选择后预览结算结果")
    }

    private var symbolName: String {
        switch skill.id.rawValue {
        case let id where id.contains("weak-point"): "scope"
        case let id where id.contains("evasion"): "figure.run"
        case let id where id.contains("divination"): "eye.fill"
        case let id where id.contains("premonition"): "shield.lefthalf.filled"
        default: "sparkles.rectangle.stack.fill"
        }
    }
}

private struct SkillDetailSheet: View {
    let skill: TBSkillDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 3) {
                    Text(skill.name).font(.title3.bold())
                    Text(skill.slot == .core ? "核心技能" : "主动技能")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            Text(skillDescription)
                .font(.body)
                .foregroundStyle(.primary)
            HStack {
                Label("冷却 (skill.cooldown)", systemImage: "clock")
                if skill.omenCost > 0 {
                    Label("预兆 (skill.omenCost)", systemImage: "sparkles")
                }
            }
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
    }

    private var skillDescription: String {
        switch skill.id.rawValue {
        case let id where id.contains("weak-point"): return "锁定敌人的破绽，以精准的灵性打击削弱其防护。"
        case let id where id.contains("evasion"): return "短暂偏离当前命运轨迹，降低下一次受到攻击的风险。"
        case let id where id.contains("divination"): return "读取敌人的行动征兆，并将一部分力量转化为可用预兆。"
        case let id where id.contains("premonition"): return "提前感知危险，在敌人命中前建立一道短暂护幕。"
        default: return "将这张卡牌打出，按当前战斗预览结算效果。"
        }
    }
}

#if DEBUG
#Preview {
    TurnBasedBattleView(onExit: {})
        .preferredColorScheme(.dark)
}
#endif
