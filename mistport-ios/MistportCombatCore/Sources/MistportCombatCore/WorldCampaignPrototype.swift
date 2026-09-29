import Foundation

/// Isolated, in-memory campaign rules. Not connected to GameStore, live saves,
/// money issuance or a network service. Only a trusted host may provide sessions;
/// matching an encounter ID is not server-side replay verification.
public struct MPCWorldCampaignPrototype: Codable, Equatable, Sendable {
    public enum Faction: String, Codable, CaseIterable, Sendable {
        case pumps, shipping
        public var opponent: Self { self == .pumps ? .shipping : .pumps }
    }
    public enum Route: String, Codable, Sendable { case perimeter, core }
    public enum Failure: Error, Equatable { case invalid, closed, funds, stock, locked, conflict, expired, unverified }
    public enum NewsKind: String, Codable, Sendable {
        case opened, invested, procurement, exposed, death, successor, settlement
    }
    public struct Definition: Codable, Equatable, Sendable {
        public let id: String
        public let actionStart: Int
        public let actionEnd: Int
        public let grace: Int
        public let ticketLifetime: Int
        public let supplyTarget: Int
        public let perimeterWins: Int
        public let supplyPrice: Int
        public let seedPerFaction: Int
        public init(id: String, actionStart: Int = 700, actionEnd: Int = 1000,
                    grace: Int = 20, ticketLifetime: Int = 100, supplyTarget: Int = 3,
                    perimeterWins: Int = 2, supplyPrice: Int = 16, seedPerFaction: Int = 100) {
            self.id = id; self.actionStart = actionStart; self.actionEnd = actionEnd
            self.grace = grace; self.ticketLifetime = ticketLifetime; self.supplyTarget = supplyTarget
            self.perimeterWins = perimeterWins; self.supplyPrice = supplyPrice; self.seedPerFaction = seedPerFaction
        }
    }
    public struct Account: Codable, Equatable, Sendable {
        public fileprivate(set) var copper: Int
        public fileprivate(set) var tradeableKits: Int
        public let boundMedicine: Int
        public init(copper: Int, tradeableKits: Int = 0, boundMedicine: Int = 0) {
            self.copper = copper; self.tradeableKits = tradeableKits; self.boundMedicine = boundMedicine
        }
    }
    public struct Project: Codable, Equatable, Sendable {
        public fileprivate(set) var cash: Int = 0
        public fileprivate(set) var purchased = 0
        public fileprivate(set) var stock = 0
        public fileprivate(set) var consumedForBreach = 0
        public fileprivate(set) var perimeterVictories = 0
        public fileprivate(set) var exposed = false
        public fileprivate(set) var npcDead = false
        public fileprivate(set) var successorRequired = false
        public fileprivate(set) var investments: [String: Int] = [:]
    }
    public struct Ticket: Codable, Equatable, Sendable {
        public let id: String
        public let accountID: String
        public let faction: Faction
        public let route: Route
        public let encounterID: String
        public let issuedAt: Int
        public let expiresAt: Int
        public let issuedWorldVersion: Int
    }
    public struct Battle: Sendable {
        public let ticket: Ticket
        public var session: MPCChapterOneEncounterSession
        fileprivate init(ticket: Ticket, session: MPCChapterOneEncounterSession) {
            self.ticket = ticket; self.session = session
        }
    }
    public struct BattleReceipt: Codable, Equatable, Sendable {
        public let ticketID: String
        public let outcome: MPCEncounterOutcome
        public let changedWorld: Bool
    }
    public struct News: Codable, Equatable, Sendable {
        public let id: String
        public let kind: NewsKind
        public let faction: Faction?
        public let worldVersion: Int
        public let at: Int
        public let fact: String
    }
    public struct Settlement: Codable, Equatable, Sendable {
        public let winner: Faction?
        public let refunds: [String: Int]
        public let treasuryReturned: Int
        /// Unsold/unused project assets survive settlement; not duplicated refunds.
        public let retainedKits: [Faction: Int]
    }
    private struct Command: Codable, Equatable, Sendable {
        let kind: String
        let account: String
        let faction: Faction
        let quantity: Int
    }
    public let definition: Definition
    public let openingMoney: Int
    public let openingKits: Int
    public private(set) var treasury: Int
    public private(set) var accounts: [String: Account]
    public private(set) var affiliations: [String: Faction] = [:]
    public private(set) var projects: [Faction: Project]
    public private(set) var worldVersion = 0
    public private(set) var clock = 0
    public private(set) var tickets: [String: Ticket] = [:]
    public private(set) var receipts: [String: BattleReceipt] = [:]
    public private(set) var news: [News] = []
    public private(set) var settlement: Settlement?
    private var commands: [String: Command] = [:]

    public init(definition d: Definition, accounts: [String: Account], treasury: Int) throws {
        guard !d.id.isEmpty, (1...1_000_000).contains(d.actionStart),
              d.actionEnd > d.actionStart, d.actionEnd <= 2_000_000,
              (0...10_000).contains(d.grace), (1...10_000).contains(d.ticketLifetime),
              (1...100_000).contains(d.supplyTarget), (1...100_000).contains(d.perimeterWins),
              (1...10_000).contains(d.supplyPrice), (0...1_000_000).contains(d.seedPerFaction),
              (0...1_000_000_000).contains(treasury), treasury >= 2 * d.seedPerFaction,
              accounts.count <= 10_000,
              accounts.allSatisfy({ !$0.key.isEmpty && (0...1_000_000).contains($0.value.copper)
                  && (0...100_000).contains($0.value.tradeableKits)
                  && (0...100_000).contains($0.value.boundMedicine) }) else { throw Failure.invalid }
        // Bound this small prototype's integer products during pro-rata refunds.
        guard treasury + accounts.values.reduce(0, { $0 + $1.copper }) <= 100_000_000 else { throw Failure.invalid }
        definition = d; self.accounts = accounts; self.treasury = treasury - 2 * d.seedPerFaction
        openingMoney = treasury + accounts.values.reduce(0) { $0 + $1.copper }
        openingKits = accounts.values.reduce(0) { $0 + $1.tradeableKits }
        projects = Dictionary(uniqueKeysWithValues: Faction.allCases.map { ($0, Project(cash: d.seedPerFaction)) })
        publish(.opened, faction: nil, key: "opened", fact: "准备期开放；双方采购预算已由财政转入。")
    }
    public var money: Int { treasury + accounts.values.reduce(0) { $0 + $1.copper } + projects.values.reduce(0) { $0 + $1.cash } }
    public var accountedKits: Int { accounts.values.reduce(0) { $0 + $1.tradeableKits } + projects.values.reduce(0) { $0 + $1.stock + $1.consumedForBreach } }
    private func validateTime(_ now: Int) throws {
        guard now >= clock, now <= 3_000_000 else { throw Failure.invalid }
        guard settlement == nil else { throw Failure.closed }
    }
    private mutating func publish(_ kind: NewsKind, faction: Faction?, key: String, fact: String) {
        let id = definition.id + ":" + key
        guard !news.contains(where: { $0.id == id }) else { return }
        news.append(.init(id: id, kind: kind, faction: faction, worldVersion: worldVersion, at: clock, fact: fact))
    }
    private func repeated(_ id: String, command: Command) throws -> Bool {
        guard !id.isEmpty else { throw Failure.invalid }
        guard let old = commands[id] else { return false }
        guard old == command else { throw Failure.conflict }
        return true
    }
    /// Joining requires no money. The prototype freezes affiliation for this event.
    public mutating func join(accountID: String, faction: Faction, now: Int) throws {
        try validateTime(now)
        guard accounts[accountID] != nil, now < definition.actionStart else { throw Failure.closed }
        if let old = affiliations[accountID] { guard old == faction else { throw Failure.conflict }; return }
        affiliations[accountID] = faction; clock = now; worldVersion += 1
    }
    @discardableResult public mutating func invest(id: String, accountID: String, faction: Faction, amount: Int, now: Int) throws -> Bool {
        let command = Command(kind: "invest", account: accountID, faction: faction, quantity: amount)
        if try repeated(id, command: command) { return false }
        try validateTime(now)
        guard now < definition.actionStart, (1...1_000_000).contains(amount),
              let account = accounts[accountID] else { throw Failure.invalid }
        guard affiliations[accountID] == nil || affiliations[accountID] == faction else { throw Failure.conflict }
        guard account.copper >= amount else { throw Failure.funds }
        accounts[accountID]!.copper -= amount; projects[faction]!.cash += amount
        projects[faction]!.investments[accountID, default: 0] += amount
        affiliations[accountID] = faction; commands[id] = command; clock = now; worldVersion += 1
        publish(.invested, faction: faction, key: "invest:" + id, fact: "已收到投资 \(amount) 铜；这是项目转账，不是发行。")
        return true
    }
    /// Candidate construction kits only. Bound medicine cannot satisfy this inventory.
    @discardableResult public mutating func sellKits(id: String, seller: String, faction: Faction, quantity: Int, now: Int) throws -> Bool {
        let command = Command(kind: "sell", account: seller, faction: faction, quantity: quantity)
        if try repeated(id, command: command) { return false }
        try validateTime(now)
        guard now < definition.actionEnd, quantity > 0, quantity <= definition.supplyTarget,
              let account = accounts[seller], let project = projects[faction],
              !project.npcDead, project.purchased + quantity <= definition.supplyTarget else { throw Failure.closed }
        guard account.tradeableKits >= quantity else { throw Failure.stock }
        let payment = quantity * definition.supplyPrice
        guard project.cash >= payment else { throw Failure.funds }
        accounts[seller]!.tradeableKits -= quantity; accounts[seller]!.copper += payment
        projects[faction]!.cash -= payment; projects[faction]!.stock += quantity
        projects[faction]!.purchased += quantity
        commands[id] = command; clock = now; worldVersion += 1
        publish(.procurement, faction: faction, key: "sale:" + id, fact: "工程物料 \(quantity) 份已验收，已支付 \(payment) 铜。")
        exposeIfReady(faction)
        return true
    }
    private mutating func exposeIfReady(_ attacker: Faction) {
        guard clock >= definition.actionStart, clock < definition.actionEnd,
              let p = projects[attacker], p.perimeterVictories >= definition.perimeterWins,
              p.stock >= definition.supplyTarget, !projects[attacker.opponent]!.exposed,
              !projects[attacker.opponent]!.npcDead else { return }
        projects[attacker]!.stock -= definition.supplyTarget
        projects[attacker]!.consumedForBreach += definition.supplyTarget
        projects[attacker.opponent]!.exposed = true
        publish(.exposed, faction: attacker.opponent, key: "exposed:" + attacker.opponent.rawValue,
                fact: "外围突破，已使用工程物料建立通道；核心挑战开放。")
    }
    /// Existing encounters are mechanical fixtures, NOT the new NPC's canon identity.
    public static func encounter(faction: Faction, route: Route) -> String {
        route == .perimeter ? "church_bounty_b01" : faction == .pumps ? "church_bounty_b03" : "church_bounty_b06"
    }
    private mutating func issueTicket(accountID: String, route: Route, now: Int) throws -> Ticket {
        try validateTime(now)
        guard now >= definition.actionStart, now < definition.actionEnd,
              let faction = affiliations[accountID] else { throw Failure.closed }
        guard !tickets.values.contains(where: { $0.accountID == accountID && receipts[$0.id] == nil
            && now <= $0.expiresAt + definition.grace }) else { throw Failure.conflict }
        if route == .core {
            guard projects[faction.opponent]!.exposed, !projects[faction.opponent]!.npcDead else { throw Failure.locked }
        }
        clock = now; worldVersion += 1
        let ticket = Ticket(id: definition.id + ":battle:\(tickets.count + 1)", accountID: accountID,
                            faction: faction, route: route, encounterID: Self.encounter(faction: faction, route: route),
                            issuedAt: now, expiresAt: min(now + definition.ticketLifetime, definition.actionEnd), issuedWorldVersion: worldVersion)
        tickets[ticket.id] = ticket
        return ticket
    }
    /// Binds a runtime to an immutable issued ticket. A failed start commits nothing.
    public mutating func beginBattle(accountID: String, route: Route, loadout: MPCChapterOneLoadout, now: Int) throws -> Battle {
        var next = self
        let ticket = try next.issueTicket(accountID: accountID, route: route, now: now)
        let session = try MPCChapterOneEncounterSession.start(encounterID: ticket.encounterID, companionIDs: [], loadout: loadout)
        self = next
        return Battle(ticket: ticket, session: session)
    }
    /// Trusted local runtime only. Network clients must never submit this object.
    /// No reward minting: repeats return the same receipt; a different result conflicts.
    public mutating func settleBattle(_ battle: Battle, now: Int) throws -> BattleReceipt {
        let ticketID = battle.ticket.id, session = battle.session
        guard let ticket = tickets[ticketID], ticket == battle.ticket,
              ticket.encounterID == session.encounter.id, session.outcome != .inProgress else { throw Failure.unverified }
        if let receipt = receipts[ticketID] {
            guard receipt.outcome == session.outcome else { throw Failure.conflict }
            return receipt
        }
        try validateTime(now)
        guard now >= ticket.issuedAt, now <= ticket.expiresAt + definition.grace else { throw Failure.expired }
        clock = now; worldVersion += 1
        var changed = false
        if session.outcome == .victory {
            if ticket.route == .perimeter, now < definition.actionEnd {
                projects[ticket.faction]!.perimeterVictories += 1
                exposeIfReady(ticket.faction)
                changed = true
            } else if ticket.route == .core, !projects[ticket.faction.opponent]!.npcDead {
                let target = ticket.faction.opponent
                projects[target]!.npcDead = true; projects[target]!.successorRequired = true
                changed = true
                publish(.death, faction: target, key: "death:" + target.rawValue, fact: "关键NPC死亡已确认；项目等待继任与结算。")
                publish(.successor, faction: target, key: "successor:" + target.rawValue, fact: "启动接管；未花资金与物资仍在项目账内。")
            }
        }
        let receipt = BattleReceipt(ticketID: ticketID, outcome: session.outcome, changedWorld: changed)
        receipts[ticketID] = receipt
        return receipt
    }
    /// Waits for all ticket grace windows before freezing the exclusive contract.
    /// No business revenue or dividend is invented; only unspent capital returns.
    public mutating func finish(now: Int) throws -> Settlement {
        if let settlement { return settlement }
        try validateTime(now)
        guard now > definition.actionEnd + definition.grace else { throw Failure.closed }
        let alive = Faction.allCases.filter { !projects[$0]!.npcDead }
        let winner = alive.count == 1 && projects[alive[0].opponent]!.npcDead ? alive[0] : nil
        var refunds: [String: Int] = [:], returned = 0
        for faction in Faction.allCases {
            let project = projects[faction]!
            let capital = definition.seedPerFaction + project.investments.values.reduce(0, +)
            var allocated = 0
            for accountID in project.investments.keys.sorted() {
                let value = capital == 0 ? 0 : project.cash * project.investments[accountID]! / capital
                refunds[accountID, default: 0] += value; accounts[accountID]!.copper += value
                allocated += value
            }
            let remainder = project.cash - allocated
            treasury += remainder; returned += remainder; projects[faction]!.cash = 0
        }
        clock = now; worldVersion += 1
        let result = Settlement(winner: winner, refunds: refunds, treasuryReturned: returned,
                                retainedKits: projects.mapValues(\.stock))
        settlement = result
        publish(.settlement, faction: winner, key: "settlement", fact: winner == nil ? "无独占合同赢家，进入重组；余款已结算。" : "独占合同已结算；仅退未花本金，不自动生成分红。")
        return result
    }
}
