import SwiftUI
import MistportCombatCore

struct CityHubView: View {
    @State private var panoramaOffset: CGFloat = 0
    @State private var tasksExpanded = false
    @State private var trackedTargetID: String?
    /// Height of the bottom bar; the harbour painting ends at its top edge.
    @State private var bottomBarHeight: CGFloat = 0
    @GestureState private var panoramaDrag: CGFloat = 0
    let path: Pathway?
    let sequence: Int
    let districtName: String
    let nextMissionTitle: String
    let missionProgress: Int
    let reputation: Int
    let coins: Int
    let materials: Int
    let clues: Int
    let ingredientCount: Int
    var serviceIsUnlocked: (CityService) -> Bool = { _ in false }
    var cafeUnlocked = false
    var onSettings: () -> Void = {}
    var onTest: (() -> Void)? = nil
    let onStory: () -> Void
    let onWorld: () -> Void
    let onExpedition: () -> Void
    let onStore: () -> Void
    let onChurch: () -> Void
    let onBountyTavern: () -> Void
    let onProfile: () -> Void
    let onBuild: () -> Void
    let onAdvancement: () -> Void
    let onSupply: () -> Void
    let onInventory: () -> Void
    let onEnterVenue: (String) -> Void
    var onNewspaper: () -> Void = {}
    var homeIsActive = true
    var streetTargets: [MPCStreetTaskTarget] = []
    var focusID: String?
    var focusRevision = 0
    private var trackedTarget: MPCStreetTaskTarget? { streetTargets.first { $0.id == trackedTargetID } ?? streetTargets.first }
    var onStreetTarget: (MPCStreetTaskTarget) -> Void = { _ in }
    var onStreetService: (String) -> Void = { _ in }
    var onCounter: (String) -> Void = { _ in }
    /// After Q30: Chapter Two's Black Salt Shore bridge (status line, action).
    var blackSaltShore: (status: String, action: () -> Void)? = nil

    private var tint: Color { path?.tint ?? .purple }

    var body: some View {
        GeometryReader { geometry in
            // The painting's height fits the screen above the bottom bar, so
            // the whole picture shows from top to bottom.
            let scenery = CGSize(width: geometry.size.width,
                                 height: max(1, geometry.size.height - max(0, bottomBarHeight - 8)))
            ZStack {
                cityPanorama(in: scenery)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)

                LinearGradient(
                    colors: [.black.opacity(0.18), .clear, .black.opacity(0.46)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    CityStatusHUD(path: path, sequence: sequence, districtName: districtName, reputation: reputation,
                                  coins: coins, materials: materials, clues: clues, ingredientCount: ingredientCount,
                                  onSettings: onSettings, onTest: onTest)
                        .padding(.horizontal, 18)
                    taskStrip(in: scenery).padding(.horizontal, 18).padding(.top, 8)
                    Spacer()
                    if let blackSaltShore {
                        CityMissionStrip(
                            tint: tint,
                            districtName: "第二章 · 黑盐岸",
                            missionTitle: "盐岸外港转运站",
                            progress: 0,
                            detail: blackSaltShore.status,
                            action: blackSaltShore.action
                        )
                        .padding(.horizontal, 28)
                        .padding(.bottom, 8)
                    }
                    CityBottomBar(
                        bottomInset: max(geometry.safeAreaInsets.bottom, 8),
                        churchUnlocked: serviceIsUnlocked(.church),
                        storeUnlocked: serviceIsUnlocked(.store),
                        onWork: onBuild,
                        onChurch: onChurch,
                        onStore: onStore,
                        onProfile: onProfile,
                        onInventory: onInventory
                    )
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomBarHeight = $0 }
                }
                .padding(.top, max(geometry.safeAreaInsets.top, 54) + 8)

                // Centred on the screen, halfway down.
                panoramaArrows(in: scenery)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()

    }

    /// The harbour painting fills the height; on a phone about a quarter of
    /// its width shows at once and the rest is reached by dragging.
    private func panoramaWidth(for viewport: CGSize) -> CGFloat {
        max(viewport.width, viewport.height * HarborPainting.aspect)
    }

    private func cityPanorama(in viewport: CGSize) -> some View {
        let panoramaWidth = panoramaWidth(for: viewport)

        return ZStack {
            CityLivingScene(isActive: homeIsActive, showsNearPeople: false)
                .frame(width: panoramaWidth, height: viewport.height)

            let painting = HarborPainting.rect(in: CGSize(width: panoramaWidth, height: viewport.height))
            let offset = boundedPanoramaOffset(panoramaOffset + panoramaDrag, in: viewport)
            let left = (panoramaWidth / 2 - viewport.width / 2 - offset - painting.minX) / painting.height
            HomeStreetScene(painting: painting, visibleRange: Double(left - 0.035)...Double(left + viewport.width / painting.height + 0.035),
                            active: homeIsActive, targets: streetTargets, trackedID: trackedTarget?.id, onTarget: onStreetTarget, onService: onStreetService)
            cityHotspots(in: viewport, panoramaWidth: panoramaWidth)
            ForEach(streetTargets.filter { $0.personID == nil }) { target in
                let point = HomeMapLayout.current.targetPoint(target)
                Button { onStreetTarget(target) } label: {
                    Image(systemName: "seal.fill").font(.title2).foregroundStyle(.red)
                        .frame(width: 44, height: 44).background(.black.opacity(0.4), in: Circle())
                }.accessibilityLabel(target.title)
                    .position(x: painting.minX + point[0] * painting.height, y: painting.minY + point[1] * painting.height)
            }
        }
        .frame(width: panoramaWidth, height: viewport.height)
        .offset(x: boundedPanoramaOffset(panoramaOffset + panoramaDrag, in: viewport))
        .frame(width: viewport.width, height: viewport.height)
        .contentShape(Rectangle())
        .clipped()
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .updating($panoramaDrag) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    panoramaOffset = boundedPanoramaOffset(
                        panoramaOffset + value.translation.width, in: viewport)
                }
        )
        .onChange(of: focusRevision) { _, _ in
            guard let id = focusID else { return }
            if let target = streetTargets.first(where: { $0.id == id || $0.taskID == id }) {
                center(HomeMapLayout.current.targetPoint(target)[0], in: viewport)
            } else if let building = HomeMapLayout.current.building(id) { center(building.at![0], in: viewport) }
        }
        #if DEBUG
        .task(id: viewport.height) { await debugLabelCheck(in: viewport) }
        #endif
    }

    private func boundedPanoramaOffset(_ offset: CGFloat, in viewport: CGSize) -> CGFloat {
        let travel = max(0, (panoramaWidth(for: viewport) - viewport.width) / 2)
        return min(travel, max(-travel, offset))
    }

    #if DEBUG
    /// Device check of the building labels: -MistportHubPanX centres a painting x
    /// on screen; -MistportHubSnapshot saves the window and its layout to Documents.
    private func debugLabelCheck(in viewport: CGSize) async {
        let arguments = UserDefaults.standard
        let width = panoramaWidth(for: viewport)
        let painting = HarborPainting.rect(in: CGSize(width: width, height: viewport.height))
        if let x = arguments.string(forKey: "MistportHubPanX").flatMap(Double.init) {
            panoramaOffset = boundedPanoramaOffset(width / 2 - (painting.minX + CGFloat(x) * painting.height), in: viewport)
        }
        guard let name = arguments.string(forKey: "MistportHubSnapshot") else { return }
        HomeFrameSampler.shared.begin()
        try? await Task.sleep(for: .seconds(4))
        guard !Task.isCancelled,
              let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows).first(where: \.isKeyWindow),
              let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try? image.pngData()?.write(to: folder.appendingPathComponent(name))
        let layout: [String: Double] = [
            "viewportWidth": Double(viewport.width), "viewportHeight": Double(viewport.height),
            "panoramaWidth": Double(width), "paintingMinX": Double(painting.minX), "paintingMinY": Double(painting.minY),
            "paintingHeight": Double(painting.height), "offset": Double(boundedPanoramaOffset(panoramaOffset, in: viewport)),
            "windowWidth": Double(window.bounds.width), "windowHeight": Double(window.bounds.height),
            "screenScale": Double(window.traitCollection.displayScale)
        ]
        try? JSONSerialization.data(withJSONObject: layout, options: .sortedKeys)
            .write(to: folder.appendingPathComponent(name + ".json"))
        if ProcessInfo.processInfo.arguments.contains("--home-map-review-motion") {
            for (index, delay) in [8.0, 12.0, 8.0].enumerated() {
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                HomeFrameSampler.saveScreenshot("home-motion-\(index + 1).png")
            }
        }
    }
    #endif

    private func panoramaArrows(in viewport: CGSize) -> some View {
        let travel = max(0, (panoramaWidth(for: viewport) - viewport.width) / 2)
        let currentOffset = boundedPanoramaOffset(panoramaOffset + panoramaDrag, in: viewport)
        let step = min(travel, viewport.width * 0.55)

        return HStack {
            if currentOffset < travel - 1 {
                panoramaArrow("chevron.left", label: "查看左侧港城") {
                    panoramaOffset = boundedPanoramaOffset(panoramaOffset + step, in: viewport)
                }
            }
            Spacer()
            if currentOffset > -travel + 1 {
                panoramaArrow("chevron.right", label: "查看右侧港城") {
                    panoramaOffset = boundedPanoramaOffset(panoramaOffset - step, in: viewport)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private func panoramaArrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.25), action)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 40, height: 56)
                .background(.black.opacity(0.24), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// Building labels, pinned in painting units (x across, y down, both in
    /// painting heights; see HarborPainting). The plaque's pin sits on the
    /// building, so the label is centred 20 pt above it.
    private func cityHotspots(in size: CGSize, panoramaWidth: CGFloat) -> some View {
        let painting = HarborPainting.rect(in: CGSize(width: panoramaWidth, height: size.height))
        func at(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: painting.minX + CGFloat(x) * painting.height, y: painting.minY + CGFloat(y) * painting.height - 20)
        }
        return ZStack {
            ForEach(HomeMapLayout.current.buildings, id: \.id) { building in
                CityLandmarkTag(title: building.id == "industry" ? "工业委员会" : building.name!, action: buildingAction(building.id!))
                    .position(at(building.at![0], building.at![1]))
            }
        }
        .frame(width: panoramaWidth, height: size.height)
    }
    private func buildingAction(_ id: String) -> (() -> Void)? {
        switch id {
        case "church": serviceIsUnlocked(.church) ? onChurch : nil
        case "tavern": serviceIsUnlocked(.church) && path?.id == .fool ? onBountyTavern : nil
        case "industry": onBuild
        case "newspaper": onNewspaper
        case "cityhall", "police", "post", "clinic", "harbor", "oldstreet", "board", "cafe": { onCounter(id) }
        default: nil
        }
    }
    private func center(_ x: Double, in viewport: CGSize) {
        let width = panoramaWidth(for: viewport)
        withAnimation(.easeOut(duration: 0.4)) { panoramaOffset = boundedPanoramaOffset(width / 2 - x * viewport.height, in: viewport) }
    }
    private func taskStrip(in viewport: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Button(trackedTarget?.title ?? nextMissionTitle) {
                    if let target = trackedTarget { center(HomeMapLayout.current.targetPoint(target)[0], in: viewport) }
                    else { onStory() }
                }.lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                Button { tasksExpanded.toggle() } label: { Image(systemName: tasksExpanded ? "chevron.up" : "chevron.down").frame(width: 44, height: 36) }
                    .accessibilityLabel(tasksExpanded ? "收起当前任务" : "展开当前任务，\(streetTargets.count)个目标")
            }
            if tasksExpanded {
                Button("主线 · " + nextMissionTitle, action: onStory)
                ForEach(streetTargets) { target in
                    Button(target.title) { trackedTargetID = target.id; center(HomeMapLayout.current.targetPoint(target)[0], in: viewport) }
                }
            }
            if let target = trackedTarget {
                let x = HomeMapLayout.current.targetPoint(target)[0]
                let width = panoramaWidth(for: viewport)
                let screen = viewport.width / 2 - width / 2 + boundedPanoramaOffset(panoramaOffset + panoramaDrag, in: viewport) + x * viewport.height
                if screen < 0 || screen > viewport.width {
                    Button { center(x, in: viewport) } label: { Label("任务目标在\(screen < 0 ? "左" : "右")侧", systemImage: screen < 0 ? "arrow.left" : "arrow.right") }
                }
            }
        }.font(.caption).foregroundStyle(.white).padding(.horizontal, 10)
            .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 10))
    }

}

private struct CityStatusHUD: View {
    @AppStorage("mistport.player.display-name", store: .standard) private var playerName = ""
    @State private var isExpanded = false
    let path: Pathway?
    let sequence: Int
    let districtName: String
    let reputation: Int
    let coins: Int
    let materials: Int
    let clues: Int
    let ingredientCount: Int
    let onSettings: () -> Void
    let onTest: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isExpanded {
                expandedContent
                    .frame(maxWidth: .infinity)
            } else {
                compactContent
                    .frame(width: 92)
            }
            if !isExpanded { Spacer(minLength: 0) }
        }
        .animation(.easeInOut(duration: 0.24), value: isExpanded)
    }

    private var compactContent: some View {
        Button {
            isExpanded = true
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 2) {
                    Text(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? (path?.name ?? "旅人") : playerName)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                HStack(spacing: 4) {
                    Image("RewardCoin").resizable().scaledToFit().frame(width: 17, height: 17)
                    Text("\(coins)")
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .lineLimit(1)
                }
                Text("点按展开")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .cityStatusPanel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("玩家信息，铜币 \(coins)，点按展开")
    }

    private var expandedContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 22, height: 40)
                }
                .accessibilityLabel("收起玩家信息")
                VStack(alignment: .leading, spacing: 3) {
                    Text(playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                         ? (path?.name ?? "旅人") : playerName)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .lineLimit(1)
                    Text("\(path?.name ?? "未定路径") · 序列 \(sequence) · \(districtName)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                if let onTest {
                    Button(action: onTest) {
                        Image(systemName: "wrench.and.screwdriver")
                            .frame(width: 40, height: 40)
                    }.accessibilityLabel("测试")
                }
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }.accessibilityLabel("设置")
            }
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            HStack(spacing: 6) {
                WalletChip(asset: "RewardCoin", label: "铜币", value: coins)
                WalletChip(asset: "RewardMaterial", label: "材料", value: materials)
                WalletChip(asset: "RewardReputation", label: "线索", value: clues)
                WalletChip(asset: "GameNavChurch", label: "演证", value: ingredientCount)
                VStack(spacing: 2) {
                    Text("声望").font(.system(size: 9))
                    Text("\(reputation) · 门槛100").font(.system(size: 11, weight: .bold).monospacedDigit())
                        .lineLimit(1).minimumScaleFactor(0.7)
                }.frame(maxWidth: .infinity).foregroundStyle(.yellow)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.65))
        .padding(12)
        .cityStatusPanel()
    }
}

private extension View {
    func cityStatusPanel() -> some View {
        self
            .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.65))
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [.black.opacity(0.78), .black.opacity(0.60)], startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16).stroke(.yellow.opacity(0.4), lineWidth: 1)
            }
    }
}

private struct WalletChip: View {
    let asset: String
    let label: String
    let value: Int

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(asset).resizable().scaledToFit().frame(width: 17, height: 17)
                Text("\(value)")
                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            Text(label).font(.system(size: 9)).foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

private struct CityMissionStrip: View {
    let tint: Color
    let districtName: String
    let missionTitle: String
    let progress: Int
    /// Replaces the mission count line when set.
    var detail: String? = nil
    let action: () -> Void
    private let brass = Color(red: 0.65, green: 0.49, blue: 0.28)

    var body: some View {
        Button(action: { GameInterfaceSound.shared.playClick(); action() }) {
            HStack(spacing: 11) {
                Image("CityMissionWaxSeal")
                    .resizable().scaledToFit().frame(width: 43, height: 43)
                    .saturation(0.65).brightness(-0.10)
                    .shadow(color: .black.opacity(0.65), radius: 2, y: 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(districtName).font(.system(size: 10, weight: .semibold, design: .serif)).foregroundStyle(brass)
                    Text(missionTitle).font(.system(size: 14, weight: .bold, design: .serif)).lineLimit(1).foregroundStyle(Color(red: 0.94, green: 0.88, blue: 0.73))
                    Text(detail ?? "已完成  \(min(progress, GameStore.playerTestMissionLimit)) / \(GameStore.playerTestMissionLimit)  关").font(.system(size: 10)).lineLimit(1).foregroundStyle(.white.opacity(0.48))
                }
                Spacer(minLength: 0)
                VStack(spacing: 3) {
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold))
                    Text("前往").font(.system(size: 10, weight: .bold, design: .serif))
                }.foregroundStyle(Color(red: 0.88, green: 0.76, blue: 0.51)).frame(width: 40, height: 44)
                .background(LinearGradient(colors: [brass.opacity(0.25), .black.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                .overlay(Rectangle().stroke(brass.opacity(0.5), lineWidth: 1))
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
            .background {
                ZStack {
                    Color(red: 0.055, green: 0.067, blue: 0.10)
                    LinearGradient(colors: [brass.opacity(0.18), .clear, .black.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .overlay(Rectangle().stroke(LinearGradient(colors: [brass, Color(red: 0.22, green: 0.17, blue: 0.12), brass.opacity(0.75)], startPoint: .top, endPoint: .bottom), lineWidth: 3))
            .overlay(Rectangle().stroke(brass.opacity(0.35), lineWidth: 1).padding(5))
            .overlay {
                VStack { HStack { rivet; Spacer(); rivet }; Spacer(); HStack { rivet; Spacer(); rivet } }.padding(3)
            }
            .shadow(color: .black.opacity(0.65), radius: 8, y: 5)
        }.buttonStyle(.plain).frame(maxWidth: .infinity)
    }
    private var rivet: some View {
        Circle().fill(brass).frame(width: 5, height: 5).shadow(color: .black, radius: 1, y: 1)
    }
}

private struct CityBottomBar: View {
    var bottomInset: CGFloat = 8
    var churchUnlocked = false
    var storeUnlocked = false
    let onWork: () -> Void
    let onChurch: () -> Void
    let onStore: () -> Void
    let onProfile: () -> Void
    let onInventory: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            CityBarButton(title: "角色", artName: "GameNavProfile", artScale: 0.88, action: onProfile)
            // The workbench art is a dense, square object; shown at full size it reads larger than its neighbours.
            CityBarButton(title: "百工坊", artName: "GameNavWorkshop", artScale: 0.84, action: onWork)
            CityBarButton(title: "教会", artName: "GameNavChurch", isLocked: !churchUnlocked, artScale: 0.88, action: onChurch)
            CityBarButton(title: "商店", artName: "GameNavStore", isLocked: !storeUnlocked, artScale: 0.88, action: onStore)
            CityBarButton(title: "行囊", artName: "GameNavInventory", artScale: 0.88, action: onInventory)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 22)
        .padding(.top, 11)
        .padding(.bottom, bottomInset)
        .background {
            LinearGradient(colors: [Color(red: 0.13, green: 0.13, blue: 0.30).opacity(0.65), Color(red: 0.09, green: 0.08, blue: 0.22).opacity(0.9)], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.23)).frame(height: 1) }
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
    }
}

struct ChurchPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.07, blue: 0.15), Color(red: 0.10, green: 0.08, blue: 0.20)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Spacer()
                    Button("关闭", action: { dismiss() })
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer()

                Image("GameNavChurch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .shadow(color: Color.blue.opacity(0.34), radius: 18)

                Text("星辉教会")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color(red: 0.92, green: 0.80, blue: 0.55))

                Text("祷告厅尚未开放")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.82))

                Text("祝福、忏悔与教会委托将在这里开启。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}

private struct CityBarButton: View {
    let title: String
    let artName: String
    var isLocked = false
    var artScale: CGFloat = 1
    let action: () -> Void

    var body: some View {
        Button(action: { GameInterfaceSound.shared.playClick(); action() }) {
            VStack(spacing: 1) {
                ZStack {
                    Image(artName + "Anime")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 62 * artScale, height: 62 * artScale)
                        .shadow(color: Color.indigo.opacity(0.45), radius: 4, y: 2)
                        .opacity(0.94)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity).frame(height: 64)
                Text(isLocked ? "🔒 " + title : title)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.65), radius: 2, y: 1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .saturation(isLocked ? 0 : 1)
        .opacity(isLocked ? 0.42 : 1)
        .accessibilityHint(isLocked ? "尚未开放，随主线推进解锁" : "")
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
    }
}

private struct NavIconCloud: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(.white.opacity(0.24))
                .frame(width: 70, height: 29)
                .blur(radius: 12)
                .offset(y: 8)
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 39, height: 39)
                .blur(radius: 10)
                .offset(x: -18, y: 1)
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 34, height: 34)
                .blur(radius: 9)
                .offset(x: 19, y: 3)
        }
        .allowsHitTesting(false)
    }
}

private struct CityLandmarkTag: View {
    let title: String
    var action: (() -> Void)? = nil

    var body: some View {
        Group {
            if let action {
                Button {
                    GameInterfaceSound.shared.playClick()
                    action()
                } label: {
                    label
                }
                .buttonStyle(.plain)
            } else {
                label
            }
        }
        .accessibilityLabel(title)
    }

    private var label: some View {
        CityLandmarkPlaque(title: title, enterable: action != nil)
    }
}

enum HubFeatureKind {
    case profile
    case build
    case advancement
    case inventory

    var title: String {
        switch self {
        case .profile: "路径档案"
        case .build: "作战构筑"
        case .advancement: "晋阶仪式"
        case .inventory: "补给与背包"
        }
    }

    var emblem: GameEmblem {
        switch self {
        case .profile: .profile
        case .build: .build
        case .advancement: .advancement
        case .inventory: .inventory
        }
    }
}

struct HubFeatureView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: HubFeatureKind
    let game: GameStore

    @State private var inventoryCategory: InventoryCategory = .all
    @State private var selectedInventoryItemID: String?
    @State private var inventoryDetailRequest = 0
    @State private var buildStep: BuildSetupStep = MPCChapterOneCatalog.relicsEnabled ? .relics : .passives
    @State private var selectedBuildDetail: BuildDetailItem?
    @State private var showsFoolGuide = false

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                Image(decorative: backgroundArt)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            LinearGradient(
                colors: kind == .inventory
                    ? [.black.opacity(0.10), .black.opacity(0.24)]
                    : [.black.opacity(0.20), .black.opacity(0.58), .black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 12) {
                    featureHeader
                    featureContent
                }
                .padding(.horizontal, kind == .inventory ? 26 : 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .onChange(of: inventoryDetailRequest) { _, _ in
                withAnimation { reader.scrollTo("inventory-selected-detail", anchor: .bottom) }
            }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .sheet(item: $selectedBuildDetail) { item in
            BuildDetailSheet(item: item)
        }
        .sheet(isPresented: $showsFoolGuide) {
            FoolPathGuideView()
        }
    }

    private var backgroundArt: String {
        switch kind {
        case .profile: game.selectedPath?.artName ?? "MistportCityHub"
        case .build: "SceneClockDistrictV2"
        case .advancement: "SceneMirrorTheater"
        case .inventory: "SceneInventoryCelestialArchive"
        }
    }

    private var featureHeader: some View {
        HStack(spacing: 11) {
            GameEmblemView(emblem: kind.emblem, tint: .yellow)
                .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.title)
                    .font(.title3.bold())
                Text(kind == .inventory ? "随旅途收集 · 留存每一份所得" : "雾岬序列系统")
                    .font(.caption2)
                    .foregroundStyle(kind == .inventory ? InventoryPalette.ink.opacity(0.65) : .white.opacity(0.58))
            }
            Spacer()
            if kind == .build {
                Button(action: { showsFoolGuide = true }) {
                    Text("🔍 愚者攻略")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.purple.opacity(0.62), in: HexActionShape())
                }
                .buttonStyle(.plain)
            }
            MistportPlaqueButton(title: "返回", compact: true, expands: false, action: { dismiss() })
        }
        .padding(12)
        .foregroundStyle(kind == .inventory ? InventoryPalette.ink : .white)
        .background(kind == .inventory ? InventoryPalette.surface : .black.opacity(0.70), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.yellow.opacity(0.22), lineWidth: 1) }
    }

    @ViewBuilder
    private var featureContent: some View {
        switch kind {
        case .profile:
            profileContent
        case .build:
            buildContent
        case .advancement:
            advancementContent
        case .inventory:
            inventoryContent
        }
    }

    private var profileContent: some View {
        VStack(spacing: 10) {
            FeatureStatPlate(
                title: game.selectedPath?.name ?? "未选择路径",
                subtitle: "序列 \(game.displayedSequence) · 最大生命 \(game.chapterOneCampaign.party.playerMaxHP)",
                symbol: game.selectedPath?.symbol ?? "sparkles",
                tint: game.selectedPath?.tint ?? .purple
            )
            FeatureStatPlate(title: "区域进度", subtitle: "\(game.selectedChapterDistrict.name) · \(min(GameStore.playerTestMissionLimit, game.completedMissionCount(in: game.selectedChapterDistrict)))/\(GameStore.playerTestMissionLimit)", symbol: "map.fill", tint: .cyan)
            FeatureStatPlate(title: "路径原则", subtitle: game.selectedPath?.abilityName ?? "尚未觉醒", symbol: "quote.bubble.fill", tint: .yellow)
        }
    }

    private var buildContent: some View {
        VStack(spacing: 14) {
            BuildSetupSummary(game: game)
            BuildStepPicker(selection: $buildStep)

            Group {
                switch buildStep {
                case .relics:
                    VStack(alignment: .leading, spacing: 10) {
                        BuildStepIntroduction(
                            number: 1,
                            title: "选择两件遗落物",
                            detail: "I 槽决定主要战斗特性，II 槽补足生存或控制。两槽不能装备同一件。",
                            tint: .cyan
                        )
                        LazyVGrid(columns: buildGridColumns, spacing: 10) {
                            ForEach(CharacterLoadoutCatalog.foolWeapons) { relic in
                                RelicLoadoutPlate(
                                    relic: relic,
                                    progress: game.completedMissionCount(in: game.selectedChapterDistrict),
                                    testAccess: game.hasFoolTestAccess,
                                    primarySelected: game.equippedWeaponID == relic.id,
                                    secondarySelected: game.equippedSecondaryRelicID == relic.id,
                                    onInspect: { selectedBuildDetail = .relic(relic) },
                                    onPrimary: { game.equipWeapon(relic.id) },
                                    onSecondary: { game.equipSecondaryRelic(relic.id) }
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                case .passives:
                    VStack(alignment: .leading, spacing: 10) {
                        BuildStepIntroduction(
                            number: 2,
                            title: "选择两个被动",
                            detail: "被动会持续改变整场战斗。选择第三项时，会自动替换最早装配的一项。",
                            tint: .purple
                        )
                        LazyVGrid(columns: buildGridColumns, spacing: 10) {
                            ForEach(CharacterLoadoutCatalog.foolPassives) { passive in
                                PassiveLoadoutPlate(
                                    passive: passive,
                                    progress: game.completedMissionCount(in: game.selectedChapterDistrict),
                                    testAccess: game.hasFoolTestAccess,
                                    isSelected: game.selectedPassiveIDs.contains(passive.id),
                                    onInspect: { selectedBuildDetail = .passive(passive) },
                                    onToggle: { game.togglePassive(passive.id) }
                                )
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                case .tactics:
                    VStack(alignment: .leading, spacing: 10) {
                        BuildStepIntroduction(
                            number: 3,
                            title: "选择一套战术",
                            detail: "战术会一次配置被动、天赋和技能变体，适合快速开战，也可以继续手动微调。",
                            tint: .yellow
                        )
                        Text("本次携带技能")
                            .font(.headline.bold())
                            .padding(.horizontal, 8)
                        LazyVGrid(columns: buildGridColumns, spacing: 10) {
                            ForEach(game.configuredDungeonSkills) { skill in
                                BuildSkillPlate(skill: skill) {
                                    selectedBuildDetail = .skill(skill)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        ForEach(GameBuildPreset.allCases) { preset in
                            BuildPresetPlate(
                                preset: preset,
                                progress: game.completedMissionCount(in: game.selectedChapterDistrict),
                                testAccess: game.hasFoolTestAccess,
                                action: { game.applyBuildPreset(preset) }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BuildNavigationBar(
                step: buildStep,
                onRecommend: {
                    game.applyBuildPreset(.cardChain)
                    buildStep = .tactics
                },
                onBack: {
                    if let previous = BuildSetupStep(rawValue: buildStep.rawValue - 1), MPCChapterOneCatalog.relicsEnabled || previous != .relics {
                        buildStep = previous
                    }
                },
                onContinue: {
                    if let next = BuildSetupStep(rawValue: buildStep.rawValue + 1) {
                        buildStep = next
                    } else {
                        dismiss()
                    }
                }
            )

            if !game.featureMessage.isEmpty {
                FeatureMessageBanner(message: game.featureMessage)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var buildGridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    }

    private var advancementContent: some View {
        let completed = game.completedMissionCount(in: game.selectedChapterDistrict)
        return VStack(spacing: 10) {
            FeatureStatPlate(
                title: "晋阶主材",
                subtitle: game.chapterAdvancementIsReady
                    ? "三份主材齐备"
                    : "已取得 \(game.advancementIngredients.count)/3 · 缺 \(game.missingAdvancementIngredientNames.joined(separator: "、"))",
                symbol: "flask.fill",
                tint: .purple
            )
            ForEach(Array([GrowthMilestone.weaponResonance, .skillEvolution, .talentAwakening, .advancementProof].enumerated()), id: \.offset) { index, milestone in
                let threshold = (index + 1) * 5
                let unlocked = game.milestoneIsUnlocked(milestone, in: game.selectedChapterDistrict)
                FeatureStatPlate(
                    title: milestone.title,
                    subtitle: threshold > GameStore.playerTestMissionLimit ? "后续篇章开放" : (unlocked ? "已达成" : "完成本区任务 \(min(completed, threshold))/\(threshold)"),
                    symbol: milestone.symbol,
                    tint: unlocked ? .green : .yellow
                )
            }
            HStack(spacing: 12) {
                    GameEmblemView(emblem: .advancement, tint: .yellow)
                        .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(game.sequenceEightQualified ? "序列 8 已达成" : "举行序列 8 晋阶仪式")
                            .font(.headline)
                        Text("三份主材 + 晋阶演证 · 不依赖商店随机刷新")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    Text("仪式")
                        .font(.caption.bold())
                        .foregroundStyle(.yellow)
                        .frame(width: 58, height: 40)
                        .background(.black.opacity(0.74), in: HexActionShape())
                        .overlay { HexActionShape().stroke(.yellow.opacity(0.72), lineWidth: 1.4) }
                }
                .padding(13)
                .background(.black.opacity(0.80), in: RoundedRectangle(cornerRadius: 17))
                .overlay { RoundedRectangle(cornerRadius: 17).stroke(.yellow.opacity(0.55), lineWidth: 1) }
                .contentShape(RoundedRectangle(cornerRadius: 17))
                .onTapGesture(perform: game.performAdvancement)
            if !game.featureMessage.isEmpty {
                FeatureMessageBanner(message: game.featureMessage)
            }
        }
    }

    private var inventoryContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 0) {
                ForEach(InventoryCategory.allCases.filter { MPCChapterOneCatalog.relicsEnabled || game.chapterOneCampaign.ownsManualMask || game.chapterOneCampaign.ownsUsurpedLifeMedal || $0 != .relic }) { category in
                    InventoryCategoryButton(
                        category: category,
                        count: inventoryItems.filter { category == .all || $0.category == category }.count,
                        isSelected: inventoryCategory == category,
                        action: {
                            inventoryCategory = category
                            selectedInventoryItemID = inventoryItems.first { category == .all || $0.category == category }?.id
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .background(alignment: .bottom) { Rectangle().fill(InventoryPalette.ink.opacity(0.16)).frame(height: 1) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("物品分类")

            if filteredInventoryItems.isEmpty {
                InventoryEmptyState(category: inventoryCategory)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 4), spacing: 9) {
                    ForEach(filteredInventoryItems) { item in
                        InventorySlot(
                            item: item,
                            isSelected: selectedInventoryItem?.id == item.id,
                            action: {
                                selectedInventoryItemID = item.id
                                inventoryDetailRequest += 1
                            }
                        )
                    }
                    ForEach(0..<emptyInventorySlotCount, id: \.self) { _ in
                        InventoryEmptySlot()
                    }
                }

                if let item = selectedInventoryItem {
                    InventoryDetailPanel(item: item, action: { performInventoryAction(item) })
                        .id("inventory-selected-detail")
                }
            }
            if !game.featureMessage.isEmpty {
                FeatureMessageBanner(message: game.featureMessage)
            }
        }
        .onAppear {
            if selectedInventoryItemID == nil {
                selectedInventoryItemID = filteredInventoryItems.first?.id
            }
        }
    }

    private var inventoryItems: [InventoryDisplayItem] {
        let catalog = GameContent.oldClockVenues.flatMap(\.catalog)
        let venueItems = game.ownedVenueItems.keys.sorted().compactMap { itemID -> InventoryDisplayItem? in
            guard let item = catalog.first(where: { $0.id == itemID }) else { return nil }
            return InventoryDisplayItem(
                id: itemID,
                title: item.name,
                detail: item.detail,
                source: item.grantsAdvancementMaterial ? "午夜商店的隐秘货架" : "雾港商店补给",
                count: game.ownedVenueItems[itemID, default: 0],
                symbol: item.symbol,
                tint: item.rarity.tint,
                rarity: item.rarity.title,
                category: item.grantsAdvancementMaterial ? .material : .consumable,
                actionTitle: nil
            )
        }

        let ingredients = AdvancementIngredient.allCases.compactMap { ingredient -> InventoryDisplayItem? in
            guard game.advancementIngredients.contains(ingredient) else { return nil }
            return InventoryDisplayItem(
                id: "ingredient-\(ingredient.id)", title: ingredient.traitName,
                detail: ingredient.traitDetail, source: "首领析出 · \(ingredient.inventorySource)",
                count: 1, symbol: ingredient.inventorySymbol, tint: .purple,
                rarity: "首领遗痕", category: .material, actionTitle: nil
            )
        }

        let campaign = game.chapterOneCampaign
        let collected = campaign.inventory.keys.sorted().compactMap { id -> InventoryDisplayItem? in
            guard let count = campaign.inventory[id], count > 0 else { return nil }
            let item = MPCChapterOneCatalog.items.first { $0.id == id }
            let category: InventoryCategory
            switch item?.kind {
            case .consumable: category = .consumable
            case .material: category = .material
            case .currency: return nil
            default: category = .quest
            }
            let missions = MPCChapterOneCatalog.missions.filter {
                $0.rewardItemIDs.contains(id)
                    && game.completedChapterMissionIDs.contains("old-clock-\($0.number)")
            }
            let source = missions.isEmpty ? "已收入行囊" : missions.map {
                "第\($0.number)关 · \($0.name)"
            }.joined(separator: "；")
            let usage = id == "consumable_pain_salve" ? "\n进入战斗后，受伤时点击面板中的止痛膏使用。" : ""
            return InventoryDisplayItem(id: "campaign-item-" + id,
                title: item?.name ?? "未编目的物品", detail: (item?.description ?? "已保存此物品，详细资料待补充。") + usage,
                source: source, count: count, symbol: id == "consumable_pain_salve" ? "cross.case.fill" : (category == .quest ? "doc.text.fill" : category.symbol), tint: category.tint,
                rarity: category == .quest ? "剧情物证" : "关卡收集", category: category, actionTitle: nil)
        }
        let relics = campaign.ownedRelicIDs.sorted().compactMap { id -> InventoryDisplayItem? in
            guard MPCChapterOneCatalog.isRelicEnabled(id), let relic = MPCChapterOneCatalog.relics.first(where: { $0.id == id }) else { return nil }
            let rewardMission = MPCChapterOneCatalog.missions.first { mission in
                MPCChapterOneCatalog.encounters.contains {
                    $0.id == mission.encounterID && $0.firstClearRelicID == id
                }
            }
            let source = rewardMission.map { "第\($0.number)关 · \($0.name) · 首通获得" }
                ?? "已获得的遗落物"
            return InventoryDisplayItem(id: "campaign-relic-" + id,
                title: relic.name, detail: relic.mechanism + "\n代价：" + relic.cost + "\n" + relic.story + (id == MPCChapterOneCatalog.ownerlessMaskRelicID ? "\n永久裂纹：\(campaign.masqueradeCrackCount)/10" + (campaign.masqueradeCrackCount >= 10 ? " · 已失效" : "") : ""),
                source: id == MPCChapterOneCatalog.usurpedLifeMedalRelicID ? "第4关战后 · 奥黛尔定向交付" : id == MPCChapterOneCatalog.ownerlessMaskRelicID ? "第3关战前 · 玛拉赠予" : id == "relic_encore_bell" ? "第5关 · 邮差与玛拉移交异常物" : source,
                count: 1, symbol: "seal.fill", tint: .orange, rarity: "遗落物", category: .relic,
                actionTitle: [MPCChapterOneCatalog.ownerlessMaskRelicID, MPCChapterOneCatalog.usurpedLifeMedalRelicID].contains(id)
                    ? ((campaign.loadout.selectedActiveRelicID ?? MPCChapterOneCatalog.ownerlessMaskRelicID) == id ? "已选主动遗落物" : "选为主动遗落物")
                    : campaign.loadout.relicIDs.contains(id) ? "卸下" : "装配",
                maskCracks: id == MPCChapterOneCatalog.ownerlessMaskRelicID ? campaign.masqueradeCrackCount : 0)
        }
        return collected + relics + venueItems.filter { campaign.inventory[$0.id] == nil } + ingredients
    }

    private var filteredInventoryItems: [InventoryDisplayItem] {
        inventoryItems.filter { inventoryCategory == .all || $0.category == inventoryCategory }
    }

    private var selectedInventoryItem: InventoryDisplayItem? {
        filteredInventoryItems.first { $0.id == selectedInventoryItemID } ?? filteredInventoryItems.first
    }

    private var emptyInventorySlotCount: Int {
        guard !filteredInventoryItems.isEmpty else { return 0 }
        let remainder = filteredInventoryItems.count % 4
        return remainder == 0 ? 0 : 4 - remainder
    }

    private func performInventoryAction(_ item: InventoryDisplayItem) {
        if item.id.hasPrefix("campaign-relic-") {
            game.toggleCampaignRelic(String(item.id.dropFirst("campaign-relic-".count)))
        } else if item.category == .consumable {
            game.useInventoryItem(item.id)
        } else if item.category == .relic {
            game.equipWeapon(String(item.id.dropFirst("relic-".count)))
        }
    }
}

private enum InventoryCategory: String, CaseIterable, Identifiable {
    case all
    case consumable
    case material
    case relic
    case quest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .consumable: "补给"
        case .material: "素材"
        case .relic: "遗落物"
        case .quest: "剧情"
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2.fill"
        case .consumable: "flask.fill"
        case .material: "sparkles"
        case .relic: "seal.fill"
        case .quest: "book.closed.fill"
        }
    }

    var tint: Color {
        switch self {
        case .all: Color(red: 0.98, green: 0.78, blue: 0.05)
        case .consumable: Color(red: 0.02, green: 0.79, blue: 0.68)
        case .material: Color(red: 0.82, green: 0.18, blue: 0.88)
        case .relic: Color(red: 1.00, green: 0.48, blue: 0.08)
        case .quest: Color(red: 0.06, green: 0.72, blue: 0.84)
        }
    }
}

private struct InventoryDisplayItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let source: String
    let count: Int
    let symbol: String
    let tint: Color
    let rarity: String
    let category: InventoryCategory
    let actionTitle: String?
    var maskCracks: Int = 0

    var artName: String? {
        chapterOneInventoryArtName(id)
    }
}

/// Shared bitmap artwork for the bag and the victory receipt. Evidence is
/// selected by its stable item ID, so a later translated name cannot turn an
/// earned clue into the generic blue material icon.
func chapterOneInventoryArtName(_ id: String) -> String? {
        if id.hasPrefix("campaign-relic-") {
            let relicID = String(id.dropFirst("campaign-relic-".count))
            if EarlyRelicShop.ids.contains(relicID) { return EarlyRelicShop.art(relicID) }
        }
        return switch id {
        case "campaign-relic-relic_usurped_life_medal": "IconRelicUsurpedLifeMedal"
        case "campaign-relic-relic_ownerless_mask": "IconRelicOwnerlessMask"
        case "campaign-relic-relic_encore_bell": "ItemEncoreBellCutout"
        case "campaign-relic-relic_paper_raincoat": "IconRelicPaperDouble"
        case "campaign-relic-relic_trimmed_nameplate": "IconRelicTrimmedNameplate"
        case "campaign-relic-relic_unified_gear": "IconRelicThreeProofRing"
        case "campaign-relic-relic_nameless_seal": "IconRelicNamelessSeal"
        case "campaign-item-consumable_pain_salve": "ItemPainSalve"
        case "campaign-item-chapter30_e03", "campaign-item-chapter30_e21": "ItemEvidenceCollar"
        case "campaign-item-chapter30_e06", "campaign-item-chapter30_e23", "campaign-item-chapter30_e31", "campaign-item-evidence_missing_register", "campaign-item-evidence_family_dossier": "ItemEvidenceRegistry"
        case "campaign-item-chapter30_e20", "campaign-item-chapter30_e30", "campaign-item-chapter30_e35", "campaign-item-evidence_belonging_threads": "ItemEvidenceThread"
        case "campaign-item-chapter30_e22", "campaign-item-chapter30_e25", "campaign-item-chapter30_e26", "campaign-item-chapter30_e28", "campaign-item-chapter30_e34", "campaign-item-chapter30_e37": "ItemEvidenceRoute"
        case "campaign-item-chapter30_e36": "ItemEvidenceKey"
        case "campaign-item-chapter30_p04_personal_proof", "campaign-item-chapter30_u01_needle_permit", "campaign-item-chapter30_u02_church_continuation": "ItemEvidenceKey"
        case "campaign-item-chapter30_p05_paradox_proof", "campaign-item-chapter30_p06_ownerless_echo": "ItemEvidenceThread"
        case "campaign-item-chapter30_e05": "ItemLateSecondWatch"
        case "campaign-item-chapter30_e10", "campaign-item-key_thirteenth_recording": "ItemMemoryFilament"
        case "campaign-item-chapter30_e14", "campaign-item-chapter30_e33": "ItemClockCoffee"
        case "campaign-item-chapter30_e08", "campaign-item-chapter30_e27", "campaign-item-chapter30_e32": "ItemOldClockPass"
        case "campaign-item-chapter30_e02", "campaign-item-chapter30_e16", "campaign-item-chapter30_e24", "campaign-item-chapter30_e29", "campaign-item-evidence_delivery_stub", "campaign-item-evidence_testimony_versions", "campaign-item-evidence_transfer_order": "ItemSealedTransfer"
        case "campaign-item-item_blank_identity": "ItemOldClockPass"
        case "campaign-item-item_tracking_module": "ItemHoundTrace"
        case "campaign-item-evidence_nameplate_box": "ItemOldClockPass"
        case "campaign-item-item_old_clock_pass": "ItemOldClockPass"
        case "campaign-item-item_late_second_watch": "ItemLateSecondWatch"
        case "campaign-item-item_hound_trace": "ItemHoundTrace"
        case "campaign-item-item_sealed_transfer": "ItemSealedTransfer"
        case "campaign-item-consumable_mirror_salve": "ItemMirrorSalve"
        case "campaign-item-consumable_salt_tea": "ItemSaltTea"
        case "campaign-item-consumable_clock_key": "ItemEvidenceKey"
        case "campaign-item-item_memory_filament", "campaign-item-material_memory_filament": "ItemMemoryFilament"
        case "campaign-item-material_clock_bronze": "ItemOwnerlessSpring"
        case "campaign-item-material_skill_dust": "RewardMaterial"
        case "campaign-item-material_shield_jaw_hide": "ItemShieldJawHide"
        case "campaign-item-crafted_repair_strap": "ItemRepairStrap"
        case "clock-coffee": "ItemClockCoffee"
        case "fog-sugar": "ItemFogSugar"
        case "rain-rumor": "ItemRainRumor"
        case "memory-bean": "ItemMemoryBean"
        case "ownerless-spring": "ItemOwnerlessSpring"
        case "off-menu-note": "ItemSealedTransfer"
        case "ingredient-ownerless-spring": "ItemOwnerlessSpring"
        default: nil
        }
}

private enum InventoryQuestItem: String, CaseIterable {
    case thirteenthChime
    case erasedName
    case councilCipher
    case silentBallot

    var unlockAt: Int {
        switch self {
        case .thirteenthChime: 5
        case .erasedName: 10
        case .councilCipher: 15
        case .silentBallot: 20
        }
    }

    var title: String {
        switch self {
        case .thirteenthChime: "第十三声录音蜡片"
        case .erasedName: "被擦除的钟匠名牌"
        case .councilCipher: "归一议会密钥残页"
        case .silentBallot: "无声表决票"
        }
    }

    var detail: String {
        switch self {
        case .thirteenthChime: "记录了正常十二响之后，多出的一次不存在的钟声。"
        case .erasedName: "名牌正面被刮去，背面残留无冕议长的祷词缩写。"
        case .councilCipher: "可译出议会在旧城区布置的三处校正节点。"
        case .silentBallot: "首领战后取得；证明整起钟灾是一场献给造物主的演证。"
        }
    }

    var source: String {
        switch self {
        case .thirteenthChime: "钟楼失声"
        case .erasedName: "无名钟匠"
        case .councilCipher: "密室校时"
        case .silentBallot: "归一档案库"
        }
    }

    var symbol: String {
        switch self {
        case .thirteenthChime: "waveform.badge.magnifyingglass"
        case .erasedName: "person.text.rectangle.fill"
        case .councilCipher: "key.fill"
        case .silentBallot: "doc.text.fill"
        }
    }
}

private extension AdvancementIngredient {
    var inventorySymbol: String {
        switch self {
        case .mirrorMothScale: "aqi.medium"
        case .reverseClockEssence: "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .ownerlessMaskWax: "theatermasks.fill"
        }
    }

    var inventoryDetail: String {
        switch self {
        case .mirrorMothScale: "首领遗痕·欺光视界：稳定晋阶后的灵性视野，识别伪装与残影。"
        case .reverseClockEssence: "首领遗痕·逆时锚髓：从逆走钟芯析出，承担晋阶仪式的时间锚点。"
        case .ownerlessMaskWax: "首领遗痕·空名蜡印：抹去旧身份回声，为新能力提供稳定容器。"
        }
    }

    var inventorySource: String {
        switch self {
        case .mirrorMothScale: "任务 8 · 镜蛾温室"
        case .reverseClockEssence: "任务 15 · 逆走机芯"
        case .ownerlessMaskWax: "任务 19 · 无主印章"
        }
    }
}

private extension CharacterWeaponDefinition {
    var buildArtName: String {
        switch id {
        case "silver-lie-blade": "IconRelicOwnerlessMask"
        case "paper-moon-token": "IconRelicPaperMoon"
        case "mirror-card-case": "IconRelicMirrorCase"
        case "backward-watch": "IconRelicBackwardWatch"
        default: "IconRelicOwnerlessMask"
        }
    }

    var inventorySymbol: String {
        switch id {
        case "silver-lie-blade": "theatermasks.fill"
        case "paper-moon-token": "moon.stars.fill"
        case "mirror-card-case": "rectangle.stack.fill"
        case "backward-watch": "pocketwatch.fill"
        default: "seal.fill"
        }
    }
}

private extension CharacterPassiveDefinition {
    var buildArtName: String {
        switch id {
        case "marked-deck": "IconSkillWeakness"
        case "false-exit": "IconSkillSpiritualDodge"
        case "borrowed-name": "IconSkillDivination"
        case "last-applause": "IconSkillOmenRecord"
        default: "IconSkillDangerPremonition"
        }
    }
}

private extension DungeonSkillDefinition {
    var buildArtName: String {
        switch id {
        case .strike: "IconSkillWeakness"
        case .mobility: "IconSkillSpiritualDodge"
        case .control: "IconSkillDivination"
        case .ward: "IconSkillDangerPremonition"
        case .ultimate: "IconSkillOmenRecord"
        }
    }
}

private struct BuildDetailItem: Identifiable {
    let id: String
    let category: String
    let name: String
    let artName: String
    let summary: String
    let rows: [(String, String)]
    let usage: String
    let tint: Color

    static func relic(_ relic: CharacterWeaponDefinition) -> Self {
        .init(
            id: "relic-\(relic.id)", category: "遗落物", name: relic.name,
            artName: relic.buildArtName, summary: relic.effect,
            rows: [("战力", "+\(relic.power)"), ("装配", "I / II 槽"), ("解锁", relic.unlockAt == 0 ? "初始可用" : "任务 \(relic.unlockAt)")],
            usage: relic.detailUsage, tint: relic.color
        )
    }

    static func passive(_ passive: CharacterPassiveDefinition) -> Self {
        .init(
            id: "passive-\(passive.id)", category: "被动能力", name: passive.name,
            artName: passive.buildArtName, summary: passive.effect,
            rows: [("类型", "常驻生效"), ("上限", "装配 2 项"), ("解锁", passive.unlockAt == 0 ? "初始可用" : "任务 \(passive.unlockAt)")],
            usage: passive.detailUsage, tint: passive.color
        )
    }

    static func skill(_ skill: DungeonSkillDefinition) -> Self {
        .init(
            id: "skill-\(skill.id.rawValue)", category: "愚者战斗技能", name: skill.name,
            artName: skill.buildArtName, summary: skill.skillSummary,
            rows: [("伤害", "\(skill.damage)"), ("冷却", "\(Int(skill.cooldown)) 回合"), ("范围", "\(Int(skill.radius))")],
            usage: skill.skillUsage, tint: skill.tint
        )
    }
}

private extension CharacterWeaponDefinition {
    var detailUsage: String {
        switch id {
        case "silver-lie-blade": "保命型遗落物。预判首领爆发失败时仍能用替身承受一次重伤，适合尚未熟悉预兆机制的玩家。"
        case "paper-moon-token": "控制型遗落物。与简易占卜、危险预感配合，先削减敌方意志，再打断蓄力或延长其失衡窗口。"
        case "mirror-card-case": "输出型遗落物。强化卡牌的射程与弹射，面对多目标波次时收益最高。"
        default: "循环型遗落物。成功闪避后加速技能周转，适合熟悉敌方行动顺序的玩家。"
        }
    }
}

private extension CharacterPassiveDefinition {
    var detailUsage: String {
        switch id {
        case "marked-deck": "稳定提高攻击技能伤害，适合快速清理普通波次。"
        case "false-exit": "缩短应变技能冷却，让灵性闪避更频繁地处理虚假连击。"
        case "borrowed-name": "强化控场与削韧，面对精英和首领的蓄力阶段更有效。"
        default: "提高终结技伤害，适合在失衡窗口集中爆发。"
        }
    }
}

private extension DungeonSkillDefinition {
    var skillSummary: String {
        switch id {
        case .strike: "识破破绽后掷出影牌，造成稳定单体伤害。"
        case .mobility: "根据预兆回避攻击；若识破虚假连击，可避开整段伤害。"
        case .control: "扰乱敌方行动并削减意志，为下一次爆发创造窗口。"
        case .ward: "读取危险征兆，获得防护并揭示敌人的下一步意图。"
        case .ultimate: "结算已记录的预兆，对失衡目标造成高额终结伤害。"
        }
    }

    var skillUsage: String {
        switch id {
        case .strike: "无高危预兆时使用。冷却短，是自动战斗的基础填充技能。"
        case .mobility: "看到“虚假攻击”或连续攻击预兆时保留使用，不要一亮就交。"
        case .control: "优先对正在蓄力、意志较低或即将进入强化阶段的敌人使用。"
        case .ward: "不确定敌方行动时先读取预兆；它会帮助自动策略选择后续技能。"
        case .ultimate: "留到敌人失衡、标记充足或进入首领易伤阶段再释放。"
        }
    }
}

private enum BuildSetupStep: Int, CaseIterable, Identifiable {
    case relics
    case passives
    case tactics

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .relics: "遗落物"
        case .passives: "被动"
        case .tactics: "战术"
        }
    }

    var artName: String {
        switch self {
        case .relics: "IconRelicMirrorCase"
        case .passives: "IconSkillOmenRecord"
        case .tactics: "IconSkillDivination"
        }
    }

    var tint: Color {
        switch self {
        case .relics: .cyan
        case .passives: .purple
        case .tactics: .yellow
        }
    }
}

private struct BuildSetupSummary: View {
    let game: GameStore

    private var relicCount: Int {
        [game.equippedWeaponID, game.equippedSecondaryRelicID]
            .filter { !$0.isEmpty }
            .count
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("本次出战配置")
                    .font(.headline.bold())
                Text("被动 \(game.selectedPassiveIDs.count)/2 · 战术 1/1")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("最大生命")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                Text("\(game.chapterOneCampaign.party.playerMaxHP)")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(.yellow)
            }
        }
        .padding(14)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.cyan.opacity(0.35), lineWidth: 1) }
    }
}

private struct BuildStepPicker: View {
    @Binding var selection: BuildSetupStep

    var body: some View {
        HStack(spacing: 8) {
            ForEach(BuildSetupStep.allCases.filter { MPCChapterOneCatalog.relicsEnabled || $0 != .relics }) { step in
                Button {
                    withAnimation(.snappy(duration: 0.24)) { selection = step }
                } label: {
                    VStack(spacing: 4) {
                        Image(decorative: step.artName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 38, height: 38)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(step.tint.opacity(selection == step ? 0.95 : 0.28), lineWidth: selection == step ? 2 : 1)
                            }
                        Text(step.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(selection == step ? .white : .white.opacity(0.52))
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .contentShape(Rectangle())
                    .background(
                        selection == step ? step.tint.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("第 \(step.rawValue + 1) 步，\(step.title)")
            }
        }
        .padding(7)
        .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.10), lineWidth: 1) }
    }
}

private struct BuildStepIntroduction: View {
    let number: Int
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(tint)
                .frame(width: 4, height: 45)
                .shadow(color: tint.opacity(0.8), radius: 5)
            VStack(alignment: .leading, spacing: 4) {
                Text("第\(number)式 · \(title)")
                    .font(.title3.bold())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct BuildNavigationBar: View {
    let step: BuildSetupStep
    let onRecommend: () -> Void
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            Button(action: onRecommend) {
                Text("推荐配置 · 幻牌连锁")
                .font(.caption.bold())
                .foregroundStyle(.yellow)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(.yellow.opacity(0.10), in: HexActionShape())
                .overlay { HexActionShape().stroke(.yellow.opacity(0.48), lineWidth: 1) }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                if step != (MPCChapterOneCatalog.relicsEnabled ? .relics : .passives) {
                    Button("上一步", action: onBack)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 94)
                        .frame(minHeight: 46)
                        .background(.white.opacity(0.10), in: HexActionShape())
                        .buttonStyle(.plain)
                }
                MistportPlaqueButton(title: step == .tactics ? "完成配置" : "下一步", action: onContinue)
            }
        }
        .padding(12)
        .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.10), lineWidth: 1) }
    }
}

private struct RelicLoadoutPlate: View {
    let relic: CharacterWeaponDefinition
    let progress: Int
    let testAccess: Bool
    let primarySelected: Bool
    let secondarySelected: Bool
    let onInspect: () -> Void
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    private var unlocked: Bool { testAccess || progress >= relic.unlockAt }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button(action: onInspect) {
                VStack(alignment: .leading, spacing: 7) {
                    Image(decorative: relic.buildArtName)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 78)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(alignment: .bottomLeading) {
                            LinearGradient(colors: [.clear, .black.opacity(0.82)], startPoint: .top, endPoint: .bottom)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    Text(relic.name).font(.caption.bold())
                    Text(unlocked ? relic.effect : "任务 \(progress)/\(relic.unlockAt)")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .buttonStyle(.plain)
            HStack(spacing: 6) {
                LoadoutSlotButton(title: "I", selected: primarySelected, enabled: unlocked, action: onPrimary)
                LoadoutSlotButton(title: "II", selected: secondarySelected, enabled: unlocked, action: onSecondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 154)
        .background(.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(relic.color.opacity(primarySelected || secondarySelected ? 0.8 : 0.22), lineWidth: 1) }
    }
}

private struct LoadoutSlotButton: View {
    let title: String
    let selected: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(selected ? "槽 \(title) ✓" : "装入 \(title)")
                .font(.system(size: 10, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 42)
                .foregroundStyle(selected ? Color(red: 0.12, green: 0.11, blue: 0.15) : .white.opacity(enabled ? 0.82 : 0.35))
                .background {
                    Image("ButtonArt27LoadoutSlot")
                        .resizable(capInsets: EdgeInsets(top: 32, leading: 42, bottom: 32, trailing: 42), resizingMode: .stretch)
                        .accessibilityHidden(true)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled || selected)
    }
}

private struct PassiveLoadoutPlate: View {
    let passive: CharacterPassiveDefinition
    let progress: Int
    let testAccess: Bool
    let isSelected: Bool
    let onInspect: () -> Void
    let onToggle: () -> Void

    private var unlocked: Bool { testAccess || progress >= passive.unlockAt }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button(action: onInspect) {
                VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(decorative: passive.buildArtName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay { RoundedRectangle(cornerRadius: 8).stroke(passive.color.opacity(0.7), lineWidth: 1) }
                    Spacer()
                    Text("点击查看")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.52))
                }
                Text(passive.name).font(.caption.bold())
                Text(unlocked ? passive.effect : "任务 \(progress)/\(passive.unlockAt)")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
                }
            }
            .buttonStyle(.plain)
            Button(action: onToggle) {
                Text(isSelected ? "已装配 · 点击卸下" : unlocked ? "装配" : "未解锁")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? .black : .white.opacity(unlocked ? 0.85 : 0.35))
                    .frame(maxWidth: .infinity, minHeight: 27)
                    .background(isSelected ? .yellow : .white.opacity(0.09), in: HexActionShape())
            }
            .buttonStyle(.plain)
            .disabled(!unlocked)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .leading)
        .background(.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).stroke(passive.color.opacity(isSelected ? 0.9 : 0.22), lineWidth: isSelected ? 2 : 1) }
    }
}

private struct BuildSkillPlate: View {
    let skill: DungeonSkillDefinition
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Image(decorative: skill.buildArtName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                Text(skill.name)
                    .font(.caption.bold())
                Text("伤害 \(skill.damage) · 冷却 \(Int(skill.cooldown)) 回合")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 15))
            .overlay { RoundedRectangle(cornerRadius: 15).stroke(skill.tint.opacity(0.60), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

private struct BuildDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: BuildDetailItem

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, item.tint.opacity(0.32), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Image(decorative: item.artName)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay { RoundedRectangle(cornerRadius: 22).stroke(item.tint.opacity(0.85), lineWidth: 2) }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.category)
                            .font(.caption.bold())
                            .foregroundStyle(item.tint)
                        Text(item.name)
                            .font(.largeTitle.bold())
                        Text(item.summary)
                            .font(.body)
                            .foregroundStyle(.white.opacity(0.80))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 0) {
                        ForEach(Array(item.rows.enumerated()), id: \.offset) { index, row in
                            HStack {
                                Text(row.0).foregroundStyle(.white.opacity(0.58))
                                Spacer()
                                Text(row.1).fontWeight(.bold)
                            }
                            .padding(.vertical, 11)
                            if index < item.rows.count - 1 { Divider().overlay(.white.opacity(0.12)) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 7) {
                        Text("实战用法").font(.headline.bold()).foregroundStyle(.yellow)
                        Text(item.usage).font(.body).foregroundStyle(.white.opacity(0.82))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))

                    MistportPlaqueButton(title: "返回构筑", action: { dismiss() })
                }
                .padding(20)
            }
        }
        .foregroundStyle(.white)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct FoolPathGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color.purple.opacity(0.36), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("愚者攻略").font(.largeTitle.bold())
                            Text("序列 9 · 街头戏法师").foregroundStyle(.cyan)
                        }
                        Spacer()
                        MistportPlaqueButton(title: "关闭", compact: true, expands: false, action: { dismiss() })
                    }

                    GuidePlate(title: "战斗定位", text: "愚者通过叠加误认、转成错位、延迟敌人行动，再在破绽窗口完成爆发。", tint: .purple)
                    GuidePlate(title: "战前编排", text: "普通技能按战前排列顺序自动循环。遗落物假面由你手动使用，不占技能槽；用它与伪证烙印铺垫误认，再用身份错置转成错位，最后用错影追猎或荒谬归结兑现。", tint: .cyan)
                    GuidePlate(title: "自动战斗如何选择", text: "系统从左到右扫描技能序列；当前不可用的技能跳过，继续寻找下一张可用技能。技能都不可用时才进行普攻。", tint: .yellow)
                    GuidePlate(title: "推荐入门配置", text: "偏差透镜强化4层误认目标的终结，纸月筹码保留控制方向；优先把铺垫、转化和终结技能排成稳定循环。", tint: .mint)
                    GuidePlate(title: "第一章首领要点", text: "先处理寄忆核心，再观察空壳守卫的蓄力意图。归名执事·赫恩代表归一系统的唯一身份逻辑，保留错位给荒谬归结完成终结。", tint: .orange)
                }
                .padding(20)
            }
        }
        .foregroundStyle(.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct GuidePlate: View {
    let title: String
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.bold()).foregroundStyle(tint)
            Text(text).font(.body).foregroundStyle(.white.opacity(0.82)).lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 17))
        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 4).padding(.vertical, 12) }
    }
}

private struct BuildCurrentLoadout: View {
    let game: GameStore

    private var weaponName: String {
        CharacterLoadoutCatalog.weapon(id: game.equippedWeaponID)?.name ?? "未装备"
    }

    private var secondaryRelicName: String {
        CharacterLoadoutCatalog.weapon(id: game.equippedSecondaryRelicID)?.name ?? "未装备"
    }

    private var passiveNames: [String] {
        game.selectedPassiveIDs.compactMap { CharacterLoadoutCatalog.passive(id: $0)?.name }
    }

    private var talentName: String {
        switch game.selectedTalentBranchID {
        case "deceiver": "欺诈师"
        case "boundary": "越界者"
        default: "戏法师"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("当前构筑")
                    .font(.title3.bold())
                Spacer()
                Text("最大生命 \(game.chapterOneCampaign.party.playerMaxHP)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.yellow)
            }
            HStack(spacing: 8) {
                if MPCChapterOneCatalog.relicsEnabled {
                    BuildSlot(label: "遗落物 I", value: weaponName, tint: .cyan)
                    BuildSlot(label: "遗落物 II", value: secondaryRelicName, tint: .mint)
                }
                BuildSlot(label: "天赋", value: talentName, tint: .purple)
            }
            HStack(spacing: 8) {
                BuildSlot(label: "被动 I", value: passiveNames.first ?? "未装配", tint: .purple)
                BuildSlot(label: "被动 II", value: passiveNames.dropFirst().first ?? "未装配", tint: .cyan)
            }
            HStack(spacing: 8) {
                ForEach(game.configuredDungeonSkills) { skill in
                    BuildSlot(
                        label: skill.id == .ultimate ? "终结" : skill.id == .mobility ? "应变" : skill.id == .control ? "控场" : skill.id == .ward ? "防护" : "攻击",
                        value: skill.name,
                        tint: skill.tint
                    )
                }
            }
        }
        .padding(14)
        .background(.black.opacity(0.74), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(.cyan.opacity(0.40), lineWidth: 1) }
    }
}

private struct BuildSlot: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(String(value.prefix(1)))
                .font(.headline.bold())
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.17), in: Diamond())
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BuildPresetPlate: View {
    let preset: GameBuildPreset
    let progress: Int
    let testAccess: Bool
    let action: () -> Void

    private var isUnlocked: Bool { testAccess || progress >= preset.unlockAt }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Diamond().fill((isUnlocked ? Color.yellow : .gray).opacity(0.18))
                    Diamond().stroke(isUnlocked ? .yellow : .gray, lineWidth: 1.2)
                    Text(String(preset.name.prefix(1)))
                        .font(.headline.bold())
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(preset.name).font(.headline.bold())
                    Text(preset.role).font(.caption).foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
                Text(isUnlocked ? "启用" : "\(progress)/\(preset.unlockAt)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(isUnlocked ? .black : .white.opacity(0.56))
                    .frame(width: 58, height: 38)
                    .background(isUnlocked ? .yellow : .gray.opacity(0.28), in: HexActionShape())
            }
            .foregroundStyle(.white)
            .padding(12)
            .background(.black.opacity(0.70), in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(.yellow.opacity(isUnlocked ? 0.34 : 0.12), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

private struct FeatureStatPlate: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Diamond().fill(tint.opacity(0.18))
                Diamond().stroke(tint.opacity(0.85), lineWidth: 1)
                Text(String(title.prefix(1)))
                    .font(.headline.bold())
                    .foregroundStyle(tint)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.64))
            }
            Spacer()
        }
        .padding(13)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).stroke(tint.opacity(0.24), lineWidth: 1) }
    }
}

private struct SkillForgePlate: View {
    let skill: DungeonSkillDefinition
    let level: Int
    let cost: Int
    let isEvolutionUnlocked: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Diamond().fill(skill.tint.opacity(0.22))
                Diamond().stroke(skill.tint, lineWidth: 1.4)
                Text(String(skill.name.prefix(1)))
                    .font(.title3.bold())
                    .foregroundStyle(skill.tint)
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(skill.name).font(.headline)
                    Text("Lv.\(level)").font(.caption.bold().monospacedDigit()).foregroundStyle(.yellow)
                }
                Text("伤害 \(skill.damage + (level - 1) * 12) · 冷却 \(Int(ceil(skill.cooldown))) 回合")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.64))
            }
            Spacer()
            Button(action: action) {
                VStack(spacing: 1) {
                    Text(level >= 5 ? "已满" : "强化")
                    if level < 5 { Text("◇ \(cost)").font(.system(size: 9, weight: .bold)) }
                }
                .font(.caption.bold())
                .foregroundStyle(isEvolutionUnlocked ? .black : .white.opacity(0.5))
                .frame(width: 54, height: 42)
                .background(isEvolutionUnlocked ? .yellow : .gray.opacity(0.35), in: HexActionShape())
            }
            .buttonStyle(.plain)
        }
        .padding(13)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).stroke(skill.tint.opacity(0.35), lineWidth: 1) }
    }
}

private enum InventoryPalette {
    static let surface = Color(red: 0.11, green: 0.09, blue: 0.13).opacity(0.82)
    static let ink = Color(red: 0.91, green: 0.91, blue: 0.87)
    static let gold = Color(red: 0.79, green: 0.73, blue: 0.58)
}

private struct InventoryCategoryButton: View {
    let category: InventoryCategory
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(category.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(isSelected ? InventoryPalette.gold : InventoryPalette.ink.opacity(0.72))
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(isSelected ? InventoryPalette.gold.opacity(0.72) : InventoryPalette.ink.opacity(0.46))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if isSelected {
                    Capsule().fill(InventoryPalette.gold).frame(width: 28, height: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.title)，\(count)件")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct InventorySlot: View {
    let item: InventoryDisplayItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 5) {
                    ZStack {
                        if let artName = item.artName {
                            Image(inventoryDisplayArtName(artName)).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay { MaskCrackOverlay(count: item.maskCracks) }
                        } else {
                            Text("原画待补")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 49, height: 49)
                    Text(item.title)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                }
                .padding(8)

                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(InventoryPalette.gold, lineWidth: 1)
                        .padding(2)
                        .allowsHitTesting(false)
                }

                if item.count > 1 {
                    Text("×\(item.count)")
                        .font(.system(size: 9, weight: .heavy).monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.82), in: Capsule())
                        .padding(5)
                }
            }
            .frame(minHeight: 92)
        }
        .buttonStyle(.plain)
        .foregroundStyle(InventoryPalette.ink)
    }
}

private func inventoryDisplayArtName(_ artName: String) -> String {
    switch artName {
    case "ItemEvidenceCollar": "ItemEvidenceCollarCutout"
    case "ItemEvidenceKey": "ItemEvidenceKeyCutout"
    case "ItemEvidenceRegistry": "ItemEvidenceRegistryCutout"
    case "ItemEvidenceRoute": "ItemEvidenceRouteCutout"
    case "ItemEvidenceThread": "ItemEvidenceThreadCutout"
    case "ItemHoundTrace": "ItemHoundTraceCutout"
    case "ItemLateSecondWatch": "ItemLateSecondWatchCutout"
    case "ItemMemoryFilament": "ItemMemoryFilamentCutout"
    case "ItemOldClockPass": "ItemOldClockPassCutout"
    case "ItemPainSalve": "ItemPainSalveCutout"
    case "ItemSealedTransfer": "ItemSealedTransferCutout"
    default: artName
    }
}

private struct InventoryEmptySlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(InventoryPalette.surface.opacity(0.55))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(InventoryPalette.ink.opacity(0.09), lineWidth: 1)
                    .padding(6)
            }
            .frame(minHeight: 92)
    }
}

private struct InventoryDetailPanel: View {
    let item: InventoryDisplayItem
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                if let artName = item.artName {
                    Image(inventoryDisplayArtName(artName)).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay { MaskCrackOverlay(count: item.maskCracks) }
                } else {
                    Text("原画待补")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 78, height: 78)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title).font(.headline.bold())
                    Spacer()
                    Text(item.rarity)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(InventoryPalette.gold)
                }
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(InventoryPalette.ink.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                Text("来源：\(item.source)")
                    .font(.caption2)
                    .foregroundStyle(InventoryPalette.ink.opacity(0.48))
                    .lineLimit(2)

                HStack {
                    Text("持有 ×\(item.count)")
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(InventoryPalette.gold)
                    Spacer()
                    if let actionTitle = item.actionTitle {
                        Button(action: action) {
                            if actionTitle == "已选主动遗落物" || actionTitle == "选为主动遗落物" {
                                Image(decorative: actionTitle == "已选主动遗落物"
                                      ? "ButtonArtInventorySelectedActiveRelic"
                                      : "ButtonArtInventorySelectActiveRelic")
                                    .resizable()
                                    .frame(width: 106, height: 33)
                                    .contentShape(Rectangle())
                            } else {
                                Text(actionTitle)
                                    .font(.caption.bold())
                                    .foregroundStyle(actionTitle == "已装配" ? item.tint : .black)
                                    .frame(width: 66, height: 34)
                                    .background(actionTitle == "已装配" ? .black.opacity(0.45) : item.tint, in: HexActionShape())
                                    .overlay { HexActionShape().stroke(item.tint.opacity(0.75), lineWidth: 1) }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(actionTitle)
                        .disabled(actionTitle == "已装配" || actionTitle == "已选主动遗落物")
                    }
                }
            }
        }
        .foregroundStyle(InventoryPalette.ink)
        .padding(13)
        .background(InventoryPalette.surface, in: RoundedRectangle(cornerRadius: 17))
    }
}

private struct InventoryEmptyState: View {
    let category: InventoryCategory

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: category.symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(InventoryPalette.gold)
            Text("暂无\(category.title == "全部" ? "物品" : category.title)")
                .font(.headline.bold())
            Text("完成关卡、接收剧情交付或购买后，实际获得的物品会显示在这里。")
                .font(.caption)
                .foregroundStyle(InventoryPalette.ink.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 20)
        .foregroundStyle(InventoryPalette.ink)
        .background(InventoryPalette.surface, in: RoundedRectangle(cornerRadius: 18))

    }
}

/// A tactile, in-world action plaque.  This deliberately avoids the flat yellow
/// CTA treatment used by utility apps: the action reads as a brass-edged control
/// from Mistport's clockwork architecture.
struct MistportPlaqueButton: View {
    let title: String
    var compact = false
    var expands = true
    var isEnabled = true
    var horizontalInset: CGFloat? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if compact {
                    HStack(spacing: 7) {
                        Text(title).font(.system(size: 14, weight: .heavy, design: .rounded)).tracking(0.5)
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.91, blue: 0.50))
                    .frame(maxWidth: expands ? .infinity : nil, minHeight: 38)
                    .padding(.horizontal, horizontalInset ?? 4)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.72)).overlay(RoundedRectangle(cornerRadius: 12).stroke(.yellow.opacity(0.72), lineWidth: 1)))
                } else {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .tracking(1)
                        .foregroundStyle(Color(red: 0.14, green: 0.12, blue: 0.16))
                        .frame(maxWidth: expands ? .infinity : nil, minHeight: 62)
                        .padding(.horizontal, horizontalInset ?? 20)
                        .background {
                            Image("ButtonArt25MainAction")
                                .resizable(capInsets: EdgeInsets(top: 25, leading: 120, bottom: 25, trailing: 120), resizingMode: .stretch)
                                .accessibilityHidden(true)
                        }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(PlaquePressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
    }

    private var plaqueMark: some View {
        ZStack {
            Circle().fill(.black.opacity(0.35)).frame(width: 22, height: 22)
            DiamondPlaqueMark()
                .fill(LinearGradient(colors: [.white, .yellow, .orange], startPoint: .top, endPoint: .bottom))
                .frame(width: 11, height: 11)
        }
    }
}

private struct DiamondPlaqueMark: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
        }
    }
}

private struct PlaquePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.12 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct FeatureMessageBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption.bold())
            .foregroundStyle(.yellow)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(.yellow.opacity(0.45), lineWidth: 1) }
    }
}

private struct HexActionShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            let cut = min(9, rect.width * 0.18)
            path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
        }
    }
}

struct SceneAtmosphere: View {
    let rainStrength: Int
    let fogOpacity: Double
    let tint: Color

    var body: some View {
        ZStack {
            FogLayer(opacity: fogOpacity, tint: tint)
            if rainStrength > 0 {
                RainLayer(dropCount: rainStrength)
            }
            AmbientLightLayer(tint: tint)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FogLayer: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }

    let opacity: Double
    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let primaryOffset = reduceMotion ? 0 : sin(time * 0.12) * 90
            let secondaryOffset = reduceMotion ? 0 : cos(time * 0.09) * 120

            ZStack {
                Ellipse()
                    .fill(Color.white.opacity(opacity))
                    .frame(width: 520, height: 180)
                    .blur(radius: 42)
                    .offset(x: primaryOffset, y: 80)
                Ellipse()
                    .fill(tint.opacity(opacity * 0.66))
                    .frame(width: 620, height: 220)
                    .blur(radius: 58)
                    .offset(x: secondaryOffset, y: -190)
            }
        }
    }
}

private struct RainLayer: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }

    let dropCount: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                for index in 0..<dropCount {
                    let seed = Double(index) * 0.61803398875
                    let x = (seed * Double(size.width) * 1.7 + elapsed * 36)
                        .truncatingRemainder(dividingBy: Double(size.width) + 60) - 30
                    let y = (seed * 977 + elapsed * 250)
                        .truncatingRemainder(dividingBy: Double(size.height) + 80) - 40
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x - 7, y: y + 24))
                    context.stroke(path, with: .color(.white.opacity(0.25)), lineWidth: 0.8)
                }
            }
        }
        .blendMode(.screen)
    }
}

private struct AmbientLightLayer: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }

    let tint: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { timeline in
            let elapsed = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.09 + (sin(elapsed * 1.7) + 1) * 0.035

            RadialGradient(
                colors: [tint.opacity(pulse), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 180
            )
            .frame(width: 360, height: 360)
            .offset(y: 75)
            .blendMode(.screen)
        }
    }
}
