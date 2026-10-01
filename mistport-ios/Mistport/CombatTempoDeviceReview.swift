import SwiftUI
import MistportCombatCore

/// The production path always selects the shared rules. Old rules are available
/// only in the explicitly isolated DEBUG comparison shell.
enum CombatTempoReviewConfiguration {
    #if DEBUG
    @MainActor static var activeSample: String?
    #endif
    static var requested: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--tempo-device-review=") }
        #else
        false
        #endif
    }
    static var baseline: Bool {
        requested && ProcessInfo.processInfo.arguments.contains("--tempo-baseline")
    }
    static func profile(_ encounterID: String) -> MPCCombatTempo? {
        baseline ? nil : MPCCombatTempo.profile(encounterID: encounterID)
    }
}

#if DEBUG
import ReplayKit
import Darwin

@MainActor
struct CombatTempoDeviceReviewRoot: View {
    let game: GameStore
    let storefront: Storefront
    @State private var session: MPCChapterOneEncounterSession?
    @State private var campaign = MPCChapterOneCampaignState.chapterStartState
    @State private var running = false
    @State private var preparing = false
    @State private var finished = false
    @State private var message = "正在准备样板"
    @State private var beganAt: Date?
    @State private var runID = UUID().uuidString
    @State private var selectedSample: String?
    @State private var recordingStarted = false
    @State private var reviewPass = 0
    @State private var hasSetLaunchSpeed = false
    @State private var passSpeed = 1

    private var sample: String {
        selectedSample ?? String(ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--tempo-device-review=") }!.dropFirst(22))
    }
    private var requestsRecording: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--tempo-record-auto") && !arguments.contains("--tempo-preview-only")
    }
    private var requestsSnapshots: Bool {
        // UIKit drawHierarchy does not capture the embedded Unity framebuffer
        // reliably and produced a black battle view on the review device.
        sample == "home" && (requestsRecording || ProcessInfo.processInfo.arguments.contains("--tempo-snapshots"))
    }
    private var speed: Int {
        passSpeed
    }
    private var fileStem: String {
        "tempo-" + (CombatTempoReviewConfiguration.baseline ? "before" : "after") + "-" + sample + "-x\(speed)"
    }

    var body: some View {
        ZStack {
            if sample == "home" {
                ContentView(game: game, storefront: storefront)
            } else if let session, running {
                ChapterOneEncounterTestView(initialSession: session, campaign: campaign,
                    battleIsActive: running, automatesSkillSequence: true,
                    showsStandaloneOpeningBattleButton: false,
                    onVictory: { result in Task { await finish(result: result, outcome: "victory") } },
                    onExit: { Task {
                        await finish(result: nil, outcome: "retreat")
                        selectedSample = "home"
                    } },
                    onDefeat: { Task { await finish(result: nil, outcome: "defeat") } })
            } else {
                Color.black.overlay {
                    if !requestsRecording { Text(message).foregroundStyle(.white) }
                }
            }
            if !running && requestsRecording {
                VStack {
                    Text("隔离样板 · \(sample) · ×\(speed)").font(.headline)
                    Button(message) { Task { await record() } }
                        .buttonStyle(.borderedProminent).disabled(preparing || finished)
                        .accessibilityIdentifier("tempo-review-record")
                }
                .padding(20).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !requestsRecording {
                Menu {
                    Button("重看本场") { reviewPass += 1 }
                    Button("港城雨云") { selectedSample = "home" }
                    Button("发条猎犬") { selectedSample = "q4" }
                    Button("石颚") { selectedSample = "d01" }
                    Button("第七号空壳") { selectedSample = "b01" }
                    Button("主角动作") { selectedSample = "hero" }
                } label: {
                    Label("换样板", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption).padding(10)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.leading, 12).padding(.bottom, 4)
                .accessibilityIdentifier("tempo-review-samples")
            }
        }
        .task(id: sample + "-\(reviewPass)") {
            session = nil; campaign = .chapterStartState
            running = false; preparing = false; finished = false
            recordingStarted = false; beganAt = nil; runID = UUID().uuidString
            message = "正在准备样板"
            CombatTempoReviewConfiguration.activeSample = sample
            UIApplication.shared.isIdleTimerDisabled = true
            if !hasSetLaunchSpeed {
                UserDefaults.standard.set(ProcessInfo.processInfo.arguments.contains("--tempo-speed=2") ? 2 : 1,
                    forKey: GameSettingsKeys.battleSpeed)
                hasSetLaunchSpeed = true
            }
            passSpeed = UserDefaults.standard.integer(forKey: GameSettingsKeys.battleSpeed) == 2 ? 2 : 1
            if sample == "home" {
                // The weather fixture must begin in the city, not in the
                // fresh-account Mara/path introduction. Only this suite changes.
                if game.selectedPathID == nil, let fool = GameContent.pathways.first(where: { $0.id == .fool }) {
                    game.select(fool, gender: .male)
                }
                game.completeChapterOneTutorial(.opening)
                game.completeChapterOneTutorial(.mapEntry)
                game.completeChapterOneTutorial(.cityMission)
                game.markDailyNewspaperSeen(); game.begin()
            } else {
                do {
                    // The normal title flow starts Unity after the native window
                    // is active. A direct DEBUG battle must preserve that order:
                    // creating Unity during first-window activation can initialize
                    // its keyboard while the launch snapshot is still dismissing.
                    while UIApplication.shared.applicationState != .active {
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    try await Task.sleep(for: .seconds(1))
                    logFootprint("before-unity")
                    UnityBattleRuntime.shared.preload()
                    // runEmbedded returns before BattlePrototype.Start finishes
                    // loading its models. Wait for a real scene anchor receipt
                    // before allocating the native SpriteKit overlay as well.
                    let deadline = ContinuousClock.now.advanced(by: .seconds(15))
                    while UnityBattleRuntime.shared.enemyHealthAnchorViewports.isEmpty,
                          ContinuousClock.now < deadline {
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    guard !Task.isCancelled else { return }
                    logFootprint("scene-ready")
                    let mission = sample == "q4" ? 4 : sample == "hero" ? 13 : 7
                    for n in 1...mission { _ = campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: n) }
                    campaign.grantHoundTutorialCard()
                    campaign.ownedRelicIDs.insert(MPCChapterOneCatalog.ownerlessMaskRelicID)
                    let loadout: MPCChapterOneLoadout
                    let id: String
                    if sample == "q4" {
                        loadout = .init(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
                        id = "chapter01_q04_encounter"
                    } else {
                        guard let floor = MPCChurchTowerCatalog.floor(number: 1) else { return }
                        if sample == "hero" {
                            var hand = MPCChapterOneLoadout(normalSkillIDs: [.mirrorPursuit, .absurdFinale], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
                            hand.selectedActiveRelicID = MPCChapterOneCatalog.ownerlessMaskRelicID
                            loadout = hand
                        } else { loadout = MPCChurchTowerVerificationRunner.recommendedLoadout(for: floor) }
                        id = (sample == "d01" || sample == "hero") ? "church_tower_001" : "church_bounty_b01"
                    }
                    campaign.loadout = loadout
                    if let active = loadout.selectedActiveRelicID { campaign.ownedRelicIDs.insert(active) }
                    session = try .start(encounterID: id, party: campaign.party, companionIDs: [], loadout: loadout)
                } catch {
                    guard !Task.isCancelled else { return }
                    message = "样板暂时无法打开"
                    writeReport(outcome: "preparation-error", completed: false, result: nil, error: error)
                    return
                }
            }
            guard !Task.isCancelled else { return }
            writeReport(outcome: "prepared", completed: false, result: nil)
            if requestsSnapshots { HomeFrameSampler.saveScreenshot(fileStem + "-prepared.png") }
            if requestsRecording, sample == "home" || session != nil {
                // This explicit DEBUG fixture flag starts a native recording;
                // ReplayKit still owns and presents the system consent prompt.
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                await record()
            } else {
                await preview()
            }
        }
    }

    private func preview() async {
        guard sample == "home" || session != nil else { return }
        beganAt = Date(); running = true
        logFootprint("preview-start")
        writeReport(outcome: "previewing", completed: false, result: nil)
        try? await Task.sleep(for: .seconds(6))
        guard !Task.isCancelled else { return }
        // A native screenshot proves the displayed state, never a recorded battle.
        if requestsSnapshots { HomeFrameSampler.saveScreenshot(fileStem + "-preview.png") }
        logFootprint("preview-six-seconds")
        if !finished { writeReport(outcome: "previewing", completed: false, result: nil) }
    }

    private func record() async {
        guard !preparing, !finished, sample == "home" || session != nil else { return }
        preparing = true
        do {
            let recorder = RPScreenRecorder.shared()
            recorder.isMicrophoneEnabled = false
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                recorder.startRecording { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
            recordingStarted = true; beganAt = Date(); running = true
            writeReport(outcome: "recording", completed: false, result: nil)
            // Only the native home scene supports the UIKit screenshot helper.
            try? await Task.sleep(for: .seconds(2))
            if requestsSnapshots { HomeFrameSampler.saveScreenshot(fileStem + ".png") }
            if sample == "home" {
                try? await Task.sleep(for: .seconds(16))
                await finish(result: nil, outcome: "home-weather")
            } else {
                try? await Task.sleep(for: .seconds(180))
                if !finished { await finish(result: nil, outcome: "timeout") }
            }
        } catch {
            preparing = false; message = "录制不可用，直接查看"
            writeReport(outcome: "recording-error", completed: false, result: nil, error: error)
            if requestsSnapshots { HomeFrameSampler.saveScreenshot(fileStem + "-error.png") }
            await preview()
        }
    }
    private func finish(result: MPCChapterOneEncounterSession?, outcome: String) async {
        guard !finished else { return }
        finished = true
        guard recordingStarted, RPScreenRecorder.shared().isRecording else {
            writeReport(outcome: "preview-" + outcome, completed: false, result: result)
            if requestsSnapshots { HomeFrameSampler.saveScreenshot(fileStem + "-preview-result.png") }
            return
        }
        try? await Task.sleep(for: .seconds(1))
        do {
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                RPScreenRecorder.shared().stopRecording(withOutput: folder.appendingPathComponent(fileStem + ".mp4")) { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
            writeReport(outcome: outcome, completed: outcome != "timeout", result: result)
            message = "录制已保存"
        } catch { message = "录像未能保存"; writeReport(outcome: "saving-error", completed: false, result: result, error: error) }
    }
    private func writeReport(outcome: String, completed: Bool, result: MPCChapterOneEncounterSession?, error: Error? = nil) {
        var report: [String: Any] = ["isolatedFixture": true, "realPlayerRewardSettlement": false,
            "runID": runID, "writtenAt": ISO8601DateFormatter().string(from: Date()),
            "sample": sample, "speed": UserDefaults.standard.integer(forKey: GameSettingsKeys.battleSpeed),
            "initialSpeed": speed, "baseline": CombatTempoReviewConfiguration.baseline,
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "outcome": outcome, "completed": completed,
            "recordingRequested": requestsRecording, "recordingStarted": recordingStarted,
            "previewCompleted": finished && !recordingStarted,
            "wallSeconds": beganAt.map { Date().timeIntervalSince($0) } ?? 0,
            "method": recordingStarted ? "Native ReplayKit; live App battle" : "Live App preview; no recording",
            "fixtureInputs": "DEBUG Q4 mask input; D01/B01 medal input at rule time 22s and when ready thereafter",
            "userVisualApproval": false]
        report["footprintMB"] = footprintMB()
        report["unityAnchorCount"] = UnityBattleRuntime.shared.enemyHealthAnchorViewports.count
        report["applicationState"] = UIApplication.shared.applicationState.rawValue
        report["windows"] = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).map { ["key": $0.isKeyWindow, "hidden": $0.isHidden,
                "controller": String(describing: type(of: $0.rootViewController)),
                "level": $0.windowLevel.rawValue] as [String: Any] }
        if recordingStarted { report["file"] = fileStem + ".mp4" }
        report["recorderAvailable"] = RPScreenRecorder.shared().isAvailable
        if sample == "home" { report["homeInCityHub"] = game.phase == .cityHub }
        if let error {
            let failure = error as NSError
            report["recordingError"] = ["domain": failure.domain, "code": failure.code, "description": failure.localizedDescription]
        }
        if let result { report["playerHP"] = result.playerHP; report["playerMaxHP"] = result.playerMaxHP; report["round"] = result.round }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]) {
            try? data.write(to: folder.appendingPathComponent(fileStem + ".json"))
        }
    }
    private func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return status == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : -1
    }
    private func logFootprint(_ phase: String) {
        NSLog("TEMPO_PREVIEW %@ footprintMB=%.1f anchors=%d", phase, footprintMB(),
              UnityBattleRuntime.shared.enemyHealthAnchorViewports.count)
    }
}
#endif
