import CoreGraphics
import SwiftUI

enum VenueKind: String {
    case cafe
    case restaurant
}

enum VenueItemRarity: Int, Comparable {
    case common
    case uncommon
    case rare

    static func < (lhs: VenueItemRarity, rhs: VenueItemRarity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var title: String {
        switch self {
        case .common: "常见"
        case .uncommon: "特别"
        case .rare: "隐秘"
        }
    }

    var tint: Color {
        switch self {
        case .common: .white
        case .uncommon: .cyan
        case .rare: .yellow
        }
    }
}

enum VenueItemCategory: String, Hashable {
    case provision
    case intelligence
    case crafting
    case advancement
}

struct VenueItemDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let symbol: String
    let artName: String?
    let category: VenueItemCategory
    /// 1 = 序列 9 / 第一章。后续章节使用同谱系的更高阶版本，而非重复投放本物品。
    let progressionTier: Int
    let price: Int
    let rarity: VenueItemRarity
    let grantsAdvancementMaterial: Bool
}

struct VenueOffer: Identifiable, Hashable {
    let id: String
    let item: VenueItemDefinition
    var isSold = false
}

struct VenueDefinition: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let kind: VenueKind
    let position: CGPoint
    let backgroundArtName: String
    let ownerName: String
    let ownerTitle: String
    let ownerArtName: String
    let greeting: String
    let catalog: [VenueItemDefinition]
}

extension GameContent {
    static let oldClockVenues: [VenueDefinition] = [
        VenueDefinition(
            id: "midnight-clock-cafe",
            name: "午夜钟咖啡馆",
            subtitle: "热饮、传闻与雨夜来客",
            kind: .cafe,
            position: CGPoint(x: 13_028, y: 12_588),
            backgroundArtName: "SceneMidnightClockCafeV2",
            ownerName: "莫莉·温恩",
            ownerTitle: "咖啡馆主人",
            ownerArtName: "PortraitMollyWynn",
            greeting: "进来避雨吧。菜单每天一样，柜台下面的东西可不一定。",
            catalog: [
                VenueItemDefinition(id: "clock-coffee", name: "十二响黑咖啡", detail: "下一场战斗首次技能冷却缩短。", symbol: "cup.and.saucer.fill", artName: "ItemClockCoffee", category: .provision, progressionTier: 1, price: 12, rarity: .common, grantsAdvancementMaterial: false),
                VenueItemDefinition(id: "fog-sugar", name: "雾糖方块", detail: "恢复少量侵蚀耐受。", symbol: "cube.fill", artName: "ItemFogSugar", category: .provision, progressionTier: 1, price: 18, rarity: .common, grantsAdvancementMaterial: false),
                VenueItemDefinition(id: "rain-rumor", name: "写在杯底的传闻", detail: "显示本区一个隐藏材料点。", symbol: "eye.fill", artName: "ItemRainRumor", category: .intelligence, progressionTier: 1, price: 28, rarity: .uncommon, grantsAdvancementMaterial: false),
                VenueItemDefinition(id: "memory-bean", name: "记忆烘焙豆", detail: "可用于制作灵性恢复剂。", symbol: "leaf.fill", artName: "ItemMemoryBean", category: .crafting, progressionTier: 1, price: 34, rarity: .uncommon, grantsAdvancementMaterial: false),
                VenueItemDefinition(id: "ownerless-spring", name: "无主灵摆簧", detail: "序列晋阶演证所需的稀有辅材。", symbol: "clock.badge.exclamationmark.fill", artName: "ItemOwnerlessSpring", category: .advancement, progressionTier: 1, price: 88, rarity: .rare, grantsAdvancementMaterial: true)
            ]
        ),
        VenueDefinition(
            id: "copper-key-restaurant",
            name: "铜匙餐厅",
            subtitle: "炖锅、熟客与秘密菜单",
            kind: .restaurant,
            position: CGPoint(x: 12_572, y: 13_008),
            backgroundArtName: "SceneCopperKeyRestaurantV2",
            ownerName: "巴托·铜勺",
            ownerTitle: "餐厅老板",
            ownerArtName: "PortraitBartoCopperSpoon",
            greeting: "先吃饭，后谈怪物。若钟声响到第十三下，就别碰桌上的银匙。",
            catalog: [
                VenueItemDefinition(id: "gear-stew", name: "齿轮牛肉炖锅", detail: "下一场战斗最大生命提高。", symbol: "takeoutbag.and.cup.and.straw.fill", artName: nil, category: .provision, progressionTier: 1, price: 20, rarity: .common, grantsAdvancementMaterial: false),
                VenueItemDefinition(id: "lamp-bread", name: "雾灯烤面包", detail: "短时间提高移动速度。", symbol: "birthday.cake.fill", artName: nil, category: .provision, progressionTier: 1, price: 16, rarity: .common, grantsAdvancementMaterial: false),
                VenueItemDefinition(id: "salt-fish", name: "反潮盐鱼", detail: "下一次水系伤害降低。", symbol: "fish.fill", artName: nil, category: .provision, progressionTier: 1, price: 30, rarity: .uncommon, grantsAdvancementMaterial: false),
                VenueItemDefinition(id: "off-menu-note", name: "秘密菜单背页", detail: "记录一名归一议会联络人的行踪。", symbol: "doc.text.fill", artName: nil, category: .intelligence, progressionTier: 1, price: 42, rarity: .uncommon, grantsAdvancementMaterial: false),
                VenueItemDefinition(id: "echo-marrow", name: "回声兽髓", detail: "序列晋阶演证所需的稀有辅材。", symbol: "sparkles", artName: nil, category: .advancement, progressionTier: 1, price: 92, rarity: .rare, grantsAdvancementMaterial: true)
            ]
        )
    ]
}
