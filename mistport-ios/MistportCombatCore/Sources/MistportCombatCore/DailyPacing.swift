import Foundation

/// Daily pacing agreed 2026-09-29 (PROGRESSION_WALLS_AND_BOUNTY_RELICS_20260928.md §9):
/// progress opens by calendar day, so extra hours cannot buy a lead; they only earn
/// copper. Day 1 is the save's first calendar day, and days a player skips still
/// count, so anyone can catch up. Bounties already open by day (MPCDailyBountyRotation).
///
/// The app checks these before a battle starts, never after a win: a won battle
/// always pays. Values are `var` only so tools/progression-sim can sweep them
/// (`PACING=`); the game never writes them. Local saves trust the device clock;
/// a moved-forward clock can only be caught by a server.
public enum MPCDailyPacing {
    /// Story missions open on day 1 (Q1–Q3, so the first session is not a single
    /// short battle), then this many more each day (Q30 on day 28).
    nonisolated(unsafe) public static var missionsOnFirstDay = 3
    nonisolated(unsafe) public static var missionsPerDay = 1
    /// Tower first clears allowed per day, accumulating. Replays of cleared floors
    /// are never limited; they pay no first-clear reward.
    nonisolated(unsafe) public static var towerFloorsPerDay = 4

    /// 1 on the save's first calendar day; a clock set before the start counts as day 1.
    public static func dayNumber(start: Date, now: Date, calendar: Calendar = .current) -> Int {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: now)).day ?? 0
        return max(1, days + 1)
    }

    public static func highestOpenMission(day: Int) -> Int {
        min(30, missionsOnFirstDay + max(0, day - 1) * missionsPerDay)
    }

    public static func isMissionOpen(_ mission: Int, day: Int) -> Bool {
        mission <= highestOpenMission(day: day)
    }

    /// First day on which `mission` is open, for "opens tomorrow" text.
    public static func openingDay(mission: Int) -> Int {
        mission <= missionsOnFirstDay ? 1 : 1 + (mission - missionsOnFirstDay + missionsPerDay - 1) / missionsPerDay
    }

    /// Tower floors that may have been first-cleared by the end of `day`.
    public static func towerFirstClearsAllowed(day: Int) -> Int {
        min(MPCChurchTowerCatalog.releasedFloorCount, max(1, day) * towerFloorsPerDay)
    }

    /// Whether one more floor may be first-cleared today; mission gates on floors still apply.
    public static func canFirstClearTower(clearedFloors: Int, day: Int) -> Bool {
        clearedFloors < towerFirstClearsAllowed(day: day)
    }

    /// Start date for a save made before pacing existed: late enough to stay honest,
    /// early enough that the next mission and the next tower floor are open today.
    public static func migratedStart(today: Date, completedMissions: Int, clearedTowerFloors: Int,
                                     calendar: Calendar = .current) -> Date {
        let missionDay = openingDay(mission: min(30, completedMissions + 1))
        let nextFloor = clearedTowerFloors >= MPCChurchTowerCatalog.releasedFloorCount ? 0 : clearedTowerFloors + 1
        let floorDay = (nextFloor + towerFloorsPerDay - 1) / towerFloorsPerDay
        let day = max(1, missionDay, floorDay)
        return calendar.date(byAdding: .day, value: -(day - 1), to: calendar.startOfDay(for: today))!
    }
}

/// The calendar a save plays by: written once and kept with the save. A save from
/// before pacing (any story or tower progress, no record) gets a migrated start that
/// keeps its next mission and floor open today; a new save starts today.
public struct MPCDailyPacingStart: Codable, Equatable, Sendable {
    public enum Origin: String, Codable, Sendable { case newSave, migrated }
    public let start: Date
    public let origin: Origin
    /// When the record was written: the migration receipt for an old save.
    public let recordedAt: Date

    public init(start: Date, origin: Origin, recordedAt: Date) {
        self.start = start; self.origin = origin; self.recordedAt = recordedAt
    }

    /// For a save that has no record yet. Call once, then store the result.
    public static func resolve(now: Date, completedMissions: Int, clearedTowerFloors: Int,
                               calendar: Calendar = .current) -> MPCDailyPacingStart {
        guard completedMissions > 0 || clearedTowerFloors > 0 else {
            return .init(start: calendar.startOfDay(for: now), origin: .newSave, recordedAt: now)
        }
        return .init(start: MPCDailyPacing.migratedStart(today: now, completedMissions: completedMissions,
                                                         clearedTowerFloors: clearedTowerFloors, calendar: calendar),
                     origin: .migrated, recordedAt: now)
    }

    public func day(now: Date, calendar: Calendar = .current) -> Int {
        MPCDailyPacing.dayNumber(start: start, now: now, calendar: calendar)
    }
}

extension MPCDailyPacing {
    /// Why an uncleared mission cannot start today, or nil when it can.
    public static func missionLockText(_ mission: Int, day: Int) -> String? {
        guard !isMissionOpen(mission, day: day) else { return nil }
        let wait = openingDay(mission: mission) - day
        return wait == 1 ? "第 \(mission) 关明天开放" : "第 \(mission) 关 \(wait) 天后开放"
    }

    /// Why a new tower floor cannot be first-cleared today, or nil when it can.
    public static func towerLockText(clearedFloors: Int, day: Int) -> String? {
        guard !canFirstClearTower(clearedFloors: clearedFloors, day: day) else { return nil }
        return "今天的新层已封堵完，明天再来；已封堵的层可以随时重打"
    }

    /// Short line for the city: what today still opens.
    public static func todaySummary(day: Int, completedMissions: Int, clearedFloors: Int) -> String {
        let highest = highestOpenMission(day: day)
        let story = completedMissions >= 30 ? "主线已全部打完"
            : completedMissions >= highest ? (missionLockText(completedMissions + 1, day: day) ?? "")
            : "今天可推进到第 \(highest) 关"
        let floors = max(0, towerFirstClearsAllowed(day: day) - clearedFloors)
        let tower = clearedFloors >= MPCChurchTowerCatalog.releasedFloorCount ? "深井已全部封堵"
            : floors == 0 ? "深井新层明天再开" : "深井今天还能新封 \(floors) 层"
        return "第 \(day) 天 · \(story) · \(tower)"
    }
}
