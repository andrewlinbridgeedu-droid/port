import SwiftUI
import MistportCombatCore
import WebKit

struct ChapterStageMapView: View {
    @Bindable var game: GameStore
    let onExit: () -> Void
    let onEnterVenue: (String) -> Void

    @State private var selectedMissionID: String?
    @State private var runnerNumber = 0
    @State private var isRunnerMoving = false

    private let mapHeight: CGFloat = 2_180

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ZStack(alignment: .bottom) {
                    ScrollView(.vertical) {
                        stageCanvas(width: geometry.size.width)
                            .frame(width: geometry.size.width, height: mapHeight)
                    }
                    .scrollIndicators(.hidden)
                    .defaultScrollAnchor(.bottom)
                    .onAppear {
                        runnerNumber = game.completedMissionCount(in: game.selectedChapterDistrict)
                        selectedMissionID = game.nextChapterMission?.id
                        scrollToCurrent(using: proxy)
                    }
                    .onChange(of: game.selectedChapterDistrict.id) {
                        runnerNumber = game.completedMissionCount(in: game.selectedChapterDistrict)
                        selectedMissionID = game.nextChapterMission?.id
                        scrollToCurrent(using: proxy)
                    }

                    VStack(spacing: 0) {
                        StageMapHeader(game: game, onExit: onExit)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .allowsHitTesting(true)

                    if let selectedMission {
                        StageMissionDock(
                            mission: selectedMission,
                            isCompleted: game.missionIsCompleted(selectedMission),
                            isMoving: isRunnerMoving,
                            onChallenge: { travel(to: selectedMission) }
                        )
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .background(Color(red: 0.02, green: 0.04, blue: 0.10))
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    private var selectedMission: DistrictMission? {
        guard let selectedMissionID else { return nil }
        return game.playerTestMissions.first { $0.id == selectedMissionID }
    }

    private func stageCanvas(width: CGFloat) -> some View {
        ZStack {
            mapBackdrop(width: width)

            LinearGradient(
                colors: [.black.opacity(0.28), .clear, .black.opacity(0.24)],
                startPoint: .top,
                endPoint: .bottom
            )

            StageRouteLine(points: (0...20).map { routePoint(for: $0, width: width) })

            ForEach(game.playerTestMissions) { mission in
                StageMapNode(
                    mission: mission,
                    isCompleted: game.missionIsCompleted(mission),
                    isAvailable: game.missionIsAvailable(mission),
                    isSelected: selectedMissionID == mission.id,
                    action: { selectedMissionID = mission.id }
                )
                .id(mission.id)
                .position(routePoint(for: mission.number, width: width))
            }

            StageVenueSign(
                title: "午夜钟咖啡馆",
                symbol: "cup.and.saucer.fill",
                tint: .orange,
                action: { onEnterVenue("midnight-clock-cafe") }
            )
            .position(x: width * 0.75, y: 1_770)

            StageVenueSign(
                title: "铜匙餐厅",
                symbol: "fork.knife",
                tint: .purple,
                action: { onEnterVenue("copper-key-restaurant") }
            )
            .position(x: width * 0.22, y: 840)

            StageRunnerToken(isMoving: isRunnerMoving)
                .position(routePoint(for: runnerNumber, width: width))
                .animation(.linear(duration: travelDuration), value: runnerNumber)
        }
    }

    private func mapBackdrop(width: CGFloat) -> some View {
        let baseArt = [
            "MirrorTideManorTileV1",
            "RainwaterDrainsTileV1",
            "GearWorksTileV1",
            "FoglampStreetTileV1",
            "OldClockSquareTileV1"
        ]
        let shift = max(0, game.selectedChapterDistrict.order - 1) % baseArt.count
        let art = Array(baseArt[shift...] + baseArt[..<shift])

        return VStack(spacing: 0) {
            ForEach(Array(art.enumerated()), id: \.offset) { _, name in
                Image(decorative: name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: mapHeight / 5)
                    .clipped()
            }
        }
        .frame(width: width, height: mapHeight)
    }

    private var travelDuration: TimeInterval {
        guard let selectedMission else { return 0.7 }
        return min(1.6, 0.55 + Double(abs(selectedMission.number - runnerNumber)) * 0.10)
    }

    private func routePoint(for number: Int, width: CGFloat) -> CGPoint {
        let lanes: [CGFloat] = [0.20, 0.42, 0.70, 0.54, 0.28, 0.62]
        let lane = lanes[max(0, number) % lanes.count]
        return CGPoint(
            x: width * lane,
            y: mapHeight - 95 - CGFloat(number) * 96
        )
    }

    private func travel(to mission: DistrictMission) {
        guard game.missionIsAvailable(mission), !isRunnerMoving else { return }
        isRunnerMoving = true
        let duration = travelDuration
        runnerNumber = mission.number

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            isRunnerMoving = false
            game.beginMission(mission)
        }
    }

    private func scrollToCurrent(using proxy: ScrollViewProxy) {
        guard let mission = game.nextChapterMission ?? game.playerTestMissions.last else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeOut(duration: 0.35)) {
                proxy.scrollTo(mission.id, anchor: .center)
            }
        }
    }
}

private struct StageRouteLine: View {
    let points: [CGPoint]

    var body: some View {
        Canvas { context, _ in
            guard let first = points.first else { return }
            var route = Path()
            route.move(to: first)
            for point in points.dropFirst() {
                route.addLine(to: point)
            }
            context.stroke(route, with: .color(.black.opacity(0.46)), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            context.stroke(route, with: .color(.yellow.opacity(0.78)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [4, 7]))
        }
        .allowsHitTesting(false)
    }
}

private struct StageRunnerToken: View {
    let isMoving: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.09, paused: !isMoving)) { timeline in
            let frame = Int(timeline.date.timeIntervalSinceReferenceDate / 0.09) % 6 + 1
            let assetName = isMoving ? String(format: "FoolRunN%02d", frame) : "FoolIdleN"
            ZStack {
                Image(decorative: assetName)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(Color(red: 0.035, green: 0.018, blue: 0.065).opacity(0.92))
                    .scaledToFit()
                    .scaleEffect(1.035)

                Image(decorative: assetName)
                    .resizable()
                    .scaledToFit()
            }
            .frame(width: 64, height: 64)
        }
        .shadow(color: .black.opacity(0.48), radius: 3, y: 2)
        .zIndex(20)
        .allowsHitTesting(false)
    }
}

private struct StageMapNode: View {
    let mission: DistrictMission
    let isCompleted: Bool
    let isAvailable: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.78))
                    .frame(width: 54, height: 54)
                Circle()
                    .stroke(nodeColor, lineWidth: isSelected ? 4 : 2)
                    .frame(width: 54, height: 54)
                Image(systemName: symbol)
                    .font(.caption.bold())
                .foregroundStyle(nodeColor)
            }
            .overlay(alignment: .bottom) {
                if let milestone = mission.growthMilestone {
                    Image(systemName: milestone.symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 20, height: 20)
                        .background(.yellow, in: Circle())
                        .offset(y: 8)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.48)
        .accessibilityLabel("关卡 \(mission.number)，\(mission.title)")
    }

    private var symbol: String {
        if isCompleted { return "checkmark" }
        if !isAvailable { return "lock.fill" }
        return mission.kind.symbol
    }

    private var nodeColor: Color {
        if isCompleted { return .green }
        if !isAvailable { return .gray }
        return mission.kind == .boss ? .orange : .yellow
    }
}

private struct StageVenueSign: View {
    let title: String
    let symbol: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.78), in: Capsule())
                .overlay { Capsule().stroke(tint.opacity(0.86), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

private struct StageMapHeader: View {
    let game: GameStore
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                GameArtReturnButton(action: onExit)
                .accessibilityHint("离开旧城区任务地图，回到雾岬港主城")
            
                VStack(alignment: .leading, spacing: 1) {
                    Text("第一章 · 雾岬自由联邦")
                        .font(.headline.bold())
                    Text("\(game.selectedChapterDistrict.name) · \(min(GameStore.playerTestMissionLimit, game.completedMissionCount(in: game.selectedChapterDistrict)))/\(GameStore.playerTestMissionLimit)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.66))
                }
                Spacer()
                Label("\(game.reputation(in: game.selectedChapterDistrict))", systemImage: "seal.fill")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.yellow)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(GameContent.chapterOneDistricts) { district in
                        let unlocked = game.districtIsUnlocked(district)
                        Button {
                            game.selectChapterDistrict(district)
                        } label: {
                            Label("第\(district.order)区", systemImage: unlocked ? district.symbol : "lock.fill")
                                .font(.caption2.bold())
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    district.id == game.selectedChapterDistrict.id
                                        ? Color.purple.opacity(0.74)
                                        : .black.opacity(0.62),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!unlocked)
                        .opacity(unlocked ? 1 : 0.45)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .padding(11)
        // The status bar already reserves the upper safe area. Keep a small
        // breathing inset instead of repeating that height inside the plaque.
        .padding(.top, 28)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.14), lineWidth: 1) }
    }
}

private struct StageMissionDock: View {
    let mission: DistrictMission
    let isCompleted: Bool
    let isMoving: Bool
    let onChallenge: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill((mission.kind == .boss ? Color.orange : .yellow).opacity(0.15))
                Image(systemName: mission.kind.symbol)
                    .foregroundStyle(mission.kind == .boss ? .orange : .yellow)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("关卡 \(mission.number) · \(mission.title)")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                Text("战力 \(mission.recommendedPower) · +\(mission.reputationReward) 声望")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer(minLength: 5)
            MistportPlaqueButton(
                title: isMoving ? "前往中" : (isCompleted ? "再战" : "挑战"),
                compact: true,
                expands: false,
                isEnabled: !isMoving,
                action: onChallenge
            )
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.84), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.yellow.opacity(0.32), lineWidth: 1) }
    }
}

struct DistrictLocationMapView: View {
    @Bindable var game: GameStore
    let onExit: () -> Void
    let onOpenExpedition: () -> Void
    let onEnterVenue: (String) -> Void

    @State private var selectedLocationIndex = 0
    @State private var showWalkableStreet = true
    @State private var neighborConversation: MapNeighbor?
    @State private var neighborError = false
    private struct MapNeighbor: Identifiable { let id: String }
    @State private var selectedMissionID: String?
    @State private var runnerMissionNumber = 1
    @State private var isRunnerMoving = false
    @State private var cameraOffset = CGSize.zero
    @State private var settledCameraOffset = CGSize.zero
    @State private var zoomScale: CGFloat = 1
    @State private var settledZoomScale: CGFloat = 1
    @State private var needsInitialCameraCenter = true
    @State private var isEnteringMission = false
    @State private var missionEntryPulse = false

    struct LocationDefinition: Identifiable {
        let id: Int
        let title: String
        let subtitle: String
        let symbol: String
        let position: CGPoint
        let missionNumbers: ClosedRange<Int>
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if game.selectedChapterDistrict.order == 1 && showWalkableStreet {
                    WisteriaStreetWebView(completedMissions: game.playerTestMissions
                        .sorted { $0.number < $1.number }
                        .prefix(while: { game.missionIsCompleted($0) }).count, onNeighbor: { id in
                            do { try game.talkToNeighbor(id); neighborConversation = .init(id: id) }
                            catch { neighborError = true }
                        })
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    movableMap(in: geometry.size)
                        .allowsHitTesting(true)
                }

                VStack(spacing: 0) {
                    DistrictLocationHeader(game: game, onExit: onExit)
                    Text(showWalkableStreet && game.selectedChapterDistrict.order == 1 ? "点击街道跑动 · 拖动查看" : "拖动地图查看全区 · 双指缩放")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.52), in: Capsule())
                        .padding(.top, 6)
                    if game.selectedChapterDistrict.order == 1 {
                        Button(showWalkableStreet ? "全区地图" : "返回街道") {
                            showWalkableStreet.toggle()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(.top, 8)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .allowsHitTesting(!isMapEntryTutorial)

                if isMapEntryTutorial {
                    Color.black.opacity(0.68)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }

                if let selectedLocation, let mission = selectedMission ?? activeMission(in: selectedLocation) {
                    DistrictLocationDock(
                        district: game.selectedChapterDistrict,
                        location: selectedLocation,
                        mission: mission,
                        completed: completedCount(in: selectedLocation),
                        total: missions(in: selectedLocation).count,
                        isTutorialTarget: isMapEntryTutorial,
                        onEnter: {
                            guard !isEnteringMission else { return }
                            if isMapEntryTutorial {
                                game.completeChapterOneTutorial(.mapEntry)
                            }
                            isEnteringMission = true
                            // The combat session and Unity runtime are prepared before
                            // this tap. Keep the themed transition on screen long enough
                            // for the hourglass artwork to remain readable instead of
                            // replacing it after the previous 80 ms flash.
                            Task { @MainActor in
                                await Task.yield()
                                try? await Task.sleep(for: .milliseconds(1_080))
                                guard !Task.isCancelled else { return }
                                game.beginMission(mission)
                            }
                        }
                    )
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .task(id: mission.id) {
                        // Let the selected location paint first, then prepare
                        // the combat runtime before the player taps Enter.
                        await Task.yield()
                        guard !Task.isCancelled else { return }
                        game.prepareChapterOneMission(mission)
                    }
                }

                if isEnteringMission {
                    ZStack {
                        Color(red: 0.015, green: 0.018, blue: 0.026)
                            .opacity(0.82)
                            .ignoresSafeArea()

                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                Color.purple.opacity(missionEntryPulse ? 0.34 : 0.16),
                                                Color(red: 0.95, green: 0.60, blue: 0.16).opacity(0.05),
                                                .clear
                                            ],
                                            center: .center,
                                            startRadius: 3,
                                            endRadius: 74
                                        )
                                    )
                                    .frame(width: 154, height: 154)
                                    .scaleEffect(missionEntryPulse ? 1.08 : 0.92)
                                    .animation(
                                        .easeInOut(duration: 1.05).repeatForever(autoreverses: true),
                                        value: missionEntryPulse
                                    )

                                Image("LoadingHourglass")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 160, height: 160)
                                    .shadow(color: .purple.opacity(missionEntryPulse ? 0.48 : 0.22), radius: 14)
                                    .offset(y: missionEntryPulse ? -3 : 3)
                                    .animation(
                                        .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                                        value: missionEntryPulse
                                    )
                                    .accessibilityHidden(true)
                            }

                            VStack(spacing: 5) {
                                Text("钟门开启")
                                    .font(.system(size: 21, weight: .black, design: .serif))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 1.00, green: 0.94, blue: 0.72),
                                                Color(red: 0.94, green: 0.62, blue: 0.18)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )

                                Text("雾幕之后，战局显现")
                                    .font(.system(size: 11, weight: .medium, design: .serif))
                                    .tracking(1.4)
                                    .foregroundStyle(.white.opacity(0.56))

                                Text("战斗资源加载中…")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .tracking(1.1)
                                    .foregroundStyle(Color(red: 0.86, green: 0.72, blue: 1.00).opacity(0.82))
                            }
                        }
                    }
                    .onAppear {
                        missionEntryPulse = true
                    }
                    .onDisappear {
                        missionEntryPulse = false
                    }
                    .transition(.opacity)
                    .zIndex(300)
                }
            }
        }
        .background(Color(red: 0.02, green: 0.04, blue: 0.10))
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .alert("街坊委托暂时无法打开", isPresented: $neighborError) { Button("好", role: .cancel) {} }
        .sheet(item: $neighborConversation, onDismiss: { game.endNeighborConversation() }) { neighbor in
            NeighborConversationView(game: game, neighborID: neighbor.id)
        }
        .task(id: game.pacingDay) { try? game.openNeighborDay() }
        .onChange(of: game.selectedChapterDistrict.id) {
            resetMapSelection()
        }
        .onAppear {
            resetMapSelection()
        }
    }

    private var isMapEntryTutorial: Bool {
        game.selectedChapterDistrict.order == 1
            && !game.hasSeenChapterOneTutorial(.mapEntry)
    }

    private func movableMap(in viewportSize: CGSize) -> some View {
        // Chapter one is a wide illustrated city map. Keep its native 4:3
        // composition instead of forcing it into the previous square canvas.
        // The taller canvas leaves a purposeful left-to-right travel lane.
        // Approved chapter-one panorama: 5504 × 3072 (wide 16:9 composition).
        let mapAspectRatio: CGFloat = 5_504 / 3_072
        let canvasHeight = max(viewportSize.height * 1.42, viewportSize.width / mapAspectRatio)
        let canvasSize = CGSize(width: canvasHeight * mapAspectRatio, height: canvasHeight)
        let minimumScale = max(viewportSize.width / canvasSize.width, viewportSize.height / canvasSize.height)
        let effectiveScale = max(minimumScale, zoomScale)
        return ZStack {
            Image(decorative: "MistportWorldMap")
                .resizable()
                .scaledToFill()
                .frame(width: canvasSize.width, height: canvasSize.height)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.04), .clear, .black.opacity(0.18)],
                startPoint: .top,
                endPoint: .bottom
            )

            ForEach(locations) { location in
                DistrictLocationHotspot(
                    title: location.title,
                    symbol: location.symbol,
                    completed: completedCount(in: location),
                    total: missions(in: location).count,
                    isUnlocked: isUnlocked(location),
                    isSelected: location.id == selectedLocationIndex,
                    action: { select(location) }
                )
                .position(normalized: location.position, canvasSize: canvasSize)
            }

            DistrictMapVenueButton(
                title: "午夜钟咖啡馆",
                symbol: "cup.and.saucer.fill",
                action: { onEnterVenue("midnight-clock-cafe") }
            )
            .position(normalized: CGPoint(x: 0.42, y: 0.52), canvasSize: canvasSize)

            DistrictMapVenueButton(
                title: "铜匙餐厅",
                symbol: "fork.knife",
                action: { onEnterVenue("copper-key-restaurant") }
            )
            .position(normalized: CGPoint(x: 0.30, y: 0.61), canvasSize: canvasSize)

            DistrictTeamDungeonButton(
                title: game.selectedChapterDistrict.teamExpedition.title,
                isUnlocked: game.teamExpeditionIsUnlocked(in: game.selectedChapterDistrict),
                completed: game.completedMissionCount(in: game.selectedChapterDistrict),
                action: onOpenExpedition
            )
            .position(normalized: CGPoint(x: 0.84, y: 0.15), canvasSize: canvasSize)

            DistrictProgressFog(
                revealedPoints: game.playerTestMissions
                    .filter { game.missionIsCompleted($0) || game.missionIsAvailable($0) }
                    .map { missionPosition(for: $0.number) }
                    + locations.filter(isUnlocked).map(\.position),
                canvasSize: canvasSize
            )

            StageRunnerToken(isMoving: isRunnerMoving)
                .frame(width: 54, height: 54)
                .position(normalized: missionPosition(for: runnerMissionNumber), canvasSize: canvasSize)
                .animation(.easeInOut(duration: 0.28), value: runnerMissionNumber)
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .scaleEffect(effectiveScale)
        .offset(cameraOffset)
        .contentShape(Rectangle())
        .simultaneousGesture(mapDragGesture(viewportSize: viewportSize, canvasSize: canvasSize, scale: effectiveScale))
        .simultaneousGesture(mapMagnifyGesture(viewportSize: viewportSize, canvasSize: canvasSize, minimumScale: minimumScale))
        .frame(width: viewportSize.width, height: viewportSize.height)
        .clipped()
        .task(id: needsInitialCameraCenter) {
            // Let resetMapSelection establish the runner first, then make the
            // opening composition follow the protagonist. Keying this task to
            // the request flag avoids the onAppear/task ordering race that
            // previously left the runner hidden behind the bottom dock.
            await Task.yield()
            guard needsInitialCameraCenter else { return }
            let protagonistPoint = missionPosition(for: runnerMissionNumber)
            let safeFocus = CGPoint(x: 0.5, y: 0.70)
            let proposed = CGSize(
                width: (safeFocus.x - protagonistPoint.x) * canvasSize.width * effectiveScale,
                height: (safeFocus.y - protagonistPoint.y) * canvasSize.height * effectiveScale
            )
            cameraOffset = constrainedOffset(
                proposed,
                viewportSize: viewportSize,
                canvasSize: canvasSize,
                scale: effectiveScale
            )
            settledCameraOffset = cameraOffset
            needsInitialCameraCenter = false
        }
    }

    private func mapDragGesture(viewportSize: CGSize, canvasSize: CGSize, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let proposed = CGSize(
                    width: settledCameraOffset.width + value.translation.width,
                    height: settledCameraOffset.height + value.translation.height
                )
                cameraOffset = constrainedOffset(proposed, viewportSize: viewportSize, canvasSize: canvasSize, scale: scale)
            }
            .onEnded { _ in
                settledCameraOffset = cameraOffset
            }
    }

    private func mapMagnifyGesture(viewportSize: CGSize, canvasSize: CGSize, minimumScale: CGFloat) -> some Gesture {
        MagnifyGesture(minimumScaleDelta: 0.01)
            .onChanged { value in
                zoomScale = min(1.5, max(minimumScale, settledZoomScale * value.magnification))
                cameraOffset = constrainedOffset(
                    settledCameraOffset,
                    viewportSize: viewportSize,
                    canvasSize: canvasSize,
                    scale: zoomScale
                )
            }
            .onEnded { _ in
                settledZoomScale = zoomScale
                settledCameraOffset = cameraOffset
            }
    }

    private func constrainedOffset(
        _ proposed: CGSize,
        viewportSize: CGSize,
        canvasSize: CGSize,
        scale: CGFloat
    ) -> CGSize {
        let horizontalLimit = max(0, (canvasSize.width * scale - viewportSize.width) / 2)
        let verticalLimit = max(0, (canvasSize.height * scale - viewportSize.height) / 2)
        return CGSize(
            width: min(horizontalLimit, max(-horizontalLimit, proposed.width)),
            height: min(verticalLimit, max(-verticalLimit, proposed.height))
        )
    }

    private var selectedLocation: LocationDefinition? {
        locations.first { $0.id == selectedLocationIndex }
    }

    private var selectedMission: DistrictMission? {
        guard let selectedMissionID else { return nil }
        return game.playerTestMissions.first { $0.id == selectedMissionID }
    }

    private var firstOpenLocationIndex: Int {
        locations.last(where: isUnlocked)?.id ?? 0
    }

    private var locations: [LocationDefinition] {
        let names: [(String, String, String)] = switch game.selectedChapterDistrict.order {
        case 1: [
            ("紫藤街口", "雨夜失踪者", "signpost.right.and.left.fill"),
            ("雾灯街", "午夜报时", "light.beacon.max.fill"),
            ("齿轮工坊", "记忆流水线", "gearshape.2.fill"),
            ("雨水渠", "逆流泵心", "drop.triangle.fill"),
            ("归名档案回廊", "唯一正确的名字", "building.2.fill")
        ]
        case 2: [
            ("七码头", "封仓令", "shippingbox.fill"),
            ("工人宿舍", "结晶热", "bed.double.fill"),
            ("旧排水渠", "地下盐河", "water.waves"),
            ("检疫仓", "白潮病区", "cross.case.fill"),
            ("中央母仓", "母晶源头", "diamond.fill")
        ]
        case 3: [
            ("银幕街", "空席首演", "sparkles.rectangle.stack"),
            ("回声剧场", "镜中观众", "theatermasks.fill"),
            ("后台迷廊", "替身名单", "person.2.fill"),
            ("倒影仓库", "失窃身份", "rectangle.on.rectangle"),
            ("潮汐主舞台", "锚镜终演", "curtains.closed")
        ]
        case 4: [
            ("外港浮桥", "倒流航道", "sailboat.fill"),
            ("打捞船坞", "沉船回声", "anchor"),
            ("东侧闸站", "潮闸失控", "water.waves.and.arrow.up"),
            ("溺钟礁", "旧航线", "bell.fill"),
            ("海底闸心", "深潮之门", "door.left.hand.open")
        ]
        default: [
            ("市政档案馆", "失真档案", "books.vertical.fill"),
            ("领事长廊", "无面宴会", "person.crop.circle.badge.questionmark"),
            ("巡礼大道", "封城法令", "shield.fill"),
            ("雾冠广场", "议会军阵", "building.columns.fill"),
            ("中央议厅", "雾冠审判", "crown.fill")
        ]
        }

        let positions = game.selectedChapterDistrict.order == 1
            ? [
                // Each district marker now sits inside the mission range it
                // represents. The former opening marker was far from nodes
                // 1–5, so the fog hole and the selected story disagreed.
                CGPoint(x: 0.22, y: 0.66),
                CGPoint(x: 0.47, y: 0.58),
                CGPoint(x: 0.66, y: 0.53),
                CGPoint(x: 0.76, y: 0.38),
                CGPoint(x: 0.85, y: 0.21)
            ]
            : [
                CGPoint(x: 0.50, y: 0.76),
                CGPoint(x: 0.28, y: 0.58),
                CGPoint(x: 0.72, y: 0.49),
                CGPoint(x: 0.31, y: 0.30),
                CGPoint(x: 0.70, y: 0.15)
            ]
        let ranges = [1...5, 6...10, 11...13, 14...15, 16...20]

        return names.indices.map { index in
            LocationDefinition(
                id: index,
                title: names[index].0,
                subtitle: names[index].1,
                symbol: names[index].2,
                position: positions[index],
                missionNumbers: ranges[index]
            )
        }
    }

    private func missions(in location: LocationDefinition) -> [DistrictMission] {
        game.playerTestMissions.filter { location.missionNumbers.contains($0.number) }
    }

    private func completedCount(in location: LocationDefinition) -> Int {
        missions(in: location).filter(game.missionIsCompleted).count
    }

    private func isUnlocked(_ location: LocationDefinition) -> Bool {
        missions(in: location).contains { game.missionIsAvailable($0) }
    }

    private func activeMission(in location: LocationDefinition) -> DistrictMission? {
        let candidates = missions(in: location)
        return candidates.first { game.missionIsAvailable($0) && !game.missionIsCompleted($0) }
            ?? candidates.last(where: game.missionIsCompleted)
    }

    private func missionPosition(for number: Int) -> CGPoint {
        let points = game.selectedChapterDistrict.order == 1
            ? chapterOneMissionPoints
            : defaultMissionPoints
        return points[min(max(number - 1, 0), points.count - 1)]
    }

    /// The new first-chapter map reads as one deliberate expedition: residential
    /// lanes on the left, the wisteria crossing, then the rising eastern causeway.
    /// The starting position lands on a visible street, never on a painted roof.
    private var chapterOneMissionPoints: [CGPoint] {
        [
            // The protagonist stands on the broad stone lane west of the canal.
            // Movement remains authored between mission points, never free-form.
            CGPoint(x: 0.17, y: 0.89), CGPoint(x: 0.18, y: 0.70),
            CGPoint(x: 0.23, y: 0.64), CGPoint(x: 0.28, y: 0.58),
            CGPoint(x: 0.34, y: 0.53), CGPoint(x: 0.39, y: 0.50),
            CGPoint(x: 0.44, y: 0.54), CGPoint(x: 0.48, y: 0.59),
            CGPoint(x: 0.52, y: 0.63), CGPoint(x: 0.56, y: 0.66),
            CGPoint(x: 0.61, y: 0.59), CGPoint(x: 0.66, y: 0.54),
            CGPoint(x: 0.70, y: 0.48), CGPoint(x: 0.74, y: 0.42),
            CGPoint(x: 0.77, y: 0.36), CGPoint(x: 0.80, y: 0.31),
            CGPoint(x: 0.83, y: 0.26), CGPoint(x: 0.85, y: 0.21),
            CGPoint(x: 0.88, y: 0.17), CGPoint(x: 0.91, y: 0.13)
        ]
    }

    private var defaultMissionPoints: [CGPoint] {
        [
            CGPoint(x: 0.47, y: 0.83), CGPoint(x: 0.55, y: 0.80),
            CGPoint(x: 0.59, y: 0.75), CGPoint(x: 0.51, y: 0.70),
            CGPoint(x: 0.43, y: 0.67), CGPoint(x: 0.36, y: 0.63),
            CGPoint(x: 0.29, y: 0.60), CGPoint(x: 0.22, y: 0.56),
            CGPoint(x: 0.30, y: 0.51), CGPoint(x: 0.40, y: 0.48),
            CGPoint(x: 0.53, y: 0.54), CGPoint(x: 0.66, y: 0.57),
            CGPoint(x: 0.79, y: 0.55), CGPoint(x: 0.65, y: 0.46),
            CGPoint(x: 0.50, y: 0.39), CGPoint(x: 0.37, y: 0.32),
            CGPoint(x: 0.28, y: 0.24), CGPoint(x: 0.43, y: 0.21),
            CGPoint(x: 0.58, y: 0.17), CGPoint(x: 0.72, y: 0.13)
        ]
    }

    private func select(_ location: LocationDefinition) {
        selectedLocationIndex = location.id
        selectedMissionID = activeMission(in: location)?.id
    }

    private func travel(to mission: DistrictMission) {
        guard game.missionIsAvailable(mission), !isRunnerMoving else { return }
        selectedMissionID = mission.id
        selectedLocationIndex = locations.first(where: { $0.missionNumbers.contains(mission.number) })?.id ?? 0

        guard mission.number != runnerMissionNumber else { return }
        isRunnerMoving = true
        let step = mission.number > runnerMissionNumber ? 1 : -1

        Task { @MainActor in
            for number in stride(from: runnerMissionNumber + step, through: mission.number, by: step) {
                runnerMissionNumber = number
                try? await Task.sleep(for: .milliseconds(280))
            }
            isRunnerMoving = false
        }
    }

    private func resetMapSelection() {
        selectedLocationIndex = firstOpenLocationIndex
        let mission = game.nextChapterMission
            ?? game.playerTestMissions.last(where: game.missionIsCompleted)
            ?? game.playerTestMissions.first
        selectedMissionID = mission?.id
        runnerMissionNumber = mission?.number ?? 1
        isRunnerMoving = false
        zoomScale = 1.1
        settledZoomScale = 1.1
        cameraOffset = .zero
        settledCameraOffset = .zero
        needsInitialCameraCenter = true

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--preview-map-tour") {
            zoomScale = 0.42
            settledZoomScale = zoomScale
            cameraOffset = .zero
            settledCameraOffset = .zero
        }
        #endif
    }
}

private struct DistrictProgressFog: View {
    let revealedPoints: [CGPoint]
    let canvasSize: CGSize

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ZStack {
                    // Locked districts should read as genuinely unknown, not
                    // merely desaturated. The soft cutouts still reveal the
                    // protagonist's current route.
                    Color(red: 0.92, green: 0.94, blue: 0.98).opacity(0.97)

                    ForEach(0..<20, id: \.self) { index in
                        DistrictFogWisp(
                            index: index,
                            seconds: seconds,
                            canvasSize: canvasSize
                        )
                    }

                    if revealedPoints.count > 1 {
                        Path { path in
                            let points = revealedPoints.map {
                                CGPoint(x: canvasSize.width * $0.x, y: canvasSize.height * $0.y)
                            }
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for point in points.dropFirst() { path.addLine(to: point) }
                        }
                        .stroke(.black, style: StrokeStyle(lineWidth: 220, lineCap: .round, lineJoin: .round))
                        .blur(radius: 36)
                        .blendMode(.destinationOut)
                    }

                    ForEach(Array(revealedPoints.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(.black)
                            .frame(width: 520, height: 520)
                            .blur(radius: 54)
                            .position(normalized: point, canvasSize: canvasSize)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DistrictFogWisp: View {
    let index: Int
    let seconds: TimeInterval
    let canvasSize: CGSize

    var body: some View {
        let speed = 0.055 + Double(index % 4) * 0.009
        let phase = seconds * speed + Double(index) * 1.73
        let baseX = 0.06 + CGFloat((index * 37) % 89) / 100
        let baseY = 0.05 + CGFloat((index * 53) % 91) / 100
        let x = canvasSize.width * baseX + CGFloat(sin(phase)) * 46
        let y = canvasSize.height * baseY + CGFloat(cos(phase * 0.83)) * 34
        let opacity = 0.10 + Double(index % 3) * 0.025

        Ellipse()
            .fill(Color.white.opacity(opacity))
            .frame(
                width: 210 + CGFloat(index % 5) * 46,
                height: 90 + CGFloat(index % 4) * 31
            )
            .blur(radius: 34)
            .position(x: x, y: y)
    }
}

private struct DistrictMissionMapNode: View {
    let mission: DistrictMission
    let isCompleted: Bool
    let isAvailable: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if mission.kind != .combat {
                    Diamond()
                        .stroke(nodeAccent.opacity(isAvailable ? 0.96 : 0.40), lineWidth: mission.kind == .boss ? 2.5 : 1.7)
                        .frame(width: mission.kind == .boss ? 48 : 43, height: mission.kind == .boss ? 48 : 43)
                        .rotationEffect(.degrees(45))
                }

                Circle()
                    .fill(nodeFill)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Circle()
                            .stroke(isSelected ? .white : nodeAccent.opacity(0.88), lineWidth: isSelected ? 2.5 : 1.2)
                    }

                Image(systemName: isCompleted ? "checkmark" : mission.kind.symbol)
                    .font(.system(size: mission.kind == .boss ? 13 : 11, weight: .black))
                    .foregroundStyle(isAvailable || isCompleted ? .black.opacity(0.82) : .white.opacity(0.62))

            }
            .frame(width: 54, height: 58)
            .shadow(color: isSelected ? nodeAccent.opacity(0.82) : .black.opacity(0.34), radius: isSelected ? 9 : 3)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityLabel("\(mission.kind.title)关卡 \(mission.number)，\(mission.title)")
        .accessibilityValue(isCompleted ? "已完成" : (isAvailable ? "可挑战" : "未开放"))
    }

    private var nodeAccent: Color {
        if isCompleted { return .mint }
        switch mission.kind {
        case .combat: return .cyan
        case .elite: return .yellow
        case .boss: return .red
        }
    }

    private var nodeFill: some ShapeStyle {
        if isCompleted {
            return AnyShapeStyle(LinearGradient(colors: [.mint, .green], startPoint: .top, endPoint: .bottom))
        }
        guard isAvailable else {
            return AnyShapeStyle(Color.black.opacity(0.72))
        }
        switch mission.kind {
        case .combat:
            return AnyShapeStyle(LinearGradient(colors: [Color(red: 0.76, green: 0.96, blue: 1), .cyan], startPoint: .top, endPoint: .bottom))
        case .elite:
            return AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.93, blue: 0.60), .orange], startPoint: .top, endPoint: .bottom))
        case .boss:
            return AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.60, blue: 0.58), .red], startPoint: .top, endPoint: .bottom))
        }
    }
}

private struct DistrictMissionRoute: View {
    let points: [CGPoint]
    let canvasSize: CGSize

    var body: some View {
        let scaledPoints = points.map {
            CGPoint(x: canvasSize.width * $0.x, y: canvasSize.height * $0.y)
        }

        Path { path in
            guard let first = scaledPoints.first else { return }
            path.move(to: first)
            for point in scaledPoints.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(
            LinearGradient(
                colors: [.white.opacity(0.60), Color(red: 0.93, green: 0.76, blue: 0.34).opacity(0.78)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 7])
        )
        .shadow(color: .black.opacity(0.40), radius: 2)
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(false)
    }
}

private extension View {
    func position(normalized point: CGPoint, canvasSize: CGSize) -> some View {
        position(x: canvasSize.width * point.x, y: canvasSize.height * point.y)
    }
}

private struct DistrictLocationHotspot: View {
    let title: String
    let symbol: String
    let completed: Int
    let total: Int
    let isUnlocked: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    if isUnlocked && isOpeningLocation {
                        EmptyView()
                    } else {
                        Circle()
                            .fill(isUnlocked ? nodeColor : Color.black.opacity(0.76))
                            .frame(width: 46, height: 46)
                            .overlay {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.white.opacity(isSelected ? 0.95 : 0.62), nodeColor.opacity(0.92)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isSelected ? 2.4 : 1.2
                                    )
                            }
                            .shadow(color: isUnlocked ? nodeColor.opacity(0.45) : .black.opacity(0.35), radius: 6)

                        Image(systemName: isUnlocked ? symbol : "lock.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(isUnlocked ? .black.opacity(0.80) : .white.opacity(0.55))
                    }
                }
                .frame(
                    width: isOpeningLocation ? 0 : 72,
                    height: isOpeningLocation ? 0 : 72
                )
                Text(title)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.76), in: Capsule())
                Text("\(completed)/\(total)")
                    .font(.system(size: 9, weight: .bold).monospacedDigit())
                    .foregroundStyle(
                        isUnlocked && isOpeningLocation
                            ? Color(red: 0.86, green: 0.72, blue: 1.0)
                            : (isUnlocked ? .yellow : .gray)
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .opacity(isUnlocked ? 1 : 0.58)
    }

    private var nodeColor: Color {
        completed == total ? .green : .yellow
    }

    private var isOpeningLocation: Bool {
        title == "紫藤街口"
    }
}

private struct DistrictMapVenueButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.caption2.bold())
                .foregroundStyle(Color(red: 0.91, green: 0.94, blue: 0.95))
                .padding(.leading, 35)
                .padding(.trailing, 10)
                .frame(minWidth: 126, minHeight: 42)
                .background {
                    Image("ButtonArt17DistrictVenue")
                        .resizable(capInsets: EdgeInsets(top: 18, leading: 48, bottom: 18, trailing: 48), resizingMode: .stretch)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct DistrictTeamDungeonButton: View {
    let title: String
    let isUnlocked: Bool
    let completed: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.caption.bold())
                    Text(isUnlocked ? "团队副本 · 可选挑战" : "完成 \(completed)/10 解锁")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.leading, 48)
                Spacer(minLength: 32)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .background {
                Image("ButtonArt18TeamDungeon")
                    .resizable(capInsets: EdgeInsets(top: 20, leading: 90, bottom: 20, trailing: 52), resizingMode: .stretch)
                    .saturation(isUnlocked ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .opacity(isUnlocked ? 1 : 0.66)
    }
}

private struct DistrictLocationHeader: View {
    let game: GameStore
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                GameArtReturnButton(action: onExit)
                .accessibilityHint("离开旧城区任务地图，回到雾岬港主城")

                VStack(alignment: .leading, spacing: 1) {
                    Text("第一章 · 雾岬自由联邦")
                        .font(.headline.bold())
                    Text("\(game.selectedChapterDistrict.name) · \(min(GameStore.playerTestMissionLimit, game.completedMissionCount(in: game.selectedChapterDistrict)))/\(GameStore.playerTestMissionLimit)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.64))
                }

                Spacer()

                Label("\(game.reputation(in: game.selectedChapterDistrict))", systemImage: "seal.fill")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.yellow)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    ForEach(GameContent.chapterOneDistricts) { district in
                        let unlocked = game.districtIsUnlocked(district)
                        Button {
                            game.selectChapterDistrict(district)
                        } label: {
                            Label("第\(district.order)区", systemImage: unlocked ? district.symbol : "lock.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(
                                    district.id == game.selectedChapterDistrict.id
                                        ? Color.purple.opacity(0.78)
                                        : Color.black.opacity(0.56),
                                    in: Capsule()
                                )
                                .overlay { Capsule().stroke(.white.opacity(0.12), lineWidth: 1) }
                        }
                        .buttonStyle(.plain)
                        .disabled(!unlocked)
                        .opacity(unlocked ? 1 : 0.45)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(.white)
        .padding(11)
        // The status bar already reserves the upper safe area. Keep a small
        // breathing inset instead of repeating that height inside the plaque.
        .padding(.top, 28)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.14), lineWidth: 1) }
    }
}

private struct DistrictLocationDock: View {
    let district: ChapterDistrict
    let location: DistrictLocationMapView.LocationDefinition
    let mission: DistrictMission
    let completed: Int
    let total: Int
    let isTutorialTarget: Bool
    let onEnter: () -> Void
    @State private var isStoryExpanded = false
    @State private var tutorialButtonBreath = false

    var body: some View {
        HStack(spacing: 11) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                    isStoryExpanded.toggle()
                }
            } label: {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("关卡 \(mission.number) · \(mission.title)")
                        .font(.subheadline.bold())
                    if isStoryExpanded {
                        Text("\(district.name) · \(district.question)")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.37, green: 0.20, blue: 0.47).opacity(0.86))
                        Text(district.theme)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.20).opacity(0.70))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("目标：\(mission.objective) · 奖励：\(mission.rewardText) · 进度 \(completed)/\(total)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.20).opacity(0.54))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Label("\(district.subtitle) · 点击查看地图问题", systemImage: "book.closed.fill")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.20).opacity(0.54))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 5)
            MistportPlaqueButton(
                title: buttonTitle,
                compact: true,
                expands: false,
                horizontalInset: 13,
                action: onEnter
            )
                .frame(minWidth: 82)
                .offset(x: -5)
                .scaleEffect(isTutorialTarget && tutorialButtonBreath ? 1.09 : 0.97)
                .shadow(
                    color: isTutorialTarget ? Color.purple.opacity(tutorialButtonBreath ? 0.58 : 0.14) : .clear,
                    radius: tutorialButtonBreath ? 18 : 3
                )
                .animation(
                    isTutorialTarget
                        ? .easeInOut(duration: 1.3).repeatForever(autoreverses: true)
                        : .default,
                    value: tutorialButtonBreath
                )
        }
        .foregroundStyle(Color(red: 0.13, green: 0.10, blue: 0.16))
        .padding(12)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.91).opacity(0.52),
                    Color(red: 0.95, green: 0.91, blue: 0.83).opacity(0.38)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(red: 0.43, green: 0.28, blue: 0.50).opacity(0.42), lineWidth: 1)
        }
        .onAppear {
            if isTutorialTarget { tutorialButtonBreath = true }
        }
    }

    private var buttonTitle: String {
        // This action opens the battle; growth rewards are delivered by
        // progression, not by pressing a separate awakening/advancement button.
        if mission.districtID == "old-clock" { return "进入" }
        if let milestone = mission.growthMilestone {
            return milestone.title
        }
        return mission.kind == .boss ? "首领战" : "进入"
    }
}

struct MissionBoardView: View {
    @Environment(\.dismiss) private var dismiss

    let game: GameStore
    let onOpenExpedition: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Image(decorative: "MistportWorldMap")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [.black.opacity(0.42), Color(red: 0.02, green: 0.03, blue: 0.09).opacity(0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12) {
                        chapterHeader
                        districtSelector
                        districtProgressCard
                        Text(game.repeatWorkNotice).font(.caption).foregroundStyle(.yellow)

                        ForEach(game.playerTestMissions) { mission in
                            DistrictMissionRow(
                                mission: mission,
                                isCompleted: game.missionIsCompleted(mission),
                                isAvailable: game.missionIsAvailable(mission),
                                rewardCopper: game.missionCoinReward(for: mission, firstClear: !game.missionIsCompleted(mission)),
                                lockReason: game.missionLockText(mission),
                                action: { begin(mission) }
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 28)
                }
            }
            .foregroundStyle(.white)
            .navigationTitle("雾岬任务航图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    GameArtReturnButton(title: "完成") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var chapterHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("第一章 · 雾岬自由联邦")
                .font(.title2.bold())
            HStack {
                Label("1 个完整城区", systemImage: "map.fill")
                Label("20 项主任务", systemImage: "list.number")
                Label("1 场晋阶仪式", systemImage: "seal.fill")
            }
            .font(.caption.bold())
            .foregroundStyle(.cyan)
            Text("沿《第十三声》主线完成观察训练、三次阶段守关与最终首领战，固定取得全部晋阶材料。")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
    }

    private var districtSelector: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 9) {
                ForEach(GameContent.chapterOneDistricts) { district in
                    let isUnlocked = game.districtIsUnlocked(district)
                    let isSelected = district.id == game.selectedChapterDistrict.id
                    Button {
                        game.selectChapterDistrict(district)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: isUnlocked ? district.symbol : "lock.fill")
                                .font(.headline)
                            Text("第\(district.order)区")
                                .font(.caption2.bold())
                            Text(isUnlocked ? district.name : "未开放")
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .frame(width: 82, height: 72)
                        .background(isSelected ? Color.purple.opacity(0.46) : .black.opacity(0.58), in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(isSelected ? .purple : .white.opacity(0.14), lineWidth: isSelected ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isUnlocked)
                    .opacity(isUnlocked ? 1 : 0.52)
                    .accessibilityLabel("第\(district.order)区，\(district.name)，\(isUnlocked ? "已开放" : "未开放")")
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
    }

    private var districtProgressCard: some View {
        let district = game.selectedChapterDistrict
        let completed = game.completedMissionCount(in: district)
        let reputation = game.reputation(in: district)

        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: district.symbol)
                    .font(.title2)
                    .foregroundStyle(.yellow)
                VStack(alignment: .leading, spacing: 1) {
                    Text(district.name)
                        .font(.title3.bold())
                    Text(district.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Text("\(completed)/20")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.yellow)
            }

            Text(district.theme)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))

            ReputationProgressView(value: reputation)

            HStack(spacing: 6) {
                milestoneBadge("武装", symbol: "hammer.fill", unlocked: completed >= 5)
                milestoneBadge("技能", symbol: "sparkles", unlocked: completed >= 10)
                milestoneBadge("天赋", symbol: "seal.fill", unlocked: completed >= 15)
                milestoneBadge("晋阶", symbol: "chevron.up.2", unlocked: completed >= 20)
            }

            HStack {
                Label("声望 \(reputation) · 晋阶门槛100", systemImage: "seal.fill")
                Spacer()
                Text(reputation >= 100 ? "已达门槛，声望继续累计" : "还需 \(100 - reputation) 声望")
            }
            .font(.caption2.bold().monospacedDigit())
            .foregroundStyle(reputation >= 100 ? .green : .white.opacity(0.62))
        }
        .padding(14)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.yellow.opacity(0.30), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    private func milestoneBadge(_ title: String, symbol: String, unlocked: Bool) -> some View {
        Label(title, systemImage: unlocked ? symbol : "lock.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(unlocked ? .yellow : .white.opacity(0.36))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background((unlocked ? Color.yellow : .white).opacity(0.08), in: Capsule())
    }

    private var teamExpeditionCard: some View {
        let district = game.selectedChapterDistrict
        let expedition = district.teamExpedition
        let completed = game.completedMissionCount(in: district)
        let isUnlocked = game.teamExpeditionIsUnlocked(in: district)

        return Button(action: openExpedition) {
            HStack(spacing: 12) {
                Image(systemName: isUnlocked ? "person.3.fill" : "lock.fill")
                    .font(.title2)
                    .foregroundStyle(isUnlocked ? .cyan : .gray)
                    .frame(width: 44, height: 44)
                    .background((isUnlocked ? Color.cyan : .gray).opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text("本区唯一团队副本")
                        .font(.caption2.bold())
                        .foregroundStyle(.yellow)
                    Text(expedition.title)
                        .font(.headline)
                    Text(isUnlocked ? "约 \(expedition.estimatedMinutes) 分钟 · 随到随组" : "远征将在后续测试开放")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(isUnlocked ? .cyan : .gray)
            }
            .foregroundStyle(.white)
            .padding(13)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke((isUnlocked ? Color.cyan : .gray).opacity(0.32), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .accessibilityHint(isUnlocked ? "打开团队副本匹配" : "完成十个本区任务后开放")
    }

    private func begin(_ mission: DistrictMission) {
        game.beginMission(mission)
        dismiss()
    }

    private func openExpedition() {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))
            onOpenExpedition()
        }
    }
}

private struct ReputationProgressView: View {
    let value: Int

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(.linearGradient(colors: [.purple, .yellow], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geometry.size.width * min(1, CGFloat(value) / 100))
            }
        }
        .frame(height: 8)
        .animation(.easeOut(duration: 0.2), value: value)
        .accessibilityLabel("区域声望")
        .accessibilityValue("已累计\(value)，晋阶门槛100")
    }
}

private struct DistrictMissionRow: View {
    let mission: DistrictMission
    let isCompleted: Bool
    let isAvailable: Bool
    let rewardCopper: Int
    let lockReason: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(stateColor.opacity(0.16))
                    Image(systemName: stateSymbol)
                        .font(.caption.bold())
                        .foregroundStyle(stateColor)
                }
                .frame(width: 39, height: 39)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("\(mission.number). \(mission.title)")
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        if mission.kind != .combat {
                            Text(mission.kind.title)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(mission.kind == .boss ? .orange : .cyan)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background((mission.kind == .boss ? Color.orange : .cyan).opacity(0.12), in: Capsule())
                        }
                        if let milestone = mission.growthMilestone {
                            Text(milestone.title)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.yellow)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.yellow.opacity(0.12), in: Capsule())
                        }
                    }
                    Text(isAvailable ? "本次奖励 \(rewardCopper) 铜币" : lockReason ?? "完成前置主线后开放")
                        .font(.caption).foregroundStyle(.yellow)
                    Text(mission.objective)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        Label("战力 \(mission.recommendedPower)", systemImage: "bolt.fill")
                        Label("+\(mission.reputationReward) 声望", systemImage: "seal.fill")
                        Text(mission.difficultyLabel)
                    }
                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.58))
                }
                Spacer(minLength: 4)
                Image(systemName: isCompleted ? "arrow.clockwise" : "chevron.right")
                    .foregroundStyle(stateColor)
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(stateColor.opacity(0.28), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.48)
        .accessibilityLabel("任务 \(mission.number)，\(mission.title)，\(isCompleted ? "已完成" : (isAvailable ? "可挑战" : lockReason ?? "完成前置主线后开放"))")
        .accessibilityHint(isAvailable ? (isCompleted ? "可以重复挑战，不重复获得声望" : "进入战斗副本") : (lockReason ?? "完成前置主线后开放"))
    }

    private var stateColor: Color {
        if isCompleted { return .green }
        if isAvailable { return mission.kind == .boss ? .orange : .purple }
        return .gray
    }

    private var stateSymbol: String {
        if isCompleted { return "checkmark" }
        if isAvailable { return mission.kind.symbol }
        return "lock.fill"
    }
}

#if DEBUG
#Preview {
    MissionBoardView(game: GameStore(), onOpenExpedition: {})
}
#endif


/// Offline, fixed-camera 3D street. The enclosing native view owns missions and save data.
private struct WisteriaStreetWebView: UIViewRepresentable {
    let completedMissions: Int
    let onNeighbor: (String) -> Void
    private var testBypass: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--map-unlocked")
        #else
        false
        #endif
    }
    private var debugWalkTarget: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--daily-pacing-device-walk"), args.contains("--daily-map-walk") else { return nil }
        return args.contains("--daily-map-recipient") ? "west-lane" : "postman"
        #else
        return nil
        #endif
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var onNeighbor: ((String) -> Void)?
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--daily-map-walk") {
                NSLog("DAILY_MAP_MESSAGE: main=%@ url=%@ body=%@", message.frameInfo.isMainFrame ? "true" : "false", message.frameInfo.request.url?.absoluteString ?? "nil", String(describing: message.body))
            }
            #endif
            guard message.name == "neighborArrival", message.frameInfo.isMainFrame,
                  message.frameInfo.request.url?.scheme == "mistport-map",
                  let body = message.body as? [String: Any] else { return }
            #if DEBUG
            if body["kind"] as? String == "ready", let ids = body["ids"] as? [String] {
                let complete = Set(ids) == Set(MPCNeighborCatalog.all.map(\.id)) && ids.count == 23
                NSLog("DAILY_MAP_ROSTER: complete=%@ count=%d", complete ? "true" : "false", ids.count)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    saveDailyLoopReviewFrame("map-street-loaded")
                }
                return
            }
            #endif
            guard let id = body["id"] as? String, let distance = body["distance"] as? Double,
                  distance >= 0, distance <= 2.5, MPCNeighborCatalog.neighbor(id) != nil else { return }
            #if DEBUG
            NSLog("DAILY_MAP_NEIGHBOR_ARRIVAL: %@ distance=%.3f", id, distance)
            #endif
            onNeighbor?(id)
        }
        var completed = 0
        var bypass = false
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("window.setMapProgress?.(\(completed), \(bypass));", completionHandler: nil)
            #if DEBUG
            NSLog("DAILY_MAP_PAGE_FINISHED: %@", webView.url?.absoluteString ?? "nil")
            if ProcessInfo.processInfo.arguments.contains("--daily-map-walk") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(12))
                    saveDailyLoopReviewFrame("map-after-load")
                    webView.evaluateJavaScript("document.body.innerText") { result, error in
                        NSLog("DAILY_MAP_PAGE_TEXT: %@ error=%@", String(describing: result), String(describing: error))
                    }
                }
            }
            #endif
        }
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            NSLog("Mistport street navigation failed: %@", String(describing: error))
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            NSLog("Mistport street load failed: %@", String(describing: error))
        }
    }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "neighborArrival")
        configuration.setURLSchemeHandler(WisteriaBundleHandler(), forURLScheme: "mistport-map")
        configuration.userContentController.addUserScript(WKUserScript(
            source: "window.__mapProgress = \(completedMissions); window.__mapBypass = \(testBypass); window.__neighborWalkTarget = '\(debugWalkTarget ?? "")';",
            injectionTime: .atDocumentStart, forMainFrameOnly: true))
        context.coordinator.onNeighbor = onNeighbor
        context.coordinator.completed = completedMissions
        context.coordinator.bypass = testBypass
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 0.08, green: 0.11, blue: 0.15, alpha: 1)
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.scrollView.contentInset = .zero
        view.scrollView.isScrollEnabled = false
        view.scrollView.bounces = false
        view.load(URLRequest(url: URL(string: "mistport-map://local/index.html")!))
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.onNeighbor = onNeighbor
        context.coordinator.completed = completedMissions
        context.coordinator.bypass = testBypass
        view.evaluateJavaScript("window.setMapProgress?.(\(completedMissions), \(testBypass));", completionHandler: nil)
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "neighborArrival")
        coordinator.onNeighbor = nil
        view.stopLoading()
        view.loadHTMLString("", baseURL: nil)
    }
}

/// Serve only bundled map files; module requests never depend on a development server.
private final class WisteriaBundleHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url,
              let root = Bundle.main.resourceURL?.appendingPathComponent("WisteriaMap").resolvingSymlinksInPath().standardizedFileURL else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let file = root.appendingPathComponent(url.path).resolvingSymlinksInPath().standardizedFileURL
        guard file.path.hasPrefix(root.path + "/") else {
            NSLog("Mistport street resource outside bundle: %@", url.path)
            urlSchemeTask.didFailWithError(URLError(.noPermissionsToReadFile)); return
        }
        let data: Data
        do { data = try Data(contentsOf: file) }
        catch {
            NSLog("Mistport street resource read failed: %@ error=%@", file.path, String(describing: error))
            urlSchemeTask.didFailWithError(error); return
        }
        let mime: String
        switch file.pathExtension {
        case "html": mime = "text/html"
        case "js": mime = "application/javascript"
        case "json", "gltf": mime = "application/json"
        case "png": mime = "image/png"
        default: mime = "application/octet-stream"
        }
        urlSchemeTask.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}
