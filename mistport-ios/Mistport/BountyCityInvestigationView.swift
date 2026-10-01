import MistportCombatCore
import SwiftUI

/// A street scene for an accepted warrant. Places are reached on the city road
/// before their people or evidence can be used; the dossier is only a journal.
struct BountyCityInvestigationView: View {
    @Bindable var game: GameStore
    let bounty: MPCChurchBounty
    let onExit: () -> Void
    let onBattle: () -> Void

    @State private var actor = UnitPoint(x: 1132.0 / 2048, y: 1000.0 / 1143)
    @State private var actorFacing = "S"
    @State private var selectedSpotID: String?
    @State private var doorSpotID: String?
    @State private var isWalking = false
    @State private var notice = ""
    @State private var chosenSuspectID: String?
    @State private var chosenSupportIDs: Set<String> = []
    @State private var warrantReady = false
    @State private var showsPoker = false
    @State private var dialogueVisibleCount = 0
    @State private var portraitDrift = false
    @State private var mapScrollX: CGFloat = -1
    @State private var mapScrollY: CGFloat = 0
    @State private var mapDragStartX: CGFloat?
    @State private var mapDragStartY: CGFloat?
    @State private var mapCanvasWidth: CGFloat = 0
    @State private var mapCanvasHeight: CGFloat = 0
    @State private var mapViewportWidth: CGFloat = 0
    @State private var mapZoom: CGFloat = 1
    @State private var mapPinchStartZoom: CGFloat?
    @State private var mapManualCameraUntil: Date = .distantPast
    @State private var walkingTask: Task<Void, Never>?

    private var progress: MPCChurchBountyProgress {
        game.churchServices.bounties.cases[bounty.id] ?? .init()
    }

    private var spots: [BountyCitySpot] {
        let evidence = bounty.nodes.map { node in
            BountyCitySpot(id: node.id, title: node.location, location: node.location,
                           point: BountyCitySpot.coordinate(node.location), nodeID: node.id)
        }
        let desks = [
            BountyCitySpot(id: "church-desk", title: "教会柜台", location: "教会",
                           point: .init(x: 0.77, y: 0.25), nodeID: nil),
            BountyCitySpot(id: "tavern-desk", title: "酒馆柜台", location: "酒馆",
                           point: .init(x: 0.46, y: 0.54), nodeID: nil)
        ]
        return evidence + desks
    }

    private var selectedSpot: BountyCitySpot? {
        spots.first { $0.id == selectedSpotID }
    }

    var body: some View {
        GeometryReader { geo in
            let mapHeight = max(500, geo.size.height * 0.82)
            let interiorHeight = max(360, geo.size.height * 0.56)
            let mapWidth = mapHeight * (5504.0 / 3072.0)
            VStack(spacing: 0) {
                header
                if let art = interiorArt {
                    interiorScene(art: art, canvasHeight: interiorHeight)
                } else {
                    mapScene(canvasWidth: mapWidth, canvasHeight: mapHeight,
                             viewportWidth: geo.size.width)
                }
                sitePanel
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Color(red: 0.07, green: 0.075, blue: 0.12))
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showsPoker) {
            BountyPokerRound(game: game, caseID: bounty.id) { result in
                switch result.outcome {
                case .win: notice = "\(result.modeName)胜出，赢得\(result.netCopper) 铜币和约定口供。"
                case .tie: notice = "平局，\(result.wager) 铜币赌注已退回。"
                case .loss: notice = "牌局输了，损失 \(result.wager) 铜币；可以再试或查公开档案。"
                }
            }
            .presentationDetents([.large])
        }
        .task(id: selectedSpotID) {
            dialogueVisibleCount = 0
            guard let node = selectedSpot.flatMap({ spot in
                bounty.nodes.first(where: { $0.id == spot.nodeID })
            }), !node.dialogue.isEmpty else { return }
            for index in 1...node.dialogue.count {
                if Task.isCancelled { return }
                dialogueVisibleCount = index
                try? await Task.sleep(for: .milliseconds(24))
            }
        }
        .onDisappear { walkingTask?.cancel() }
    }

    private var interiorArt: String? {
        guard let spot = selectedSpot, let nodeID = spot.nodeID,
              let node = bounty.nodes.first(where: { $0.id == nodeID }) else {
            if selectedSpot?.location == "酒馆" { return "BountyTavernInterior" }
            if selectedSpot?.location == "教会" { return "ChurchJointSanctuary" }
            return nil
        }
        if bounty.id == "b07" {
            switch nodeID {
            case "witness": return "BountyNPCPostman"
            case "wound": return "PortraitOdelleFinn"
            case "exclude": return "BountyNPCCarpenter"
            case "compare": return "BountyDrainArchivist"
            default: break
            }
        }
        if node.id == "identity" { return "BountyCityHideout" }
        if node.speaker.contains("奥黛尔") { return "PortraitOdelleFinn" }
        if node.speaker.contains("维拉") { return "PortraitVeraCopperbranch" }
        if node.speaker.contains("诺恩") { return "PortraitNornKade" }
        if node.speaker.contains("伊莱") { return "PortraitEliWhiteSparrow" }
        if node.speaker.contains("档案员") { return "BountyNPCArchivist" }
        return "BountyCityRoom"
    }

    private func interiorScene(art: String, canvasHeight: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            GeometryReader { geo in
                Image(art)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(portraitDrift ? 1.045 : 1.0)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            LinearGradient(colors: [.clear, .clear, .black.opacity(0.50)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            Button {
                doorSpotID = selectedSpotID
                selectedSpotID = nil
                notice = ""
            } label: {
                Label("出门回街", systemImage: "door.left.hand.open")
                    .font(.caption.bold())
                    .padding(10)
                    .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(height: canvasHeight)
        .overlay(alignment: .bottom) {
            if selectedSpot?.nodeID == "identity",
               progress.warrantPresented,
               progress.victoriousBattleID == nil {
                Button(action: onBattle) {
                    Label("阻止目标 · 进入战斗", systemImage: "bolt.shield.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(ChurchGold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.black.opacity(0.90), in: Capsule())
                        .overlay(Capsule().stroke(ChurchGold.opacity(0.78)))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            portraitDrift = false
            withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                portraitDrift = true
            }
        }
    }

    private func mapScene(canvasWidth: CGFloat, canvasHeight: CGFloat,
                          viewportWidth: CGFloat) -> some View {
        let scaledWidth = canvasWidth * mapZoom
        let scaledHeight = canvasHeight * mapZoom
        return ZStack {
            ZStack {
                Image("BountyCityPanorama")
                    .resizable()
                    .frame(width: scaledWidth, height: scaledHeight)
                    .accessibilityHidden(true)
                    .gesture(SpatialTapGesture().onEnded { value in
                        let tapped = UnitPoint(x: value.location.x / scaledWidth,
                                               y: value.location.y / scaledHeight)
                        walkOnRoad(to: BountyCitySpot.nearestRoadPoint(to: tapped))
                    })
                ForEach(spots) { spot in
                    if spot.nodeID != "identity" || progress.evidenceIDs.contains("compare") {
                        marker(for: spot)
                            .position(x: scaledWidth * spot.point.x,
                                      y: scaledHeight * spot.point.y)
                    }
                }
                actorMarker
                    .position(x: scaledWidth * actor.x, y: scaledHeight * actor.y - 10)
                    .opacity(HarborAlleyVisibility.isHidden(actor) ? 0 : 1)
            }
            .frame(width: scaledWidth, height: scaledHeight)
            .offset(x: -max(0, mapScrollX), y: -max(0, mapScrollY))
            .frame(width: viewportWidth, height: canvasHeight, alignment: .topLeading)
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        guard mapPinchStartZoom == nil else { return }
                        if mapDragStartX == nil { mapDragStartX = max(0, mapScrollX) }
                        if mapDragStartY == nil { mapDragStartY = max(0, mapScrollY) }
                        mapScrollX = min(max(0, (mapDragStartX ?? 0) - value.translation.width),
                                         max(0, scaledWidth - viewportWidth))
                        mapScrollY = min(max(0, (mapDragStartY ?? 0) - value.translation.height),
                                         max(0, scaledHeight - canvasHeight))
                    }
                    .onEnded { _ in
                        mapDragStartX = nil
                        mapDragStartY = nil
                        mapManualCameraUntil = Date().addingTimeInterval(2)
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { factor in
                        if mapPinchStartZoom == nil { mapPinchStartZoom = mapZoom }
                        changeZoom(to: (mapPinchStartZoom ?? 1) * factor)
                    }
                    .onEnded { _ in mapPinchStartZoom = nil }
            )
            HStack {
                mapPanButton("西街", symbol: "chevron.left", delta: -viewportWidth * 0.65)
                Spacer()
                HStack(spacing: 4) {
                    mapZoomButton("缩小地图", symbol: "minus.magnifyingglass", factor: 1 / 1.35)
                    Text("\(Int(mapZoom * 100))%")
                        .font(.caption.bold().monospacedDigit())
                        .frame(minWidth: 38)
                    mapZoomButton("放大地图", symbol: "plus.magnifyingglass", factor: 1.35)
                }
                .padding(.horizontal, 4)
                .background(.black.opacity(0.82), in: Capsule())
                mapPanButton("东岸", symbol: "chevron.right", delta: viewportWidth * 0.65)
            }
            .padding(.horizontal, 6)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)
        }
        .frame(height: canvasHeight)
        .onAppear {
            mapCanvasWidth = canvasWidth
            mapCanvasHeight = canvasHeight
            mapViewportWidth = viewportWidth
            if mapScrollX < 0 { centerMap(on: actor, animated: false) }
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.clear, .black.opacity(0.42)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 76)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            if !isWalking, let door = spots.first(where: { $0.id == doorSpotID }) {
                Button {
                    selectedSpotID = door.id
                    doorSpotID = nil
                    notice = ""
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "door.left.hand.open")
                        Text("已到\(door.title) · 点击进入")
                            .lineLimit(1)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(ChurchGold)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 11)
                    .background(.black.opacity(0.88), in: Capsule())
                    .overlay(Capsule().stroke(ChurchGold.opacity(0.72)))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)
                .accessibilityLabel("进入\(door.title)")
            }
        }
    }

    private func mapPanButton(_ title: String, symbol: String, delta: CGFloat) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                mapScrollX = min(max(0, max(0, mapScrollX) + delta),
                                 max(0, mapCanvasWidth * mapZoom - mapViewportWidth))
            }
        } label: {
            Label(title, systemImage: symbol)
                .font(.caption.bold())
                .padding(.horizontal, 8).padding(.vertical, 7)
                .background(.black.opacity(0.82), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看\(title)地图")
    }

    private func mapZoomButton(_ title: String, symbol: String, factor: CGFloat) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { changeZoom(to: mapZoom * factor) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func changeZoom(to requested: CGFloat) {
        guard mapCanvasWidth > 0, mapCanvasHeight > 0, mapViewportWidth > 0 else { return }
        let next = min(2.6, max(1, requested))
        let focusX = (max(0, mapScrollX) + mapViewportWidth * 0.5) / (mapCanvasWidth * mapZoom)
        let focusY = (max(0, mapScrollY) + mapCanvasHeight * 0.5) / (mapCanvasHeight * mapZoom)
        mapZoom = next
        mapScrollX = min(max(0, focusX * mapCanvasWidth * next - mapViewportWidth * 0.5),
                         max(0, mapCanvasWidth * next - mapViewportWidth))
        mapScrollY = min(max(0, focusY * mapCanvasHeight * next - mapCanvasHeight * 0.5),
                         max(0, mapCanvasHeight * next - mapCanvasHeight))
    }

    private func centerMap(on point: UnitPoint, animated: Bool) {
        guard mapCanvasWidth > 0, mapCanvasHeight > 0, mapViewportWidth > 0 else { return }
        let nextX = min(max(0, mapCanvasWidth * mapZoom * point.x - mapViewportWidth * 0.5),
                        max(0, mapCanvasWidth * mapZoom - mapViewportWidth))
        let nextY = min(max(0, mapCanvasHeight * mapZoom * point.y - mapCanvasHeight * 0.5),
                        max(0, mapCanvasHeight * mapZoom - mapCanvasHeight))
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                mapScrollX = nextX
                mapScrollY = nextY
            }
        } else {
            mapScrollX = nextX
            mapScrollY = nextY
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            GameArtReturnButton(title: "收起城图", action: onExit)
            VStack(alignment: .leading, spacing: 2) {
                Text("雾港 · 通缉调查").font(.system(size: 18, weight: .bold, design: .serif))
                Text(bounty.title + " · " + currentQuestion)
                    .font(.caption).lineLimit(2).foregroundStyle(.white.opacity(0.72))
            }
            Spacer(minLength: 0)
            Text("\(progress.evidenceIDs.count)/5")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(ChurchGold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .padding(.top, 42)
        .background(.black.opacity(0.88))
    }

    private var currentQuestion: String {
        if progress.victoriousBattleID != nil { return "带着现场物证回柜台交案" }
        if progress.evidenceIDs.contains("identity") { return "选择嫌疑人并出示两项独立材料" }
        if progress.evidenceIDs.contains("compare") { return "到现场核对特征与行为" }
        if progress.evidenceIDs.contains("witness") && progress.evidenceIDs.contains("wound") {
            return "比对两条独立线索"
        }
        return "先访问目击者与物证所在地"
    }

    private func marker(for spot: BountyCitySpot) -> some View {
        let visited = progress.visitedLocations.contains(spot.location)
        let found = spot.nodeID.map { progress.evidenceIDs.contains($0) } ?? false
        return Button { travel(to: spot) } label: {
            Text(spot.title)
                .font(.system(size: 12, weight: .heavy, design: .serif))
                .lineLimit(1)
                .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.23))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color(red: 0.97, green: 0.96, blue: 0.93)
                    .opacity(found || visited ? 0.99 : 0.91), in: Capsule())
                .frame(minWidth: 64, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(isWalking)
        .accessibilityLabel("前往并进入\(spot.title)")
    }

    private var actorMarker: some View {
        TimelineView(.animation(minimumInterval: 0.09, paused: !isWalking)) { timeline in
            let frame = Int(timeline.date.timeIntervalSinceReferenceDate / 0.09) % 6 + 1
            let art: String = if isWalking {
                switch actorFacing {
                case "N": String(format: "FoolRunN%02d", frame)
                case "S": String(format: "FoolRunS%02d", frame)
                default: String(format: "FoolRun%02d", frame)
                }
            } else { "FoolIdleS" }
            ZStack {
                Circle().fill(.cyan.opacity(0.25)).frame(width: 20, height: 20).offset(y: 12)
                Image(decorative: art)
                    .resizable().scaledToFit()
                    .frame(width: 36, height: 36)
                    .scaleEffect(x: actorFacing == "W" && isWalking ? -1 : 1, y: 1)
            }
        }
        .shadow(color: .black.opacity(0.75), radius: 3)
        .accessibilityLabel("主角当前所在")
    }

    private var sitePanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if interiorArt == nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            ForEach(spots) { spot in
                                if spot.nodeID != "identity" || progress.evidenceIDs.contains("compare") {
                                    Button(spot.title) { travel(to: spot) }
                                        .font(.caption.bold())
                                        .foregroundStyle(progress.evidenceIDs.contains(spot.nodeID ?? "") ? .cyan : ChurchGold)
                                        .padding(.horizontal, 10).padding(.vertical, 7)
                                        .background(.white.opacity(0.08), in: Capsule())
                                        .overlay(Capsule().stroke(ChurchGold.opacity(0.48)))
                                        .disabled(isWalking)
                                }
                            }
                        }
                    }
                }
                if isWalking {
                    Text("沿街道前往地点……").font(.headline).foregroundStyle(ChurchGold)
                } else if let door = spots.first(where: { $0.id == doorSpotID }) {
                    Text(door.title).font(.system(size: 20, weight: .bold, design: .serif))
                    Text("已到门口。进入后才能与人物交谈、查验物证。")
                        .font(.footnote).foregroundStyle(.white.opacity(0.82))
                    sceneButton("进入\(door.title)") {
                        selectedSpotID = door.id
                        doorSpotID = nil
                        notice = ""
                    }
                } else if let spot = selectedSpot {
                    HStack {
                        Text(spot.title).font(.system(size: 20, weight: .bold, design: .serif))
                        Spacer()
                        Text(progress.visitedLocations.contains(spot.location) ? "已到访" : "未到访")
                            .font(.caption).foregroundStyle(ChurchGold)
                    }
                    if let nodeID = spot.nodeID,
                       let node = bounty.nodes.first(where: { $0.id == nodeID }) {
                        evidenceScene(node)
                    } else {
                        Text(spot.location == "酒馆" ? "向酒馆老板交付卷宗，或继续打听街上的人。" : "向教会登记员陈述调查结果。")
                            .font(.footnote)
                        if spot.location == "酒馆" && bounty.id == "b08"
                            && !progress.pokerWins.contains(bounty.id) {
                            sceneButton("与牌手对局 · 选择换牌或斗地主") { showsPoker = true }
                            Text("赢牌可得蜡面买卖者口供；输牌可重赛，港务登记也能提供替代证据。")
                                .font(.caption).foregroundStyle(.white.opacity(0.68))
                        }
                        if progress.victoriousBattleID != nil {
                            Text("现场已收押。回到柜台后在卷宗领取一次性报酬。")
                                .font(.footnote).foregroundStyle(ChurchGold)
                        }
                        sceneButton("返回柜台") { onExit() }
                    }
                    if !notice.isEmpty {
                        Text(notice).font(.footnote).foregroundStyle(ChurchGold)
                    }
                } else {
                    Text("点路面自由行走，或点建筑标记沿街前往。到门口后点击进入，再与人物交谈或检查物证。")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                    if !notice.isEmpty { Text(notice).font(.footnote).foregroundStyle(ChurchGold) }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.black.opacity(0.91))
        .overlay(alignment: .top) { Rectangle().fill(ChurchGold.opacity(0.6)).frame(height: 1) }
    }

    @ViewBuilder
    private func evidenceScene(_ node: MPCChurchBountyNode) -> some View {
        let found = progress.evidenceIDs.contains(node.id)
        Text(node.speaker + " · " + node.location)
            .font(.caption.bold()).foregroundStyle(ChurchGold)
        if found {
            dialogueText(node)
            Text("卷宗：\(node.evidence)").font(.footnote).foregroundStyle(.cyan)
        } else {
            dialogueText(node)
            if node.id == "compare" || node.id == "identity" {
                sceneButton(node.id == "identity" ? "先观察现场" : "先检查台面物件") {
                    perform(success: "现场所见已记录，下一步由你作出比对。") {
                        try game.investigateChurchBounty(bounty.id, nodeID: node.id)
                    }
                }
            }
            if node.id == "identity" {
                sceneButton("观察外观特征") {
                    perform(success: "外观特征已记下。") {
                        try game.inspectChurchBountySite(bounty.id, featureID: "appearance")
                    }
                }
                sceneButton("观察现场行为") {
                    perform(success: "现场行为已记下。") {
                        try game.inspectChurchBountySite(bounty.id, featureID: "conduct")
                    }
                }
            }
            if let challenge = MPCChurchBountyCatalog.challenge(caseID: bounty.id, nodeID: node.id) {
                Text(challenge.question).font(.footnote.bold()).foregroundStyle(ChurchGold)
                ForEach(challenge.choices) { choice in
                    sceneButton(choice.text) {
                        perform(success: choice.explanation) {
                            try game.answerChurchBounty(bounty.id, nodeID: node.id, choiceID: choice.id)
                        }
                    }
                }
            } else {
                sceneButton(node.id == "wound" ? "检查物证并记录" : "交谈并记录口供") {
                    perform(success: "已将来源与原话收入卷宗。") {
                        try game.investigateChurchBounty(bounty.id, nodeID: node.id)
                    }
                }
            }
        }
        if bounty.id == "b03" && node.location == "码头" && !progress.pokerWins.contains(bounty.id) {
            sceneButton("与老水手对局 · 选择换牌或斗地主") { showsPoker = true }
            Text("赢牌可得暗号解释；输牌可重赛，沉船档案柜另有公开航海日志。")
                .font(.caption).foregroundStyle(.white.opacity(0.68))
        }
        if (bounty.id == "b03" && node.location == "沉船档案柜")
            || (bounty.id == "b08" && node.location == "港务登记处") {
            sceneButton("查阅公开档案作为替代线索") {
                perform(success: "独立档案已收录；无需赢牌也能继续查案。") {
                    try game.inspectChurchBountyAlternative(bounty.id)
                }
            }
        }
        if node.id == "identity" && progress.evidenceIDs.contains("identity") {
            warrantPanel
        }
    }

    private var warrantPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("现场缉捕核验").font(.headline).foregroundStyle(ChurchGold)
            Text("选择嫌疑人，再亲自勾选两项来自不同来源的材料。")
                .font(.caption).foregroundStyle(.white.opacity(0.76))
            HStack {
                choiceButton(bounty.title, selected: chosenSuspectID == bounty.enemyID) {
                    chosenSuspectID = bounty.enemyID
                }
                choiceButton("传闻中的无辜者", selected: chosenSuspectID == "rumour-suspect") {
                    chosenSuspectID = "rumour-suspect"
                }
            }
            ForEach(["witness", "wound"], id: \.self) { id in
                if let node = bounty.nodes.first(where: { $0.id == id }),
                   progress.evidenceIDs.contains(id) {
                    choiceButton(node.evidence, selected: chosenSupportIDs.contains(id)) {
                        if chosenSupportIDs.contains(id) { chosenSupportIDs.remove(id) }
                        else { chosenSupportIDs.insert(id) }
                    }
                }
            }
            sceneButton("出示通缉令") {
                guard let suspect = chosenSuspectID else {
                    notice = "先选择嫌疑人。"
                    return
                }
                perform(success: "身份与两项独立材料吻合，现场缉捕获准。") {
                    try game.presentChurchBountyWarrant(
                        bounty.id, suspectID: suspect, supportingEvidenceIDs: chosenSupportIDs)
                    warrantReady = true
                }
            }
            if (warrantReady || progress.warrantPresented) && progress.victoriousBattleID == nil {
                sceneButton("阻止目标 · 进入战斗") { onBattle() }
            }
        }
        .padding(.top, 6)
    }

    private func choiceButton(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                Text(title).font(.caption).lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(selected ? ChurchGold.opacity(0.22) : .white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ChurchGold.opacity(0.42)))
        }
        .buttonStyle(.plain)
    }

    private func sceneButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(ChurchGold)
                .frame(maxWidth: .infinity, minHeight: 36)
                .background(ChurchGold.opacity(0.11), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ChurchGold.opacity(0.55)))
        }
        .buttonStyle(.plain)
    }

    private func dialogueText(_ node: MPCChurchBountyNode) -> some View {
        Button {
            dialogueVisibleCount = node.dialogue.count
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(String(node.dialogue.prefix(dialogueVisibleCount)))
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if dialogueVisibleCount < node.dialogue.count {
                    Text("轻点显示全部对白")
                        .font(.caption2)
                        .foregroundStyle(ChurchGold)
                }
            }
            .padding(12)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func walkOnRoad(to destination: UnitPoint) {
        guard !isWalking else { return }
        selectedSpotID = nil
        doorSpotID = nil
        notice = ""
        moveAlongRoad(to: destination)
    }

    private func travel(to spot: BountyCitySpot) {
        guard !isWalking else { return }
        selectedSpotID = nil
        doorSpotID = nil
        notice = ""
        let destination = BountyCitySpot.nearestRoadPoint(to: spot.point)
        moveAlongRoad(to: destination) {
            do {
                try game.visitChurchBounty(bounty.id, location: spot.location)
                doorSpotID = spot.id
            } catch {
                notice = "此地点尚未开放，先阅读卷宗与主线提示。"
            }
        }
    }

    private func perform(success: String, _ work: () throws -> Void) {
        do { try work(); notice = success }
        catch { notice = "线索仍有缺口：核对地点、独立证据或现场特征后再试。" }
    }

    private func moveAlongRoad(to destination: UnitPoint, completion: (() -> Void)? = nil) {
        isWalking = true
        let route = BountyCitySpot.route(from: actor, to: destination)
        walkingTask = Task { @MainActor in
            for point in route {
                guard !Task.isCancelled else { isWalking = false; return }
                let start = actor
                let dx = point.x - start.x
                let dy = point.y - start.y
                if abs(dx) > abs(dy) * 1.15 { actorFacing = dx >= 0 ? "E" : "W" }
                else if abs(dy) > 0.001 { actorFacing = dy >= 0 ? "S" : "N" }
                let distance = hypot(dx * 2048, dy * 1143)
                let steps = max(1, Int(ceil(distance / 19.6 * 30)))
                for step in 1...steps {
                    guard !Task.isCancelled else { isWalking = false; return }
                    let fraction = CGFloat(step) / CGFloat(steps)
                    actor = UnitPoint(x: start.x + dx * fraction, y: start.y + dy * fraction)
                    followBountyActor()
                    try? await Task.sleep(for: .milliseconds(33))
                }
            }
            guard !Task.isCancelled else { isWalking = false; return }
            completion?()
            isWalking = false
        }
    }

    private func followBountyActor() {
        guard Date() >= mapManualCameraUntil, mapCanvasWidth > 0,
              mapCanvasHeight > 0, mapViewportWidth > 0 else { return }
        let x = mapCanvasWidth * mapZoom * actor.x
        let y = mapCanvasHeight * mapZoom * actor.y
        let left = max(0, mapScrollX)
        let top = max(0, mapScrollY)
        let screenX = x - left
        let screenY = y - top
        let targetX: CGFloat = if screenX < mapViewportWidth * 0.40 {
            x - mapViewportWidth * 0.40
        } else if screenX > mapViewportWidth * 0.60 {
            x - mapViewportWidth * 0.60
        } else { left }
        let targetY: CGFloat = if screenY < mapCanvasHeight * 0.38 {
            y - mapCanvasHeight * 0.38
        } else if screenY > mapCanvasHeight * 0.62 {
            y - mapCanvasHeight * 0.62
        } else { top }
        mapScrollX = min(max(0, left + (targetX - left) * 0.14),
                         max(0, mapCanvasWidth * mapZoom - mapViewportWidth))
        mapScrollY = min(max(0, top + (targetY - top) * 0.14),
                         max(0, mapCanvasHeight * mapZoom - mapCanvasHeight))
    }
}

private struct BountyCitySpot: Identifiable {
    let id: String
    let title: String
    let location: String
    let point: UnitPoint
    let nodeID: String?

    static func coordinate(_ location: String) -> UnitPoint {
        let points: [String: UnitPoint] = [
            "旧邮局": .init(x: 0.17, y: 0.55), "诊所": .init(x: 0.31, y: 0.57),
            "木工街": .init(x: 0.26, y: 0.68), "旧排水口": .init(x: 0.43, y: 0.62),
            "第三间空屋": .init(x: 0.22, y: 0.49),
            "封锁公告处": .init(x: 0.56, y: 0.72), "巡逻值房": .init(x: 0.62, y: 0.65),
            "铁匠铺": .init(x: 0.30, y: 0.68), "废岗亭": .init(x: 0.71, y: 0.47),
            "避难屋": .init(x: 0.27, y: 0.56), "市政救援站": .init(x: 0.54, y: 0.70),
            "渡运台": .init(x: 0.79, y: 0.70), "废浴场": .init(x: 0.84, y: 0.60),
            "港务登记处": .init(x: 0.82, y: 0.65), "钟台": .init(x: 0.58, y: 0.78),
            "码头": .init(x: 0.91, y: 0.72), "沉船档案柜": .init(x: 0.76, y: 0.64),
            "钟沉船": .init(x: 0.94, y: 0.57),
            "公证柜台": .init(x: 0.54, y: 0.72), "验印台": .init(x: 0.62, y: 0.72),
            "废印厂外": .init(x: 0.36, y: 0.57), "废印厂": .init(x: 0.32, y: 0.52),
            "旧衣铺": .init(x: 0.20, y: 0.67), "联络处": .init(x: 0.60, y: 0.67),
            "染坊账房": .init(x: 0.36, y: 0.65), "染坊后院": .init(x: 0.34, y: 0.56),
            "军甲修理棚": .init(x: 0.83, y: 0.73), "报警钟楼": .init(x: 0.57, y: 0.76),
            "封舱台外": .init(x: 0.89, y: 0.65), "封舱台": .init(x: 0.93, y: 0.61),
            "雇工会": .init(x: 0.42, y: 0.64), "相片铺": .init(x: 0.31, y: 0.61),
            "旧照相馆": .init(x: 0.23, y: 0.58),
            "民事柜台": .init(x: 0.55, y: 0.75), "卷宗室": .init(x: 0.61, y: 0.73),
            "质押所外": .init(x: 0.34, y: 0.66), "废质押所": .init(x: 0.27, y: 0.61),
            "地下纸窖": .init(x: 0.25, y: 0.55),
            "施济登记处": .init(x: 0.73, y: 0.32), "守灯诊所": .init(x: 0.70, y: 0.42),
            "施济厅外": .init(x: 0.79, y: 0.32), "封闭施济厅": .init(x: 0.82, y: 0.27)
        ]
        return points[location] ?? .init(x: 0.57, y: 0.76)
    }

    // The same player-traced streets used by the roaming citizens.  The old
    // hand-entered 27-node graph cut across the clock fountain and roofs.
    private static let roads: [UnitPoint] = HarborRoadNetwork.current.nodes.map {
        UnitPoint(x: $0[0] / 2048, y: $0[1] / 1143)
    }
    private static let links: [(Int, Int)] = HarborRoadNetwork.current.edges.map { ($0[0], $0[1]) }

    private static func squaredDistance(_ a: UnitPoint, _ b: UnitPoint) -> CGFloat {
        let dx = (a.x - b.x) * 2048
        let dy = (a.y - b.y) * 1143
        return dx * dx + dy * dy
    }

    private static func nearestRoadEdge(to point: UnitPoint) -> (Int, Int, UnitPoint) {
        var nearest = (0, 1, roads[0])
        var best = CGFloat.greatestFiniteMagnitude
        for (from, to) in links {
            let a = roads[from], b = roads[to]
            let dx = (b.x - a.x) * 2048, dy = (b.y - a.y) * 1143
            let lengthSquared = dx * dx + dy * dy
            guard lengthSquared > 0 else { continue }
            let fraction = max(0, min(1, (((point.x - a.x) * 2048) * dx
                                      + ((point.y - a.y) * 1143) * dy) / lengthSquared))
            let candidate = UnitPoint(x: a.x + (b.x - a.x) * fraction,
                                      y: a.y + (b.y - a.y) * fraction)
            let distance = squaredDistance(candidate, point)
            if distance < best { best = distance; nearest = (from, to, candidate) }
        }
        return nearest
    }

    static func nearestRoadPoint(to point: UnitPoint) -> UnitPoint {
        nearestRoadEdge(to: point).2
    }

    static func route(from start: UnitPoint, to end: UnitPoint) -> [UnitPoint] {
        let startEdge = nearestRoadEdge(to: start)
        let endEdge = nearestRoadEdge(to: end)
        if Set([startEdge.0, startEdge.1]) == Set([endEdge.0, endEdge.1]) {
            return [endEdge.2]
        }
        var bestRoute: [UnitPoint] = []
        var bestLength = CGFloat.greatestFiniteMagnitude
        for first in [startEdge.0, startEdge.1] {
            for last in [endEdge.0, endEdge.1] {
                let (indices, roadLength) = path(from: first, to: last)
                guard !indices.isEmpty else { continue }
                let total = sqrt(squaredDistance(startEdge.2, roads[first])) + roadLength
                    + sqrt(squaredDistance(roads[last], endEdge.2))
                if total < bestLength {
                    bestLength = total
                    bestRoute = indices.map { roads[$0] }
                }
            }
        }
        if squaredDistance(start, startEdge.2) > 1 { bestRoute.insert(startEdge.2, at: 0) }
        if squaredDistance(bestRoute.last ?? start, endEdge.2) > 1 { bestRoute.append(endEdge.2) }
        return bestRoute
    }

    private static func path(from first: Int, to last: Int) -> ([Int], CGFloat) {
        var distances = Array(repeating: CGFloat.greatestFiniteMagnitude, count: roads.count)
        var previous = Array(repeating: -1, count: roads.count)
        var visited = Set<Int>()
        distances[first] = 0
        while visited.count < roads.count {
            guard let current = roads.indices.filter({ !visited.contains($0) })
                .min(by: { distances[$0] < distances[$1] }),
                distances[current] < .greatestFiniteMagnitude else { break }
            if current == last { break }
            visited.insert(current)
            for (a, b) in links {
                let neighbor: Int
                if a == current { neighbor = b }
                else if b == current { neighbor = a }
                else { continue }
                let length = sqrt(squaredDistance(roads[current], roads[neighbor]))
                if distances[current] + length < distances[neighbor] {
                    distances[neighbor] = distances[current] + length
                    previous[neighbor] = current
                }
            }
        }
        var indices = [last]
        while indices[0] != first && previous[indices[0]] >= 0 {
            indices.insert(previous[indices[0]], at: 0)
        }
        guard indices[0] == first else { return ([], .greatestFiniteMagnitude) }
        return (indices, distances[last])
    }
}

/// The hub's harbor entrance is a place to visit, not a second story shortcut.
/// Accepted warrants still use BountyCityInvestigationView for their evidence rules.
struct HarborCityExplorationView: View {
    @Bindable var game: GameStore
    let onBack: () -> Void

    @State private var presentedPlace: HarborPlace?
    @State private var entryTask: Task<Void, Never>?
    @State private var dialogueTask: Task<Void, Never>?
    @State private var isNight = false
    @State private var pedestrianTiming: [String: HarborPedestrianTiming] = [:]
    @State private var talkingCitizen: HarborCitizenDialogue?
    @State private var bubbleVisible = false
    @State private var roamingVariant = Int.random(in: 0..<3)
    @State private var scrollX: CGFloat = -1
    @State private var scrollY: CGFloat = 0
    @State private var dragStartX: CGFloat?
    @State private var dragStartY: CGFloat?
    @State private var canvasWidth: CGFloat = 0
    @State private var canvasHeight: CGFloat = 0
    @State private var viewportWidth: CGFloat = 0
    @State private var zoom: CGFloat = 1
    @State private var pinchStartZoom: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                GeometryReader { mapGeometry in
                    let mapHeight = mapGeometry.size.height
                    map(canvasWidth: mapHeight * (5504.0 / 3072.0),
                        canvasHeight: mapHeight,
                        viewportWidth: mapGeometry.size.width)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(red: 0.06, green: 0.07, blue: 0.11))
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onDisappear {
            entryTask?.cancel()
            dialogueTask?.cancel()
        }
        .fullScreenCover(item: $presentedPlace) { place in
            switch place {
            case .church:
                ChurchSanctuaryView(game: game)
            case .tavern:
                TavernInteriorView(game: game, onBack: { presentedPlace = nil })
            case .cafe:
                if let venue = game.activeVenue {
                    VenueView(game: game, venue: venue)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            GameArtReturnButton(title: "返回主页", action: onBack)
            .accessibilityLabel("退出港城，返回主页")
            Text("雾港 · 港城")
                .font(.system(size: 19, weight: .bold, design: .serif))
            Spacer(minLength: 0)
            Button {
                withAnimation(.easeInOut(duration: 0.9)) { isNight.toggle() }
            } label: {
                Label(isNight ? "天亮" : "入夜", systemImage: isNight ? "sun.max.fill" : "moon.stars.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isNight ? "切换到白天" : "切换到夜晚")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.top, 49)
        .padding(.bottom, 10)
        .background(.black.opacity(0.88))
    }

    private func map(canvasWidth: CGFloat, canvasHeight: CGFloat,
                     viewportWidth: CGFloat) -> some View {
        let scaledWidth = canvasWidth * zoom
        let scaledHeight = canvasHeight * zoom
        return ZStack {
            ZStack {
                Image("BountyCityPanorama")
                    .resizable()
                    .frame(width: scaledWidth, height: scaledHeight)
                    .accessibilityHidden(true)
                    .gesture(SpatialTapGesture().onEnded { value in
                        // A moving 28-point sprite can leave a mouse click
                        // between frame capture and button dispatch.  Let
                        // the street receive a nearby tap as the same person.
                        if let pedestrian = nearestVisibleCitizen(
                            to: value.location, width: scaledWidth,
                            height: scaledHeight) {
                            focusCitizen(pedestrian)
                        } else {
                            dismissDialogue()
                        }
                    })
                ambientPedestrians(width: scaledWidth, height: scaledHeight)
                if isNight {
                    nightAtmosphere(width: scaledWidth, height: scaledHeight)
                        .transition(.opacity)
                }
                ForEach(HarborPlace.allCases) { place in
                    placeMarker(place)
                        .position(x: scaledWidth * place.markerPoint.x,
                                  y: scaledHeight * place.markerPoint.y)
                }
                if let citizen = talkingCitizen, bubbleVisible {
                    speechBubble(for: citizen)
                        .position(x: scaledWidth * citizen.point.x,
                                  y: scaledHeight * citizen.point.y - 50)
                        .zIndex(20)
                }
            }
            .frame(width: scaledWidth, height: scaledHeight)
            .offset(x: -max(0, scrollX), y: -max(0, scrollY))
            .frame(width: viewportWidth, height: canvasHeight, alignment: .topLeading)
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 18)
                    .onChanged { value in
                        guard pinchStartZoom == nil else { return }
                        if dragStartX == nil { dragStartX = max(0, scrollX) }
                        if dragStartY == nil { dragStartY = max(0, scrollY) }
                        scrollX = min(max(0, (dragStartX ?? 0) - value.translation.width),
                                      max(0, scaledWidth - viewportWidth))
                        scrollY = min(max(0, (dragStartY ?? 0) - value.translation.height),
                                      max(0, scaledHeight - canvasHeight))
                    }
                    .onEnded { _ in
                        dragStartX = nil
                        dragStartY = nil
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { factor in
                        if pinchStartZoom == nil { pinchStartZoom = zoom }
                        changeZoom(to: (pinchStartZoom ?? 1) * factor)
                    }
                    .onEnded { _ in pinchStartZoom = nil }
            )

            HStack(spacing: 6) {
                panButton("西街", symbol: "chevron.left", delta: -viewportWidth * 0.65)
                Spacer()
                HStack(spacing: 3) {
                    zoomButton("缩小地图", symbol: "minus.magnifyingglass", factor: 1 / 1.35)
                    Text("\(Int(zoom * 100))%")
                        .font(.caption.bold().monospacedDigit())
                        .frame(minWidth: 39)
                    zoomButton("放大地图", symbol: "plus.magnifyingglass", factor: 1.35)
                }
                .padding(.horizontal, 4)
                .background(Color(red: 0.97, green: 0.96, blue: 0.93).opacity(0.91), in: Capsule())
                panButton("东岸", symbol: "chevron.right", delta: viewportWidth * 0.65)
            }
            .foregroundStyle(Color(red: 0.20, green: 0.20, blue: 0.23))
            .padding(.horizontal, 6)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)
        }
        .frame(height: canvasHeight)
        .onAppear {
            self.canvasWidth = canvasWidth
            self.canvasHeight = canvasHeight
            self.viewportWidth = viewportWidth
            if scrollX < 0 { center(on: .init(x: 0.56, y: 0.72)) }
        }
    }

    private func nightAtmosphere(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.025, green: 0.045, blue: 0.13).opacity(0.82), location: 0),
                    .init(color: Color(red: 0.045, green: 0.09, blue: 0.21).opacity(0.70), location: 0.38),
                    .init(color: Color(red: 0.045, green: 0.10, blue: 0.19).opacity(0.53), location: 1),
                ], startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                for index in 0..<70 {
                    let x = CGFloat((index * 137 + 47) % 997) / 997 * size.width
                    let y = CGFloat((index * 271 + 73) % 997) / 997 * size.height * 0.26
                    let radius: CGFloat = index.isMultiple(of: 11) ? 1.45 : 0.65
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y,
                                                       width: radius * 2, height: radius * 2)),
                                 with: .color(.white.opacity(index.isMultiple(of: 3) ? 0.62 : 0.36)))
                }
            }
            ForEach(Array([UnitPoint(x: 0.14, y: 0.64), UnitPoint(x: 0.30, y: 0.65),
                           UnitPoint(x: 0.49, y: 0.52), UnitPoint(x: 0.57, y: 0.75),
                           UnitPoint(x: 0.73, y: 0.43), UnitPoint(x: 0.78, y: 0.22),
                           UnitPoint(x: 0.77, y: 0.62), UnitPoint(x: 0.91, y: 0.53)].enumerated()), id: \.offset) { light in
                RadialGradient(colors: [Color(red: 1, green: 0.74, blue: 0.31).opacity(0.53), .clear],
                               center: .center, startRadius: 0, endRadius: 68)
                    .frame(width: 136, height: 136)
                    .position(x: width * light.element.x, y: height * light.element.y)
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    private func placeMarker(_ place: HarborPlace) -> some View {
        let unlocked = isUnlocked(place)
        return Button {
            guard unlocked else { return }
            dismissDialogue()
            entryTask?.cancel()
            center(on: place.markerPoint)
            entryTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(440))
                guard !Task.isCancelled else { return }
                enter(place)
            }
        } label: {
            Text(place.markerTitle)
                .font(.system(size: 14, weight: .heavy, design: .serif))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(red: 0.97, green: 0.96, blue: 0.93).opacity(0.91), in: Capsule())
            .foregroundStyle(unlocked ? Color(red: 0.20, green: 0.20, blue: 0.23) : .gray)
            .frame(minWidth: 66, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(unlocked ? "进入\(place.title)" : "\(place.title)尚未开放")
    }

    private func ambientPedestrians(width: CGFloat, height: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 0.15)) { timeline in
            ZStack {
                ForEach(HarborPedestrianCatalog.current.citizens) { pedestrian in
                    let effectiveDate = talkingCitizen?.id == pedestrian.id
                        ? (talkingCitizen?.freezeDate ?? timeline.date)
                        : (pedestrianTiming[pedestrian.id]?.effectiveDate(at: timeline.date)
                           ?? timeline.date)
                    let pose = pedestrian.pose(at: effectiveDate, variant: roamingVariant)
                    let behindArchitecture = HarborAlleyVisibility.isHidden(pose.point)
                    Button {
                        focusCitizen(pedestrian)
                    } label: {
                        ZStack {
                            Ellipse()
                                .fill(.black.opacity(0.38))
                                .frame(width: 12, height: 4)
                                .offset(y: 8)
                            walkAtlasFrame(pedestrian.atlasName, frame: pose.frame)
                                .scaleEffect(x: pose.facingEast ? -1 : 1, y: 1)
                            Text(pedestrian.name)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 3)
                                .background(.black.opacity(0.7), in: Capsule())
                                .offset(y: -18)
                        }
                        .frame(width: 54, height: 54)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // The atlas feet end at about 78% of its height; center the
                    // foot and contact shadow on the surveyed pavement point.
                    .position(x: width * pose.point.x, y: height * pose.point.y - 8)
                    .opacity(behindArchitecture ? 0 : 1)
                    .allowsHitTesting(!behindArchitecture)
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0)
                        .onChanged { _ in pausePedestrian(pedestrian.id) })
                    .onHover { hovered in
                        if hovered { pausePedestrian(pedestrian.id) }
                    }
                    .accessibilityLabel("与\(pedestrian.name)交谈")
                }
            }
            .frame(width: width, height: height)
        }
    }

    private func pausePedestrian(_ id: String) {
        guard talkingCitizen?.id != id else { return }
        let now = Date()
        let previousOffset = pedestrianTiming[id]?.offset(at: now) ?? 0
        pedestrianTiming[id] = HarborPedestrianTiming(baseOffset: previousOffset,
                                                       pausedAt: now)
    }

    private func nearestVisibleCitizen(to tap: CGPoint, width: CGFloat,
                                       height: CGFloat) -> HarborPedestrian? {
        let now = Date()
        var nearest: HarborPedestrian?
        var nearestDistance: CGFloat = 42
        for pedestrian in HarborPedestrianCatalog.current.citizens {
            let effectiveDate = talkingCitizen?.id == pedestrian.id
                ? (talkingCitizen?.freezeDate ?? now)
                : (pedestrianTiming[pedestrian.id]?.effectiveDate(at: now) ?? now)
            let pose = pedestrian.pose(at: effectiveDate, variant: roamingVariant)
            if HarborAlleyVisibility.isHidden(pose.point) { continue }
            let distance = hypot(tap.x - width * pose.point.x,
                                 tap.y - (height * pose.point.y - 8))
            if distance <= nearestDistance {
                nearest = pedestrian
                nearestDistance = distance
            }
        }
        return nearest
    }

    private func focusCitizen(_ pedestrian: HarborPedestrian) {
        entryTask?.cancel()
        dialogueTask?.cancel()
        dismissDialogue()
        let now = Date()
        let effectiveDate = pedestrianTiming[pedestrian.id]?.effectiveDate(at: now) ?? now
        let pose = pedestrian.pose(at: effectiveDate, variant: roamingVariant)
        talkingCitizen = .init(id: pedestrian.id, name: pedestrian.name,
                               text: pedestrian.dialogue, point: pose.point,
                               freezeDate: effectiveDate)
        bubbleVisible = false
        center(on: pose.point)
        dialogueTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(340))
            guard !Task.isCancelled, talkingCitizen?.id == pedestrian.id else { return }
            withAnimation(.easeOut(duration: 0.16)) { bubbleVisible = true }
        }
    }

    private func dismissDialogue() {
        dialogueTask?.cancel()
        if let citizen = talkingCitizen {
            let now = Date()
            pedestrianTiming[citizen.id] = HarborPedestrianTiming(
                baseOffset: max(0, now.timeIntervalSince(citizen.freezeDate)),
                pausedAt: now)
        }
        bubbleVisible = false
        talkingCitizen = nil
    }

    private func speechBubble(for citizen: HarborCitizenDialogue) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(citizen.name)
                        .font(.system(size: 14, weight: .bold, design: .serif))
                    Spacer(minLength: 4)
                    Button { dismissDialogue() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("结束与\(citizen.name)的对话")
                }
                Text(citizen.text)
                    .font(.system(size: 12, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(Color(red: 0.16, green: 0.18, blue: 0.23))
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.25), radius: 7, y: 3)
            HarborSpeechTail()
                .fill(.white)
                .frame(width: 17, height: 10)
        }
        .frame(width: min(230, max(180, viewportWidth - 38)))
        .accessibilityElement(children: .contain)
    }

    private func walkAtlasFrame(_ name: String, frame: Int) -> some View {
        Image(decorative: name)
            .resizable()
            .interpolation(.high)
            .frame(width: 8 * 28, height: 28)
            .offset(x: -CGFloat(frame) * 28)
            .frame(width: 28, height: 28, alignment: .leading)
            .clipped()
    }

    private func isUnlocked(_ place: HarborPlace) -> Bool {
        switch place {
        case .church: game.cityServiceIsUnlocked(.church)
        case .tavern: game.selectedPathID == .fool && game.cityServiceIsUnlocked(.church)
        case .cafe: game.venueIsUnlocked("midnight-clock-cafe")
        }
    }

    private func enter(_ place: HarborPlace) {
        guard isUnlocked(place) else { return }
        if place == .cafe { game.prepareVenue("midnight-clock-cafe") }
        presentedPlace = place
    }

    private func panButton(_ title: String, symbol: String, delta: CGFloat) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.28)) {
                scrollX = min(max(0, max(0, scrollX) + delta),
                              max(0, canvasWidth * zoom - viewportWidth))
            }
        } label: {
            Label(title, systemImage: symbol)
                .font(.caption.bold())
                .padding(.horizontal, 7).padding(.vertical, 7)
                .background(Color(red: 0.97, green: 0.96, blue: 0.93).opacity(0.91), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("查看\(title)地图")
    }

    private func zoomButton(_ title: String, symbol: String, factor: CGFloat) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { changeZoom(to: zoom * factor) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func changeZoom(to requested: CGFloat) {
        guard canvasWidth > 0, canvasHeight > 0, viewportWidth > 0 else { return }
        let next = min(2.6, max(1, requested))
        let focusX = (max(0, scrollX) + viewportWidth * 0.5) / (canvasWidth * zoom)
        let focusY = (max(0, scrollY) + canvasHeight * 0.5) / (canvasHeight * zoom)
        zoom = next
        scrollX = min(max(0, focusX * canvasWidth * next - viewportWidth * 0.5),
                      max(0, canvasWidth * next - viewportWidth))
        scrollY = min(max(0, focusY * canvasHeight * next - canvasHeight * 0.5),
                      max(0, canvasHeight * next - canvasHeight))
    }

    private func center(on point: UnitPoint) {
        guard canvasWidth > 0, canvasHeight > 0, viewportWidth > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            scrollX = min(max(0, canvasWidth * zoom * point.x - viewportWidth * 0.5),
                          max(0, canvasWidth * zoom - viewportWidth))
            scrollY = min(max(0, canvasHeight * zoom * point.y - canvasHeight * 0.5),
                          max(0, canvasHeight * zoom - canvasHeight))
        }
    }

}

private enum HarborPlace: String, CaseIterable, Identifiable {
    case church, tavern, cafe

    var id: String { rawValue }
    var title: String {
        switch self {
        case .church: "教会"
        case .tavern: "酒馆通缉"
        case .cafe: "午夜钟咖啡馆"
        }
    }
    var markerTitle: String {
        switch self {
        case .church: "教会"
        case .tavern: "酒馆"
        case .cafe: "咖啡馆"
        }
    }
    var markerPoint: UnitPoint {
        switch self {
        case .church: .init(x: 0.79, y: 0.20)
        case .tavern: .init(x: 0.472, y: 0.49)
        case .cafe: .init(x: 0.35, y: 0.58)
        }
    }
    var arrivalPoint: UnitPoint {
        switch self {
        case .church: .init(x: 0.77, y: 0.25)
        case .tavern: .init(x: 0.46, y: 0.54)
        case .cafe: .init(x: 0.35, y: 0.64)
        }
    }
}

private struct HarborPedestrianCatalog: Decodable {
    let referenceWidth: CGFloat
    let referenceHeight: CGFloat
    let citizens: [HarborPedestrian]

    static let current: Self = {
        guard let url = Bundle.main.url(forResource: "harbor-pedestrians",
                                        withExtension: "json", subdirectory: "WisteriaMap"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Self.self, from: data) else {
            assertionFailure("Bundled harbor pedestrian routes are missing")
            return Self(referenceWidth: 2048, referenceHeight: 1143,
                        citizens: [])
        }
        return catalog
    }()
}

private struct HarborRoadNetwork: Decodable {
    let nodes: [[CGFloat]]
    let edges: [[Int]]

    static let current: Self = {
        guard let url = Bundle.main.url(forResource: "navigation", withExtension: "json",
                                        subdirectory: "WisteriaMap"),
              let data = try? Data(contentsOf: url),
              let network = try? JSONDecoder().decode(Self.self, from: data) else {
            assertionFailure("Bundled harbor road network is missing")
            return Self(nodes: [[1132, 1000], [1160, 1000]], edges: [[0, 1]])
        }
        return network
    }()
}

/// The player's blue alleys include short sections that disappear behind the
/// drawn buildings.  Do not render a pedestrian over a roof merely because a
/// 2D street centerline runs behind that foreground artwork.
private enum HarborAlleyVisibility {
    static func isHidden(_ point: UnitPoint) -> Bool {
        let x = point.x * 2048
        let y = point.y * 1143
        let upperRoofs = x >= 495 && x <= 640 && y >= 468 && y <= 555
        let middleBlock = x >= 390 && x <= 715 && y >= 555 && y <= 710
        let lowerRoofs = x >= 290 && x <= 435 && y >= 690 && y <= 785
        return upperRoofs || middleBlock || lowerRoofs
    }
}

private struct HarborPedestrian: Decodable, Identifiable {
    let id: String
    let name: String
    let atlasName: String
    let routes: [[[CGFloat]]]
    let pixelsPerSecond: Double
    let phase: Double
    let frameDuration: Double
    let dialogue: String

    func pose(at date: Date, variant: Int) -> (point: UnitPoint, facingEast: Bool, frame: Int) {
        guard !routes.isEmpty else {
            return (.init(x: 0.5, y: 0.7), true, 0)
        }
        let route = routes[variant % routes.count]
        guard route.count > 1 else {
            return (.init(x: route[0][0] / 2048, y: route[0][1] / 1143), true, 0)
        }
        var total = 0.0
        for index in 1..<route.count {
            total += hypot(Double(route[index][0] - route[index - 1][0]),
                           Double(route[index][1] - route[index - 1][1]))
        }
        let distance = (date.timeIntervalSinceReferenceDate * pixelsPerSecond + phase * total)
            .truncatingRemainder(dividingBy: total)
        var traversed = 0.0
        var segment = route.count - 2
        var fraction: CGFloat = 1
        for index in 1..<route.count {
            let length = hypot(Double(route[index][0] - route[index - 1][0]),
                               Double(route[index][1] - route[index - 1][1]))
            if distance <= traversed + length {
                segment = index - 1
                fraction = CGFloat((distance - traversed) / max(length, 0.001))
                break
            }
            traversed += length
        }
        let start = route[segment]
        let end = route[segment + 1]
        let point = UnitPoint(
            x: (start[0] + (end[0] - start[0]) * fraction)
                / HarborPedestrianCatalog.current.referenceWidth,
            y: (start[1] + (end[1] - start[1]) * fraction)
                / HarborPedestrianCatalog.current.referenceHeight)
        let frame = Int((date.timeIntervalSinceReferenceDate / frameDuration + phase * 3)
            .truncatingRemainder(dividingBy: 8))
        let facingSegment = stride(from: segment, through: 0, by: -1).first {
            abs(route[$0 + 1][0] - route[$0][0]) > 0.5
        } ?? segment
        return (point, route[facingSegment + 1][0] > route[facingSegment][0], frame)
    }
}

private struct HarborPedestrianTiming {
    let baseOffset: TimeInterval
    let pausedAt: Date

    func offset(at date: Date) -> TimeInterval {
        baseOffset + min(2, max(0, date.timeIntervalSince(pausedAt)))
    }

    func effectiveDate(at date: Date) -> Date {
        date.addingTimeInterval(-offset(at: date))
    }
}

private struct HarborCitizenDialogue: Identifiable {
    let id: String
    let name: String
    let text: String
    let point: UnitPoint
    let freezeDate: Date
}

private struct HarborSpeechTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: .init(x: rect.minX, y: rect.minY))
            path.addLine(to: .init(x: rect.midX, y: rect.maxY))
            path.addLine(to: .init(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}
