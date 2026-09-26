import Foundation

public enum MPCChurch: String, Codable, CaseIterable, Sendable { case lamp, mirror, archive }
public struct MPCChurchLoanOffer: Codable, Equatable, Sendable {
    public let relicID: String
    public let church: MPCChurch
    public let value: Int
    public let unlockMission: Int
    public let requiredLifetimeMerit: Int
    /// A substantial escrow, rounded up to the next ten copper. The contract
    /// snapshots this number so later catalog changes cannot alter a refund.
    public var deposit: Int {
        let twoThirds = (value * 2 + 2) / 3
        return ((twoThirds + 9) / 10) * 10
    }
    /// One non-refundable copper rental fee covers up to three actual battles.
    public var rentalFee: Int { (value + 9) / 10 }
    public var totalDue: Int { deposit + rentalFee }
    /// Only contracts signed before the copper-rent revision use merit fees.
    public var legacyDeposit: Int { (value + 3) / 4 }
    public var meritPerBattle: Int { (value + 119) / 120 }
    public static let all: [Self] = [
        .init(relicID:"relic_salt_sealed_breathing_bag",church:.lamp,value:120,unlockMission:4,requiredLifetimeMerit:20),
        .init(relicID:"relic_return_gift_clasp",church:.lamp,value:160,unlockMission:4,requiredLifetimeMerit:20),
        .init(relicID:"relic_deferred_stamp",church:.archive,value:360,unlockMission:9,requiredLifetimeMerit:20),
        .init(relicID:"relic_reflecting_ink_mirror",church:.mirror,value:520,unlockMission:14,requiredLifetimeMerit:40),
        .init(relicID:"relic_sealed_paperweight",church:.lamp,value:400,unlockMission:18,requiredLifetimeMerit:40),
        .init(relicID:"relic_countertide_anchor",church:.archive,value:640,unlockMission:20,requiredLifetimeMerit:80),
        .init(relicID:"relic_ownership_severing_needle",church:.mirror,value:720,unlockMission:26,requiredLifetimeMerit:80),
        .init(relicID:"relic_blank_name_card",church:.lamp,value:680,unlockMission:17,requiredLifetimeMerit:80)
    ]
}
public enum MPCChurchLoanError: Error, Equatable { case unavailable, ineligible, insufficientFunds, duplicate, exhausted, battlePending, invalidBattle, invalidLoan }
public enum MPCChurchBattleOutcome: String, Codable, Sendable { case victory, defeat, retreat }
public struct MPCChurchLoanTerms: Codable, Equatable, Sendable {
    public let deposit: Int
    public let rentalFee: Int
    public init(deposit: Int, rentalFee: Int) {
        self.deposit = deposit
        self.rentalFee = rentalFee
    }
}
public struct MPCChurchLoan: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let itemUID: String
    public let offer: MPCChurchLoanOffer
    public var durability: Int = 100
    public var remainingBattles: Int = 3
    public var returned: Bool = false
    public var pendingBattleID: String?
    /// Nil for pre-revision saves: honor their original deposit and merit fees.
    public var terms: MPCChurchLoanTerms?
    public var isLegacyContract: Bool { terms == nil }
    public var depositHeld: Int { terms?.deposit ?? offer.legacyDeposit }
    public var rentalFeePaid: Int { terms?.rentalFee ?? 0 }
    public var returnPreview: MPCChurchLoanReturn {
        let retainedDeposit = isLegacyContract
            ? min(depositHeld, (offer.value * (100 - durability) + 199) / 200)
            : (durability == 0 ? depositHeld : 0)
        return MPCChurchLoanReturn(
            loanID: id,
            copperRefund: depositHeld - retainedDeposit,
            meritRefund: isLegacyContract ? remainingBattles * offer.meritPerBattle : 0,
            damageFee: retainedDeposit)
    }
}
public struct MPCChurchLoanReturn: Codable, Equatable, Sendable {
    public let loanID: String
    public let copperRefund: Int
    public let meritRefund: Int
    public let damageFee: Int
}
/// The host synchronizes wallet balances immediately before each transaction and
/// persists this ledger together with the resulting wallet once. Owned items stay
/// in a separate inventory; borrowing never inserts or removes their ownership.
public struct MPCChurchLoanLedger: Codable, Equatable, Sendable {
    public var coins: Int
    public var lifetimeMerit: Int
    public var availableMerit: Int
    public private(set) var loans: [String:MPCChurchLoan] = [:]
    public private(set) var battleLoans: [String:[String]] = [:]
    public private(set) var settledBattleIDs: Set<String> = []
    public private(set) var returnReceipts: [String:MPCChurchLoanReturn] = [:]
    public init(coins: Int = 0, lifetimeMerit: Int = 0, availableMerit: Int = 0) {
        self.coins = max(0,coins); self.lifetimeMerit = max(0,lifetimeMerit); self.availableMerit = max(0,availableMerit)
    }
    @discardableResult public mutating func borrow(relicID: String, completedMissions: Set<Int>, loanID: String = UUID().uuidString) throws -> MPCChurchLoan {
        guard let offer = MPCChurchLoanOffer.all.first(where: {$0.relicID == relicID}) else { throw MPCChurchLoanError.unavailable }
        guard completedMissions.contains(offer.unlockMission), lifetimeMerit >= offer.requiredLifetimeMerit else { throw MPCChurchLoanError.ineligible }
        guard loans[loanID] == nil, !loans.values.contains(where: {!$0.returned && $0.offer.relicID == relicID}) else { throw MPCChurchLoanError.duplicate }
        guard coins >= offer.totalDue else { throw MPCChurchLoanError.insufficientFunds }
        coins -= offer.totalDue
        var loan = MPCChurchLoan(id:loanID,itemUID:"loan-item-" + loanID,offer:offer)
        loan.terms = .init(deposit: offer.deposit, rentalFee: offer.rentalFee)
        loans[loanID] = loan
        return loan
    }
    public func effectiveRelicID(loanID: String) -> String? {
        guard let loan = loans[loanID], !loan.returned, loan.durability > 0,
              loan.remainingBattles > 0 || loan.pendingBattleID != nil else { return nil }
        return loan.offer.relicID
    }
    /// Called only when a gameplay event actually destroys or loses the loaned
    /// copy. Ordinary three-battle wear does not forfeit its deposit.
    @discardableResult public mutating func markLost(_ id: String) throws -> Bool {
        guard var loan = loans[id], !loan.returned else { throw MPCChurchLoanError.invalidLoan }
        guard loan.pendingBattleID == nil else { throw MPCChurchLoanError.battlePending }
        if loan.durability == 0 { return false }
        loan.durability = 0
        loan.remainingBattles = 0
        loans[id] = loan
        return true
    }
    /// A resumed battle keeps the same ID and does not charge again. Unequipped
    /// loans do not enter this transaction. Persist before dispatching combat.
    @discardableResult public mutating func beginBattle(battleID: String, equippedLoanID: String?) throws -> Bool {
        try beginBattle(battleID:battleID,equippedLoanIDs:equippedLoanID.map {[$0]} ?? [])
    }
    @discardableResult public mutating func beginBattle(battleID: String, equippedLoanIDs: [String]) throws -> Bool {
        let ids = equippedLoanIDs.sorted()
        guard !ids.isEmpty else { return false }
        guard !battleID.isEmpty, Set(ids).count == ids.count, ids.count <= 2 else { throw MPCChurchLoanError.invalidBattle }
        if settledBattleIDs.contains(battleID) { throw MPCChurchLoanError.invalidBattle }
        if let existing = battleLoans[battleID] {
            guard existing == ids else { throw MPCChurchLoanError.invalidBattle }; return false
        }
        var updated = loans
        var activeCount = 0, passiveCount = 0
        for id in ids {
            guard var loan = updated[id], !loan.returned else { throw MPCChurchLoanError.invalidLoan }
            guard loan.pendingBattleID == nil else { throw MPCChurchLoanError.battlePending }
            guard loan.remainingBattles > 0, loan.durability > 0 else { throw MPCChurchLoanError.exhausted }
            if loan.offer.relicID == "relic_blank_name_card" { activeCount += 1 } else { passiveCount += 1 }
            loan.remainingBattles -= 1; loan.pendingBattleID = battleID; updated[id] = loan
        }
        guard activeCount <= 1, passiveCount <= 1 else { throw MPCChurchLoanError.invalidBattle }
        loans = updated; battleLoans[battleID] = ids; return true
    }
    @discardableResult public mutating func settleBattle(battleID: String, outcome: MPCChurchBattleOutcome) throws -> Bool {
        guard let ids = battleLoans[battleID] else { throw MPCChurchLoanError.invalidBattle }
        if settledBattleIDs.contains(battleID) { return false }
        var updated = loans
        for id in ids {
            guard var loan = updated[id], loan.pendingBattleID == battleID, !loan.returned else { throw MPCChurchLoanError.invalidBattle }
            loan.durability = max(0,loan.durability - (outcome == .victory ? 2 : outcome == .defeat ? 5 : 3))
            loan.pendingBattleID = nil; updated[id] = loan
        }
        loans = updated; settledBattleIDs.insert(battleID); return true
    }
    /// For new contracts the rental fee is kept even if returned unused; an
    /// intact loan returns its entire escrow. Legacy loans retain their signed
    /// merit-refund and wear-charge terms. Pending battles must settle first.
    @discardableResult public mutating func returnLoan(_ id: String) throws -> MPCChurchLoanReturn {
        if let receipt = returnReceipts[id] { return receipt }
        guard var loan = loans[id], !loan.returned else { throw MPCChurchLoanError.invalidLoan }
        guard loan.pendingBattleID == nil else { throw MPCChurchLoanError.battlePending }
        let receipt = loan.returnPreview
        coins += receipt.copperRefund; availableMerit += receipt.meritRefund
        loan.returned = true; loans[id] = loan; returnReceipts[id] = receipt
        return receipt
    }
    public func mayTransferItem(uid: String) -> Bool { !loans.values.contains { $0.itemUID == uid } }
    public static func ownedRepairPrice(value: Int, durability: Int) -> Int { (max(0,value) * (100-min(100,max(0,durability))) + 199) / 200 }
    public static func ownedSalePrice(value: Int, durability: Int) -> Int { max(0,value) * min(100,max(0,durability)) * 2 / 500 }
}
