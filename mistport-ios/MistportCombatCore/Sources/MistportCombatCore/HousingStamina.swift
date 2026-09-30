import Foundation

/// Stamina, lodging and meals (HOUSING_STAMINA_ARCHITECTURE_20260930.md, user-approved
/// 2026-09-30). Stamina gates the daily loop only: story missions, tower first clears and
/// bounties cost none, because they already open by day. Everyone's maximum is the same;
/// better lodging and meals only recover a little faster.
public enum MPCStamina {
    public static let maximum = 100
    /// Recovery a day with the basic basket; lodging and meal bonuses add up to `bonusCap`.
    public static let baseRecoveryPerDay = 100
    public static let bonusCap = 20

    public enum Activity: String, Codable, Sendable, CaseIterable {
        case post, errandTwoStep, errandThreeStep, remnant, eventDelivery, eventBattle, craft
        case urgentErrand, jointErrand, cityCommission
        case highlandShort, highlandLong
        /// Story, tower first clears and replays, bounties: free.
        case storyOrChurch
    }

    public static func cost(_ activity: Activity) -> Int {
        switch activity {
        case .post: 10
        case .errandTwoStep: 10
        case .errandThreeStep: 15
        case .remnant: 20
        case .eventDelivery: 5
        case .eventBattle: 15
        case .craft: 5
        case .urgentErrand: 15
        case .jointErrand: 25
        case .cityCommission: 35
        case .highlandShort: 15
        case .highlandLong: 30
        case .storyOrChurch: 0
        }
    }
}

/// A player's stamina on the server clock. It recovers continuously and stops at the maximum,
/// so it cannot be banked. Spending carries a receipt, so a retried request spends once.
public struct MPCStaminaState: Codable, Equatable, Sendable {
    public enum Failure: Error, Equatable, Sendable { case notEnough(needed: Int, available: Int) }
    /// Stamina at `settledAt` (seconds on the server clock), with fractions kept.
    public private(set) var value: Double
    public private(set) var settledAt: TimeInterval
    public private(set) var recoveryPerDay: Int
    public private(set) var receipts: Set<String> = []

    public init(at now: TimeInterval, recoveryPerDay: Int = MPCStamina.baseRecoveryPerDay) {
        value = Double(MPCStamina.maximum); settledAt = now; self.recoveryPerDay = recoveryPerDay
    }

    public func current(at now: TimeInterval) -> Double {
        min(Double(MPCStamina.maximum), value + max(0, now - settledAt) / 86_400 * Double(recoveryPerDay))
    }

    /// Whole points available now (what the App shows and what a task checks).
    public func available(at now: TimeInterval) -> Int { Int(current(at: now).rounded(.down)) }

    /// Seconds until `points` are available, 0 if they already are.
    public func secondsUntil(_ points: Int, at now: TimeInterval) -> TimeInterval {
        let missing = Double(min(points, MPCStamina.maximum)) - current(at: now)
        return missing <= 0 ? 0 : missing / Double(recoveryPerDay) * 86_400
    }

    private mutating func settle(at now: TimeInterval) {
        value = current(at: now); settledAt = max(settledAt, now)
    }

    /// Spends stamina when an activity starts. Returns false for a receipt already spent.
    @discardableResult
    public mutating func spend(_ activity: MPCStamina.Activity, receiptID: String, at now: TimeInterval) throws -> Bool {
        guard !receipts.contains(receiptID) else { return false }
        let cost = MPCStamina.cost(activity)
        let have = available(at: now)
        guard have >= cost else { throw Failure.notEnough(needed: cost, available: have) }
        settle(at: now)
        value -= Double(cost)
        receipts.insert(receiptID)
        return true
    }

    /// A new lodging or meal changes the recovery speed from now on.
    public mutating func setRecovery(perDay: Int, at now: TimeInterval) {
        settle(at: now); recoveryPerDay = perDay
    }
}

public enum MPCHousingCatalog {
    public enum District: String, Codable, Sendable { case harbor, oldArcade, canal, church, highland }

    public struct Lodging: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let district: District
        public let copperPerDay: Int
        public let staminaBonus: Int
        /// Rooms on a 2,000-player server; nil is unlimited.
        public let rooms: Int?
        /// The church shelter: only while the player holds less than their recovery line.
        public let belowRecoveryLineOnly: Bool
    }

    public struct Meal: Equatable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let copperPerDay: Int
        public let staminaBonus: Int
        /// The house kitchen comes with a highland house.
        public let requiresLodgingID: String?
    }

    public static let lodgings: [Lodging] = [
        .init(id: "shelter", name: "教会避难屋", district: .church, copperPerDay: 0, staminaBonus: 0, rooms: nil, belowRecoveryLineOnly: true),
        .init(id: "dock_bunk", name: "码头铺位", district: .harbor, copperPerDay: 3, staminaBonus: 0, rooms: nil, belowRecoveryLineOnly: false),
        .init(id: "arcade_room", name: "拱廊合租间", district: .oldArcade, copperPerDay: 6, staminaBonus: 3, rooms: 1_200, belowRecoveryLineOnly: false),
        .init(id: "canal_house", name: "运河联排屋", district: .canal, copperPerDay: 12, staminaBonus: 6, rooms: 600, belowRecoveryLineOnly: false),
        .init(id: "bell_loft", name: "钟楼阁楼", district: .church, copperPerDay: 16, staminaBonus: 10, rooms: 200, belowRecoveryLineOnly: false),
        .init(id: "highland_house", name: "高地石宅", district: .highland, copperPerDay: 30, staminaBonus: 12, rooms: 80, belowRecoveryLineOnly: false),
    ]

    public static let meals: [Meal] = [
        .init(id: "church_soup", name: "教会施粥", copperPerDay: 0, staminaBonus: 0, requiresLodgingID: "shelter"),
        .init(id: "soup_shed", name: "汤棚", copperPerDay: 9, staminaBonus: 0, requiresLodgingID: nil),
        .init(id: "bakery", name: "面包坊", copperPerDay: 12, staminaBonus: 3, requiresLodgingID: nil),
        .init(id: "cafe", name: "咖啡馆", copperPerDay: 14, staminaBonus: 5, requiresLodgingID: nil),
        .init(id: "house_kitchen", name: "宅内厨房", copperPerDay: 20, staminaBonus: 8, requiresLodgingID: "highland_house"),
    ]

    public static let basicLodgingID = "dock_bunk", basicMealID = "soup_shed"
    public static let shelterID = "shelter", shelterMealID = "church_soup"
    /// Only a highland resident can take highland-board errands (user decision 2026-09-30).
    public static let highlandLodgingID = "highland_house"
    public static let leaseDays = 7

    public static func lodging(_ id: String) -> Lodging? { lodgings.first { $0.id == id } }
    public static func meal(_ id: String) -> Meal? { meals.first { $0.id == id } }

    public static func recoveryPerDay(lodgingID: String, mealID: String) -> Int {
        let bonus = (lodging(lodgingID)?.staminaBonus ?? 0) + (meal(mealID)?.staminaBonus ?? 0)
        return MPCStamina.baseRecoveryPerDay + min(MPCStamina.bonusCap, bonus)
    }

    /// The recovery line (shared economy V3, unchanged): below it posting pays and the shelter opens.
    public static func recoveryLine(completedMissions: Int) -> Int {
        completedMissions >= 30 ? 400 : completedMissions >= 23 ? 600 : completedMissions >= 20 ? 460 : completedMissions >= 17 ? 380 : 180
    }
}

/// Where a player lives and eats, and the daily payment. The server holds this; rooms and
/// the queue for the limited tiers are counted across players on the server.
public struct MPCHousingLedger: Codable, Equatable, Sendable {
    public enum Failure: Error, Equatable, Sendable { case unknown, notAllowed, noRoom }

    public struct DayPayment: Codable, Equatable, Sendable {
        public let day: Int
        public let lodgingID: String
        public let mealID: String
        public let copper: Int
        /// True when the chosen lodging or meal could not be paid and a cheaper one was used.
        public let downgraded: Bool
        public var recoveryPerDay: Int { MPCHousingCatalog.recoveryPerDay(lodgingID: lodgingID, mealID: mealID) }
    }

    /// The lodging and meal the player chose (the lease), and the last day the lease covers.
    public private(set) var lodgingID = MPCHousingCatalog.basicLodgingID
    public private(set) var mealID = MPCHousingCatalog.basicMealID
    public private(set) var leaseEndsDay = 0
    public private(set) var payments: [Int: DayPayment] = [:]

    public init() {}

    /// Changing food does not extend a lease or replace a day's paid receipt.
    public mutating func chooseMeal(_ mealID: String) throws {
        guard let meal = MPCHousingCatalog.meal(mealID) else { throw Failure.unknown }
        guard meal.requiresLodgingID == nil || meal.requiresLodgingID == lodgingID else { throw Failure.notAllowed }
        self.mealID = mealID
    }

    /// Signs a lease of `leaseDays` from `day`. `roomsLeft` is the server's count for that
    /// lodging (nil for unlimited). Paying is daily; signing costs nothing by itself.
    public mutating func sign(lodgingID: String, mealID: String, day: Int, roomsLeft: Int?) throws {
        guard let lodging = MPCHousingCatalog.lodging(lodgingID), let meal = MPCHousingCatalog.meal(mealID) else { throw Failure.unknown }
        guard !lodging.belowRecoveryLineOnly, meal.requiresLodgingID == nil || meal.requiresLodgingID == lodgingID else { throw Failure.notAllowed }
        if lodging.rooms != nil, lodgingID != self.lodgingID || day > leaseEndsDay { guard (roomsLeft ?? 0) > 0 else { throw Failure.noRoom } }
        self.lodgingID = lodgingID; self.mealID = mealID
        leaseEndsDay = day + MPCHousingCatalog.leaseDays - 1
    }

    /// The day's payment, taken on the player's first request of a server day. Never goes
    /// into debt and never takes the player below half their recovery line: the meal drops
    /// to the soup shed first, then the lodging to the dock bunk; below the recovery line the
    /// church shelter and its soup are free. A lease that ended falls back to the basics.
    @discardableResult
    public mutating func payDay(_ day: Int, cash: inout Int, completedMissions: Int) -> DayPayment {
        if let paid = payments[day] { return paid }
        if day > leaseEndsDay { lodgingID = MPCHousingCatalog.basicLodgingID; mealID = MPCHousingCatalog.basicMealID }
        let line = MPCHousingCatalog.recoveryLine(completedMissions: completedMissions)
        let keep = line / 2
        func price(_ l: String, _ m: String) -> Int {
            (MPCHousingCatalog.lodging(l)?.copperPerDay ?? 0) + (MPCHousingCatalog.meal(m)?.copperPerDay ?? 0)
        }
        let choices: [(String, String)] = [
            (lodgingID, mealID),
            (lodgingID, MPCHousingCatalog.basicMealID),
            (MPCHousingCatalog.basicLodgingID, MPCHousingCatalog.basicMealID),
        ]
        var chosen = (MPCHousingCatalog.shelterID, MPCHousingCatalog.shelterMealID)
        if cash >= line {
            chosen = choices.first { cash - price($0.0, $0.1) >= keep } ?? choices.last!
            if cash - price(chosen.0, chosen.1) < 0 { chosen = (MPCHousingCatalog.shelterID, MPCHousingCatalog.shelterMealID) }
        } else if cash - price(MPCHousingCatalog.basicLodgingID, MPCHousingCatalog.basicMealID) >= keep {
            chosen = (MPCHousingCatalog.basicLodgingID, MPCHousingCatalog.basicMealID)
        }
        let copper = price(chosen.0, chosen.1)
        cash -= copper
        let payment = DayPayment(day: day, lodgingID: chosen.0, mealID: chosen.1, copper: copper,
                                 downgraded: chosen != (lodgingID, mealID))
        payments[day] = payment
        payments = payments.filter { $0.key > day - 30 }
        return payment
    }

    /// Highland-board errands need a highland house that is paid for today.
    public func canTakeHighlandErrands(day: Int) -> Bool {
        payments[day]?.lodgingID == MPCHousingCatalog.highlandLodgingID
    }
}
