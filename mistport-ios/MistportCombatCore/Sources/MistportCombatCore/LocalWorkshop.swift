import Foundation

/// First local profession slice. No world campaign fixtures or shared-market issuance.
/// The 18-copper NPC allocation is a finite, per-save launch budget, not recurring minting.
public struct MPCLocalWorkshopLedger: Codable, Equatable, Sendable {
    public static let hideID = "material_shield_jaw_hide"
    public static let strapID = "crafted_repair_strap"
    public enum Order: String, Codable, Sendable { case offered, delivered, installed }
    public enum Failure: Error, Equatable { case locked, funds, stock, exhausted, conflict }
    public private(set) var learnedBasics = false
    public private(set) var proficiency = 0
    public private(set) var order = Order.offered
    public private(set) var procurementCopper = 18
    public private(set) var externalPayments = 0
    public private(set) var projectStraps = 0
    public private(set) var towerTickets: [String: Int] = [:]
    public private(set) var finishedTowerTickets: Set<String> = []
    public private(set) var materialReceipts: Set<String> = []
    private var applied: [String: String] = [:]
    public init() {}

    public static func isUnlocked(completedMissions: Set<Int>) -> Bool { completedMissions.contains(16) }
    public mutating func learnBasics(completedMissions: Set<Int>) throws {
        guard Self.isUnlocked(completedMissions: completedMissions) else { throw Failure.locked }
        learnedBasics = true
    }
    private func alreadyApplied(_ id: String, command: String) throws -> Bool {
        guard !id.isEmpty else { throw Failure.conflict }
        guard let previous = applied[id] else { return false }
        guard previous == command else { throw Failure.conflict }
        return true
    }

    /// Only a newly started, eligible F1 battle can create a material entitlement.
    /// Old cleared floors are deliberately not used to backfill material.
    public mutating func beginTower(id: String, floor: Int, completedMissions: Set<Int>) throws {
        guard Self.isUnlocked(completedMissions: completedMissions), floor == 1 else { return }
        guard !id.isEmpty, towerTickets[id] == nil, !finishedTowerTickets.contains(id) else { throw Failure.conflict }
        towerTickets[id] = floor
    }
    public mutating func abandonTower(id: String) {
        guard towerTickets.removeValue(forKey: id) != nil else { return }
        finishedTowerTickets.insert(id)
    }
    @discardableResult public mutating func claimTower(id: String, floor: Int,
        session: MPCChapterOneEncounterSession, inventory: inout [String: Int]) throws -> Bool {
        if materialReceipts.contains(id) { return false }
        guard towerTickets[id] == floor, floor == 1, !finishedTowerTickets.contains(id),
              session.encounter.id == MPCChurchTowerCatalog.floor(number: floor)?.id,
              session.outcome == .victory else { throw Failure.locked }
        guard inventory[Self.hideID, default: 0] < Int.max else { throw Failure.stock }
        inventory[Self.hideID, default: 0] += 1
        towerTickets.removeValue(forKey: id)
        finishedTowerTickets.insert(id); materialReceipts.insert(id)
        return true
    }
    @discardableResult public mutating func craft(id: String, completedMissions: Set<Int>,
        coins: inout Int, inventory: inout [String: Int]) throws -> Bool {
        if try alreadyApplied(id, command: "craft") { return false }
        guard Self.isUnlocked(completedMissions: completedMissions), learnedBasics else { throw Failure.locked }
        guard inventory[Self.hideID, default: 0] >= 1,
              inventory[Self.strapID, default: 0] <= Int.max - 3,
              externalPayments <= Int.max - 13 else { throw Failure.stock }
        guard coins >= 13 else { throw Failure.funds }
        coins -= 13; externalPayments += 13
        inventory[Self.hideID, default: 0] -= 1
        inventory[Self.strapID, default: 0] += 3
        proficiency = min(20, proficiency + 1)
        applied[id] = "craft"
        return true
    }
    @discardableResult public mutating func deliver(id: String, completedMissions: Set<Int>,
        coins: inout Int, inventory: inout [String: Int]) throws -> Bool {
        if try alreadyApplied(id, command: "deliver") { return false }
        guard Self.isUnlocked(completedMissions: completedMissions) else { throw Failure.locked }
        guard order == .offered, procurementCopper >= 18 else { throw Failure.exhausted }
        guard inventory[Self.strapID, default: 0] >= 2, coins <= Int.max - 18 else { throw Failure.stock }
        coins += 18; procurementCopper -= 18
        inventory[Self.strapID, default: 0] -= 2; projectStraps = 2
        order = .delivered; applied[id] = "deliver"
        return true
    }
    @discardableResult public mutating func install(id: String, completedMissions: Set<Int>) throws -> Bool {
        if try alreadyApplied(id, command: "install") { return false }
        guard Self.isUnlocked(completedMissions: completedMissions) else { throw Failure.locked }
        guard order == .delivered, projectStraps == 2 else { throw Failure.stock }
        projectStraps = 0; order = .installed; applied[id] = "install"
        return true
    }
}
