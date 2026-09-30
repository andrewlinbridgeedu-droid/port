import Foundation
import MistportCombatCore

/// A cached housing snapshot. The rules implementation is temporary; no shared-server
/// occupancy or clock authority is claimed by this adapter.
struct HousingRecord: Codable, Equatable {
    var ledger = MPCHousingLedger()
    var stamina: MPCStaminaState
    var homeLodgingID = MPCHousingCatalog.basicLodgingID
    var bonusExpiresAt: Date?
    var queuedLodgingIDs: Set<String> = []
    init(at date: Date) { stamina = .init(at: date.timeIntervalSince1970) }
}
struct HousingUpdate {
    var record: HousingRecord
    var cash: Int
}
struct HousingRoomAvailability: Identifiable {
    let id: String
    let roomsLeft: Int?
    let capacity: Int?
}

/// Commands are asynchronous so a server adapter can authorize them without changing views.
/// commit caches an accepted snapshot; GameStore journals wallet and snapshot together.
@MainActor
protocol HousingService: AnyObject {
    var record: HousingRecord? { get }
    var isReadable: Bool { get }
    func prepareDay(cash: Int, completedMissions: Int, at date: Date) async throws -> HousingUpdate
    func prepareLease(lodgingID: String, mealID: String, at date: Date, cash: Int,
                      completedMissions: Int) async throws -> HousingUpdate
    func prepareMeal(mealID: String, at date: Date, cash: Int,
                     completedMissions: Int) async throws -> HousingUpdate
    func prepareSpend(_ activity: MPCStamina.Activity, receiptID: String,
                      at date: Date) async throws -> HousingRecord
    func rooms() async throws -> [HousingRoomAvailability]
    func commit(_ record: HousingRecord) throws
}

enum HousingServiceFailure: Error, LocalizedError {
    case unreadable, unavailable, shelterAutomatic
    var errorDescription: String? {
        switch self {
        case .unreadable: "住处账本暂不可读取，请重新打开。"
        case .unavailable: "房间已满，请先登记等候。"
        case .shelterAutomatic: "施济登记会在每日生活费结算时，按恢复线安排避难屋。"
        }
    }
}

/// Pacific day identity uses Calendar, not a fixed UTC offset; DST cannot pay twice.
enum HousingServerDay {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }
    static func number(_ date: Date) -> Int { calendar.ordinality(of: .day, in: .era, for: date)! }
    static func nextBoundary(_ date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }
}

@MainActor
final class RulesHousingService: HousingService {
    static let persistenceKey = "mistport.housing-stamina.v1"
    private let defaults: UserDefaults
    private let roomCounts: [String: Int]
    private(set) var record: HousingRecord?
    private(set) var isReadable = true

    init(defaults: UserDefaults, roomCounts: [String: Int] = [:]) {
        self.roomCounts = roomCounts
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.persistenceKey) {
            do { record = try JSONDecoder().decode(HousingRecord.self, from: data) }
            catch { isReadable = false }
        }
    }
    private func current(at date: Date) throws -> HousingRecord {
        guard isReadable else { throw HousingServiceFailure.unreadable }
        var r = record ?? HousingRecord(at: date)
        // Paid lodging bonuses end at midnight even when the app stayed closed.
        // Unpaid days recover at the base rate, never retroactively at the luxury rate.
        if let expiry = r.bonusExpiresAt, date >= expiry {
            r.stamina.setRecovery(perDay: MPCStamina.baseRecoveryPerDay, at: expiry.timeIntervalSince1970)
            r.bonusExpiresAt = nil
        }
        return r
    }
    func prepareDay(cash: Int, completedMissions: Int, at date: Date) async throws -> HousingUpdate {
        var r = try current(at: date), coins = cash
        let isNewDay = r.ledger.payments[HousingServerDay.number(date)] == nil
        let payment = r.ledger.payDay(HousingServerDay.number(date), cash: &coins,
                                    completedMissions: completedMissions)
        if isNewDay { r.homeLodgingID = payment.lodgingID }
        r.stamina.setRecovery(perDay: payment.recoveryPerDay, at: date.timeIntervalSince1970)
        r.bonusExpiresAt = HousingServerDay.nextBoundary(date)
        return .init(record: r, cash: coins)
    }
    func prepareLease(lodgingID: String, mealID: String, at date: Date, cash: Int,
                      completedMissions: Int) async throws -> HousingUpdate {
        var update = try await prepareDay(cash: cash, completedMissions: completedMissions, at: date)
        guard let lodging = MPCHousingCatalog.lodging(lodgingID) else { throw MPCHousingLedger.Failure.unknown }
        guard !lodging.belowRecoveryLineOnly else { throw HousingServiceFailure.shelterAutomatic }
        let availability = try await rooms().first { $0.id == lodgingID }
        try update.record.ledger.sign(lodgingID: lodgingID, mealID: mealID,
            day: HousingServerDay.number(date), roomsLeft: availability?.roomsLeft)
        update.record.homeLodgingID = lodgingID
        update.record.queuedLodgingIDs.remove(lodgingID)
        // Today's paid receipt is immutable. Moving or changing meals does not re-charge
        // today and does not grant an unpaid recovery bonus; the next daily receipt applies it.
        return update
    }
    func prepareMeal(mealID: String, at date: Date, cash: Int,
                     completedMissions: Int) async throws -> HousingUpdate {
        var update = try await prepareDay(cash: cash, completedMissions: completedMissions, at: date)
        try update.record.ledger.chooseMeal(mealID)
        return update
    }
    func prepareSpend(_ activity: MPCStamina.Activity, receiptID: String,
                      at date: Date) async throws -> HousingRecord {
        var r = try current(at: date)
        _ = try r.stamina.spend(activity, receiptID: receiptID, at: date.timeIntervalSince1970)
        return r
    }
    func rooms() async throws -> [HousingRoomAvailability] {
        guard isReadable else { throw HousingServiceFailure.unreadable }
        // Single-ledger capacity fixture, never a claim about live shared-server occupancy.
        return MPCHousingCatalog.lodgings.map { lodging in
            .init(id: lodging.id, roomsLeft: roomCounts[lodging.id] ?? lodging.rooms, capacity: lodging.rooms)
        }
    }
    func commit(_ record: HousingRecord) throws {
        guard isReadable else { throw HousingServiceFailure.unreadable }
        let data = try JSONEncoder().encode(record)
        defaults.set(data, forKey: Self.persistenceKey)
        self.record = record
    }
}


/// Serializes commands across suspension points; a double tap cannot overwrite another wallet snapshot.
@MainActor
final class HousingCommandGate {
    private var busy = false
    private var waiting: [CheckedContinuation<Void, Never>] = []
    func acquire() async {
        if !busy { busy = true; return }
        await withCheckedContinuation { waiting.append($0) }
    }
    func release() {
        if waiting.isEmpty { busy = false } else { waiting.removeFirst().resume() }
    }
}
