import Foundation

/// These IDs are the existing native advancement entitlements. New chapter
/// procurement changes their source, never duplicates or invalidates ownership.
public enum MPCAdvancementMaterialMarket {
    public struct Offer: Equatable, Sendable {
        public let id: String
        public let unlockMission: Int
        public let price: Int
    }
    public struct Receipt: Equatable, Sendable {
        public let coins: Int
        public let ownedIDs: Set<String>
    }
    public static let offers: [Offer] = [
        .init(id: "mirrorMothScale", unlockMission: 17, price: 260),
        .init(id: "reverseClockEssence", unlockMission: 20, price: 340),
        .init(id: "ownerlessMaskWax", unlockMission: 23, price: 480)
    ]
    public static func purchase(_ id: String, completedMissionNumbers: Set<Int>, coins: Int,
                                ownedIDs: Set<String>) -> Receipt? {
        guard let offer = offers.first(where: { $0.id == id }),
              completedMissionNumbers.contains(offer.unlockMission),
              !ownedIDs.contains(id), coins >= offer.price else { return nil }
        return .init(coins: coins - offer.price, ownedIDs: ownedIDs.union([id]))
    }
}
