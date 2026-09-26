import CoreHaptics
import MistportCombatCore
import UIKit

/// One native owner. Same-frame results arbitrate before playback; old hits are never queued.
@MainActor
final class CombatHaptics {
    static let shared = CombatHaptics()
    private var engine: CHHapticEngine?
    private var player: (any CHHapticPatternPlayer)?
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
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        engine?.stop(completionHandler: nil)
        gate.reset()
        receivedIDs.removeAll()
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
                    Task { @MainActor in self?.engine = nil; self?.player = nil }
                }
                engine = newEngine
            }
            guard let engine else { return }
            try engine.start()
            try? player?.stop(atTime: CHHapticTimeImmediate)
            func transient(_ intensity: Float, _ sharpness: Float, at time: Double = 0) -> CHHapticEvent {
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ], relativeTime: time)
            }
            var events = [transient(Float(cue.intensity), Float(cue.sharpness))]
            if cue == .pursuit {
                events = [transient(0.25, 0.72), transient(0.42, 0.8, at: 0.07)]
            } else if cue == .heavy || cue == .ultimate || cue == .defeat {
                events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(cue.intensity) * 0.32),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15),
                    CHHapticEventParameter(parameterID: .decayTime, value: 0.09)
                ], relativeTime: 0.015, duration: cue == .ultimate ? 0.12 : 0.085))
            }
            player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            engine = nil
            fallback(cue)
        }
    }

    private func fallback(_ cue: MPCCombatHapticCue) {
        let generator = UIImpactFeedbackGenerator(style: cue.intensity >= 0.6 ? .heavy : (cue.sharpness >= 0.7 ? .rigid : .soft))
        generator.impactOccurred(intensity: CGFloat(cue.intensity))
    }
}
