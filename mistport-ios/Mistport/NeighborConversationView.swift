import SwiftUI
import MistportCombatCore

struct NeighborConversationView: View {
    @Bindable var game: GameStore
    let neighborID: String
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var battle: PestTicket?
    private struct PestTicket: Identifiable { let id: String; let offerID: String }

    var body: some View {
        GameArtPage(title: MPCNeighborCatalog.neighbor(neighborID)?.name ?? "街坊", subtitle: "街坊来往 · 今日委托", art: neighborID == "postman" ? "HomePostOfficeEmpty20260929" : "HomeCommissionOfficeEmpty20260929", closeTitle: "告辞") {
            Text("第 \(game.pacingDay) 天 · 好感 \(game.neighbors.affinity[neighborID, default: 0])").font(.subheadline)
            Text("今天的请求明天会作废；已开打的赶塔怪行动可完成结算。").font(.footnote).foregroundStyle(.secondary)
            ForEach(game.neighbors.offers.filter { $0.neighborID == neighborID }) { offer in
                if let errand = offer.errand { offerCard(offer, errand) }
            }
            ForEach(game.neighbors.offers.filter { $0.errand?.recipientID == neighborID && !$0.done && game.canRelayNeighbor($0.id) }) { offer in
                GroupBox("有人托你传话") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(offer.errand?.request ?? "")
                        Button("把话带到 · \(offer.errand?.copper ?? 0) 铜") {
                            perform { try await game.relayNeighbor(offer.id) }
                            if game.neighbors.offers.first(where: { $0.id == offer.id })?.done == true { message = (offer.errand?.reply ?? "") + "\n" + message }
                        }
                    }
                }
            }
            if !message.isEmpty { Text(message).foregroundStyle(.orange) }
            if game.neighbors.offers.allSatisfy({ $0.neighborID != neighborID && $0.errand?.recipientID != neighborID }) {
                Text("今天没有托你的事，沿街走走吧。")
            }
            let stories = game.neighbors.stories(neighborID)
            ForEach(Array(stories.enumerated()), id: \.offset) { index, story in
                GroupBox("街坊往事 · \(index + 1)") { Text(story).frame(maxWidth: .infinity, alignment: .leading) }
            }
            if MPCNeighborCatalog.neighbor(neighborID)?.isWritten == true && stories.count < 2 {
                Text("好感达到 \(MPCNeighborCatalog.storyAffinity.map(String.init).joined(separator: " 和 ")) 时，会聊起更多往事。").font(.footnote).foregroundStyle(.secondary)
            }
        }
            .task(id: game.pacingDay) { try? game.openNeighborDay() }
            .task {
                #if DEBUG
                let args = ProcessInfo.processInfo.arguments
                if args.contains("--daily-pacing-device-walk"), args.contains("--daily-map-walk") {
                    try? await Task.sleep(for: .seconds(2))
                    saveDailyLoopReviewFrame("map-talk-\(neighborID)")
                    if args.contains("--daily-map-recipient"), neighborID == "west-lane",
                       let offer = game.neighbors.offers.first(where: { $0.errand?.recipientID == neighborID && game.canRelayNeighbor($0.id) }) {
                        perform { try await game.relayNeighbor(offer.id) }
                        NSLog("DAILY_MAP_RELAY: completed=%@", game.neighbors.offers.first { $0.id == offer.id }?.done == true ? "true" : "false")
                        try? await Task.sleep(for: .seconds(1))
                        saveDailyLoopReviewFrame("map-relay-complete")
                    }
                }
                #endif
            }
            .fullScreenCover(item: $battle) { ticket in
                NeighborPestBattleView(game: game, offerID: ticket.offerID, battleID: ticket.id, onClose: { battle = nil })
            }
    }
    private func offerCard(_ offer: MPCNeighborLedger.Offer, _ errand: MPCNeighborErrand) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(errand.request).font(.headline)
            if offer.done {
                Text(errand.thanks)
                Text("已完成，报酬已到账。").foregroundStyle(.green)
            } else if let ticket = offer.activeTicket {
                Text("有一场未结束的赶塔怪行动。")
                Button("撤销旧行动后重新准备") {
                    do { try game.abandonNeighborPest(offerID: offer.id, ticket: ticket) }
                    catch { message = "撤销未完成，请重试。" }
                }
            } else if offer.day != game.pacingDay {
                Text("这条请求已过期。")
            } else {
                StaminaCostView(activity: game.staminaActivityForNeighbor(offer.id))
                Text("完成得 \(errand.copper) 铜 · 好感 +1").font(.subheadline)
                switch errand.kind {
                case .deliver:
                    let stock = game.chapterOneCampaign.inventory[errand.itemID ?? "", default: 0]
                    Text("需要 \(GameStore.workshopItemName(errand.itemID ?? "")) ×\(errand.count) · 持有 \(stock)")
                    Button("交给街坊") { perform { try await game.deliverNeighbor(offer.id) } }.disabled(stock < errand.count)
                    if stock < errand.count { Text("货物不足，先到工坊制作。").font(.footnote) }
                case .find:
                    Text(errand.question ?? "")
                    ForEach(errand.choices, id: \.id) { choice in
                        let excluded = offer.excludedChoiceIDs.contains(choice.id)
                        Button { perform { try await game.answerNeighbor(offer.id, choiceID: choice.id) } } label: {
                            Text(choice.text).strikethrough(excluded).frame(maxWidth: .infinity, alignment: .leading)
                        }.disabled(excluded)
                        if excluded { Text(choice.explanation).font(.footnote).foregroundStyle(.secondary) }
                    }
                    Text("答错只划掉选项，不扣铜。").font(.footnote)
                case .message:
                    if !game.canRelayNeighbor(offer.id) {
                        Button("接下传话") { Task { do { try await game.acceptNeighborMessage(offer.id); message = "话记住了，可以前往接话的人。" } catch { message = game.housingError(error) } } }
                    }
                    Text("已记下口信。请到 \(MPCNeighborCatalog.neighbor(errand.recipientID ?? "")?.name ?? "收话人") 面前交谈。")
                case .pest:
                    Button("去赶走塔怪") { battle = .init(id: UUID().uuidString, offerID: offer.id) }.buttonStyle(GameArtButtonStyle(primary: true))
                }
            }
        }
    }
    private func perform(_ action: @escaping () async throws -> MPCNeighborLedger.Reward?) {
        Task {
        do {
            if let reward = try await action() { message = reward.thanks + "\n已收 \(reward.copper) 铜，好感 \(reward.affinity)。" + (reward.story.map { "\n" + $0 } ?? "") }
            else { message = "这条线索对不上，已划掉该选项；没有扣铜。" }
        } catch { message = game.housingError(error) }
        }
    }
}

struct NeighborPestBattleView: View {
    @Bindable var game: GameStore
    let offerID: String
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
                            _ = try game.settleNeighborPest(offerID: offerID, ticket: battleID, session: result)
                            won = true; finished = true
                        } catch { startError = "结算未完成，请保留本场并重试。" }
                    }, onExit: {
                        if started && !finished { try? game.abandonNeighborPest(offerID: offerID, ticket: battleID, defeated: false) }
                        onClose()
                    },
                    onDefeat: {
                        guard !finished else { return }
                        try? game.abandonNeighborPest(offerID: offerID, ticket: battleID, defeated: true)
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
                            configuredSession = try await game.beginNeighborPest(offerID: offerID, ticket: battleID, skills: skills)
                            started = true
                        } catch { startError = game.housingError(error) } }
                    })
                VStack { HStack { GameArtReturnButton(title: "返回街坊") { onClose() }; Spacer() }; Spacer() }.padding()
            }
            if !startError.isEmpty { Text(startError).foregroundStyle(.orange).padding().background(.black) }
            if finished {
                GameArtBattleResult(won: won, detail: won ? "塔怪已赶走，委托报酬和好感已到账。" : "这一场不记贡献，可以重新准备。", title: "返回街坊", action: onClose)
            }
        }
        .preferredColorScheme(.dark).buttonStyle(.plain)
        .task { if previewSession == nil { previewSession = try? game.neighborPestPreview(offerID: offerID, ticket: battleID) } }
    }
}
