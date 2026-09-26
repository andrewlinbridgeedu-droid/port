import MistportCombatCore
import SwiftUI

struct BountyCardResult {
    let modeName: String
    let outcome: MPCPokerOutcome
    let wager: Int
    let netCopper: Int
}

/// The tavern pans across a wide painted room with a subtle bounded 2.5D turn.
/// The original art and Mor portrait remain separate, unchanged assets.
struct TavernInteriorView: View {
    @Bindable var game: GameStore
    let onBack: () -> Void
    @State private var showsBoard = false
    @State private var showsPoker = ProcessInfo.processInfo.arguments.contains("--preview-tavern-poker")
    @State private var talkingToMor = ProcessInfo.processInfo.arguments.contains("--preview-tavern-dialogue")
    @State private var cameraPosition: CGFloat = ProcessInfo.processInfo.arguments.contains("--preview-tavern-look-right")
        || ProcessInfo.processInfo.arguments.contains("--preview-tavern-dialogue") ? 0.96
        : ProcessInfo.processInfo.arguments.contains("--preview-tavern-look-center") ? 0.50 : 0.06
    @GestureState private var dragDistance: CGFloat = 0
    private let gold = Color(red: 0.94, green: 0.77, blue: 0.47)

    var body: some View {
        GeometryReader { geometry in
            let sceneHeight = geometry.size.height * 1.04
            let sceneWidth = sceneHeight * (16.0 / 9.0)
            let overflow = max(0, (sceneWidth - geometry.size.width) / 2)
            let position = min(1, max(0, cameraPosition - dragDistance / max(1, overflow * 2)))
            ZStack(alignment: .top) {
                Image("BountyTavernPanorama4K")
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .blur(radius: 25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                ZStack {
                    Image("BountyTavernPanorama4K")
                        .resizable()
                        .frame(width: sceneWidth, height: sceneHeight)
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            cameraPosition = 0.96
                            talkingToMor = true
                        }
                    } label: {
                        Text("灰筹·莫尔")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(.white.opacity(0.94), in: Capsule())
                            .foregroundStyle(Color(red: 0.20, green: 0.19, blue: 0.20))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("与灰筹莫尔对话，前港务抵押登记员")
                    .position(x: sceneWidth * 0.87, y: sceneHeight * 0.24)
                }
                .frame(width: sceneWidth, height: sceneHeight)
                .rotation3DEffect(.degrees((Double(position) - 0.5) * 4.0),
                                  axis: (x: 0, y: 1, z: 0), perspective: 0.22)
                .offset(x: overflow * (1 - 2 * position))
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .updating($dragDistance) { value, state, _ in state = value.translation.width }
                        .onEnded { value in
                            let nextPosition = min(1, max(0, cameraPosition - value.translation.width / max(1, overflow * 2)))
                            cameraPosition = nextPosition
                            if nextPosition < 0.70 { talkingToMor = false }
                        }
                )
                .ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.78), .clear, .clear, .black.opacity(0.80)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold))
                                .frame(width: 44, height: 44)
                                .background(.black.opacity(0.5), in: Circle())
                        }.accessibilityLabel("返回港城")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("暮钟酒馆").font(.system(size: 26, weight: .heavy, design: .serif))
                            Text("左右拖动看酒馆 · 灰筹的牌桌")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.82))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20).padding(.top, max(52, geometry.safeAreaInsets.top + 14))
                    HStack(spacing: 10) {
                        Button("← 吧台") {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                cameraPosition = 0.04
                                talkingToMor = false
                            }
                        }
                        Spacer()
                        Button("莫尔牌桌 →") {
                            withAnimation(.easeInOut(duration: 0.35)) { cameraPosition = 0.96 }
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 15).padding(.vertical, 9)
                    .background(.black.opacity(0.42), in: Capsule())
                    .padding(.horizontal, 20).padding(.top, 10)
                    Spacer()
                    VStack(alignment: .leading, spacing: 11) {
                        Text(talkingToMor
                             ? (game.tavernPokerUnlocked ? "莫尔把两副牌推到灯下。" : "莫尔洗着牌，抬头看了你一眼。")
                             : "吧台旁的旧相识")
                            .font(.system(size: 19, weight: .bold, design: .serif)).foregroundStyle(gold)
                        Text(talkingToMor
                             ? (game.tavernPokerUnlocked
                                ? "“弥伦的账结了。以后坐这儿，押铜也好；我偶尔拿一件收回的抵押物当彩头。赢了拿走，输了别赊账。”"
                                : "“今天先记住这张桌子。等借脸人的事有了结果，再回来找我；我给你留一局。”")
                             : "点莫尔交谈，或去吧台领取与交还通缉委托。")
                            .font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
                        if let prize = game.availableTavernPrize, game.tavernPokerUnlocked {
                            Text("今日彩头 · \(prize.name) · 斗地主押40铜 · 一次机会")
                                .font(.system(size: 12, weight: .bold)).foregroundStyle(gold)
                        }
                        HStack(spacing: 10) {
                            Button("悬赏告示") { showsBoard = true }
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(.white.opacity(0.16), in: Capsule())
                            Button(game.tavernPokerUnlocked ? "与莫尔打牌" : "问莫尔的牌局") {
                                if game.tavernPokerUnlocked {
                                    showsPoker = true
                                } else {
                                    withAnimation(.easeInOut(duration: 0.35)) {
                                        cameraPosition = 0.96
                                        talkingToMor = true
                                    }
                                }
                            }
                            .accessibilityLabel(game.tavernPokerUnlocked ? "与莫尔打牌" : "向莫尔打听将来的牌局")
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.20))
                            .background(gold, in: Capsule())
                        }
                        .font(.system(size: 13, weight: .bold))
                        .buttonStyle(.plain)
                    }
                    .padding(17)
                    .background(.black.opacity(0.66), in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 17)
                    .padding(.bottom, max(24, geometry.safeAreaInsets.bottom + 12))
                }
            }
            .foregroundStyle(.white)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .task { game.refreshTavernPrize() }
        .onChange(of: showsBoard) { _, open in
            if !open { game.refreshTavernPrize() }
        }
        .fullScreenCover(isPresented: $showsBoard) {
            ChurchBountyBoard(game: game, onBack: { showsBoard = false }, origin: "酒馆")
        }
        .fullScreenCover(isPresented: $showsPoker) {
            BountyPokerRound(game: game, caseID: "tavern") { _ in }
        }
    }
}

/// Optional informant table. The same staked hand survives closing this sheet.
struct BountyPokerRound: View {
    @Bindable var game: GameStore
    let caseID: String
    let onFinish: (BountyCardResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var wager = 10
    @State private var round: MPCPokerRound?
    @State private var douGame: MPCDouGame?
    @State private var discarded: Set<Int> = []
    @State private var douSelected: Set<String> = []
    @State private var result: MPCPokerShowdown?
    @State private var errorText: String?
    @State private var mode: CardMode = .simple
    @State private var showsHelp = false
    @State private var featuredPrize = false

    private enum CardMode: String { case simple, landlord }

    private let gold = Color(red: 0.92, green: 0.75, blue: 0.42)
    private let cream = Color(red: 0.96, green: 0.92, blue: 0.81)
    private var isTavernFreeplay: Bool { caseID == "tavern" }
    private var opponentName: String { caseID == "b03" ? "码头老水手" : "灰筹·莫尔" }
    private var caseTitle: String { caseID == "b03" ? "溺钟海盗" : isTavernFreeplay ? "酒馆常驻牌桌" : "借脸人·弥伦" }
    private var clueTitle: String { caseID == "b03" ? "逆钟暗号的来历" : "蜡面交易的见面线索" }
    private var backdropName: String { caseID == "b03" ? "BountyCityPanorama" : "BountyTavernDepthRoom" }
    private var activePrize: MPCTavernPrize? {
        guard let douGame else { return nil }
        return game.churchServices.tavernFeaturedGames[douGame.gameID]
    }

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = min(64, max(44, (geometry.size.width - 78) / 5))
            ZStack {
                Image(backdropName)
                    .resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(colors: [
                            Color(red: 0.045, green: 0.09, blue: 0.16).opacity(0.88),
                            Color(red: 0.025, green: 0.09, blue: 0.14).opacity(0.96),
                            Color(red: 0.025, green: 0.055, blue: 0.10).opacity(0.98)
                        ], startPoint: .top, endPoint: .bottom)
                    }
                    .ignoresSafeArea()
                if mode == .landlord && geometry.size.width > geometry.size.height {
                    landscapeLandlord(geometry: geometry, cardWidth: cardWidth)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            header
                            invitation
                            modePicker
                            if mode == .simple {
                                if let round {
                                    table(round: round, cardWidth: cardWidth)
                                } else {
                                    wagerPicker(cardWidth: cardWidth)
                                }
                            } else {
                                if let douGame { douTable(douGame) }
                                else { douWagerPicker(cardWidth: cardWidth) }
                            }
                            rules
                            if let errorText {
                                Text(errorText).font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(red: 1, green: 0.68, blue: 0.55))
                            }
                            Button(round == nil && douGame == nil ? (isTavernFreeplay ? "离开牌桌" : "离开牌桌 · 改查公开档案") : "暂离牌桌 · 下次继续此局") { dismiss() }
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.78))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 52)
                        .padding(.bottom, 24)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .background(Color(red: 0.025, green: 0.055, blue: 0.10).ignoresSafeArea())
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onAppear {
            if isTavernFreeplay { game.refreshTavernPrize() }
            round = game.churchServices.pokerActiveRounds[caseID]
            douGame = game.churchServices.douActiveGames[caseID]
            if douGame != nil { mode = .landlord }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-bounty-landlord")
                || ProcessInfo.processInfo.arguments.contains("--preview-tavern-poker") { mode = .landlord }
            #endif
            MistportOrientation.set(mode == .landlord ? .landscapeRight : .portrait)
        }
        .onChange(of: mode) { _, newMode in
            MistportOrientation.set(newMode == .landlord ? .landscapeRight : .portrait)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            MistportOrientation.set(mode == .landlord ? .landscapeRight : .portrait)
        }
        .onDisappear { MistportOrientation.set(.portrait) }
        .sheet(isPresented: $showsHelp) { helpSheet }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isTavernFreeplay ? "雾港 · 酒馆牌局" : "雾港 · 通缉情报")
                    .font(.system(size: 11, weight: .bold)).tracking(2.1).foregroundStyle(gold)
                Text(mode == .simple ? "五张换牌" : "雾港斗地主")
                    .font(.system(size: 28, weight: .heavy, design: .serif))
                Text(caseTitle)
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Button { showsHelp = true } label: {
                Image(systemName: "questionmark")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(width: 38, height: 38)
                    .background(gold.opacity(0.18), in: Circle())
                    .overlay(Circle().stroke(gold.opacity(0.7), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("查看两种牌局玩法")
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.13), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("暂离牌局")
        }
    }

    /// Dou Dizhu alone uses a wide table. The rest of the app, including
    /// five-card draw, remains in portrait and keeps its original navigation.
    private func landscapeLandlord(geometry: GeometryProxy, cardWidth: CGFloat) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text("雾港斗地主")
                    .font(.system(size: 20, weight: .heavy, design: .serif))
                    .foregroundStyle(gold)
                Text("\(caseTitle) · \(opponentName)")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(cream)
                Spacer()
                Text("\(game.venueCoins) 铜")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(gold)
                Button { showsHelp = true } label: {
                    Image(systemName: "questionmark.circle.fill").font(.system(size: 27))
                }
                .accessibilityLabel("查看两种牌局玩法")
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 27))
                }
                .accessibilityLabel("暂离牌局")
                .buttonStyle(.plain)
            }
            .frame(height: 36)
            if let douGame {
                HStack(alignment: .top, spacing: 12) {
                    landscapeDouSidebar(douGame)
                        .frame(width: min(250, geometry.size.width * 0.30))
                    Rectangle().fill(gold.opacity(0.25)).frame(width: 1)
                    landscapeDouAction(douGame)
                        .frame(maxWidth: .infinity)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 10) {
                        invitation
                        Button("切回五张换牌") { mode = .simple }
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(.white.opacity(0.12), in: Capsule())
                            .buttonStyle(.plain)
                    }
                    .frame(width: min(250, geometry.size.width * 0.30))
                    landscapeWagerPicker
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .padding(.leading, max(20, geometry.safeAreaInsets.leading + 10))
        .padding(.trailing, max(20, geometry.safeAreaInsets.trailing + 10))
        .padding(.top, max(12, geometry.safeAreaInsets.top + 8))
        .padding(.bottom, max(8, geometry.safeAreaInsets.bottom))
    }

    private func landscapeDouSidebar(_ state: MPCDouGame) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                douSeat(state, player: 1)
                douSeat(state, player: 2)
            }
            Text("押注 \(state.wager) 铜 · 叫分 \(state.highestBid) · 倍数 ×\(state.multiplier)")
                .font(.system(size: 11, weight: .bold)).foregroundStyle(gold)
            Text(state.recentAction)
                .font(.system(size: 11)).foregroundStyle(cream)
                .fixedSize(horizontal: false, vertical: true)
            if !state.lastPlay.isEmpty {
                Text("桌上 · \(douName(state.lastPlayer!)) 出 \(MPCDouRules.classify(state.lastPlay)?.label ?? "牌")")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(gold)
                douTrick(state)
            }
            Spacer(minLength: 0)
            Text(isTavernFreeplay ? "常驻牌桌可押铜；特定日子有物品彩头。" : "赢牌得口供；不玩也可查公开档案。")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.7))
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.035, green: 0.17, blue: 0.19).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private var landscapeWagerPicker: some View {
        let prize = isTavernFreeplay ? game.availableTavernPrize : nil
        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("三人 · 两副牌 · 叫地主")
                    .font(.system(size: 17, weight: .bold, design: .serif)).foregroundStyle(gold)
                Spacer()
                Text("108张随机牌 · 无保底")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(cream)
            }
            if let prize {
                Button {
                    featuredPrize.toggle()
                    if featuredPrize { wager = 40 }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: featuredPrize ? "checkmark.seal.fill" : "seal")
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("今夜彩头 · \(prize.name)")
                                .font(.system(size: 14, weight: .bold, design: .serif))
                            Text("押40铜 · 赢退押并得物品 · 输失押 · 今日仅一次")
                                .font(.system(size: 10))
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(featuredPrize ? Color(red: 0.08, green: 0.15, blue: 0.20) : cream)
                    .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 58)
                    .background(featuredPrize ? gold : .white.opacity(0.11),
                                in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            } else if isTavernFreeplay {
                Text("今日没有物品彩头，普通铜币局照常开放。")
                    .font(.system(size: 11)).foregroundStyle(cream)
            }
            HStack(spacing: 8) {
                ForEach(MPCDouRules.wagers, id: \.self) { amount in
                    Button { wager = amount; featuredPrize = false } label: {
                        Text("\(amount) 铜")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundStyle(!featuredPrize && wager == amount
                                ? Color(red: 0.08, green: 0.15, blue: 0.20) : cream)
                            .background(!featuredPrize && wager == amount ? gold : .white.opacity(0.11),
                                        in: RoundedRectangle(cornerRadius: 9))
                    }.buttonStyle(.plain)
                }
            }
            Text(featuredPrize ? "物品局胜负都结算，当天不能重开；离桌保留已发牌局。"
                 : "普通局胜按叫分、炸弹赚铜；败只损失押注。已发牌局可离桌保留。")
                .font(.system(size: 10)).foregroundStyle(cream)
                .lineLimit(2)
            Button { startDou() } label: {
                Text(featuredPrize ? "押40铜 · 争夺\(prize?.name ?? "彩头")" : "押\(wager)铜 · 洗牌开局")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.20))
                    .frame(maxWidth: .infinity, minHeight: 43)
                    .background(gold, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(game.venueCoins < (featuredPrize ? 40 : wager))
            .opacity(game.venueCoins < (featuredPrize ? 40 : wager) ? 0.45 : 1)
        }
        .padding(12)
        .background(Color(red: 0.035, green: 0.17, blue: 0.19).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func landscapeDouAction(_ state: MPCDouGame) -> some View {
        let target = MPCDouRules.classify(state.lastPlay)
        let selectedCards = state.hands[0].filter { douSelected.contains($0.id) }
        let chosen = MPCDouRules.classify(selectedCards)
        let canPlay = chosen != nil && (target == nil || chosen!.beats(target!))
        return VStack(alignment: .leading, spacing: 6) {
            if state.phase == .bidding {
                Text("叫地主 · 看牌后叫 0–3 分，最高者拿 6 张底牌")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(gold)
                douHand(state, selectable: false)
                HStack(spacing: 7) {
                    ForEach(0...3, id: \.self) { points in
                        Button(points == 0 ? "不叫" : "叫 \(points) 分") { bidDou(state, points: points) }
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(points == 0 ? cream : Color(red: 0.07, green: 0.12, blue: 0.20))
                            .background(points == 0 ? Color.white.opacity(0.14) : gold,
                                        in: RoundedRectangle(cornerRadius: 9))
                            .disabled(points != 0 && points <= state.highestBid)
                            .opacity(points != 0 && points <= state.highestBid ? 0.35 : 1)
                    }
                }
            } else if state.phase == .playing {
                Text(target == nil ? "新一轮 · 你先出" : "需压过 \(target!.label) · \(douName(state.lastPlayer!))")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(gold)
                douHand(state)
                Text(chosen == nil ? "点牌抬起；向左右滑牌扇。" : canPlay ? "已选 \(chosen!.label) · 可出" : "牌型压不过桌面")
                    .font(.system(size: 11)).foregroundStyle(canPlay ? gold : cream)
                HStack(spacing: 8) {
                    Button("提示") { hintDou(state) }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                    Button("不出") { passDou(state) }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                        .disabled(target == nil).opacity(target == nil ? 0.4 : 1)
                    Button("出牌") { playDou(state) }
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.20))
                        .background(gold, in: RoundedRectangle(cornerRadius: 9))
                        .disabled(!canPlay).opacity(canPlay ? 1 : 0.4)
                }
                .font(.system(size: 13, weight: .bold))
                .buttonStyle(.plain)
            } else if let settlement = state.settlement {
                Text(douOutcomeTitle(settlement))
                    .font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(gold)
                Text(douOutcomeDetail(settlement))
                    .font(.system(size: 13)).foregroundStyle(cream)
                Button(settlement.playerWon ? (isTavernFreeplay ? "回到酒馆" : "带口供返回调查") : "再押一局") {
                    if settlement.playerWon { dismiss() }
                    else { douGame = nil; douSelected.removeAll() }
                }
                .buttonStyle(.borderedProminent).tint(gold)
            }
            if let errorText {
                Text(errorText).font(.system(size: 10)).foregroundStyle(gold)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.035, green: 0.17, blue: 0.19).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            modeButton(.simple, title: "五张换牌", subtitle: isTavernFreeplay ? "轻松 · 押铜对局" : "轻松 · 五局内得口供")
            modeButton(.landlord, title: "雾港斗地主", subtitle: "三人两副 · 全随机")
        }
    }

    private func modeButton(_ target: CardMode, title: String, subtitle: String) -> some View {
        Button { mode = target; errorText = nil } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .bold, design: .serif))
                Text(subtitle).font(.system(size: 10)).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(mode == target ? Color(red: 0.06, green: 0.15, blue: 0.20) : cream)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 54).padding(.horizontal, 11)
            .background(mode == target ? gold : Color.white.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled((round != nil && target != .simple) || (douGame != nil && target != .landlord))
        .accessibilityLabel("\(title)，\(subtitle)")
    }

    private var invitation: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 6) {
                Text(opponentName)
                    .font(.system(size: 18, weight: .bold, design: .serif)).foregroundStyle(gold)
                Text(isTavernFreeplay ? "“今晚想押铜，还是看看我的彩头？”" : "“赢我一局，我告诉你\(clueTitle)。”")
                    .font(.system(size: 14, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(isTavernFreeplay ? "前港务抵押登记员。结案后留在酒馆开桌；彩头牌局胜负都要结算。" : "这是线索交易；不打牌也可去公开档案查证。")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if caseID != "b03" {
                Image("BountyNPCMor")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 69, height: 110)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(Color(red: 0.075, green: 0.13, blue: 0.20).opacity(0.94),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(gold.opacity(0.38), lineWidth: 1))
    }

    private func wagerPicker(cardWidth: CGFloat) -> some View {
        let attempts = game.churchServices.pokerSimpleAttempts[caseID] ?? 0
        let covered = !isTavernFreeplay && attempts >= 4 && game.venueCoins < wager
        return VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("先押注，再发牌")
                    .font(.system(size: 18, weight: .bold, design: .serif)).foregroundStyle(cream)
                Spacer()
                Text("持有 \(game.venueCoins) 铜")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(gold)
            }
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { _ in cardBack(width: cardWidth * 0.8) }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: 9) {
                ForEach(MPCPokerRules.wagers, id: \.self) { amount in
                    Button { wager = amount } label: {
                        Text("\(amount) 铜")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(wager == amount ? Color(red: 0.08, green: 0.15, blue: 0.20) : cream)
                            .background(wager == amount ? gold : Color.white.opacity(0.09),
                                        in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("押注\(amount)铜币")
                }
            }
            Text(isTavernFreeplay ? "胜：返还赌注并赢同额铜币。负：赌注归对手。平：退还赌注。常驻牌局没有保底。" : "胜：返还赌注并赢同额铜币，取得口供。负：赌注归对手。平：退还赌注，重开一局。")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(cream)
                .fixedSize(horizontal: false, vertical: true)
            if !isTavernFreeplay { Text(attempts >= 4
                 ? "第5局保底：不管换哪三张，都能赢得口供。铜币不足时，前四局赌注抵作本局押金；本局不再扣钱，也不赚铜币。"
                 : "情报保底还差 \(5 - attempts) 局；此前没赢，第5局一定得到口供。")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(gold)
                .fixedSize(horizontal: false, vertical: true) }
            Button { startRound() } label: {
                Text(covered ? "旧赌注抵押 · 保底发牌" : "押 \(wager) 铜 · 发牌")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.18))
                    .background(gold, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(game.venueCoins < wager && !covered)
            .opacity(game.venueCoins < wager && !covered ? 0.55 : 1)
            if game.venueCoins < wager && !covered {
                Text(isTavernFreeplay ? "铜币不足，稍后再来。" : "铜币不足；可离开牌桌，直接查公开档案。")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(15)
        .background(Color(red: 0.035, green: 0.17, blue: 0.19).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 18))
    }

    private func table(round: MPCPokerRound, cardWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(round.wager == 0 ? "前四局赌注已抵押" : "赌注 \(round.wager) 铜 · 已寄存")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(gold)
                Spacer()
                Text(round.wager == 0 ? "本局仅赢口供" : "底池 \(round.wager * 2) 铜")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(cream)
            }
            sectionTitle("对手手牌", detail: result?.dealerRank.label ?? "摊牌才公开")
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { index in
                    if let result { cardFace(result.dealer[index], width: cardWidth * 0.79, selected: false) }
                    else { cardBack(width: cardWidth * 0.79) }
                }
            }
            .frame(maxWidth: .infinity)
            Rectangle().fill(gold.opacity(0.23)).frame(height: 1).padding(.vertical, 4)
            sectionTitle("你的手牌", detail: result?.playerRank.label ?? "点选 0–3 张换掉")
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { index in
                    Button { toggleDiscard(index) } label: {
                        cardFace((result?.player ?? round.player)[index], width: cardWidth,
                                 selected: result == nil && discarded.contains(index))
                    }
                    .buttonStyle(.plain)
                    .disabled(result != nil)
                    .accessibilityLabel("第\(index + 1)张，\((result?.player ?? round.player)[index].label)，\(discarded.contains(index) && result == nil ? "换掉" : "保留")")
                }
            }
            .frame(maxWidth: .infinity)
            if let result {
                Text(outcomeText(result))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(result.outcome == .loss ? Color(red: 1, green: 0.70, blue: 0.56) : gold)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            } else {
                Text("你与对手各持五张；双方各换一次，最多三张。对手换牌不会偷看你的牌。")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                if let result {
                    if result.outcome == .win && !isTavernFreeplay { dismiss() }
                    else { self.result = nil; self.round = nil; discarded.removeAll() }
                } else { showDown(round) }
            } label: {
                Text(result == nil ? "换牌并摊牌" : result?.outcome == .win && !isTavernFreeplay ? "带着口供返回调查" : "再押一局")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.18))
                    .background(gold, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(red: 0.035, green: 0.17, blue: 0.19).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(gold.opacity(0.37), lineWidth: 1))
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(mode == .simple ? "牌型规则" : "出牌规则速览")
                .font(.system(size: 16, weight: .bold, design: .serif)).foregroundStyle(gold)
            Text(mode == .simple
                 ? "同花顺 ＞ 四条 ＞ 葫芦 ＞ 同花 ＞ 顺子 ＞ 三条 ＞ 两对 ＞ 一对 ＞ 高牌"
                 : "地主一人对两名农民；同牌型同张数才能压牌，4–8张炸弹压普通牌，四王天王炸最大。")
                .font(.system(size: 12, weight: .medium)).foregroundStyle(cream)
                .fixedSize(horizontal: false, vertical: true)
            Text(mode == .simple
                 ? "同牌型先比组成牌的点数，再比剩余大牌；完全相同算平局。A 可作最大的牌，也可作 A-2-3-4-5 最小顺子。"
                 : "轮流叫分，地主拿六张底牌并先出；两人连续不出，上一位赢得牌权。先出完牌的一方获胜。点右上角 ？看完整桌规。")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    private func douWagerPicker(cardWidth: CGFloat) -> some View {
        let prize = isTavernFreeplay ? game.availableTavernPrize : nil
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("三人 · 两副牌 · 叫地主")
                    .font(.system(size: 17, weight: .bold, design: .serif)).foregroundStyle(gold)
                Spacer()
                Text("持有 \(game.venueCoins) 铜").font(.system(size: 11)).foregroundStyle(cream)
            }
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { _ in cardBack(width: cardWidth * 0.8) }
            }.frame(maxWidth: .infinity)
            Text("108张真正随机洗牌。各拿34张，留6张底牌；赢靠叫分、配合与出牌。此模式没有五局保底。")
                .font(.system(size: 12)).foregroundStyle(cream)
                .fixedSize(horizontal: false, vertical: true)
            if let prize {
                Button {
                    featuredPrize.toggle()
                    if featuredPrize { wager = 40 }
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(featuredPrize ? "✓ 今夜彩头 · \(prize.name)" : "今夜彩头 · \(prize.name)")
                            .font(.system(size: 15, weight: .bold, design: .serif))
                        Text("押40铜，仅此一次；胜得\(prize.kind == .relic ? "遗落物" : "晋级主材")并退押，败失40铜。无保底、不附加倍数铜利。")
                            .font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(featuredPrize ? Color(red: 0.07, green: 0.16, blue: 0.19) : cream)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(featuredPrize ? gold : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
            } else if isTavernFreeplay {
                Text("今天没有特殊彩头；普通铜币牌局照常开放。")
                    .font(.system(size: 11)).foregroundStyle(cream)
            }
            HStack(spacing: 9) {
                ForEach(MPCDouRules.wagers, id: \.self) { amount in
                    Button { wager = amount; featuredPrize = false } label: {
                        Text("\(amount) 铜")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .foregroundStyle(wager == amount ? Color(red: 0.08, green: 0.15, blue: 0.20) : cream)
                            .background(wager == amount ? gold : Color.white.opacity(0.09),
                                        in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
            Text(featuredPrize ? "彩头已在桌上封存。胜：退40铜并领取物品；败：失40铜，当天彩头结束。中途离桌保留此局。"
                 : isTavernFreeplay ? "普通局先扣赌注；胜按倍数赢铜，败只失本局赌注。"
                 : "押注先扣，输掉最多失去所押铜币；获胜返还押注，并按叫分、炸弹及春天赚取1–8倍赌注与口供。")
                .font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            Button { startDou() } label: {
                Text(featuredPrize ? "押40铜 · 争夺\(prize?.name ?? "彩头")" : "押 \(wager) 铜 · 洗两副牌")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(Color(red: 0.09, green: 0.13, blue: 0.18))
                    .background(gold, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(game.venueCoins < (featuredPrize ? 40 : wager))
            .opacity(game.venueCoins < (featuredPrize ? 40 : wager) ? 0.55 : 1)
            if game.venueCoins < wager {
                Text(isTavernFreeplay ? "铜币不足，稍后再来。" : "铜币不足；可换简单模式或查公开档案。")
                    .font(.system(size: 11)).foregroundStyle(cream)
            }
        }
        .padding(15)
        .background(Color(red: 0.035, green: 0.17, blue: 0.19).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 18))
    }

    private func douTable(_ state: MPCDouGame) -> some View {
        let target = MPCDouRules.classify(state.lastPlay)
        let selectedCards = state.hands[0].filter { douSelected.contains($0.id) }
        let chosen = MPCDouRules.classify(selectedCards)
        let canPlay = chosen != nil && (target == nil || chosen!.beats(target!))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(activePrize.map { "彩头：\($0.name) · 押\(state.wager)铜" } ?? "押注 \(state.wager) 铜")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(gold)
                Spacer()
                Text("叫分 \(state.highestBid) · 倍数 ×\(state.multiplier)")
                    .font(.system(size: 11)).foregroundStyle(cream)
            }
            HStack(spacing: 8) {
                douSeat(state, player: 1)
                douSeat(state, player: 2)
            }
            Text(state.recentAction)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(cream)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(minHeight: 30)
            if state.phase == .bidding {
                Text("轮到你叫分。叫分最高者成为地主，拿6张底牌并先出。").font(.system(size: 12))
                douHand(state, selectable: false)
                HStack(spacing: 6) {
                    ForEach(0...3, id: \.self) { points in
                        Button(points == 0 ? "不叫" : "\(points)分") { bidDou(state, points: points) }
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .background(points == 0 ? Color.white.opacity(0.12) : gold.opacity(0.86),
                                        in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(points == 0 ? .white : Color(red: 0.07, green: 0.12, blue: 0.20))
                            .disabled(points != 0 && points <= state.highestBid)
                            .opacity(points != 0 && points <= state.highestBid ? 0.3 : 1)
                    }
                }
            } else if state.phase == .playing {
                Text(target == nil ? "新一轮 · 你先出任意合法牌型"
                     : "需压过 \(target!.label)；牌权：\(douName(state.lastPlayer!))")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(gold)
                if !state.lastPlay.isEmpty { douTrick(state) }
                douHand(state)
                Text(chosen == nil ? "点选手牌组成牌型；可点“提示”查看合法出牌。"
                     : canPlay ? "已选 \(chosen!.label) · \(selectedCards.count)张，可出"
                     : "已选 \(chosen!.label)，但压不过当前牌型")
                    .font(.system(size: 11)).foregroundStyle(canPlay ? gold : cream)
                HStack(spacing: 8) {
                    Button("提示") { hintDou(state) }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    Button("不出") { passDou(state) }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        .disabled(target == nil)
                        .opacity(target == nil ? 0.35 : 1)
                    Button("出牌") { playDou(state) }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.20))
                        .background(gold, in: RoundedRectangle(cornerRadius: 10))
                        .disabled(!canPlay)
                        .opacity(canPlay ? 1 : 0.4)
                }
                .font(.system(size: 13, weight: .bold))
                .buttonStyle(.plain)
            } else if let settlement = state.settlement {
                Text(douOutcomeTitle(settlement))
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundStyle(gold)
                Text(douOutcomeDetail(settlement))
                    .font(.system(size: 12)).foregroundStyle(cream)
                Button(settlement.playerWon ? (isTavernFreeplay ? "回到酒馆" : "带口供返回调查") : "再押一局") {
                    if settlement.playerWon { dismiss() }
                    else { douGame = nil; douSelected.removeAll() }
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color(red: 0.08, green: 0.15, blue: 0.20))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(gold, in: Capsule())
            }
        }
        .padding(14)
        .background(Color(red: 0.035, green: 0.17, blue: 0.19).opacity(0.96),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(gold.opacity(0.37), lineWidth: 1))
    }

    private func douSeat(_ state: MPCDouGame, player: Int) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image("BountyPokerCardBack")
                    .resizable().scaledToFill().frame(width: 22, height: 31)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                Text(player == 1 ? opponentName : caseID == "b03" ? "船务信使" : "下班跑堂")
                    .font(.system(size: 11, weight: .bold)).lineLimit(1)
            }
            Text("\(state.hands[player].count) 张 · \(state.landlord == nil ? "待叫分" : state.landlord == player ? "地主" : "农民")")
                .font(.system(size: 10)).foregroundStyle(gold)
        }
        .frame(maxWidth: .infinity).padding(8)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func douHand(_ state: MPCDouGame, selectable: Bool = true) -> some View {
        let cards = state.hands[0].sorted {
            $0.rank != $1.rank ? $0.rank > $1.rank : $0.id < $1.id
        }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("你的手牌 · \(cards.count)张 · \(state.landlord == nil ? "待叫分" : state.landlord == 0 ? "地主" : "农民")")
                    .font(.system(size: 13, weight: .bold, design: .serif)).foregroundStyle(gold)
                Spacer()
                Text("已选 \(douSelected.count) 张")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(cream)
            }
            Text(selectable ? "按点数排成牌扇；左右滑动查看，点牌抬起，再点可收回。"
                            : "左右滑动看牌，决定是否叫地主。")
                .font(.system(size: 10)).foregroundStyle(.white.opacity(0.72))
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: -34) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let selected = douSelected.contains(card.id)
                    Button {
                        if douSelected.contains(card.id) { douSelected.remove(card.id) }
                        else { douSelected.insert(card.id) }
                    } label: {
                        douCardFace(card, selected: selected)
                            .rotationEffect(.degrees((Double(index) / Double(max(1, cards.count - 1)) - 0.5) * 8),
                                            anchor: .bottom)
                            .offset(y: selected ? -17 : 0)
                    }
                    .buttonStyle(.plain)
                    .disabled(!selectable)
                    .zIndex(Double(index))
                    .accessibilityLabel("\(card.label)，\(selected ? "已选" : "未选")")
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 112, alignment: .bottom)
            }
            .scrollIndicators(.hidden)
            .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func douCardFace(_ card: MPCDouCard, selected: Bool) -> some View {
        let ink = card.isRed ? Color(red: 0.69, green: 0.10, blue: 0.16)
                             : Color(red: 0.08, green: 0.18, blue: 0.30)
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [Color.white, cream],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            if card.rank >= 16 {
                Image(card.rank == 17 ? "BountyJokerSun" : "BountyJokerMoon")
                    .resizable().scaledToFit()
                    .frame(width: 58, height: 82)
                    .offset(x: 4, y: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Image(systemName: card.rank == 17 ? "sun.max.fill" : "moon.stars.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("J\nO\nK\nE\nR")
                        .font(.system(size: 8, weight: .black, design: .serif))
                        .lineSpacing(-2)
                    Spacer(minLength: 0)
                    Text(card.copy == 0 ? "Ⅰ" : "Ⅱ")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(card.rank == 17 ? Color(red: 0.67, green: 0.08, blue: 0.10)
                                                    : Color(red: 0.07, green: 0.28, blue: 0.60))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(4)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(String(card.label.dropLast()))
                        .font(.system(size: 20, weight: .heavy, design: .serif))
                    Text(card.suit).font(.system(size: 16, weight: .bold))
                    Spacer(minLength: 0)
                    Text(card.suit).font(.system(size: 27))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(card.copy == 0 ? "Ⅰ" : "Ⅱ")
                        .font(.system(size: 8, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .foregroundStyle(ink)
                .padding(5)
            }
        }
        .frame(width: 62, height: 90)
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(selected ? gold : gold.opacity(0.68), lineWidth: selected ? 2.5 : 1))
        .shadow(color: .black.opacity(selected ? 0.55 : 0.30), radius: selected ? 7 : 3, y: 3)
    }

    private func douTrick(_ state: MPCDouGame) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: -11) {
                ForEach(state.lastPlay) { card in
                    if card.rank >= 16 {
                        Image(card.rank == 17 ? "BountyJokerSun" : "BountyJokerMoon")
                            .resizable().scaledToFit()
                            .frame(width: 38, height: 52)
                            .background(cream, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(gold.opacity(0.75), lineWidth: 1))
                    } else {
                        Text(card.label)
                            .font(.system(size: 12, weight: .bold, design: .serif))
                            .foregroundStyle(card.isRed ? Color(red: 0.69, green: 0.10, blue: 0.16)
                                                       : Color(red: 0.08, green: 0.18, blue: 0.30))
                            .frame(width: 38, height: 52, alignment: .topLeading)
                            .padding(.top, 6).padding(.leading, 5)
                            .background(cream, in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(gold.opacity(0.75), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 5)
        }
        .scrollIndicators(.hidden)
        .frame(height: 60)
        .accessibilityLabel("桌上待压的\(state.lastPlay.count)张牌")
    }

    private var helpSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("牌桌玩法")
                        .font(.system(size: 26, weight: .bold, design: .serif)).foregroundStyle(gold)
                    Spacer()
                    Button("完成") { showsHelp = false }
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(gold)
                }
                helpSection("五张换牌 · 轻松", text: "一副52张牌，各拿5张；你可换0–3张，按整手牌型比较：同花顺＞四条＞葫芦＞同花＞顺子＞三条＞两对＞一对＞高牌。同型再比点数。平局退注，败局失注。通缉线索局若前四局未赢，第五局保底取口供；酒馆常驻局没有保底。")
                helpSection("雾港斗地主 · 牌技", text: "这是三人两副牌的雾港变体，共108张，各34张、留6张底牌。轮流叫0–3分，最高者为地主，拿底牌并先出；其余两人合作。单张、对子、三张、三带一／二、顺子、连对、飞机及带翼、四带二均可出。同型同张数才能压；4–8张同点炸弹压普通牌，较长炸弹更大；四张王是最大的天王炸。连过两家，牌权回到上一位出牌者。地主先出完则地主胜，任一农民先出完则农民方胜。每局真随机洗牌，没有保底。")
                helpSection("赌注与退路", text: "两种模式先押10／20／40铜。五张换牌胜出净赚等额；普通斗地主胜出按叫分、炸弹与春天获得1–8倍净收益，输了最多损失本局押注。离桌会保存已发牌局。通缉局赢牌可取得约定口供，也能不赌而查公开档案。")
                if isTavernFreeplay {
                    helpSection("莫尔的特别彩头", text: "完成借脸人通缉并交案后，莫尔常驻酒馆。约每三天有一件你已达到解锁进度且尚未拥有的遗落物或晋级主材；当天只开放一次40铜斗地主彩头局。赢了退押并得物品，不叠加铜币倍数；输了失去40铜，次日也未必有新彩头。普通铜币局每天照常玩。")
                }
            }
            .padding(22)
        }
        .background(Color(red: 0.025, green: 0.055, blue: 0.10).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func helpSection(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 17, weight: .bold, design: .serif)).foregroundStyle(gold)
            Text(text).font(.system(size: 13)).foregroundStyle(cream)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
    }

    private func douName(_ player: Int) -> String {
        player == 0 ? "你" : player == 1 ? opponentName : caseID == "b03" ? "船务信使" : "下班跑堂"
    }
    private func startDou() {
        do { douGame = try game.startChurchBountyDou(caseID, wager: featuredPrize ? 40 : wager, featuredPrize: featuredPrize); errorText = nil }
        catch { errorText = "无法发牌：请确认仍在牌桌且铜币足够。" }
    }
    private func bidDou(_ state: MPCDouGame, points: Int) {
        do { updateDou(try game.bidChurchBountyDou(caseID, gameID: state.gameID, points: points)) }
        catch { errorText = "叫分未完成，请重试。" }
    }
    private func playDou(_ state: MPCDouGame) {
        do { updateDou(try game.playChurchBountyDou(caseID, gameID: state.gameID, cardIDs: douSelected)) }
        catch { errorText = "牌型不合法或压不过当前牌；请重选。" }
    }
    private func passDou(_ state: MPCDouGame) {
        do { updateDou(try game.passChurchBountyDou(caseID, gameID: state.gameID)) }
        catch { errorText = "当前需要先出牌。" }
    }
    private func hintDou(_ state: MPCDouGame) {
        let target = MPCDouRules.classify(state.lastPlay)
        let options = MPCDouRules.legalMoves(state.hands[0], beating: target)
        if let best = options.first(where: { MPCDouRules.classify($0)?.isBomb == false }) ?? options.first {
            douSelected = Set(best.map(\.id))
            errorText = "已标出一手合法牌；也可以自己重新选牌。"
        } else { errorText = "没有可压的牌，这轮可以选择不出。" }
    }
    private func updateDou(_ state: MPCDouGame) {
        douGame = state
        douSelected.removeAll()
        errorText = nil
        if let result = state.settlement {
            let prize = game.churchServices.tavernFeaturedGames[state.gameID]
            let actualNet = prize == nil ? result.netCopper
                : result.playerWon ? (game.churchServices.tavernPrizePaidGames.contains(state.gameID) ? 0 : 40)
                                   : -result.wager
            onFinish(.init(modeName: "雾港斗地主", outcome: result.playerWon ? .win : .loss,
                           wager: result.wager, netCopper: actualNet))
        }
    }

    private func douOutcomeTitle(_ settlement: MPCDouSettlement) -> String {
        if let prize = activePrize {
            return settlement.playerWon ? "你方获胜 · 赢得\(prize.name)" : "你方落败 · 今日彩头结束"
        }
        if isTavernFreeplay { return settlement.playerWon ? "你方获胜 · 铜币到账" : "你方落败 · 可再押一局" }
        return settlement.playerWon ? "你方获胜 · 取得口供" : "你方落败 · 可再试或查档案"
    }

    private func douOutcomeDetail(_ settlement: MPCDouSettlement) -> String {
        if activePrize != nil {
            if !settlement.playerWon { return "失去本局押注 \(settlement.wager) 铜；彩头不会再重开。" }
            return game.churchServices.tavernPrizePaidGames.contains(settlement.gameID)
                ? "押注 \(settlement.wager) 铜已返还；奖品已存入背包。"
                : "押注已返还；奖品中途已持有，折价补偿40铜。"
        }
        return settlement.playerWon ? "叫分与炸弹结算 ×\(settlement.multiplier)，净赚 \(settlement.netCopper) 铜。"
            : "失去本局押注 \(settlement.wager) 铜。"
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .bold, design: .serif))
            Spacer()
            Text(detail).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.67))
        }
    }

    private func cardBack(width: CGFloat) -> some View {
        Image("BountyPokerCardBack")
            .resizable().scaledToFill()
            .frame(width: width, height: width * 1.5)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(gold.opacity(0.85), lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 5, y: 3)
            .accessibilityLabel("雾港星盘牌背")
    }

    private func cardFace(_ card: MPCPokerCard, width: CGFloat, selected: Bool) -> some View {
        let ink = card.isRed ? Color(red: 0.64, green: 0.11, blue: 0.16)
                             : Color(red: 0.11, green: 0.18, blue: 0.31)
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: [.white, Color(red: 0.94, green: 0.91, blue: 0.83)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 0) {
                Text(card.rankLabel).font(.system(size: width * 0.27, weight: .heavy, design: .serif))
                Text(card.suit).font(.system(size: width * 0.21))
                Spacer(minLength: 0)
                Text(card.suit).font(.system(size: width * 0.48)).frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
            .foregroundStyle(ink)
            .padding(width * 0.10)
            if selected {
                VStack {
                    Spacer()
                    Text("换掉").font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.72, green: 0.24, blue: 0.18))
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(width: width, height: width * 1.5)
        .overlay(RoundedRectangle(cornerRadius: 8)
            .stroke(selected ? Color(red: 1, green: 0.70, blue: 0.38) : gold,
                    lineWidth: selected ? 2.5 : 1.3))
        .shadow(color: .black.opacity(0.27), radius: 4, y: 2)
    }

    private func toggleDiscard(_ index: Int) {
        guard result == nil else { return }
        if discarded.contains(index) { discarded.remove(index) }
        else if discarded.count < 3 { discarded.insert(index) }
    }

    private func startRound() {
        do {
            round = try game.startChurchBountyPoker(caseID, wager: wager)
            discarded.removeAll()
            errorText = nil
        } catch {
            errorText = "无法发牌：请确认仍在牌桌且铜币足够。"
        }
    }

    private func showDown(_ round: MPCPokerRound) {
        do {
            let finished = try game.finishChurchBountyPoker(caseID, roundID: round.roundID,
                                                              discarding: discarded)
            result = finished
            onFinish(.init(modeName: "五张换牌", outcome: finished.outcome,
                           wager: finished.wager, netCopper: finished.netCopper))
            errorText = nil
        } catch {
            errorText = "结算未完成，赌注和手牌仍保留；请再试一次。"
        }
    }

    private func outcomeText(_ result: MPCPokerShowdown) -> String {
        switch result.outcome {
        case .win: return "你赢了 · \(result.playerRank.label) 胜 \(result.dealerRank.label) · \(isTavernFreeplay ? "净赚 \(result.wager) 铜" : result.wager == 0 ? "取得口供" : "净赚 \(result.wager) 铜与口供")"
        case .tie: return "平局 · 双方 \(result.playerRank.label) · 已退还 \(result.wager) 铜"
        case .loss: return "你输了 · \(result.playerRank.label) 对 \(result.dealerRank.label) · 损失 \(result.wager) 铜"
        }
    }
}
