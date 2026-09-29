import SwiftUI
import MistportCombatCore

enum DailyNewspaperDestination { case story, tower, bounties, workshop, events, tavern, neighbors, remnants, work }

struct DailyNewspaperView: View {
    @Bindable var game: GameStore
    let onSelect: (DailyNewspaperDestination) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("雾港日刊 · 第 \(game.pacingDay) 天").font(.title.bold())
                    Text(game.todayPacingSummary).font(.subheadline)
                    row("主线进展", destination: .story) {
                        if let next = game.nextChapterMission {
                            Text("\(next.title) · \(game.missionLockText(next) ?? "今天可以推进")")
                        } else { Text("本章主线已完成，可回访旧关。") }
                    }
                    row("深井封堵", destination: .tower) {
                        Text("累计封堵 \(game.churchTowerProgress.clearedFloors.count)/100 层；今天还能新封 \(max(0, MPCDailyPacing.towerFirstClearsAllowed(day: game.pacingDay) - game.churchTowerProgress.clearedFloors.count)) 层。")
                        Text(game.towerPacingLockText ?? "已封堵的层可随时重打。")
                    }
                    row("通缉日刊", destination: .bounties) {
                        let offers = game.previewChurchBountyIssue().offerIDs.compactMap(MPCChurchBountyCatalog.bounty(id:))
                        Text(offers.isEmpty ? "当前没有新的通缉，已接案卷可继续。" : offers.map(\.title).joined(separator: " · "))
                    }
                    row("工坊订单", destination: .workshop, locked: game.cityServiceIsUnlocked(.workshop) ? nil : "完成 Q5 后开放工坊") {
                        Text("可用预算 \(game.workshopOrders.budget) 铜，最多累积 3 天。")
                        Text(game.workshopProficiencyNotice)
                    }
                    row("城市事件", destination: .events) {
                        if let event = MPCCityEventCatalog.running(day: game.pacingDay) {
                            Text("\(event.title) · 第 \(event.firstDay)–\(event.lastDay) 天")
                            Text("还需 \(game.cityEvents.winsLeft(event)) 场胜利；今天已记 \(game.cityEvents.winsCounted(event.id, day: game.pacingDay))/2 场。")
                        } else { Text(game.pacingDay < 4 ? "第一场事件在第 4 天开始。" : "本章事件已结束，可查看城市变化。") }
                    }
                    row("酒馆彩头", destination: .tavern, locked: game.tavernPokerUnlocked ? nil : "酒馆牌桌尚未开放") {
                        if let prize = game.newspaperTavernPrize { Text("今日彩头：\(prize.name)；到牌桌确认本局规则。") }
                        else { Text("今天暂无可领取的额外彩头，仍可按牌桌规则游玩。") }
                    }
                    row("街坊委托", destination: .neighbors) {
                        let offers = game.newspaperNeighborOffers.filter { !$0.done }
                        if offers.isEmpty { Text(game.pacingDay < 2 ? "第 2 天起，街坊会有小事相托。" : "今天的委托已经完成。") }
                        ForEach(offers) { offer in
                            Text("\(MPCNeighborCatalog.neighbor(offer.neighborID)?.name ?? "街坊")：\(offer.errand?.request ?? "")")
                        }
                        Text("进入街道，走到人物面前交谈；传话要去收话人处。")
                    }
                    row("无名残余案", destination: .remnants) {
                        Text(game.todayRemnant?.title ?? "任意通缉结案领奖后，每天开放一个小案。")
                    }
                    row("今日工作", destination: .work) { Text(game.repeatWorkNotice) }
                }.padding()
            }
            .navigationTitle("每日告示")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("收起") { dismiss() } } }
            .onAppear { game.markDailyNewspaperSeen() }
        }
    }
    private func row<Detail: View>(_ title: String, destination: DailyNewspaperDestination, locked: String? = nil,
                                   @ViewBuilder detail: () -> Detail) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("前往") { onSelect(destination) }.disabled(locked != nil).accessibilityLabel("前往\(title)")
            }
            detail().font(.subheadline).foregroundStyle(.secondary)
            if let locked { Text(locked).font(.footnote).foregroundStyle(.orange) }
            Divider()
        }
    }
}
