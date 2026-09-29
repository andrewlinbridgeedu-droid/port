import Foundation

/// Chapter one's four local city events, agreed 2026-09-29
/// (DAILY_LOOP_AND_ECONOMY_20260929.md §4.3, §8.3). Same shape as the lights event:
/// deliver goods to a funded order, win the event's street battles, and the city
/// changes. Single save: the other helpers are labelled fixtures, not players.
/// Progress follows the calendar: at most two battle wins count per day, the order
/// buys only what the event still needs, and a failure costs a week, never a story gate.
public struct MPCCityEvent: Equatable, Sendable, Identifiable {
    public struct Delivery: Equatable, Sendable {
        public let itemID: String
        public let quantity: Int
        /// Paid per unit from the event's escrow; below the workshop order price.
        public let price: Int
    }

    /// What the city change does to the daily loop. Success lasts for the chapter from
    /// the day the event is completed; failure lasts `MPCCityEventCatalog.failureDays`
    /// days after the event's last day.
    public struct Effects: Equatable, Sendable {
        /// Added to the workshop order board's daily budget.
        public var orderBudgetBonus = 0
        /// Added to the shop's pain-salve price.
        public var salveSurcharge = 0
        /// Added to every recipe's base-stock copper (negative is a discount).
        public var craftSurcharge = 0
        public init(orderBudgetBonus: Int = 0, salveSurcharge: Int = 0, craftSurcharge: Int = 0) {
            self.orderBudgetBonus = orderBudgetBonus; self.salveSurcharge = salveSurcharge; self.craftSurcharge = craftSurcharge
        }
        static func + (a: Effects, b: Effects) -> Effects {
            .init(orderBudgetBonus: a.orderBudgetBonus + b.orderBudgetBonus, salveSurcharge: a.salveSurcharge + b.salveSurcharge,
                  craftSurcharge: a.craftSurcharge + b.craftSurcharge)
        }
    }

    public let id: String
    public let title: String
    public let firstDay: Int
    public let lastDay: Int
    public let partner: String
    public let briefing: String
    public let deliveries: [Delivery]
    public let battleTitle: String
    public let battlesNeeded: Int
    public let waves: [[MPCChurchTowerCatalog.Species]]
    /// Street bodies weigh like the tower band at or below this floor.
    public let bodyFloor: Int
    public let success: String
    public let successEffects: Effects
    public let failure: String
    public let failureEffects: Effects
    /// Kept for chapter two (e.g. whether the steam workshop was founded on time).
    public let successFlag: String

    public func isRunning(day: Int) -> Bool { (firstDay...lastDay).contains(day) }
    /// Everything the event can ever pay; its money is new copper in a single save.
    public var escrow: Int {
        deliveries.reduce(0) { $0 + $1.quantity * $1.price } + battlesNeeded * MPCCityEventCatalog.battlePay
    }
}

public enum MPCCityEventCatalog {
    public static let countedWinsPerDay = 2
    public static let battlePay = 10
    public static let failureDays = 7
    public static let prefix = "church_maintenance_event_"
    public static let fixtureNotice = "一起帮忙的其他街坊和工人是预置人物，不是联网玩家；进度只算你自己的交付和战斗。"

    static var strap: String { MPCCraftingCatalog.strapID }
    static var salve: String { MPCCraftingCatalog.salveID }
    static var patch: String { MPCCraftingCatalog.patchID }
    static var cloth: String { MPCCraftingCatalog.clothID }

    public static let all: [MPCCityEvent] = [
        .init(id: "casualty-wave", title: "伤患潮", firstDay: 4, lastDay: 10, partner: "奥黛尔（诊所）",
              briefing: "塔里外溢的伤者一夜之间挤满了诊所，绷带和止痛膏都见了底。诊所街上还有塔怪拦着送药的人。",
              deliveries: [.init(itemID: strap, quantity: 9, price: 5), .init(itemID: salve, quantity: 4, price: 12)],
              battleTitle: "清理诊所街", battlesNeeded: 6, waves: [[.shieldJaw, .copperback], [.saltSac]], bodyFloor: 10,
              success: "诊所撑过了伤患潮。奥黛尔开始长期收购药剂，工坊订单每天多 10 铜预算。",
              successEffects: .init(orderBudgetBonus: 10),
              failure: "诊所缺药，止痛膏在商店涨价 10 铜，持续一周。",
              failureEffects: .init(salveSurcharge: 10), successFlag: "clinic_buys_remedies"),
        .init(id: "pump-station", title: "泵站修复", firstDay: 11, lastDay: 17, partner: "泵站工头",
              briefing: "西区泵站的滤网被塔里渗出的瘴气糊死，清水断了三天。工头要过滤布换网，作业区里还盘着囊背寄魔。",
              deliveries: [.init(itemID: cloth, quantity: 12, price: 4), .init(itemID: strap, quantity: 4, price: 5)],
              battleTitle: "清理泵站作业区", battlesNeeded: 6, waves: [[.backSac, .shieldJaw], [.saltSac, .goldenThroat]], bodyFloor: 40,
              success: "泵站恢复供水，织造订单多了，工坊订单每天再多 10 铜预算。",
              successEffects: .init(orderBudgetBonus: 10),
              failure: "限水一周，工坊每次制作的底料多花 2 铜。",
              failureEffects: .init(craftSurcharge: 2), successFlag: "clean_water_restored"),
        .init(id: "harbor-blockade", title: "港口封锁", firstDay: 18, lastDay: 24, partner: "港务员",
              briefing: "主航道被封，封锁线后的旧仓区让塔怪占了。港务处要修甲片补船壳，也要人清出一条临时通道。",
              deliveries: [.init(itemID: patch, quantity: 12, price: 4), .init(itemID: salve, quantity: 2, price: 12)],
              battleTitle: "清理封锁线仓区", battlesNeeded: 6, waves: [[.scissor, .shieldJaw], [.crown, .copperback]], bodyFloor: 70,
              success: "替代航路开通，底料运进来便宜了，工坊每次制作少花 2 铜。",
              successEffects: .init(craftSurcharge: -2),
              failure: "封锁又拖了一周，港务处停购，工坊订单每天少 20 铜预算。",
              failureEffects: .init(orderBudgetBonus: -20), successFlag: "alternate_route_open"),
        .init(id: "workshop-foundation", title: "蒸汽工坊奠基", firstDay: 25, lastDay: 28, partner: "维拉（铁匠铺）",
              briefing: "维拉要在旧锅炉房的地基上立起蒸汽工坊。工地缺各类基础货，夜里还有塔怪来扒地基。",
              deliveries: [.init(itemID: strap, quantity: 6, price: 5), .init(itemID: patch, quantity: 6, price: 4),
                           .init(itemID: cloth, quantity: 6, price: 4), .init(itemID: salve, quantity: 2, price: 12)],
              battleTitle: "守住工地", battlesNeeded: 4, waves: [[.boneclaw], [.scissor, .crown]], bodyFloor: 90,
              success: "蒸汽工坊奠基完成，第二章的进阶配方从这里开始。",
              successEffects: .init(),
              failure: "奠基推迟，第二章开头要先补完地基，进阶配方晚一周开放。",
              failureEffects: .init(), successFlag: "steam_workshop_founded")
    ]

    public static func event(_ id: String) -> MPCCityEvent? { all.first { $0.id == id } }
    /// The event running on this pacing day, if any.
    public static func running(day: Int) -> MPCCityEvent? { all.first { $0.isRunning(day: day) } }

    public static func encounterID(eventID: String, ticket: String) -> String { prefix + eventID + "_" + ticket }
    public static func encounter(id: String) -> MPCEncounterContent? {
        guard let parsed = MPCStreetEncounters.parse(id, prefix: prefix), let event = event(parsed.key) else { return nil }
        return MPCStreetEncounters.content(id: id, name: event.battleTitle, tag: "event", waves: event.waves, floor: event.bodyFloor)
    }
}

/// One save's part in the four events. Receipts make every command safe to replay;
/// the order pays from the event's escrow and never beyond what the event needs.
public struct MPCCityEventLedger: Codable, Equatable, Sendable {
    public enum Failure: Error, Equatable { case notRunning, notNeeded, stock, dailyLimit, pending, invalidBattle, conflict }
    public enum Status: String, Codable, Sendable { case upcoming, running, succeeded, failed }

    public struct Progress: Codable, Equatable, Sendable {
        public fileprivate(set) var delivered: [String: Int] = [:]
        public fileprivate(set) var wins = 0
        /// Counted wins by pacing day, for the two-a-day limit.
        public fileprivate(set) var winsByDay: [String: Int] = [:]
        public fileprivate(set) var paid = 0
        public fileprivate(set) var completedDay: Int?
    }
    public struct Entry: Codable, Equatable, Sendable {
        public let id: String
        public let eventID: String
        public let text: String
        public let copper: Int
    }
    struct Receipt: Codable, Equatable, Sendable {
        let command: String
        let units: Int
    }

    public private(set) var progress: [String: Progress] = [:]
    public private(set) var activeTicket: String?
    public private(set) var activeEventID: String?
    public private(set) var entries: [Entry] = []
    private var receipts: [String: Receipt] = [:]
    private var settledTickets: Set<String> = []
    public init() {}

    public func status(_ eventID: String, day: Int) -> Status {
        guard let event = MPCCityEventCatalog.event(eventID) else { return .upcoming }
        if let done = progress[eventID]?.completedDay, day >= done { return .succeeded }
        if day < event.firstDay { return .upcoming }
        return day > event.lastDay ? .failed : .running
    }

    public func remaining(_ event: MPCCityEvent, itemID: String) -> Int {
        guard let need = event.deliveries.first(where: { $0.itemID == itemID }) else { return 0 }
        return max(0, need.quantity - (progress[event.id]?.delivered[itemID] ?? 0))
    }
    public func winsLeft(_ event: MPCCityEvent) -> Int { max(0, event.battlesNeeded - (progress[event.id]?.wins ?? 0)) }
    public func winsCounted(_ eventID: String, day: Int) -> Int { progress[eventID]?.winsByDay[String(day)] ?? 0 }

    /// Success flags of completed events, for chapter two.
    public var flags: Set<String> {
        Set(MPCCityEventCatalog.all.filter { progress[$0.id]?.completedDay != nil }.map(\.successFlag))
    }

    /// The city as it stands on this day.
    public func effects(day: Int) -> MPCCityEvent.Effects {
        MPCCityEventCatalog.all.reduce(MPCCityEvent.Effects()) { total, event in
            switch status(event.id, day: day) {
            case .succeeded: return total + event.successEffects
            case .failed where day <= event.lastDay + MPCCityEventCatalog.failureDays: return total + event.failureEffects
            default: return total
            }
        }
    }

    private func replay(_ id: String, _ command: String) throws -> Int? {
        guard MPCStreetEncounters.validTicket(id) else { throw Failure.conflict }
        guard let prior = receipts[id] else { return nil }
        guard prior.command == command else { throw Failure.conflict }
        return prior.units
    }

    private mutating func completeIfDone(_ event: MPCCityEvent, day: Int) {
        guard var p = progress[event.id], p.completedDay == nil, winsLeft(event) == 0,
              event.deliveries.allSatisfy({ remaining(event, itemID: $0.itemID) == 0 }) else { return }
        p.completedDay = day
        progress[event.id] = p
        entries.append(.init(id: "complete-" + event.id, eventID: event.id, text: event.success, copper: 0))
    }

    /// Hands over up to `count` units of a good the event still needs and is paid for
    /// them. Returns the units taken; a replayed receipt returns its first result.
    @discardableResult
    public mutating func deliver(id: String, eventID: String, itemID: String, count: Int, day: Int,
                                 coins: inout Int, inventory: inout [String: Int]) throws -> Int {
        let command = "deliver:" + eventID + ":" + itemID
        if let units = try replay(id, command) { return units }
        guard let event = MPCCityEventCatalog.event(eventID), status(eventID, day: day) == .running else { throw Failure.notRunning }
        guard let need = event.deliveries.first(where: { $0.itemID == itemID }), remaining(event, itemID: itemID) > 0 else {
            throw Failure.notNeeded
        }
        let units = min(count, remaining(event, itemID: itemID), inventory[itemID, default: 0])
        guard units > 0 else { throw Failure.stock }
        let pay = units * need.price
        inventory[itemID, default: 0] -= units
        coins += pay
        var p = progress[eventID] ?? .init()
        p.delivered[itemID, default: 0] += units
        p.paid += pay
        progress[eventID] = p
        receipts[id] = .init(command: command, units: units)
        entries.append(.init(id: id, eventID: eventID, text: "\(event.partner)收下\(units)件，付\(pay)铜。", copper: pay))
        completeIfDone(event, day: day)
        return units
    }

    /// Writes the ticket before combat. Only one event battle runs at a time, and none
    /// starts once today's two wins are counted or the event has all the wins it needs.
    public mutating func beginBattle(ticket: String, eventID: String, day: Int) throws -> String {
        if activeTicket == ticket, activeEventID == eventID { return MPCCityEventCatalog.encounterID(eventID: eventID, ticket: ticket) }
        guard let event = MPCCityEventCatalog.event(eventID), status(eventID, day: day) == .running else { throw Failure.notRunning }
        guard activeTicket == nil else { throw Failure.pending }
        guard MPCStreetEncounters.validTicket(ticket), receipts[ticket] == nil, !settledTickets.contains(ticket) else { throw Failure.conflict }
        guard winsLeft(event) > 0 else { throw Failure.notNeeded }
        guard winsCounted(eventID, day: day) < MPCCityEventCatalog.countedWinsPerDay else { throw Failure.dailyLimit }
        activeTicket = ticket
        activeEventID = eventID
        return MPCCityEventCatalog.encounterID(eventID: eventID, ticket: ticket)
    }

    /// Settles the finished battle once. A win on a running day inside today's limit
    /// counts and pays; anything else just closes the ticket.
    @discardableResult
    public mutating func settleBattle(ticket: String, session: MPCChapterOneEncounterSession, day: Int, coins: inout Int) throws -> Bool {
        if settledTickets.contains(ticket) { return false }
        guard activeTicket == ticket, let eventID = activeEventID, let event = MPCCityEventCatalog.event(eventID),
              session.encounter.id == MPCCityEventCatalog.encounterID(eventID: eventID, ticket: ticket),
              session.outcome != .inProgress else { throw Failure.invalidBattle }
        activeTicket = nil
        activeEventID = nil
        settledTickets.insert(ticket)
        guard session.outcome == .victory, status(eventID, day: day) == .running, winsLeft(event) > 0,
              winsCounted(eventID, day: day) < MPCCityEventCatalog.countedWinsPerDay else {
            entries.append(.init(id: "settle-" + ticket, eventID: eventID,
                                 text: session.outcome == .victory ? "打赢了，今天的贡献已经记满。" : "没有守住，这一场不记贡献。", copper: 0))
            return true
        }
        var p = progress[eventID] ?? .init()
        p.wins += 1
        p.winsByDay[String(day), default: 0] += 1
        p.paid += MPCCityEventCatalog.battlePay
        progress[eventID] = p
        coins += MPCCityEventCatalog.battlePay
        entries.append(.init(id: "settle-" + ticket, eventID: eventID,
                             text: "\(event.battleTitle)：打赢了，记 1 场，付\(MPCCityEventCatalog.battlePay)铜。", copper: MPCCityEventCatalog.battlePay))
        completeIfDone(event, day: day)
        return true
    }

    /// Retreat or an abandoned battle closes the ticket without contribution.
    public mutating func abandonBattle(ticket: String) {
        guard activeTicket == ticket, let eventID = activeEventID else { return }
        activeTicket = nil
        activeEventID = nil
        settledTickets.insert(ticket)
        entries.append(.init(id: "settle-" + ticket, eventID: eventID, text: "中途撤退，这一场不记贡献。", copper: 0))
    }
}
