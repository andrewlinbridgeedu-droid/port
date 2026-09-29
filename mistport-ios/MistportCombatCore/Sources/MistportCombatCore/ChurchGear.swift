import Foundation

/// Equipment earned in the church tower and on closed bounty cases. These
/// bonuses enter the same encounter loadout as cards and relics, so the reward
/// changes actual combat rather than only the character-sheet power number.
public struct MPCChurchGearStats: Equatable, Sendable {
    public var attackBP: Int
    public var maxHP: Int
    public var damageReductionBP: Int
    /// Deepest tower floor among the worn pieces (0 when none); the Q18, Q26 and
    /// Q30 walls check it (MPCProgressionWalls.meetsTowerFloor).
    public var towerDepth: Int

    public init(attackBP: Int = 0, maxHP: Int = 0, damageReductionBP: Int = 0, towerDepth: Int = 0) {
        self.attackBP = attackBP
        self.maxHP = maxHP
        self.damageReductionBP = damageReductionBP
        self.towerDepth = towerDepth
    }
}

public struct MPCChurchGearItem: Equatable, Sendable, Identifiable {
    public enum Slot: String, Sendable { case weapon, armor }
    public let id: String
    public let name: String
    public let slot: Slot
    public let stats: MPCChurchGearStats
    public let source: String

    public var strength: Int {
        stats.attackBP + stats.maxHP * 10 + stats.damageReductionBP
    }
    /// The tower floor that drops this piece; nil for bounty and workshop pieces.
    public var towerFloor: Int? {
        guard source.hasPrefix("深井第"), source.hasSuffix("层") else { return nil }
        return Int(source.dropFirst(3).dropLast())
    }
    /// The tower floor a workshop piece stands for; it must be cleared to wear it.
    public var craftTier: Int? {
        guard source.hasPrefix("工坊·F"), source.hasSuffix("档") else { return nil }
        return Int(source.dropFirst(4).dropLast())
    }
    /// Depth this piece counts for in the tower check (MPCProgressionWalls.meetsTowerFloor).
    public var depth: Int? { towerFloor ?? craftTier }
}

public enum MPCChurchGearCatalog {
    private static func weapon(_ id: String, _ name: String, _ source: String, _ attackBP: Int) -> MPCChurchGearItem {
        .init(id: id, name: name, slot: .weapon, stats: .init(attackBP: attackBP), source: source)
    }
    private static func armor(_ id: String, _ name: String, _ source: String, _ hp: Int, _ reductionBP: Int) -> MPCChurchGearItem {
        .init(id: id, name: name, slot: .armor, stats: .init(maxHP: hp, damageReductionBP: reductionBP), source: source)
    }

    public static let all: [MPCChurchGearItem] = earned + crafted
    private static let earned: [MPCChurchGearItem] = [
        weapon("tower-f02-jaw-edge", "石颚裂刃", "深井第2层", 1_500),
        armor("tower-f04-seal-plate", "井口封甲", "深井第4层", 160, 700),
        weapon("tower-f06-salt-knife", "盐痕短刀", "深井第6层", 2_500),
        armor("tower-f08-joint-guard", "双颚护胄", "深井第8层", 270, 1_100),
        weapon("tower-f10-anchor-blade", "首锚断刃", "深井第10层", 3_600),
        armor("tower-f20-mist-mail", "盐雾层甲", "深井第20层", 360, 1_500),
        weapon("tower-f30-archive-edge", "暗渠档刃", "深井第30层", 5_500),
        armor("tower-f40-scissor-mail", "断桥刃甲", "深井第40层", 460, 1_900),
        weapon("tower-f50-crown-edge", "冠鸣裂锋", "深井第50层", 7_500),
        armor("tower-f60-bone-mail", "骨爪封甲", "深井第60层", 560, 2_300),
        weapon("tower-f70-joint-edge", "合流断锋", "深井第70层", 9_500),
        armor("tower-f80-deep-mail", "沉井护胄", "深井第80层", 660, 2_700),
        weapon("tower-f90-rift-edge", "裂隙封刃", "深井第90层", 11_500),
        armor("tower-f100-last-seal", "终界封甲", "深井第100层", 760, 3_000),
        weapon("bounty-b01-broken-sword", "七号缺齿剑", "通缉 B01", 2_800),
        armor("bounty-b02-backframe", "收尸人外锁架", "通缉 B02", 310, 1_350),
        weapon("bounty-b03-tide-anchor", "溺钟潮锚", "通缉 B03", 4_300),
        weapon("bounty-b04-reverse-seal", "伪造者倒签笔", "通缉 B04", 3_800),
        weapon("bounty-b05-red-shears", "赤丝银剪", "通缉 B05", 4_900),
        armor("bounty-b06-dark-lantern", "无灯舱甲", "通缉 B06", 410, 1_700),
        armor("bounty-b07-bell-throat", "金喉铃护", "通缉 B07", 200, 900),
        weapon("bounty-b08-mirror-rapier", "借脸镜刺", "通缉 B08", 3_300),
        armor("bounty-b09-copper-shell", "吞契铜背甲", "通缉 B09", 370, 1_500),
        weapon("bounty-b10-life-ledger", "绯月寿账签", "通缉 B10", 4_700)
    ]

    /// Workshop gear agreed 2026-09-29 (DAILY_LOOP_AND_ECONOMY_20260929.md §4.2): a blade
    /// and a mail per tier floor. Each has the strength of the best tower piece of its slot
    /// at that floor less 100, spread differently, so it is another build, never a lead:
    /// the blade trades a tenth of the attack for health, the mail two fifths of the
    /// damage reduction for health.
    public static let craftTiers = [10, 30, 50, 70, 90]
    private static let craftNames: [Int: (blade: String, mail: String)] = [
        10: ("铆鳞短刃", "铆皮护甲"), 30: ("寄膜鞘刃", "寄膜软甲"), 50: ("冠丝裂刃", "甲片编甲"),
        70: ("骨爪长刃", "骨鳞重甲"), 90: ("深井合刃", "深井织甲")
    ]
    static func bestTowerPiece(_ slot: MPCChurchGearItem.Slot, atOrBelow floor: Int) -> MPCChurchGearItem {
        earned.filter { $0.slot == slot && ($0.towerFloor ?? .max) <= floor }.max { $0.strength < $1.strength }!
    }
    private static let crafted: [MPCChurchGearItem] = craftTiers.flatMap { tier -> [MPCChurchGearItem] in
        let blade = bestTowerPiece(.weapon, atOrBelow: tier).stats
        let attack = blade.attackBP * 9 / 10 / 100 * 100
        let mail = bestTowerPiece(.armor, atOrBelow: tier).stats
        let reduction = mail.damageReductionBP * 6 / 10 / 50 * 50
        let source = "工坊·F\(tier)档"
        return [
            .init(id: "craft-t\(tier)-blade", name: craftNames[tier]!.blade, slot: .weapon,
                  stats: .init(attackBP: attack, maxHP: (blade.attackBP - attack) / 10 - 10), source: source),
            .init(id: "craft-t\(tier)-mail", name: craftNames[tier]!.mail, slot: .armor,
                  stats: .init(maxHP: mail.maxHP + (mail.damageReductionBP - reduction) / 10 - 10, damageReductionBP: reduction),
                  source: source)
        ]
    }
    public static func craftedPiece(tier: Int, slot: MPCChurchGearItem.Slot) -> MPCChurchGearItem? {
        crafted.first { $0.craftTier == tier && $0.slot == slot }
    }

    public static func item(_ id: String) -> MPCChurchGearItem? { all.first { $0.id == id } }
    public static func towerDrop(floor: Int) -> MPCChurchGearItem? {
        all.first { $0.source == "深井第\(floor)层" }
    }
    public static func bountyDrop(caseID: String) -> MPCChurchGearItem? {
        all.first { $0.source == "通缉 \(caseID.uppercased())" }
    }
}

public struct MPCChurchGearLedger: Codable, Equatable, Sendable {
    public enum RepairFailure: Error, Equatable { case notCrafted, notOwned, full, noKit }
    /// Workshop pieces wear like relics (2 on a win, 5 on a defeat, 3 on a retreat) and
    /// are mended with workshop goods: the mail with a repair strap, the blade with a patch.
    public static let repairPerKit = 25
    public static let bladeKitID = "crafted_armor_patch"
    public static var mailKitID: String { MPCLocalWorkshopLedger.strapID }

    public private(set) var ownedIDs: Set<String> = []
    public private(set) var equippedWeaponID: String?
    public private(set) var equippedArmorID: String?
    /// Durability of owned workshop pieces, 0–100. Tower pieces do not wear.
    public private(set) var craftedDurability: [String: Int] = [:]
    public private(set) var wearBattleIDs: Set<String> = []
    public init() {}

    enum CodingKeys: String, CodingKey { case ownedIDs, equippedWeaponID, equippedArmorID, craftedDurability, wearBattleIDs }
    /// Saves from before workshop gear have no durability or wear receipts.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ownedIDs = try c.decodeIfPresent(Set<String>.self, forKey: .ownedIDs) ?? []
        equippedWeaponID = try c.decodeIfPresent(String.self, forKey: .equippedWeaponID)
        equippedArmorID = try c.decodeIfPresent(String.self, forKey: .equippedArmorID)
        craftedDurability = try c.decodeIfPresent([String: Int].self, forKey: .craftedDurability) ?? [:]
        wearBattleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .wearBattleIDs) ?? []
    }

    /// First-clear/first-case claims are idempotent. A stronger newly earned
    /// piece is worn automatically, but every owned piece remains selectable.
    /// Workshop pieces are never put on automatically: wearing one needs its floor.
    @discardableResult public mutating func grant(_ id: String) -> Bool {
        guard let item = MPCChurchGearCatalog.item(id), ownedIDs.insert(id).inserted else { return false }
        if item.craftTier != nil { craftedDurability[id] = 100; return true }
        let currentID = item.slot == .weapon ? equippedWeaponID : equippedArmorID
        if currentID.flatMap(MPCChurchGearCatalog.item)?.strength ?? -1 < item.strength {
            if item.slot == .weapon { equippedWeaponID = id } else { equippedArmorID = id }
        }
        return true
    }
    /// Tower and bounty pieces only; workshop pieces go through `equip(_:highestTowerFloor:)`.
    @discardableResult public mutating func equip(_ id: String) -> Bool {
        guard MPCChurchGearCatalog.item(id)?.craftTier == nil else { return false }
        return equip(id, highestTowerFloor: 0)
    }
    /// A workshop piece can be worn only once its tier floor has been cleared, however
    /// it was obtained, so buying one never skips the tower.
    @discardableResult public mutating func equip(_ id: String, highestTowerFloor: Int) -> Bool {
        guard ownedIDs.contains(id), let item = MPCChurchGearCatalog.item(id) else { return false }
        if let tier = item.craftTier, highestTowerFloor < tier { return false }
        if item.slot == .weapon { equippedWeaponID = id } else { equippedArmorID = id }
        return true
    }
    /// Bounty cases stopped paying weapon and armor on 2026-09-28. Removes those
    /// pieces and wears the strongest remaining piece in each slot; returns what was removed.
    @discardableResult public mutating func retireBountyGear() -> [String] {
        let retired = ownedIDs.filter { MPCChurchGearCatalog.item($0)?.source.hasPrefix("通缉") == true }.sorted()
        guard !retired.isEmpty else { return [] }
        ownedIDs.subtract(retired)
        let remaining = ownedIDs.compactMap(MPCChurchGearCatalog.item).filter { $0.craftTier == nil }
        func strongest(_ slot: MPCChurchGearItem.Slot) -> String? {
            remaining.filter { $0.slot == slot }.max { $0.strength < $1.strength }?.id
        }
        if let id = equippedWeaponID, retired.contains(id) { equippedWeaponID = strongest(.weapon) }
        if let id = equippedArmorID, retired.contains(id) { equippedArmorID = strongest(.armor) }
        return retired
    }
    public func durability(_ id: String) -> Int? { craftedDurability[id] }

    /// Wears the equipped workshop pieces once per battle.
    @discardableResult public mutating func wear(battleID: String, outcome: MPCChurchBattleOutcome) -> Bool {
        guard !battleID.isEmpty, wearBattleIDs.insert(battleID).inserted else { return false }
        let loss = outcome == .victory ? 2 : outcome == .defeat ? 5 : 3
        for id in [equippedWeaponID, equippedArmorID].compactMap({ $0 }) where craftedDurability[id] != nil {
            craftedDurability[id] = max(0, craftedDurability[id]! - loss)
        }
        return true
    }
    /// Mends a workshop piece with one kit from the inventory.
    public mutating func repair(_ id: String, inventory: inout [String: Int]) throws {
        guard let item = MPCChurchGearCatalog.item(id), item.craftTier != nil else { throw RepairFailure.notCrafted }
        guard ownedIDs.contains(id), let current = craftedDurability[id] else { throw RepairFailure.notOwned }
        guard current < 100 else { throw RepairFailure.full }
        let kit = item.slot == .weapon ? Self.bladeKitID : Self.mailKitID
        guard inventory[kit, default: 0] >= 1 else { throw RepairFailure.noKit }
        inventory[kit, default: 0] -= 1
        craftedDurability[id] = min(100, current + Self.repairPerKit)
    }

    /// Worn pieces add up; a broken workshop piece (durability 0) gives nothing.
    public var stats: MPCChurchGearStats {
        let worn = [equippedWeaponID, equippedArmorID].compactMap { $0.flatMap(MPCChurchGearCatalog.item) }
            .filter { craftedDurability[$0.id].map { $0 > 0 } ?? true }
        return .init(attackBP: worn.map(\.stats.attackBP).reduce(0, +),
                     maxHP: worn.map(\.stats.maxHP).reduce(0, +),
                     damageReductionBP: worn.map(\.stats.damageReductionBP).reduce(0, +),
                     towerDepth: worn.compactMap(\.depth).max() ?? 0)
    }
}
