import SwiftUI

struct WorldRouteView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(decorative: "MistportWorldMap")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.34), .clear, .black.opacity(0.40)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                SceneAtmosphere(rainStrength: 0, fogOpacity: 0.16, tint: .cyan)

                ForEach(GameContent.worldRoute) { region in
                    WorldMapNode(region: region)
                        .position(nodePosition(for: region, in: geometry.size))
                }

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("九联邦航路")
                                .font(.title2.bold())
                            Text("序列 9 → 0")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.white.opacity(0.62))
                        }
                        Spacer()
                        Button("完成", systemImage: "xmark", action: { dismiss() })
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 16))
                    Spacer()
                    Label("当前 · 雾岬自由联邦", systemImage: "location.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.68), in: Capsule())
                }
                .frame(
                    width: max(0, geometry.size.width - 28),
                    height: max(0, geometry.size.height - 16)
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    private func nodePosition(for region: WorldRegion, in size: CGSize) -> CGPoint {
        let normalized: CGPoint
        switch region.sequence {
        case 9: normalized = CGPoint(x: 0.43, y: 0.86)
        case 8: normalized = CGPoint(x: 0.66, y: 0.75)
        case 7: normalized = CGPoint(x: 0.34, y: 0.65)
        case 6: normalized = CGPoint(x: 0.64, y: 0.56)
        case 5: normalized = CGPoint(x: 0.35, y: 0.47)
        case 4: normalized = CGPoint(x: 0.66, y: 0.39)
        case 3: normalized = CGPoint(x: 0.36, y: 0.31)
        case 2: normalized = CGPoint(x: 0.66, y: 0.24)
        case 1: normalized = CGPoint(x: 0.43, y: 0.16)
        default: normalized = CGPoint(x: 0.65, y: 0.09)
        }
        return CGPoint(x: size.width * normalized.x, y: size.height * normalized.y)
    }
}

private struct WorldMapNode: View {
    let region: WorldRegion

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 5) {
                Text("\(region.sequence)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.black)
                    .frame(width: 25, height: 25)
                    .background(nodeColor, in: Circle())
                Text(region.sequence >= 8 || region.sequence == 0 ? region.name : "序列 \(region.sequence)")
                    .font(.caption2.bold())
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.leading, 4)
            .padding(.trailing, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.66), in: Capsule())
            .overlay { Capsule().stroke(nodeColor.opacity(0.68), lineWidth: 1) }
            .shadow(color: nodeColor.opacity(0.34), radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(region.access == .locked)
        .opacity(region.access == .locked ? 0.68 : 1)
        .accessibilityLabel("序列 \(region.sequence)，\(region.name)")
    }

    private var nodeColor: Color {
        switch region.access {
        case .current: .yellow
        case .preview: .purple
        case .locked: .gray
        case .final: .cyan
        }
    }
}

private struct WorldRouteSummary: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("序列 9 → 1：九个主题联邦", systemImage: "map.fill")
                .font(.headline)
                .foregroundStyle(.yellow)
            Text("每个联邦只制作 1 座核心城、2 片卫星区域与 2–3 个重点副本。其余城市存在于航线、档案与角色口述中，既保留世界规模，也控制制作成本。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .lineSpacing(3)
            Text("序列 0 不是第十个联邦，而是终局“无冕天域”。")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.purple)
        }
        .padding(16)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

private struct WorldRegionCard: View {
    let region: WorldRegion

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            sequenceSeal

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(region.name)
                        .font(.headline)
                        .foregroundStyle(regionColor)
                    Spacer(minLength: 8)
                    Text(accessLabel)
                        .font(.caption2.bold())
                        .foregroundStyle(regionColor)
                }

                Text("核心城 · \(region.capital)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.74))
                Text(region.theme)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                Text(region.conflict)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .background(regionColor.opacity(0.085), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(regionColor.opacity(0.28), lineWidth: 1) }
        .opacity(region.access == .locked ? 0.72 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("序列 \(region.sequence)，\(region.name)，核心城 \(region.capital)，\(accessLabel)")
    }

    private var sequenceSeal: some View {
        VStack(spacing: 1) {
            Text("序列")
                .font(.system(.caption2, design: .rounded).weight(.semibold))
            Text("\(region.sequence)")
                .font(.title3.bold().monospacedDigit())
        }
        .foregroundStyle(regionColor)
        .frame(width: 52, height: 52)
        .background(regionColor.opacity(0.11), in: Circle())
        .overlay { Circle().stroke(regionColor.opacity(0.46), lineWidth: 1) }
        .accessibilityHidden(true)
    }

    private var regionColor: Color {
        switch region.access {
        case .current: .yellow
        case .preview: .purple
        case .locked: .gray
        case .final: .cyan
        }
    }

    private var accessLabel: String {
        switch region.access {
        case .current: "序章开放"
        case .preview: "下一篇章"
        case .locked: "尚未抵达"
        case .final: "六路终局"
        }
    }
}

struct ExpeditionBoardView: View {
    private enum MatchState: Equatable {
        case idle
        case matching
        case ready
    }

    @Environment(\.dismiss) private var dismiss
    @State private var matchState: MatchState = .idle
    let selectedPath: Pathway?
    let expedition: ExpeditionDefinition
    let isUnlocked: Bool
    let completedMissionCount: Int
    let onEnter: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(decorative: "SceneMirrorTheater")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                LinearGradient(
                    colors: [.black.opacity(0.25), .clear, .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                SceneAtmosphere(rainStrength: 0, fogOpacity: 0.22, tint: .cyan)

                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(expedition.city)远征站")
                                .font(.title2.bold())
                            Label("联机演示", systemImage: "hammer.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(.yellow)
                        }
                        Spacer()
                        Button("完成", systemImage: "xmark", action: { dismiss() })
                            .labelStyle(.iconOnly)
                            .buttonStyle(.bordered)
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))

                    Spacer()
                    compactParty
                    compactExpeditionDock
                }
                .frame(
                    width: max(0, geometry.size.width - 28),
                    height: max(0, geometry.size.height - 16)
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    private var compactParty: some View {
        HStack(spacing: 8) {
            ForEach(GameContent.expeditionMembers(for: selectedPath)) { member in
                ExpeditionMemberToken(member: member, isReady: matchState == .ready)
            }
        }
        .padding(10)
        .background(.black.opacity(0.68), in: Capsule())
        .overlay { Capsule().stroke(.white.opacity(0.14), lineWidth: 1) }
    }

    private var compactExpeditionDock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(expedition.title)
                        .font(.title3.bold())
                    Text("\(expedition.city) · 约 \(expedition.estimatedMinutes) 分钟")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.cyan)
                }
                Spacer()
                Text(matchState == .ready ? "6/6" : "1/6")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(matchState == .ready ? .green : .white.opacity(0.62))
            }

            Text(expedition.objective)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .lineLimit(1)

            Button(action: handleMatchButton) {
                Label(matchButtonTitle, systemImage: matchButtonSymbol)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(matchState == .ready ? .green : .cyan)
            .foregroundStyle(.black)
            .disabled(!isUnlocked || matchState == .matching)
            .sensoryFeedback(.success, trigger: matchState == .ready)

            Label(
                isUnlocked
                    ? "无公会 · 无打卡 · AI 随时补位"
                    : "远征将在后续测试开放",
                systemImage: isUnlocked ? "bolt.horizontal.circle.fill" : "lock.fill"
            )
                .font(.caption2.bold())
                .foregroundStyle(.yellow)
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(.black.opacity(0.80), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(.cyan.opacity(0.38), lineWidth: 1) }
    }

    private var prototypeNotice: some View {
        Label("玩法原型：正在展示匹配与 AI 补位流程，尚未连接真实服务器", systemImage: "hammer.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.yellow)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
    }

    private var taskFlow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("任务三段式")
                .font(.headline)

            ForEach(Array(TaskStage.allCases.enumerated()), id: \.element.id) { index, stage in
                HStack(spacing: 12) {
                    Image(systemName: stage.symbol)
                        .foregroundStyle(index == 1 ? .cyan : .purple)
                        .frame(width: 26)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(index + 1). \(stage.title)")
                            .font(.subheadline.weight(.semibold))
                        Text(stage.detail)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
    }

    private var expeditionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(expedition.city, systemImage: "location.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                Spacer()
                Text("约 \(expedition.estimatedMinutes) 分钟")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
            Text(expedition.title)
                .font(.title2.bold())
            Text(expedition.objective)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.74))
                .lineSpacing(3)
            Label(expedition.storyReason, systemImage: "book.closed.fill")
                .font(.caption)
                .foregroundStyle(.purple.opacity(0.9))

            Button(action: beginMatching) {
                Label(matchButtonTitle, systemImage: matchButtonSymbol)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .foregroundStyle(.black)
            .disabled(matchState != .idle)
            .sensoryFeedback(.success, trigger: matchState == .ready)
        }
        .padding(18)
        .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(.cyan.opacity(0.35), lineWidth: 1) }
    }

    private var partySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("临时远征队")
                    .font(.headline)
                Spacer()
                Text(matchState == .ready ? "6 / 6 已就绪" : "1 / 6 等待补位")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(matchState == .ready ? .green : .white.opacity(0.52))
            }

            ForEach(GameContent.expeditionMembers(for: selectedPath)) { member in
                ExpeditionMemberRow(member: member, isReady: matchState == .ready)
            }
        }
        .padding(16)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }

    private var noGuildPolicy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("没有公会打卡", systemImage: "calendar.badge.minus")
                .font(.headline)
                .foregroundStyle(.yellow)
            Text("保留好友与最近同行者，不设置会长、捐献、签到和强制团本。城市公共事件采用异步贡献，不要求固定时间上线。")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.64))
                .lineSpacing(3)
        }
        .padding(16)
        .background(.yellow.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private var matchButtonTitle: String {
        guard isUnlocked else { return "团队副本尚未开放" }
        return switch matchState {
        case .idle: "随到随组 · 开始匹配"
        case .matching: "正在寻找同行者…"
        case .ready: "进入团队副本"
        }
    }

    private var matchButtonSymbol: String {
        guard isUnlocked else { return "lock.fill" }
        return switch matchState {
        case .idle: "person.3.fill"
        case .matching: "hourglass"
        case .ready: "checkmark.seal.fill"
        }
    }

    private func beginMatching() {
        guard isUnlocked, matchState == .idle else { return }
        matchState = .matching

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            matchState = .ready
        }
    }

    private func handleMatchButton() {
        if matchState == .ready {
            onEnter()
        } else {
            beginMatching()
        }
    }
}

private struct ExpeditionMemberToken: View {
    let member: ExpeditionMember
    let isReady: Bool

    private var path: Pathway? {
        GameContent.pathways.first { $0.id == member.id }
    }

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: member.symbol)
                .font(.caption.bold())
                .foregroundStyle(path?.tint ?? .white)
                .frame(width: 31, height: 31)
                .background((path?.tint ?? .white).opacity(0.14), in: Circle())
                .overlay { Circle().stroke((path?.tint ?? .white).opacity(0.46), lineWidth: 1) }
            Circle()
                .fill(member.isLocalPlayer ? .yellow : (isReady ? .green : .gray))
                .frame(width: 5, height: 5)
        }
        .opacity(member.isLocalPlayer || isReady ? 1 : 0.42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(member.name)，\(member.isLocalPlayer ? "你" : (isReady ? "潮汐化身" : "空位"))")
    }
}

private struct ExpeditionMemberRow: View {
    let member: ExpeditionMember
    let isReady: Bool

    private var path: Pathway? {
        GameContent.pathways.first { $0.id == member.id }
    }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: member.symbol)
                .foregroundStyle(path?.tint ?? .white)
                .frame(width: 28, height: 28)
                .background((path?.tint ?? .white).opacity(0.10), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline.weight(.semibold))
                Text(member.role)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.52))
            }
            Spacer()
            Text(member.isLocalPlayer ? "你" : (isReady ? "潮汐化身" : "空位"))
                .font(.caption2.bold())
                .foregroundStyle(member.isLocalPlayer ? .yellow : (isReady ? .cyan : .white.opacity(0.38)))
        }
        .padding(.vertical, 4)
        .opacity(member.isLocalPlayer || isReady ? 1 : 0.52)
        .accessibilityElement(children: .combine)
    }
}
