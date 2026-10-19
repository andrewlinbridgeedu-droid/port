import Testing
@testable import MistportCombatCore

/// 雨后第一天 (2026-10-18): six stops after Q2, in order, each paid once.
@Suite("City tour: 玛拉's first-day walk")
struct CityTourTests {
    @Test func sixStopsInTheUsersOrder() {
        #expect(MPCCityTour.stops.map(\.title) == ["汤棚", "码头铺位", "邮局", "银行", "午夜钟咖啡馆", "守灯会"])
        #expect(Set(MPCCityTour.stops.map(\.id)).count == 6)
        for stop in MPCCityTour.stops {
            #expect(!stop.scene.isEmpty && !stop.lesson.isEmpty && !stop.done.isEmpty)
            if case .question(_, let choices, let answer, let nudge) = stop.task {
                #expect(choices.indices.contains(answer) && !nudge.isEmpty)
            }
        }
    }

    @Test func opensAfterQ2LikeTheChurch() {
        #expect(!MPCCityTour.isOpen(completedMissionNumbers: [1]))
        #expect(MPCCityTour.isOpen(completedMissionNumbers: [1, 2]))
        #expect(MPCCityTour.unlockMission == MPCChurchTowerCatalog.unlockMission)
    }

    @Test func stopsAreWalkedInOrderAndPaidOnce() {
        var ledger = MPCCityTour.Ledger()
        #expect(ledger.nextStop?.id == "soup")
        let outOfOrder = ledger.complete("bank")
        let first = ledger.complete("soup")
        let again = ledger.complete("soup")
        #expect(!outOfOrder && first && !again)
        for id in ["bunk", "post", "bank", "cafe", "lamp"] {
            let done = ledger.complete(id)
            #expect(done)
        }
        #expect(ledger.isFinished && ledger.nextStop == nil)
        #expect(MPCCityTour.stops.map(\.reward).reduce(0, +) == 38)
    }
}
