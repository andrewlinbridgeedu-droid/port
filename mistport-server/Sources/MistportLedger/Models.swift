import Foundation
import MistportCombatCore

/// Server economy settings. Every number here is a candidate from the design docs, not a
/// launch value: fee 5% and the local-import cap 12,000 come from the shared-economy
/// decisions (2026-09-29), the public-target reward is one 12-copper basket.
public struct LedgerPolicy: Codable, Sendable, Equatable {
    public enum FeeDestination: String, Codable, Sendable { case cityBudget = "city-budget", burn }
    public var feeBasisPoints: Int64 = 500
    public var feeDestination: FeeDestination = .cityBudget
    /// Issued once when the ledger is created; pays battle rewards.
    public var cityBudgetGenesis: Int64 = 100_000
    public var localImportCap: Int64 = 12_000
    public var ticketLifetimeSeconds: Int64 = 30 * 60
    public var lightsPublicReward: Int64 = 12
    public var maxQuantity: Int64 = 9_999
    public var maxUnitPrice: Int64 = 1_000_000
    public init() {}
}

/// Business failures. They are recorded against the operation ID, so a retry with the
/// same ID gets the same answer; storage failures are not recorded and may be retried.
public enum LedgerError: String, Error, Codable, Sendable {
    case unauthorized, notFound, invalidRequest, operationConflict
    case insufficientFunds, insufficientItems, unknownItem
    case soldOut, listingClosed, ownListing, notSeller
    case alreadyImported, fingerprintUsed
    case notEligible, alreadyAttempted, budgetExhausted
    case ticketClosed, ticketExpired, encounterMismatch
}

public struct AccountCreated: Codable, Sendable, Equatable {
    public let accountID: String
    public let token: String
}

public struct AccountView: Codable, Sendable, Equatable {
    public let accountID: String
    public let cash: Int64
    public let items: [String: Int64]
    /// The server-held character: its loadout is the tower verification loadout for this floor.
    public let characterFloor: Int
    public let maxFloor: Int
}

public struct LotMove: Codable, Sendable, Equatable {
    public let lot: String
    public let quantity: Int64
}

public struct ImportReceipt: Codable, Sendable, Equatable {
    public let accountID: String
    public let requested: Int64
    public let granted: Int64
    public let fingerprint: String
}

public struct ListingReceipt: Codable, Sendable, Equatable {
    public let listingID: String
    public let item: String
    public let quantity: Int64
    public let unitPrice: Int64
    public let lots: [LotMove]
}

public struct TradeReceipt: Codable, Sendable, Equatable {
    public let listingID: String
    public let buyer: String
    public let seller: String
    public let item: String
    public let quantity: Int64
    public let unitPrice: Int64
    public let gross: Int64
    public let fee: Int64
    public let sellerNet: Int64
    public let lots: [LotMove]
    public let remaining: Int64
}

public struct CancelReceipt: Codable, Sendable, Equatable {
    public let listingID: String
    public let returned: Int64
}

public struct ListingView: Codable, Sendable, Equatable {
    public let listingID: String
    public let seller: String
    public let item: String
    public let unitPrice: Int64
    public let remaining: Int64
    public let status: String
    public let version: Int64
}

public struct BattleRequest: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable { case tower, lightsPublic = "lights-public" }
    public var kind: Kind
    public var floor: Int?
    public var side: String?
    public var consumables: [String: Int64]
    public init(kind: Kind, floor: Int? = nil, side: String? = nil, consumables: [String: Int64] = [:]) {
        self.kind = kind; self.floor = floor; self.side = side; self.consumables = consumables
    }
}

public struct TicketReceipt: Codable, Sendable, Equatable {
    public let ticketID: String
    public let encounterID: String
    public let ruleVersion: String
    /// Copper reserved for this battle before it starts; paid only on a verified win.
    public let reward: Int64
    public let expiresAt: Int64
    public let characterFloor: Int
    public let consumables: [String: Int64]
}

public struct SettlementReceipt: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable { case won, lost, rejected }
    public let ticketID: String
    public let status: Status
    public let reason: String?
    public let seconds: Double
    public let playerHP: Int
    public let rewardPaid: Int64
    public let rewardReleased: Int64
    public let consumablesUsed: [String: Int64]
    public let consumablesReturned: [String: Int64]
    public let drops: [String: Int64]
    public let publicPoints: Int64
}

public struct AuditReport: Codable, Sendable, Equatable {
    public let ok: Bool
    public let moneySupply: Int64
    public let issued: [String: Int64]
    public let burned: [String: Int64]
    public let journalEntries: Int64
    public let problems: [String]
}

/// Items the server knows: tower materials (drops) and battle consumables.
public enum LedgerCatalog {
    public static let materials: Set<String> = [
        MPCTowerMaterials.hide, MPCTowerMaterials.gland, MPCTowerMaterials.membrane, MPCTowerMaterials.chitin,
        MPCTowerMaterials.silk, MPCTowerMaterials.talon, MPCTowerMaterials.fiber, MPCTowerMaterials.scale,
    ]
    public static let consumables: Set<String> = Set(MPCChapterOneCatalog.items.filter { $0.kind == .consumable }.map(\.id))
    public static func isKnown(_ item: String) -> Bool { materials.contains(item) || consumables.contains(item) }

    public static func loadout(floor: Int) -> MPCChapterOneLoadout {
        let definition = MPCChurchTowerCatalog.floor(number: max(1, min(floor, MPCChurchTowerCatalog.floors.count)))!
        return MPCChurchTowerVerificationRunner.recommendedLoadout(for: definition)
    }
}
