import Foundation
import HTTPTypes
import Hummingbird
import MistportCombatCore
import MistportLedger

/// HTTP front of the shared-server sample. The client only sends intents (operation ID +
/// request); every balance, item, eligibility check and battle outcome is decided by
/// the ledger. Players authenticate with `Authorization: Bearer <token>` from account
/// creation; operator routes need `X-Admin-Token` and are off when no admin token is set.
public struct ServerConfiguration: Sendable {
    public var databasePath: String
    public var host: String
    public var port: Int
    public var adminToken: String?
    public var policy: LedgerPolicy

    public init(databasePath: String, host: String = "127.0.0.1", port: Int = 8080, adminToken: String? = nil, policy: LedgerPolicy = .init()) {
        self.databasePath = databasePath; self.host = host; self.port = port; self.adminToken = adminToken; self.policy = policy
    }

    /// Reads MISTPORT_DB, MISTPORT_HOST, MISTPORT_PORT and MISTPORT_ADMIN_TOKEN.
    public static func fromEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        .init(databasePath: env["MISTPORT_DB"] ?? "mistport-server.sqlite",
              host: env["MISTPORT_HOST"] ?? "127.0.0.1",
              port: env["MISTPORT_PORT"].flatMap(Int.init) ?? 8080,
              adminToken: env["MISTPORT_ADMIN_TOKEN"].flatMap { $0.count >= 16 ? $0 : nil })
    }
}

// MARK: Request and response bodies

public struct ImportBody: Codable, Sendable { public var op: String; public var fingerprint: String; public var copper: Int64 }
public struct ListBody: Codable, Sendable { public var op: String; public var item: String; public var quantity: Int64; public var unitPrice: Int64 }
public struct BuyBody: Codable, Sendable { public var op: String; public var quantity: Int64 }
public struct OperationBody: Codable, Sendable { public var op: String }
public struct TicketBody: Codable, Sendable { public var op: String; public var battle: BattleRequest }
public struct SettleBody: Codable, Sendable { public var op: String; public var log: MPCBattleInputLog }
public struct CharacterBody: Codable, Sendable { public var floor: Int; public var maxFloor: Int? }
public struct GrantBody: Codable, Sendable { public var account: String; public var item: String; public var quantity: Int64 }

public struct Health: ResponseEncodable, Sendable { public let ok: Bool; public let battleRules: String }
public struct Listings: ResponseCodable, Sendable { public let listings: [ListingView] }
public struct PublicScores: ResponseCodable, Sendable { public let event: String; public let points: [String: Int64] }

extension AccountCreated: ResponseCodable {}
extension AccountView: ResponseCodable {}
extension ImportReceipt: ResponseCodable {}
extension ListingReceipt: ResponseCodable {}
extension TradeReceipt: ResponseCodable {}
extension CancelReceipt: ResponseCodable {}
extension TicketReceipt: ResponseCodable {}
extension SettlementReceipt: ResponseCodable {}
extension AuditReport: ResponseCodable {}
extension LotMove: ResponseCodable {}

/// Ledger failures as JSON: `{"error": "<code>"}` with a matching status.
public struct APIError: HTTPResponseError {
    public let code: String
    public let status: HTTPResponse.Status

    public init(_ error: LedgerError) {
        code = error.rawValue
        switch error {
        case .unauthorized: status = .unauthorized
        case .notFound: status = .notFound
        case .invalidRequest, .unknownItem, .encounterMismatch: status = .badRequest
        default: status = .conflict
        }
    }

    public init(code: String, status: HTTPResponse.Status) { self.code = code; self.status = status }

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let body = try JSONEncoder().encode(["error": code])
        return Response(status: status, headers: [.contentType: "application/json"], body: .init(byteBuffer: ByteBuffer(bytes: body)))
    }
}

/// Runs blocking ledger work off the server's event loops.
func offload<T: Sendable>(_ body: @escaping @Sendable () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global().async {
            do { continuation.resume(returning: try body()) }
            catch let error as LedgerError { continuation.resume(throwing: APIError(error)) }
            catch { continuation.resume(throwing: error) }
        }
    }
}

public func buildRouter(ledger: Ledger, adminToken: String?) -> Router<BasicRequestContext> {
    let router = Router()

    @Sendable func player(_ request: Request) async throws -> String {
        guard let header = request.headers[.authorization], header.hasPrefix("Bearer ") else { throw APIError(.unauthorized) }
        let token = String(header.dropFirst("Bearer ".count))
        guard let account = try await offload({ try ledger.authenticate(token: token) }) else { throw APIError(.unauthorized) }
        return account
    }
    @Sendable func admin(_ request: Request) throws {
        guard let adminToken else { throw APIError(code: "adminDisabled", status: .forbidden) }
        guard let header = request.headers[HTTPField.Name("X-Admin-Token")!], header == adminToken else { throw APIError(.unauthorized) }
    }

    router.get("/health") { _, _ in Health(ok: true, battleRules: MPCBattleInputLog.currentVersion) }

    let v0 = router.group("v0")
    v0.post("accounts") { _, _ in try await offload { try ledger.createPlayer() } }
    v0.get("me") { request, _ in
        let account = try await player(request)
        return try await offload { try ledger.account(account) }
    }
    v0.post("import") { request, context in
        let account = try await player(request)
        let body = try await request.decode(as: ImportBody.self, context: context)
        return try await offload { try ledger.importLocal(account: account, op: body.op, fingerprint: body.fingerprint, copper: body.copper) }
    }
    v0.get("market") { request, _ in
        let item = request.uri.queryParameters.get("item")
        return Listings(listings: try await offload { try ledger.openListings(item: item) })
    }
    v0.post("market/listings") { request, context in
        let account = try await player(request)
        let body = try await request.decode(as: ListBody.self, context: context)
        return try await offload { try ledger.list(account: account, op: body.op, item: body.item, quantity: body.quantity, unitPrice: body.unitPrice) }
    }
    v0.post("market/listings/:id/buy") { request, context in
        let account = try await player(request)
        let id = try context.parameters.require("id")
        let body = try await request.decode(as: BuyBody.self, context: context)
        return try await offload { try ledger.buy(account: account, op: body.op, listingID: id, quantity: body.quantity) }
    }
    v0.post("market/listings/:id/cancel") { request, context in
        let account = try await player(request)
        let id = try context.parameters.require("id")
        let body = try await request.decode(as: OperationBody.self, context: context)
        return try await offload { try ledger.cancel(account: account, op: body.op, listingID: id) }
    }
    v0.post("battles") { request, context in
        let account = try await player(request)
        let body = try await request.decode(as: TicketBody.self, context: context)
        return try await offload { try ledger.openTicket(account: account, op: body.op, request: body.battle) }
    }
    v0.post("battles/:id/settle") { request, context in
        let account = try await player(request)
        let id = try context.parameters.require("id")
        let body = try await request.decode(as: SettleBody.self, context: context)
        return try await offload { try ledger.settle(account: account, op: body.op, ticketID: id, log: body.log) }
    }
    v0.get("events/lights") { _, _ in
        PublicScores(event: "lights", points: try await offload { try ledger.publicScores() })
    }

    let operator_ = v0.group("admin")
    operator_.get("audit") { request, _ in
        try admin(request)
        return try await offload { try ledger.audit() }
    }
    operator_.post("characters/:account") { request, context in
        try admin(request)
        let account = try context.parameters.require("account")
        let body = try await request.decode(as: CharacterBody.self, context: context)
        return try await offload {
            try ledger.setCharacter(account: account, floor: body.floor, maxFloor: body.maxFloor)
            return try ledger.account(account)
        }
    }
    operator_.post("grants") { request, context in
        try admin(request)
        let body = try await request.decode(as: GrantBody.self, context: context)
        return try await offload { try ledger.grantTestItems(account: body.account, item: body.item, quantity: body.quantity) }
    }
    return router
}

public func buildApplication(_ configuration: ServerConfiguration) throws -> some ApplicationProtocol {
    let ledger = try Ledger(path: configuration.databasePath, policy: configuration.policy)
    return Application(router: buildRouter(ledger: ledger, adminToken: configuration.adminToken),
                       configuration: .init(address: .hostname(configuration.host, port: configuration.port), serverName: "mistport-m0"))
}
