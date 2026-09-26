import Foundation

public enum MPCChurchOwnedRelicError: Error, Equatable {
    case notOwned, unavailable, exhausted, battlePending, invalidBattle, insufficientFunds
}
public struct MPCChurchOwnedRepairReceipt: Codable, Equatable, Sendable {
    public let relicID: String
    public let restoredDurability: Int
    public let copperCost: Int
}
/// One owned copy per relic ID is the current inventory contract. This ledger
/// never grants or removes ownership. Missing durability on an existing owned
/// ordinary relic migrates lazily to 100; R01/R02 remain outside this system.
public struct MPCChurchOwnedRelicLedger: Codable, Equatable, Sendable {
    public private(set) var durability: [String:Int] = [:]
    public private(set) var battleRelicIDs: [String:[String]] = [:]
    public private(set) var settledBattleIDs: Set<String> = []
    public init() {}
    public static var ordinaryRelicIDs: Set<String> { Set(MPCChurchLoanOffer.all.map(\.relicID)) }
    public func currentDurability(_ relicID: String) -> Int {
        min(100,max(0,durability[relicID,default:100]))
    }
    public func canUse(_ relicID: String, ownedRelicIDs: Set<String>) -> Bool {
        ownedRelicIDs.contains(relicID) && (!Self.ordinaryRelicIDs.contains(relicID) || currentDurability(relicID) > 0)
    }
    public func hasPendingBattle(_ relicID: String) -> Bool {
        battleRelicIDs.contains { !settledBattleIDs.contains($0.key) && $0.value.contains(relicID) }
    }
    /// A replacement bought after a lost copy starts at full condition.
    public mutating func retireLostCopy(_ relicID: String) {
        guard Self.ordinaryRelicIDs.contains(relicID), !hasPendingBattle(relicID) else { return }
        durability.removeValue(forKey: relicID)
    }
    /// Call with actual active/passive IDs after resolving loan precedence.
    /// borrowedRelicIDs excludes an identically named loan from owned wear.
    /// All validation completes before any record is committed.
    @discardableResult public mutating func beginBattle(battleID: String, equippedRelicIDs: [String], ownedRelicIDs: Set<String>, borrowedRelicIDs: Set<String> = []) throws -> Bool {
        guard !battleID.isEmpty, !settledBattleIDs.contains(battleID) else { throw MPCChurchOwnedRelicError.invalidBattle }
        let ids = Set(equippedRelicIDs).intersection(Self.ordinaryRelicIDs).subtracting(borrowedRelicIDs).sorted()
        if let existing = battleRelicIDs[battleID] {
            guard existing == ids else { throw MPCChurchOwnedRelicError.invalidBattle }; return false
        }
        for id in ids {
            guard ownedRelicIDs.contains(id) else { throw MPCChurchOwnedRelicError.notOwned }
            guard currentDurability(id) > 0 else { throw MPCChurchOwnedRelicError.exhausted }
            guard !hasPendingBattle(id) else { throw MPCChurchOwnedRelicError.battlePending }
        }
        for id in ids { durability[id] = currentDurability(id) }
        battleRelicIDs[battleID] = ids
        return true
    }
    @discardableResult public mutating func settleBattle(battleID: String, outcome: MPCChurchBattleOutcome) throws -> Bool {
        guard let ids = battleRelicIDs[battleID] else { throw MPCChurchOwnedRelicError.invalidBattle }
        if settledBattleIDs.contains(battleID) { return false }
        let wear = outcome == .victory ? 2 : outcome == .defeat ? 5 : 3
        for id in ids { durability[id] = max(0,currentDurability(id) - wear) }
        settledBattleIDs.insert(battleID); return true
    }
    public func repairCost(_ relicID: String, ownedRelicIDs: Set<String>) throws -> Int {
        guard let offer = MPCChurchLoanOffer.all.first(where: {$0.relicID == relicID}) else { throw MPCChurchOwnedRelicError.unavailable }
        guard ownedRelicIDs.contains(relicID) else { throw MPCChurchOwnedRelicError.notOwned }
        guard !hasPendingBattle(relicID) else { throw MPCChurchOwnedRelicError.battlePending }
        return MPCChurchLoanLedger.ownedRepairPrice(value:offer.value,durability:currentDurability(relicID))
    }
    /// Host supplies the latest balance and deducts receipt.copperCost in the
    /// same persistence transaction as this ledger. A repeated full repair costs
    /// zero, so restoring or double-tapping cannot deduct the earlier cost twice.
    @discardableResult public mutating func repair(_ relicID: String, ownedRelicIDs: Set<String>, availableCoins: Int) throws -> MPCChurchOwnedRepairReceipt {
        let cost = try repairCost(relicID,ownedRelicIDs:ownedRelicIDs)
        guard availableCoins >= cost else { throw MPCChurchOwnedRelicError.insufficientFunds }
        let restored = 100-currentDurability(relicID)
        durability[relicID] = 100
        return .init(relicID:relicID,restoredDurability:restored,copperCost:cost)
    }
}
