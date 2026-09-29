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
    /// Story missions open on day 1, then this many more each day (Q30 on day 30).
    nonisolated(unsafe) public static var missionsOnFirstDay = 1
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
