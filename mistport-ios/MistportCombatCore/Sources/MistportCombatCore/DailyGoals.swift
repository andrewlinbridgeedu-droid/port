import Foundation

// 今日三件事 (2026-10-22, user: 先做 1、2 和 3). Up to three small goals a day, finishable in about half
// an hour, drawn from what the day really offers: the next story mission, the well's new floors, a star
// not yet earned, a neighbour's errand. Each goal counts what was done after the day's plan was made;
// finishing every goal pays a small reward once that day. Nothing carries over and missing a day costs
// nothing.

/// Counts that only grow, read when the day's plan is made and again to see what was done since.
public struct MPCDailyProgress: Codable, Equatable, Sendable {
    public var missionsCleared: Int
    public var towerFloors: Int
    public var stars: Int
    public var errands: Int
    public init(missionsCleared: Int, towerFloors: Int, stars: Int, errands: Int) {
        self.missionsCleared = missionsCleared; self.towerFloors = towerFloors; self.stars = stars; self.errands = errands
    }
    func value(_ kind: MPCDailyGoal.Kind) -> Int {
        switch kind {
        case .story: missionsCleared
        case .tower: towerFloors
        case .star: stars
        case .errand: errands
        }
    }
}

public struct MPCDailyGoal: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case story, tower, star, errand }
    public let kind: Kind
    /// How many more than at the start of the day.
    public let count: Int
    /// Player-facing line (plain Chinese).
    public let title: String
    public var id: String { kind.rawValue }

    public func progress(from baseline: MPCDailyProgress, to now: MPCDailyProgress) -> Int {
        min(count, max(0, now.value(kind) - baseline.value(kind)))
    }
    public func isDone(from baseline: MPCDailyProgress, to now: MPCDailyProgress) -> Bool {
        progress(from: baseline, to: now) >= count
    }
}

public struct MPCDailyGoalPlan: Codable, Equatable, Sendable {
    /// Finishing every goal of a day: a third of an hour's paid work, and a little skill dust.
    public static let rewardCopper = 10
    public static let rewardDust = 2

    public let day: Int
    public let baseline: MPCDailyProgress
    public let goals: [MPCDailyGoal]
    public private(set) var claimed = false

    /// What the day offers when its plan is made.
    public struct Offer: Equatable, Sendable {
        /// The next story mission, when it is open today and not yet cleared.
        public var openMission: (number: Int, title: String)?
        /// New well floors the day still allows (0 when the well is closed).
        public var towerFloorsLeft: Int
        /// A cleared mission that still has a star to earn.
        public var missingStarMission: (number: Int, title: String)?
        /// Errands and street tasks open today.
        public var errandsOpen: Int
        public init(openMission: (number: Int, title: String)? = nil, towerFloorsLeft: Int = 0,
                    missingStarMission: (number: Int, title: String)? = nil, errandsOpen: Int = 0) {
            self.openMission = openMission; self.towerFloorsLeft = towerFloorsLeft
            self.missingStarMission = missingStarMission; self.errandsOpen = errandsOpen
        }
        public static func == (a: Offer, b: Offer) -> Bool {
            a.openMission?.number == b.openMission?.number && a.towerFloorsLeft == b.towerFloorsLeft
                && a.missingStarMission?.number == b.missingStarMission?.number && a.errandsOpen == b.errandsOpen
        }
    }

    public init(day: Int, baseline: MPCDailyProgress, goals: [MPCDailyGoal]) {
        self.day = day; self.baseline = baseline; self.goals = goals
    }

    /// The day's goals in this order, at most three: the story first, the well, a star, an errand.
    public static func make(day: Int, baseline: MPCDailyProgress, offer: Offer) -> MPCDailyGoalPlan {
        var goals: [MPCDailyGoal] = []
        if let mission = offer.openMission {
            goals.append(.init(kind: .story, count: 1, title: "打过第 \(mission.number) 关《\(mission.title)》"))
        }
        if offer.towerFloorsLeft > 0 {
            let floors = min(4, offer.towerFloorsLeft)
            goals.append(.init(kind: .tower, count: floors, title: "深井新封 \(floors) 层"))
        }
        if let mission = offer.missingStarMission {
            goals.append(.init(kind: .star, count: 1, title: "拿到 1 颗新的挑战星（比如第 \(mission.number) 关《\(mission.title)》）"))
        }
        if offer.errandsOpen > 0 {
            goals.append(.init(kind: .errand, count: 1, title: "办完 1 件街坊委托或街头急件"))
        }
        return .init(day: day, baseline: baseline, goals: Array(goals.prefix(3)))
    }

    public func doneCount(now: MPCDailyProgress) -> Int { goals.filter { $0.isDone(from: baseline, to: now) }.count }
    public func allDone(now: MPCDailyProgress) -> Bool { !goals.isEmpty && doneCount(now: now) == goals.count }
    public func canClaim(now: MPCDailyProgress) -> Bool { !claimed && allDone(now: now) }

    /// Marks the day's reward as paid. True only the first time, and only once every goal is done.
    public mutating func claim(now: MPCDailyProgress) -> Bool {
        guard canClaim(now: now) else { return false }
        claimed = true
        return true
    }
}
