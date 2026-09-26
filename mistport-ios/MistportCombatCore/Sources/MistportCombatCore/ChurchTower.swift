import Foundation

/// Authored hundred-floor joint church operation. Chapter gates and clear
/// entitlements are separate; replay never duplicates the first-clear reward.
public enum MPCChurchTowerCatalog {
    public enum Species: String, Codable, Sendable {
        case riftHound = "church_d00_rift_hound"
        case shieldJaw = "church_d01_shield_jaw"
        case saltSac = "church_d02_salt_sac"
        case backSac = "church_d03_back_sac"
        case scissor = "church_d04_scissor"
        case crown = "church_d05_crown"
        case boneclaw = "church_d06_boneclaw"
        case copperback = "church_d07_copperback"
        case crimsonBrute = "church_d08_crimson_brute"
        case veilOracle = "church_d09_veil_oracle"
        case goldenThroat = "church_d10_golden_throat"
        case moonfang = "church_d11_moonfang"
        public var name: String {
            switch self {
            case .riftHound: return "裂隙猎犬"
            case .shieldJaw: return "盾颚魔"
            case .saltSac: return "盐囊瘴魔"
            case .backSac: return "囊背寄魔"
            case .scissor: return "剪肢螳魔"
            case .crown: return "裂冠啸魔"
            case .boneclaw: return "骨爪掠魔"
            case .copperback: return "铜背甲兽"
            case .crimsonBrute: return "赤蛮魔"
            case .veilOracle: return "绯幕先知"
            case .goldenThroat: return "金喉树蛙"
            case .moonfang: return "月牙鼠"
            }
        }
    }
    public struct Enemy: Equatable, Sendable {
        public let species: Species
        public let hp: Int
        public let attack: Int
        public let interval: Double
        public let initialDelay: Double
        public let elite: Bool
        public init(species: Species, hp: Int, attack: Int, interval: Double, initialDelay: Double, elite: Bool = false) {
            self.species = species; self.hp = hp; self.attack = attack
            self.interval = interval; self.initialDelay = initialDelay; self.elite = elite
        }
    }
    public struct Reward: Codable, Equatable, Sendable {
        public let coins: Int
        public let merit: Int
    }
    public struct Floor: Identifiable, Equatable, Sendable {
        public let number: Int
        public let title: String
        public let waves: [[Enemy]]
        public var enemies: [Enemy] { waves.first ?? [] }
        public init(number: Int, title: String, enemies: [Enemy]) { self.init(number: number, title: title, waves: [enemies]) }
        public init(number: Int, title: String, waves: [[Enemy]]) { self.number = number; self.title = title; self.waves = waves }
        public var id: String { String(format: "church_tower_%03d", number) }
        public var requiredMission: Int {
            switch number { case ...10: return 0; case ...30: return 10; case ...50: return 13; case ...70: return 16; default: return 20 }
        }
        public func enemyID(slot: Int) -> String { enemyID(wave: 0, slot: slot) }
        public func enemyID(wave: Int, slot: Int) -> String {
            waves[wave][slot].species.rawValue + (number <= 10 ? String(format: "_f%02d_s%d", number, slot) : String(format: "_f%03d_w%d_s%d", number, wave, slot))
        }
        public var encounter: MPCEncounterContent {
            MPCEncounterContent(id: id, name: title, investigationID: "church_tower", waves: waves.indices.map { w in .init(enemyIDs: waves[w].indices.map { enemyID(wave: w, slot: $0) }) }, companionSlots: 0, fixedRewardItemIDs: [], firstClearRelicID: nil, recommendedTags: ["church_tower"])
        }
        public var firstClearReward: Reward { Reward(coins: 8 + 2 * ((number - 1) / 10), merit: 2 + (number - 1) / 30) }
    }
    public static let releasedFloorCount = 100
    public static let unlockMission = 7
    public static func isUnlocked(completedMissionNumbers: Set<Int>) -> Bool {
        true // User explicitly opened the church before the former Q7 gate.
    }
    public static func floor(number: Int) -> Floor? { floors.first { $0.number == number } }
    public static func encounter(id: String) -> MPCEncounterContent? { floors.first { $0.id == id }?.encounter }
    private static let configurations: [String: Enemy] = {
        var result: [String: Enemy] = [:]
        for floor in floors { for wave in floor.waves.indices { for slot in floor.waves[wave].indices {
            result[floor.enemyID(wave: wave, slot: slot)] = floor.waves[wave][slot]
        } } }
        return result
    }()
    public static func enemyConfiguration(contentID: String) -> Enemy? { configurations[contentID] ?? MPCChurchMaintenanceCatalog.enemyConfiguration(contentID: contentID) }
    public static func isShieldJaw(_ id: String) -> Bool { id.hasPrefix(Species.shieldJaw.rawValue + "_") }
    public static func isRiftHound(_ id: String) -> Bool { id.hasPrefix(Species.riftHound.rawValue + "_") }
    public static func enemyDefinition(id: String) -> MPCEnemyContent? {
        guard let e = enemyConfiguration(contentID: id) else { return nil }
        let pattern: [String]
        switch e.species {
        case .riftHound: pattern = ["charge", "tower_flame_first", "tower_flame_second", "recover"] + (id.contains("_w") ? ["tower_pounce_charge", "tower_hound_pounce", "recover"] : [])
        case .shieldJaw: pattern = ["guard", "charge", "archive_slam", "recover"]
        case .saltSac: pattern = ["tower_sac_charge", "tower_poison", "tower_salt_spike", "recover"]
        case .backSac: pattern = ["tower_mend_charge", "tower_mend", "tower_short_pounce", "recover"]
        case .scissor: pattern = ["tower_blade_charge", "tower_cut_first", "tower_cut_second", "tower_raised_blade", "tower_heavy_cut", "recover"]
        case .crown: pattern = ["tower_crown_charge", "tower_empower", "tower_sound_arrow", "recover"]
        case .boneclaw: pattern = ["tower_claw_charge", "tower_piercing_claw", "tower_tail_sweep", "tower_claw_charge", "tower_heavy_claw", "recover"]
        case .copperback, .crimsonBrute, .veilOracle, .goldenThroat, .moonfang:
            let stem: String
            switch e.species {
            case .copperback: stem = "copperback"
            case .crimsonBrute: stem = "brute"
            case .veilOracle: stem = "veil"
            case .goldenThroat: stem = "throat"
            default: stem = "moonfang"
            }
            pattern = ["tower_" + stem + "_charge", "tower_" + stem + "_first", "tower_" + stem + "_charge2", "tower_" + stem + "_second", "recover"]
        }
        return MPCEnemyContent(id: id, name: e.species.name + (e.elite ? " · 精英" : ""), rank: e.elite ? .elite : .normal, maxHP: e.hp, attack: e.attack, defense: 8, intentPattern: pattern, teachingPurpose: "联封深井", skills: [])
    }
    /// Full cycle: the jaw exposes itself while charging; two fireballs have
    /// separate contact events. Recovery remains a genuine output window.
    public static func preparationDuration(contentID: String, intent: String) -> Double? {
        guard enemyConfiguration(contentID: contentID) != nil else { return nil }
        switch intent {
        case "tower_copperback_charge", "tower_brute_charge", "tower_veil_charge", "tower_throat_charge", "tower_moonfang_charge": return 2.2
        case "tower_copperback_charge2", "tower_brute_charge2", "tower_veil_charge2", "tower_throat_charge2", "tower_moonfang_charge2": return 2.8
        case "guard": return 3
        case "charge", "tower_sac_charge", "tower_mend_charge", "tower_crown_charge": return 2
        case "tower_pounce_charge": return 1.5
        case "tower_blade_charge": return 1.6
        case "tower_raised_blade": return 3.2
        case "tower_claw_charge": return 3.5
        case "recover": return 4.5
        default: return nil
        }
    }
    /// Unity ChurchDemonPresentation actual contact callbacks. Preparation
    /// phases have their own authored durations and never use this fallback.
    public static func contactDuration(contentID: String, intent: String) -> Double {
        if let species = enemyConfiguration(contentID: contentID)?.species,
           [.copperback, .crimsonBrute, .veilOracle, .goldenThroat, .moonfang].contains(species) { return 0.5 }
        if isShieldJaw(contentID) { return 1.0 }
        return ["tower_cut_first", "tower_cut_second"].contains(intent) ? 0.35 : 0.65
    }
    private static func jaw(_ hp: Int, _ attack: Int, _ delay: Double = 6, elite: Bool = false) -> Enemy {
        Enemy(species: .shieldJaw, hp: hp, attack: attack, interval: 12, initialDelay: delay, elite: elite)
    }
    private static func sac(_ hp: Int, _ attack: Int, _ delay: Double = 4) -> Enemy {
        Enemy(species: .saltSac, hp: hp, attack: attack, interval: 11, initialDelay: delay)
    }
    private static func small(_ species: Species, _ hp: Int, _ attack: Int, _ delay: Double) -> Enemy {
        Enemy(species: species, hp: hp, attack: attack, interval: 13, initialDelay: delay)
    }
    /// Entry stays open. First five teach shield openings; six introduces finite
    /// poison. No borrowed mask or unearned Q8 card is silently supplied.
    private static let openingFloors: [Floor] = [
        Floor(number: 1, title: "石颚初醒", enemies: [jaw(620, 65, 3)]),
        Floor(number: 2, title: "石颚闭合", enemies: [jaw(750, 80), small(.copperback, 180, 18, 8), small(.copperback, 180, 18, 11)]),
        Floor(number: 3, title: "双颚错拍", enemies: [jaw(450, 45, 3), jaw(450, 45, 8), small(.copperback, 190, 19, 10), small(.copperback, 190, 19, 13)]),
        Floor(number: 4, title: "松甲时分", enemies: [jaw(950, 95), small(.goldenThroat, 195, 19, 8), small(.copperback, 195, 19, 12)]),
        Floor(number: 5, title: "第一道封线", enemies: [jaw(600, 55, 3), jaw(650, 60, 8), small(.goldenThroat, 200, 20, 10), small(.copperback, 200, 20, 13)]),
        Floor(number: 6, title: "盐囊初裂", enemies: [sac(850, 75), small(.moonfang, 205, 20, 8), small(.goldenThroat, 205, 20, 12)]),
        Floor(number: 7, title: "瘴息余痕", enemies: [sac(1050, 85), small(.moonfang, 210, 21, 8), small(.copperback, 210, 21, 12)]),
        Floor(number: 8, title: "瘴后石颚", enemies: [sac(550, 55, 3), jaw(650, 60, 8), small(.crimsonBrute, 220, 22, 10), small(.moonfang, 220, 22, 13)]),
        Floor(number: 9, title: "断续封锚", enemies: [sac(650, 60, 3), jaw(800, 75, 8), small(.crimsonBrute, 225, 22, 10), small(.goldenThroat, 225, 22, 13)]),
        Floor(number: 10, title: "守住井口", enemies: [sac(850, 65, 3), jaw(900, 80, 8, elite: true), small(.veilOracle, 235, 23, 10), small(.crimsonBrute, 235, 23, 13)])
    ]
    /// Explicit wave compositions, not one roster with a floor-number HP multiplier.
    /// Each decade changes target order, attack timing and between-wave resources.
    public static let floors: [Floor] = openingFloors + laterFloors
    private static let laterFloors: [Floor] = {
        typealias S = Species
        // Both legacy layout symbols now resolve to D01; no D00 can spawn.
        let h = S.shieldJaw, j = S.shieldJaw, p = S.saltSac, m = S.backSac
        let c = S.scissor, n = S.crown, b = S.boneclaw
        let bands: [[[[S]]]] = [
            [[[p]], [[h,p]], [[p,j]], [[h],[p]], [[h,p,j]], [[j],[p,h]], [[p],[j,h]], [[h,j],[p]], [[p,h],[j]], [[h],[p,j]]],
            [[[m,h]], [[j,m]], [[p,m,h]], [[h],[m,j]], [[j,h,m]], [[p],[h,m]], [[j],[p,m]], [[h,p],[m,j]], [[j,h],[p,m]], [[h,p],[m,j,h]]],
            [[[c]], [[c,h]], [[c,j]], [[p],[c]], [[c,h,j]], [[c],[p,h]], [[j,c],[h]], [[p,j],[c]], [[c,h],[p]], [[c,j],[c,h,p]]],
            [[[n,h]], [[n,j]], [[n,c]], [[p],[n,h]], [[n,j,m]], [[c],[n,p]], [[j,h],[n,m]], [[n,c],[p,j]], [[h,p],[n,c]], [[n,h],[n,j,m]]],
            [[[b]], [[b,h]], [[b,j]], [[p],[b]], [[b,h,j]], [[c],[b,p]], [[j,b],[h]], [[p,j],[b]], [[b,h],[c]], [[j,h],[b,p]]],
            [[[c,h],[b]], [[p],[b,j]], [[b,c],[h]], [[j],[b,p]], [[c,h],[b,m]], [[p,j],[b,h]], [[c],[p,j],[b]], [[h,p],[b,c]], [[j,c],[b,m]], [[c,h],[p,j],[b,m]]],
            [[[j,c],[h,p]], [[h],[m,j,c]], [[p,j],[c,h]], [[c],[h,p],[m,j]], [[j,c],[h],[m,p]], [[h,p],[c,j]], [[j,h],[p],[m,c]], [[c,p],[h,j]], [[j,c],[p,h]], [[j,c],[h,p],[m,j,c]]],
            [[[n,p],[c,j]], [[b,h],[p,j]], [[c,j],[n,m]], [[p],[b,n]], [[n,c],[b,j]], [[h,p],[n,b]], [[j,c],[b,m]], [[n,h],[p],[b,c]], [[c,j],[n,p]], [[n,p],[c,j],[b,h,m,j]]],
            [[[h,j,c],[b,p]], [[n,h],[c],[b,j]], [[p,j],[b],[n,m]], [[c,h],[b,p],[n,j]], [[n,c],[b,h],[p,j]], [[h,p],[c,b],[n,j]], [[j,c],[b],[n,m,h]], [[n,p],[b,j],[c,h]], [[h,j],[c,p],[b,n]], [[h,j,c],[b,p],[n,j,m,c]]]
        ]
        // Replace only authored ordinary D01 slots; preserve every wave/body budget.
        let minions: [Int: (Int, Int, S)] = [
            12: (0,0,.copperback),
            22: (0,0,.goldenThroat), 24: (0,0,.copperback),
            32: (0,1,.crimsonBrute), 33: (0,1,.goldenThroat), 36: (1,1,.copperback),
            42: (0,1,.moonfang), 44: (1,1,.copperback), 45: (0,1,.goldenThroat), 47: (0,0,.crimsonBrute),
            52: (0,1,.copperback), 53: (0,1,.goldenThroat), 55: (0,1,.crimsonBrute), 57: (0,0,.moonfang),
            61: (0,1,.copperback), 62: (1,1,.veilOracle), 64: (0,0,.goldenThroat), 65: (0,1,.crimsonBrute), 66: (0,1,.moonfang),
            71: (0,0,.copperback), 72: (0,0,.goldenThroat), 73: (0,1,.crimsonBrute), 74: (1,0,.moonfang), 75: (0,0,.veilOracle),
            81: (1,1,.copperback), 82: (0,1,.goldenThroat), 83: (0,1,.crimsonBrute), 85: (1,1,.moonfang), 86: (0,0,.veilOracle),
            91: (0,0,.copperback), 92: (0,1,.goldenThroat), 93: (0,1,.crimsonBrute), 94: (0,1,.moonfang), 95: (1,1,.veilOracle)
        ]
        let titles = ["盐息辨界", "回收寄囊", "剪刃封线", "裂冠回响", "骨爪深痕", "错拍围封", "三锚合流", "深界共振", "百层联封"]
        return bands.enumerated().flatMap { band, layouts in
            layouts.enumerated().map { offset, layout in
                let number = 11 + band * 10 + offset
                let waves = layout.enumerated().map { wave, species in
                    let authored = species.enumerated().map { slot, kind in
                        let elite = offset == 9 && wave == layout.count - 1 && slot == 0
                        // Body budgets vary by role and number of waves, never floor index.
                        let bodyHP: Int = kind == .backSac ? 430 : kind == .crown ? 470 : kind == .shieldJaw ? 600 : kind == .boneclaw ? 680 : 540
                        let hp = bodyHP + (elite ? 180 : 0) + (layout.count == 1 ? 140 : 0)
                        let attack: Int = kind == .boneclaw ? 55 : kind == .scissor ? 42 : kind == .backSac ? 28 : kind == .saltSac ? 36 : 45
                        let replacement = minions[number]
                        let selected = replacement?.0 == wave && replacement?.1 == slot ? replacement!.2 : kind
                        precondition(selected == kind || (kind == .shieldJaw && !elite), "Minions must replace ordinary shield-jaw slots")
                        return Enemy(species: selected, hp: hp, attack: attack + (elite ? 8 : 0), interval: 10, initialDelay: 3 + Double(slot) * 3.5, elite: elite)
                    }
                    // Keep the authored major threats, then form a readable
                    // escort group of two actual D07–D11 small-monster models.
                    let escortSpecies: [Species] = [.copperback, .goldenThroat, .moonfang, .crimsonBrute, .veilOracle]
                    var majors = authored.filter { ![S.copperback, .goldenThroat, .moonfang, .crimsonBrute, .veilOracle].contains($0.species) }
                    var escorts = authored.filter { [S.copperback, .goldenThroat, .moonfang, .crimsonBrute, .veilOracle].contains($0.species) }
                    if majors.count > 2 { majors = Array(majors.prefix(2)) }
                    while escorts.count < 2 {
                        let kind = escortSpecies[(band + offset + wave + escorts.count) % escortSpecies.count]
                        escorts.append(small(kind, 210 + band * 19, 20 + band * 2,
                            8 + Double(escorts.count) * 3))
                    }
                    return Array((majors + escorts).prefix(4))
                }
                return Floor(number: number, title: titles[band] + " · " + String(offset + 1), waves: waves)
            }
        }
    }()

}

/// Persist this value together with the returned currency delta in the same save.
/// Defeat/withdrawal do not call claimVictory and cannot roll back earlier clears.
public struct MPCChurchTowerProgress: Codable, Equatable, Sendable {
    public private(set) var clearedFloors: Set<Int>
    public init(clearedFloors: Set<Int> = []) {
        self.clearedFloors = clearedFloors
    }
    public func canEnter(_ floor: Int, completedMissionNumbers: Set<Int>) -> Bool {
        guard MPCChurchTowerCatalog.isUnlocked(completedMissionNumbers: completedMissionNumbers),
              let definition = MPCChurchTowerCatalog.floor(number: floor),
              definition.requiredMission == 0 || completedMissionNumbers.contains(definition.requiredMission) else { return false }
        return floor == 1 || (1..<floor).allSatisfy { clearedFloors.contains($0) }
    }
    public var nextFloor: Int? {
        (1...MPCChurchTowerCatalog.releasedFloorCount).first { !clearedFloors.contains($0) }
    }
    @discardableResult
    public mutating func claimVictory(floor: Int, completedMissionNumbers: Set<Int>) -> MPCChurchTowerCatalog.Reward? {
        guard canEnter(floor, completedMissionNumbers: completedMissionNumbers),
              !clearedFloors.contains(floor), let definition = MPCChurchTowerCatalog.floor(number: floor) else { return nil }
        clearedFloors.insert(floor)
        return definition.firstClearReward
    }
}
