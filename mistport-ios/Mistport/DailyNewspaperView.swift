import SwiftUI
import MistportCombatCore

enum DailyNewspaperDestination { case story, tower, bounties, workshop, events, tavern, neighbors, remnants, work }

/// Live game text on the newspaper's reusable paper stock.
struct MistportNewsprintPage<Content: View>: View {
    let title: String
    let day: Int
    @ViewBuilder let content: () -> Content
    @Environment(\.dismiss) private var dismiss
    private let ink = Color(red: 0.19, green: 0.14, blue: 0.09)
    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.075, blue: 0.04).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("雾港日刊 · 附刊").font(.system(size: 17, weight: .bold, design: .serif))
                    Spacer()
                    GameArtReturnButton(title: "收起附刊") { dismiss() }
                }.foregroundStyle(Color(red: 0.93, green: 0.86, blue: 0.70)).padding(18)
                GameArtPaperScroll(newsprint: true) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Text("街区小报  ·  每日发行"); Spacer(); Text("第 \(day) 期") }
                            .font(.system(size: 11, design: .serif))
                        Rectangle().fill(ink).frame(height: 1)
                        Text(title).font(.system(size: 34, weight: .black, design: .serif)).frame(maxWidth: .infinity)
                        HStack { Text("第 \(day) 天"); Spacer(); Text("本地消息 · 街区告示") }
                            .font(.system(size: 11, design: .serif))
                        Rectangle().fill(ink).frame(height: 2)
                        content().buttonStyle(GameArtButtonStyle())
                        Rectangle().fill(ink.opacity(0.5)).frame(height: 0.7)
                        Text("雾港报馆印行").font(.system(size: 11, design: .serif)).frame(maxWidth: .infinity)
                    }.font(.system(size: 16, design: .serif)).foregroundStyle(ink).tint(ink)
                        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.bottom, 24)
                }
            }
        }.preferredColorScheme(.light)
    }
}

struct DailyNewspaperView: View {
    @Bindable var game: GameStore
    let onSelect: (DailyNewspaperDestination) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var talkingToPrinter = false
    /// The arrivals just acknowledged, shown as a receipt line (2026-10-22).
    @State private var received: Int?
    private let ink = Color(red: 0.19, green: 0.14, blue: 0.09)
    private let paper = Color(red: 0.93, green: 0.86, blue: 0.70)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("雾港报馆").font(.system(size: 20, weight: .bold, design: .serif))
                Spacer()
                GameArtReturnButton { dismiss() }
            }
            .foregroundStyle(paper).padding(18)
            .background(Color(red: 0.12, green: 0.075, blue: 0.04))
            GameArtPaperScroll(newsprint: true) {
                VStack(spacing: 0) {
                    // A banner, not the whole room (2026-10-15: one page).
                    HomeSceneBanner(room: .newspaper, actorArt: talkingToPrinter ? "HomePrinter20260929" : "HomeEditor20260929", height: 170)
                        .overlay(alignment: .bottomLeading) {
                            Text(talkingToPrinter ? "排字工 · 新刊已经印好了。" : "报馆编辑  ·  今日新刊已经印好，请看。")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundStyle(.white).padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.black.opacity(0.58))
                        }
                    HStack {
                        Button("报馆编辑") { talkingToPrinter = false }
                        Spacer()
                        Button("排字工") { talkingToPrinter = true }
                    }.font(.subheadline.bold()).foregroundStyle(ink).padding(12)
                    newspaper
                        .padding(.horizontal, 15).padding(.top, 8).padding(.bottom, 30)
                        .padding(.horizontal, 10)
                }
            }
        }
        .background(Color(red: 0.12, green: 0.075, blue: 0.04).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { game.markDailyNewspaperSeen(); game.ensureDailyGoalPlan() }
        #if DEBUG
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--home-map-review"),
                  UserDefaults.standard.string(forKey: "MistportNewspaperStaff") == "printer" else { return }
            talkingToPrinter = true
        }
        #endif
    }

    private var newspaper: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("港城晨报  ·  每日发行")
                Spacer()
                Text("第 \(game.pacingDay) 期")
            }.font(.system(size: 10, weight: .medium, design: .serif))
            paperRule(thickness: 1)
            Text("雾 港 日 刊")
                .font(.system(size: 38, weight: .black, design: .serif))
                .minimumScaleFactor(0.7).lineLimit(1)
                .frame(maxWidth: .infinity)
            HStack {
                Text("第 \(game.pacingDay) 天")
                Spacer()
                Text("街头消息 · 教会公告 · 港城生活")
            }.font(.system(size: 10, design: .serif))
            paperRule(thickness: 2)
            Text(game.housingDailyNotice).font(.system(size: 12, design: .serif))
            Text(game.todayPacingSummary).font(.system(size: 14, weight: .semibold, design: .serif))
            morningLedger
            cityTrendFront
            paperRule(thickness: 1)
            row("主线进展", destination: .story) {
                if let next = game.nextChapterMission {
                    Text("\(next.title) · \(game.missionLockText(next) ?? "今天可以推进")")
                    if game.missionLockText(next) != nil { Text("前往可重访已开放关卡；新关等待日限开放。") }
                } else { Text("本章主线已完成，可回访旧关。") }
            }
            row("深井封堵", destination: .tower, locked: game.cityServiceIsUnlocked(.church) ? nil : MPCChurchTowerCatalog.lockText) {
                if !game.cityServiceIsUnlocked(.church) {
                    Text(MPCDailyPacing.openingNote(afterMission: MPCChurchTowerCatalog.unlockMission, day: game.pacingDay))
                } else {
                Text("累计封堵 \(game.churchTowerProgress.clearedFloors.count)/100 层；今天还能新封 \(max(0, MPCDailyPacing.towerFirstClearsAllowed(day: game.pacingDay) - game.churchTowerProgress.clearedFloors.count)) 层。")
                Text(game.towerPacingLockText ?? "已封堵的层可随时重打。")
                }
            }
            row("通缉日刊", destination: .bounties, locked: game.cityServiceIsUnlocked(.church) ? nil : MPCChurchTowerCatalog.lockText) {
                if !game.cityServiceIsUnlocked(.church) {
                    Text(MPCDailyPacing.openingNote(afterMission: MPCChurchTowerCatalog.unlockMission, day: game.pacingDay))
                } else {
                let offers = game.previewChurchBountyIssue().offerIDs.compactMap(MPCChurchBountyCatalog.bounty(id:))
                    .filter { game.churchServices.bounties.cases[$0.id]?.claimed != true }
                // Cases past the player's story progress are listed but cannot be taken; say so.
                let done = game.churchTowerMissionNumbers
                Text(offers.isEmpty ? "当前没有新的通缉，已接案卷可继续。" : offers.map {
                    done.contains($0.unlockMission) ? $0.title : "\($0.title)（第 \($0.unlockMission) 关后）"
                }.joined(separator: " · "))
                }
            }
            row("工坊订单", destination: .workshop, locked: game.cityServiceIsUnlocked(.workshop) ? nil : "完成第 5 关后开放工坊") {
                if !game.cityServiceIsUnlocked(.workshop) {
                    Text(MPCDailyPacing.openingNote(afterMission: 5, day: game.pacingDay))
                } else {
                    Text("可用预算 \(game.workshopOrders.budget) 铜，最多累积 3 天。")
                    Text(game.workshopProficiencyNotice)
                }
            }
            row("城市事件", destination: .events) {
                if let event = MPCCityEventCatalog.running(day: game.pacingDay) {
                    Text("\(event.title) · 第 \(event.firstDay)–\(event.lastDay) 天 · \(game.cityEvents.status(event.id, day: game.pacingDay) == .succeeded ? "已完成" : "进行中")")
                    Text("还需 \(game.cityEvents.winsLeft(event)) 场胜利；今天已记 \(game.cityEvents.winsCounted(event.id, day: game.pacingDay))/2 场。")
                } else { Text(game.pacingDay < 4 ? "第一场事件在第 4 天开始。" : "本章事件已结束，可查看城市变化。") }
            }
            row("酒馆彩头", destination: .tavern, locked: game.tavernPokerUnlocked ? nil : "借脸人一案结案领奖后开放牌桌") {
                if !game.tavernPokerUnlocked { Text("先完成酒馆相关通缉案，日后可在这里查看彩头。") }
                else if let prize = game.newspaperTavernPrize { Text("今日彩头：\(prize.name)；到牌桌确认本局规则。") }
                else { Text("今天暂无可领取的额外彩头，仍可按牌桌规则游玩。") }
            }
            row("街坊委托", destination: .neighbors) {
                let offers = game.newspaperNeighborOffers.filter { !$0.done }
                if offers.isEmpty { Text("今天的委托已经完成。") }
                ForEach(offers) { offer in
                    Text("\(MPCNeighborCatalog.neighbor(offer.neighborID)?.name ?? "街坊")：\(offer.errand?.request ?? "")")
                }
                ForEach(game.streetTasks.offers.filter { !$0.done }) { offer in
                    if let task = offer.task { Text("\(StreetTaskText.kind(task.kind)) · \(task.title)：\(task.request)") }
                }
                Text(game.cityContributionText).font(.system(size: 12, design: .serif))
                Text("进入街道，走到人物面前交谈；委托板也能直接接。")
            }
            row("无名残余案", destination: .remnants) {
                Text(game.todayRemnant?.title ?? "任意通缉结案领奖后，每天开放一个小案。")
            }
            row("今日工作", destination: .work) { Text(game.repeatWorkNotice) }
            HStack { Spacer(); Text("雾港报馆印行 · 今日消息到此"); Spacer() }
                .font(.system(size: 10, design: .serif))
        }.foregroundStyle(ink)
    }
    /// The city's trend (2026-10-17): the three sides' shares, the week's rise and fall, what the
    /// player did, the stages settled, the day's shock and where it is heading. Only facts.
    private var cityTrendFront: some View {
        let trend = game.cityTrend
        let mine = game.cityTrendLedger.receipts.filter { $0.counted > 0 && $0.day >= game.pacingDay - 1 }
        return VStack(alignment: .leading, spacing: 7) {
            Text("城势 · 雾港靠什么担保一个人").font(.system(size: 20, weight: .bold, design: .serif))
            ForEach(MPCCityFaction.allCases, id: \.self) { side in
                HStack(spacing: 8) {
                    Text("\(side.name) · \(side.motto)").font(.system(size: 12, weight: .semibold, design: .serif))
                        .frame(width: 92, alignment: .leading)
                    GeometryReader { box in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(ink.opacity(0.12))
                            Rectangle().fill(ink.opacity(0.72)).frame(width: box.size.width * trend.share(side))
                        }
                    }.frame(height: 7)
                    Text("\(Int((trend.share(side) * 100).rounded()))%" + weekArrow(trend, side))
                        .font(.system(size: 12, design: .serif).monospacedDigit()).frame(width: 52, alignment: .trailing)
                }
            }
            ForEach(mine, id: \.id) { receipt in
                Text("本报讯：你\(receipt.fact)。（\(receipt.side.name)\(receipt.key ? " · 关键一票" : "")）")
                    .font(.system(size: 12, design: .serif))
            }
            if let shock = trend.shocks.last, shock.day >= game.pacingDay - 1 {
                Text("突发：\(shock.news)。\(shock.side.name)受挫。").font(.system(size: 12, weight: .semibold, design: .serif))
            }
            if let plot = trend.plot {
                let side = plot.target
                if let killed = plot.killedDay {
                    Text("第 \(killed) 天，\(side.leaderTitle)\(side.leaderName)遇刺身亡。" + (plot.aftermath == .collapse
                        ? "\(side.name)树倒猢狲散。" : "全城为他举哀，\(side.name)反倒更齐心了。"))
                        .font(.system(size: 13, weight: .bold, design: .serif))
                } else if MPCCityTrendWorld.plotDays.contains(game.pacingDay) {
                    Text("\(side.leaderTitle)\(side.leaderName)在\(side.leaderPlace)公开露面。风声：刺客得手 \(plot.struck) 次，护卫挡下 \(plot.held) 次。")
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                } else {
                    Text("\(side.leaderLabel)躲过了这一轮风声。").font(.system(size: 12, design: .serif))
                }
            }
            if let ending = trend.ending {
                Text("本章定局：\(ending.summary)。").font(.system(size: 13, weight: .bold, design: .serif))
            }
            ForEach(trend.results, id: \.stage) { result in
                Text("\(result.stage.title)已定：\(result.winner.name)拿下——\(result.stage.outcome(result.winner))。")
                    .font(.system(size: 12, design: .serif))
            }
            if let forecast = trend.forecast { Text(forecast).font(.system(size: 13, weight: .semibold, design: .serif)) }
            Text(trend.smokeReport).font(.system(size: 12, design: .serif))
            if let notice = MPCCityTrendSnapshot.lampHouseNotice(day: game.pacingDay) {
                Text("本报讯：" + notice).font(.system(size: 12, design: .serif))
            }
            let yours = MPCCityFaction.allCases.compactMap { side in trend.yours[side.rawValue].map { "\(side.name) \($0)" } }
            Text(yours.isEmpty ? "你这周还没有替哪一边办过事。办委托时选的办法，会算进全城的城势。"
                 : "你这周替：" + yours.joined(separator: " · ") + "。")
                .font(.system(size: 11, design: .serif))

        }
    }
    /// 昨夜到账 and 今日小目标 (2026-10-22, user: 先做 1、2 和 3). Money that settled on its own since the last
    /// paper, read in one place; up to three goals for today with a small reward when all are done.
    @ViewBuilder private var morningLedger: some View {
        let arrivals = game.morningArrivals
        let total = arrivals.map(\.coins).reduce(0, +)
        let gold = Color(red: 0.55, green: 0.36, blue: 0.05)
        if let received {
            Text("已收下 \(received) 铜，都在钱包里。").font(.system(size: 14, weight: .bold, design: .serif)).foregroundStyle(gold)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        } else if !arrivals.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("昨夜到账").font(.system(size: 20, weight: .bold, design: .serif))
                ForEach(Array(arrivals.enumerated()), id: \.offset) { _, arrival in
                    HStack(alignment: .firstTextBaseline) {
                        Text(arrival.text).font(.system(size: 13, design: .serif))
                        Spacer(minLength: 6)
                        Text("+\(arrival.coins) 铜").font(.system(size: 14, weight: .bold, design: .serif).monospacedDigit()).foregroundStyle(gold)
                    }
                }
                Text("这些钱到期时已经自动进了钱包，这里一次列给你看。").font(.system(size: 11, design: .serif))
                Button {
                    GameInterfaceSound.shared.playClick()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { received = total }
                    game.acknowledgeArrivals()
                } label: {
                    Text("收下 · 共 +\(total) 铜").font(.system(size: 14, weight: .bold, design: .serif))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .overlay(Rectangle().stroke(ink.opacity(0.75), lineWidth: 0.8))
                }.buttonStyle(.plain)
            }
        }
        if let plan = game.dailyGoalPlan, !plan.goals.isEmpty {
            let now = game.dailyProgress
            let reward = "铜币 +\(MPCDailyGoalPlan.rewardCopper)、技能粉尘 +\(MPCDailyGoalPlan.rewardDust)"
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("今日小目标").font(.system(size: 20, weight: .bold, design: .serif))
                    Spacer()
                    Text("\(plan.doneCount(now: now))/\(plan.goals.count)").font(.system(size: 14, weight: .bold, design: .serif).monospacedDigit())
                }
                ForEach(plan.goals) { goal in
                    let done = goal.isDone(from: plan.baseline, to: now)
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Image(systemName: done ? "checkmark.square.fill" : "square").font(.system(size: 13))
                        Text(goal.title).font(.system(size: 14, design: .serif)).strikethrough(done, color: ink.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        if goal.count > 1 {
                            Text("\(goal.progress(from: plan.baseline, to: now))/\(goal.count)").font(.system(size: 12, design: .serif).monospacedDigit())
                        }
                    }.opacity(done ? 0.6 : 1)
                }
                if plan.claimed {
                    Text("今天的奖励已领：\(reward)。明天的小目标明早随报纸送到。").font(.system(size: 12, design: .serif))
                } else if plan.canClaim(now: now) {
                    Button {
                        GameInterfaceSound.shared.playClick()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { game.claimDailyGoals() }
                    } label: {
                        Text("领取 · \(reward)").font(.system(size: 14, weight: .bold, design: .serif)).foregroundStyle(gold)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .overlay(Rectangle().stroke(gold, lineWidth: 1))
                    }.buttonStyle(.plain)
                } else {
                    Text("都办完可领：\(reward)。做不完也没关系，明天换新的。").font(.system(size: 12, design: .serif))
                }
            }
        }
    }
    /// ▲/▼ for the week's change in a side's share, once there is a week to compare with.
    private func weekArrow(_ trend: MPCCityTrendSnapshot, _ side: MPCCityFaction) -> String {
        guard !trend.lastWeek.isEmpty else { return "" }
        let change = trend.share(side, of: trend.week) - trend.share(side, of: trend.lastWeek)
        return change > 0.02 ? " ▲" : change < -0.02 ? " ▼" : " –"
    }
    private func paperRule(thickness: CGFloat) -> some View {
        Rectangle().fill(ink.opacity(0.7)).frame(height: thickness)
    }
    private func row<Detail: View>(_ title: String, destination: DailyNewspaperDestination, locked: String? = nil,
                                   @ViewBuilder detail: () -> Detail) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.system(size: 20, weight: .bold, design: .serif))
                Spacer()
                Button { onSelect(destination) } label: {
                    HStack(spacing: 4) { Text("前往"); Image(systemName: "arrow.up.right") }
                        .font(.system(size: 12, weight: .semibold, design: .serif))
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .overlay(Rectangle().stroke(ink.opacity(locked == nil ? 0.7 : 0.3), lineWidth: 0.7))
                }.buttonStyle(.plain).disabled(locked != nil).opacity(locked == nil ? 1 : 0.45).accessibilityLabel("前往\(title)")
            }
            detail().font(.system(size: 14, design: .serif)).foregroundStyle(ink.opacity(0.85)).lineSpacing(3)
            if let locked { Text(locked).font(.system(size: 12, design: .serif)).foregroundStyle(Color(red: 0.48, green: 0.17, blue: 0.10)) }
            paperRule(thickness: 0.6).padding(.top, 5)
        }
    }
}
