import CoreHaptics
import MistportCombatCore
import UIKit

/// One native owner. Same-frame results arbitrate before playback; old hits are never queued.
@MainActor
final class CombatHaptics {
    static let shared = CombatHaptics()
    private var engine: CHHapticEngine?
    /// The transient-strike player plus, for rumbling cues, a separate continuous player.
    private var players: [any CHHapticPatternPlayer] = []
    private var gate = MPCCombatHapticGate()
    private var pending: (id: String, cue: MPCCombatHapticCue)?
    private var flushTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var active = true
    private var receivedIDs: [String] = []

    private var enabled: Bool {
        UserDefaults.standard.object(forKey: GameSettingsKeys.hapticsEnabled) as? Bool ?? true
    }

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foreground), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc private func background() { active = false; cancel() }
    @objc private func foreground() { active = true }
    @objc private func settingsChanged() { if !enabled { cancel() } }

    func emit(_ cue: MPCCombatHapticCue, id: String = UUID().uuidString) {
        guard enabled, active, !receivedIDs.contains(id) else { return }
        receivedIDs.append(id)
        if receivedIDs.count > 256 { receivedIDs.removeFirst() }
        if let pending, pending.cue.priority >= cue.priority { return }
        pending = (id, cue)
        guard flushTask == nil else { return }
        flushTask = Task { @MainActor [weak self] in
            // Coalesce one combat tick without delaying feedback by a perceptible beat.
            do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
            guard let self else { return }
            let event = self.pending
            self.pending = nil
            self.flushTask = nil
            guard self.enabled, self.active, let event,
                  self.gate.allows(eventID: event.id, cue: event.cue, at: ProcessInfo.processInfo.systemUptime) else { return }
            self.play(event.cue)
        }
    }

    func outgoing(skillID: String?, damage: Int, id: String = UUID().uuidString) {
        if let cue = MPCCombatHapticCue.outgoing(skillID: skillID, damage: damage) { emit(cue, id: id) }
    }

    func incoming(hpLoss: Int, shieldLoss: Int, blocked: Bool, maxHP: Int, defeated: Bool, id: String = UUID().uuidString) {
        // Defeat is emitted once by the battle outcome transition, including lethal DOT.
        guard !defeated else { return }
        if let cue = MPCCombatHapticCue.incoming(hpLoss: hpLoss, shieldLoss: shieldLoss, blocked: blocked, maxHP: maxHP, isDefeated: false) { emit(cue, id: id) }
    }

    func cancel() {
        flushTask?.cancel(); flushTask = nil; pending = nil
        previewTask?.cancel(); previewTask = nil
        stopPlayers()
        engine?.stop(completionHandler: nil)
        gate.reset()
        receivedIDs.removeAll()
    }

    private func stopPlayers() {
        for player in players { try? player.stop(atTime: CHHapticTimeImmediate) }
        players.removeAll()
    }

    func preview() {
        cancel()
        previewTask = Task { @MainActor [weak self] in
            for cue: MPCCombatHapticCue in [.basic, .heavy, .maskBlock] {
                guard !Task.isCancelled, let self, self.enabled, self.active else { return }
                self.emit(cue)
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
            }
        }
    }

    private func play(_ cue: MPCCombatHapticCue) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { fallback(cue); return }
        do {
            if engine == nil {
                let newEngine = try CHHapticEngine()
                newEngine.isAutoShutdownEnabled = true
                newEngine.playsHapticsOnly = true
                newEngine.resetHandler = { [weak self] in
                    Task { @MainActor in self?.engine = nil; self?.players.removeAll() }
                }
                engine = newEngine
            }
            guard let engine else { return }
            try engine.start()
            stopPlayers()
            func transient(_ intensity: Float, _ sharpness: Float, at time: Double = 0) -> CHHapticEvent {
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ], relativeTime: time)
            }
            // A crisp strike, then (for cards and hits on the hero) a short low rumble that
            // fades; finishers add an aftershock (2026-10-07, user: 关键是手机震动).
            var events = [transient(Float(cue.intensity), Float(cue.sharpness))]
            if cue == .pursuit {
                events = [transient(0.6, 0.72), transient(Float(cue.intensity), 0.8, at: 0.07)]
            }
            if cue == .heavy || cue == .ultimate || cue == .hurtHeavy || cue == .defeat {
                events.append(transient(Float(cue.intensity) * 0.75, 0.35, at: 0.075))
            }
            if cue == .ultimate { events.append(transient(0.6, 0.3, at: 0.16)) }
            // Strikes and rumble are separate patterns on separate players: a
            // hapticIntensityControl curve scales its whole pattern, so sharing one pattern
            // faded the aftershock / second / third transients along with the rumble
            // (pursuit's second tap fell to ~0.14 instead of 0.82) (2026-10-08).
            var patterns = [try CHHapticPattern(events: events, parameters: [])]
            if cue.rumble > 0 {
                let rumbleEvent = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(cue.intensity) * 0.6),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12)
                ], relativeTime: 0.012, duration: cue.rumble)
                let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
                    .init(relativeTime: 0, value: 1), .init(relativeTime: cue.rumble, value: 0)
                ], relativeTime: 0.012)
                patterns.append(try CHHapticPattern(events: [rumbleEvent], parameterCurves: [fade]))
            }
            players = try patterns.map { try engine.makePlayer(with: $0) }
            for player in players { try player.start(atTime: CHHapticTimeImmediate) }
        } catch {
            engine = nil
            players.removeAll()
            fallback(cue)
        }
    }

    private func fallback(_ cue: MPCCombatHapticCue) {
        let generator = UIImpactFeedbackGenerator(style: cue.intensity >= 0.6 ? .heavy : (cue.sharpness >= 0.7 ? .rigid : .soft))
        generator.impactOccurred(intensity: CGFloat(cue.intensity))
    }
}
