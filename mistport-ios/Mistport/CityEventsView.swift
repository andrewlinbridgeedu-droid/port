import SwiftUI
import MistportCombatCore

struct CityEventsView: View {
    @Bindable var game: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var battle: EventBattleTicket?
    @State private var errorText = ""
    private struct EventBattleTicket: Identifiable { let id: String; let eventID: String }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("第 \(game.pacingDay) 天 · 城市事件板").font(.title2.bold())
                    Text(MPCCityEventCatalog.fixtureNotice).font(.footnote).foregroundStyle(.secondary)
                    if let ticket = game.cityEvents.activeTicket {
                        Text("有一场未结束的行动。若上次已离开战斗，可撤销票据后重新出发。")
                        Button("撤销未结束的行动") { perform { try game.abandonCityEvent(ticket: ticket) } }
                    }
                    if let event = MPCCityEventCatalog.running(day: game.pacingDay) {
                        eventCard(event)
                    } else {
                        Text(game.pacingDay < 4 ? "第 4 天开放第一场城市事件。" : "本章四场事件已结束，可查看结果。")
                    }
                    GroupBox("城市变化") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("工坊每日订单预算：\(game.dailyCityEffects.orderBudgetBonus >= 0 ? "+" : "")\(game.dailyCityEffects.orderBudgetBonus) 铜")
                            Text("制作底料：\(game.dailyCityEffects.craftSurcharge >= 0 ? "+" : "")\(game.dailyCityEffects.craftSurcharge) 铜／次")
                            Text("商店止痛膏：\(game.painSalvePrice) 铜／份")
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(MPCCityEventCatalog.all) { event in
                        if !event.isRunning(day: game.pacingDay) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(event.title) · 第 \(event.firstDay)–\(event.lastDay) 天").font(.headline)
                                Text(statusText(event))
                            }
                        }
                    }
                    if !errorText.isEmpty { Text(errorText).foregroundStyle(.orange).accessibilityAddTraits(.updatesFrequently) }
                }.padding()
            }
            .navigationTitle("城市事件")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("返回") { dismiss() } } }
            .fullScreenCover(item: $battle) { ticket in
                CityEventBattleView(game: game, eventID: ticket.eventID, battleID: ticket.id, onClose: { battle = nil })
            }
        }
    }
    private func eventCard(_ event: MPCCityEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.title).font(.title.bold())
            Text("第 \(event.firstDay)–\(event.lastDay) 天 · \(event.partner)").font(.subheadline)
            Text(event.briefing)
            if game.cityEvents.status(event.id, day: game.pacingDay) == .succeeded {
                Text(event.success).foregroundStyle(.green)
            } else {
                ForEach(event.deliveries, id: \.itemID) { delivery in
                    let left = game.cityEvents.remaining(event, itemID: delivery.itemID)
                    let stock = game.chapterOneCampaign.inventory[delivery.itemID, default: 0]
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(GameStore.workshopItemName(delivery.itemID))：还需 \(left)/\(delivery.quantity) 件 · 背包 \(stock) 件")
                        StaminaCostView(activity: .eventDelivery)
                        Button("交付 1 件 · 收 \(delivery.price) 铜") {
                            Task { do { try await game.deliverCityEvent(event.id, itemID: delivery.itemID); errorText = "" } catch { errorText = game.housingError(error) } }
                        }.disabled(left == 0 || stock == 0)
                        if stock == 0 && left > 0 { Text("背包缺货，可去工坊制作。").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                let today = game.cityEvents.winsCounted(event.id, day: game.pacingDay)
                let left = game.cityEvents.winsLeft(event)
                Text("战斗还需 \(left) 场 · 今天已记 \(today)/2 场")
                StaminaCostView(activity: .eventBattle)
                Button("\(event.battleTitle) · 胜利 10 铜") {
                    battle = .init(id: UUID().uuidString, eventID: event.id)
                }.buttonStyle(.borderedProminent)
                    .disabled(today >= 2 || left == 0 || game.cityEvents.activeTicket != nil)
                if today >= 2 { Text("事件战今天已记 2 场，明天再来。") }
                if left == 0 { Text("所需胜场已完成；交齐货物即可完成事件。") }
                Text("完成：\(event.success)").font(.footnote)
                Text("逾期：\(event.failure)").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
    private func statusText(_ event: MPCCityEvent) -> String {
        switch game.cityEvents.status(event.id, day: game.pacingDay) {
        case .upcoming: return "尚未开始"
        case .running: return "进行中"
        case .succeeded: return event.success
        case .failed: return event.failure + (game.pacingDay > event.lastDay + MPCCityEventCatalog.failureDays ? "（本章临时价格影响已结束）" : "")
        }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); errorText = "" } catch { errorText = "操作未完成：请核对库存、事件进度或未结束的行动。" }
    }
}

struct CityEventBattleView: View {
    @Bindable var game: GameStore
    let eventID: String
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
                        do {
                            try game.settleCityEvent(ticket: battleID, session: result)
                            won = true; finished = true
                        } catch { startError = "结算未完成，请保留本场并重试。" }
                    }, onExit: {
                        if started && !finished { try? game.abandonCityEvent(ticket: battleID, defeated: false) }
                        onClose()
                    },
                    onDefeat: {
                        guard !finished else { return }
                        try? game.abandonCityEvent(ticket: battleID, defeated: true)
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
                        Task { do {
                            configuredSession = try await game.beginCityEvent(eventID: eventID, ticket: battleID, skills: skills)
                            started = true
                        } catch { startError = game.housingError(error) } }
                    })
                VStack { HStack { Button("返回事件板") { onClose() }; Spacer() }; Spacer() }.padding()
            }
            if !startError.isEmpty { Text(startError).foregroundStyle(.orange).padding().background(.black) }
            if finished {
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack(spacing: 16) {
                    Text(won ? "阻碍已解除" : "行动未完成").font(.title.bold()).foregroundStyle(won ? .yellow : .orange)
                    Text(won ? "记 1 场事件胜利，已付 10 铜。" : "这一场不记贡献，可以重新准备。")
                    ChurchActionButton(title: "返回事件板") { onClose() }
                }
                .foregroundStyle(.white).padding(24)
            }
        }
        .preferredColorScheme(.dark).buttonStyle(.plain)
        .task { if previewSession == nil { previewSession = try? game.cityEventPreview(eventID: eventID, ticket: battleID) } }
    }
}
