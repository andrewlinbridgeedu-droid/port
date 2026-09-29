import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Daily pacing: story and tower first clears open by calendar day")
struct DailyPacingTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }()

    func date(_ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    @Test func daysCountCalendarMidnightsAndNeverGoBelowOne() {
        #expect(MPCDailyPacing.dayNumber(start: date(1, 23), now: date(1, 23), calendar: calendar) == 1)
        // One minute past midnight is already the next day.
        #expect(MPCDailyPacing.dayNumber(start: date(1, 23), now: date(2, 0), calendar: calendar) == 2)
        #expect(MPCDailyPacing.dayNumber(start: date(1), now: date(30), calendar: calendar) == 30)
        #expect(MPCDailyPacing.dayNumber(start: date(10), now: date(3), calendar: calendar) == 1)
    }

    @Test func threeMissionsOnDayOneThenOneADayAndSkippedDaysStillCount() {
        #expect(MPCDailyPacing.highestOpenMission(day: 1) == 3)
        #expect(MPCDailyPacing.highestOpenMission(day: 2) == 4)
        #expect(MPCDailyPacing.isMissionOpen(18, day: 16))
        #expect(!MPCDailyPacing.isMissionOpen(19, day: 16))
        #expect(MPCDailyPacing.openingDay(mission: 30) == 28)
        #expect(MPCDailyPacing.highestOpenMission(day: 45) == 30)
        for mission in 1...30 {
            #expect(MPCDailyPacing.isMissionOpen(mission, day: MPCDailyPacing.openingDay(mission: mission)))
            #expect(!MPCDailyPacing.isMissionOpen(mission, day: MPCDailyPacing.openingDay(mission: mission) - 1) || mission <= 3)
        }
    }

    @Test func towerAllowanceAccumulatesAndReachesEveryWallFloorByItsMission() {
        #expect(MPCDailyPacing.towerFirstClearsAllowed(day: 1) == MPCDailyPacing.towerFloorsPerDay)
        #expect(MPCDailyPacing.canFirstClearTower(clearedFloors: 0, day: 1))
        #expect(!MPCDailyPacing.canFirstClearTower(clearedFloors: MPCDailyPacing.towerFloorsPerDay, day: 1))
        #expect(MPCDailyPacing.towerFirstClearsAllowed(day: 400) == MPCChurchTowerCatalog.releasedFloorCount)
        // A wall's floor is allowed by the day its mission opens.
        for wall in MPCProgressionWalls.walls {
            guard let floor = wall.towerFloor else { continue }
            #expect(MPCDailyPacing.towerFirstClearsAllowed(day: MPCDailyPacing.openingDay(mission: wall.mission)) >= floor,
                    "F\(floor) not allowed by the day Q\(wall.mission) opens")
        }
    }

    @Test func migratedSavesKeepTheirNextStepOpenToday() {
        let today = date(29, 9)
        for (missions, floors) in [(0, 0), (7, 0), (12, 30), (17, 64), (29, 100), (30, 100)] {
            let start = MPCDailyPacing.migratedStart(today: today, completedMissions: missions,
                                                     clearedTowerFloors: floors, calendar: calendar)
            let day = MPCDailyPacing.dayNumber(start: start, now: today, calendar: calendar)
            #expect(MPCDailyPacing.isMissionOpen(min(30, missions + 1), day: day))
            #expect(floors >= MPCChurchTowerCatalog.releasedFloorCount
                    || MPCDailyPacing.canFirstClearTower(clearedFloors: floors, day: day))
            // Not earlier than needed: one day less would close the next mission or floor.
            if day > 1 {
                #expect(!MPCDailyPacing.isMissionOpen(min(30, missions + 1), day: day - 1)
                        || !MPCDailyPacing.canFirstClearTower(clearedFloors: floors, day: day - 1))
            }
        }
        #expect(MPCDailyPacing.migratedStart(today: today, completedMissions: 0, clearedTowerFloors: 0, calendar: calendar)
                == calendar.startOfDay(for: today))
    }

    @Test func aNewSaveStartsTodayAndAnOldSaveIsMigratedOnce() throws {
        let now = date(29, 21)
        let fresh = MPCDailyPacingStart.resolve(now: now, completedMissions: 0, clearedTowerFloors: 0, calendar: calendar)
        #expect(fresh.origin == .newSave && fresh.day(now: now, calendar: calendar) == 1)
        #expect(fresh.start == calendar.startOfDay(for: now))
        let old = MPCDailyPacingStart.resolve(now: now, completedMissions: 17, clearedTowerFloors: 40, calendar: calendar)
        #expect(old.origin == .migrated && old.recordedAt == now)
        #expect(MPCDailyPacing.isMissionOpen(18, day: old.day(now: now, calendar: calendar)))
        // The record is what the save keeps: it round-trips and later days count from it.
        let stored = try JSONDecoder().decode(MPCDailyPacingStart.self, from: JSONEncoder().encode(old))
        #expect(stored == old)
        #expect(stored.day(now: date(30, 1), calendar: calendar) == old.day(now: now, calendar: calendar) + 1)
    }

    @Test func lockTextsSayWhenThingsOpen() {
        #expect(MPCDailyPacing.missionLockText(3, day: 1) == nil)
        #expect(MPCDailyPacing.missionLockText(4, day: 1) == "第 4 关明天开放")
        #expect(MPCDailyPacing.missionLockText(6, day: 1) == "第 6 关 3 天后开放")
        #expect(MPCDailyPacing.towerLockText(clearedFloors: 0, day: 1) == nil)
        #expect(MPCDailyPacing.towerLockText(clearedFloors: MPCDailyPacing.towerFloorsPerDay, day: 1) != nil)
        #expect(MPCDailyPacing.todaySummary(day: 1, completedMissions: 0, clearedFloors: 0)
                == "第 1 天 · 今天可推进到第 3 关 · 深井今天还能新封 \(MPCDailyPacing.towerFloorsPerDay) 层")
        #expect(MPCDailyPacing.todaySummary(day: 2, completedMissions: 4, clearedFloors: 8)
                == "第 2 天 · 第 5 关明天开放 · 深井新层明天再开")
        #expect(MPCDailyPacing.todaySummary(day: 40, completedMissions: 30, clearedFloors: 100)
                == "第 40 天 · 主线已全部打完 · 深井已全部封堵")
    }
}
