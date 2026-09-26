/// Haptic intent derived from confirmed combat results, independent of device playback.
public enum MPCCombatHapticCue: String, CaseIterable, Sendable {
    case basic, sidestep, identity, stamp, pursuit, heavy, counter, defense, ultimate
    case maskActivate, maskBlock, heal, shield, hurtLight, hurtMedium, hurtHeavy, defeat

    public var priority: Int {
        switch self {
        case .defeat: 100
        case .hurtHeavy: 90
        case .maskBlock: 80
        case .hurtMedium: 75
        case .ultimate: 70
        case .heavy: 65
        case .hurtLight: 74
        case .shield: 30
        case .sidestep, .identity, .stamp, .pursuit, .counter: 50
        case .defense, .maskActivate: 15
        case .basic: 20
        case .heal: 10
        }
    }

    /// Initial authored values, to be calibrated by feel on the target iPhone.
    public var intensity: Float {
        switch self {
        case .basic: 0.20
        case .sidestep: 0.42
        case .identity: 0.32
        case .stamp: 0.48
        case .pursuit: 0.42
        case .heavy: 0.68
        case .counter: 0.48
        case .defense: 0.18
        case .ultimate: 0.78
        case .maskActivate: 0.15
        case .maskBlock: 0.45
        case .heal: 0.18
        case .shield: 0.30
        case .hurtLight: 0.35
        case .hurtMedium: 0.50
        case .hurtHeavy: 0.65
        case .defeat: 0.70
        }
    }

    public var sharpness: Float {
        switch self {
        case .basic: 0.85
        case .sidestep, .identity, .pursuit, .counter: 0.75
        case .stamp: 0.55
        case .heavy, .ultimate: 0.45
        case .maskBlock: 1.0
        case .maskActivate, .defense, .shield: 0.70
        case .heal: 0.20
        case .hurtLight, .hurtMedium, .hurtHeavy, .defeat: 0.15
        }
    }

    /// Call once for an entire resolved action, aggregating actual positive damage
    /// across victims. Target count must never multiply haptic playback.
    public static func outgoing(skillID: String?, damage: Int) -> Self? {
        switch skillID {
        case "fool_skill_02": return .maskActivate
        case "fool_skill_09": return .defense
        case "fool_skill_03": return nil // Retired paper substitute.
        default: break
        }
        guard damage > 0 else { return nil }
        switch skillID {
        case nil, "basic": return .basic
        case "fool_skill_01": return .sidestep
        case "fool_skill_04": return .identity
        case "fool_skill_05": return .stamp
        case "fool_skill_06": return .pursuit
        case "fool_skill_07": return .heavy
        case "fool_skill_08": return .counter
        case "fool_skill_10": return .ultimate
        default: return nil
        }
    }

    /// No charge warnings or periodic poison pulses. A hit emits one cue only;
    /// actual health damage takes precedence over protection feedback.
    public static func incoming(hpLoss: Int, shieldLoss: Int, blocked: Bool,
                                maxHP: Int, isDefeated: Bool,
                                isPeriodic: Bool = false) -> Self? {
        if isDefeated { return .defeat }
        guard !isPeriodic else { return nil }
        if hpLoss > 0 {
            let fraction = Double(hpLoss) / Double(max(1, maxHP))
            if fraction > 0.30 { return .hurtHeavy }
            if fraction >= 0.10 { return .hurtMedium }
            return .hurtLight
        }
        if blocked { return .maskBlock }
        if shieldLoss > 0 { return .shield }
        return nil
    }
}

/// Bounded, non-queuing arbitration. Call with a monotonic clock and a stable
/// resolution ID shared by all victims/callbacks of the same combat action.
public struct MPCCombatHapticGate: Sendable {
    private var recentIDs: [String] = []
    private var knownIDs: Set<String> = []
    private var acceptedTimes: [Double] = []
    private var lastTime: Double?
    private var lastPriority = 0
    public init() {}

    public mutating func allows(eventID: String, cue: MPCCombatHapticCue, at time: Double) -> Bool {
        guard time.isFinite, !knownIDs.contains(eventID) else { return false }
        // Even a dropped event is consumed: duplicate callbacks cannot play it later.
        knownIDs.insert(eventID)
        recentIDs.append(eventID)
        if recentIDs.count > 256 { knownIDs.remove(recentIDs.removeFirst()) }
        if let lastTime, time < lastTime { return false }
        acceptedTimes.removeAll { time - $0 >= 1.0 }
        if cue != .defeat {
            guard acceptedTimes.count < 3 else { return false }
            if let lastTime, time - lastTime < 0.160, cue.priority <= lastPriority { return false }
        }
        acceptedTimes.append(time)
        lastTime = time
        lastPriority = cue.priority
        return true
    }

    public mutating func reset() { self = Self() }
}
