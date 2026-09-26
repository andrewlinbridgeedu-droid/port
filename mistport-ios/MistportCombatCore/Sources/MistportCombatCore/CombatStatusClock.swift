import Foundation

public enum MPCStatusClock: String, Codable, CaseIterable, Sendable {
    case playerActionEnd = "PLAYER_ACTION_END"
    case enemyActionEnd = "ENEMY_ACTION_END"
    case roundEnd = "ROUND_END"
    case chargeOnly = "CHARGE_ONLY"
}

public enum MPCStatusStackRule: String, Codable, Sendable {
    case add = "ADD"
    case setMax = "SET_MAX"
    case replace = "REPLACE"
    case noStack = "NO_STACK"
}

public enum MPCStatusRefreshRule: String, Codable, Sendable {
    case refreshToBase = "REFRESH_TO_BASE"
    case keepLonger = "KEEP_LONGER"
    case noRefresh = "NO_REFRESH"
}

public struct MPCStatusDefinition: Equatable, Sendable {
    public let id: String
    public let clock: MPCStatusClock
    public let baseDuration: Int
    public let stackRule: MPCStatusStackRule
    public let maxStacks: Int
    public let refreshRule: MPCStatusRefreshRule

    public init(
        id: String,
        clock: MPCStatusClock,
        baseDuration: Int,
        stackRule: MPCStatusStackRule = .replace,
        maxStacks: Int = 1,
        refreshRule: MPCStatusRefreshRule = .refreshToBase
    ) {
        precondition(baseDuration >= 0)
        precondition(maxStacks >= 1)
        self.id = id
        self.clock = clock
        self.baseDuration = baseDuration
        self.stackRule = stackRule
        self.maxStacks = maxStacks
        self.refreshRule = refreshRule
    }
}

public struct MPCStatusState: Equatable, Sendable {
    public let definition: MPCStatusDefinition
    public var stacks: Int
    public var charges: Int
    public var remainingDuration: Int
    public var appliedClockIndex: Int

    public init(
        definition: MPCStatusDefinition,
        stacks: Int = 1,
        charges: Int = 0,
        remainingDuration: Int? = nil,
        appliedClockIndex: Int
    ) {
        self.definition = definition
        self.stacks = min(definition.maxStacks, max(1, stacks))
        self.charges = max(0, charges)
        self.remainingDuration = remainingDuration ?? definition.baseDuration
        self.appliedClockIndex = appliedClockIndex
    }
}

public struct MPCStatusTimeline: Equatable, Sendable {
    public private(set) var statuses: [String: MPCStatusState]
    public private(set) var clockIndexes: [MPCStatusClock: Int]

    public init(
        statuses: [String: MPCStatusState] = [:],
        clockIndexes: [MPCStatusClock: Int] = [:]
    ) {
        self.statuses = statuses
        self.clockIndexes = clockIndexes
    }

    public subscript(id: String) -> MPCStatusState? {
        statuses[id]
    }

    public mutating func apply(
        _ definition: MPCStatusDefinition,
        stacks addedStacks: Int = 1,
        charges: Int = 0
    ) {
        let protectedIndex = clockIndexes[definition.clock, default: 0] + 1
        guard var current = statuses[definition.id] else {
            statuses[definition.id] = MPCStatusState(
                definition: definition,
                stacks: addedStacks,
                charges: charges,
                appliedClockIndex: protectedIndex
            )
            return
        }

        switch definition.stackRule {
        case .add:
            current.stacks = min(definition.maxStacks, current.stacks + max(0, addedStacks))
        case .setMax:
            current.stacks = min(definition.maxStacks, max(current.stacks, addedStacks))
        case .replace:
            current.stacks = min(definition.maxStacks, max(1, addedStacks))
        case .noStack:
            break
        }

        switch definition.refreshRule {
        case .refreshToBase:
            current.remainingDuration = definition.baseDuration
            current.appliedClockIndex = protectedIndex
        case .keepLonger:
            if definition.baseDuration >= current.remainingDuration {
                current.remainingDuration = definition.baseDuration
                current.appliedClockIndex = protectedIndex
            }
        case .noRefresh:
            break
        }

        if definition.stackRule == .replace {
            current.charges = max(0, charges)
        } else {
            current.charges = max(current.charges, charges)
        }
        statuses[definition.id] = current
    }

    public mutating func advance(_ clock: MPCStatusClock) {
        guard clock != .chargeOnly else { return }
        let nextIndex = clockIndexes[clock, default: 0] + 1
        clockIndexes[clock] = nextIndex

        for id in Array(statuses.keys) {
            guard var status = statuses[id],
                  status.definition.clock == clock,
                  nextIndex > status.appliedClockIndex else { continue }
            status.remainingDuration -= 1
            if status.remainingDuration <= 0 {
                statuses.removeValue(forKey: id)
            } else {
                statuses[id] = status
            }
        }
    }

    @discardableResult
    public mutating func consumeCharge(for id: String) -> Bool {
        guard var status = statuses[id], status.charges > 0 else { return false }
        status.charges -= 1
        if status.charges == 0, status.definition.clock == .chargeOnly {
            statuses.removeValue(forKey: id)
        } else {
            statuses[id] = status
        }
        return true
    }

    public mutating func clearOnDeath() {
        statuses.removeAll(keepingCapacity: true)
    }
}
