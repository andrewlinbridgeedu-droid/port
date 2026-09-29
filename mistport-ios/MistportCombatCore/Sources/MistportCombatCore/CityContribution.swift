import Foundation

/// City contribution, agreed 2026-09-29 (HOME_MAP_STREET_TASKS_20260929.md §6): street
/// tasks earn contribution, and higher street tasks open as it grows. It replaces the old
/// district reputation shown on the home screen. Points come only from things that are
/// capped by the day or happen once, so contribution follows the calendar, not hours
/// played. It never gates the story, the wall bounties, world events or basic tasks.
public enum MPCCityContribution {
    public enum Source: String, Codable, Sendable, CaseIterable {
        /// A story mission's first clear.
        case mission
        /// A neighbour errand from the plaza board.
        case errand
        /// A post-office letter run; only the first two a day count.
        case post
        /// A remnant case.
        case remnant
        /// A closed bounty case.
        case bounty
        /// A world-event battle that counted toward the event; at most two a day.
        case eventBattle
        /// A world event that ended in success, once per event.
        case eventSuccess
    }

    /// Candidate values. tools/progression-sim (all/completionist, 2026-09-29): a player doing the
    /// day's street tasks has about 140 points on day 7, 233 on day 14 and 313 on day 21, so the
    /// tiers below land on days 6–7, 13 and 20; a story-only player ends chapter one near 104.
    public static func points(_ source: Source) -> Int {
        switch source {
        case .mission: 2
        case .errand: 2
        case .post: 1
        case .remnant: 3
        case .bounty: 10
        case .eventBattle: 1
        case .eventSuccess: 5
        }
    }

    /// Daily caps for sources that repeat within a day; nil means the source's own rules cap it.
    public static func dailyCap(_ source: Source) -> Int? {
        switch source {
        case .post: 2
        case .eventBattle: 2
        default: nil
        }
    }

    /// Higher street tasks, each opened by a tier.
    public enum Feature: String, Codable, Sendable, CaseIterable {
        /// Letter runs with a reply, a new address or a parcel to fetch (three steps).
        case letterChains
        /// One extra urgent errand on the plaza board each day.
        case urgentErrand
        /// A joint errand every third day: two or three neighbours' requests in one chain.
        case jointErrand
        /// Remnant cases from the next tower band up.
        case higherRemnants
        /// A weekly city commission from the harbour office or city hall.
        case cityCommission
    }

    public struct Tier: Equatable, Sendable {
        public let level: Int
        public let name: String
        public let threshold: Int
        public let opens: [Feature]
    }

    public static let tiers: [Tier] = [
        .init(level: 1, name: "新来的", threshold: 0, opens: []),
        .init(level: 2, name: "熟面孔", threshold: 120, opens: [.letterChains, .urgentErrand]),
        .init(level: 3, name: "街坊信得过的人", threshold: 220, opens: [.jointErrand, .higherRemnants]),
        .init(level: 4, name: "雾港的帮手", threshold: 300, opens: [.cityCommission]),
    ]

    public static func tier(points: Int) -> Tier {
        tiers.last { points >= $0.threshold } ?? tiers[0]
    }

    public static func nextTier(points: Int) -> Tier? {
        tiers.first { points < $0.threshold }
    }

    public static func requiredTier(_ feature: Feature) -> Tier {
        tiers.first { $0.opens.contains(feature) }!
    }

    public static func isOpen(_ feature: Feature, points: Int) -> Bool {
        points >= requiredTier(feature).threshold
    }

    /// For the home screen and the newspaper.
    public static func progressText(points: Int) -> String {
        let now = tier(points: points)
        guard let next = nextTier(points: points) else { return "城市贡献度 \(points) · \(now.name)" }
        return "城市贡献度 \(points)／\(next.threshold) · \(now.name)，下一档“\(next.name)”"
    }
}

/// One save's contribution. Every award has a receipt ID, so a repeated callback,
/// a restored save or a replayed battle never pays twice.
public struct MPCCityContributionLedger: Codable, Equatable, Sendable {
    public private(set) var points = 0
    public private(set) var receipts: Set<String> = []
    /// "day|source" → awards counted that day, for the capped sources.
    public private(set) var daily: [String: Int] = [:]
    /// Set once when an old save's progress was converted; the receipt of that migration.
    public private(set) var migratedPoints: Int?

    public init() {}

    public var tier: MPCCityContribution.Tier { MPCCityContribution.tier(points: points) }
    public func isOpen(_ feature: MPCCityContribution.Feature) -> Bool { MPCCityContribution.isOpen(feature, points: points) }

    /// Awards a source once per receipt. Returns the points added: 0 for a repeated
    /// receipt or when the day's cap for that source is already reached.
    @discardableResult
    public mutating func record(receiptID: String, source: MPCCityContribution.Source, day: Int) -> Int {
        guard !receipts.contains(receiptID) else { return 0 }
        let key = "\(day)|\(source.rawValue)"
        if let cap = MPCCityContribution.dailyCap(source), daily[key, default: 0] >= cap { return 0 }
        receipts.insert(receiptID)
        if MPCCityContribution.dailyCap(source) != nil { daily[key, default: 0] += 1 }
        let added = MPCCityContribution.points(source)
        points += added
        return added
    }

    /// One-time conversion for a save made before contribution existed: first clears,
    /// closed bounties and finished errands count as if earned. Later calls do nothing.
    @discardableResult
    public mutating func migrate(completedMissions: Int, closedBounties: Int, completedErrands: Int) -> Bool {
        guard migratedPoints == nil else { return false }
        let converted = completedMissions * MPCCityContribution.points(.mission)
            + closedBounties * MPCCityContribution.points(.bounty)
            + completedErrands * MPCCityContribution.points(.errand)
        points += converted
        migratedPoints = converted
        return true
    }
}
