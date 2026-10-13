import AVFoundation
import MistportCombatCore

@MainActor
final class HomeMusicController {
    static let shared = HomeMusicController()
    static let isEnabledKey = "mistport.music.enabled"

    private var player: AVAudioPlayer?
    private var currentTrack: String?
    private var lastPlaybackError: String?
    private var lastPhase: GamePhase = .title
    private var battleOwnership = MPCBattleMusicOwnership()
    private var battleActive: Bool { battleOwnership.encounterID != nil }
    private(set) var isEnabled: Bool

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.isEnabledKey) as? Bool ?? true
    }

    func update(for phase: GamePhase) {
        lastPhase = phase
        #if DEBUG
        // Review launches (-MistportCityMute YES) stay silent: no title, hub or battle music.
        if UserDefaults.standard.bool(forKey: "MistportCityMute") && !ProcessInfo.processInfo.arguments.contains("--verify-battle-music") {
            stop()
            return
        }
        #endif
        guard isEnabled else {
            stop()
            return
        }

        if battleActive {
            let cue = battleOwnership.cue ?? .gears
            if currentTrack != cue.assetName || player?.isPlaying != true {
                startTrack(cue.assetName)
            }
            return
        }

        switch phase {
        case .title:
            if currentTrack != "ColdIronThrone-1" && currentTrack != "ColdIronThrone-2" {
                startTrack(Bool.random() ? "ColdIronThrone-1" : "ColdIronThrone-2")
            }
        case .pathSelection, .cityHub:
            if currentTrack != "CharacterSelection" {
                startTrack("CharacterSelection")
            }
        default:
            stop()
        }
    }

    func setEnabled(_ enabled: Bool, for phase: GamePhase? = nil) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.isEnabledKey)
        update(for: phase ?? lastPhase)
    }

    func setBattleActive(_ active: Bool, encounterID: String, ownerID: UUID) {
        guard battleOwnership.setActive(active, encounterID: encounterID, ownerID: ownerID) else { return }
        update(for: lastPhase)
        #if DEBUG
        recordPlaybackReview()
        #endif
    }

    func setVolume(_ volume: Double) {
        let bounded = min(1, max(0, volume))
        UserDefaults.standard.set(bounded, forKey: GameSettingsKeys.musicVolume)
        #if DEBUG
        player?.volume = ProcessInfo.processInfo.arguments.contains("--verify-battle-music") ? 0 : Float(bounded)
        #else
        player?.volume = Float(bounded)
        #endif
    }

    func stop() {
        player?.stop()
        player = nil
        currentTrack = nil
    }

    private func startTrack(_ track: String) {
        player?.stop()
        player = nil; currentTrack = nil; lastPlaybackError = nil
        let fileExtension = track.hasPrefix("Battle") ? "m4a" : "mp3"
        guard let url = Bundle.main.url(forResource: track, withExtension: fileExtension) else {
            lastPlaybackError = "Missing resource: \(track).\(fileExtension)"
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = Float(UserDefaults.standard.object(forKey: GameSettingsKeys.musicVolume) as? Double ?? 0.7)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--verify-battle-music") { player.volume = 0 }
            #endif
            player.numberOfLoops = -1
            player.prepareToPlay()
            if !player.play() { lastPlaybackError = "AVAudioPlayer.play returned false" }
            self.player = player
            currentTrack = track
        } catch {
            let failure = error as NSError
            lastPlaybackError = "\(failure.domain) \(failure.code): \(failure.localizedDescription)"
            player = nil
            currentTrack = nil
        }
    }
    #if DEBUG
    private var reviewEvents: [[String: Any]] = []
    private var recordsPlaybackReview = true
    private func recordPlaybackReview() {
        guard recordsPlaybackReview, ProcessInfo.processInfo.arguments.contains("--verify-battle-music") else { return }
        reviewEvents.append(["encounter": battleOwnership.encounterID ?? "none",
            "expected": battleOwnership.cue?.assetName ?? "scene", "actual": currentTrack ?? "none",
            "playing": player?.isPlaying == true, "volume": player?.volume ?? -1, "error": lastPlaybackError ?? "none", "phase": String(describing: lastPhase), "at": Date().timeIntervalSince1970])
        Self.saveMusicReview(["silentAudit": true, "build": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown", "launchArguments": ProcessInfo.processInfo.arguments, "events": reviewEvents], name: "battle-music-live-review.json")
    }
    private static func saveMusicReview(_ report: [String: Any], name: String) {
        guard let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
              let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys, .prettyPrinted]) else { return }
        try? data.write(to: folder.appendingPathComponent(name))
    }
    /// Decode and play every packaged cue at zero volume; no settings or save writes.
    static func verifyAllBattleRoutes() async {
        guard ProcessInfo.processInfo.arguments.contains("--verify-battle-music") else { return }
        let audit = HomeMusicController()
        audit.isEnabled = true
        audit.recordsPlaybackReview = false
        audit.update(for: .cityHub)
        let ids = MPCChapterOneCatalog.missions.map(\.encounterID)
            + (1...100).map { String(format: "church_tower_%03d", $0) }
            + MPCChurchBountyCatalog.all.map(\.encounterID)
            + ["church_maintenance_j1_s1_job1", "church_maintenance_j2_f50_s1_job1", "church_maintenance_j2_f90_s1_job1"]
        var rows: [[String: Any]] = []
        for id in ids {
            let owner = UUID(), cue = MPCBattleMusicCue.forEncounterID(id)
            audit.setBattleActive(true, encounterID: id, ownerID: owner)
            try? await Task.sleep(for: .milliseconds(120))
            rows.append(["encounter": id, "expected": cue.assetName, "actual": audit.currentTrack ?? "none",
                         "playing": audit.player?.isPlaying == true, "volume": audit.player?.volume ?? -1, "error": audit.lastPlaybackError ?? "none"])
            audit.setBattleActive(false, encounterID: id, ownerID: owner)
            try? await Task.sleep(for: .milliseconds(120))
        }
        let old = UUID(), fresh = UUID(), q3 = "chapter01_q03_encounter"
        audit.setBattleActive(true, encounterID: q3, ownerID: old)
        try? await Task.sleep(for: .milliseconds(120))
        audit.setBattleActive(true, encounterID: q3, ownerID: fresh)
        audit.setBattleActive(false, encounterID: q3, ownerID: old)
        let lateStopIgnored = audit.currentTrack == MPCBattleMusicCue.forEncounterID(q3).assetName && audit.player?.isPlaying == true
        audit.setBattleActive(false, encounterID: q3, ownerID: fresh)
        try? await Task.sleep(for: .milliseconds(120))
        let returnedToHub = audit.currentTrack == "CharacterSelection"
        audit.setBattleActive(true, encounterID: q3, ownerID: fresh)
        try? await Task.sleep(for: .milliseconds(120))
        let restarted = audit.currentTrack == MPCBattleMusicCue.forEncounterID(q3).assetName && audit.player?.isPlaying == true
        audit.stop()
        saveMusicReview(["silentAudit": true, "routes": rows, "lateSameEncounterStopIgnored": lateStopIgnored,
                         "returnedToHub": returnedToHub, "retryRestartsBattle": restarted], name: "battle-music-route-review.json")
    }
    #endif

}
