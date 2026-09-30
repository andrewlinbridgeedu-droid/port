#if DEBUG
import SwiftUI
import UIKit
import MistportCombatCore

/// Explicit isolated-suite visual walk; never used by normal gameplay or timing reports.
struct DailyStreetReviewView: View {
    @Bindable var game: GameStore
    let kind: String
    @State private var session: MPCChapterOneEncounterSession?
    @State private var failure = ""
    private let ticket = "daily-visual-review"
    var body: some View {
        Group {
            if let session {
                ChapterOneEncounterTestView(initialSession: session, campaign: game.churchBattleCampaign,
                    playerSequence: game.currentSequence, battleIsActive: true, automatesSkillSequence: true,
                    showsStandaloneOpeningBattleButton: false,
                    onVictory: { result in
                        do {
                            try game.finishDailyStreetReview(kind: kind, ticket: ticket, session: result)
                            NSLog("DAILY_STREET_VISUAL_VICTORY: %@ %@", kind, result.encounter.id)
                        } catch { NSLog("DAILY_STREET_VISUAL_SETTLE_ERROR: %@", String(describing: error)) }
                    }, onExit: { NSLog("DAILY_STREET_VISUAL_EXIT: %@", kind) },
                    onDefeat: { NSLog("DAILY_STREET_VISUAL_DEFEAT: %@", kind) },
                    onUseManualMask: { game.recordManualMaskUse(encounterID: session.encounter.id) },
                    onConsumeSupply: game.consumeCampaignSupply)
            } else { Text(failure.isEmpty ? "独立街头战验收夹具正在准备" : failure) }
        }
        .task {
            guard ProcessInfo.processInfo.arguments.contains("--daily-pacing-device-walk") else { return }
            do {
                await Task.yield()
                UnityBattleRuntime.shared.preload()
                try await Task.sleep(for: .milliseconds(500))
                session = try await game.beginDailyStreetReview(kind: kind, ticket: ticket)
                NSLog("DAILY_STREET_VISUAL_START: %@ %@", kind, session!.encounter.id)
                var last = 0
                for second in [8,16,28,45,60] {
                    try await Task.sleep(for: .seconds(second - last)); last = second
                    saveDailyLoopReviewFrame("street-\(kind)-\(second)")
                }
                NSLog("DAILY_STREET_VISUAL_CAPTURE_DONE: %@", kind)
            } catch { failure = String(describing: error); NSLog("DAILY_STREET_VISUAL_ERROR: %@", failure) }
        }
    }
}

@MainActor
func saveDailyLoopReviewFrame(_ name: String) {
    guard ProcessInfo.processInfo.arguments.contains("--daily-pacing-device-walk"),
          let window = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows).first(where: \.isKeyWindow),
          let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
    do {
        try image.pngData()?.write(to: folder.appendingPathComponent("daily-review-\(name).png"))
        NSLog("DAILY_REVIEW_FRAME: %@", name)
    } catch { NSLog("DAILY_REVIEW_FRAME_ERROR: %@", String(describing: error)) }
}
#endif
