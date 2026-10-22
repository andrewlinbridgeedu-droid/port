import Foundation
import Testing
@testable import MistportCombatCore

@Suite("今日三件事")
struct DailyGoalTests {
    let start = MPCDailyProgress(missionsCleared: 7, towerFloors: 8, stars: 10, errands: 3)

    @Test func atMostThreeGoalsInOrderFromWhatTheDayOffers() {
        let full = MPCDailyGoalPlan.make(day: 5, baseline: start, offer: .init(
            openMission: (8, "不属于我的名字"), towerFloorsLeft: 12, missingStarMission: (2, "雾都幽灵"), errandsOpen: 2))
        #expect(full.goals.map(\.kind) == [.story, .tower, .star])
        #expect(full.goals[1].count == 4)
        // The well closed and nothing to replay yet: what is left, no padding.
        let early = MPCDailyGoalPlan.make(day: 1, baseline: .init(missionsCleared: 0, towerFloors: 0, stars: 0, errands: 0),
                                          offer: .init(openMission: (1, "雨夜醒来")))
        #expect(early.goals.map(\.kind) == [.story])
        let quiet = MPCDailyGoalPlan.make(day: 25, baseline: start, offer: .init(towerFloorsLeft: 2, errandsOpen: 1))
        #expect(quiet.goals.map(\.kind) == [.tower, .errand] && quiet.goals[0].count == 2)
        #expect(MPCDailyGoalPlan.make(day: 30, baseline: start, offer: .init()).goals.isEmpty)
    }

    @Test func doneIsMeasuredFromTheStartOfTheDayAndPaysOnce() throws {
        var plan = MPCDailyGoalPlan.make(day: 5, baseline: start, offer: .init(
            openMission: (8, "不属于我的名字"), towerFloorsLeft: 12, errandsOpen: 1))
        var now = start
        now.missionsCleared += 1; now.towerFloors += 3
        let early = plan.claim(now: now)
        #expect(plan.doneCount(now: now) == 1 && !early)
        #expect(plan.goals[1].progress(from: start, to: now) == 3)
        now.towerFloors += 2; now.errands += 1
        #expect(plan.allDone(now: now))
        let first = plan.claim(now: now), second = plan.claim(now: now)
        #expect(first && !second && plan.claimed)
        let round = try JSONDecoder().decode(MPCDailyGoalPlan.self, from: JSONEncoder().encode(plan))
        #expect(round == plan && !round.canClaim(now: now))
    }

    @Test func aDayWithNoGoalsHasNothingToClaim() {
        var plan = MPCDailyGoalPlan.make(day: 30, baseline: start, offer: .init())
        let claimed = plan.claim(now: start)
        #expect(!plan.allDone(now: start) && !claimed)
    }
}
