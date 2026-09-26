import SwiftUI
import MistportCombatCore

// Register this source with the Mistport application target. State and wallet
// transactions live in GameStore's shared ChurchServices journal, not this view.
private let maintenanceGold = Color(red: 0.88, green: 0.75, blue: 0.47)

struct ChurchMaintenanceView: View {
    @Bindable var game: GameStore
    let onBack: () -> Void
    @State private var selectedJobID: String?
    @State private var selectedFloor = 1
    @State private var battlePresented = false
    @State private var notice = ""
    private var openJobs: [MPCChurchMaintenanceJob] { game.churchMaintenanceJobs.filter { !$0.claimed } }
    private var job: MPCChurchMaintenanceJob? { selectedJobID.flatMap { game.churchServices.maintenance.jobs[$0] } }
    private var clearedFloors: [Int] {
        let cleared = game.churchTowerProgress.clearedFloors
        return stride(from:10,through:100,by:10).filter { end in (1...end).allSatisfy(cleared.contains) }
    }

    var body: some View {
        ZStack {
            GeometryReader { g in
                Image(job == nil ? "ChurchJointSanctuary" : "ChurchSealMap").resizable().scaledToFill()
                    .frame(width:g.size.width,height:g.size.height).clipped()
            }.ignoresSafeArea()
            LinearGradient(colors:[.black.opacity(0.36),.black.opacity(0.1),.black.opacity(0.88)],startPoint:.top,endPoint:.bottom).ignoresSafeArea()
            VStack(spacing:0) {
                ChurchSceneHeader(title:job == nil ? "封线值务" : (job?.kind == .patrol ? "封口巡检" : "塔内维护"),
                    subtitle:job == nil ? "按件结算 · 无入场费" : "核验工单，再前往清剿",
                    onBack:{ if selectedJobID != nil { selectedJobID=nil; notice="" } else { onBack() } })
                ScrollView {
                    VStack(alignment:.leading,spacing:24) {
                        if game.churchHasDepartedMistport { Text(game.churchNeedsRemoteContact ? game.churchRemoteContactPauseReason : game.churchMistportPauseReason).font(.footnote).foregroundStyle(maintenanceGold) }
                        if let job { workOrder(job) } else { workSelection }
                        if !notice.isEmpty { Text(notice).font(.callout).foregroundStyle(maintenanceGold).padding(.vertical,8) }
                    }.padding(.horizontal,24).padding(.bottom,32)
                }
            }
        }.foregroundStyle(.white)
        .onAppear { if !clearedFloors.contains(selectedFloor) { selectedFloor=clearedFloors.first ?? 1 } }
        .fullScreenCover(isPresented:$battlePresented) {
            if let job {
                ChurchMaintenanceBattleView(game:game,job:job,onExit:{ battlePresented=false })
            }
        }
    }
    private var workSelection: some View {
        VStack(alignment:.leading,spacing:26) {
            Spacer().frame(height:100)
            Text("有人守住入口，才有人能够回去。")
                .font(.system(size:23,weight:.medium,design:.serif)).shadow(color:.black,radius:6)
            if !openJobs.isEmpty {
                Text("未结工单").font(.headline).foregroundStyle(maintenanceGold)
                ForEach(openJobs) { job in
                    Button { selectedJobID=job.id; notice="" } label: {
                        HStack {
                            Text(job.kind == .patrol ? "封口巡检" : "第\(max(1,job.floor-9))–\(job.floor)层维护")
                            Spacer()
                            Text(job.activeBattleID == nil ? "继续核验" : "中断待结")
                        }.padding(.vertical,13).overlay(alignment:.bottom) { Rectangle().fill(maintenanceGold.opacity(0.5)).frame(height:1) }
                    }.buttonStyle(.plain)
                }
            }
            VStack(alignment:.leading,spacing:12) {
                Text("巡检封口").font(.system(size:25,weight:.bold,design:.serif)).foregroundStyle(maintenanceGold)
                Text("核对封签与人员撤离后，依次巡检三处封口。每处连续清理两波，三处完成才结算整单报酬。")
                Text("60 铜币  ·  6 功勋").foregroundStyle(maintenanceGold)
                ChurchActionButton(title:game.churchTowerMissionNumbers.contains(9) ? "领取巡检工单" : "完成第9关后开放",enabled:game.churchTowerMissionNumbers.contains(9) && game.churchMistportFieldworkAvailable) {
                    perform { selectedJobID = try game.acceptChurchMaintenance(kind:.patrol) }
                }
            }.padding(18).background(.black.opacity(0.65)).overlay(Rectangle().stroke(maintenanceGold.opacity(0.6)))
            VStack(alignment:.leading,spacing:12) {
                Text("维护已封层段").font(.system(size:25,weight:.bold,design:.serif)).foregroundStyle(maintenanceGold)
                Text("只复巡已完整封堵的十层段。三个维护点各清理三波，全部完成后结算；不重复领取深井首通奖励。")
                if clearedFloors.isEmpty {
                    Text("完整封堵第1–10层后，可接取维护。").foregroundStyle(.white.opacity(0.65))
                } else {
                    HStack {
                        Button { moveFloor(-1) } label:{ Image(systemName:"chevron.left").frame(width:44,height:44) }.accessibilityLabel("上一已通层")
                        Spacer()
                        Text("第 \(max(1,selectedFloor-9))–\(selectedFloor) 层").font(.title3.bold()).foregroundStyle(maintenanceGold)
                        Spacer()
                        Button { moveFloor(1) } label:{ Image(systemName:"chevron.right").frame(width:44,height:44) }.accessibilityLabel("下一已通层")
                    }
                }
                Text("80 铜币  ·  8 功勋").foregroundStyle(maintenanceGold)
                ChurchActionButton(title:"领取维护工单",enabled:!clearedFloors.isEmpty && game.churchRemoteServicesAvailable) {
                    perform { selectedJobID = try game.acceptChurchMaintenance(kind:.towerMaintenance,floor:selectedFloor) }
                }
            }.padding(18).background(.black.opacity(0.65)).overlay(Rectangle().stroke(maintenanceGold.opacity(0.6)))
        }
    }
    @ViewBuilder private func workOrder(_ job: MPCChurchMaintenanceJob) -> some View {
        VStack(alignment:.leading,spacing:20) {
            Text(job.kind == .patrol ? "三处封口 · 值守交接" : "第\(max(1,job.floor-9))–\(job.floor)层 · 维护路线")
                .font(.system(size:25,weight:.bold,design:.serif)).foregroundStyle(maintenanceGold)
            Text("维护点完成 \(job.completedSites.count) / 3")
                .font(.headline).foregroundStyle(maintenanceGold)
            Text("每处独立整备；出战正常计入借物与自有遗物磨损。")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
            ForEach(Array(job.objectives.enumerated()),id:\.element.id) { index, objective in
                let complete = job.completedObjectiveIDs.contains(objective.id)
                let available = game.churchMaintenanceAvailable(job.kind) && (index == 0 || job.completedObjectiveIDs.contains(job.objectives[index-1].id))
                VStack(alignment:.leading,spacing:12) {
                    HStack { Text("\(index+1).  \(objective.title)").font(.headline); Spacer(); if complete { Text("已核验").foregroundStyle(maintenanceGold) } }
                    Text(objective.evidence).font(.body).lineSpacing(5)
                    if available && !complete {
                        ForEach(objective.choices) { choice in
                            let excluded = job.excludedChoiceIDs.contains(choice.id)
                            Button {
                                perform {
                                    try game.verifyChurchMaintenance(jobID:job.id,objectiveID:objective.id,choiceID:choice.id)
                                    notice = choice.explanation
                                }
                            } label: {
                                HStack(alignment:.top) {
                                    Text(excluded ? "×" : "◇").foregroundStyle(maintenanceGold)
                                    Text(choice.text).multilineTextAlignment(.leading)
                                }.frame(maxWidth:.infinity,alignment:.leading).padding(.vertical,10)
                                    .overlay(alignment:.bottom) { Rectangle().fill(maintenanceGold.opacity(0.35)).frame(height:1) }
                            }.buttonStyle(.plain).disabled(excluded).opacity(excluded ? 0.5 : 1)
                        }
                    } else if !complete { Text("先完成上一项核验").font(.caption).foregroundStyle(.white.opacity(0.55)) }
                }.padding(18).background(.black.opacity(0.72)).overlay(Rectangle().stroke(maintenanceGold.opacity(complete ? 0.8 : 0.28)))
            }
            if job.claimed {
                Text("工单已结清").font(.title2).foregroundStyle(maintenanceGold)
                ChurchActionButton(title:"返回值务处") { selectedJobID=nil }
            } else if let interrupted = job.activeBattleID {
                Text("上次清剿尚未结算。放弃后会按撤退结清借物，再重新整备。")
                ChurchActionButton(title:"结清中断战斗") {
                    perform { try game.finishChurchMaintenance(jobID:job.id,battleID:interrupted,outcome:.retreat) }
                }
            } else {
                ChurchActionButton(title:"前往第\(job.currentSite)处清剿",enabled:game.churchMaintenanceAvailable(job.kind) && job.objectives.allSatisfy {job.completedObjectiveIDs.contains($0.id)}) { battlePresented=true }
            }
        }.padding(.top,24)
    }
    private func moveFloor(_ delta:Int) {
        guard let index=clearedFloors.firstIndex(of:selectedFloor), !clearedFloors.isEmpty else { return }
        selectedFloor=clearedFloors[min(clearedFloors.count-1,max(0,index+delta))]
    }
    private func perform(_ operation:() throws -> Void) {
        do { try operation() } catch { notice="工单尚未变更，请核对开放层段与未结战斗。" }
    }
}

private struct ChurchMaintenanceBattleView: View {
    @Bindable var game: GameStore
    let job: MPCChurchMaintenanceJob
    let onExit: () -> Void
    @State private var session: MPCChapterOneEncounterSession?
    @State private var skills:[FoolSkillID] = []
    @State private var started=false
    @State private var battleID=UUID().uuidString
    @State private var victory=false
    @State private var reordered=true
    @State private var notice=""
    private var liveJob: MPCChurchMaintenanceJob { game.churchServices.maintenance.jobs[job.id] ?? job }
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let session {
                ChapterOneEncounterTestView(initialSession:session,campaign:game.churchBattleCampaign,playerSequence:game.currentSequence,
                    battleIsActive:started,showsStandaloneOpeningBattleButton:false,
                    onVictory:{ _ in
                        do { try game.finishChurchMaintenance(jobID:job.id,battleID:battleID,outcome:.victory); victory=true }
                        catch { notice="结算尚未完成，请保留本页。" }
                    },onExit:{ finish(.retreat); onExit() },onDefeat:{ finish(.defeat) },
                    onRetrySetup:{ finish(.retreat); started=false; skills=[]; battleID=UUID().uuidString; preview() },
                    onUseManualMask:{ game.recordManualMaskUse(encounterID:job.encounterID) },onConsumeSupply:game.consumeCampaignSupply)
                    .id(battleID)
            }
            if !started && !victory {
                ChapterOneBattleSetupOverlay(availableSkills:MPCChapterOneCatalog.visibleSkills.filter {game.chapterOneCampaign.unlockedSkillIDs.contains($0.id) && $0.id != .maskedWhisper},
                    relics:[],selectedSkillIDs:$skills,requiresFirstReorder:false,slotCapacity:game.chapterOneLoadoutSlotCapacity,
                    hasCompletedFirstReorder:$reordered,usesEarlyTutorialLayout:true,showsStartTutorialHint:false,onStart:{
                        do { session=try game.beginChurchMaintenance(jobID:job.id,battleID:battleID,skills:skills); started=true }
                        catch { notice="无法进入清剿，请检查工单或借物未结记录。" }
                    })
                VStack { HStack { Button("返回工单",action:onExit).padding(16); Spacer() }; Spacer() }
            }
            if victory {
                Color.black.opacity(0.85).ignoresSafeArea()
                VStack(spacing:24) {
                    Image("BattleVictoryCrest").resizable().scaledToFit().frame(height:140)
                    Text(liveJob.allSitesComplete ? "值务完成" : "本处封线恢复").font(.system(size:30,weight:.bold,design:.serif)).foregroundStyle(maintenanceGold)
                    Text("维护点完成 \(liveJob.completedSites.count) / 3").foregroundStyle(maintenanceGold)
                    if liveJob.allSitesComplete {
                        Text(job.kind == .patrol ? "+60 铜币    +6 功勋" : "+80 铜币    +8 功勋").foregroundStyle(maintenanceGold)
                        Text("三处均已完成，工单报酬已结清。").font(.callout)
                        ChurchActionButton(title:"返回值务处",action:onExit)
                    } else {
                        Text("本处不单独发放报酬。下一处重新编排后出战。").font(.callout).multilineTextAlignment(.center)
                        ChurchActionButton(title:"整备第\(liveJob.currentSite)处") {
                            started=false; victory=false; skills=[]; notice=""
                            battleID=UUID().uuidString; preview()
                        }
                        ChurchActionButton(title:"保存进度，返回工单",action:onExit)
                    }
                }.padding(28)
            }
            if !notice.isEmpty { VStack { Spacer(); Text(notice).padding().background(.black); Spacer() }.allowsHitTesting(false) }
        }.foregroundStyle(.white).onAppear { preview() }
    }
    private func preview() {
        var loadout=game.churchBattleCampaign.loadout; loadout.normalSkillIDs=[]
        session=try? MPCChapterOneEncounterSession.start(encounterID:liveJob.encounterID,party:game.chapterOneCampaign.party,
            consumables:game.chapterOneCampaign.inventory,companionIDs:[],loadout:loadout)
    }
    private func finish(_ outcome:MPCChurchBattleOutcome) {
        guard started else { return }
        do { try game.finishChurchMaintenance(jobID:job.id,battleID:battleID,outcome:outcome) }
        catch { notice="结算未完成，请稍后从工单继续处理。" }
    }
}
