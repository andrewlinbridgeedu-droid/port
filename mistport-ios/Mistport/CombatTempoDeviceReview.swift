import SwiftUI
import MistportCombatCore

/// The production path always selects the shared rules. Old rules are available
/// only in the explicitly isolated DEBUG comparison shell.
enum CombatTempoReviewConfiguration {
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

@MainActor
struct CombatTempoDeviceReviewRoot: View {
    let game: GameStore
    let storefront: Storefront
    @State private var session: MPCChapterOneEncounterSession?
    @State private var campaign = MPCChapterOneCampaignState.chapterStartState
    @State private var running = false
    @State private var preparing = false
    @State private var finished = false
    @State private var message = "开始录制"
    @State private var beganAt: Date?
    @State private var runID = UUID().uuidString

    private var sample: String {
        String(ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--tempo-device-review=") }!.dropFirst(22))
    }
    private var speed: Int {
        ProcessInfo.processInfo.arguments.contains("--tempo-speed=2") ? 2 : 1
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
                    onExit: { Task { await finish(result: nil, outcome: "retreat") } },
                    onDefeat: { Task { await finish(result: nil, outcome: "defeat") } })
            } else { Color.black }
            if !running {
                VStack {
                    Text("隔离样板 · \(sample) · ×\(speed)").font(.headline)
                    Button(message) { Task { await record() } }
                        .buttonStyle(.borderedProminent).disabled(preparing || finished)
                        .accessibilityIdentifier("tempo-review-record")
                }
                .padding(20).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .task {
            UIApplication.shared.isIdleTimerDisabled = true
            UserDefaults.standard.set(speed, forKey: GameSettingsKeys.battleSpeed)
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
                    UnityBattleRuntime.shared.preload()
                    await Task.yield()
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
                } catch { message = String(describing: error) }
            }
            writeReport(outcome: "prepared", completed: false, result: nil)
            HomeFrameSampler.saveScreenshot(fileStem + "-prepared.png")
            if ProcessInfo.processInfo.arguments.contains("--tempo-record-auto"), sample == "home" || session != nil {
                // This explicit DEBUG fixture flag starts a native recording;
                // ReplayKit still owns and presents the system consent prompt.
                try? await Task.sleep(for: .seconds(3))
                await record()
            }
        }
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
            beganAt = Date(); running = true
            writeReport(outcome: "recording", completed: false, result: nil)
            // Screenshots are native window pixels; the recording keeps every frame.
            try? await Task.sleep(for: .seconds(2))
            HomeFrameSampler.saveScreenshot(fileStem + ".png")
            if sample == "home" {
                try? await Task.sleep(for: .seconds(16))
                await finish(result: nil, outcome: "home-weather")
            } else {
                try? await Task.sleep(for: .seconds(180))
                if !finished { await finish(result: nil, outcome: "timeout") }
            }
        } catch {
            preparing = false; message = "录制失败：\(error)"
            writeReport(outcome: "recording-error", completed: false, result: nil, error: error)
            HomeFrameSampler.saveScreenshot(fileStem + "-error.png")
        }
    }
    private func finish(result: MPCChapterOneEncounterSession?, outcome: String) async {
        guard !finished, RPScreenRecorder.shared().isRecording else { return }
        finished = true
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
            running = false; message = "录制已保存 · \(outcome)"
        } catch { message = "保存失败：\(error)"; writeReport(outcome: "saving-error", completed: false, result: result, error: error) }
    }
    private func writeReport(outcome: String, completed: Bool, result: MPCChapterOneEncounterSession?, error: Error? = nil) {
        var report: [String: Any] = ["isolatedFixture": true, "realPlayerRewardSettlement": false,
            "runID": runID, "writtenAt": ISO8601DateFormatter().string(from: Date()),
            "sample": sample, "speed": speed, "baseline": CombatTempoReviewConfiguration.baseline,
            "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "outcome": outcome, "completed": completed, "file": fileStem + ".mp4",
            "wallSeconds": beganAt.map { Date().timeIntervalSince($0) } ?? 0,
            "method": "Native ReplayKit; live App battle; DEBUG Q4 mask input; D01/B01 medal input at rule time 22s and when ready thereafter",
            "userVisualApproval": false]
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
}
#endif
