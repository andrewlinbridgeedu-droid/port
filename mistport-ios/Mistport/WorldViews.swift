import MistportCombatCore
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

/// Chapter Two's minimal bridge: the Black Salt Shore pier, the outer-harbour
/// transfer station and its two event contacts, and the way back to the pier.
/// Names and places are provisional; no portraits exist yet, so none are drawn.
struct BlackSaltShoreView: View {
    @Bindable var game: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var openContact: MPCChapterTwoBridge.Contact?
    @State private var showsEvent = ProcessInfo.processInfo.arguments.contains("--preview-lights-event")
    @State private var showsWork = ProcessInfo.processInfo.arguments.contains("--preview-lights-work")
    @State private var notice = ""

    private var atStation: Bool { game.chapterTwoBridge.location == .station }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(decorative: atStation ? "SaltportStationBackdrop" : "BlackSaltShoreBackdrop")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.65), .clear, .black.opacity(0.18), .black.opacity(0.78)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        blackSaltHeader
                        Spacer(minLength: atStation ? max(120, geometry.size.height * 0.18) : max(160, geometry.size.height * 0.26))
                        if atStation { station } else { shore }
                        if !notice.isEmpty {
                            Text(notice)
                                .font(.footnote)
                                .foregroundStyle(.orange)
                                .padding(.top, 12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height, alignment: .top)
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showsEvent) { LightsEventPreviewView() }
        .background(Color.clear.fullScreenCover(isPresented: $showsWork) { LightsLocalEventView(game: game) })
    }

    private var blackSaltHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(ChurchGold.opacity(0.7), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")
            VStack(alignment: .leading, spacing: 3) {
                Text(atStation ? "盐岸外港转运站" : "黑盐岸 · 检疫码头")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(ChurchGold)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                Text("第二章 · 地点与人物均为暂名")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private var shore: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Rectangle().fill(ChurchGold).frame(width: 22, height: 1)
                Text("退潮后的黑盐岸")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(ChurchGold)
            }
            Text("潮水退去，码头木桩上结着一层黑盐。雾港的灯已经看不见了。")
                .font(.system(size: 19, design: .serif))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Text("获救的居民仍然自由，伊恩回到了诊所，替代封口依旧有效。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.78))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(ChurchGold.opacity(0.35)).frame(height: 1)
            Text(game.sequenceEightRitualStatus)
                .font(.footnote)
                .foregroundStyle(ChurchGold)
                .fixedSize(horizontal: false, vertical: true)
            if !game.sequenceEightQualified {
                blackSaltAction(title: "举行序列 8 仪式", detail: "\(MPCSequenceEightRitual.fee) 铜币",
                                symbol: "sparkle", enabled: game.churchHasDepartedMistport) {
                    game.performAdvancement()
                    notice = game.featureMessage
                }
            } else {
                Text("外港转运站在前方航线上。驶向雾港的燃料和检修货物都在那里换船。")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.78)).lineSpacing(4)
                blackSaltAction(title: "前往外港转运站", symbol: "arrow.right") {
                    game.travelToSaltportStation()
                    notice = game.chapterTwoBridgeOpen ? "" : game.chapterTwoBridgeStatus
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.035, green: 0.055, blue: 0.08).opacity(0.9),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(ChurchGold.opacity(0.36), lineWidth: 1))
    }

    private func blackSaltAction(title: String, detail: String? = nil, symbol: String,
                                 enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            GameInterfaceSound.shared.playClick()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 26)
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 2)
                if let detail {
                    Text(detail)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(Color(red: 0.08, green: 0.07, blue: 0.08))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(ChurchGold, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(detail.map { "\(title)，\($0)" } ?? title)
    }

    private var station: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("转运站只有一套主接驳装置。两家要的控制配置互不兼容，接下来三十天的供能检修权只能给一家。")
                .font(.body).foregroundStyle(.white.opacity(0.85)).lineSpacing(5)
                .padding(14)
                .background(Color(red: 0.035, green: 0.055, blue: 0.08).opacity(0.88), in: RoundedRectangle(cornerRadius: 12))
            ForEach(MPCChapterTwoBridge.Contact.allCases, id: \.self) { contact in
                contactCard(contact)
            }
            Text(game.chapterTwoBridge.worldEventStoryReady
                 ? "两份计划你都听过了。转运站的维修与采购尚未开放。"
                 : "两家负责人都在站内。先听听他们各自的打算。")
                .font(.footnote).foregroundStyle(.white.opacity(0.6))
            if game.chapterTwoBridge.worldEventStoryReady {
                blackSaltAction(title: "转运站检修单", detail: game.lightsEvent.closed ? "已结束" : "本存档", symbol: "wrench.and.screwdriver") { showsWork = true }
                blackSaltAction(title: "供能争端 · 事件预览", detail: "假设快照", symbol: "newspaper") { showsEvent = true }
            }
            ChurchActionButton(title: "返回黑盐岸码头") { game.returnToBlackSaltShore() }
        }
    }

    private func contactCard(_ contact: MPCChapterTwoBridge.Contact) -> some View {
        let met = game.chapterTwoBridge.metContacts.contains(contact)
        let expanded = openContact == contact || met
        return Button {
            GameInterfaceSound.shared.playClick()
            game.meetSaltportContact(contact)
            openContact = contact
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(decorative: contact == .aidaVein ? "SaltportAidaPortrait" : "SaltportRowanPortrait")
                        .resizable().scaledToFill()
                        .frame(width: expanded ? 96 : 64, height: expanded ? 96 : 64, alignment: .top)
                        .background(Color(red: 0.08, green: 0.10, blue: 0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ChurchGold.opacity(0.45)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(contact.name).font(.system(size: 19, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                        Text(contact.role).font(.caption).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    Text(met ? "已交谈" : "交谈").font(.caption.bold())
                        .foregroundStyle(met ? .white.opacity(0.5) : ChurchGold)
                }
                if expanded {
                    ForEach(contact.lines, id: \.self) { line in
                        Text(line).font(.system(size: 15, design: .serif)).lineSpacing(4)
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(16)
            .background(Color(red: 0.035, green: 0.055, blue: 0.08).opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ChurchGold.opacity(0.35)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("与\(contact.name)交谈，\(contact.role)")
    }
}

/// Content preview of 《谁让雾港重新亮灯》 driven by a hypothetical snapshot.
/// Read-only: no investing, selling or fighting from here. Debug builds can
/// switch snapshots; that switch never touches story eligibility or saves.
struct LightsEventPreviewView: View {
    typealias P = MPCLightsEventPreview
    enum Tab: String, CaseIterable { case overview = "总览", news = "公报", ledger = "项目账", result = "结果" }

    @Environment(\.dismiss) private var dismiss
    @State private var snapshotID = Self.initialSnapshotID
    @State private var tab = Self.initialTab
    @State private var openArticle: String? = Self.initialArticle

    private static var initialSnapshotID: String {
        #if DEBUG
        if let id = UserDefaults.standard.string(forKey: "MistportLightsSnapshot"),
           P.fixtures.contains(where: { $0.id == id }) { return id }
        #endif
        return P.fixtures[0].id
    }
    private static var initialTab: Tab {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: "MistportLightsTab"),
           let tab = Tab.allCases.first(where: { "\($0)" == raw }) { return tab }
        #endif
        return .overview
    }
    private static var initialArticle: String? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: "MistportLightsArticle")
        #else
        return nil
        #endif
    }
    private var snapshot: P.Snapshot { P.fixtures.first { $0.id == snapshotID } ?? P.fixtures[0] }
    private let muted = Color.white.opacity(0.65)

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.07), Color(red: 0.07, green: 0.08, blue: 0.09)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    hypotheticalBanner
                    Picker("页面", selection: $tab) {
                        ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    switch tab {
                    case .overview: overview
                    case .news: news
                    case .ledger: ledgers
                    case .result: result
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(ChurchGold.opacity(0.7), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")
            VStack(alignment: .leading, spacing: 3) {
                Text("谁让雾港重新亮灯").font(.system(size: 24, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                    .lineLimit(1).minimumScaleFactor(0.75)
                Text("盐岸外港转运站 · 供能争端").font(.caption).foregroundStyle(muted)
            }
            Spacer(minLength: 0)
        }
    }

    private var hypotheticalBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("假设快照 · \(snapshot.phase.title)").font(.subheadline.bold()).foregroundStyle(.orange)
            Text(P.hypotheticalNotice + "事件尚未开放，本页不能投资、交货或参战。")
                .font(.caption).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
            #if DEBUG
            Menu {
                ForEach(P.fixtures) { fixture in
                    Button(fixture.label) { snapshotID = fixture.id; openArticle = nil }
                }
            } label: {
                Label("开发：切换快照 · \(snapshot.label)", systemImage: "slider.horizontal.3")
                    .font(.caption).foregroundStyle(ChurchGold).multilineTextAlignment(.leading)
            }
            #endif
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }

    // MARK: Overview

    private var newsHeader: some View {
        Image(decorative: "LightsNewsHeader")
            .resizable().scaledToFill()
            .frame(maxWidth: .infinity).frame(height: 128)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 14) {
            newsHeader
            Text("转运站只有一套主接驳装置。两家的控制配置互不兼容，三十日独占经营权只能给一家；落败方仍可经营原有业务。")
                .font(.body).foregroundStyle(.white.opacity(0.85)).lineSpacing(4)
            planCard(.pumps, lead: "工程监理 艾妲·维恩", aim: "先恢复住宅与诊所的药基处理；账册公开。",
                     cost: "分流给民用线路后，可收费的工坊服务容量较少，回本取决于需求。",
                     win: "住宅线路亮灯，诊所新增稳定工作台。")
            planCard(.shipping, lead: "护航总管 罗文·凯尔", aim: "先恢复燃料周转与工坊生产。",
                     cost: "工业先行会延后部分住宅增量供能；运输与货源中断风险较高。",
                     win: "码头吊机和炉火恢复，货船班次牌更新。")
            Text("时间表（首测候选）：准备 7 日 → 公共行动 48 小时 → 核心窗口 24 小时 → 经营 30 日。")
                .font(.footnote).foregroundStyle(muted)
            linkButton("看最新公报", .news)
        }
    }

    private func planCard(_ f: P.Faction, lead: String, aim: String, cost: String, win: String) -> some View {
        let l = snapshot.ledger(f)
        return VStack(alignment: .leading, spacing: 6) {
            Text(P.sideName(f)).font(.system(size: 19, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
            Text(lead).font(.caption).foregroundStyle(muted)
            row("主张", aim); row("代价", cost); row("胜出后", win)
            Text("快照：已筹 \(l.raised)/\(P.fundingCap) 铜 · 已安装 \(l.installedKits)/\(P.kitSlots) 处")
                .font(.caption.monospacedDigit()).foregroundStyle(.orange.opacity(0.9))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func row(_ label: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.caption.bold()).foregroundStyle(muted).frame(width: 44, alignment: .leading)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: News

    private var news: some View {
        let articles = P.articles(for: snapshot)
        return VStack(alignment: .leading, spacing: 12) {
            Text("已发布 \(articles.count)/8 篇。条件不成立的新闻不发布，只选与快照事实相符的版本。")
                .font(.caption).foregroundStyle(muted)
            ForEach(articles.reversed()) { article in
                articleCard(article)
            }
        }
    }

    private func articleCard(_ article: P.Article) -> some View {
        let open = openArticle == article.id
        return VStack(alignment: .leading, spacing: 8) {
            Button { openArticle = open ? nil : article.id } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(article.id) · \(article.day) · \(article.variant)").font(.caption).foregroundStyle(muted)
                    Text(article.headline).font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(ChurchGold).multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            if open {
                if article.id == "L01" { newsHeader }
                ForEach(article.paragraphs, id: \.self) {
                    Text($0).font(.system(size: 15, design: .serif)).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    ForEach(article.links, id: \.self) { link in
                        switch link {
                        case .plans: linkButton("比较两份计划", .overview)
                        case .ledger: linkButton("查看项目账", .ledger)
                        case .result: linkButton("看结果", .result)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func linkButton(_ title: String, _ target: Tab) -> some View {
        Button(title) { tab = target; openArticle = nil }
            .font(.footnote.bold()).foregroundStyle(ChurchGold)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .overlay(Capsule().stroke(ChurchGold.opacity(0.6)))
    }

    // MARK: Ledger

    private var ledgers: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(P.Faction.allCases, id: \.self) { ledgerCard($0) }
            Text("组具首测报价 \(P.kitPrice) 铜/套（过滤布、维修绑带、锡罐各 2 件）；单账号最多投 \(P.perAccountCap) 铜。投资是收益份额，不保本。投资与采购入口尚未开放。")
                .font(.caption).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func ledgerCard(_ f: P.Faction) -> some View {
        let l = snapshot.ledger(f)
        let showsPublic = snapshot.phase.dayIndex >= 8
        return VStack(alignment: .leading, spacing: 8) {
            Text(P.projectName(f)).font(.system(size: 18, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
            amount("已筹资金", "\(l.raised) / \(P.fundingCap) 铜 · \(l.investors) 人")
            amount("已安装", "\(l.installedKits) / \(P.kitSlots) 处 · 已花 \(l.spent) 铜")
            amount("未完成订单", "\(l.orderedKits) 套 · \(l.committed) 铜")
            amount("账上现金", "\(l.cash) 铜")
            amount("尚未下单", l.missingKits == 0 ? "无" : "\(l.missingKits) 套 · 现金可再付 \(l.fundableKits) 套")
            if showsPublic {
                amount("公共贡献", "\(l.publicScore) 点 · \(l.successfulAccounts) 个账号成功")
                amount("工程资格", l.qualified ? "已取得" : l.worksComplete ? "成功账号不足 \(P.minimumSuccessfulAccounts) 个" : "工程未完成")
            }
            Text("核对：\(l.spent) + \(l.committed) + \(l.cash) = \(l.raised) 铜")
                .font(.caption2.monospacedDigit()).foregroundStyle(muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func amount(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(muted)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit())
        }
    }

    // MARK: Result

    @ViewBuilder private var result: some View {
        if let contract = snapshot.contract {
            VStack(alignment: .leading, spacing: 12) {
                Text(contractTitle(contract)).font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                Text(P.npcResult(aidaDead: snapshot.aidaDead, rowanDead: snapshot.rowanDead)).font(.body)
                Text("公共贡献：\(P.sideName(.pumps)) \(snapshot.pumps.publicScore) 点，\(P.sideName(.shipping)) \(snapshot.shipping.publicScore) 点。")
                    .font(.subheadline).foregroundStyle(muted)
                ForEach(["我的公共行动", "我的货物去了哪里", "我的突破", "我的项目账"], id: \.self) { title in
                    amount(title, "无记录")
                }
                Text("假设快照不含你的个人记录；结算不按投资额发放胜利奖金。").font(.caption).foregroundStyle(muted)
            }
        } else {
            Text("尚未结算。合同、人物状态和个人记录在世界结算后出现；未发生的结果不会提前显示。")
                .font(.body).foregroundStyle(muted)
        }
    }

    private func contractTitle(_ contract: P.Contract) -> String {
        switch contract {
        case .awarded(let f): "\(P.sideName(f))取得三十日经营权"
        case .interim(.tie): "临时接管：公共分相同"
        case .interim(.noneQualified): "临时接管：没有合格经营者"
        case .interim(.bothDead): "临时接管：两位负责人均死亡"
        }
    }
}

/// The one real loop of the lights event on this save: side, workbench,
/// delivery, installation, one ordinary public attempt and the local result.
struct LightsLocalEventView: View {
    typealias E = MPCLightsLocalEvent
    typealias P = MPCLightsEventPreview
    @Bindable var game: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var notice = ""
    @State private var battleID: String?
    private let muted = Color.white.opacity(0.65)
    private var event: E { game.lightsEvent }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.03, green: 0.05, blue: 0.07), Color(red: 0.07, green: 0.08, blue: 0.09)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    Text(E.fixtureNotice).font(.caption).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                    step(1, "选择支持", done: event.side != nil) { sideStep }
                    step(2, "准备维修绑带", done: game.lightsStrapCount >= E.strapsPerKit || event.projectStraps > 0 || event.worksComplete) { craftStep }
                    step(3, "交货", done: !event.orderOpen) { deliverStep }
                    step(4, "安装第12套组具", done: event.worksComplete) { installStep }
                    step(5, "普通公共行动", done: event.closed) { publicStep }
                    if event.closed { resultCard }
                    if !notice.isEmpty { Text(notice).font(.footnote).foregroundStyle(.orange) }
                    if !event.entries.isEmpty { logCard }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .fullScreenCover(item: Binding(get: { battleID.map(BattleTicket.init) }, set: { battleID = $0?.id })) { ticket in
            LightsPublicBattleView(game: game, battleID: ticket.id, onClose: { battleID = nil })
        }
    }

    private struct BattleTicket: Identifiable { let id: String }

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44).background(.black.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(ChurchGold.opacity(0.7), lineWidth: 1))
            }.buttonStyle(.plain).accessibilityLabel("返回")
            VStack(alignment: .leading, spacing: 3) {
                Text("转运站检修单").font(.system(size: 24, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                Text("谁让雾港重新亮灯 · 本地一次").font(.caption).foregroundStyle(muted)
            }
            Spacer(minLength: 0)
        }
    }

    private func step<Content: View>(_ n: Int, _ title: String, done: Bool, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(n)").font(.caption.bold()).frame(width: 22, height: 22)
                    .background(done ? ChurchGold : Color.white.opacity(0.12), in: Circle())
                    .foregroundStyle(done ? .black : .white)
                Text(title).font(.system(size: 17, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                Spacer()
                if done { Image(systemName: "checkmark").foregroundStyle(ChurchGold) }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    private func action(_ title: String, enabled: Bool = true, _ run: @escaping () throws -> Void) -> some View {
        Button {
            GameInterfaceSound.shared.playClick()
            do { try run(); notice = "" } catch { notice = message(error) }
        } label: {
            Text(title).font(.subheadline.bold()).foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(ChurchGold, in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.4)
    }

    private func message(_ error: Error) -> String {
        switch error {
        case E.Failure.locked: return "先在转运站见过两位负责人，并选择支持一方。"
        case E.Failure.stock, MPCLocalWorkshopLedger.Failure.stock: return "材料不足。"
        case E.Failure.funds, MPCLocalWorkshopLedger.Failure.funds: return "铜币不足。"
        case E.Failure.order: return "这张订单已经收满。"
        case E.Failure.attempted: return "本存档的公共行动尝试已经用过。"
        default: return "操作未完成，钱物没有变化。"
        }
    }

    @ViewBuilder private var sideStep: some View {
        if let side = event.side {
            Text("已支持\(P.sideName(side))。立场在本次事件内锁定。").font(.subheadline).foregroundStyle(muted)
        } else {
            Text("免费支持，不收报名费，也不发工资。选定后本次事件不能更换。").font(.subheadline).foregroundStyle(muted)
            HStack(spacing: 10) {
                action("泵站联合会") { try game.chooseLightsSide(.pumps) }
                action("灰帆联营") { try game.chooseLightsSide(.shipping) }
            }
        }
    }

    @ViewBuilder private var craftStep: some View {
        Text("工作台配方：1 份盾颚韧皮 + 13 铜 → 3 条维修绑带。韧皮来自教会塔第 1 层的新一场胜利。")
            .font(.subheadline).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
        Text("持有：韧皮 \(game.lightsHideCount) · 绑带 \(game.lightsStrapCount) · 铜币 \(game.venueCoins)")
            .font(.subheadline.monospacedDigit())
        if !event.worksComplete {
            action("制作一批 · 13 铜", enabled: event.side != nil && game.lightsHideCount > 0) { try game.craftStrapsAtStation() }
        }
    }

    @ViewBuilder private var deliverStep: some View {
        if event.orderOpen {
            Text("\(event.side.map(P.projectName) ?? "项目")还收 \(E.strapsPerKit) 条绑带，每条 \(E.strapPrice) 铜；项目账上还有 \(event.projectCash) 铜。")
                .font(.subheadline).foregroundStyle(muted)
            action("交 \(E.strapsPerKit) 条 · 收 \(E.orderBudget) 铜", enabled: event.side != nil && game.lightsStrapCount >= E.strapsPerKit) {
                try game.deliverLightsStraps()
            }
        } else {
            Text("订单已收满，不再收货。多出的绑带仍在你的背包里。").font(.subheadline).foregroundStyle(muted)
        }
    }

    @ViewBuilder private var installStep: some View {
        Text("工程 \(event.installedKits)/\(P.kitSlots)。绑带与已入库的过滤布、锡罐组成组具，装上后就是设施的一部分。")
            .font(.subheadline).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
        if !event.worksComplete {
            action("安装", enabled: event.projectStraps == E.strapsPerKit) { try game.installLightsKit() }
        }
    }

    @ViewBuilder private var publicStep: some View {
        if let side = event.side {
            Text("\(MPCLightsPublicTarget.title(side))：一场普通战斗。本存档只有一次有效尝试，失败或撤退也会用掉。胜利记 1 点公共贡献。")
                .font(.subheadline).foregroundStyle(muted).fixedSize(horizontal: false, vertical: true)
        }
        if event.closed {
            Text(event.publicWon ? "已完成：胜利，记 1 点。" : "已完成：未胜利，不记贡献。").font(.subheadline)
        } else if let pending = event.activeTicket {
            action("放弃未结的公共行动") { game.abandonLightsPublic(battleID: pending, defeated: false) }
        } else {
            action("进入战斗", enabled: event.worksComplete) { battleID = UUID().uuidString }
        }
    }

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本地结果").font(.caption.bold()).foregroundStyle(muted)
            Text(contractTitle).font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
            ForEach(E.Faction.allCases, id: \.self) { f in
                let l = event.ledger(f)
                HStack {
                    Text(P.sideName(f) + (f == event.side ? "（本方）" : "")).font(.subheadline)
                    Spacer()
                    Text("\(l.publicScore) 点 · \(l.successfulAccounts) 账号 · 工程 \(l.installedKits)/12 · \(l.qualified ? "有资格" : "无资格")")
                        .font(.caption.monospacedDigit()).foregroundStyle(muted)
                }
            }
            Text("两位负责人均存活；核心人物战尚未开放。结果不发胜利奖金。").font(.caption).foregroundStyle(muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ChurchGold.opacity(0.5)))
    }

    private var contractTitle: String {
        switch event.contract {
        case .awarded(let f)?: return "\(P.sideName(f))取得三十日经营权"
        case .interim?: return "临时接管"
        case nil: return "待结算"
        }
    }

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("回执").font(.caption.bold()).foregroundStyle(muted)
            ForEach(Array(event.entries.enumerated()), id: \.offset) { _, entry in
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.text).font(.caption).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if entry.playerCopperDelta != 0 {
                        Text("\(entry.playerCopperDelta > 0 ? "+" : "")\(entry.playerCopperDelta) 铜").font(.caption.monospacedDigit()).foregroundStyle(ChurchGold)
                    }
                }
            }
        }
    }
}

/// Ordinary public battle, run through the shipped church-maintenance presentation.
struct LightsPublicBattleView: View {
    @Bindable var game: GameStore
    let battleID: String
    let onClose: () -> Void
    @State private var started = false
    @State private var finished = false
    @State private var won = false
    @State private var skills: [FoolSkillID] = []
    @State private var reordered = true
    @State private var configuredSession: MPCChapterOneEncounterSession?
    @State private var previewSession: MPCChapterOneEncounterSession?
    @State private var startError = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let initial = configuredSession ?? previewSession {
                ChapterOneEncounterTestView(initialSession: initial,
                    campaign: game.churchBattleCampaign, playerSequence: game.currentSequence,
                    battleIsActive: started, automatesSkillSequence: true,
                    showsStandaloneOpeningBattleButton: false,
                    onVictory: { result in
                        guard !finished else { return }
                        game.settleLightsPublic(battleID: battleID, session: result)
                        won = true; finished = true
                    }, onExit: {
                        if started && !finished { game.abandonLightsPublic(battleID: battleID, defeated: false) }
                        onClose()
                    },
                    onDefeat: {
                        guard !finished else { return }
                        game.abandonLightsPublic(battleID: battleID, defeated: true)
                        finished = true
                    },
                    onRetrySetup: { onClose() },
                    onSequenceChanged: { skills = $0 },
                    onSelectActiveRelic: game.selectCampaignActiveRelic,
                    onSelectPassiveRelic: game.toggleCampaignRelic,
                    onUseManualMask: { game.recordManualMaskUse(encounterID: initial.encounter.id) },
                    onConsumeSupply: game.consumeCampaignSupply)
            }
            if !started && !finished {
                ChapterOneBattleSetupOverlay(
                    availableSkills: MPCChapterOneCatalog.visibleSkills.filter {
                        game.chapterOneCampaign.unlockedSkillIDs.contains($0.id) && $0.id != .maskedWhisper
                    }, relics: [], selectedSkillIDs: $skills,
                    requiresFirstReorder: false, slotCapacity: game.chapterOneLoadoutSlotCapacity,
                    hasCompletedFirstReorder: $reordered, usesEarlyTutorialLayout: true,
                    showsStartTutorialHint: false,
                    onStart: {
                        game.saveChapterOneBattleLoadout(skills)
                        do {
                            configuredSession = try game.beginLightsPublic(battleID: battleID, skills: skills)
                            started = true
                        } catch { startError = "无法开始：本存档的公共行动尝试可能已用过。" }
                    })
                if !startError.isEmpty { Text(startError).foregroundStyle(.orange) }
            }
            if finished {
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text(won ? "阻碍已解除" : "行动未完成").font(.title.bold()).foregroundStyle(won ? .yellow : .orange)
                    Text(won ? "记 1 点公共贡献。" : "本次尝试已用掉，不记贡献。")
                    ChurchActionButton(title: "返回检修单") { onClose() }
                }
                .foregroundStyle(.white).padding(24)
            }
        }
        .preferredColorScheme(.dark).buttonStyle(.plain)
        .task { if previewSession == nil { previewSession = try? game.lightsPublicPreview(battleID: battleID) } }
    }
}
