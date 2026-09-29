import Crypto
import Foundation
import MistportCombatCore

/// The authoritative account and asset ledger of the shared server (M0 sample).
///
/// - Copper: every change is one journal row. `issue` creates money from a named source,
///   `burn` destroys it, `transfer` moves it between accounts (players, the city budget,
///   ticket escrow). Money supply therefore always equals issued minus burned.
/// - Items: every unit belongs to a lot that records where it came from (tower drop,
///   test grant). Moving items keeps their lot, so provenance survives trades.
/// - Operations: every mutating call carries a client operation ID. The same ID with the
///   same payload returns the stored answer (including a stored failure); the same ID with
///   a different payload is refused. One call is one SQLite transaction.
/// - Battles: a ticket reserves the reward and the consumables before the battle; the
///   settlement replays the client's inputs with `MPCChurchBattleDriver` on the server's
///   own character and pays only a verified win, once.
public final class Ledger: @unchecked Sendable {
    public static let cityBudget = "sys:city-budget"
    public let policy: LedgerPolicy
    private let db: Database
    private let lock = NSLock()
    private let clock: @Sendable () -> Int64

    public init(path: String, policy: LedgerPolicy = .init(),
                clock: @escaping @Sendable () -> Int64 = { Int64(Date().timeIntervalSince1970) }) throws {
        self.policy = policy
        self.clock = clock
        db = try Database(path: path)
        try locked { try migrate() }
    }

    // MARK: Schema

    private func migrate() throws {
        try db.transaction {
            try db.execute("""
            CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS accounts(
                id TEXT PRIMARY KEY, kind TEXT NOT NULL, token_hash TEXT UNIQUE,
                cash INTEGER NOT NULL DEFAULT 0 CHECK(cash >= 0), created_at INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS characters(
                account TEXT PRIMARY KEY REFERENCES accounts(id), floor INTEGER NOT NULL, max_floor INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS money_journal(
                seq INTEGER PRIMARY KEY AUTOINCREMENT, op TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('issue','transfer','burn')),
                source TEXT, from_account TEXT, to_account TEXT, amount INTEGER NOT NULL CHECK(amount > 0), at INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS lots(
                seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT UNIQUE NOT NULL, item TEXT NOT NULL, origin TEXT NOT NULL,
                origin_ref TEXT, created_op TEXT NOT NULL, quantity INTEGER NOT NULL CHECK(quantity > 0), at INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS holdings(
                owner TEXT NOT NULL, lot TEXT NOT NULL REFERENCES lots(id), quantity INTEGER NOT NULL CHECK(quantity >= 0),
                PRIMARY KEY(owner, lot));
            CREATE TABLE IF NOT EXISTS item_journal(
                seq INTEGER PRIMARY KEY AUTOINCREMENT, op TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('create','move','consume')),
                lot TEXT NOT NULL, from_owner TEXT, to_owner TEXT, quantity INTEGER NOT NULL CHECK(quantity > 0), at INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS listings(
                id TEXT PRIMARY KEY, seller TEXT NOT NULL, item TEXT NOT NULL, unit_price INTEGER NOT NULL,
                quantity INTEGER NOT NULL, remaining INTEGER NOT NULL CHECK(remaining >= 0), status TEXT NOT NULL,
                version INTEGER NOT NULL, created_at INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS operations(
                account TEXT NOT NULL, op_id TEXT NOT NULL, name TEXT NOT NULL, payload_hash TEXT NOT NULL,
                result TEXT NOT NULL, at INTEGER NOT NULL, PRIMARY KEY(account, op_id));
            CREATE TABLE IF NOT EXISTS tickets(
                id TEXT PRIMARY KEY, account TEXT NOT NULL, kind TEXT NOT NULL, floor INTEGER, side TEXT,
                encounter TEXT NOT NULL, reward INTEGER NOT NULL, character_floor INTEGER NOT NULL, consumables TEXT NOT NULL,
                status TEXT NOT NULL, created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL, result TEXT);
            CREATE TABLE IF NOT EXISTS imports(
                account TEXT PRIMARY KEY, fingerprint TEXT UNIQUE NOT NULL, requested INTEGER NOT NULL, granted INTEGER NOT NULL, at INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS lights_attempts(account TEXT PRIMARY KEY, side TEXT NOT NULL, ticket TEXT NOT NULL, won INTEGER NOT NULL);
            CREATE TABLE IF NOT EXISTS public_scores(event TEXT NOT NULL, side TEXT NOT NULL, points INTEGER NOT NULL, PRIMARY KEY(event, side));
            """)
            if try db.query("SELECT value FROM meta WHERE key = 'genesis'").isEmpty {
                let op = "genesis"
                try ensureAccount(Self.cityBudget, kind: "system")
                if policy.cityBudgetGenesis > 0 {
                    try issue(op: op, to: Self.cityBudget, amount: policy.cityBudgetGenesis, source: "genesis:city-budget")
                }
                try db.run("INSERT INTO meta(key, value) VALUES('genesis', ?)", [.text(String(clock()))])
                try db.run("INSERT INTO meta(key, value) VALUES('schema', '1')")
            }
        }
    }

    // MARK: Accounts

    public func createPlayer() throws -> AccountCreated {
        try locked {
            try db.transaction {
                let id = "p-" + Self.randomHex(8)
                let token = Self.randomHex(32)
                try db.run("INSERT INTO accounts(id, kind, token_hash, cash, created_at) VALUES(?, 'player', ?, 0, ?)",
                           [.text(id), .text(Self.sha256(token)), .int(clock())])
                try db.run("INSERT INTO characters(account, floor, max_floor) VALUES(?, 1, 0)", [.text(id)])
                return AccountCreated(accountID: id, token: token)
            }
        }
    }

    /// The account for a bearer token, or nil.
    public func authenticate(token: String) throws -> String? {
        guard !token.isEmpty, token.count <= 128 else { return nil }
        return try locked {
            try db.query("SELECT id FROM accounts WHERE token_hash = ? AND kind = 'player'", [.text(Self.sha256(token))]).first?.text("id")
        }
    }

    public func account(_ id: String) throws -> AccountView {
        try locked {
            guard let row = try db.query("SELECT a.cash, c.floor, c.max_floor FROM accounts a JOIN characters c ON c.account = a.id WHERE a.id = ?", [.text(id)]).first else {
                throw LedgerError.notFound
            }
            return AccountView(accountID: id, cash: row.int("cash"), items: try itemsOwned(by: id),
                               characterFloor: Int(row.int("floor")), maxFloor: Int(row.int("max_floor")))
        }
    }

    public func cash(_ id: String) throws -> Int64 {
        try locked { try db.query("SELECT cash FROM accounts WHERE id = ?", [.text(id)]).first?.int("cash") ?? 0 }
    }

    /// Test and operator tool: sets which tower-floor loadout the server character uses.
    /// The shared character progression is not built yet; this is not a player action.
    /// `maxFloor` defaults to the floor below, so that floor can be fought.
    public func setCharacter(account: String, floor: Int, maxFloor: Int? = nil) throws {
        let floors = MPCChurchTowerCatalog.floors.count
        let cleared = maxFloor ?? floor - 1
        guard (1...floors).contains(floor), (0..<floors).contains(cleared) else { throw LedgerError.invalidRequest }
        try locked {
            try db.transaction {
                guard try db.run("UPDATE characters SET floor = ?, max_floor = ? WHERE account = ?",
                                 [.int(Int64(floor)), .int(Int64(cleared)), .text(account)]) == 1 else { throw LedgerError.notFound }
            }
        }
    }

    /// Test and operator tool: creates items with origin `test-grant` (labelled in provenance).
    public func grantTestItems(account: String, item: String, quantity: Int64) throws -> LotMove {
        guard LedgerCatalog.isKnown(item) else { throw LedgerError.unknownItem }
        guard (1...policy.maxQuantity).contains(quantity) else { throw LedgerError.invalidRequest }
        return try locked {
            try db.transaction {
                guard try db.query("SELECT 1 FROM accounts WHERE id = ? AND kind = 'player'", [.text(account)]).first != nil else { throw LedgerError.notFound }
                let op = "test-grant-" + Self.randomHex(6)
                let lot = try createLot(op: op, item: item, quantity: quantity, owner: account, origin: "test-grant", ref: nil)
                return LotMove(lot: lot, quantity: quantity)
            }
        }
    }

    // MARK: Local wealth import (user decision 2026-09-29: local copper goes to the shared server)

    public func importLocal(account: String, op: String, fingerprint: String, copper: Int64) throws -> ImportReceipt {
        struct Payload: Encodable { let fingerprint: String; let copper: Int64 }
        guard (8...128).contains(fingerprint.count), copper >= 0 else { throw LedgerError.invalidRequest }
        return try operation("import-local", account: account, op: op, payload: Payload(fingerprint: fingerprint, copper: copper)) {
            guard try db.query("SELECT 1 FROM imports WHERE account = ?", [.text(account)]).isEmpty else { throw LedgerError.alreadyImported }
            guard try db.query("SELECT 1 FROM imports WHERE fingerprint = ?", [.text(fingerprint)]).isEmpty else { throw LedgerError.fingerprintUsed }
            let granted = min(copper, policy.localImportCap)
            if granted > 0 { try issue(op: op, to: account, amount: granted, source: "local-import") }
            try db.run("INSERT INTO imports(account, fingerprint, requested, granted, at) VALUES(?, ?, ?, ?, ?)",
                       [.text(account), .text(fingerprint), .int(copper), .int(granted), .int(clock())])
            return ImportReceipt(accountID: account, requested: copper, granted: granted, fingerprint: fingerprint)
        }
    }

    // MARK: Market

    public func list(account: String, op: String, item: String, quantity: Int64, unitPrice: Int64) throws -> ListingReceipt {
        struct Payload: Encodable { let item: String; let quantity: Int64; let unitPrice: Int64 }
        guard LedgerCatalog.isKnown(item) else { throw LedgerError.unknownItem }
        guard (1...policy.maxQuantity).contains(quantity), (1...policy.maxUnitPrice).contains(unitPrice) else { throw LedgerError.invalidRequest }
        return try operation("list", account: account, op: op, payload: Payload(item: item, quantity: quantity, unitPrice: unitPrice)) {
            let id = "l-" + Self.randomHex(8)
            let lots = try moveItems(op: op, item: item, quantity: quantity, from: account, to: "listing:" + id)
            try db.run("INSERT INTO listings(id, seller, item, unit_price, quantity, remaining, status, version, created_at) VALUES(?, ?, ?, ?, ?, ?, 'open', 1, ?)",
                       [.text(id), .text(account), .text(item), .int(unitPrice), .int(quantity), .int(quantity), .int(clock())])
            return ListingReceipt(listingID: id, item: item, quantity: quantity, unitPrice: unitPrice, lots: lots)
        }
    }

    /// Buys `quantity` from an open listing. Copper and goods change hands in one
    /// transaction; when several buyers race for the last unit only one succeeds.
    public func buy(account: String, op: String, listingID: String, quantity: Int64) throws -> TradeReceipt {
        struct Payload: Encodable { let listingID: String; let quantity: Int64 }
        guard (1...policy.maxQuantity).contains(quantity) else { throw LedgerError.invalidRequest }
        return try operation("buy", account: account, op: op, payload: Payload(listingID: listingID, quantity: quantity)) {
            guard let listing = try db.query("SELECT * FROM listings WHERE id = ?", [.text(listingID)]).first else { throw LedgerError.notFound }
            guard listing.string("status") == "open" else { throw LedgerError.listingClosed }
            let seller = listing.string("seller")
            guard seller != account else { throw LedgerError.ownListing }
            guard listing.int("remaining") >= quantity else { throw LedgerError.soldOut }
            let price = listing.int("unit_price")
            let (gross, overflow) = price.multipliedReportingOverflow(by: quantity)
            guard !overflow else { throw LedgerError.invalidRequest }
            let fee = gross * policy.feeBasisPoints / 10_000
            try move(op: op, from: account, to: seller, amount: gross - fee)
            if fee > 0 {
                switch policy.feeDestination {
                case .cityBudget: try move(op: op, from: account, to: Self.cityBudget, amount: fee)
                case .burn: try burn(op: op, from: account, amount: fee, reason: "trade-fee")
                }
            }
            let lots = try moveItems(op: op, item: listing.string("item"), quantity: quantity, from: "listing:" + listingID, to: account)
            let remaining = listing.int("remaining") - quantity
            try db.run("UPDATE listings SET remaining = ?, version = version + 1, status = ? WHERE id = ?",
                       [.int(remaining), .text(remaining == 0 ? "sold" : "open"), .text(listingID)])
            return TradeReceipt(listingID: listingID, buyer: account, seller: seller, item: listing.string("item"), quantity: quantity,
                                unitPrice: price, gross: gross, fee: fee, sellerNet: gross - fee, lots: lots, remaining: remaining)
        }
    }

    public func cancel(account: String, op: String, listingID: String) throws -> CancelReceipt {
        struct Payload: Encodable { let listingID: String }
        return try operation("cancel", account: account, op: op, payload: Payload(listingID: listingID)) {
            guard let listing = try db.query("SELECT * FROM listings WHERE id = ?", [.text(listingID)]).first else { throw LedgerError.notFound }
            guard listing.string("seller") == account else { throw LedgerError.notSeller }
            guard listing.string("status") == "open" else { throw LedgerError.listingClosed }
            let remaining = listing.int("remaining")
            if remaining > 0 { _ = try moveItems(op: op, item: listing.string("item"), quantity: remaining, from: "listing:" + listingID, to: account) }
            try db.run("UPDATE listings SET remaining = 0, version = version + 1, status = 'cancelled' WHERE id = ?", [.text(listingID)])
            return CancelReceipt(listingID: listingID, returned: remaining)
        }
    }

    public func openListings(item: String? = nil) throws -> [ListingView] {
        try locked {
            let rows = try item.map { try db.query("SELECT * FROM listings WHERE status = 'open' AND item = ? ORDER BY unit_price, created_at", [.text($0)]) }
                ?? db.query("SELECT * FROM listings WHERE status = 'open' ORDER BY item, unit_price, created_at")
            return rows.map { ListingView(listingID: $0.string("id"), seller: $0.string("seller"), item: $0.string("item"), unitPrice: $0.int("unit_price"),
                                          remaining: $0.int("remaining"), status: $0.string("status"), version: $0.int("version")) }
        }
    }

    // MARK: Battles

    /// Before a battle: checks eligibility, reserves the reward from the city budget and
    /// moves the consumables the player brings into the ticket, so the reward cannot be
    /// short after a win and the items cannot be sold mid-battle.
    public func openTicket(account: String, op: String, request: BattleRequest) throws -> TicketReceipt {
        try expireTickets()
        return try operation("open-ticket", account: account, op: op, payload: request) {
            guard let character = try db.query("SELECT floor, max_floor FROM characters WHERE account = ?", [.text(account)]).first else { throw LedgerError.notFound }
            let id = "t-" + Self.randomHex(8)
            let encounter: String
            var reward: Int64 = 0
            switch request.kind {
            case .tower:
                guard let number = request.floor, let floor = MPCChurchTowerCatalog.floor(number: number) else { throw LedgerError.invalidRequest }
                guard number <= Int(character.int("max_floor")) + 1 else { throw LedgerError.notEligible }
                encounter = floor.id
            case .lightsPublic:
                guard let raw = request.side, let side = MPCLightsPublicTarget.Faction(rawValue: raw) else { throw LedgerError.invalidRequest }
                guard try db.query("SELECT 1 FROM lights_attempts WHERE account = ?", [.text(account)]).isEmpty else { throw LedgerError.alreadyAttempted }
                encounter = MPCLightsPublicTarget.encounterID(side: side, ticket: id)
                reward = policy.lightsPublicReward
                try db.run("INSERT INTO lights_attempts(account, side, ticket, won) VALUES(?, ?, ?, 0)", [.text(account), .text(raw), .text(id)])
            }
            let escrow = "ticket:" + id
            try ensureAccount(escrow, kind: "escrow")
            if reward > 0 {
                do { try move(op: op, from: Self.cityBudget, to: escrow, amount: reward) }
                catch LedgerError.insufficientFunds { throw LedgerError.budgetExhausted }
            }
            for (item, count) in request.consumables.sorted(by: { $0.key < $1.key }) {
                guard LedgerCatalog.consumables.contains(item) else { throw LedgerError.unknownItem }
                guard (1...99).contains(count) else { throw LedgerError.invalidRequest }
                _ = try moveItems(op: op, item: item, quantity: count, from: account, to: escrow)
            }
            let expires = clock() + policy.ticketLifetimeSeconds
            try db.run("""
                INSERT INTO tickets(id, account, kind, floor, side, encounter, reward, character_floor, consumables, status, created_at, expires_at)
                VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, 'open', ?, ?)
                """, [.text(id), .text(account), .text(request.kind.rawValue), request.floor.map { .int(Int64($0)) } ?? .null,
                      request.side.map(Database.Value.text) ?? .null, .text(encounter), .int(reward), .int(character.int("floor")),
                      .text(try Self.json(request.consumables)), .int(clock()), .int(expires)])
            return TicketReceipt(ticketID: id, encounterID: encounter, ruleVersion: MPCBattleInputLog.currentVersion, reward: reward,
                                 expiresAt: expires, characterFloor: Int(character.int("floor")), consumables: request.consumables)
        }
    }

    /// After a battle: replays the client's inputs on the server's character. A verified
    /// win pays the reserved reward (and tower drops) once; a loss returns the reward to
    /// the city budget; an illegal log is rejected. Used consumables are consumed.
    public func settle(account: String, op: String, ticketID: String, log: MPCBattleInputLog) throws -> SettlementReceipt {
        struct Payload: Encodable { let ticketID: String; let log: MPCBattleInputLog }
        let payload = Payload(ticketID: ticketID, log: log)
        guard Self.validOperationID(op) else { throw LedgerError.invalidRequest }
        // A retry of a finished settlement answers from the stored receipt without replaying.
        if let stored: SettlementReceipt = try locked({ try storedAnswer("settle", account: account, op: op, payload: payload) }) { return stored }
        try expireTickets()

        // The replay is pure and can take tens of milliseconds, so it runs outside the lock;
        // the transaction below checks again that the ticket is still open.
        let ticket = try locked { try db.query("SELECT * FROM tickets WHERE id = ? AND account = ?", [.text(ticketID), .text(account)]).first }
        var verdict: Result<MPCChurchBattleDriver.Result, MPCChurchBattleDriver.Failure>?
        if let ticket, ticket.string("status") == "open", log.encounterID == ticket.string("encounter") {
            let brought = try Self.decode([String: Int64].self, ticket.string("consumables")).mapValues(Int.init)
            do { verdict = .success(try MPCChurchBattleDriver.replay(log, loadout: LedgerCatalog.loadout(floor: Int(ticket.int("character_floor"))), consumables: brought)) }
            catch let failure as MPCChurchBattleDriver.Failure { verdict = .failure(failure) }
        }

        return try operation("settle", account: account, op: op, payload: payload) {
            guard let ticket = try db.query("SELECT * FROM tickets WHERE id = ? AND account = ?", [.text(ticketID), .text(account)]).first else { throw LedgerError.notFound }
            switch ticket.string("status") {
            case "open": break
            case "expired": throw LedgerError.ticketExpired
            default: throw LedgerError.ticketClosed
            }
            guard log.encounterID == ticket.string("encounter"), let verdict else { throw LedgerError.encounterMismatch }
            let escrow = "ticket:" + ticketID
            let reward = ticket.int("reward")
            let brought = try Self.decode([String: Int64].self, ticket.string("consumables"))
            var used: [String: Int64] = [:]
            let status: SettlementReceipt.Status
            var reason: String?
            var seconds = 0.0, hp = 0
            switch verdict {
            case .success(let result):
                status = result.outcome == .victory ? .won : .lost
                seconds = result.seconds; hp = result.playerHP
                used = result.consumablesUsed.mapValues(Int64.init)
            case .failure(let failure):
                status = .rejected
                reason = String(describing: failure)
            }
            for (item, count) in used.sorted(by: { $0.key < $1.key }) where count > 0 {
                _ = try consumeItems(op: op, item: item, quantity: min(count, brought[item, default: 0]), from: escrow, reason: "battle:" + ticketID)
            }
            var returned: [String: Int64] = [:]
            for (item, count) in brought.sorted(by: { $0.key < $1.key }) {
                let left = count - min(used[item, default: 0], count)
                if left > 0 { _ = try moveItems(op: op, item: item, quantity: left, from: escrow, to: account); returned[item] = left }
            }
            var paid: Int64 = 0, released: Int64 = 0
            var drops: [String: Int64] = [:]
            var points: Int64 = 0
            if status == .won {
                if reward > 0 { try move(op: op, from: escrow, to: account, amount: reward); paid = reward }
                if ticket.string("kind") == BattleRequest.Kind.tower.rawValue {
                    let floor = Int(ticket.int("floor"))
                    for (item, count) in MPCTowerMaterials.drops(floor: floor).sorted(by: { $0.key < $1.key }) {
                        _ = try createLot(op: op, item: item, quantity: Int64(count), owner: account, origin: "tower-drop", ref: ticketID)
                        drops[item] = Int64(count)
                    }
                    try db.run("UPDATE characters SET max_floor = MAX(max_floor, ?) WHERE account = ?", [.int(Int64(floor)), .text(account)])
                } else {
                    let side = ticket.string("side")
                    try db.run("INSERT INTO public_scores(event, side, points) VALUES('lights', ?, 1) ON CONFLICT(event, side) DO UPDATE SET points = points + 1", [.text(side)])
                    try db.run("UPDATE lights_attempts SET won = 1 WHERE account = ?", [.text(account)])
                    points = 1
                }
            } else if reward > 0 {
                try move(op: op, from: escrow, to: Self.cityBudget, amount: reward); released = reward
            }
            let receipt = SettlementReceipt(ticketID: ticketID, status: status, reason: reason, seconds: seconds, playerHP: hp,
                                            rewardPaid: paid, rewardReleased: released, consumablesUsed: used, consumablesReturned: returned,
                                            drops: drops, publicPoints: points)
            try db.run("UPDATE tickets SET status = ?, result = ? WHERE id = ?", [.text(status.rawValue), .text(try Self.json(receipt)), .text(ticketID)])
            return receipt
        }
    }

    /// Closes tickets past their expiry: the reward goes back to the city budget and the
    /// consumables back to the player. Returns how many were closed.
    @discardableResult
    public func expireTickets() throws -> Int {
        try locked {
            try db.transaction {
                let rows = try db.query("SELECT * FROM tickets WHERE status = 'open' AND expires_at < ?", [.int(clock())])
                for ticket in rows {
                    let id = ticket.string("id"), account = ticket.string("account"), escrow = "ticket:" + id
                    let op = "expire-" + id
                    if ticket.int("reward") > 0 { try move(op: op, from: escrow, to: Self.cityBudget, amount: ticket.int("reward")) }
                    for (item, count) in try Self.decode([String: Int64].self, ticket.string("consumables")).sorted(by: { $0.key < $1.key }) where count > 0 {
                        _ = try moveItems(op: op, item: item, quantity: count, from: escrow, to: account)
                    }
                    try db.run("UPDATE tickets SET status = 'expired' WHERE id = ?", [.text(id)])
                }
                return rows.count
            }
        }
    }

    public func publicScores() throws -> [String: Int64] {
        try locked {
            try db.query("SELECT side, points FROM public_scores WHERE event = 'lights'").reduce(into: [:]) { $0[$1.string("side")] = $1.int("points") }
        }
    }

    // MARK: Audit

    /// Recomputes every balance from the journals and checks the escrows.
    public func audit() throws -> AuditReport {
        try locked {
            var problems: [String] = []
            let supply = try db.query("SELECT COALESCE(SUM(cash), 0) AS s FROM accounts").first!.int("s")
            let issued = try db.query("SELECT source, SUM(amount) AS s FROM money_journal WHERE kind = 'issue' GROUP BY source")
                .reduce(into: [String: Int64]()) { $0[$1.string("source")] = $1.int("s") }
            let burned = try db.query("SELECT source, SUM(amount) AS s FROM money_journal WHERE kind = 'burn' GROUP BY source")
                .reduce(into: [String: Int64]()) { $0[$1.string("source")] = $1.int("s") }
            let totalIssued = issued.values.reduce(0, +), totalBurned = burned.values.reduce(0, +)
            if supply != totalIssued - totalBurned { problems.append("money supply \(supply) != issued \(totalIssued) - burned \(totalBurned)") }
            for row in try db.query("""
                SELECT a.id, a.cash,
                  COALESCE((SELECT SUM(amount) FROM money_journal WHERE to_account = a.id), 0) -
                  COALESCE((SELECT SUM(amount) FROM money_journal WHERE from_account = a.id), 0) AS derived
                FROM accounts a
                """) where row.int("cash") != row.int("derived") {
                problems.append("account \(row.string("id")) cash \(row.int("cash")) != journal \(row.int("derived"))")
            }
            for row in try db.query("""
                SELECT l.id, l.quantity,
                  COALESCE((SELECT SUM(quantity) FROM item_journal WHERE lot = l.id AND kind = 'consume'), 0) AS consumed,
                  COALESCE((SELECT SUM(quantity) FROM holdings WHERE lot = l.id), 0) AS held
                FROM lots l
                """) where row.int("quantity") - row.int("consumed") != row.int("held") {
                problems.append("lot \(row.string("id")) created \(row.int("quantity")) - consumed \(row.int("consumed")) != held \(row.int("held"))")
            }
            for row in try db.query("""
                SELECT s.id, s.status, s.remaining, COALESCE((SELECT SUM(quantity) FROM holdings WHERE owner = 'listing:' || s.id), 0) AS held
                FROM listings s
                """) where row.int("held") != (row.string("status") == "open" ? row.int("remaining") : 0) {
                problems.append("listing \(row.string("id")) escrow \(row.int("held")) != remaining \(row.int("remaining"))")
            }
            for row in try db.query("""
                SELECT t.id, t.status, t.reward, COALESCE((SELECT cash FROM accounts WHERE id = 'ticket:' || t.id), 0) AS held,
                  COALESCE((SELECT SUM(quantity) FROM holdings WHERE owner = 'ticket:' || t.id), 0) AS items
                FROM tickets t
                """) {
                let open = row.string("status") == "open"
                if row.int("held") != (open ? row.int("reward") : 0) { problems.append("ticket \(row.string("id")) escrow \(row.int("held")) != reward") }
                if !open && row.int("items") != 0 { problems.append("closed ticket \(row.string("id")) still holds \(row.int("items")) items") }
            }
            let entries = try db.query("SELECT COUNT(*) AS n FROM money_journal").first!.int("n")
            return AuditReport(ok: problems.isEmpty, moneySupply: supply, issued: issued, burned: burned, journalEntries: entries, problems: problems)
        }
    }

    // MARK: Operation receipts

    private struct Stored<R: Codable>: Codable {
        var ok: R?
        var error: LedgerError?
    }

    private enum Outcome<R> { case ok(R), failed(LedgerError) }

    static func validOperationID(_ op: String) -> Bool {
        (1...80).contains(op.count) && op.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "-" || $0 == "_" }
    }

    private func storedAnswer<P: Encodable, R: Codable>(_ name: String, account: String, op: String, payload: P) throws -> R? {
        guard let row = try db.query("SELECT name, payload_hash, result FROM operations WHERE account = ? AND op_id = ?", [.text(account), .text(op)]).first else { return nil }
        guard row.string("name") == name, row.string("payload_hash") == (try Self.payloadHash(name, payload)) else { throw LedgerError.operationConflict }
        let stored = try Self.decode(Stored<R>.self, row.string("result"))
        if let error = stored.error { throw error }
        guard let ok = stored.ok else { throw LedgerError.notFound }
        return ok
    }

    private func operation<P: Encodable, R: Codable>(_ name: String, account: String, op: String, payload: P, _ body: () throws -> R) throws -> R {
        guard Self.validOperationID(op) else { throw LedgerError.invalidRequest }
        let outcome: Outcome<R> = try locked {
            try db.transaction {
                do {
                    if let stored: R = try storedAnswer(name, account: account, op: op, payload: payload) { return .ok(stored) }
                } catch let error as LedgerError {
                    return .failed(error)
                }
                let outcome: Outcome<R>
                do { outcome = .ok(try db.savepoint(body)) }
                catch let error as LedgerError { outcome = .failed(error) }
                let stored: Stored<R>
                switch outcome {
                case .ok(let value): stored = Stored(ok: value, error: nil)
                case .failed(let error): stored = Stored(ok: nil, error: error)
                }
                try db.run("INSERT INTO operations(account, op_id, name, payload_hash, result, at) VALUES(?, ?, ?, ?, ?, ?)",
                           [.text(account), .text(op), .text(name), .text(try Self.payloadHash(name, payload)), .text(try Self.json(stored)), .int(clock())])
                return outcome
            }
        }
        switch outcome {
        case .ok(let value): return value
        case .failed(let error): throw error
        }
    }

    // MARK: Money and item primitives (call inside a transaction)

    private func ensureAccount(_ id: String, kind: String) throws {
        try db.run("INSERT OR IGNORE INTO accounts(id, kind, cash, created_at) VALUES(?, ?, 0, ?)", [.text(id), .text(kind), .int(clock())])
    }

    private func journal(op: String, kind: String, source: String?, from: String?, to: String?, amount: Int64) throws {
        try db.run("INSERT INTO money_journal(op, kind, source, from_account, to_account, amount, at) VALUES(?, ?, ?, ?, ?, ?, ?)",
                   [.text(op), .text(kind), source.map(Database.Value.text) ?? .null, from.map(Database.Value.text) ?? .null,
                    to.map(Database.Value.text) ?? .null, .int(amount), .int(clock())])
    }

    private func issue(op: String, to: String, amount: Int64, source: String) throws {
        guard amount > 0 else { return }
        guard try db.run("UPDATE accounts SET cash = cash + ? WHERE id = ?", [.int(amount), .text(to)]) == 1 else { throw LedgerError.notFound }
        try journal(op: op, kind: "issue", source: source, from: nil, to: to, amount: amount)
    }

    private func burn(op: String, from: String, amount: Int64, reason: String) throws {
        guard amount > 0 else { return }
        guard try db.run("UPDATE accounts SET cash = cash - ? WHERE id = ? AND cash >= ?", [.int(amount), .text(from), .int(amount)]) == 1 else { throw LedgerError.insufficientFunds }
        try journal(op: op, kind: "burn", source: reason, from: from, to: nil, amount: amount)
    }

    private func move(op: String, from: String, to: String, amount: Int64) throws {
        guard amount > 0 else { return }
        guard try db.run("UPDATE accounts SET cash = cash - ? WHERE id = ? AND cash >= ?", [.int(amount), .text(from), .int(amount)]) == 1 else { throw LedgerError.insufficientFunds }
        guard try db.run("UPDATE accounts SET cash = cash + ? WHERE id = ?", [.int(amount), .text(to)]) == 1 else { throw LedgerError.notFound }
        try journal(op: op, kind: "transfer", source: nil, from: from, to: to, amount: amount)
    }

    private func createLot(op: String, item: String, quantity: Int64, owner: String, origin: String, ref: String?) throws -> String {
        let id = "lot-" + Self.randomHex(8)
        try db.run("INSERT INTO lots(id, item, origin, origin_ref, created_op, quantity, at) VALUES(?, ?, ?, ?, ?, ?, ?)",
                   [.text(id), .text(item), .text(origin), ref.map(Database.Value.text) ?? .null, .text(op), .int(quantity), .int(clock())])
        try db.run("INSERT INTO holdings(owner, lot, quantity) VALUES(?, ?, ?)", [.text(owner), .text(id), .int(quantity)])
        try db.run("INSERT INTO item_journal(op, kind, lot, from_owner, to_owner, quantity, at) VALUES(?, 'create', ?, NULL, ?, ?, ?)",
                   [.text(op), .text(id), .text(owner), .int(quantity), .int(clock())])
        return id
    }

    /// Takes `quantity` of `item` from `owner`, oldest lots first.
    private func take(item: String, quantity: Int64, from owner: String) throws -> [LotMove] {
        let rows = try db.query("""
            SELECT h.lot, h.quantity FROM holdings h JOIN lots l ON l.id = h.lot
            WHERE h.owner = ? AND l.item = ? AND h.quantity > 0 ORDER BY l.seq
            """, [.text(owner), .text(item)])
        guard rows.reduce(0, { $0 + $1.int("quantity") }) >= quantity else { throw LedgerError.insufficientItems }
        var left = quantity, moves: [LotMove] = []
        for row in rows where left > 0 {
            let n = min(left, row.int("quantity"))
            try db.run("UPDATE holdings SET quantity = quantity - ? WHERE owner = ? AND lot = ?", [.int(n), .text(owner), .text(row.string("lot"))])
            moves.append(LotMove(lot: row.string("lot"), quantity: n))
            left -= n
        }
        try db.run("DELETE FROM holdings WHERE owner = ? AND quantity = 0", [.text(owner)])
        return moves
    }

    private func moveItems(op: String, item: String, quantity: Int64, from: String, to: String) throws -> [LotMove] {
        let moves = try take(item: item, quantity: quantity, from: from)
        for move in moves {
            try db.run("INSERT INTO holdings(owner, lot, quantity) VALUES(?, ?, ?) ON CONFLICT(owner, lot) DO UPDATE SET quantity = quantity + excluded.quantity",
                       [.text(to), .text(move.lot), .int(move.quantity)])
            try db.run("INSERT INTO item_journal(op, kind, lot, from_owner, to_owner, quantity, at) VALUES(?, 'move', ?, ?, ?, ?, ?)",
                       [.text(op), .text(move.lot), .text(from), .text(to), .int(move.quantity), .int(clock())])
        }
        return moves
    }

    private func consumeItems(op: String, item: String, quantity: Int64, from: String, reason: String) throws -> [LotMove] {
        guard quantity > 0 else { return [] }
        let moves = try take(item: item, quantity: quantity, from: from)
        for move in moves {
            try db.run("INSERT INTO item_journal(op, kind, lot, from_owner, to_owner, quantity, at) VALUES(?, 'consume', ?, ?, ?, ?, ?)",
                       [.text(op), .text(move.lot), .text(from), .text(reason), .int(move.quantity), .int(clock())])
        }
        return moves
    }

    private func itemsOwned(by owner: String) throws -> [String: Int64] {
        try db.query("SELECT l.item, SUM(h.quantity) AS n FROM holdings h JOIN lots l ON l.id = h.lot WHERE h.owner = ? GROUP BY l.item", [.text(owner)])
            .reduce(into: [:]) { $0[$1.string("item")] = $1.int("n") }
    }

    /// Where every unit of `item` held by `owner` came from.
    public func provenance(owner: String, item: String) throws -> [(lot: String, origin: String, ref: String?, quantity: Int64)] {
        try locked {
            try db.query("""
                SELECT l.id, l.origin, l.origin_ref, h.quantity FROM holdings h JOIN lots l ON l.id = h.lot
                WHERE h.owner = ? AND l.item = ? ORDER BY l.seq
                """, [.text(owner), .text(item)]).map { ($0.string("id"), $0.string("origin"), $0.text("origin_ref"), $0.int("quantity")) }
        }
    }

    // MARK: Helpers

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    static func randomHex(_ bytes: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<bytes).map { _ in String(format: "%02x", UInt8.random(in: 0...255, using: &generator)) }.joined()
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func payloadHash<P: Encodable>(_ name: String, _ payload: P) throws -> String {
        sha256(name + "\n" + (try json(payload)))
    }

    static func json<P: Encodable>(_ value: P) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ text: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(text.utf8))
    }
}
