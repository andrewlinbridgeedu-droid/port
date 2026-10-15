import Foundation

/// Workshop rules agreed 2026-09-29 (DAILY_LOOP_AND_ECONOMY_20260929.md §4.2):
/// the workshop opens after Q5; every tower demon drops its own material on every
/// win, first clear or replay; four basic recipes anyone can make; workshop gear by
/// tier (MPCChurchGearCatalog.craftTiers); NPC orders with a daily budget.
/// Extra hours earn copper, never a lead: gear tiers follow the story and the tower,
/// proficiency grows only from the day's first crafts, and NPC money is finite.

public enum MPCTowerMaterials {
    public static let hide = MPCLocalWorkshopLedger.hideID
    public static let gland = "material_salt_sac_gland"
    public static let membrane = "material_back_sac_membrane"
    public static let chitin = "material_scissor_chitin"
    public static let silk = "material_crown_resonance_silk"
    public static let talon = "material_boneclaw_talon"
    public static let fiber = "material_throat_fiber"
    public static let scale = "material_demon_scale"
    /// Which tower demon drops a material (for item sources); scale comes from every minion.
    public static func species(for materialID: String) -> MPCChurchTowerCatalog.Species? {
        switch materialID {
        case hide: return .shieldJaw
        case gland: return .saltSac
        case membrane: return .backSac
        case chitin: return .scissor
        case silk: return .crown
        case talon: return .boneclaw
        case fiber: return .goldenThroat
        default: return nil
        }
    }

    public static func material(for species: MPCChurchTowerCatalog.Species) -> String {
        switch species {
        case .shieldJaw: hide
        case .saltSac: gland
        case .backSac: membrane
        case .scissor: chitin
        case .crown: silk
        case .boneclaw: talon
        case .goldenThroat: fiber
        case .riftHound, .copperback, .crimsonBrute, .veilOracle, .moonfang: scale
        }
    }

    /// One unit per body on the floor, for every victory (first clear or replay).
    public static func drops(floor: Int) -> [String: Int] {
        guard let definition = MPCChurchTowerCatalog.floor(number: floor) else { return [:] }
        return definition.waves.flatMap { $0 }.reduce(into: [:]) { $0[material(for: $1.species), default: 0] += 1 }
    }
}

public struct MPCCraftRecipe: Equatable, Sendable, Identifiable {
    public enum Craft: String, Codable, Sendable, CaseIterable { case leather, alchemy, metal, weaving }
    public let id: String
    public let name: String
    public let craft: Craft
    public let inputs: [String: Int]
    /// Base stock bought at the bench, in copper.
    public let copper: Int
    /// An inventory item, or a workshop gear ID (see `isGear`).
    public let output: String
    public let outputCount: Int
    /// Opens once any mission at or past this one is completed.
    public let requiredMission: Int
    public let requiredProficiency: Int
    public var isGear: Bool { MPCChurchGearCatalog.item(output) != nil }
}

public enum MPCCraftingCatalog {
    /// User decision 2026-09-29: from Q5 (day 3 under daily pacing), not Q16.
    public static let unlockMission = 5
    public static let salveID = "consumable_pain_salve"
    public static let clothID = "crafted_filter_cloth"
    public static var strapID: String { MPCLocalWorkshopLedger.strapID }
    public static var patchID: String { MPCChurchGearLedger.bladeKitID }

    public static func isUnlocked(completedMissions: Set<Int>) -> Bool {
        completedMissions.contains { $0 >= unlockMission }
    }

    typealias M = MPCTowerMaterials
    public static let basics: [MPCCraftRecipe] = [
        .init(id: "recipe_repair_strap", name: "维修绑带", craft: .leather, inputs: [M.hide: 1], copper: 13,
              output: MPCLocalWorkshopLedger.strapID, outputCount: 3, requiredMission: unlockMission, requiredProficiency: 0),
        .init(id: "recipe_pain_salve", name: "止痛膏", craft: .alchemy, inputs: [M.gland: 1], copper: 10,
              output: salveID, outputCount: 1, requiredMission: unlockMission, requiredProficiency: 0),
        .init(id: "recipe_armor_patch", name: "修甲片", craft: .metal, inputs: [M.scale: 2], copper: 8,
              output: MPCChurchGearLedger.bladeKitID, outputCount: 2, requiredMission: unlockMission, requiredProficiency: 0),
        .init(id: "recipe_filter_cloth", name: "过滤布", craft: .weaving, inputs: [M.fiber: 2], copper: 8,
              output: clothID, outputCount: 2, requiredMission: unlockMission, requiredProficiency: 0)
    ]

    /// Blade (metal) and mail (leather) per tier; missions match the tower bands
    /// (F11–30 after Q10, F31–50 after Q13, F51–70 after Q16, F71–100 after Q20).
    public static let gear: [MPCCraftRecipe] = {
        let plan: [(tier: Int, mission: Int, proficiency: Int, copper: Int, blade: [String: Int], mail: [String: Int])] = [
            (10, unlockMission, 0, 40, [M.scale: 4, M.hide: 2], [M.hide: 4, M.scale: 2]),
            (30, 10, 4, 80, [M.scale: 6, M.membrane: 3], [M.hide: 6, M.membrane: 3]),
            (50, 13, 8, 120, [M.chitin: 4, M.silk: 2], [M.hide: 6, M.chitin: 3, M.silk: 1]),
            (70, 16, 12, 160, [M.talon: 4, M.chitin: 3], [M.talon: 3, M.hide: 6]),
            (90, 20, 16, 200, [M.talon: 4, M.silk: 3, M.chitin: 3], [M.talon: 4, M.silk: 3, M.hide: 6])
        ]
        return plan.flatMap { row -> [MPCCraftRecipe] in
            let blade = MPCChurchGearCatalog.craftedPiece(tier: row.tier, slot: .weapon)!
            let mail = MPCChurchGearCatalog.craftedPiece(tier: row.tier, slot: .armor)!
            return [
                .init(id: "recipe_\(blade.id)", name: blade.name, craft: .metal, inputs: row.blade, copper: row.copper,
                      output: blade.id, outputCount: 1, requiredMission: row.mission, requiredProficiency: row.proficiency),
                .init(id: "recipe_\(mail.id)", name: mail.name, craft: .leather, inputs: row.mail, copper: row.copper,
                      output: mail.id, outputCount: 1, requiredMission: row.mission, requiredProficiency: row.proficiency)
            ]
        }
    }()

    public static let all: [MPCCraftRecipe] = basics + gear
    public static func recipe(_ id: String) -> MPCCraftRecipe? { all.first { $0.id == id } }
    /// Base stock actually paid once the city's surcharge or discount applies; never below zero.
    public static func baseStock(_ recipe: MPCCraftRecipe, surcharge: Int = 0) -> Int { max(0, recipe.copper + surcharge) }
    public static func isOpen(_ recipe: MPCCraftRecipe, completedMissions: Set<Int>) -> Bool {
        completedMissions.contains { $0 >= recipe.requiredMission }
    }
}

/// One save's crafting: proficiency per craft, grown only by the day's first five
/// successful crafts, and receipts so a replayed command never crafts twice.
public struct MPCCraftingLedger: Codable, Equatable, Sendable {
    public enum Failure: Error, Equatable { case unknown, locked, proficiency, stock, funds, owned }
    public static let proficiencyCraftsPerDay = 5
    /// Chapter one stops here; higher work belongs to the chosen main profession (2026-09-28).
    public static let proficiencyCap = 20

    public private(set) var proficiency: [String: Int] = [:]
    public private(set) var day = 0
    public private(set) var proficiencyCraftsToday = 0
    public private(set) var receipts: Set<String> = []
    public init() {}

    public func points(_ craft: MPCCraftRecipe.Craft) -> Int { proficiency[craft.rawValue, default: 0] }

    /// Validates everything first, then pays, consumes and produces in one step.
    /// Goods go to the inventory; gear goes to the gear ledger (not worn).
    @discardableResult
    /// `surcharge` is the city's change to base-stock prices (MPCCityEventLedger.effects).
    public mutating func craft(receiptID: String, recipeID: String, day: Int, completedMissions: Set<Int>,
                               coins: inout Int, inventory: inout [String: Int], gear: inout MPCChurchGearLedger,
                               surcharge: Int = 0) throws -> Bool {
        if receipts.contains(receiptID) { return false }
        guard let recipe = MPCCraftingCatalog.recipe(recipeID) else { throw Failure.unknown }
        guard MPCCraftingCatalog.isOpen(recipe, completedMissions: completedMissions) else { throw Failure.locked }
        guard points(recipe.craft) >= recipe.requiredProficiency else { throw Failure.proficiency }
        guard recipe.inputs.allSatisfy({ inventory[$0.key, default: 0] >= $0.value }) else { throw Failure.stock }
        let cost = MPCCraftingCatalog.baseStock(recipe, surcharge: surcharge)
        guard coins >= cost else { throw Failure.funds }
        if recipe.isGear && gear.ownedIDs.contains(recipe.output) { throw Failure.owned }

        coins -= cost
        for (id, count) in recipe.inputs { inventory[id, default: 0] -= count }
        if recipe.isGear { gear.grant(recipe.output) } else { inventory[recipe.output, default: 0] += recipe.outputCount }
        if day > self.day { self.day = day; proficiencyCraftsToday = 0 }
        if proficiencyCraftsToday < Self.proficiencyCraftsPerDay && points(recipe.craft) < Self.proficiencyCap {
            proficiency[recipe.craft.rawValue, default: 0] += 1
            proficiencyCraftsToday += 1
        }
        receipts.insert(receiptID)
        return true
    }
}

/// Clinic, harbour office and church buy workshop goods with a finite daily budget.
/// Unspent money carries over for at most three days, so skipping a day costs little
/// and hoarding days is capped. In a single save this budget is new copper; a shared
/// economy must count it as issuance.
public struct MPCWorkshopOrderBoard: Codable, Equatable, Sendable {
    public enum Failure: Error, Equatable { case notBought, stock, budget }
    public static let dailyBudget = 60
    public static let carriedDays = 3
    public static var prices: [String: Int] {
        [MPCCraftingCatalog.strapID: 9, MPCCraftingCatalog.salveID: 24, MPCCraftingCatalog.patchID: 8, MPCCraftingCatalog.clothID: 8]
    }

    public private(set) var day = 0
    public private(set) var budget = 0
    /// Everything the board has ever paid.
    public private(set) var paid = 0
    public private(set) var receipts: [String: Int] = [:]
    public init() {}

    /// Adds each new day's money, keeping at most three days' worth. `bonus` is the
    /// city's change to the daily budget (MPCCityEventLedger.effects), as of that day.
    public mutating func open(day: Int, bonus: Int = 0) {
        guard day > self.day else { return }
        let daily = max(0, Self.dailyBudget + bonus)
        budget = max(0, min(daily * Self.carriedDays, budget + daily * (day - self.day)))
        self.day = day
    }

    /// Sells up to `count` units, as many as today's money covers. Returns units sold;
    /// a replayed receipt returns its first result without paying again.
    @discardableResult
    public mutating func sell(receiptID: String, itemID: String, count: Int, day: Int,
                              coins: inout Int, inventory: inout [String: Int], bonus: Int = 0) throws -> Int {
        if let done = receipts[receiptID] { return done }
        guard let price = Self.prices[itemID] else { throw Failure.notBought }
        open(day: day, bonus: bonus)
        let units = min(count, inventory[itemID, default: 0], budget / price)
        guard count > 0, inventory[itemID, default: 0] >= 1 else { throw Failure.stock }
        guard units > 0 else { throw Failure.budget }
        inventory[itemID, default: 0] -= units
        coins += units * price; budget -= units * price; paid += units * price
        receipts[receiptID] = units
        return units
    }
}
