import Foundation

/// Equipment earned in the church tower and on closed bounty cases. These
/// bonuses enter the same encounter loadout as cards and relics, so the reward
/// changes actual combat rather than only the character-sheet power number.
public struct MPCChurchGearStats: Equatable, Sendable {
    public var attackBP: Int
    public var maxHP: Int
    public var damageReductionBP: Int

    public init(attackBP: Int = 0, maxHP: Int = 0, damageReductionBP: Int = 0) {
        self.attackBP = attackBP
        self.maxHP = maxHP
        self.damageReductionBP = damageReductionBP
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
}

public enum MPCChurchGearCatalog {
    private static func weapon(_ id: String, _ name: String, _ source: String, _ attackBP: Int) -> MPCChurchGearItem {
        .init(id: id, name: name, slot: .weapon, stats: .init(attackBP: attackBP), source: source)
    }
    private static func armor(_ id: String, _ name: String, _ source: String, _ hp: Int, _ reductionBP: Int) -> MPCChurchGearItem {
        .init(id: id, name: name, slot: .armor, stats: .init(maxHP: hp, damageReductionBP: reductionBP), source: source)
    }

    public static let all: [MPCChurchGearItem] = [
        weapon("tower-f02-jaw-edge", "石颚裂刃", "深井第2层", 1_500),
        armor("tower-f04-seal-plate", "井口封甲", "深井第4层", 160, 700),
        weapon("tower-f06-salt-knife", "盐痕短刀", "深井第6层", 2_500),
        armor("tower-f08-joint-guard", "双颚护胄", "深井第8层", 270, 1_100),
        weapon("tower-f10-anchor-blade", "首锚断刃", "深井第10层", 3_600),
        armor("tower-f20-mist-mail", "盐雾层甲", "深井第20层", 330, 1_400),
        weapon("tower-f30-archive-edge", "暗渠档刃", "深井第30层", 4_100),
        armor("tower-f40-scissor-mail", "断桥刃甲", "深井第40层", 390, 1_650),
        weapon("tower-f50-crown-edge", "冠鸣裂锋", "深井第50层", 4_600),
        armor("tower-f60-bone-mail", "骨爪封甲", "深井第60层", 450, 1_850),
        weapon("tower-f70-joint-edge", "合流断锋", "深井第70层", 5_100),
        armor("tower-f80-deep-mail", "沉井护胄", "深井第80层", 510, 2_050),
        weapon("tower-f90-rift-edge", "裂隙封刃", "深井第90层", 5_600),
        armor("tower-f100-last-seal", "终界封甲", "深井第100层", 580, 2_250),
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
    public static func item(_ id: String) -> MPCChurchGearItem? { all.first { $0.id == id } }
    public static func towerDrop(floor: Int) -> MPCChurchGearItem? {
        all.first { $0.source == "深井第\(floor)层" }
    }
    public static func bountyDrop(caseID: String) -> MPCChurchGearItem? {
        all.first { $0.source == "通缉 \(caseID.uppercased())" }
    }
}

public struct MPCChurchGearLedger: Codable, Equatable, Sendable {
    public private(set) var ownedIDs: Set<String> = []
    public private(set) var equippedWeaponID: String?
    public private(set) var equippedArmorID: String?
    public init() {}

    /// First-clear/first-case claims are idempotent. A stronger newly earned
    /// piece is worn automatically, but every owned piece remains selectable.
    @discardableResult public mutating func grant(_ id: String) -> Bool {
        guard let item = MPCChurchGearCatalog.item(id), ownedIDs.insert(id).inserted else { return false }
        let currentID = item.slot == .weapon ? equippedWeaponID : equippedArmorID
        if currentID.flatMap(MPCChurchGearCatalog.item)?.strength ?? -1 < item.strength {
            if item.slot == .weapon { equippedWeaponID = id } else { equippedArmorID = id }
        }
        return true
    }
    @discardableResult public mutating func equip(_ id: String) -> Bool {
        guard ownedIDs.contains(id), let item = MPCChurchGearCatalog.item(id) else { return false }
        if item.slot == .weapon { equippedWeaponID = id } else { equippedArmorID = id }
        return true
    }
    public var stats: MPCChurchGearStats {
        let weapon = equippedWeaponID.flatMap(MPCChurchGearCatalog.item)?.stats ?? .init()
        let armor = equippedArmorID.flatMap(MPCChurchGearCatalog.item)?.stats ?? .init()
        return .init(attackBP: weapon.attackBP, maxHP: armor.maxHP, damageReductionBP: armor.damageReductionBP)
    }
}
