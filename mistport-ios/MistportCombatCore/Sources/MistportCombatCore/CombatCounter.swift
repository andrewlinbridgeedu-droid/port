import Foundation

/// A defended heavy attack earns one manual restart of the ordinary sequence.
/// Several attackers or a multi-hit move cannot stack or extend the opportunity.
public struct MPCCombatCounter: Equatable, Sendable {
    public static let window: TimeInterval = 3
    public static let minimumInterval: TimeInterval = 18
    public private(set) var availableUntil: TimeInterval?
    public private(set) var activeUntil: TimeInterval?
    public private(set) var queued = false
    public private(set) var readyAt: TimeInterval = 0
    public init() {}

    public func isAvailable(at now: TimeInterval) -> Bool {
        now.isFinite && !queued && (availableUntil ?? 0) > now
    }
    public func isActive(at now: TimeInterval) -> Bool { (activeUntil ?? 0) > now }
    @discardableResult public mutating func offer(at now: TimeInterval) -> Bool {
        guard now.isFinite, now >= readyAt, !queued, !isAvailable(at: now), !isActive(at: now) else { return false }
        availableUntil = now + Self.window
        readyAt = now + Self.minimumInterval
        return true
    }
    @discardableResult public mutating func request(at now: TimeInterval) -> Bool {
        guard isAvailable(at: now) else { return false }
        availableUntil = nil; queued = true
        return true
    }
    /// The current cast completes before this restart; no cast or pending hit is cancelled.
    @discardableResult public mutating func activate(at now: TimeInterval) -> Bool {
        guard now.isFinite, queued else { return false }
        queued = false; activeUntil = now + Self.window
        return true
    }
    public mutating func clearWindow() { availableUntil = nil; activeUntil = nil; queued = false }

    /// Plain bites, poison ticks, buff casts and wind-up itself do not count.
    public static func isHeavy(_ intent: String) -> Bool {
        ["memory_breath", "emerald_burst", "name_hunt", "name_devour", "pounce",
         "slam", "archive_slam", "real_strike", "thirteenth_charge", "tower_salt_spike",
         "tower_slam"].contains(intent)
    }
}
