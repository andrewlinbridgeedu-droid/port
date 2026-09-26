import Foundation

public enum MPCTavernPrizeKind: String, Codable, Sendable {
    case relic
    case advancementMaterial
}

/// The prize is photographed into the wager before dealing, so a midnight
/// rollover or inventory change cannot silently replace the object at stake.
public struct MPCTavernPrize: Codable, Equatable, Sendable {
    public let dayOrdinal: Int
    public let kind: MPCTavernPrizeKind
    public let itemID: String
    public let name: String

    public init(dayOrdinal: Int, kind: MPCTavernPrizeKind, itemID: String, name: String) {
        self.dayOrdinal = dayOrdinal
        self.kind = kind
        self.itemID = itemID
        self.name = name
    }
}

public enum MPCTavernPrizeRotation {
    /// A featured stake appears on roughly one day in three, only when the
    /// player's story progress has made at least one unowned item available.
    public static func offer(dayOrdinal: Int, completedMissions: Set<Int>,
                             ownedRelicIDs: Set<String>, ownedMaterialIDs: Set<String>) -> MPCTavernPrize? {
        guard dayOrdinal % 3 == 2 else { return nil }
        let relics = MPCChurchLoanOffer.all
            .filter { $0.value >= 360 && completedMissions.contains($0.unlockMission)
                && MPCChapterOneCatalog.isRelicEnabled($0.relicID)
                && !ownedRelicIDs.contains($0.relicID) }
            .compactMap { offer -> MPCTavernPrize? in
                guard let relic = MPCChapterOneCatalog.relics.first(where: { $0.id == offer.relicID }) else { return nil }
                return .init(dayOrdinal: dayOrdinal, kind: .relic, itemID: offer.relicID, name: relic.name)
            }
        let materialNames = [
            "mirrorMothScale": "星纹镜蛾鳞粉",
            "reverseClockEssence": "逆走钟芯髓液",
            "ownerlessMaskWax": "无主面蜡"
        ]
        let materials = MPCAdvancementMaterialMarket.offers
            .filter { completedMissions.contains($0.unlockMission) && !ownedMaterialIDs.contains($0.id) }
            .compactMap { offer -> MPCTavernPrize? in
                guard let name = materialNames[offer.id] else { return nil }
                return .init(dayOrdinal: dayOrdinal, kind: .advancementMaterial, itemID: offer.id, name: name)
            }
        let choices = relics + materials
        guard !choices.isEmpty else { return nil }
        return choices[(dayOrdinal / 3) % choices.count]
    }
}
