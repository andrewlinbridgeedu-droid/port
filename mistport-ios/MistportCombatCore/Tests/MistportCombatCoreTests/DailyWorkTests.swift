import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Repeatable work pays less after the day's first jobs")
struct DailyWorkTests {
    @Test func threeFullThreeHalfThenATenth() {
        var ledger = MPCDailyWorkLedger()
        let paid = (1...8).map { ledger.settle(receiptID: "j0-\($0)", day: 3, copper: 40, merit: 0).copper }
        #expect(paid == [40, 40, 40, 20, 20, 20, 4, 4])
        // A small base pay never rounds down to nothing.
        #expect(ledger.settle(receiptID: "replay", day: 3, copper: 8, merit: 0).copper == 1)
    }

    @Test func meritOnlyForTheFirstTwoMeritJobs() {
        var ledger = MPCDailyWorkLedger()
        let postal = ledger.settle(receiptID: "j0", day: 9, copper: 40, merit: 0)
        let patrols = (1...3).map { ledger.settle(receiptID: "j1-\($0)", day: 9, copper: 60, merit: 6) }
        #expect(postal.merit == 0)
        #expect(patrols.map(\.merit) == [6, 6, 0])
        // The patrols are jobs 2–4 of the day: the fourth is already half pay.
        #expect(patrols.map(\.copper) == [60, 60, 30])
    }

    @Test func aNewDayResetsButAMovedBackClockDoesNot() {
        var ledger = MPCDailyWorkLedger()
        for n in 1...4 { _ = ledger.settle(receiptID: "a\(n)", day: 5, copper: 80, merit: 8) }
        #expect(ledger.preview(day: 5, copper: 80) == 40)
        #expect(ledger.preview(day: 6, copper: 80) == 80)
        #expect(ledger.settle(receiptID: "b1", day: 6, copper: 80, merit: 8) == .init(copper: 80, merit: 8, percent: 100))
        // Setting the clock back to day 5 keeps counting day 6's jobs.
        #expect(ledger.settle(receiptID: "b2", day: 5, copper: 80, merit: 8).percent == 100)
        #expect(ledger.jobsToday == 2 && ledger.day == 6)
    }

    @Test func aReceiptIsPaidOnceAcrossReloads() throws {
        var ledger = MPCDailyWorkLedger()
        let first = ledger.settle(receiptID: "same", day: 2, copper: 40, merit: 0)
        ledger = try JSONDecoder().decode(MPCDailyWorkLedger.self, from: JSONEncoder().encode(ledger))
        let again = ledger.settle(receiptID: "same", day: 2, copper: 40, merit: 0)
        #expect(again == first && ledger.jobsToday == 1)
    }
}
