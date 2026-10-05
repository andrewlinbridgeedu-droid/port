import SwiftUI
import MistportCombatCore

struct RemnantCasesView: View {
    @Bindable var game: GameStore
    @State private var message = ""
    @State private var battle: RemnantTicket?
    private struct RemnantTicket: Identifiable { let id: String; let day: Int }

    var body: some View {
        MistportNewsprintPage(title: "无名残余案", day: game.pacingDay) {
            Text("通缉结案后，每天有一个当地小案。未接的日子不累计；保留最近 7 天，在途战斗和已胜未领报酬另行保留。").font(.footnote).foregroundStyle(.secondary)
            Text(game.repeatWorkNotice)
            StaminaCostView(activity: .remnant)
            if let today = game.todayRemnant {
                if game.remnants.job(day: game.pacingDay) == nil {
                    Text(today.title).font(.headline)
                    Text(today.area)
                    Button("接下今天的小案") { perform { try game.acceptDailyRemnant() } }.buttonStyle(GameArtButtonStyle(primary: true))
                }
            } else { Text("先完成任意一份通缉案的结案领奖，这片街区才会开放每日残余案。") }
            ForEach(game.remnants.jobs.values.sorted { $0.day > $1.day }, id: \.day) { job in
                if let remnant = job.remnant { jobCard(job, remnant) }
            }
            if !message.isEmpty { Text(message).foregroundStyle(.orange) }
        }
            .task(id: game.pacingDay) { perform { try game.openRemnantDay() } }
            .fullScreenCover(item: $battle) { ticket in
                RemnantBattleView(game: game, day: ticket.day, battleID: ticket.id, onClose: { battle = nil })
            }
    }
    private func jobCard(_ job: MPCRemnantLedger.Job, _ remnant: MPCRemnantCase) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("第 \(job.day) 天 · \(remnant.title)").font(.system(size: 22, weight: .bold, design: .serif))
            Text("\(remnant.area) · 强度按塔层 \(job.band) 档").font(.subheadline)
            if job.claimed { Text("已领奖，不会重复发放。").foregroundStyle(.green) }
            else if job.won {
                Text("战斗胜利，报酬保留待领。")
                Button("领取 \(game.repeatWorkPreview(copper: MPCRemnantCatalog.copper)) + \(GameStore.workshopItemName(remnant.material)) ×2") {
                    do {
                        if let payout = try game.claimRemnant(day: job.day) { message = "已收 \(payout.copper) 铜及材料 ×2。" }
                    } catch { message = "暂未领到报酬，请重试；已胜记录仍保留。" }
                }.buttonStyle(GameArtButtonStyle(primary: true))
            } else if let ticket = job.activeTicket {
                Text("有一场未结束的战斗；撤销后可重新准备。")
                Button("撤销未结束的战斗") { perform { try game.abandonRemnant(day: job.day, ticket: ticket) } }
            } else {
                let lead = remnant.leads[job.lead]
                Text(lead.evidence)
                if !job.solved {
                    Text(lead.question).font(.headline)
                    ForEach(lead.choices, id: \.id) { choice in
                        let excluded = job.excludedChoiceIDs.contains(choice.id)
                        Button {
                            Task { do { message = try await game.answerRemnant(day: job.day, choiceID: choice.id) ? "线索对上了，可以前往清理。" : "线索不符，已划掉；不扣铜。" }
                            catch { message = game.housingError(error) } }
                        } label: { Text(choice.text).strikethrough(excluded).frame(maxWidth: .infinity, alignment: .leading) }
                            .disabled(excluded)
                        if excluded { Text(choice.explanation).font(.footnote).foregroundStyle(.secondary) }
                    }
                } else {
                    Text("调查完成。当前预计：\(game.repeatWorkPreview(copper: MPCRemnantCatalog.copper))，另得材料 ×2。")
                    Button("前往清理") { battle = .init(id: UUID().uuidString, day: job.day) }.buttonStyle(GameArtButtonStyle(primary: true))
                }
            }
            Rectangle().fill(.primary.opacity(0.4)).frame(height: 0.6).padding(.top, 6)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func perform(_ action: () throws -> Void) {
        do { try action(); message = "" } catch { message = "操作未完成，请核对当前案卷和未结束的战斗。" }
    }
}

struct RemnantBattleView: View {
    @Bindable var game: GameStore
    let day: Int
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
                            try game.settleRemnant(day: day, ticket: battleID, session: result)
                            won = true; finished = true
                        } catch { startError = "结算未完成，请保留本场并重试。" }
                    }, onExit: {
                        if started && !finished { try? game.abandonRemnant(day: day, ticket: battleID, defeated: false) }
                        onClose()
                    },
                    onDefeat: {
                        guard !finished else { return }
                        try? game.abandonRemnant(day: day, ticket: battleID, defeated: true)
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
                            configuredSession = try await game.beginRemnant(day: day, ticket: battleID, skills: skills)
                            started = true
                        } catch { startError = game.housingError(error) } }
                    })
                if (configuredSession ?? previewSession) == nil {
                    VStack { HStack { GameArtReturnButton(title: "返回案卷") { onClose() }; Spacer() }; Spacer() }.padding()
                }
            }
            if !startError.isEmpty { Text(startError).foregroundStyle(.orange).padding().background(.black) }
            if finished {
                GameArtBattleResult(won: won, detail: won ? "残余已清理，回案卷领取报酬。" : "这一场不记贡献，可以重新准备。", title: "返回案卷", action: onClose)
            }
        }
        .preferredColorScheme(.dark).buttonStyle(.plain)
        .task { if previewSession == nil { previewSession = try? game.remnantPreview(day: day, ticket: battleID) } }
    }
}
