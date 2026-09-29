import Observation
import Foundation
import MistportCombatCore
import SwiftUI

/// Shared presentation for the two early passive relics. Existing bitmap art is
/// temporary until their dedicated illustrations are delivered.
enum EarlyRelicShop {
    static let salt = "relic_salt_sealed_breathing_bag"
    static let clasp = "relic_return_gift_clasp"
    static let stamp = "relic_deferred_stamp"
    static let mirror = "relic_reflecting_ink_mirror"
    static let paperweight = "relic_sealed_paperweight"
    static let anchor = "relic_countertide_anchor"
    static let needle = "relic_ownership_severing_needle"
    static let blankCard = "relic_blank_name_card"
    static let ids = [salt, clasp, stamp, mirror, blankCard, paperweight, anchor, needle]
    static let activeIDs = [MPCChapterOneCatalog.ownerlessMaskRelicID, MPCChapterOneCatalog.usurpedLifeMedalRelicID, blankCard]
    static var passiveIDs: [String] { ids.filter { !activeIDs.contains($0) } }
    static func price(_ id: String) -> Int? {
        [salt: 120, clasp: 160, stamp: 360, mirror: 520, paperweight: 400, anchor: 640, needle: 720, blankCard: 680][id]
    }
    static func unlock(_ id: String) -> Int {
        [salt: 4, clasp: 4, stamp: 9, mirror: 14, paperweight: 18, anchor: 20, needle: 26, blankCard: 17][id] ?? 31
    }
    static func name(_ id: String) -> String {
        [salt: "盐封呼吸囊", clasp: "返礼银扣", stamp: "迟签印章", mirror: "反照墨镜", paperweight: "缄卷镇纸", anchor: "逆潮铜锚", needle: "归属断线针", blankCard: "空栏名片"][id] ?? "遗落物"
    }
    static func art(_ id: String) -> String {
        [salt: "RelicSaltPouch", clasp: "RelicReturnClasp", stamp: "RelicDeferredStamp", mirror: "RelicInkMirror", paperweight: "RelicPaperweight", anchor: "RelicCountertideAnchor", needle: "RelicSeveringNeedle", blankCard: "RelicBlankCard"][id] ?? "RewardMaterial"
    }
    static func detail(_ id: String) -> String {
        switch id {
        case salt: return "收容60%毒伤，容量为入场生命上限；每收容10点封存1点生命上限，战后解除但不回血。"
        case clasp: return "挡一次直伤，最多30%入场生命；给敌人所挡伤害50%的盾。8秒且礼盾消失后再次就绪。"
        case stamp: return "一笔技能直伤延后3秒，追加40%（最多15%入场生命）。12秒冷却；目标离场或届时免伤则整笔作废。"
        case mirror: return "锁定2秒后普攻先给敌人回血，换4秒内反射另一敌人一击（最多20%入场生命）。8秒冷却；落空不退，单敌不触发。"
        case paperweight: return "第3编排槽的本次技能全部封存，换4秒一次35%入场生命直伤收容。占用与卡牌冷却照常，18秒冷却；少于3牌不启动。"
        case anchor: return "同敌同招首击多受5%入场生命，随后2秒下两段共收容35%。10秒冷却；单段攻击只付代价。"
        case needle: return "截取选中敌人的外来治疗，最多20%入场生命；随后自己6秒不能回血。每场2次、12秒冷却。"
        case blankCard: return "3秒与固定敌人互不受彼此直伤。自己的技能照常消耗；其他敌人、毒伤与控制照常。18秒冷却。"
        default: return ""
        }
    }
}

/// A service requires both an authored unlock milestone and a released gameplay loop.
/// The church is always open; the workshop opens after Q5 (MPCCraftingCatalog.unlockMission,
/// user decision 2026-09-29); other services stay unreleased.
enum CityService: String {
    case workshop, cafe, restaurant, church, store, advancement
    var unlockMissionID: String? {
        switch self {
        case .workshop: return "old-clock-\(MPCCraftingCatalog.unlockMission)"
        case .church: return "old-clock-7"
        default: return nil // Assigned with the corresponding story/content release.
        }
    }
    var isReleased: Bool { self == .church || self == .workshop }
}

enum GameBuildPreset: String, CaseIterable, Identifiable {
    case cardChain
    case misdirection
    case boundarySurvival

    var id: String { rawValue }

    var name: String {
        switch self {
        case .cardChain: "幻牌连锁"
        case .misdirection: "错位控场"
        case .boundarySurvival: "越界生存"
        }
    }

    var role: String {
        switch self {
        case .cardChain: "远程输出"
        case .misdirection: "群体控制"
        case .boundarySurvival: "机动生存"
        }
    }

    var unlockAt: Int {
        switch self {
        case .cardChain: 5
        case .misdirection, .boundarySurvival: 15
        }
    }

}

enum AdvancementIngredient: String, CaseIterable, Identifiable {
    case mirrorMothScale
    case reverseClockEssence
    case ownerlessMaskWax

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mirrorMothScale: "星纹镜蛾鳞粉"
        case .reverseClockEssence: "逆走钟芯髓液"
        case .ownerlessMaskWax: "无主面蜡"
        }
    }

    var purchaseOffer: MPCAdvancementMaterialMarket.Offer {
        MPCAdvancementMaterialMarket.offers.first { $0.id == rawValue }!
    }
    var purchaseArt: String {
        switch self {
        case .mirrorMothScale: "RewardMaterial"
        case .reverseClockEssence: "ItemOwnerlessSpring"
        case .ownerlessMaskWax: "CityMissionWaxSeal"
        }
    }

    var traitName: String {
        switch self {
        case .mirrorMothScale: "欺光视界"
        case .reverseClockEssence: "逆时锚髓"
        case .ownerlessMaskWax: "空名蜡印"
        }
    }

    var traitDetail: String {
        switch self {
        case .mirrorMothScale: "晋阶主材：让晋阶后的灵性视野识别伪装与残影。"
        case .reverseClockEssence: "晋阶主材：为晋阶仪式固定时间锚点，降低失控回响。"
        case .ownerlessMaskWax: "晋阶主材：抹去旧身份的回声，使新能力获得稳定容器。"
        }
    }
}

@Observable
@MainActor
final class GameStore {
    /// Debug compilation alone must not unlock progression for player tests.
    static let playerTestMissionLimit = 30
    var playerTestComplete: Bool { completedChapterMissionIDs.contains("old-clock-30") }
    var playerTestMissions: [DistrictMission] {
        selectedChapterDistrict.missions.filter { $0.districtID == "old-clock" && $0.number <= Self.playerTestMissionLimit }
    }
    func missionIsInPlayerTest(_ mission: DistrictMission) -> Bool {
        mission.districtID == "old-clock" && mission.number <= Self.playerTestMissionLimit
    }
    private(set) var permitsDeveloperTools = false
    private var permitsSandboxGrowth = false
    var hasFoolTestAccess: Bool {
        permitsSandboxGrowth
    }

    private enum PersistenceKey {
        static let selectedPathID = "character.selected-path"
        static let selectedCharacterGender = "character.selected-gender"
        static let completedChapterMissionIDs = "chapter-one.completed-mission-ids"
        /// MPCDailyPacingStart: the save's day 1, written once (migration receipt for old saves).
        static let dailyPacingStart = "mistport.daily-pacing.start.v1"
        static let dailyWork = "mistport.daily-work.v1"
        static let dailyWorkshop = "mistport.daily-workshop.v1"
        static let selectedChapterDistrictID = "chapter-one.selected-district-id"
        static let venueCoins = "economy.venue-coins"
        static let ownedVenueItems = "economy.owned-venue-items"
        static let skillLevels = "growth.skill-levels"
        static let foolSkillLevels = "growth.fool-skill-levels.v1"
        static let currentSequence = "growth.current-sequence"
        static let materials = "growth.advancement-materials"
        static let advancementIngredients = "growth.advancement-ingredients"
        static let equippedWeaponID = "character.equipped-weapon"
        static let equippedSecondaryRelicID = "character.equipped-secondary-relic"
        static let selectedPassiveIDs = "character.selected-passives"
        static let selectedTalentBranchID = "character.talent-branch"
        static let equippedOutfitID = "character.equipped-outfit"
        static let skillVariants = "character.skill-variants"
        static let chapterOneTutorialFlags = "chapter-one.tutorial-flags"
        static let chapterOneBehaviorTags = "chapter-one.behavior-tags"
        static let chapterOneComboRecords = "chapter-one.combo-records"
        static let chapterOneBattleLoadout = "chapter-one.battle-loadout"
        static let debugBattlePlacementPrefix = "debug.chapter-one.player-placement."
    }

    private struct DailyWorkRecord: Codable {
        let migratedAt: Date
        var ledger: MPCDailyWorkLedger
        init() { migratedAt = Date(); ledger = .init() }
    }
    private var dailyWorkRecord = DailyWorkRecord()
    private struct DailyWorkshopRecord: Codable {
        let migratedAt: Date
        init() { migratedAt = Date() }
        var crafting = MPCCraftingLedger()
        var orders = MPCWorkshopOrderBoard()
        var towerTickets: [String: Int] = [:]
        var finishedTowerTickets: Set<String> = []
        var repairs: Set<String> = []
    }
    private var dailyWorkshopRecord = DailyWorkshopRecord()
    private let defaults: UserDefaults
    private(set) var phase: GamePhase = .title
    var chapterOneCampaign = MPCChapterOneCampaignState.chapterStartState
    /// Day 1 of this save's calendar (MPCDailyPacing). Resolved at the end of init.
    private(set) var dailyPacingStart: MPCDailyPacingStart?
    /// The clock pacing reads; debug checks replace it, the game never does.
    var pacingClock: () -> Date = { Date() }
    private(set) var chapterOneTutorialFlags: Set<String> = []
    private(set) var selectedPathID: Pathway.ID?
    private(set) var selectedCharacterGender: CharacterGender = .male
    private(set) var encounterIndex = 0
    private(set) var acting = 0
    private(set) var clues = 0
    private(set) var materials = 0
    private(set) var advancementIngredients: Set<AdvancementIngredient> = []
    /// Sequence 8 reached by the qualification-only ritual; combat still reads `currentSequence`.
    private(set) var sequenceEightRitual: MPCSequenceEightRitual.Receipt?
    private(set) var chapterTwoBridge = MPCChapterTwoBridge()
    private(set) var instability = 0
    private(set) var abilityUsed = false
    private(set) var abilityEnabled = false
    private(set) var isResolving = false
    private(set) var history: [String] = []
    private(set) var latestResult = ""
    private(set) var selectedChapterDistrictID = "old-clock"
    private(set) var activeChapterMissionID: String?
    @ObservationIgnored private var preparedChapterOneMissionID: String?
    var churchServicesRevision = 0
    @ObservationIgnored private var preparedChapterOneSession: MPCChapterOneEncounterSession?
    private(set) var isTeamExpeditionActive = false
    private(set) var completedChapterMissionIDs: Set<String> = []
    private(set) var activeVenueID: String?
    private(set) var venueOffers: [VenueOffer] = []
    private(set) var postalJobSerial = 0
    private(set) var postalJobStep = 0
    private(set) var venueCoins = 180
    private(set) var venueMessage = ""
    private(set) var ownedVenueItems: [String: Int] = [:]
    private(set) var skillLevels: [DungeonSkillID: Int] = [
        .strike: 1, .mobility: 1, .control: 1, .ward: 1, .ultimate: 1
    ]
    private(set) var foolSkillLevels: [FoolSkillID: Int] = [:]
    private(set) var featureMessage = ""
    private(set) var currentSequence = 9
    private(set) var equippedWeaponID = "silver-lie-blade"
    private(set) var equippedSecondaryRelicID = "paper-moon-token"
    private(set) var selectedPassiveIDs: [String] = ["marked-deck", "false-exit"]
    private(set) var hermitTalents = HermitTalentAllocation()
    var hermitTalentBudget: Int {
        // Confirmed story grant: Q9 awards four points. No Debug bonus or
        // per-two-missions approximation; later grants require authored milestones.
        max(chapterOneCampaign.chapterTalentPointsEarned, completedChapterMissionIDs.contains("old-clock-9") ? 4 : 0)
    }
    var hermitTalentPoints: Int { max(0, hermitTalentBudget - hermitTalents.learned.count) }
    func learnHermitTalent(_ id: String) {
        guard hermitTalents.learn(id, budget: hermitTalentBudget) else { return }
        preparedChapterOneSession = nil
        preparedChapterOneMissionID = nil
        defaults.set(Array(hermitTalents.learned).sorted(), forKey: "character.hermit-talents.v1")
    }
    func resetHermitTalents() {
        hermitTalents.reset()
        preparedChapterOneSession = nil
        preparedChapterOneMissionID = nil
        defaults.removeObject(forKey: "character.hermit-talents.v1")
    }
    private(set) var selectedTalentBranchID = "trickster"
    private(set) var equippedOutfitID = "mistport-night"
    private(set) var skillVariants: [String: String] = [:]
    private var venueVisitCounts: [String: Int] = [:]

    init(
        launchArguments: [String] = ProcessInfo.processInfo.arguments,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        if let data = defaults.data(forKey: PersistenceKey.dailyWorkshop),
           let record = try? JSONDecoder().decode(DailyWorkshopRecord.self, from: data) { dailyWorkshopRecord = record }
        if let data = defaults.data(forKey: PersistenceKey.dailyWork),
           let record = try? JSONDecoder().decode(DailyWorkRecord.self, from: data) { dailyWorkRecord = record }
        #if DEBUG
        if launchArguments.contains("--developer-tools") {
            defaults.set(true, forKey: "mistport.developer-editor.enabled")
        }
        permitsDeveloperTools = defaults.bool(forKey: "mistport.developer-editor.enabled")
            || launchArguments.contains("--verify-p1-ui")
        permitsSandboxGrowth = launchArguments.contains("--unlock-sandbox-growth")
        #endif
        completedChapterMissionIDs = Set(defaults.stringArray(forKey: PersistenceKey.completedChapterMissionIDs) ?? [])
        chapterOneTutorialFlags = Set(defaults.stringArray(forKey: PersistenceKey.chapterOneTutorialFlags) ?? [])

        #if DEBUG
        if launchArguments.contains("--reset-tutorial") {
            defaults.removeObject(forKey: Self.settlementJournalKey)
            defaults.removeObject(forKey: "mistport.campaign-inventory.v1")
            defaults.removeObject(forKey: "mistport.campaign-relics.v1")
            defaults.removeObject(forKey: "mistport.campaign-active-relic.v1")
            defaults.removeObject(forKey: "character.hermit-talents.v1")
            // A tutorial reset must also clear the persisted test-account
            // campaign. Clearing only the cue flags leaves the player in an
            // old district/mission state, which makes the reset appear not
            // to work on a physical device where app data survives rebuilds.
            defaults.removeObject(forKey: PersistenceKey.completedChapterMissionIDs)
            defaults.removeObject(forKey: PersistenceKey.selectedChapterDistrictID)
            defaults.removeObject(forKey: PersistenceKey.venueCoins)
            defaults.removeObject(forKey: PersistenceKey.ownedVenueItems)
            defaults.removeObject(forKey: PersistenceKey.skillLevels)
            defaults.removeObject(forKey: PersistenceKey.foolSkillLevels)
            defaults.removeObject(forKey: Self.skillUpgradeJournalKey)
            defaults.removeObject(forKey: PersistenceKey.currentSequence)
            for key in Self.sequenceEightRitualKeys { defaults.removeObject(forKey: key) }
            defaults.removeObject(forKey: PersistenceKey.materials)
            defaults.removeObject(forKey: PersistenceKey.advancementIngredients)
            defaults.removeObject(forKey: PersistenceKey.equippedWeaponID)
            defaults.removeObject(forKey: PersistenceKey.equippedSecondaryRelicID)
            defaults.removeObject(forKey: PersistenceKey.selectedPassiveIDs)
            defaults.removeObject(forKey: PersistenceKey.selectedTalentBranchID)
            defaults.removeObject(forKey: PersistenceKey.equippedOutfitID)
            defaults.removeObject(forKey: PersistenceKey.skillVariants)
            defaults.removeObject(forKey: PersistenceKey.chapterOneBehaviorTags)
            defaults.removeObject(forKey: PersistenceKey.chapterOneComboRecords)
            defaults.removeObject(forKey: PersistenceKey.chapterOneBattleLoadout)
            chapterOneTutorialFlags = []
            completedChapterMissionIDs = []
            defaults.removeObject(forKey: PersistenceKey.chapterOneTutorialFlags)
            selectedPathID = .fool
            phase = .districtMap
        }

        if launchArguments.contains("--reset-to-chapter-one-q4") {
            // Keep the real-device test account at the authored entrance to
            // Q4: Q1-Q3 are cleared, Q4 is the next available mission. Clear
            // later rewards/loadouts as well so this is a genuine player
            // progression state rather than only a map-label override.
            let progressKeysToClear = [
                PersistenceKey.completedChapterMissionIDs,
                PersistenceKey.dailyPacingStart,
                PersistenceKey.dailyWork,
                PersistenceKey.dailyWorkshop,
                PersistenceKey.selectedChapterDistrictID,
                PersistenceKey.venueCoins,
                PersistenceKey.ownedVenueItems,
                PersistenceKey.skillLevels,
                PersistenceKey.foolSkillLevels,
                Self.skillUpgradeJournalKey,
                PersistenceKey.currentSequence,
                Self.sequenceEightRitualKey,
                Self.sequenceEightRitualCommitKey,
                Self.chapterTwoBridgeKey,
                PersistenceKey.materials,
                PersistenceKey.advancementIngredients,
                PersistenceKey.equippedWeaponID,
                PersistenceKey.equippedSecondaryRelicID,
                PersistenceKey.selectedPassiveIDs,
                PersistenceKey.selectedTalentBranchID,
                PersistenceKey.equippedOutfitID,
                PersistenceKey.skillVariants,
                PersistenceKey.chapterOneBehaviorTags,
                PersistenceKey.chapterOneComboRecords,
                PersistenceKey.chapterOneBattleLoadout
            ]
            for key in progressKeysToClear {
                defaults.removeObject(forKey: key)
            }

            let completedMissionIDs = (1...3).map { "old-clock-\($0)" }
            defaults.set(completedMissionIDs, forKey: PersistenceKey.completedChapterMissionIDs)
            defaults.set("old-clock", forKey: PersistenceKey.selectedChapterDistrictID)
            completedChapterMissionIDs = Set(completedMissionIDs)
            selectedPathID = .fool
            phase = .districtMap
        }

        if launchArguments.contains("--reset-to-chapter-one-q3") {
            // Keep the real-device test account at the authored entrance to
            // Q3: Q1-Q2 are cleared, Q3 is the next available mission. This
            // must write persistent progress, not merely open an isolated
            // preview, otherwise the map immediately returns to the later
            // mission on the next launch.
            let progressKeysToClear = [
                PersistenceKey.completedChapterMissionIDs,
                PersistenceKey.dailyPacingStart,
                PersistenceKey.dailyWork,
                PersistenceKey.dailyWorkshop,
                PersistenceKey.selectedChapterDistrictID,
                PersistenceKey.venueCoins,
                PersistenceKey.ownedVenueItems,
                PersistenceKey.skillLevels,
                PersistenceKey.foolSkillLevels,
                Self.skillUpgradeJournalKey,
                PersistenceKey.currentSequence,
                Self.sequenceEightRitualKey,
                Self.sequenceEightRitualCommitKey,
                Self.chapterTwoBridgeKey,
                PersistenceKey.materials,
                PersistenceKey.advancementIngredients,
                PersistenceKey.equippedWeaponID,
                PersistenceKey.equippedSecondaryRelicID,
                PersistenceKey.selectedPassiveIDs,
                PersistenceKey.selectedTalentBranchID,
                PersistenceKey.equippedOutfitID,
                PersistenceKey.skillVariants,
                PersistenceKey.chapterOneBehaviorTags,
                PersistenceKey.chapterOneComboRecords,
                PersistenceKey.chapterOneBattleLoadout
            ]
            for key in progressKeysToClear {
                defaults.removeObject(forKey: key)
            }

            let completedMissionIDs = (1...2).map { "old-clock-\($0)" }
            defaults.set(completedMissionIDs, forKey: PersistenceKey.completedChapterMissionIDs)
            defaults.set("old-clock", forKey: PersistenceKey.selectedChapterDistrictID)
            completedChapterMissionIDs = Set(completedMissionIDs)
            selectedPathID = .fool
            phase = .districtMap
        }
        #endif
        restoreChapterOneCampaignFromMissionProgress()
        restoreChapterOneCampaignEvidence()
        if let rawPath = defaults.string(forKey: PersistenceKey.selectedPathID),
           let pathID = Pathway.ID(rawValue: rawPath) {
            selectedPathID = pathID
        }
        if let rawGender = defaults.string(forKey: PersistenceKey.selectedCharacterGender),
           let gender = CharacterGender(rawValue: rawGender) {
            selectedCharacterGender = gender
        }
        if let savedLoadout = defaults.stringArray(forKey: PersistenceKey.chapterOneBattleLoadout) {
            chapterOneCampaign.loadout.normalSkillIDs = savedLoadout.compactMap(FoolSkillID.init(rawValue:))
        }
        if let savedDistrictID = defaults.string(forKey: PersistenceKey.selectedChapterDistrictID),
           GameContent.chapterOneDistricts.contains(where: { $0.id == savedDistrictID }) {
            selectedChapterDistrictID = savedDistrictID
        }
        if defaults.object(forKey: PersistenceKey.venueCoins) != nil {
            venueCoins = defaults.integer(forKey: PersistenceKey.venueCoins)
        }
        if let savedItems = defaults.dictionary(forKey: PersistenceKey.ownedVenueItems) as? [String: Int] {
            ownedVenueItems = savedItems
        }
        if let savedSkillLevels = defaults.dictionary(forKey: PersistenceKey.skillLevels) as? [String: Int] {
            for (rawID, level) in savedSkillLevels {
                guard let skillID = DungeonSkillID(rawValue: rawID) else { continue }
                skillLevels[skillID] = max(1, min(level, 5))
            }
        }
        if let saved = defaults.dictionary(forKey: PersistenceKey.foolSkillLevels) as? [String: Int] {
            foolSkillLevels = Self.decodedFoolLevels(saved)
        }
        if defaults.object(forKey: PersistenceKey.currentSequence) != nil {
            currentSequence = max(0, min(defaults.integer(forKey: PersistenceKey.currentSequence), 9))
        }
        if defaults.object(forKey: PersistenceKey.materials) != nil {
            materials = max(0, defaults.integer(forKey: PersistenceKey.materials))
        }
        advancementIngredients = Set(
            (defaults.stringArray(forKey: PersistenceKey.advancementIngredients) ?? [])
                .compactMap(AdvancementIngredient.init(rawValue:))
        )
        equippedWeaponID = defaults.string(forKey: PersistenceKey.equippedWeaponID) ?? equippedWeaponID
        equippedSecondaryRelicID = defaults.string(forKey: PersistenceKey.equippedSecondaryRelicID) ?? equippedSecondaryRelicID
        selectedPassiveIDs = defaults.stringArray(forKey: PersistenceKey.selectedPassiveIDs) ?? selectedPassiveIDs
        hermitTalents = .restored(defaults.stringArray(forKey: "character.hermit-talents.v1") ?? [], budget: hermitTalentBudget)
        selectedTalentBranchID = defaults.string(forKey: PersistenceKey.selectedTalentBranchID) ?? selectedTalentBranchID
        equippedOutfitID = MPCOutfit(rawValue: defaults.string(forKey: PersistenceKey.equippedOutfitID) ?? "")?.rawValue
            ?? MPCOutfit.mistportNight.rawValue
        skillVariants = defaults.dictionary(forKey: PersistenceKey.skillVariants) as? [String: String] ?? [:]
        if let savedInventory = defaults.dictionary(forKey: "mistport.campaign-inventory.v1") as? [String: Int] {
            chapterOneCampaign.inventory = savedInventory
        }
        if let savedRelics = defaults.stringArray(forKey: "mistport.campaign-relics.v1") {
            chapterOneCampaign.ownedRelicIDs.formUnion(savedRelics)
        }
        if let equippedRelics = defaults.stringArray(forKey: "mistport.campaign-equipped-relics.v1") {
            chapterOneCampaign.loadout.relicIDs = Array(equippedRelics.filter { chapterOneCampaign.ownedRelicIDs.contains($0) && MPCChapterOneCatalog.isRelicEnabled($0) && !EarlyRelicShop.activeIDs.contains($0) }.prefix(1))
        }
        chapterOneCampaign.masqueradeCrackCount = min(10, max(0, defaults.integer(forKey: "mistport.mask-cracks.v1")))
        chapterOneCampaign.chapterThirtyRewardVersion = defaults.integer(forKey: "mistport.chapter30-reward-version.v1")
        chapterOneCampaign.lifetimeChurchMerit = defaults.integer(forKey: "mistport.church-lifetime-merit.v1")
        chapterOneCampaign.spendableChurchMerit = defaults.integer(forKey: "mistport.church-spendable-merit.v1")
        chapterOneCampaign.chapterTalentPointsEarned = defaults.integer(forKey: "mistport.chapter-talent-earned.v1")
        chapterOneCampaign.encoreBellMigrationVersion = defaults.integer(forKey: "mistport.encore-bell-migration.v1")
        let savedActiveRelic = defaults.string(forKey: "mistport.campaign-active-relic.v1")
        recoverMissionSettlement()
        recoverChurchTowerSettlement()
        recoverChurchServices()
        reconcileChurchGearEntitlements()
        // Recover the absolute settlement snapshot before applying an additive grant.
        let grantedMedal = completedChapterMissionIDs.contains("old-clock-4")
            ? chapterOneCampaign.grantUsurpedLifeMedalAfterQ4() : false
        if let activeRelic = savedActiveRelic,
           EarlyRelicShop.activeIDs.contains(activeRelic),
           chapterOneCampaign.ownedRelicIDs.contains(activeRelic) {
            chapterOneCampaign.loadout.selectedActiveRelicID = activeRelic
        }
        let completedStoryNumbers = Set(completedChapterMissionIDs.compactMap { id -> Int? in
            guard id.hasPrefix("old-clock-") else { return nil }
            return Int(id.dropFirst("old-clock-".count))
        })
        let restoredStoryEvidence = chapterOneCampaign.restoreClaimStoryEvidence(completedMissionNumbers: completedStoryNumbers)
        if grantedMedal || restoredStoryEvidence || savedActiveRelic != nil { persistChapterProgress() }
        recoverEarlyRelicPurchase()
        sequenceEightRitual = defaults.data(forKey: Self.sequenceEightRitualKey)
            .flatMap { try? JSONDecoder().decode(MPCSequenceEightRitual.Receipt.self, from: $0) }
        recoverSequenceEightRitual()
        chapterTwoBridge = defaults.data(forKey: Self.chapterTwoBridgeKey)
            .flatMap { try? JSONDecoder().decode(MPCChapterTwoBridge.self, from: $0) } ?? MPCChapterTwoBridge()
        postalJobSerial = defaults.integer(forKey: "mistport.postal-serial.v1")
        postalJobStep = min(2, max(0, defaults.integer(forKey: "mistport.postal-step.v1")))
        recoverPostalSettlement()
        recoverSkillUpgrade()
        if chapterOneCampaign.encoreBellMigrationVersion < 1,
           chapterOneTutorialFlags.contains("chapter-one.tutorial.q5Delivery") {
            chapterOneCampaign.acceptEncoreBellDelivery()
        }
        let migratedBell = chapterOneCampaign.migrateLegacyPaperRelicToEncoreBell()
        let migratedMask = chapterOneCampaign.migrateLegacyMaskCardToRelic()
        if migratedBell || migratedMask { persistChapterProgress() }

        // After every progress load and reset argument above: old saves migrate once here.
        resolveDailyPacingStart()
        if defaults.object(forKey: PersistenceKey.dailyWork) == nil { persistDailyWork(DailyWorkRecord()) }
        if defaults.object(forKey: PersistenceKey.dailyWorkshop) == nil { persistDailyWorkshop(DailyWorkshopRecord()) }

        #if DEBUG
        if launchArguments.contains("--preview-path") {
            phase = .pathSelection
        } else if launchArguments.contains("--preview-venue")
            || launchArguments.contains("--preview-venue-rare")
            || launchArguments.contains("--preview-venue-restaurant") {
            selectedPathID = .fool
            phase = .districtMap
            if launchArguments.contains("--preview-venue-rare") {
                venueVisitCounts["midnight-clock-cafe"] = 4
            }
            prepareVenue(
                launchArguments.contains("--preview-venue-restaurant")
                    ? "copper-key-restaurant"
                    : "midnight-clock-cafe"
            )
        } else if launchArguments.contains("--preview-map") || launchArguments.contains("--preview-map-tour") {
            selectedPathID = .fool
            phase = .districtMap
        } else if launchArguments.contains("--preview-city") {
            selectedPathID = .fool
            phase = .cityHub
        } else if launchArguments.contains("--preview-missions")
            || launchArguments.contains("--preview-profile")
            || launchArguments.contains("--preview-outfit-starlight")
            || launchArguments.contains("--preview-outfit-carnival")
            || launchArguments.contains("--preview-build")
            || launchArguments.contains("--preview-advancement")
            || launchArguments.contains("--preview-inventory") {
            selectedPathID = .fool
            phase = .cityHub
            if launchArguments.contains("--preview-outfit-starlight") {
                equippedOutfitID = "starlight-magician"
            } else if launchArguments.contains("--preview-outfit-carnival") {
                equippedOutfitID = "midnight-carnival"
            }
        } else if launchArguments.contains("--preview-dungeon")
            || launchArguments.contains("--preview-prebattle-loadout")
            || launchArguments.contains("--preview-clock-guard")
            || launchArguments.contains("--preview-boss")
            || launchArguments.contains("--preview-elite")
            || launchArguments.contains("--preview-salt-dungeon")
            || launchArguments.contains("--preview-mirror-dungeon")
            || launchArguments.contains("--preview-tide-dungeon")
            || launchArguments.contains("--preview-crown-dungeon")
            || launchArguments.contains("--preview-salt-boss")
            || launchArguments.contains("--preview-mirror-boss")
            || launchArguments.contains("--preview-tide-boss")
            || launchArguments.contains("--preview-crown-boss")
            || launchArguments.contains("--preview-victory") {
            selectedPathID = .fool
            if launchArguments.contains("--preview-prebattle-loadout") {
                activeChapterMissionID = "old-clock-2"
            } else if launchArguments.contains("--preview-clock-guard") {
                // Q5 is the Clockwork Hound encounter.  Point the dedicated
                // guard preview at the authored Old District guard boss so
                // animation QA never silently opens the wrong 3D enemy.
                activeChapterMissionID = "old-clock-20"
            } else if launchArguments.contains("--preview-salt-boss") {
                activeChapterMissionID = "salt-warehouse-20"
            } else if launchArguments.contains("--preview-mirror-boss") {
                activeChapterMissionID = "mirror-theater-20"
            } else if launchArguments.contains("--preview-tide-boss") {
                activeChapterMissionID = "tide-gate-20"
            } else if launchArguments.contains("--preview-crown-boss") {
                activeChapterMissionID = "mist-crown-20"
            } else if launchArguments.contains("--preview-salt-dungeon") {
                activeChapterMissionID = "salt-warehouse-18"
            } else if launchArguments.contains("--preview-mirror-dungeon") {
                activeChapterMissionID = "mirror-theater-18"
            } else if launchArguments.contains("--preview-tide-dungeon") {
                activeChapterMissionID = "tide-gate-18"
            } else if launchArguments.contains("--preview-crown-dungeon") {
                activeChapterMissionID = "mist-crown-18"
            } else if launchArguments.contains("--preview-boss") {
                activeChapterMissionID = "old-clock-20"
            } else if launchArguments.contains("--preview-elite") {
                activeChapterMissionID = "old-clock-19"
            } else {
                activeChapterMissionID = "old-clock-18"
            }
            phase = .dungeon
        } else if launchArguments.contains("--preview-adventure") {
            selectedPathID = .fool
            phase = .adventure
        }
        if launchArguments.contains("--verify-p1-ui") {
            selectedPathID = .fool
            selectedChapterDistrictID = "old-clock"
            // Keep an explicitly selected battle preview in the isolated store.
            if phase != .dungeon { phase = .districtMap }
        }
        if launchArguments.contains("--verify-church-services") { Self.verifyChurchServices() }
        if launchArguments.contains("--verify-bounty-daily-risk") { Self.verifyBountyDailyRisk() }
        if launchArguments.contains("--verify-bounty-poker") { Self.verifyBountyPoker() }
        if launchArguments.contains("--verify-church-departure") { Self.verifyChurchDeparture() }
        if launchArguments.contains("--verify-church-tower") { Self.verifyChurchTower() }
        if launchArguments.contains("--verify-church-tower-100") { Self.verifyChurchTowerHundred() }
        if launchArguments.contains("--verify-player-growth") { Self.verifyPlayerGrowthPersistence() }
        if launchArguments.contains("--verify-daily-pacing") { Self.verifyDailyPacing() }
        if launchArguments.contains("--verify-daily-work") { Self.verifyDailyWorkIntegration() }
        if launchArguments.contains("--verify-daily-workshop") { Self.verifyDailyWorkshopIntegration() }
        if launchArguments.contains("--verify-p0") { Self.verifySettlementRecovery() }
        if launchArguments.contains("--verify-early-relic-shop") { Self.verifyEarlyRelicShop(); Self.verifyAdvancementProcurement() }
        if launchArguments.contains("--verify-q5-migration") { Self.verifyEncoreBellMigration() }
        if launchArguments.contains("--verify-sequence8-ritual") { Self.verifySequenceEightRitual() }
        if launchArguments.contains("--verify-chapter2-bridge") { Self.verifyChapterTwoBridge() }
        if launchArguments.contains("--verify-lights-local") { Self.verifyLightsLocalEvent() }
        if launchArguments.contains("--preview-p0-settlement") {
            selectedPathID = .fool
            phase = .cityHub
            recoveredMissionReward = .init(missionID: "p0-preview", coins: 30, firstClear: true, materials: 1)
        }
        #endif
    }

    #if DEBUG
    private static func verifyAdvancementProcurement() {
        let suite = "mistport.material-procurement-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let store = GameStore(launchArguments: [], defaults: storage)
        store.venueCoins = 1000
        store.purchasePainSalve()
        assert(store.painSalveStock == 0 && store.venueCoins == 1000)
        store.completedChapterMissionIDs.insert("old-clock-4")
        store.purchasePainSalve()
        assert(store.painSalveStock == 1 && store.venueCoins == 970)
        store.purchasePainSalve()
        assert(store.painSalveStock == 1 && store.venueCoins == 970)
        let medicineRestored = GameStore(launchArguments: [], defaults: storage)
        assert(medicineRestored.painSalveStock == 1 && medicineRestored.venueCoins == 970)
        assert(store.consumeCampaignSupply("consumable_pain_salve"))
        store.purchasePainSalve()
        assert(store.painSalveStock == 1 && store.venueCoins == 940)
        store.venueCoins = 1000
        if let oldQ8 = GameContent.chapterOneDistricts.first?.missions.first(where: { $0.number == 8 }) {
            store.grantFirstClearAdvancementIngredient(for: oldQ8)
            assert(store.advancementIngredients.isEmpty)
        }
        store.purchaseAdvancementIngredient(.mirrorMothScale)
        assert(store.venueCoins == 1000 && store.advancementIngredients.isEmpty)
        // A legacy save already owns this item and must never buy it again.
        store.advancementIngredients.insert(.mirrorMothScale)
        store.persistChapterProgress()
        let restored = GameStore(launchArguments: [], defaults: storage)
        restored.completedChapterMissionIDs.insert("old-clock-17")
        restored.purchaseAdvancementIngredient(.mirrorMothScale)
        assert(restored.venueCoins == 1000 && restored.advancementIngredients.contains(.mirrorMothScale))
        restored.purchaseAdvancementIngredient(.reverseClockEssence)
        assert(restored.venueCoins == 1000)
        restored.completedChapterMissionIDs.insert("old-clock-20")
        restored.purchaseAdvancementIngredient(.reverseClockEssence)
        assert(restored.venueCoins == 660)
        restored.purchaseAdvancementIngredient(.reverseClockEssence)
        assert(restored.venueCoins == 660)
        restored.completedChapterMissionIDs.insert("old-clock-23")
        restored.purchaseAdvancementIngredient(.ownerlessMaskWax)
        assert(restored.venueCoins == 180 && restored.advancementIngredients.count == 3)
        let reopened = GameStore(launchArguments: [], defaults: storage)
        assert(reopened.venueCoins == 180 && reopened.advancementIngredients.count == 3)
        reopened.performAdvancement()
        assert(reopened.currentSequence == 9 && reopened.venueCoins == 180 && reopened.advancementIngredients.count == 3)
        let pending = EarlyRelicPurchase(coins: 17, relicIDs: [],
            ingredients: AdvancementIngredient.allCases.map(\.rawValue), materialCount: 3)
        storage.set(try! JSONEncoder().encode(pending), forKey: earlyRelicPurchaseKey)
        let recovered = GameStore(launchArguments: [], defaults: storage)
        assert(recovered.venueCoins == 17 && recovered.advancementIngredients.count == 3)
        assert(storage.object(forKey: earlyRelicPurchaseKey) == nil)
        let again = GameStore(launchArguments: [], defaults: storage)
        assert(again.venueCoins == 17 && again.advancementIngredients.count == 3)
        NSLog("ADVANCEMENT_PROCUREMENT_VERIFY_PASS: no old drops, milestones, old ownership, one debit, restore, journal")
    }

    private static func verifyEarlyRelicShop() {
        let suite = "mistport.early-relic-shop-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let store = GameStore(launchArguments: [], defaults: storage)
        store.purchaseEarlyRelic(EarlyRelicShop.salt)
        assert(store.venueCoins == 180 && !store.chapterOneCampaign.ownedRelicIDs.contains(EarlyRelicShop.salt))
        store.completedChapterMissionIDs.insert("old-clock-4")
        store.venueCoins = 500
        store.purchaseEarlyRelic(EarlyRelicShop.salt)
        assert(store.venueCoins == 380 && store.chapterOneCampaign.loadout.relicIDs.isEmpty)
        store.purchaseEarlyRelic(EarlyRelicShop.salt)
        assert(store.venueCoins == 380)
        store.purchaseEarlyRelic(EarlyRelicShop.clasp)
        assert(store.venueCoins == 220 && store.chapterOneCampaign.loadout.relicIDs.isEmpty)
        store.toggleCampaignRelic(EarlyRelicShop.salt)
        store.toggleCampaignRelic(EarlyRelicShop.clasp)
        assert(store.chapterOneCampaign.loadout.relicIDs == [EarlyRelicShop.clasp])
        let restored = GameStore(launchArguments: [], defaults: storage)
        assert(restored.venueCoins == 220 && restored.chapterOneCampaign.loadout.relicIDs == [EarlyRelicShop.clasp])
        let pending = EarlyRelicPurchase(coins: 100, relicIDs: [EarlyRelicShop.salt, EarlyRelicShop.clasp])
        storage.set(try! JSONEncoder().encode(pending), forKey: earlyRelicPurchaseKey)
        let recovered = GameStore(launchArguments: [], defaults: storage)
        assert(recovered.venueCoins == 100)
        assert(storage.object(forKey: earlyRelicPurchaseKey) == nil)
        let again = GameStore(launchArguments: [], defaults: storage)
        assert(again.venueCoins == 100 && again.chapterOneCampaign.ownedRelicIDs.contains(EarlyRelicShop.clasp))
        let serial = again.postalJobSerial
        again.verifyPostalField("错误", serial: serial, step: 0)
        assert(again.postalJobStep == 0 && again.venueCoins == 100)
        for step in 0..<3 { again.verifyPostalField(again.postalJobFields[step], serial: serial, step: step) }
        assert(again.venueCoins == 140 && again.postalJobSerial == serial + 1)
        again.verifyPostalField("星纹蜡封", serial: serial, step: 2)
        assert(again.venueCoins == 140)
        let postalRestored = GameStore(launchArguments: [], defaults: storage)
        assert(postalRestored.venueCoins == 140 && postalRestored.postalJobSerial == serial + 1)
        // Later relics are gated independently, never by the first shop unlock.
        postalRestored.venueCoins = 10_000
        for id in EarlyRelicShop.ids where ![EarlyRelicShop.salt, EarlyRelicShop.clasp].contains(id) {
            postalRestored.purchaseEarlyRelic(id)
            assert(!postalRestored.chapterOneCampaign.ownedRelicIDs.contains(id))
        }
        for id in EarlyRelicShop.ids {
            postalRestored.completedChapterMissionIDs.insert("old-clock-\(EarlyRelicShop.unlock(id))")
        }
        postalRestored.completedChapterMissionIDs.insert("old-clock-25")
        for id in EarlyRelicShop.ids { postalRestored.purchaseEarlyRelic(id) }
        assert(EarlyRelicShop.ids.allSatisfy(postalRestored.chapterOneCampaign.ownedRelicIDs.contains))
        postalRestored.selectCampaignActiveRelic(EarlyRelicShop.blankCard)
        postalRestored.toggleCampaignRelic(EarlyRelicShop.paperweight)
        assert(postalRestored.chapterOneCampaign.loadout.selectedActiveRelicID == EarlyRelicShop.blankCard)
        assert(postalRestored.chapterOneCampaign.loadout.relicIDs == [EarlyRelicShop.paperweight])
        NSLog("EARLY_RELIC_SHOP_VERIFY_PASS: locked, debit, duplicate, manual equip, restore, journal, postal verification")
    }

    private static func verifyPlayerGrowthPersistence() {
        let suite = "mistport.player-growth-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let store = GameStore(launchArguments: [], defaults: storage)
        assert(!store.hasFoolTestAccess && !store.permitsDeveloperTools)
        store.debugJumpToOldClockMission(10, enterImmediately: false)
        store.returnToCity()
        assert(store.skillDust == 30 && store.hermitTalentBudget == 4)
        store.upgradeFoolSkill(.mirrorPursuit)
        assert(store.skillDust == 30 && store.foolSkillLevel(for: .mirrorPursuit) == 1)
        store.upgradeFoolSkill(.sidestepStrike)
        assert(store.skillDust == 0 && store.foolSkillLevel(for: .sidestepStrike) == 2)
        store.upgradeFoolSkill(.sidestepStrike)
        assert(store.skillDust == 0 && store.foolSkillLevel(for: .sidestepStrike) == 2)
        let restored = GameStore(launchArguments: [], defaults: storage)
        assert(restored.skillDust == 0 && restored.foolSkillLevel(for: .sidestepStrike) == 2)
        let mission = GameContent.chapterOneDistricts[0].missions[9]
        assert(restored.chapterOneSession(for: mission).loadout.skillLevel(for: .sidestepStrike) == 2)
        assert(!restored.missionIsAvailable(GameContent.chapterOneDistricts[0].missions[15]))
        let pending = SkillUpgradeJournal(levels: [FoolSkillID.sidestepStrike.rawValue: 3], inventory: ["material_skill_dust": 7])
        storage.set(try! JSONEncoder().encode(pending), forKey: Self.skillUpgradeJournalKey)
        let recovered = GameStore(launchArguments: [], defaults: storage)
        assert(recovered.skillDust == 7 && recovered.foolSkillLevel(for: .sidestepStrike) == 3)
        let twice = GameStore(launchArguments: [], defaults: storage)
        assert(twice.skillDust == 7 && twice.foolSkillLevel(for: .sidestepStrike) == 3)
        twice.restart()
        let fresh = GameStore(launchArguments: [], defaults: storage)
        assert(fresh.completedChapterMissionIDs.isEmpty && fresh.foolSkillLevels.isEmpty && fresh.skillDust == 0)
        assert(fresh.chapterOneCampaign.ownedRelicIDs.isEmpty)
        assert(Self.playerTestMissionLimit == 30)
        let all = GameContent.chapterOneDistricts[0].missions
        let gap = GameStore(launchArguments: [], defaults: UserDefaults(suiteName: suite + ".gap")!)
        defer { UserDefaults(suiteName: suite + ".gap")!.removePersistentDomain(forName: suite + ".gap") }
        gap.completedChapterMissionIDs = ["old-clock-2"]
        assert(gap.missionIsAvailable(all[0]))
        assert(gap.missionIsAvailable(all[1]))
        assert(!gap.missionIsAvailable(all[2]))
        // Q30 opens on day 28 (MPCDailyPacing); a day-1 save must wait for it.
        gap.completedChapterMissionIDs = Set((1...29).map { "old-clock-\($0)" })
        assert(!gap.missionIsAvailable(all[29]) && gap.missionLockText(all[29]) != nil)
        gap.debugSetPacingDay(40)
        assert(gap.missionIsAvailable(all[29]) && !gap.playerTestComplete)
        gap.completedChapterMissionIDs.insert("old-clock-30")
        assert(gap.playerTestComplete)
        NSLog("PLAYER_GROWTH_VERIFY_PASS: locked card, debit, no funds, restore, battle level, Q30 release boundary, interrupted upgrade, reset")
    }

    /// Daily pacing on disposable suites: new save, next day, reopen, tower allowance,
    /// one-time migration of a save from before pacing, and restart.
    private static func verifyDailyPacing() {
        let suite = "mistport.daily-pacing." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        let oldSuite = suite + ".old"
        let old = UserDefaults(suiteName: oldSuite)!
        defer { storage.removePersistentDomain(forName: suite); old.removePersistentDomain(forName: oldSuite) }
        let all = GameContent.chapterOneDistricts[0].missions
        let fresh = GameStore(launchArguments: [], defaults: storage)
        assert(fresh.dailyPacingStart?.origin == .newSave && fresh.pacingDay == 1)
        fresh.completedChapterMissionIDs = Set((1...3).map { "old-clock-\($0)" })
        assert(!fresh.missionIsAvailable(all[3]) && fresh.missionLockText(all[3]) == "第 4 关明天开放")
        assert(fresh.missionIsAvailable(all[0]) && fresh.missionLockText(all[0]) == nil)
        fresh.pacingClock = { Date().addingTimeInterval(86_400) }
        assert(fresh.pacingDay == 2 && fresh.missionIsAvailable(all[3]))
        let reopened = GameStore(launchArguments: [], defaults: storage)
        assert(reopened.dailyPacingStart == fresh.dailyPacingStart)
        storage.set(try! JSONEncoder().encode(MPCChurchTowerProgress(clearedFloors: [1, 2, 3, 4])),
                    forKey: "mistport.church-tower.progress.v1")
        assert(reopened.towerFloorIsOpenToday(4) && !reopened.towerFloorIsOpenToday(5) && reopened.towerPacingLockText != nil)
        assert((try? reopened.churchTowerSession(floor: 5)) == nil)
        assert((try? reopened.churchTowerSession(floor: 4)) != nil)
        assert((try? reopened.beginChurchTower(floor: 5, battleID: "pacing-locked", skills: [])) == nil)
        assert((try? reopened.beginChurchTower(floor: 4, battleID: "pacing-replay", skills: [])) != nil)
        old.set((1...17).map { "old-clock-\($0)" }, forKey: PersistenceKey.completedChapterMissionIDs)
        let migrated = GameStore(launchArguments: [], defaults: old)
        assert(migrated.dailyPacingStart?.origin == .migrated && migrated.missionIsAvailable(all[17]))
        assert(!migrated.missionIsAvailable(all[18]))
        let again = GameStore(launchArguments: [], defaults: old)
        assert(again.dailyPacingStart == migrated.dailyPacingStart)
        migrated.restart()
        assert(migrated.dailyPacingStart?.origin == .newSave && migrated.pacingDay == 1)
        NSLog("DAILY_PACING_VERIFY_PASS: new save day 1, Q4 tomorrow, replay open, next day, reopen, tower 4/day, migration once, restart")
    }

    /// Explicit DEBUG walk only. Never seed or reset either player-owned suite.
    static func dailyPacingDeviceWalkDefaults() -> UserDefaults {
        let suite = "mistport.daily-pacing-device-walk.v1"
        let storage = UserDefaults(suiteName: suite)!
        storage.removePersistentDomain(forName: suite)
        let seed = GameStore(launchArguments: [], defaults: storage)
        seed.debugJumpToOldClockMission(4, enterImmediately: false)
        storage.set(try! JSONEncoder().encode(MPCChurchTowerProgress(clearedFloors: [1, 2, 3, 4])),
                    forKey: "mistport.church-tower.progress.v1")
        seed.debugSetPacingDay(1)
        if ProcessInfo.processInfo.arguments.contains("--daily-work-preview") {
            seed.debugJumpToOldClockMission(10, enterImmediately: false)
            seed.debugSetPacingDay(1)
            storage.set(try! JSONEncoder().encode(MPCChurchTowerProgress(clearedFloors: Set(1...10))),
                        forKey: "mistport.church-tower.progress.v1")
            var work = seed.dailyWorkRecord
            for n in 1...6 { _ = work.ledger.settle(receiptID: "preview-\(n)", day: 1, copper: 40, merit: 6) }
            seed.persistDailyWork(work)
        }
        if ProcessInfo.processInfo.arguments.contains("--daily-workshop-preview") {
            seed.debugJumpToOldClockMission(6, enterImmediately: false)
            seed.debugSetPacingDay(3)
            seed.venueCoins = 600
            for id in [MPCTowerMaterials.hide, MPCTowerMaterials.gland, MPCTowerMaterials.scale, MPCTowerMaterials.fiber] {
                seed.chapterOneCampaign.inventory[id] = 20
            }
            seed.persistChapterProgress()
            for n in 1...6 { try! seed.craftDailyWorkshop(recipeID: "recipe_repair_strap", transactionID: "preview-craft-\(n)") }
        }
        return storage
    }

    private static func verifyEncoreBellMigration() {
        let suite = "mistport.q5-migration." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        for cleared in [4, 5, 20] {
            storage.removePersistentDomain(forName: suite)
            let completed = (1...cleared).map { "old-clock-\($0)" }
            storage.set(completed, forKey: PersistenceKey.completedChapterMissionIDs)
            storage.set(731, forKey: PersistenceKey.venueCoins)
            storage.set(["item_sealed_transfer": 1, "consumable_salt_tea": 2], forKey: "mistport.campaign-inventory.v1")
            storage.set(["relic_paper_raincoat", "relic_trimmed_nameplate"], forKey: "mistport.campaign-relics.v1")
            storage.set(["relic_paper_raincoat", "relic_trimmed_nameplate"], forKey: "mistport.campaign-equipped-relics.v1")
            storage.set(["chapter-one.tutorial.q5Delivery"], forKey: PersistenceKey.chapterOneTutorialFlags)
            let migrated = GameStore(launchArguments: [], defaults: storage)
            assert(migrated.chapterOneCampaign.ownedRelicIDs.contains("relic_encore_bell"))
            assert(!migrated.chapterOneCampaign.ownedRelicIDs.contains("relic_paper_raincoat"))
            assert(migrated.chapterOneCampaign.loadout.relicIDs == ["relic_trimmed_nameplate"])
            assert(migrated.completedChapterMissionIDs == Set(completed))
            assert(migrated.venueCoins == 731)
            assert(migrated.chapterOneCampaign.inventory == ["item_sealed_transfer": 1, "consumable_salt_tea": 2])
            assert(!migrated.hasSeenChapterOneTutorial(.q5Delivery))
            migrated.completeChapterOneTutorial(.q5Delivery)
            let restored = GameStore(launchArguments: [], defaults: storage)
            assert(restored.chapterOneCampaign.ownedRelicIDs == migrated.chapterOneCampaign.ownedRelicIDs)
            assert(restored.chapterOneCampaign.loadout.relicIDs == migrated.chapterOneCampaign.loadout.relicIDs)
            assert(restored.chapterOneCampaign.inventory == migrated.chapterOneCampaign.inventory)
            assert(restored.venueCoins == 731 && restored.hasSeenChapterOneTutorial(.q5Delivery))
            assert(restored.chapterOneCampaign.encoreBellMigrationVersion == 1)
        }
        storage.removePersistentDomain(forName: suite)
        let fresh = GameStore(launchArguments: [], defaults: storage)
        assert(!fresh.chapterOneCampaign.ownedRelicIDs.contains("relic_encore_bell"))
        fresh.completeChapterOneTutorial(.q5Delivery)
        assert(fresh.chapterOneCampaign.ownedRelicIDs.contains("relic_encore_bell"))
        assert(!fresh.chapterOneCampaign.loadout.relicIDs.contains("relic_encore_bell"))
        fresh.toggleCampaignRelic("relic_encore_bell")
        let equipped = GameStore(launchArguments: [], defaults: storage)
        assert(equipped.chapterOneCampaign.loadout.relicIDs.contains("relic_encore_bell"))
        NSLog("Q5_MIGRATION_VERIFY_PASS: legacy 4/5/20, balances, delivery, restart, manual equipment")
    }

    private static func verifySettlementRecovery() {
        let suite = "mistport.p0-verification." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let store = GameStore(launchArguments: [], defaults: storage)
        let mission = GameContent.chapterOneDistricts.first!.missions.first!
        store.beginMission(mission)
        let before = store.venueCoins
        let receipt = store.settleActiveMissionRewards()!
        assert(store.venueCoins == before + receipt.coins)
        _ = store.settleActiveMissionRewards()
        assert(store.venueCoins == before + receipt.coins)
        let restored = GameStore(launchArguments: [], defaults: storage)
        assert(restored.venueCoins == store.venueCoins)
        assert(restored.recoveredMissionReward?.coins == receipt.coins)
        restored.acknowledgeMissionReward()
        let afterAck = GameStore(launchArguments: [], defaults: storage)
        assert(afterAck.recoveredMissionReward == nil)
        assert(afterAck.venueCoins == store.venueCoins)
        afterAck.beginMission(mission)
        let replay = afterAck.settleActiveMissionRewards()!
        assert(!replay.firstClear)
        assert(afterAck.venueCoins == store.venueCoins + replay.coins)
        afterAck.completeDungeon()
        assert(afterAck.venueCoins == store.venueCoins + replay.coins)
        print("P0_VERIFY_PASS: commit, duplicate, interruption recovery, acknowledge, replay, auto-exit")
    }
    #endif

    private func restoreChapterOneCampaignFromMissionProgress() {
        let completedMissions = GameContent.chapterOneDistricts
            .flatMap(\.missions)
            .filter { completedChapterMissionIDs.contains($0.id) }
            .sorted { $0.globalOrder < $1.globalOrder }
        for mission in completedMissions {
            if let encounterID = MPCChapterOneCatalog.encounterID(
                forDistrictID: mission.districtID,
                missionNumber: mission.number
            ),
               let encounter = MPCChapterOneCatalog.encounters.first(where: { $0.id == encounterID }) {
                chapterOneCampaign.claimVictory(for: encounter)
            }
            _ = chapterOneCampaign.applyChapterMissionProgress(
                districtID: mission.districtID,
                missionNumber: mission.number
            )
        }
    }

    private func restoreChapterOneCampaignEvidence() {
        let tags = (defaults.stringArray(forKey: PersistenceKey.chapterOneBehaviorTags) ?? [])
            .compactMap(MPCChapterOneBehaviorTag.init(rawValue:))
        chapterOneCampaign.completedBehaviorTags = Set(tags)
        guard let data = defaults.data(forKey: PersistenceKey.chapterOneComboRecords),
              let records = try? JSONDecoder().decode([MPCComboExecutionRecord].self, from: data)
        else { return }
        chapterOneCampaign.comboExecutionRecords = records
    }

    func hasSeenChapterOneTutorial(_ cue: ChapterOneTutorialCue) -> Bool {
        chapterOneTutorialFlags.contains(cue.persistenceKey)
    }

    func completeChapterOneTutorial(_ cue: ChapterOneTutorialCue) {
        if cue == .q5Delivery {
            chapterOneCampaign.acceptEncoreBellDelivery()
            persistChapterProgress()
        }
        if cue == .q8Prelude {
            _ = chapterOneCampaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 8)
            persistChapterProgress()
        }
        guard chapterOneTutorialFlags.insert(cue.persistenceKey).inserted else { return }
        defaults.set(Array(chapterOneTutorialFlags).sorted(), forKey: PersistenceKey.chapterOneTutorialFlags)
    }

    private func resetChapterOneTutorial(_ cue: ChapterOneTutorialCue) {
        guard chapterOneTutorialFlags.remove(cue.persistenceKey) != nil else { return }
        defaults.set(Array(chapterOneTutorialFlags).sorted(), forKey: PersistenceKey.chapterOneTutorialFlags)
    }

    func chapterOnePlayerPlacement(forMissionNumber missionNumber: Int) -> ChapterOnePlayerPlacement {
        return .standard
    }

    var selectedPath: Pathway? {
        GameContent.pathways.first { $0.id == selectedPathID }
    }

    var selectedCharacterArtName: String? {
        selectedPath?.artName(for: selectedCharacterGender)
    }

    var currentEncounter: Encounter? {
        guard GameContent.encounters.indices.contains(encounterIndex) else { return nil }
        return GameContent.encounters[encounterIndex]
    }

    var ritualIsReady: Bool {
        acting >= 3 && clues >= 2 && materials >= 2
    }

    var chapterAdvancementIsReady: Bool {
        currentSequence == 9
            && selectedChapterDistrict.id == "mist-crown"
            && completedChapterMissionIDs.contains("mist-crown-20")
            && advancementIngredients.count == AdvancementIngredient.allCases.count
    }

    var missingAdvancementIngredientNames: [String] {
        AdvancementIngredient.allCases
            .filter { !advancementIngredients.contains($0) }
            .map(\.name)
    }

    var currentAlignedChoice: StoryChoice? {
        guard let selectedPath, let currentEncounter else { return nil }
        return currentEncounter.alignedChoices[selectedPath.id]
    }

    var selectedChapterDistrict: ChapterDistrict {
        GameContent.chapterOneDistricts.first { $0.id == selectedChapterDistrictID }
            ?? GameContent.chapterOneDistricts[0]
    }

    var activeChapterMission: DistrictMission? {
        guard let activeChapterMissionID else { return nil }
        return GameContent.chapterOneDistricts
            .flatMap(\.missions)
            .first { $0.id == activeChapterMissionID }
    }

    var nextChapterMission: DistrictMission? {
        playerTestMissions.first { !completedChapterMissionIDs.contains($0.id) }
    }

    var currentTeamExpedition: ExpeditionDefinition {
        selectedChapterDistrict.teamExpedition
    }

    var activeVenue: VenueDefinition? {
        guard let activeVenueID else { return nil }
        return GameContent.oldClockVenues.first { $0.id == activeVenueID }
    }

    var combatPower: Int {
        let milestoneBonus = GameContent.chapterOneDistricts.reduce(into: 0) { total, district in
            total += unlockedMilestones(in: district).count * 60
        }
        let skillBonus = skillLevels.values.reduce(0) { $0 + max(0, $1 - 1) * 35 }
        let sequenceBonus = (9 - currentSequence) * 300
        let weaponBonus = MPCChapterOneCatalog.relicsEnabled ? ((CharacterLoadoutCatalog.weapon(id: equippedWeaponID)?.power ?? 0)
            + (CharacterLoadoutCatalog.weapon(id: equippedSecondaryRelicID)?.power ?? 0)) : 0
        let churchGearBonus = churchServices.gear.stats.attackBP / 15 + churchServices.gear.stats.maxHP / 2
        let talentBonus = milestoneIsUnlocked(.talentAwakening, in: selectedChapterDistrict) ? 45 : 0
        return 100 + completedChapterMissionIDs.count * 25 + milestoneBonus + skillBonus + sequenceBonus + weaponBonus + churchGearBonus + talentBonus
    }

    /// Number of ordinary skill cards that may be equipped in the saved combat loop.
    /// This grows through chapter-one progression. Every equipped card executes
    /// once per round; sequence rank never caps that count.
    var chapterOneLoadoutSlotCapacity: Int {
        min(4, max(1, chapterOneCampaign.loadoutSlotCapacity))
    }

    func saveChapterOneBattleLoadout(_ skillIDs: [FoolSkillID]) {
        let uniqueSkillIDs = skillIDs.reduce(into: [FoolSkillID]()) { result, skillID in
            guard skillID != .maskedWhisper, !result.contains(skillID) else { return }
            result.append(skillID)
        }
        chapterOneCampaign.loadout.normalSkillIDs = Array(uniqueSkillIDs.prefix(chapterOneLoadoutSlotCapacity))
        defaults.set(
            chapterOneCampaign.loadout.normalSkillIDs.map(\.rawValue),
            forKey: PersistenceKey.chapterOneBattleLoadout
        )
    }

    var configuredDungeonSkills: [DungeonSkillDefinition] {
        guard let selectedPath else { return [] }
        let relics = (MPCChapterOneCatalog.relicsEnabled ? [equippedWeaponID, equippedSecondaryRelicID] : []).compactMap(CharacterLoadoutCatalog.weapon(id:))
        let talentIsActive = milestoneIsUnlocked(.talentAwakening, in: selectedChapterDistrict)
        return DungeonSkillCatalog.skills(for: selectedPath).map { skill in
            let evolved = skillVariants[skill.id.rawValue] == "evolved"
            let weaponDamage = relics.reduce(0) { $0 + max(0, $1.power / 5) }
            let talentDamage = talentIsActive && selectedTalentBranchID == "trickster" ? 6 : 0
            let passiveDamage: Int = {
                if skill.id == .strike, selectedPassiveIDs.contains("marked-deck") { return 10 }
                if skill.id == .control, selectedPassiveIDs.contains("borrowed-name") { return 12 }
                if skill.id == .ultimate, selectedPassiveIDs.contains("last-applause") { return 18 }
                return 0
            }()
            let evolvedDamage = evolved ? (skill.id == .ultimate ? 20 : 12) : 0
            let evolutionCooldownReduction: TimeInterval = evolved && skill.id == .mobility ? 1 : 0
            let talentCooldownReduction: TimeInterval = {
                if talentIsActive, selectedTalentBranchID == "deceiver", skill.id == .ultimate { return 1 }
                if talentIsActive, selectedTalentBranchID == "boundary", skill.id == .mobility { return 1 }
                return 0
            }()
            let relicCooldownReduction: TimeInterval = MPCChapterOneCatalog.relicsEnabled && [equippedWeaponID, equippedSecondaryRelicID].contains("backward-watch") ? 1 : 0
            let passiveCooldownReduction: TimeInterval = skill.id == .mobility && selectedPassiveIDs.contains("false-exit") ? 1 : 0
            let extraRange: CGFloat = {
                if MPCChapterOneCatalog.relicsEnabled, [equippedWeaponID, equippedSecondaryRelicID].contains("mirror-card-case"), skill.id == .strike { return 45 }
                if talentIsActive, selectedTalentBranchID == "boundary", skill.id == .mobility { return 30 }
                return 0
            }()
            let extraRadius: CGFloat = talentIsActive && selectedTalentBranchID == "deceiver" && skill.id == .ultimate ? 25 : 0
            return DungeonSkillDefinition(
                id: skill.id,
                name: skill.name,
                symbol: skill.symbol,
                cooldown: max(1, skill.cooldown - evolutionCooldownReduction - talentCooldownReduction - relicCooldownReduction - passiveCooldownReduction),
                damage: skill.damage + weaponDamage + talentDamage + passiveDamage + evolvedDamage,
                range: skill.range + extraRange,
                radius: skill.radius + extraRadius,
                behavior: skill.behavior,
                tint: skill.tint
            )
        }
    }

    func equipWeapon(_ weaponID: String) {
        guard MPCChapterOneCatalog.relicsEnabled else { return }
        guard let weapon = CharacterLoadoutCatalog.weapon(id: weaponID) else {
            featureMessage = "武装资料不存在。"
            return
        }
        guard weaponID != equippedSecondaryRelicID else {
            featureMessage = "两件遗落物不能相同。"
            return
        }
        guard hasFoolTestAccess || completedMissionCount(in: selectedChapterDistrict) >= weapon.unlockAt else {
            featureMessage = "完成本区第 \(weapon.unlockAt) 项任务后解锁。"
            return
        }
        equippedWeaponID = weaponID
        featureMessage = "已装备“\(weapon.name)”，战斗能力同步更新。"
        persistChapterProgress()
    }

    func equipSecondaryRelic(_ relicID: String) {
        guard MPCChapterOneCatalog.relicsEnabled else { return }
        guard relicID != equippedWeaponID, let relic = CharacterLoadoutCatalog.weapon(id: relicID) else {
            featureMessage = "两件遗落物不能相同。"
            return
        }
        guard hasFoolTestAccess || completedMissionCount(in: selectedChapterDistrict) >= relic.unlockAt else {
            featureMessage = "完成本区第 \(relic.unlockAt) 项任务后解锁。"
            return
        }
        equippedSecondaryRelicID = relicID
        featureMessage = "第二件遗落物已装备。"
        persistChapterProgress()
    }

    func togglePassive(_ passiveID: String) {
        guard let passive = CharacterLoadoutCatalog.passive(id: passiveID),
              (hasFoolTestAccess || completedMissionCount(in: selectedChapterDistrict) >= passive.unlockAt) else {
            featureMessage = "该被动尚未解锁。"
            return
        }
        if selectedPassiveIDs.contains(passiveID) {
            guard selectedPassiveIDs.count > 1 else {
                featureMessage = "至少保留一个被动。"
                return
            }
            selectedPassiveIDs.removeAll { $0 == passiveID }
        } else {
            if selectedPassiveIDs.count == 2 { selectedPassiveIDs.removeFirst() }
            selectedPassiveIDs.append(passiveID)
        }
        featureMessage = "已装配 \(selectedPassiveIDs.count)/2 个被动。"
        persistChapterProgress()
    }

    func chooseSkillVariant(skillID: DungeonSkillID, variantID: String, unlockAt: Int) {
        guard hasFoolTestAccess || completedMissionCount(in: selectedChapterDistrict) >= unlockAt else {
            featureMessage = "完成本区第 \(unlockAt) 项任务后解锁该技能变体。"
            return
        }
        skillVariants[skillID.rawValue] = variantID
        featureMessage = "技能变体已编入战斗栏。"
        persistChapterProgress()
    }

    func chooseTalentBranch(_ branchID: String) {
        guard hasFoolTestAccess || milestoneIsUnlocked(.talentAwakening, in: selectedChapterDistrict) else {
            featureMessage = "完成本区第 15 项任务后，才能觉醒路径天赋。"
            return
        }
        selectedTalentBranchID = branchID
        featureMessage = "天赋流派已切换，返回城市可随时重置。"
        persistChapterProgress()
    }

    func equipOutfit(_ outfitID: String) {
        guard let outfit = MPCOutfit(rawValue: outfitID),
              CharacterLoadoutCatalog.outfits.contains(where: { $0.id == outfitID }) else {
            featureMessage = "衣装资料不存在。"
            return
        }
        equippedOutfitID = outfit.rawValue
        preparedChapterOneSession = nil
        preparedChapterOneMissionID = nil
        featureMessage = ""
        persistChapterProgress()
    }

    func applyBuildPreset(_ preset: GameBuildPreset) {
        let completed = completedMissionCount(in: selectedChapterDistrict)
        guard hasFoolTestAccess || completed >= preset.unlockAt else {
            featureMessage = "完成本区第 \(preset.unlockAt) 项任务后解锁“\(preset.name)”。"
            return
        }

        switch preset {
        case .cardChain:
            equippedWeaponID = "mirror-card-case"
            equippedSecondaryRelicID = "paper-moon-token"
            selectedTalentBranchID = "trickster"
            selectedPassiveIDs = ["marked-deck", "borrowed-name"]
            skillVariants = [:]
        case .misdirection:
            equippedWeaponID = "silver-lie-blade"
            equippedSecondaryRelicID = "paper-moon-token"
            selectedTalentBranchID = "deceiver"
            selectedPassiveIDs = ["borrowed-name", "false-exit"]
            skillVariants = [DungeonSkillID.ultimate.rawValue: "evolved"]
        case .boundarySurvival:
            equippedWeaponID = "backward-watch"
            equippedSecondaryRelicID = "silver-lie-blade"
            selectedTalentBranchID = "boundary"
            selectedPassiveIDs = ["false-exit", "last-applause"]
            skillVariants = [DungeonSkillID.mobility.rawValue: "evolved"]
        }
        featureMessage = "已启用“\(preset.name)”，下一场战斗立即生效。"
        persistChapterProgress()
    }

    func unlockedMilestones(in district: ChapterDistrict) -> [GrowthMilestone] {
        let completed = completedMissionCount(in: district)
        return [
            (5, GrowthMilestone.weaponResonance),
            (10, .skillEvolution),
            (15, .talentAwakening),
            (20, .advancementProof)
        ].compactMap { threshold, milestone in
            completed >= threshold ? milestone : nil
        }
    }

    func milestoneIsUnlocked(_ milestone: GrowthMilestone, in district: ChapterDistrict) -> Bool {
        unlockedMilestones(in: district).contains(milestone)
    }

    func begin() {
        phase = selectedPathID == nil ? .pathSelection : .cityHub
    }

    func select(_ path: Pathway, gender: CharacterGender) {
        guard GameContent.initiallyAvailablePathIDs.contains(path.id) else { return }
        selectedPathID = path.id
        selectedCharacterGender = gender
        defaults.set(path.id.rawValue, forKey: PersistenceKey.selectedPathID)
        defaults.set(gender.rawValue, forKey: PersistenceKey.selectedCharacterGender)
        resetChapterOneTutorial(.cityMission)
        phase = .cityHub
    }

    func beginStoryMission() {
        guard let mission = nextChapterMission else { return }
        beginMission(mission)
    }

    func enterDistrictMap() {
        guard selectedPathID != nil else {
            phase = .pathSelection
            return
        }
        // The intermediate street screen is no longer part of mission entry.
        guard let mission = nextChapterMission.flatMap({ missionIsAvailable($0) ? $0 : nil })
            ?? playerTestMissions.last(where: { missionIsAvailable($0) }) else {
            returnToCity()
            return
        }
        completeChapterOneTutorial(.mapEntry)
        prepareChapterOneMission(mission)
        beginMission(mission)
    }

    func cityServiceIsUnlocked(_ service: CityService) -> Bool {
        if service == .church { return service.isReleased }
        // Same rule as the rules library: any mission at or past Q5 completed.
        if service == .workshop { return service.isReleased && MPCLocalWorkshopLedger.isUnlocked(completedMissions: churchTowerMissionNumbers) }
        guard service.isReleased, let milestone = service.unlockMissionID else { return false }
        return completedChapterMissionIDs.contains(milestone)
    }

    func venueIsUnlocked(_ venueID: String) -> Bool {
        switch venueID {
        case "midnight-clock-cafe": return cityServiceIsUnlocked(.cafe)
        case "copper-key-restaurant": return cityServiceIsUnlocked(.restaurant)
        default: return false
        }
    }

    func prepareVenue(_ venueID: String) {
        guard venueIsUnlocked(venueID) else {
            activeVenueID = nil
            venueOffers = []
            venueMessage = "尚未开放 · 随主线推进解锁"
            return
        }
        guard let venue = GameContent.oldClockVenues.first(where: { $0.id == venueID }) else { return }
        activeVenueID = venueID
        let visit = venueVisitCounts[venueID, default: 0] + 1
        venueVisitCounts[venueID] = visit

        var generator = SystemRandomNumberGenerator()
        let common = venue.catalog.filter { $0.rarity == .common }.shuffled(using: &generator)
        let uncommon = venue.catalog.filter { $0.rarity == .uncommon }.shuffled(using: &generator)
        let rare = venue.catalog.first { $0.rarity == .rare }
        var selected = Array(common.prefix(2)) + Array(uncommon.prefix(1))
        let rareAppears = visit.isMultiple(of: 5) || Int.random(in: 0..<100, using: &generator) < 10
        if rareAppears, let rare {
            selected.append(rare)
        } else if let surprise = (uncommon.dropFirst().first ?? common.dropFirst(2).first) {
            selected.append(surprise)
        }
        venueOffers = selected.enumerated().map { index, item in
            VenueOffer(id: "\(venueID)-\(visit)-\(index)-\(item.id)", item: item)
        }
        if venue.kind == .cafe {
            if rareAppears {
                venueMessage = "今天的钟慢了半拍。看看柜台——有件东西不属于普通客人。"
            } else if visit == 1 {
                venueMessage = "第一次来？先喝点热的。雨停以前，别轻信街上的钟声。"
            } else {
                let cafeLines = [
                    "还是老位置。菜单没变，但今夜送货的人换了。",
                    "你身上的雾味更重了。需要补给，还是需要一个秘密？",
                    "十二声以后再离开。第十三声响起时，这里不接待活人。"
                ]
                venueMessage = cafeLines[(visit - 2) % cafeLines.count]
            }
        } else if rareAppears {
            venueMessage = "秘密菜单翻到最后一页了。那件辅材，只卖给能活着带走它的人。"
        } else if visit == 1 {
            venueMessage = venue.greeting
        } else {
            let restaurantLines = [
                "今天的汤里没有怪物。至少我盛出来时没有。",
                "先坐。空着肚子追线索，只会把自己送上别人的餐桌。",
                "熟客才看得到背页。你还差一点，但可以买顿热饭。"
            ]
            venueMessage = restaurantLines[(visit - 2) % restaurantLines.count]
        }
    }

    func purchaseVenueOffer(_ offerID: VenueOffer.ID) {
        guard let venueID = activeVenueID, venueIsUnlocked(venueID) else { return }
        guard let index = venueOffers.firstIndex(where: { $0.id == offerID }),
              !venueOffers[index].isSold else { return }
        let item = venueOffers[index].item
        guard venueCoins >= item.price else {
            venueMessage = "你的铜币不够。雨夜里，欠账比怪物追得更快。"
            return
        }
        venueCoins -= item.price
        venueOffers[index].isSold = true
        ownedVenueItems[item.id, default: 0] += 1
        if item.grantsAdvancementMaterial {
            materials += 1
            venueMessage = "收进内袋，别在街上打开。归一议会也在找这件晋阶辅材。"
        } else {
            switch item.category {
            case .provision:
                venueMessage = "趁效果还在时出发。热气散尽，它就只是普通食物了。"
            case .intelligence:
                venueMessage = "读完就烧掉。若纸上的字开始移动，说明它也在读你。"
            case .crafting:
                venueMessage = "材料是真的，记忆未必。制作前先确认那段回忆属于谁。"
            case .advancement:
                venueMessage = "收好它。晋阶仪式里，任何一个缺口都会要命。"
            }
        }
        persistChapterProgress()
    }

    var skillDust: Int { max(0, chapterOneCampaign.inventory["material_skill_dust", default: 0]) }

    func foolSkillLevel(for id: FoolSkillID) -> Int {
        MPCSkillGrowth.clampedLevel(foolSkillLevels[id, default: 1])
    }

    func canUpgradeFoolSkill(_ id: FoolSkillID) -> Bool {
        chapterOneCampaign.unlockedSkillIDs.contains(id) && MPCSkillGrowth.canUpgrade(id)
            && foolSkillLevel(for: id) < MPCSkillGrowth.maximumLevel
    }

    func upgradeFoolSkill(_ id: FoolSkillID) {
        guard phase != .dungeon else { featureMessage = "请回到主城后强化技能。"; return }
        guard canUpgradeFoolSkill(id), let cost = MPCSkillGrowth.upgradeCost(from: foolSkillLevel(for: id)) else { return }
        guard skillDust >= cost else { featureMessage = "技能粉尘不足，还需要 \(cost - skillDust) 份。"; return }
        // Close an older reward journal before this newer inventory transaction.
        acknowledgeMissionReward()
        var levels = foolSkillLevels
        levels[id] = foolSkillLevel(for: id) + 1
        var inventory = chapterOneCampaign.inventory
        inventory["material_skill_dust"] = skillDust - cost
        let journal = SkillUpgradeJournal(levels: Dictionary(uniqueKeysWithValues: levels.map { ($0.key.rawValue, $0.value) }), inventory: inventory)
        guard let data = try? JSONEncoder().encode(journal) else { return }
        defaults.set(data, forKey: Self.skillUpgradeJournalKey)
        foolSkillLevels = levels
        chapterOneCampaign.inventory = inventory
        preparedChapterOneSession = nil
        preparedChapterOneMissionID = nil
        persistChapterProgress()
        defaults.removeObject(forKey: Self.skillUpgradeJournalKey)
        let name = MPCChapterOneCatalog.skills.first { $0.id == id }?.name ?? "技能"
        featureMessage = "\(name)已强化至 Lv.\(foolSkillLevel(for: id))，消耗\(cost)份技能粉尘。"
    }

    private struct SkillUpgradeJournal: Codable {
        let levels: [String: Int]
        let inventory: [String: Int]
    }
    private static let skillUpgradeJournalKey = "mistport.pending-skill-upgrade.v1"
    private static func decodedFoolLevels(_ saved: [String: Int]) -> [FoolSkillID: Int] {
        Dictionary(uniqueKeysWithValues: saved.compactMap { rawID, level in
            guard let id = FoolSkillID(rawValue: rawID), MPCSkillGrowth.canUpgrade(id) else { return nil }
            return (id, MPCSkillGrowth.clampedLevel(level))
        })
    }
    private func recoverSkillUpgrade() {
        guard let data = defaults.data(forKey: Self.skillUpgradeJournalKey),
              let journal = try? JSONDecoder().decode(SkillUpgradeJournal.self, from: data) else { return }
        foolSkillLevels = Self.decodedFoolLevels(journal.levels)
        chapterOneCampaign.inventory = journal.inventory.mapValues { max(0, $0) }
        persistChapterProgress()
        defaults.removeObject(forKey: Self.skillUpgradeJournalKey)
    }

    func skillLevel(for skillID: DungeonSkillID) -> Int {
        skillLevels[skillID, default: 1]
    }

    func skillUpgradeCost(for skillID: DungeonSkillID) -> Int {
        skillLevel(for: skillID) * 30
    }

    func upgradeSkill(_ skillID: DungeonSkillID) {
        let currentLevel = skillLevel(for: skillID)
        guard currentLevel < 5 else {
            featureMessage = "该能力已达到当前序列上限。晋升序列后才能继续强化。"
            return
        }
        guard hasFoolTestAccess || milestoneIsUnlocked(.skillEvolution, in: selectedChapterDistrict) else {
            featureMessage = "完成本区第 10 项任务，觉醒“技能进化”后方可强化。"
            return
        }
        let cost = skillUpgradeCost(for: skillID)
        guard venueCoins >= cost else {
            featureMessage = "雾港铜币不足，还需要 \(cost - venueCoins) 枚。"
            return
        }
        venueCoins -= cost
        skillLevels[skillID] = currentLevel + 1
        featureMessage = "能力强化至 Lv.\(currentLevel + 1)，伤害与效果同步提升。"
        persistChapterProgress()
    }

    func useInventoryItem(_ itemID: String) {
        guard let count = ownedVenueItems[itemID], count > 0 else {
            featureMessage = "这件物品已经用完。"
            return
        }
        guard let item = GameContent.oldClockVenues.flatMap(\.catalog).first(where: { $0.id == itemID }) else {
            featureMessage = "物品资料受雾潮干扰，暂时无法使用。"
            return
        }
        if item.grantsAdvancementMaterial {
            featureMessage = "晋阶辅材必须在仪式中使用，不能直接消耗。"
            return
        }
        ownedVenueItems[itemID] = count - 1
        if ownedVenueItems[itemID] == 0 {
            ownedVenueItems.removeValue(forKey: itemID)
        }
        featureMessage = "已使用“\(item.name)”。效果将在下一场战斗生效。"
        persistChapterProgress()
    }

    @discardableResult
    func consumeCampaignSupply(_ id: String) -> Bool {
        guard MPCChapterOneCatalog.items.contains(where: { $0.id == id && $0.kind == .consumable }),
              chapterOneCampaign.inventory[id, default: 0] > 0 else { return false }
        chapterOneCampaign.inventory[id, default: 0] -= 1
        persistChapterProgress()
        return true
    }

    /// The Black Salt Shore ritual, qualification only: materials and fee are spent
    /// once through a written commit; no Sequence 8 combat rule is granted.
    func performAdvancement() {
        guard currentSequence == 9 else {
            featureMessage = "当前序列权益保留；后续晋阶将在黑盐岸开放。"
            return
        }
        var coins = venueCoins
        var ingredients = Set(advancementIngredients.map(\.rawValue))
        do {
            let receipt = try MPCSequenceEightRitual.perform(id: UUID().uuidString,
                completedMissions: churchTowerMissionNumbers, coins: &coins, ingredients: &ingredients,
                inventory: chapterOneCampaign.inventory, existing: sequenceEightRitual)
            let commit = SequenceEightRitualCommit(receipt: receipt, coins: coins, ingredients: ingredients.sorted())
            guard let data = try? JSONEncoder().encode(commit) else { return }
            defaults.set(data, forKey: Self.sequenceEightRitualCommitKey)
            recoverSequenceEightRitual()
            featureMessage = "序列 8 仪式完成：已交付三份主材与\(receipt.fee)铜币。新能力随后续剧情开放。"
        } catch MPCSequenceEightRitual.Failure.completed {
            featureMessage = "序列 8 仪式已完成；新能力随后续剧情开放。"
        } catch MPCSequenceEightRitual.Failure.locked {
            featureMessage = "第30关后抵达黑盐岸，才能举行序列 8 仪式。"
        } catch MPCSequenceEightRitual.Failure.materials {
            featureMessage = "晋阶主材尚缺：\(missingAdvancementIngredientNames.joined(separator: "、"))。"
        } catch MPCSequenceEightRitual.Failure.proofs {
            featureMessage = "剧情凭证尚缺：\(missingSequenceEightProofNames.joined(separator: "、"))。"
        } catch {
            featureMessage = "铜币不足，还需要\(max(0, MPCSequenceEightRitual.fee - venueCoins))枚。"
        }
    }

    /// Shown sequence: the qualification ritual records Sequence 8 without S8 combat rules.
    var displayedSequence: Int { sequenceEightRitual == nil ? currentSequence : min(currentSequence, 8) }

    /// Old saves already at Sequence 8 keep it and are never charged again.
    var sequenceEightQualified: Bool { currentSequence <= 8 || sequenceEightRitual != nil }

    var missingSequenceEightProofNames: [String] {
        MPCSequenceEightRitual.proofIDs.filter { chapterOneCampaign.inventory[$0, default: 0] == 0 }
            .map { id in MPCChapterOneCatalog.items.first { $0.id == id }?.name ?? id }
    }

    var sequenceEightRitualStatus: String {
        if sequenceEightRitual != nil { return "已完成：三份主材与\(MPCSequenceEightRitual.fee)铜币已交付，记为序列 8。新能力随后续剧情开放。" }
        if currentSequence <= 8 { return "已是序列 8，原有权益保留。" }
        guard churchTowerMissionNumbers.contains(MPCSequenceEightRitual.storyMission) else {
            return "第30关后抵达黑盐岸举行。需三份主材、个人演证、悖论见证、无主回响，提交时扣\(MPCSequenceEightRitual.fee)铜币。"
        }
        let missing = missingAdvancementIngredientNames + missingSequenceEightProofNames
        return missing.isEmpty
            ? "主材与凭证齐备；提交时扣三份主材与\(MPCSequenceEightRitual.fee)铜币，凭证保留。"
            : "尚缺：\(missing.joined(separator: "、"))。"
    }

    // MARK: Chapter Two bridge (Black Salt Shore → transfer station → shore)

    var chapterTwoBridgeOpen: Bool {
        MPCChapterTwoBridge.isOpen(q30Complete: churchHasDepartedMistport, ritualComplete: sequenceEightQualified)
    }

    var chapterTwoBridgeStatus: String {
        guard churchHasDepartedMistport else { return "第30关后前往黑盐岸。" }
        guard sequenceEightQualified else { return "先在黑盐岸举行序列 8 仪式，再前往外港转运站。仪式可在角色页举行。" }
        if chapterTwoBridge.worldEventStoryReady { return "已见过两位负责人。转运站的维修与采购尚未开放。" }
        return "外港转运站在前方航线上。两家为供能检修权来到这里。"
    }

    func travelToSaltportStation() { updateChapterTwoBridge { try $0.travelToStation(q30Complete: $1, ritualComplete: $2) } }
    func meetSaltportContact(_ contact: MPCChapterTwoBridge.Contact) {
        updateChapterTwoBridge { try $0.meet(contact, q30Complete: $1, ritualComplete: $2) }
    }
    func returnToBlackSaltShore() { updateChapterTwoBridge { bridge, _, _ in bridge.returnToShore() } }

    /// Only the bridge record is written; Chapter One progress is never touched.
    private func updateChapterTwoBridge(_ change: (inout MPCChapterTwoBridge, Bool, Bool) throws -> Bool) {
        var bridge = chapterTwoBridge
        do {
            guard try change(&bridge, churchHasDepartedMistport, sequenceEightQualified),
                  let data = try? JSONEncoder().encode(bridge) else { return }
            defaults.set(data, forKey: Self.chapterTwoBridgeKey)
            chapterTwoBridge = bridge
        } catch {
            featureMessage = chapterTwoBridgeStatus
        }
    }

    struct MissionRewardReceipt: Codable {
        let missionID: String
        let coins: Int
        let firstClear: Bool
        let materials: Int
        var itemNames: [String]? = nil
        var damageBySource: [String: Int]? = nil
    }

    private var settledMissionReward: MissionRewardReceipt?
    private struct SettlementJournal: Codable {
        let receipt: MissionRewardReceipt
        let coins: Int
        let materials: Int
        let ingredients: [String]
        let completed: [String]
        let sequence: Int
        let inventory: [String: Int]
        let relics: [String]
        var rewardVersion: Int? = nil
        var lifetimeMerit: Int? = nil
        var spendableMerit: Int? = nil
        var talentEarned: Int? = nil
        var dailyWork: DailyWorkRecord? = nil
    }
    private static let settlementJournalKey = "mistport.pending-settlement.v1"
    var recoveredMissionReward: MissionRewardReceipt?

    func acknowledgeMissionReward() {
        persistChapterProgress()
        defaults.removeObject(forKey: Self.settlementJournalKey)
        recoveredMissionReward = nil
    }

    func finishRecoveredMissionReward() {
        let missionID = recoveredMissionReward?.missionID
        acknowledgeMissionReward()
        activeChapterMissionID = nil
        if let district = GameContent.chapterOneDistricts.first(where: { $0.missions.contains(where: { $0.id == missionID }) }) {
            selectedChapterDistrictID = district.id
            phase = .cityHub
        } else { phase = .cityHub }
    }

    private func recoverMissionSettlement() {
        guard let data = defaults.data(forKey: Self.settlementJournalKey),
              let journal = try? JSONDecoder().decode(SettlementJournal.self, from: data) else { return }
        venueCoins = journal.coins
        materials = journal.materials
        advancementIngredients = Set(journal.ingredients.compactMap(AdvancementIngredient.init(rawValue:)))
        completedChapterMissionIDs = Set(journal.completed)
        currentSequence = journal.sequence
        restoreChapterOneCampaignFromMissionProgress()
        chapterOneCampaign.inventory = journal.inventory
        chapterOneCampaign.ownedRelicIDs = Set(journal.relics)
        chapterOneCampaign.chapterThirtyRewardVersion = journal.rewardVersion ?? chapterOneCampaign.chapterThirtyRewardVersion
        chapterOneCampaign.lifetimeChurchMerit = journal.lifetimeMerit ?? chapterOneCampaign.lifetimeChurchMerit
        chapterOneCampaign.spendableChurchMerit = journal.spendableMerit ?? chapterOneCampaign.spendableChurchMerit
        chapterOneCampaign.chapterTalentPointsEarned = journal.talentEarned ?? chapterOneCampaign.chapterTalentPointsEarned
        if let work = journal.dailyWork { persistDailyWork(work) }
        recoveredMissionReward = journal.receipt
        persistChapterProgress()
    }


    /// Commit once while the battle and its aftermath remain on screen.
    func settleActiveMissionRewards(itemNames: [String] = [], damageBySource: [String: Int] = [:]) -> MissionRewardReceipt? {
        guard let mission = activeChapterMission else { return nil }
        if let receipt = settledMissionReward, receipt.missionID == mission.id { return receipt }
        let materialsBefore = materials
        let wasNewCompletion = !completedChapterMissionIDs.contains(mission.id)
        guard wasNewCompletion || dailyWorkIsReadable else { return nil }
        var work = dailyWorkRecord
        let base = baseMissionCoinReward(for: mission, firstClear: wasNewCompletion)
        let earnedCoins = wasNewCompletion ? base : work.ledger.settle(receiptID: "story-" + UUID().uuidString, day: pacingDay, copper: base, merit: 0).copper
        completedChapterMissionIDs.insert(mission.id)
        venueCoins += earnedCoins
        if wasNewCompletion {
            acting += 1
            grantFirstClearAdvancementIngredient(for: mission)
            _ = chapterOneCampaign.applyChapterMissionProgress(
                districtID: mission.districtID,
                missionNumber: mission.number
            )
            // Promotion is a separate Black Salt ritual. A mission settlement
            // must not grant sequence 8 or charge its materials/fee.
        }

        let district = GameContent.chapterOneDistricts.first { $0.id == mission.districtID }
        let earnedReputation = district.map { self.reputation(in: $0) } ?? 0
        if wasNewCompletion, let milestone = mission.growthMilestone {
            let bossSuffix = mission.kind == .boss ? " 首领遗痕已析出并收入晋阶库存。" : ""
            latestResult = "\(milestone.title)已解锁；获得 \(earnedCoins) 铜币。\(bossSuffix)区域声望 \(earnedReputation)/\(ChapterDistrict.reputationToAdvance)。"
        } else if earnedReputation >= ChapterDistrict.reputationToAdvance,
           let district,
           let nextDistrict = GameContent.chapterOneDistricts.first(where: { $0.order == district.order + 1 }) {
            latestResult = "\(district.name)声望已满，下一区“\(nextDistrict.name)”开放。"
        } else {
            let replayText = wasNewCompletion ? "首次完成" : "回响重演"
            latestResult = "\(replayText) \(mission.title)：获得 \(earnedCoins) 铜币，区域声望 \(earnedReputation)/\(ChapterDistrict.reputationToAdvance)。"
        }
        let receipt = MissionRewardReceipt(missionID: mission.id, coins: earnedCoins,
                                           firstClear: wasNewCompletion,
                                           materials: max(0, materials - materialsBefore), itemNames: itemNames, damageBySource: damageBySource)
        let journal = SettlementJournal(receipt: receipt, coins: venueCoins, materials: materials,
            ingredients: advancementIngredients.map(\.rawValue), completed: Array(completedChapterMissionIDs),
            sequence: currentSequence, inventory: chapterOneCampaign.inventory,
            relics: Array(chapterOneCampaign.ownedRelicIDs),
            rewardVersion: chapterOneCampaign.chapterThirtyRewardVersion,
            lifetimeMerit: chapterOneCampaign.lifetimeChurchMerit,
            spendableMerit: chapterOneCampaign.spendableChurchMerit,
            talentEarned: chapterOneCampaign.chapterTalentPointsEarned,
            dailyWork: wasNewCompletion ? nil : work)
        // One encoded write-ahead record owns the post-settlement values. On
        // restart replay absolute values, never add the reward a second time.
        guard let encoded = try? JSONEncoder().encode(journal) else { return nil }
        defaults.set(encoded, forKey: Self.settlementJournalKey)
        settledMissionReward = receipt
        if !wasNewCompletion { persistDailyWork(work) }
        persistChapterProgress()
        return receipt
    }

    func completeDungeon() {
        if isTeamExpeditionActive {
            isTeamExpeditionActive = false
            materials += 2
            venueCoins += 60
            latestResult = "团队挑战完成：获得 60 铜币与 2 份晋阶辅材，未消耗区域任务进度。"
            persistChapterProgress()
            phase = .cityHub
            return
        }
        guard let mission = activeChapterMission else {
            phase = .cityHub
            return
        }

        _ = settleActiveMissionRewards()
        settledMissionReward = nil
        activeChapterMissionID = nil
        acknowledgeMissionReward()
        // Q2 continues directly into Q3; other completed battles return home.
        if mission.districtID == "old-clock", mission.number == 2,
           let next = GameContent.chapterOneDistricts.first(where: { $0.id == "old-clock" })?.missions.first(where: { $0.number == 3 }) {
            prepareChapterOneMission(next)
            beginMission(next)
        } else {
            phase = .cityHub
        }
    }

    func returnToCity() {
        guard selectedPathID != nil else {
            phase = .pathSelection
            return
        }
        activeChapterMissionID = nil
        isTeamExpeditionActive = false
        phase = .cityHub
    }

    func selectChapterDistrict(_ district: ChapterDistrict) {
        guard districtIsUnlocked(district) else { return }
        selectedChapterDistrictID = district.id
        persistChapterProgress()
    }

    func beginMission(_ mission: DistrictMission) {
        guard missionIsAvailable(mission) else { return }
        settledMissionReward = nil
        selectedChapterDistrictID = mission.districtID
        activeChapterMissionID = mission.id
        isTeamExpeditionActive = false
        phase = .dungeon
    }

    /// Builds the expensive first-chapter combat session while the player is
    /// still on the map. Entering the mission can then consume this prepared
    /// value without blocking the button transition.
    func prepareChapterOneMission(_ mission: DistrictMission) {
        guard missionIsInPlayerTest(mission) else { return }
        guard selectedPathID == .fool else {
            preparedChapterOneMissionID = nil
            preparedChapterOneSession = nil
            return
        }
        preparedChapterOneSession = makeChapterOneSession(for: mission)
        preparedChapterOneMissionID = mission.id
    }

    func prepareInitialChapterOneMission() {
        guard let district = GameContent.chapterOneDistricts.first(where: { $0.id == "old-clock" }),
              let mission = district.missions.first else { return }
        preparedChapterOneSession = makeChapterOneSession(for: mission)
        preparedChapterOneMissionID = mission.id
    }

    func chapterOneSession(for mission: DistrictMission) -> MPCChapterOneEncounterSession {
        if preparedChapterOneMissionID == mission.id,
           let preparedChapterOneSession {
            self.preparedChapterOneMissionID = nil
            self.preparedChapterOneSession = nil
            return preparedChapterOneSession
        }
        return makeChapterOneSession(for: mission)
    }

    private func makeChapterOneSession(for mission: DistrictMission) -> MPCChapterOneEncounterSession {
        let chapterMission = mission.districtID == "old-clock"
            ? MPCChapterOneCatalog.mission(forOldClockMissionNumber: mission.number)
            : nil
        let encounterID = chapterMission?.encounterID
            ?? MPCChapterOneCatalog.encounterID(
                forDistrictID: mission.districtID,
                missionNumber: mission.number
            )
            ?? "encounter_rain_01"
        if mission.districtID == "old-clock", mission.number >= 3 {
            let alreadyOwnedMask = chapterOneCampaign.ownsManualMask
            chapterOneCampaign.grantHoundTutorialCard()
            if !alreadyOwnedMask { persistChapterProgress() }
        }
        if hasSeenChapterOneTutorial(.q8Prelude) {
            _ = chapterOneCampaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 8)
        }
        var loadout = chapterOneCampaign.loadout(forMissionID: chapterMission?.id ?? encounterID)
        loadout.talents = hermitTalents
        loadout.skillLevels = foolSkillLevels
        var permittedSkills = chapterOneCampaign.unlockedSkillIDs
        if let trialSkillID = chapterMission?.trialSkillID {
            permittedSkills.insert(trialSkillID)
        }
        loadout.normalSkillIDs = loadout.normalSkillIDs.filter(permittedSkills.contains)
        if mission.districtID == "old-clock", mission.number == 1 {
            loadout.normalSkillIDs = [.sidestepStrike]
        }
        loadout.passiveIDs = loadout.passiveIDs.filter(chapterOneCampaign.unlockedPassiveIDs.contains)
        loadout.relicIDs = loadout.relicIDs.filter(chapterOneCampaign.ownedRelicIDs.contains)
        loadout.churchGear = churchServices.gear.stats
        loadout.bountyRelicID = churchServices.bountyRelics.equippedID
        loadout.outfit = MPCOutfit(rawValue: equippedOutfitID) ?? .mistportNight
        return try! MPCChapterOneEncounterSession.start(
            encounterID: encounterID,
            party: chapterOneCampaign.party,
            consumables: chapterOneCampaign.inventory,
            companionIDs: chapterMission?.companionIDs ?? [],
            loadout: loadout
        )
    }

    func beginTeamExpedition() {
        guard teamExpeditionIsUnlocked(in: selectedChapterDistrict) else { return }
        activeChapterMissionID = nil
        isTeamExpeditionActive = true
        phase = .dungeon
    }

    func completedMissionCount(in district: ChapterDistrict) -> Int {
        district.missions.lazy.filter { self.completedChapterMissionIDs.contains($0.id) }.count
    }

    func missionCoinReward(for mission: DistrictMission, firstClear: Bool) -> Int {
        let base = baseMissionCoinReward(for: mission, firstClear: firstClear)
        return firstClear ? base : dailyWorkRecord.ledger.preview(day: pacingDay, copper: base)
    }

    private func baseMissionCoinReward(for mission: DistrictMission, firstClear: Bool) -> Int {
        let firstClearValue = MPCChapterOneThirtyMissionContract.firstClear(for: mission.number)?.copper ?? 0
        return firstClear ? firstClearValue : max(8, Int(Double(firstClearValue) * 0.35))
    }

    func missionMaterialReward(for mission: DistrictMission, firstClear: Bool) -> Int {
        guard firstClear else { return 0 }
        return 0 // Main-story materials are purchased; old ownership is preserved.
    }

    private func grantFirstClearAdvancementIngredient(for mission: DistrictMission) {
        // Existing saved entitlements remain untouched. In chapter30, Q17/20/23
        // unlock purchases rather than awarding the old Q8/15/19 boss drops.
        return
    }

    func reputation(in district: ChapterDistrict) -> Int {
        completedMissionCount(in: district) * ChapterDistrict.reputationPerMission
    }

    func districtIsUnlocked(_ district: ChapterDistrict) -> Bool {
        guard district.id == "old-clock" else { return false }
        guard district.order > 1 else { return true }
        guard let previous = GameContent.chapterOneDistricts.first(where: { $0.order == district.order - 1 }) else {
            return false
        }
        return reputation(in: previous) >= ChapterDistrict.reputationToAdvance
    }

    func missionIsCompleted(_ mission: DistrictMission) -> Bool {
        completedChapterMissionIDs.contains(mission.id)
    }

    func missionIsAvailable(_ mission: DistrictMission) -> Bool {
        guard missionIsInPlayerTest(mission) else { return false }
        guard let district = GameContent.chapterOneDistricts.first(where: { $0.id == mission.districtID }),
              districtIsUnlocked(district) else { return false }
        if missionIsCompleted(mission) { return true }
        // Progress opens by calendar day; replays of cleared missions are never limited.
        guard MPCDailyPacing.isMissionOpen(mission.number, day: pacingDay) else { return false }
        let next = district.missions.filter { missionIsInPlayerTest($0) && !missionIsCompleted($0) }
            .min { $0.number < $1.number }
        return mission.id == next?.id
    }

    func teamExpeditionIsUnlocked(in district: ChapterDistrict) -> Bool {
        // This build opens only the authored solo Q1–Q30 investigation.
        false
    }

    func enableAbility() {
        guard !abilityUsed, !isResolving else { return }
        abilityUsed = true
        abilityEnabled = true
        latestResult = "\(selectedPath?.abilityName ?? "路径能力") 已启用：这次行动会更接近你的路径。"
    }

    func choose(_ choice: StoryChoice) {
        guard !isResolving else { return }
        isResolving = true

        var delta = choice.delta
        if abilityEnabled, let selectedPathID {
            switch selectedPathID {
            case .fool:
                delta.acting += 1
                delta.instability += 1
            case .priestess:
                delta.clues += 1
                delta.instability += 1
            case .chariot:
                delta.materials += 1
                delta.instability += 1
            case .magician:
                if clues <= materials {
                    delta.clues += 1
                } else {
                    delta.materials += 1
                }
                delta.instability += 1
            case .justice:
                delta.instability -= 1
            case .star:
                delta.acting += 1
                delta.clues += 1
                delta.instability += 1
            }
        }

        acting += delta.acting
        clues += delta.clues
        materials += delta.materials
        instability = max(0, min(instability + delta.instability, 6))
        abilityEnabled = false
        latestResult = choice.result
        history.insert("\(currentEncounter?.title ?? "雾港")：\(choice.title)", at: 0)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            if encounterIndex + 1 < GameContent.encounters.count {
                encounterIndex += 1
                latestResult = ""
                isResolving = false
            } else {
                isResolving = false
                phase = .ritual
            }
        }
    }

    func resolveRitual() {
        phase = .ending(success: ritualIsReady && instability < 5)
    }

    func restart() {
        for key in ["mistport.church.remote-contact.v1", "mistport.church.services.v1", "mistport.church.services.pending.v1", "mistport.church-tower.progress.v1", "mistport.church-tower.pending.v1", Self.earlyRelicPurchaseKey, "mistport.postal-settlement.v1", "mistport.postal-serial.v1", "mistport.postal-step.v1", "mistport.chapter30-reward-version.v1", "mistport.church-lifetime-merit.v1", "mistport.church-spendable-merit.v1", "mistport.chapter-talent-earned.v1"] { defaults.removeObject(forKey: key) }
        postalJobSerial = 0
        postalJobStep = 0
        chapterOneCampaign = .chapterStartState
        settledMissionReward = nil
        recoveredMissionReward = nil
        preparedChapterOneSession = nil
        preparedChapterOneMissionID = nil
        for key in [Self.settlementJournalKey, Self.skillUpgradeJournalKey, "mistport.campaign-inventory.v1", "mistport.campaign-relics.v1", "mistport.campaign-equipped-relics.v1", "mistport.campaign-active-relic.v1", "mistport.encore-bell-migration.v1", "mistport.mask-cracks.v1", PersistenceKey.chapterOneBehaviorTags, PersistenceKey.chapterOneComboRecords] {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: PersistenceKey.selectedPathID)
        defaults.removeObject(forKey: PersistenceKey.selectedCharacterGender)
        phase = .title
        selectedPathID = nil
        selectedCharacterGender = .male
        encounterIndex = 0
        acting = 0
        clues = 0
        materials = 0
        advancementIngredients = []
        instability = 0
        abilityUsed = false
        abilityEnabled = false
        isResolving = false
        history = []
        latestResult = ""
        selectedChapterDistrictID = "old-clock"
        activeChapterMissionID = nil
        completedChapterMissionIDs = []
        // A new save starts a new calendar and repeat-work ledger.
        persistDailyWork(DailyWorkRecord())
        persistDailyWorkshop(DailyWorkshopRecord())
        defaults.removeObject(forKey: PersistenceKey.dailyPacingStart)
        dailyPacingStart = nil
        resolveDailyPacingStart()
        venueCoins = 180
        ownedVenueItems = [:]
        skillLevels = [.strike: 1, .mobility: 1, .control: 1, .ward: 1, .ultimate: 1]
        foolSkillLevels = [:]
        currentSequence = 9
        sequenceEightRitual = nil
        chapterTwoBridge = MPCChapterTwoBridge()
        for key in Self.sequenceEightRitualKeys { defaults.removeObject(forKey: key) }
        equippedWeaponID = "silver-lie-blade"
        equippedSecondaryRelicID = "paper-moon-token"
        selectedPassiveIDs = ["marked-deck", "false-exit"]
        selectedTalentBranchID = "trickster"
        resetHermitTalents()
        equippedOutfitID = "mistport-night"
        skillVariants = [:]
        chapterOneTutorialFlags = []
        defaults.removeObject(forKey: "mistport.chapterOne.firstSequenceReorderTutorialCompleted")
        featureMessage = ""
        defaults.removeObject(forKey: PersistenceKey.completedChapterMissionIDs)
        defaults.removeObject(forKey: PersistenceKey.selectedChapterDistrictID)
        defaults.removeObject(forKey: PersistenceKey.venueCoins)
        defaults.removeObject(forKey: PersistenceKey.ownedVenueItems)
        defaults.removeObject(forKey: PersistenceKey.skillLevels)
        defaults.removeObject(forKey: PersistenceKey.foolSkillLevels)
        defaults.removeObject(forKey: Self.skillUpgradeJournalKey)
        defaults.removeObject(forKey: PersistenceKey.currentSequence)
        defaults.removeObject(forKey: PersistenceKey.materials)
        defaults.removeObject(forKey: PersistenceKey.advancementIngredients)
        defaults.removeObject(forKey: PersistenceKey.equippedWeaponID)
        defaults.removeObject(forKey: PersistenceKey.equippedSecondaryRelicID)
        defaults.removeObject(forKey: PersistenceKey.selectedPassiveIDs)
        defaults.removeObject(forKey: PersistenceKey.selectedTalentBranchID)
        defaults.removeObject(forKey: PersistenceKey.equippedOutfitID)
        defaults.removeObject(forKey: PersistenceKey.skillVariants)
        defaults.removeObject(forKey: PersistenceKey.chapterOneTutorialFlags)
        defaults.removeObject(forKey: PersistenceKey.chapterOneBattleLoadout)
    }

    #if DEBUG
    func debugBattlePlacement(forMissionNumber missionNumber: Int) -> ChapterOnePlayerPlacement {
        let key = PersistenceKey.debugBattlePlacementPrefix + String(max(1, missionNumber))
        guard let data = defaults.data(forKey: key),
              let placement = try? JSONDecoder().decode(ChapterOnePlayerPlacement.self, from: data) else {
            return .standard
        }
        return placement.normalized
    }

    func debugSetBattlePlacement(
        _ placement: ChapterOnePlayerPlacement,
        forMissionNumber missionNumber: Int
    ) {
        let key = PersistenceKey.debugBattlePlacementPrefix + String(max(1, missionNumber))
        if let data = try? JSONEncoder().encode(placement.normalized) {
            defaults.set(data, forKey: key)
        }
    }

    func debugResetBattlePlacement(forMissionNumber missionNumber: Int) {
        let key = PersistenceKey.debugBattlePlacementPrefix + String(max(1, missionNumber))
        defaults.removeObject(forKey: key)
    }

    /// Rebuilds the player-facing campaign state immediately before an old
    /// clock mission. This is intentionally a real progression state, not an
    /// all-unlocked sandbox, so the selected mission can be tested with the
    /// same cards, relics, and slots a player would have earned.
    func debugJumpToOldClockMission(_ missionNumber: Int, enterImmediately: Bool) {
        guard (1...Self.playerTestMissionLimit).contains(missionNumber) else { return }
        defaults.removeObject(forKey: Self.settlementJournalKey)
        defaults.removeObject(forKey: Self.skillUpgradeJournalKey)
        settledMissionReward = nil
        recoveredMissionReward = nil
        guard let district = GameContent.chapterOneDistricts.first(where: { $0.id == "old-clock" }),
              let mission = district.missions.first(where: { $0.number == missionNumber }) else {
            return
        }

        let completedMissions = district.missions.filter { $0.number < mission.number }
        let existingMaskCracks = chapterOneCampaign.masqueradeCrackCount
        chapterOneCampaign = .chapterStartState
        chapterOneCampaign.masqueradeCrackCount = existingMaskCracks
        for completedMission in completedMissions {
            if let encounterID = MPCChapterOneCatalog.encounterID(forOldClockMissionNumber: completedMission.number),
               let encounter = MPCChapterOneCatalog.encounters.first(where: { $0.id == encounterID }) {
                chapterOneCampaign.claimVictory(for: encounter)
            }
            _ = chapterOneCampaign.applyChapterMissionProgress(
                districtID: completedMission.districtID,
                missionNumber: completedMission.number
            )
        }

        if missionNumber > 5 { chapterOneCampaign.acceptEncoreBellDelivery() }

        selectedPathID = .fool
        selectedCharacterGender = .male
        selectedChapterDistrictID = district.id
        completedChapterMissionIDs = Set(completedMissions.map(\.id))
        // A jumped save is dated like a migrated one, so its next mission is open today.
        defaults.removeObject(forKey: PersistenceKey.dailyPacingStart)
        dailyPacingStart = nil
        resolveDailyPacingStart()
        hermitTalents = .restored(Array(hermitTalents.learned), budget: hermitTalentBudget)
        activeChapterMissionID = enterImmediately ? mission.id : nil
        isTeamExpeditionActive = false
        preparedChapterOneMissionID = nil
        preparedChapterOneSession = nil
        chapterOneTutorialFlags = []
        completeChapterOneTutorial(.cityMission)
        venueCoins = 180 + completedMissions.reduce(0) { total, completedMission in
            total + missionCoinReward(for: completedMission, firstClear: true)
        }
        acting = completedMissions.count
        clues = 0
        materials = 0
        advancementIngredients = []
        currentSequence = 9
        sequenceEightRitual = nil
        chapterTwoBridge = MPCChapterTwoBridge()
        for key in Self.sequenceEightRitualKeys { defaults.removeObject(forKey: key) }
        skillLevels = [.strike: 1, .mobility: 1, .control: 1, .ward: 1, .ultimate: 1]
        foolSkillLevels = [:]
        equippedWeaponID = "silver-lie-blade"
        equippedSecondaryRelicID = "paper-moon-token"
        selectedPassiveIDs = ["marked-deck", "false-exit"]
        selectedTalentBranchID = "trickster"
        equippedOutfitID = "mistport-night"
        skillVariants = [:]
        activeVenueID = nil
        venueOffers = []
        venueMessage = ""
        defaults.set(Array(chapterOneTutorialFlags).sorted(), forKey: PersistenceKey.chapterOneTutorialFlags)
        defaults.removeObject(forKey: PersistenceKey.chapterOneBattleLoadout)
        persistChapterProgress()
        defaults.set(
            chapterOneCampaign.loadout.normalSkillIDs.map(\.rawValue),
            forKey: PersistenceKey.chapterOneBattleLoadout
        )
        phase = enterImmediately ? .dungeon : .districtMap
    }

    func debugResetToChapterStart() {
        debugJumpToOldClockMission(1, enterImmediately: false)
    }
    #endif

    var earlyRelicShopUnlocked: Bool { completedChapterMissionIDs.contains("old-clock-4") }

    func relicPurchaseUnlocked(_ id: String) -> Bool {
        completedChapterMissionIDs.contains("old-clock-\(EarlyRelicShop.unlock(id))")
            && (id != EarlyRelicShop.needle || completedChapterMissionIDs.contains("old-clock-25"))
    }

    private struct PostalSettlement: Codable {
        let completedSerial: Int
        let coins: Int
        var dailyWork: DailyWorkRecord? = nil
    }
    var postalJobFields: [String] {
        let index = postalJobSerial
        return [Self.postalNames[index % 3], Self.postalStreets[(index / 3) % 3], Self.postalSeals[(index / 9) % 3]]
    }
    static let postalNames = ["艾达", "莫里", "塔文"]
    static let postalStreets = ["东升降街", "西钟楼巷", "旧灯街"]
    static let postalSeals = ["三点蜡封", "双线蜡封", "星纹蜡封"]
    var postalJobOptions: [String] {
        [Self.postalNames, Self.postalStreets, Self.postalSeals][postalJobStep]
    }
    /// A reward needs three verified fields for the current serial. Repeated
    /// completion events cannot settle the same work order twice.
    func verifyPostalField(_ answer: String, serial: Int, step: Int) {
        guard earlyRelicShopUnlocked, serial == postalJobSerial, step == postalJobStep else { return }
        guard answer == postalJobFields[step] else { featureMessage = "与原始单据不符，请重新核对。"; return }
        if step < 2 {
            postalJobStep += 1
            defaults.set(postalJobStep, forKey: "mistport.postal-step.v1")
            return
        }
        guard dailyWorkIsReadable else { featureMessage = "工单账本暂不可读取，请重新打开游戏。"; return }
        var work = dailyWorkRecord
        let payout = work.ledger.settle(receiptID: "postal-\(serial)", day: pacingDay, copper: 40, merit: 0)
        let receipt = PostalSettlement(completedSerial: serial, coins: venueCoins + payout.copper, dailyWork: work)
        guard let data = try? JSONEncoder().encode(receipt) else { return }
        defaults.set(data, forKey: "mistport.postal-settlement.v1")
        recoverPostalSettlement()
        featureMessage = "邮务核对完成，获得\(payout.copper)铜币。"
    }
    private func recoverPostalSettlement() {
        guard let data = defaults.data(forKey: "mistport.postal-settlement.v1"),
              let receipt = try? JSONDecoder().decode(PostalSettlement.self, from: data) else { return }
        venueCoins = receipt.coins
        if let work = receipt.dailyWork { persistDailyWork(work) }
        postalJobSerial = max(postalJobSerial, receipt.completedSerial + 1)
        postalJobStep = 0
        defaults.set(postalJobSerial, forKey: "mistport.postal-serial.v1")
        defaults.set(0, forKey: "mistport.postal-step.v1")
        persistChapterProgress()
        defaults.removeObject(forKey: "mistport.postal-settlement.v1")
    }

    private struct EarlyRelicPurchase: Codable {
        let coins: Int
        let relicIDs: [String]
        var ingredients: [String]? = nil
        var materialCount: Int? = nil
        var painSalveCount: Int? = nil
    }
    private static let earlyRelicPurchaseKey = "mistport.early-relic-purchase.v1"
    private static let sequenceEightRitualKey = "mistport.sequence8-ritual.v1"
    private static let sequenceEightRitualCommitKey = "mistport.sequence8-ritual.pending.v1"
    /// The Chapter Two bridge depends on the ritual, so it is cleared with it.
    private static let chapterTwoBridgeKey = "mistport.chapter2-bridge.v1"
    private static let sequenceEightRitualKeys = [sequenceEightRitualKey, sequenceEightRitualCommitKey, chapterTwoBridgeKey]

    /// Absolute state after the ritual, so applying it again changes nothing.
    private struct SequenceEightRitualCommit: Codable {
        let receipt: MPCSequenceEightRitual.Receipt
        let coins: Int
        let ingredients: [String]
    }

    private func recoverSequenceEightRitual() {
        guard let data = defaults.data(forKey: Self.sequenceEightRitualCommitKey),
              let commit = try? JSONDecoder().decode(SequenceEightRitualCommit.self, from: data),
              let receiptData = try? JSONEncoder().encode(commit.receipt) else { return }
        venueCoins = commit.coins
        advancementIngredients = Set(commit.ingredients.compactMap(AdvancementIngredient.init(rawValue:)))
        sequenceEightRitual = commit.receipt
        defaults.set(receiptData, forKey: Self.sequenceEightRitualKey)
        persistChapterProgress()
        defaults.removeObject(forKey: Self.sequenceEightRitualCommitKey)
    }

    /// One absolute journal prevents a restart between payment and delivery
    /// from either charging twice or losing the purchased item.
    func purchaseEarlyRelic(_ id: String) {
        guard relicPurchaseUnlocked(id), let price = EarlyRelicShop.price(id),
              MPCChapterOneCatalog.isRelicEnabled(id),
              !chapterOneCampaign.ownedRelicIDs.contains(id) else { return }
        guard venueCoins >= price else { featureMessage = "铜币不足，还需要 \(price - venueCoins) 枚。"; return }
        let purchase = EarlyRelicPurchase(coins: venueCoins - price,
            relicIDs: Array(chapterOneCampaign.ownedRelicIDs.union([id])))
        guard let data = try? JSONEncoder().encode(purchase) else { return }
        defaults.set(data, forKey: Self.earlyRelicPurchaseKey)
        recoverEarlyRelicPurchase()
        featureMessage = "已购入\(EarlyRelicShop.name(id))，可选择装备到被动位。"
    }

    func advancementPurchaseUnlocked(_ ingredient: AdvancementIngredient) -> Bool {
        completedChapterMissionIDs.contains("old-clock-\(ingredient.purchaseOffer.unlockMission)")
    }

    func purchaseAdvancementIngredient(_ ingredient: AdvancementIngredient) {
        let completed = Set(completedChapterMissionIDs.compactMap { id -> Int? in
            guard id.hasPrefix("old-clock-") else { return nil }
            return Int(id.dropFirst("old-clock-".count))
        })
        guard let receipt = MPCAdvancementMaterialMarket.purchase(ingredient.rawValue,
            completedMissionNumbers: completed, coins: venueCoins,
            ownedIDs: Set(advancementIngredients.map(\.rawValue))) else {
            if advancementIngredients.contains(ingredient) { featureMessage = "已持有\(ingredient.name)，无需重复购买。" }
            else if !advancementPurchaseUnlocked(ingredient) { featureMessage = "完成第\(ingredient.purchaseOffer.unlockMission)关后开放采购。" }
            else { featureMessage = "铜币不足，还需要\(max(0, ingredient.purchaseOffer.price - venueCoins))枚。" }
            return
        }
        let purchase = EarlyRelicPurchase(coins: receipt.coins,
            relicIDs: Array(chapterOneCampaign.ownedRelicIDs), ingredients: Array(receipt.ownedIDs),
            materialCount: max(materials, receipt.ownedIDs.count))
        guard let data = try? JSONEncoder().encode(purchase) else { return }
        defaults.set(data, forKey: Self.earlyRelicPurchaseKey)
        recoverEarlyRelicPurchase()
        featureMessage = "已购入\(ingredient.name)，保留至黑盐岸晋阶仪式。"
    }

    var painSalveStock: Int { chapterOneCampaign.inventory["consumable_pain_salve", default: 0] }

    /// One ready supply at a time: a second tap cannot debit a second purchase.
    /// Historical larger stacks are preserved and used before buying another.
    func purchasePainSalve() {
        guard earlyRelicShopUnlocked, painSalveStock == 0 else { return }
        guard venueCoins >= 30 else { featureMessage = "铜币不足，还需要\(30 - venueCoins)枚。"; return }
        let purchase = EarlyRelicPurchase(coins: venueCoins - 30,
            relicIDs: Array(chapterOneCampaign.ownedRelicIDs), painSalveCount: 1)
        guard let data = try? JSONEncoder().encode(purchase) else { return }
        defaults.set(data, forKey: Self.earlyRelicPurchaseKey)
        recoverEarlyRelicPurchase()
        preparedChapterOneSession = nil
        preparedChapterOneMissionID = nil
        featureMessage = "已购入止痛膏，战斗中使用可恢复25%生命。"
    }

    private func recoverEarlyRelicPurchase() {
        guard let data = defaults.data(forKey: Self.earlyRelicPurchaseKey),
              let purchase = try? JSONDecoder().decode(EarlyRelicPurchase.self, from: data) else { return }
        venueCoins = purchase.coins
        chapterOneCampaign.ownedRelicIDs.formUnion(purchase.relicIDs)
        if let ingredients = purchase.ingredients {
            advancementIngredients.formUnion(ingredients.compactMap(AdvancementIngredient.init(rawValue:)))
        }
        if let count = purchase.materialCount { materials = count }
        if let count = purchase.painSalveCount { chapterOneCampaign.inventory["consumable_pain_salve"] = count }
        persistChapterProgress()
        defaults.removeObject(forKey: Self.earlyRelicPurchaseKey)
    }

    func selectCampaignActiveRelic(_ id: String) {
        guard EarlyRelicShop.activeIDs.contains(id),
              chapterOneCampaign.ownedRelicIDs.contains(id) else { return }
        chapterOneCampaign.loadout.selectedActiveRelicID = id
        preparedChapterOneSession = nil
        preparedChapterOneMissionID = nil
        persistChapterProgress()
    }

    func toggleCampaignRelic(_ id: String) {
        if EarlyRelicShop.activeIDs.contains(id) {
            selectCampaignActiveRelic(id)
            return
        }
        guard MPCChapterOneCatalog.isRelicEnabled(id) else { return }
        guard chapterOneCampaign.ownedRelicIDs.contains(id) else { return }
        if chapterOneCampaign.loadout.relicIDs.contains(id) {
            chapterOneCampaign.loadout.relicIDs.removeAll { $0 == id }
        } else {
            chapterOneCampaign.loadout.relicIDs = [id]
        }
        preparedChapterOneSession = nil
        preparedChapterOneMissionID = nil
        persistChapterProgress()
    }

    @discardableResult
    func recordManualMaskUse(encounterID: String) -> Bool {
        guard chapterOneCampaign.registerMasqueradeUse(encounterID: encounterID) else { return false }
        persistChapterProgress()
        return true
    }

    private func persistChapterProgress() {
        defaults.set(chapterOneCampaign.chapterThirtyRewardVersion, forKey: "mistport.chapter30-reward-version.v1")
        defaults.set(chapterOneCampaign.lifetimeChurchMerit, forKey: "mistport.church-lifetime-merit.v1")
        defaults.set(chapterOneCampaign.spendableChurchMerit, forKey: "mistport.church-spendable-merit.v1")
        defaults.set(chapterOneCampaign.chapterTalentPointsEarned, forKey: "mistport.chapter-talent-earned.v1")
        if let activeRelic = chapterOneCampaign.loadout.selectedActiveRelicID {
            defaults.set(activeRelic, forKey: "mistport.campaign-active-relic.v1")
        } else {
            defaults.removeObject(forKey: "mistport.campaign-active-relic.v1")
        }
        defaults.set(chapterOneCampaign.masqueradeCrackCount, forKey: "mistport.mask-cracks.v1")
        chapterOneCampaign.migrateLegacyMaskCardToRelic()
        defaults.set(chapterOneCampaign.loadout.normalSkillIDs.map(\.rawValue), forKey: PersistenceKey.chapterOneBattleLoadout)
        defaults.set(chapterOneCampaign.encoreBellMigrationVersion, forKey: "mistport.encore-bell-migration.v1")
        defaults.set(chapterOneCampaign.inventory, forKey: "mistport.campaign-inventory.v1")
        defaults.set(Array(chapterOneCampaign.ownedRelicIDs), forKey: "mistport.campaign-relics.v1")
        defaults.set(chapterOneCampaign.loadout.relicIDs, forKey: "mistport.campaign-equipped-relics.v1")
        defaults.set(Array(completedChapterMissionIDs).sorted(), forKey: PersistenceKey.completedChapterMissionIDs)
        defaults.set(selectedChapterDistrictID, forKey: PersistenceKey.selectedChapterDistrictID)
        defaults.set(venueCoins, forKey: PersistenceKey.venueCoins)
        defaults.set(ownedVenueItems, forKey: PersistenceKey.ownedVenueItems)
        defaults.set(Dictionary(uniqueKeysWithValues: skillLevels.map { ($0.key.rawValue, $0.value) }), forKey: PersistenceKey.skillLevels)
        defaults.set(Dictionary(uniqueKeysWithValues: foolSkillLevels.map { ($0.key.rawValue, $0.value) }), forKey: PersistenceKey.foolSkillLevels)
        defaults.set(currentSequence, forKey: PersistenceKey.currentSequence)
        defaults.set(materials, forKey: PersistenceKey.materials)
        defaults.set(advancementIngredients.map(\.rawValue).sorted(), forKey: PersistenceKey.advancementIngredients)
        defaults.set(equippedWeaponID, forKey: PersistenceKey.equippedWeaponID)
        defaults.set(equippedSecondaryRelicID, forKey: PersistenceKey.equippedSecondaryRelicID)
        defaults.set(selectedPassiveIDs, forKey: PersistenceKey.selectedPassiveIDs)
        defaults.set(selectedTalentBranchID, forKey: PersistenceKey.selectedTalentBranchID)
        defaults.set(equippedOutfitID, forKey: PersistenceKey.equippedOutfitID)
        defaults.set(skillVariants, forKey: PersistenceKey.skillVariants)
        defaults.set(
            chapterOneCampaign.completedBehaviorTags.map(\.rawValue).sorted(),
            forKey: PersistenceKey.chapterOneBehaviorTags
        )
        if let comboData = try? JSONEncoder().encode(chapterOneCampaign.comboExecutionRecords) {
            defaults.set(comboData, forKey: PersistenceKey.chapterOneComboRecords)
        }
    }
}


extension GameStore {
    private struct TowerSettlement: Codable {
        let progress: MPCChurchTowerProgress
        let coins: Int
        let lifetimeMerit: Int
        let spendableMerit: Int
    }
    var churchTowerProgress: MPCChurchTowerProgress {
        guard let data = defaults.data(forKey: "mistport.church-tower.progress.v1"),
              let progress = try? JSONDecoder().decode(MPCChurchTowerProgress.self, from: data) else { return .init() }
        return progress
    }
    var churchTowerMissionNumbers: Set<Int> {
        Set(completedChapterMissionIDs.compactMap { id in
            id.hasPrefix("old-clock-") ? Int(id.dropFirst("old-clock-".count)) : nil
        })
    }
    func recoverChurchTowerSettlement() {
        guard let data = defaults.data(forKey: "mistport.church-tower.pending.v1"),
              let receipt = try? JSONDecoder().decode(TowerSettlement.self, from: data) else { return }
        venueCoins = receipt.coins
        chapterOneCampaign.lifetimeChurchMerit = receipt.lifetimeMerit
        chapterOneCampaign.spendableChurchMerit = receipt.spendableMerit
        defaults.set(try? JSONEncoder().encode(receipt.progress), forKey: "mistport.church-tower.progress.v1")
        persistChapterProgress()
        defaults.removeObject(forKey: "mistport.church-tower.pending.v1")
    }
    @discardableResult
    func settleChurchTower(floor: Int, session: MPCChapterOneEncounterSession, battleID: String? = nil) -> Bool {
        guard session.outcome == .victory,
              session.encounter.id == MPCChurchTowerCatalog.floor(number: floor)?.id else { return false }
        if let battleID {
            guard dailyWorkshopRecord.towerTickets[battleID] == floor || churchServices.workshop.towerTickets[battleID] == floor else { return false }
        }
        var progress = churchTowerProgress
        let reward = progress.claimVictory(floor: floor, completedMissionNumbers: churchTowerMissionNumbers)
        do {
            var workshop = churchServices.workshop
            var daily = dailyWorkshopRecord
            var inventory = chapterOneCampaign.inventory
            if let battleID, daily.towerTickets[battleID] == floor, !daily.finishedTowerTickets.contains(battleID) {
                for (id, count) in MPCTowerMaterials.drops(floor: floor) { inventory[id, default: 0] += count }
                daily.towerTickets.removeValue(forKey: battleID)
                daily.finishedTowerTickets.insert(battleID)
            } else if let battleID, workshop.towerTickets[battleID] != nil {
                _ = try workshop.claimTower(id: battleID, floor: floor, session: session, inventory: &inventory)
            }
            try updateChurchServices(dailyWorkshop: daily, towerProgress: progress, inventory: inventory) { state in
                state.workshop = workshop
                if let battleID { try settleChurchGear(&state, battleID: battleID, outcome: .victory) }
                if let reward {
                    state.loans.coins += reward.coins
                    state.loans.lifetimeMerit += reward.merit
                    state.loans.availableMerit += reward.merit
                    if let drop = MPCChurchGearCatalog.towerDrop(floor: floor) {
                        state.gear.grant(drop.id)
                    }
                }
            }
            return reward != nil
        } catch { return false }
    }
    func churchTowerSession(floor: Int) throws -> MPCChapterOneEncounterSession {
        try requireChurchRemoteService()
        guard churchTowerProgress.canEnter(floor, completedMissionNumbers: churchTowerMissionNumbers),
              towerFloorIsOpenToday(floor),
              let definition = MPCChurchTowerCatalog.floor(number: floor) else { throw MPCEncounterRuntimeError.unknownEncounter }
        var loadout = churchBattleCampaign.loadout
        loadout.normalSkillIDs = []
        loadout.talents = hermitTalents
        loadout.skillLevels = foolSkillLevels
        return try MPCChapterOneEncounterSession.start(encounterID: definition.id,
            party: chapterOneCampaign.party, consumables: chapterOneCampaign.inventory,
            companionIDs: [], loadout: loadout)
    }
}

// MARK: Daily pacing (2026-09-29): checked before a battle starts, never at settlement.
extension GameStore {
    var pacingDay: Int {
        (dailyPacingStart ?? MPCDailyPacingStart(start: pacingClock(), origin: .newSave, recordedAt: pacingClock()))
            .day(now: pacingClock())
    }
    /// Writes the record once: today for a new save, a migrated start for a save with progress.
    func resolveDailyPacingStart() {
        if let data = defaults.data(forKey: PersistenceKey.dailyPacingStart),
           let stored = try? JSONDecoder().decode(MPCDailyPacingStart.self, from: data) {
            dailyPacingStart = stored
            return
        }
        let record = MPCDailyPacingStart.resolve(now: pacingClock(),
                                                 completedMissions: churchTowerMissionNumbers.count,
                                                 clearedTowerFloors: churchTowerProgress.clearedFloors.count)
        defaults.set(try? JSONEncoder().encode(record), forKey: PersistenceKey.dailyPacingStart)
        dailyPacingStart = record
    }
    /// Why an uncleared story mission cannot start today (nil when it can or is cleared).
    func missionLockText(_ mission: DistrictMission) -> String? {
        guard missionIsInPlayerTest(mission), !missionIsCompleted(mission) else { return nil }
        return MPCDailyPacing.missionLockText(mission.number, day: pacingDay)
    }
    /// Cleared floors can always be replayed; a new floor needs today's allowance.
    func towerFloorIsOpenToday(_ floor: Int) -> Bool {
        churchTowerProgress.clearedFloors.contains(floor) || towerPacingLockText == nil
    }
    var towerPacingLockText: String? {
        MPCDailyPacing.towerLockText(clearedFloors: churchTowerProgress.clearedFloors.count, day: pacingDay)
    }
    var todayPacingSummary: String {
        MPCDailyPacing.todaySummary(day: pacingDay, completedMissions: churchTowerMissionNumbers.count,
                                    clearedFloors: churchTowerProgress.clearedFloors.count)
    }
    #if DEBUG
    /// Checks and walk saves only: make today day `day` of this save.
    func debugSetPacingDay(_ day: Int) {
        let today = Calendar.current.startOfDay(for: pacingClock())
        let start = Calendar.current.date(byAdding: .day, value: -(max(1, day) - 1), to: today)!
        let record = MPCDailyPacingStart(start: start, origin: .migrated, recordedAt: pacingClock())
        defaults.set(try? JSONEncoder().encode(record), forKey: PersistenceKey.dailyPacingStart)
        dailyPacingStart = record
    }
    #endif
}

#if DEBUG
extension GameStore {
    /// Runs shipping combat rules in memory only: no player defaults, rewards,
    /// inventory or scene mutations. This is rules validation on device, not a
    /// substitute for Unity presentation/contact-callback acceptance.
    private static func verifyChurchTowerHundred() {
        Task.detached(priority: .utility) {
            let started = Date()
            var rows: [[String: Any]] = []
            var wins = 0
            for number in 1...100 {
                do {
                    let report = try MPCChurchTowerVerificationRunner.run(number: number)
                    let definition = MPCChurchTowerCatalog.floor(number: number)!
                    let loadout = report.session.loadout
                    let victory = report.session.outcome == .victory
                    if victory { wins += 1 }
                    rows.append([
                        "floor": number, "missionCompleted": report.mission,
                        "outcome": report.session.outcome.rawValue,
                        "playerHP": report.session.playerHP, "seconds": report.seconds,
                        "route": report.route.rawValue,
                        "skillIDs": loadout.normalSkillIDs.map(\.rawValue),
                        "slotCapacity": report.mission >= 10 ? 4 : 2,
                        "ultimateUnlocked": loadout.isUltimateUnlocked,
                        "talents": Array(loadout.talents.learned).sorted(),
                        "activeRelic": loadout.selectedActiveRelicID ?? "",
                        "passiveRelics": loadout.relicIDs,
                        "skillCasts": report.skillCasts, "medalUses": report.medalUses,
                        "waveEntryHP": report.waveEntryHP, "rosters": report.rosterDescriptors,
                        "firstClearCoins": definition.firstClearReward.coins,
                        "firstClearMerit": definition.firstClearReward.merit
                    ])
                    NSLog("CHURCH_TOWER_100_FLOOR: %d %@ hp=%d seconds=%.2f", number, report.session.outcome.rawValue, report.session.playerHP, report.seconds)
                } catch {
                    rows.append(["floor": number, "outcome": "error", "error": String(describing: error)])
                    NSLog("CHURCH_TOWER_100_ERROR: %d %@", number, String(describing: error))
                }
            }
            let payload: [String: Any] = [
                "schema": 1, "verification": "shipping-core-on-device",
                "playerSaveModified": false, "visualAcceptance": false,
                "passed": wins == 100 && rows.count == 100, "wins": wins,
                "wallSeconds": Date().timeIntervalSince(started), "floors": rows
            ]
            do {
                let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("church-tower-100-verification.json")
                try data.write(to: url, options: .atomic)
                NSLog("CHURCH_TOWER_100_%@: %d/100 report=%@", wins == 100 ? "PASS" : "FAIL", wins, url.path)
            } catch { NSLog("CHURCH_TOWER_100_REPORT_ERROR: %@", String(describing: error)) }
        }
    }

    private static func verifyChurchTower() {
        let suite = "mistport.church-tower-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let store = GameStore(launchArguments: [], defaults: storage)
        assert(store.cityServiceIsUnlocked(.church))
        assert(store.completedChapterMissionIDs.isEmpty)
        assert(store.cityServiceIsUnlocked(.church))
        store.persistChapterProgress()
        // Exercise the real entry method with a malicious/stale picker payload.
        // This suite is isolated and removed after verification.
        store.chapterOneCampaign.unlockedSkillIDs = [.sidestepStrike]
        store.chapterOneCampaign.loadoutSlotCapacity = 2
        let filtered = try! store.beginChurchTower(floor: 1, battleID: "verify-illegal-cards", skills: [.namelessStage, .maskedWhisper, .sidestepStrike, .sidestepStrike])
        assert(filtered.loadout.normalSkillIDs == [.sidestepStrike])
        let empty = try! store.beginChurchTower(floor: 1, battleID: "verify-empty-cards", skills: [])
        assert(empty.loadout.normalSkillIDs.isEmpty)
        var battle = try! store.churchTowerSession(floor: 1)
        assert(!store.settleChurchTower(floor: 1, session: battle))
        // F1 is now the true-shield demon. The old basic-only tight loop
        // never advanced its guard phase and would hang this ledger check.
        battle = try! MPCChurchTowerVerificationRunner.run(number: 1).session
        assert(battle.outcome == .victory)
        let before = store.venueCoins
        assert(store.settleChurchTower(floor: 1, session: battle))
        assert(store.venueCoins == before + 8)
        assert(!store.settleChurchTower(floor: 1, session: battle))
        let restored = GameStore(launchArguments: [], defaults: storage)
        assert(restored.venueCoins == before + 8)
        assert(restored.churchTowerProgress.clearedFloors == [1])
        assert(restored.chapterOneCampaign.spendableChurchMerit == 2)
        assert(!restored.settleChurchTower(floor: 2, session: battle))
        let snapshot = TowerSettlement(progress: .init(clearedFloors: [1,2]), coins: before + 16,
            lifetimeMerit: 4, spendableMerit: 4)
        storage.set(try! JSONEncoder().encode(snapshot), forKey: "mistport.church-tower.pending.v1")
        let recovered = GameStore(launchArguments: [], defaults: storage)
        assert(recovered.venueCoins == before + 16 && recovered.churchTowerProgress.clearedFloors == [1,2])
        let again = GameStore(launchArguments: [], defaults: storage)
        assert(again.venueCoins == recovered.venueCoins && again.chapterOneCampaign.spendableChurchMerit == 4)
        NSLog("CHURCH_TOWER_VERIFY_PASS: unlock, defeat rejection, first clear, duplicate, restore, mismatched battle, journal recovery")
        Task { @MainActor in
            let renderer = ImageRenderer(content: ChurchSanctuaryView(game: recovered).frame(width: 390, height: 844))
            renderer.scale = 2
            if let data = renderer.uiImage?.pngData() {
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("church-sanctuary-verification.png")
                try? data.write(to: url)
                NSLog("CHURCH_SANCTUARY_RENDER_SAVED")
            }
        }
    }
}
#endif

extension GameStore {
    struct ChurchServicesState: Codable {
        var loans = MPCChurchLoanLedger()
        var bounties = MPCChurchBountyLedger()
        var dailyBountyIssue: MPCDailyBountyIssue? = nil
        var bountyCarriedRelics: [String:[String]] = [:]
        var bountyDefeatLosses: [String:MPCBountyDefeatLoss] = [:]
        var pokerActiveRounds: [String:MPCPokerRound] = [:]
        var pokerSettlements: [String:MPCPokerShowdown] = [:]
        var pokerSimpleAttempts: [String:Int] = [:]
        var douActiveGames: [String:MPCDouGame] = [:]
        var douSettlements: [String:MPCDouSettlement] = [:]
        var tavernPrizeCheckedDay: Int? = nil
        var tavernDailyPrize: MPCTavernPrize? = nil
        var tavernPrizeResolvedDays: Set<Int> = []
        var tavernFeaturedGames: [String:MPCTavernPrize] = [:]
        var tavernPrizePaidGames: Set<String> = []
        var equippedLoanIDs: [String] = []
        var maintenance = MPCChurchMaintenanceLedger()
        var ownedCondition = MPCChurchOwnedRelicLedger()
        var gear = MPCChurchGearLedger()
        var workshop = MPCLocalWorkshopLedger()
        var lightsEvent = MPCLightsLocalEvent()
        var bountyRelics = MPCBountyRelicLedger()
        init() {}
        private enum CodingKeys: String, CodingKey { case loans, bounties, dailyBountyIssue, bountyCarriedRelics, bountyDefeatLosses, pokerActiveRounds, pokerSettlements, pokerSimpleAttempts, douActiveGames, douSettlements, tavernPrizeCheckedDay, tavernDailyPrize, tavernPrizeResolvedDays, tavernFeaturedGames, tavernPrizePaidGames, equippedLoanIDs, maintenance, ownedCondition, gear, workshop, lightsEvent, bountyRelics }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            loans = try c.decodeIfPresent(MPCChurchLoanLedger.self, forKey: .loans) ?? .init()
            bounties = try c.decodeIfPresent(MPCChurchBountyLedger.self, forKey: .bounties) ?? .init()
            dailyBountyIssue = try c.decodeIfPresent(MPCDailyBountyIssue.self, forKey: .dailyBountyIssue)
            bountyCarriedRelics = try c.decodeIfPresent([String:[String]].self, forKey: .bountyCarriedRelics) ?? [:]
            bountyDefeatLosses = try c.decodeIfPresent([String:MPCBountyDefeatLoss].self, forKey: .bountyDefeatLosses) ?? [:]
            pokerActiveRounds = try c.decodeIfPresent([String:MPCPokerRound].self, forKey: .pokerActiveRounds) ?? [:]
            pokerSettlements = try c.decodeIfPresent([String:MPCPokerShowdown].self, forKey: .pokerSettlements) ?? [:]
            pokerSimpleAttempts = try c.decodeIfPresent([String:Int].self, forKey: .pokerSimpleAttempts)
                ?? Dictionary(grouping: pokerSettlements.values, by: \.caseID).mapValues(\.count)
            douActiveGames = try c.decodeIfPresent([String:MPCDouGame].self, forKey: .douActiveGames) ?? [:]
            douSettlements = try c.decodeIfPresent([String:MPCDouSettlement].self, forKey: .douSettlements) ?? [:]
            tavernPrizeCheckedDay = try c.decodeIfPresent(Int.self, forKey: .tavernPrizeCheckedDay)
            tavernDailyPrize = try c.decodeIfPresent(MPCTavernPrize.self, forKey: .tavernDailyPrize)
            tavernPrizeResolvedDays = try c.decodeIfPresent(Set<Int>.self, forKey: .tavernPrizeResolvedDays) ?? []
            tavernFeaturedGames = try c.decodeIfPresent([String:MPCTavernPrize].self, forKey: .tavernFeaturedGames) ?? [:]
            tavernPrizePaidGames = try c.decodeIfPresent(Set<String>.self, forKey: .tavernPrizePaidGames) ?? []
            equippedLoanIDs = try c.decodeIfPresent([String].self, forKey: .equippedLoanIDs) ?? []
            maintenance = try c.decodeIfPresent(MPCChurchMaintenanceLedger.self, forKey: .maintenance) ?? .init()
            ownedCondition = try c.decodeIfPresent(MPCChurchOwnedRelicLedger.self, forKey: .ownedCondition) ?? .init()
            gear = try c.decodeIfPresent(MPCChurchGearLedger.self, forKey: .gear) ?? .init()
            workshop = try c.decodeIfPresent(MPCLocalWorkshopLedger.self, forKey: .workshop) ?? .init()
            lightsEvent = try c.decodeIfPresent(MPCLightsLocalEvent.self, forKey: .lightsEvent) ?? .init()
            bountyRelics = try c.decodeIfPresent(MPCBountyRelicLedger.self, forKey: .bountyRelics) ?? .init()
        }
    }
    private struct BountyRelicSnapshot: Codable {
        let ownedIDs: [String]
        let equippedIDs: [String]
        let activeID: String?
    }
    private struct ChurchServicesReceipt: Codable {
        let state: ChurchServicesState
        var dailyWork: DailyWorkRecord? = nil
        var dailyWorkshop: DailyWorkshopRecord? = nil
        let coins: Int
        let lifetime: Int
        let available: Int
        var towerProgress: MPCChurchTowerProgress? = nil
        var relicSnapshot: BountyRelicSnapshot? = nil
        var ingredientIDs: [String]? = nil
        var inventory: [String: Int]? = nil
    }
    var churchServices: ChurchServicesState {
        _ = churchServicesRevision
        return defaults.data(forKey: "mistport.church.services.v1").flatMap { try? JSONDecoder().decode(ChurchServicesState.self, from: $0) } ?? .init()
    }
    /// Tower floors pay gear; closed bounty cases pay relics (bounty gear was
    /// retired on 2026-09-28 by a one-time migration recorded in the ledger).
    private func reconcileChurchGearEntitlements() {
        let services = churchServices
        let floors = churchTowerProgress.clearedFloors
        let claimed = services.bounties.cases.filter { $0.value.claimed }.map(\.key)
        let missingGear = floors.compactMap(MPCChurchGearCatalog.towerDrop(floor:))
            .filter { !services.gear.ownedIDs.contains($0.id) }
        let missingRelics = claimed.filter { id in
            MPCBountyRelicCatalog.relic(forCase: id).map { !services.bountyRelics.ownedIDs.contains($0.id) } ?? false
        }
        guard !missingGear.isEmpty || !missingRelics.isEmpty || !services.bountyRelics.hasMigrated else { return }
        try? updateChurchServices { state in
            for item in missingGear.sorted(by: { $0.id < $1.id }) { state.gear.grant(item.id) }
            state.bountyRelics.migrate(gear: &state.gear, claimedCaseIDs: claimed)
            for id in claimed.sorted() { state.bountyRelics.grant(caseID: id) }
        }
    }
    func equipBountyRelic(_ id: String?) throws {
        try updateChurchServices { state in
            guard state.bountyRelics.equip(id) else { throw MPCChurchLoanError.exhausted }
        }
    }
    /// First story mission not yet cleared, used to spot a player standing at a wall.
    var nextChapterMissionNumber: Int? {
        let done = churchTowerMissionNumbers
        return (1...30).first { !done.contains($0) }
    }
    func wallDefeatHint(missionNumber: Int) -> String? {
        let relics = churchServices.bountyRelics
        return MPCProgressionWalls.defeatHint(mission: missionNumber,
            highestTowerFloor: churchTowerProgress.clearedFloors.max() ?? 0,
            equippedRelicID: relics.equippedID, ownedRelicIDs: relics.ownedIDs,
            wornTowerDepth: churchServices.gear.stats.towerDepth,
            caseTitle: { MPCChurchBountyCatalog.bounty(id: $0)?.title })
    }
    func equipChurchGear(_ id: String) throws {
        try updateChurchServices { state in
            guard state.gear.equip(id, highestTowerFloor: churchTowerProgress.clearedFloors.max() ?? 0) else { throw MPCChurchLoanError.exhausted }
        }
    }
    func recoverChurchServices() {
        guard let data = defaults.data(forKey: "mistport.church.services.pending.v1"), let receipt = try? JSONDecoder().decode(ChurchServicesReceipt.self, from: data) else { return }
        venueCoins = receipt.coins
        if let work = receipt.dailyWork { persistDailyWork(work) }
        if let workshop = receipt.dailyWorkshop { persistDailyWorkshop(workshop) }
        chapterOneCampaign.lifetimeChurchMerit = receipt.lifetime
        chapterOneCampaign.spendableChurchMerit = receipt.available
        if let relics = receipt.relicSnapshot {
            chapterOneCampaign.ownedRelicIDs = Set(relics.ownedIDs)
            chapterOneCampaign.loadout.relicIDs = relics.equippedIDs
            chapterOneCampaign.loadout.selectedActiveRelicID = relics.activeID
        }
        if let inventory = receipt.inventory { chapterOneCampaign.inventory = inventory }
        if let ingredients = receipt.ingredientIDs {
            advancementIngredients = Set(ingredients.compactMap(AdvancementIngredient.init(rawValue:)))
        }
        defaults.set(try? JSONEncoder().encode(receipt.state), forKey: "mistport.church.services.v1")
        if let progress = receipt.towerProgress { defaults.set(try? JSONEncoder().encode(progress), forKey: "mistport.church-tower.progress.v1") }
        persistChapterProgress()
        defaults.removeObject(forKey: "mistport.church.services.pending.v1")
        churchServicesRevision += 1
    }
    private func updateChurchServices(dailyWorkshop: DailyWorkshopRecord? = nil, towerProgress: MPCChurchTowerProgress? = nil, relicSnapshot: BountyRelicSnapshot? = nil, ingredientIDs: [String]? = nil, inventory: [String: Int]? = nil, _ change: (inout ChurchServicesState) throws -> Void) throws {
        // Never replace an unreadable financial ledger with the default empty state.
        guard workshopLedgerIsReadable else { throw MPCLocalWorkshopLedger.Failure.locked }
        var state = churchServices
        state.loans.coins = venueCoins
        state.loans.lifetimeMerit = chapterOneCampaign.lifetimeChurchMerit
        state.loans.availableMerit = chapterOneCampaign.spendableChurchMerit
        try change(&state)
        try commitChurchServices(state, dailyWorkshop: dailyWorkshop, towerProgress: towerProgress, relicSnapshot: relicSnapshot, ingredientIDs: ingredientIDs, inventory: inventory)
    }
    private func commitChurchServices(_ state: ChurchServicesState, dailyWork: DailyWorkRecord? = nil, dailyWorkshop: DailyWorkshopRecord? = nil, towerProgress: MPCChurchTowerProgress? = nil, relicSnapshot: BountyRelicSnapshot? = nil, ingredientIDs: [String]? = nil, inventory: [String: Int]? = nil) throws {
        let receipt = ChurchServicesReceipt(state: state, dailyWork: dailyWork, dailyWorkshop: dailyWorkshop, coins: state.loans.coins, lifetime: state.loans.lifetimeMerit, available: state.loans.availableMerit, towerProgress: towerProgress, relicSnapshot: relicSnapshot, ingredientIDs: ingredientIDs, inventory: inventory)
        defaults.set(try JSONEncoder().encode(receipt), forKey: "mistport.church.services.pending.v1")
        recoverChurchServices()
        preparedChapterOneSession = nil
        preparedChapterOneMissionID = nil
    }
    func borrowChurchRelic(_ relicID: String) throws {
        try requireChurchRemoteService()
        try updateChurchServices { state in
            _ = try state.loans.borrow(relicID: relicID, completedMissions: churchTowerMissionNumbers)
        }
    }
    func returnChurchRelic(_ loanID: String) throws {
        try updateChurchServices { state in
            _ = try state.loans.returnLoan(loanID)
            state.equippedLoanIDs.removeAll { $0 == loanID }
        }
    }
    func markChurchLoanLost(_ loanID: String) throws {
        try updateChurchServices { state in
            _ = try state.loans.markLost(loanID)
            state.equippedLoanIDs.removeAll { $0 == loanID }
        }
    }
    func equipChurchLoan(_ loanID: String) throws {
        try updateChurchServices { state in
            guard let relic = state.loans.effectiveRelicID(loanID: loanID) else { throw MPCChurchLoanError.exhausted }
            if state.equippedLoanIDs.contains(loanID) { state.equippedLoanIDs.removeAll { $0 == loanID }; return }
            let active = EarlyRelicShop.activeIDs.contains(relic)
            state.equippedLoanIDs.removeAll { id in
                guard let other = state.loans.effectiveRelicID(loanID: id) else { return true }
                return EarlyRelicShop.activeIDs.contains(other) == active
            }
            state.equippedLoanIDs.append(loanID)
        }
    }
    var churchBattleCampaign: MPCChapterOneCampaignState { presentingChurchLoans(in: chapterOneCampaign) }
    private func beginChurchGear(_ state: inout ChurchServicesState, battleID: String, loadout: MPCChapterOneLoadout) throws {
        let actual = Set(loadout.relicIDs + [loadout.selectedActiveRelicID].compactMap { $0 })
        let borrowed = state.equippedLoanIDs.filter { id in
            guard let relic = state.loans.effectiveRelicID(loanID: id) else { return false }
            return actual.contains(relic)
        }
        let borrowedRelics = Set(borrowed.compactMap { state.loans.effectiveRelicID(loanID: $0) })
        _ = try state.loans.beginBattle(battleID: battleID, equippedLoanIDs: borrowed)
        _ = try state.ownedCondition.beginBattle(battleID: battleID, equippedRelicIDs: Array(actual), ownedRelicIDs: chapterOneCampaign.ownedRelicIDs, borrowedRelicIDs: borrowedRelics)
    }
    private func settleChurchGear(_ state: inout ChurchServicesState, battleID: String, outcome: MPCChurchBattleOutcome) throws {
        _ = state.gear.wear(battleID: battleID, outcome: outcome)
        if state.loans.battleLoans[battleID] != nil { _ = try state.loans.settleBattle(battleID: battleID, outcome: outcome) }
        if state.ownedCondition.battleRelicIDs[battleID] != nil { _ = try state.ownedCondition.settleBattle(battleID: battleID, outcome: outcome) }
    }
    func beginChurchLoanBattle(_ battleID: String, loadout: MPCChapterOneLoadout? = nil) throws {
        try updateChurchServices { state in try beginChurchGear(&state, battleID: battleID, loadout: loadout ?? churchBattleCampaign.loadout) }
    }
    func finishChurchLoanBattle(_ battleID: String, outcome: MPCChurchBattleOutcome) {
        var daily = dailyWorkshopRecord
        if outcome != .victory, daily.towerTickets.removeValue(forKey: battleID) != nil { daily.finishedTowerTickets.insert(battleID) }
        try? updateChurchServices(dailyWorkshop: daily) { state in
            try settleChurchGear(&state, battleID: battleID, outcome: outcome)
            if outcome != .victory { state.workshop.abandonTower(id: battleID) }
        }
    }
    func repairOwnedChurchRelic(_ relicID: String) throws {
        try updateChurchServices { state in
            let receipt = try state.ownedCondition.repair(relicID, ownedRelicIDs: chapterOneCampaign.ownedRelicIDs, availableCoins: state.loans.coins)
            state.loans.coins -= receipt.copperCost
        }
    }
    func refreshChurchBountyBoard(asOf date: Date = Date()) {
        let today = MPCDailyBountyRotation.dayOrdinal(for: date)
        func eligible(_ state: ChurchServicesState, _ id: String) -> Bool {
            let progress = state.bounties.cases[id]
            return progress?.accepted != true && progress?.claimed != true
        }
        // Standing at a mechanism wall without its relic: that case is printed today.
        func guaranteed(_ state: ChurchServicesState) -> String? {
            guard let next = nextChapterMissionNumber,
                  let id = MPCProgressionWalls.guaranteedCase(nextMission: next, ownedRelicIDs: state.bountyRelics.ownedIDs),
                  eligible(state, id) else { return nil }
            return id
        }
        let current = churchServices
        if let previous = current.dailyBountyIssue, previous.dayOrdinal >= today,
           previous.guaranteeing(guaranteed(current)) == previous { return }
        try? updateChurchServices { state in
            if let previous = state.dailyBountyIssue, previous.dayOrdinal >= today {
                state.dailyBountyIssue = previous.guaranteeing(guaranteed(state))
                return
            }
            let ids = MPCChurchBountyCatalog.all.map(\.id).filter { eligible(state, $0) }
            state.dailyBountyIssue = MPCDailyBountyRotation.issue(dayOrdinal: today, eligibleIDs: ids)
                .guaranteeing(guaranteed(state))
        }
    }
    func acceptChurchBounty(_ id: String) throws {
        refreshChurchBountyBoard()
        guard churchServices.dailyBountyIssue?.offerIDs.contains(id) == true
            || churchServices.bounties.cases[id]?.accepted == true else { throw MPCChurchBountyError.locked }
        try updateChurchServices { state in _ = try state.bounties.accept(id, completedMissions: churchTowerMissionNumbers) }
    }
    func visitChurchBounty(_ id: String, location: String) throws {
        try updateChurchServices { state in _ = try state.bounties.visit(id, location: location, completedMissions: churchTowerMissionNumbers) }
    }
    func investigateChurchBounty(_ id: String, nodeID: String) throws {
        try updateChurchServices { state in _ = try state.bounties.investigate(id, nodeID: nodeID, completedMissions: churchTowerMissionNumbers) }
    }
    func answerChurchBounty(_ id: String, nodeID: String, choiceID: String) throws {
        try updateChurchServices { state in _ = try state.bounties.answer(id, nodeID: nodeID, choiceID: choiceID, completedMissions: churchTowerMissionNumbers) }
    }
    func inspectChurchBountySite(_ id: String, featureID: String) throws {
        try updateChurchServices { state in _ = try state.bounties.inspectSiteFeature(id, featureID: featureID, completedMissions: churchTowerMissionNumbers) }
    }
    var tavernPokerUnlocked: Bool {
        churchServices.bounties.cases["b08"]?.claimed == true
    }
    /// Printing the day's stake once also records days with no eligible prize.
    /// Reopening the room or earning an item later cannot reroll that sheet.
    func refreshTavernPrize(asOf date: Date = Date()) {
        guard tavernPokerUnlocked else { return }
        let day = MPCDailyBountyRotation.dayOrdinal(for: date)
        guard (churchServices.tavernPrizeCheckedDay ?? 0) < day else { return }
        let offer = MPCTavernPrizeRotation.offer(dayOrdinal: day,
            completedMissions: churchTowerMissionNumbers,
            ownedRelicIDs: chapterOneCampaign.ownedRelicIDs,
            ownedMaterialIDs: Set(advancementIngredients.map(\.rawValue)))
        try? updateChurchServices { state in
            guard (state.tavernPrizeCheckedDay ?? 0) < day else { return }
            state.tavernPrizeCheckedDay = day
            state.tavernDailyPrize = offer
        }
    }
    var availableTavernPrize: MPCTavernPrize? {
        let state = churchServices
        guard let prize = state.tavernDailyPrize,
              !state.tavernPrizeResolvedDays.contains(prize.dayOrdinal),
              (prize.kind == .relic ? !chapterOneCampaign.ownedRelicIDs.contains(prize.itemID)
                                    : !advancementIngredients.contains { $0.rawValue == prize.itemID })
        else { return nil }
        return prize
    }
    /// The stake is held when the cards are dealt. Closing the sheet keeps
    /// the same hand and stake for the next visit to this table.
    func startChurchBountyPoker(_ id: String, wager: Int) throws -> MPCPokerRound {
        if let active = churchServices.pokerActiveRounds[id] { return active }
        guard churchServices.douActiveGames[id] == nil else { throw MPCPokerError.noActiveRound }
        let table = id == "b03" ? "码头" : id == "b08" ? "酒馆" : ""
        guard id == "tavern" ? tavernPokerUnlocked
            : (!table.isEmpty && churchServices.bounties.cases[id]?.currentLocation == table
                && churchServices.bounties.cases[id]?.accepted == true) else { throw MPCChurchBountyError.wrongLocation }
        guard id == "tavern" || churchServices.bounties.cases[id]?.pokerWins.contains(id) != true else {
            throw MPCChurchBountyError.pokerUnavailable
        }
        guard MPCPokerRules.wagers.contains(wager) else { throw MPCPokerError.invalidWager }
        var deck = MPCPokerRules.standardDeck
        deck.shuffle()
        let fifth = id != "tavern" && (churchServices.pokerSimpleAttempts[id] ?? 0) >= 4
        if fifth {
            deck = try MPCPokerRules.guaranteedFifthDeck(shuffledDeck: deck)
        }
        // Earlier losing stakes can underwrite the last, guaranteed clue hand
        // if the player's purse is empty. This one awards the clue but no cash.
        let coveredByEarlierStakes = fifth && venueCoins < wager
        let actualStake = coveredByEarlierStakes ? 0 : wager
        let round = try MPCPokerRules.deal(caseID: id, wager: actualStake, roundID: UUID().uuidString,
                                           shuffledDeck: deck,
                                           priorStakesCoverFifth: coveredByEarlierStakes)
        try updateChurchServices { state in
            if state.pokerActiveRounds[id] != nil { throw MPCPokerError.noActiveRound }
            guard state.loans.coins >= actualStake else { throw MPCPokerError.insufficientCopper }
            state.loans.coins -= actualStake
            state.pokerActiveRounds[id] = round
        }
        return round
    }
    func finishChurchBountyPoker(_ id: String, roundID: String, discarding indices: Set<Int>) throws -> MPCPokerShowdown {
        if let settled = churchServices.pokerSettlements[roundID] { return settled }
        guard let active = churchServices.pokerActiveRounds[id], active.roundID == roundID else {
            throw MPCPokerError.noActiveRound
        }
        let result = try MPCPokerRules.showdown(active, discarding: indices)
        try updateChurchServices { state in
            guard state.pokerActiveRounds[id]?.roundID == roundID else { throw MPCPokerError.noActiveRound }
            if id != "tavern" {
                switch result.outcome {
                case .win:
                    _ = try state.bounties.playPoker(id, won: true, completedMissions: churchTowerMissionNumbers)
                case .loss:
                    _ = try state.bounties.playPoker(id, won: false, completedMissions: churchTowerMissionNumbers)
                case .tie:
                    break
                }
            }
            state.loans.coins += result.payout
            state.pokerSettlements[roundID] = result
            state.pokerSimpleAttempts[id, default: 0] += 1
            state.pokerActiveRounds.removeValue(forKey: id)
        }
        return result
    }

    private func makeBountyDouGame(_ id: String, wager: Int, gameID: String) throws -> MPCDouGame {
        for _ in 0..<32 {
            var cards = MPCDouRules.standardDeck
            cards.shuffle()
            var game = try MPCDouRules.deal(caseID: id, wager: wager, gameID: gameID,
                                            shuffledDeck: cards, startingPlayer: Int.random(in: 0..<3))
            try game.runComputerTurns()
            if game.phase != .redeal { return game }
        }
        throw MPCDouError.invalidDeck
    }
    /// The two-deck table is fully shuffled each deal. Its one-time stake is
    /// kept in the same crash-safe church-services receipt as the story clue.
    func startChurchBountyDou(_ id: String, wager: Int, featuredPrize: Bool = false) throws -> MPCDouGame {
        if let active = churchServices.douActiveGames[id] { return active }
        guard churchServices.pokerActiveRounds[id] == nil else { throw MPCDouError.wrongPhase }
        let table = id == "b03" ? "码头" : id == "b08" ? "酒馆" : ""
        guard id == "tavern" ? tavernPokerUnlocked
            : (!table.isEmpty && churchServices.bounties.cases[id]?.currentLocation == table
                && churchServices.bounties.cases[id]?.accepted == true) else { throw MPCChurchBountyError.wrongLocation }
        guard id == "tavern" || churchServices.bounties.cases[id]?.pokerWins.contains(id) != true else {
            throw MPCChurchBountyError.pokerUnavailable
        }
        if id == "tavern" { refreshTavernPrize() }
        let prize = featuredPrize ? availableTavernPrize : nil
        guard !featuredPrize || (id == "tavern" && wager == 40 && prize != nil) else {
            throw MPCChurchBountyError.pokerUnavailable
        }
        guard MPCDouRules.wagers.contains(wager) else { throw MPCDouError.invalidStake }
        let game = try makeBountyDouGame(id, wager: wager, gameID: UUID().uuidString)
        try updateChurchServices { state in
            guard state.loans.coins >= wager else { throw MPCPokerError.insufficientCopper }
            state.loans.coins -= wager
            state.douActiveGames[id] = game
            if let prize { state.tavernFeaturedGames[game.gameID] = prize }
        }
        return game
    }
    private func advanceBountyDou(_ id: String, gameID: String,
                                  action: (inout MPCDouGame) throws -> Void) throws -> MPCDouGame {
        guard var game = churchServices.douActiveGames[id], game.gameID == gameID else {
            throw MPCDouError.gameFinished
        }
        guard game.currentPlayer == 0 else { throw MPCDouError.wrongTurn }
        try action(&game)
        try game.runComputerTurns()
        if game.phase == .redeal { game = try makeBountyDouGame(id, wager: game.wager, gameID: gameID) }
        let prize = churchServices.tavernFeaturedGames[gameID]
        let wonPrize = game.settlement?.playerWon == true ? prize : nil
        let isUnowned = wonPrize.map { reward in
            reward.kind == .relic ? !chapterOneCampaign.ownedRelicIDs.contains(reward.itemID)
                : !advancementIngredients.contains { $0.rawValue == reward.itemID }
        } ?? false
        let relicSnapshot: BountyRelicSnapshot? = wonPrize.flatMap { reward in
            guard isUnowned && reward.kind == .relic else { return nil }
            return .init(ownedIDs: Array(chapterOneCampaign.ownedRelicIDs.union([reward.itemID])),
                         equippedIDs: chapterOneCampaign.loadout.relicIDs,
                         activeID: chapterOneCampaign.loadout.selectedActiveRelicID)
        }
        let ingredientIDs: [String]? = wonPrize.flatMap { reward in
            guard isUnowned && reward.kind == .advancementMaterial else { return nil }
            return Array(Set(advancementIngredients.map(\.rawValue)).union([reward.itemID]))
        }
        try updateChurchServices(relicSnapshot: relicSnapshot, ingredientIDs: ingredientIDs) { state in
            guard state.douActiveGames[id]?.gameID == gameID else { throw MPCDouError.gameFinished }
            if let settlement = game.settlement {
                if id != "tavern" {
                    _ = try state.bounties.playPoker(id, won: settlement.playerWon,
                                                      completedMissions: churchTowerMissionNumbers)
                }
                if let prize {
                    state.tavernPrizeResolvedDays.insert(prize.dayOrdinal)
                    if settlement.playerWon && isUnowned {
                        state.tavernPrizePaidGames.insert(gameID)
                        if prize.kind == .relic { state.ownedCondition.retireLostCopy(prize.itemID) }
                    }
                    // Duplicate ownership during a paused game converts the
                    // promised object to forty copper instead of duplicating it.
                    state.loans.coins += settlement.playerWon ? settlement.wager + (isUnowned ? 0 : 40) : 0
                } else { state.loans.coins += settlement.payout }
                state.douSettlements[gameID] = settlement
                state.douActiveGames.removeValue(forKey: id)
            } else { state.douActiveGames[id] = game }
        }
        return game
    }
    func bidChurchBountyDou(_ id: String, gameID: String, points: Int) throws -> MPCDouGame {
        try advanceBountyDou(id, gameID: gameID) { try $0.bid(points) }
    }
    func playChurchBountyDou(_ id: String, gameID: String, cardIDs: Set<String>) throws -> MPCDouGame {
        try advanceBountyDou(id, gameID: gameID) { try $0.play(cardIDs: cardIDs) }
    }
    func passChurchBountyDou(_ id: String, gameID: String) throws -> MPCDouGame {
        try advanceBountyDou(id, gameID: gameID) { try $0.pass() }
    }
    func inspectChurchBountyAlternative(_ id: String) throws {
        try updateChurchServices { state in _ = try state.bounties.inspectAlternativeLead(id, completedMissions: churchTowerMissionNumbers) }
    }
    func presentChurchBountyWarrant(_ id: String, suspectID: String, supportingEvidenceIDs: Set<String>) throws {
        try updateChurchServices { state in _ = try state.bounties.presentWarrant(id, suspectID: suspectID, supportingEvidenceIDs: supportingEvidenceIDs) }
    }
    func beginChurchBounty(_ id: String, battleID: String, skills: [FoolSkillID]) throws -> MPCChapterOneEncounterSession {
        guard let definition = MPCChurchBountyCatalog.bounty(id: id) else { throw MPCChurchBountyError.unavailable }
        var loadout = churchBattleCampaign.loadout
        loadout.normalSkillIDs = skills; loadout.talents = hermitTalents; loadout.skillLevels = foolSkillLevels
        let session = try MPCChapterOneEncounterSession.start(encounterID: definition.encounterID, party: chapterOneCampaign.party, consumables: chapterOneCampaign.inventory, companionIDs: [], loadout: loadout)
        try updateChurchServices { state in
            _ = try state.bounties.beginBattle(id, battleID: battleID)
            try beginChurchGear(&state, battleID: battleID, loadout: loadout)
            let borrowed = Set(state.equippedLoanIDs.compactMap { state.loans.effectiveRelicID(loanID: $0) })
            let carried = Set(loadout.relicIDs + [loadout.selectedActiveRelicID].compactMap { $0 })
                .intersection(MPCChurchOwnedRelicLedger.ordinaryRelicIDs)
                .intersection(chapterOneCampaign.ownedRelicIDs)
                .subtracting(borrowed)
            state.bountyCarriedRelics[battleID] = carried.sorted()
        }
        return session
    }
    func finishChurchBounty(_ id: String, battleID: String, outcome: MPCChurchBattleOutcome) throws {
        let prior = churchServices
        if prior.bounties.cases[id]?.settledBattleIDs.contains(battleID) == true { return }
        let loss = outcome == .defeat
            ? MPCBountyDefeatRisk.loss(battleID: battleID, availableCopper: venueCoins,
                carriedOrdinaryRelicIDs: prior.bountyCarriedRelics[battleID] ?? []) : nil
        let relicSnapshot: BountyRelicSnapshot? = loss?.relicID.map { lostID in
            .init(ownedIDs: Array(chapterOneCampaign.ownedRelicIDs.subtracting([lostID])).sorted(),
                  equippedIDs: chapterOneCampaign.loadout.relicIDs.filter { $0 != lostID },
                  activeID: chapterOneCampaign.loadout.selectedActiveRelicID == lostID ? nil : chapterOneCampaign.loadout.selectedActiveRelicID)
        }
        try updateChurchServices(relicSnapshot: relicSnapshot) { state in
            let settled = try state.bounties.settleBattle(id, battleID: battleID, outcome: outcome)
            guard settled else { return }
            try settleChurchGear(&state, battleID: battleID, outcome: outcome)
            if let loss {
                state.loans.coins = max(0, state.loans.coins - loss.copper)
                if let lostID = loss.relicID { state.ownedCondition.retireLostCopy(lostID) }
                state.bountyDefeatLosses[battleID] = loss
            }
        }
    }
    func claimChurchBounty(_ id: String) throws {
        try updateChurchServices { state in
            if let reward = try state.bounties.claim(id) {
                state.loans.coins += reward.copper
                state.loans.lifetimeMerit += reward.merit
                state.loans.availableMerit += reward.merit
                state.bountyRelics.grant(caseID: id)
            }
        }
    }
}

extension GameStore {
    func applyingChurchLoans(to source: MPCChapterOneLoadout, allowsActive: Bool = true) -> MPCChapterOneLoadout {
        var loadout = source
        loadout.churchGear = churchServices.gear.stats
        loadout.bountyRelicID = churchServices.bountyRelics.equippedID
        loadout.outfit = MPCOutfit(rawValue: equippedOutfitID) ?? .mistportNight
        let condition = churchServices.ownedCondition
        loadout.relicIDs.removeAll { condition.currentDurability($0) == 0 }
        if let active = loadout.selectedActiveRelicID, condition.currentDurability(active) == 0 { loadout.selectedActiveRelicID = nil }
        for id in churchServices.equippedLoanIDs {
            guard let relic = churchServices.loans.effectiveRelicID(loanID: id) else { continue }
            if EarlyRelicShop.activeIDs.contains(relic) { if allowsActive { loadout.selectedActiveRelicID = relic } }
            else { loadout.relicIDs = [relic] }
        }
        return loadout
    }
}

extension GameStore {
var churchMaintenanceJobs: [MPCChurchMaintenanceJob] {
    churchServices.maintenance.jobs.values.sorted { $0.id < $1.id }
}
func acceptChurchMaintenance(kind: MPCChurchMaintenanceKind, floor: Int? = nil) throws -> String {
        try requireChurchMaintenanceAccess(kind)
    let id = UUID().uuidString
    try updateChurchServices { state in
        _ = try state.maintenance.accept(kind: kind, floor: floor,
            completedMissions: churchTowerMissionNumbers,
            clearedTowerFloors: churchTowerProgress.clearedFloors, jobID: id)
    }
    return id
}
func verifyChurchMaintenance(jobID: String, objectiveID: String, choiceID: String) throws {
        guard let job = churchServices.maintenance.jobs[jobID] else { throw MPCChurchMaintenanceError.invalidJob }; try requireChurchMaintenanceAccess(job.kind)
    try updateChurchServices { state in
        _ = try state.maintenance.verify(jobID: jobID, objectiveID: objectiveID, choiceID: choiceID)
    }
}
func beginChurchMaintenance(jobID: String, battleID: String, skills: [FoolSkillID]) throws -> MPCChapterOneEncounterSession {
        guard let accessJob = churchServices.maintenance.jobs[jobID] else { throw MPCChurchMaintenanceError.invalidJob }; try requireChurchMaintenanceAccess(accessJob.kind)
    guard let job = churchServices.maintenance.jobs[jobID] else { throw MPCChurchMaintenanceError.invalidJob }
    var loadout = churchBattleCampaign.loadout
    loadout.normalSkillIDs = skills; loadout.talents = hermitTalents; loadout.skillLevels = foolSkillLevels
    let session = try MPCChapterOneEncounterSession.start(encounterID: job.encounterID,
        party: chapterOneCampaign.party, consumables: chapterOneCampaign.inventory,
        companionIDs: [], loadout: loadout)
    try updateChurchServices { state in
        _ = try state.maintenance.beginBattle(jobID: jobID, battleID: battleID)
        try beginChurchGear(&state, battleID: battleID, loadout: loadout)
    }
    return session
}
func finishChurchMaintenance(jobID: String, battleID: String, outcome: MPCChurchBattleOutcome) throws {
    try updateChurchServicesAndWork { state, work in
        _ = try state.maintenance.settleBattle(jobID: jobID, battleID: battleID, outcome: outcome)
        try settleChurchGear(&state, battleID: battleID, outcome: outcome)
        if outcome == .victory, let reward = try state.maintenance.claim(jobID: jobID) {
            let payout = work.ledger.settle(receiptID: "maintenance-" + jobID, day: pacingDay, copper: reward.copper, merit: reward.merit)
            state.loans.coins += payout.copper
            state.loans.lifetimeMerit += payout.merit
            state.loans.availableMerit += payout.merit
        }
    }
}


}

extension GameStore {
    func presentingChurchLoans(in source: MPCChapterOneCampaignState) -> MPCChapterOneCampaignState {
        var result = source
        result.loadout = applyingChurchLoans(to: source.loadout)
        for relic in EarlyRelicShop.ids where churchServices.ownedCondition.currentDurability(relic) == 0 { result.depletedRelicIDs.insert(relic) }
        for id in churchServices.equippedLoanIDs {
            if let relic = churchServices.loans.effectiveRelicID(loanID: id) { result.ownedRelicIDs.insert(relic); result.depletedRelicIDs.remove(relic) }
        }
        return result
    }
}

#if DEBUG
extension GameStore {
    func prepareTavernPreview() {
        guard !tavernPokerUnlocked else { refreshTavernPrize(); return }
        venueCoins = 200
        completedChapterMissionIDs.insert("old-clock-9")
        let fixture = Data(#"{"cases":{"b08":{"claimed":true}}}"#.utf8)
        guard let ledger = try? JSONDecoder().decode(MPCChurchBountyLedger.self, from: fixture) else { return }
        try? updateChurchServices { $0.bounties = ledger }
        refreshTavernPrize()
    }

    static func verifyTavernPrizeSettlement() {
        let suite = "mistport.tavern-prize-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let game = GameStore(launchArguments: [], defaults: storage)
        game.venueCoins = 100
        game.completedChapterMissionIDs.insert("old-clock-9")
        let fixture = Data(#"{"cases":{"b08":{"claimed":true}}}"#.utf8)
        let ledger = try! JSONDecoder().decode(MPCChurchBountyLedger.self, from: fixture)
        try! game.updateChurchServices { $0.bounties = ledger }
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 25, hour: 12))!
        game.refreshTavernPrize(asOf: day)
        assert(game.availableTavernPrize?.itemID == "relic_deferred_stamp")
        let active = try! game.startChurchBountyDou("tavern", wager: 40, featuredPrize: true)
        assert(game.venueCoins == 60)
        var payload = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(active)) as! [String: Any]
        var hands = payload["hands"] as! [[Any]]
        hands[0] = [hands[0][0]]
        payload["hands"] = hands
        payload["phase"] = "playing"
        payload["landlord"] = 0
        payload["currentPlayer"] = 0
        payload["highestBid"] = 1
        let finishable = try! JSONDecoder().decode(MPCDouGame.self,
            from: JSONSerialization.data(withJSONObject: payload))
        try! game.updateChurchServices { $0.douActiveGames["tavern"] = finishable }
        let settled = try! game.playChurchBountyDou("tavern", gameID: active.gameID,
            cardIDs: [finishable.hands[0][0].id])
        assert(settled.settlement?.playerWon == true)
        assert(game.venueCoins == 100)
        assert(game.chapterOneCampaign.ownedRelicIDs.contains("relic_deferred_stamp"))
        assert(game.churchServices.tavernPrizePaidGames.contains(active.gameID))
        assert(game.availableTavernPrize == nil)
        let restored = GameStore(launchArguments: [], defaults: storage)
        assert(restored.venueCoins == 100 && restored.chapterOneCampaign.ownedRelicIDs.contains("relic_deferred_stamp"))
        assert(restored.churchServices.douSettlements[active.gameID] != nil)
        assert((try? restored.playChurchBountyDou("tavern", gameID: active.gameID,
            cardIDs: [finishable.hands[0][0].id])) == nil)
        let materialSuite = "mistport.tavern-material-check." + UUID().uuidString
        let materialStorage = UserDefaults(suiteName: materialSuite)!
        defer { materialStorage.removePersistentDomain(forName: materialSuite) }
        let materialGame = GameStore(launchArguments: [], defaults: materialStorage)
        materialGame.venueCoins = 100
        materialGame.completedChapterMissionIDs.insert("old-clock-17")
        materialGame.chapterOneCampaign.ownedRelicIDs.formUnion(MPCChurchLoanOffer.all.map(\.relicID))
        try! materialGame.updateChurchServices { $0.bounties = ledger }
        materialGame.refreshTavernPrize(asOf: day)
        assert(materialGame.availableTavernPrize?.itemID == "mirrorMothScale")
        let materialRound = try! materialGame.startChurchBountyDou("tavern", wager: 40, featuredPrize: true)
        var materialPayload = try! JSONSerialization.jsonObject(with: JSONEncoder().encode(materialRound)) as! [String: Any]
        var materialHands = materialPayload["hands"] as! [[Any]]
        materialHands[0] = [materialHands[0][0]]
        materialPayload["hands"] = materialHands
        materialPayload["phase"] = "playing"
        materialPayload["landlord"] = 0
        materialPayload["currentPlayer"] = 0
        materialPayload["highestBid"] = 1
        let finishableMaterial = try! JSONDecoder().decode(MPCDouGame.self,
            from: JSONSerialization.data(withJSONObject: materialPayload))
        try! materialGame.updateChurchServices { $0.douActiveGames["tavern"] = finishableMaterial }
        _ = try! materialGame.playChurchBountyDou("tavern", gameID: materialRound.gameID,
            cardIDs: [finishableMaterial.hands[0][0].id])
        assert(materialGame.advancementIngredients.contains(.mirrorMothScale))
        let materialRestored = GameStore(launchArguments: [], defaults: materialStorage)
        assert(materialRestored.advancementIngredients.contains(.mirrorMothScale))
        assert(materialRestored.venueCoins == 100)
        NSLog("TAVERN_PRIZE_VERIFY_PASS: gated, escrow, relic and material rewards, restart, duplicate rejection")
    }

    func prepareBountyPokerPreview() {
        guard churchServices.bounties.cases["b08"]?.accepted != true else { return }
        venueCoins = 100
        try? updateChurchServices { state in
            _ = try state.bounties.visit("b08", location: "酒馆", completedMissions: [])
            _ = try state.bounties.accept("b08", completedMissions: [])
        }
    }

    private static func verifyBountyPoker() {
        let suite = "mistport.bounty-poker-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let game = GameStore(launchArguments: [], defaults: storage)
        game.venueCoins = 100
        try! game.updateChurchServices { state in
            _ = try state.bounties.visit("b08", location: "酒馆", completedMissions: [])
            _ = try state.bounties.accept("b08", completedMissions: [])
        }
        let round = try! game.startChurchBountyPoker("b08", wager: 10)
        assert(game.venueCoins == 90)
        assert(try! game.startChurchBountyPoker("b08", wager: 40) == round)
        assert(game.venueCoins == 90)
        let reopened = GameStore(launchArguments: [], defaults: storage)
        assert(reopened.churchServices.pokerActiveRounds["b08"] == round)
        assert(reopened.venueCoins == 90)
        let settled = try! reopened.finishChurchBountyPoker("b08", roundID: round.roundID,
                                                              discarding: [0, 2])
        let after = 90 + settled.payout
        assert(reopened.venueCoins == after)
        assert(try! reopened.finishChurchBountyPoker("b08", roundID: round.roundID,
                                                      discarding: [1, 3]) == settled)
        assert(reopened.venueCoins == after)
        let secondReopen = GameStore(launchArguments: [], defaults: storage)
        assert(secondReopen.venueCoins == after)
        assert(secondReopen.churchServices.pokerSettlements[round.roundID] == settled)
        assert(secondReopen.churchServices.pokerActiveRounds["b08"] == nil)
        assert(secondReopen.churchServices.bounties.cases["b08"]?.pokerWins.contains("b08") == (settled.outcome == .win))
        let reliefSuite = "mistport.bounty-poker-relief-check." + UUID().uuidString
        let reliefStorage = UserDefaults(suiteName: reliefSuite)!
        defer { reliefStorage.removePersistentDomain(forName: reliefSuite) }
        let relief = GameStore(launchArguments: [], defaults: reliefStorage)
        relief.venueCoins = 0
        try! relief.updateChurchServices { state in
            _ = try state.bounties.visit("b03", location: "教会", completedMissions: [])
            _ = try state.bounties.accept("b03", completedMissions: [])
            _ = try state.bounties.visit("b03", location: "码头", completedMissions: [])
            state.pokerSimpleAttempts["b03"] = 4
        }
        let fifth = try! relief.startChurchBountyPoker("b03", wager: 10)
        assert(fifth.wager == 0 && relief.venueCoins == 0)
        let fifthResult = try! relief.finishChurchBountyPoker("b03", roundID: fifth.roundID,
                                                               discarding: [0, 2, 4])
        assert(fifthResult.outcome == .win && fifthResult.payout == 0)
        assert(relief.churchServices.bounties.cases["b03"]?.pokerWins.contains("b03") == true)

        let douSuite = "mistport.bounty-dou-check." + UUID().uuidString
        let douStorage = UserDefaults(suiteName: douSuite)!
        defer { douStorage.removePersistentDomain(forName: douSuite) }
        let dou = GameStore(launchArguments: [], defaults: douStorage)
        dou.venueCoins = 100
        try! dou.updateChurchServices { state in
            _ = try state.bounties.visit("b08", location: "酒馆", completedMissions: [])
            _ = try state.bounties.accept("b08", completedMissions: [])
        }
        var match = try! dou.startChurchBountyDou("b08", wager: 10)
        assert(dou.venueCoins == 90)
        let douReopen = GameStore(launchArguments: [], defaults: douStorage)
        assert(douReopen.churchServices.douActiveGames["b08"] == match)
        var actions = 0
        while match.phase != .finished && actions < 300 {
            actions += 1
            assert(match.currentPlayer == 0)
            if match.phase == .bidding {
                match = try! douReopen.bidChurchBountyDou("b08", gameID: match.gameID, points: 3)
            } else {
                let moves = MPCDouRules.legalMoves(match.hands[0], beating: MPCDouRules.classify(match.lastPlay))
                if let move = moves.first {
                    match = try! douReopen.playChurchBountyDou("b08", gameID: match.gameID,
                                                                cardIDs: Set(move.map(\.id)))
                } else {
                    match = try! douReopen.passChurchBountyDou("b08", gameID: match.gameID)
                }
            }
        }
        assert(match.phase == .finished && actions < 300)
        let douResult = match.settlement!
        assert(douReopen.churchServices.douSettlements[match.gameID] == douResult)
        assert(douReopen.venueCoins == 90 + douResult.payout)
        assert(douReopen.churchServices.bounties.cases["b08"]?.pokerWins.contains("b08") == douResult.playerWon)
        print("BOUNTY_POKER_VERIFY_PASS: simple stake/recovery, fifth-hand no-cash clue, two-deck full match/settlement")
    }

    private static func verifyBountyDailyRisk() {
        let suite = "mistport.bounty-daily-risk-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let game = GameStore(launchArguments: [], defaults: storage)
        game.venueCoins = 1_000
        game.chapterOneCampaign.ownedRelicIDs.insert(EarlyRelicShop.salt)
        game.chapterOneCampaign.loadout.relicIDs = [EarlyRelicShop.salt]
        game.persistChapterProgress()
        game.refreshChurchBountyBoard()
        let issue = game.churchServices.dailyBountyIssue!
        assert((3...6).contains(issue.offerIDs.count))
        let bounty = issue.offerIDs.compactMap(MPCChurchBountyCatalog.bounty(id:))
            .first { $0.id != "b03" && $0.id != "b08" }!
        try! game.visitChurchBounty(bounty.id, location: "教会")
        try! game.acceptChurchBounty(bounty.id)
        for node in bounty.nodes {
            try! game.visitChurchBounty(bounty.id, location: node.location)
            if node.id == "identity" {
                try! game.inspectChurchBountySite(bounty.id, featureID: "appearance")
                try! game.inspectChurchBountySite(bounty.id, featureID: "conduct")
            }
            if let challenge = MPCChurchBountyCatalog.challenge(caseID: bounty.id, nodeID: node.id) {
                try! game.answerChurchBounty(bounty.id, nodeID: node.id, choiceID: challenge.correctChoiceID)
            } else {
                try! game.investigateChurchBounty(bounty.id, nodeID: node.id)
            }
        }
        try! game.presentChurchBountyWarrant(bounty.id, suspectID: bounty.enemyID,
                                             supportingEvidenceIDs: ["witness", "wound"])
        let battleID = (0..<2_000).map { "risk-\($0)" }.first {
            MPCBountyDefeatRisk.loss(battleID: $0, availableCopper: 1_000,
                                     carriedOrdinaryRelicIDs: [EarlyRelicShop.salt]).copper > 0
        }!
        _ = try! game.beginChurchBounty(bounty.id, battleID: battleID, skills: [])
        try! game.finishChurchBounty(bounty.id, battleID: battleID, outcome: .defeat)
        assert(game.venueCoins == 940)
        assert(game.chapterOneCampaign.ownedRelicIDs.contains(EarlyRelicShop.salt))
        assert(game.chapterOneCampaign.loadout.relicIDs == [EarlyRelicShop.salt])
        let reopened = GameStore(launchArguments: [], defaults: storage)
        assert(reopened.venueCoins == 940)
        assert(reopened.churchServices.bountyDefeatLosses[battleID]?.relicID == nil)
        assert(reopened.chapterOneCampaign.ownedRelicIDs.contains(EarlyRelicShop.salt))
        try! reopened.finishChurchBounty(bounty.id, battleID: battleID, outcome: .defeat)
        assert(reopened.venueCoins == 940)
        assert(reopened.churchServices.bounties.cases[bounty.id]?.evidenceIDs.contains("identity") == true)
        NSLog("BOUNTY_DAILY_RISK_VERIFY_PASS: no mission gate, daily issue, copper-only loss, relic kept, reload, no double charge, evidence retained")
    }
    private static func verifyChurchDeparture() {
        let suite = "mistport.church-departure-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let game = GameStore(launchArguments: [], defaults: storage)
        assert(game.churchRemoteServicesAvailable && game.churchMistportFieldworkAvailable)
        game.completedChapterMissionIDs.insert("old-clock-30")
        game.persistChapterProgress()
        assert(game.churchNeedsRemoteContact && !game.churchRemoteServicesAvailable)
        do { try game.requireChurchRemoteService(); assertionFailure("contact required") } catch {}
        do { try game.requireChurchMistportFieldwork(); assertionFailure("fieldwork paused") } catch {}
        assert(try! game.establishChurchRemoteContact())
        assert(!(try! game.establishChurchRemoteContact()))
        let restored = GameStore(launchArguments: [], defaults: storage)
        assert(restored.churchRemoteServicesAvailable && !restored.churchMistportFieldworkAvailable)
        assert(restored.churchRemoteContactEstablished)
        NSLog("CHURCH_DEPARTURE_VERIFY_PASS: saved departure, remote contact idempotent restore, fieldwork remains paused")
    }
    private static func verifyChurchServices() {
        let suite = "mistport.church-services-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        let game = GameStore(launchArguments: [], defaults: storage)
        game.completedChapterMissionIDs = Set((1...29).map { "old-clock-\($0)" })
        game.venueCoins = 2000
        game.chapterOneCampaign.lifetimeChurchMerit = 200
        game.chapterOneCampaign.spendableChurchMerit = 200
        game.persistChapterProgress()
        try! game.borrowChurchRelic(EarlyRelicShop.salt)
        let loan = game.churchServices.loans.loans.values.first!
        assert(game.venueCoins == 1908 && game.chapterOneCampaign.spendableChurchMerit == 200)
        assert(!game.chapterOneCampaign.ownedRelicIDs.contains(EarlyRelicShop.salt))
        try! game.equipChurchLoan(loan.id)
        assert(game.churchBattleCampaign.loadout.relicIDs == [EarlyRelicShop.salt])
        try! game.beginChurchLoanBattle("native-test")
        let restored = GameStore(launchArguments: [], defaults: storage)
        assert(restored.churchServices.loans.loans[loan.id]?.remainingBattles == 2)
        restored.finishChurchLoanBattle("native-test", outcome: .defeat)
        restored.finishChurchLoanBattle("native-test", outcome: .retreat)
        assert(restored.churchServices.loans.loans[loan.id]?.durability == 95)
        try! restored.returnChurchRelic(loan.id)
        let afterReturn = restored.venueCoins
        try! restored.returnChurchRelic(loan.id)
        assert(afterReturn == 1988 && restored.venueCoins == afterReturn && restored.chapterOneCampaign.spendableChurchMerit == 200)
        assert(restored.churchServices.equippedLoanIDs.isEmpty)
        restored.refreshChurchBountyBoard()
        let bounty = MPCChurchBountyCatalog.all.first {
            restored.churchServices.dailyBountyIssue?.offerIDs.contains($0.id) == true
                && $0.id != "b03" && $0.id != "b08"
        }!
        try! restored.visitChurchBounty(bounty.id, location: "教会")
        try! restored.acceptChurchBounty(bounty.id)
        for node in bounty.nodes {
            try! restored.visitChurchBounty(bounty.id, location: node.location)
            if node.id == "identity" {
                try! restored.inspectChurchBountySite(bounty.id, featureID: "appearance")
                try! restored.inspectChurchBountySite(bounty.id, featureID: "conduct")
            }
            if let challenge = MPCChurchBountyCatalog.challenge(caseID: bounty.id, nodeID: node.id) {
                try! restored.answerChurchBounty(bounty.id, nodeID: node.id, choiceID: challenge.correctChoiceID)
            } else { try! restored.investigateChurchBounty(bounty.id, nodeID: node.id) }
        }
        try! restored.presentChurchBountyWarrant(bounty.id, suspectID: bounty.enemyID, supportingEvidenceIDs: ["witness", "wound"])
        _ = try! restored.beginChurchBounty(bounty.id, battleID: "native-bounty", skills: [])
        try! restored.finishChurchBounty(bounty.id, battleID: "native-bounty", outcome: .victory)
        assert(restored.churchServices.bounties.cases[bounty.id]?.pendingTurnIn == true)
        try! restored.visitChurchBounty(bounty.id, location: "教会")
        try! restored.claimChurchBounty(bounty.id)
        let coinsAfterBounty = restored.venueCoins
        try! restored.finishChurchBounty(bounty.id, battleID: "native-bounty", outcome: .victory)
        assert(restored.venueCoins == coinsAfterBounty && restored.churchServices.bounties.cases[bounty.id]?.claimed == true)
        let receipt = ChurchServicesReceipt(state: restored.churchServices, coins: coinsAfterBounty + 1, lifetime: 212, available: 211)
        storage.set(try! JSONEncoder().encode(receipt), forKey: "mistport.church.services.pending.v1")
        let recovered = GameStore(launchArguments: [], defaults: storage)
        assert(recovered.venueCoins == coinsAfterBounty + 1)
        let again = GameStore(launchArguments: [], defaults: storage)
        assert(again.venueCoins == recovered.venueCoins && again.churchServices.bounties.cases[bounty.id]?.claimed == true)
        NSLog("CHURCH_SERVICES_VERIFY_PASS: borrow equip reserve restore settle return, ownership isolation, bounty evidence and idempotent reward, atomic recovery")
        Task { @MainActor in renderChurchDelivery(recovered); storage.removePersistentDomain(forName: suite) }
    }
}
#endif


// A saved remote-contact acknowledgment restores the same church services;
// it neither teleports the player back to Mistport nor creates chapter-two play.
enum ChurchFieldworkAccessError: Error { case awaitingBlackSaltContact, mistportFieldworkPaused }
extension GameStore {
    var churchHasDepartedMistport: Bool {
        completedChapterMissionIDs.contains("old-clock-30")
            || chapterOneCampaign.completedMissionIDs.contains("chapter01_q30")
            || chapterOneCampaign.completedEncounterIDs.contains("chapter01_q30_encounter")
    }
    var churchRemoteContactEstablished: Bool {
        _ = churchServicesRevision
        return churchHasDepartedMistport && defaults.bool(forKey:"mistport.church.remote-contact.v1")
    }
    var churchNeedsRemoteContact: Bool { churchHasDepartedMistport && !churchRemoteContactEstablished }
    var churchRemoteServicesAvailable: Bool { !churchHasDepartedMistport || churchRemoteContactEstablished }
    var churchMistportFieldworkAvailable: Bool { !churchHasDepartedMistport }
    var churchRemoteContactPauseReason: String { "已抵达黑盐岸。先核对联络凭据，再恢复同一封堵与借物账；层数、功勋和押金均保留。" }
    var churchMistportPauseReason: String { "雾港现场调查暂停，等待剧情开放回访；已取线索、未结工单与已得报酬保留。" }
    @discardableResult func establishChurchRemoteContact() throws -> Bool {
        guard churchHasDepartedMistport else { throw ChurchFieldworkAccessError.awaitingBlackSaltContact }
        if churchRemoteContactEstablished { return false }
        defaults.set(true,forKey:"mistport.church.remote-contact.v1")
        churchServicesRevision += 1
        return true
    }
    func requireChurchRemoteService() throws {
        guard churchRemoteServicesAvailable else { throw ChurchFieldworkAccessError.awaitingBlackSaltContact }
    }
    func requireChurchMistportFieldwork() throws {
        guard churchMistportFieldworkAvailable else { throw ChurchFieldworkAccessError.mistportFieldworkPaused }
    }
    func churchMaintenanceAvailable(_ kind: MPCChurchMaintenanceKind) -> Bool {
        kind == .patrol ? churchMistportFieldworkAvailable : churchRemoteServicesAvailable
    }
    private func requireChurchMaintenanceAccess(_ kind: MPCChurchMaintenanceKind) throws {
        if kind == .patrol { try requireChurchMistportFieldwork() } else { try requireChurchRemoteService() }
    }
    func beginChurchTower(floor: Int, battleID: String, skills: [FoolSkillID]) throws -> MPCChapterOneEncounterSession {
        try requireChurchRemoteService()
        guard churchTowerProgress.canEnter(floor,completedMissionNumbers:churchTowerMissionNumbers),
              towerFloorIsOpenToday(floor),
              let definition = MPCChurchTowerCatalog.floor(number:floor) else { throw MPCEncounterRuntimeError.unknownEncounter }
        var loadout = churchBattleCampaign.loadout
        // The tower uses the same owned cards and slot limit as the campaign.
        // A stale picker or verification caller must not grant future skills.
        var legalSkills: [FoolSkillID] = []
        for skill in skills where skill != .maskedWhisper && chapterOneCampaign.unlockedSkillIDs.contains(skill) {
            if !legalSkills.contains(skill) { legalSkills.append(skill) }
        }
        loadout.normalSkillIDs = Array(legalSkills.prefix(chapterOneLoadoutSlotCapacity))
        loadout.talents = hermitTalents; loadout.skillLevels = foolSkillLevels
        let session = try MPCChapterOneEncounterSession.start(encounterID:definition.id,party:chapterOneCampaign.party,
            consumables:chapterOneCampaign.inventory,companionIDs:[],loadout:loadout)
        // The battle ticket and equipment receipt are written together before combat starts.
        guard dailyWorkshopIsReadable else { throw MPCLocalWorkshopLedger.Failure.locked }
        var workshop = dailyWorkshopRecord
        guard !battleID.isEmpty, workshop.towerTickets[battleID] == nil, !workshop.finishedTowerTickets.contains(battleID) else { throw MPCLocalWorkshopLedger.Failure.conflict }
        workshop.towerTickets[battleID] = floor
        try updateChurchServices(dailyWorkshop: workshop) { state in
            try beginChurchGear(&state, battleID: battleID, loadout: loadout)
        }
        return session
    }
    var churchPendingRewardCount: Int {
        let state=churchServices
        return state.bounties.cases.values.filter { !$0.claimed && $0.victoriousBattleID != nil }.count
            + state.maintenance.jobs.values.filter { !$0.claimed && $0.allSitesComplete }.count
    }
    func claimCompletedChurchAccounts() throws {
        try updateChurchServicesAndWork { state, work in
            for id in state.bounties.cases.keys.sorted() {
                guard let progress=state.bounties.cases[id], !progress.claimed, progress.victoriousBattleID != nil else { continue }
                if let reward=try state.bounties.claim(id) {
                    state.loans.coins += reward.copper; state.loans.lifetimeMerit += reward.merit; state.loans.availableMerit += reward.merit
                }
            }
            for id in state.maintenance.jobs.keys.sorted() {
                guard let job=state.maintenance.jobs[id], !job.claimed, job.allSitesComplete else { continue }
                if let reward=try state.maintenance.claim(jobID:id) {
                    let payout = work.ledger.settle(receiptID: "maintenance-" + id, day: pacingDay, copper: reward.copper, merit: reward.merit)
                    state.loans.coins += payout.copper; state.loans.lifetimeMerit += payout.merit; state.loans.availableMerit += payout.merit
                }
            }
        }
    }
}


extension GameStore {
    var localWorkshop: MPCLocalWorkshopLedger { churchServices.workshop }
    var workshopHideCount: Int { chapterOneCampaign.inventory[MPCLocalWorkshopLedger.hideID, default: 0] }
    var workshopStrapCount: Int { chapterOneCampaign.inventory[MPCLocalWorkshopLedger.strapID, default: 0] }
    var workshopLedgerIsReadable: Bool {
        guard let data = defaults.data(forKey: "mistport.church.services.v1") else { return true }
        return (try? JSONDecoder().decode(ChurchServicesState.self, from: data)) != nil
    }
    private func requireLocalWorkshop() throws {
        guard cityServiceIsUnlocked(.workshop), phase != .dungeon, workshopLedgerIsReadable,
              churchMistportFieldworkAvailable else {
            throw MPCLocalWorkshopLedger.Failure.locked
        }
    }
    func learnWorkshopBasics() throws {
        try requireLocalWorkshop()
        acknowledgeMissionReward()
        try updateChurchServices { state in
            try state.workshop.learnBasics(completedMissions: churchTowerMissionNumbers)
        }
    }
    func craftWorkshopStraps(transactionID: String = UUID().uuidString) throws {
        try craftDailyWorkshop(recipeID: "recipe_repair_strap", transactionID: transactionID)
    }
    func deliverWorkshopStraps(transactionID: String = UUID().uuidString) throws {
        try requireLocalWorkshop()
        acknowledgeMissionReward()
        var ledger = localWorkshop, coins = venueCoins
        var inventory = chapterOneCampaign.inventory
        _ = try ledger.deliver(id: transactionID, completedMissions: churchTowerMissionNumbers,
                               coins: &coins, inventory: &inventory)
        try updateChurchServices(inventory: inventory) { state in
            state.workshop = ledger; state.loans.coins = coins
        }
    }
    func installWorkshopStraps(transactionID: String = UUID().uuidString) throws {
        try requireLocalWorkshop()
        acknowledgeMissionReward()
        try updateChurchServices { state in
            _ = try state.workshop.install(id: transactionID, completedMissions: churchTowerMissionNumbers)
        }
    }
}

// MARK: Lights event, local loop at the transfer station
// Eligibility is the Chapter Two story (ritual + both contacts met). Coins,
// inventory and the event ledger are committed in one church-services receipt.
extension GameStore {
    var lightsEvent: MPCLightsLocalEvent { churchServices.lightsEvent }
    var lightsEventEligible: Bool { chapterTwoBridgeOpen && chapterTwoBridge.worldEventStoryReady }
    var lightsHideCount: Int { chapterOneCampaign.inventory[MPCLocalWorkshopLedger.hideID, default: 0] }
    var lightsStrapCount: Int { chapterOneCampaign.inventory[MPCLightsLocalEvent.strapID, default: 0] }

    func chooseLightsSide(_ side: MPCLightsLocalEvent.Faction) throws {
        let eligible = lightsEventEligible
        try updateChurchServices { state in _ = try state.lightsEvent.choose(side, id: "side", eligible: eligible) }
    }
    /// The station workbench runs the same leather recipe as the paused Mistport workshop.
    func craftStrapsAtStation(transactionID: String = UUID().uuidString) throws {
        guard lightsEventEligible else { throw MPCLightsLocalEvent.Failure.locked }
        try craftDailyWorkshop(recipeID: "recipe_repair_strap", transactionID: transactionID, atStation: true)
    }
    func deliverLightsStraps(transactionID: String = UUID().uuidString) throws {
        var event = lightsEvent, coins = venueCoins
        var inventory = chapterOneCampaign.inventory
        _ = try event.deliver(id: transactionID, eligible: lightsEventEligible, coins: &coins, inventory: &inventory)
        try updateChurchServices(inventory: inventory) { state in
            state.lightsEvent = event; state.loans.coins = coins
        }
    }
    func installLightsKit(transactionID: String = UUID().uuidString) throws {
        let eligible = lightsEventEligible
        try updateChurchServices { state in _ = try state.lightsEvent.install(id: transactionID, eligible: eligible) }
    }
    /// Setup preview only; nothing is written until the battle starts.
    func lightsPublicPreview(battleID: String) throws -> MPCChapterOneEncounterSession {
        guard let side = lightsEvent.side else { throw MPCLightsLocalEvent.Failure.locked }
        return try MPCChapterOneEncounterSession.start(encounterID: MPCLightsPublicTarget.encounterID(side: side, ticket: battleID),
            party: chapterOneCampaign.party, consumables: chapterOneCampaign.inventory, companionIDs: [], loadout: churchBattleCampaign.loadout)
    }
    /// The world ticket and the equipment receipt are written together before combat.
    func beginLightsPublic(battleID: String, skills: [FoolSkillID]) throws -> MPCChapterOneEncounterSession {
        var loadout = churchBattleCampaign.loadout
        var legalSkills: [FoolSkillID] = []
        for skill in skills where skill != .maskedWhisper && chapterOneCampaign.unlockedSkillIDs.contains(skill) {
            if !legalSkills.contains(skill) { legalSkills.append(skill) }
        }
        loadout.normalSkillIDs = Array(legalSkills.prefix(chapterOneLoadoutSlotCapacity))
        loadout.talents = hermitTalents; loadout.skillLevels = foolSkillLevels
        var event = lightsEvent
        let encounterID = try event.beginPublic(id: battleID, eligible: lightsEventEligible)
        let session = try MPCChapterOneEncounterSession.start(encounterID: encounterID, party: chapterOneCampaign.party,
            consumables: chapterOneCampaign.inventory, companionIDs: [], loadout: loadout)
        try updateChurchServices { state in
            try beginChurchGear(&state, battleID: battleID, loadout: loadout)
            state.lightsEvent = event
        }
        return session
    }
    func settleLightsPublic(battleID: String, session: MPCChapterOneEncounterSession) {
        try? updateChurchServices { state in
            try settleChurchGear(&state, battleID: battleID, outcome: session.outcome == .victory ? .victory : .defeat)
            _ = try state.lightsEvent.settlePublic(id: battleID, session: session)
        }
    }
    func abandonLightsPublic(battleID: String, defeated: Bool) {
        try? updateChurchServices { state in
            try settleChurchGear(&state, battleID: battleID, outcome: defeated ? .defeat : .retreat)
            state.lightsEvent.abandonPublic(id: battleID, defeated: defeated)
        }
    }
}

#if DEBUG
extension GameStore {
    /// The workshop device walk plays in its own suite and never opens the player's.
    static let workshopDeviceWalkSuite = "mistport.workshop-device-walk"

    /// Opens the walk suite, seeding it once as a player who has just cleared Q16.
    static func workshopDeviceWalkDefaults() -> UserDefaults {
        let storage = UserDefaults(suiteName: workshopDeviceWalkSuite)!
        let seededKey = "mistport.workshop-device-walk.seeded"
        guard !storage.bool(forKey: seededKey) else { return storage }
        GameStore(launchArguments: [], defaults: storage).debugJumpToOldClockMission(17, enterImmediately: false)
        storage.set(Pathway.ID.fool.rawValue, forKey: PersistenceKey.selectedPathID)
        storage.set(CharacterGender.male.rawValue, forKey: PersistenceKey.selectedCharacterGender)
        storage.set(true, forKey: seededKey)
        return storage
    }

    /// The Chapter Two bridge walk: its own suite, seeded once as a player who
    /// has just cleared Q30 with the three materials and 1000 copper in hand.
    static let chapterTwoBridgeWalkSuite = "mistport.chapter2-bridge-walk"

    static func chapterTwoBridgeWalkDefaults() -> UserDefaults {
        let storage = UserDefaults(suiteName: chapterTwoBridgeWalkSuite)!
        let seededKey = "mistport.chapter2-bridge-walk.seeded"
        guard !storage.bool(forKey: seededKey) else { return storage }
        GameStore(launchArguments: [], defaults: storage).debugJumpToOldClockMission(30, enterImmediately: false)
        storage.set((1...30).map { "old-clock-\($0)" }, forKey: PersistenceKey.completedChapterMissionIDs)
        storage.set(1000, forKey: PersistenceKey.venueCoins)
        storage.set(AdvancementIngredient.allCases.map(\.rawValue), forKey: PersistenceKey.advancementIngredients)
        storage.set(Pathway.ID.fool.rawValue, forKey: PersistenceKey.selectedPathID)
        storage.set(CharacterGender.male.rawValue, forKey: PersistenceKey.selectedCharacterGender)
        storage.set(true, forKey: seededKey)
        return storage
    }

    /// Sequence 8 ritual transaction on disposable suites; the report goes to Documents.
    static func verifySequenceEightRitual() {
        let suites = ["main", "interrupted", "legacy"].map { "mistport.sequence8-check.\($0)." + UUID().uuidString }
        defer { suites.forEach { UserDefaults(suiteName: $0)?.removePersistentDomain(forName: $0) } }
        var checks: [String] = []
        func check(_ condition: Bool, _ label: String) throws {
            guard condition else { throw NSError(domain: "SequenceEightRitualVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: label]) }
            checks.append(label)
        }
        func seed(_ storage: UserDefaults, through mission: Int, coins: Int, materials: [AdvancementIngredient] = AdvancementIngredient.allCases) {
            storage.set((1...mission).map { "old-clock-\($0)" }, forKey: PersistenceKey.completedChapterMissionIDs)
            storage.set(coins, forKey: PersistenceKey.venueCoins)
            storage.set(materials.map(\.rawValue), forKey: PersistenceKey.advancementIngredients)
        }
        var report: [String: Any] = ["scope": "Production GameStore on disposable suites; player save untouched"]
        do {
            let storage = UserDefaults(suiteName: suites[0])!
            seed(storage, through: 29, coins: 1000)
            var store = GameStore(launchArguments: [], defaults: storage)
            store.performAdvancement()
            try check(store.sequenceEightRitual == nil && store.venueCoins == 1000 && store.advancementIngredients.count == 3, "before Q30 nothing is spent")
            seed(storage, through: 30, coins: 279)
            store = GameStore(launchArguments: [], defaults: storage)
            try check(store.missingSequenceEightProofNames.isEmpty, "Q25/26/30 proofs come from story progress")
            store.performAdvancement()
            try check(store.sequenceEightRitual == nil && store.venueCoins == 279 && store.advancementIngredients.count == 3, "279 copper: refused, nothing spent")
            seed(storage, through: 30, coins: 1000, materials: [.mirrorMothScale, .reverseClockEssence])
            store = GameStore(launchArguments: [], defaults: storage)
            store.performAdvancement()
            try check(store.sequenceEightRitual == nil && store.venueCoins == 1000 && store.advancementIngredients.count == 2, "missing material: refused, nothing spent")
            seed(storage, through: 30, coins: 1000)
            store = GameStore(launchArguments: [], defaults: storage)
            store.performAdvancement()
            try check(store.venueCoins == 720 && store.advancementIngredients.isEmpty && store.sequenceEightRitual?.fee == 280, "ritual spends three materials and 280 once")
            try check(store.missingSequenceEightProofNames.isEmpty, "proofs are checked, not consumed")
            try check(store.currentSequence == 9 && store.displayedSequence == 8 && store.sequenceEightQualified, "shows Sequence 8; combat sequence unchanged")
            store.performAdvancement()
            try check(store.venueCoins == 720, "second tap is not charged")
            let reloaded = GameStore(launchArguments: [], defaults: storage)
            try check(reloaded.venueCoins == 720 && reloaded.advancementIngredients.isEmpty && reloaded.displayedSequence == 8, "receipt and balances survive reload")
            reloaded.restart()
            try check(reloaded.sequenceEightRitual == nil && storage.data(forKey: sequenceEightRitualKey) == nil, "restart clears the ritual record")

            let interrupted = UserDefaults(suiteName: suites[1])!
            seed(interrupted, through: 30, coins: 1000)
            var coins = 1000, ingredients = Set(AdvancementIngredient.allCases.map(\.rawValue))
            let receipt = try MPCSequenceEightRitual.perform(id: "interrupted", completedMissions: Set(1...30), coins: &coins,
                ingredients: &ingredients, inventory: Dictionary(uniqueKeysWithValues: MPCSequenceEightRitual.proofIDs.map { ($0, 1) }), existing: nil)
            interrupted.set(try JSONEncoder().encode(SequenceEightRitualCommit(receipt: receipt, coins: coins, ingredients: ingredients.sorted())),
                            forKey: sequenceEightRitualCommitKey)
            let recovered = GameStore(launchArguments: [], defaults: interrupted)
            try check(recovered.venueCoins == 720 && recovered.advancementIngredients.isEmpty && recovered.sequenceEightRitual?.id == "interrupted"
                      && interrupted.object(forKey: sequenceEightRitualCommitKey) == nil, "commit written before a crash is applied exactly once")

            let legacy = UserDefaults(suiteName: suites[2])!
            seed(legacy, through: 30, coins: 1000)
            legacy.set(8, forKey: PersistenceKey.currentSequence)
            let old = GameStore(launchArguments: [], defaults: legacy)
            old.performAdvancement()
            try check(old.venueCoins == 1000 && old.advancementIngredients.count == 3 && old.displayedSequence == 8, "old Sequence 8 save is kept and never charged")
            report["passed"] = true
        } catch {
            report["passed"] = false
            report["failure"] = error.localizedDescription
        }
        report["checks"] = checks
        if let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: folder.appendingPathComponent("sequence8-ritual-verification.json"))
        }
    }

    /// Chapter Two bridge on a disposable suite: gates, contacts, return path,
    /// reload, restart, and Chapter One progress byte-identical throughout.
    static func verifyChapterTwoBridge() {
        let suite = "mistport.chapter2-bridge-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        var checks: [String] = []
        func check(_ condition: Bool, _ label: String) throws {
            guard condition else { throw NSError(domain: "ChapterTwoBridgeVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: label]) }
            checks.append(label)
        }
        struct ChapterOneSnapshot: Equatable {
            let missionIDs: Set<String>
            let campaign: MPCChapterOneCampaignState
        }
        func chapterOneSnapshot(_ store: GameStore) -> ChapterOneSnapshot {
            ChapterOneSnapshot(missionIDs: store.completedChapterMissionIDs, campaign: store.chapterOneCampaign)
        }
        var report: [String: Any] = ["scope": "Production GameStore on a disposable suite; player save untouched"]
        do {
            storage.set((1...29).map { "old-clock-\($0)" }, forKey: PersistenceKey.completedChapterMissionIDs)
            storage.set(1000, forKey: PersistenceKey.venueCoins)
            storage.set(AdvancementIngredient.allCases.map(\.rawValue), forKey: PersistenceKey.advancementIngredients)
            var store = GameStore(launchArguments: [], defaults: storage)
            store.travelToSaltportStation()
            try check(!store.chapterTwoBridgeOpen && store.chapterTwoBridge.location == .shore, "before Q30 the station is closed")
            storage.set((1...30).map { "old-clock-\($0)" }, forKey: PersistenceKey.completedChapterMissionIDs)
            store = GameStore(launchArguments: [], defaults: storage)
            store.travelToSaltportStation()
            try check(!store.chapterTwoBridgeOpen && store.chapterTwoBridge.location == .shore, "after Q30 without the ritual the station is closed")
            store.performAdvancement()
            try check(store.sequenceEightRitual != nil && store.chapterTwoBridgeOpen, "ritual opens the bridge")
            let chapterOne = chapterOneSnapshot(store)
            let coins = store.venueCoins
            store.meetSaltportContact(.aidaVein)
            try check(store.chapterTwoBridge.metContacts.isEmpty, "contacts are met only at the station")
            store.travelToSaltportStation()
            store.meetSaltportContact(.aidaVein)
            store.meetSaltportContact(.rowanKell)
            store.meetSaltportContact(.aidaVein)
            try check(store.chapterTwoBridge.metContacts == [.aidaVein, .rowanKell] && store.chapterTwoBridge.worldEventStoryReady, "both contacts met once each")
            store.returnToBlackSaltShore()
            try check(store.chapterTwoBridge.location == .shore, "return path leads back to the shore")
            try check(chapterOneSnapshot(store) == chapterOne && store.venueCoins == coins && store.churchHasDepartedMistport,
                      "Q30 outcome, Chapter One campaign and copper unchanged")
            let reloaded = GameStore(launchArguments: [], defaults: storage)
            try check(reloaded.chapterTwoBridge == store.chapterTwoBridge && chapterOneSnapshot(reloaded) == chapterOne, "bridge survives reload")
            reloaded.restart()
            try check(reloaded.chapterTwoBridge == MPCChapterTwoBridge() && storage.data(forKey: chapterTwoBridgeKey) == nil, "restart clears the bridge")
            report["passed"] = true
        } catch {
            report["passed"] = false
            report["failure"] = error.localizedDescription
        }
        report["checks"] = checks
        if let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: folder.appendingPathComponent("chapter2-bridge-verification.json"))
        }
    }

    /// Lights local loop on a disposable suite: story gate, workbench, funded
    /// delivery, installation, one real public battle, reload and restart.
    static func verifyLightsLocalEvent() {
        let suite = "mistport.lights-local-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        var checks: [String] = []
        func check(_ condition: Bool, _ label: String) throws {
            guard condition else { throw NSError(domain: "LightsLocalVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: label]) }
            checks.append(label)
        }
        var report: [String: Any] = ["scope": "Production GameStore on a disposable suite; player save untouched"]
        do {
            storage.set((1...30).map { "old-clock-\($0)" }, forKey: PersistenceKey.completedChapterMissionIDs)
            storage.set(1000, forKey: PersistenceKey.venueCoins)
            storage.set(AdvancementIngredient.allCases.map(\.rawValue), forKey: PersistenceKey.advancementIngredients)
            storage.set([MPCLocalWorkshopLedger.hideID: 1], forKey: "mistport.campaign-inventory.v1")
            var store = GameStore(launchArguments: [], defaults: storage)
            try check((try? store.chooseLightsSide(.pumps)) == nil && store.lightsEvent.side == nil, "closed before the ritual and both contacts")
            store.performAdvancement()
            store.travelToSaltportStation()
            store.meetSaltportContact(.aidaVein); store.meetSaltportContact(.rowanKell)
            try check(store.lightsEventEligible, "ritual and both contacts open the event")
            try store.chooseLightsSide(.pumps)
            try store.craftStrapsAtStation(transactionID: "craft-1")
            try check(store.venueCoins == 707 && store.lightsHideCount == 0 && store.lightsStrapCount == 3, "workbench: 1 hide + 13 copper -> 3 straps")
            try store.deliverLightsStraps(transactionID: "deliver-1")
            try store.deliverLightsStraps(transactionID: "deliver-1")
            try check(store.venueCoins == 725 && store.lightsStrapCount == 1 && store.lightsEvent.projectCash == 0, "delivery pays 18 once from the project budget")
            try check((try? store.deliverLightsStraps(transactionID: "deliver-2")) == nil && store.venueCoins == 725, "full order refuses more straps")
            try store.installLightsKit(transactionID: "install-1")
            try check(store.lightsEvent.installedKits == 12, "installation completes 12/12")
            store = GameStore(launchArguments: [], defaults: storage)
            try check(store.lightsEvent.installedKits == 12 && store.venueCoins == 725 && store.lightsStrapCount == 1, "ledger, copper and straps survive reload")
            var battle = try store.beginLightsPublic(battleID: "public-1", skills: [])
            for step in 0..<400 where battle.outcome == .inProgress {
                if battle.isAwaitingTowerWave {
                    let now = Double(step) * 2 + 10
                    _ = battle.advanceRelicClock(at: now); battle.advanceChurchTowerEffects(at: now)
                }
                for enemy in battle.enemies.filter(\.isAlive) where battle.outcome == .inProgress {
                    _ = try battle.applyPartyDamage(99_999, to: enemy.id)
                    if battle.outcome == .inProgress, battle.enemies.contains(where: { $0.id == enemy.id && $0.isAlive }) {
                        battle.commitEnemyImpact(from: enemy.id)
                        try? battle.endRound(actingEnemyID: enemy.id, at: Double(step))
                    }
                }
            }
            try check(battle.outcome == .victory, "public target is a real runtime battle won by damage")
            try check((try? store.beginLightsPublic(battleID: "public-2", skills: [])) == nil, "second attempt refused while the first is open")
            store.settleLightsPublic(battleID: "public-1", session: battle)
            store.settleLightsPublic(battleID: "public-1", session: battle)
            try check(store.lightsEvent.publicWon && store.lightsEvent.closed && store.lightsEvent.contract == .awarded(.pumps), "victory: own side qualifies and leads")
            try check(store.venueCoins == 725, "the result pays no victory bonus")
            let reloaded = GameStore(launchArguments: [], defaults: storage)
            try check(reloaded.lightsEvent == store.lightsEvent && (try? reloaded.beginLightsPublic(battleID: "public-3", skills: [])) == nil, "result survives reload; no new attempt")
            reloaded.restart()
            try check(GameStore(launchArguments: [], defaults: storage).lightsEvent == MPCLightsLocalEvent(), "restart clears the event")
            report["passed"] = true
        } catch {
            report["passed"] = false
            report["failure"] = error.localizedDescription
        }
        report["checks"] = checks
        if let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
           let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: folder.appendingPathComponent("lights-local-verification.json"))
        }
    }

    /// Production GameStore exercised only against a fresh, disposable defaults suite.
    static func verifyLocalWorkshopIntegration() async {
        let suite = "mistport.local-workshop-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var checks: [String] = []
        func check(_ condition: Bool, _ label: String) throws {
            guard condition else { throw NSError(domain: "LocalWorkshopVerification", code: 1, userInfo: [NSLocalizedDescriptionKey: label]) }
            checks.append(label)
        }
        func render(_ store: GameStore, _ name: String) async throws {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
                throw NSError(domain: "WorkshopRenderSceneMissing", code: 1)
            }
            // NavigationStack is UIKit-backed and cannot be captured with ImageRenderer.
            // A tall native window exposes the entire short form for layout inspection.
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 1500)
            window.rootViewController = UIHostingController(rootView: LocalWorkshopView(game: store))
            window.windowLevel = .alert + 1
            window.isHidden = false
            defer { window.isHidden = true }
            try await Task.sleep(for: .milliseconds(300))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let png = image.pngData() else { throw NSError(domain: "WorkshopRenderMissing", code: 1) }
            try png.write(to: folder.appendingPathComponent(name))
        }
        do {
            let locked = GameStore(launchArguments: [], defaults: storage)
            do { try locked.learnWorkshopBasics(); throw NSError(domain: "UnexpectedEarlyWorkshop", code: 1) }
            catch MPCLocalWorkshopLedger.Failure.locked { checks.append("pre-Q5 recipe learning is rejected") }
            // Existing save with a cleared F1: migration must not backfill repeat loot.
            storage.set(["old-clock-16"], forKey: PersistenceKey.completedChapterMissionIDs)
            storage.set(71, forKey: PersistenceKey.venueCoins)
            storage.set(["consumable_pain_salve": 2, "chapter30_e02": 1], forKey: "mistport.campaign-inventory.v1")
            storage.set(try JSONEncoder().encode(MPCChurchTowerProgress(clearedFloors: [1])), forKey: "mistport.church-tower.progress.v1")
            var oldServices = try JSONSerialization.jsonObject(with: JSONEncoder().encode(ChurchServicesState())) as! [String: Any]
            oldServices.removeValue(forKey: "workshop")
            storage.set(try JSONSerialization.data(withJSONObject: oldServices), forKey: "mistport.church.services.v1")
            let store = GameStore(launchArguments: [], defaults: storage)
            try check(store.cityServiceIsUnlocked(.workshop) && store.venueCoins == 71 && store.workshopHideCount == 0, "old save: unlock preserved, no fixture money or retroactive hide")
            try await render(store, "local-workshop-before.png")
            try store.learnWorkshopBasics()
            _ = try store.beginChurchTower(floor: 1, battleID: "integration-victory", skills: [.sidestepStrike])
            let victory = try MPCChurchTowerVerificationRunner.run(number: 1).session
            _ = store.settleChurchTower(floor: 1, session: victory, battleID: "integration-victory")
            _ = store.settleChurchTower(floor: 1, session: victory, battleID: "integration-victory")
            try check(store.venueCoins == 71 && store.workshopHideCount == 1, "repeat victory: one hide, no duplicate old first-clear cash")
            let beforeCraftState = store.churchServices
            let beforeCraftInventory = store.chapterOneCampaign.inventory
            try store.craftWorkshopStraps(transactionID: "one-batch")
            try check(store.venueCoins == 58 && store.workshopStrapCount == 3 && store.craftingLedger.points(.leather) == 1, "craft charges real balance and increments skill once")
            // Simulate a process ending with an encoded journal but stale/mixed property-list keys.
            let pending = ChurchServicesReceipt(state: store.churchServices, dailyWorkshop: store.dailyWorkshopRecord, coins: store.venueCoins,
                lifetime: store.chapterOneCampaign.lifetimeChurchMerit, available: store.chapterOneCampaign.spendableChurchMerit,
                inventory: store.chapterOneCampaign.inventory)
            storage.set(try JSONEncoder().encode(beforeCraftState), forKey: "mistport.church.services.v1")
            storage.set(beforeCraftInventory, forKey: "mistport.campaign-inventory.v1")
            storage.set(71, forKey: PersistenceKey.venueCoins)
            storage.set(try JSONEncoder().encode(pending), forKey: "mistport.church.services.pending.v1")
            let recovered = GameStore(launchArguments: [], defaults: storage)
            try check(recovered.venueCoins == 58 && recovered.workshopHideCount == 0 && recovered.workshopStrapCount == 3 && recovered.craftingLedger.points(.leather) == 1, "interrupted journal restores matching money, inventory and skill")
            try recovered.craftWorkshopStraps(transactionID: "one-batch")
            try check(recovered.venueCoins == 58 && recovered.workshopStrapCount == 3, "same craft receipt after restart is not charged twice")
            try recovered.deliverWorkshopStraps(transactionID: "one-sale")
            try recovered.deliverWorkshopStraps(transactionID: "one-sale")
            try check(recovered.venueCoins == 76 && recovered.workshopStrapCount == 1 && recovered.localWorkshop.procurementCopper == 0, "finite sale transfers 18 once and keeps unsold item")
            do { try recovered.deliverWorkshopStraps(transactionID: "new-sale"); throw NSError(domain: "UnexpectedSecondSale", code: 1) }
            catch MPCLocalWorkshopLedger.Failure.exhausted { checks.append("exhausted order refuses another sale") }
            try recovered.installWorkshopStraps(transactionID: "one-fit")
            try recovered.installWorkshopStraps(transactionID: "one-fit")
            let restored = GameStore(launchArguments: [], defaults: storage)
            try check(restored.localWorkshop.order == .installed && restored.localWorkshop.projectStraps == 0 && restored.workshopStrapCount == 1 && restored.venueCoins == 76, "installation and leftover survive reload without second payment")
            try check(restored.chapterOneCampaign.inventory["consumable_pain_salve"] == 2 && restored.chapterOneCampaign.inventory["chapter30_e02"] == 1, "unrelated supplies and story evidence preserved")
            try check(restored.venueCoins + restored.localWorkshop.procurementCopper + restored.craftingLedger.receipts.count * 13 == 71 + 18, "finite startup allocation, transfer and external payment reconcile")
            _ = try restored.beginChurchTower(floor: 1, battleID: "integration-retreat", skills: [])
            restored.finishChurchLoanBattle("integration-retreat", outcome: .retreat)
            _ = restored.settleChurchTower(floor: 1, session: victory, battleID: "integration-retreat")
            try check(restored.workshopHideCount == 0, "retired battle ticket cannot later grant hide")
            try await render(restored, "local-workshop-complete.png")
            let legacyReceipt = ChurchServicesReceipt(state: restored.churchServices, coins: restored.venueCoins,
                lifetime: restored.chapterOneCampaign.lifetimeChurchMerit, available: restored.chapterOneCampaign.spendableChurchMerit)
            storage.set(try JSONEncoder().encode(legacyReceipt), forKey: "mistport.church.services.pending.v1")
            let legacyRecovered = GameStore(launchArguments: [], defaults: storage)
            try check(legacyRecovered.workshopStrapCount == 1 && legacyRecovered.painSalveStock == 2,
                      "old service receipt without inventory preserves current bag")
            restored.completedChapterMissionIDs.insert("old-clock-30")
            do { try restored.installWorkshopStraps(transactionID: "after-departure"); throw NSError(domain: "UnexpectedRemoteWorkshop", code: 1) }
            catch MPCLocalWorkshopLedger.Failure.locked { checks.append("Q30 departure blocks local workshop actions without clearing progress") }
            restored.completedChapterMissionIDs.remove("old-clock-30")
            let healthy = storage.data(forKey: "mistport.church.services.v1")!
            storage.set(Data("unreadable".utf8), forKey: "mistport.church.services.v1")
            do { try restored.learnWorkshopBasics(); throw NSError(domain: "UnexpectedCorruptWrite", code: 1) }
            catch MPCLocalWorkshopLedger.Failure.locked { checks.append("unreadable service ledger disables workshop without overwriting bytes") }
            try check(storage.data(forKey: "mistport.church.services.v1") == Data("unreadable".utf8), "corrupt bytes retained")
            storage.set(healthy, forKey: "mistport.church.services.v1")
            let freshStorage = UserDefaults(suiteName: suite + ".first-clear")!
            defer { freshStorage.removePersistentDomain(forName: suite + ".first-clear") }
            freshStorage.set(["old-clock-16"], forKey: PersistenceKey.completedChapterMissionIDs)
            let fresh = GameStore(launchArguments: [], defaults: freshStorage)
            let initialCoins = fresh.venueCoins
            _ = try fresh.beginChurchTower(floor: 1, battleID: "first-clear", skills: [])
            let firstAward = fresh.settleChurchTower(floor: 1, session: victory, battleID: "first-clear")
            let secondAward = fresh.settleChurchTower(floor: 1, session: victory, battleID: "first-clear")
            let freshRestored = GameStore(launchArguments: [], defaults: freshStorage)
            try check(firstAward && !secondAward && freshRestored.venueCoins == initialCoins + 8
                      && freshRestored.workshopHideCount == 1 && freshRestored.chapterOneCampaign.spendableChurchMerit == 2,
                      "first-clear copper and merit plus new material settle once together across reload")
            let report: [String: Any] = ["passed": true, "checks": checks, "playerDefaultsTouched": false,
                "coins": restored.venueCoins, "straps": restored.workshopStrapCount,
                "proficiency": restored.craftingLedger.points(.leather),
                "scope": "Production Swift GameStore and SwiftUI render; no Unity or device play acceptance"]
            try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: folder.appendingPathComponent("local-workshop-verification.json"))
            NSLog("LOCAL_WORKSHOP_VERIFY_PASS: %d checks", checks.count)
        } catch {
            let report: [String: Any] = ["passed": false, "checks": checks, "error": String(describing: error)]
            try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: folder.appendingPathComponent("local-workshop-verification.json"))
            NSLog("LOCAL_WORKSHOP_VERIFY_FAIL: %@", String(describing: error))
        }
    }
}
#endif

// MARK: Shared repeat-work settlement (J0, J1, J2, story replays)
extension GameStore {
    private var dailyWorkIsReadable: Bool {
        guard let data = defaults.data(forKey: PersistenceKey.dailyWork) else { return false }
        return (try? JSONDecoder().decode(DailyWorkRecord.self, from: data)) != nil
    }
    private func persistDailyWork(_ record: DailyWorkRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: PersistenceKey.dailyWork)
        dailyWorkRecord = record
    }
    private func updateChurchServicesAndWork(_ change: (inout ChurchServicesState, inout DailyWorkRecord) throws -> Void) throws {
        guard workshopLedgerIsReadable, dailyWorkIsReadable else { throw MPCLocalWorkshopLedger.Failure.locked }
        var state = churchServices
        var work = dailyWorkRecord
        state.loans.coins = venueCoins
        state.loans.lifetimeMerit = chapterOneCampaign.lifetimeChurchMerit
        state.loans.availableMerit = chapterOneCampaign.spendableChurchMerit
        try change(&state, &work)
        try commitChurchServices(state, dailyWork: work)
    }
    var repeatWorkNotice: String {
        let ledger = dailyWorkRecord.ledger
        let count = pacingDay > ledger.day ? 0 : ledger.jobsToday
        let meritCount = pacingDay > ledger.day ? 0 : ledger.meritJobsToday
        return "今天第 \(count + 1) 单；第 4 单起半价，第 7 单起一成。"
            + (meritCount >= MPCDailyWorkLedger.meritJobsPerDay ? "今天功勋已记满。" : "功勋每天只计前 2 单有功勋的工作。")
    }
    func repeatWorkPreview(copper: Int, merit: Int = 0) -> String {
        let ledger = dailyWorkRecord.ledger
        let paid = ledger.preview(day: pacingDay, copper: copper)
        let meritCount = pacingDay > ledger.day ? 0 : ledger.meritJobsToday
        let meritPaid = meritCount < MPCDailyWorkLedger.meritJobsPerDay ? merit : 0
        return merit > 0 ? "\(paid) 铜币 · \(meritPaid) 功勋" : "\(paid) 铜币"
    }
    func maintenancePayoutText(jobID: String) -> String {
        guard let payout = dailyWorkRecord.ledger.settled["maintenance-" + jobID] else {
            return "工单报酬已结清"
        }
        return "+\(payout.copper) 铜币 · +\(payout.merit) 功勋"
    }

    #if DEBUG
    private static func verifyDailyWorkIntegration() {
        let suite = "mistport.daily-work-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let store = GameStore(launchArguments: [], defaults: storage)
        let migration = storage.data(forKey: PersistenceKey.dailyWork)!
        assert(store.dailyWorkRecord.ledger.jobsToday == 0)
        _ = GameStore(launchArguments: [], defaults: storage)
        assert(storage.data(forKey: PersistenceKey.dailyWork) == migration)
        store.debugJumpToOldClockMission(10, enterImmediately: false)
        storage.set(try! JSONEncoder().encode(MPCChurchTowerProgress(clearedFloors: Set(1...10))), forKey: "mistport.church-tower.progress.v1")
        store.debugSetPacingDay(1)
        func postal() {
            let serial = store.postalJobSerial
            for step in 0..<3 { store.verifyPostalField(store.postalJobFields[step], serial: serial, step: step) }
            let coins = store.venueCoins
            store.verifyPostalField("", serial: serial, step: 2)
            assert(store.venueCoins == coins)
        }
        func maintenance(_ kind: MPCChurchMaintenanceKind) {
            let id = try! store.acceptChurchMaintenance(kind: kind, floor: kind == .patrol ? nil : 10)
            for objective in store.churchServices.maintenance.jobs[id]!.objectives {
                try! store.verifyChurchMaintenance(jobID: id, objectiveID: objective.id, choiceID: objective.correctChoiceID)
            }
            for site in 1...3 {
                let battle = "work-check-\(id)-\(site)"
                _ = try! store.beginChurchMaintenance(jobID: id, battleID: battle, skills: [])
                try! store.finishChurchMaintenance(jobID: id, battleID: battle, outcome: .victory)
                let coins = store.venueCoins
                try! store.finishChurchMaintenance(jobID: id, battleID: battle, outcome: .victory)
                assert(store.venueCoins == coins)
            }
        }
        let before = store.venueCoins
        let merit = store.chapterOneCampaign.lifetimeChurchMerit
        postal(); maintenance(.patrol); maintenance(.towerMaintenance); maintenance(.patrol)
        assert(store.venueCoins == before + 40 + 60 + 80 + 30)
        assert(store.chapterOneCampaign.lifetimeChurchMerit == merit + 14)
        postal(); postal(); postal()
        assert(store.venueCoins == before + 40 + 60 + 80 + 30 + 20 + 20 + 4)
        assert(store.dailyWorkRecord.ledger.jobsToday == 7)
        store.activeChapterMissionID = "old-clock-1"
        let replay = store.settleActiveMissionRewards()!
        assert(!replay.firstClear && replay.coins == MPCDailyWorkLedger.scaled(store.baseMissionCoinReward(for: store.activeChapterMission!, firstClear: false), percent: 10))
        assert(store.dailyWorkRecord.ledger.jobsToday == 8)
        _ = store.settleActiveMissionRewards()
        assert(store.dailyWorkRecord.ledger.jobsToday == 8)
        let restored = GameStore(launchArguments: [], defaults: storage)
        assert(restored.venueCoins == store.venueCoins && restored.dailyWorkRecord.ledger == store.dailyWorkRecord.ledger)
        restored.acknowledgeMissionReward()
        // A persisted write-ahead postal record recovers wallet and counter together.
        var work = restored.dailyWorkRecord
        let payout = work.ledger.settle(receiptID: "postal-\(restored.postalJobSerial)", day: 1, copper: 40, merit: 0)
        let pending = PostalSettlement(completedSerial: restored.postalJobSerial, coins: restored.venueCoins + payout.copper, dailyWork: work)
        storage.set(try! JSONEncoder().encode(pending), forKey: "mistport.postal-settlement.v1")
        let recovered = GameStore(launchArguments: [], defaults: storage)
        let twice = GameStore(launchArguments: [], defaults: storage)
        assert(recovered.venueCoins == pending.coins && twice.venueCoins == pending.coins)
        assert(twice.dailyWorkRecord.ledger == work.ledger)
        twice.debugSetPacingDay(2)
        assert(twice.repeatWorkPreview(copper: 40) == "40 铜币")
        twice.restart()
        assert(twice.dailyWorkRecord.ledger.jobsToday == 0 && twice.dailyWorkRecord.ledger.settled.isEmpty)
        NSLog("DAILY_WORK_VERIFY_PASS: empty migration once, shared J0/J1/J2/story counter, 100/50/10 percent, two merit jobs, duplicate callbacks, reopen, journal recovery, next day, restart")
    }
    #endif
}

// MARK: Daily workshop recipes, orders, material tickets and equipment care
extension GameStore {
    var craftingLedger: MPCCraftingLedger { dailyWorkshopRecord.crafting }
    var workshopOrders: MPCWorkshopOrderBoard {
        var board = dailyWorkshopRecord.orders
        board.open(day: pacingDay, bonus: dailyCityEffects.orderBudgetBonus)
        return board
    }
    // The event board supplies these effects when its persisted ledger is present.
    // Until task 1.4 installs that ledger, no inaccessible event can penalize crafting.
    var dailyCityEffects: MPCCityEvent.Effects {
        guard let data = defaults.data(forKey: "mistport.city-events.v1"),
              let record = try? JSONDecoder().decode(CityEventRecord.self, from: data) else { return .init() }
        return record.ledger.effects(day: pacingDay)
    }
    private struct CityEventRecord: Codable {
        let migratedAt: Date
        var ledger: MPCCityEventLedger
        init() { migratedAt = Date(); ledger = .init() }
    }
    private var dailyWorkshopIsReadable: Bool {
        guard let data = defaults.data(forKey: PersistenceKey.dailyWorkshop) else { return false }
        return (try? JSONDecoder().decode(DailyWorkshopRecord.self, from: data)) != nil
    }
    private func persistDailyWorkshop(_ record: DailyWorkshopRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: PersistenceKey.dailyWorkshop)
        dailyWorkshopRecord = record
    }
    func openDailyWorkshopOrders() {
        guard cityServiceIsUnlocked(.workshop), dailyWorkshopIsReadable else { return }
        var record = dailyWorkshopRecord
        record.orders.open(day: pacingDay, bonus: dailyCityEffects.orderBudgetBonus)
        persistDailyWorkshop(record)
    }
    var workshopProficiencyNotice: String {
        let ledger = craftingLedger
        let counted = pacingDay > ledger.day ? 0 : ledger.proficiencyCraftsToday
        return counted >= MPCCraftingLedger.proficiencyCraftsPerDay
            ? "熟练度今天已满 5 次；仍可制作，自用或交货。"
            : "今天已记 \(counted)/5 次制作熟练度。"
    }
    func workshopRecipeLock(_ recipe: MPCCraftRecipe) -> String? {
        guard MPCCraftingCatalog.isOpen(recipe, completedMissions: churchTowerMissionNumbers) else { return "完成第 \(recipe.requiredMission) 关后开放" }
        guard craftingLedger.points(recipe.craft) >= recipe.requiredProficiency else { return "需要本门手艺熟练 \(recipe.requiredProficiency)" }
        if recipe.isGear && churchServices.gear.ownedIDs.contains(recipe.output) { return "已拥有这件装备" }
        let missing = recipe.inputs.filter { chapterOneCampaign.inventory[$0.key, default: 0] < $0.value }
        if !missing.isEmpty { return "缺少：" + missing.sorted(by: { $0.key < $1.key }).map { "\(Self.workshopItemName($0.key)) ×\($0.value)" }.joined(separator: "、") }
        let price = MPCCraftingCatalog.baseStock(recipe, surcharge: dailyCityEffects.craftSurcharge)
        return venueCoins < price ? "还差 \(price - venueCoins) 铜底料钱" : nil
    }
    func craftDailyWorkshop(recipeID: String, transactionID: String = UUID().uuidString, atStation: Bool = false) throws {
        if !atStation { try requireLocalWorkshop() }
        guard dailyWorkshopIsReadable else { throw MPCLocalWorkshopLedger.Failure.locked }
        acknowledgeMissionReward()
        var record = dailyWorkshopRecord, inventory = chapterOneCampaign.inventory
        var gear = churchServices.gear, coins = venueCoins
        guard try record.crafting.craft(receiptID: transactionID, recipeID: recipeID, day: pacingDay,
            completedMissions: churchTowerMissionNumbers, coins: &coins, inventory: &inventory,
            gear: &gear, surcharge: dailyCityEffects.craftSurcharge) else { return }
        try updateChurchServices(dailyWorkshop: record, inventory: inventory) { state in
            state.gear = gear; state.loans.coins = coins
        }
    }
    @discardableResult
    func sellDailyWorkshop(itemID: String, count: Int = 1, transactionID: String = UUID().uuidString) throws -> Int {
        try requireLocalWorkshop()
        guard dailyWorkshopIsReadable else { throw MPCLocalWorkshopLedger.Failure.locked }
        acknowledgeMissionReward()
        var record = dailyWorkshopRecord, inventory = chapterOneCampaign.inventory, coins = venueCoins
        let sold = try record.orders.sell(receiptID: transactionID, itemID: itemID, count: count, day: pacingDay,
            coins: &coins, inventory: &inventory, bonus: dailyCityEffects.orderBudgetBonus)
        try updateChurchServices(dailyWorkshop: record, inventory: inventory) { $0.loans.coins = coins }
        return sold
    }
    func repairWorkshopGear(_ id: String, transactionID: String = UUID().uuidString) throws {
        guard phase != .dungeon, dailyWorkshopIsReadable else { throw MPCLocalWorkshopLedger.Failure.locked }
        var record = dailyWorkshopRecord
        guard record.repairs.insert(transactionID).inserted else { return }
        var inventory = chapterOneCampaign.inventory, gear = churchServices.gear
        try gear.repair(id, inventory: &inventory)
        try updateChurchServices(dailyWorkshop: record, inventory: inventory) { $0.gear = gear }
    }
    static func workshopItemName(_ id: String) -> String {
        let names = [MPCTowerMaterials.hide: "韧皮", MPCTowerMaterials.gland: "盐囊腺",
            MPCTowerMaterials.membrane: "背囊膜", MPCTowerMaterials.chitin: "剪刃甲片",
            MPCTowerMaterials.silk: "共鸣丝", MPCTowerMaterials.talon: "骨爪",
            MPCTowerMaterials.fiber: "喉纤维", MPCTowerMaterials.scale: "恶魔鳞片",
            MPCCraftingCatalog.strapID: "维修绑带", MPCCraftingCatalog.salveID: "止痛膏",
            MPCCraftingCatalog.patchID: "修甲片", MPCCraftingCatalog.clothID: "过滤布"]
        return names[id] ?? MPCChurchGearCatalog.item(id)?.name ?? id
    }
}

#if DEBUG
extension GameStore {
    private static func verifyDailyWorkshopIntegration() {
        let suite = "mistport.daily-workshop-check." + UUID().uuidString
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let store = GameStore(launchArguments: [], defaults: storage)
        let migration = storage.data(forKey: PersistenceKey.dailyWorkshop)!
        _ = GameStore(launchArguments: [], defaults: storage)
        assert(storage.data(forKey: PersistenceKey.dailyWorkshop) == migration)
        assert(store.craftingLedger.receipts.isEmpty)
        store.debugJumpToOldClockMission(6, enterImmediately: false)
        store.debugSetPacingDay(3)
        assert(store.cityServiceIsUnlocked(.workshop))
        store.venueCoins = 50_000
        let materialIDs = [MPCTowerMaterials.hide, MPCTowerMaterials.gland, MPCTowerMaterials.membrane,
            MPCTowerMaterials.chitin, MPCTowerMaterials.silk, MPCTowerMaterials.talon, MPCTowerMaterials.fiber, MPCTowerMaterials.scale]
        for id in materialIDs { store.chapterOneCampaign.inventory[id] = 1000 }
        store.persistChapterProgress()
        for n in 1...6 { try! store.craftDailyWorkshop(recipeID: "recipe_repair_strap", transactionID: "cap-\(n)") }
        assert(store.craftingLedger.points(.leather) == 5 && store.craftingLedger.proficiencyCraftsToday == 5)
        let coins = store.venueCoins, straps = store.workshopStrapCount
        try! store.craftDailyWorkshop(recipeID: "recipe_repair_strap", transactionID: "cap-1")
        assert(store.venueCoins == coins && store.workshopStrapCount == straps)
        store.openDailyWorkshopOrders()
        assert(store.workshopOrders.budget == 180)
        let sold = try! store.sellDailyWorkshop(itemID: MPCCraftingCatalog.strapID, count: 100, transactionID: "order")
        assert(sold == 18 && store.venueCoins == coins + 162)
        _ = try! store.sellDailyWorkshop(itemID: MPCCraftingCatalog.strapID, count: 100, transactionID: "order")
        assert(store.venueCoins == coins + 162)
        let restored = GameStore(launchArguments: [], defaults: storage)
        assert(restored.craftingLedger == store.craftingLedger && restored.workshopOrders == store.workshopOrders)
        // Material tickets cover first clear, replay, duplicate and a retired attempt.
        storage.set(try! JSONEncoder().encode(MPCChurchTowerProgress(clearedFloors: [1])), forKey: "mistport.church-tower.progress.v1")
        let drops = MPCTowerMaterials.drops(floor: 2), inventoryBefore = store.chapterOneCampaign.inventory
        let victory = try! MPCChurchTowerVerificationRunner.run(number: 2).session
        assert(victory.outcome == .victory)
        for id in ["material-first", "material-replay"] {
            _ = try! store.beginChurchTower(floor: 2, battleID: id, skills: [])
            _ = store.settleChurchTower(floor: 2, session: victory, battleID: id)
            _ = store.settleChurchTower(floor: 2, session: victory, battleID: id)
        }
        for (id, count) in drops { assert(store.chapterOneCampaign.inventory[id, default: 0] == inventoryBefore[id, default: 0] + count * 2) }
        _ = try! store.beginChurchTower(floor: 2, battleID: "material-abandon", skills: [])
        store.finishChurchLoanBattle("material-abandon", outcome: .retreat)
        let retiredInventory = store.chapterOneCampaign.inventory
        _ = store.settleChurchTower(floor: 2, session: victory, battleID: "material-abandon")
        assert(store.chapterOneCampaign.inventory == retiredInventory)
        // Earn every proficiency through the real daily cap, then craft all ten pieces.
        store.debugJumpToOldClockMission(21, enterImmediately: false)
        store.venueCoins = 50_000
        for id in materialIDs { store.chapterOneCampaign.inventory[id] = 1000 }
        store.persistChapterProgress()
        for (index, recipe) in MPCCraftingCatalog.basics.enumerated() {
            for round in 0..<4 {
                store.debugSetPacingDay(10 + index * 4 + round)
                for n in 0..<5 { try! store.craftDailyWorkshop(recipeID: recipe.id, transactionID: "practice-\(index)-\(round)-\(n)") }
            }
            assert(store.craftingLedger.points(recipe.craft) == 20)
        }
        for recipe in MPCCraftingCatalog.gear { try! store.craftDailyWorkshop(recipeID: recipe.id) }
        let piece = MPCChurchGearCatalog.craftedPiece(tier: 50, slot: .armor)!
        do { try store.equipChurchGear(piece.id); assertionFailure("craft gear skipped tower gate") } catch {}
        storage.set(try! JSONEncoder().encode(MPCChurchTowerProgress(clearedFloors: Set(1...50))), forKey: "mistport.church-tower.progress.v1")
        try! store.equipChurchGear(piece.id)
        assert(store.churchServices.gear.stats.towerDepth == 50)
        try! store.beginChurchLoanBattle("crafted-wear")
        store.finishChurchLoanBattle("crafted-wear", outcome: .victory)
        store.finishChurchLoanBattle("crafted-wear", outcome: .victory)
        assert(store.churchServices.gear.durability(piece.id) == 98)
        let repairStock = store.workshopStrapCount
        try! store.repairWorkshopGear(piece.id, transactionID: "repair")
        try! store.repairWorkshopGear(piece.id, transactionID: "repair")
        assert(store.churchServices.gear.durability(piece.id) == 100 && store.workshopStrapCount == repairStock - 1)
        let final = GameStore(launchArguments: [], defaults: storage)
        assert(final.craftingLedger == store.craftingLedger && final.churchServices.gear == store.churchServices.gear)
        NSLog("DAILY_WORKSHOP_VERIFY_PASS: migration once, Q5/day3, five daily crafts, duplicate craft/order, finite orders, first/repeat species drops, retired tickets, fourteen recipes, wear gate, tower depth, wear once, repair once, reopen")
    }
}
#endif
