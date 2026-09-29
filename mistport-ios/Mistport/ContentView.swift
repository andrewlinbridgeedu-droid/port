import MistportCombatCore
import SwiftUI
import UIKit

private enum AppSheet: String, Identifiable {
    case settings
    case store
    case church
    case world
    case expedition
    case missions
    case profile
    case build
    case workshop
    case advancement
    case inventory

    var id: String { rawValue }
}

struct ContentView: View {
    @Bindable var game: GameStore
    @Bindable var storefront: Storefront
    @State private var blackSaltShorePresented = ProcessInfo.processInfo.arguments.contains("--preview-black-salt-shore")
    @State private var churchPresented = (ProcessInfo.processInfo.arguments.contains("--preview-church") || ProcessInfo.processInfo.arguments.contains("--verify-church-entry"))
    @State private var tavernBountyPresented = false
    @State private var presentedSheet: AppSheet? = {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--preview-missions") { return .missions }
        if arguments.contains("--preview-build") { return .build }
        if arguments.contains("--preview-advancement") { return .advancement }
        if arguments.contains("--preview-inventory") { return .inventory }
        if arguments.contains("--preview-store") { return .store }
        return nil
    }()
    @State private var isProfilePresented = ProcessInfo.processInfo.arguments.contains("--preview-talents")
        || ProcessInfo.processInfo.arguments.contains("--preview-profile")
        || ProcessInfo.processInfo.arguments.contains("--preview-relics")
        || ProcessInfo.processInfo.arguments.contains("--preview-outfit-starlight")
        || ProcessInfo.processInfo.arguments.contains("--preview-outfit-carnival")
    @State private var isVenuePresented = ProcessInfo.processInfo.arguments.contains("--preview-venue")
        || ProcessInfo.processInfo.arguments.contains("--preview-venue-rare")
        || ProcessInfo.processInfo.arguments.contains("--preview-venue-restaurant")
    @State private var isTurnBasedBattlePresented = ProcessInfo.processInfo.arguments.contains("--preview-turn-battle")
    #if DEBUG
    @State private var isDeveloperTestPanelPresented = false
    #endif
    @State private var isRevealingPathSelection = false
    @State private var isLaunchLoading = false
    @State private var launchLoadingProgress = 0.0
    @State private var launchLoadingMessage = "雾门响应中"
    @AppStorage(HomeMusicController.isEnabledKey, store: .standard) private var musicEnabled = true

    private var isDirectChapterOnePreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains { argument in
            argument == "--preview-chapter-one" || argument.hasPrefix("--preview-chapter-one-")
        }
        #else
        false
        #endif
    }

    private var isGoddessDialoguePreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--preview-chapter-one-goddess-dialogue")
        #else
        false
        #endif
    }

    var body: some View {
        if isGoddessDialoguePreview {
            ChapterOneTutorialOverlay(cue: .firstBattle) {}
        } else if isDirectChapterOnePreview {
            ChapterOneTestView()
        } else {
            standardContent
        }
    }

    private var standardContent: some View {
        ZStack {
            if game.phase == .dungeon {
                Color.black.ignoresSafeArea()
            } else {
                MistBackground(
                    tint: game.phase == .title
                        ? Color(red: 0.82, green: 0.61, blue: 0.22)
                        : (game.selectedPath?.tint ?? .purple),
                    showsDriftingMist: game.phase == .title
                )
            }

            Group {
                switch game.phase {
                case .title:
                    TitleView(onBegin: game.begin)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                case .pathSelection:
                    PathSelectionView(
                        onSelect: { path, gender in game.select(path, gender: gender) },
                        onBack: game.restart
                    )
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .allowsHitTesting(
                            game.hasSeenChapterOneTutorial(.opening) && !isRevealingPathSelection
                        )
                case .cityHub:
                    CityHubView(
                        path: game.selectedPath,
                        sequence: game.displayedSequence,
                        districtName: game.selectedChapterDistrict.name,
                        nextMissionTitle: game.nextChapterMission.map { game.missionLockText($0) ?? $0.title } ?? "本次调查已完成 · 可重访",
                        missionProgress: game.completedMissionCount(in: game.selectedChapterDistrict),
                        reputation: game.reputation(in: game.selectedChapterDistrict),
                        coins: game.venueCoins,
                        materials: game.materials,
                        clues: game.clues,
                        ingredientCount: game.advancementIngredients.count,
                        serviceIsUnlocked: game.cityServiceIsUnlocked,
                        cafeUnlocked: game.venueIsUnlocked("midnight-clock-cafe"),
                        onSettings: { GameInterfaceSound.shared.playClick(); presentedSheet = .settings },
                        onTest: cityTestAction,
                        onStory: game.enterDistrictMap,
                        onWorld: { presentedSheet = .world },
                        onExpedition: { presentedSheet = .expedition },
                        onStore: { if game.cityServiceIsUnlocked(.store) { presentedSheet = .store } },
                        onChurch: { if game.cityServiceIsUnlocked(.church) { churchPresented = true } },
                        onBountyTavern: {
                            if game.selectedPathID == .fool && game.cityServiceIsUnlocked(.church) {
                                tavernBountyPresented = true
                            }
                        },
                        onProfile: { isProfilePresented = true },
                        onBuild: { presentedSheet = .workshop },
                        onAdvancement: { presentedSheet = .advancement },
                        onSupply: {
                            guard game.venueIsUnlocked("midnight-clock-cafe") else { return }
                            game.prepareVenue("midnight-clock-cafe")
                            isVenuePresented = true
                        },
                        onInventory: { presentedSheet = .inventory },
                        onEnterVenue: { venueID in
                            guard game.venueIsUnlocked(venueID) else { return }
                            game.prepareVenue(venueID)
                            isVenuePresented = true
                        },
                        blackSaltShore: game.churchHasDepartedMistport ? (
                            status: !game.sequenceEightQualified ? "先举行序列 8 仪式"
                                : game.chapterTwoBridge.worldEventStoryReady ? "已见过两家负责人 · 可重访" : "两家负责人在站内等候",
                            action: { blackSaltShorePresented = true }
                        ) : nil
                    )
                case .districtMap:
                    // Legacy entry/debug routes bypass the removed street page too.
                    Color.black.ignoresSafeArea()
                        .task { game.enterDistrictMap() }
                case .dungeon:
                    if game.selectedPathID == .fool,
                       game.activeChapterMission != nil {
                        ChapterOneMissionBridgeView(game: game)
                            // Every mission owns an independent entrance/setup/
                            // combat state machine. SwiftUI otherwise reuses the
                            // bridge when only activeChapterMission changes,
                            // leaking the previous mission's session and
                            // battleHasStarted flag into the next encounter.
                            .id("\(game.activeChapterMission?.districtID ?? "none")-\(game.activeChapterMission?.number ?? -1)")
                    } else {
                        DungeonPrototypeView(
                            path: game.selectedPath,
                            mission: game.activeChapterMission,
                            combatPower: game.combatPower,
                            playerSequence: game.currentSequence,
                            configuredSkills: game.configuredDungeonSkills,
                            isFirstClear: game.activeChapterMission.map { !game.missionIsCompleted($0) } ?? true,
                            coinReward: game.activeChapterMission.map {
                                game.missionCoinReward(for: $0, firstClear: !game.missionIsCompleted($0))
                            } ?? 60,
                            materialReward: game.activeChapterMission.map {
                                game.missionMaterialReward(for: $0, firstClear: !game.missionIsCompleted($0))
                            } ?? 2,
                            equippedRelicIDs: MPCChapterOneCatalog.relicsEnabled ? [game.equippedWeaponID, game.equippedSecondaryRelicID] : [],
                            onExit: game.returnToCity,
                            onVictory: game.completeDungeon
                        )
                    }
                case .adventure:
                    AdventureView(game: game, onExit: game.returnToCity)
                case .ritual:
                    RitualView(game: game)
                case .ending(let success):
                    EndingView(success: success, path: game.selectedPath, onRestart: game.restart, onStore: { presentedSheet = .store })
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
            }

            if game.phase == .title {
                DriftingMist()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                VStack {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        #if DEBUG
                        if game.permitsDeveloperTools { developerTestButton }
                        #endif
                        musicToggle
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
                .padding(.trailing, 14)
                .zIndex(30)

                GeometryReader { geometry in
                    TitleGateButton(action: beginLaunchLoading)
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height * 0.69
                        )
                }
                .zIndex(10)
            }

            #if DEBUG
            if game.phase != .title,
               game.phase != .cityHub,
               game.phase != .dungeon,
               !isLaunchLoading {
                VStack {
                    HStack {
                        Spacer(minLength: 0)
                        if game.permitsDeveloperTools { developerTestButton }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 10)
                .padding(.trailing, 14)
                .zIndex(30)
            }
            #endif

            if let receipt = game.recoveredMissionReward {
                ChapterOneVictoryReceiptView(title: "已恢复战后奖励", receipt: receipt, skillIDs: []) {
                    game.finishRecoveredMissionReward()
                }.zIndex(500)
            }

            if isLaunchLoading {
                MistportLaunchLoadingView(
                    progress: launchLoadingProgress,
                    message: launchLoadingMessage
                )
                .transition(.opacity)
                .zIndex(100)
            }

            if game.phase == .pathSelection,
               !game.hasSeenChapterOneTutorial(.opening) {
                ChapterOneTutorialOverlay(cue: .opening) {
                    game.completeChapterOneTutorial(.opening)
                    isRevealingPathSelection = true
                }
                .zIndex(20)
            }

            if game.phase == .pathSelection, isRevealingPathSelection {
                PathSelectionMistReveal {
                    isRevealingPathSelection = false
                }
                .zIndex(21)
            }

            if game.phase == .cityHub,
               game.selectedPathID == .fool,
               !game.hasSeenChapterOneTutorial(.cityMission) {
                ChapterOneTutorialOverlay(cue: .cityMission) {
                    game.completeChapterOneTutorial(.cityMission)
                    game.enterDistrictMap()
                }
                .zIndex(20)
            }
        }
        .onAppear {
            HomeMusicController.shared.update(for: game.phase)
        }
        .onChange(of: game.phase) { _, phase in
            HomeMusicController.shared.update(for: phase)
        }
        .fullScreenCover(isPresented: $churchPresented) { ChurchSanctuaryView(game: game) }
        .fullScreenCover(isPresented: $blackSaltShorePresented) { BlackSaltShoreView(game: game) }
        .fullScreenCover(isPresented: $tavernBountyPresented) {
            TavernInteriorView(game: game, onBack: { tavernBountyPresented = false })
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .settings:
                GameSettingsView()
            case .store:
                if game.cityServiceIsUnlocked(.store) {
                    StoreView(storefront: storefront)
                } else {
                    Text("商店尚未开放 · 随主线推进解锁").padding()
                }
            case .church:
                if game.cityServiceIsUnlocked(.church) {
                    ChurchSanctuaryView(game: game)
                } else {
                    Text("教会尚未开放 · 随主线推进解锁").padding()
                }
            case .workshop:
                LocalWorkshopView(game: game)
            case .world:
                WorldRouteView()
            case .expedition:
                ExpeditionBoardView(
                    selectedPath: game.selectedPath,
                    expedition: game.currentTeamExpedition,
                    isUnlocked: game.teamExpeditionIsUnlocked(in: game.selectedChapterDistrict),
                    completedMissionCount: game.completedMissionCount(in: game.selectedChapterDistrict),
                    onEnter: {
                        game.beginTeamExpedition()
                        presentedSheet = nil
                    }
                )
            case .missions:
                MissionBoardView(
                    game: game,
                    onOpenExpedition: { presentedSheet = .expedition }
                )
            case .profile:
                EmptyView()
            case .build:
                CharacterProfileView(game: game)
            case .advancement:
                HubFeatureView(kind: .advancement, game: game)
            case .inventory:
                HubFeatureView(kind: .inventory, game: game)
            }
        }
        #if DEBUG
        .sheet(isPresented: $isDeveloperTestPanelPresented) {
            DeveloperTestPanel(game: game)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        #endif
        .fullScreenCover(isPresented: $isProfilePresented) {
            CharacterProfileView(game: game)
        }
        .fullScreenCover(isPresented: $isVenuePresented) {
            if let venue = game.activeVenue, game.venueIsUnlocked(venue.id) {
                VenueView(game: game, venue: venue)
            } else {
                VStack(spacing: 20) {
                    Text("场所尚未开放 · 随主线推进解锁")
                    Button("返回") { isVenuePresented = false }
                }
            }
        }
        .fullScreenCover(isPresented: $isTurnBasedBattlePresented) {
            TurnBasedBattleView {
                isTurnBasedBattlePresented = false
            }
        }
    }

    private var cityTestAction: (() -> Void)? {
        #if DEBUG
        return game.permitsDeveloperTools ? { GameInterfaceSound.shared.playClick(); isDeveloperTestPanelPresented = true } : nil
        #else
        return nil
        #endif
    }

    private var musicToggle: some View {
        Button {
            musicEnabled.toggle()
            HomeMusicController.shared.setEnabled(musicEnabled, for: game.phase)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: musicEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 11, weight: .bold))

                ZStack(alignment: musicEnabled ? .trailing : .leading) {
                    Capsule()
                        .fill(.white.opacity(0.20))
                        .frame(width: 34, height: 18)
                    Circle()
                        .fill(musicEnabled ? Color(red: 1.0, green: 0.80, blue: 0.30) : .white.opacity(0.62))
                        .frame(width: 14, height: 14)
                        .padding(2)
                }
            }
            .foregroundStyle(.white.opacity(0.92))
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(.black.opacity(0.30), in: Capsule())
            .overlay {
                Capsule().stroke(.white.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("音乐开关")
        .accessibilityValue(musicEnabled ? "已开启" : "已关闭")
        .accessibilityHint("左右拨动以关闭或开启主页音乐")
    }

    #if DEBUG
    private var developerTestButton: some View {
        Button {
            isDeveloperTestPanelPresented = true
        } label: {
            Label("测试", systemImage: "wrench.and.screwdriver.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .padding(.horizontal, 9)
                .frame(height: 30)
                .background(.black.opacity(0.30), in: Capsule())
                .overlay {
                    Capsule().stroke(.yellow.opacity(0.42), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("开发者测试台")
        .accessibilityHint("选择章节关卡并进入真机测试")
    }
    #endif

    private func beginLaunchLoading() {
        guard !isLaunchLoading else { return }
        isLaunchLoading = true
        launchLoadingProgress = 0.02
        launchLoadingMessage = "雾门响应中"

        Task { @MainActor in
            await Task.yield()
            await LaunchAssetPreloader.preload { progress, message in
                withAnimation(.easeOut(duration: 0.22)) {
                    launchLoadingProgress = progress
                }
                launchLoadingMessage = message
            }

            launchLoadingMessage = "编织首场战局"
            game.prepareInitialChapterOneMission()
            withAnimation(.easeOut(duration: 0.2)) {
                launchLoadingProgress = 0.78
            }
            await Task.yield()

            launchLoadingMessage = "唤醒战斗舞台"
            UnityBattleRuntime.shared.preload()
            withAnimation(.easeOut(duration: 0.24)) {
                launchLoadingProgress = 1
            }
            launchLoadingMessage = "钟门已开启"
            try? await Task.sleep(for: .milliseconds(320))
            game.begin()
            withAnimation(.easeOut(duration: 0.22)) {
                isLaunchLoading = false
            }
        }
    }
}

@MainActor
private enum LaunchAssetPreloader {
    private static var retainedImages: [UIImage] = []

    private static let groups: [(progress: Double, message: String, names: [String])] = [
        (0.18, "解封途径档案", [
            "TitleArcanaEmblem", "PathFoolFemale", "PathFoolMale",
            "PathPriestessFemale", "PathPriestessMale", "PathChariotFemale", "PathChariotMale",
            "GuideMiriel", "PortraitMaraGrey"
        ]),
        (0.36, "点亮雾港城区", [
            "MistportCityHub", "MistportCityPanorama", "MistportWorldMap",
            "OldClockSquareTileV1", "FoglampStreetTileV1", "GearWorksTileV1",
            "RainwaterDrainsTileV1", "MirrorTideManorTileV1"
        ]),
        (0.56, "载入旧城区战场", [
            "SceneClockDistrictV2", "FoolCombatTopDownV3", "ClockGuardCurrent3DPreview",
            "HellHoundIdle", "MemoryParasiteNodeVertical", "BattleDefeatEmblem"
        ]),
        (0.68, "预热秘仪与光效", [
            "FoolSkillVFXAtlas", "FoolTarotVFXAtlas",
            "IconSkillWeakness", "IconSkillSpiritualDodge", "IconSkillDivination"
        ])
    ]

    static func preload(
        onProgress: (_ progress: Double, _ message: String) -> Void
    ) async {
        if !retainedImages.isEmpty {
            onProgress(0.68, "资源已就绪")
            return
        }

        for group in groups {
            onProgress(group.progress - 0.08, group.message)
            await Task.yield()
            for name in group.names {
                guard let image = UIImage(named: name) else { continue }
                retainedImages.append(image.preparingForDisplay() ?? image)
            }
            onProgress(group.progress, group.message)
            await Task.yield()
        }
    }
}

#if DEBUG
private struct DeveloperTestPanel: View {
    @Bindable var game: GameStore
    @Environment(\.dismiss) private var dismiss

    private var missions: [DistrictMission] {
        (GameContent.chapterOneDistricts.first(where: { $0.id == "old-clock" })?.missions ?? []).filter { $0.number <= GameStore.playerTestMissionLimit }
    }

    var body: some View {
        NavigationStack {
            List(missions) { mission in
                Button {
                    game.debugJumpToOldClockMission(mission.number, enterImmediately: true)
                    dismiss()
                } label: {
                    HStack {
                        Text("第\(mission.number)关 · \(mission.title)")
                            .foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .accessibilityLabel("进入第\(mission.number)关 · \(mission.title)")
                .listRowBackground(Color.white.opacity(0.06))
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.025, green: 0.03, blue: 0.07))
            .navigationTitle("关卡列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#endif

private struct MistportLaunchLoadingView: View {
    let progress: Double
    let message: String
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reduceMotion = false
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    private let gold = Color(red: 0.88, green: 0.69, blue: 0.36)
    private var fraction: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            Color(red: 0.018, green: 0.014, blue: 0.035).opacity(0.98).ignoresSafeArea()
            RadialGradient(colors: [Color.purple.opacity(0.13), .clear], center: .center,
                           startRadius: 10, endRadius: 260).ignoresSafeArea()
            VStack(spacing: 26) {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || accessibilityReduceMotion)) { timeline in
                    let time = reduceMotion || accessibilityReduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Circle().fill(RadialGradient(colors: [.purple.opacity(0.24), .clear], center: .center, startRadius: 12, endRadius: 88))
                        astrolabe(time: time)
                        Image("TitleArcanaEmblem")
                            .resizable().scaledToFit().frame(width: 86, height: 86)
                            .shadow(color: gold.opacity(0.22), radius: 8)
                            .shadow(color: .purple.opacity(0.45), radius: 19)
                    }
                }
                .frame(width: 184, height: 184)
                .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("雾港启封")
                        .font(.system(size: 28, weight: .black, design: .serif)).tracking(3)
                        .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.96, blue: 0.82), gold], startPoint: .top, endPoint: .bottom))
                        .shadow(color: gold.opacity(0.18), radius: 12)
                    Text(message)
                        .font(.system(size: 12, weight: .medium, design: .serif)).tracking(2)
                        .foregroundStyle(Color(red: 0.72, green: 0.68, blue: 0.64))
                }

                VStack(spacing: 12) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || accessibilityReduceMotion || fraction >= 1)) { timeline in
                        let time = reduceMotion || accessibilityReduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                        progressTrack(time: time)
                    }
                    .frame(height: 22)
                    HStack(spacing: 10) {
                        Rectangle().fill(gold.opacity(0.24)).frame(width: 25, height: 0.5)
                        Text("\(Int(fraction * 100))%")
                            .font(.system(size: 11, weight: .semibold, design: .serif).monospacedDigit())
                            .tracking(2).foregroundStyle(gold.opacity(0.85))
                        Rectangle().fill(gold.opacity(0.24)).frame(width: 25, height: 0.5)
                    }
                }
                .frame(maxWidth: 280)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("载入进度")
                .accessibilityValue("\(Int(fraction * 100))%")
            }
            .padding(.horizontal, 32)
        }
        .allowsHitTesting(true)
    }

    private func astrolabe(time: Double) -> some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            func point(_ radius: Double, _ angle: Double) -> CGPoint {
                CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            }
            let metal = Gradient(colors: [Color(red: 0.28, green: 0.19, blue: 0.09), gold, Color(red: 1, green: 0.94, blue: 0.70), gold.opacity(0.5)])
            let shading = GraphicsContext.Shading.linearGradient(metal, startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height))
            for radius in [86.0, 82.0, 68.0, 57.0] {
                let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                context.stroke(ring, with: shading, lineWidth: radius == 82 ? 1.5 : 0.65)
            }
            for i in 0..<60 {
                let angle = Double(i) * .pi / 30 - .pi / 2
                var tick = Path()
                tick.move(to: point(i % 5 == 0 ? 71 : 75, angle))
                tick.addLine(to: point(79, angle))
                context.stroke(tick, with: .color(gold.opacity(i % 5 == 0 ? 0.9 : 0.32)), lineWidth: i % 5 == 0 ? 1.6 : 0.65)
            }
            // Counter-moving inset arcs, distinct from the stationary engraved dial.
            for i in 0..<3 {
                let start = time * (i == 1 ? -0.23 : 0.34) + Double(i) * 2.1
                let radius = i == 1 ? 62.0 : 89.0
                var arc = Path()
                arc.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(start + 0.85), clockwise: false)
                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: 3))
                    glow.stroke(arc, with: .color((i == 1 ? Color.purple : gold).opacity(0.65)), lineWidth: 3)
                }
                context.stroke(arc, with: .color(i == 1 ? Color(red: 0.78, green: 0.58, blue: 1) : Color(red: 1, green: 0.9, blue: 0.62)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                context.fill(diamond(at: point(radius, start + 0.85), width: 3, height: 3), with: .color(.white.opacity(0.9)))
            }
            for i in 0..<4 {
                let position = point(83, Double(i) * .pi / 2)
                context.fill(diamond(at: position, width: 3, height: 6), with: shading)
            }
        }
    }

    private func progressTrack(time: Double) -> some View {
        Canvas { context, size in
            let left = 10.0, width = max(0, size.width - 20), y = size.height / 2
            let frame = CGRect(x: left, y: y - 5, width: width, height: 10)
            let metal = GraphicsContext.Shading.linearGradient(Gradient(colors: [gold.opacity(0.35), Color(red: 1, green: 0.91, blue: 0.65), gold.opacity(0.4)]), startPoint: CGPoint(x: 0, y: y - 5), endPoint: CGPoint(x: 0, y: y + 5))
            context.fill(Path(roundedRect: frame, cornerRadius: 2), with: .color(Color(red: 0.035, green: 0.02, blue: 0.07)))
            context.stroke(Path(roundedRect: frame, cornerRadius: 2), with: metal, lineWidth: 0.8)
            let fillWidth = max(0, (width - 4) * fraction)
            let fill = Path(roundedRect: CGRect(x: left + 2, y: y - 3, width: fillWidth, height: 6), cornerRadius: 1)
            context.drawLayer { glow in
                glow.addFilter(.blur(radius: 5))
                glow.fill(fill, with: .color(.purple.opacity(0.5)))
            }
            context.fill(fill, with: .linearGradient(Gradient(colors: [Color(red: 0.29, green: 0.12, blue: 0.53), Color(red: 0.70, green: 0.40, blue: 0.88), gold, Color(red: 1, green: 0.91, blue: 0.62)]), startPoint: CGPoint(x: left, y: y), endPoint: CGPoint(x: left + max(1, fillWidth), y: y)))
            context.drawLayer { shine in
                shine.clip(to: fill)
                let x = left + (time * 45).truncatingRemainder(dividingBy: width + 50) - 25
                shine.fill(Path(CGRect(x: x, y: y - 3, width: 30, height: 6)), with: .linearGradient(Gradient(colors: [.clear, .white.opacity(0.5), .clear]), startPoint: CGPoint(x: x, y: y), endPoint: CGPoint(x: x + 30, y: y)))
            }
            for side in [left - 3, left + width + 3] {
                context.fill(diamond(at: CGPoint(x: side, y: y), width: 5, height: 5), with: metal)
                context.fill(diamond(at: CGPoint(x: side, y: y), width: 2, height: 2), with: .color(Color(red: 0.27, green: 0.12, blue: 0.39)))
            }
            if fraction > 0 {
                let tip = CGPoint(x: left + 2 + fillWidth, y: y)
                context.drawLayer { glow in
                    glow.addFilter(.blur(radius: 3))
                    glow.fill(diamond(at: tip, width: 3, height: 6), with: .color(gold))
                }
                context.fill(diamond(at: tip, width: 1.5, height: 4), with: .color(Color(red: 1, green: 0.96, blue: 0.80)))
            }
        }
    }

    private func diamond(at point: CGPoint, width: Double, height: Double) -> Path {
        Path { path in
            path.move(to: CGPoint(x: point.x, y: point.y - height))
            path.addLine(to: CGPoint(x: point.x + width, y: point.y))
            path.addLine(to: CGPoint(x: point.x, y: point.y + height))
            path.addLine(to: CGPoint(x: point.x - width, y: point.y))
            path.closeSubpath()
        }
    }
}

#if DEBUG
#Preview {
    ContentView(game: GameStore(), storefront: Storefront())
}
#endif
