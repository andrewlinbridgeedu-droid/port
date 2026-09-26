import SwiftUI
import UIKit
#if canImport(UnityFramework)
import UnityFramework
#endif

#if canImport(UnityFramework)
@_silgen_name("MistportConfigureUnityExecuteHeader")
private func configureUnityExecuteHeader()
#endif

// PLAYER_IMPACT_POLICY_BEGIN
/// Visual packets derived only from the already resolved native loss. No rules mutate here.
struct UnityPlayerImpactChannel {
    private(set) var context = UUID().uuidString
    private(set) var sequence: UInt64 = 0
    private var events: Set<String> = []

    mutating func reset() -> String {
        context = UUID().uuidString
        sequence = 0
        events.removeAll(keepingCapacity: true)
        return "player-impact-context:\(context)"
    }

    static func resolvedLoss(before: Int, after: Int) -> Int { max(0, before - after) }

    mutating func action(hpBefore: Int, hpAfter: Int, shieldBefore: Int, shieldAfter: Int,
                         maxHP: Int, defeated: Bool, eventID: String, reduceMotion: Bool) -> String? {
        let hpLoss = Self.resolvedLoss(before: hpBefore, after: hpAfter)
        let shieldLoss = Self.resolvedLoss(before: shieldBefore, after: shieldAfter)
        guard maxHP > 0, hpLoss > 0 || shieldLoss > 0, !eventID.isEmpty,
              !events.contains(eventID) else { return nil }
        events.insert(eventID)
        sequence += 1
        return "player-impact:\(context);\(sequence);\(hpLoss);\(shieldLoss);\(maxHP);\(defeated ? 1 : 0);\(reduceMotion ? 1 : 0)"
    }
}
// PLAYER_IMPACT_POLICY_END

enum UnityBattleEncounterPresentation {
    case clockGuard
    case chapterThirty(Int)
    case churchTower([String])
    case waveInstances([String])
    case dualClockGuard
    case clockCore
    case coreEscort
    case puppetCore
    case houndEscort
    case leechEscort
    case earlyHellHound
    case hellHoundPounce
    case hellHound

    var bridgeAction: String {
        switch self {
        case .churchTower(let ids): return "church-tower:" + ids.joined(separator: ",")
        case .chapterThirty(let number): return "chapter-thirty:\(number)"
        case .waveInstances(let ids): return "wave-instances:" + ids.joined(separator: ",")
        case .clockGuard: return "clock-guard"
        case .dualClockGuard: return "dual-clock-guard"
        case .clockCore: return "clock-core"
        case .coreEscort: return "core-escort"
        case .puppetCore: return "puppet-core"
        case .houndEscort: return "hound-escort"
        case .leechEscort: return "leech-escort"
        case .earlyHellHound: return "early-hell-hound"
        case .hellHoundPounce: return "hell-hound-pounce"
        case .hellHound: return "hell-hound"
        }
    }
}

#if canImport(UnityFramework)
@MainActor
final class UnityBattleRuntime: NSObject, ObservableObject, UnityFrameworkListener {
    static let shared = UnityBattleRuntime()

    @Published private(set) var combatContactToken = 0
    private var combatContacts: [String: Int] = [:]
    fileprivate var playerImpactChannel = UnityPlayerImpactChannel()
    func consumeCombatContact(_ key: String) -> Bool {
        guard combatContacts[key, default: 0] > 0 else { return false }
        combatContacts[key, default: 0] -= 1
        return true
    }
    @Published private(set) var isReady = false
    @Published private(set) var enemyPresentationCompletionToken = 0
    @Published private(set) var clockCorePresentationCompletionToken = 0
    @Published private(set) var enemyPresentationPhase = ""
    @Published private(set) var enemyPresentationPhaseBeganAt = Date.distantPast
    @Published private(set) var enemyHealthAnchorViewports: [String: CGPoint] = [:]
    @Published private(set) var effectAnchorViewports: [String: CGPoint] = [:]
    private var framework: UnityFramework?
    private weak var hostView: UIView?
    private weak var nativeWindow: UIWindow?
    private var pendingEncounterPresentation: UnityBattleEncounterPresentation = .clockGuard
    private var pendingTargetSigilsPayload = ""
    private var pendingEnemyVisibilityPayload = ""
    private var pendingPlayerPlacementAction = "player-position:default"

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUnityBattleEvent(_:)),
            name: Notification.Name("MistportUnityBattleEvent"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func attach(to view: UIView) {
        hostView = view
        if framework == nil {
            startUnity()
        } else {
            attachUnityView()
        }
    }

    /// Keeps the embedded Unity root view matched to SwiftUI's actual battle
    /// viewport. During launch preloading Unity is created before this host has
    /// its final bounds, so autoresizing alone can preserve the temporary
    /// startup size and leave the battlefield letterboxed.
    func layout(in view: UIView) {
        guard hostView === view,
              let unityView = framework?.appController()?.rootViewController?.view else {
            return
        }
        unityView.frame = view.bounds
        unityView.setNeedsLayout()
        unityView.layoutIfNeeded()
    }

    /// Starts Unity while the native launch loading screen is visible. The
    /// Unity view remains hidden until a battle host explicitly attaches it.
    func preload() {
        guard framework == nil else { return }
        startUnity()
    }

    func detach(from view: UIView) {
        if hostView === view {
            hostView = nil
        }
    }

    func send(action: String) {
        let changesImpactContext = action == "combat-start" || action == "combat-stop" || action == "player-reset"
        let impactContextAction = changesImpactContext ? playerImpactChannel.reset() : nil
        if action == "combat-start" || action == "combat-stop" { combatContacts.removeAll() }
        guard isReady else { return }
        let json = #"{"action":"\#(action)"}"#
        framework?.sendMessageToGO(
            withName: "Mistport Unity Battle Bridge",
            functionName: "ApplyCommand",
            message: json
        )
        if let impactContextAction { send(action: impactContextAction) }
    }

    func configureEncounter(_ presentation: UnityBattleEncounterPresentation) {
        let impactContextAction = playerImpactChannel.reset()
        pendingEncounterPresentation = presentation
        pendingEnemyVisibilityPayload = ""
        pendingTargetSigilsPayload = ""
        guard isReady else { return }
        send(action: presentation.bridgeAction)
        send(action: impactContextAction)
    }

    func setTargetSigils(_ payload: String) {
        pendingTargetSigilsPayload = payload
        guard isReady else { return }
        framework?.sendMessageToGO(
            withName: "Mistport Unity Battle Bridge",
            functionName: "SetTargetSigils",
            message: payload
        )
    }

    func setEnemyVisibility(_ payload: String) {
        pendingEnemyVisibilityPayload = payload
        guard isReady else { return }
        framework?.sendMessageToGO(
            withName: "Mistport Unity Battle Bridge",
            functionName: "SetEnemyVisibility",
            message: payload
        )
    }

    func setPlayerPlacement(_ placement: ChapterOnePlayerPlacement) {
        let normalized = placement.normalized
        pendingPlayerPlacementAction = normalized == .standard
            ? "player-position:default"
            : "player-position:\(normalized.x),\(normalized.yFromTop)"
        guard isReady else { return }
        send(action: pendingPlayerPlacementAction)
    }

    func healthAnchor(for unityEnemyID: String) -> CGPoint? {
        enemyHealthAnchorViewports[unityEnemyID]
    }

    /// Unity owns the moving 3D rig; native SpriteKit owns the layered 2D
    /// spell effects. These anchors keep the two renderers aligned without
    /// putting pixel offsets into individual enemy scripts.
    func effectAnchor(for identifier: String) -> CGPoint? {
        effectAnchorViewports[identifier]
    }

    /// Waits for Unity to report that the guard's in-place attack presentation
    /// has finished. The timeout protects the native turn loop when an older
    /// or unavailable Unity export cannot emit the completion event.
    func waitForEnemyPresentationCompletion(
        after token: Int,
        timeout: Duration = .seconds(3.5)
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while enemyPresentationCompletionToken <= token, clock.now < deadline {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    func waitForClockCorePresentationCompletion(
        after token: Int,
        timeout: Duration = .seconds(2)
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clockCorePresentationCompletionToken <= token, clock.now < deadline {
            if Task.isCancelled { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    @objc private func handleUnityBattleEvent(_ notification: Notification) {
        guard let json = notification.userInfo?["json"] as? String,
              let data = json.data(using: .utf8),
              let payload = try? JSONDecoder().decode(UnityBattleEventPayload.self, from: data) else {
            return
        }
        switch (payload.eventName, payload.value) {
        case ("combat-contact", _):
            combatContacts[payload.value, default: 0] += 1
            combatContactToken &+= 1
        case ("presentation-complete", "enemy"):
            enemyPresentationCompletionToken &+= 1
        case ("presentation-complete", "clock-core-cast"):
            clockCorePresentationCompletionToken &+= 1
        case ("presentation-phase", _):
            enemyPresentationPhase = payload.value
            enemyPresentationPhaseBeganAt = Date()
        case ("enemy-health-anchors", _):
            updateEnemyHealthAnchors(payload.value)
        case ("battle-effect-anchors", _):
            updateEffectAnchors(payload.value)
        default:
            break
        }
    }

    private func updateEnemyHealthAnchors(_ serializedAnchors: String) {
        var updated: [String: CGPoint] = [:]
        for entry in serializedAnchors.split(separator: ";") {
            let components = entry.split(separator: ",")
            guard components.count == 3,
                  let x = Double(components[1]),
                  let unityY = Double(components[2]) else {
                continue
            }
            updated[String(components[0])] = CGPoint(
                x: min(1, max(0, x)),
                y: min(1, max(0, 1 - unityY))
            )
        }
        if !updated.isEmpty {
            enemyHealthAnchorViewports = updated
        }
    }

    private func updateEffectAnchors(_ serializedAnchors: String) {
        var updated: [String: CGPoint] = [:]
        for entry in serializedAnchors.split(separator: ";") {
            let components = entry.split(separator: ",")
            guard components.count == 3,
                  let x = Double(components[1]),
                  let unityY = Double(components[2]) else {
                continue
            }
            updated[String(components[0])] = CGPoint(
                x: min(1, max(0, x)),
                y: min(1, max(0, 1 - unityY))
            )
        }
        if !updated.isEmpty {
            effectAnchorViewports = updated
        }
    }

    private func startUnity() {
        guard let unity = UnityFramework.getInstance() else { return }
        // Unity creates and keys its own UIWindow during runEmbedded. Retain
        // the SwiftUI window so native controls remain the event destination.
        nativeWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        framework = unity
        configureUnityExecuteHeader()
        let dataBundleID = Bundle.main.bundleIdentifier ?? "com.yourcompany.mistport"
        dataBundleID.withCString { bundleID in
            unity.setDataBundleId(bundleID)
        }
        unity.register(self)
        unity.runEmbedded(
            withArgc: CommandLine.argc,
            argv: CommandLine.unsafeArgv,
            appLaunchOpts: nil
        )
        isReady = true
        if hostView == nil {
            if let unityWindow = unity.appController()?.window,
               unityWindow !== nativeWindow {
                unityWindow.isUserInteractionEnabled = false
                unityWindow.isHidden = true
            }
            nativeWindow?.makeKeyAndVisible()
        } else {
            attachUnityView()
        }
        send(action: pendingEncounterPresentation.bridgeAction)
        send(action: playerImpactChannel.reset())
        send(action: pendingPlayerPlacementAction)
        setTargetSigils(pendingTargetSigilsPayload)
        setEnemyVisibility(pendingEnemyVisibilityPayload)
    }

    private func attachUnityView() {
        guard let hostView,
              let unityView = framework?.appController()?.rootViewController?.view else {
            return
        }
        // Native SwiftUI owns all combat input. Unity is the visual stage only;
        // disabling interaction prevents its full-screen view from swallowing
        // taps intended for cards and action controls layered above it.
        hostView.isUserInteractionEnabled = false
        unityView.isUserInteractionEnabled = false
        unityView.removeFromSuperview()
        hostView.layoutIfNeeded()
        unityView.frame = hostView.bounds
        unityView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostView.addSubview(unityView)

        // zIndex cannot cross UIWindow boundaries. Make Unity's temporary
        // window non-interactive and restore the native SwiftUI window as key.
        if let unityWindow = framework?.appController()?.window,
           unityWindow !== nativeWindow {
            unityWindow.isUserInteractionEnabled = false
            unityWindow.windowLevel = UIWindow.Level(
                rawValue: UIWindow.Level.normal.rawValue - 1
            )
        }
        nativeWindow?.makeKey()
    }

    nonisolated func unityDidUnload(_ notification: Notification!) {
        Task { @MainActor in
            framework = nil
            isReady = false
        }
    }
}

private struct UnityBattleEventPayload: Decodable {
    let eventName: String
    let value: String
}

struct UnityBattleSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UnityPassthroughView()
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
        view.onLayout = { hostView in
            UnityBattleRuntime.shared.layout(in: hostView)
        }
        UnityBattleRuntime.shared.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        UnityBattleRuntime.shared.attach(to: uiView)
        uiView.setNeedsLayout()
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Void) {
        UnityBattleRuntime.shared.detach(from: uiView)
    }
}

private final class UnityPassthroughView: UIView {
    var onLayout: ((UIView) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(self)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        false
    }
}
#else
/// Keep a native fallback for builds that intentionally omit UnityFramework.
/// Simulator exports can now use the same live Animator path as device builds;
/// this branch is selected by module availability, not by platform name.
@MainActor
final class UnityBattleRuntime: NSObject, ObservableObject {
    static let shared = UnityBattleRuntime()

    @Published private(set) var combatContactToken = 0
    private var combatContacts: [String: Int] = [:]
    fileprivate var playerImpactChannel = UnityPlayerImpactChannel()
    func consumeCombatContact(_ key: String) -> Bool {
        guard combatContacts[key, default: 0] > 0 else { return false }
        combatContacts[key, default: 0] -= 1
        return true
    }
    @Published private(set) var isReady = false
    @Published private(set) var enemyPresentationCompletionToken = 0
    @Published private(set) var clockCorePresentationCompletionToken = 0
    @Published private(set) var enemyPresentationPhase = ""
    @Published private(set) var enemyPresentationPhaseBeganAt = Date.distantPast
    @Published private(set) var enemyHealthAnchorViewports: [String: CGPoint] = [:]
    @Published private(set) var effectAnchorViewports: [String: CGPoint] = [:]

    private override init() {
        super.init()
    }

    func attach(to view: UIView) {
        view.isUserInteractionEnabled = false
    }

    func layout(in view: UIView) {
        _ = view
    }

    func preload() {}

    func detach(from view: UIView) {
        _ = view
    }

    func send(action: String) {
        let changesImpactContext = action == "combat-start" || action == "combat-stop" || action == "player-reset"
        let impactContextAction = changesImpactContext ? playerImpactChannel.reset() : nil
        if action == "combat-start" || action == "combat-stop" { combatContacts.removeAll() }
        _ = action
        _ = impactContextAction
    }

    func configureEncounter(_ presentation: UnityBattleEncounterPresentation) {
        _ = presentation
        _ = playerImpactChannel.reset()
    }

    func setTargetSigils(_ payload: String) {
        _ = payload
    }

    func setEnemyVisibility(_ payload: String) {
        _ = payload
    }

    func setPlayerPlacement(_ placement: ChapterOnePlayerPlacement) {
        _ = placement
    }

    func healthAnchor(for unityEnemyID: String) -> CGPoint? {
        enemyHealthAnchorViewports[unityEnemyID]
    }

    func effectAnchor(for identifier: String) -> CGPoint? {
        effectAnchorViewports[identifier]
    }

    func waitForEnemyPresentationCompletion(
        after token: Int,
        timeout: Duration = .seconds(3.5)
    ) async {
        _ = token
        _ = timeout
    }

    func waitForClockCorePresentationCompletion(
        after token: Int,
        timeout: Duration = .seconds(2)
    ) async {
        _ = token
        _ = timeout
    }
}

struct UnityBattleSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.isUserInteractionEnabled = false
    }
}
#endif

@MainActor
extension UnityBattleRuntime {
    func presentPlayerImpact(hpBefore: Int, hpAfter: Int, shieldBefore: Int, shieldAfter: Int,
                             maxHP: Int, defeated: Bool, eventID: String) {
        guard isReady,
              let action = playerImpactChannel.action(
                hpBefore: hpBefore, hpAfter: hpAfter, shieldBefore: shieldBefore, shieldAfter: shieldAfter,
                maxHP: maxHP, defeated: defeated, eventID: eventID,
                reduceMotion: UIAccessibility.isReduceMotionEnabled
              ) else { return }
        send(action: action)
    }
}
