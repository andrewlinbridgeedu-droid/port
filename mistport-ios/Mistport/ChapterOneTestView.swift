import MistportCombatCore
import SpriteKit
import SwiftUI
import UniformTypeIdentifiers

struct ChapterOneTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0
    @State private var session: MPCChapterOneEncounterSession?
    @State private var pendingConclusion: MPCChapterOneEncounterSession?
    @State private var completedPreview: MPCChapterOneEncounterSession?
    @State private var campaign: MPCChapterOneCampaignState
    @State private var companionOrder = MPCChapterOneCatalog.companions.map(\.id)
    /// Recreate the player-facing state immediately before Q5. The direct
    /// device preview must exercise the authored tutorial hand, not the
    /// fully-unlocked combat sandbox used by the design catalog preview.
    private static func hellHoundTutorialCampaign(missionID: String) -> MPCChapterOneCampaignState {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        for missionNumber in 1..<Int(missionID.suffix(2))! {
            _ = campaign.applyChapterMissionProgress(
                districtID: "old-clock",
                missionNumber: missionNumber
            )
        }
        // Q4 and Q5 are both authored around the same two-card lesson. Keep
        // the direct device previews faithful to the player route even when
        // they are launched without replaying Q1–Q3 in the UI.
        campaign.unlockedSkillIDs.insert(.sidestepStrike)
        campaign.skillUnlockStates[.sidestepStrike] = .permanent
        campaign.grantHoundTutorialCard()
        campaign.loadout.normalSkillIDs = [.fabricatedEvidence, .sidestepStrike]
        campaign.loadoutSlotCapacity = 2
        campaign.currentMissionID = missionID
        return campaign
    }

    /// Recreate the player-facing hand immediately before Q3. Q1's card is
    /// already permanent, while Q3's reward card is not available until this
    /// encounter is cleared. This keeps the direct device check faithful to
    /// the route while still isolating the multi-enemy presentation.
    private static func fogGhostPreviewCampaign() -> MPCChapterOneCampaignState {
        var campaign = clockCoreTutorialCampaign()
        campaign.unlockedSkillIDs.remove(.maskedWhisper)
        campaign.skillUnlockStates.removeValue(forKey: .maskedWhisper)
        campaign.loadout.normalSkillIDs = [.sidestepStrike]
        campaign.currentMissionID = "chapter01_q02"
        return campaign
    }

    private static func clockCoreTutorialCampaign() -> MPCChapterOneCampaignState {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        for q in 1...2 { _ = campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: q) }
        campaign.unlockedSkillIDs.insert(.sidestepStrike)
        campaign.skillUnlockStates[.sidestepStrike] = .permanent
        campaign.loadout.normalSkillIDs = [.sidestepStrike]
        campaign.loadout.normalSkillIDs = [.fabricatedEvidence, .sidestepStrike]
        campaign.loadoutSlotCapacity = 2
        campaign.currentMissionID = "chapter01_q03"
        campaign.grantHoundTutorialCard()
        return campaign
    }

    /// The sixth acceptance scene is the original SpriteKit encounter. Give
    /// it the two authored cards so its fallback presentation can be checked
    /// with the same sequence density as the Unity Q1-Q5 scenes, while keeping
    /// the relic row empty.
    private static func rainFirstPreviewCampaign() -> MPCChapterOneCampaignState {
        // This is a presentation fallback, but it must still look like the
        // story hand rather than the old all-unlocked design sandbox. Start
        // from the real campaign state and add only the two cards this scene
        // is meant to exercise. In particular, do not inherit the sandbox's
        // relics or its complete skill catalogue.
        var campaign = MPCChapterOneCampaignState.chapterStartState
        campaign.unlockedSkillIDs.insert(.sidestepStrike)
        campaign.skillUnlockStates[.sidestepStrike] = .permanent
        campaign.grantHoundTutorialCard()
        campaign.loadout.normalSkillIDs = [.sidestepStrike]
        campaign.loadoutSlotCapacity = 2
        campaign.currentMissionID = "encounter_rain_01"
        return campaign
    }

    private static func houndFinaleCampaign() -> MPCChapterOneCampaignState {
        var campaign = hellHoundTutorialCampaign(missionID: "chapter01_q06")
        if let cleared = MPCChapterOneCatalog.encounters.first(where: { $0.id == "chapter01_q05_encounter" }) {
            campaign.claimVictory(for: cleared)
        }
        if campaign.ownedRelicIDs.contains("relic_paper_raincoat") {
            campaign.loadout.relicIDs = ["relic_paper_raincoat"]
        }
        campaign.currentMissionID = "chapter01_q06"
        return campaign
    }

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let isLeechPreview = (arguments.contains("--preview-chapter-one-leech") || arguments.contains("--preview-chapter-one-q6"))
        let isFirstBattlePreview = arguments.contains("--preview-chapter-one-battle")
        let isGhostPreview = arguments.contains("--preview-chapter-one-q2")
        let isClockCorePreview = arguments.contains("--preview-chapter-one-q3")
        let isHoundFirstPreview = arguments.contains("--preview-chapter-one-hound-first")
        let isDevVerification = arguments.contains("--preview-chapter-one-dev-verification") || arguments.contains("--preview-chapter-one-encore-bell")
        let isRainFirstPreview = arguments.contains("--preview-chapter-one-rain-first")
        // The battle preview is specifically for the opening tutorial, not
        // the full design sandbox. Keep only the one starting card available.
        let seededPreviewCampaign: MPCChapterOneCampaignState = if isLeechPreview {
            Self.houndFinaleCampaign()
        } else if isFirstBattlePreview {
            .chapterStartState
        } else if isGhostPreview {
            Self.fogGhostPreviewCampaign()
        } else if isClockCorePreview {
            Self.clockCoreTutorialCampaign()
        } else if isHoundFirstPreview {
            Self.hellHoundTutorialCampaign(missionID: "chapter01_q04")
        } else if isDevVerification {
            Self.hellHoundTutorialCampaign(missionID: "chapter01_q05")
        } else if isRainFirstPreview {
            Self.rainFirstPreviewCampaign()
        } else {
            // The chapter test台 is the player route on a real device. Keep
            // its initial state identical to a fresh campaign so cards and
            // relics appear only after their authored story rewards.
            .chapterStartState
        }
        let isDeveloperPreview = arguments.contains("--preview-chapter-one")
            || arguments.contains { $0.hasPrefix("--preview-chapter-one-") }
        var previewCampaign = seededPreviewCampaign
        if arguments.contains("--preview-chapter-one-encore-bell") {
            previewCampaign.loadout.normalSkillIDs = []
            previewCampaign.loadout.relicIDs = []
        }
        let requestedMission = arguments.first(where: { $0.hasPrefix("--preview-chapter-one-mission=") })
            .flatMap { Int($0.split(separator: "=").last ?? "") }
        // These two direct battles are visual audit fixtures. They run only
        // with the isolated player-test-audit suite, never grant a real tower
        // clear or bounty settlement, and do not imply legal progression.
        let hasAuditSuite = arguments.contains("--player-test-audit")
        let requestedTowerFloor = hasAuditSuite
            ? arguments.first(where: { $0.hasPrefix("--preview-chapter-one-church-floor=") })
                .flatMap { Int($0.split(separator: "=").last ?? "") }
            : nil
        let requestedBountyID = hasAuditSuite
            ? arguments.first(where: { $0.hasPrefix("--preview-chapter-one-bounty-case=") })
                .flatMap { $0.split(separator: "=").last.map { String($0).lowercased() } }
            : nil
        if let number = requestedMission, (1...30).contains(number) {
            previewCampaign = .chapterStartState
            for mission in MPCChapterOneCatalog.missions where mission.number < number {
                if let encounter = MPCChapterOneCatalog.encounters.first(where: { $0.id == mission.encounterID }) {
                    previewCampaign.claimVictory(for: encounter)
                }
            }
            previewCampaign.loadout.normalSkillIDs = []
        }
        if (requestedTowerFloor != nil || requestedBountyID != nil) && requestedMission == nil {
            // Use one local Q30-equivalent hand so all audited enemy types can
            // be opened without modifying Preferences or forging past clears.
            previewCampaign = .chapterStartState
            for mission in MPCChapterOneCatalog.missions {
                if let encounter = MPCChapterOneCatalog.encounters.first(where: { $0.id == mission.encounterID }) {
                    previewCampaign.claimVictory(for: encounter)
                }
            }
            previewCampaign.loadout.normalSkillIDs = []
        }
        _campaign = State(initialValue: isDeveloperPreview ? previewCampaign : .chapterStartState)
        let initialTab: Int
        if arguments.contains("--preview-chapter-one-skills") {
            initialTab = 1
        } else if arguments.contains("--preview-chapter-one-companions") {
            initialTab = 2
        } else {
            initialTab = 0
        }
        _tab = State(initialValue: initialTab)

        if (isLeechPreview || isFirstBattlePreview || isGhostPreview || isClockCorePreview || isHoundFirstPreview || isDevVerification || isRainFirstPreview),
           let encounterID = isLeechPreview ? Optional("chapter01_q08_encounter") : isGhostPreview ? Optional("chapter01_q02_encounter") : isClockCorePreview
                ? Optional("chapter01_q03_encounter")
                : isHoundFirstPreview
                ? Optional("chapter01_q04_encounter")
                : isDevVerification
                ? Optional("chapter01_q05_encounter")
                : isRainFirstPreview
                ? Optional("encounter_rain_01")
                : Optional("chapter01_q01_encounter") {
            _session = State(initialValue: try? .start(
                encounterID: encounterID,
                party: previewCampaign.party,
                consumables: previewCampaign.inventory,
                companionIDs: MPCChapterOneCatalog.mission(forEncounterID: encounterID)?.companionIDs ?? [],
                loadout: isRainFirstPreview
                    ? previewCampaign.effectiveLoadout
                    : isFirstBattlePreview
                    ? previewCampaign.loadout(forMissionID: "chapter01_q01")
                    : (isHoundFirstPreview || isDevVerification)
                        ? previewCampaign.loadout(forMissionID: isHoundFirstPreview ? "chapter01_q04" : "chapter01_q05")
                        : previewCampaign.effectiveLoadout
            ))
        }
        if let number = requestedMission,
           let mission = MPCChapterOneCatalog.missions.first(where: { $0.number == number }) {
            _session = State(initialValue: try? .start(encounterID: mission.encounterID,
                party: previewCampaign.party, consumables: previewCampaign.inventory,
                companionIDs: mission.companionIDs, loadout: previewCampaign.loadout))
        }
        if let number = requestedTowerFloor, (1...100).contains(number),
           let floor = MPCChurchTowerCatalog.floor(number: number) {
            _session = State(initialValue: try? .start(encounterID: floor.id,
                party: previewCampaign.party, consumables: previewCampaign.inventory,
                companionIDs: [], loadout: previewCampaign.loadout))
        }
        if let id = requestedBountyID, let bounty = MPCChurchBountyCatalog.bounty(id: id) {
            _session = State(initialValue: try? .start(encounterID: bounty.encounterID,
                party: previewCampaign.party, consumables: previewCampaign.inventory,
                companionIDs: [], loadout: previewCampaign.loadout))
        }

    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("内容", selection: $tab) {
                    Text("关卡").tag(0)
                    Text("技能").tag(1)
                    Text("队友").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .accessibilityIdentifier("chapter-one-test-tabs")

                switch tab {
                case 0: encounters
                case 1: skills
                default: companions
                }
            }
            .background(Color(red: 0.04, green: 0.05, blue: 0.09))
            .foregroundStyle(.white)
            .navigationTitle("第一章 · 雾港·被保存的人")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("退出") { dismiss() } } }
            .fullScreenCover(item: $session) { active in
                ChapterOneEncounterTestView(
                    initialSession: active,
                    campaign: campaign,
                    battleIsActive: false,
                    automatesSkillSequence: true,
                    encorePrototypeEnabled: active.encounter.id == "chapter01_q05_encounter",
                    tutorialCue: active.encounter.id == "chapter01_q02_encounter" ? .fogGhostPrelude : active.encounter.id == "chapter01_q03_encounter" ? .houndPrelude : nil,
                    requiresExplicitBattleStartAfterIntervention: true,
                    onVictory: finish,
                    onExit: { session = nil; completedPreview = nil }
                )
                .overlay {
                    if let completedPreview {
                        ChapterOneVictoryReceiptView(title: "演练完成", receipt: .init(
                            missionID: completedPreview.encounter.id, coins: 0, firstClear: false, materials: 0), skillIDs: []) {
                            self.completedPreview = nil
                            session = nil

                        }
                    }
                }
            }

        }
    }

    private var encounters: some View {
        List {
            Section("进度") {
                Text("已完成 \(campaign.completedEncounterIDs.count) / \(orderedEncounterIDs.count) · 测试关卡已全部开放")
                if let worldState = campaign.endingWorldState {
                    Text("区域结局：\(worldState)").font(.caption)
                }
                if campaign.misdirectionTrainingCompleted {
                    Text("阶位8误导训练：已完成").foregroundStyle(.green)
                }
            }
            ForEach(MPCChapterOneCatalog.investigations) { investigation in
                Section(investigation.id == "chapter01_q05" ? "不肯落幕 · 翠焰亡灵试演" : investigation.name) {
                    Text(investigation.id == "chapter01_q04"
                         ? "猎犬留在远处蓄力喷吐冥火；观察蓄力节奏，练习假面承接与反击。"
                         : investigation.id == "chapter01_q05"
                         ? "翠焰亡灵蓄力施法；摇铃延缓3秒，但返场伤害提高50%。手动假面可承接一次攻击。当前为独立试演。"
                         : investigation.narrativeOutcome).font(.caption).foregroundStyle(.secondary)
                    ForEach(investigation.encounterIDs, id: \.self) { id in
                        if let encounter = MPCChapterOneCatalog.encounters.first(where: { $0.id == id }) {
                            Button {
                                // Direct test entry includes the cards already
                                // taught by this point; selection remains manual.
                                let mission = MPCChapterOneCatalog.mission(forEncounterID: id)
                                if let number = mission?.number, number >= 2 {
                                    campaign.unlockedSkillIDs.insert(.sidestepStrike)
                                    campaign.skillUnlockStates[.sidestepStrike] = .permanent
                                }
                                if let number = mission?.number, number >= 3 {
                                    campaign.grantHoundTutorialCard()
                                }
                                var encounterLoadout = playableLoadout
                                if let number = mission?.number, number == 1 {
                                    encounterLoadout.normalSkillIDs.removeAll { $0 != .sidestepStrike }
                                }
                                session = try? .start(
                                    encounterID: id, party: campaign.party,
                                    consumables: campaign.inventory,
                                    companionIDs: availableCompanionIDs,
                                    loadout: encounterLoadout
                                )
                            } label: {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(id == "chapter01_q05_encounter" ? "不肯落幕 · 翠焰亡灵" : encounter.name)
                                        Spacer()
                                        Text(encounterStatus(id))
                                    }
                                    Text("\(encounter.waves.count)波 · 手动选牌后开始战斗")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .disabled(!isEncounterAvailable(id))
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("chapter-one-encounters-list")
        .scrollContentBackground(.hidden)
    }

    private var skills: some View {
        // Paper Double is delivered by Mara as a relic now. Keep the legacy
        // enum/content entry for save compatibility, but never expose it in
        // the active-skill catalogue or let it look like an unlockable card.
        let displayedSkills = MPCChapterOneCatalog.visibleSkills.filter { $0.id != .paperDouble }
        return List {
            Section("\(displayedSkills.count)个主动技能 · 装备6个普通技能") {
                ForEach(displayedSkills) { skill in
                    Button {
                        if !skill.isUltimate { toggleNormalSkill(skill.id) }
                    } label: {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(skill.name + (skill.isUltimate ? " · 终极" : ""))
                                Spacer()
                                Text(skillStatus(skill))
                            }
                            Text(skill.summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!campaign.unlockedSkillIDs.contains(skill.id) || skill.isUltimate)
                }
            }
            Section("6个被动 · 装备2个") {
                ForEach(MPCChapterOneCatalog.passives) { passive in
                    Button { togglePassive(passive.id) } label: {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(passive.name)
                                Spacer()
                                Text(!campaign.unlockedPassiveIDs.contains(passive.id) ? "未解锁" : (campaign.loadout.passiveIDs.contains(passive.id) ? "已装备" : "未装备"))
                            }
                            Text(passive.summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(!campaign.unlockedPassiveIDs.contains(passive.id))
                }
            }
            Section("战前仪式") {
                Picker("仪式", selection: $campaign.loadout.ritual) {
                    ForEach(MPCChapterOneRitual.allCases, id: \.self) { ritual in
                        Text(localizedRitual(ritual)).tag(ritual)
                    }
                }
            }
        }
        .accessibilityIdentifier("chapter-one-skills-list")
        .scrollContentBackground(.hidden)
    }

    private var companions: some View {
        List {
            Section("点击调整优先出战顺序") {
                ForEach(MPCChapterOneCatalog.companions) { companion in
                    Button {
                        companionOrder.removeAll(where: { $0 == companion.id })
                        companionOrder.insert(companion.id, at: 0)
                    } label: {
                        VStack(alignment: .leading) {
                            HStack {
                                Text(companion.name)
                                Spacer()
                                Text(availableCompanionIDs.contains(companion.id) ? "顺位 \((companionOrder.firstIndex(of: companion.id) ?? 0) + 1)" : "未加入")
                            }
                            Text("\(companion.pathName) · \(localizedRole(companion.role))").font(.caption)
                            Text("3普通技能 · 1终极 · 1固定被动").font(.caption2).foregroundStyle(.yellow)
                        }
                    }
                    .disabled(!availableCompanionIDs.contains(companion.id))
                }
            }
        }
        .accessibilityIdentifier("chapter-one-companions-list")
        .scrollContentBackground(.hidden)
    }

    private var orderedEncounterIDs: [String] {
        MPCChapterOneCatalog.investigations.flatMap(\.encounterIDs)
    }

    private var availableCompanionIDs: [String] {
        let completedInvestigations = MPCChapterOneCatalog.investigations.filter { investigation in
            investigation.encounterIDs.allSatisfy(campaign.completedEncounterIDs.contains)
        }.count
        let reachedStage = completedInvestigations + 1
        return companionOrder.filter { id in
            guard let companion = MPCChapterOneCatalog.companions.first(where: { $0.id == id }) else { return false }
            return companion.unlockStage.rawValue <= reachedStage
        }
    }

    private var playableLoadout: MPCChapterOneLoadout {
        var result = campaign.effectiveLoadout
        let storage = ProcessInfo.processInfo.arguments.contains("--verify-p1-ui")
            ? UserDefaults(suiteName: "mistport.p1-ui-verification")! : UserDefaults.standard
        let budget = campaign.completedMissionIDs.contains("chapter01_q09") ? 4 : 0
        result.talents = .restored(storage.stringArray(forKey: "character.hermit-talents.v1") ?? [], budget: budget)
        result.normalSkillIDs = result.normalSkillIDs.filter(campaign.unlockedSkillIDs.contains)
        result.passiveIDs = result.passiveIDs.filter(campaign.unlockedPassiveIDs.contains)
        result.relicIDs = result.relicIDs.filter(campaign.ownedRelicIDs.contains)
        return result
    }

    private func isEncounterAvailable(_ id: String) -> Bool {
        orderedEncounterIDs.contains(id)
    }

    private func encounterStatus(_ id: String) -> String {
        if campaign.completedEncounterIDs.contains(id) { return "可重演" }
        return isEncounterAvailable(id) ? "进入" : "未解锁"
    }

    private func skillStatus(_ skill: MPCSkillContent) -> String {
        guard campaign.unlockedSkillIDs.contains(skill.id) else { return "未解锁" }
        if skill.isUltimate { return "固定终极" }
        return campaign.loadout.normalSkillIDs.contains(skill.id) ? "已装备" : "未装备"
    }

    private func finish(_ completed: MPCChapterOneEncounterSession) {
        guard completedPreview == nil else { return }
        campaign.completeEncounter(completed)
        completedPreview = completed
    }

    private func toggleNormalSkill(_ id: FoolSkillID) {
        if let index = campaign.loadout.normalSkillIDs.firstIndex(of: id) {
            campaign.loadout.normalSkillIDs.remove(at: index)
        } else if campaign.loadout.normalSkillIDs.count < 4 {
            campaign.loadout.normalSkillIDs.append(id)
        } else {
            campaign.loadout.normalSkillIDs[3] = id
        }
    }

    private func togglePassive(_ id: String) {
        toggle(id, in: &campaign.loadout.passiveIDs, limit: 2)
    }

    private func toggle(_ id: String, in values: inout [String], limit: Int) {
        if let index = values.firstIndex(of: id) { values.remove(at: index) }
        else if values.count < limit { values.append(id) }
        else { values[limit - 1] = id }
    }
}

struct ChapterOneConclusionView: View {
    let onComplete: (MPCChapterOneEndingChoice, MPCMisdirectionTrainingResult) -> Void
    @State private var ending: MPCChapterOneEndingChoice?
    @State private var training = MPCMisdirectionTrainingSession()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("归一档案库已经停止。旧城区的记忆将如何处理？")
                        .font(.headline)

                    ForEach(MPCChapterOneEndingChoice.allCases, id: \.self) { choice in
                        Button {
                            ending = choice
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(endingTitle(choice)).font(.headline)
                                    Spacer()
                                    if ending == choice { Image(systemName: "checkmark.circle.fill") }
                                }
                                Text(choice.worldState).font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                        }
                        .buttonStyle(.bordered)
                    }

                    if ending != nil {
                        Divider()
                        Text("阶位8“误导”训练回声").font(.title3.bold())
                        Text("训练攻击将命中玩家本体，并附加“记忆剥离”。选择一种误导方式。")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("把攻击偏转到舞台幻象") {
                            training.perform(.redirectToIllusion)
                        }.buttonStyle(.borderedProminent)
                        Button("保留伤害，但令附加状态失效") {
                            training.perform(.suppressAttachedStatus)
                        }.buttonStyle(.borderedProminent)

                        if let result = training.result {
                            GroupBox("训练结果") {
                                Text(result.summary)
                                Text("最终目标：\(result.finalTarget)")
                            }
                            Text("训练奖励 · 新技能「后手改写」")
                                .font(.subheadline.bold())
                                .foregroundStyle(.yellow)
                            Button("完成训练并铭刻技能") {
                                if let ending { onComplete(ending, result) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("第十三声之后")
        }
    }
}

private func endingTitle(_ choice: MPCChapterOneEndingChoice) -> String {
    switch choice {
    case .destroyClock: "摧毁归一档案库"
    case .sealClock: "交由教会封存"
    case .returnMemories: "分还居民记忆"
    }
}

private enum QueuedRetargetPolicy {
    case anyValidEnemy
    case sameTargetOnly
}

private enum QueuedCombatAction: Equatable {
    case skill(FoolSkillID)
    case basic(MPCPlayerActionCategory)
}

private enum CombatFloatingNumberKind {
    case healing
    case damage
    case defenseUp
    case playerDamage, parried, critical, bonus, status

    func text(for amount: Int) -> String {
        switch self {
        case .healing: "+\(amount)"
        case .damage, .playerDamage, .parried, .critical, .bonus: "−\(amount)"
        case .defenseUp: "防御提高 \(amount)%"
        case .status: ""
        }
    }

    var color: Color {
        switch self {
        case .healing:
            Color(red: 0.28, green: 0.95, blue: 0.56)
        case .playerDamage, .damage, .critical, .bonus:
            Color(red: 1.0, green: 0.25, blue: 0.22)
        case .parried: Color(white: 0.75)
        case .status: Color(red: 0.8, green: 0.57, blue: 1)
        case .defenseUp:
            Color(red: 0.74, green: 0.56, blue: 1.0)
        }
    }

    var verticalOffset: CGFloat {
        switch self {
        case .healing: -30
        case .damage, .critical, .bonus: -36
        case .playerDamage, .parried: 26
        case .defenseUp: -56
        case .status: -64
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .healing: 36
        case .damage, .playerDamage, .parried, .bonus: 26
        case .critical: 34
        case .status: 19
        case .defenseUp: 18
        }
    }
}

private struct CombatFloatingNumber: Identifiable {
    let id = UUID()
    /// `nil` anchors the number to the protagonist. Unity-backed hound
    /// attacks intentionally use the SwiftUI overlay for the authoritative
    /// player damage number because the native enemy-turn presentation is
    /// effects-only in those encounters.
    let enemyID: String?
    let amount: Int
    let kind: CombatFloatingNumberKind
    var sourceLabel: String? = nil
    var isFloating = false
    /// Freeze the impact point before a kill removes/replaces the target's formation.
    var normalizedAnchor: CGPoint? = nil
    var lane = 0
}

private struct BattleDefeatSigil: View {
    @State private var isPulsing = false

    var body: some View {
        Image("BattleDefeatEmblem")
            .resizable()
            .scaledToFit()
            .frame(width: 156, height: 156)
            .scaleEffect(isPulsing ? 1.025 : 0.985)
            .shadow(color: Color.red.opacity(isPulsing ? 0.62 : 0.32), radius: isPulsing ? 20 : 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct BattleDefeatOverlay: View {
    let damageBySource: [String: Int]
    let painSalveRemaining: Int
    let maskCracks: Int
    let bountyLossText: String?
    var wallHintText: String? = nil
    let retry: () -> Void
    let exit: () -> Void

    @State private var ritualGlow = false
    @State private var didFinish = false

    private func finish(_ action: () -> Void, source: String) {
        guard !didFinish else { return }
        didFinish = true
        #if DEBUG
        let event = "source=\(source) uptime=\(ProcessInfo.processInfo.systemUptime)"
        NSLog("[MistportDefeat] %@", event)
        if ProcessInfo.processInfo.arguments.contains("--verify-p1-ui") {
            UserDefaults(suiteName: "mistport.p1-ui-verification")?.set(event, forKey: "debug.lastDefeatAction")
        }
        #endif
        action()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.20),
                    Color(red: 0.10, green: 0.012, blue: 0.025).opacity(0.72),
                    Color.black.opacity(0.72)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            RadialGradient(
                colors: [
                    Color(red: 0.72, green: 0.07, blue: 0.06).opacity(ritualGlow ? 0.24 : 0.13),
                    .clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: ritualGlow ? 300 : 230
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 22) {
                BattleDefeatSigil()
                    .scaleEffect(ritualGlow ? 1.03 : 0.98)

                VStack(spacing: 7) {
                    Text("战斗失败")
                        .font(.system(size: 48, weight: .black, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.88, blue: 0.72),
                                    Color(red: 1.0, green: 0.32, blue: 0.27)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.red.opacity(0.58), radius: 10)
                        .shadow(color: .black.opacity(0.94), radius: 3, y: 3)

                    Text("◇  钟声在此中断  ◇")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(Color(red: 0.92, green: 0.65, blue: 0.34).opacity(0.92))
                        .tracking(2)
                }

                HStack(spacing: 10) {
                    Rectangle().frame(height: 1)
                    Image(systemName: "diamond.fill")
                        .font(.system(size: 6))
                    Rectangle().frame(height: 1)
                }
                .foregroundStyle(
                    LinearGradient(
                        colors: [.clear, Color(red: 0.88, green: 0.48, blue: 0.19), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .padding(.horizontal, 10)

                Text("本次挑战已结束，请选择下一步").font(.caption).foregroundStyle(.white.opacity(0.7))
                Text("已用补给不会返还 · 止痛膏剩余\(painSalveRemaining)份 · 假面裂纹\(maskCracks)/10永久保留")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.orange.opacity(0.92))
                if let bountyLossText {
                    Text(bountyLossText)
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 1, green: 0.76, blue: 0.62))
                        .padding(.horizontal, 12)
                }
                if let wallHintText {
                    Text(wallHintText)
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ChurchGold)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 12)
                }
                BattleDamageSummary(damage: damageBySource)
                HStack(spacing: 12) {
                    defeatActionButton(
                        title: "返回主界面",
                        symbol: "arrowshape.turn.up.left.fill",
                        primary: false,
                        action: { finish(exit, source: "exit-button") }
                    )
                    defeatActionButton(
                        title: "重新挑战",
                        symbol: "arrow.counterclockwise",
                        primary: true,
                        action: { finish(retry, source: "retry-button") }
                    )
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 390)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                ritualGlow = true
            }
        }

    }

    private func defeatActionButton(
        title: String,
        symbol: String,
        primary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .heavy))
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .foregroundStyle(
                primary
                    ? Color(red: 1.0, green: 0.91, blue: 0.79)
                    : Color(red: 0.95, green: 0.82, blue: 0.61)
            )
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                primary
                    ? LinearGradient(
                        colors: [
                            Color(red: 0.67, green: 0.06, blue: 0.07),
                            Color(red: 0.38, green: 0.02, blue: 0.04)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : LinearGradient(
                        colors: [
                            Color(red: 0.14, green: 0.08, blue: 0.13),
                            Color(red: 0.055, green: 0.035, blue: 0.065)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
            )
            .overlay {
                Capsule()
                    .stroke(
                        primary
                            ? Color(red: 1.0, green: 0.61, blue: 0.31).opacity(0.94)
                            : Color(red: 0.73, green: 0.53, blue: 0.27).opacity(0.68),
                        lineWidth: 1.1
                    )
            }
        }
        .buttonStyle(.plain)
        .clipShape(Capsule())
        .shadow(color: primary ? Color.red.opacity(0.34) : .black.opacity(0.35), radius: 7, y: 3)
    }
}

private struct ChapterOneEnemyIntentDisplay: Identifiable {
    let id: String
    let enemyName: String
    let intent: String
    let nextIntent: String?
}

private struct ChapterOneEnemyIntentStrip: View {
    let intents: [ChapterOneEnemyIntentDisplay]
    let bossCountdown: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 9, weight: .black))
                    .accessibilityHidden(true)
                Text("敌方意图")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                Spacer(minLength: 4)
                if let bossCountdown {
                    Text("第十三声倒计时 \(bossCountdown)")
                        .font(.system(size: 8, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.orange)
                } else {
                    Text("已公开")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.46))
                }
            }
            .foregroundStyle(.yellow)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(intents) { intent in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(intent.enemyName)
                                .font(.system(size: 8, weight: .black, design: .rounded))
                                .lineLimit(1)
                            Text("当前 · \(localizedIntent(intent.intent, enemyName: intent.enemyName))")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(1)
                            if let nextIntent = intent.nextIntent {
                                Text("预告 · \(localizedIntent(nextIntent, enemyName: intent.enemyName))")
                                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange.opacity(0.88))
                                    .lineLimit(1)
                            }
                        }
                        .frame(minWidth: 92, alignment: .leading)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.yellow.opacity(0.24), lineWidth: 1)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibilityLabel(for: intent))
                    }
                }
                .padding(.horizontal, 1)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.black.opacity(0.44), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.yellow.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("敌方意图")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let intentText = intents.map(accessibilityLabel(for:)).joined(separator: "；")
        guard let bossCountdown else { return intentText }
        return "\(intentText)；第十三声倒计时 \(bossCountdown)"
    }

    private func accessibilityLabel(for intent: ChapterOneEnemyIntentDisplay) -> String {
        let forecast = intent.nextIntent.map { "，预告\(localizedIntent($0, enemyName: intent.enemyName))" } ?? ""
        return "\(intent.enemyName)，当前意图\(localizedIntent(intent.intent, enemyName: intent.enemyName))\(forecast)"
    }
}

struct ChapterOneEncounterTestView: View {
    @AppStorage(GameSettingsKeys.battleSpeed, store: .standard) private var savedBattleSpeed = 1
    // Rule time starts at zero, matching deterministic replay. Uptime only feeds frame deltas.
    @State private var battleTime: TimeInterval = 0
    /// The haste end last told to Unity (抢拍开幕's hourglass beside the hero, 2026-10-15).
    @State private var sentHeroHasteUntil: TimeInterval = 0
    @State private var lastBattleWallTime: TimeInterval?
    @State private var battleTickRemainder: TimeInterval = 0
    @State private var isFastForwardingBattle = false
    @State private var didSkipBattle = false
    @State private var combatDraggedSkill: FoolSkillID?
    @State private var combatDragOffset: CGSize = .zero
    @State private var lightAttackClock: MPCLightAttackClock?
    @State private var playerHitFlashUntil: TimeInterval = 0
    #if DEBUG
    @State private var tempoReviewStartedAt: TimeInterval?
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceCombatMotion
    private var battleSpeed: Int { savedBattleSpeed == 2 ? 2 : 1 }
    @AppStorage(GameSettingsKeys.hapticsEnabled, store: .standard) private var hapticsEnabled = true
    @AppStorage(GameSettingsKeys.combatSoundVolume, store: .standard) private var combatSoundVolume = 0.6
    /// Volume sent to Unity. Review launches (-MistportCityMute YES, DEBUG) keep
    /// battle sounds silent as well as the harbour.
    private var unityCombatVolume: Double {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "MistportCityMute") { return 0 }
        #endif
        return combatSoundVolume
    }
    private static let q1PreludeAttackCount = 3

    @AppStorage("mistport.skipCombatAnimations") private var skipsCombatAnimations = false
    @AppStorage("mistport.combatItemsOnLeft") private var combatItemsOnLeft = false
    private let initialSession: MPCChapterOneEncounterSession
    private let campaign: MPCChapterOneCampaignState
    @State private var maskCrackCount: Int
    @State private var session: MPCChapterOneEncounterSession
    @State private var visualScene: DungeonScene
    @ObservedObject private var unityBattleRuntime = UnityBattleRuntime.shared
    @State private var selectedTargetID: String?
    @State private var actionMessage = "选择目标并使用技能"
    @State private var transientEnemyHealth: [String: Int] = [:]
    @State private var lastChurchPoisonPresentation: Bool?
    @State private var lastChurchEmpoweredPresentation: String?
    @State private var lastChurchBindingsPresentation: String?
    @State private var lastChurchEscortedPresentation: String?
    @State private var combatFloatingNumbers: [CombatFloatingNumber] = []
    @State private var healthOverlaySize: CGSize = .zero
    @State private var musicOwnerID = UUID()
    @State private var isResolvingEnemyTurn = false
    @State private var showsTutorial: Bool
    @State private var isFirstCardTutorial = false
    @State private var selectedCardID: FoolSkillID?
    @State private var queuedActions: [QueuedCombatAction] = []
    @State private var requestedUltimate = false
    @State private var requestedEmeraldMask = false
    @State private var q3HuntStart: TimeInterval?
    @State private var q4CycleStart: TimeInterval?
    private var isQ3Hound: Bool { session.encounter.id == "chapter01_q03_encounter" }
    private var isQ4Hound: Bool { session.encounter.id == "chapter01_q04_encounter" }
    @State private var chosenLoopSkills: [FoolSkillID]? = []
    @State private var skillScheduler = ContinuousSkillScheduler()
    @State private var playerCastReadyAt: TimeInterval = 0
    @State private var pendingPlayerImpact: (skill: FoolSkillID?, target: String, time: TimeInterval, sealed: Bool)?
    @State private var signatureCallout: SignatureCalloutCue?
    /// The session whose Q30 离场祝福 have been shown (once per attempt).
    @State private var announcedFarewellSessionID: UUID?
    /// Q30 天使出场 (2026-10-11, user: 天使出场…): Unity's `angel-intro` before the clock starts,
    /// every attempt, skippable. Pauses combat like the Q1/Q5 interventions.
    @State private var showsQ30AngelIntro = false
    /// When `angel-intro` went to Unity (the line table's zero); nil while waiting for the stage.
    @State private var q30AngelIntroStartedAt: Date?
    /// The attempt whose intro has begun (each start builds a new session).
    @State private var q30AngelIntroSessionID: UUID?
    /// Allies whose rig was last sent `down` (final-boss party; `syncPartyRigPresentation`).
    @State private var lastPartyFallenPresentation: Set<String> = []
    @State private var presentedRelicEventIDs: Set<String> = []
    @State private var pendingGhostReveals: [String: TimeInterval] = [:]
    @State private var revealedGhostIDs: Set<String> = []
    @State private var enemyReadyAt: [String: TimeInterval] = [:]
    @State private var pendingEnemyImpacts: [String: TimeInterval] = [:]
    @State private var encoreBell = MPCEncoreBellState()
    @State private var encoreClock: TimeInterval = 0
    @State private var encoreRingToken = 0
    @State private var encoreRingAt: TimeInterval?

    private let encorePrototypeEnabled: Bool
    private var usesEncoreBellPrototype: Bool {
        session.encounter.id == "chapter01_q05_encounter"
            && encorePrototypeEnabled
    }
    private var usesEncoreRevenant: Bool { session.isEncoreEncounter || usesEncoreBellPrototype || session.chapterMissionNumber == 19 }
    private var usesManualEmeraldMask: Bool { (maskIsTeachingLoan || (session.loadout.selectedActiveRelicID ?? MPCChapterOneCatalog.ownerlessMaskRelicID) == MPCChapterOneCatalog.ownerlessMaskRelicID) && ownsManualMask && !usesEncoreBellPrototype && ((MPCChapterOneCatalog.mission(forEncounterID: session.encounter.id)?.number ?? 0) >= 3 || session.encounter.id.hasPrefix("church_")) }
    private var usesBellTiming: Bool { !session.encounter.id.hasPrefix("church_") && session.encounter.id != "chapter01_q08_encounter" && (usesEncoreRevenant || session.loadout.relicIDs.contains("relic_encore_bell") || session.enemies.contains(where: { $0.intentPattern.contains("charge") })) }
    private var showsEncoreBell: Bool {
        guard MPCChapterOneCatalog.relicsEnabled else { return false }
        return usesEncoreBellPrototype || session.loadout.relicIDs.contains("relic_encore_bell")
            || campaign.ownedRelicIDs.contains("relic_encore_bell")
    }
    @State private var continuousVictoryReported = false
    @State private var victoryPresentationDeadline: TimeInterval?
    @State private var preludeRevealAt: TimeInterval?

    @State private var basicCooldownStarted: TimeInterval?

    @State private var queuedTargetIDs: [FoolSkillID: String] = [:]
    @State private var queuedBasicTargetIDs: [String: String] = [:]
    @State private var pendingTargetSkillID: FoolSkillID?
    @State private var pendingBasicTargetCategory: MPCPlayerActionCategory?
    @State private var inspectedSkill: MPCSkillContent?
    @State private var q1PreludeRoundsCompleted = 0
    @State private var q1CardsGranted: Bool
    @State private var showsQ1GoddessIntervention = false
    @State private var showsQ5MaraIntervention = false
    // Keep the Q5 finishing beat visible long enough for the player to see
    // the second hit actually defeat the hound before the mission closes.
    @State private var isHoldingQ5VictoryPresentation = false
    // Closing Mara's intervention and switching the parent back to pre-battle
    // setup happen in two SwiftUI update passes. Keep automation locally
    // blocked across that gap so neither side can steal a turn before the
    // player explicitly presses Start Battle again.
    @State private var waitsForPostInterventionStart = false
    @State private var isDefeatOverlayVisible = false
    @State private var hasStartedHeldQ5Preview = false
    @State private var hasStartedOpeningBattle = false
    private let playerSequence: Int
    private let locksCardSelectionForPreview: Bool
    private let showsCardComparisonPreview: Bool
    private let automatesSkillSequence: Bool
    private let holdsQ5Preview: Bool
    /// The mission bridge owns the pre-battle setup button. The standalone
    /// preview keeps its own opening button so the direct Q1 test remains
    /// playable without the bridge.
    private let showsStandaloneOpeningBattleButton: Bool
    private let locksExitForTutorial: Bool
    private let requiresExplicitBattleStartAfterIntervention: Bool
    private let playerPlacement: ChapterOnePlayerPlacement
    let battleIsActive: Bool
    let tutorialCue: ChapterOneTutorialCue?
    let onVictory: (MPCChapterOneEncounterSession) -> Void
    let onExit: () -> Void
    let onDefeat: () -> Void
    let bountyLossText: String?
    let wallHintText: String?
    let onRetrySetup: () -> Void
    let onSequenceChanged: ([FoolSkillID]) -> Void
    let onSelectActiveRelic: (String) -> Void
    let onSelectPassiveRelic: (String) -> Void
    let onUseManualMask: () -> Bool
    let onConsumeSupply: (String) -> Bool
    let onToggleEncoreBell: () -> Void
    let onTutorialDismiss: () -> Void
    let onFirstBattleInterventionCompleted: () -> Void

    // The lower shelf is a dense inventory, not a second hero display. Keep
    // cards at 60% of the previous 58×85 shelf size so the relic row can fit
    // above it without making the battlefield feel crowded.
    private let combatDockCardWidth: CGFloat = 48
    private let combatDockCardHeight: CGFloat = 70

    init(
        initialSession: MPCChapterOneEncounterSession,
        campaign: MPCChapterOneCampaignState,
        playerSequence: Int = 9,
        playerPlacement: ChapterOnePlayerPlacement = .standard,
        battleIsActive: Bool = true,
        automatesSkillSequence: Bool = true,
        encorePrototypeEnabled: Bool = false,
        tutorialCue: ChapterOneTutorialCue? = nil,
        requiresExplicitBattleStartAfterIntervention: Bool = true,
        showsStandaloneOpeningBattleButton: Bool = true,
        onVictory: @escaping (MPCChapterOneEncounterSession) -> Void,
        onExit: @escaping () -> Void,
        onDefeat: @escaping () -> Void = {},
        bountyLossText: String? = nil,
        wallHintText: String? = nil,
        onRetrySetup: @escaping () -> Void = {},
        onSequenceChanged: @escaping ([FoolSkillID]) -> Void = { _ in },
        onSelectActiveRelic: @escaping (String) -> Void = { _ in },
        onSelectPassiveRelic: @escaping (String) -> Void = { _ in },
        onUseManualMask: @escaping () -> Bool = { true },
        onConsumeSupply: @escaping (String) -> Bool = { _ in true },
        onToggleEncoreBell: @escaping () -> Void = {},
        onTutorialDismiss: @escaping () -> Void = {},
        onFirstBattleInterventionCompleted: @escaping () -> Void = {}
    ) {
        let arguments = ProcessInfo.processInfo.arguments
        let locksCardSelectionForPreview = arguments.contains("--preview-card-selection")
        let previewsUnselectedCard = arguments.contains("--preview-card-unselected")
        let showsCardComparisonPreview = arguments.contains("--preview-card-comparison")
        let holdsQ5Preview = arguments.contains("--preview-chapter-one-q5-hold")
        // Q1 must finish Mara's explanation before the player can configure
        // the opening sequence. Do not postpone the tutorial behind combat.
        let delaysFirstBattleTutorial = false
        let openingCardID = MPCChapterOneCatalog.visibleSkills.first {
            initialSession.loadout.battleSkillIDs.contains($0.id)
                && initialSession.canUseFoolSkill($0.id)
        }?.id
        self.encorePrototypeEnabled = encorePrototypeEnabled || arguments.contains("--preview-chapter-one-encore-bell")
        var initialSession = initialSession
        initialSession.adoptTempo(CombatTempoReviewConfiguration.profile(initialSession.encounter.id))
        _lightAttackClock = State(initialValue: initialSession.tempo.map(MPCLightAttackClock.init(tempo:)))
        if self.encorePrototypeEnabled {
            initialSession.prepareEncoreBellPrototype()
            initialSession.setContinuousSkillSequence([])
        }
        self.initialSession = initialSession
        self.campaign = campaign
        self.playerSequence = playerSequence
        self.playerPlacement = playerPlacement.normalized
        self.battleIsActive = holdsQ5Preview ? false : battleIsActive
        self.automatesSkillSequence = automatesSkillSequence && !holdsQ5Preview
        self.holdsQ5Preview = holdsQ5Preview
        self.showsStandaloneOpeningBattleButton = showsStandaloneOpeningBattleButton
        self.requiresExplicitBattleStartAfterIntervention = requiresExplicitBattleStartAfterIntervention
        #if DEBUG
        // Test builds allow leaving every tutorial encounter immediately.
        self.locksExitForTutorial = false
        #else
        self.locksExitForTutorial = [
            "chapter01_q01_encounter",
            "chapter01_q02_encounter",
            "chapter01_q03_encounter",
            "chapter01_q04_encounter",
            "chapter01_q05_encounter"
        ].contains(initialSession.encounter.id)
        #endif
        _session = State(initialValue: initialSession)
        // A recreated view can arrive already in the battle phase; onChange
        // will not fire then. Seed only that active view from this attempt's
        // configured sequence, while setup still starts deliberately empty.
        _chosenLoopSkills = State(initialValue: battleIsActive && !holdsQ5Preview
            ? initialSession.loadout.normalSkillIDs : [])
        let presentationScene = makeChapterOnePresentationScene(
            for: initialSession,
            playerSequence: playerSequence,
            playerPlacement: playerPlacement
        )
        if MPCChapterOneBattleIdentity.supportsUnity(encounterID: initialSession.encounter.id) {
            presentationScene.enableEffectsOnlyOverlay()
        }
        _visualScene = State(initialValue: presentationScene)
        _selectedTargetID = State(initialValue: Self.defaultTargetID(in: initialSession.enemies))
        _showsTutorial = State(initialValue: tutorialCue != nil && !delaysFirstBattleTutorial && !locksCardSelectionForPreview && !previewsUnselectedCard && !showsCardComparisonPreview)
        _actionMessage = State(initialValue: "选择目标并使用技能")
        _selectedCardID = State(initialValue: (locksCardSelectionForPreview || showsCardComparisonPreview) ? openingCardID : nil)
        // Q1 starts with an empty sequence, but its first three fallback basic
        // attacks are still the authored prelude that summons Mara.
        _q1CardsGranted = State(
            initialValue: initialSession.encounter.id != "chapter01_q01_encounter"
        )
        self.locksCardSelectionForPreview = locksCardSelectionForPreview || showsCardComparisonPreview
        self.showsCardComparisonPreview = showsCardComparisonPreview
        self.tutorialCue = tutorialCue
        self.onVictory = onVictory
        self.onDefeat = onDefeat
        self.bountyLossText = bountyLossText
        self.wallHintText = wallHintText
        self.onExit = onExit
        self.onRetrySetup = onRetrySetup
        self.onSelectActiveRelic = onSelectActiveRelic
        self.onSelectPassiveRelic = onSelectPassiveRelic
        self.onUseManualMask = onUseManualMask
        self._maskCrackCount = State(initialValue: campaign.masqueradeCrackCount)
        self.onConsumeSupply = onConsumeSupply
        self.onToggleEncoreBell = onToggleEncoreBell
        self.onSequenceChanged = onSequenceChanged
        self.onTutorialDismiss = onTutorialDismiss
        self.onFirstBattleInterventionCompleted = onFirstBattleInterventionCompleted
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Opaque fallback while the full-height battle surface attaches.
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    battleHeader
                        .padding(.horizontal, 14)
                        // Give the compact header symmetric breathing room.
                        // The previous top-only inset left every control
                        // visually touching the lower edge of the black bar.
                        .frame(minHeight: 34, alignment: .center)
                        .padding(.vertical, 8)
                        // The battle stage can contain a sky or moon, but the
                        // navigation band must stay a quiet, opaque UI surface.
                        .background {
                            Color.black
                                .ignoresSafeArea(edges: .top)
                        }
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 1)
                        }
                        .tutorialWashed(isFirstCardTutorial)
                        // Keep the player inside the first-card tutorial until
                        // the required action has been completed.
                        .allowsHitTesting(true)

                    ZStack(alignment: .bottom) {
                        battlefield
                            .offset(x: reduceCombatMotion || battleTime >= playerHitFlashUntil ? 0 : sin(battleTime * 135) * 2.2)
                            .overlay {
                                if battleTime < playerHitFlashUntil {
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.red.opacity(0.38), lineWidth: 12)
                                        .blur(radius: 8).allowsHitTesting(false)
                                }
                            }
                            // Render the arena behind the floating card dock,
                            // all the way to the bottom edge, without a blank band.
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            // Keep the SpriteView viewport stable when the
                            // dock grows from the prelude controls into the
                            // full card hand. Resizing an aspect-fill scene
                            // was cropping the arena and made actors appear to
                            // jump to a much larger scale.
                            .allowsHitTesting(true)
                            .zIndex(0)

                        if usesBellTiming, let rangAt = encoreRingAt,
                           combatIsActive, encoreClock - rangAt < 2.4 {
                            Image("ItemEncoreBellCutout")
                                .resizable().scaledToFit().frame(width: 160, height: 220)
                                .opacity(0.42 * min(1, max(0, (encoreClock - rangAt) / 0.16))
                                    * min(1, max(0, (2.4 - (encoreClock - rangAt)) / 0.6)))
                                .blendMode(.screen)
                                .rotationEffect(.degrees(sin((encoreClock - rangAt) * 16) * 16), anchor: .top)
                                .shadow(color: .orange.opacity(0.3), radius: 18)
                                .position(x: geometry.size.width * 0.75, y: geometry.size.height * 0.37)
                                .allowsHitTesting(false).zIndex(40)
                        }
                        VStack(alignment: .trailing, spacing: 4) {
                            if teachesMaskTiming {
                                // Playtest 2026-10-04: new players died in Q3
                                // without connecting the hound's glow to the
                                // mask. While the two teaching hunts have it
                                // ready, say so right above the dock.
                                MaskTimingCue()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 84)
                                .allowsHitTesting(false)
                            }
                            if session.playerIsDown && combatIsActive {
                                // Final-boss party (2026-10-11): the fallen hero's cards stop; say why
                                // in the same slot above the dock while the allies fight on.
                                partyHeroDownCue
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 84)
                                .allowsHitTesting(false)
                            }
                            if combatIsActive || (!showsTutorial) || (showsStandaloneOpeningBattleButton && (holdsQ5Preview || waitsForPostInterventionStart || requiresOpeningBattleStart)) {
                                combatDock
                            }
                        }
                            .frame(width: max(0, geometry.size.width - 24))
                            .padding(.horizontal, 12)
                            .padding(.bottom, 4)
                            // The Q30 intro is a cutscene: the dock steps aside for its dialogue.
                            .opacity(showsQ30AngelIntro ? 0 : 1)
                            .allowsHitTesting(!showsQ30AngelIntro)
                            .zIndex(50)

                        if combatIsActive && (session.canRequestCounter || session.counter.queued || session.isCounterActive) {
                            GeometryReader { stage in
                                counterControl
                                    .position(x: stage.size.width * 0.5, y: stage.size.height * 0.56)
                            }
                            .zIndex(52)
                        }
                        if combatSideRailItemCount > 0 && !showsQ30AngelIntro && !isFirstCardTutorial {
                            GeometryReader { stage in
                                paperRelicDockSection
                                    .frame(width: 64, height: min(CGFloat(combatSideRailItemCount) * 83 + 44, max(170, stage.size.height - 330)))
                                    .position(x: combatItemsOnLeft ? 40 : stage.size.width - 40,
                                              y: stage.size.height * 0.42)
                            }
                            .zIndex(51)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if (holdsQ5Preview || (showsStandaloneOpeningBattleButton && requiresOpeningBattleStart)) && !combatIsActive {
                    Button {
                        if holdsQ5Preview {
                            startHeldQ5Preview()
                        } else {
                            startOpeningBattle()
                        }
                    } label: {
                        Text(openingSequenceIsComplete ? "开始战斗" : "请选择\(openingRequiredCardCount)张技能")
                            .font(.system(size: 30, weight: .black, design: .serif))
                            .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                            .modifier(BattleStartButtonChrome())
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chapter-one-preview-start-battle")
                    .disabled(!openingSequenceIsComplete)
                    .opacity(openingSequenceIsComplete ? 1 : 0.65)
                    .offset(y: -52)
                    .zIndex(100)
                }

                if let callout = signatureCallout {
                    SignatureMoveCallout(kicker: callout.kicker, title: callout.title, detail: callout.detail,
                                         hold: callout.hold, reduceMotion: reduceCombatMotion)
                        .id(callout.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 104)
                        .allowsHitTesting(false)
                        .accessibilityIdentifier("chapter-one-signature-callout")
                        .zIndex(95)
                }

                if showsQ30AngelIntro {
                    q30AngelIntroOverlay(bottomInset: geometry.safeAreaInsets.bottom)
                        .transition(.opacity)
                        .zIndex(105)
                }

                if showsQ1GoddessIntervention {
                    ChapterOneTutorialOverlay(cue: .firstBattle) {
                        waitsForPostInterventionStart = requiresExplicitBattleStartAfterIntervention
                        hasStartedOpeningBattle = false
                        UnityBattleRuntime.shared.send(action: "combat-stop")
                        withAnimation(.easeOut(duration: 0.2)) {
                            showsQ1GoddessIntervention = false
                        }
                        var value = session
                        if value.encounter.id == "chapter01_q01_encounter" {
                            _ = value.grantTrialSkill(.sidestepStrike)
                            session = value
                        }
                        q1CardsGranted = true
                        // Keep the tutorial flag for the granted-card
                        // presentation. The standalone preview queues this
                        // card from its explanatory button; the real mission
                        // bridge releases the automatic scan after the
                        // explicit Start Battle tap.
                        isFirstCardTutorial = true
                        actionMessage = "装备「错步穿行」后开始战斗"
                        onFirstBattleInterventionCompleted()

                    }
                } else if showsQ5MaraIntervention {
                    ChapterOneTutorialOverlay(cue: .q5PaperDoubleIntervention) {
                        var value = session
                        value.resolveQ5MaraIntervention()
                        session = value
                        showsQ5MaraIntervention = false
                        // The first lethal hit sends the Unity actor through
                        // the defeat presentation, which hides its renderers.
                        // Mara's rewind must restore the real protagonist
                        // before arming the relic; otherwise the next battle
                        // looks as if the protagonist has permanently become
                        // the paper double.
                        if usesUnityBattlefield {
                            UnityBattleRuntime.shared.send(action: "player-reset")
                        }
                        syncVisualHealth()
                        actionMessage = "遗落物「纸人代身」已就位 · 下一次致命冥火将由纸人承受"
                    }
                } else if showsTutorial, let tutorialCue {
                    ChapterOneTutorialOverlay(cue: tutorialCue) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showsTutorial = false
                        }
                        onTutorialDismiss()
                    }
                }

                if isDefeatOverlayVisible {
                    BattleDefeatOverlay(
                        damageBySource: session.damageBySource,
                        painSalveRemaining: campaign.inventory["consumable_pain_salve", default: 0],
                        maskCracks: maskCrackCount,
                        bountyLossText: bountyLossText,
                        wallHintText: wallHintText,
                        retry: restartEncounter,
                        exit: exitBattleSettlingMedal
                    )
                    .zIndex(120)
                }
            }
            .overlay {
                if isFastForwardingBattle && combatIsActive && session.outcome == .inProgress {
                    ZStack {
                        Color(red: 0.055, green: 0.045, blue: 0.085)
                        VStack(spacing: 18) {
                            ProgressView().tint(.yellow)
                            Text("正在结算战斗…").font(.title3.bold())
                        }.padding(28)
                    }
                    .accessibilityIdentifier("combat-fast-settlement")
                }
            }
            .foregroundStyle(.white)
            .ignoresSafeArea(edges: .bottom)
        }
        .sheet(item: $inspectedSkill) { skill in
            ChapterSkillDetailSheet(skill: skill)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        // Expose individual combat controls and dialogue actions to VoiceOver.
        // A named containing element obscures the dynamically inserted tutorial.
        // SwiftUI may preserve this battle view while the selected teaching
        // encounter changes. Key the setup task to the encounter so Q3 always
        // reconfigures Unity from the guard-only model to guard + clock core.
        .task(id: session.encounter.id) {
            synchronizeBattleMusic()
            visualScene.onEnemyTapped = { targetID in
                handleEnemyTap(targetID)
            }
            if usesUnityBattlefield {
                UnityBattleRuntime.shared.send(action: "audio-volume:\(unityCombatVolume)")
                UnityBattleRuntime.shared.send(action: combatIsActive ? "combat-start" : "combat-stop")
                UnityBattleRuntime.shared.configureEncounter(unityBattlePresentation)
            UnityBattleRuntime.shared.send(action: usesEncoreRevenant ? "encore-model-on" : "encore-model-off")
            UnityBattleRuntime.shared.send(action: "early-presence:\(MPCChapterOneCatalog.mission(forEncounterID: session.encounter.id)?.number ?? 0)")
                UnityBattleRuntime.shared.setPlayerPlacement(playerPlacement)
                synchronizeBattlePresentationSettings()
                showPartyRigs()
            }
            syncVisualHealth()
            // The SpriteKit scene may finish spawning its actors one run loop
            // after SwiftUI presents it. Repeat the initial sync so tutorial
            // statuses, including the control seal, are present before the
            // first card is chosen.
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            syncVisualHealth()
            updateQueuedTargetPresentation()
            #if DEBUG
            if usesUnityBattlefield,
               ProcessInfo.processInfo.arguments.contains("--preview-enemy-attack") {
                // Reuse the existing enemy-animation QA launch switch for the
                // live Unity actor as well as the SpriteKit VFX layer. The
                // delay aligns both wind-ups and leaves player automation off.
                try? await Task.sleep(for: .milliseconds(820))
                guard !Task.isCancelled else { return }
                while !Task.isCancelled {
                    UnityBattleRuntime.shared.send(action: "enemy")
                    try? await Task.sleep(for: .milliseconds(4_200))
                }
            }
            #endif
        }
        .task(id: isFastForwardingBattle) {
            if isFastForwardingBattle { await finishSkippedBattle() }
        }
        .task(id: unityBattleRuntime.isReady) {
            guard usesEncoreRevenant, unityBattleRuntime.isReady else { return }
            // Unity retains this request until its battle handles are installed.
            unityBattleRuntime.send(action: "encore-model-on")
        }
        .task(id: "\(combatIsActive)-\(showsTutorial)-\(showsQ1GoddessIntervention)-\(showsQ5MaraIntervention)-\(waitsForPostInterventionStart)-\(showsQ30AngelIntro)") {
            guard automatesSkillSequence, combatIsActive else { return }
            lastBattleWallTime = nil
            while !Task.isCancelled && combatIsActive {
                if !showsTutorial && !showsQ1GoddessIntervention && !showsQ5MaraIntervention && !waitsForPostInterventionStart && !showsQ30AngelIntro {
                    tickContinuousCombat()
                } else {
                    lastBattleWallTime = nil
                    battleTickRemainder = 0
                }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
        // Q30 天使出场: send the cutscene once the stage stands (same test as the combat loop's:
        // Unity up and the boss reporting anchors), so its line table starts with the picture.
        .task(id: "\(showsQ30AngelIntro)-\(unityBattleRuntime.isReady)-\(unityBattleRuntime.enemyHealthAnchorViewports.isEmpty)") {
            guard showsQ30AngelIntro, q30AngelIntroStartedAt == nil, unityBattleRuntime.isReady,
                  !unityBattleRuntime.enemyHealthAnchorViewports.isEmpty else { return }
            unityBattleRuntime.send(action: "party-show")
            unityBattleRuntime.send(action: "angel-intro")
            // The cutscene runs on Unity's scaled clock; ×2 would outrun the lines.
            unityBattleRuntime.send(action: "combat-speed:1")
            q30AngelIntroStartedAt = Date()
        }
        .task(id: q30AngelIntroStartedAt) {
            guard let start = q30AngelIntroStartedAt else { return }
            try? await Task.sleep(for: .seconds(max(0, Self.q30AngelIntroDuration - Date().timeIntervalSince(start))))
            guard !Task.isCancelled, showsQ30AngelIntro, q30AngelIntroStartedAt == start else { return }
            finishQ30AngelIntro(skipped: false)
        }
        .onChange(of: unityBattleRuntime.combatContactToken) { _, _ in
            guard automatesSkillSequence, combatIsActive, !showsTutorial,
                  !showsQ1GoddessIntervention, !showsQ5MaraIntervention, !waitsForPostInterventionStart, !showsQ30AngelIntro else { return }
            tickContinuousCombat()
        }
        .onChange(of: unityBattleRuntime.isReady) { _, isReady in
            // A Unity reload loses the cutscene; replay it from the top once the stage is back.
            if !isReady, showsQ30AngelIntro { q30AngelIntroStartedAt = nil }
            guard isReady, usesUnityBattlefield else { return }
            UnityBattleRuntime.shared.send(action: "audio-volume:\(unityCombatVolume)")
            UnityBattleRuntime.shared.send(action: combatIsActive ? "combat-start" : "combat-stop")
            UnityBattleRuntime.shared.configureEncounter(unityBattlePresentation)
                UnityBattleRuntime.shared.send(action: usesEncoreRevenant ? "encore-model-on" : "encore-model-off")
                UnityBattleRuntime.shared.send(action: "early-presence:\(MPCChapterOneCatalog.mission(forEncounterID: session.encounter.id)?.number ?? 0)")
            UnityBattleRuntime.shared.setPlayerPlacement(playerPlacement)
                synchronizeBattlePresentationSettings()
            showPartyRigs()
            syncVisualHealth()
        }
        .onChange(of: session.chapterDepartedEnemyIDs) { _, _ in
            // Objective completion may retire a positive-HP actor without a hit.
            // In particular the fifth Boss cycle must update its visible body.
            syncVisualHealth()
        }
        .onChange(of: combatIsActive) { _, isActive in
            synchronizeBattleMusic()
            if !isActive {
                pendingPlayerImpact = nil
                pendingEnemyImpacts.removeAll()
                enemyReadyAt.removeAll()
                lightAttackClock?.reset()
                q3HuntStart = nil
                q4CycleStart = nil
                session.clearQ4HoundState()
                unityBattleRuntime.send(action: "q4-hound:clear")
                pendingGhostReveals.removeAll()
                revealedGhostIDs.removeAll()
                playerCastReadyAt = 0
                // Back to setup mid-intro: the cutscene goes with the battle phase.
                if showsQ30AngelIntro {
                    unityBattleRuntime.send(action: "angel-intro-skip")
                    showsQ30AngelIntro = false
                    q30AngelIntroStartedAt = nil
                }
            }
            if usesUnityBattlefield {
                UnityBattleRuntime.shared.send(action: isActive ? "combat-start" : "combat-stop")
                if isActive { synchronizeBattlePresentationSettings() }
            }
        }
        .onChange(of: savedBattleSpeed) { _, _ in synchronizeBattlePresentationSettings() }
        .onChange(of: combatSoundVolume) { _, _ in
            if usesUnityBattlefield { UnityBattleRuntime.shared.send(action: "audio-volume:\(unityCombatVolume)") }
        }
        .onChange(of: session.emeraldPoisonIntensity) { _, intensity in
            unityBattleRuntime.send(action: "emerald-poison:\(intensity)")
        }
        .onDisappear {
            isFastForwardingBattle = false
            unityBattleRuntime.suppressesPresentation = false
            HomeMusicController.shared.setBattleActive(false, encounterID: session.encounter.id, ownerID: musicOwnerID)
            _ = session.finishRelicBattle()
            CombatHaptics.shared.cancel()
            session.clearEmeraldPoison()
            unityBattleRuntime.send(action: "emerald-poison:0")
            clearChurchStatusPresentation()
            if usesBellTiming { unityBattleRuntime.send(action: "encore-clear"); unityBattleRuntime.send(action: "encore-model-off") }
            // Final-boss party (2026-10-11): leaving mid-intro stops the cutscene; the allies go
            // and the boss steps back to its usual place for whatever battle Unity hosts next.
            if showsQ30AngelIntro { unityBattleRuntime.send(action: "angel-intro-skip") }
            if usesUnityBattlefield && session.isPartyBossEncounter { unityBattleRuntime.send(action: "party-clear") }
            if usesUnityBattlefield { UnityBattleRuntime.shared.send(action: "combat-stop") }
        }
        .onChange(of: battleIsActive) { _, isActive in
            CombatHaptics.shared.cancel()
            if isActive {
                // The mission bridge creates a fresh session when the player
                // taps "开始战斗". The child view keeps its own live combat
                // state, so adopt that configured snapshot before automation
                // can enqueue the first action. Without this handoff, the
                // pre-intervention session (including a broken control seal)
                // remained visible under the setup overlay.
                // A fresh attempt can be value-equal to the initial snapshot.
                // Always transfer the selected sequence when combat begins.
                adoptConfiguredSession(initialSession)
                return
            }

            guard waitsForPostInterventionStart else { return }
            // The setup screen is now authoritative. Clear anything that may
            // have been queued during the intervention transition and restore
            // the untouched encounter snapshot. The granted-card/tutorial
            // flags remain local, while HP, enemy status and the control seal
            // are reset until the player explicitly starts the next battle.
            adoptConfiguredSession(initialSession)
            chosenLoopSkills = []
            waitsForPostInterventionStart = false
        }
        .onChange(of: initialSession) { _, configuredSession in
            // SwiftUI can deliver the new parent session before or after the
            // battleIsActive transition. Keep a second guarded handoff so the
            // configured loadout is never replaced by stale child @State.
            guard battleIsActive, configuredSession != session else { return }
            adoptConfiguredSession(configuredSession)
        }
        .onChange(of: session.outcome) { _, outcome in

            // A fresh attempt may arrive after the active flag. Reconcile both
            // terminal and in-progress outcomes, not just stop on the old defeat.
            synchronizeBattleMusic()
            if outcome == .defeat { CombatHaptics.shared.emit(.defeat); onDefeat() }
            if outcome != .inProgress && usesEncoreRevenant {
                unityBattleRuntime.send(action: "encore-clear")
                requestedEmeraldMask = false
            }
            guard outcome == .defeat else {
                isDefeatOverlayVisible = false
                return
            }
            // Q5's first defeat is an authored Mara beat, not a retry screen.
            // Let the hound's lethal animation finish, then the commit path
            // presents Mara's rewind overlay and calls the runtime reset.
            if session.encounter.id == "chapter01_q05_encounter",
               session.paperDoubleTutorialPhase == .awaitingMara {
                isDefeatOverlayVisible = false
                if usesUnityBattlefield {
                    UnityBattleRuntime.shared.send(action: "player-defeated")
                } else {
                    visualScene.presentChapterOnePlayerDefeat()
                }
                return
            }
            if didSkipBattle {
                isDefeatOverlayVisible = true
                return
            }
            // Let the player shatter finish before the defeat surface claims
            // the whole screen; otherwise the new visual reads like a cut.
            isDefeatOverlayVisible = false
            if usesUnityBattlefield {
                UnityBattleRuntime.shared.send(action: "player-defeated")
            } else {
                visualScene.presentChapterOnePlayerDefeat()
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(720))
                guard !Task.isCancelled, session.outcome == .defeat else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    isDefeatOverlayVisible = true
                }
            }
        }
    }

    private func synchronizeBattleMusic() {
        HomeMusicController.shared.setBattleActive(combatIsActive && session.outcome == .inProgress,
            encounterID: session.encounter.id, ownerID: musicOwnerID)
    }

    private var combatIsActive: Bool {
        // The mission bridge owns the authoritative entrance/setup/battle
        // phase. Its child view can survive the transition back to setup, so
        // local preview flags must never keep combat alive after the parent
        // has withdrawn `battleIsActive`. Those flags are only valid for the
        // standalone command-line previews that render their own start button.
        // `waitsForPostInterventionStart` is an additional local interlock:
        // SwiftUI can deliver the parent's `.setup` phase one render pass
        // after Mara's dismissal. During that pass the old combat snapshot is
        // still present, but no action may be committed until the new setup
        // screen's Start Battle button is tapped.
        (battleIsActive && !waitsForPostInterventionStart)
            || (showsStandaloneOpeningBattleButton && hasStartedOpeningBattle && !waitsForPostInterventionStart)
            || (holdsQ5Preview && hasStartedHeldQ5Preview)
    }

    private var pausesAutomaticCombatForFirstCardTutorial: Bool {
        // The standalone command-line Q1 preview explicitly teaches the
        // player to tap the first card, and its intervention callback queues
        // that card for them. The real mission bridge instead returns to the
        // setup screen: once the player taps "开始战斗", the normal automatic
        // scan must be allowed to execute the first granted card immediately.
        false
    }

    private var requiresOpeningBattleStart: Bool {
        !hasStartedOpeningBattle
    }

    private var counterControl: some View {
        VStack(spacing: 3) {
            if session.canRequestCounter {
                Button {
                    if session.requestCounter(at: battleTime) { actionMessage = "反击准备 · 当前动作结束后重启编排" }
                } label: {
                    VStack(spacing: 2) {
                        Text("反击").font(.system(size: 22, weight: .black))
                        Text("刷新普通牌 · \(max(0, (session.counter.availableUntil ?? battleTime) - battleTime), specifier: "%.1f")秒")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color(red: 1, green: 0.90, blue: 0.58))
                    .frame(width: 140, height: 52)
                    .background(Color(red: 0.10, green: 0.08, blue: 0.14), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow.opacity(0.85), lineWidth: 1.5))
                }
                .buttonStyle(.plain).accessibilityIdentifier("chapter-one-counter")
                .accessibilityHint("消耗本次反击机会，刷新普通牌并从第一张重新施放；不刷新遗落物和大招")
            } else {
                Text(session.counter.queued ? "反击准备中" : "反击连招")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.yellow)
                    .padding(8).background(.black.opacity(0.65), in: Capsule())
                    .allowsHitTesting(false)
            }
        }
    }

    private var openingRequiredCardCount: Int {
        min(campaign.loadoutSlotCapacity, ownedBattleSkills.filter { !$0.isUltimate }.count)
    }
    private var openingSequenceIsComplete: Bool {
        (chosenLoopSkills ?? visibleBattleSkills.map(\.id)).count == openingRequiredCardCount
    }

    private func startOpeningBattle() {
        guard openingSequenceIsComplete else { return }
        if usesUnityBattlefield { UnityBattleRuntime.shared.send(action: "combat-start") }
        withAnimation(.easeOut(duration: 0.20)) {
            waitsForPostInterventionStart = false
            hasStartedOpeningBattle = true
        }
        actionMessage = "战斗开始 · 先完成三次前置攻击"
        syncVisualHealth()
        beginQ30AngelIntroIfNeeded(session)
    }

    private func startHeldQ5Preview() {
        guard openingSequenceIsComplete else { return }
        withAnimation(.easeOut(duration: 0.20)) {
            hasStartedHeldQ5Preview = true
        }
        actionMessage = "战斗开始 · 可检查两张技能牌的顺序"
        syncVisualHealth()
    }

    private var isQ1PreludeActive: Bool {
        session.encounter.id == "chapter01_q01_encounter" && !q1CardsGranted
    }

    private var queuedSkillIDs: [FoolSkillID] {
        queuedActions.compactMap { action in
            guard case let .skill(skill) = action else { return nil }
            return skill
        }
    }

    private var firstTutorialCardID: FoolSkillID? {
        if session.loadout.battleSkillIDs.contains(.sidestepStrike),
           session.canUseFoolSkill(.sidestepStrike) {
            return .sidestepStrike
        }
        return MPCChapterOneCatalog.visibleSkills
            .first {
                session.loadout.battleSkillIDs.contains($0.id)
                    && session.canUseFoolSkill($0.id)
            }?
            .id
    }

    private var visibleBattleSkills: [MPCSkillContent] {
        // The ordinary sequence contains normal cards only. Including
        // `battleSkillIDs` also appended the ultimate and made Mara's
        // one-card grant appear as two cards in Q1.
        guard q1CardsGranted || session.encounter.id != "chapter01_q01_encounter" else {
            return []
        }
        let equipped = session.loadout.normalSkillIDs.filter { $0 != .maskedWhisper }.compactMap { equippedID in
            MPCChapterOneCatalog.visibleSkills.first { $0.id == equippedID }
        }.filter { $0.id != .paperDouble }
        if session.encounter.id == "chapter01_q01_encounter" {
            return equipped.filter { $0.id == .sidestepStrike }
        }
        return equipped
    }

    /// The lower shelf is the player's persistent collection, not the combat
    /// sequence. It remains visible during combat but never drives execution.
    private var ownedBattleSkills: [MPCSkillContent] {
        // Tutorial availability is determined by the encounter, not by a
        // previous test battle or the transient first-cast teaching flag.
        if session.encounter.id == "chapter01_q01_encounter" {
            return q1CardsGranted ? MPCChapterOneCatalog.visibleSkills.filter { $0.id == .sidestepStrike } : []
        }
        let permittedSkillIDs = campaign.unlockedSkillIDs
        let unlocked = MPCChapterOneCatalog.visibleSkills.filter {
            $0.id != .paperDouble && permittedSkillIDs.contains($0.id)
                && (!$0.isUltimate || session.loadout.isUltimateUnlocked)
        }

        return unlocked
    }

    private var actionSlotLimit: Int {
        if isHoundLesson { return 1 }
        // Sequence never caps the number of actions in a round. Every
        // ordinary card currently equipped and unlocked executes once in the
        // saved order. Q1's one-card tutorial is reflected by
        // `visibleBattleSkills` itself.
        return max(1, visibleBattleSkills.count)
    }

    private var isHoundLesson: Bool {
        session.encounter.id == "chapter01_q04_encounter"
            || session.encounter.id == "chapter01_q05_encounter"
    }

    /// Finish the opening sequence before revisiting ready skills. Subsequent
    /// casts use the earliest real-time cooldown deadline, with slot-order ties.
    /// One main-actor clock owns all rule mutations. Each actor has its own
    /// cast/impact deadlines; no suspended task can overwrite a newer session.
    private var canSkipBattle: Bool {
        combatIsActive && session.outcome == .inProgress && !isFastForwardingBattle
            && !showsTutorial && !showsQ1GoddessIntervention && !showsQ5MaraIntervention
            && !waitsForPostInterventionStart && !showsQ30AngelIntro
            && !isQ1PreludeActive && !isFirstCardTutorial
    }

    private func beginSkippingBattle() {
        guard canSkipBattle else { return }
        didSkipBattle = true
        // Stop presentation only. Every existing pending impact, cooldown, shield,
        // poison timer, wave and random state remains in the current session.
        unityBattleRuntime.send(action: "combat-stop")
        CombatHaptics.shared.cancel()
        isFastForwardingBattle = true
    }

    @MainActor
    private func finishSkippedBattle() async {
        unityBattleRuntime.suppressesPresentation = true
        defer {
            unityBattleRuntime.suppressesPresentation = false
            isFastForwardingBattle = false
            lastBattleWallTime = nil
            battleTickRemainder = 0
        }
        // Same 50 ms step as watched combat, batched without wall-clock waiting.
        // Yield between batches so the settlement indicator and cancellation work.
        var steps = 0
        while !Task.isCancelled && combatIsActive && session.outcome == .inProgress {
            for _ in 0..<200 {
                guard session.outcome == .inProgress && !showsQ1GoddessIntervention
                    && !showsQ5MaraIntervention && !waitsForPostInterventionStart else { break }
                battleTime += 0.05
                advanceContinuousCombat(at: battleTime)
                steps += 1
            }
            if showsQ1GoddessIntervention || showsQ5MaraIntervention || waitsForPostInterventionStart { break }
            if steps >= 72_000 { break } // Never fabricate a result for a non-terminating encounter.
            await Task.yield()
        }
        guard !Task.isCancelled else { return }
        if session.outcome == .victory {
            if !continuousVictoryReported {
                continuousVictoryReported = true
                onVictory(session)
            }
        } else if session.outcome == .defeat {
            isDefeatOverlayVisible = !(session.encounter.id == "chapter01_q05_encounter"
                && session.paperDoubleTutorialPhase == .awaitingMara)
        } else {
            // An authored intervention must still be read; resume the same state.
            didSkipBattle = false
            isFastForwardingBattle = false
            unityBattleRuntime.suppressesPresentation = false
            unityBattleRuntime.configureEncounter(unityBattlePresentation)
            unityBattleRuntime.setPlayerPlacement(playerPlacement)
            replaceVisualScene(for: session)
            unityBattleRuntime.send(action: "combat-start")
            if steps >= 72_000 { actionMessage = "战斗暂未分出胜负，已返回战场" }
        }
    }

    private func tickContinuousCombat() {
        guard !isFastForwardingBattle else { return }
        let wall = ProcessInfo.processInfo.systemUptime
        defer { lastBattleWallTime = wall }
        guard let previous = lastBattleWallTime,
              !usesUnityBattlefield || unityBattleRuntime.isReady else { return }
        // Wall time selects how many fixed rule ticks run. No rule duration is
        // divided by two, and background/paused time never becomes a catch-up hit.
        battleTickRemainder += min(0.1, max(0, wall - previous)) * Double(battleSpeed)
        while battleTickRemainder + 0.000001 >= 0.05 {
            battleTickRemainder -= 0.05
            battleTime += 0.05
            advanceContinuousCombat(at: battleTime)
        }
    }

    private func advanceContinuousCombat(at now: TimeInterval) {
        let damageFormationBeforeClock = session.enemies
        let waveBeforeClock = session.waveIndex
        let relicTarget = selectedTargetID.flatMap { id in session.enemies.first { $0.id == id && $0.isAlive }?.id }
            ?? session.enemies.first(where: \.isAlive)?.id
        session.updateRelicTarget(relicTarget, at: now)
        presentNewRelicEvents()
        // Q24 replaces its formation when the children arrive. Let existing
        // visual contacts finish before disabling/repositioning those handles.
        let canInstallSplitFormation = session.chapterMissionNumber != 24
            || (pendingEnemyImpacts.isEmpty && pendingPlayerImpact == nil)
        let arrivingGhosts = pendingGhostReveals.filter { canInstallSplitFormation && now >= $0.value }.map(\.key)
        if !arrivingGhosts.isEmpty {
            for id in arrivingGhosts {
                pendingGhostReveals.removeValue(forKey: id)
                revealedGhostIDs.insert(id)
            }
            if session.chapterMissionNumber == 24, usesUnityBattlefield {
                // The mother has had its full one-second death fade. Replace
                // its slot once; later child deaths only change visibility.
                unityBattleRuntime.configureEncounter(unityBattlePresentation)
                unityBattleRuntime.setPlayerPlacement(playerPlacement)
            }
            syncVisualHealth()
            updateQueuedTargetPresentation()
        }

        if session.isChurchCombat {
            for enemy in session.enemies {
                guard let nativeID = unityBattleEnemyID(for: enemy) else { continue }
                if !enemy.isAlive {
                    if session.cancelCommittedEnemyImpact(enemyID: enemy.id, at: now) {
                        pendingEnemyImpacts.removeValue(forKey: enemy.id)
                        _ = unityBattleRuntime.consumeCombatContact("enemy:" + nativeID)
                    }
                } else {
                    if session.cancelTargetedSupport(enemyID: enemy.id, at: now) {
                        pendingEnemyImpacts.removeValue(forKey: enemy.id)
                        enemyReadyAt[enemy.id] = now
                    }
                }
            }
        }

        // Reveal can occur while both parents are hidden and there are no
        // live anchors yet; only attacks must wait for a rendered model.
        // Framework attachment precedes Unity's first installed battle frame.
        // Do not commit attacks that have no model yet to produce a contact.
        guard isFastForwardingBattle || session.outcome != .inProgress || !usesUnityBattlefield || (session.isChurchCombat && !session.enemies.contains(where: \.isAlive))
            || (unityBattleRuntime.isReady && !unityBattleRuntime.enemyHealthAnchorViewports.isEmpty) else { return }
        #if DEBUG
        // Labelled review input through the real manual-mask path; no HP or
        // charges are injected. Production battles always require the tap.
        if CombatTempoReviewConfiguration.requested, isQ4Hound,
           let cycle = q4CycleStart, now >= cycle + 7.8, now < cycle + 8.4,
           manualMaskIsReady { requestEmeraldMask() }
        #endif
        #if DEBUG
        if CombatTempoReviewConfiguration.requested,
           ["d01", "b01"].contains(CombatTempoReviewConfiguration.activeSample ?? "") {
            if tempoReviewStartedAt == nil { tempoReviewStartedAt = now }
            // Same labelled input policy as the rule-library verification runner;
            // the actual relic method remains the only owner of its effect.
            if now - (tempoReviewStartedAt ?? now) >= 22,
               session.enemies.first(where: \.isAlive)?.currentIntent != "guard",
               session.activateUsurpedLifeMedal(isOwned: ownsMedal, at: now) { syncVisualHealth() }
        }
        if CombatTempoReviewConfiguration.requested, CombatTempoReviewConfiguration.activeSample == "hero",
           manualMaskIsReady, session.masqueradeCharges == 0 { requestEmeraldMask() }
        #endif
        if session.expireOwnedManualMasquerade(at: now) { unityBattleRuntime.send(action: "masquerade:0") }
        let openingBefore = session.isQ4OpeningActive
        session.advanceQ4Clock(at: now)
        if openingBefore && !session.isQ4OpeningActive { unityBattleRuntime.send(action: "q4-hound:recover") }
        let healthBeforeRelicClock = session.playerHP
        let maximumBeforeRelicClock = session.playerMaxHP
        let intensityBeforeRelicClock = session.emeraldPoisonIntensity
        _ = session.advanceEmeraldPoison(at: now)
        syncChurchStatusPresentation()
        let orderedHits = session.drainOrderedSkillImpacts()
        for impact in orderedHits {
            presentEnemyImpacts(skill: impact.skill, hits: impact.targets.map { ($0.targetID, $0.damage) }, enemies: damageFormationBeforeClock)
            for hit in impact.targets { showCombatFloatingNumber(hit.damage, for: hit.targetID, kind: .damage, enemies: damageFormationBeforeClock) }
            if usesUnityBattlefield, !isFastForwardingBattle {
                let ids = impact.targets.compactMap { hit in damageFormationBeforeClock.first { $0.id == hit.targetID }.flatMap { MPCChapterOneBattleIdentity.battleID(for: $0.id, in: damageFormationBeforeClock) } }
                unityBattleRuntime.send(action: "ordered-impact:\(impact.skill.rawValue):\(ids.joined(separator: "|"))")
            }
        }
        if !orderedHits.isEmpty { syncVisualHealth() }
        // 抢拍开幕's haste (2026-10-15, user: the haste needs a cue lasting its 3.2 or 4.5 seconds):
        // whenever the rules start or extend it, Unity's hourglass beside the hero is given the
        // seconds left; an extension spins it once more.
        if usesUnityBattlefield, !isFastForwardingBattle, session.orderedHasteUntil > now,
           session.orderedHasteUntil > sentHeroHasteUntil + 0.01 {
            sentHeroHasteUntil = session.orderedHasteUntil
            unityBattleRuntime.send(action: "hero-haste:\(String(format: "%.2f", session.orderedHasteUntil - now))")
        }
        if session.waveIndex != waveBeforeClock {
            pendingPlayerImpact = nil
            pendingEnemyImpacts.removeAll()
            enemyReadyAt.removeAll()
            pendingGhostReveals.removeAll()
            revealedGhostIDs.removeAll()
            selectedTargetID = session.enemies.first(where: \.isAlive)?.id
            unityBattleRuntime.configureEncounter(unityBattlePresentation)
            unityBattleRuntime.setPlayerPlacement(playerPlacement)
            replaceVisualScene(for: session)
            syncVisualHealth()
            return
        }
        presentNewRelicEvents()
        // Ticks settled inside an enemy action count too (the clock call alone read 0 for those).
        let poisonDamage = session.takePendingPoisonHealthDamage()
        if poisonDamage > 0 { showPlayerDamageFloatingNumber(poisonDamage) }
        if healthBeforeRelicClock != session.playerHP || maximumBeforeRelicClock != session.playerMaxHP
            || intensityBeforeRelicClock != session.emeraldPoisonIntensity { syncVisualHealth() }
        if usesBellTiming {
            encoreClock = now
            if usesEncoreBellPrototype && session.expireTimedMasquerade(at: now) {
                unityBattleRuntime.send(action: "masquerade:0")
            }
            if let id = encoreBell.pendingEnemyID,
               !session.enemies.contains(where: { $0.id == id && $0.isAlive }) {
                encoreBell.enemyDied(id)
                pendingEnemyImpacts.removeValue(forKey: id)
                unityBattleRuntime.send(action: "encore-clear")
            }
        }
        if session.outcome == .victory {
            if victoryPresentationDeadline == nil {
                // Mixed encounters use the same death animation as the first leech encounter.
                let containsLeech = session.enemies.contains { MPCChapterOneBattleIdentity.family(for: $0.contentID) == "memory-leech" }
                victoryPresentationDeadline = now + (containsLeech ? 4.5 : 1.2)
            }
            if !continuousVictoryReported && now >= max(playerCastReadyAt, victoryPresentationDeadline ?? now) {
                continuousVictoryReported = true
                onVictory(session)
            }
            return
        }
        guard session.outcome == .inProgress else { return }
        if let reveal = preludeRevealAt {
            if now >= reveal {
                preludeRevealAt = nil
                pendingEnemyImpacts.removeAll()
                enemyReadyAt.removeAll()
                lightAttackClock?.reset()
                q3HuntStart = nil
                q4CycleStart = nil
                session.clearQ4HoundState()
                unityBattleRuntime.send(action: "q4-hound:clear")
                pendingGhostReveals.removeAll()
                revealedGhostIDs.removeAll()
                showsQ1GoddessIntervention = true
                UnityBattleRuntime.shared.send(action: "combat-stop")
            }
            return
        }

        // Q28–Q30 (2026-10-10): a fallen hero's cast in flight is lost; the allies fight on.
        if session.playerIsDown { pendingPlayerImpact = nil }
        // Both watched and skipped battles resolve on the same authored deadline.
        // Unity contact messages are presentation acknowledgements, never rule clocks.
        if let impact = pendingPlayerImpact, now >= impact.time {
            _ = unityBattleRuntime.consumeCombatContact("player")
            pendingPlayerImpact = nil
            var value = session
            let previousWave = value.waveIndex
            do {
                if let skill = impact.skill {
                    // Editing the next sequence must not cancel a cast already in flight.
                    let selectedSequence = chosenLoopSkills ?? value.loadout.normalSkillIDs
                    if skill != .namelessStage, !value.loadout.normalSkillIDs.contains(skill) {
                        value.setContinuousSkillSequence([skill] + selectedSequence)
                    }
                    let sealed = value.controlSealActive
                    let statesBefore = value.foolStates
                    let shieldBefore = value.playerShield
                    let result = try value.useFoolSkill(skill, targetID: impact.target, usesRealtimeCooldown: true, sealedByPaperweight: impact.sealed)
                    value.setContinuousSkillSequence(selectedSequence)
                    if skill == .namelessStage { recordUltimateContact(value) }
                    if skill == .maskedWhisper {
                        unityBattleRuntime.send(action: "masquerade:2")
                    }
                    if sealed && !value.controlSealActive {
                        UnityBattleRuntime.shared.send(action: "guardian-ward-break")
                    }
                    presentEnemyImpacts(skill: skill, hits: result.targets.map { ($0.targetID, $0.damage) }, hapticID: "player-\(impact.time)")
                    for hit in result.targets {
                        let prior = statesBefore[hit.targetID]
                        let bonus = (prior?.illusionStacks ?? 0) > 0 || (prior?.misalignmentStacks ?? 0) > 0
                        if skill == .sidestepStrike, hit.damage > 0 {
                            enqueueCombatFloatingNumber(CombatFloatingNumber(
                                enemyID: hit.targetID, amount: hit.damage, kind: bonus ? .bonus : .damage, sourceLabel: bonus ? ((prior?.misalignmentStacks ?? 0) > 0 ? "错位" : "误认") : nil
                            ))
                        } else {
                            showCombatFloatingNumber(hit.damage, for: hit.targetID, kind: bonus ? .bonus : .damage)
                        }
                        if let after = value.foolStates[hit.targetID] {
                            let gained = after.illusionStacks - (prior?.illusionStacks ?? 0)
                            if gained > 0 { showCombatStatus("误认＋\(gained)", at: hit.targetID) }
                            if after.misalignmentStacks > (prior?.misalignmentStacks ?? 0) { showCombatStatus("错位", at: hit.targetID) }
                        }
                    }
                    if value.playerShield > shieldBefore { showCombatStatus("护盾", at: nil) }
                    if skill == .backstageChange, (value.triggeredEffects.last?.contains("无可净化") == false) { showCombatStatus("净化", at: nil) }
                    if isFirstCardTutorial { isFirstCardTutorial = false; onTutorialDismiss() }
                } else {
                    let damage = try value.useBasicAction(.damage, targetID: impact.target)
                    presentEnemyImpacts(skill: nil, hits: [(impact.target, damage)], hapticID: "player-\(impact.time)")
                    showCombatFloatingNumber(damage, for: impact.target, kind: .damage)
                    if isQ1PreludeActive {
                        q1PreludeRoundsCompleted += 1
                        if q1PreludeRoundsCompleted >= Self.q1PreludeAttackCount {
                            preludeRevealAt = max(now + 0.15, playerCastReadyAt)
                        }
                    }
                }
                if value.outcome == .inProgress {
                    presentCompanionActions(value.performCompanionActions(focusTargetID: selectedTargetID))
                }
                session = value
                presentNewRelicEvents()
                recordRelicPlayerContact(value, skill: impact.skill)
                if usesBellTiming { print("[Encore] player-contact at=\(now) skill=\(String(describing: impact.skill)) bell=\(encoreBell.phase)") }
                syncVisualHealth()
                if value.waveIndex != previousWave {
                    pendingEnemyImpacts.removeAll()
                    enemyReadyAt.removeAll()
                    q3HuntStart = nil
                    q4CycleStart = nil
                    session.clearQ4HoundState()
                    unityBattleRuntime.send(action: "q4-hound:clear")
                    pendingGhostReveals.removeAll()
                    revealedGhostIDs.removeAll()
                    replaceVisualScene(for: value)
                }
            } catch { actionMessage = errorMessage(error) }
        }
        guard session.outcome == .inProgress, preludeRevealAt == nil else { return }

        for enemyID in pendingEnemyImpacts.keys.sorted() {
            let nativeID = session.enemies.first(where: { $0.id == enemyID }).flatMap { unityBattleEnemyID(for: $0) }
            let resolvingActor = session.enemies.first(where: { $0.id == enemyID })
            let isWindup = resolvingActor?.currentIntent == "charge"
            guard now >= pendingEnemyImpacts[enemyID, default: .infinity] else { continue }
            if let nativeID { _ = unityBattleRuntime.consumeCombatContact("enemy:" + nativeID) }
            let hapticID = "enemy-\(enemyID)-\(pendingEnemyImpacts[enemyID, default: now])"
            pendingEnemyImpacts.removeValue(forKey: enemyID)
            if usesBellTiming && isWindup {
                if encoreBell.phase == .deferred {
                    encoreBell.consumeReleaseIfDue(at: now)
                } else {
                    encoreBell.completeCharge()
                }
                enemyReadyAt[enemyID] = now
                print("[EncorePrototype] release at=\(now) hp=\(session.playerHP)")
                unityBattleRuntime.send(action: "encore-release")
            }
            guard session.outcome == .inProgress,
                  session.enemies.contains(where: { $0.id == enemyID }) else { continue }
            var value = session
            let hpBefore = value.playerHP
            let shieldBefore = value.playerShield
            do {
                let paperBefore = value.q5PaperRelicTriggered
                let phantomBefore = value.masqueradeCharges
                try value.endRound(actingEnemyID: enemyID, at: now)
                if value.encounter.id.hasPrefix("church_") { enemyReadyAt[enemyID] = now + (resolvingActor?.currentIntent == "tower_flame_first" ? 0.3 : 0) }
                if let resolvedIntent = resolvingActor?.currentIntent,
                   let delay = value.authoredRecoveryDelay(after: resolvedIntent, enemyID: enemyID) {
                    enemyReadyAt[enemyID] = now + delay
                }
                if value.masqueradeCharges != phantomBefore {
                    unityBattleRuntime.send(action: "masquerade-hit:\(value.masqueradeCharges)")
                }
                if !paperBefore && value.q5PaperRelicTriggered {
                    visualScene.presentChapterOnePaperDoubleBreak()
                    unityBattleRuntime.send(action: "paper-double-break")
                }
                if isQ4Hound, let resolved = value.lastEnemyActionResolutions.first {
                    if resolved.intent == "q4_flame_second" {
                        unityBattleRuntime.send(action: value.isQ4OpeningActive ? "q4-hound:opening" : "q4-hound:recover")
                        if value.isQ4OpeningActive { actionMessage = "双焰被承接 · 点击反击重启编排" }
                        q4CycleStart = (q4CycleStart ?? now) + 20
                    }
                }
                if usesUnityBattlefield {
                    unityBattleRuntime.presentPlayerImpact(
                        hpBefore: hpBefore, hpAfter: value.playerHP,
                        shieldBefore: shieldBefore, shieldAfter: value.playerShield,
                        maxHP: value.playerMaxHP, defeated: value.outcome == .defeat, eventID: hapticID
                    )
                }
                if !isFastForwardingBattle { CombatHaptics.shared.incoming(
                    hpLoss: max(0, hpBefore - value.playerHP),
                    shieldLoss: max(0, shieldBefore - value.playerShield),
                    blocked: value.masqueradeCharges < phantomBefore,
                    maxHP: value.playerMaxHP, defeated: value.outcome == .defeat, id: hapticID
                ) }
                if value.encounter.id == "chapter01_q06_encounter" {
                    enemyReadyAt[enemyID] = now
                    if resolvingActor?.currentIntent == "archive_slam" { unityBattleRuntime.send(action: "archive-state:open") }
                }
                if value.encounter.id == "chapter01_q08_encounter" {
                    let nextDelay: Double = switch resolvingActor?.currentIntent {
                    case "parasite": (resolvingActor?.intentIndex ?? 0) % 5 < 2 ? 1.9 : 0.9
                    case "charge": 0.9
                    default: 2.9
                    }
                    enemyReadyAt[enemyID] = now + nextDelay
                    if resolvingActor?.currentIntent == "name_devour" { unityBattleRuntime.send(action: "leech-charge:off") }
                }
                session = value
                if value.lastRelicPlayerHealing > 0 {
                    enqueueCombatFloatingNumber(CombatFloatingNumber(enemyID: nil, amount: value.lastRelicPlayerHealing, kind: .healing))
                }
                presentNewRelicEvents()
                recordRelicEnemyContact(value, beforeHP: hpBefore, beforeShield: shieldBefore)
                if usesBellTiming { print("[Encore] enemy-contact at=\(now) damage=\(max(0, hpBefore - value.playerHP))") }
                if value.houndOpeningReady { actionMessage = "猎犬扑错名字 · 下一次命中伤害提高50%" }
                showPlayerDamageFloatingNumber(max(0, hpBefore - value.playerHP))
                if hpBefore > value.playerHP,
                   value.lastEnemyActionResolutions.contains(where: { $0.playerDamage > 0 && $0.intent != "q4_probe" }) {
                    playerHitFlashUntil = now + 0.2
                }
                for action in value.lastEnemyActionResolutions {
                    if let healed = action.healedTargetID, action.healing > 0 {
                        showCombatFloatingNumber(action.healing, for: healed, kind: .healing)
                        if let recipient = value.enemies.first(where: { $0.id == healed }), let id = unityBattleEnemyID(for: recipient) {
                            unityBattleRuntime.send(action: "enemy-heal:" + id)
                        }
                    }
                    if action.redirectedByPaperDouble { visualScene.presentChapterOnePaperDoubleBreak() }
                    presentPartyEnemyBeat(action, in: value)
                }
                // Also plays `down` for any ally this beat felled, instead of its flinch.
                syncVisualHealth()
                if value.paperDoubleTutorialPhase == .awaitingMara {
                    showsQ5MaraIntervention = true
                    return
                }
            } catch { actionMessage = errorMessage(error) }
        }
        guard session.outcome == .inProgress else { return }

        // Enemies start independently, including while the player is casting.
        for (index, enemy) in session.enemies.enumerated() where enemy.isAlive {
            let isSplitGhost = enemy.contentID == "enemy_resonant_clock_guard_q2_split"
            if isSplitGhost && !revealedGhostIDs.contains(enemy.id) { continue }
            if enemyReadyAt[enemy.id] == nil {
                enemyReadyAt[enemy.id] = ["enemy_clockwork_hound", "enemy_emerald_revenant"].contains(enemy.contentID)
                    ? now : now + (isSplitGhost ? 0.5 + Double(index % 2) * 0.25 : 2.4 + Double(index) * 0.35)
                if let tower = MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID) {
                    enemyReadyAt[enemy.id] = now + tower.initialDelay
                    if enemy.currentIntent == "guard", let nativeID = unityBattleEnemyID(for: enemy) {
                        unityBattleRuntime.send(action: "enemy:\(nativeID):guard")
                    }
                }
                if session.encounter.id == "chapter01_q06_encounter" { enemyReadyAt[enemy.id] = now }
                if session.encounter.id == "chapter01_q08_encounter" { enemyReadyAt[enemy.id] = now + 2.9 }
            }
            if isQ3Hound {
                if q3HuntStart == nil { q3HuntStart = now }
                enemyReadyAt[enemy.id] = MPCQ3HoundTiming.castTime(
                    start: q3HuntStart ?? now, attackIndex: enemy.intentIndex)
            }
            if isQ4Hound {
                if q4CycleStart == nil { q4CycleStart = now }
                let offset: Double = switch enemy.currentIntent {
                case "q4_probe": 2
                case "charge": 6
                case "q4_flame_first": 8
                default: 8.65
                }
                enemyReadyAt[enemy.id] = (q4CycleStart ?? now) + offset
            }
            guard now >= enemyReadyAt[enemy.id, default: .infinity], pendingEnemyImpacts[enemy.id] == nil else { continue }
            if session.isChurchCombat, session.churchPreparationMustWait(enemyID: enemy.id, pendingEnemyIDs: Set(pendingEnemyImpacts.keys)) {
                enemyReadyAt[enemy.id] = now + 0.25
                continue
            }
            let isHound = enemy.contentID == "enemy_clockwork_hound" || enemy.contentID == "enemy_emerald_revenant"
            let isCore = enemy.contentID == "enemy_memory_leech_node"
            let isGhost = enemy.contentID == "enemy_resonant_clock_guard_q2" || isSplitGhost
            let houndCooldown = 3.0
            enemyReadyAt[enemy.id] = now + (isGhost ? (index.isMultiple(of: 2) ? 4.0 : 4.8) : isHound ? houndCooldown : isCore ? 5 : 3.2) * enemy.attackIntervalMultiplier
            if session.encounter.id == "chapter01_q07_encounter" {
                enemyReadyAt[enemy.id] = now + (isCore ? 4 : 4.8)
            }
            if session.consumeEnemyDelay(for: enemy.id) {
                if session.encounter.id == "chapter01_q08_encounter" {
                    enemyReadyAt[enemy.id] = now + 4
                    unityBattleRuntime.send(action: "leech-charge:restrained")
                }
                continue
            }
            if session.encounter.id.hasPrefix("church_"), session.authoredPreparationDuration(for: enemy.id) == nil {
                session.commitEnemyImpact(from: enemy.id)
                let contact = MPCBattleContactTiming.enemyContact(contentID: enemy.contentID, intent: enemy.currentIntent, encounterID: session.encounter.id)
                pendingEnemyImpacts[enemy.id] = now + contact
                enemyReadyAt[enemy.id] = now + contact
                if let nativeID = unityBattleEnemyID(for: enemy) {
                    _ = unityBattleRuntime.consumeCombatContact("enemy:" + nativeID)
                    let target = enemy.currentIntent == "tower_mend" ? session.repairTargetID(for: enemy.id) : enemy.currentIntent == "tower_empower" ? session.towerEmpowerTargetID(for: enemy.id) : nil
                    let recipient = target.flatMap { MPCChapterOneBattleIdentity.battleID(for: $0, in: session.enemies) }
                    unityBattleRuntime.send(action: "enemy:\(nativeID):\(enemy.currentIntent)" + (["tower_mend", "tower_empower"].contains(enemy.currentIntent) ? ":" + (recipient ?? "none") : ""))
                }
                continue
            }
            if let duration = session.authoredPreparationDuration(for: enemy.id) {
                session.commitEnemyImpact(from: enemy.id)
                pendingEnemyImpacts[enemy.id] = now + duration
                enemyReadyAt[enemy.id] = now + duration
                if let nativeID = unityBattleEnemyID(for: enemy) {
                    _ = unityBattleRuntime.consumeCombatContact("enemy:" + nativeID)
                    unityBattleRuntime.send(action: "enemy:\(nativeID):\(enemy.currentIntent)")
                }
                continue
            }
            if enemy.contentID == "enemy_archive_gatekeeper", ["guard", "recover"].contains(enemy.currentIntent) {
                unityBattleRuntime.send(action: enemy.currentIntent == "guard" ? "archive-state:guard" : "archive-state:open")
                session.commitEnemyImpact(from: enemy.id)
                let delay = enemy.currentIntent == "recover" ? MPCChapterOneEncounterSession.archiveRecoveryDuration : 3
                pendingEnemyImpacts[enemy.id] = now + delay
                enemyReadyAt[enemy.id] = now + delay
                continue
            }
            if session.encounter.id == "chapter01_q08_encounter", enemy.currentIntent == "charge" {
                unityBattleRuntime.send(action: "leech-charge:on")
                session.commitEnemyImpact(from: enemy.id)
                pendingEnemyImpacts[enemy.id] = now + 2
                enemyReadyAt[enemy.id] = now + 2
                continue
            }
            if usesBellTiming && enemy.currentIntent == "charge" {
                let deadline = now + (isQ4Hound ? 2.0 : usesEncoreRevenant ? 3.0 : 1.1)
                encoreBell.beginCharge(enemyID: enemy.id, startedAt: now, windupDeadline: deadline)
                pendingEnemyImpacts[enemy.id] = deadline
                enemyReadyAt[enemy.id] = deadline
                print("[EncorePrototype] charge at=\(now) deadline=\(deadline)")
                unityBattleRuntime.send(action: isQ4Hound ? "q4-hound:charge" : "encore-charge")
                continue
            }
            if enemy.contentID == "enemy_emerald_revenant" {
                unityBattleRuntime.send(action: enemy.currentIntent == "emerald_burst" ? "emerald-spell:burst" : "emerald-spell:mist")
            }
            if isQ4Hound {
                let phase = enemy.currentIntent == "q4_probe" ? "probe" : enemy.currentIntent == "q4_flame_first" ? "first" : "second"
                unityBattleRuntime.send(action: "q4-hound:" + phase)
            }
            if enemy.contentID == "enemy_archive_gatekeeper", enemy.currentIntent == "archive_slam" {
                unityBattleRuntime.send(action: "archive-state:clear")
            }
            session.commitEnemyImpact(from: enemy.id)
            pendingEnemyImpacts[enemy.id] = now + MPCBattleContactTiming.enemyContact(contentID: enemy.contentID, intent: enemy.currentIntent, encounterID: session.encounter.id)
            if usesUnityBattlefield {
                if isCore, let id = unityBattleEnemyID(for: enemy) {
                    if enemy.currentIntent == "repair_guard" {
                        let recipient = session.repairTargetID(for: enemy.id).flatMap { MPCChapterOneBattleIdentity.battleID(for: $0, in: session.enemies) } ?? "none"
                        unityBattleRuntime.send(action: "enemy:\(id):repair_guard:\(recipient)")
                    } else { unityBattleRuntime.send(action: "enemy:" + id) }
                }
                else if let id = unityBattleEnemyID(for: enemy) {
                    let carriesIntent = ["archive_slam", "name_devour", "thirteenth_charge"].contains(enemy.currentIntent) || (isHound && ["bite", "charge"].contains(enemy.currentIntent))
                        || (id.hasPrefix("clock-guard-") && ["guard", "fortify", "calibrate", "calibration", "recover"].contains(enemy.currentIntent))
                    unityBattleRuntime.send(action: "enemy:\(id)" + (carriesIntent ? ":\(enemy.currentIntent)" : ""))
                }
            } else {
                visualScene.presentChapterOneEnemyTurn(damage: 0, intents: [enemy.currentIntent], actingEnemyIDs: [enemy.id])
            }
        }

        // Final-boss party allies act on combat time, including while the hero is down; the
        // healer's revive channel runs here too (no-op outside Q28–Q30).
        let heroHPBeforeAllies = session.playerHP
        let reviveBeforeAllies = session.heroReviveAt
        let allyFormation = session.enemies
        let allyActions = session.advanceCompanions(at: now, focusTargetID: selectedTargetID)
        presentCompanionActions(allyActions, enemies: allyFormation)
        // 奥黛尔 kneels to channel the hero's revive (2026-10-11): her rig casts as it begins.
        if reviveBeforeAllies == nil, session.heroReviveAt != nil, let healer = partyHealerID,
           let rig = Self.partyRigName(healer), usesUnityBattlefield {
            unityBattleRuntime.send(action: "ally:\(rig):cast")
        }
        if heroHPBeforeAllies <= 0, session.playerHP > 0 { showCombatStatus("救起", at: nil) }
        if !allyActions.isEmpty || session.playerHP != heroHPBeforeAllies {
            syncVisualHealth()
        }
        guard session.outcome == .inProgress else { return }

        advanceLightAttacks(at: now)
        guard session.outcome == .inProgress, !session.playerIsDown,
              pendingGhostReveals.isEmpty, now >= playerCastReadyAt, now >= session.orderedCastReadyAt, pendingPlayerImpact == nil,
              let target = selectedTargetID.flatMap({ id in session.enemies.first { $0.id == id && $0.isAlive } })
                ?? session.enemies.first(where: \.isAlive) else { return }
        let sequence = chosenLoopSkills ?? visibleBattleSkills.map(\.id)
        if session.activateCounter(at: now) {
            skillScheduler.restartForCounter(sequence: sequence, at: now)
            actionMessage = "反击 · 普通牌刷新 · 从第一张重启"
            if isQ4Hound && usesUnityBattlefield { unityBattleRuntime.send(action: "q4-hound:opening") }
        }
        let automaticSequence = (usesEncoreBellPrototype || usesManualEmeraldMask) ? sequence.filter { $0 != .maskedWhisper } : sequence
        let requestedSkill: FoolSkillID? = requestedUltimate
            && session.loadout.isUltimateUnlocked && session.canUseFoolSkill(.namelessStage)
            ? .namelessStage : nil
        // Formal mask only enters requestEmeraldMask: lifetime accounting cannot
        // be bypassed through the historical automatic card cast path.
        // The final boss's 夺名代签 (2026-10-10) holds one card; the loop passes over it.
        let skill = isQ1PreludeActive ? nil : (requestedSkill ?? skillScheduler.next(in: automaticSequence, at: now, skipping: session.sealedFoolSkillIDs(at: now)))
        if let skill {
            if skill == .namelessStage { requestedUltimate = false }
            if skill == .maskedWhisper { requestedEmeraldMask = false }
            session.setContinuousSkillSequence(sequence)
            skillScheduler.didCast(skill, at: now)
            playerCastReadyAt = now + (skill.isOrderedOrdinary ? 0 : (session.tempo?.skillRecovery ?? MPCCombatTempo.standard.skillRecovery))
            let sealsSkill = session.willSealPreparedSkill(skill, at: now)
            let timing = session.prepareOrderedSkill(skill, targetID: target.id, at: now)
            pendingPlayerImpact = (skill, target.id, timing?.firstImpactAt ?? (now + MPCBattleContactTiming.playerContact(skill)), sealsSkill)
            if let timing, usesUnityBattlefield {
                unityBattleRuntime.send(action: "skill-timing:\(skill.rawValue):\(timing.firstImpactAt - now):\(timing.lastImpactAt - now)")
            }
            if sealsSkill {
                // The card's slot and cooldown are consumed normally. Its
                // original attack must never be shown before the seal resolves.
            } else if usesUnityBattlefield {
                let suffix = unityBattleEnemyID(for: target).map { ":\($0)" } ?? ""
                if skill == .sidestepStrike {
                    let secondaryID = session.enemies.first { $0.isAlive && $0.id != target.id }
                        .flatMap { unityBattleEnemyID(for: $0) } ?? ""
                    unityBattleRuntime.send(action: "sidestep-secondary:\(secondaryID)")
                }
                // Same reach as the rules: two for 错步 in the story, three in the tower,
                // where 荒谬's volley also lands on two bystanders.
                let reach = skill.isOrderedOrdinary ? (skill == .sidestepStrike ? 2 : 0) : MPCFoolGroupCards.extraTargets(encounterID: session.encounter.id, skill: skill)
                if skill == .namelessStage || reach > 0 {
                    let recipients = skill == .namelessStage
                        ? session.enemies.filter(\.isAlive)
                        : [target] + Array(session.enemies.filter { $0.isAlive && $0.id != target.id }.prefix(reach))
                    let ids = recipients.compactMap { unityBattleEnemyID(for: $0) }
                    unityBattleRuntime.send(action: "skill-targets:\(ids.joined(separator: "|"))")
                }
                unityBattleRuntime.send(action: "skill:\(skill.rawValue)\(suffix)")
            } else {
                visualScene.presentFoolSkill(FoolSpellVFXSkill.authored(skill), extendedPresentation: true)
            }
            if !sealsSkill { announceSignatureMove(skill) }
        } else if now >= (basicCooldownStarted ?? -100) + (session.tempo?.basicInterval ?? 2.4) {
            basicCooldownStarted = now
            playerCastReadyAt = now + (session.tempo?.basicRecovery ?? MPCCombatTempo.standard.basicRecovery)
            pendingPlayerImpact = (nil, target.id, now + MPCBattleContactTiming.playerContact(nil), false)
            if usesUnityBattlefield {
                let suffix = unityBattleEnemyID(for: target).map { ":\($0)" } ?? ""
                unityBattleRuntime.send(action: "basic\(suffix)")
            }
            else { visualScene.presentFoolBasicAttack() }
        }
    }

    // MARK: Final-boss party presentation (Q28–Q30; 2026-10-11, user: 为什么不接入：队友画面…)

    /// Unity's painted cut-out rigs for the party allies (`ally:<rig>:<take>`).
    private static func partyRigName(_ companionID: String) -> String? {
        switch companionID {
        case "ally_norn_kade": "norn"
        case "ally_odelle_finn": "odelle"
        default: nil
        }
    }

    /// The rig take for an ally's skill: 诺恩 strikes (破甲) or raises the lantern (守墙, armed
    /// 替挡); 奥黛尔 casts her mend, cleanse or rounds and throws the vial between them.
    private static func partyRigAction(skillID: String) -> String {
        switch skillID {
        case "ally_guard_wall", "ally_intercept": "guard"
        case "ally_odelle_mend", "ally_odelle_cleanse", "ally_odelle_clinic_rounds": "cast"
        default: "attack"   // ally_armor_break, ally_odelle_vial, ally_unbroken_march
        }
    }

    /// The HUD's short name: 诺恩·凯德 → 诺恩.
    private static func partyShortName(_ companionID: String) -> String {
        let name = MPCChapterOneCatalog.companions.first { $0.id == companionID }?.name ?? companionID
        return name.split(separator: "·").first.map(String.init) ?? name
    }

    private var partyHealerID: String? {
        session.activeCompanionIDs.first { id in MPCChapterOneCatalog.companions.first { $0.id == id }?.role == .healer }
    }

    /// Puts 诺恩 and 奥黛尔 beside the hero and sets the boss back (`party-show`). `rebuild` clears
    /// the old rigs first (a retried attempt); either way any fallen pose is sent again.
    private func showPartyRigs(rebuild: Bool = false) {
        guard usesUnityBattlefield, session.isPartyBossEncounter else { return }
        if rebuild { unityBattleRuntime.send(action: "party-clear") }
        unityBattleRuntime.send(action: "party-show")
        lastPartyFallenPresentation = []
        syncPartyRigPresentation()
    }

    /// Each resolved ally action plays its take on that ally's rig.
    private func presentCompanionActions(_ actions: [MPCCompanionActionResolution], enemies: [MPCRuntimeEnemy]? = nil) {
        guard !isFastForwardingBattle else { return }
        for action in actions {
            if let target = action.targetID, action.amount > 0, (enemies ?? session.enemies).contains(where: { $0.id == target }) {
                showCombatFloatingNumber(action.amount, for: target, kind: .damage, enemies: enemies)
            }
            guard usesUnityBattlefield, session.isPartyBossEncounter, let rig = Self.partyRigName(action.companionID) else { continue }
            unityBattleRuntime.send(action: "ally:\(rig):\(Self.partyRigAction(skillID: action.skillID))")
        }
    }

    /// One enemy beat on the rigs: an ally it hurt flinches, the protector who took the thirteenth
    /// blow for the hero guards instead; one it felled is left to `syncPartyRigPresentation` (down).
    private func presentPartyEnemyBeat(_ action: MPCEnemyActionResolution, in value: MPCChapterOneEncounterSession) {
        guard usesUnityBattlefield, value.isPartyBossEncounter else { return }
        var struck = Set(action.allyDamage.filter { $0.value > 0 }.keys)
        if let guardID = action.interceptedBy { struck.insert(guardID) }
        for id in struck.sorted() where value.isAllyStanding(id) {
            guard let rig = Self.partyRigName(id) else { continue }
            unityBattleRuntime.send(action: "ally:\(rig):\(id == action.interceptedBy ? "guard" : "hit")")
        }
    }

    /// Keeps the rigs' fallen poses with the rules: `down` once per fall (`revive` should an ally
    /// ever stand again). Runs from `syncVisualHealth`.
    private func syncPartyRigPresentation() {
        guard usesUnityBattlefield, session.isPartyBossEncounter else { return }
        let fallen = Set(session.activeCompanionIDs.filter { !session.isAllyStanding($0) })
        guard fallen != lastPartyFallenPresentation else { return }
        for id in fallen.subtracting(lastPartyFallenPresentation).sorted() {
            if let rig = Self.partyRigName(id) { unityBattleRuntime.send(action: "ally:\(rig):down") }
        }
        for id in lastPartyFallenPresentation.subtracting(fallen).sorted() {
            if let rig = Self.partyRigName(id) { unityBattleRuntime.send(action: "ally:\(rig):revive") }
        }
        lastPartyFallenPresentation = fallen
    }

    /// Party HUD (2026-10-11): each ally's battle health in the hero bar's look, small in the
    /// battlefield's top-left corner, clear of the boss and the card dock. Grey with 倒下 when
    /// fallen, 封 under 夺名代签, 救起中 beside the healer while she channels the hero's revive.
    private var partyAllyHUD: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(session.activeCompanionIDs, id: \.self) { id in
                let standing = session.isAllyStanding(id)
                let sealed = standing && session.isAllySealed(id)
                let reviving = standing && id == partyHealerID && session.heroReviveAt != nil
                HStack(spacing: 5) {
                    Text(Self.partyShortName(id))
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 36, alignment: .leading)
                    compactHealthBar(value: session.allyHP[id, default: 0], maximum: session.allyMaxHP[id, default: 1],
                                     tint: .green, condensed: true)
                    if !standing {
                        Text("倒下")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.85))
                    } else if sealed {
                        Text("封")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.43))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.purple.opacity(0.82), in: Capsule())
                    }
                    if reviving {
                        Text("救起中")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.cyan)
                    }
                }
                .saturation(standing ? 1 : 0)
                .opacity(standing ? 1 : 0.6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("队友 \(Self.partyShortName(id))，生命 \(session.allyHP[id, default: 0])/\(session.allyMaxHP[id, default: 0])"
                    + (standing ? "" : "，倒下") + (sealed ? "，被夺名代签封住" : "") + (reviving ? "，正在救起主角" : ""))
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: 6))
    }

    /// The fallen hero (2026-10-11): who is bringing them back, or that the allies hold the line.
    private var partyHeroDownCue: some View {
        let healer = partyHealerID.map(Self.partyShortName) ?? "队友"
        return Text(session.heroReviveAt != nil ? "主角倒地 · \(healer)救援中" : "主角倒地 · 队友支撑中")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(.white)
            .fixedSize()
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color(red: 0.42, green: 0.08, blue: 0.10).opacity(0.88)))
            .overlay(Capsule().stroke(Color.yellow.opacity(0.6), lineWidth: 1))
    }

    /// 夺名代签's sealed card (2026-10-11): dimmed in the strip with a small lock and 封.
    private var sealedCardMark: some View {
        VStack(spacing: 0) {
            Image(systemName: "lock.fill").font(.system(size: 10, weight: .black))
            Text("封").font(.system(size: 10, weight: .black))
        }
        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.43))
        .padding(.horizontal, 5).padding(.vertical, 3)
        .background(Color.purple.opacity(0.82), in: RoundedRectangle(cornerRadius: 5))
        .shadow(color: .black.opacity(0.8), radius: 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Q30 天使出场 (2026-10-11, user: 天使出场…)

    /// Unity's `angel-intro` runs 28.5 s from the command.
    private static let q30AngelIntroDuration: Double = 28.5
    /// The intro's lines, seconds from `angel-intro` (drafts; edit here). 18.4–24.1 is the fight
    /// inside the ball of light, left wordless.
    private static let q30AngelIntroLines: [Q30AngelIntroLine] = [
        .init(start: 0.6, end: 3.6, speaker: "瑟维安", text: "切断了外接，就以为切断了我？"),
        .init(start: 3.6, end: 6.6, speaker: "瑟维安", text: "雾港的每一个名字，都签在我的册子上——包括你的。"),
        .init(start: 6.6, end: 9.6, speaker: "瑟维安", text: "可惜你的名字，在你入港之前，就已经有人订下了。"),
        .init(start: 9.6, end: 12.6, speaker: "瑟维安", text: "来吧，收件人。我把他交还给你。"),
        .init(start: 12.6, end: 14.4, speaker: "裂口深处的声音", text: "……归还。"),
        .init(start: 14.4, end: 16.6, speaker: nil, text: "天上亮起一盏孤灯。"),
        .init(start: 16.6, end: 18.4, speaker: "伊莱娅", text: "到此为止。外面的那位，归我。"),
        .init(start: 24.1, end: 26.1, speaker: "伊莱娅", text: "里面的私印，交给你们。"),
        .init(start: 26.1, end: 28.5, speaker: "瑟维安", text: "没有主人……那就用我自己的名字，签完这一份。"),
    ]

    /// Every Q30 attempt opens on the cutscene with the clock held, so hero, allies and boss stay
    /// full; the stage task sends it once Unity stands. The farewell blessings wait for its end.
    private func beginQ30AngelIntroIfNeeded(_ value: MPCChapterOneEncounterSession) {
        guard value.chapterMissionNumber == 30, usesUnityBattlefield, value.outcome == .inProgress,
              q30AngelIntroSessionID != value.settlementID else { return }
        q30AngelIntroSessionID = value.settlementID
        q30AngelIntroStartedAt = nil
        showsQ30AngelIntro = true
    }

    /// Natural end or 跳过 (Unity drops the cutscene at once): then the blessings, the player's
    /// speed again, and the loop resumes as after the other interludes.
    private func finishQ30AngelIntro(skipped: Bool) {
        guard showsQ30AngelIntro else { return }
        if skipped { unityBattleRuntime.send(action: "angel-intro-skip") }
        withAnimation(.easeOut(duration: 0.25)) { showsQ30AngelIntro = false }
        q30AngelIntroStartedAt = nil
        synchronizeBattlePresentationSettings()
        announceFarewellBlessingsIfNeeded(session)
    }

    /// The intro's dialogue box and 跳过: the battle's dark violet with a gold hairline, plain type.
    /// Lines follow the wall clock from `angel-intro`, so they stay with Unity's picture.
    private func q30AngelIntroOverlay(bottomInset: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 10) {
            Spacer(minLength: 0)
            Button { finishQ30AngelIntro(skipped: true) } label: {
                Text("跳过 ›")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.55))
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .overlay(Capsule().stroke(Color(red: 1.0, green: 0.75, blue: 0.24).opacity(0.5), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("跳过开场")
            .accessibilityIdentifier("chapter-one-q30-intro-skip")
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                let elapsed = q30AngelIntroStartedAt.map { context.date.timeIntervalSince($0) } ?? -1
                let line = Self.q30AngelIntroLines.first { elapsed >= $0.start && elapsed < $0.end }
                ZStack(alignment: .bottom) {
                    if let line {
                        q30AngelIntroDialogue(line)
                            .id(line.start)
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .bottom)
                .animation(.easeOut(duration: 0.25), value: line?.start)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, bottomInset + 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func q30AngelIntroDialogue(_ line: Q30AngelIntroLine) -> some View {
        let narration = line.speaker == nil
        return VStack(alignment: narration ? .center : .leading, spacing: 5) {
            if let speaker = line.speaker {
                Text(speaker)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.45))
            }
            Text(line.text)
                .font(.system(size: 16, weight: narration ? .regular : .medium))
                .foregroundStyle(.white.opacity(narration ? 0.8 : 0.96))
                .multilineTextAlignment(narration ? .center : .leading)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: narration ? .center : .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.13, green: 0.12, blue: 0.22).opacity(0.86), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(red: 0.78, green: 0.62, blue: 0.34).opacity(0.55), lineWidth: 1))
        .shadow(color: .black.opacity(0.55), radius: 10, y: 3)
        .accessibilityElement(children: .combine)
    }

    /// Named finishers announce themselves as they are cast (2026-10-07, after comparing
    /// with other games' signature moves: 名招出手时打一行招式名). Only 荒谬归结 for now.
    private static let signatureMoves: Set<FoolSkillID> = [.absurdFinale]

    private func announceSignatureMove(_ skill: FoolSkillID) {
        guard !isFastForwardingBattle else { return }
        guard Self.signatureMoves.contains(skill) else { return }
        let cue = SignatureCalloutCue(title: skillName(skill))
        signatureCallout = cue
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1300))
            if signatureCallout?.id == cue.id { signatureCallout = nil }
        }
    }

    private func advanceLightAttacks(at now: TimeInterval) {
        guard var clock = lightAttackClock else { return }
        var value = session
        var events = MPCChurchBattleStepper.Events()
        let hpBefore = value.playerHP
        let opening = (value.q4OpeningUntil ?? -1) > now
        clock.advance(&value, now: now, step: 0.05,
                      authoredPending: pendingEnemyImpacts, authoredReady: enemyReadyAt,
                      blocked: { opening || $0.delayedRounds > 0 }, into: &events)
        lightAttackClock = clock
        session = value
        for attack in events.lightAttacks {
            if let enemy = value.enemies.first(where: { $0.id == attack.enemyID }),
               let nativeID = unityBattleEnemyID(for: enemy) {
                let duration = max(0.05, Double(attack.landsAtTick) * 0.05 - now)
                unityBattleRuntime.send(action: "enemy-light:\(nativeID):\(duration)")
            }
        }
        for hit in events.lightResolved {
            let nativeID = value.enemies.first(where: { $0.id == hit.enemyID }).flatMap { unityBattleEnemyID(for: $0) } ?? ""
            unityBattleRuntime.send(action: "light-contact:\(nativeID):\(hit.parried ? 1 : 0)")
            enqueueCombatFloatingNumber(CombatFloatingNumber(enemyID: nil, amount: hit.damage,
                kind: hit.parried ? .parried : .playerDamage, sourceLabel: hit.parried ? "招架" : nil))
        }
        for id in events.lightCancelled {
            if let enemy = value.enemies.first(where: { $0.id == id }), let nativeID = unityBattleEnemyID(for: enemy) {
                unityBattleRuntime.send(action: "light-cancel:\(nativeID)")
            }
        }
        if !events.lightResolved.isEmpty || value.playerHP != hpBefore { syncVisualHealth() }
    }

    private func presentNewRelicEvents() {
        guard !isFastForwardingBattle else { return }
        for event in session.relicDamageEvents {
            guard presentedRelicEventIDs.insert("damage-\(event.id)").inserted, event.damage > 0 else { continue }
            showCombatFloatingNumber(event.damage, for: event.targetID, kind: .damage)
            presentEnemyImpacts(skill: nil, hits: [(event.targetID, event.damage)], hapticID: "relic-\(event.id)")
        }
        for event in session.relicHealingEvents {
            guard presentedRelicEventIDs.insert("healing-\(event.id)").inserted, event.damage > 0 else { continue }
            showCombatFloatingNumber(event.damage, for: event.targetID, kind: .healing)
            if let enemy = session.enemies.first(where: { $0.id == event.targetID }), let nativeID = unityBattleEnemyID(for: enemy) {
                unityBattleRuntime.send(action: "enemy-heal:\(nativeID)")
            }
        }
    }



    private func recordRelicEnemyContact(_ value: MPCChapterOneEncounterSession, beforeHP: Int, beforeShield: Int) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--verify-p1-ui"),
              let storage = UserDefaults(suiteName: "mistport.p1-ui-verification") else { return }
        var records = storage.array(forKey: "debug.relic-enemy-contacts") as? [[String: Any]] ?? []
        let actions: [[String: Any]] = value.lastEnemyActionResolutions.map {
            ["enemy": $0.enemyID, "intent": $0.intent, "damage": $0.playerDamage]
        }
        records.append(["encounter": value.encounter.id, "session": value.settlementID.uuidString,
                        "uptime": battleTime,
                        "hpBefore": beforeHP, "hpAfter": value.playerHP,
                        "shieldBefore": beforeShield, "shieldAfter": value.playerShield,
                        "actions": actions, "ringExposurePending": value.ringExposurePending,
                        "effects": Array(value.triggeredEffects.suffix(8))])
        storage.set(Array(records.suffix(80)), forKey: "debug.relic-enemy-contacts")
        #endif
    }

    private func recordRelicPlayerContact(_ value: MPCChapterOneEncounterSession, skill: FoolSkillID?) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--verify-p1-ui"),
              let storage = UserDefaults(suiteName: "mistport.p1-ui-verification") else { return }
        var records = storage.array(forKey: "debug.relic-player-contacts") as? [[String: Any]] ?? []
        let enemies: [[String: Any]] = value.enemies.map { enemy in
            let state = value.foolState(for: enemy.id)
            return ["enemy": enemy.id, "illusion": state?.illusionStacks ?? -1,
                    "misalignment": state?.misalignmentStacks ?? -1]
        }
        records.append(["encounter": value.encounter.id, "session": value.settlementID.uuidString,
                        "skill": skill?.rawValue ?? "basic", "enemies": enemies,
                        "ringExposurePending": value.ringExposurePending,
                        "sealConversionReady": value.sealConversionReady])
        storage.set(Array(records.suffix(80)), forKey: "debug.relic-player-contacts")
        #endif
    }

    private func recordUltimateContact(_ value: MPCChapterOneEncounterSession) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--verify-p1-ui"),
              let storage = UserDefaults(suiteName: "mistport.p1-ui-verification") else { return }
        let enemies: [[String: Any]] = value.enemies.filter(\.isAlive).map { enemy in
            let state = value.foolState(for: enemy.id)
            return ["id": enemy.id, "illusionStacks": state?.illusionStacks ?? -1,
                    "finaleReady": state?.finaleReady ?? false]
        }
        var records = storage.array(forKey: "debug.ultimate-contacts") as? [[String: Any]] ?? []
        records.append(["encounter": value.encounter.id,
                        "session": value.settlementID.uuidString,
                        "canUseAgain": value.canUseFoolSkill(.namelessStage),
                        "enemies": enemies])
        storage.set(Array(records.suffix(20)), forKey: "debug.ultimate-contacts")
        #endif
    }

    private func enqueueAutomaticTurn() {
        if isQ1PreludeActive {
            enqueueAutomaticBasicAttack()
            return
        }

        let sequence = chosenLoopSkills ?? visibleBattleSkills.map(\.id)
        guard !sequence.isEmpty else {
            enqueueAutomaticBasicAttack()
            return
        }

        guard let skill = nextAutomaticSkill(in: sequence) else {
            // Basic attacks fill the gap while skill cooldowns run in real time.
            enqueueAutomaticBasicAttack()
            actionMessage = "自动普攻 · 技能冷却中"
            return
        }

        let targetID = selectedTargetID.flatMap { selectedID in
            session.enemies.contains(where: { $0.id == selectedID && $0.isAlive })
                ? selectedID
                : nil
        } ?? Self.defaultTargetID(in: session.enemies)
        queuedActions = [.skill(skill)]
        queuedTargetIDs = [skill: targetID].compactMapValues { $0 }
        actionMessage = "自动执行 · \(skillName(skill))"
        updateQueuedTargetPresentation()
    }

    private func nextAutomaticSkill(in sequence: [FoolSkillID]) -> FoolSkillID? {
        skillScheduler.next(in: sequence.filter {
            $0 != .namelessStage || session.canUseFoolSkill($0)
        }, at: battleTime, skipping: session.sealedFoolSkillIDs(at: battleTime))
    }

    /// Automatic fallback attacks must be fully resolved without opening the
    /// manual target-picker. Otherwise the automatic task commits an empty
    /// queue and combat appears frozen on “选择目标”.
    private func enqueueAutomaticBasicAttack() {
        guard let targetID = selectedTargetID.flatMap({ selectedID in
            session.enemies.contains(where: { $0.id == selectedID && $0.isAlive })
                ? selectedID
                : nil
        }) ?? Self.defaultTargetID(in: session.enemies) else { return }

        queuedActions = [.basic(.damage)]
        queuedBasicTargetIDs[MPCPlayerActionCategory.damage.rawValue] = targetID
        pendingBasicTargetCategory = nil
        selectedTargetID = targetID
        actionMessage = "自动普攻"
        updateQueuedTargetPresentation()
    }

    private var battleRelicContents: [MPCRelicContent] {
        let ids = session.loadout.relicIDs.filter(MPCChapterOneCatalog.isRelicEnabled)
        var seen = Set<String>()
        return ids.compactMap { id in
            guard seen.insert(id).inserted, !EarlyRelicShop.activeIDs.contains(id), id != "relic_encore_bell", id != "relic_paper_raincoat" else { return nil }
            return MPCChapterOneCatalog.relics.first { $0.id == id }
        }
    }

    /// Keep the lower card shelf compact; relics and supplies live on the side rail.
    private var showsCombatInventoryPanel: Bool {
        (showsStandaloneOpeningBattleButton || combatIsActive || !ownedBattleSkills.isEmpty)
            && (combatIsActive || waitsForPostInterventionStart || !battleRelicContents.isEmpty || !ownedBattleSkills.isEmpty)
    }

    /// Keep owned cards available for selection before combat starts.
    private var showsCombatSkillShelf: Bool {
        !ownedBattleSkills.isEmpty
    }

    private func battleRelicStatus(for relic: MPCRelicContent) -> (String, Color) {
        if campaign.depletedRelicIDs.contains(relic.id) {
            return ("失效0% · 修复后生效", .orange)
        }
        let now = battleTime
        let state = session.sequenceNineRelics
        switch relic.id {
        case EarlyRelicShop.stamp:
            if let debt = state.deferredDamage { return ("待签 \(max(0, Int(ceil(debt.dueAt - now))))秒", .yellow) }
            return (now < state.stampReadyAt ? "\(Int(ceil(state.stampReadyAt - now)))秒" : "就绪", .yellow)
        case EarlyRelicShop.mirror:
            return (now < state.mirrorExpiresAt && state.mirrorTargetID != nil ? "反照待触发" : now < state.mirrorReadyAt ? "\(Int(ceil(state.mirrorReadyAt - now)))秒" : "锁定后赠血", .cyan)
        case EarlyRelicShop.paperweight:
            if session.loadout.normalSkillIDs.count < 3 { return ("需编排至少3张牌", .orange) }
            if now < state.paperweightExpiresAt && state.paperweightCapacity > 0 { return ("庇护 \(state.paperweightCapacity)", .yellow) }
            return (now < state.paperweightReadyAt ? "\(Int(ceil(state.paperweightReadyAt - now)))秒" : "第3槽待封", .yellow)
        case EarlyRelicShop.anchor:
            if now < state.anchorExpiresAt && state.anchorSegments > 0 { return ("余\(state.anchorSegments)段 · \(state.anchorCapacity)", .cyan) }
            return (now < state.anchorReadyAt ? "\(Int(ceil(state.anchorReadyAt - now)))秒" : "就绪", .cyan)
        case EarlyRelicShop.needle:
            if now < state.healingBlockedUntil { return ("封疗 \(Int(ceil(state.healingBlockedUntil - now)))秒", .orange) }
            return ("剩余 \(max(0, 2 - state.needleUses))次", .mint)
        default: break
        }
        if relic.id == EarlyRelicShop.salt {
            return ("收容 \(session.saltBreathingBagStored)/\(session.playerBaseMaxHP)", .mint)
        }
        if relic.id == EarlyRelicShop.clasp {
            if session.returnGiftClaspIsReady { return ("就绪", .yellow) }
            let remaining = max(0, Int(ceil(session.returnGiftClaspReadyAt - battleTime)))
            return (remaining > 0 ? "\(remaining)秒 · 礼盾" : "等待礼盾破除", .orange)
        }
        if relic.id == "relic_unified_gear" {
            return session.ringExposurePending ? ("下次自身承伤+25%", .orange) : ("三类成环 · 触发后承伤增加", .white.opacity(0.7))
        }
        if relic.id == "relic_nameless_seal" {
            return session.sealConversionReady ? ("下次转换保留误认", .yellow) : ("宣告2层 · 随后一次免费转换", .white.opacity(0.7))
        }
        guard relic.id == "relic_paper_raincoat" else {
            return ("已装备", Color(red: 0.38, green: 0.88, blue: 0.72))
        }
        if session.paperDoubleTutorialPhase == .enraged {
            return ("等待玛拉交付", .black.opacity(0.48))
        } else if session.q5PaperRelicReady {
            return ("可触发", Color(red: 0.18, green: 0.62, blue: 0.42))
        } else if session.q5PaperRelicTriggered {
            return ("已发动", Color(red: 0.78, green: 0.42, blue: 0.12))
        } else {
            return ("已装备", Color(red: 0.18, green: 0.62, blue: 0.42))
        }
    }

    private func relicArtName(_ relicID: String) -> String? {
        if EarlyRelicShop.ids.contains(relicID) { return EarlyRelicShop.art(relicID) }
        return switch relicID {
        case "relic_encore_bell": "ItemEncoreBellCutout"
        case "relic_paper_raincoat": "IconRelicPaperDouble"
        case "relic_trimmed_nameplate": "IconRelicTrimmedNameplate"
        case "relic_unified_gear": "IconRelicThreeProofRing"
        case "relic_nameless_seal": "IconRelicNamelessSeal"
        default: nil
        }
    }

    /// Only positive, authoritative damage receives a body impact. Mapping uses
    /// the pre-resolution formation so lethal hits retain their original identity.
    private func presentEnemyImpacts(skill: FoolSkillID?, hits: [(String, Int)], enemies: [MPCRuntimeEnemy]? = nil, hapticID: String = UUID().uuidString) {
        guard !isFastForwardingBattle else { return }
        if !skipsCombatAnimations {
            CombatHaptics.shared.outgoing(skillID: skill?.rawValue, damage: hits.reduce(0) { $0 + max(0, $1.1) }, id: hapticID)
        }
        guard usesUnityBattlefield, !skipsCombatAnimations,
              let action = MPCChapterOneBattleIdentity.impactAction(skill: skill, hits: hits, enemies: enemies ?? session.enemies) else { return }
        unityBattleRuntime.send(action: action)
    }

    private var ownsManualMask: Bool {
        campaign.ownsManualMask
    }

    private var maskIsTeachingLoan: Bool {
        ["chapter01_q03_encounter", "chapter01_q04_encounter"].contains(session.encounter.id)
    }

    private var ownsMedal: Bool {
        campaign.ownedRelicIDs.contains(MPCChapterOneCatalog.usurpedLifeMedalRelicID)
    }

    private func selectDockRelic(_ id: String) {
        guard !combatIsActive, !maskIsTeachingLoan, !campaign.depletedRelicIDs.contains(id) else { return }
        let owned = campaign.ownedRelicIDs.contains(id)
        guard session.selectActiveRelic(id, isOwned: owned) else { return }
        onSelectActiveRelic(id)
    }

    private var passiveRelicSelection: some View {
        VStack(spacing: 10) {
            ForEach(EarlyRelicShop.passiveIDs.filter(campaign.ownedRelicIDs.contains), id: \.self) { id in
                Button {
                    guard !combatIsActive, !campaign.depletedRelicIDs.contains(id) else { return }
                    var loadout = session.loadout
                    loadout.relicIDs = loadout.relicIDs.contains(id) ? [] : [id]
                    guard let configured = try? MPCChapterOneEncounterSession.start(
                        encounterID: session.encounter.id, party: campaign.party,
                        consumables: campaign.inventory,
                        companionIDs: MPCChapterOneCatalog.mission(forEncounterID: session.encounter.id)?.companionIDs ?? [],
                        loadout: loadout) else { return }
                    session = configured
                    onSelectPassiveRelic(id)
                } label: {
                    VStack(spacing: 2) {
                        Image(EarlyRelicShop.art(id)).resizable().scaledToFit().frame(width: 42, height: 42)
                            .overlay { RoundedRectangle(cornerRadius: 8).stroke(.yellow.opacity(session.loadout.relicIDs.contains(id) ? 0.95 : 0.15), lineWidth: 1.5) }
                        Text(campaign.depletedRelicIDs.contains(id) ? "失效0%" : EarlyRelicShop.name(id))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(campaign.depletedRelicIDs.contains(id) ? .orange : .white)
                    }
                }.buttonStyle(.plain)
                    .disabled(campaign.depletedRelicIDs.contains(id))
                    .accessibilityLabel("被动遗落物，\(EarlyRelicShop.name(id))")
                    .accessibilityValue(campaign.depletedRelicIDs.contains(id) ? "完好度0%，已失效，请在教会或战前修复" : session.loadout.relicIDs.contains(id) ? "已装备，再次点击卸下" : "未装备")
            }
        }
    }

    private var activeRelicSelection: some View {
        VStack(spacing: 10) {
            if ownsManualMask {
                relicSelectionButton(id: MPCChapterOneCatalog.ownerlessMaskRelicID, art: "IconRelicOwnerlessMask", title: "假面")
            }
            if ownsMedal {
                relicSelectionButton(id: MPCChapterOneCatalog.usurpedLifeMedalRelicID, art: "IconRelicUsurpedLifeMedal", title: "僭命勋章")
            }
            if campaign.ownedRelicIDs.contains(EarlyRelicShop.blankCard) {
                relicSelectionButton(id: EarlyRelicShop.blankCard, art: EarlyRelicShop.art(EarlyRelicShop.blankCard), title: "空栏名片")
            }
        }
    }

    private func dockRelicIsSelected(_ id: String) -> Bool {
        (session.loadout.selectedActiveRelicID ?? MPCChapterOneCatalog.ownerlessMaskRelicID) == id
    }

    private func relicSelectionButton(id: String, art: String, title: String) -> some View {
        Button { selectDockRelic(id) } label: {
            VStack(spacing: 3) {
                Image(art).resizable().scaledToFit().frame(width: 46, height: 46)
                    .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(dockRelicIsSelected(id) ? 0.95 : 0.15), lineWidth: 1.5) }
                Text(campaign.depletedRelicIDs.contains(id) ? "\(title) · 失效" : title)
                    .font(.system(size: 10, weight: .bold))
            }
        }.buttonStyle(.plain)
            .disabled(campaign.depletedRelicIDs.contains(id))
            .accessibilityLabel("装备" + title)
            .accessibilityValue(campaign.depletedRelicIDs.contains(id) ? "完好度0%，已失效，请修复" : dockRelicIsSelected(id) ? "已选择" : "未选择")
    }

    private var blankNameCardButton: some View {
        Button {
            guard combatIsActive, session.outcome == .inProgress,
                  let target = selectedTargetID.flatMap({ id in session.enemies.first { $0.id == id && $0.isAlive } }) ?? session.enemies.first(where: \.isAlive) else { return }
            _ = session.activateBlankNameCard(isOwned: campaign.ownedRelicIDs.contains(EarlyRelicShop.blankCard), targetID: target.id, at: battleTime)
        } label: {
            VStack(spacing: 3) {
                Image(EarlyRelicShop.art(EarlyRelicShop.blankCard)).resizable().scaledToFit().frame(width: 46, height: 46)
                VStack(spacing: 2) {
                    Text("空栏名片").font(.system(size: 10, weight: .bold))
                    let now = battleTime
                    let state = session.sequenceNineRelics
                    Text(now < state.blankCardExpiresAt ? "契约中" : now < state.blankCardReadyAt ? "\(Int(ceil(state.blankCardReadyAt - now)))秒" : "就绪")
                        .font(.system(size: 9)).foregroundStyle(.yellow)
                }.foregroundStyle(.white)
            }
        }.buttonStyle(.plain)
            .disabled(!combatIsActive || session.outcome != .inProgress || battleTime < session.sequenceNineRelics.blankCardReadyAt)
            .accessibilityLabel("使用空栏名片，与当前敌人缔结三秒契约")
    }

    private var medalRelicButton: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { _ in
            let now = battleTime
            let remaining = max(0, (session.usurpedLifeMedalExpiresAt ?? now) - now)
            let cooldown = max(0, session.usurpedLifeMedalReadyAt - now)
            let active = session.isUsurpedLifeMedalActive
            Button {
                guard combatIsActive, session.outcome == .inProgress else { return }
                if session.activateUsurpedLifeMedal(isOwned: ownsMedal, at: battleTime) {
                    syncVisualHealth()
                }
            } label: {
                VStack(spacing: 3) {
                    Image("IconRelicUsurpedLifeMedal").resizable().scaledToFit().frame(width: 46, height: 46)
                        .brightness(active ? 0.08 * min(1, remaining / 2) : 0)
                        .shadow(color: .purple.opacity(active ? 0.75 * min(1, remaining / 2) : 0), radius: active ? 5 + 2 * sin(now * 4) : 0)
                        .overlay {
                            if active {
                                UsurpedMedalCrownEffect(remaining: remaining, time: now).allowsHitTesting(false)
                                Circle().trim(from: 0, to: min(1, remaining / 8)).stroke(Color.yellow.opacity(min(1, remaining / 2)), lineWidth: 2).rotationEffect(.degrees(-90))
                            } else if cooldown > 0 {
                                ClockwiseCardCooldown(now: battleTime, startedAt: session.usurpedLifeMedalReadyAt - 24, duration: 24)
                            }
                        }
                    VStack(spacing: 3) {
                        Text("僭命勋章").font(.system(size: 10, weight: .bold))
                        Text(active ? String(format: "%.1fs", remaining) : cooldown > 0 ? "\(Int(ceil(cooldown)))s" : "可发动")
                            .font(.system(size: 9, weight: .medium)).foregroundStyle(active ? Color.yellow : Color.secondary)
                    }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
                .disabled(!combatIsActive || session.outcome != .inProgress || active || cooldown > 0)
                .accessibilityIdentifier("combat-relic-usurped-life-medal")
                .accessibilityLabel("发动僭命勋章")
        }
    }

    private var teachesMaskTiming: Bool {
        guard ["chapter01_q03_encounter", "chapter01_q04_encounter"].contains(session.encounter.id),
              combatIsActive, session.outcome == .inProgress,
              manualMaskIsReady, session.masqueradeCharges == 0 else { return false }
        if isQ3Hound {
            guard let start = q3HuntStart else { return false }
            let phase = (battleTime - start).truncatingRemainder(dividingBy: MPCQ3HoundTiming.cycle)
            return phase >= 1.5 && phase <= 3.0
        }
        guard isQ4Hound else { return true }
        // Q4 repeats a 20 s cycle: probe at +2.45, flames at +8.45/+9.10.
        // A 4 s phantom only covers both flames when raised after ~+5.1, and
        // the mask is ready again before that in later cycles, so light the
        // cue only inside the real window (playtest 2026-10-04).
        guard let cycle = q4CycleStart else { return false }
        let phase = battleTime - cycle
        return phase >= 5.3 && phase <= 8.3
    }

    private var manualMaskIsReady: Bool {
        usesManualEmeraldMask && ownsManualMask && (maskIsTeachingLoan || maskCrackCount < 10)
            && battleTime >= max(session.ownedManualMaskReadyAt, skillScheduler.readyAt[.maskedWhisper, default: 0])
    }

    private func requestEmeraldMask() {
        guard combatIsActive, session.outcome == .inProgress, manualMaskIsReady else { return }
        do {
            let now = battleTime
            let target = selectedTargetID.flatMap { id in session.enemies.first { $0.id == id && $0.isAlive } }
                ?? session.enemies.first(where: \.isAlive)
            let victimFormation = session.enemies
            let previousSession = session
            guard let result = try session.useOwnedManualMasquerade(targetID: target?.id, isOwned: ownsManualMask, lifetimeCracks: maskCrackCount, at: now) else { return }
            guard onUseManualMask() else { session = previousSession; return }
            if !maskIsTeachingLoan { maskCrackCount = min(10, maskCrackCount + 1) }
            presentEnemyImpacts(skill: .maskedWhisper, hits: result.targets.map { ($0.targetID, $0.damage) }, enemies: victimFormation)
            for hit in result.targets where hit.damage > 0 {
                var number = CombatFloatingNumber(enemyID: hit.targetID, amount: hit.damage, kind: .damage, sourceLabel: "假面")
                if healthOverlaySize.width > 0, healthOverlaySize.height > 0,
                   let anchor = combatFloatingNumberPosition(number, in: healthOverlaySize, enemies: victimFormation, includesLane: false) {
                    number.normalizedAnchor = CGPoint(x: anchor.x / healthOverlaySize.width, y: anchor.y / healthOverlaySize.height)
                }
                enqueueCombatFloatingNumber(number)
            }
            skillScheduler.didCast(.maskedWhisper, at: now)
            unityBattleRuntime.send(action: "masquerade:\(session.masqueradeCharges)")
            unityBattleRuntime.send(action: "tempo-mask")
            requestedEmeraldMask = false
            syncVisualHealth()
        } catch { actionMessage = errorMessage(error) }
    }

    private var manualMaskRelicButton: some View {
        Button { requestEmeraldMask() } label: {
            VStack(spacing: 3) {
                Image("IconRelicOwnerlessMask")
                    .resizable().scaledToFit().frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .overlay { MaskCrackOverlay(count: maskCrackCount) }
                    .overlay {
                        if session.masqueradeCharges > 0, let expiry = session.ownedManualMaskExpiresAt {
                            TimelineView(.animation(minimumInterval: 0.05)) { _ in
                                Circle().trim(from: 0, to: min(1, max(0, (expiry - battleTime) / 4)))
                                    .stroke(Color.purple.opacity(0.85), lineWidth: 2).rotationEffect(.degrees(-90))
                            }.allowsHitTesting(false)
                        }
                    }
                    .overlay { ClockwiseCardCooldown(now: battleTime, startedAt: skillScheduler.startedAt[.maskedWhisper], duration: 18) }
                    .overlay { RoundedRectangle(cornerRadius: 9).stroke(.yellow.opacity(manualMaskIsReady ? 0.9 : 0.2), lineWidth: 1.5).allowsHitTesting(false) }
                VStack(spacing: 3) {
                    Text(maskCrackCount >= 10 && !maskIsTeachingLoan ? "已失效" : "假面").font(.system(size: 10, weight: .bold))
                    HStack(spacing: 3) {
                        ForEach(0..<2, id: \.self) { index in
                            Circle().fill(index < session.masqueradeCharges ? Color.purple : Color.white.opacity(0.18)).frame(width: 6, height: 6)
                        }
                    }
                }
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!combatIsActive || session.outcome != .inProgress || !manualMaskIsReady)
        .accessibilityIdentifier("combat-relic-ownerless-mask")
        .accessibilityLabel("使用遗落物假面")
        .accessibilityValue("裂纹\(maskCrackCount)/10，剩余承伤\(session.masqueradeCharges)次")
    }

    private var manualMasqueradeStatus: String {
        if !combatIsActive { return "战中手动" }
        if session.masqueradeCharges > 0, let expiry = session.timedMasqueradeExpiresAt {
            return String(format: "假人 %.1f秒", max(0, expiry - encoreClock))
        }
        let remaining = max(0, session.timedMasqueradeReadyAt - encoreClock)
        return remaining > 0 ? String(format: "冷却 %.1f秒", remaining) : "点击假面"
    }

    private func summonTimedMasquerade() {
        guard usesEncoreBellPrototype, combatIsActive, !showsTutorial else { return }
        let now = battleTime
        guard session.activateTimedMasquerade(at: now) else { return }
        unityBattleRuntime.send(action: "masquerade:1")
        CombatHaptics.shared.emit(.maskActivate)
    }

    private var encoreBellStatus: String {
        if !combatIsActive {
            if usesEncoreBellPrototype { return "试用 · 蓄力时点击 · 每场一次" }
            return session.loadout.relicIDs.contains("relic_encore_bell") ? "已装备 · 点击卸下" : "点击装备 · 每场一次"
        }
        guard session.outcome == .inProgress else { return "战斗已结束" }
        guard usesEncoreBellPrototype || session.loadout.relicIDs.contains("relic_encore_bell") else { return "未装备 · 下次战前点击装备" }
        if !session.enemies.contains(where: { $0.intentPattern.contains("charge") }) { return "本场敌人无蓄力招式" }
        switch encoreBell.phase {
        case .ready: return "等待蓄力 · 每场一次"
        case .windingUp:
            let remaining = max(0, (encoreBell.initialWindupDeadline ?? encoreClock) - encoreClock)
            return String(format: "点击摇铃 · 蓄力 %.1f 秒", remaining)
        case .deferred:
            let remaining = max(0, (encoreBell.releaseDeadline ?? encoreClock) - encoreClock)
            return String(format: "重击暂缓 · %.1f 秒后返场", remaining)
        case .spent: return "本场已使用"
        }
    }

    private func ringEncoreBell() {
        let now = battleTime
        guard session.canUseEncoreBell, combatIsActive, session.outcome == .inProgress,
              let id = encoreBell.pendingEnemyID,
              session.enemies.contains(where: { $0.id == id && $0.isAlive }),
              encoreBell.phase == .windingUp else { return }
        var nextBell = encoreBell
        guard nextBell.ring(at: now), let deadline = nextBell.releaseDeadline,
              session.markEncoreDebt(enemyID: id) else { return }
        encoreBell = nextBell
        encoreRingAt = now
        pendingEnemyImpacts[id] = deadline
        enemyReadyAt[id] = deadline
        encoreRingToken += 1
        print("[EncorePrototype] ring at=\(now) release=\(deadline) hp=\(session.playerHP)")
        unityBattleRuntime.send(action: "encore-bell")
    }

    private var encoreBellButton: some View {
        Button {
            if combatIsActive { ringEncoreBell() }
            else if !usesEncoreBellPrototype && campaign.ownedRelicIDs.contains("relic_encore_bell") {
                var loadout = session.loadout
                if loadout.relicIDs.contains("relic_encore_bell") {
                    loadout.relicIDs.removeAll { $0 == "relic_encore_bell" }
                } else {
                    guard loadout.relicIDs.count < 2 else { actionMessage = "遗落物已装满，请先在行囊卸下一件"; return }
                    loadout.relicIDs.append("relic_encore_bell")
                }
                if let configured = try? MPCChapterOneEncounterSession.start(
                    encounterID: session.encounter.id, party: campaign.party,
                    consumables: campaign.inventory,
                    companionIDs: MPCChapterOneCatalog.mission(forEncounterID: session.encounter.id)?.companionIDs ?? [],
                    loadout: loadout) {
                    session = configured
                    onToggleEncoreBell()
                }
            }
        } label: {
            VStack(spacing: 3) {
                Image("ItemEncoreBellCutout").resizable().scaledToFit()
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .rotationEffect(.degrees(encoreBell.phase == .deferred ? -12 : 0))
                    .animation(.spring(duration: 0.3), value: encoreRingToken)
                VStack(spacing: 2) {
                    Text("返场铃").font(.system(size: 10, weight: .bold))
                    Text(encoreBell.phase == .windingUp ? "点击摇铃" : encoreBell.phase == .spent ? "已使用" : encoreBell.phase == .deferred ? "暂缓中" : combatIsActive ? "等待蓄力" : session.loadout.relicIDs.contains("relic_encore_bell") ? "已装备" : "点击装备")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(encoreBell.phase == .windingUp ? Color.yellow : Color.white.opacity(0.7))
                }
            }
            .foregroundStyle(.white)
            .padding(5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(combatIsActive
                  ? (!session.canUseEncoreBell || session.outcome != .inProgress || encoreBell.phase != .windingUp)
                  : usesEncoreBellPrototype)
        .accessibilityIdentifier("encore-bell")
        .accessibilityLabel(combatIsActive ? "摇响不肯落幕的铃" : "装备或卸下不肯落幕的铃")
        .accessibilityValue(encoreBellStatus)
        .sensoryFeedback(.impact(weight: .heavy), trigger: encoreRingToken) { _, _ in hapticsEnabled }
    }

    private var combatSideRailItemCount: Int {
        var count = availableBattleSupplyIDs.count + (showsEncoreBell ? 1 : 0)
        if !combatIsActive && !maskIsTeachingLoan {
            count += EarlyRelicShop.activeIDs.filter(campaign.ownedRelicIDs.contains).count
            count += EarlyRelicShop.passiveIDs.filter(campaign.ownedRelicIDs.contains).count
        } else {
            if usesManualEmeraldMask { count += 1 }
            if !maskIsTeachingLoan && ownsMedal && dockRelicIsSelected(MPCChapterOneCatalog.usurpedLifeMedalRelicID) { count += 1 }
            if combatIsActive && dockRelicIsSelected(EarlyRelicShop.blankCard) { count += 1 }
            count += battleRelicContents.count
        }
        return count
    }

    private var paperRelicDockSection: some View {
        VStack(spacing: 2) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { combatItemsOnLeft.toggle() }
            } label: {
                Image(systemName: combatItemsOnLeft ? "arrow.right.to.line" : "arrow.left.to.line")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.yellow).frame(width: 60, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(combatItemsOnLeft ? "将遗落物和物品移到右侧" : "将遗落物和物品移到左侧")
            ScrollView(.vertical) {
                VStack(spacing: 10) {
                    if !combatIsActive && !maskIsTeachingLoan {
                        activeRelicSelection
                        passiveRelicSelection
                    } else {
                        if usesManualEmeraldMask { manualMaskRelicButton }
                        if ownsMedal && !maskIsTeachingLoan && dockRelicIsSelected(MPCChapterOneCatalog.usurpedLifeMedalRelicID) { medalRelicButton }
                        if combatIsActive && dockRelicIsSelected(EarlyRelicShop.blankCard) { blankNameCardButton }
                        ForEach(battleRelicContents) { relic in
                            let status = battleRelicStatus(for: relic)
                            VStack(spacing: 2) {
                                if let art = relicArtName(relic.id) {
                                    Image(art).resizable().scaledToFit().frame(width: 42, height: 42)
                                } else {
                                    Image(systemName: "seal.fill").frame(width: 42, height: 42)
                                }
                                Text(relic.name).font(.system(size: 9, weight: .bold))
                                Text(status.0).font(.system(size: 8)).foregroundStyle(status.1)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    if showsEncoreBell { encoreBellButton }
                    ForEach(availableBattleSupplyIDs, id: \.self) { id in
                        let name = MPCChapterOneCatalog.items.first { $0.id == id }?.name ?? "补给"
                        let isShield = id == "consumable_mirror_salve"
                        Button { useBattleSupply(id) } label: {
                            VStack(spacing: 2) {
                                Image(id == "consumable_salt_tea" ? "ItemSaltTea" : isShield ? "ItemMirrorSalve" : "ItemPainSalve")
                                    .resizable().scaledToFit().frame(width: 42, height: 42)
                                    .overlay(alignment: .bottomTrailing) {
                                        Text("×\(session.consumables[id, default: 0])")
                                            .font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                            .padding(2).background(.black.opacity(0.85), in: Capsule())
                                    }
                                Text(name).font(.system(size: 9, weight: .semibold))
                                Text(isShield ? "+100盾" : id == "consumable_pain_salve" ? "+25%生命" : "+20%生命")
                                    .font(.system(size: 8)).foregroundStyle(.white.opacity(0.7))
                            }
                            .frame(width: 56).frame(minHeight: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!combatIsActive || session.outcome != .inProgress
                            || (!isShield && battleTime < session.sequenceNineRelics.healingBlockedUntil)
                            || (isShield ? session.playerShield >= session.playerMaxHP * 4 / 10 : session.playerHP >= session.playerMaxHP))
                        .accessibilityLabel("使用\(name)，持有\(session.consumables[id, default: 0])")
                    }
                }
                .frame(width: 58).padding(.bottom, 6)
            }
            .scrollIndicators(.visible)
        }
        .multilineTextAlignment(.center).foregroundStyle(.white)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(.yellow.opacity(0.3), lineWidth: 0.8).allowsHitTesting(false) }
    }

    private var availableBattleSupplyIDs: [String] {
        ["consumable_pain_salve", "consumable_mirror_salve", "consumable_salt_tea"]
            .filter { session.consumables[$0, default: 0] > 0 }
    }

    private func useBattleSupply(_ id: String) {
        #if DEBUG
        NSLog("[MistportSupply] tap id=%@ combatActive=%d outcome=%@ hp=%d/%d held=%d campaign=%d", id, combatIsActive ? 1 : 0, session.outcome.rawValue, session.playerHP, session.playerMaxHP, session.consumables[id, default: 0], campaign.inventory[id, default: 0])
        #endif
        guard combatIsActive, session.outcome == .inProgress else { return }
        let name = MPCChapterOneCatalog.items.first { $0.id == id }?.name ?? "补给"
        var updated = session
        let previousHP = updated.playerHP
        let previousShield = updated.playerShield
        do {
            try updated.useConsumable(id)
            guard onConsumeSupply(id) else {
                actionMessage = "\(name)已用完"
                return
            }
            session = updated
            let restoredHP = updated.playerHP - previousHP
            if restoredHP > 0 {
                CombatHaptics.shared.emit(.heal)
                enqueueCombatFloatingNumber(CombatFloatingNumber(enemyID: nil, amount: restoredHP, kind: .healing))
            }
            syncVisualHealth()
            actionMessage = id == "consumable_mirror_salve"
                ? "\(name)增加\(updated.playerShield - previousShield)护盾"
                : "\(name)恢复\(updated.playerHP - previousHP)生命"
        } catch {
            actionMessage = "当前无需使用\(name)"
        }
    }

    private var queuedComboPreview: (title: String, detail: String)? {
        guard queuedSkillIDs.count >= 2 else { return nil }
        return switch Array(queuedSkillIDs.prefix(2)) {
        case [.stolenTempo, .mirrorBarrage]: ("抢拍 → 连弹", "加速让固定引导从三发提升至六发")
        case [.fabricatedEvidence, .identityDisplacement]: ("伪证 → 张冠", "四层误认在到期前转为错位与破甲")
        case [.identityDisplacement, .mirrorPursuit]: ("张冠 → 双影", "错位期间兑现两段重击")
        case [.delayedSignature, .mirrorBarrage]: ("落款 → 连弹", "让后续连击计入2.6秒后的爆炸")
        default: nil
        }
    }

    private func retargetPolicy(for skill: FoolSkillID) -> QueuedRetargetPolicy {
        switch skill {
        case .sidestepStrike, .mirrorPursuit, .absurdFinale, .namelessStage:
            .anyValidEnemy
        default:
            .sameTargetOnly
        }
    }

    private func exitBattleSettlingMedal() {
        _ = session.finishRelicBattle()
        syncVisualHealth()
        onExit()
    }

    private var battleHeader: some View {
        HStack(spacing: 10) {
            GameArtReturnButton(title: "退出") {
                guard !locksExitForTutorial else { return }
                exitBattleSettlingMedal()
            }
            .overlay(alignment: .bottomTrailing) {
                if locksExitForTutorial {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(GameArt.gold)
                        .padding(3).background(GameArt.night, in: Circle())
                        .allowsHitTesting(false)
                }
            }
            .opacity(locksExitForTutorial ? 0.72 : 1)
            .accessibilityLabel(locksExitForTutorial ? "教学期间无法退出战斗" : "退出战斗")
            .accessibilityHint(locksExitForTutorial ? "完成当前教学后解锁" : "返回主界面")

            VStack(alignment: .leading, spacing: 2) {
                Text(usesEncoreBellPrototype ? "不肯落幕 · 遗落物试演" : session.encounter.name)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .white,
                                Color(red: 1.0, green: 0.92, blue: 0.70),
                                .white.opacity(0.96)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.72, blue: 0.22).opacity(0.82),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: 76, height: 1)
                        .offset(y: 3)
                    }
            }

            Spacer()

            Button { savedBattleSpeed = battleSpeed == 1 ? 2 : 1 } label: {
                VStack(spacing: 1) {
                    Text("\(battleSpeed)×").font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("倍速").font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(Color(red: 1, green: 0.84, blue: 0.48))
                .frame(width: 46, height: 44)
                .background(Color(red: 0.12, green: 0.11, blue: 0.16), in: RoundedRectangle(cornerRadius: 9))
                .overlay { RoundedRectangle(cornerRadius: 9).stroke(.yellow.opacity(0.38), lineWidth: 1) }
            }.buttonStyle(.plain).accessibilityIdentifier("combat-speed")
                .accessibilityLabel("战斗速度 \(battleSpeed) 倍")
            battleProgressChip
        }
    }

    private var battlefield: some View {
        GeometryReader { proxy in
            ZStack {
                if usesUnityBattlefield {
                    UnityBattleSurface()
                        // Bind Unity to the actual battle viewport. Without
                        // an explicit frame, the embedded root view can keep
                        // its launch-time portrait size and leave black bars
                        // after SwiftUI lays out the header and card dock.
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        // Unity is a visual layer for this encounter. Native
                        // cards and action buttons must receive the touches.
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    // Reuse the original authored SpriteKit card VFX as a
                    // transparent layer over the Unity characters. It must
                    // use the exact same viewport as Unity or the two layers
                    // will appear to be independently letterboxed.
                    SpriteView(
                        scene: visualScene,
                        preferredFramesPerSecond: 60,
                        options: [.allowsTransparency, .ignoresSiblingOrder]
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                } else {
                    SpriteView(
                        scene: visualScene,
                        preferredFramesPerSecond: 60,
                        options: [.ignoresSiblingOrder]
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    // Native target buttons and health bars below announce the
                    // current roster; SpriteKit actor names are presentation only.
                    .accessibilityHidden(true)
                }

            // Keep both authoritative HP bars visible above the presentation
            // layer.  The Unity/SpriteKit actors are deliberately non-
            // interactive, so this HUD remains crisp and always readable.
            if usesUnityBattlefield {
                ForEach(Array(session.enemies.filter(\.isAlive).enumerated()), id: \.element.id) { index, enemy in
                    let anchor = enemyHealthBarPosition(for: enemy, index: index,
                        total: session.enemies.filter(\.isAlive).count, in: proxy.size,
                        appliesModelClearance: false)
                    Button {
                        selectedTargetID = enemy.id
                        updateQueuedTargetPresentation()
                    } label: {
                        ZStack(alignment: .bottom) {
                            Color.clear
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: 64, height: enemy.contentID == "enemy_memory_leech_node" ? 54 : 86)
                    .position(x: anchor.x, y: anchor.y + (enemy.contentID == "enemy_memory_leech_node" ? 28 : 52))
                    .accessibilityLabel(protectedBossTargetLabel(for: enemy)
                        ?? "目标 \(MPCChapterOneBattleIdentity.presentationName(contentID: enemy.contentID, encounterID: session.encounter.id, fallback: enemy.name))，生命 \(enemy.hp)/\(enemy.maxHP)")
                }
            }
            combatantHealthOverlay
                .opacity(showsQ30AngelIntro ? 0 : 1)
            if session.isPartyBossEncounter && combatIsActive {
                partyAllyHUD
                    .padding(.leading, 10)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .opacity(showsQ30AngelIntro ? 0 : 1)
                    .allowsHitTesting(false)
                    .zIndex(21)
            }
            if !combatIsActive, !showsTutorial,
               let mission = MPCChapterOneCatalog.mission(forEncounterID: session.encounter.id),
               // From Q3 the bridge's readiness panel carries these lines, so
               // they never sit on a tall boss's health bar.
               (1...2).contains(mission.number) {
                VStack {
                    TimelineView(.periodic(from: .now, by: 4)) { context in
                        let lines = Self.enemyPreludeLines(mission.number)
                        Text(lines[Int(context.date.timeIntervalSince1970 / 4) % lines.count])
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 10))
                    }
                    // The bridge's prebattle readiness panel owns the top
                    // band; sit below it so the two never overlap.
                    .padding(.top, 16).padding(.horizontal, 28)
                    Spacer()
                }.allowsHitTesting(false)
            }

            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(minHeight: 280)
        .animation(.easeOut(duration: 0.20), value: targetSelectionDetail)
    }

    static func enemyPreludeLines(_ mission: Int) -> [String] {
        switch mission {
        case 1: return ["空壳守卫：已认领人员，不得离开保管区域。", "街区播报：无法说明来历的人，也会得到照看。"]
        case 2: return ["退信间的低语：别送我回家。", "另一道残响：他们没有……领到我。"]
        case 3: return ["旧犬项圈里的名字，与你记得的一致。", "邮务编号旁，还刻着一道陌生的委托号。"]
        case 4: return ["同一只猎犬停在远处，喉间双焰渐亮。", "项圈里传来断续的召回信号。"]
        case 5: return ["邮务执役者：退件尚未清零……", "邮务执役者：已送达。已送达。"]
        case 6: return ["档案门卫：通行证有效。", "档案门卫：请由领回您的监护人申请查阅。"]
        case 7: return ["空壳守卫：归属待填，请勿取走。", "空白牌背面，露出诊所领药编号。"]
        case 8: return ["记忆蛭：那只杯子……你很熟悉。", "它借来的声音，正试探你的反应。"]
        case 9: return ["书记员：重复报案，撤回原述。", "奥黛尔的寻人证词正在被覆盖。"]
        case 10: return ["档案守卫：名单所列，均已领回。", "押运编号指向一户你不认识的家庭。"]
        case 11: return ["门后的人：你从小就用这一只。", "茶杯底部却印着诊所的药柜编号。"]
        case 12: return ["书记员：一名移出，一名补入。", "玛拉紧紧攥着旧通行证。"]
        case 13: return ["背架录音：安置完成。等待调拨。", "洛克：后面……原本不是这一句。"]
        case 14: return ["书记员：家庭归属已核定。", "伊恩的名牌后面，牵出细红线。"]
        case 15: return ["维娅：没有这些家，他们今晚住在哪里？", "丝线仍在把陌生人编入家庭。"]
        default: return ["雾中的身影正注视着你。"]
        }
    }

    private var usesUnityBattlefield: Bool {
#if canImport(UnityFramework)
        MPCChapterOneBattleIdentity.supportsUnity(encounterID: session.encounter.id)
#else
        return false
#endif
    }

    private var unityBattlePresentation: UnityBattleEncounterPresentation {
        if session.encounter.id.hasPrefix("church_bounty_") {
            return .waveInstances(session.enemies.compactMap { MPCChapterOneBattleIdentity.visualDescriptor(for: $0.id, in: session.enemies, encounterID: session.encounter.id) })
        }
        if session.encounter.id.hasPrefix("church_tower_") || session.encounter.id.hasPrefix("church_maintenance_") {
            return .churchTower(session.enemies.compactMap {
                MPCChapterOneBattleIdentity.visualDescriptor(for: $0.id, in: session.enemies, encounterID: session.encounter.id)
            })
        }
        if session.chapterMissionNumber == 24,
           !revealedGhostIDs.isEmpty || (session.outcome != .inProgress && session.enemies.contains(where: {
               $0.contentID == "enemy_resonant_clock_guard_q2_split" && session.foolStates[$0.id] != nil
           })) {
            // Resolve identities against the complete roster, including the
            // dead mother, so contact callbacks keep the same child IDs.
            return .waveInstances(session.enemies.filter {
                $0.contentID != "enemy_resonant_clock_guard_q2"
            }.compactMap {
                MPCChapterOneBattleIdentity.visualDescriptor(for: $0.id, in: session.enemies, encounterID: session.encounter.id)
            })
        }
        if (16...30).contains(session.chapterMissionNumber) { return .chapterThirty(session.chapterMissionNumber) }
        if let mission = MPCChapterOneCatalog.mission(forEncounterID: session.encounter.id), (mission.number >= 9 || mission.number == 6 || mission.number == 8) {
            return .waveInstances(session.enemies.compactMap {
                MPCChapterOneBattleIdentity.visualDescriptor(for: $0.id, in: session.enemies, encounterID: session.encounter.id)
            })
        }
        switch session.encounter.id {
        case "chapter01_q02_encounter": return .dualClockGuard
        case "chapter01_q03_encounter": return .earlyHellHound
        case "chapter01_q04_encounter": return .earlyHellHound
        case "chapter01_q05_encounter": return .hellHound
        case "chapter01_q06_encounter": return .waveInstances(["clock-guard-primary@archivist"])
        case "chapter01_q07_encounter": return .coreEscort
        case "chapter01_q08_encounter": return .waveInstances(["memory-leech-primary"])
        case "chapter01_q09_encounter": return .puppetCore
        case "chapter01_q10_encounter": return .houndEscort
        default: return .clockGuard
        }
    }

    private var targetSelectionDetail: String? {
        if let pendingTargetSkillID {
            return skillName(pendingTargetSkillID)
        }
        if pendingBasicTargetCategory == .damage {
            return "普攻"
        }
        return nil
    }

    private func protectedBossTargetLabel(for enemy: MPCRuntimeEnemy) -> String? {
        guard [28, 29].contains(session.chapterMissionNumber),
              enemy.contentID == "boss_chronarch_sovereign" else { return nil }
        let source = session.chapterMissionNumber == 28 ? "五锚外接护层" : "钟环有限储备"
        return "目标 \(enemy.name)，\(source)，已完成\(session.completedBossCycles)个完整循环，共5个；攻击由护层承接，本体生命不减少"
    }

    private var bossAuthorityTrack: some View {
        VStack(spacing: 3) {
            Text(session.chapterMissionNumber == 28 ? "五锚外接护层" : "钟环储备")
                .font(.system(size: 9, weight: .bold))
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { cycle in
                    Capsule()
                        .fill(cycle < session.completedBossCycles ? Color.gray.opacity(0.45) : Color.yellow)
                        .frame(width: 14, height: 6)
                }
            }
            Text("完整循环 \(session.completedBossCycles)/5")
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(.yellow)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(.black.opacity(0.76), in: RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("\(session.chapterMissionNumber == 28 ? "五锚外接护层" : "钟环储备")，已完成\(session.completedBossCycles)个完整循环，共5个")
    }

    private var combatantHealthOverlay: some View {
        GeometryReader { proxy in
            Color.clear.frame(width: 0, height: 0)
                .onAppear { healthOverlaySize = proxy.size }
                .onChange(of: proxy.size) { _, size in healthOverlaySize = size }
            let aliveEnemies = session.enemies.filter { $0.isAlive && ($0.contentID != "enemy_resonant_clock_guard_q2_split" || revealedGhostIDs.contains($0.id)) }
            ForEach(Array(aliveEnemies.enumerated()), id: \.element.id) { index, enemy in
                Group {
                    if protectedBossTargetLabel(for: enemy) != nil {
                        bossAuthorityTrack
                    } else {
                        compactHealthBar(
                            value: transientEnemyHealth[enemy.id] ?? enemy.hp,
                            maximum: enemy.maxHP,
                            tint: .red,
                            condensed: aliveEnemies.count > 1,
                            crowded: aliveEnemies.count >= 3
                        )
                    }
                }
                .overlay(alignment: .top) {
                    combatStatusStrip(session.enemyCombatStatuses(enemyID: enemy.id, at: battleTime))
                        .offset(y: 9)
                }
                .overlay(alignment: .top) {
                    if index == 0 {
                        VStack(spacing: 3) {
                            if session.chapterObjectiveRequired > 0 {
                                ProgressView(value: Double(session.chapterObjectiveProgress), total: Double(session.chapterObjectiveRequired))
                                    .tint(.cyan).frame(width: 88)
                                Text("\(session.chapterMissionNumber == 20 ? "拘束解除" : "根结拆除") \(session.chapterObjectiveProgress)/\(session.chapterObjectiveRequired)")
                                    .font(.system(size: 9, weight: .bold)).foregroundStyle(.cyan)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .accessibilityLabel("\(session.chapterMissionNumber == 20 ? "拘束解除" : "根结拆除")，已完成\(session.chapterObjectiveProgress)，总计\(session.chapterObjectiveRequired)")
                            }
                            if session.chapterMissionNumber == 26 && session.chapterSupplyRemaining > 0 {
                                ProgressView(value: Double(session.chapterSupplyRemaining), total: 900)
                                    .tint(.yellow).frame(width: 88)
                                Text("车链供能 \(session.chapterSupplyRemaining)/900").font(.system(size: 9, weight: .bold)).foregroundStyle(.yellow)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                        }.offset(y: -28)
                    }
                }
                // Keep the enemy bar clearly above the model instead of
                // crossing its head/shoulders.
                .position(enemyHealthBarPosition(
                    for: enemy,
                    index: index,
                    total: aliveEnemies.count,
                    in: proxy.size
                ))
            }

            if session.sequenceNineRelics.paperweightCapacity > 0,
               battleTime < session.sequenceNineRelics.paperweightExpiresAt {
                Ellipse()
                    .fill(RadialGradient(colors: [.clear, .yellow.opacity(0.06), .yellow.opacity(0.35)], center: .center, startRadius: 22, endRadius: 72))
                    .overlay { Ellipse().stroke(.yellow.opacity(0.72), lineWidth: 1.5) }
                    .frame(width: 96, height: 142)
                    .position(x: playerHealthBarPosition(in: proxy.size).x, y: playerHealthBarPosition(in: proxy.size).y + 76)
                    .allowsHitTesting(false)
            }

            compactHealthBar(
                value: session.playerHP,
                maximum: session.playerMaxHP,
                tint: .green,
                temporaryExtension: session.isUsurpedLifeMedalActive
            )
            // This is the protagonist's bar. Anchor it to the protagonist's
            // configured screen placement, never to the enemy row.
            .overlay(alignment: .top) {
                combatStatusStrip(session.playerCombatStatuses(at: battleTime))
                    .offset(y: 10)
            }
            .position(playerHealthBarPosition(in: proxy.size))

            // These labels intentionally live above both renderers. SpriteKit
            // effects can sit behind the embedded Unity view, but combat
            // values must remain readable whenever HP actually changes.
            ForEach(combatFloatingNumbers) { number in
                if let position = combatFloatingNumberPosition(number, in: proxy.size) {
                    VStack(spacing: 1) {
                        if let source = number.sourceLabel {
                            Text(source)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(red: 0.86, green: 0.70, blue: 1))
                        }
                        Text(number.kind.text(for: number.amount))
                            .font(.system(size: number.kind != .healing && number.enemyID != nil && session.enemies.filter(\.isAlive).count >= 3 ? 19 : number.kind.fontSize, weight: .black, design: .rounded))
                    }
                        .foregroundStyle(number.kind.color)
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .shadow(color: .black.opacity(0.9), radius: 3, y: 2)
                        .shadow(color: number.kind.color.opacity(0.38), radius: 8)
                        .position(position)
                        .offset(y: number.isFloating ? -32 : 0)
                        .transition(.opacity.combined(with: .scale(scale: 0.82)))
                }
            }
        }
        .allowsHitTesting(false)
        .zIndex(20)
    }

    private func combatStatusStrip(_ statuses: [MPCCombatStatus]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(17), spacing: 2), count: 4), spacing: 2) {
            ForEach(statuses) { status in
                let tint: Color = status.harmful ? Color(red: 1, green: 0.55, blue: 0.62) : Color(red: 0.55, green: 0.85, blue: 1)
                Image(systemName: status.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 17, height: 17)
                    .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 3))
                    .overlay { RoundedRectangle(cornerRadius: 3).stroke(tint.opacity(0.85), lineWidth: 0.7) }
                    .overlay(alignment: .bottomTrailing) {
                        if let count = status.count {
                            Text("\(count)")
                                .font(.system(size: 8, weight: .heavy, design: .rounded))
                                .monospacedDigit().foregroundStyle(.white)
                                .padding(.horizontal, 1)
                                .background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 2))
                                .offset(x: 1, y: 1)
                        }
                    }
                    .accessibilityLabel(status.name + (status.count.map { "，\($0)\(status.countUnit)" } ?? ""))
            }
        }
        .frame(width: 74)
        .fixedSize(horizontal: true, vertical: true)
    }

    private func enemyHealthBarPosition(
        for enemy: MPCRuntimeEnemy,
        index: Int,
        total: Int,
        in size: CGSize,
        appliesModelClearance: Bool = true
    ) -> CGPoint {
        if usesUnityBattlefield,
           let unityID = unityBattleEnemyID(for: enemy),
           let anchor = unityBattleRuntime.healthAnchor(for: unityID) {
            let isLeech = MPCChapterOneBattleIdentity.family(for: enemy.contentID) == "memory-leech"
            let verticalOffset: CGFloat = appliesModelClearance && isLeech
                ? -36 : (usesEncoreRevenant ? 0 : 22)
            return CGPoint(
                x: anchor.x * size.width,
                // Unity's profile anchor includes generous animation
                // clearance. Pull the compact HUD back down to the visible
                // helmet instead of leaving it floating near the header.
                y: max(8, min(size.height - 8, anchor.y * size.height + verticalOffset))
            )
        }
        if let anchor = visualScene.chapterOneEnemyHealthAnchorInView(for: enemy.id) {
            return CGPoint(
                x: max(8, min(size.width - 8, anchor.x)),
                y: max(8, min(size.height - 8, anchor.y - 10))
            )
        }
        // Simulator uses the same authored formation as the SpriteKit
        // fallback. The old fixed 25% y-position floated an extra red bar
        // near the chapter header, far away from the enemy it described.
        // Keep the bar tied to the formation slot and lift it above the
        // silhouette by a stable viewport amount.
        let aliveEnemies = session.enemies.filter(\.isAlive)
        let slots = chapterOneFormationSlots(for: aliveEnemies)
        let slot = slots.indices.contains(index) ? slots[index] : .frontCenter
        let actorPoint = chapterOneFormationViewPoint(for: slot, in: size)
        return CGPoint(
            x: actorPoint.x,
            y: max(8, actorPoint.y - size.height * 0.105)
        )
    }

    private func playerHealthBarPosition(in size: CGSize) -> CGPoint {
        if usesUnityBattlefield,
           let anchor = unityBattleRuntime.effectAnchor(for: "player-health") {
            return CGPoint(
                x: anchor.x * size.width,
                // Renderer bounds include the full cast take, so the raw
                // anchor sits well above the current head pose. This visual
                // correction keeps the green bar unmistakably attached to
                // the protagonist rather than the enemy's feet.
                y: max(8, min(size.height - 8, anchor.y * size.height + 22))
            )
        }
        // A live Unity encounter must never fall back to the hidden SpriteKit
        // actor: that is what left the green bar floating at waist height.
        if usesUnityBattlefield {
            let placement = playerPlacement.normalized
            return CGPoint(
                x: CGFloat(placement.x) * size.width,
                y: max(20, CGFloat(placement.yFromTop - 0.11) * size.height)
            )
        }
        if let anchor = visualScene.chapterOnePlayerHealthAnchorInView() {
            return CGPoint(
                x: max(8, min(size.width - 8, anchor.x)),
                y: max(8, min(size.height - 8, anchor.y - 10))
            )
        }
        // The scene may not be attached during the first SwiftUI layout pass.
        // Keep a placement-based fallback only until the real artwork bounds
        // become available.
        let placement = playerPlacement.normalized
        return CGPoint(
            x: CGFloat(placement.x) * size.width,
            y: max(20, min(size.height - 20, CGFloat(placement.yFromTop - 0.055) * size.height))
        )
    }

    private func combatFloatingNumberPosition(
        _ number: CombatFloatingNumber,
        in size: CGSize,
        enemies: [MPCRuntimeEnemy]? = nil,
        includesLane: Bool = true
    ) -> CGPoint? {
        // Two columns and two rows leave enough room for four simultaneous
        // values, including their 32-point upward travel. Freeze the base
        // impact point without an offset so the lane is applied only once.
        let slot = min(3, max(0, number.lane))
        let laneX: CGFloat = includesLane ? [-46, 46, -46, 46][slot] : 0
        let laneY: CGFloat = includesLane ? [0, 0, -76, -76][slot] : 0
        if let anchor = number.normalizedAnchor {
            return CGPoint(x: max(44, min(size.width - 44, anchor.x * size.width + laneX)), y: max(20, min(size.height - 20, anchor.y * size.height + laneY)))
        }
        let formation = enemies ?? session.enemies
        guard let enemyID = number.enemyID else {
            let playerAnchor = playerHealthBarPosition(in: size)
            let playerHealthBarY = playerAnchor.y
            return CGPoint(
                x: max(44, min(size.width - 44, playerAnchor.x + laneX)),
                y: min(
                    max(20, playerHealthBarY + number.kind.verticalOffset + laneY),
                    max(20, size.height - 20)
                )
            )
        }
        guard let enemy = formation.first(where: { $0.id == enemyID }) else {
            return nil
        }
        let aliveEnemies = formation.filter(\.isAlive)
        // Keep lethal-hit numbers visible during the one-second death fade.
        // Unity retains the per-actor anchor while it disappears.
        let index = aliveEnemies.firstIndex(where: { $0.id == enemyID })
            ?? formation.firstIndex(where: { $0.id == enemyID }) ?? 0
        let healthBar: CGPoint
        if usesUnityBattlefield,
           let id = MPCChapterOneBattleIdentity.battleID(for: enemy.id, in: formation),
           let anchor = unityBattleRuntime.healthAnchor(for: id) {
            healthBar = CGPoint(x: anchor.x * size.width, y: anchor.y * size.height + (usesEncoreRevenant ? 0 : 22))
        } else {
            healthBar = enemyHealthBarPosition(
                for: enemy,
                index: index,
                total: aliveEnemies.count,
                in: size
            )
        }
        return CGPoint(
            x: max(44, min(size.width - 44, healthBar.x + laneX)),
            y: min(
                max(20, healthBar.y + number.kind.verticalOffset + laneY),
                max(20, size.height - 20)
            )
        )
    }

    @MainActor
    private func showCombatFloatingNumber(
        _ amount: Int,
        for enemyID: String,
        kind: CombatFloatingNumberKind,
        enemies: [MPCRuntimeEnemy]? = nil
    ) {
        guard amount > 0 else { return }
        var number = CombatFloatingNumber(enemyID: enemyID, amount: amount, kind: kind)
        if healthOverlaySize.width > 0, healthOverlaySize.height > 0,
           let anchor = combatFloatingNumberPosition(number, in: healthOverlaySize, enemies: enemies, includesLane: false) {
            number.normalizedAnchor = CGPoint(x: anchor.x / healthOverlaySize.width, y: anchor.y / healthOverlaySize.height)
        }
        enqueueCombatFloatingNumber(number)
    }

    @MainActor
    private func showPlayerDamageFloatingNumber(_ amount: Int) {
        guard amount > 0 else { return }
        enqueueCombatFloatingNumber(
            CombatFloatingNumber(enemyID: nil, amount: amount, kind: .playerDamage)
        )
    }

    private func showCombatStatus(_ text: String, at enemyID: String?) {
        enqueueCombatFloatingNumber(CombatFloatingNumber(enemyID: enemyID, amount: 0, kind: .status, sourceLabel: text))
    }

    @MainActor
    private func enqueueCombatFloatingNumber(_ input: CombatFloatingNumber) {
        guard !isFastForwardingBattle else { return }
        var number = input
        if number.normalizedAnchor == nil,
           healthOverlaySize.width > 0, healthOverlaySize.height > 0,
           let anchor = combatFloatingNumberPosition(number, in: healthOverlaySize, includesLane: false) {
            number.normalizedAnchor = CGPoint(x: anchor.x / healthOverlaySize.width, y: anchor.y / healthOverlaySize.height)
        }
        let siblings = combatFloatingNumbers.filter { $0.enemyID == number.enemyID && ($0.kind == .status) == (number.kind == .status) }
        // Fade the oldest through the existing removal transition before a
        // fifth label is added. Slots offset the labels so simultaneous hits read.
        if siblings.count >= 4, let oldest = siblings.first {
            withAnimation(.easeOut(duration: 0.10)) {
                combatFloatingNumbers.removeAll { $0.id == oldest.id }
            }
        }
        let occupied = Set(combatFloatingNumbers.filter { $0.enemyID == number.enemyID && ($0.kind == .status) == (number.kind == .status) }.map(\.lane))
        number.lane = (0..<4).first { !occupied.contains($0) } ?? 0
        withAnimation(.easeOut(duration: 0.12)) {
            combatFloatingNumbers.append(number)
        }
        #if DEBUG
        recordFloatingNumberReview(number)
        #endif
        Task { @MainActor [numberID = number.id] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.9)) {
                    guard let index = combatFloatingNumbers.firstIndex(where: { $0.id == numberID }) else { return }
                    combatFloatingNumbers[index].isFloating = true
            }
            try? await Task.sleep(for: .milliseconds(number.kind == .healing ? 2400 : 1200))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                combatFloatingNumbers.removeAll { $0.id == numberID }
            }
        }
    }

    #if DEBUG
    @State private var floatingReviewEvents: [[String: Any]] = []
    private func recordFloatingNumberReview(_ number: CombatFloatingNumber) {
        guard ProcessInfo.processInfo.arguments.contains("--verify-battle-music") else { return }
        floatingReviewEvents.append(["encounter": session.encounter.id, "wave": session.waveIndex,
            "battleTime": battleTime, "target": number.enemyID ?? "player", "amount": number.amount,
            "kind": String(describing: number.kind), "lane": number.lane,
            "anchorAvailable": combatFloatingNumberPosition(number, in: healthOverlaySize) != nil,
            "frozenAnchor": number.normalizedAnchor != nil])
        guard let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? JSONSerialization.data(withJSONObject: ["events": floatingReviewEvents], options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: folder.appendingPathComponent("battle-hit-ui-review.json"))
    }
    #endif

    private func synchronizeBattlePresentationSettings() {
        // The Q30 intro plays at its own pace (its lines are timed in real seconds).
        unityBattleRuntime.send(action: "combat-speed:\(showsQ30AngelIntro ? 1 : battleSpeed)")
        unityBattleRuntime.send(action: "hero-outfit:\((session.loadout.outfit ?? .mistportNight).rawValue)")
        unityBattleRuntime.send(action: "tempo-sample:\(CombatTempoReviewConfiguration.baseline ? "off" : session.encounter.id)")
    }

    private func compactHealthBar(
        value: Int,
        maximum: Int,
        tint: Color,
        condensed: Bool = false,
        crowded: Bool = false,
        temporaryExtension: Bool = false
    ) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.58))
                if temporaryExtension {
                    Rectangle().fill(Color.yellow.opacity(0.25))
                        .frame(width: proxy.size.width / 3)
                        .offset(x: proxy.size.width * 2 / 3)
                }
                Capsule()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.55)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: proxy.size.width * CGFloat(max(0, value)) / CGFloat(max(1, maximum)))
                if temporaryExtension {
                    Rectangle().fill(Color.yellow)
                        .frame(width: max(0, proxy.size.width * (CGFloat(value) / CGFloat(max(1, maximum)) - 2 / 3)), height: 5)
                        .offset(x: proxy.size.width * 2 / 3)
                    Rectangle().fill(Color.white.opacity(0.8)).frame(width: 1).offset(x: proxy.size.width * 2 / 3)
                }
            }.clipShape(Capsule())
        }
        .frame(width: crowded ? 32 : condensed ? 52 : temporaryExtension ? 126 : 84, height: crowded ? 3 : condensed ? 4 : 5)
        .animation(.easeOut(duration: 0.22), value: value)
        .shadow(color: .black.opacity(0.75), radius: 1, y: 1)
    }

    private var unityEnemyTargetHitAreas: some View {
        GeometryReader { proxy in
            let aliveEnemies = session.enemies.filter { $0.isAlive && ($0.contentID != "enemy_resonant_clock_guard_q2_split" || revealedGhostIDs.contains($0.id)) }
            ForEach(Array(aliveEnemies.enumerated()), id: \.element.id) { index, enemy in
                let fallback = chapterOneFormationViewPoint(
                    for: chapterOneFormationSlots(for: aliveEnemies)[index],
                    in: proxy.size
                )
                let anchor = unityBattleEnemyID(for: enemy)
                    .flatMap { unityBattleRuntime.effectAnchor(for: $0) }
                Button {
                    handleEnemyTap(enemy.id)
                } label: {
                    Color.clear
                        .contentShape(Ellipse())
                }
                .buttonStyle(.plain)
                .frame(
                    width: proxy.size.width * 0.30,
                    height: proxy.size.height * 0.30
                )
                .position(
                    x: anchor.map { $0.x * proxy.size.width } ?? fallback.x,
                    y: anchor.map { $0.y * proxy.size.height } ?? fallback.y
                )
                .accessibilityLabel("选择目标 \(MPCChapterOneBattleIdentity.presentationName(contentID: enemy.contentID, encounterID: session.encounter.id, fallback: enemy.name))")
            }
        }
    }

    private func targetSelectionPrompt(detail: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(red: 0.72, green: 0.66, blue: 1.0))
                .symbolEffect(.pulse, options: .repeating.speed(0.72))
            VStack(alignment: .leading, spacing: 1) {
                Text("选择目标")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                Text(detail)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(.black.opacity(0.78), in: Capsule())
        .overlay {
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.68, blue: 1.0).opacity(0.72),
                            Color(red: 0.68, green: 0.38, blue: 1.0).opacity(0.72)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Color(red: 0.42, green: 0.36, blue: 1.0).opacity(0.34), radius: 10)
        .accessibilityLabel("选择(detail)的目标")
    }

    private var battleProgressChip: some View {
        HStack(spacing: 5) {
            Text("CHAPTER I")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(.yellow.opacity(0.92))
            Text("波次 \(session.waveIndex + 1)/\(session.encounter.waves.count)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.black.opacity(0.56), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var playerActor: some View {
        VStack(spacing: 5) {
            Spacer()
            Image(decorative: "FoolCombatTopDownV3")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 180)
                .shadow(color: .cyan.opacity(0.48), radius: 12)
            VStack(spacing: 3) {
                Text("愚者")
                    .font(.caption.bold())
                ProgressView(value: Double(session.playerHP), total: Double(session.playerMaxHP))
                    .tint(.green)
                HStack(spacing: 6) {
                    Text("\(session.playerHP)/\(session.playerMaxHP)")
                    if session.playerShield > 0 {
                        Label("\(session.playerShield)", systemImage: "shield.fill")
                            .foregroundStyle(.cyan)
                    }
                }
                .font(.caption2.bold())
            }
            .padding(8)
            .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var enemyFormation: some View {
        VStack(spacing: 7) {
            ForEach(session.enemies.filter(\.isAlive)) { enemy in
                Button {
                    selectedTargetID = enemy.id
                } label: {
                    VStack(spacing: 3) {
                        Image(decorative: enemyArtName(enemy.contentID))
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: session.enemies.filter(\.isAlive).count > 1 ? 105 : 180)
                            .shadow(color: selectedTargetID == enemy.id ? .purple : .black, radius: 12)
                        Text(MPCChapterOneBattleIdentity.presentationName(contentID: enemy.contentID, encounterID: session.encounter.id, fallback: enemy.name))
                            .font(.caption.bold())
                            .lineLimit(1)
                        if protectedBossTargetLabel(for: enemy) != nil {
                            bossAuthorityTrack
                        } else {
                            ProgressView(value: Double(enemy.hp), total: Double(enemy.maxHP))
                                .tint(.red)
                            if let state = session.foolState(for: enemy.id) {
                                Text("HP \(enemy.hp) · 误认 \(state.illusionStacks) · 错位 \(state.misalignmentStacks)")
                                    .font(.caption2)
                            }
                        }
                    }
                    .padding(7)
                    .background(
                        selectedTargetID == enemy.id ? Color.purple.opacity(0.5) : Color.black.opacity(0.66),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedTargetID == enemy.id ? Color.white.opacity(0.8) : .clear, lineWidth: 2)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(protectedBossTargetLabel(for: enemy)
                    ?? "目标 \(MPCChapterOneBattleIdentity.presentationName(contentID: enemy.contentID, encounterID: session.encounter.id, fallback: enemy.name))，生命 \(enemy.hp)/\(enemy.maxHP)")
            }
        }
    }

    private var combatDock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let start = MPCOrderedSkillRules.pressureStart(mission: session.chapterMissionNumber) {
                Text(battleTime < start ? "\(Int(ceil(start - battleTime)))秒后敌方追逼 · 连招要赶在短窗口内" : "敌方追逼 · 每4秒伤害翻倍，尽快终结")
                    .font(.system(size: 9, weight: .medium)).foregroundStyle(battleTime < start ? .yellow : .orange)
                    .padding(.horizontal, 8)
            }
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(chosenLoopSkills ?? visibleBattleSkills.map(\.id), id: \.self) { skill in
                    Button {
                        if usesManualEmeraldMask && combatIsActive && skill == .maskedWhisper { requestEmeraldMask() }
                        else if usesEncoreBellPrototype && combatIsActive {
                            if skill == .maskedWhisper { summonTimedMasquerade() }
                        } else { toggleLoopSkill(skill) }
                    } label: {
                    Image(decorative: skillCardArtName(skill))
                        .resizable().scaledToFill()
                        .frame(width: (chosenLoopSkills ?? visibleBattleSkills.map(\.id)).count > 4 ? 44 : 58,
                               height: (chosenLoopSkills ?? visibleBattleSkills.map(\.id)).count > 4 ? 65 : 85).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.yellow, lineWidth: 2))
                        .overlay(alignment: .bottom) {
                            Text(skillName(skill)).font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity).padding(.vertical, 4)
                                .background(.black.opacity(0.75)).clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 9, bottomTrailingRadius: 9))
                                .allowsHitTesting(false)
                        }
                        .overlay {
                            if usesEncoreBellPrototype && skill == .maskedWhisper {
                                VStack {
                                    Spacer()
                                    Text(manualMasqueradeStatus)
                                        .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                        .padding(3).background(.black.opacity(0.8))
                                }.allowsHitTesting(false)
                            } else {
                                cooldownOverlay(for: skill)

                            }
                        }
                        // 夺名代签 (final boss, 2026-10-11): the loop passes over this card until the seal
                        // lifts; same clock as the scheduler's `skipping:`.
                        .saturation(session.isFoolSkillSealed(skill, at: battleTime) ? 0.12 : 1)
                        .brightness(session.isFoolSkillSealed(skill, at: battleTime) ? -0.3 : 0)
                        .overlay { if session.isFoolSkillSealed(skill, at: battleTime) { sealedCardMark } }
                        .contentShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(skillName(skill))
                    .accessibilityValue(session.isFoolSkillSealed(skill, at: battleTime) ? "被夺名代签封住" : "")
                    .accessibilityIdentifier("combat-action-" + skill.rawValue)
                    .offset(skill == combatDraggedSkill ? combatDragOffset : .zero)
                    .zIndex(skill == combatDraggedSkill ? 1 : 0)
                    .highPriorityGesture(combatCardDragGesture(for: skill))

                    .overlay {
                        if skill == .maskedWhisper && manualMaskIsReady && combatIsActive {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(red: 1, green: 0.78, blue: 0.34).opacity(session.enemies.contains { $0.isAlive && $0.currentIntent == "charge" } ? 1 : 0.5), lineWidth: 2)
                                .shadow(color: .purple.opacity(0.65), radius: 7)
                                .allowsHitTesting(false)
                        }
                    }
                }
                Spacer(minLength: 0)
                VStack(spacing: 7) {
                    Button { beginSkippingBattle() } label: {
                        Label("跳过战斗", systemImage: "forward.end.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(red: 1, green: 0.84, blue: 0.48))
                            .padding(.horizontal, 7).frame(minHeight: 32)
                            .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 7))
                            .overlay { RoundedRectangle(cornerRadius: 7).stroke(.yellow.opacity(0.4), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSkipBattle)
                    .accessibilityIdentifier("combat-skip-picture")
                basicActionCard("普攻", subtitle: "自动出招", systemImage: "sparkles",
                                artName: "IconBasicAttackFool", tint: .orange,
                                isLocked: false, queuePositions: []) { }
                    .overlay { ClockwiseCardCooldown(now: battleTime, startedAt: basicCooldownStarted, duration: session.tempo?.basicInterval ?? 2.4) }
                }
            }
            .frame(minHeight: 85, alignment: .bottom)
            .padding(.horizontal, 8)
            combatInventoryDock
        }
    }

    @discardableResult
    private func combatCardDragGesture(for skill: FoolSkillID) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                combatDraggedSkill = skill
                combatDragOffset = value.translation
            }
            .onEnded { value in
                defer { combatDraggedSkill = nil; combatDragOffset = .zero }
                let sequence = chosenLoopSkills ?? visibleBattleSkills.map(\.id)
                guard let from = sequence.firstIndex(of: skill), sequence.count > 1 else { return }
                let pitch: CGFloat = (sequence.count > 4 ? 44 : 58) + 7
                let shift = Int((value.translation.width / pitch).rounded())
                let to = min(sequence.count - 1, max(0, from + shift))
                _ = moveCombatCard(skill, to: sequence[to])
            }
    }

    private func moveCombatCard(_ source: FoolSkillID, to target: FoolSkillID) -> Bool {
        let previous = chosenLoopSkills ?? visibleBattleSkills.map(\.id)
        guard session.outcome == .inProgress, source != target,
              let from = previous.firstIndex(of: source), let to = previous.firstIndex(of: target) else { return false }
        var reordered = previous
        reordered.insert(reordered.remove(at: from), at: to)
        if combatIsActive {
            _ = skillScheduler.didReorder(from: previous, to: reordered, at: battleTime)
            actionMessage = "顺序已调整 · 换位卡牌重新冷却"
        }
        chosenLoopSkills = reordered
        session.setContinuousSkillSequence(reordered)
        if !combatIsActive { onSequenceChanged(reordered) }
        return true
    }

    private func cooldownOverlay(for skill: FoolSkillID) -> some View {
        ClockwiseCardCooldown(now: battleTime, startedAt: skillScheduler.startedAt[skill],
                              duration: ContinuousSkillScheduler.duration(for: skill))
    }

    private var ultimateCardStatus: String {
        if session.foolUltimateUsed { return "本场已用" }
        if pendingPlayerImpact?.skill == .namelessStage { return "释放中" }
        if session.playerIsDown { return "主角倒地" }
        if session.isFoolSkillSealed(.namelessStage, at: battleTime) { return "暂被封住" }
        if !combatIsActive { return "战中手动" }
        return requestedUltimate ? "等待释放" : "点击释放"
    }

    private var ultimateCardStatusOverlay: some View {
        VStack(spacing: 4) {
            Text("每场一次")
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 4).padding(.vertical, 2)
                .background(.black.opacity(0.8), in: Capsule())
            Spacer(minLength: 0)
            Text(ultimateCardStatus)
                .font(.system(size: 10, weight: .black))
                .padding(.horizontal, 3).padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.85))
        }
        .foregroundStyle(session.foolUltimateUsed ? .white.opacity(0.75) : .yellow)
        .padding(.top, 4).padding(.bottom, 16)
        .allowsHitTesting(false)
    }

    private func toggleLoopSkill(_ skill: FoolSkillID) {
        if usesManualEmeraldMask && combatIsActive && skill == .maskedWhisper { requestEmeraldMask(); return }
        if usesEncoreBellPrototype && combatIsActive { return }
        guard ownedBattleSkills.contains(where: { $0.id == skill }) else { return }
        if skill == .namelessStage {
            guard combatIsActive, session.outcome == .inProgress, !session.playerIsDown,
                  session.loadout.isUltimateUnlocked, session.canUseFoolSkill(skill),
                  pendingPlayerImpact?.skill != skill else { return }
            requestedUltimate.toggle()
            actionMessage = requestedUltimate ? "终极技能将在当前动作结束后释放" : "已取消终极技能"
            return
        }
        if combatIsActive {
            actionMessage = "战斗中可拖动上排换位；替换技能请在战前完成"
            return
        }
        var skills = chosenLoopSkills ?? visibleBattleSkills.map(\.id)
        if let index = skills.firstIndex(of: skill) { skills.remove(at: index) }
        else if skills.count < campaign.loadoutSlotCapacity { skills.append(skill) }
        else {
            actionMessage = "当前可编排\(campaign.loadoutSlotCapacity)张技能，请先移除一张再替换"
            return
        }
        chosenLoopSkills = skills
        session.setContinuousSkillSequence(skills)
        if !combatIsActive { onSequenceChanged(skills) }
    }

    private var combatInventoryDock: some View {
        VStack(spacing: 5) {
            if isQ1PreludeActive {
                HStack(spacing: 8) {
                    Text("等待获得秘仪卡牌")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .frame(height: 78)
            }
            if session.outcome == .defeat {
                defeatPanel
            } else {
            if session.bossPhase != nil {
                HStack(spacing: 6) {
                    responseButton("闪避", .evasion)
                    responseButton("防护", .protection)
                    responseButton("破意志", .willBreak)
                    responseButton("终结", .fullFinisher)
                }
            }

            if let preview = queuedComboPreview {
                HStack(spacing: 8) {
                    Image(systemName: "theatermasks.fill")
                        .foregroundStyle(Color(red: 0.92, green: 0.67, blue: 0.27))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(preview.title)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                        Text(preview.detail)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Capsule()
                        .fill(LinearGradient(colors: [.purple.opacity(0.15), .yellow.opacity(0.86), .purple.opacity(0.15)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 44, height: 2)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(red: 0.14, green: 0.09, blue: 0.23).opacity(0.82), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.yellow.opacity(0.22), lineWidth: 1))
            }

            if !isQ1PreludeActive {
            if showsCombatInventoryPanel {
            VStack(spacing: 5) {
            if showsCombatSkillShelf {
            VStack(spacing: 0) {
                ScrollViewReader { reader in
                HStack(spacing: 0) {
                    if ownedBattleSkills.count > 5 {
                        Button {
                            if let first = ownedBattleSkills.first {
                                withAnimation { reader.scrollTo(first.id, anchor: .leading) }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 30, height: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).foregroundStyle(.yellow)
                        .accessibilityLabel("查看前面的卡牌")
                    }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 5) {
                        if showsCardComparisonPreview,
                           let skill = MPCChapterOneCatalog.visibleSkills.first(where: { session.loadout.battleSkillIDs.contains($0.id) }) {
                            comparisonUnselectedCard(skill)
                        }
                        ForEach(ownedBattleSkills) { skill in
                            // A tap immediately queues the card; long press
                            // keeps the separate detail presentation.
                            let remaining = session.remainingCooldownActions(for: skill.id)
                            let isTutorialCard = isFirstCardTutorial && firstTutorialCardID == skill.id
                            let isSelectedCard = skill.isUltimate ? requestedUltimate : (chosenLoopSkills ?? visibleBattleSkills.map(\.id)).contains(skill.id)
                            let queueIndex = (chosenLoopSkills ?? visibleBattleSkills.map(\.id)).firstIndex(of: skill.id)
                            Button {
                                toggleLoopSkill(skill.id)
                            } label: {
                                ZStack(alignment: .bottom) {
                                    Image(decorative: skillCardArtName(skill.id))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: combatDockCardWidth, height: combatDockCardHeight)
                                        .clipped()

                                    LinearGradient(
                                        // Keep the card artwork readable. The old
                                        // 0.92 overlay made the entire card look
                                        // black on a real device instead of only
                                        // grounding the label at the bottom.
                                        colors: [.clear, .black.opacity(0.30)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )

                                    // An ultimate is once per battle, not a normal card that
                                    // becomes usable again when its 20-second timer clears.
                                    if skill.isUltimate {
                                        if session.foolUltimateUsed { Color.black.opacity(0.58) }
                                        ultimateCardStatusOverlay
                                    } else {
                                        cooldownOverlay(for: skill.id)
                                    }
                                    if session.isFoolSkillSealed(skill.id, at: battleTime) {
                                        Color.black.opacity(0.5)
                                        sealedCardMark.frame(maxHeight: .infinity, alignment: .center)
                                    }
                                    if session.loadout.relicIDs.contains(EarlyRelicShop.paperweight), queueIndex == 2 {
                                        Text("封")
                                            .font(.system(size: 22, weight: .black, design: .serif))
                                            .foregroundStyle(.yellow.opacity(battleTime >= session.sequenceNineRelics.paperweightReadyAt ? 0.95 : 0.30))
                                            .padding(5)
                                            .background(.purple.opacity(0.72), in: Circle())
                                            .frame(maxHeight: .infinity, alignment: .center)
                                    }

                                    VStack(spacing: 2) {
                                        Text(skill.name)
                                            .font(.system(size: 7, weight: .black))
                                            .lineLimit(1)
                                        if remaining == 0 {
                                            Text(skill.isUltimate ? "终极" : "帷幕技能")
                                                .font(.system(size: 6, weight: .bold))
                                                .foregroundStyle(.white.opacity(0.7))
                                        }
                                    }
                                    .padding(.bottom, 4)
                                }
                                .frame(width: combatDockCardWidth, height: combatDockCardHeight)
                                .background(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    if isTutorialCard && !isSelectedCard {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(red: 1.0, green: 0.78, blue: 0.26).opacity(0.82), lineWidth: 2)
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    if !combatIsActive {
                                    Image(systemName: "viewfinder.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white, .black.opacity(0.78))
                                        .shadow(color: .black.opacity(0.8), radius: 3)
                                        .padding(2)
                                        .contentShape(Circle())
                                        .highPriorityGesture(TapGesture().onEnded { inspectedSkill = skill })
                                    .accessibilityLabel("查看 \(skill.name) 详情")
                                    }
                                }
                                .saturation(skill.isUltimate && session.foolUltimateUsed ? 0.08 : (combatIsActive ? 1 : (remaining > 0 ? 0.08 : (session.canUseFoolSkill(skill.id) ? 1 : 0.15))))
                                .opacity(combatIsActive ? 1 : (remaining > 0 ? 1 : (session.canUseFoolSkill(skill.id) ? 1 : 0.55)))
                                // Once cooldown starts, show only the dark cooldown
                                // state instead of briefly stacking selection glow.
                                .overlay {
                                    if isSelectedCard && remaining == 0 && !combatIsActive {
                                        TutorialCardFocusHalo()
                                            .allowsHitTesting(false)
                                    }
                                }
                                .overlay(alignment: .topLeading) {
                                    if let queueIndex {
                                        Text("\(queueIndex + 1)")
                                            .font(.system(size: 9, weight: .black, design: .rounded))
                                            .foregroundStyle(.black)
                                            .frame(width: 16, height: 16)
                                            .background(
                                                Circle().fill(
                                                    LinearGradient(
                                                        colors: [.white, Color(red: 1.0, green: 0.75, blue: 0.18)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                            )
                                            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1))
                                            .shadow(color: .yellow.opacity(0.75), radius: 7)
                                            .offset(x: 2, y: 2)
                                    }
                                }
                                .overlay(alignment: .top) {
                                    if isFirstCardTutorial && !isSelectedCard && !isTutorialCard {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black.opacity(0.42))
                                    }
                                }
                                .rotationEffect(isSelectedCard ? .degrees(-2.2) : .zero)
                                .offset(y: isSelectedCard ? -5 : .zero)
                                .tutorialButtonEmphasis(isTutorialCard && !isSelectedCard, tint: .yellow)
                            }
                            .buttonStyle(.plain)
                            .zIndex(isSelectedCard ? 100_000 : 100)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.42, maximumDistance: 18)
                                    .onEnded { _ in if !combatIsActive { inspectedSkill = skill } }
                            )
                            .disabled(skill.isUltimate && (!combatIsActive || session.playerIsDown || session.outcome != .inProgress || !session.canUseFoolSkill(skill.id) || pendingPlayerImpact?.skill == skill.id))
                            .accessibilityLabel(queueIndex.map { "第\($0 + 1)张，\(skill.name)卡牌" } ?? "\(skill.name)卡牌，未编排")
                            .accessibilityValue(skill.isUltimate
                                ? "每场一次，\(ultimateCardStatus)"
                                : (remaining > 0 ? "冷却剩余\(remaining)次行动" : "可以使用"))
                            .accessibilityHint(usesManualEmeraldMask && combatIsActive && skill.id == .maskedWhisper ? (isQ4Hound ? "手动展开假面，承接双焰预警后的两颗火球" : "手动释放假面，承接绿焰预警后的大招") : skill.isUltimate ? "战斗中点击释放，每场一次；再次点击可取消尚未开始的释放" : "点击加入或移出行动栏，长按查看卡牌介绍")
                            .id(skill.id)
                        }
                        if showsCardComparisonPreview,
                           let skill = MPCChapterOneCatalog.visibleSkills.first(where: { session.loadout.battleSkillIDs.contains($0.id) }) {
                            comparisonUnselectedCard(skill)
                        }
                    }
                    // Selection changes only transforms the card; it must not
                    // inflate the dock or make the whole card row jump vertically.
                    .padding(.horizontal, isFirstCardTutorial ? 24 : 6)
                    .padding(.top, isFirstCardTutorial ? 18 : 5)
                    .padding(.bottom, 2)
                    .background { CardDockMeasurement(role: "content") }
            }
            .background { CardDockMeasurement(role: "viewport") }
                    if ownedBattleSkills.count > 5 {
                        Button {
                            if let last = ownedBattleSkills.last {
                                withAnimation { reader.scrollTo(last.id, anchor: .trailing) }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .frame(width: 30, height: 44).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).foregroundStyle(.yellow)
                        .accessibilityLabel("查看后面的卡牌")
                    }
                }
                }
            // Keep later cards inside the same viewport as early chapters.
            // The hand scrolls horizontally instead of drawing beyond its panel.
            // Keep a small breathing strip below the reduced cards. The relic
            // section above this row is conditional, so no empty relic row is
            // rendered before Mara has delivered an item.
            .frame(height: 82)
            }
            }
            }
            .padding(4)
            }
            }

        }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Color(red: 0.10, green: 0.08, blue: 0.17), Color(red: 0.025, green: 0.025, blue: 0.055)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(LinearGradient(colors: [.clear, .yellow.opacity(0.7), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                        .padding(.horizontal, 24)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(LinearGradient(colors: [Color(red: 0.78, green: 0.62, blue: 0.34), .purple.opacity(0.25), Color(red: 0.48, green: 0.37, blue: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.55), radius: 12, y: 4)
    }

    private var skipAnimationToggle: some View {
        Button {
            skipsCombatAnimations.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: skipsCombatAnimations ? "checkmark.square.fill" : "square")
                Text("跳过动画")
            }
            .font(.system(size: 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(skipsCombatAnimations ? .yellow : .white.opacity(0.64))
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("跳过战斗动画")
        .accessibilityValue(skipsCombatAnimations ? "已勾选" : "未勾选")
    }

    private func comparisonUnselectedCard(_ skill: MPCSkillContent) -> some View {
        ZStack(alignment: .bottom) {
                Image(decorative: skillCardArtName(skill.id))
                    .resizable()
                    .scaledToFill()
                    .frame(width: combatDockCardWidth, height: combatDockCardHeight)
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.30)], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 2) {
                Text(skill.name)
                    .font(.system(size: 7, weight: .black))
                    .lineLimit(1)
                Text(skill.isUltimate ? "终极" : "帷幕技能")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, 4)
        }
        .frame(width: combatDockCardWidth, height: combatDockCardHeight)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .saturation(0.76)
        .brightness(-0.035)
        .blur(radius: 0.2)
        .opacity(0.90)
    }

    private var defeatPanel: some View {
        EmptyView()
    }

    private func adoptConfiguredSession(_ configuredSession: MPCChapterOneEncounterSession) {
        didSkipBattle = false
        isFastForwardingBattle = false
        _ = session.finishRelicBattle()
        CombatHaptics.shared.cancel()
        var configuredSession = configuredSession
        configuredSession.adoptTempo(CombatTempoReviewConfiguration.profile(configuredSession.encounter.id))
        lightAttackClock = configuredSession.tempo.map(MPCLightAttackClock.init(tempo:))
        lastBattleWallTime = nil
        battleTickRemainder = 0
        battleTime = 0
        sentHeroHasteUntil = 0
        playerHitFlashUntil = 0
        combatDraggedSkill = nil
        combatDragOffset = .zero
        #if DEBUG
        tempoReviewStartedAt = nil
        #endif
        if usesEncoreBellPrototype { configuredSession.prepareEncoreBellPrototype() }
        encoreRingAt = nil
        encoreBell.reset()
        unityBattleRuntime.send(action: "encore-clear")
        skillScheduler = ContinuousSkillScheduler()
        requestedUltimate = false
        requestedEmeraldMask = false
        continuousVictoryReported = false
        victoryPresentationDeadline = nil
        pendingPlayerImpact = nil
        pendingEnemyImpacts.removeAll()
        enemyReadyAt.removeAll()
        q3HuntStart = nil
        q4CycleStart = nil
        session.clearQ4HoundState()
        unityBattleRuntime.send(action: "q4-hound:clear")
        pendingGhostReveals.removeAll()
        revealedGhostIDs.removeAll()
        playerCastReadyAt = 0
        preludeRevealAt = nil
        basicCooldownStarted = nil
        session = configuredSession
        waitsForPostInterventionStart = false
        synchronizeBattleMusic()
        chosenLoopSkills = configuredSession.loadout.normalSkillIDs
        // Starting combat must preserve the target selected during setup.
        if !configuredSession.enemies.contains(where: { $0.id == selectedTargetID && $0.isAlive }) {
            selectedTargetID = Self.defaultTargetID(in: configuredSession.enemies)
        }
        queuedActions.removeAll()
        queuedTargetIDs.removeAll()
        queuedBasicTargetIDs.removeAll()
        pendingTargetSkillID = nil
        pendingBasicTargetCategory = nil
        selectedCardID = nil
        combatFloatingNumbers.removeAll()
        transientEnemyHealth.removeAll()
        isResolvingEnemyTurn = false
        isHoldingQ5VictoryPresentation = false
        syncVisualHealth()
        updateQueuedTargetPresentation()
        // Q30 opens on the angel's cutscene; its end announces the blessings (2026-10-11).
        if battleIsActive { beginQ30AngelIntroIfNeeded(configuredSession) }
        announceFarewellBlessingsIfNeeded(configuredSession)
    }

    /// Q30 离场祝福 (2026-10-10, user): as combat begins, 伊莱娅's blessing and then the
    /// pursuer's gift, each through the signature callout with its one-line effect. After the
    /// angel intro when it plays (2026-10-11).
    private func announceFarewellBlessingsIfNeeded(_ value: MPCChapterOneEncounterSession) {
        guard battleIsActive, !showsQ30AngelIntro, let blessings = value.farewellBlessings,
              announcedFarewellSessionID != value.settlementID else { return }
        announcedFarewellSessionID = value.settlementID
        let cues = [
            SignatureCalloutCue(kicker: "伊莱娅的祝福", title: blessings.hero.name, detail: blessings.hero.effect, hold: 2.2),
            SignatureCalloutCue(kicker: "追索者的赠礼", title: blessings.sovereign.name, detail: blessings.sovereign.effect, hold: 2.2),
        ]
        Task { @MainActor in
            for cue in cues {
                signatureCallout = cue
                try? await Task.sleep(for: .milliseconds(2700))
                if signatureCallout?.id == cue.id { signatureCallout = nil }
            }
        }
    }

    private func restartEncounter() {
        didSkipBattle = false
        isFastForwardingBattle = false
        playerHitFlashUntil = 0
        combatDraggedSkill = nil
        combatDragOffset = .zero
        #if DEBUG
        tempoReviewStartedAt = nil
        #endif
        _ = session.finishRelicBattle()
        isDefeatOverlayVisible = false
        isHoldingQ5VictoryPresentation = false
        battleTime = 0
        sentHeroHasteUntil = 0
        lastBattleWallTime = nil
        battleTickRemainder = 0
        lightAttackClock = initialSession.tempo.map(MPCLightAttackClock.init(tempo:))
        skillScheduler = ContinuousSkillScheduler()
        requestedUltimate = false
        requestedEmeraldMask = false
        continuousVictoryReported = false
        victoryPresentationDeadline = nil
        pendingPlayerImpact = nil
        pendingEnemyImpacts.removeAll()
        enemyReadyAt.removeAll()
        q3HuntStart = nil
        q4CycleStart = nil
        session.clearQ4HoundState()
        unityBattleRuntime.send(action: "q4-hound:clear")
        pendingGhostReveals.removeAll()
        revealedGhostIDs.removeAll()
        playerCastReadyAt = 0
        preludeRevealAt = nil
        basicCooldownStarted = nil
        session = initialSession
        if usesEncoreBellPrototype { session.prepareEncoreBellPrototype() }
        encoreRingAt = nil
        encoreBell.reset()
        unityBattleRuntime.send(action: "encore-clear")
        session.limitConsumables(to: campaign.inventory)
        chosenLoopSkills = []
        hasStartedHeldQ5Preview = false
        selectedTargetID = Self.defaultTargetID(in: initialSession.enemies)
        queuedActions.removeAll()
        queuedTargetIDs.removeAll()
        queuedBasicTargetIDs.removeAll()
        pendingTargetSkillID = nil
        pendingBasicTargetCategory = nil
        combatFloatingNumbers.removeAll()
        actionMessage = "选择目标并使用技能"
        hasStartedOpeningBattle = false
        q1CardsGranted = initialSession.encounter.id != "chapter01_q01_encounter"
        isFirstCardTutorial = false
        q1PreludeRoundsCompleted = 0
        showsQ1GoddessIntervention = false
        // The next Q30 start plays the angel intro again (the standalone preview reuses this session).
        if showsQ30AngelIntro { unityBattleRuntime.send(action: "angel-intro-skip") }
        showsQ30AngelIntro = false
        q30AngelIntroStartedAt = nil
        q30AngelIntroSessionID = nil
        waitsForPostInterventionStart = !showsStandaloneOpeningBattleButton
        onSequenceChanged([])
        onRetrySetup()
        replaceVisualScene(for: initialSession)
        if usesUnityBattlefield {
            UnityBattleRuntime.shared.send(action: "player-reset")
        }
        // Fresh, standing ally rigs for the retry (a fallen rig only answers revive).
        showPartyRigs(rebuild: true)
    }

    private func responseButton(_ title: String, _ response: MPCBossMechanicResponse) -> some View {
        Button(title) {
            var value = session
            if let chosenLoopSkills { value.setContinuousSkillSequence(chosenLoopSkills) }
            let previousWave = value.waveIndex
            try? value.endRound(response: response)
            session = value
            if value.waveIndex != previousWave {
                replaceVisualScene(for: value)
            } else {
                syncVisualHealth()
            }
            actionMessage = value.outcome == .defeat ? "战斗失败 · 可重新挑战" : "敌方行动已经结算"
        }
        .buttonStyle(.borderedProminent)
        .tint(.red.opacity(0.8))
        .disabled(isResolvingEnemyTurn)
    }

    private func toggleQueuedSkill(_ skill: FoolSkillID) {
        guard combatIsActive,
              !locksCardSelectionForPreview,
              !isResolvingEnemyTurn,
              session.canUseFoolSkill(skill) else { return }

        if let index = queuedActions.firstIndex(of: .skill(skill)) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                queuedActions.remove(at: index)
                queuedTargetIDs[skill] = nil
                if pendingTargetSkillID == skill { pendingTargetSkillID = nil }
                if selectedCardID == skill { selectedCardID = nil }
            }
            updateQueuedTargetPresentation()
            updateQueueMessage()
            return
        }

        guard queuedActions.count < actionSlotLimit else {
            actionMessage = "本回合已排入全部 \(actionSlotLimit) 张已装备卡牌"
            return
        }

        // Keep the card visibly selected while the player is choosing its
        // target. Previously selection was derived only from the queued list,
        // so multi-target encounters lost the original tilt/foil treatment
        // during this intermediate state.
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            selectedCardID = skill
        }

        if skill == .paperDouble {
            enqueue(skill, targetID: nil)
            commitFirstTutorialCardIfNeeded()
            return
        }

        let legalTargets = session.enemies.filter(\.isAlive)
        guard let target = legalTargets.first(where: { $0.id == selectedTargetID })
                ?? legalTargets.first else { return }
        selectedTargetID = target.id
        // Queue against the current/default living enemy immediately. Tapping
        // another enemy before commit still retargets this queued skill.
        enqueue(skill, targetID: target.id)
        commitFirstTutorialCardIfNeeded()
    }

    private func commitFirstTutorialCardIfNeeded() {
        // Continuous combat owns all automated casts; never launch the legacy task.
        guard !automatesSkillSequence, combatIsActive, isFirstCardTutorial else { return }
        Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, combatIsActive, !queuedActions.isEmpty else { return }
            commitQueuedTurn()
        }
    }

    private func enqueue(_ skill: FoolSkillID, targetID: String?) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
            queuedActions.append(.skill(skill))
            queuedTargetIDs[skill] = targetID
            pendingTargetSkillID = automatesSkillSequence ? nil : (targetID == nil ? nil : skill)
            selectedCardID = skill
        }
        updateQueueMessage()
        if let targetID,
           let target = session.enemies.first(where: { $0.id == targetID }) {
            actionMessage = "已选目标：\(target.name) · 第 \(queuedActions.count) 个行动已排入"
        }
        updateQueuedTargetPresentation()
    }

    private func enqueueBasicAction(
        _ category: MPCPlayerActionCategory,
        targetID: String? = nil
    ) {
        // Let the player prepare the next action while the enemy presentation
        // is playing. Committing remains disabled until resolution finishes.
        guard combatIsActive,
              !locksCardSelectionForPreview,
              session.outcome == .inProgress else { return }
        if let index = queuedActions.firstIndex(of: .basic(category)) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                _ = queuedActions.remove(at: index)
                queuedBasicTargetIDs[category.rawValue] = nil
            }
            updateQueueMessage()
            updateQueuedTargetPresentation()
            return
        }
        guard queuedActions.count < actionSlotLimit else {
            actionMessage = "本回合已排入全部 \(actionSlotLimit) 张已装备卡牌"
            return
        }
        let resolvedTargetID: String?
        if category == .damage {
            resolvedTargetID = targetID
                ?? selectedTargetID.flatMap { selectedID in
                    session.enemies.contains(where: { $0.id == selectedID && $0.isAlive })
                        ? selectedID
                        : nil
                }
                ?? Self.defaultTargetID(in: session.enemies)
        } else {
            resolvedTargetID = nil
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            queuedActions.append(.basic(category))
            if let resolvedTargetID {
                queuedBasicTargetIDs[category.rawValue] = resolvedTargetID
            }
            pendingBasicTargetCategory = category == .damage ? .damage : nil
        }
        if category == .protection {
            actionMessage = "第 \(queuedActions.count) 个行动：防御"
        } else if let resolvedTargetID,
                  let target = session.enemies.first(where: { $0.id == resolvedTargetID }) {
            actionMessage = "普攻已排入 · 目标 \(target.name)"
        } else {
            actionMessage = "第 \(queuedActions.count) 个行动：普攻"
        }
        updateQueuedTargetPresentation()
    }

    private func resolveQ1PreludeRound(_ category: MPCPlayerActionCategory) {
        guard combatIsActive else { return }
        isResolvingEnemyTurn = true
        var value = session
        let targetID = selectedTargetID ?? value.enemies.first(where: \.isAlive)?.id

        if category == .protection {
            if usesUnityBattlefield, !skipsCombatAnimations { UnityBattleRuntime.shared.send(action: "defend") }
            if !skipsCombatAnimations { visualScene.presentFoolBasicDefense() }
            actionMessage = "防御展开 · 护幕 +100"
        } else {
            if usesUnityBattlefield, !skipsCombatAnimations { UnityBattleRuntime.shared.send(action: "basic") }
            if !skipsCombatAnimations { visualScene.presentFoolBasicAttack() }
            basicCooldownStarted = battleTime
            actionMessage = "普攻出手"
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(skipsCombatAnimations ? 90 : 620))
            guard combatIsActive else {
                isResolvingEnemyTurn = false
                return
            }
            do {
                _ = try value.useBasicAction(category, targetID: targetID)
            } catch {
                actionMessage = errorMessage(error)
                isResolvingEnemyTurn = false
                return
            }
            if category == .damage, let targetID {
                // Skip mode omits the attack strip but keeps an immediate hit
                // reaction, so the zero-damage control-seal probe remains
                // visible and the player can tell the action resolved.
                visualScene.presentChapterOneHitReaction(targetID: targetID, damage: 0)
                actionMessage = "普攻命中 · 0 伤害"
                try? await Task.sleep(for: .milliseconds(skipsCombatAnimations ? 30 : 620))
            }
            guard value.outcome == .inProgress else {
                isResolvingEnemyTurn = false
                return
            }

            let playerHPBeforeEnemyTurn = value.playerHP
            let resolvingEnemyActions = value.announcedIntents.filter {
                !$0.intent.hasPrefix("下一意图：") && $0.intent != "delayed"
            }
            let resolvingEnemyIntents = resolvingEnemyActions.map(\.intent)
            do {
                try value.endRound(response: category == .protection ? .protection : .none)
            } catch {
                actionMessage = errorMessage(error)
                isResolvingEnemyTurn = false
                return
            }

            let received = max(0, playerHPBeforeEnemyTurn - value.playerHP)
            actionMessage = category == .damage
                ? "0 伤害 · 敌方行动"
                : "防御完成 · 敌方行动"
            if !skipsCombatAnimations {
                let unityCompletionToken = usesUnityBattlefield && UnityBattleRuntime.shared.isReady
                    ? UnityBattleRuntime.shared.enemyPresentationCompletionToken
                    : nil
                if usesUnityBattlefield {
                    UnityBattleRuntime.shared.send(action: "enemy")
                }
                // The third visible attack must finish before Miriel enters.
                visualScene.presentChapterOneEnemyTurn(
                    damage: received,
                    intents: resolvingEnemyIntents
                )
                await waitForEnemyPresentationToSettle(
                    unityCompletionToken: unityCompletionToken
                )
            }

            guard combatIsActive else {
                isResolvingEnemyTurn = false
                return
            }

            session = value
            syncVisualHealth()
            let completedPreludeAttacks = q1PreludeRoundsCompleted + 1
            q1PreludeRoundsCompleted = completedPreludeAttacks

            if completedPreludeAttacks >= Self.q1PreludeAttackCount {
                actionMessage = ""
                // The overlay itself fades the battle to black for one second
                // before revealing the guide; mounting it must not add another transition.
                var blackoutTransaction = Transaction(animation: nil)
                blackoutTransaction.disablesAnimations = true
                withTransaction(blackoutTransaction) {
                    showsQ1GoddessIntervention = true
                }
            } else {
                let remainingAttacks = Self.q1PreludeAttackCount - completedPreludeAttacks
                actionMessage = "控制印记仍在 · 还需普攻 \(remainingAttacks) 次"
            }
            isResolvingEnemyTurn = false
        }
    }

    private func basicActionCard(
        _ title: String,
        subtitle: String,
        systemImage: String,
        artName: String?,
        tint: Color,
        isLocked: Bool,
        queuePositions: [Int],
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !isLocked else { return }
            action()
        } label: {
            ZStack(alignment: .bottom) {
                if let artName {
                    Image(decorative: artName)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.32, blue: 0.42), Color(red: 0.02, green: 0.08, blue: 0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: systemImage)
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(.white, tint)
                        .shadow(color: tint.opacity(0.72), radius: 10)
                        .offset(y: -12)
                }

                LinearGradient(colors: [.clear, .black.opacity(0.94)], startPoint: .center, endPoint: .bottom)

                VStack(spacing: 1) {
                    HStack(spacing: 4) {
                        Image(systemName: isLocked ? "lock.fill" : systemImage)
                            .font(.system(size: 7, weight: .black))
                        Text(title)
                            .font(.system(size: 8, weight: .black, design: .rounded))
                    }
                    Text(subtitle)
                        .font(.system(size: 6, weight: .bold, design: .rounded))
                        .foregroundStyle(isLocked ? .white.opacity(0.48) : tint.opacity(0.92))
                        .lineLimit(1)
                }
                .padding(.bottom, 4)
            }
            .foregroundStyle(.white)
            .frame(width: 51, height: 59)
            .background(.black)
            .clipShape(.rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(tint.opacity(isLocked ? 0.24 : 0.92), lineWidth: 1.5)
            }
            .overlay(alignment: .topLeading) {
                if !queuePositions.isEmpty {
                    Text(queuePositions.map(String.init).joined(separator: "·"))
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)
                        .frame(height: 16)
                        .background(tint, in: Capsule())
                        .padding(3)
                }
            }
            .shadow(color: tint.opacity(isLocked ? 0 : 0.28), radius: 9, y: 3)
            .saturation(isLocked ? 0.15 : 1)
            .opacity(isLocked ? 0.52 : 1)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .disabled(isLocked)
        .accessibilityLabel(title)
        .accessibilityValue(isLocked ? "尚未解锁" : subtitle)
    }

    private func basicQueuePositions(for category: MPCPlayerActionCategory) -> [Int] {
        queuedActions.enumerated().compactMap { index, action in
            action == .basic(category) ? index + 1 : nil
        }
    }

    private func handleEnemyTap(_ targetID: String) {
        selectedTargetID = targetID
        if let pendingTargetSkillID {
            // Keep target mode open after the first choice. The same card can
            // be retargeted repeatedly until the player removes the card or
            // commits the queue.
            if queuedSkillIDs.contains(pendingTargetSkillID) {
                queuedTargetIDs[pendingTargetSkillID] = targetID
                actionMessage = session.enemies.first(where: { $0.id == targetID })
                    .map { "已改选目标：\($0.name)" } ?? "已改选目标"
                updateQueuedTargetPresentation()
            } else {
                enqueuePendingSkillTarget(pendingTargetSkillID, targetID: targetID)
            }
        } else if let pendingBasicTargetCategory {
            if queuedActions.contains(.basic(pendingBasicTargetCategory)) {
                queuedBasicTargetIDs[pendingBasicTargetCategory.rawValue] = targetID
                actionMessage = session.enemies.first(where: { $0.id == targetID })
                    .map { "已改选普攻目标：\($0.name)" } ?? "已改选普攻目标"
                updateQueuedTargetPresentation()
            } else {
                enqueuePendingBasicTarget(pendingBasicTargetCategory, targetID: targetID)
            }
        } else if let selectedCardID,
                  selectedCardID != .paperDouble,
                  queuedSkillIDs.contains(selectedCardID) {
            queuedTargetIDs[selectedCardID] = targetID
            if let target = session.enemies.first(where: { $0.id == targetID }) {
                actionMessage = "已改选目标：\(target.name)"
            }
            updateQueuedTargetPresentation()
        } else if queuedActions.contains(.basic(.damage)) {
            // Basic attacks remain optionally targetable after being queued.
            queuedBasicTargetIDs[MPCPlayerActionCategory.damage.rawValue] = targetID
            if let target = session.enemies.first(where: { $0.id == targetID }) {
                actionMessage = "已改选普攻目标：\(target.name)"
            }
            updateQueuedTargetPresentation()
        } else {
            updateQueuedTargetPresentation()
        }
    }

    private func clearQueuedTurn() {
        withAnimation(.easeOut(duration: 0.2)) {
            queuedActions.removeAll()
            queuedTargetIDs.removeAll()
            queuedBasicTargetIDs.removeAll()
            pendingTargetSkillID = nil
            pendingBasicTargetCategory = nil
        }
        updateQueueMessage()
        updateQueuedTargetPresentation()
    }

    private func updateQueueMessage() {
        actionMessage = queuedActions.isEmpty
            ? "选择本回合的行动"
            : "已编排 \(queuedActions.count)/\(actionSlotLimit) 个行动"
    }

    private func updateQueuedTargetPresentation() {
        // Target selection remains in the queue and transparent hit regions.
        // The battlefield must not display selection ornaments or floor rings.
        if usesUnityBattlefield {
            UnityBattleRuntime.shared.setTargetSigils("")
        }
        visualScene.showQueuedTargets([], pendingTargetIDs: [])
    }

    private func enqueuePendingSkillTarget(
        _ skill: FoolSkillID,
        targetID: String
    ) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
            queuedActions.append(.skill(skill))
            queuedTargetIDs[skill] = targetID
            selectedCardID = skill
        }
        if let target = session.enemies.first(where: { $0.id == targetID }) {
            actionMessage = "已选目标：\(target.name) · 可继续改选"
        }
        updateQueueMessage()
        updateQueuedTargetPresentation()
    }

    private func enqueuePendingBasicTarget(
        _ category: MPCPlayerActionCategory,
        targetID: String
    ) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
            queuedActions.append(.basic(category))
            queuedBasicTargetIDs[category.rawValue] = targetID
        }
        if let target = session.enemies.first(where: { $0.id == targetID }) {
            actionMessage = "已选目标：\(target.name) · 普攻可继续改选"
        }
        updateQueueMessage()
        updateQueuedTargetPresentation()
    }

    private static func defaultTargetID(
        in enemies: [MPCRuntimeEnemy]
    ) -> String? {
        let alive = enemies.filter(\.isAlive)
        guard !alive.isEmpty else { return nil }
        // The hound/puppet encounter opens on the immediate attacker, not
        // the fortifying escort. Keep this stable regardless of screen order.
        if alive.contains(where: { $0.contentID == "enemy_calibration_puppet" }),
           let hound = alive.first(where: { $0.contentID == "enemy_clockwork_hound" }) {
            return hound.id
        }
        // Q29's executor is the live authorization source. The boss body is
        // protected and the hollow guard is the lower-pressure escort.
        if alive.contains(where: { $0.contentID == "boss_chronarch_sovereign" }),
           let executor = alive.first(where: { $0.contentID == "enemy_codex_executor" }) {
            return executor.id
        }
        if let guardEnemy = alive.first(where: {
            $0.contentID == "boss_hollow_clock_guard"
                || $0.contentID == "enemy_hollow_clockmaker"
                || $0.contentID == "enemy_hollow_clockmaker_q1"
                || $0.contentID == "enemy_resonant_clock_guard_q2"
        }) {
            return guardEnemy.id
        }
        return alive[alive.count / 2].id
    }

    /// A multi-target skill still has one visual impact anchor. Resolve that
    /// anchor from the live combat state instead of letting a presentation
    /// layer infer it from the whole hit list. This matters when the first
    /// victim dies during a queued action: the spell must remain attached to
    /// an enemy, never fall back to the protagonist or the battlefield center.
    private static func combatVisualTargetID(
        preferredTargetID: String?,
        in enemies: [MPCRuntimeEnemy]
    ) -> String? {
        if let preferredTargetID,
           enemies.contains(where: { $0.id == preferredTargetID && $0.isAlive }) {
            return preferredTargetID
        }
        return enemies.first(where: \.isAlive)?.id
    }

    private func unityBattleEnemyID(
        for enemy: MPCRuntimeEnemy
    ) -> String? {
        MPCChapterOneBattleIdentity.battleID(for: enemy.id, in: session.enemies)
    }

    private func commitQueuedTurn() {
        guard !automatesSkillSequence, combatIsActive,
              !queuedActions.isEmpty,
              !isResolvingEnemyTurn,
              !isHoldingQ5VictoryPresentation,
              !locksCardSelectionForPreview else { return }
        let committedActions = queuedActions
        let committedTargetIDs = queuedTargetIDs
        let committedBasicTargetIDs = queuedBasicTargetIDs
        let completesFirstCardTutorial = isFirstCardTutorial
        queuedActions.removeAll()
        queuedTargetIDs.removeAll()
        queuedBasicTargetIDs.removeAll()
        pendingTargetSkillID = nil
        pendingBasicTargetCategory = nil
        updateQueuedTargetPresentation()
        isResolvingEnemyTurn = true

        if isQ1PreludeActive {
            guard committedActions == [.basic(.damage)] else {
                isResolvingEnemyTurn = false
                actionMessage = "先将普攻排入第①行动位"
                return
            }
            resolveQ1PreludeRound(.damage)
            return
        }

        Task { @MainActor in
            guard combatIsActive else {
                isResolvingEnemyTurn = false
                return
            }
            var value = session
            let previousWave = value.waveIndex
            var messages: [String] = []
            var interruptedByBossPhase = false
            var playerDamageDealt = 0
            var enemyHealingEvents: [(targetID: String, amount: Int)] = []
            var enemyDefenseBoostEvents: [(targetID: String, percentage: Int)] = []
            var enemyActionResolutions: [MPCEnemyActionResolution] = []
            var shouldPresentQ5MaraIntervention = false

            actionLoop: for (actionIndex, action) in committedActions.enumerated() where value.outcome == .inProgress {
                guard combatIsActive else { isResolvingEnemyTurn = false; return }
                let orderText = "\(actionIndex + 1)/\(committedActions.count)"
                switch action {
                case let .basic(category):
                    selectedCardID = nil
                    if category == .protection {
                        actionMessage = "正在执行 \(orderText)：防御"
                        if usesUnityBattlefield, !skipsCombatAnimations { UnityBattleRuntime.shared.send(action: "defend") }
                        if !skipsCombatAnimations { visualScene.presentFoolBasicDefense() }
                        _ = try? value.useBasicAction(.protection)
                        messages.append("防御 · 护幕 +100")
                        try? await Task.sleep(for: .milliseconds(skipsCombatAnimations ? 90 : 720))
                    } else {
                        let queuedTargetID = committedBasicTargetIDs[category.rawValue]
                        let targetID = queuedTargetID.flatMap { candidateID in
                            value.enemies.contains(where: { $0.id == candidateID && $0.isAlive })
                                ? candidateID
                                : nil
                        } ?? Self.defaultTargetID(in: value.enemies)
                        guard let targetID else { continue actionLoop }
                        basicCooldownStarted = battleTime
                        actionMessage = "正在执行 \(orderText)：普攻"
                        if usesUnityBattlefield, !skipsCombatAnimations { UnityBattleRuntime.shared.send(action: "basic") }
                        if !skipsCombatAnimations {
                            visualScene.presentFoolBasicAttack()
                            // TarotNova reaches the target at 0.58s; preserve the
                            // SpriteKit fallback's existing contact timing.
                            try? await Task.sleep(for: .milliseconds(usesUnityBattlefield ? 580 : 360))
                        }
                        do {
                            let damage = try value.useBasicAction(.damage, targetID: targetID)
                            playerDamageDealt += damage
                            presentEnemyImpacts(skill: nil, hits: [(targetID, damage)])
                            if usesUnityBattlefield { showCombatFloatingNumber(damage, for: targetID, kind: .damage) }
                            messages.append("普攻命中 · \(damage) 点伤害")
                            visualScene.presentChapterOneHitReaction(targetID: targetID, damage: damage)
                            selectedTargetID = targetID
                            session = value
                            syncVisualHealth()
                            // Let the 1.65s tarot effect finish before the next action.
                            try? await Task.sleep(for: .milliseconds(skipsCombatAnimations ? 90 : (usesUnityBattlefield ? 1070 : 360)))
                        } catch {
                            messages.append(errorMessage(error))
                        }
                    }

                case let .skill(skill):
                    let targetID: String?
                    if let plannedTargetID = committedTargetIDs[skill],
                       value.enemies.contains(where: { $0.id == plannedTargetID && $0.isAlive }) {
                        targetID = plannedTargetID
                    } else if retargetPolicy(for: skill) == .anyValidEnemy {
                        targetID = value.enemies.first(where: \.isAlive)?.id
                    } else {
                        messages.append("\(skillName(skill))：目标已失效")
                        continue actionLoop
                    }
                    // The core may resolve this card against two enemies, but
                    // the visual cast must use exactly one stable enemy anchor.
                    // Keep the pre-action choice only as a preference; after
                    // resolution we re-select from the enemies that survived
                    // so a lethal first hit cannot leave the effect on a dead
                    // actor or redirect it to the player.
                    let plannedVisualTargetID = Self.combatVisualTargetID(
                        preferredTargetID: targetID,
                        in: value.enemies
                    )
                    selectedTargetID = plannedVisualTargetID
                    selectedCardID = skill
                    let controlSealWasActive = value.controlSealActive
                    // Skipping animation shortens timing only; the skill must
                    // still show its cast and impact, especially Sidestep
                    // Strike's signature hit.
                    if !skipsCombatAnimations, !usesUnityBattlefield {
                        visualScene.presentFoolSkill(
                            FoolSpellVFXSkill.authored(skill),
                            extendedPresentation: true
                        )
                    }
                    do {
                        let bossPhaseBeforeAction = value.bossPhase
                        let preResolutionRecipients = value.enemies.filter(\.isAlive)
                        let result = try value.useFoolSkill(skill, targetID: targetID, usesRealtimeCooldown: automatesSkillSequence)
                        skillScheduler.didCast(skill, at: battleTime)
                        // A multi-target skill can kill the planned anchor as
                        // part of this very resolution. Choose one surviving
                        // enemy for the authored spell impact before Unity is
                        // asked to play it. If both victims die, the Unity
                        // bridge still falls back only across enemy handles.
                        let resolvedVisualTargetID = Self.combatVisualTargetID(
                            preferredTargetID: plannedVisualTargetID,
                            in: value.enemies
                        )
                        selectedTargetID = resolvedVisualTargetID ?? targetID
                        if usesUnityBattlefield, !skipsCombatAnimations {
                            let unityVisualTargetID = (skill == .sidestepStrike ? result.targets.first?.targetID : resolvedVisualTargetID)
                                .flatMap { id in value.enemies.first(where: { $0.id == id }) }
                                .flatMap { unityBattleEnemyID(for: $0) }
                            let targetSuffix = unityVisualTargetID.map { ":\($0)" } ?? ""
                            if skill == .sidestepStrike {
                                let secondaryID = result.targets.dropFirst().first
                                    .flatMap { hit in value.enemies.first { $0.id == hit.targetID } }
                                    .flatMap { unityBattleEnemyID(for: $0) } ?? ""
                                UnityBattleRuntime.shared.send(action: "sidestep-secondary:\(secondaryID)")
                            }
                            // 荒谬归结 lists its tower bystanders too, so the volley visibly lands on them.
                            if skill == .namelessStage || skill == .sidestepStrike || (skill == .absurdFinale && result.targets.count > 1) {
                                let recipients = skill == .namelessStage ? preResolutionRecipients
                                    : result.targets.compactMap { hit in preResolutionRecipients.first { $0.id == hit.targetID } }
                                let ids = recipients.compactMap { unityBattleEnemyID(for: $0) }
                                UnityBattleRuntime.shared.send(action: "skill-targets:\(ids.joined(separator: "|"))")
                            }
                            UnityBattleRuntime.shared.send(
                                action: "skill:\(skill.rawValue)\(targetSuffix)"
                            )
                        }
                        if !skipsCombatAnimations { announceSignatureMove(skill) }
                        let brokeControlSeal = controlSealWasActive && !value.controlSealActive
                        playerDamageDealt += result.targets.reduce(0) { total, hit in
                            total + max(0, hit.damage)
                        }
                        messages.append(
                            brokeControlSeal
                                ? (value.encounter.id == "chapter01_q02_encounter"
                                    ? "寄生护罩破除"
                                    : "控制印记破除 · 保护层消失")
                                : (result.damage > 0
                                    ? "\(skillName(skill))命中 · \(result.damage) 点伤害"
                                    : "\(skillName(skill))已生效")
                        )
                        actionMessage = "正在执行 \(orderText)：\(skillName(skill))"
                        if !skipsCombatAnimations {
                            try? await Task.sleep(for: .milliseconds(850))
                        }
                        presentEnemyImpacts(skill: skill, hits: result.targets.map { ($0.targetID, $0.damage) })
                        if let targetID {
                            if brokeControlSeal {
                                if usesUnityBattlefield {
                                    UnityBattleRuntime.shared.send(action: "guardian-ward-break")
                                }
                                visualScene.presentChapterOneControlSealBreak(targetID: targetID)
                                showCombatFloatingNumber(
                                    result.damage,
                                    for: targetID,
                                    kind: .damage
                                )
                                try? await Task.sleep(for: .milliseconds(skipsCombatAnimations ? 30 : 900))
                            } else {
                                // Damage numbers remain per victim, but the
                                // authored impact/shake/VFX is intentionally
                                // presented once at one still-valid enemy.
                                // Iterating hit reactions here used to let a
                                // disappearing second victim redirect the
                                // effect to an invalid/default presentation
                                // anchor.
                                let visualHit = result.targets.first { hit in
                                    value.enemies.contains { enemy in
                                        enemy.id == hit.targetID && enemy.isAlive
                                    }
                                } ?? result.targets.first(where: { $0.targetID == resolvedVisualTargetID })
                                if let visualHit {
                                    visualScene.presentChapterOneHitReaction(
                                        targetID: visualHit.targetID,
                                        damage: visualHit.damage,
                                        showsDamageNumber: !usesUnityBattlefield
                                    )
                                }
                                for hit in result.targets {
                                    if usesUnityBattlefield {
                                        showCombatFloatingNumber(
                                            hit.damage,
                                            for: hit.targetID,
                                            kind: .damage
                                        )
                                    } else if hit.targetID != visualHit?.targetID {
                                        visualScene.presentChapterOneDamageNumber(
                                            targetID: hit.targetID,
                                            damage: hit.damage
                                        )
                                    }
                                }
                            }
                        }
                        session = value
                        syncVisualHealth()
                        try? await Task.sleep(for: .milliseconds(skipsCombatAnimations ? 90 : 360))

                        if value.bossPhase != bossPhaseBeforeAction, value.bossPhase != nil {
                            let returnedActions = Array(committedActions.dropFirst(actionIndex + 1))
                            queuedActions = returnedActions
                            queuedTargetIDs = committedTargetIDs
                            queuedBasicTargetIDs = committedBasicTargetIDs
                            interruptedByBossPhase = true
                            actionMessage = "首领进入新阶段 · 后续卡牌已退回队列"
                            updateQueuedTargetPresentation()
                            break
                        }
                    } catch {
                        messages.append(errorMessage(error))
                    }
                }
            }
            selectedCardID = nil

            if value.outcome == .inProgress && !interruptedByBossPhase {
                guard combatIsActive else { isResolvingEnemyTurn = false; return }
                messages += value.performCompanionActions(focusTargetID: selectedTargetID).map(\.message)
            }
            if let selectedTargetID,
               !value.enemies.contains(where: { $0.id == selectedTargetID && $0.isAlive }) {
                self.selectedTargetID = Self.defaultTargetID(in: value.enemies)
            }

            let shouldResolveEnemyTurn = value.outcome == .inProgress
                && value.waveIndex == previousWave
                && !interruptedByBossPhase
            let playerHPBeforeEnemyTurn = value.playerHP
            let resolvingEnemyActions = value.announcedIntents.filter {
                !$0.intent.hasPrefix("下一意图：") && $0.intent != "delayed"
            }
            let resolvingEnemyIntents = resolvingEnemyActions.map(\.intent)
            if shouldResolveEnemyTurn {
                let q5PhaseBeforeEnemyTurn = value.paperDoubleTutorialPhase
                let enemyHPBeforeTurn = Dictionary(
                    uniqueKeysWithValues: value.enemies.map { ($0.id, $0.hp) }
                )
                let enemyDefenseBonusBeforeTurn = Dictionary(
                    uniqueKeysWithValues: value.enemies.map {
                        ($0.id, value.enemyDefenseBonusBP(for: $0.id))
                    }
                )
                do {
                    try value.endRound()
                    enemyActionResolutions = value.lastEnemyActionResolutions
                    shouldPresentQ5MaraIntervention =
                        q5PhaseBeforeEnemyTurn != .awaitingMara
                        && value.paperDoubleTutorialPhase == .awaitingMara
                    enemyHealingEvents = value.enemies.compactMap { enemy in
                        let restored = enemy.hp - (enemyHPBeforeTurn[enemy.id] ?? enemy.hp)
                        return restored > 0 ? (enemy.id, restored) : nil
                    }
                    enemyDefenseBoostEvents = value.enemies.compactMap { enemy in
                        let previousBonus = enemyDefenseBonusBeforeTurn[enemy.id] ?? 0
                        let currentBonus = value.enemyDefenseBonusBP(for: enemy.id)
                        guard currentBonus > previousBonus else { return nil }
                        return (enemy.id, currentBonus / 100)
                    }
                    let damage = max(0, playerHPBeforeEnemyTurn - value.playerHP)
                    messages.append(damage > 0 ? "敌方回合 · 受到 \(damage) 点伤害" : "敌方回合 · 攻势被化解")
                } catch {
                    messages.append(errorMessage(error))
                }
            }
            if completesFirstCardTutorial {
                isFirstCardTutorial = false
                onTutorialDismiss()
            }

            if shouldResolveEnemyTurn {
                // Damage numbers belong to the player action that created
                // them. Remove them before the enemy presentation begins so
                // they cannot visually imply that an attacker hurt itself.
                withAnimation(.easeOut(duration: 0.12)) {
                    combatFloatingNumbers.removeAll { $0.kind == .damage }
                }
                // Q4's hound is rendered through Unity's effects-only bridge;
                // that bridge deliberately does not draw the native player
                // damage label. Read the authoritative per-enemy ledger here
                // so a normal 88-point breath is visible on the protagonist,
                // while a Q5 paper-double interception remains damage-free.
                let houndDamage = enemyActionResolutions.reduce(0) { total, resolution in
                    guard resolution.playerDamage > 0,
                          value.enemies.first(where: { $0.id == resolution.enemyID })?.contentID == "enemy_clockwork_hound"
                    else { return total }
                    return total + resolution.playerDamage
                }
                showPlayerDamageFloatingNumber(houndDamage)
                actionMessage = "敌方行动：\(localizedIntent(resolvingEnemyIntents.first ?? "strike"))"
                if !skipsCombatAnimations {
                    if !enemyHealingEvents.isEmpty || !enemyDefenseBoostEvents.isEmpty {
                        let repairedName = enemyHealingEvents.first.flatMap { event in
                            value.enemies.first(where: { $0.id == event.targetID })?.name
                        } ?? "受损目标"
                        actionMessage = "寄忆核心 · 修复\(repairedName)"
                        let corePresentationToken = usesUnityBattlefield && unityBattleRuntime.isReady
                            ? unityBattleRuntime.clockCorePresentationCompletionToken
                            : nil
                        if usesUnityBattlefield {
                            unityBattleRuntime.send(action: "clock-core-cast")
                        }
                        if let corePresentationToken {
                            await unityBattleRuntime.waitForClockCorePresentationCompletion(
                                after: corePresentationToken
                            )
                        } else {
                            try? await Task.sleep(for: .milliseconds(820))
                        }
                        enemyHealingEvents.forEach { event in
                            if let healedEnemy = value.enemies.first(where: { $0.id == event.targetID }) {
                                transientEnemyHealth[event.targetID] = healedEnemy.hp
                            }
                            showCombatFloatingNumber(
                                event.amount,
                                for: event.targetID,
                                kind: .healing
                            )
                            visualScene.presentChapterOneEnemyHealing(
                                targetID: event.targetID,
                                amount: event.amount,
                                delay: 0
                            )
                        }
                        enemyDefenseBoostEvents.forEach { event in
                            showCombatFloatingNumber(
                                event.percentage,
                                for: event.targetID,
                                kind: .defenseUp
                            )
                        }
                        try? await Task.sleep(for: .milliseconds(220))
                    }

                    // Consume the core's authoritative per-enemy ledger in
                    // authored order. Never infer an attacker from a combined
                    // player HP delta: that made dual guards animate together,
                    // stack their numbers, and appear to damage themselves.
                    for enemyAction in enemyActionResolutions {
                        guard enemyAction.healing == 0,
                              enemyAction.defenseBoostBP == 0 else { continue }
                        let nonAttackIntents: Set<String> = [
                            "transfer", "recover", "guard", "fortify",
                            "calibrate", "charge", "delayed"
                        ]
                        guard !nonAttackIntents.contains(enemyAction.intent) else { continue }
                        let actingEnemy = value.enemies.first { $0.id == enemyAction.enemyID }
                        let actingEnemyName = actingEnemy?.name ?? "敌方"
                        actionMessage = "\(actingEnemyName) · \(localizedIntent(enemyAction.intent))"
                        if enemyAction.redirectedByPaperDouble {
                            actionMessage = "纸人代身 · 替主角承受致命攻击"
                            visualScene.presentChapterOnePaperDoubleBreak()
                        }

                        if actingEnemy?.contentID == "enemy_memory_leech_node" {
                            let corePresentationToken = usesUnityBattlefield && unityBattleRuntime.isReady
                                ? unityBattleRuntime.clockCorePresentationCompletionToken
                                : nil
                            if usesUnityBattlefield { unityBattleRuntime.send(action: "clock-core-cast") }
                            visualScene.presentChapterOneEnemyTurn(
                                damage: enemyAction.playerDamage,
                                intents: [enemyAction.intent],
                                actingEnemyIDs: [enemyAction.enemyID]
                            )
                            if let corePresentationToken {
                                await unityBattleRuntime.waitForClockCorePresentationCompletion(
                                    after: corePresentationToken
                                )
                            } else {
                                try? await Task.sleep(for: .milliseconds(820))
                            }
                            continue
                        }

                        let battleEnemyID = actingEnemy.flatMap { unityBattleEnemyID(for: $0) }
                        let unityCompletionToken = usesUnityBattlefield
                            && unityBattleRuntime.isReady
                            && battleEnemyID != nil
                            ? unityBattleRuntime.enemyPresentationCompletionToken
                            : nil
                        if usesUnityBattlefield, let battleEnemyID {
                            unityBattleRuntime.send(action: "enemy:\(battleEnemyID)")
                        }
                        visualScene.presentChapterOneEnemyTurn(
                            damage: enemyAction.playerDamage,
                            intents: [enemyAction.intent],
                            actingEnemyIDs: [enemyAction.enemyID]
                        )
                        await waitForEnemyPresentationToSettle(
                            unityCompletionToken: unityCompletionToken
                        )
                        // Unity normally restores the protagonist after the
                        // paper fragments finish. Reassert that same cleanup
                        // boundary from the authoritative combat host so a
                        // stale embedded presentation cannot leave the paper
                        // silhouette in place on the next Q5 beat.
                        if enemyAction.redirectedByPaperDouble,
                           usesUnityBattlefield,
                           !skipsCombatAnimations {
                            unityBattleRuntime.send(action: "player-reset")
                        }
                    }
                }
            }

            // Do not expose the incremented intent while the previous intent's
            // animation is still playing. Publish the next forecast only once
            // the enemy action has visibly finished.
            session = value
            transientEnemyHealth.removeAll()
            isResolvingEnemyTurn = false
            syncVisualHealth()
            if shouldPresentQ5MaraIntervention {
                actionMessage = ""
                showsQ5MaraIntervention = true
                return
            } else if interruptedByBossPhase {
                actionMessage = "首领进入新阶段 · 后续卡牌已退回队列"
            } else if value.outcome == .victory {
                if value.encounter.id == "chapter01_q05_encounter" {
                    // The core has already applied the second finishing hit.
                    // Hold the defeated state long enough for the player to
                    // see the revenant collapse before the mission closes.
                    isHoldingQ5VictoryPresentation = true
                    actionMessage = "不肯落幕的铃 · 翠焰亡灵返场"
                    try? await Task.sleep(for: .milliseconds(skipsCombatAnimations ? 240 : 1_150))
                    guard !Task.isCancelled else { return }
                    isHoldingQ5VictoryPresentation = false
                }
                actionMessage = "战斗胜利"
                onVictory(value)
            } else if value.outcome == .defeat {
                actionMessage = "战斗失败 · 可重新挑战"
            } else if value.waveIndex != previousWave {
                replaceVisualScene(for: value)
                actionMessage = "新的敌群正在接近"
            } else {
                let received = max(0, playerHPBeforeEnemyTurn - value.playerHP)
                actionMessage = compactRoundResult(dealt: playerDamageDealt, received: received)
            }
        }
    }


    private func compactRoundResult(dealt: Int, received: Int) -> String {
        if dealt == 0, received == 0 {
            return "行动已结算 · 轮到你"
        }
        return "伤害 \(dealt) · 受击 \(received) · 轮到你"
    }

    /// The next player countdown begins after the enemy's attack presentation
    /// finishes, followed by a short visual rest.
    /// SpriteKit-only encounters retain their authored presentation duration;
    /// Unity-backed encounters use the runtime completion event.
    @MainActor
    private func waitForEnemyPresentationToSettle(
        unityCompletionToken: Int?
    ) async {
        if let unityCompletionToken {
            await UnityBattleRuntime.shared.waitForEnemyPresentationCompletion(
                after: unityCompletionToken
            )
        } else {
            try? await Task.sleep(for: .milliseconds(780))
        }
        guard !Task.isCancelled else { return }
        try? await Task.sleep(for: .milliseconds(120))
    }

    private func clearChurchStatusPresentation() {
        guard usesUnityBattlefield else { return }
        unityBattleRuntime.send(action: "church-status:poison:0")
        unityBattleRuntime.send(action: "church-status:empowered:")
        unityBattleRuntime.send(action: "church-status:bindings:")
        unityBattleRuntime.send(action: "church-status:escorted:")
        lastChurchEscortedPresentation = nil
        lastChurchBindingsPresentation = nil
        lastChurchPoisonPresentation = nil
        lastChurchEmpoweredPresentation = nil
    }

    private func syncChurchStatusPresentation() {
        guard usesUnityBattlefield, session.isChurchCombat else { return }
        let poison = session.outcome == .inProgress && (session.churchFinitePoisonActive || session.churchSpittleActive)
        let empowered = session.outcome == .inProgress ? session.enemies.filter {
            $0.isAlive && session.towerEmpoweredEnemyIDs.contains($0.id)
        }.compactMap { unityBattleEnemyID(for: $0) }.sorted().joined(separator: ",") : ""
        let bindings = session.outcome == .inProgress ? session.enemies.filter {
            $0.isAlive && session.churchBindingSourceIDs.contains($0.id)
        }.compactMap { unityBattleEnemyID(for: $0) }.sorted().joined(separator: ",") : ""
        let escorted = session.outcome == .inProgress ? session.enemies.filter {
            $0.isAlive && session.churchEscortedCaptainIDs.contains($0.id)
        }.compactMap { unityBattleEnemyID(for: $0) }.sorted().joined(separator: ",") : ""
        if lastChurchEscortedPresentation != escorted {
            unityBattleRuntime.send(action: "church-status:escorted:" + escorted)
            lastChurchEscortedPresentation = escorted
        }
        if lastChurchBindingsPresentation != bindings {
            unityBattleRuntime.send(action: "church-status:bindings:" + bindings)
            lastChurchBindingsPresentation = bindings
        }
        if lastChurchPoisonPresentation != poison {
            unityBattleRuntime.send(action: "church-status:poison:\(poison ? 1 : 0)")
            lastChurchPoisonPresentation = poison
        }
        if lastChurchEmpoweredPresentation != empowered {
            unityBattleRuntime.send(action: "church-status:empowered:" + empowered)
            lastChurchEmpoweredPresentation = empowered
        }
    }

    private func syncVisualHealth() {
        syncChurchStatusPresentation()
        syncPartyRigPresentation()
        for enemy in session.enemies where enemy.isAlive && enemy.contentID == "enemy_resonant_clock_guard_q2_split" {
            if !revealedGhostIDs.contains(enemy.id) && pendingGhostReveals[enemy.id] == nil {
                pendingGhostReveals[enemy.id] = battleTime + 1.0
            }
        }
        guard !isFastForwardingBattle else { return }
        visualScene.syncChapterOnePresentation(
            playerHP: session.playerHP,
            playerMaxHP: session.playerMaxHP,
            enemyHealth: Dictionary(uniqueKeysWithValues: session.enemies.map {
                ($0.id, (current: $0.hp, maximum: $0.maxHP))
            })
        )
        visualScene.syncChapterOneStatuses(
            enemyStates: session.foolStates,
            paperDoubleCounterReady: false,
            controlSealActive: session.controlSealActive
        )
        if usesUnityBattlefield {
            let payload = session.enemies.compactMap { enemy -> String? in
                guard let unityID = unityBattleEnemyID(for: enemy) else { return nil }
                if enemy.contentID == "enemy_resonant_clock_guard_q2_split" && !revealedGhostIDs.contains(enemy.id) {
                    return "\(unityID)=hidden"
                }
                let remainsInFlight = !enemy.hasDeparted && session.committedEnemyImpacts.contains(enemy.id)
                let disposition = MPCChapterOneBattleIdentity.defeatPresentation(contentID: enemy.contentID, encounterID: session.encounter.id)
                return "\(unityID)=\(enemy.isAlive || remainsInFlight ? "visible" : disposition)"
            }.joined(separator: ";")
            UnityBattleRuntime.shared.setEnemyVisibility(payload)
        }
    }

    private func replaceVisualScene(for session: MPCChapterOneEncounterSession) {
        guard !isFastForwardingBattle else { return }
        clearChurchStatusPresentation()
        let scene = makeChapterOnePresentationScene(
            for: session,
            playerSequence: playerSequence,
            playerPlacement: playerPlacement
        )
        if MPCChapterOneBattleIdentity.supportsUnity(encounterID: session.encounter.id) {
            scene.enableEffectsOnlyOverlay()
        }
        scene.onEnemyTapped = { targetID in
            handleEnemyTap(targetID)
        }
        visualScene = scene
        updateQueuedTargetPresentation()
    }

    private func enemyArtName(_ contentID: String) -> String {
        if let art = chapterOneStoryArt(contentID, encounterID: session.encounter.id) { return art }
        return switch contentID {
        case "enemy_clockwork_hound": "HellHoundIdle"
        case "enemy_memory_leech": "MirrorShadeIdle"
        case "enemy_mirror_double": "CrackedMirrorMarionette"
        case "enemy_calibration_puppet": "ClockGuardCurrent3DPreview"
        case "enemy_lampeater_spawn": "BossLampDevourer"
        // Dedicated executor models are pending; retain a humanoid placeholder.
        case "elite_clock_chaser": "ClockGuardCurrent3DPreview"
        case "elite_memory_trimmer": "CrackedMirrorMarionette"
        case "boss_severian_unified_clock": "BossSeravianUnified"
        default: "ClockGuardCurrent3DPreview"
        }
    }
}

private enum HellHoundFirePhase: String {
    case charge = "hell-hound-charge"
    case breath = "hell-hound-breath"
    case impact = "hell-hound-impact"

    init?(bridgeValue: String) {
        self.init(rawValue: bridgeValue)
    }
}

/// Positions the fire canvas between Unity's live mouth and player anchors.
/// Unity reports each authored animation beat, so the native fire never has
/// to estimate where the hound is in its pounce.
private struct HellHoundFireBreathOverlay: View {
    let sourceViewport: CGPoint?
    let targetViewport: CGPoint?
    let phase: HellHoundFirePhase
    let phaseBeganAt: Date

    var body: some View {
        GeometryReader { geometry in
            let mouth = point(
                from: sourceViewport ?? CGPoint(x: 0.66, y: 0.49),
                in: geometry.size
            )
            let playerImpact = point(
                from: targetViewport ?? CGPoint(x: 0.50, y: 0.72),
                in: geometry.size
            )
            // The reused aura grows away from its pinned base. Start beneath
            // the upper muzzle and end at the hero's lower torso so its
            // visible flame reads as a breath that falls out of the mouth.
            let source = CGPoint(x: mouth.x, y: mouth.y + geometry.size.height * 0.018)
            let target = CGPoint(x: playerImpact.x, y: playerImpact.y + geometry.size.height * 0.030)
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(phaseBeganAt))
                HellHoundFlameProjectile(
                    source: source,
                    target: target,
                    elapsed: elapsed,
                    phase: phase
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func point(from viewport: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(1, max(0, viewport.x)) * size.width,
            y: min(1, max(0, viewport.y)) * size.height
        )
    }
}

/// A three-beat hellfire cast: mouth charge, particle breath and impact burst.
/// The fire uses the same additive glow and ember language as Miriel's aura,
/// but each travelling element is an independent soft flame particle so the
/// cast never resolves into a geometric beam.
private struct HellHoundFlameProjectile: View {
    let source: CGPoint
    let target: CGPoint
    let elapsed: TimeInterval
    let phase: HellHoundFirePhase
    private let palette = MirielFireAuraPalette.hellHound
    private let paleCore = Color(red: 1.0, green: 0.91, blue: 0.56)
    private let effectScale: CGFloat = 1.65

    var body: some View {
        Canvas { context, _ in
            let time = CGFloat(elapsed)
            let lane = lane(from: source, to: target)
            switch phase {
            case .charge:
                drawMouthCharge(
                    context: &context,
                    source: source,
                    forward: lane.forward,
                    normal: lane.normal,
                    time: time
                )
            case .breath:
                drawMouthCharge(
                    context: &context,
                    source: source,
                    forward: lane.forward,
                    normal: lane.normal,
                    time: 0.30 + time
                )
                drawFlameBurst(
                    context: &context,
                    source: source,
                    target: target,
                    time: 0.14 + time
                )
            case .impact:
                drawImpact(context: &context, target: target, time: 0.40 + time)
            }
        }
        .allowsHitTesting(false)
    }

    private func lane(from start: CGPoint, to end: CGPoint) -> (forward: CGPoint, normal: CGPoint, length: CGFloat) {
        let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
        let length = max(CGFloat(1), sqrt(delta.x * delta.x + delta.y * delta.y))
        let forward = CGPoint(x: delta.x / length, y: delta.y / length)
        return (forward, CGPoint(x: -forward.y, y: forward.x), length)
    }

    private func easeOut(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return 1 - pow(1 - t, 3)
    }

    private func easeInOut(_ value: CGFloat) -> CGFloat {
        let t = min(1, max(0, value))
        return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    private func sine(_ value: CGFloat) -> CGFloat {
        CGFloat(sin(Double(value)))
    }

    private func cosine(_ value: CGFloat) -> CGFloat {
        CGFloat(cos(Double(value)))
    }

    private func flightPoint(_ progress: CGFloat, source: CGPoint, target: CGPoint, normal: CGPoint) -> CGPoint {
        let clamped = min(1, max(0, progress))
        let line = CGPoint(
            x: source.x + (target.x - source.x) * clamped,
            y: source.y + (target.y - source.y) * clamped
        )
        let downwardArc = sine(clamped * .pi) * 24
        return CGPoint(
            x: line.x + normal.x * 0,
            y: line.y + downwardArc + normal.y * 0
        )
    }

    private func ellipsePath(center: CGPoint, length: CGFloat, width: CGFloat, angle: CGFloat) -> Path {
        let local = Path(ellipseIn: CGRect(
            x: -length / 2,
            y: -width / 2,
            width: length,
            height: width
        ))
        return local
            .applying(CGAffineTransform(rotationAngle: angle))
            .applying(CGAffineTransform(translationX: center.x, y: center.y))
    }

    private func drawRadialFire(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        opacity: CGFloat,
        blur: CGFloat
    ) {
        let path = Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        let gradient = Gradient(colors: [
            paleCore.opacity(Double(opacity)),
            palette.core.opacity(Double(opacity * 0.94)),
            palette.brightFlame.opacity(Double(opacity * 0.74)),
            palette.outerFlame.opacity(Double(opacity * 0.38)),
            Color.clear
        ])
        context.drawLayer { glow in
            glow.addFilter(.blur(radius: blur))
            glow.blendMode = .plusLighter
            glow.fill(
                path,
                with: .radialGradient(
                    gradient,
                    center: center,
                    startRadius: 1,
                    endRadius: radius * 1.16
                )
            )
        }
        context.blendMode = .plusLighter
        context.fill(
            path,
            with: .radialGradient(
                gradient,
                center: center,
                startRadius: 1,
                endRadius: radius
            )
        )
    }

    private func drawFlamePuff(
        context: inout GraphicsContext,
        center: CGPoint,
        forward: CGPoint,
        length: CGFloat,
        width: CGFloat,
        opacity: CGFloat,
        isHot: Bool
    ) {
        let angle = CGFloat(atan2(Double(forward.y), Double(forward.x)))
        let outer = ellipsePath(center: center, length: length, width: width, angle: angle)
        let outerGradient = Gradient(colors: [
            palette.outerFlame.opacity(Double(opacity * 0.74)),
            palette.middleFlame.opacity(Double(opacity * 0.64)),
            palette.brightFlame.opacity(Double(opacity * 0.42)),
            Color.clear
        ])
        context.blendMode = .normal
        context.fill(
            outer,
            with: .radialGradient(
                outerGradient,
                center: center,
                startRadius: 1,
                endRadius: length * 0.64
            )
        )
        context.drawLayer { glow in
            glow.addFilter(.blur(radius: width * 0.48))
            glow.blendMode = .plusLighter
            glow.fill(
                outer,
                with: .radialGradient(
                    outerGradient,
                    center: center,
                    startRadius: 1,
                    endRadius: length * 0.68
                )
            )
        }

        let inner = ellipsePath(
            center: center,
            length: length * 0.63,
            width: width * 0.52,
            angle: angle
        )
        let innerGradient = Gradient(colors: [
            (isHot ? paleCore : palette.core).opacity(Double(opacity * (isHot ? 0.86 : 0.61))),
            palette.coreMiddle.opacity(Double(opacity * 0.78)),
            palette.brightFlame.opacity(Double(opacity * 0.42)),
            Color.clear
        ])
        context.blendMode = .plusLighter
        context.fill(
            inner,
            with: .radialGradient(
                innerGradient,
                center: center,
                startRadius: 1,
                endRadius: length * 0.38
            )
        )
    }

    private func drawMouthCharge(
        context: inout GraphicsContext,
        source: CGPoint,
        forward: CGPoint,
        normal: CGPoint,
        time: CGFloat
    ) {
        let progress = easeOut(time / 0.17)
        guard progress > 0 else { return }
        let pulse = 1 + sine(time * 42) * 0.08
        let center = CGPoint(x: source.x + forward.x * 10, y: source.y + forward.y * 10)
        drawRadialFire(
            context: &context,
            center: center,
            radius: (20 + progress * 31) * pulse * effectScale,
            opacity: progress * 0.90,
            blur: 12 * effectScale
        )

        context.blendMode = .plusLighter
        for index in 0..<3 {
            let ringProgress = (CGFloat(index) * 0.31 + time * 1.9)
                .truncatingRemainder(dividingBy: 1)
            let radius = (15 + ringProgress * 39) * effectScale
            context.stroke(
                ellipsePath(
                    center: center,
                    length: radius * 2,
                    width: radius * 0.76,
                    angle: CGFloat(atan2(Double(forward.y), Double(forward.x)))
                ),
                with: .color(palette.brightFlame.opacity(Double(progress * 0.54))),
                style: StrokeStyle(lineWidth: 1.5)
            )
        }
        for index in 0..<20 {
            let seed = CGFloat(index) * 2.41
            let orbit = (17 + CGFloat(index % 5) * 5 + progress * 18) * effectScale
            let angle = seed + time * (6.8 + CGFloat(index % 3))
            let point = CGPoint(
                x: center.x + cosine(angle) * orbit + forward.x * 10,
                y: center.y + sine(angle) * orbit * 0.62 + forward.y * 10
            )
            let radius = (1.1 + CGFloat(index % 3) * 0.7) * effectScale
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .color((index % 3 == 0 ? palette.coreMiddle : palette.ember)
                    .opacity(Double(progress * 0.76)))
            )
        }
    }

    private func drawFlameBurst(
        context: inout GraphicsContext,
        source: CGPoint,
        target: CGPoint,
        time: CGFloat
    ) {
        let burst = easeInOut((time - 0.14) / 0.26)
        guard burst > 0 else { return }
        let fade = 1 - min(1, max(0, (time - 0.40) / 0.22))
        let lane = lane(from: source, to: target)

        for index in 0..<52 {
            let seed = CGFloat(index) * 1.618
            let stagger = CGFloat(index % 13) * 0.038
            let travel = min(1, max(0, (burst - stagger) / max(0.12, 1 - stagger)))
            guard travel > 0 else { continue }
            let lateral = sine(seed * 1.37 + time * (7 + CGFloat(index % 4)))
                * (5 + travel * (22 + CGFloat(index % 5) * 7)) * effectScale
            let base = flightPoint(travel, source: source, target: target, normal: lane.normal)
            let center = CGPoint(
                x: base.x + lane.normal.x * lateral,
                y: base.y + lane.normal.y * lateral
            )
            let distortedForward = CGPoint(
                x: lane.forward.x + lane.normal.x * sine(seed) * 0.30,
                y: lane.forward.y + lane.normal.y * sine(seed) * 0.30
            )
            let forward = self.lane(from: .zero, to: distortedForward).forward
            let length = (15 + CGFloat(index % 5) * 4 + (1 - travel) * 12) * effectScale
            let opacity = (0.18 + CGFloat(index % 4) * 0.08)
                * (0.62 + (1 - travel) * 0.38)
                * fade
            drawFlamePuff(
                context: &context,
                center: center,
                forward: forward,
                length: length,
                width: length * (0.46 + CGFloat(index % 3) * 0.05),
                opacity: opacity,
                isHot: index % 11 == 0
            )
        }

        let head = flightPoint(burst, source: source, target: target, normal: lane.normal)
        for index in 0..<12 {
            let angle = CGFloat(index) / 12 * .pi * 2 + time * 6.5
            let spread = (8 + CGFloat(index % 4) * 6) * effectScale
            let center = CGPoint(
                x: head.x + cosine(angle) * spread,
                y: head.y + sine(angle) * spread
            )
            let forward = self.lane(
                from: .zero,
                to: CGPoint(
                    x: lane.forward.x + lane.normal.x * sine(angle) * 0.35,
                    y: lane.forward.y + lane.normal.y * sine(angle) * 0.35
                )
            ).forward
            drawFlamePuff(
                context: &context,
                center: center,
                forward: forward,
                length: (24 + CGFloat(index % 3) * 7) * effectScale,
                width: (14 + CGFloat(index % 2) * 5) * effectScale,
                opacity: 0.42 * fade,
                isHot: index % 4 == 0
            )
        }
        drawRadialFire(
            context: &context,
            center: head,
            radius: (16 + sine(time * 35) * 2) * effectScale,
            opacity: 0.34 * fade,
            blur: 6 * effectScale
        )
    }

    private func drawImpact(context: inout GraphicsContext, target: CGPoint, time: CGFloat) {
        let impact = easeOut((time - 0.40) / 0.22)
        guard impact > 0 else { return }
        let fade = 1 - impact
        drawRadialFire(
            context: &context,
            center: target,
            radius: (27 + impact * 78) * effectScale,
            opacity: 0.90 * fade,
            blur: 16 * effectScale
        )

        context.blendMode = .plusLighter
        for index in 0..<2 {
            let radius = (28 + impact * (42 + CGFloat(index) * 25)) * effectScale
            context.stroke(
                Path(ellipseIn: CGRect(
                    x: target.x - radius,
                    y: target.y - radius * 0.50,
                    width: radius * 2,
                    height: radius
                )),
                with: .color((index == 0 ? palette.coreMiddle : palette.brightFlame)
                    .opacity(Double(fade * (0.78 - CGFloat(index) * 0.25)))),
                style: StrokeStyle(lineWidth: 2.1 - CGFloat(index) * 0.55)
            )
        }
        for index in 0..<30 {
            let angle = CGFloat(index) * .pi * 2 / 30 + 0.19
            let distance = impact * (32 + CGFloat(index % 6) * 12) * effectScale
            let point = CGPoint(
                x: target.x + cosine(angle) * distance,
                y: target.y + sine(angle) * distance * 0.74
            )
            let radius = (1.5 + CGFloat(index % 4) * 0.8) * effectScale
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - radius,
                    y: point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .color((index % 3 == 0 ? palette.coreMiddle : palette.ember)
                    .opacity(Double(fade * 0.82)))
            )
        }
        for index in 0..<14 {
            let angle = CGFloat(index) / 14 * .pi * 2 + 0.31
            let distance = (16 + impact * (14 + CGFloat(index % 4) * 8)) * effectScale
            let center = CGPoint(
                x: target.x + cosine(angle) * distance,
                y: target.y + sine(angle) * distance * 0.75
            )
            let forward = lane(from: target, to: center).forward
            drawFlamePuff(
                context: &context,
                center: center,
                forward: forward,
                length: (18 + CGFloat(index % 3) * 5) * effectScale,
                width: (10 + CGFloat(index % 2) * 4) * effectScale,
                opacity: fade * 0.46,
                isHot: index % 5 == 0
            )
        }
    }
}

struct ChapterSkillDetailSheet: View {
    let skill: MPCSkillContent

    var body: some View {
        GameArtPage(title: skill.name, subtitle: skill.isUltimate ? "终极技能 · 秘仪档案" : "帷幕技能 · 秘仪档案", closeTitle: "收起") {
            Image(decorative: skillCardArtName(skill.id))
                .resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 190)
                .shadow(color: .purple.opacity(0.22), radius: 12, y: 4)
            GroupBox("技能效果") { Text(skill.summary).font(.body).lineSpacing(6).frame(maxWidth: .infinity, alignment: .leading) }
            if !skill.tags.isEmpty {
                Text(skill.tags.joined(separator: "  ·  ")).font(.subheadline.bold()).foregroundStyle(GameArt.ink)
            }
        }
    }
}

private struct ChapterRelicDetailSheet: View {
    let relic: MPCRelicContent

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if relic.id == "relic_paper_raincoat" {
                    Image(decorative: "IconRelicPaperDouble")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 112)
                } else {
                    Image(systemName: "seal.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Color(red: 0.50, green: 0.35, blue: 0.72))
                        .frame(width: 88, height: 112)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(relic.name)
                        .font(.title3.bold())
                    Text("遗落物")
                        .font(.caption.bold())
                        .foregroundStyle(.purple)
                    Text(relic.buildDirection)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("效果")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(relic.mechanism)
                    .font(.body)
                Text("代价：\(relic.cost)")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Text(relic.story)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(22)
    }
}

private func skillCardArtName(_ skillID: FoolSkillID) -> String {
        if skillID.isOrderedOrdinary { return skillID.orderedCardAssetName }
        return switch skillID {
        case .maskedWhisper: "IconSkillDangerPremonition"
        case .paperDouble: "IconSkillPaperDouble"
        default: "IconSkillOmenRecord"
        }
}

@MainActor
private func makeChapterOnePresentationScene(
    for session: MPCChapterOneEncounterSession,
    playerSequence: Int,
    playerPlacement: ChapterOnePlayerPlacement = .standard
) -> DungeonScene {
    let visibleEnemies = Array(session.enemies.filter(\.isAlive).prefix(3))
    let formationSlots = chapterOneFormationSlots(for: visibleEnemies)
    let spawns = visibleEnemies.enumerated().map { index, enemy in
        let kind = presentationEnemyKind(enemy.contentID)
        let position = chapterOneFormationScenePoint(
            for: formationSlots[index],
            in: CGSize(width: 430, height: 932)
        )
        let isBoss = enemy.contentID == "boss_severian_unified_clock"
            || enemy.contentID == "boss_hollow_clock_guard"
        let isElite = enemy.contentID.hasPrefix("elite_")
        return DungeonEnemySpawn(
            id: enemy.id,
            title: MPCChapterOneBattleIdentity.presentationName(contentID: enemy.contentID, encounterID: session.encounter.id, fallback: enemy.name),
            kind: kind,
            position: position,
            // CombatCore owns real HP. A high presentation HP prevents the
            // renderer's legacy damage model from removing authored actors.
            maxHealth: enemy.maxHP,
            attackDamage: enemy.attack,
            movementSpeed: 0,
            attackRange: 0,
            telegraphDuration: 1,
            rank: isBoss ? .boss : (isElite ? .elite : .normal),
            artworkOverride: chapterOneStoryArt(enemy.contentID, encounterID: session.encounter.id)
        )
    }
    let level = DungeonLevel(
        id: "chapter-one-\(session.encounter.id)-\(session.waveIndex)",
        title: session.encounter.name,
        subtitle: "第一章 · 愚者完整体验",
        artName: "SceneClockDistrictV2",
        sceneSize: CGSize(width: 430, height: 932),
        spawnPoint: playerPlacement.scenePoint(in: CGSize(width: 430, height: 932)),
        walkablePolygon: [
            CGPoint(x: 24, y: 128), CGPoint(x: 406, y: 128),
            CGPoint(x: 330, y: 690), CGPoint(x: 54, y: 690)
        ],
        obstacles: [],
        enemies: spawns
    )
    let fool = GameContent.pathways.first(where: { $0.id == .fool }) ?? GameContent.pathways[0]
    return DungeonScene(
        level: level,
        path: fool,
        skills: DungeonSkillCatalog.skills(for: fool),
        presentationOnly: true,
        playerSequence: playerSequence,
        playerPlacement: playerPlacement
    )
}

private enum ChapterOneFormationSlot {
    case frontLeft
    case frontCenter
    case frontRight
    case rearLeft
    case rearCenter
    case rearRight
}

/// Clock Plaza is the native renderer's reference formation. Every model uses
/// one of these slots; model-specific code may change scale/orientation but
/// must never add a positional correction.
private func chapterOneFormationScenePoint(
    for slot: ChapterOneFormationSlot,
    in size: CGSize
) -> CGPoint {
    let normalized: CGPoint = switch slot {
    case .frontLeft: CGPoint(x: 0.327, y: 0.531)
    case .frontCenter: CGPoint(x: 0.500, y: 0.531)
    case .frontRight: CGPoint(x: 0.673, y: 0.531)
    case .rearLeft: CGPoint(x: 0.315, y: 0.572)
    case .rearCenter: CGPoint(x: 0.500, y: 0.572)
    case .rearRight: CGPoint(x: 0.685, y: 0.572)
    }
    return CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
}

private func chapterOneFormationViewPoint(
    for slot: ChapterOneFormationSlot,
    in size: CGSize
) -> CGPoint {
    let scenePoint = chapterOneFormationScenePoint(for: slot, in: size)
    return CGPoint(x: scenePoint.x, y: size.height - scenePoint.y)
}

private func chapterOneFormationSlots(
    for enemies: [MPCRuntimeEnemy]
) -> [ChapterOneFormationSlot] {
    guard enemies.count > 1 else {
        return enemies.isEmpty ? [] : [.frontCenter]
    }

    let supportIDs: Set<String> = [
        "enemy_memory_leech_node",
        "enemy_memory_leech"
    ]
    if enemies.count == 2,
       let supportIndex = enemies.firstIndex(where: { supportIDs.contains($0.contentID) }) {
        return enemies.indices.map {
            $0 == supportIndex ? .rearLeft : .frontCenter
        }
    }

    if enemies.count == 3,
       let supportIndex = enemies.firstIndex(where: { supportIDs.contains($0.contentID) }) {
        var frontIndex = 0
        return enemies.indices.map { index in
            if index == supportIndex { return .rearCenter }
            defer { frontIndex += 1 }
            return frontIndex == 0 ? .frontLeft : .frontRight
        }
    }

    let ordered: [ChapterOneFormationSlot] = [
        .frontCenter,
        .frontLeft,
        .frontRight,
        .rearCenter,
        .rearLeft,
        .rearRight
    ]
    return enemies.indices.map { ordered[min($0, ordered.count - 1)] }
}

private func presentationEnemyKind(_ contentID: String) -> DungeonEnemyKind {
    switch contentID {
    case "enemy_clockwork_rat": .saltCrystalGnawer
    case "enemy_memory_leech_node": .reversePumpHeart
    case "boss_hollow_clock_guard": .hollowClockGuard
    case "enemy_hollow_clockmaker", "enemy_hollow_clockmaker_q1", "enemy_resonant_clock_guard_q2": .hollowClockGuard
    case "enemy_clockwork_hound": .gearHound
    case "enemy_memory_leech": .saltWraith
    case "enemy_mirror_double": .mirrorShade
    case "enemy_calibration_puppet": .hollowClockGuard
    case "enemy_lampeater_spawn": .lampDevourer
    case "elite_clock_chaser": .hollowClockGuard
    case "elite_memory_trimmer": .crackedMirrorMarionette
    case "boss_severian_unified_clock": .seravianUnified
    default: .gearHound
    }
}

private func localizedIntent(_ intent: String, enemyName: String? = nil) -> String {
    let minionNames: [String: String] = [
        "tower_copperback_first": "铜甲震",
        "tower_copperback_second": "掀甲崩",
        "tower_copperback_charge": "压甲蓄势",
        "tower_copperback_charge2": "侧背锁肩",
        "tower_brute_first": "赤拳灼击",
        "tower_brute_second": "双拳坠焰",
        "tower_brute_charge": "收拳蓄焰",
        "tower_brute_charge2": "举臂聚焰",
        "tower_veil_first": "绯刃",
        "tower_veil_second": "交幕裁切",
        "tower_veil_charge": "勾爪织咒",
        "tower_veil_charge2": "交臂张幕",
        "tower_throat_first": "金喉声弹",
        "tower_throat_second": "扁波裂鸣",
        "tower_throat_charge": "鼓囊蓄声",
        "tower_throat_charge2": "蹲身压鸣",
        "tower_moonfang_first": "月牙噬",
        "tower_moonfang_second": "扫月",
        "tower_moonfang_charge": "伏身蓄咬",
        "tower_moonfang_charge2": "转腰蓄尾",
    ]
    if let name = minionNames[intent] { return name }
    if intent == "memory_breath", enemyName == "翠焰亡灵" { return "翠毒漫天" }
    return [
        "q4_probe": "试探火球", "q4_flame_first": "追索双焰·一", "q4_flame_second": "追索双焰·二", "strike": "攻击", "guard": "架起防御", "charge": "蓄力", "emerald_burst": "返场毒爆",
        "pounce": "扑击", "recover": "恢复", "parasite": "记忆寄生",
        "transfer": "转存记忆", "memory_strike": "记忆冲击", "bite": "撕咬", "scavenge": "搬运齿片",
        "hunt": "认名锁定", "memory_breath": "冥火喷吐", "memory_bite": "夺忆撕咬", "feint": "佯攻",
        "real_strike": "真实一击", "fortify": "加固", "calibrate": "校准",
        "slam": "重砸", "dim": "熄灯", "hide_minor_intent": "隐藏意图", "calibration": "准备校正",
        "thirteenth_charge": "校正重击蓄力", "trim_buff": "裁剪增益",
        "shear": "剪切", "archive": "归档", "unified_moment": "归一时刻",
        "thirteenth_bell": "第十三声"
    ][intent, default: intent]
}

private func skillName(_ id: FoolSkillID) -> String {
    MPCChapterOneCatalog.visibleSkills.first(where: { $0.id == id })?.name ?? id.rawValue
}

private func errorMessage(_ error: Error) -> String {
    switch error {
    case FoolComboError.requiresFourIllusions: "需要目标达到4层误认"
    case FoolBattleError.ultimateAlreadyUsed: "终极技能每场战斗只能使用一次"
    case MPCEncounterRuntimeError.skillOnCooldown(_, let remaining): "技能还需等待\(remaining)次行动"
    case MPCEncounterRuntimeError.skillNotEquipped: "该技能未装备"
    case MPCEncounterRuntimeError.invalidTarget: "请选择一个存活目标"
    case MPCEncounterRuntimeError.noConsumableRemaining: "该消耗品已经用完"
    default: "行动无法执行"
    }
}

private func localizedTag(_ tag: String) -> String {
    [
        "intent": "意图", "guard": "防护", "evasion": "闪避", "focus_fire": "集火",
        "will_break": "破意志", "armor": "护甲", "multi_target": "多目标", "cooldown_hold": "保留冷却",
        "elite": "精英", "dispel": "驱散", "timeline": "时间轴", "boss": "首领",
        "phase": "阶段", "finisher": "终结"
    ][tag, default: tag]
}

private func localizedRole(_ role: MPCCompanionRole) -> String {
    switch role {
    case .protector: "守护"
    case .healer: "治疗"
    case .construct: "构装"
    }
}

private func localizedTactic(_ mode: MPCPartyTacticMode) -> String {
    switch mode {
    case .balanced: "均衡"
    case .focusFire: "集火"
    case .defensive: "防守"
    case .comboSupport: "连段支援"
    case .conserve: "保留资源"
    }
}

private func localizedRitual(_ ritual: MPCChapterOneRitual) -> String {
    switch ritual {
    case .observe: "观测仪式 · 额外揭示意图"
    case .paperWard: "纸幕仪式 · 初始护盾"
    case .borrowedSecond: "借秒仪式 · 首次冷却缩短"
    }
}

private extension View {
    func tutorialWashed(_ isActive: Bool) -> some View {
        // Rectangular wash layers made the battlefield look like it was under
        // a large translucent panel and could intercept controls. Onboarding
        // now relies on target-button emphasis instead.
        self
    }

    func mistportOrnateFramePanel(cornerRadius: CGFloat = 20) -> some View {
        background {
            GeometryReader { proxy in
                Image("BattleDockFrame")
                    .resizable()
                    // Stretch to the shallow dock ratio so the supplied frame
                    // keeps both its upper and lower ornaments visible.
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.38).opacity(0.82),
                            Color(red: 0.62, green: 0.30, blue: 0.08).opacity(0.70),
                            Color(red: 1.0, green: 0.92, blue: 0.62).opacity(0.46)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.15
                )
        }
        .shadow(color: Color(red: 0.28, green: 0.08, blue: 0.02).opacity(0.56), radius: 14, y: 5)
    }
}

extension MPCChapterOneEncounterSession: @retroactive Identifiable {
    public var id: String { encounter.id }
}

struct ChapterOneBattleSetupOverlay: View {
    let availableSkills: [MPCSkillContent]
    let relics: [MPCRelicContent]
    @Binding var selectedSkillIDs: [FoolSkillID]
    let requiresFirstReorder: Bool
    let slotCapacity: Int
    @Binding var hasCompletedFirstReorder: Bool
    let usesEarlyTutorialLayout: Bool
    let showsStartTutorialHint: Bool
    let onStart: () -> Void
    @State private var draggedSkillID: FoolSkillID?
    @State private var dragStartIndex: Int?

    /// Playtest 2026-10-04: an empty sequence fought with basic attacks
    /// only and nothing said so. Fill it in the listed order instead.
    private func startFillingEmptySequence() {
        guard !startIsDisabled else { return }
        if selectedSkillIDs.isEmpty {
            selectedSkillIDs = Array(availableSkills.map(\.id).prefix(slotCapacity))
        }
        onStart()
    }
    @State private var insertionIndex: Int?
    @State private var dragTranslation: CGSize = .zero
    @State private var dragHighlightPhase = false
    @State private var inspectedSkill: MPCSkillContent?
    @State private var glassShimmerPhase = false
    @State private var startButtonIsArmed = false

    private let selectedCardWidth: CGFloat = 72
    private let selectedCardSpacing: CGFloat = 12

    private var requiredCardCount: Int { min(slotCapacity, availableSkills.filter { !$0.isUltimate }.count) }
    private var startIsDisabled: Bool { selectedSkillIDs.count != requiredCardCount }

    private var selectedSkills: [MPCSkillContent] {
        selectedSkillIDs.compactMap { id in
            availableSkills.first(where: { $0.id == id })
        }
    }

    @ViewBuilder
    var body: some View {
        // Every mission uses the existing battlefield dock for manual selection.
        // A second setup panel would duplicate cards and cover the battlefield.
        earlyTutorialLayout
    }

    private var earlyTutorialLayout: some View {
        ZStack {
            Button(startIsDisabled ? "请选择\(requiredCardCount)张技能" : "开始战斗") {
                guard startButtonIsArmed else { return }
                startFillingEmptySequence()
            }
            .font(.system(size: 32, weight: .black, design: .serif))
            .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
            .modifier(BattleStartButtonChrome())
            .buttonStyle(.plain)
            .allowsHitTesting(startButtonIsArmed && !startIsDisabled)
            .opacity(startIsDisabled ? 0.65 : 1)
            .accessibilityIdentifier("chapter-one-start-battle")
            .offset(y: -52)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            startButtonIsArmed = true
        }
    }

    private var laterMissionLayout: some View {
        ZStack {

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 6) {
                if !relics.isEmpty {
                    HStack(alignment: .center, spacing: 8) {
                        Label("遗落物", systemImage: "sparkles")
                            .font(.caption.bold())
                        .foregroundStyle(Color(red: 1.0, green: 0.90, blue: 0.58))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(relics) { relic in
                                    setupRelicCard(relic)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        .scrollClipDisabled()
                        .frame(height: 38)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
                if selectedSkills.count == 2 {
                    Button {
                        moveConfiguredSkill(selectedSkillIDs[1], offset: -1)
                    } label: {
                        Label("交换顺序", systemImage: "arrow.left.arrow.right")
                            .font(.caption.weight(.bold)).foregroundStyle(.yellow)
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .background(.black.opacity(0.6), in: Capsule())
                    }.buttonStyle(.plain).padding(.bottom, 6)
                }

                if requiresFirstReorder && !hasCompletedFirstReorder {
                    Text(selectedSkills.count < 2
                         ? "先选择两张牌，再点击交换顺序"
                         : "交换两张牌的顺序，观察先手技能的变化")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.yellow.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                }

                if !availableSkills.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(selectedSkills + availableSkills.filter { !selectedSkillIDs.contains($0.id) }) { skill in
                            Button {
                                if selectedSkillIDs.contains(skill.id) {
                                    selectedSkillIDs.removeAll { $0 == skill.id }
                                } else if selectedSkillIDs.count < slotCapacity {
                                    selectedSkillIDs.append(skill.id)
                                }
                            } label: {
                                setupSkillCard(skill, order: selectedSkillIDs.firstIndex(of: skill.id).map { $0 + 1 }, selected: selectedSkillIDs.contains(skill.id))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("编排" + skill.name)
                            .accessibilityValue(selectedSkillIDs.contains(skill.id) ? "已选" : "未选")
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                }

                }
                .padding(.top, 10)
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(red: 0.055, green: 0.04, blue: 0.095).opacity(0.96))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(Color(red: 0.65, green: 0.52, blue: 0.25).opacity(0.75), lineWidth: 1)
                        }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            Button {
                guard startButtonIsArmed else { return }
                startFillingEmptySequence()
            } label: {
                Text("开始挑战")
                    .font(.system(size: 22, weight: .black, design: .serif))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 1.00, green: 0.96, blue: 0.72),
                                Color(red: 0.96, green: 0.72, blue: 0.22),
                                Color(red: 0.72, green: 0.38, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.orange.opacity(0.28), radius: 5, y: 2)
                    .padding(.horizontal, 42)
                    .padding(.vertical, 16)
                    .background { Image("ButtonArt01TalentInvocation").resizable().scaledToFit().frame(width: 230, height: 62) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("chapter-one-start-battle")
            .disabled(startIsDisabled || !startButtonIsArmed)
            .opacity(startIsDisabled ? 0.46 : 1)
            .overlay(alignment: .bottom) {
                if showsStartTutorialHint {
                    VStack(spacing: 2) {
                        Image(systemName: "chevron.up")
                            .font(.caption.bold())
                        Text("点击「开始挑战」")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Color(red: 1.0, green: 0.86, blue: 0.43))
                    .shadow(color: .black.opacity(0.7), radius: 3, y: 2)
                    .opacity(glassShimmerPhase ? 1 : 0.56)
                    .offset(y: 40)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: glassShimmerPhase
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .accessibilityHint(showsStartTutorialHint ? "点击后开始第一场教学战斗" : "")
            // Keep the action with the setup dock, below the cards.
            .padding(.bottom, 4)
            .onAppear {
                glassShimmerPhase = true
            }
            .task {
                // Do not let the touch that entered the mission fall through
                // into this newly presented button. The button remains visible
                // immediately, but combat requires a fresh, intentional tap.
                try? await Task.sleep(for: .milliseconds(320))
                guard !Task.isCancelled else { return }
                startButtonIsArmed = true
            }

            }
        }
        // Q1 intentionally has no selectable cards before Mara intervenes.
        // Without an explicit battlefield-sized container, the setup overlay
        // collapses to its empty lower dock on device and the start button can
        // be laid out outside the visible stage. Later missions accidentally
        // hid this bug because their card rows supplied an intrinsic height.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .sheet(item: $inspectedSkill) { skill in
            ChapterSkillDetailSheet(skill: skill)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func setupRelicCard(_ relic: MPCRelicContent) -> some View {
        HStack(spacing: 6) {
            if relic.id == "relic_paper_raincoat" {
                Image(decorative: "IconRelicPaperDouble")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "seal.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color(red: 0.76, green: 0.48, blue: 0.12))
                    .frame(width: 32, height: 32)
            }
            Text(relic.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.90))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(height: 36)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("遗落物，\(relic.name)")
    }

    private func setupSkillCard(
        _ skill: MPCSkillContent,
        order: Int?,
        selected: Bool,
        scale: CGFloat = 1
    ) -> some View {
        let width = 72 * scale
        let height = 106 * scale
        let cornerRadius = 11 * scale
        return ZStack(alignment: .topLeading) {
            Image(decorative: skillCardArtName(skill.id))
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .clipped()
            if let order {
                Text("\(order)")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(width: 17, height: 17)
                    .background(.yellow, in: Circle())
                    .padding(4)
            }
        }
        .frame(width: width, height: height)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(selected ? .yellow.opacity(0.82) : .white.opacity(0.18), lineWidth: selected ? 1.5 : 1))
        .overlay(alignment: .topTrailing) {
            if !selected {
                Button {
                    inspectedSkill = skill
                } label: {
                    Image(systemName: "viewfinder.circle.fill")
                        .font(.system(size: 18 * scale, weight: .bold))
                        .foregroundStyle(.white, .black.opacity(0.76))
                        .shadow(color: .black.opacity(0.82), radius: 2)
                        .padding(4 * scale)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看\(skill.name)介绍")
            }
        }
    }

    private func sequenceDragGesture(for skillID: FoolSkillID) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                if draggedSkillID == nil {
                    beginDragging(skillID)
                }
                updateDragging(skillID, translation: value.translation)
            }
            .onEnded { _ in
                finishDragging(skillID)
            }
    }

    private func moveConfiguredSkill(_ skillID: FoolSkillID, offset: Int) {
        guard let index = selectedSkillIDs.firstIndex(of: skillID),
              selectedSkillIDs.indices.contains(index + offset) else { return }
        selectedSkillIDs.swapAt(index, index + offset)
        if requiresFirstReorder { hasCompletedFirstReorder = true }
    }

    private func beginDragging(_ skillID: FoolSkillID) {
        // A single card has no meaningful reorder destination and therefore
        // must never enter the drag-hint state.
        guard selectedSkillIDs.count > 1,
              draggedSkillID == nil,
              let startIndex = selectedSkillIDs.firstIndex(of: skillID) else { return }

        draggedSkillID = skillID
        dragStartIndex = startIndex
        insertionIndex = startIndex
        dragTranslation = .zero
        dragHighlightPhase = true
    }

    private func updateDragging(_ skillID: FoolSkillID, translation: CGSize) {
        guard draggedSkillID == skillID,
              let startIndex = dragStartIndex else { return }

        dragTranslation = translation
        let slotWidth = selectedCardWidth + selectedCardSpacing
        let projectedCenter = CGFloat(startIndex) * slotWidth
            + translation.width
        // Treat the centre of each neighbouring card as the insertion threshold.
        // This lets a card swap as soon as it is dragged past its neighbour,
        // while still allowing index 0 (far left) and count (far right).
        let rawIndex = Int((projectedCenter / slotWidth).rounded())
        let destination = min(max(rawIndex, 0), selectedSkillIDs.count - 1)
        insertionIndex = destination > startIndex ? destination + 1 : destination
    }

    private var proposedDestinationIndex: Int? {
        guard selectedSkillIDs.count > 1,
              let startIndex = dragStartIndex,
              let insertionIndex else { return nil }

        let adjustedIndex = insertionIndex > startIndex ? insertionIndex - 1 : insertionIndex
        let destination = min(max(adjustedIndex, 0), selectedSkillIDs.count - 1)
        return destination == startIndex ? nil : destination
    }

    private func reorderPreviewOffset(for cardIndex: Int) -> CGFloat {
        guard let startIndex = dragStartIndex,
              let destination = proposedDestinationIndex,
              cardIndex != startIndex else { return 0 }
        let slotWidth = selectedCardWidth + selectedCardSpacing

        if destination < startIndex,
           cardIndex >= destination,
           cardIndex < startIndex {
            return slotWidth
        }

        if destination > startIndex,
           cardIndex > startIndex,
           cardIndex <= destination {
            return -slotWidth
        }

        return 0
    }

    private var insertionHint: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color.purple.opacity(0.07))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.34), .purple.opacity(0.62)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.4
                    )
            }
            .shadow(color: .purple.opacity(0.28), radius: 6)
            .frame(width: selectedCardWidth, height: 106)
            .transition(.opacity.combined(with: .scale(scale: 0.94)))
            .allowsHitTesting(false)
    }

    private func finishDragging(_ skillID: FoolSkillID) {
        guard draggedSkillID == skillID,
              let startIndex = dragStartIndex,
              let insertionIndex else {
            resetDragging()
            return
        }

        var reordered = selectedSkillIDs
        let moved = reordered.remove(at: startIndex)
        let adjustedIndex = insertionIndex > startIndex ? insertionIndex - 1 : insertionIndex
        let destination = min(max(adjustedIndex, 0), reordered.count)
        reordered.insert(moved, at: destination)
        let didReorder = reordered != selectedSkillIDs

        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            if didReorder {
                selectedSkillIDs = reordered
            }
            resetDragging()
        }

        if didReorder && requiresFirstReorder {
            hasCompletedFirstReorder = true
        }
    }

    private func resetDragging() {
        draggedSkillID = nil
        dragStartIndex = nil
        insertionIndex = nil
        dragTranslation = .zero
        dragHighlightPhase = false
    }

    private func removeConfiguredSkill(_ id: FoolSkillID) {
        withAnimation(.easeOut(duration: 0.18)) {
            selectedSkillIDs.removeAll { $0 == id }
        }
    }

}

private struct ChapterOnePrebattleLoadoutView: View {
    let missionTitle: String
    let availableSkills: [MPCSkillContent]
    @Binding var selectedSkillIDs: [FoolSkillID]
    let onConfirm: () -> Void

    private var selectedSkills: [MPCSkillContent] {
        selectedSkillIDs.compactMap { id in
            availableSkills.first(where: { $0.id == id })
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.015, green: 0.045, blue: 0.038), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("战前编排")
                        .font(.system(size: 30, weight: .black, design: .serif))
                    Text(missionTitle)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.62))
                    Text(selectedSkillIDs.count > 1
                         ? "长按已选卡牌拖动排序 · 战斗按从左到右执行"
                         : "选择本场要使用的卡牌")
                        .font(.caption)
                        .foregroundStyle(.yellow.opacity(0.86))
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("执行序列  \(selectedSkillIDs.count)/4")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(selectedSkills.enumerated()), id: \.element.id) { index, skill in
                                VStack(spacing: 5) {
                                    ZStack(alignment: .topLeading) {
                                        Image(decorative: skillCardArtName(skill.id))
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 88, height: 128)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.yellow.opacity(0.82), lineWidth: 1.5))
                                        Text("\(index + 1)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.black)
                                            .frame(width: 22, height: 22)
                                            .background(.yellow, in: Circle())
                                            .padding(5)
                                    }
                                    Text(skill.name)
                                        .font(.caption2.bold())
                                        .lineLimit(1)
                                }
                                .draggable(skill.id.rawValue)
                                .dropDestination(for: String.self) { items, _ in
                                    guard let raw = items.first,
                                          let dragged = FoolSkillID(rawValue: raw),
                                          let from = selectedSkillIDs.firstIndex(of: dragged),
                                          let to = selectedSkillIDs.firstIndex(of: skill.id),
                                          from != to else { return false }
                                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                        let moved = selectedSkillIDs.remove(at: from)
                                        selectedSkillIDs.insert(moved, at: to)
                                    }
                                    return true
                                }
                                .zIndex(100)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .scrollClipDisabled()
                    .frame(height: 164)
                }

                Text("可用卡牌")
                    .font(.headline)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(availableSkills) { skill in
                            let isSelected = selectedSkillIDs.contains(skill.id)
                            Button {
                                if let index = selectedSkillIDs.firstIndex(of: skill.id) {
                                    selectedSkillIDs.remove(at: index)
                                } else if selectedSkillIDs.count < 4 {
                                    selectedSkillIDs.append(skill.id)
                                }
                            } label: {
                                HStack(spacing: 9) {
                                    Image(decorative: skillCardArtName(skill.id))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 62)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 7))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(skill.name).font(.caption.bold())
                                        Text(skill.summary)
                                            .font(.system(size: 9))
                                            .foregroundStyle(.white.opacity(0.58))
                                            .lineLimit(2)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(isSelected ? .yellow : .white.opacity(0.5))
                                }
                                .padding(8)
                                .background(isSelected ? Color.purple.opacity(0.22) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button(action: onConfirm) {
                    Text("确认序列 · 开始战斗")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedSkillIDs.count != min(4, availableSkills.count))
                .opacity(selectedSkillIDs.count != min(4, availableSkills.count) ? 0.35 : 1)
            }
            .padding(22)
        }
        .foregroundStyle(.white)
    }
}

private enum ChapterOneBattleFlowPhase: Equatable {
    case entrance
    case setup
    case battle
}

struct ChapterOneMissionBridgeView: View {
    @Bindable var game: GameStore
    @State private var campaign: MPCChapterOneCampaignState
    @State private var session: MPCChapterOneEncounterSession
    @State private var pendingStoryCue: ChapterOneTutorialCue?
    @State private var pendingSkillRewards: [FoolSkillID] = []
    @State private var victoryReceipt: GameStore.MissionRewardReceipt?
    @State private var victoryTitle = "战斗胜利"
    @State private var victoryHandled = false
    @State private var loanBattleID = UUID().uuidString

    @State private var battleStartError = ""
    @State private var showsBattleStartError = false
    @State private var entranceStage = 0
    @State private var battleFlowPhase: ChapterOneBattleFlowPhase = .entrance
    @State private var firstBattleInterventionCompleted = false
    @State private var draftSkillIDs: [FoolSkillID]
    @AppStorage("mistport.chapterOne.firstSequenceReorderTutorialCompleted")
    private var hasCompletedFirstSequenceReorderTutorial = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }

    init(game: GameStore) {
        self.game = game
        let number = game.activeChapterMission?.number ?? 1
        let activeMission = game.activeChapterMission
            ?? game.selectedChapterDistrict.missions.first(where: { $0.number == number })!
        let session = game.chapterOneSession(for: activeMission)
        let campaign = game.chapterOneCampaign
        _campaign = State(initialValue: campaign)
        _session = State(initialValue: session)
        // Every encounter starts with an empty sequence. Ownership does not
        // select cards; Mara explains the order and the player taps each card.
        _draftSkillIDs = State(initialValue: [])
    }

    var body: some View {
        if !pendingSkillRewards.isEmpty && victoryReceipt == nil {
            ChapterOneGrowthRewardView(skillIDs: pendingSkillRewards) {
                pendingSkillRewards.removeAll()
                finishCompletedEncounter()
            }
        } else if let pendingStoryCue {
            ChapterOneTutorialOverlay(cue: pendingStoryCue) {
                game.completeChapterOneTutorial(pendingStoryCue)
                self.pendingStoryCue = nil
                game.completeDungeon()
            }
            .background(Color.black.ignoresSafeArea())
        } else {
            ZStack {
                ChapterOneEncounterTestView(
                    initialSession: session,
                    campaign: game.presentingChurchLoans(in: campaign),
                    playerSequence: game.currentSequence,
                    playerPlacement: game.chapterOnePlayerPlacement(
                        forMissionNumber: game.activeChapterMission?.number ?? 1
                    ),
                    battleIsActive: battleFlowPhase == .battle,
                    // All player actions are explicitly queued and committed.
                    automatesSkillSequence: true,
                    tutorialCue: tutorialCue,
                    // The bridge presents ChapterOneBattleSetupOverlay in
                    // .setup. Do not leave the child's standalone Q1 button
                    // underneath it, or two identical start controls appear.
                    showsStandaloneOpeningBattleButton: false,
                    onVictory: completeEncounter,
                    onExit: { game.finishChurchLoanBattle(loanBattleID, outcome: .retreat); game.returnToCity() },
                    onDefeat: { game.finishChurchLoanBattle(loanBattleID, outcome: .defeat) },
                    wallHintText: game.activeChapterMission.flatMap { game.wallDefeatHint(missionNumber: $0.number) },
                    onRetrySetup: {
                        #if DEBUG
                        NSLog("[MistportRetry] retry setup mission=%@ phase=%@", game.activeChapterMissionID ?? "nil", String(describing: battleFlowPhase))
                        #endif
                        game.finishChurchLoanBattle(loanBattleID, outcome: .retreat)
                        loanBattleID = UUID().uuidString
                        draftSkillIDs = []
                        battleFlowPhase = .setup
                    },
                    onSequenceChanged: { skills in
                        draftSkillIDs = skills
                        persistCombatSequence(skills)
                    },
                    onSelectActiveRelic: { id in
                        game.selectCampaignActiveRelic(id)
                        campaign.loadout.selectedActiveRelicID = game.chapterOneCampaign.loadout.selectedActiveRelicID
                    },
                    onSelectPassiveRelic: { id in
                        game.toggleCampaignRelic(id)
                        campaign.loadout.relicIDs = game.chapterOneCampaign.loadout.relicIDs
                    },
                    onUseManualMask: {
                        guard game.recordManualMaskUse(encounterID: session.encounter.id) else { return false }
                        campaign.masqueradeCrackCount = game.chapterOneCampaign.masqueradeCrackCount
                        return true
                    },
                    onConsumeSupply: { id in
                        guard game.consumeCampaignSupply(id) else { return false }
                        campaign.inventory = game.chapterOneCampaign.inventory
                        return true
                    },
                    onToggleEncoreBell: {
                        game.toggleCampaignRelic("relic_encore_bell")
                        campaign = game.chapterOneCampaign
                    },
                    onTutorialDismiss: {
                        if let tutorialCue {
                            game.completeChapterOneTutorial(tutorialCue)
                            campaign = game.chapterOneCampaign
                        }
                    },
                    onFirstBattleInterventionCompleted: {
                        game.completeChapterOneTutorial(.firstBattle)
                        firstBattleInterventionCompleted = true
                        draftSkillIDs = []
                        withAnimation(.easeOut(duration: 0.24)) {
                            battleFlowPhase = .setup
                        }
                    }
                )
                // Keep the Unity/SpriteKit host alive when battle starts.
                // Re-keying when combat begins tears down and reattaches the
                // renderer exactly as the opening spell begins, producing a
                // full-screen black frame/layer on device. Mission changes are
                // already isolated by ChapterOneMissionBridgeView's mission ID.
                .id(session.encounter.id)
                .brightness(tutorialCue == nil && entranceStage < 2 ? -0.42 : 0)
                .saturation(tutorialCue == nil && entranceStage < 2 ? 0.35 : 1)
                .allowsHitTesting(tutorialCue != nil || battleFlowPhase != .entrance)
                .animation(.easeOut(duration: reduceMotion ? 0.01 : 0.55), value: entranceStage)

                if tutorialCue == nil && battleFlowPhase == .entrance {
                    BattleEntranceOverlay(
                        stage: entranceStage,
                        districtName: game.activeChapterMission?.districtName ?? "旧城区",
                        encounterName: game.activeChapterMission.map {
                            "任务 \($0.number) · \($0.title)"
                        } ?? session.encounter.name,
                        tint: game.selectedPath?.tint ?? .purple,
                        reduceMotion: reduceMotion,
                        dockReservedHeight: 350,
                        showsTitle: false
                    )
                    .transition(.opacity)
                    .zIndex(200)
                }

                if battleFlowPhase == .setup && tutorialCue == nil {
                    ChapterOneBattleSetupOverlay(
                        availableSkills: availablePrebattleSkills,
                        relics: availablePrebattleRelics,
                        selectedSkillIDs: $draftSkillIDs,
                        requiresFirstReorder: requiresFirstSequenceReorder,
                        slotCapacity: game.chapterOneLoadoutSlotCapacity,
                        hasCompletedFirstReorder: $hasCompletedFirstSequenceReorderTutorial,
                        usesEarlyTutorialLayout: isOldClockMission && (game.activeChapterMission?.number ?? 1) <= 10,
                        showsStartTutorialHint: isOldClockMission && game.activeChapterMission?.number == 1,
                        onStart: beginConfiguredBattle
                    )
                    .onChange(of: draftSkillIDs) { _, updatedSkillIDs in
                        persistCombatSequence(updatedSkillIDs)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .zIndex(190)

                    VStack {
                        let number = game.activeChapterMission?.number ?? 1
                        if number >= 3 || Self.prebattleObjective(number) != nil {
                            prebattleReadiness
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 54)
                    .padding(.horizontal, 18)
                    .zIndex(191)
                }
            }
            .blur(radius: victoryReceipt == nil ? 0 : 5)
            .overlay {
                if let victoryReceipt {
                    ChapterOneVictoryReceiptView(title: victoryTitle, receipt: victoryReceipt,
                                                 skillIDs: pendingSkillRewards,
                                                 missionNumber: session.chapterMissionNumber) {
                        self.victoryReceipt = nil
                        pendingSkillRewards.removeAll()
                        finishCompletedEncounter()
                    }
                }
            }
            // Key the entrance lifecycle to the encounter as well as its
            // tutorial. Missions one and two both have a nil prebattle cue;
            // cue-only identity could therefore leave the second mission
            // reusing an unfinished entrance task and permanently covering
            // the setup button.
            .task(id: entranceTaskID) {
                // A mission always enters through the same three exclusive
                // phases. Reset here as well as in init because SwiftUI may
                // preserve this bridge while the selected mission changes.
                battleFlowPhase = .entrance
                entranceStage = 0
                guard tutorialCue == nil else {
                    entranceStage = 3
                    battleFlowPhase = .setup
                    return
                }
                await playEntranceSequence()
            }
            .alert("无法开始战斗", isPresented: $showsBattleStartError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(battleStartError)
            }
        }
    }

    private var requiresFirstSequenceReorder: Bool {
        let missionNumber = game.activeChapterMission?.number ?? 1
        return isOldClockMission && missionNumber >= 4
            && !hasCompletedFirstSequenceReorderTutorial
            && availablePrebattleSkills.count >= 2
            && game.chapterOneLoadoutSlotCapacity >= 2
    }

    private var prebattleReadiness: some View {
        let number = game.activeChapterMission?.number ?? 1
        let equipped = campaign.loadout.relicIDs + [campaign.loadout.selectedActiveRelicID].compactMap { $0 }
        let depleted = Array(Set(equipped)).sorted().filter {
            EarlyRelicShop.ids.contains($0)
                && campaign.ownedRelicIDs.contains($0)
                && game.churchServices.ownedCondition.currentDurability($0) == 0
        }
        return VStack(alignment: .leading, spacing: 5) {
            if (3...8).contains(number) {
                let lines = ChapterOneEncounterTestView.enemyPreludeLines(number)
                if !lines.isEmpty {
                    TimelineView(.periodic(from: .now, by: 4)) { context in
                        Text(lines[Int(context.date.timeIntervalSince1970 / 4) % lines.count])
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            if let objective = Self.prebattleObjective(number) {
                Text(objective)
                    .font(.caption.bold())
                    .foregroundStyle(.yellow)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if number >= 3 {
                HStack(spacing: 8) {
                    Text("止痛膏 \(game.painSalveStock)份 · 假面裂纹 \(campaign.masqueradeCrackCount)/10")
                        .font(.caption2.bold())
                    Spacer(minLength: 4)
                    if game.earlyRelicShopUnlocked && game.painSalveStock == 0 {
                        Button("补给 \(game.painSalvePrice)铜币") {
                            game.purchasePainSalve()
                            campaign = game.chapterOneCampaign
                        }
                        .font(.caption2.bold())
                        .disabled(game.venueCoins < game.painSalvePrice)
                        .accessibilityIdentifier("chapter-one-prebattle-buy-salve")
                    }
                }
                Text(number <= 4 ? "教学战假面不增裂纹；战中使用止痛膏会消耗。" : "失败也会消耗已用止痛膏；每次使用假面永久增加1道裂纹。")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.78))
            }
            ForEach(depleted, id: \.self) { id in
                if let offer = MPCChurchLoanOffer.all.first(where: { $0.relicID == id }) {
                    let price = MPCChurchLoanLedger.ownedRepairPrice(value: offer.value, durability: 0)
                    HStack(spacing: 8) {
                        Text("\(EarlyRelicShop.name(id))已失效 · 完好度0%")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                        Spacer(minLength: 4)
                        Button("修复 \(price)铜币") {
                            do { try game.repairOwnedChurchRelic(id) }
                            catch {
                                battleStartError = "修复失败：\(error.localizedDescription)"
                                showsBattleStartError = true
                            }
                        }
                        .font(.caption2.bold())
                        .disabled(game.venueCoins < price)
                        .accessibilityIdentifier("chapter-one-prebattle-repair-\(id)")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 390, alignment: .leading)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.yellow.opacity(0.35), lineWidth: 1))
    }

    private static func prebattleObjective(_ number: Int) -> String? {
        switch number {
        case 8: "张冠李戴未满4层先造成伤害并加1层；满4层再释放才延迟行动。技能按编排顺序自动出牌。"
        case 20: "目标：趁锤卫恢复或校准，解除1600点拘束；救出活档案即可胜利。"
        case 25: "目标：趁维娅恢复或校准，拆除1800点根结；她不会被击杀。"
        case 26: "目标：先打断900点车链供能，再击败锤卫。"
        case 27: "先处理持续追击的猎犬；档案守卫封甲时免伤，重砸后的恢复空档可集中输出。"
        case 28: "目标：活过五次完整回流，等五锚同时显露后切断外接力量；无需打空总签官本体生命。"
        case 29: "目标：撑过五次完整循环，待钟环储备耗尽、总签官离场后，清除剩余两名护卫。"
        case 30: "目标：击败总签官本体并活过所有已出手的攻击；同归于尽不算胜利。"
        default: nil
        }
    }

    private var isOldClockMission: Bool {
        game.activeChapterMission?.districtID == "old-clock"
    }

    private var entranceTaskID: String {
        "\(session.encounter.id)-\(tutorialCue?.rawValue ?? "no-tutorial")"
    }

    private var availablePrebattleSkills: [MPCSkillContent] {
        let missionNumber = game.activeChapterMission?.number ?? 1
        if isOldClockMission && missionNumber == 1 {
            guard firstBattleInterventionCompleted else { return [] }
            return MPCChapterOneCatalog.visibleSkills.filter { $0.id == .sidestepStrike }
        }

        var permitted = campaign.unlockedSkillIDs
        if isOldClockMission, let trialSkillID = game.activeChapterMission.flatMap({ mission in
            MPCChapterOneCatalog.mission(forOldClockMissionNumber: mission.number)?.trialSkillID
        }) {
            permitted.insert(trialSkillID)
        }
        return MPCChapterOneCatalog.visibleSkills.filter {
            !$0.isUltimate && permitted.contains($0.id)
        }
    }

    private var availablePrebattleRelics: [MPCRelicContent] {
        let loadout = campaign.effectiveLoadout
        let equipped = Set(loadout.relicIDs)
        return MPCChapterOneCatalog.relics.filter {
            equipped.contains($0.id)
                && campaign.ownedRelicIDs.contains($0.id)
                && !campaign.depletedRelicIDs.contains($0.id)
                && !((isOldClockMission && (game.activeChapterMission?.number ?? 0) < 5) && $0.id == "relic_paper_raincoat")
        }
    }

    private func beginConfiguredBattle() {
        // Starting combat is only legal from the setup phase. This prevents a
        // stale gesture or an async entrance completion from carrying a prior
        // mission directly into combat and hiding its setup button.
        #if DEBUG
        NSLog("[MistportStart] tapped phase=%@ cue=%@", String(describing: battleFlowPhase), tutorialCue.map { $0.rawValue } ?? "nil")
        #endif
        // A tap that arrives while the entrance curtain is still finishing
        // used to be dropped silently (playtest 2026-10-05: Q11/Q12 needed a
        // second or third tap). The player's intent is clear: close the
        // curtain and start.
        if battleFlowPhase == .entrance, tutorialCue == nil { finishEntranceSequence() }
        guard battleFlowPhase == .setup else { return }

        let permitted = Set(availablePrebattleSkills.map(\.id))
        let missionNumber = game.activeChapterMission?.number ?? 1
        var selected = Array(draftSkillIDs.filter(permitted.contains).prefix(game.chapterOneLoadoutSlotCapacity))
        // Playtest 2026-10-04: starting with an empty sequence silently fought
        // with basic attacks only. Fill it in the listed order instead.
        if selected.isEmpty {
            selected = Array(availablePrebattleSkills.map(\.id).prefix(game.chapterOneLoadoutSlotCapacity))
            draftSkillIDs = selected
        }

        var loadout = campaign.effectiveLoadout
        loadout.selectedActiveRelicID = [3, 4].contains(missionNumber)
            ? MPCChapterOneCatalog.ownerlessMaskRelicID : campaign.loadout.selectedActiveRelicID
        loadout.talents = game.hermitTalents
        loadout.normalSkillIDs = selected
        campaign.loadout.normalSkillIDs = selected.filter(campaign.unlockedSkillIDs.contains)
        campaign.lifetimeChurchMerit = game.chapterOneCampaign.lifetimeChurchMerit
        campaign.spendableChurchMerit = game.chapterOneCampaign.spendableChurchMerit
        game.saveChapterOneBattleLoadout(campaign.loadout.normalSkillIDs)

        let mission = isOldClockMission
            ? MPCChapterOneCatalog.mission(forOldClockMissionNumber: missionNumber)
            : nil
        let encounterID = mission?.encounterID
            ?? MPCChapterOneCatalog.encounterID(
                forDistrictID: game.activeChapterMission?.districtID ?? "old-clock",
                missionNumber: missionNumber
            )
            ?? session.encounter.id
        loadout = game.applyingChurchLoans(to: loadout, allowsActive: ![3, 4].contains(missionNumber))
        do {
            var prepared = try MPCChapterOneEncounterSession.start(
                encounterID: encounterID,
                party: campaign.party,
                consumables: campaign.inventory,
                companionIDs: mission?.companionIDs ?? [],
                loadout: loadout
            )
            // Q30 离场祝福 (2026-10-10, user): each attempt, 伊莱娅 and the pursuer leave one
            // random blessing each; the battle view announces them as combat begins.
            if prepared.chapterMissionNumber == 30 {
                var generator = SystemRandomNumberGenerator()
                prepared.applyFarewellBlessings(.roll(using: &generator))
            }
            try game.beginChurchLoanBattle(loanBattleID, loadout: loadout)
            session = prepared
        } catch {
            battleStartError = "无法开始这场战斗：\(error.localizedDescription)"
            showsBattleStartError = true
            return
        }
        withAnimation(.easeOut(duration: 0.24)) {
            battleFlowPhase = .battle
        }
    }

    private func persistCombatSequence(_ skillIDs: [FoolSkillID]) {
        let persistable = skillIDs.filter(campaign.unlockedSkillIDs.contains)
        campaign.loadout.normalSkillIDs = persistable
        campaign.lifetimeChurchMerit = game.chapterOneCampaign.lifetimeChurchMerit
        campaign.spendableChurchMerit = game.chapterOneCampaign.spendableChurchMerit
        game.saveChapterOneBattleLoadout(persistable)
    }

    @MainActor
    private func playEntranceSequence() async {
        entranceStage = 0
        battleFlowPhase = .entrance
        // SwiftUI may cancel a view-bound task while the embedded renderer is
        // attaching or publishing state. Never leave the entrance curtain up
        // after cancellation: it would permanently cover the battle setup UI.
        defer {
            if battleFlowPhase == .entrance {
                finishEntranceSequence()
            }
        }

        if reduceMotion {
            entranceStage = 2
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            finishEntranceSequence()
            return
        }

        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.42)) {
            entranceStage = 1
        }

        try? await Task.sleep(for: .milliseconds(620))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            entranceStage = 2
        }

        try? await Task.sleep(for: .milliseconds(600))
        guard !Task.isCancelled else { return }
        finishEntranceSequence()
    }

    @MainActor
    private func finishEntranceSequence() {
        withAnimation(.easeInOut(duration: reduceMotion ? 0.01 : 0.36)) {
            entranceStage = 3
            battleFlowPhase = .setup
        }
    }

    private var tutorialCue: ChapterOneTutorialCue? {
        guard isOldClockMission else { return nil }
        let missionNumber = game.activeChapterMission?.number ?? 1
        let cue: ChapterOneTutorialCue?
        switch missionNumber {
        // Q1's tutorial is authored as an in-battle intervention after three
        // ineffective attacks; it must not appear before the entrance/setup.
        case 1: cue = nil
        case 2: cue = .fogGhostPrelude
        case 3: cue = .houndPrelude
        case 4: cue = .secondBattle
        case 5: cue = .q5Delivery
        case 6: cue = .q6Prelude
        case 7: cue = .q7Prelude
        case 8: cue = .q8Prelude
        case 9: cue = .q9Prelude
        case 10: cue = .q10Prelude
        case 11: cue = .q11Prelude
        case 12: cue = .q12Prelude
        case 13: cue = .q13Prelude
        case 14: cue = .q14Prelude
        case 15: cue = .q15Prelude
        case 16: cue = .q16Prelude
        case 17: cue = .q17Prelude
        case 18: cue = .q18Prelude
        case 19: cue = .q19Prelude
        case 20: cue = .q20Prelude
        case 21: cue = .q21Prelude
        case 22: cue = .q22Prelude
        case 23: cue = .q23Prelude
        case 24: cue = .q24Prelude
        case 25: cue = .q25Prelude
        case 26: cue = .q26Prelude
        case 27: cue = .q27Prelude
        case 28: cue = .q28Prelude
        case 29: cue = .q29Prelude
        case 30: cue = .q30Prelude
        default: cue = nil
        }
        guard let cue, !game.hasSeenChapterOneTutorial(cue) else { return nil }
        return cue
    }

    private func completeEncounter(_ completed: MPCChapterOneEncounterSession) {
        guard !victoryHandled else { return }
        victoryHandled = true
        game.finishChurchLoanBattle(loanBattleID, outcome: .victory)
        let previouslyUnlocked = campaign.unlockedSkillIDs
        let oldInventory = campaign.inventory
        let oldRelics = campaign.ownedRelicIDs
        campaign.lifetimeChurchMerit = game.chapterOneCampaign.lifetimeChurchMerit
        campaign.spendableChurchMerit = game.chapterOneCampaign.spendableChurchMerit
        campaign.completeEncounter(completed)
        game.chapterOneCampaign = campaign
        session = completed
        pendingSkillRewards = MPCChapterOneCatalog.visibleSkills.map(\.id).filter {
            campaign.unlockedSkillIDs.contains($0) && !previouslyUnlocked.contains($0)
        }
        let number = game.activeChapterMission?.number ?? 0
        victoryTitle = isOldClockMission && [3, 4].contains(number) ? "暂时摆脱追猎"
            : isOldClockMission && number == 5 ? "翠焰亡灵退场"
            : isOldClockMission && number == 6 ? "追猎解除" : "战斗胜利"
        var itemNames = campaign.inventory.keys.sorted().compactMap { id -> String? in
            let gained = campaign.inventory[id, default: 0] - oldInventory[id, default: 0]
            guard gained > 0 else { return nil }
            let name = MPCChapterOneCatalog.items.first(where: { $0.id == id })?.name ?? "调查物品"
            return "\(name) ×\(gained)"
        }
        itemNames += campaign.ownedRelicIDs.subtracting(oldRelics).sorted().map { id in
            MPCChapterOneCatalog.relics.first(where: { $0.id == id })?.name ?? "遗落物"
        }
        victoryReceipt = game.settleActiveMissionRewards(itemNames: itemNames, damageBySource: completed.damageBySource)
        if victoryReceipt == nil { finishCompletedEncounter() }
    }

    private func finishCompletedEncounter() {
        if session.encounter.id == "encounter_midnight_02" {
            // Legacy saves enter the same fixed chapter resolution, never
            // the superseded three-ending selection screen.
            pendingStoryCue = .q30Aftermath
        } else if isOldClockMission, game.activeChapterMission?.number == 1,
                  !game.hasSeenChapterOneTutorial(.rainFirstAftermath) {
            pendingStoryCue = .rainFirstAftermath
        } else if isOldClockMission, game.activeChapterMission?.number == 2,
                  !game.hasSeenChapterOneTutorial(.rainInterlude) {
            pendingStoryCue = .rainInterlude
        } else if isOldClockMission, game.activeChapterMission?.number == 3,
                  !game.hasSeenChapterOneTutorial(.q3Aftermath) {
            pendingStoryCue = .q3Aftermath
        } else if isOldClockMission, game.activeChapterMission?.number == 4,
                  !game.hasSeenChapterOneTutorial(.q4Aftermath) {
            pendingStoryCue = .q4Aftermath
        } else if isOldClockMission,
                  let cue = [5: ChapterOneTutorialCue.q5Aftermath, 6: .q6Aftermath, 7: .q7Aftermath, 8: .q8Aftermath, 9: .q9Aftermath, 10: .q10Aftermath,
                             11: .q11Aftermath, 12: .q12Aftermath, 13: .q13Aftermath, 14: .q14Aftermath, 15: .q15Aftermath,
                             16: .q16Aftermath, 17: .q17Aftermath, 18: .q18Aftermath, 19: .q19Aftermath, 20: .q20Aftermath,
                             21: .q21Aftermath, 22: .q22Aftermath, 23: .q23Aftermath, 24: .q24Aftermath, 25: .q25Aftermath, 26: .q26Aftermath, 27: .q27Aftermath, 28: .q28Aftermath, 29: .q29Aftermath, 30: .q30Aftermath][game.activeChapterMission?.number ?? 0],
                  !game.hasSeenChapterOneTutorial(cue) {
            pendingStoryCue = cue
        } else {
            game.completeDungeon()
        }
    }
}

private struct ChapterOneGrowthRewardView: View {
    let skillIDs: [FoolSkillID]
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }
    @State private var revealedCount = 0
    @State private var glowBreath = false
    @State private var confirmShimmer = false

    private var skills: [MPCSkillContent] {
        skillIDs.compactMap { id in MPCChapterOneCatalog.visibleSkills.first(where: { $0.id == id }) }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.08, green: 0.05, blue: 0.17), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.purple.opacity(glowBreath ? 0.25 : 0.11))
                .frame(width: 330, height: 330)
                .blur(radius: 54)
                .scaleEffect(glowBreath ? 1.08 : 0.88)

            VStack(spacing: 20) {
                VStack(spacing: 7) {
                    Text("LEVEL UP")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(5)
                        .foregroundStyle(Color.yellow.opacity(0.78))
                    Text("位阶提升")
                        .font(.system(size: 34, weight: .black, design: .serif))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.82, green: 0.55, blue: 0.18), Color(red: 1.0, green: 0.94, blue: 0.70), Color(red: 0.82, green: 0.55, blue: 0.18)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("习得技能 · 战前可编排")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.66))
                }

                HStack(spacing: 16) {
                    ForEach(Array(skills.enumerated()), id: \.element.id) { index, skill in
                        VStack(spacing: 9) {
                            ZStack {
                                IrregularCardEdgeGlow(isVisible: index < revealedCount)

                                Image(decorative: skillCardArtName(skill.id))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 124, height: 170)
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.yellow.opacity(0.92), lineWidth: 2)
                                    }
                                    .shadow(color: .orange.opacity(0.78), radius: 18)
                            }
                            .frame(width: 166, height: 214)
                            Text(skill.name)
                                .font(.system(size: 16, weight: .black, design: .rounded))
                            Text(skill.summary)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.66))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .frame(width: 132)
                                .frame(minHeight: 38)
                        }
                        .opacity(index < revealedCount ? 1 : 0)
                        .scaleEffect(index < revealedCount ? 1 : 0.72)
                        .offset(y: index < revealedCount ? 0 : 24)
                    }
                }

                Button {
                    if revealedCount < skills.count {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                            revealedCount = skills.count
                        }
                    } else {
                        onContinue()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: revealedCount < skills.count ? "sparkles" : "seal.fill")
                            .font(.system(size: 18, weight: .bold))
                        VStack(spacing: 1) {
                            Text(revealedCount < skills.count ? "揭示技能" : "铭刻入牌组")
                                .font(.system(size: 17, weight: .black, design: .serif))
                            Text(revealedCount < skills.count ? "REVEAL" : "CONFIRM · CONTINUE")
                                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                                .tracking(1.6)
                                .opacity(0.62)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .black))
                    }
                    .foregroundStyle(Color(red: 0.16, green: 0.08, blue: 0.02))
                    .frame(width: 238, height: 60)
                    .background {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.78, green: 0.45, blue: 0.10), Color(red: 1.0, green: 0.93, blue: 0.60), Color(red: 0.90, green: 0.58, blue: 0.14)],
                                    startPoint: confirmShimmer ? .trailing : .leading,
                                    endPoint: confirmShimmer ? .leading : .trailing
                                )
                            )
                            .overlay {
                                Capsule()
                                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
                                    .padding(3)
                            }
                    }
                    .shadow(color: Color.orange.opacity(0.48), radius: 16, y: 5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
        }
        .foregroundStyle(.white)
        .task {
            guard revealedCount == 0 else { return }
            for index in skills.indices {
                if !reduceMotion { try? await Task.sleep(for: .milliseconds(index == 0 ? 260 : 520)) }
                withAnimation(.spring(response: 0.46, dampingFraction: 0.70)) {
                    revealedCount = index + 1
                }
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                glowBreath = true
            }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                confirmShimmer = true
            }
        }
    }
}

private struct IrregularCardEdgeGlow: View {
    let isVisible: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    let indexValue = Double(index)
                    let primarySpeed = 0.71 + indexValue * 0.083
                    let primaryPhase = time * primarySpeed + indexValue * 1.37
                    let primary = sin(primaryPhase)
                    let secondarySpeed = 1.19 + Double(index % 3) * 0.127
                    let secondaryPhase = time * secondarySpeed + indexValue * 0.61
                    let secondary = sin(secondaryPhase)
                    let flicker = max(0, min(1, 0.52 + primary * 0.23 + secondary * 0.15))
                    let size = CGFloat(19 + (index % 3) * 2) + CGFloat(flicker) * 3
                    let xPositions: [CGFloat] = [-59, 59, -59, 59, -31, 31, -31, 31]
                    let yPositions: [CGFloat] = [-79, -79, 79, 79, -88, -88, 88, 88]
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.34, blue: 0.10).opacity(0.26),
                                    Color(red: 1.0, green: 0.69, blue: 0.22).opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size / 2
                            )
                        )
                        .frame(width: size, height: size)
                        .blur(radius: 2)
                        .offset(
                            x: xPositions[index] + CGFloat(secondary) * 1.4,
                            y: yPositions[index] + CGFloat(primary) * 2.2
                        )
                        .opacity(isVisible ? 0.32 + flicker * 0.38 : 0)
                }
            }
            .frame(width: 138, height: 190)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A clockwise sweep from twelve o'clock; the timer reflects real elapsed seconds.
private struct ClockwiseCardCooldown: View {
    var now: TimeInterval? = nil
    let startedAt: TimeInterval?
    let duration: TimeInterval
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: startedAt == nil)) { _ in
            let elapsed = startedAt.map { (now ?? ProcessInfo.processInfo.systemUptime) - $0 } ?? duration
            let progress = min(1, max(0, elapsed / duration))
            if progress < 1 {
                GeometryReader { geometry in
                    let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    ZStack {
                        Path { path in
                            path.move(to: center)
                            path.addArc(center: center, radius: max(geometry.size.width, geometry.size.height),
                                        startAngle: .degrees(-90 + 360 * progress), endAngle: .degrees(270), clockwise: false)
                            path.closeSubpath()
                        }.fill(.black.opacity(0.6))
                    }.frame(width: geometry.size.width, height: geometry.size.height)
                }.clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }.allowsHitTesting(false)
    }
}


struct ChapterOneVictoryReceiptView: View {
    let title: String
    let receipt: GameStore.MissionRewardReceipt
    let skillIDs: [FoolSkillID]
    let missionNumber: Int?
    let onFinished: () -> Void
    init(title: String, receipt: GameStore.MissionRewardReceipt,
         skillIDs: [FoolSkillID], missionNumber: Int? = nil,
         onFinished: @escaping () -> Void) {
        self.title = title
        self.receipt = receipt
        self.skillIDs = skillIDs
        self.missionNumber = missionNumber
        self.onFinished = onFinished
    }
    @State private var didFinish = false
    // Playtest 2026-10-05: card taps still landing after the last blow pressed
    // this button before the player saw the rewards (Q11, Q12). Arm it late.
    @State private var continueIsArmed = false
    private func finish() {
        guard !didFinish, continueIsArmed else { return }
        didFinish = true
        onFinished()
    }
    @State private var stage = 1
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesInterfaceMotion = false
    private var reduceMotion: Bool { systemReduceMotion || reducesInterfaceMotion }

    private func rewardArtName(_ line: String) -> String {
        let name = line.components(separatedBy: " ×").first ?? line
        if let item = MPCChapterOneCatalog.items.first(where: { $0.name == name }) {
            return chapterOneInventoryArtName("campaign-item-" + item.id) ?? "RewardMaterial"
        }
        if let relic = MPCChapterOneCatalog.relics.first(where: { $0.name == name }) {
            return chapterOneInventoryArtName("campaign-relic-" + relic.id) ?? "RewardMaterial"
        }
        return "RewardMaterial"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.28), Color(red: 0.055, green: 0.045, blue: 0.12).opacity(0.94), .black],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
            VStack(spacing: 12) {
                if stage >= 1 {
                    Image("BattleVictoryCrest")
                        .resizable().scaledToFit()
                        .frame(maxWidth: 300).frame(height: 120)
                        .shadow(color: .yellow.opacity(0.22), radius: 20)
                        .transition(.scale(scale: 0.72).combined(with: .opacity))
                    Text(title).font(.system(size: 30, weight: .bold, design: .serif))
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .foregroundStyle(Color(red: 1, green: 0.87, blue: 0.52))
                        .shadow(color: .black, radius: 8)
                    Text(receipt.firstClear ? "首次完成" : "回响重演")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                }
                if stage >= 2 {
                    if missionNumber == 28 {
                        Text("五锚回流已定位 · 完整循环 5/5")
                            .font(.headline).foregroundStyle(.yellow)
                    } else if missionNumber == 29 {
                        Text("钟环储备耗尽 · 两名护卫已清除")
                            .font(.headline).foregroundStyle(.yellow)
                    }
                    if let damage = receipt.damageBySource, damage.values.contains(where: { $0 > 0 }) {
                        BattleDamageSummary(damage: damage, expanded: false)
                    }
                    Text("通关奖励").font(.headline).foregroundStyle(.white.opacity(0.8))
                    HStack(spacing: 30) {
                        VStack(spacing: 8) {
                            Image("RewardCoin").resizable().scaledToFit().frame(width: 48, height: 48)
                            Text(receipt.coins > 0 ? "铜币 +\(receipt.coins)" : "演练不发放正式奖励").font(.headline)
                        }
                        if receipt.materials > 0 {
                            VStack(spacing: 8) {
                                Image("RewardMaterial").resizable().scaledToFit().frame(width: 48, height: 48)
                                Text("晋阶材料 +\(receipt.materials)").font(.headline)
                            }
                        }
                    }.foregroundStyle(.white).padding(.top, 12)
                    ForEach(Array((receipt.itemNames ?? []).filter { !$0.hasPrefix("雾岬铜币") }.enumerated()), id: \.offset) { _, name in
                        HStack(spacing: 14) {
                            Image(rewardArtName(name))
                                .resizable().scaledToFit().frame(width: 44, height: 44)
                            Text(name == "迟秒怀表" ? "迟秒怀表 · 调查物证（不可装备）" : name).font(.headline).foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 20).padding(.vertical, 6)
                        .background(Color.white.opacity(0.055))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    ForEach(skillIDs, id: \.self) { id in
                        if let skill = MPCChapterOneCatalog.visibleSkills.first(where: { $0.id == id }) {
                            Text("习得 · \(skill.name)").foregroundStyle(.white).font(.headline)
                        }
                    }
                    MistportPlaqueButton(title: "继续 · 前往后续", action: finish)
                    .accessibilityIdentifier("chapter-one-victory-continue")
                    .opacity(continueIsArmed ? 1 : 0.45)
                    .allowsHitTesting(continueIsArmed)
                    .padding(.top, 14)
                    .task {
                        try? await Task.sleep(for: .milliseconds(1_100))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.25)) { continueIsArmed = true }
                    }
                }
                Color.clear.frame(height: 16)
            }.padding(.horizontal, 24).padding(.top, 24)
            }
        }
        .accessibilityElement(children: .contain)
        .task {
            do {
                try await Task.sleep(for: .milliseconds(200))
                withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.3)) { stage = 1 }
                try await Task.sleep(for: .milliseconds(400))
                withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.3)) { stage = 2 }
            } catch { }
        }
    }
}

private struct BattleDamageSummary: View {
    let damage: [String: Int]
    var expanded = false
    private var rows: [(key: String, value: Int)] {
        Array(damage.filter { $0.value > 0 }.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }.prefix(expanded ? 20 : 3))
    }
    private var total: Int { damage.values.reduce(0, +) }
    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Text("对敌伤害").font(.headline)
                Spacer()
                Text("\(total)").font(.headline.monospacedDigit()).foregroundStyle(.yellow)
            }
            ForEach(rows, id: \.key) { row in
                HStack(spacing: 8) {
                    Text(name(row.key)).font(.caption).frame(width: 82, alignment: .leading)
                    GeometryReader { geometry in
                        Capsule().fill(.white.opacity(0.10))
                            .overlay(alignment: .leading) {
                                Capsule().fill(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geometry.size.width * Double(row.value) / Double(max(1, total)))
                            }
                    }.frame(height: 7)
                    Text(String(format: "%.1f%%", Double(row.value) * 100 / Double(max(1, total))))
                        .font(.caption.monospacedDigit()).frame(width: 48, alignment: .trailing)
                }
            }
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(14)
        .background(.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }
    private func name(_ id: String) -> String {
        if id == "basic" { return "普攻" }
        return MPCChapterOneCatalog.visibleSkills.first { $0.id.rawValue == id }?.name ?? "其他伤害"
    }
}

/// Isolated simulator diagnostics; no visible UI or production persistence.
private struct CardDockMeasurement: View {
    let role: String
    var body: some View {
        #if DEBUG
        GeometryReader { geometry in
            let frame = geometry.frame(in: .global)
            Color.clear
                .onAppear { record(frame) }
                .onChange(of: frame) { _, updated in record(updated) }
        }
        .allowsHitTesting(false)
        #else
        Color.clear.allowsHitTesting(false)
        #endif
    }
    private func record(_ frame: CGRect) {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--verify-p1-ui") else { return }
        UserDefaults(suiteName: "mistport.p1-ui-verification")?.set(
            ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height],
            forKey: "debug.card-dock.\(role)")
        #endif
    }
}


struct MaskCrackOverlay: View {
    let count: Int
    var body: some View {
        Canvas { context, size in
            for index in 0..<min(10, max(0, count)) {
                let angle = Double(index) * 2.39996 - 1.2
                let radius = min(size.width, size.height) * 0.38
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                func point(_ fraction: Double, _ offset: Double) -> CGPoint {
                    CGPoint(x: center.x + cos(angle + offset) * radius * fraction,
                            y: center.y + sin(angle + offset) * radius * fraction)
                }
                var crack = Path()
                crack.move(to: point(1, 0)); crack.addLine(to: point(0.76, 0.08))
                crack.addLine(to: point(0.62, -0.08)); crack.addLine(to: point(0.35, 0.04))
                crack.move(to: point(0.76, 0.08)); crack.addLine(to: point(0.66, 0.29))
                context.stroke(crack, with: .color(Color(red: 0.12, green: 0.025, blue: 0.20)), lineWidth: max(1.2, size.width * 0.018))
                context.stroke(crack, with: .color(Color(red: 0.42, green: 0.16, blue: 0.58).opacity(0.8)), lineWidth: max(0.55, size.width * 0.006))
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

private func chapterOneStoryArt(_ contentID: String, encounterID: String) -> String? {
    if ["chapter01_q09_encounter", "chapter01_q12_encounter", "chapter01_q14_encounter"].contains(encounterID), contentID == "enemy_calibration_puppet" { return "StoryScribe20260916" }
    if encounterID == "chapter01_q13_encounter", contentID == "elite_clock_chaser" { return "StoryRescue20260916" }
    return nil
}

/// A separate transient crown, not a recolored inventory icon. Each engraved
/// segment loses cohesion in the last two seconds and lifts away independently.
private struct UsurpedMedalCrownEffect: View {
    let remaining: TimeInterval
    let time: TimeInterval
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(GameSettingsKeys.reduceMotion, store: .standard) private var reducesGameMotion = false

    var body: some View {
        Canvas { context, size in
            let points: [CGPoint] = [
                CGPoint(x: 0.30, y: 0.57), CGPoint(x: 0.39, y: 0.64),
                CGPoint(x: 0.45, y: 0.49), CGPoint(x: 0.52, y: 0.63),
                CGPoint(x: 0.64, y: 0.52), CGPoint(x: 0.62, y: 0.74),
                CGPoint(x: 0.37, y: 0.74), CGPoint(x: 0.30, y: 0.57)
            ]
            let dissolve = max(0, min(1, (2 - remaining) / 2))
            for index in 0..<(points.count - 1) {
                let phase = max(0, min(1, dissolve * 1.6 - Double(index) * 0.085))
                var segment = context
                segment.opacity = (1 - phase) * (reduceMotion || reducesGameMotion ? 0.9 : 0.85 + 0.15 * sin(time * 4))
                let movement = reduceMotion || reducesGameMotion ? 0 : phase
                segment.translateBy(x: (Double(index % 3) - 1) * 7 * movement, y: -12 * movement)
                var path = Path()
                path.move(to: CGPoint(x: points[index].x * size.width, y: points[index].y * size.height))
                path.addLine(to: CGPoint(x: points[index + 1].x * size.width, y: points[index + 1].y * size.height))
                segment.addFilter(.shadow(color: .purple.opacity(0.9), radius: 3))
                segment.stroke(path, with: .color(Color(red: 1, green: 0.86, blue: 0.38)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
            }
        }
    }
}

struct ChurchTowerView: View {
    @Bindable var game: GameStore
    @Environment(\.dismiss) private var dismiss
    var onBack: (() -> Void)? = nil
    @State private var tier = 0
    @State private var selected = 1
    private struct BattleDestination: Identifiable {
        let id = UUID()
        let floor: Int
        let session: MPCChapterOneEncounterSession
    }
    @State private var battleDestination: BattleDestination?
    @State private var error = ""
    private let sealPoints: [CGPoint] = [CGPoint(x: 0.246, y: 0.183), CGPoint(x: 0.659, y: 0.25), CGPoint(x: 0.279, y: 0.31), CGPoint(x: 0.74, y: 0.375), CGPoint(x: 0.278, y: 0.44), CGPoint(x: 0.699, y: 0.502), CGPoint(x: 0.325, y: 0.569), CGPoint(x: 0.739, y: 0.637), CGPoint(x: 0.347, y: 0.702), CGPoint(x: 0.68, y: 0.777)]
    private let tierNames = ["井口封线", "盐雾渗层", "回生暗渠", "双刃断桥", "冠鸣回廊", "骨爪深穴", "交错封锁", "沉井围阵", "裂隙王庭", "最后界碑"]
    private var floor: MPCChurchTowerCatalog.Floor { MPCChurchTowerCatalog.floor(number: selected)! }
    private var available: Bool { game.churchRemoteServicesAvailable && game.churchTowerProgress.canEnter(selected, completedMissionNumbers: game.churchTowerMissionNumbers) && game.towerFloorIsOpenToday(selected) }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                Image("ChurchSealMap").resizable().frame(width: geo.size.width, height: geo.size.height * 0.82).position(x: geo.size.width / 2, y: geo.size.height * 0.47)
                LinearGradient(colors: [.black.opacity(0.65), .clear, .clear, .black.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                VStack(spacing: 8) {
                    ChurchSceneHeader(title: "联封深井", subtitle: "已封堵 \(game.churchTowerProgress.clearedFloors.count) / 100", onBack: { if let onBack { onBack() } else { dismiss() } })
                    HStack {
                        Button { changeTier(-1) } label: { Image(systemName: "chevron.left").padding(12) }.disabled(tier == 0)
                        Spacer()
                        VStack(spacing: 3) {
                            Text(tierNames[tier]).font(.system(size: 20, weight: .semibold, design: .serif))
                            Text("第 \(tier * 10 + 1) — \(tier * 10 + 10) 层").font(.caption).tracking(2)
                        }
                        Spacer()
                        Button { changeTier(1) } label: { Image(systemName: "chevron.right").padding(12) }.disabled(tier == 9)
                    }.foregroundStyle(ChurchGold).padding(.horizontal, 22)
                    Spacer()
                    VStack(spacing: 10) {
                        Text("第 \(selected) 层 · \(floor.title)").font(.system(size: 23, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                        Text("\(floor.waves.count) 波入侵 · \(floor.waves.map(\.count).map(String.init).joined(separator: " / ")) 名敌人")
                            .font(.footnote).foregroundStyle(.white.opacity(0.75))
                        HStack(spacing: 24) {
                            HStack(spacing: 6) {
                                Image(decorative: "RewardCoin").resizable().scaledToFit().frame(width: 21, height: 21)
                                Text("\(floor.firstClearReward.coins) 铜币")
                            }
                            HStack(spacing: 6) {
                                Image(decorative: "RewardReputation").resizable().scaledToFit().frame(width: 21, height: 21)
                                Text("\(floor.firstClearReward.merit) 功勋")
                            }
                        }.font(.subheadline).foregroundStyle(ChurchGold)
                        if let drop = MPCChurchGearCatalog.towerDrop(floor: selected) {
                            Text(game.churchTowerProgress.clearedFloors.contains(selected) ? "已获得装备 · \(drop.name)" : "首次封堵掉落 · \(drop.name)")
                                .font(.footnote.bold()).foregroundStyle(.cyan)
                        }
                        ChurchTowerArtButton(
                            title: game.churchTowerProgress.clearedFloors.contains(selected) ? .returnSeal : .enterSeal,
                            enabled: available
                        ) { launch(selected) }
                        if !available {
                            Text(entryBlockReason).font(.caption).foregroundStyle(.white.opacity(0.65))
                        }
                        if !error.isEmpty { Text(error).font(.caption).foregroundStyle(.orange) }
                    }.padding(20).frame(maxWidth: .infinity).background(.black.opacity(0.65)).overlay(alignment: .top) { Rectangle().fill(ChurchGold.opacity(0.6)).frame(height: 1) }
                }
                // Metal seals remain native hit targets, independent of the painted path.
                ForEach(0..<10) { index in
                    let point = sealPoints[index]
                    let number = tier * 10 + index + 1
                    let cleared = game.churchTowerProgress.clearedFloors.contains(number)
                    let unlocked = game.churchTowerProgress.canEnter(number, completedMissionNumbers: game.churchTowerMissionNumbers)
                        && game.towerFloorIsOpenToday(number)
                    Button { selected = number } label: {
                        ZStack {
                            Circle().fill(RadialGradient(colors: [selected == number ? Color.purple.opacity(0.9) : Color(red: 0.12, green: 0.11, blue: 0.15), .black], center: .center, startRadius: 0, endRadius: 30))
                            Circle().stroke(LinearGradient(colors: [ChurchGold, .brown, ChurchGold.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: selected == number ? 3 : 1.5)
                            Circle().stroke(ChurchGold.opacity(0.35), lineWidth: 1).padding(5)
                            Text(cleared ? "✓" : "\(number)").font(.system(size: 21, weight: .bold, design: .serif)).foregroundStyle(unlocked || cleared ? ChurchGold : .gray)
                        }.frame(width: 37, height: 37).shadow(color: selected == number ? .purple.opacity(0.8) : .clear, radius: 13)
                    }.buttonStyle(.plain).accessibilityLabel("第\(number)层，\(cleared ? "已封堵，可重打" : unlocked ? "可进入" : !game.towerFloorIsOpenToday(number) ? (game.towerPacingLockText ?? "今日未开放") : "未解锁")")
                    .position(x: geo.size.width * point.x, y: geo.size.height * (0.06 + point.y * 0.82))
                }
            }
        }.foregroundStyle(.white).preferredColorScheme(.dark).buttonStyle(.plain)
        .onAppear(perform: selectNextUncleared)
        // A full-screen battle does not re-trigger onAppear on return; point
        // at the next floor as soon as the cover closes.
        .onChange(of: battleDestination == nil) { _, closed in if closed { selectNextUncleared() } }
        .fullScreenCover(item: $battleDestination) { destination in
            ChurchTowerBattleView(game: game, floor: destination.floor, initialSession: destination.session,
                onExit: { battleDestination = nil }, onNext: { launch(destination.floor + 1) }).id(destination.id)
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("--verify-church-entry") { launch(1) }
        }
    }
    private func changeTier(_ delta: Int) { tier = min(9, max(0, tier + delta)); selected = tier * 10 + 1 }
    /// Why the selected floor cannot be entered, most fundamental first.
    private var entryBlockReason: String {
        let missions = game.churchTowerMissionNumbers
        if !MPCChurchTowerCatalog.isUnlocked(completedMissionNumbers: missions) { return MPCChurchTowerCatalog.lockText }
        if !game.churchRemoteServicesAvailable { return game.churchRemoteContactPauseReason }
        if floor.requiredMission > 0, !missions.contains(floor.requiredMission) { return "完成主线第 \(floor.requiredMission) 关后取得下井许可" }
        if !game.churchTowerProgress.canEnter(selected, completedMissionNumbers: missions) { return "先封堵上一层" }
        return game.towerPacingLockText ?? ""
    }
    private func selectNextUncleared() { let next = min(100, (game.churchTowerProgress.clearedFloors.max() ?? 0) + 1); selected = next; tier = (next - 1) / 10 }
    private func launch(_ number: Int) {
        do {
            let prepared = try game.churchTowerSession(floor: number)
            selected = number; tier = (number - 1) / 10
            battleDestination = BattleDestination(floor: number, session: prepared)
        }
        catch { self.error = game.towerFloorIsOpenToday(number) ? "封线暂不可进入，请检查前层与主线许可。" : (game.towerPacingLockText ?? "") }
    }
}

let ChurchGold = Color(red: 0.89, green: 0.76, blue: 0.46)
private struct ChurchResourceBalanceBar: View {
    let merit: Int
    let coins: Int
    var meritLabel = "功勋"

    var body: some View {
        HStack(spacing: 0) {
            balance(meritLabel, amount: merit, artName: "RewardReputation")
            Rectangle()
                .fill(ChurchGold.opacity(0.35))
                .frame(width: 1, height: 20)
                .accessibilityHidden(true)
            balance("铜币", amount: coins, artName: "RewardCoin")
        }
        .frame(maxWidth: 300, minHeight: 42)
        .background(.black.opacity(0.76))
        .overlay(alignment: .top) { Rectangle().fill(ChurchGold.opacity(0.45)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(ChurchGold.opacity(0.32)).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("当前资源")
    }

    private func balance(_ title: String, amount: Int, artName: String) -> some View {
        HStack(spacing: 6) {
            Image(decorative: artName)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(0.85))
            Text("\(amount)")
                .font(.system(size: 17, weight: .semibold, design: .serif))
                .monospacedDigit()
                .foregroundStyle(ChurchGold)
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(amount)")
    }
}
struct ChurchSceneHeader: View {
    let title: String
    let subtitle: String
    let onBack: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            GameArtReturnButton(title: "返回", action: onBack)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 25, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.65))
                }
            }
            Spacer()
        }.padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
    }
}
struct ChurchActionButton: View {
    let title: String
    var enabled = true
    let action: () -> Void
    var body: some View {
        Button { GameInterfaceSound.shared.playClick(); action() } label: {
            Text(title).font(.system(size: 18, weight: .bold, design: .serif)).tracking(1).foregroundStyle(ChurchGold)
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.leading, 52)
                .background {
                    Image("ButtonArt29ChurchAction")
                        .resizable(capInsets: EdgeInsets(top: 24, leading: 92, bottom: 24, trailing: 92), resizingMode: .stretch)
                        .accessibilityHidden(true)
                }
        }.buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.45)
    }
}

private struct ChurchIllustratedActionButton: View {
    let title: String
    let artName: String
    var enabled = true
    var maxWidth: CGFloat = 220
    var visibleHeight: CGFloat? = nil
    let action: () -> Void

    var body: some View {
        Button {
            GameInterfaceSound.shared.playClick()
            action()
        } label: {
            Image(decorative: artName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxWidth)
                .frame(height: visibleHeight)
                .clipped()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(title)
        .frame(maxWidth: .infinity)
    }
}

private enum ChurchTowerArtTitle: String {
    case enterSeal = "进入封印"
    case returnSeal = "重返封线"
    case nextFloor = "准备下一层"
    case backToWell = "返回深井"

    var assetName: String {
        switch self {
        case .enterSeal: return "ButtonArtChurchTowerEntry"
        case .returnSeal: return "ButtonArtChurchTowerReturn"
        case .nextFloor: return "ButtonArtChurchTowerNext"
        case .backToWell: return "ButtonArtChurchTowerBack"
        }
    }
}

private struct ChurchTowerArtButton: View {
    let title: ChurchTowerArtTitle
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            GameInterfaceSound.shared.playClick()
            action()
        } label: {
            Image(decorative: title.assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 300)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .accessibilityLabel(title.rawValue)
    }
}

private struct ChurchTowerBattleView: View {
    @Bindable var game: GameStore
    let floor: Int
    let initialSession: MPCChapterOneEncounterSession
    let onExit: () -> Void
    let onNext: () -> Void
    @State private var loanBattleID = UUID().uuidString
    @State private var started = false
    @State private var skills: [FoolSkillID] = []
    @State private var victory = false
    @State private var awarded = false
    @State private var reordered = true
    @State private var configuredSession: MPCChapterOneEncounterSession?
    @State private var startError = ""

    var body: some View {
        ZStack {
            ChapterOneEncounterTestView(initialSession: configuredSession ?? initialSession,
                campaign: game.churchBattleCampaign, playerSequence: game.currentSequence,
                battleIsActive: started, automatesSkillSequence: true,
                showsStandaloneOpeningBattleButton: false,
                onVictory: { result in
                    guard !victory else { return }
                    awarded = game.settleChurchTower(floor: floor, session: result, battleID: loanBattleID)
                    victory = true
                }, onExit: { game.finishChurchLoanBattle(loanBattleID, outcome: .retreat); onExit() },
                onDefeat: { game.finishChurchLoanBattle(loanBattleID, outcome: .defeat) },
                onRetrySetup: { game.finishChurchLoanBattle(loanBattleID, outcome: .retreat); loanBattleID = UUID().uuidString; skills = []; started = false },
                onSequenceChanged: { skills = $0 },
                onSelectActiveRelic: game.selectCampaignActiveRelic,
                onSelectPassiveRelic: game.toggleCampaignRelic,
                onUseManualMask: { game.recordManualMaskUse(encounterID: initialSession.encounter.id) },
                onConsumeSupply: game.consumeCampaignSupply)
            if !started && !victory {
                ChapterOneBattleSetupOverlay(
                    availableSkills: MPCChapterOneCatalog.visibleSkills.filter {
                        game.chapterOneCampaign.unlockedSkillIDs.contains($0.id) && $0.id != .maskedWhisper
                    }, relics: [], selectedSkillIDs: $skills,
                    requiresFirstReorder: false, slotCapacity: game.chapterOneLoadoutSlotCapacity,
                    hasCompletedFirstReorder: $reordered, usesEarlyTutorialLayout: true,
                    showsStartTutorialHint: false,
                    onStart: {
                        game.saveChapterOneBattleLoadout(skills)
                        do {
                            configuredSession = try game.beginChurchTower(floor: floor, battleID: loanBattleID, skills: skills)
                            started = true
                        } catch { startError = "战场载入失败，请返回重试。" }
                    })
                if !startError.isEmpty { Text(startError).foregroundStyle(.orange) }
            }
            if victory {
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack(spacing: 16) {
                    Image("BattleVictoryCrest").resizable().scaledToFit().frame(height: 140)
                    Text("第 \(floor) 层封堵完成").font(.title.bold()).foregroundStyle(.yellow)
                    Text(awarded ? "+\(MPCChurchTowerCatalog.floor(number: floor)?.firstClearReward.coins ?? 0) 铜币    +\(MPCChurchTowerCatalog.floor(number: floor)?.firstClearReward.merit ?? 0) 功勋" : "已领取过首通奖励")
                    if game.localWorkshop.materialReceipts.contains(loanBattleID) {
                        Text("获得盾颚韧皮 ×1 · 已收入背包").foregroundStyle(.mint)
                    }
                    if awarded, let drop = MPCChurchGearCatalog.towerDrop(floor: floor) {
                        Text("获得装备 · \(drop.name)").foregroundStyle(.cyan)
                    }
                    if game.churchTowerProgress.canEnter(floor + 1, completedMissionNumbers: game.churchTowerMissionNumbers),
                       game.towerFloorIsOpenToday(floor + 1) {
                        ChurchTowerArtButton(title: .nextFloor) { onNext() }
                    } else if let lock = game.towerPacingLockText, !game.churchTowerProgress.clearedFloors.contains(floor + 1) {
                        Text(lock).font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                    ChurchTowerArtButton(title: .backToWell) { onExit() }
                }.foregroundStyle(.white)
            }
        }.preferredColorScheme(.dark).buttonStyle(.plain)
        .onAppear { NSLog("CHURCH_TOWER_ENTRY_PRESENTED floor=%d enemies=%d setup=visible", floor, initialSession.enemies.count) }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--verify-church-entry") else { return }
            try? await Task.sleep(for: .seconds(8))
            let runtime = UnityBattleRuntime.shared
            NSLog("CHURCH_TOWER_ENTRY_READY unity=%d anchors=%d", runtime.isReady ? 1 : 0, runtime.enemyHealthAnchorViewports.count)
            if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                if let png = image.pngData() {
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("church-entry-check.png")
                    try? png.write(to: url)
                }
            }
        }
    }
}

private enum ChurchGearArtwork {
    static func name(for id: String) -> String? {
        switch id {
        case "tower-f02-jaw-edge": "ChurchGearJawEdge"
        case "tower-f04-seal-plate": "ChurchGearSealPlate"
        case "tower-f06-salt-knife": "ChurchGearSaltKnife"
        case "tower-f08-joint-guard": "ChurchGearJawGuard"
        case "bounty-b07-bell-throat": "ChurchGearBellThroat"
        default: nil
        }
    }

    static func bonus(for item: MPCChurchGearItem) -> String {
        if item.slot == .weapon { return "伤害 +\(item.stats.attackBP / 100)%" }
        return "生命 +\(item.stats.maxHP) · 减伤 \(item.stats.damageReductionBP / 100)%"
    }

    static func comparison(_ candidate: MPCChurchGearItem, with current: MPCChurchGearItem?) -> String {
        guard let current else { return "首次穿戴 · 属性立即生效" }
        if candidate.slot == .weapon {
            let change = (candidate.stats.attackBP - current.stats.attackBP) / 100
            return change == 0 ? "与当前伤害相同" : "比当前伤害 \(signed(change))%"
        }
        let hp = candidate.stats.maxHP - current.stats.maxHP
        let reduction = (candidate.stats.damageReductionBP - current.stats.damageReductionBP) / 100
        return "比当前生命 \(signed(hp)) · 减伤 \(signed(reduction))%"
    }

    private static func signed(_ value: Int) -> String { value >= 0 ? "+\(value)" : "\(value)" }
}

private struct ChurchGearItemArt: View {
    let item: MPCChurchGearItem?
    let slot: MPCChurchGearItem.Slot
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.09, green: 0.09, blue: 0.14).opacity(0.92))
            RoundedRectangle(cornerRadius: 10)
                .stroke(ChurchGold.opacity(0.36), lineWidth: 0.8)
            if let item, let artName = ChurchGearArtwork.name(for: item.id) {
                Image(decorative: artName)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: slot == .weapon ? "sword" : "shield.lefthalf.filled")
                    .font(.system(size: size * 0.4, weight: .ultraLight))
                    .foregroundStyle(ChurchGold.opacity(item == nil ? 0.4 : 0.8))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct ChurchGearEquippedCard: View {
    let slot: MPCChurchGearItem.Slot
    let item: MPCChurchGearItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(slot == .weapon ? "武器" : "护甲")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(ChurchGold)
                Spacer()
                Text(item == nil ? "空栏位" : "穿戴中")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
            }
            ChurchGearItemArt(item: item, slot: slot, size: 86)
                .frame(maxWidth: .infinity)
            Text(item?.name ?? "尚未穿戴")
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(item.map(ChurchGearArtwork.bonus(for:)) ?? "通过封线或通缉取得")
                .font(.caption2)
                .foregroundStyle(ChurchGold.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.06, green: 0.06, blue: 0.1).opacity(0.92)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(ChurchGold.opacity(0.4), lineWidth: 0.8))
        .accessibilityElement(children: .combine)
    }
}

private struct ChurchGearChoiceRow: View {
    let item: MPCChurchGearItem
    let current: MPCChurchGearItem?
    let selected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ChurchGearItemArt(item: item, slot: item.slot, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Text(ChurchGearArtwork.bonus(for: item))
                        .font(.subheadline)
                        .foregroundStyle(ChurchGold)
                    Text(ChurchGearArtwork.comparison(item, with: current))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                    Text(item.source)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.48))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: 17))
                    .foregroundStyle(selected ? ChurchGold : .white.opacity(0.52))
                    .accessibilityHidden(true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.065, green: 0.065, blue: 0.1).opacity(0.92)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? ChurchGold : ChurchGold.opacity(0.25), lineWidth: selected ? 1.4 : 0.8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择\(item.name)，\(ChurchGearArtwork.bonus(for: item))，\(ChurchGearArtwork.comparison(item, with: current))")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

/// The separate bounty slot: one relic from a closed case, worn in every battle.
struct BountyRelicSlotSection: View {
    @Bindable var game: GameStore
    @State private var notice = ""

    var body: some View {
        let ledger = game.churchServices.bountyRelics
        let owned = MPCBountyRelicCatalog.all.filter { ledger.ownedIDs.contains($0.id) }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("通缉栏")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(ChurchGold)
                Spacer()
                Text(ledger.equippedID.flatMap { MPCBountyRelicCatalog.relic($0) }?.name ?? "未装备")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.78))
            }
            Text("结案得到的遗落物放在这里，一次带一件，专门对付某种敌人手段。")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.68))
                .fixedSize(horizontal: false, vertical: true)
            if owned.isEmpty {
                Text("还没有遗落物。在悬赏卷宗里接案、结案就能拿到。")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach(owned) { relic in
                let worn = ledger.equippedID == relic.id
                Button {
                    GameInterfaceSound.shared.playClick()
                    do { try game.equipBountyRelic(worn ? nil : relic.id); notice = "" }
                    catch { notice = "没换成，稍后再试。" }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: worn ? "checkmark.seal.fill" : "seal")
                            .foregroundStyle(worn ? ChurchGold : .white.opacity(0.5))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(relic.name).font(.subheadline.bold()).foregroundStyle(.white)
                            Text(relic.detail).font(.caption).foregroundStyle(.white.opacity(0.72))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Text(worn ? "取下" : "装上").font(.caption.bold()).foregroundStyle(ChurchGold)
                    }
                    .padding(12)
                    .background(Color.black.opacity(worn ? 0.62 : 0.42), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(ChurchGold.opacity(worn ? 0.7 : 0.18), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(relic.name)，\(worn ? "已装备，点按取下" : "点按装上")")
            }
            if !notice.isEmpty { Text(notice).font(.footnote).foregroundStyle(ChurchGold) }
        }
    }
}

struct ChurchGearArmoryView: View {
    @Bindable var game: GameStore
    let onBack: () -> Void
    @State private var notice = ""
    @State private var selectedSlot: MPCChurchGearItem.Slot = .weapon
    @State private var selectedGearID: String?

    var body: some View {
        let ledger = game.churchServices.gear
        let owned = MPCChurchGearCatalog.all.filter { ledger.ownedIDs.contains($0.id) }
        let weapon = ledger.equippedWeaponID.flatMap(MPCChurchGearCatalog.item)
        let armor = ledger.equippedArmorID.flatMap(MPCChurchGearCatalog.item)
        let current = selectedSlot == .weapon ? weapon : armor
        let choices = owned.filter { $0.slot == selectedSlot && $0.id != current?.id }
            .sorted { $0.strength > $1.strength }
        let selected = choices.first { $0.id == selectedGearID }
        ZStack {
            Color(red: 0.035, green: 0.04, blue: 0.075).ignoresSafeArea()
            GeometryReader { geometry in
                Image("ChurchJointSanctuary")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .opacity(0.34)
            }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            LinearGradient(colors: [.black.opacity(0.12), .black.opacity(0.84)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                ChurchSceneHeader(title: "封线装备", subtitle: "武器与护甲 · 已拥有 \(owned.count) 件", onBack: onBack)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.035, green: 0.04, blue: 0.075).opacity(0.94))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(ChurchGold.opacity(0.28)).frame(height: 0.7)
                    }
                ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("当前装备")
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundStyle(ChurchGold)
                        HStack(spacing: 10) {
                            ChurchGearEquippedCard(slot: .weapon, item: weapon)
                            ChurchGearEquippedCard(slot: .armor, item: armor)
                        }
                        Text("武器、护甲各穿一件。深井新装备更强时会自动穿上；工坊装备需手动穿戴，并定期修理。")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.73))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 3)
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("更换装备")
                                .font(.system(size: 20, weight: .semibold, design: .serif))
                                .foregroundStyle(ChurchGold)
                            Spacer()
                            Text("选一件 → 查看差异 → 穿戴")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.68))
                        }
                        HStack(spacing: 0) {
                            slotButton(.weapon, count: owned.filter { $0.slot == .weapon }.count)
                            slotButton(.armor, count: owned.filter { $0.slot == .armor }.count)
                        }
                        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 10))
                        ForEach(choices) { item in
                            ChurchGearChoiceRow(item: item, current: current, selected: selectedGearID == item.id) {
                                GameInterfaceSound.shared.playClick()
                                selectedGearID = item.id
                                notice = ""
                            }
                        }
                        if choices.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: selectedSlot == .weapon ? "sword" : "shield.lefthalf.filled")
                                    .font(.system(size: 30, weight: .ultraLight))
                                    .foregroundStyle(ChurchGold.opacity(0.6))
                                    .accessibilityHidden(true)
                                Text(owned.isEmpty ? "尚未取得封线装备" : "这一栏暂无可替换装备")
                                    .foregroundStyle(.white.opacity(0.82))
                                Text(owned.isEmpty ? "封堵深井第 2 层可获得首件武器；第 4 层可获得护甲。" : "继续封堵深井，就能取得更多装备。")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.58))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .padding(.horizontal, 12)
                            .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 12))
                        }
                        if !notice.isEmpty {
                            Text(notice)
                                .font(.footnote)
                                .foregroundStyle(ChurchGold)
                        }
                    }
                    .padding(.horizontal, 20)

                    WorkshopGearCareSection(game: game)
                        .padding(.horizontal, 20)
                    BountyRelicSlotSection(game: game)
                        .padding(.horizontal, 20)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)
                }
                .clipped()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let selected {
                VStack(alignment: .leading, spacing: 4) {
                    Text("准备换上 · \(selected.name)")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                    Text(ChurchGearArtwork.comparison(selected, with: current))
                        .font(.caption)
                        .foregroundStyle(ChurchGold)
                    ChurchIllustratedActionButton(title: "穿戴\(selected.name)", artName: "ButtonArtChurchGearEquipDark", maxWidth: 220, visibleHeight: 52) {
                        do {
                            try game.equipChurchGear(selected.id)
                            notice = "已穿戴\(selected.name)"
                            selectedGearID = nil
                        } catch {
                            notice = "装备未能穿戴，请重试。"
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.045, green: 0.045, blue: 0.075).opacity(0.98))
                .overlay(alignment: .top) { Rectangle().fill(ChurchGold.opacity(0.42)).frame(height: 0.8) }
            }
        }
        .foregroundStyle(.white).preferredColorScheme(.dark).buttonStyle(.plain)
    }

    private func slotButton(_ slot: MPCChurchGearItem.Slot, count: Int) -> some View {
        let active = selectedSlot == slot
        return Button {
            GameInterfaceSound.shared.playClick()
            selectedSlot = slot
            selectedGearID = nil
            notice = ""
        } label: {
            VStack(spacing: 3) {
                Text(slot == .weapon ? "武器 · \(count)" : "护甲 · \(count)")
                    .font(.subheadline.weight(.semibold))
                Rectangle().fill(active ? ChurchGold : .clear).frame(height: 2)
            }
            .foregroundStyle(active ? ChurchGold : .white.opacity(0.58))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 6)
            .padding(.top, 11)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}

struct ChurchSanctuaryView: View {
    @Bindable var game: GameStore
    @Environment(\.dismiss) private var dismiss
    @State private var destination = ProcessInfo.processInfo.arguments.contains("--verify-church-entry") ? "tower" : "hall"
    var body: some View {
        ZStack {
            switch destination {
            case "tower": ChurchTowerView(game: game, onBack: { destination = "hall" })
            case "bounty": ChurchBountyBoard(game: game, onBack: { destination = "hall" })
            case "maintenance": ChurchMaintenanceView(game: game, onBack: { destination = "hall" })
            case "loans": ChurchLoanCabinet(game: game, onBack: { destination = "hall" })
            case "gear": ChurchGearArmoryView(game: game, onBack: { destination = "hall" })
            default: game.churchHasDepartedMistport ? AnyView(remoteContact) : AnyView(hall)
            }
        }.preferredColorScheme(.dark).buttonStyle(.plain)
    }
    @State private var contactNotice = ""
    private var remoteContact: some View {
        ZStack {
            Color(red: 0.025, green: 0.035, blue: 0.06).ignoresSafeArea()
            GeometryReader { g in Image("ChurchLoanCabinet").resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped().opacity(0.24) }.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ChurchSceneHeader(title: "黑盐岸联络簿", subtitle: "三教会 · 封堵凭据", onBack: { dismiss() })
                    Text("雾港的灯已经远去。你随身带来的封堵记录，仍属于同一口深井。").font(.system(size: 21, design: .serif)).lineSpacing(7)
                    Text("联络员核对了检疫航线、原档与救援回执。你的层数、功勋和封存品押金，无需重新登记。").font(.body).foregroundStyle(.white.opacity(0.8)).lineSpacing(6)
                    Text("已封堵 \(game.churchTowerProgress.clearedFloors.count) 层 · 功勋 \(game.chapterOneCampaign.spendableChurchMerit)").foregroundStyle(ChurchGold)
                    if game.churchNeedsRemoteContact {
                        ChurchActionButton(title: "核对凭据 · 接通封线") {
                            do { _ = try game.establishChurchRemoteContact() } catch { contactNotice = "凭据尚未核对，请重试。" }
                        }
                    } else {
                        ChurchActionButton(title: "继续联封深井") { destination = "tower" }
                        ChurchActionButton(title: "封线维护") { destination = "maintenance" }
                    }
                    ChurchActionButton(title: "封存品与借物账") { destination = "loans" }
                    ChurchActionButton(title: "封线装备") { destination = "gear" }
                    ChurchActionButton(title: "查看悬赏卷宗") { destination = "bounty" }
                    if game.churchPendingRewardCount > 0 {
                        ChurchActionButton(title: "结清已完成委托") {
                            do { try game.claimCompletedChurchAccounts() } catch { contactNotice = "账目保留，请稍后重试。" }
                        }
                    }
                    Text("封线巡查暂缓；每日通缉仍可从卷宗返回港城调查。")
                        .font(.footnote).foregroundStyle(.white.opacity(0.55))
                    if !contactNotice.isEmpty { Text(contactNotice).foregroundStyle(.orange) }
                }.padding(22)
            }
        }.foregroundStyle(ChurchGold)
    }
    private var hall: some View {
        GeometryReader { geo in
            ZStack {
                Image("ChurchJointSanctuary").resizable().scaledToFill().frame(width: geo.size.width, height: geo.size.height).clipped().ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.8), .clear, .clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                VStack {
                    ChurchSceneHeader(title: "三教会联合圣所", subtitle: "守灯 · 观镜 · 缄卷", onBack: { dismiss() })
                    ChurchResourceBalanceBar(merit: game.chapterOneCampaign.spendableChurchMerit, coins: game.venueCoins)
                    Spacer(minLength: 24)
                    HStack(spacing: 8) {
                        majorEntrance("联封深井", subtitle: "百层封印") { destination = "tower" }
                        majorEntrance("悬赏卷宗", subtitle: "每日追缉") { destination = "bounty" }
                    }
                    .padding(.horizontal, 20)
                    HStack(spacing: 0) {
                        serviceEntrance("封线维护", subtitle: "巡查工单") { destination = "maintenance" }
                        Rectangle()
                            .fill(ChurchGold.opacity(0.28))
                            .frame(width: 1)
                            .padding(.vertical, 8)
                            .accessibilityHidden(true)
                        serviceEntrance("封线装备", subtitle: "已拥有 \(game.churchServices.gear.ownedIDs.count) 件") { destination = "gear" }
                    }
                    .frame(height: 54)
                    .background(.black.opacity(0.82))
                    .overlay(alignment: .top) { Rectangle().fill(ChurchGold.opacity(0.58)).frame(height: 1) }
                    .overlay(alignment: .bottom) { Rectangle().fill(ChurchGold.opacity(0.34)).frame(height: 1) }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    Button { destination = "loans" } label: {
                        ZStack(alignment: .leading) {
                            Image(decorative: "ButtonArtChurchLoanEntryRental")
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width - 40, height: (geo.size.width - 40) * 226 / 1050)
                                .clipped()
                            Image("RelicDeferredStamp")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 52, height: 52)
                                .padding(.leading, 14)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("封存借物处，累计功勋决定资格，铜币支付可退押金与不退租金")
                    .padding(.horizontal, 20)
                    .padding(.top, 13)
                    .padding(.bottom, 20)
                }
            }
        }.foregroundStyle(ChurchGold)
    }
    private func majorEntrance(_ title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.92, green: 0.86, blue: 0.75))
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.76, green: 0.67, blue: 0.54))
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.leading, 15)
            .background {
                LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.80)], startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [ChurchGold.opacity(0.88), ChurchGold.opacity(0.18)], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 1)
                    .padding(.horizontal, 15)
                    .padding(.bottom, 4)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(subtitle)")
    }
    private func serviceEntrance(_ title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.91, green: 0.85, blue: 0.74))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .foregroundStyle(Color(red: 0.72, green: 0.64, blue: 0.52))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            .padding(.leading, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(subtitle)")
    }
}

struct ChurchBountyBoard: View {
    @Bindable var game: GameStore
    let onBack: () -> Void
    var origin = "教会"
    @State private var selected: String?
    @State private var showsClosed = false
    @State private var showsRemnants = false
    private let crimson = Color(red: 0.70, green: 0.28, blue: 0.25)
    private var issue: MPCDailyBountyIssue? { game.churchServices.dailyBountyIssue }
    private var ongoing: [MPCChurchBounty] {
        MPCChurchBountyCatalog.all.filter {
            game.churchServices.bounties.cases[$0.id]?.accepted == true
                && game.churchServices.bounties.cases[$0.id]?.claimed != true
        }
    }
    private var fresh: [MPCChurchBounty] {
        (issue?.offerIDs ?? []).compactMap(MPCChurchBountyCatalog.bounty(id:)).filter {
            game.churchServices.bounties.cases[$0.id]?.accepted != true
                && game.churchServices.bounties.cases[$0.id]?.claimed != true
        }
    }
    private var closed: [MPCChurchBounty] {
        MPCChurchBountyCatalog.all.filter { game.churchServices.bounties.cases[$0.id]?.claimed == true }
    }
    var body: some View {
        if let selected, let bounty = MPCChurchBountyCatalog.bounty(id: selected) {
            ChurchBountyDossier(game: game, bounty: bounty, origin: origin, onBack: { self.selected = nil })
        } else {
            ZStack {
                GeometryReader { geo in
                    Image("ChurchBountyBoard")
                        .resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }.ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.72), Color(red: 0.08, green: 0.05, blue: 0.055).opacity(0.40), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    ChurchSceneHeader(title: "雾港·通缉档案", subtitle: origin == "酒馆" ? "酒馆与教会共同张贴" : "教会与酒馆共同张贴", onBack: onBack)
                        .background(.black.opacity(0.55))
                    Rectangle().fill(ChurchGold.opacity(0.48)).frame(height: 1)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("联合缉捕 · 每日告示")
                                        .font(.system(size: 11, weight: .semibold, design: .serif))
                                        .tracking(2)
                                        .foregroundStyle(ChurchGold.opacity(0.78))
                                    Text("今日悬赏")
                                        .font(.system(size: 31, weight: .bold, design: .serif))
                                        .foregroundStyle(Color(red: 0.96, green: 0.85, blue: 0.62))
                                }
                                Spacer()
                                Text("\(issue?.offerIDs.count ?? 0) 份在列")
                                    .font(.system(size: 12, weight: .semibold, design: .serif))
                                    .foregroundStyle(ChurchGold)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(.black.opacity(0.68))
                                    .overlay(Rectangle().stroke(ChurchGold.opacity(0.48)))
                            }
                            .padding(.top, 10)

                            HStack(alignment: .top, spacing: 12) {
                                Text("!")
                                    .font(.system(size: 15, weight: .bold, design: .serif))
                                    .foregroundStyle(crimson)
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(crimson.opacity(0.75)))
                                    .accessibilityHidden(true)
                                Text("接案前请辨认罪行与招式。阵亡可重试；每次战败有 35% 概率遗失随身铜币，随身遗落物不会遗失。")
                                    .font(.system(size: 12, weight: .medium, design: .serif))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .foregroundStyle(.white.opacity(0.86))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 0.13, green: 0.09, blue: 0.10).opacity(0.92))
                            .overlay(alignment: .leading) { Rectangle().fill(crimson).frame(width: 2) }
                            .overlay(Rectangle().stroke(ChurchGold.opacity(0.27)))

                            if !ongoing.isEmpty {
                                sectionTitle("追缉进行中", detail: "跨日保留 · \(ongoing.count) 案")
                                ForEach(ongoing) { bounty in
                                    BountyNoticeCard(bounty: bounty, power: game.combatPower,
                                        status: game.churchServices.bounties.cases[bounty.id]?.pendingTurnIn == true ? "待交案" : "调查中") {
                                        selected = bounty.id
                                    }
                                }
                            }
                            sectionTitle("今日新帖", detail: "本地每日 00:00 更替 · 当前战力 \(game.combatPower)")
                            if fresh.isEmpty {
                                Text(issue?.offerIDs.isEmpty == true ? "目前没有尚未受理的通缉目标；已结案的卷宗不会重新张贴。" : "今天的新帖已接完，继续追查在办案件。")
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.82))
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.black.opacity(0.76))
                                    .overlay(Rectangle().stroke(ChurchGold.opacity(0.35)))
                            }
                            ForEach(fresh) { bounty in
                                BountyNoticeCard(bounty: bounty, power: game.combatPower, status: "可接案") {
                                    selected = bounty.id
                                }
                            }
                            Button("无名残余案 · 每日当地小案") { showsRemnants = true }
                                .buttonStyle(GameArtButtonStyle(primary: true))
                            if !closed.isEmpty {
                                Button { withAnimation { showsClosed.toggle() } } label: {
                                    HStack {
                                        Text("已封存卷宗 · \(closed.count)").font(.headline)
                                        Spacer()
                                        Image(systemName: showsClosed ? "chevron.up" : "chevron.down")
                                    }
                                    .foregroundStyle(ChurchGold)
                                    .padding(16)
                                    .background(.black.opacity(0.8))
                                    .overlay(Rectangle().stroke(ChurchGold.opacity(0.4)))
                                }.buttonStyle(.plain)
                                if showsClosed {
                                    ForEach(closed) { bounty in
                                        BountyNoticeCard(bounty: bounty, power: game.combatPower, status: "已结案") {
                                            selected = bounty.id
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 30)
                    }
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showsRemnants) { RemnantCasesView(game: game) }
            .onAppear { game.refreshChurchBountyBoard() }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    guard !Task.isCancelled else { break }
                    game.refreshChurchBountyBoard()
                }
            }
        }
    }
    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Rectangle().fill(ChurchGold.opacity(0.7)).frame(height: 1)
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 20, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                Spacer()
                Text(detail).font(.system(size: 11, weight: .medium, design: .serif)).foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

private struct BountyNoticeCard: View {
    let bounty: MPCChurchBounty
    let power: Int
    let status: String
    let onTap: () -> Void
    private let ink = Color(red: 0.20, green: 0.14, blue: 0.12)
    private var notice: MPCBountyNotice? { MPCBountyNoticeCatalog.notice(for: bounty.id) }
    private var enemy: MPCEnemyContent? { MPCChurchBountyCatalog.enemyDefinition(id: bounty.enemyID) }
    private var danger: (String, Color) {
        guard let enemy else { return ("未知威胁", .orange) }
        let estimate = enemy.attack * 3 + enemy.maxHP / 8 + (["b03", "b08", "b10"].contains(bounty.id) ? 100 : 0)
        let ratio = Double(power) / Double(max(1, estimate))
        if ratio < 0.55 { return ("战力悬殊", Color(red: 0.71, green: 0.15, blue: 0.19)) }
        if ratio < 0.9 { return ("高度危险", Color(red: 0.78, green: 0.32, blue: 0.14)) }
        return ("仍有风险", Color(red: 0.13, green: 0.40, blue: 0.40))
    }
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("联合通缉  /  \(bounty.id.uppercased())")
                        .font(.system(size: 10, weight: .bold, design: .serif))
                        .tracking(1.4)
                        .foregroundStyle(ink.opacity(0.72))
                    Spacer()
                    Text(status)
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundStyle(status == "可接案" ? danger.1 : ink.opacity(0.7))
                }
                Rectangle().fill(ink.opacity(0.24)).frame(height: 1)
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(bounty.title)
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(notice?.crime ?? bounty.visualIdentity)
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundStyle(ink.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image("ChurchBounty" + bounty.id)
                        .resizable().scaledToFit()
                        .frame(width: 82, height: 100)
                        .background(Color(red: 0.08, green: 0.07, blue: 0.09))
                        .clipped()
                        .overlay(Rectangle().stroke(ink.opacity(0.75), lineWidth: 2))
                        .accessibilityHidden(true)
                }
                HStack(alignment: .top, spacing: 8) {
                    Text("招式")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundStyle(danger.1)
                    Text(notice?.combat ?? "招式记录待补")
                        .foregroundStyle(ink.opacity(0.9))
                        .lineLimit(2)
                }
                .font(.system(size: 12, weight: .medium, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
                Rectangle().fill(ink.opacity(0.27)).frame(height: 1)
                HStack(spacing: 6) {
                    Text(danger.0)
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundStyle(danger.1)
                    if let enemy {
                        Text("生命 \(enemy.maxHP) · 攻击 \(enemy.attack)")
                            .font(.system(size: 10, weight: .medium, design: .serif))
                            .foregroundStyle(ink.opacity(0.72))
                    }
                    Spacer(minLength: 2)
                    reward("RewardCoin", value: bounty.copper)
                    reward("RewardReputation", value: bounty.merit)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Image(decorative: "BountyNoticeParchment")
                    .resizable().scaledToFill()
            }
            .clipped()
            .overlay(Rectangle().stroke(Color(red: 0.35, green: 0.23, blue: 0.13), lineWidth: 2))
            .overlay(alignment: .topLeading) { cornerMark.rotationEffect(.degrees(180)) }
            .overlay(alignment: .topTrailing) { cornerMark.rotationEffect(.degrees(-90)) }
            .overlay(alignment: .bottomLeading) { cornerMark.rotationEffect(.degrees(90)) }
            .overlay(alignment: .bottomTrailing) { cornerMark }
            .shadow(color: .black.opacity(0.5), radius: 7, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(bounty.title)，\(danger.0)，\(notice?.crime ?? "")，\(notice?.combat ?? "")，赏金\(bounty.copper)铜币和\(bounty.merit)功勋")
    }
    private var cornerMark: some View {
        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 7)
            .fill(Color(red: 0.39, green: 0.25, blue: 0.13))
            .frame(width: 10, height: 10)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
    private func reward(_ artName: String, value: Int) -> some View {
        HStack(spacing: 3) {
            Image(decorative: artName).resizable().scaledToFit().frame(width: 16, height: 16)
            Text("\(value)").font(.system(size: 12, weight: .bold, design: .serif)).monospacedDigit()
        }
        .foregroundStyle(ink)
    }
}

private struct BountyDossierArtButton: View {
    let title: String
    let artName: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            GameInterfaceSound.shared.playClick()
            action()
        } label: {
            GeometryReader { geometry in
                Image(decorative: artName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .frame(height: 54)
            .frame(maxWidth: 460)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .saturation(enabled ? 1 : 0.3)
        .opacity(enabled ? 1 : 0.78)
        .accessibilityLabel(title)
        .frame(maxWidth: .infinity)
    }
}

private struct ChurchBountyDossier: View {
    @Bindable var game: GameStore
    let bounty: MPCChurchBounty
    var origin = "教会"
    let onBack: () -> Void
    @State private var showsInvestigationMap = false
    @State private var nodeID: String?
    @State private var notice = ""
    @State private var battlePresented = false
    private var progress: MPCChurchBountyProgress { game.churchServices.bounties.cases[bounty.id] ?? .init() }
    private var offeredToday: Bool { game.churchServices.dailyBountyIssue?.offerIDs.contains(bounty.id) == true }
    private var profileNotice: MPCBountyNotice? { MPCBountyNoticeCatalog.notice(for: bounty.id) }
    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image(origin == "酒馆" ? "BountyTavernInterior" : "ChurchBountyBoard")
                    .resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
            }.ignoresSafeArea().opacity(0.25)
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 0) {
                ChurchSceneHeader(title: bounty.title, subtitle: "悬赏 \(bounty.copper) 铜币 · \(bounty.merit) 功勋", onBack: onBack)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 18) {
                            Image("ChurchBounty" + bounty.id).resizable().scaledToFit().frame(width: 100, height: 130).background(.black.opacity(0.7)).overlay(Rectangle().stroke(ChurchGold.opacity(0.65))).overlay(Rectangle().stroke(ChurchGold.opacity(0.25)).padding(4))
                            VStack(alignment: .leading, spacing: 10) {
                                Text(progress.claimed ? "卷宗已封存" : progress.victoriousBattleID != nil ? "待回柜台交案" : progress.evidenceIDs.contains("identity") ? "身份已核实" : "身份待核").font(.system(size: 22, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                                Text(bounty.visualIdentity).font(.footnote).foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        if let notice = profileNotice {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("所犯之事").font(.caption.bold()).foregroundStyle(ChurchGold)
                                Text(notice.crime).font(.body)
                                Text("已知招式").font(.caption.bold()).foregroundStyle(ChurchGold)
                                Text(notice.combat).font(.body)
                                Text(notice.warning).font(.footnote).foregroundStyle(.orange)
                                if let enemy = MPCChurchBountyCatalog.enemyDefinition(id: bounty.enemyID) {
                                    Text("目标生命 \(enemy.maxHP) · 攻击 \(enemy.attack)   /   当前战力 \(game.combatPower)")
                                        .font(.footnote.bold()).foregroundStyle(.white.opacity(0.8))
                                }
                            }
                            .padding(15)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        if !offeredToday && !progress.accepted && !progress.claimed {
                            Text("本案今日未张贴。明日告示更新后可再查看。").font(.footnote).foregroundStyle(ChurchGold)
                        }
                        if !progress.claimed {
                            Text("战败可重试，但每次阵亡有 35% 概率遗失最多 60 铜币。随身遗落物不会遗失。")
                                .font(.footnote).foregroundStyle(Color(red: 1, green: 0.67, blue: 0.58))
                        }
                        if let relic = MPCBountyRelicCatalog.relic(forCase: bounty.id) {
                            Text(progress.claimed ? "结案遗落物已获得 · \(relic.name)" : "结案遗落物 · \(relic.name)")
                                .font(.footnote.bold()).foregroundStyle(.cyan)
                            Text(relic.detail).font(.footnote).foregroundStyle(.white.opacity(0.75))
                        }
                        if progress.claimed { Text(bounty.closure).font(.body).foregroundStyle(.white.opacity(0.85)) }
                        else {
                            if !progress.accepted {
                                BountyDossierArtButton(title: "确认风险 · 领取调查委托", artName: "ButtonArtBountyAccept", enabled: offeredToday) {
                                    perform { try game.acceptChurchBounty(bounty.id) }
                                }
                            }
                            if progress.victoriousBattleID != nil {
                                Text("现场已收押。回教会或酒馆柜台交案，报酬和遗落物一起领。")
                                    .font(.footnote).foregroundStyle(ChurchGold)
                                ChurchActionButton(title: "交案并领取报酬",
                                                   enabled: ["教会", "酒馆"].contains(progress.currentLocation)) {
                                    perform { try game.claimChurchBounty(bounty.id) }
                                }
                            } else {
                            BountyDossierArtButton(title: "进入雾港调查", artName: "ButtonArtBountyInvestigate", enabled: progress.accepted) {
                                NotificationCenter.default.post(name: .homeQuestFocus, object: bounty.id)
                            }
                            }
                            ForEach(bounty.nodes) { node in
                                let found = progress.evidenceIDs.contains(node.id)
                                Button {
                                    if found { nodeID = node.id } else { NotificationCenter.default.post(name: .homeQuestFocus, object: bounty.id) }
                                } label: {
                                    HStack(spacing: 14) {
                                        Text(found ? "◆" : "◇").font(.title2).foregroundStyle(found ? ChurchGold : .gray)
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(node.location).font(.system(size: 18, weight: .semibold, design: .serif)).foregroundStyle(ChurchGold)
                                            Text(found ? node.evidence : "到场寻找\(node.speaker)或现场物证").font(.footnote).foregroundStyle(.white.opacity(0.7))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").foregroundStyle(ChurchGold.opacity(0.7))
                                    }.padding(.vertical, 14).overlay(alignment: .bottom) { Rectangle().fill(ChurchGold.opacity(0.25)).frame(height: 1) }
                                }.buttonStyle(.plain)
                            }
                            if let pending = progress.activeBattleID {
                                Text("上次追缉尚未结清；放弃按撤退结算，证据保留。").font(.footnote).foregroundStyle(ChurchGold)
                                ChurchActionButton(title: "结清未完追缉") { perform { try game.finishChurchBounty(bounty.id, battleID: pending, outcome: .retreat) } }
                            }
                        }
                        if !notice.isEmpty { Text(notice).font(.footnote).foregroundStyle(ChurchGold) }
                    }.padding(22)
                }
            }
            if let nodeID, let node = bounty.nodes.first(where: { $0.id == nodeID }) {
                Color.black.opacity(0.88).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text(node.speaker).font(.system(size: 23, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                            Spacer()
                            GameArtReturnButton(title: "收起证词") { self.nodeID = nil; notice = "" }
                        }
                        Text(node.dialogue).font(.system(size: 18, design: .serif)).lineSpacing(8)
                        if let challenge = MPCChurchBountyCatalog.challenge(caseID: bounty.id, nodeID: nodeID), !progress.evidenceIDs.contains(nodeID) {
                            Text(challenge.question).foregroundStyle(ChurchGold)
                            ForEach(challenge.choices) { choice in
                                Button {
                                    perform { try game.answerChurchBounty(bounty.id, nodeID: nodeID, choiceID: choice.id) }
                                    notice = choice.explanation
                                } label: { Text(choice.text).font(.body).frame(maxWidth: .infinity, alignment: .leading).padding(14).overlay(Rectangle().stroke(ChurchGold.opacity(0.4))) }.buttonStyle(.plain)
                            }
                        } else {
                            Text(node.evidence).font(.footnote).foregroundStyle(ChurchGold)
                            ChurchActionButton(title: "收起证词") { self.nodeID = nil }
                        }
                        if !notice.isEmpty { Text(notice).font(.footnote).foregroundStyle(ChurchGold) }
                    }.padding(28)
                }.frame(maxHeight: 600).background(Color(red: 0.07, green: 0.055, blue: 0.065)).overlay(Rectangle().stroke(ChurchGold.opacity(0.7))).padding(18)
            }
        }.foregroundStyle(.white)
        .fullScreenCover(isPresented: $battlePresented) { ChurchBountyBattleView(game: game, bounty: bounty, onExit: { battlePresented = false }) }
        .onAppear {
            if offeredToday || progress.accepted || progress.claimed {
                try? game.visitChurchBounty(bounty.id, location: origin)
            }
        }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action() }
        catch MPCChurchBountyError.locked { notice = "今日告示已更替；请返回通缉板选新案。" }
        catch { notice = "操作尚未成立，请核对委托、地点与证据。" }
    }
}

private struct ChurchLoanPriceBreakdown: View {
    let offer: MPCChurchLoanOffer

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 0) {
                amount("押金", value: offer.deposit, note: "完好归还全退")
                Rectangle().fill(ChurchGold.opacity(0.3)).frame(width: 1, height: 45)
                amount("租金", value: offer.rentalFee, note: "三场借用，不退")
            }
            Text("签约共付 \(offer.totalDue) 铜币；累计功勋只用于资格，不扣除。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(red: 0.09, green: 0.075, blue: 0.12).opacity(0.95))
        .overlay(Rectangle().stroke(ChurchGold.opacity(0.5)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("借物费用")
    }

    private func amount(_ title: String, value: Int, note: String) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.footnote).foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 4) {
                Image(decorative: "RewardCoin").resizable().scaledToFit().frame(width: 18, height: 18)
                Text("\(value)").font(.system(size: 19, weight: .semibold, design: .serif)).monospacedDigit()
            }
            .foregroundStyle(ChurchGold)
            Text(note).font(.caption2).foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) \(value) 铜币，\(note)")
    }
}

private struct ChurchLoanCabinet: View {
    @Bindable var game: GameStore
    let onBack: () -> Void
    @State private var index = 0
    @State private var notice = ""
    private var offer: MPCChurchLoanOffer { MPCChurchLoanOffer.all[index] }
    private var loan: MPCChurchLoan? { game.churchServices.loans.loans.values.first { !$0.returned && $0.offer.relicID == offer.relicID } }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("ChurchLoanCabinet").resizable().frame(width: geo.size.width, height: geo.size.height).ignoresSafeArea()
                VStack(spacing: 10) {
                    ChurchSceneHeader(title: "封存借物处", subtitle: "", onBack: onBack)
                    ChurchResourceBalanceBar(merit: game.chapterOneCampaign.lifetimeChurchMerit, coins: game.venueCoins, meritLabel: "累计功勋")
                    HStack {
                        Button { index = (index + 7) % 8; notice = "" } label: { Image(systemName: "chevron.left").frame(width: 44, height: 60) }
                        Spacer()
                        Text(EarlyRelicShop.name(offer.relicID)).font(.system(size: 25, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                        Spacer()
                        Button { index = (index + 1) % 8; notice = "" } label: { Image(systemName: "chevron.right").frame(width: 44, height: 60) }
                    }
                    Image(EarlyRelicShop.art(offer.relicID)).resizable().scaledToFit().frame(height: geo.size.height * 0.20).shadow(color: .purple.opacity(0.5), radius: 30)
                    HStack(spacing: 9) { ForEach(0..<8) { item in Circle().fill(index == item ? ChurchGold : .gray.opacity(0.4)).frame(width: 5, height: 5) } }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if !game.churchRemoteServicesAvailable { Text(game.churchRemoteContactPauseReason).font(.footnote).foregroundStyle(ChurchGold) }
                            Text(EarlyRelicShop.detail(offer.relicID)).font(.system(size: 15, design: .serif)).lineSpacing(4)
                            Rectangle().fill(ChurchGold.opacity(0.4)).frame(height: 1)
                            if let loan {
                                Text("契约 · \(loan.remainingBattles) 场余量 · 完好度 \(loan.durability)%").font(.headline).foregroundStyle(ChurchGold)
                                let equipped = game.churchServices.equippedLoanIDs.contains(loan.id)
                                ChurchIllustratedActionButton(
                                    title: equipped ? "卸下借物" : "装备借物",
                                    artName: equipped ? "ButtonArtChurchLoanUnequip" : "ButtonArtChurchLoanEquip",
                                    enabled: loan.pendingBattleID == nil && loan.remainingBattles > 0
                                ) { perform { try game.equipChurchLoan(loan.id) } }
                                if loan.pendingBattleID != nil {
                                    Text("有一场未结清的战斗。放弃后按撤退结算一次。").font(.caption)
                                    ChurchActionButton(title: "放弃未结战斗") { if let id = loan.pendingBattleID { game.finishChurchLoanBattle(id, outcome: .retreat) } }
                                } else {
                                    let refund = loan.returnPreview
                                    if loan.isLegacyContract {
                                        Text("旧契约：可退 \(refund.copperRefund) 铜币、\(refund.meritRefund) 功勋；按原条款扣磨损费 \(refund.damageFee) 铜币。")
                                            .font(.footnote).foregroundStyle(.white.opacity(0.8))
                                    } else {
                                        Text("押金可退 \(refund.copperRefund) 铜币；已付租金 \(loan.rentalFeePaid) 铜币不退。")
                                            .font(.footnote).foregroundStyle(ChurchGold)
                                        Text(loan.durability == 0 ? "借物已损毁或遗失，押金不退。" : "正常战斗磨损不扣押金；损毁或遗失则押金全额不退。")
                                            .font(.caption).foregroundStyle(.white.opacity(0.75))
                                    }
                                    ChurchIllustratedActionButton(title: "归还并结清", artName: "ButtonArtChurchLoanReturn") { perform { try game.returnChurchRelic(loan.id) } }
                                }
                            } else {
                                ChurchLoanPriceBreakdown(offer: offer)
                                Text("正常出战磨损不扣押金；损毁或遗失才没收押金。未装备出战不消耗三场额度。").font(.caption).foregroundStyle(.white.opacity(0.75))
                                let eligible = game.churchRemoteServicesAvailable && game.churchTowerMissionNumbers.contains(offer.unlockMission) && game.chapterOneCampaign.lifetimeChurchMerit >= offer.requiredLifetimeMerit
                                Text("借用资格：第 \(offer.unlockMission) 关后 · 累计功勋 \(game.chapterOneCampaign.lifetimeChurchMerit)/\(offer.requiredLifetimeMerit)")
                                    .font(.footnote).foregroundStyle(eligible ? ChurchGold : .white.opacity(0.75))
                                ChurchIllustratedActionButton(title: "签立借物契约", artName: "ButtonArtChurchLoanContract", enabled: eligible && game.venueCoins >= offer.totalDue) { perform { try game.borrowChurchRelic(offer.relicID) } }
                            }
                            if game.chapterOneCampaign.ownedRelicIDs.contains(offer.relicID) {
                                Rectangle().fill(ChurchGold.opacity(0.35)).frame(height: 1)
                                let condition = game.churchServices.ownedCondition
                                let durability = condition.currentDurability(offer.relicID)
                                Text("自有藏品 · 完好度 \(durability)%").font(.headline).foregroundStyle(ChurchGold)
                                if condition.hasPendingBattle(offer.relicID) {
                                    Text("自有藏品尚有未结战斗，结清后可修复。").font(.caption)
                                    ChurchActionButton(title: "结清中断战斗") {
                                        for (id, relics) in condition.battleRelicIDs where relics.contains(offer.relicID) && !condition.settledBattleIDs.contains(id) { game.finishChurchLoanBattle(id, outcome: .retreat) }
                                    }
                                } else {
                                    let price = MPCChurchLoanLedger.ownedRepairPrice(value: offer.value, durability: durability)
                                    ChurchActionButton(title: "修复 · \(price) 铜币", enabled: durability < 100 && game.venueCoins >= price) { perform { try game.repairOwnedChurchRelic(offer.relicID) } }
                                    Text("归零时保留所有权，修复后恢复使用。假面裂纹与僭命勋章不在此修复。").font(.caption).foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            if !notice.isEmpty { Text(notice).font(.caption).foregroundStyle(ChurchGold) }
                        }.padding(20).background(.black.opacity(0.8)).overlay(Rectangle().stroke(ChurchGold.opacity(0.35)))
                    }.padding(.horizontal, 20)
                }
            }
        }.foregroundStyle(.white).buttonStyle(.plain)
    }
    private func perform(_ action: () throws -> Void) { do { try action(); notice = "契约已记入教会账簿。" } catch { notice = "契约未变更：请检查累计功勋、铜币或未结战斗。" } }
}

struct ChurchBountyBattleView: View {
    @Bindable var game: GameStore
    let bounty: MPCChurchBounty
    let onExit: () -> Void
    @State private var session: MPCChapterOneEncounterSession?
    @State private var skills: [FoolSkillID] = []
    @State private var started = false
    @State private var battleID = UUID().uuidString
    @State private var victory = false
    @State private var reordered = true
    @State private var error = ""
    @State private var bountyLossText: String?
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let session {
                ChapterOneEncounterTestView(initialSession: session, campaign: game.churchBattleCampaign, playerSequence: game.currentSequence,
                    battleIsActive: started, showsStandaloneOpeningBattleButton: false,
                    onVictory: { _ in
                        do { try game.finishChurchBounty(bounty.id, battleID: battleID, outcome: .victory); victory = true }
                        catch { self.error = "现场收押尚未写入卷宗，请保留本页重试。" }
                    }, onExit: { close(.retreat); onExit() },
                    onDefeat: {
                        close(.defeat)
                        if let loss = game.churchServices.bountyDefeatLosses[battleID] {
                            var lost: [String] = []
                            if loss.copper > 0 { lost.append("\(loss.copper) 铜币") }
                            if let id = loss.relicID {
                                let name = MPCChapterOneCatalog.relics.first(where: { $0.id == id })?.name ?? id
                                lost.append("遗落物「\(name)」")
                            }
                            bountyLossText = lost.isEmpty ? "本次没有遗失随身财物；线索保留，可再次追缉。" : "阵亡遗失：\(lost.joined(separator: "、"))。线索保留，可再次追缉。"
                        }
                    }, bountyLossText: bountyLossText,
                    onRetrySetup: { close(.retreat); started = false; skills = []; bountyLossText = nil; battleID = UUID().uuidString },
                    onUseManualMask: { game.recordManualMaskUse(encounterID: bounty.encounterID) }, onConsumeSupply: game.consumeCampaignSupply)
            }
            if !started && !victory {
                ChapterOneBattleSetupOverlay(availableSkills: MPCChapterOneCatalog.visibleSkills.filter { game.chapterOneCampaign.unlockedSkillIDs.contains($0.id) && $0.id != .maskedWhisper }, relics: [], selectedSkillIDs: $skills,
                    requiresFirstReorder: false, slotCapacity: game.chapterOneLoadoutSlotCapacity, hasCompletedFirstReorder: $reordered,
                    usesEarlyTutorialLayout: true, showsStartTutorialHint: false, onStart: {
                        do { session = try game.beginChurchBounty(bounty.id, battleID: battleID, skills: skills); started = true }
                        catch { self.error = "战场未能开启，请返回检查卷宗及借物契约。" }
                    })
            }
            if victory {
                Color.black.opacity(0.85).ignoresSafeArea()
                VStack(spacing: 22) {
                    Image("BattleVictoryCrest").resizable().scaledToFit().frame(height: 130)
                    Text("现场已收押").font(.system(size: 30, weight: .bold, design: .serif)).foregroundStyle(ChurchGold)
                    Text("带上现场物证，回教会或酒馆柜台陈述结果后结案。")
                        .font(.body).multilineTextAlignment(.center)
                    Text("交案奖励 · \(bounty.copper) 铜币 / \(bounty.merit) 功勋")
                        .foregroundStyle(ChurchGold)
                    ChurchActionButton(title: "回到城图", action: onExit)
                }.padding(28)
            }
            if !error.isEmpty { VStack { Spacer(); Text(error).padding().background(.black); Spacer() } }
        }.foregroundStyle(.white).onAppear {
            // Preview does not reserve a loan use or claim an investigation.
            var loadout = game.churchBattleCampaign.loadout; loadout.normalSkillIDs = []
            session = try? MPCChapterOneEncounterSession.start(encounterID: bounty.encounterID, party: game.chapterOneCampaign.party, consumables: game.chapterOneCampaign.inventory, companionIDs: [], loadout: loadout)
        }
    }
    private func close(_ outcome: MPCChurchBattleOutcome) { guard started else { return }; try? game.finishChurchBounty(bounty.id, battleID: battleID, outcome: outcome) }
}

#if DEBUG
@MainActor
func renderChurchDelivery(_ game: GameStore) {
    let views: [(String, AnyView)] = [
        ("hall", AnyView(ChurchSanctuaryView(game: game))),
        ("tower", AnyView(ChurchTowerView(game: game))),
        ("bounties", AnyView(ChurchBountyBoard(game: game, onBack: {}))),
        ("dossier", AnyView(ChurchBountyDossier(game: game, bounty: MPCChurchBountyCatalog.all[0], onBack: {}))),
        ("loans", AnyView(ChurchLoanCabinet(game: game, onBack: {}))),
        ("maintenance", AnyView(ChurchMaintenanceView(game: game, onBack: {})))
    ]
    for (name, view) in views {
        let renderer = ImageRenderer(content: view.frame(width: 390, height: 780).environment(\.colorScheme, .dark))
        renderer.scale = 2
        if let data = renderer.uiImage?.pngData() {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("church-delivery-\(name).png")
            try? data.write(to: url)
        }
    }
    NSLog("CHURCH_DELIVERY_RENDER_SAVED")
}
#endif


/// Shared gold title (restored 2026-10-14) over the breathing gold-violet haze.
private struct BattleStartButtonChrome: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathes = false

    func body(content: Content) -> some View {
        content
            .foregroundStyle(LinearGradient(
                colors: [Color(red: 1.00, green: 0.96, blue: 0.72),
                         Color(red: 0.96, green: 0.72, blue: 0.22),
                         Color(red: 0.72, green: 0.38, blue: 0.08)],
                startPoint: .top, endPoint: .bottom))
            .padding(.horizontal, 30).padding(.vertical, 10)
            // No border and no regular pill: a faint, uneven gold-to-violet haze behind
            // lettering (background request, 2026-10-07: 不要边框，金紫色渐变底，白色 / 是很淡的
            // 透明的背景 / 太规整 / 羽化要有一定的实体感，但又不能有明显的边缘感).
            .background(StartButtonHaze(breathes: breathes))
            .scaleEffect(breathes ? 1.03 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { breathes = true }
            }
    }
}


/// Volumetric lit mist behind "开始战斗" (user, 2026-10-07 on the blurred-ellipse
/// version: 羽化要有一定的实体感，但又不能有明显的边缘感). A cushion of gold -> violet
/// light whose density is shaped by smooth bell-profile elliptical gradients (no
/// flat plateau, zero slope where each lobe reaches transparent), so there is body
/// in the core but no rim anywhere. A warm highlight sits inside the upper-left of
/// the body and a deeper violet inside the lower-right, giving it volume.
private struct StartButtonHaze: View {
    let breathes: Bool

    private struct Lobe {
        let color: Color
        let peak: Double      // alpha at the lobe centre
        let x: CGFloat        // centre offset, fraction of width
        let y: CGFloat        // centre offset, fraction of height
        let w: CGFloat        // full extent where alpha reaches 0, fraction of width
        let h: CGFloat        // full extent where alpha reaches 0, fraction of height
        let tilt: Double      // degrees
        let power: Double     // bell exponent: higher = tighter core, thinner tail
    }

    private static let gold       = Color(red: 0.90, green: 0.60, blue: 0.18)
    private static let warmLight  = Color(red: 1.00, green: 0.82, blue: 0.50)
    private static let rose       = Color(red: 0.78, green: 0.38, blue: 0.54)
    private static let violet     = Color(red: 0.50, green: 0.24, blue: 0.84)
    private static let deepViolet = Color(red: 0.32, green: 0.11, blue: 0.62)
    private static let amber      = Color(red: 0.74, green: 0.40, blue: 0.12)

    private static let lobes: [Lobe] = [
        // --- atmosphere: very wide, very thin, irregular. It carries the outer falloff so
        //     the dense core never ends on its own contour (dissolves edges on dark scenes).
        Lobe(color: rose, peak: 0.06, x: 0.02, y: -0.04, w: 1.20, h: 2.24, tilt: -3, power: 1.8),
        Lobe(color: gold, peak: 0.12, x: -0.32, y: -0.16, w: 0.80, h: 2.16, tilt: -22, power: 1.8),
        Lobe(color: violet, peak: 0.13, x: 0.34, y: 0.16, w: 0.88, h: 2.16, tilt: 18, power: 1.8),
        // --- mantle: between atmosphere and body so the density steps down gradually
        //     (sum of nested bells ~ an exponential falloff: no shoulder, no rim)
        Lobe(color: gold, peak: 0.20, x: -0.26, y: -0.10, w: 1.35, h: 2.40, tilt: -14, power: 2.0),
        Lobe(color: violet, peak: 0.22, x: 0.28, y: 0.12, w: 1.45, h: 2.40, tilt: 14, power: 2.0),
        // --- body: warm half sits high-left, cool half sits low-right and runs longer
        Lobe(color: gold, peak: 0.48, x: -0.19, y: -0.05, w: 0.92, h: 1.70, tilt: -10, power: 2.4),
        Lobe(color: violet, peak: 0.52, x: 0.20, y: 0.08, w: 1.02, h: 1.80, tilt: 10, power: 2.4),
        Lobe(color: rose, peak: 0.26, x: 0.00, y: -0.03, w: 0.80, h: 1.50, tilt: -4, power: 2.2),
        // --- internal shading (kept well inside the body, never on the outline)
        Lobe(color: warmLight, peak: 0.30, x: -0.14, y: -0.18, w: 0.56, h: 0.90, tilt: -14, power: 2.2),
        Lobe(color: deepViolet, peak: 0.42, x: 0.22, y: 0.24, w: 0.62, h: 1.00, tilt: 16, power: 2.2),
        // shaded belly on the warm side: the cushion is lit from above, darker underneath
        Lobe(color: amber, peak: 0.26, x: -0.20, y: 0.24, w: 0.60, h: 0.95, tilt: -6, power: 2.2),
        // --- drifting wisps: break the outline into a diagonal plume, not an egg
        Lobe(color: gold, peak: 0.20, x: -0.50, y: -0.34, w: 0.42, h: 0.90, tilt: -30, power: 2.0),
        Lobe(color: violet, peak: 0.22, x: 0.54, y: 0.34, w: 0.44, h: 0.86, tilt: 24, power: 2.0),
    ]

    /// Built once: each lobe's bell-profile gradient.
    private static let gradients: [Gradient] = lobes.map {
        Gradient(stops: stops($0.color, peak: $0.peak, power: $0.power))
    }

    /// Bell profile (1 - t^2)^p sampled into stops: dense core, long tail, zero slope at t = 1.
    private static func stops(_ color: Color, peak: Double, power: Double) -> [Gradient.Stop] {
        let n = 14
        return (0...n).map { i in
            let t = Double(i) / Double(n)
            let a = peak * pow(max(0, 1 - t * t), power)
            return Gradient.Stop(color: color.opacity(a), location: t)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                ForEach(0..<Self.lobes.count, id: \.self) { i in
                    let l = Self.lobes[i]
                    Rectangle()
                        .fill(EllipticalGradient(
                            gradient: Self.gradients[i],
                            center: .center, startRadiusFraction: 0, endRadiusFraction: 0.5))
                        .frame(width: w * l.w, height: h * l.h)
                        .rotationEffect(.degrees(l.tilt))
                        .offset(x: w * l.x, y: h * l.y)
                }
            }
            .frame(width: w, height: h)
            .compositingGroup()
            .blur(radius: 4)
            .scaleEffect(breathes ? 1.02 : 0.98)
            .opacity(breathes ? 1.0 : 0.84)
        }
        .allowsHitTesting(false)
    }
}

/// One line over Unity's Q30 `angel-intro` (2026-10-11), in seconds from the command; a nil
/// speaker is narration.
private struct Q30AngelIntroLine {
    let start: Double
    let end: Double
    let speaker: String?
    let text: String
}

private struct SignatureCalloutCue: Equatable {
    let id = UUID()
    var kicker = "终结技"
    let title: String
    /// Q30 离场祝福 also show their one-line effect and hold longer.
    var detail: String? = nil
    var hold: Double = 0.85
}

/// A named finisher's title (2026-10-07: 名招出手时打一行招式名). Plain type, not
/// calligraphy: the game ships overseas and every string will move to English together
/// (user: 先考虑普通字体，到时一起切换到英文), so the width follows the text. It pops in
/// over the approved gold-violet haze, holds while the hero winds up, and fades as the
/// stage-sized hit lands below it.
private struct SignatureMoveCallout: View {
    var kicker = "终结技"
    let title: String
    var detail: String? = nil
    var hold: Double = 0.85
    let reduceMotion: Bool
    @State private var shown = false
    @State private var leaving = false

    var body: some View {
        VStack(spacing: 1) {
            Text(kicker)
                .font(.system(size: 12, weight: .bold))
                .tracking(4)
                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.52))
            Text(title)
                .font(.system(size: 34, weight: .heavy))
                .tracking(6)
                .foregroundStyle(.white)
            if let detail {
                Text(detail)
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
        .padding(.horizontal, 40).padding(.vertical, 12)
        .background(StartButtonHaze(breathes: true))
        .scaleEffect(reduceMotion ? 1 : (leaving ? 1.04 : (shown ? 1 : 1.22)))
        .blur(radius: reduceMotion || shown ? 0 : 6)
        .offset(x: reduceMotion ? 0 : (leaving ? 10 : (shown ? 0 : -18)))
        .opacity(leaving ? 0 : (shown ? 1 : 0))
        .onAppear {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) { shown = true }
            withAnimation(.easeIn(duration: 0.25).delay(hold)) { leaving = true }
        }
    }
}

private struct MaskTimingCue: View {
    @State private var pulses = false
    var body: some View {
        Text("喉间双焰亮起 → 点假面")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(.white)
            .fixedSize()
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color.purple.opacity(0.88)))
            .overlay(Capsule().stroke(Color.yellow.opacity(0.85), lineWidth: 1))
            .shadow(color: .purple.opacity(0.9), radius: pulses ? 10 : 3)
            .scaleEffect(pulses ? 1.06 : 0.96)
            .onAppear { withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) { pulses = true } }
    }
}
