import Foundation

/// The lifecycle of the once-per-battle Encore Bell.
public enum MPCEncoreBellPhase: String, Equatable, Sendable, Codable {
    /// The bell has not been used and may answer a future enemy charge.
    case ready
    /// An enemy is charging and the bell may still be rung.
    case windingUp
    /// The bell was rung; the same attack is waiting for its delayed release.
    case deferred
    /// The bell has been used for this battle.
    case spent
}

/// Pure value state for the Encore Bell battle relic.
///
/// Times are monotonic seconds supplied by the battle clock. Ringing is valid
/// only while the tracked enemy is in its charge windup, before the original
/// deadline. The player and other clocks are intentionally outside this type;
/// a deferred release is due three seconds after the original windup deadline.
public struct MPCEncoreBellState: Equatable, Sendable, Codable {
    public private(set) var phase: MPCEncoreBellPhase
    public private(set) var pendingEnemyID: String?
    public private(set) var initialWindupDeadline: TimeInterval?
    public private(set) var releaseDeadline: TimeInterval?
    private var chargeStartedAt: TimeInterval?

    public init() {
        self.phase = .ready
        self.pendingEnemyID = nil
        self.initialWindupDeadline = nil
        self.releaseDeadline = nil
        self.chargeStartedAt = nil
    }

    /// Starts tracking one enemy's charge. Returns false for malformed timing,
    /// a second active charge, or after the bell has been spent.
    @discardableResult
    public mutating func beginCharge(
        enemyID: String,
        startedAt: TimeInterval,
        windupDeadline: TimeInterval
    ) -> Bool {
        guard !enemyID.isEmpty,
              startedAt.isFinite,
              windupDeadline.isFinite,
              windupDeadline > startedAt,
              phase == .ready else { return false }

        phase = .windingUp
        chargeStartedAt = startedAt
        pendingEnemyID = enemyID
        initialWindupDeadline = windupDeadline
        releaseDeadline = nil
        return true
    }

    /// Rings the bell during the tracked charge's windup. A ring at or after
    /// the original deadline is late and does not consume the bell.
    @discardableResult
    public mutating func ring(at now: TimeInterval) -> Bool {
        guard phase == .windingUp,
              now.isFinite,
              let startedAt = chargeStartedAt,
              now >= startedAt,
              let startedDeadline = initialWindupDeadline,
              now < startedDeadline else { return false }

        phase = .deferred
        // The charge keeps its original windup deadline; the bell adds three
        // seconds to that deadline even when rung near the end of the windup.
        releaseDeadline = startedDeadline + 3.0
        return true
    }

    /// Reports whether the deferred attack may be released at `now`.
    /// This is a query and does not consume the release.
    public func isReleaseDue(at now: TimeInterval) -> Bool {
        guard phase == .deferred, now.isFinite, let releaseDeadline else { return false }
        return now >= releaseDeadline
    }

    /// Consumes a due deferred attack and marks the bell spent.
    @discardableResult
    public mutating func consumeReleaseIfDue(at now: TimeInterval) -> Bool {
        guard isReleaseDue(at: now) else { return false }
        phase = .spent
        clearPendingCharge()
        return true
    }

    /// Completes an ordinary, un-rung charge and makes the unused bell ready
    /// for a later charge in the same battle.
    @discardableResult
    public mutating func completeCharge() -> Bool {
        guard phase == .windingUp else { return false }
        phase = .ready
        clearPendingCharge()
        return true
    }

    /// Handles the tracked enemy dying. A deferred charge remains spent even
    /// though its pending attack is canceled; an un-rung charge stays usable.
    @discardableResult
    public mutating func enemyDied(_ enemyID: String) -> Bool {
        guard pendingEnemyID == enemyID,
              phase == .windingUp || phase == .deferred else { return false }
        let wasDeferred = phase == .deferred
        phase = wasDeferred ? .spent : .ready
        clearPendingCharge()
        return true
    }

    /// Resets the relic for a newly started battle.
    public mutating func reset() {
        phase = .ready
        clearPendingCharge()
    }

    private mutating func clearPendingCharge() {
        chargeStartedAt = nil
        pendingEnemyID = nil
        initialWindupDeadline = nil
        releaseDeadline = nil
    }

}
