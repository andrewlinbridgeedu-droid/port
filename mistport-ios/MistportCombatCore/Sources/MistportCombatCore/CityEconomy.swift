import Foundation

/// Chapter-one service rules. All commands operate on a copy; the host journals
/// the accepted snapshot and wallet together. Finite NPC balances are prototype
/// city allocations, not claims about a deployed multi-player economy.
public struct MPCCityEconomy: Codable, Equatable, Sendable {
    public enum Failure: Error, Equatable, LocalizedError, Sendable {
        case locked, funds, limit, duplicate, evidence, terms, stage, deadline, budget
        public var errorDescription: String? {
            switch self {
            case .locked: "还没有取得这项业务的资格。"
            case .funds: "可用铜币不足；在途本金不能用于付款。"
            case .limit: "已达到本阶段额度或本周接待次数。"
            case .duplicate: "这张凭据已经结算，无需再交一次。"
            case .evidence: "这份说法缺少原始单据与封印的交叉证明。"
            case .terms: "账房没有同意这份条款，请重新协商。"
            case .stage: "请先完成前一道手续。"
            case .deadline: "已超过履约期限，不能再按原合同交货。"
            case .budget: "本批客户的托管资金已用完，下一批采购尚未发布。"
            }
        }
    }
    public struct Deposit: Codable, Equatable, Sendable {
        public let principal: Int
        public let openedAt: TimeInterval
        public var closed = false
        public var dueAt: TimeInterval { openedAt + 72 * 3_600 }
        public var maturityValue: Int { principal / 20 * 24 }
    }
    public struct TermDeposit: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let principal: Int
        public let openedAt: TimeInterval
        public let profit: Int
        public var closed = false
        public var dueAt: TimeInterval { openedAt + 7 * 86_400 }
        public var maturityValue: Int { principal + profit }
    }
    public static func termProfit(_ amount: Int) -> Int { amount / 60 }
    public enum ProjectKind: String, Codable, Sendable, CaseIterable {
        case invoice, workshop, bicycle, shipping
        public var title: String {
            switch self { case .invoice: "染坊履约票据"; case .workshop: "工坊检修份额"; case .bicycle: "自行车厂首批订单"; case .shipping: "港务短程货运" }
        }
        public var mission: Int {
            switch self { case .invoice: 5; case .workshop: 16; case .bicycle: 13; case .shipping: 20 }
        }
        public var reputation: Int {
            switch self { case .invoice: 0; case .workshop: 120; case .bicycle: 120; case .shipping: 230 }
        }
        public var minimum: Int { self == .bicycle ? 60 : self == .shipping ? 100 : 20 }
        public var maximum: Int { self == .workshop ? 80 : self == .shipping ? 160 : 100 }
        public var days: Int { self == .bicycle ? 10 : self == .shipping ? 14 : 7 }
        public func repayment(_ principal: Int) -> Int {
            principal + (self == .invoice ? principal / 20 : principal * (self == .workshop ? 12 : self == .bicycle ? 15 : 20) / 100)
        }
        public func isOpen(completed: Set<Int>, reputation: Int) -> Bool {
            completed.contains(mission) && reputation >= self.reputation
        }
    }
    public struct Project: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let kind: ProjectKind
        public let principal: Int
        public let openedAt: TimeInterval
        public let batch: Int
        public var inspected = false
        public var delivered = false
        public var damaged = false
        public var settled = false
        public var repayment = 0
        public var dueAt: TimeInterval { openedAt + Double(kind.days) * 86_400 }
        public var deadline: TimeInterval { dueAt + 3 * 86_400 }
        public var fullRepayment: Int { kind.repayment(principal) }
    }
    public enum MeetingStage: String, Codable, Sendable { case invited, verified, contracted, collected, sealed, delivered, paid, failed, cancelled }
    public struct Meeting: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let customer: String
        public let openedAt: TimeInterval
        public let privateRoom: Bool
        public let lodgingID: String
        public let fee: Int
        public let inputs: Int
        public let payment: Int
        public let deliveryStamina: Int
        public var stage = MeetingStage.invited
        public var deliveredAt: TimeInterval?
        public var dueAt: TimeInterval? { deliveredAt.map { $0 + 86_400 } }
        public var deadline: TimeInterval { openedAt + 3 * 86_400 }
    }
    public private(set) var savings = 0
    public private(set) var deposit: Deposit?
    // Optional so the pre-term-deposit ledger decodes without resetting money.
    public private(set) var termDeposit: TermDeposit?
    public private(set) var projects: [Project] = []
    public private(set) var meeting: Meeting?
    public private(set) var lastMeetingAt: [String: TimeInterval] = [:]
    public private(set) var bankBonusBudget = 240
    public private(set) var customerBudget = 2_400
    public private(set) var bankBonusPaid = 0
    public private(set) var contractPaid = 0
    public private(set) var supplierReceipts = 0
    public private(set) var hostingReceipts = 0
    public private(set) var projectInputs = 0
    public private(set) var projectCustomerEscrow: [String: Int] = [:]
    public private(set) var meetingEscrow: [String: Int] = [:]
    public private(set) var restDay: Int?
    public private(set) var armedRestBP = 0
    public private(set) var armedRestDay: Int?
    public private(set) var battleRest: [String: Int] = [:]
    public private(set) var maintenanceDays: Set<Int> = []
    public private(set) var notices: [String] = []
    public init() {}

    public var outstanding: Int {
        (deposit.map { $0.closed ? 0 : $0.principal } ?? 0)
            + (termDeposit.map { $0.closed ? 0 : $0.principal } ?? 0)
            + projects.filter { !$0.settled }.map(\.principal).reduce(0, +)
    }
    public static func limit(completed: Set<Int>) -> Int { completed.contains(16) ? 160 : completed.contains(5) ? 100 : 60 }
    /// Suggested liquid reserve; the player can consciously choose otherwise.
    public static func reserve(completed: Set<Int>, ownedMaterials: Set<String>, ownedRelics: Set<String>, salve: Int) -> Int {
        let progress = completed.max() ?? 0
        let nodes = [(0, 0), (17, 500), (20, 1_150), (23, 2_100), (30, 2_400)]
        var saved = 2_400
        for index in 1..<nodes.count where progress <= nodes[index].0 {
            let lower = nodes[index - 1], upper = nodes[index]
            saved = lower.1 + (upper.1 - lower.1) * (progress - lower.0) / (upper.0 - lower.0)
            break
        }
        let paid = MPCAdvancementMaterialMarket.offers.filter { ownedMaterials.contains($0.id) }.map(\.price).reduce(0, +)
        let open = MPCAdvancementMaterialMarket.offers.filter { completed.contains($0.unlockMission) && !ownedMaterials.contains($0.id) }.map(\.price).max() ?? 0
        let basics = completed.contains(4) ? (ownedRelics.contains("relic_salt_sealed_breathing_bag") ? 0 : 120)
            + (ownedRelics.contains("relic_return_gift_clasp") ? 0 : 160) : 0
        return max(open, saved - paid, 0) + basics + 36 + salve
    }
    public mutating func save(_ amount: Int, coins: inout Int) throws {
        guard amount > 0, coins >= amount else { throw Failure.funds }
        coins -= amount; savings += amount
    }
    public mutating func withdraw(_ amount: Int, coins: inout Int) throws {
        guard amount > 0, savings >= amount else { throw Failure.funds }
        savings -= amount; coins += amount
    }
    public mutating func openDeposit(_ amount: Int, completed: Set<Int>, liquidReserve: Int = 0, now: TimeInterval, coins: inout Int) throws {
        guard completed.contains(1) else { throw Failure.locked }
        guard deposit == nil else { throw Failure.limit }
        guard [20, 40, 60].contains(amount), outstanding + amount <= Self.limit(completed: completed) else { throw Failure.limit }
        guard coins >= amount, coins - amount >= max(0, liquidReserve) else { throw Failure.funds }
        let bonus = amount / 20 * 4
        guard bankBonusBudget >= bonus else { throw Failure.budget }
        bankBonusBudget -= bonus; coins -= amount
        deposit = .init(principal: amount, openedAt: now)
    }
    public mutating func redeemDeposit(now: TimeInterval, coins: inout Int) throws {
        guard var item = deposit, !item.closed else { throw Failure.stage }
        let mature = now >= item.dueAt
        coins += mature ? item.maturityValue : item.principal
        if mature { bankBonusPaid += item.maturityValue - item.principal }
        else { bankBonusBudget += item.maturityValue - item.principal }
        item.closed = true; deposit = item
        addNotice(mature ? "新客存单到期，本息\(item.maturityValue)铜已入账。" : "已取回\(item.principal)铜本金；新客机会已使用。")
    }
    public mutating func openTermDeposit(_ amount: Int, completed: Set<Int>, liquidReserve: Int, now: TimeInterval, coins: inout Int) throws {
        guard completed.contains(1) else { throw Failure.locked }
        guard termDeposit == nil || termDeposit!.closed else { throw Failure.limit }
        guard [60, 120].contains(amount), outstanding + amount <= Self.limit(completed: completed) else { throw Failure.limit }
        guard coins >= amount, coins - amount >= max(0, liquidReserve) else { throw Failure.funds }
        let profit = Self.termProfit(amount)
        guard bankBonusBudget >= profit else { throw Failure.budget }
        bankBonusBudget -= profit; coins -= amount
        termDeposit = .init(id: UUID().uuidString, principal: amount, openedAt: now, profit: profit)
    }
    public mutating func redeemTermDeposit(now: TimeInterval, coins: inout Int) throws {
        guard var item = termDeposit, !item.closed else { throw Failure.stage }
        let mature = now >= item.dueAt
        coins += mature ? item.maturityValue : item.principal
        if mature { bankBonusPaid += item.profit } else { bankBonusBudget += item.profit }
        item.closed = true; termDeposit = item
        addNotice(mature ? "普通定期到期，本金\(item.principal)铜、利息\(item.profit)铜已入钱包。" : "已取回\(item.principal)铜本金，本期不计息。")
    }
    public mutating func openProject(kind: ProjectKind, amount: Int, completed: Set<Int>, reputation: Int = 0, day: Int, now: TimeInterval, coins: inout Int) throws {
        guard kind.isOpen(completed: completed, reputation: reputation) else { throw Failure.locked }
        guard amount >= kind.minimum, amount % 20 == 0, amount <= kind.maximum, outstanding + amount <= Self.limit(completed: completed) else { throw Failure.limit }
        let batch = (day - 1) / 7
        guard !projects.contains(where: { $0.kind == kind && (!$0.settled || $0.batch == batch) }) else { throw Failure.limit }
        guard coins >= amount else { throw Failure.funds }
        let project = Project(id: UUID().uuidString, kind: kind, principal: amount, openedAt: now, batch: batch)
        guard customerBudget >= project.fullRepayment else { throw Failure.budget }
        customerBudget -= project.fullRepayment
        projectCustomerEscrow[project.id] = project.fullRepayment
        // Actual funds go into this finite order's production inputs immediately.
        coins -= amount; projectInputs += amount; projects.append(project)
    }
    public mutating func inspectProject(_ id: String, originalSeal: Bool, now: TimeInterval) throws {
        guard let index = projects.firstIndex(where: { $0.id == id }), !projects[index].settled else { throw Failure.stage }
        guard now <= projects[index].deadline else { throw Failure.deadline }
        projects[index].inspected = true
        if !originalSeal { projects[index].damaged = true }
    }
    public mutating func deliverProject(_ id: String, now: TimeInterval) throws {
        guard let index = projects.firstIndex(where: { $0.id == id }), projects[index].inspected, !projects[index].settled else { throw Failure.stage }
        guard now <= projects[index].deadline else { throw Failure.deadline }
        projects[index].delivered = true
    }
    public mutating func invite(privateRoom: Bool, lodgingID: String, completed: Set<Int>, now: TimeInterval, coins: inout Int) throws {
        guard completed.contains(13) else { throw Failure.locked }
        guard meeting == nil || [.paid, .failed, .cancelled].contains(meeting!.stage) else { throw Failure.stage }
        if privateRoom, !["canal_house", "bell_loft", "highland_house"].contains(lodgingID) { throw Failure.locked }
        let customer = "dye_bookkeeper"
        guard now - (lastMeetingAt[customer] ?? -1e20) >= 7 * 86_400 else { throw Failure.limit }
        let fee = privateRoom ? (lodgingID == "highland_house" ? 10 : lodgingID == "bell_loft" ? 6 : 4) : 2
        let inputs = privateRoom ? (lodgingID == "highland_house" ? 50 : 30) : 20
        let payment = privateRoom ? (lodgingID == "highland_house" ? 96 : 60) : 40
        guard coins >= fee else { throw Failure.funds }
        guard customerBudget >= payment else { throw Failure.budget }
        coins -= fee; hostingReceipts += fee
        meeting = .init(id: UUID().uuidString, customer: customer, openedAt: now, privateRoom: privateRoom,
                        lodgingID: lodgingID, fee: fee, inputs: inputs, payment: payment,
                        deliveryStamina: privateRoom ? (lodgingID == "highland_house" ? 25 : 20) : 15)
        lastMeetingAt[customer] = now
    }
    public mutating func verifyMeeting(evidence: Set<String>) throws {
        guard meeting?.stage == .invited else { throw Failure.stage }
        guard evidence == ["delivery_receipt", "original_seal"] else { throw Failure.evidence }
        meeting?.stage = .verified
    }
    public mutating func contract(inspectFirst: Bool, payOnDelivery: Bool, limitedLiability: Bool, now: TimeInterval, coins: inout Int) throws {
        guard let item = meeting, item.stage == .verified else { throw Failure.stage }
        guard now <= item.deadline else { throw Failure.deadline }
        guard inspectFirst, payOnDelivery, limitedLiability else { throw Failure.terms }
        guard coins >= item.inputs else { throw Failure.funds }
        guard customerBudget >= item.payment else { throw Failure.budget }
        coins -= item.inputs; supplierReceipts += item.inputs
        customerBudget -= item.payment; meetingEscrow[item.id] = item.payment
        meeting?.stage = .contracted
    }
    public mutating func collectGoods(now: TimeInterval) throws {
        guard meeting?.stage == .contracted else { throw Failure.stage }
        guard now <= meeting!.deadline else { throw Failure.deadline }
        meeting?.stage = .collected
    }
    public mutating func sealGoods(original: Bool, now: TimeInterval) throws {
        guard meeting?.stage == .collected else { throw Failure.stage }
        guard now <= meeting!.deadline else { throw Failure.deadline }
        guard original else { throw Failure.evidence }
        meeting?.stage = .sealed
    }
    public mutating func deliverGoods(now: TimeInterval) throws {
        guard meeting?.stage == .sealed else { throw Failure.stage }
        guard now <= meeting!.deadline else { throw Failure.deadline }
        meeting?.stage = .delivered; meeting?.deliveredAt = now
    }
    public mutating func cancelMeeting() throws {
        guard let item = meeting, ![.delivered, .paid, .failed, .cancelled].contains(item.stage) else { throw Failure.stage }
        customerBudget += meetingEscrow.removeValue(forKey: item.id) ?? 0
        // Fees already hosted, inputs already purchased: never refunded as minted cash.
        meeting?.stage = .cancelled
        addNotice("会面已结束，已发生的招待与耗材不退款；本周接待次数保留。")
    }
    public mutating func settle(now: TimeInterval, coins: inout Int) {
        if let item = deposit, !item.closed, now >= item.dueAt { try? redeemDeposit(now: now, coins: &coins) }
        if let item = termDeposit, !item.closed, now >= item.dueAt { try? redeemTermDeposit(now: now, coins: &coins) }
        for index in projects.indices where !projects[index].settled {
            let project = projects[index]
            guard (now >= project.dueAt && project.delivered) || now > project.deadline else { continue }
            let escrow = projectCustomerEscrow.removeValue(forKey: project.id) ?? 0
            let payout = project.delivered && !project.damaged ? escrow : 0
            customerBudget += escrow - payout; coins += payout
            projects[index].settled = true; projects[index].repayment = payout; contractPaid += payout
            addNotice(payout > 0 ? "项目已验收，本息\(payout)铜入账。" : "项目未通过验收，投入\(project.principal)铜损失；不追加追索。")
        }
        if let item = meeting {
            if item.stage == .delivered, now >= (item.dueAt ?? .infinity) {
                let payout = meetingEscrow.removeValue(forKey: item.id) ?? 0
                coins += payout; contractPaid += payout; meeting?.stage = .paid
                addNotice("染坊核对收货，\(payout)铜合同款到账。")
            } else if ![.delivered, .paid, .failed, .cancelled].contains(item.stage), now > item.deadline {
                customerBudget += meetingEscrow.removeValue(forKey: item.id) ?? 0
                meeting?.stage = .failed; addNotice("交货期限已过，合同关闭；已发生的招待与耗材不退。")
            }
        }
    }
    public static func restBP(lodgingID: String) -> Int {
        lodgingID == "canal_house" ? 300 : ["bell_loft", "highland_house"].contains(lodgingID) ? 500 : 0
    }
    public mutating func prepareRest(day: Int, lodgingID: String) throws {
        let bonus = Self.restBP(lodgingID: lodgingID)
        guard bonus > 0 else { throw Failure.locked }
        guard restDay != day else { throw Failure.limit }
        restDay = day; armedRestDay = day; armedRestBP = bonus
    }
    public var hasArmedRest: Bool { armedRestBP > 0 }
    public func restBonus(day: Int) -> Int { armedRestDay == day ? armedRestBP : 0 }
    public mutating func consumeRest(battleID: String, day: Int) -> Int {
        if let prior = battleRest[battleID] { return prior }
        let bonus = restBonus(day: day)
        armedRestBP = 0; armedRestDay = nil
        battleRest[battleID] = bonus
        if battleRest.count > 100 { battleRest = [battleID: bonus] }
        return bonus
    }
    public mutating func maintenanceCredit(day: Int, lodgingID: String, fee: Int) -> Int {
        let cap = lodgingID == "canal_house" ? 1 : lodgingID == "bell_loft" ? 2 : lodgingID == "highland_house" ? 3 : 0
        let discount = min(cap, max(0, fee) / 2)
        guard discount > 0, !maintenanceDays.contains(day) else { return 0 }
        maintenanceDays.insert(day); maintenanceDays = maintenanceDays.filter { $0 >= day - 30 }
        return discount
    }
    private mutating func addNotice(_ value: String) { notices.append(value); notices = Array(notices.suffix(12)) }
}
