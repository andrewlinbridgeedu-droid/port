import AVFoundation
import MistportCombatCore

@MainActor
final class HomeMusicController {
    static let shared = HomeMusicController()
    static let isEnabledKey = "mistport.music.enabled"

    private var player: AVAudioPlayer?
    private var currentTrack: String?
    private var lastPhase: GamePhase = .title
    private var battleActive = false
    private var battleEncounterID: String?
    private(set) var isEnabled: Bool

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.isEnabledKey) as? Bool ?? true
    }

    func update(for phase: GamePhase) {
        lastPhase = phase
        #if DEBUG
        // Review launches (-MistportCityMute YES) stay silent: no title, hub or battle music.
        if UserDefaults.standard.bool(forKey: "MistportCityMute") {
            stop()
            return
        }
        #endif
        guard isEnabled else {
            stop()
            return
        }

        if battleActive {
            let cue = MPCBattleMusicCue.forEncounterID(battleEncounterID ?? "")
            if currentTrack != cue.assetName {
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

    func setBattleActive(_ active: Bool, encounterID: String) {
        // An outgoing view must not silence a different encounter that has
        // already become active during a SwiftUI transition.
        if !active, battleActive, battleEncounterID != encounterID { return }
        if battleActive == active, battleEncounterID == (active ? encounterID : nil) { return }
        battleActive = active
        battleEncounterID = active ? encounterID : nil
        update(for: lastPhase)
    }

    func setVolume(_ volume: Double) {
        let bounded = min(1, max(0, volume))
        UserDefaults.standard.set(bounded, forKey: GameSettingsKeys.musicVolume)
        player?.volume = Float(bounded)
    }

    func stop() {
        player?.stop()
        player = nil
        currentTrack = nil
    }

    private func startTrack(_ track: String) {
        player?.stop()
        let fileExtension = track.hasPrefix("Battle") ? "m4a" : "mp3"
        guard let url = Bundle.main.url(forResource: track, withExtension: fileExtension) else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = Float(UserDefaults.standard.object(forKey: GameSettingsKeys.musicVolume) as? Double ?? 0.7)
            player.numberOfLoops = -1
            player.prepareToPlay()
            player.play()
            self.player = player
            currentTrack = track
        } catch {
            player = nil
            currentTrack = nil
        }
    }
}
