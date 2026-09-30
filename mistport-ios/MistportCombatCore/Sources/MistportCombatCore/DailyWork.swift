import Foundation

/// Legacy job-count calibration remains available to archived simulations. The App
/// passes usesStamina: true (2026-09-30) and pays the base reward at every job count.
/// Repeatable work pay originally agreed 2026-09-29 (DAILY_LOOP_AND_ECONOMY_20260929.md §4.6).
/// J0 seal checks, J1 patrols, J2 tower maintenance, story replays and nameless
/// remnant cases share one count per day: jobs 1–3 pay in full, 4–6 half, later
/// ones a tenth, so extra hours earn a little more copper, not several times more.
/// Merit counts only for the day's first two merit-paying jobs, so loan tiers
/// cannot be reached earlier by playing longer.
///
/// The host settles each finished job once, by its receipt, and pays the result.
/// `day` is MPCDailyPacing.dayNumber; a clock moved back never resets the count.
public struct MPCDailyWorkLedger: Codable, Equatable, Sendable {
    public struct Payout: Codable, Equatable, Sendable {
        public let copper: Int
        public let merit: Int
        /// Share of the base pay, for the settlement text.
        public let percent: Int
    }

    public static let meritJobsPerDay = 2

    public private(set) var day = 0
    public private(set) var jobsToday = 0
    public private(set) var meritJobsToday = 0
    public private(set) var settled: [String: Payout] = [:]
    public init() {}

    /// Pay share for the n-th repeatable job of a day (1-based).
    public static func percent(forJob n: Int) -> Int { n <= 3 ? 100 : n <= 6 ? 50 : 10 }

    public static func scaled(_ copper: Int, percent: Int) -> Int {
        copper <= 0 ? 0 : max(1, (copper * percent + 50) / 100)
    }

    /// What one more job with this base pay would pay today, for the job board.
    public func preview(day: Int, copper: Int, usesStamina: Bool = false) -> Int {
        let next = day > self.day ? 1 : jobsToday + 1
        return Self.scaled(copper, percent: usesStamina ? 100 : Self.percent(forJob: next))
    }

    /// Settles one finished job. Settling the same receipt again returns the first payout.
    public mutating func settle(receiptID: String, day: Int, copper: Int, merit: Int, usesStamina: Bool = false) -> Payout {
        if let done = settled[receiptID] { return done }
        if day > self.day { self.day = day; jobsToday = 0; meritJobsToday = 0 }
        jobsToday += 1
        let percent = usesStamina ? 100 : Self.percent(forJob: jobsToday)
        var meritPaid = 0
        if merit > 0 && meritJobsToday < Self.meritJobsPerDay { meritJobsToday += 1; meritPaid = merit }
        let payout = Payout(copper: Self.scaled(copper, percent: percent), merit: meritPaid, percent: percent)
        settled[receiptID] = payout
        return payout
    }
}
