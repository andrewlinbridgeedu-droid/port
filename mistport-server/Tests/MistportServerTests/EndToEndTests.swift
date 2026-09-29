import Foundation
import HTTPTypes
import Hummingbird
import HummingbirdTesting
import MistportCombatCore
import MistportLedger
import Testing
@testable import MistportServer

private let adminToken = "test-admin-token-0123456789"

private func database() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent("mistport-server-\(UUID().uuidString).sqlite").path
}

private func body<T: Encodable>(_ value: T) throws -> ByteBuffer { ByteBuffer(bytes: try JSONEncoder().encode(value)) }

private func decode<T: Decodable>(_ type: T.Type, _ response: TestResponse) throws -> T {
    try JSONDecoder().decode(type, from: Data(response.body.readableBytesView))
}

private func auth(_ token: String) -> HTTPFields { [.authorization: "Bearer " + token, .contentType: "application/json"] }
private let adminHeaders: HTTPFields = [HTTPField.Name("X-Admin-Token")!: adminToken, .contentType: "application/json"]

/// What a client does between opening and settling a ticket: plays the encounter with the
/// character the server named and records only its own inputs.
private func playHonestly(_ ticket: TicketReceipt) throws -> MPCBattleInputLog {
    var nextMedalAt = 2.0
    let (_, log) = try MPCChurchBattleDriver.record(
        encounterID: ticket.encounterID, loadout: LedgerCatalog.loadout(floor: ticket.characterFloor),
        consumables: ticket.consumables.mapValues(Int.init)
    ) { view in
        var out: [MPCBattleInput] = []
        var trial = view.session
        if let target = view.session.enemies.first(where: { $0.isAlive && $0.currentIntent != "guard" }), target.id != view.target {
            out.append(.init(tick: view.tick, kind: .target, enemyID: target.id))
        }
        if view.now >= nextMedalAt, trial.activateUsurpedLifeMedal(isOwned: true, at: view.now) {
            out.append(.init(tick: view.tick, kind: .medal)); nextMedalAt = trial.usurpedLifeMedalReadyAt
        }
        return out
    }
    return log
}

@Suite("HTTP: one shared trade and one key battle, end to end")
struct EndToEndTests {
    @Test("trade and battle through the HTTP API, over the in-process router")
    func tradeAndBattle() async throws {
        let ledger = try Ledger(path: database())
        let app = Application(router: buildRouter(ledger: ledger, adminToken: adminToken))
        try await app.test(.router) { client in try await Self.scenario(client) }
    }

    @Test("the same scenario over a real socket")
    func live() async throws {
        let ledger = try Ledger(path: database())
        let app = Application(router: buildRouter(ledger: ledger, adminToken: adminToken),
                              configuration: .init(address: .hostname("127.0.0.1", port: 0)))
        try await app.test(.live) { client in try await Self.scenario(client) }
    }

    static func scenario(_ client: some TestClientProtocol) async throws {
        try await client.execute(uri: "/health", method: .get) { #expect($0.status == .ok) }

        let seller = try await client.execute(uri: "/v0/accounts", method: .post) { try decode(AccountCreated.self, $0) }
        let buyer = try await client.execute(uri: "/v0/accounts", method: .post) { try decode(AccountCreated.self, $0) }

        // Without a token nothing is allowed; operator routes need the admin token.
        try await client.execute(uri: "/v0/me", method: .get) { #expect($0.status == .unauthorized) }
        try await client.execute(uri: "/v0/admin/audit", method: .get, headers: auth(buyer.token)) { #expect($0.status == .unauthorized) }

        // Setup by the operator: the seller has three hides, the buyer's character is floor 10.
        try await client.execute(uri: "/v0/admin/grants", method: .post, headers: adminHeaders,
                                 body: try body(GrantBody(account: seller.accountID, item: MPCTowerMaterials.hide, quantity: 3))) { #expect($0.status == .ok) }
        try await client.execute(uri: "/v0/admin/characters/" + buyer.accountID, method: .post, headers: adminHeaders,
                                 body: try body(CharacterBody(floor: 10, maxFloor: nil))) { #expect($0.status == .ok) }

        // The buyer brings local copper (user decision: local wealth goes to the shared server).
        let imported = try await client.execute(uri: "/v0/import", method: .post, headers: auth(buyer.token),
                                                body: try body(ImportBody(op: "import-1", fingerprint: "save-e2e-buyer", copper: 500))) { try decode(ImportReceipt.self, $0) }
        #expect(imported.granted == 500)

        // One shared trade.
        let listing = try await client.execute(uri: "/v0/market/listings", method: .post, headers: auth(seller.token),
                                               body: try body(ListBody(op: "list-1", item: MPCTowerMaterials.hide, quantity: 3, unitPrice: 40))) { try decode(ListingReceipt.self, $0) }
        let market = try await client.execute(uri: "/v0/market?item=" + MPCTowerMaterials.hide, method: .get) { try decode(Listings.self, $0) }
        #expect(market.listings.map(\.listingID) == [listing.listingID])
        let buy = BuyBody(op: "buy-1", quantity: 2)
        let trade = try await client.execute(uri: "/v0/market/listings/\(listing.listingID)/buy", method: .post, headers: auth(buyer.token),
                                             body: try body(buy)) { try decode(TradeReceipt.self, $0) }
        #expect(trade.gross == 80 && trade.fee == 4 && trade.sellerNet == 76 && trade.remaining == 1)
        let retried = try await client.execute(uri: "/v0/market/listings/\(listing.listingID)/buy", method: .post, headers: auth(buyer.token),
                                               body: try body(buy)) { try decode(TradeReceipt.self, $0) }
        #expect(retried == trade, "a network retry does not buy twice")
        try await client.execute(uri: "/v0/market/listings/\(listing.listingID)/buy", method: .post, headers: auth(buyer.token),
                                 body: try body(BuyBody(op: "buy-1", quantity: 1))) { response in
            let error = try decode([String: String].self, response)
            #expect(response.status == .conflict && error == ["error": "operationConflict"])
        }

        // One key battle: the lights public target, settled by server replay.
        let ticket = try await client.execute(uri: "/v0/battles", method: .post, headers: auth(buyer.token),
                                              body: try body(TicketBody(op: "ticket-1", battle: .init(kind: .lightsPublic, side: "pumps")))) { try decode(TicketReceipt.self, $0) }
        #expect(ticket.reward == 12 && ticket.characterFloor == 10)
        let log = try playHonestly(ticket)
        let settled = try await client.execute(uri: "/v0/battles/\(ticket.ticketID)/settle", method: .post, headers: auth(buyer.token),
                                               body: try body(SettleBody(op: "settle-1", log: log))) { try decode(SettlementReceipt.self, $0) }
        #expect(settled.status == .won && settled.rewardPaid == 12 && settled.publicPoints == 1)
        let again = try await client.execute(uri: "/v0/battles/\(ticket.ticketID)/settle", method: .post, headers: auth(buyer.token),
                                             body: try body(SettleBody(op: "settle-1", log: log))) { try decode(SettlementReceipt.self, $0) }
        #expect(again == settled, "the reward is paid once")
        try await client.execute(uri: "/v0/battles/\(ticket.ticketID)/settle", method: .post, headers: auth(seller.token),
                                 body: try body(SettleBody(op: "steal", log: log))) { #expect($0.status == .notFound) }

        let me = try await client.execute(uri: "/v0/me", method: .get, headers: auth(buyer.token)) { try decode(AccountView.self, $0) }
        #expect(me.cash == 500 - 80 + 12 && me.items[MPCTowerMaterials.hide] == 2)
        let scores = try await client.execute(uri: "/v0/events/lights", method: .get) { try decode(PublicScores.self, $0) }
        #expect(scores.points == ["pumps": 1])

        let audit = try await client.execute(uri: "/v0/admin/audit", method: .get, headers: adminHeaders) { try decode(AuditReport.self, $0) }
        #expect(audit.ok && audit.moneySupply == 100_000 + 500, "\(audit.problems)")
    }
}
