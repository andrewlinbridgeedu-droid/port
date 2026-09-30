import Foundation
import Testing
import MistportCombatCore
@testable import MistportLedger

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int64 = 1_000_000
    var now: Int64 { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ seconds: Int64) { lock.lock(); value += seconds; lock.unlock() }
}

func temporaryDatabase() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent("mistport-ledger-\(UUID().uuidString).sqlite").path
}

func makeLedger(_ policy: LedgerPolicy = .init(), clock: TestClock = TestClock(), path: String = temporaryDatabase()) throws -> Ledger {
    try Ledger(path: path, policy: policy, clock: { clock.now })
}

/// The tower verification runner's targeting and medal use, as legal inputs.
func honestPolicy(salveBelow: Int? = nil) -> (MPCChurchBattleDriver.View) -> [MPCBattleInput] {
    var nextMedalAt = 2.0
    return { view in
        var out: [MPCBattleInput] = []
        var trial = view.session
        let alive = view.session.enemies.filter(\.isAlive)
        let species = { (e: MPCRuntimeEnemy) in MPCChurchTowerCatalog.enemyConfiguration(contentID: e.contentID)?.species }
        guard let preferred = alive.first(where: { species($0) == .backSac }) ?? alive.first(where: { species($0) == .crown })
                ?? alive.first(where: { $0.currentIntent != "guard" }) ?? alive.first else { return out }
        if preferred.id != view.target { out.append(.init(tick: view.tick, kind: .target, enemyID: preferred.id)) }
        if view.now >= nextMedalAt, trial.activateUsurpedLifeMedal(isOwned: true, at: view.now) {
            out.append(.init(tick: view.tick, kind: .medal)); nextMedalAt = trial.usurpedLifeMedalReadyAt
        }
        if let salveBelow, trial.playerHP < salveBelow, (try? trial.useConsumable("consumable_pain_salve")) != nil {
            out.append(.init(tick: view.tick, kind: .consumable, itemID: "consumable_pain_salve"))
        }
        return out
    }
}

/// What a client does: plays the ticket's encounter with the character the server named.
func play(_ ticket: TicketReceipt, policy: @escaping (MPCChurchBattleDriver.View) -> [MPCBattleInput]) throws -> (MPCChurchBattleDriver.Result, MPCBattleInputLog) {
    try MPCChurchBattleDriver.record(encounterID: ticket.encounterID, loadout: LedgerCatalog.loadout(floor: ticket.characterFloor),
                                     consumables: ticket.consumables.mapValues(Int.init), policy: policy)
}

let salve = "consumable_pain_salve"
let hide = MPCTowerMaterials.hide

@Suite("Ledger: money, items and operation receipts")
struct LedgerMoneyTests {
    @Test("genesis issues the city budget and the books balance")
    func genesis() throws {
        let ledger = try makeLedger()
        #expect(try ledger.cash(Ledger.cityBudget) == 100_000)
        let audit = try ledger.audit()
        #expect(audit.ok && audit.moneySupply == 100_000 && audit.issued == ["genesis:city-budget": 100_000])
        let path = temporaryDatabase()
        _ = try makeLedger(path: path)
        let reopened = try makeLedger(path: path)
        #expect(try reopened.cash(Ledger.cityBudget) == 100_000, "reopening does not issue genesis twice")
    }

    @Test("tokens authenticate only their own account")
    func authentication() throws {
        let ledger = try makeLedger()
        let a = try ledger.createPlayer(), b = try ledger.createPlayer()
        #expect(try ledger.authenticate(token: a.token) == a.accountID)
        #expect(try ledger.authenticate(token: b.token) == b.accountID)
        #expect(try ledger.authenticate(token: "wrong") == nil)
        #expect(try ledger.authenticate(token: "") == nil)
    }

    @Test("local copper is imported once per account and save: at most 12,000 counted, converted at 15%")
    func localImport() throws {
        let ledger = try makeLedger()
        let a = try ledger.createPlayer(), b = try ledger.createPlayer()
        let receipt = try ledger.importLocal(account: a.accountID, op: "imp-1", fingerprint: "save-aaaa-0001", copper: 20_000)
        #expect(receipt.requested == 20_000 && receipt.counted == 12_000 && receipt.granted == 1_800)
        #expect(try ledger.importLocal(account: a.accountID, op: "imp-1", fingerprint: "save-aaaa-0001", copper: 20_000) == receipt, "same operation, same answer")
        #expect(throws: LedgerError.operationConflict) { try ledger.importLocal(account: a.accountID, op: "imp-1", fingerprint: "save-aaaa-0001", copper: 5) }
        #expect(throws: LedgerError.alreadyImported) { try ledger.importLocal(account: a.accountID, op: "imp-2", fingerprint: "save-aaaa-0002", copper: 5) }
        #expect(throws: LedgerError.fingerprintUsed) { try ledger.importLocal(account: b.accountID, op: "imp-1", fingerprint: "save-aaaa-0001", copper: 5) }
        #expect(try ledger.cash(a.accountID) == 1_800 && ledger.cash(b.accountID) == 0)
        let audit = try ledger.audit()
        #expect(audit.ok && audit.issued["local-import"] == 1_800)
    }

    @Test("a trade moves copper and goods together, charges the fee once and keeps provenance")
    func trade() throws {
        let ledger = try makeLedger()
        let seller = try ledger.createPlayer(), buyer = try ledger.createPlayer()
        let lot = try ledger.grantTestItems(account: seller.accountID, item: hide, quantity: 5)
        _ = try ledger.importLocal(account: buyer.accountID, op: "imp", fingerprint: "save-buyer-01", copper: 1_000)  // 150 shared
        let listing = try ledger.list(account: seller.accountID, op: "list-1", item: hide, quantity: 5, unitPrice: 40)
        #expect(try ledger.account(seller.accountID).items[hide] == nil, "listed goods sit in escrow")

        let trade = try ledger.buy(account: buyer.accountID, op: "buy-1", listingID: listing.listingID, quantity: 3)
        #expect(trade.gross == 120 && trade.fee == 6 && trade.sellerNet == 114 && trade.remaining == 2)
        #expect(try ledger.buy(account: buyer.accountID, op: "buy-1", listingID: listing.listingID, quantity: 3) == trade, "a retried request is not a second purchase")
        #expect(try ledger.cash(buyer.accountID) == 30 && ledger.cash(seller.accountID) == 114)
        #expect(try ledger.cash(Ledger.cityBudget) == 100_006)
        #expect(try ledger.account(buyer.accountID).items[hide] == 3)
        let origin = try ledger.provenance(owner: buyer.accountID, item: hide)
        #expect(origin.map(\.lot) == [lot.lot] && origin.first?.origin == "test-grant", "bought goods keep their lot")

        #expect(throws: LedgerError.ownListing) { try ledger.buy(account: seller.accountID, op: "buy-own", listingID: listing.listingID, quantity: 1) }
        #expect(throws: LedgerError.soldOut) { try ledger.buy(account: buyer.accountID, op: "buy-2", listingID: listing.listingID, quantity: 3) }
        #expect(throws: LedgerError.notSeller) { try ledger.cancel(account: buyer.accountID, op: "cancel-x", listingID: listing.listingID) }
        let cancel = try ledger.cancel(account: seller.accountID, op: "cancel-1", listingID: listing.listingID)
        #expect(try cancel.returned == 2 && ledger.account(seller.accountID).items[hide] == 2)
        #expect(throws: LedgerError.listingClosed) { try ledger.buy(account: buyer.accountID, op: "buy-3", listingID: listing.listingID, quantity: 1) }
        #expect(try ledger.audit().ok)
    }

    @Test("a failure is recorded against its operation; a new operation can succeed later")
    func recordedFailure() throws {
        let ledger = try makeLedger()
        let seller = try ledger.createPlayer(), buyer = try ledger.createPlayer()
        _ = try ledger.grantTestItems(account: seller.accountID, item: hide, quantity: 1)
        let listing = try ledger.list(account: seller.accountID, op: "l", item: hide, quantity: 1, unitPrice: 50)
        #expect(throws: LedgerError.insufficientFunds) { try ledger.buy(account: buyer.accountID, op: "b-1", listingID: listing.listingID, quantity: 1) }
        _ = try ledger.importLocal(account: buyer.accountID, op: "imp", fingerprint: "save-buyer-02", copper: 1_000)
        #expect(throws: LedgerError.insufficientFunds) { try ledger.buy(account: buyer.accountID, op: "b-1", listingID: listing.listingID, quantity: 1) }
        #expect(try ledger.buy(account: buyer.accountID, op: "b-2", listingID: listing.listingID, quantity: 1).gross == 50)
        #expect(throws: LedgerError.invalidRequest) { try ledger.buy(account: buyer.accountID, op: "bad op id!", listingID: listing.listingID, quantity: 1) }
    }

    @Test("fees can be configured as a true burn")
    func burnedFee() throws {
        var policy = LedgerPolicy(); policy.feeDestination = .burn
        let ledger = try makeLedger(policy)
        let seller = try ledger.createPlayer(), buyer = try ledger.createPlayer()
        _ = try ledger.grantTestItems(account: seller.accountID, item: hide, quantity: 2)
        _ = try ledger.importLocal(account: buyer.accountID, op: "imp", fingerprint: "save-buyer-03", copper: 2_000)
        let listing = try ledger.list(account: seller.accountID, op: "l", item: hide, quantity: 2, unitPrice: 100)
        _ = try ledger.buy(account: buyer.accountID, op: "b", listingID: listing.listingID, quantity: 2)
        let audit = try ledger.audit()
        #expect(audit.ok && audit.burned["trade-fee"] == 10 && audit.moneySupply == 100_000 + 300 - 10)
    }

    @Test("forty buyers on eight connections race for the last unit: exactly one gets it")
    func lastUnitRace() throws {
        let path = temporaryDatabase()
        let clock = TestClock()
        let setup = try makeLedger(clock: clock, path: path)
        let seller = try setup.createPlayer()
        _ = try setup.grantTestItems(account: seller.accountID, item: hide, quantity: 1)
        let listing = try setup.list(account: seller.accountID, op: "l", item: hide, quantity: 1, unitPrice: 30)
        let buyers: [String] = try (0..<40).map { index in
            let buyer = try setup.createPlayer()
            _ = try setup.importLocal(account: buyer.accountID, op: "imp", fingerprint: "save-racer-\(index)", copper: 1_000)
            return buyer.accountID
        }
        let connections = try (0..<8).map { _ in try makeLedger(clock: clock, path: path) }
        let results = ResultBox()
        DispatchQueue.concurrentPerform(iterations: buyers.count) { index in
            let ledger = connections[index % connections.count]
            do {
                _ = try ledger.buy(account: buyers[index], op: "race", listingID: listing.listingID, quantity: 1)
                results.add("ok")
            } catch let error as LedgerError {
                results.add(error.rawValue)
            } catch {
                results.add("storage: \(error)")
            }
        }
        #expect(results.values.filter { $0 == "ok" }.count == 1)
        #expect(results.values.filter { $0 != "ok" }.allSatisfy { $0 == "soldOut" || $0 == "listingClosed" }, "\(Set(results.values))")
        let holders = try buyers.filter { try setup.account($0).items[hide] == 1 }
        #expect(holders.count == 1)
        #expect(try setup.audit().ok)
    }
}

final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var values: [String] = []
    func add(_ value: String) { lock.lock(); values.append(value); lock.unlock() }
}

@Suite("Ledger: battles are settled by server replay")
struct LedgerBattleTests {
    @Test("a won tower floor pays drops once and unlocks the next floor")
    func towerWin() throws {
        let ledger = try makeLedger()
        let player = try ledger.createPlayer()
        #expect(throws: LedgerError.notEligible) { try ledger.openTicket(account: player.accountID, op: "t-3", request: .init(kind: .tower, floor: 3)) }
        let ticket = try ledger.openTicket(account: player.accountID, op: "t-1", request: .init(kind: .tower, floor: 1))
        let (played, log) = try play(ticket, policy: honestPolicy())
        #expect(played.outcome == .victory)
        let settled = try ledger.settle(account: player.accountID, op: "s-1", ticketID: ticket.ticketID, log: log)
        #expect(settled.status == .won && settled.drops == MPCTowerMaterials.drops(floor: 1).mapValues(Int64.init))
        #expect(try ledger.settle(account: player.accountID, op: "s-1", ticketID: ticket.ticketID, log: log) == settled)
        #expect(throws: LedgerError.ticketClosed) { try ledger.settle(account: player.accountID, op: "s-2", ticketID: ticket.ticketID, log: log) }
        let view = try ledger.account(player.accountID)
        #expect(view.items == MPCTowerMaterials.drops(floor: 1).mapValues(Int64.init) && view.maxFloor == 1)
        #expect(try ledger.provenance(owner: player.accountID, item: MPCTowerMaterials.drops(floor: 1).keys.first!).allSatisfy { $0.origin == "tower-drop" && $0.ref == ticket.ticketID })
        #expect(try ledger.audit().ok)
    }

    @Test("the lights public target reserves its reward first and pays it only for a verified win")
    func lightsWin() throws {
        let ledger = try makeLedger()
        let player = try ledger.createPlayer()
        try ledger.setCharacter(account: player.accountID, floor: 10)
        let ticket = try ledger.openTicket(account: player.accountID, op: "open", request: .init(kind: .lightsPublic, side: "pumps"))
        #expect(ticket.reward == 12 && ticket.encounterID == MPCLightsPublicTarget.encounterID(side: .pumps, ticket: ticket.ticketID))
        #expect(try ledger.cash(Ledger.cityBudget) == 100_000 - 12, "reserved before the battle")
        #expect(throws: LedgerError.alreadyAttempted) { try ledger.openTicket(account: player.accountID, op: "again", request: .init(kind: .lightsPublic, side: "shipping")) }
        let (_, log) = try play(ticket, policy: honestPolicy())
        let settled = try ledger.settle(account: player.accountID, op: "settle", ticketID: ticket.ticketID, log: log)
        #expect(settled.status == .won && settled.rewardPaid == 12 && settled.publicPoints == 1)
        #expect(try ledger.cash(player.accountID) == 12 && ledger.publicScores() == ["pumps": 1])
        #expect(try ledger.audit().ok)
    }

    @Test("a lost battle pays nothing and does not advance the character")
    func towerLoss() throws {
        let ledger = try makeLedger()
        let player = try ledger.createPlayer()
        try ledger.setCharacter(account: player.accountID, floor: 1, maxFloor: 59)
        let ticket = try ledger.openTicket(account: player.accountID, op: "open", request: .init(kind: .tower, floor: 60))
        let (played, log) = try play(ticket, policy: { _ in [] })
        try #require(played.outcome != .victory, "a floor-1 character with no inputs loses floor 60")
        let settled = try ledger.settle(account: player.accountID, op: "settle", ticketID: ticket.ticketID, log: log)
        #expect(settled.status == .lost && settled.drops.isEmpty && settled.rewardPaid == 0)
        #expect(try ledger.account(player.accountID).maxFloor == 59 && ledger.account(player.accountID).items.isEmpty)
        #expect(try ledger.audit().ok)
    }

    @Test("a log played with a stronger character than the server holds, or with forged inputs, does not pay")
    func forgedLogs() throws {
        let ledger = try makeLedger()
        let player = try ledger.createPlayer()
        try ledger.setCharacter(account: player.accountID, floor: 1, maxFloor: 59)
        let ticket = try ledger.openTicket(account: player.accountID, op: "open", request: .init(kind: .tower, floor: 60))
        // The client plays with a floor-60 character; the server holds a floor-1 one.
        let (played, log) = try MPCChurchBattleDriver.record(encounterID: ticket.encounterID, loadout: LedgerCatalog.loadout(floor: 60), policy: honestPolicy())
        #expect(played.outcome == .victory)
        let settled = try ledger.settle(account: player.accountID, op: "settle", ticketID: ticket.ticketID, log: log)
        #expect(settled.status != .won && settled.drops.isEmpty)
        #expect(try ledger.account(player.accountID).maxFloor == 59)

        let other = try ledger.createPlayer()
        try ledger.setCharacter(account: other.accountID, floor: 10)
        let second = try ledger.openTicket(account: other.accountID, op: "open", request: .init(kind: .lightsPublic, side: "pumps"))
        var (_, forged) = try play(second, policy: honestPolicy())
        forged.inputs.insert(.init(tick: 1, kind: .medal), at: 0)
        forged.inputs.insert(.init(tick: 1, kind: .medal), at: 0)
        let rejected = try ledger.settle(account: other.accountID, op: "settle", ticketID: second.ticketID, log: forged)
        #expect(rejected.status == .rejected && rejected.rewardReleased == 12 && rejected.reason != nil)
        #expect(throws: LedgerError.notFound) { try ledger.settle(account: player.accountID, op: "steal", ticketID: second.ticketID, log: forged) }
        #expect(try ledger.cash(Ledger.cityBudget) == 100_000 && ledger.cash(other.accountID) == 0 && ledger.audit().ok)
    }

    @Test("consumables are held during the battle; used ones are consumed, the rest returned")
    func consumables() throws {
        let ledger = try makeLedger()
        let player = try ledger.createPlayer()
        try ledger.setCharacter(account: player.accountID, floor: 12)
        _ = try ledger.grantTestItems(account: player.accountID, item: salve, quantity: 3)
        #expect(throws: LedgerError.insufficientItems) { try ledger.openTicket(account: player.accountID, op: "too-many", request: .init(kind: .tower, floor: 12, consumables: [salve: 4])) }
        let ticket = try ledger.openTicket(account: player.accountID, op: "open", request: .init(kind: .tower, floor: 12, consumables: [salve: 2]))
        #expect(try ledger.account(player.accountID).items[salve] == 1, "brought salves cannot be sold mid-battle")
        let (played, log) = try play(ticket, policy: honestPolicy(salveBelow: 10_000))
        let used = Int64(played.consumablesUsed[salve, default: 0])
        try #require(used >= 1)
        let settled = try ledger.settle(account: player.accountID, op: "settle", ticketID: ticket.ticketID, log: log)
        #expect(settled.consumablesUsed[salve] == used && settled.consumablesReturned[salve, default: 0] == 2 - used)
        #expect(try ledger.account(player.accountID).items[salve, default: 0] == 3 - used)
        #expect(try ledger.audit().ok)
    }

    @Test("an expired ticket releases its reward and items and cannot be settled")
    func expiry() throws {
        let clock = TestClock()
        let ledger = try makeLedger(clock: clock)
        let player = try ledger.createPlayer()
        try ledger.setCharacter(account: player.accountID, floor: 10)
        _ = try ledger.grantTestItems(account: player.accountID, item: salve, quantity: 1)
        let ticket = try ledger.openTicket(account: player.accountID, op: "open", request: .init(kind: .lightsPublic, side: "pumps", consumables: [salve: 1]))
        let (_, log) = try play(ticket, policy: honestPolicy())
        clock.advance(ledger.policy.ticketLifetimeSeconds + 1)
        #expect(throws: LedgerError.ticketExpired) { try ledger.settle(account: player.accountID, op: "late", ticketID: ticket.ticketID, log: log) }
        #expect(try ledger.cash(Ledger.cityBudget) == 100_000 && ledger.account(player.accountID).items[salve] == 1)
        #expect(try ledger.audit().ok)
    }

    @Test("when the city budget cannot cover the reward the battle does not open")
    func budgetExhausted() throws {
        var policy = LedgerPolicy(); policy.cityBudgetGenesis = 5
        let ledger = try makeLedger(policy)
        let player = try ledger.createPlayer()
        #expect(throws: LedgerError.budgetExhausted) { try ledger.openTicket(account: player.accountID, op: "open", request: .init(kind: .lightsPublic, side: "pumps")) }
        // The failed opening is rolled back: the one public attempt is not used up.
        #expect(throws: LedgerError.budgetExhausted) { try ledger.openTicket(account: player.accountID, op: "open-2", request: .init(kind: .lightsPublic, side: "pumps")) }
        #expect(try ledger.cash(Ledger.cityBudget) == 5)
        #expect(try ledger.audit().ok)
    }
}
