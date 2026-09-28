import SwiftUI
import UIKit

final class MistportOrientationDelegate: NSObject, UIApplicationDelegate {
    static var allowedOrientations: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.allowedOrientations
    }
}

@MainActor
enum MistportOrientation {
    static func set(_ mask: UIInterfaceOrientationMask) {
        MistportOrientationDelegate.allowedOrientations = mask
        #if DEBUG
        print("MISTPORT_ORIENTATION_REQUEST: \(mask.rawValue)")
        #endif
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
                ?? scenes.first(where: { $0.activationState == .foregroundInactive })
        else { return }
        scene.windows.forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
            NSLog("Mistport orientation request failed: %@", String(describing: error))
            #if DEBUG
            print("MISTPORT_ORIENTATION_ERROR: \(error)")
            #endif
        }
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            print("MISTPORT_ORIENTATION_VERIFY: requested=\(mask.rawValue) actual=\(scene.interfaceOrientation.rawValue)")
        }
        #endif
    }
}

@main
struct MistportApp: App {
    @UIApplicationDelegateAdaptor(MistportOrientationDelegate.self) private var orientationDelegate
    private static var playerDefaults: UserDefaults {
        if ProcessInfo.processInfo.arguments.contains("--player-test-audit") {
            return UserDefaults(suiteName: "mistport.player-test-01-15.audit")!
        }
        if ProcessInfo.processInfo.arguments.contains("--player-test") {
            return UserDefaults(suiteName: "mistport.player-test-01-15")!
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--verify-local-workshop") {
            return UserDefaults(suiteName: "mistport.local-workshop-verification-shell")!
        }
        if ProcessInfo.processInfo.arguments.contains("--preview-bounty-poker") {
            return UserDefaults(suiteName: "mistport.bounty-card-modes-preview-20260925")!
        }
        if ProcessInfo.processInfo.arguments.contains("--preview-tavern") {
            return UserDefaults(suiteName: "mistport.tavern-feature-preview-20260925")!
        }
        if ProcessInfo.processInfo.arguments.contains("--verify-p1-ui") {
            return UserDefaults(suiteName: "mistport.p1-ui-verification")!
        }
        #endif
        // This player-test build always resumes its own save, including icon launches.
        return UserDefaults(suiteName: "mistport.player-test-01-15")!
    }
    @State private var game = GameStore(defaults: Self.playerDefaults)
    @State private var storefront = Storefront()

    init() {
        #if DEBUG
            let waveErrors = DungeonLevel.waveValidationErrors(for: GameContent.chapterOneDistricts)
        precondition(waveErrors.isEmpty, "波次配置错误：\n\(waveErrors.joined(separator: "\n"))")
        let economyErrors = GameEconomyPolicy.validationErrors(for: GameContent.chapterOneDistricts)
        precondition(economyErrors.isEmpty, "免费经济配置错误：\n\(economyErrors.joined(separator: "\n"))")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-local-workshop") {
                Text("工坊结算验证 · 隔离存档")
                    .task { await GameStore.verifyLocalWorkshopIntegration() }
            } else if ProcessInfo.processInfo.arguments.contains("--preview-bounty-poker") {
                BountyPokerPreviewHost(game: game)
            } else if ProcessInfo.processInfo.arguments.contains("--preview-tavern") {
                TavernInteriorView(game: game, onBack: {})
                    .task {
                        GameStore.verifyTavernPrizeSettlement()
                        game.prepareTavernPreview()
                        try? await Task.sleep(for: .milliseconds(1600))
                        saveTavernPreviewScreenshot()
                    }
            } else {
                ContentView(game: game, storefront: storefront)
                    .defaultAppStorage(Self.playerDefaults)
                    .preferredColorScheme(.dark)
                    .task { await storefront.prepare() }
            }
            #else
            ContentView(game: game, storefront: storefront)
                .defaultAppStorage(Self.playerDefaults)
                .preferredColorScheme(.dark)
                .task {
                    await storefront.prepare()
                }
            #endif
        }
    }
}

#if DEBUG
@MainActor
private func saveTavernPreviewScreenshot() {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
          let window = scene.windows.first(where: \.isKeyWindow) else { return }
    let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
    guard let data = image.pngData(),
          let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let filename = ProcessInfo.processInfo.arguments.contains("--preview-tavern-poker")
        ? "tavern-poker-preview.png"
        : ProcessInfo.processInfo.arguments.contains("--preview-tavern-dialogue")
            ? "tavern-dialogue-preview.png"
            : ProcessInfo.processInfo.arguments.contains("--preview-tavern-look-right")
                ? "tavern-right-preview.png"
                : ProcessInfo.processInfo.arguments.contains("--preview-tavern-look-center")
                    ? "tavern-center-preview.png" : "tavern-feature-preview.png"
    let path = directory.appendingPathComponent(filename)
    try? data.write(to: path)
    NSLog("TAVERN_PREVIEW_SCREEN_SAVED: %@", path.path)
}
#endif

#if DEBUG
private struct BountyPokerPreviewHost: View {
    @Bindable var game: GameStore
    @State private var showsPoker = true

    var body: some View {
        VStack(spacing: 24) {
            Text("牌桌预览 · 竖屏入口")
                .font(.title2.bold())
            Button("进入牌桌") { showsPoker = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.025, green: 0.055, blue: 0.10).ignoresSafeArea())
        .fullScreenCover(isPresented: $showsPoker) {
            BountyPokerRound(game: game, caseID: "b08") { _ in }
        }
        .task { game.prepareBountyPokerPreview() }
    }
}
#endif
