import Foundation

public enum MPCEncounterOutcome: String, Codable, Sendable {
    case inProgress, victory, defeat
}

public enum MPCPlayerActionCategory: String, Codable, Sendable {
    case damage, protection, control, setup, utility
}

public enum MPCBossMechanicResponse: String, Codable, Sendable {
    case none, evasion, protection, willBreak, fullFinisher
}

public enum MPCOldClockBossPhase: Int, Codable, Sendable {
    case calibration = 1
    case unifiedMoment = 2
    case thirteenthBell = 3
}

public struct MPCRuntimeEnemy: Identifiable, Equatable, Sendable {
    public let id: String
    public let contentID: String
    public let name: String
    public let maxHP: Int
    public var hp: Int
    public let attack: Int
    public let defense: Int
    public var intentPattern: [String]
    public var intentIndex: Int
    public var delayedRounds: Int

    /// Crimson split ghosts attack 50% more frequently than their originals.
    public var attackIntervalMultiplier: Double { contentID == "enemy_resonant_clock_guard_q2_split" ? 2.0 / 3.0 : 1 }
    public var hasDeparted = false
    public var isAlive: Bool { hp > 0 && !hasDeparted }
    public var currentIntent: String {
        guard !intentPattern.isEmpty else { return "wait" }
        return intentPattern[intentIndex % intentPattern.count]
    }
}

private struct MPCEnemyDefenseBoost: Equatable, Sendable {
    let bonusBP: Int
}

public struct MPCPartyPersistentState: Equatable, Sendable {
    public var playerHP: Int
    public var playerMaxHP: Int
    public var allyHP: [String: Int]
    public var allyMaxHP: [String: Int]
    public var sharedReviveCharges: Int

    public init(
        playerHP: Int = 1_000,
        playerMaxHP: Int = 1_000,
        allyHP: [String: Int] = [:],
        allyMaxHP: [String: Int] = [:],
        sharedReviveCharges: Int = 1
    ) {
        self.playerHP = playerHP
        self.playerMaxHP = playerMaxHP
        self.allyHP = allyHP
        self.allyMaxHP = allyMaxHP
        self.sharedReviveCharges = sharedReviveCharges
    }
}

/// Q30 离场祝福 (2026-10-10, user: 2人离开时分别会随机给予主角和小boss一个祝福…设计个小彩蛋而已).
/// As 伊莱娅 drags the outside pursuer into the rift, she leaves the hero one blessing and the
/// pursuer leaves 瑟维安 one gift. Battle-only: never written to the party or the campaign.
/// Magnitudes live in `MPCProgressionWalls.q30*`.
public struct MPCFarewellBlessings: Equatable, Sendable {
    public enum Hero: String, CaseIterable, Sendable {
        case lampWick = "lamp_wick", featherShelter = "feather_shelter", nameLight = "name_light"
        public var name: String {
            switch self { case .lampWick: "灯芯长明"; case .featherShelter: "羽翼庇护"; case .nameLight: "照名之光" }
        }
        /// One line for the UI, without the name; `summary` puts the name in front.
        public var effect: String {
            typealias W = MPCProgressionWalls
            return switch self {
            case .lampWick: "你对瑟维安的伤害 +\(W.q30LampWickPercent)%"
            case .featherShelter: "奥黛尔可多唤回你 \(W.q30FeatherRevives) 次（\(W.q30FeatherReviveHealthPercent)% 生命）"
            case .nameLight: "夺名代签只封 \(W.q30NameLightSealSeconds) 秒"
            }
        }
        public var summary: String { "\(name)：\(effect)" }
    }
    public enum Sovereign: String, CaseIterable, Sendable {
        case saltCrust = "salt_crust", coldBell = "cold_bell", mistMend = "mist_mend"
        public var name: String {
            switch self { case .saltCrust: "黑盐外壳"; case .coldBell: "冷钟"; case .mistMend: "雾中续命" }
        }
        public var effect: String {
            typealias W = MPCProgressionWalls
            return switch self {
            case .saltCrust: "瑟维安受到的伤害 −\(W.q30SaltCrustPercent)%"
            case .coldBell: "第十三响伤害 +\(W.q30ColdBellPercent)%"
            case .mistMend: "瑟维安进入第二、三阶段时各回复 \(W.q30MistMendPercent)% 生命"
            }
        }
        public var summary: String { "\(name)：\(effect)" }
    }
    public let hero: Hero
    public let sovereign: Sovereign
    public init(hero: Hero, sovereign: Sovereign) { self.hero = hero; self.sovereign = sovereign }
    public static func roll<G: RandomNumberGenerator>(using generator: inout G) -> Self {
        .init(hero: Hero.allCases.randomElement(using: &generator)!, sovereign: Sovereign.allCases.randomElement(using: &generator)!)
    }
    /// The two lines `applyFarewellBlessings` adds to `triggeredEffects`.
    public var announcements: [String] { ["伊莱娅的祝福：\(hero.name)", "追索者的赠礼：\(sovereign.name)"] }
}

public enum MPCChapterOneRitual: String, CaseIterable, Codable, Sendable {
    case observe = "ritual_observe"
    case paperWard = "ritual_paper_ward"
    case borrowedSecond = "ritual_borrowed_second"
}

public struct MPCChapterOneLoadout: Equatable, Sendable {
    public var normalSkillIDs: [FoolSkillID]
    public var ultimateSkillID: FoolSkillID
    public var isUltimateUnlocked: Bool
    public var passiveIDs: [String]
    public var relicIDs: [String]
    public var selectedActiveRelicID: String? = nil
    public var ritual: MPCChapterOneRitual
    public var talents = HermitTalentAllocation()
    public var skillLevels: [FoolSkillID: Int] = [:]
    public var churchGear = MPCChurchGearStats()
    /// Temporary lodging preparation; never written into persistent gear.
    public var housingRestBP = 0
    public var outfit: MPCOutfit? = nil
    /// The separate bounty slot (MPCBountyRelicCatalog); independent of shop relics.
    public var bountyRelicID: String? = nil

    public var outfitBonus: MPCOutfitBonus { outfit?.bonus ?? .none }

    public func skillLevel(for skillID: FoolSkillID) -> Int {
        MPCSkillGrowth.clampedLevel(skillLevels[skillID, default: 1])
    }

    public init(
        normalSkillIDs: [FoolSkillID] = [
            .sidestepStrike, .fabricatedEvidence, .identityDisplacement, .absurdFinale,
        ],
        ultimateSkillID: FoolSkillID = .namelessStage,
        isUltimateUnlocked: Bool = true,
        passiveIDs: [String] = ["fool_passive_01", "fool_passive_02"],
        relicIDs: [String] = ["relic_late_second_watch"],
        ritual: MPCChapterOneRitual = .observe
    ) {
        var uniqueNormalSkills: [FoolSkillID] = []
        for skillID in normalSkillIDs where skillID != .namelessStage {
            if !uniqueNormalSkills.contains(skillID) {
                uniqueNormalSkills.append(skillID)
            }
        }
        self.normalSkillIDs = Array(uniqueNormalSkills.prefix(4))
        self.ultimateSkillID = ultimateSkillID
        self.isUltimateUnlocked = isUltimateUnlocked
        self.passiveIDs = Array(passiveIDs.prefix(2))
        self.relicIDs = Array(relicIDs.prefix(2))
        self.ritual = ritual
    }

    public var battleSkillIDs: [FoolSkillID] {
        normalSkillIDs + (isUltimateUnlocked ? [ultimateSkillID] : [])
    }
}

public struct MPCChapterOneCampaignState: Equatable, Sendable {
    // Encounter IDs identify content; session IDs identify separate replays.
    private var settledSessionIDs: Set<UUID> = []
    public var currentMissionID: String
    public var completedMissionIDs: Set<String>
    public var completedEncounterIDs: Set<String>
    public var inventory: [String: Int]
    public var ownedRelicIDs: Set<String>
    public var depletedRelicIDs: Set<String>
    public var unlockedSkillIDs: Set<FoolSkillID>
    public var skillUnlockStates: [FoolSkillID: MPCSkillUnlockState]
    public var comboExecutionRecords: [MPCComboExecutionRecord]
    public var completedBehaviorTags: Set<MPCChapterOneBehaviorTag>
    public var unlockedPassiveIDs: Set<String>
    public var party: MPCPartyPersistentState
    public var loadout: MPCChapterOneLoadout
    public var loadoutSlotCapacity: Int
    public var endingChoice: MPCChapterOneEndingChoice?
    public var endingWorldState: String?
    public var encoreBellMigrationVersion: Int
    public var masqueradeCrackCount: Int
    public var chapterThirtyRewardVersion: Int
    public var lifetimeChurchMerit: Int
    public var spendableChurchMerit: Int
    public var chapterTalentPointsEarned: Int
    public var misdirectionTrainingCompleted: Bool
    public var misdirectionTrainingResponse: MPCMisdirectionTrainingResponse?

    public init(
        currentMissionID: String = "chapter01_q01",
        completedMissionIDs: Set<String> = [],
        completedEncounterIDs: Set<String> = [],
        inventory: [String: Int] = [:],
        ownedRelicIDs: Set<String> = [],
        depletedRelicIDs: Set<String> = [],
        unlockedSkillIDs: Set<FoolSkillID> = [.sidestepStrike],
        skillUnlockStates: [FoolSkillID: MPCSkillUnlockState] = [.sidestepStrike: .permanent],
        comboExecutionRecords: [MPCComboExecutionRecord] = [],
        completedBehaviorTags: Set<MPCChapterOneBehaviorTag> = [],
        unlockedPassiveIDs: Set<String> = [],
        party: MPCPartyPersistentState = MPCPartyPersistentState(),
        loadout: MPCChapterOneLoadout = MPCChapterOneLoadout(
            normalSkillIDs: [.sidestepStrike],
            isUltimateUnlocked: false,
            passiveIDs: [],
            relicIDs: []
        ),
        loadoutSlotCapacity: Int = 1,
        endingChoice: MPCChapterOneEndingChoice? = nil,
        endingWorldState: String? = nil,
        encoreBellMigrationVersion: Int = 0,
        masqueradeCrackCount: Int = 0,
        misdirectionTrainingCompleted: Bool = false,
        misdirectionTrainingResponse: MPCMisdirectionTrainingResponse? = nil,
        chapterThirtyRewardVersion: Int = 0,
        lifetimeChurchMerit: Int = 0,
        spendableChurchMerit: Int = 0,
        chapterTalentPointsEarned: Int = 0
    ) {
        self.currentMissionID = currentMissionID
        self.completedMissionIDs = completedMissionIDs
        self.completedEncounterIDs = completedEncounterIDs
        self.inventory = inventory
        self.ownedRelicIDs = ownedRelicIDs
        self.depletedRelicIDs = depletedRelicIDs
        self.unlockedSkillIDs = unlockedSkillIDs
        self.skillUnlockStates = skillUnlockStates
        self.comboExecutionRecords = comboExecutionRecords
        self.completedBehaviorTags = completedBehaviorTags
        self.unlockedPassiveIDs = unlockedPassiveIDs
        self.party = party
        self.loadout = loadout
        self.loadoutSlotCapacity = loadoutSlotCapacity
        self.endingChoice = endingChoice
        self.endingWorldState = endingWorldState
        self.masqueradeCrackCount = min(10, max(0, masqueradeCrackCount))
        self.encoreBellMigrationVersion = encoreBellMigrationVersion
        self.misdirectionTrainingCompleted = misdirectionTrainingCompleted
        self.misdirectionTrainingResponse = misdirectionTrainingResponse
        self.chapterThirtyRewardVersion = chapterThirtyRewardVersion
        self.lifetimeChurchMerit = max(0, lifetimeChurchMerit)
        self.spendableChurchMerit = max(0, spendableChurchMerit)
        self.chapterTalentPointsEarned = max(0, chapterTalentPointsEarned)
    }

    /// Call only after the session accepts the tap; save immediately, including on retries.
    @discardableResult
    public mutating func registerMasqueradeUse(encounterID: String) -> Bool {
        if encounterID == "chapter01_q03_encounter" || encounterID == "chapter01_q04_encounter" { return true }
        guard masqueradeCrackCount < 10 else { return false }
        if encounterID != "chapter01_q03_encounter" && encounterID != "chapter01_q04_encounter" {
            masqueradeCrackCount = min(10, masqueradeCrackCount + 1)
        }
        return true
    }

    public var ownsUsurpedLifeMedal: Bool { ownedRelicIDs.contains(MPCChapterOneCatalog.usurpedLifeMedalRelicID) }

    /// Idempotent entitlement. Call after Q4 completion or confirmed legacy Q4 progress.
    @discardableResult
    public mutating func grantUsurpedLifeMedalAfterQ4() -> Bool {
        ownedRelicIDs.insert(MPCChapterOneCatalog.usurpedLifeMedalRelicID).inserted
    }

    public static var fullyUnlockedTestState: Self {
        Self(
            inventory: Dictionary(uniqueKeysWithValues: MPCChapterOneCatalog.items.map {
                ($0.id, $0.kind == .keyItem ? 1 : $0.maxStack)
            }),
            ownedRelicIDs: Set(MPCChapterOneCatalog.relics.map(\.id)),
            unlockedSkillIDs: Set(MPCChapterOneCatalog.skills.map(\.id)),
            skillUnlockStates: Dictionary(uniqueKeysWithValues: MPCChapterOneCatalog.skills.map { ($0.id, .permanent) }),
            unlockedPassiveIDs: Set(MPCChapterOneCatalog.passives.map(\.id)),
            party: MPCPartyPersistentState(
                allyHP: Dictionary(uniqueKeysWithValues: MPCChapterOneCatalog.companions.map { ($0.id, $0.maxHP) }),
                allyMaxHP: Dictionary(uniqueKeysWithValues: MPCChapterOneCatalog.companions.map { ($0.id, $0.maxHP) })
            ),
            loadout: MPCChapterOneLoadout(),
            loadoutSlotCapacity: 4
        )
    }

    /// Player-facing first-chapter start. All catalog content remains present,
    /// but abilities, allies, relics and items are earned through the authored
    /// investigation sequence instead of being granted at launch.
    public static var chapterStartState: Self {
        Self(
            inventory: ["currency_copper": 180],
            unlockedSkillIDs: [],
            skillUnlockStates: [:],
            loadout: MPCChapterOneLoadout(
                normalSkillIDs: [],
                isUltimateUnlocked: false,
                passiveIDs: [],
                relicIDs: [],
                ritual: .observe
            ),
            loadoutSlotCapacity: 1
        )
    }

    @discardableResult
    public mutating func applyChapterMissionProgress(
        districtID: String,
        missionNumber: Int
    ) -> FoolSkillID? {
        if districtID == "old-clock", missionNumber == 3 {
            loadoutSlotCapacity = max(loadoutSlotCapacity, 2)
            ownedRelicIDs.insert(MPCChapterOneCatalog.ownerlessMaskRelicID)
        }
        if districtID == "old-clock", missionNumber == 10 {
            loadoutSlotCapacity = max(loadoutSlotCapacity, 4)
        }
        if districtID == "old-clock", missionNumber == 4 { grantUsurpedLifeMedalAfterQ4() }
        // The Fool's ordinary sequence is intentionally capped at four cards
        // for chapter one. Later areas deepen relic and ultimate branches
        // instead of widening the active row indefinitely.

        let granted = districtID == "old-clock" ? unlockOrderedSkills(availableThrough: missionNumber + 1) : []
        let skillID: FoolSkillID? = districtID == "old-clock" && missionNumber == 13 ? .namelessStage : granted.first
        guard let skillID else { return nil }
        let wasNew = unlockedSkillIDs.insert(skillID).inserted
        skillUnlockStates[skillID] = .permanent
        if skillID == .namelessStage {
            loadout.isUltimateUnlocked = true
        } else if !loadout.normalSkillIDs.contains(skillID), loadout.normalSkillIDs.count < loadoutSlotCapacity {
            loadout.normalSkillIDs.append(skillID)
        }
        return wasNew || granted.contains(skillID) ? skillID : nil
    }

    /// Only eligibility changes: no first-clear settlement, money or items are replayed.
    @discardableResult
    public mutating func unlockOrderedSkills(availableThrough mission: Int) -> [FoolSkillID] {
        let old = unlockedSkillIDs
        loadoutSlotCapacity = MPCOrderedSkillRules.slotCapacity(availableThrough: mission)
        for skill in MPCOrderedSkillRules.ordinarySkills {
            guard let gate = MPCOrderedSkillRules.unlockMission(skill), gate <= mission,
                  skill != .sidestepStrike || mission > 1 else { continue }
            unlockedSkillIDs.insert(skill); skillUnlockStates[skill] = .permanent
            if !old.contains(skill), !loadout.normalSkillIDs.contains(skill), loadout.normalSkillIDs.count < loadoutSlotCapacity {
                loadout.normalSkillIDs.append(skill)
            }
        }
        loadout.normalSkillIDs = Array(loadout.normalSkillIDs.filter(\.isOrderedOrdinary).prefix(loadoutSlotCapacity))
        return MPCOrderedSkillRules.ordinarySkills.filter { !old.contains($0) && unlockedSkillIDs.contains($0) }
    }

    public var ownsManualMask: Bool { ownedRelicIDs.contains(MPCChapterOneCatalog.ownerlessMaskRelicID) }

    /// Compatibility entry point: Q3 now grants a relic, never a skill card.
    public mutating func grantHoundTutorialCard() {
        loadoutSlotCapacity = max(loadoutSlotCapacity, 2)
        ownedRelicIDs.insert(MPCChapterOneCatalog.ownerlessMaskRelicID)
        migrateLegacyMaskCardToRelic()
    }

    /// Idempotent; no quest, reward, talent or archived skill-level data is changed.
    @discardableResult
    public mutating func migrateLegacyMaskCardToRelic() -> Bool {
        let before = self
        if unlockedSkillIDs.contains(.maskedWhisper) || skillUnlockStates[.maskedWhisper] == .permanent
            || loadout.normalSkillIDs.contains(.maskedWhisper) {
            ownedRelicIDs.insert(MPCChapterOneCatalog.ownerlessMaskRelicID)
        }
        unlockedSkillIDs.remove(.maskedWhisper)
        skillUnlockStates.removeValue(forKey: .maskedWhisper)
        loadout.normalSkillIDs.removeAll { $0 == .maskedWhisper }
        return self != before
    }

    /// Authored Q5 handoff only. Call from its accepted dialogue, never battle start.
    /// Ownership is granted once; equipment remains the player's choice.
    @discardableResult
    public mutating func acceptEncoreBellDelivery() -> Bool {
        guard MPCChapterOneCatalog.relicsEnabled else { return false }
        return ownedRelicIDs.insert("relic_encore_bell").inserted
    }

    /// Compatibility for old handoff callers; the paper relic is retired.
    public mutating func acceptPaperRelicDelivery() {
        acceptEncoreBellDelivery()
    }

    /// Run after loading a save and persist the version with that save.
    /// Legacy ownership, equipment or depletion is evidence of the old handoff.
    /// Quest completion, coins and first-clear settlement are untouched.
    @discardableResult
    public mutating func migrateLegacyPaperRelicToEncoreBell() -> Bool {
        guard MPCChapterOneCatalog.relicsEnabled, encoreBellMigrationVersion < 1 else { return false }
        let oldID = "relic_paper_raincoat"
        let hadPaper = ownedRelicIDs.contains(oldID) || depletedRelicIDs.contains(oldID)
            || loadout.relicIDs.contains(oldID)
        ownedRelicIDs.remove(oldID)
        depletedRelicIDs.remove(oldID)
        loadout.relicIDs.removeAll { $0 == oldID }
        if hadPaper { acceptEncoreBellDelivery() }
        encoreBellMigrationVersion = 1
        return true
    }

    public mutating func refillAllTestItems() {
        for item in MPCChapterOneCatalog.items {
            inventory[item.id] = item.kind == .keyItem ? 1 : item.maxStack
        }
    }

    public var effectiveLoadout: MPCChapterOneLoadout {
        var result = loadout
        result.normalSkillIDs = Array(result.normalSkillIDs.filter { $0 != .maskedWhisper }.prefix(loadoutSlotCapacity))
        var seenRelicIDs = Set<String>()
        result.relicIDs = result.relicIDs.filter {
            $0 != "relic_paper_raincoat" && MPCChapterOneCatalog.isRelicEnabled($0) && ownedRelicIDs.contains($0)
                && !depletedRelicIDs.contains($0)
                && seenRelicIDs.insert($0).inserted
        }
        var hasPassive = false
        result.relicIDs.removeAll { id in
            guard MPCSequenceNineRelicIDs.passives.contains(id) else { return false }
            if hasPassive { return true }; hasPassive = true; return false
        }
        if result.selectedActiveRelicID == MPCChapterOneCatalog.usurpedLifeMedalRelicID && !ownsUsurpedLifeMedal {
            result.selectedActiveRelicID = nil
        }
        // The manual relic is available when owned, independently of card/relic slots.
        if ownsManualMask && !result.relicIDs.contains(MPCChapterOneCatalog.ownerlessMaskRelicID) {
            result.relicIDs.append(MPCChapterOneCatalog.ownerlessMaskRelicID)
        }
        return result
    }

    public func loadout(forMissionID missionID: String?) -> MPCChapterOneLoadout {
        var result = effectiveLoadout
        guard let missionID,
              let mission = MPCChapterOneCatalog.mission(forEncounterID: missionID)
                    ?? MPCChapterOneCatalog.missions.first(where: { $0.id == missionID })
        else { return result }
        if let trialSkillID = mission.trialSkillID,
           !result.normalSkillIDs.contains(trialSkillID) {
            result.normalSkillIDs.append(trialSkillID)
        }
        return result
    }

    public mutating func restoreAllTestRelics() {
        depletedRelicIDs.removeAll()
    }

    public mutating func completeEncounter(_ session: MPCChapterOneEncounterSession) {
        guard session.outcome == .victory else { return }
        guard settledSessionIDs.insert(session.settlementID).inserted else { return }
        let wasNewClear = !completedEncounterIDs.contains(session.encounter.id)
        let missionID = MPCChapterOneCatalog.mission(forEncounterID: session.encounter.id)?.id
        for (id, count) in session.consumables { inventory[id] = count }
        claimVictory(for: session.encounter)
        if wasNewClear {
            completedBehaviorTags.formUnion(session.behaviorTags)
            comboExecutionRecords.append(contentsOf: session.comboRecords.map { record in
                .init(
                    comboID: record.comboID,
                    battleID: record.battleID,
                    missionID: missionID,
                    skillSequence: record.skillSequence,
                    behaviorTags: record.behaviorTags,
                    validTargetChain: record.validTargetChain
                )
            })
        }
        // The final-boss party is battle-only: its allies, their health and the spent revive
        // never reach the persistent party that tower and bounty battles start from.
        if !session.isPartyBossEncounter { party = session.persistentPartyState() }
        if session.mistAnchorWasConsumed {
            depletedRelicIDs.insert("relic_mist_anchor_shard")
        }
        if !session.isPartyBossEncounter { applyPostEncounterRecovery() }
    }

    public mutating func claimVictory(for encounter: MPCEncounterContent) {
        let authoredMission = MPCChapterOneCatalog.mission(forEncounterID: encounter.id)
        let alreadyCleared = completedEncounterIDs.contains(encounter.id)
            || authoredMission.map { completedMissionIDs.contains($0.id) } == true
        completedEncounterIDs.insert(encounter.id)
        let firstClear = !alreadyCleared
        if let mission = authoredMission {
            completedMissionIDs.insert(mission.id)
            guard firstClear, let reward = MPCChapterOneThirtyMissionContract.firstClear(for: mission.number) else { return }
            inventory["currency_copper", default: 0] += reward.copper
            inventory["material_skill_dust", default: 0] += reward.skillDust
            lifetimeChurchMerit += reward.merit
            spendableChurchMerit += reward.merit
            chapterTalentPointsEarned += reward.talentPoints
            for itemID in reward.itemIDs {
                if isStoryItem(itemID) { inventory[itemID] = max(1, inventory[itemID, default: 0]) }
                else { inventory[itemID, default: 0] += 1 }
            }
            for skillID in mission.permanentSkillIDs {
                skillUnlockStates[skillID] = .permanent
                unlockedSkillIDs.insert(skillID)
                if skillID != .namelessStage,
                   !loadout.normalSkillIDs.contains(skillID), loadout.normalSkillIDs.count < loadoutSlotCapacity {
                    loadout.normalSkillIDs.append(skillID)
                }
            }
            _ = applyChapterMissionProgress(districtID: "old-clock", missionNumber: mission.number)
            currentMissionID = MPCChapterOneCatalog.mission(forOldClockMissionNumber: mission.number + 1)?.id ?? mission.id
            if mission.number == 18 { ownedRelicIDs.insert("relic_sealed_paperweight") }
            chapterThirtyRewardVersion = 1
            return
        }
        // Preserve non-main prototype settlement without granting its rewards to main missions.
        for itemID in encounter.fixedRewardItemIDs where firstClear || !isStoryItem(itemID) {
            inventory[itemID, default: 0] += itemID == "material_skill_dust" ? 30 : 1
        }
        if MPCChapterOneCatalog.relicsEnabled, firstClear, let relicID = encounter.firstClearRelicID {
            ownedRelicIDs.insert(relicID)
        }
        guard firstClear,
              let investigation = MPCChapterOneCatalog.investigations.first(where: { $0.encounterIDs.contains(encounter.id) }) else { return }
        let opensInvestigationBuild = investigation.encounterIDs.first == encounter.id
        let completesInvestigation = investigation.encounterIDs.last == encounter.id

        // Permanent combat verbs arrive one at a time. A first clear should
        // teach one new decision, not replace the player's whole deck at once.
        let earnedSkillIDs: [FoolSkillID] = switch encounter.id {
        case "encounter_rain_01": [.sidestepStrike]
        case "encounter_stolen_01": [.identityDisplacement]
        case "encounter_stolen_02": [.fabricatedEvidence]
        case "encounter_thirteenth_01": [.mirrorPursuit]
        case "encounter_thirteenth_02": [.absurdFinale]
        case "encounter_midnight_01": [.turnTheTables]
        case "encounter_midnight_02": [.namelessStage]
        default: []
        }
        unlockedSkillIDs.formUnion(earnedSkillIDs)
        if earnedSkillIDs.contains(.namelessStage) {
            loadout.isUltimateUnlocked = true
        }

        if opensInvestigationBuild {
            unlockedPassiveIDs.formUnion(investigation.unlockPassiveIDs)
        }
        if completesInvestigation {
            for itemID in investigation.unlockItemIDs where inventory[itemID, default: 0] == 0 {
                inventory[itemID] = 1
            }
            ownedRelicIDs.formUnion(investigation.unlockRelicIDs.filter(MPCChapterOneCatalog.isRelicEnabled))
        }

        // Newly earned chapter tools enter the next playable build
        // immediately. The player can later replace them in the build screen;
        // this prevents progression from unlocking content invisibly.
        for skillID in earnedSkillIDs where skillID != .namelessStage {
            guard !loadout.normalSkillIDs.contains(skillID), loadout.normalSkillIDs.count < 5 else { continue }
            loadout.normalSkillIDs.append(skillID)
        }
        for passiveID in investigation.unlockPassiveIDs where opensInvestigationBuild {
            guard !loadout.passiveIDs.contains(passiveID), loadout.passiveIDs.count < 2 else { continue }
            loadout.passiveIDs.append(passiveID)
        }
        for relicID in investigation.unlockRelicIDs where completesInvestigation && MPCChapterOneCatalog.relicsEnabled {
            guard !loadout.relicIDs.contains(relicID), loadout.relicIDs.count < 2 else { continue }
            loadout.relicIDs.append(relicID)
        }
    }

    /// Add only already-earned, bound narrative evidence. Never replay rewards.
    @discardableResult
    public mutating func restoreClaimStoryEvidence(completedMissionNumbers: Set<Int>) -> Bool {
        let before = self
        for mission in MPCChapterOneCatalog.missions where completedMissionNumbers.contains(mission.number) {
            // Record both historical forms before replay can reach the new reward schedule.
            completedMissionIDs.insert(mission.id)
            completedEncounterIDs.insert(mission.encounterID)
            let entitlement = MPCChapterOneThirtyMissionContract.firstClear(for: mission.number)?.itemIDs ?? []
            for id in entitlement where isStoryItem(id) && inventory[id, default: 0] == 0 {
                inventory[id] = 1
            }
        }
        if completedMissionNumbers.contains(18) { ownedRelicIDs.insert("relic_sealed_paperweight") }
        chapterThirtyRewardVersion = 1
        return self != before
    }

    public mutating func applyPostEncounterRecovery() {
        let recovery = party.playerMaxHP * 15 / 100
        party.playerHP = min(party.playerMaxHP, max(party.playerHP, party.playerMaxHP / 10) + recovery)
        for (id, maxHP) in party.allyMaxHP {
            let current = party.allyHP[id, default: maxHP]
            party.allyHP[id] = current <= 0 ? maxHP / 10 : min(maxHP, current + maxHP * 15 / 100)
        }
    }

    private func isStoryItem(_ id: String) -> Bool {
        MPCChapterOneCatalog.items.first(where: { $0.id == id })?.kind == .keyItem
    }
}

public struct MPCEncounterLogEntry: Equatable, Sendable {
    public let round: Int
    public let message: String
    public let damageTaken: Int
    public let bossMechanicMissed: Bool
}

public struct MPCDefeatAnalysis: Equatable, Sendable {
    public let criticalRound: Int
    public let summary: String
    public let recommendations: [String]
}

public struct MPCFoolSkillTargetResolution: Equatable, Sendable {
    public let targetID: String
    public let damage: Int

    public init(targetID: String, damage: Int) {
        self.targetID = targetID
        self.damage = damage
    }
}

public struct MPCFoolSkillEncounterResolution: Equatable, Sendable {
    public let skillID: FoolSkillID
    public let damage: Int
    public let targetID: String?
    public let targets: [MPCFoolSkillTargetResolution]

    public init(
        skillID: FoolSkillID,
        damage: Int,
        targetID: String?,
        targets: [MPCFoolSkillTargetResolution]? = nil
    ) {
        self.skillID = skillID
        self.damage = damage
        self.targetID = targetID
        self.targets = targets ?? targetID.map {
            [.init(targetID: $0, damage: damage)]
        } ?? []
    }
}

public struct MPCExecutedSkill: Equatable, Sendable {
    public let skillID: FoolSkillID
    public let targetID: String?
    public let round: Int
}

public struct MPCCompanionActionResolution: Equatable, Sendable {
    public let companionID: String
    public let skillID: String
    public let message: String
    /// Enemy hit, party member healed/cleansed/shielded (`MPCChapterOneEncounterSession.partyPlayerUnitID`
    /// for the hero), and the amount dealt or restored.
    public internal(set) var targetID: String? = nil
    public internal(set) var amount: Int = 0
}

/// One authoritative enemy beat, kept in authored formation order.
/// Presentation code must consume this list instead of reconstructing enemy
/// actions from the next-turn forecast or from an aggregate HP delta.
public struct MPCEnemyActionResolution: Equatable, Sendable {
    public let enemyID: String
    public let intent: String
    public let playerDamage: Int
    public let redirectedByPaperDouble: Bool
    public let healedTargetID: String?
    public let healing: Int
    public let defenseBoostBP: Int
    /// Final-boss party (Q28–Q30): health each ally lost to this beat (the slam, a name
    /// seal, an intercepted thirteenth blow).
    public internal(set) var allyDamage: [String: Int] = [:]
    /// The ally that took the thirteenth blow in the hero's place.
    public internal(set) var interceptedBy: String? = nil
    /// 夺名代签: the hero's sealed card, or the ally held to its basic attack.
    public internal(set) var sealedSkillID: FoolSkillID? = nil
    public internal(set) var sealedAllyID: String? = nil
}

private struct MPCResolvedEnemyIntent {
    let damage: Int
    let missedBossMechanic: Bool
    var healedTargetID: String? = nil
    var healing: Int = 0
    var defenseBoostBP: Int = 0

    static func attack(_ damage: Int) -> Self {
        .init(damage: damage, missedBossMechanic: false)
    }
}

public enum MPCEncounterRuntimeError: Error, Equatable {
    case unknownEncounter
    case invalidTarget
    case encounterFinished
    case skillNotEquipped(FoolSkillID)
    case unknownConsumable
    case noConsumableRemaining
    case noHealingNeeded
    /// Final-boss party: the hero has fallen and cannot act until revived.
    case playerDown
}

/// The authored Q5 tutorial beat is deliberately isolated from the generic
/// enemy loop so its lethal setup cannot leak into another encounter.
public enum MPCPaperDoubleTutorialPhase: String, Equatable, Sendable {
    case inactive
    case enraged
    case awaitingMara
    case counterattack
    case completed
}

public struct MPCChapterOneEncounterSession: Equatable, Sendable {
    public let settlementID = UUID()
    /// Attacks committed by the presentation clock must land even if their caster
    /// is defeated. The final wave cannot advance until these contacts drain.
    public private(set) var committedEnemyImpacts: Set<String> = []
    public private(set) var damageBySource: [String: Int] = [:]
    private var activeDamageSource = "other"
    private var resolvingEnemyAction = false
    private var combatHasBegun = false
    public private(set) var completedBossCycles = 0
    public private(set) var chapterObjectiveProgress = 0
    public private(set) var chapterSupplyRemaining = 900
    public private(set) var chapterVerificationHits = 0
    public private(set) var chapterVerificationFailed = false
    public var isChurchCombat: Bool { encounter.id.hasPrefix("church_") }
    public var chapterMissionNumber: Int { MPCChapterOneCatalog.mission(forEncounterID: encounter.id)?.number ?? 0 }
    public var chapterObjectiveRequired: Int { chapterMissionNumber == 20 ? 1600 : chapterMissionNumber == 25 ? 1800 : 0 }
    public var chapterDepartedEnemyIDs: Set<String> { Set(enemies.filter(\.hasDeparted).map(\.id)) }

    // MARK: Final-boss party (Q28–Q30; 2026-10-10, user: the hero plus AI 诺恩 and 奥黛尔)
    /// The hero's unit in the party planner, companion results and 夺名代签 targets.
    public static let partyPlayerUnitID = "chapter_one_player"
    /// The sovereign's three meetings. Allies start full with one shared revive and never
    /// touch the persistent party; the slam reaches every standing ally; Q30 runs in phases.
    public var isPartyBossEncounter: Bool { (28...30).contains(chapterMissionNumber) }
    /// Battle health of each active ally.
    public private(set) var allyMaxHP: [String: Int] = [:]
    /// The protector who takes the next thirteenth blow aimed at the hero (once per boss loop).
    public private(set) var armedInterceptAllyID: String?
    private var interceptUsedSerial: Int?
    /// Sovereign loops, finished or cut short by a Q30 phase change.
    private var sovereignCycleSerial = 0
    /// 夺名代签: one sealed card of the hero, or allies held to their basic attack, until then.
    public private(set) var sealedFoolSkillID: FoolSkillID?
    public private(set) var heroSealExpiresAt: TimeInterval = 0
    public private(set) var allySealExpiresAt: [String: TimeInterval] = [:]
    private var nameSealCursor = 0
    private var foolSkillCastAt: [FoolSkillID: TimeInterval] = [:]
    private var allyReadyAt: [String: TimeInterval] = [:]
    /// The healer's mend has its own cooldown; between mends she throws vials.
    private var mendReadyAt: [String: TimeInterval] = [:]
    private var resolvingCompanionDamage = false
    /// The allies' latest actions, for presentation when the caller dropped the return value.
    public private(set) var lastCompanionActions: [MPCCompanionActionResolution] = []
    /// When the healer's revive channel completes for a fallen hero; nil when none is running.
    public private(set) var heroReviveAt: TimeInterval?
    private var nextCompanionTickAt: TimeInterval = 0
    /// Q30 离场祝福 (2026-10-10, user): nil until `applyFarewellBlessings`, and in every other battle.
    public private(set) var farewellBlessings: MPCFarewellBlessings?
    /// 雾中续命: the phase whose entry last healed the sovereign; its loop never falls back below it.
    private var mistMendPhase = 0

    /// Q30 only, once, before combat begins (the App rolls as the Q30 session is created).
    /// 羽翼庇护 adds its revives now; the other five act where their rule lands. False when refused.
    @discardableResult
    public mutating func applyFarewellBlessings(_ blessings: MPCFarewellBlessings) -> Bool {
        guard chapterMissionNumber == 30, farewellBlessings == nil, outcome == .inProgress, !combatHasBegun else { return false }
        farewellBlessings = blessings
        if blessings.hero == .featherShelter { sharedReviveCharges += MPCProgressionWalls.q30FeatherRevives }
        triggeredEffects += blessings.announcements
        return true
    }

    /// Final-boss party (2026-10-10, user): the hero has fallen while an ally still fights.
    /// The hero cannot act; blows meant for the hero fall on the next standing ally; the
    /// party loses only when all three are down.
    public var playerIsDown: Bool { isPartyBossEncounter && outcome == .inProgress && playerHP <= 0 }
    /// The hero stands, or in a party fight an ally still stands for the fallen hero.
    private var partyStillStanding: Bool { playerHP > 0 || (isPartyBossEncounter && activeCompanionIDs.contains { isAllyStanding($0) }) }
    /// The ally a blow meant for the fallen hero lands on: protector first, then healer.
    private var heroStandInID: String? { activeCompanionIDs.first { isAllyStanding($0) } }
    private var revivingHealerID: String? {
        activeCompanionIDs.first { id in
            MPCChapterOneCatalog.companions.first { $0.id == id }?.role == .healer && isAllyStanding(id) && !isAllySealed(id)
        }
    }

    /// The allies' combat-time clock for party fights; call every frame or step (the story
    /// stepper and the App's loop do). It runs the healer's revive channel and lets the allies
    /// act on their cadence even while the hero is down. Other battles return at once: their
    /// allies still act after each player hit.
    @discardableResult
    public mutating func advanceCompanions(at now: TimeInterval, focusTargetID: String? = nil) -> [MPCCompanionActionResolution] {
        guard isPartyBossEncounter, outcome == .inProgress, now.isFinite else { return [] }
        _ = advanceRelicClock(at: now)
        guard outcome == .inProgress else { return [] }
        advanceHeroRevive()
        guard !activeCompanionIDs.isEmpty, relicClock >= nextCompanionTickAt else { return [] }
        nextCompanionTickAt = relicClock + Double(MPCProgressionWalls.partyCompanionTickTenths) / 10
        return performCompanionActions(focusTargetID: focusTargetID)
    }

    /// The healer channels the shared revive while she stands unsealed; a seal or her fall
    /// breaks the channel, which restarts when she can again.
    private mutating func advanceHeroRevive() {
        guard playerIsDown, sharedReviveCharges > 0, let healer = revivingHealerID else { heroReviveAt = nil; return }
        guard let due = heroReviveAt else {
            heroReviveAt = relicClock + Double(MPCProgressionWalls.partyReviveTenths) / 10
            return
        }
        guard relicClock >= due else { return }
        heroReviveAt = nil
        // 羽翼庇护's revives come after the battle's own one, at their own share of health.
        let blessed = farewellBlessings?.hero == .featherShelter && sharedReviveCharges <= MPCProgressionWalls.q30FeatherRevives
        sharedReviveCharges -= 1
        playerHP = max(1, playerMaxHP * (blessed ? MPCProgressionWalls.q30FeatherReviveHealthPercent : MPCProgressionWalls.partyReviveHealthPercent) / 100)
        triggeredEffects.append("\(companionName(healer))：唤回主角")
        log.append(.init(round: round, message: "\(companionName(healer))使用界锚复原", damageTaken: 0, bossMechanicMissed: false))
    }

    public func isFoolSkillSealed(_ skill: FoolSkillID, at now: TimeInterval) -> Bool {
        skill == sealedFoolSkillID && now < heroSealExpiresAt
    }
    /// What the automatic loop must pass over (`ContinuousSkillScheduler.next(skipping:)`).
    public func sealedFoolSkillIDs(at now: TimeInterval) -> Set<FoolSkillID> {
        guard let skill = sealedFoolSkillID, isFoolSkillSealed(skill, at: now) else { return [] }
        return [skill]
    }
    public func isAllySealed(_ id: String) -> Bool { relicClock < allySealExpiresAt[id, default: 0] }
    public func isAllyStanding(_ id: String) -> Bool { activeCompanionIDs.contains(id) && allyHP[id, default: 0] > 0 }
    /// Q30's loop by the sovereign's health: 1 down to 60%, 2 down to 30%, then 3 (enraged);
    /// never below the phase a 雾中续命 heal was given for.
    public var finalBossPhase: Int? {
        guard chapterMissionNumber == 30, let boss = enemies.first(where: { $0.contentID == "boss_chronarch_sovereign" }) else { return nil }
        return max(Self.q30Phase(of: boss), mistMendPhase)
    }
    /// Who the next 夺名代签 lands on: hero → protector → healer, skipping the fallen.
    public var nextNameSealTargetID: String? { nameSealTarget()?.id }

    static func q30Phase(of boss: MPCRuntimeEnemy) -> Int {
        if boss.hp * 100 >= boss.maxHP * MPCProgressionWalls.q30PhaseTwoBelowPercent { return 1 }
        return boss.hp * 100 >= boss.maxHP * MPCProgressionWalls.q30EnrageBelowPercent ? 2 : 3
    }
    /// Four attacks (2026-10-10, user): the strike and the thirteenth blow at the hero, the
    /// slam at all three, the name seal at one. Phase three drops the recovery.
    static func q30Pattern(phase: Int) -> [String] {
        switch phase {
        case 1: ["strike", "strike", "thirteenth_charge", "recover"]
        case 2: ["name_seal", "strike", "slam", "thirteenth_charge", "recover"]
        default: ["slam", "name_seal", "thirteenth_charge", "strike"]
        }
    }
    private func nameSealTarget() -> (id: String, cursor: Int)? {
        let order = [Self.partyPlayerUnitID] + activeCompanionIDs
        for step in 0..<order.count {
            let slot = (nameSealCursor + step) % order.count
            let id = order[slot]
            if id == Self.partyPlayerUnitID ? playerHP > 0 : isAllyStanding(id) { return (id, slot + 1) }
        }
        return nil
    }
    private func companionName(_ id: String) -> String {
        MPCChapterOneCatalog.companions.first { $0.id == id }?.name ?? id
    }
    /// Battle health for an ally; party fights scale the catalog value for tuning.
    static func battleMaxHP(companionID: String, partyBoss: Bool) -> Int {
        let base = MPCChapterOneCatalog.companions.first { $0.id == companionID }?.maxHP ?? 800
        return partyBoss ? max(1, base * MPCProgressionWalls.partyAllyHPPercent / 100) : base
    }
    @discardableResult
    private mutating func damageAlly(_ id: String, _ amount: Int) -> Int {
        guard let hp = allyHP[id], hp > 0, amount > 0 else { return 0 }
        let dealt = min(hp, amount)
        allyHP[id] = hp - dealt
        if hp == dealt {
            allySealExpiresAt[id] = nil
            if armedInterceptAllyID == id { armedInterceptAllyID = nil }
            triggeredEffects.append("\(companionName(id))倒下")
        }
        return dealt
    }
    /// Same strict position cursor as ContinuousSkillScheduler, recorded at dispatch.
    private func nextScheduledFoolSkill() -> FoolSkillID? {
        let loop = loadout.normalSkillIDs.filter { $0 != .maskedWhisper }
        guard !loop.isEmpty else { return nil }
        let next = orderedLastDispatched.flatMap { loop.firstIndex(of: $0) }.map { ($0 + 1) % loop.count } ?? 0
        return loop[next]
    }
    private mutating func clearHeroSeal() -> Bool {
        guard sealedFoolSkillID != nil, relicClock < heroSealExpiresAt else { sealedFoolSkillID = nil; return false }
        sealedFoolSkillID = nil
        heroSealExpiresAt = 0
        return true
    }

    private var finiteDamageTicks: [MPCTimedRelicDamage] = []
    private var towerPoisonSpent: Set<String> = []
    private var towerWaveReadyAt: TimeInterval?
    public var isAwaitingTowerWave: Bool { towerWaveReadyAt != nil }
    private var towerCommittedEmpower: [String: String] = [:]
    private var towerCommittedEmpowerCasters: Set<String> = []
    private struct TowerEmpower: Equatable, Sendable { let sourceID: String; let expiresAt: TimeInterval; var activeCycle: Int? }
    private var towerMendCasts: [String: Int] = [:]
    private var towerEmpowers: [String: TowerEmpower] = [:]
    public var towerEmpoweredEnemyIDs: Set<String> { Set(towerEmpowers.keys) }
    public var churchFinitePoisonActive: Bool {
        outcome == .inProgress && finiteDamageTicks.contains { tick in
            tick.source.hasPrefix("tower-poison:") && enemies.contains { $0.isAlive && "tower-poison:" + $0.id == tick.source }
        }
    }
    public var churchSpittleActive: Bool {
        outcome == .inProgress && finiteDamageTicks.contains { tick in
            tick.source.hasPrefix("bounty-spittle:") && enemies.contains { $0.isAlive && "bounty-spittle:" + $0.id == tick.source }
        }
    }
    public var churchEscortedCaptainIDs: Set<String> {
        Set(enemies.filter { $0.isAlive && $0.contentID == "bounty_b03_drowned_captain" && isTrueImmune($0) }.map(\.id))
    }
    public var churchBindingSourceIDs: Set<String> {
        guard outcome == .inProgress else { return [] }
        return Set(finiteDamageTicks.compactMap { tick in
            guard tick.source.hasPrefix("bounty-poison:") else { return nil }
            let source = String(tick.source.dropFirst("bounty-poison:".count))
            return enemies.contains { $0.id == source && $0.isAlive } ? source : nil
        })
    }
    public func isChurchHighThreatPreparation(enemyID: String) -> Bool {
        guard isChurchCombat, let enemy = enemies.first(where: { $0.id == enemyID && $0.isAlive }),
              !["guard", "recover"].contains(enemy.currentIntent) else { return false }
        return authoredPreparationDuration(for: enemyID) != nil
    }
    public func churchPreparationMustWait(enemyID: String, pendingEnemyIDs: Set<String>) -> Bool {
        isChurchHighThreatPreparation(enemyID: enemyID) && pendingEnemyIDs.contains {
            $0 != enemyID && isChurchHighThreatPreparation(enemyID: $0)
        }
    }
    public func towerEmpowerTargetID(for casterID: String) -> String? {
        if towerCommittedEmpowerCasters.contains(casterID) { return towerCommittedEmpower[casterID] }
        return enemies.first { $0.id != casterID && $0.isAlive && MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species != .crown }?.id
    }
    private mutating func clearDefeatedTowerEffects() {
        let live = Set(enemies.filter(\.isAlive).map(\.id))
        finiteDamageTicks.removeAll { tick in
            for prefix in ["tower-poison:", "bounty-poison:", "bounty-spittle:"] where tick.source.hasPrefix(prefix) {
                return !live.contains(String(tick.source.dropFirst(prefix.count)))
            }
            return false
        }
        towerEmpowers = towerEmpowers.filter { live.contains($0.key) && live.contains($0.value.sourceID) && relicClock < $0.value.expiresAt }
    }
    /// One fixed one-second death fade between waves. Clocks, HP, relic debts and
    /// consumables belong to the whole floor; loading a wave never refreshes them.
    public mutating func advanceChurchTowerEffects(at now: TimeInterval) {
        guard isChurchCombat, now.isFinite else { return }
        towerEmpowers = towerEmpowers.filter { now < $0.value.expiresAt }
        clearDefeatedTowerEffects()
        guard outcome == .inProgress, let ready = towerWaveReadyAt, now >= ready,
              committedEnemyImpacts.isEmpty, !resolvingEnemyAction else { return }
        towerWaveReadyAt = nil
        waveIndex += 1
        loadWave(waveIndex)
        round += 1
    }


    private mutating func advanceFiniteDamage(at now: TimeInterval) {
        clearDefeatedTowerEffects()
        while let next = finiteDamageTicks.indices.min(by: { finiteDamageTicks[$0].dueAt < finiteDamageTicks[$1].dueAt }),
              finiteDamageTicks[next].dueAt <= now, outcome == .inProgress {
            let tick = finiteDamageTicks[next]
            resolveDeferredRelicDamage(through: tick.dueAt)
            guard outcome == .inProgress else { break }
            _ = advanceUsurpedLifeMedal(at: tick.dueAt)
            relicClock = tick.dueAt
            let hp = playerHP
            absorbPlayerDamage(tick.damage, isDamageOverTime: true)
            lastPoisonHealthDamage += hp - playerHP
            pendingPoisonHealthDamage += hp - playerHP
            if tick.remaining > 1 { finiteDamageTicks[next] = .init(source: tick.source, damage: tick.damage, dueAt: tick.dueAt + 3, remaining: tick.remaining - 1) }
            else { finiteDamageTicks.remove(at: next) }
            if playerHP <= 0, isPartyBossEncounter { settlePlayerDownIfNeeded() }
            else if playerHP <= 0 { outcome = .defeat; finishRelicBattle() }
        }
    }
    private mutating func queueFiniteDamage(source: String, damage: Int, ticks: Int = 3) {
        // Same source cannot stack unlimited carpets by repeatedly refreshing a timer.
        guard !finiteDamageTicks.contains(where: { $0.source == source }) else { return }
        finiteDamageTicks.append(.init(source: source, damage: damage, dueAt: relicClock + 3, remaining: ticks))
    }
    private mutating func updateChapterObjective() {
        guard outcome == .inProgress, partyStillStanding, !resolvingEnemyAction, committedEnemyImpacts.isEmpty else { return }
        let q = chapterMissionNumber
        if [28,29].contains(q), completedBossCycles >= 5,
           let boss = enemies.firstIndex(where: { $0.contentID == "boss_chronarch_sovereign" }) {
            enemies[boss].hasDeparted = true
        }
        if [20,25].contains(q), chapterObjectiveProgress >= chapterObjectiveRequired {
            for index in enemies.indices { enemies[index].hasDeparted = true }
        }
        if q == 10, !enemies.contains(where: { $0.contentID == "enemy_calibration_puppet" && $0.isAlive }) {
            for index in enemies.indices where enemies[index].contentID == "enemy_clockwork_hound" { enemies[index].hasDeparted = true }
        }
        if enemies.allSatisfy({ !$0.isAlive }), finiteDamageTicks.isEmpty { advanceWaveOrWin() }
    }
    public private(set) var nameDevourCount = 0
    private var committedRepairTargets: [String: String] = [:]
    private var committedRepairCasters: Set<String> = []
    public var q7RepairTargetID: String? {
        enemies.first { $0.contentID == "enemy_memory_leech_node" }.flatMap { repairTargetID(for: $0.id) }
    }
    /// Frozen per caster: two support cores cannot overwrite one another's
    /// launched beam target. Dead recipients never retarget or revive.
    public func repairTargetID(for casterID: String) -> String? {
        if committedRepairCasters.contains(casterID) { return committedRepairTargets[casterID] }
        let isTowerHealer = enemies.first { $0.id == casterID }.flatMap { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID) }?.species == .backSac
        let recipients = enemies.filter { $0.contentID != "enemy_memory_leech_node" && (!isTowerHealer || ($0.id != casterID && MPCChurchTowerCatalog.enemyConfiguration(contentID: $0.contentID)?.species != .backSac)) }
        return Self.lowestHealthEnemyIndex(in: recipients).map { recipients[$0].id }
    }

    /// Battle-only ambient mist. Each three-second beat grows stronger until combat ends.
    /// Compatibility flag: 1 while the persistent cloud is active, 0 otherwise.
    public private(set) var emeraldPoisonTicksRemaining = 0
    public private(set) var emeraldPoisonIntensity = 0
    public var isEmeraldPoisonActive: Bool { emeraldPoisonNextTick != nil }
    public private(set) var emeraldPoisonDamagePerTick = 0
    private var emeraldPoisonNextTick: TimeInterval?
    private var emeraldPoisonSourceID: String?

    /// 悔笔's cleanse, worst first: thins the emerald fog back to its first concentration
    /// (the fog itself lasts the battle), then the story core's released poison, then the
    /// enemy damage-over-time with the most damage left. Returns what was cleansed.
    private mutating func cleanseOnePlayerDamageOverTime() -> String? {
        if isEmeraldPoisonActive, emeraldPoisonIntensity > 1 {
            emeraldPoisonIntensity = 1
            emeraldPoisonDamagePerTick = max(1, playerBaseMaxHP * 2 / 100)
            return "毒雾浓度"
        }
        if let poison = campaignPrototype?.poisonRemaining, poison > 0 {
            campaignPrototype?.poisonRemaining = 0
            return "核心毒雾"
        }
        if let worst = finiteDamageTicks.indices.max(by: {
            finiteDamageTicks[$0].damage * finiteDamageTicks[$0].remaining < finiteDamageTicks[$1].damage * finiteDamageTicks[$1].remaining
        }) {
            finiteDamageTicks.remove(at: worst)
            return "持续伤害"
        }
        return nil
    }

    public mutating func clearEmeraldPoison() {
        emeraldPoisonTicksRemaining = 0
        emeraldPoisonIntensity = 0
        emeraldPoisonDamagePerTick = 0
        emeraldPoisonNextTick = nil
        emeraldPoisonSourceID = nil
    }

    /// Poison health damage since the last call, wherever its ticks were settled; for display.
    public mutating func takePendingPoisonHealthDamage() -> Int {
        defer { pendingPoisonHealthDamage = 0 }
        return pendingPoisonHealthDamage
    }

    /// Catch up due beats once, without advancing enemy turns or consuming direct-hit defenses.
    @discardableResult
    public mutating func advanceEmeraldPoison(at now: TimeInterval) -> Int {
        lastPoisonHealthDamage = 0
        advanceChurchTowerEffects(at: now)
        guard now.isFinite else { return 0 }
        guard outcome == .inProgress else {
            _ = advanceUsurpedLifeMedal(at: now)
            clearEmeraldPoison()
            return 0
        }
        let hpBefore = playerHP
        while let deadline = emeraldPoisonNextTick, now >= deadline,
              emeraldPoisonTicksRemaining > 0, outcome == .inProgress {
            resolveDeferredRelicDamage(through: deadline)
            guard outcome == .inProgress else { break }
            _ = advanceUsurpedLifeMedal(at: deadline)
            relicClock = deadline
            let shieldBefore = playerShield
            let poisonHPBefore = playerHP
            absorbPlayerDamage(emeraldPoisonDamagePerTick, isDamageOverTime: true)
            lastPoisonHealthDamage += poisonHPBefore - playerHP
            pendingPoisonHealthDamage += poisonHPBefore - playerHP
            log.append(.init(round: round, message: "翠毒漫天：毒雾造成\(emeraldPoisonDamagePerTick)伤害，浓度\(emeraldPoisonIntensity)",
                damageTaken: emeraldPoisonDamagePerTick, bossMechanicMissed: false))
            triggeredEffects.append("翠毒漫天：持续侵蚀\(emeraldPoisonDamagePerTick)，护盾吸收\(shieldBefore - playerShield)")
            if playerHP <= 0 { outcome = .defeat; settleUsurpedLifeMedal() }
            if outcome != .inProgress { clearEmeraldPoison() }
            else {
                emeraldPoisonIntensity += 1
                emeraldPoisonDamagePerTick += max(1, playerBaseMaxHP / 200)
                emeraldPoisonNextTick = deadline + 3
            }
        }
        advanceFiniteDamage(at: now)
        resolveDeferredRelicDamage(through: now)
        updateChapterObjective()
        _ = advanceUsurpedLifeMedal(at: now)
        advanceOrderedSkills(at: now)
        relicClock = max(relicClock, now)
        return hpBefore - playerHP
    }

    /// A delayed actor spends this ready beat without starting a new attack.
    public mutating func consumeEnemyDelay(for id: String) -> Bool {
        guard let index = enemies.firstIndex(where: { $0.id == id }),
              enemies[index].delayedRounds > 0, !q22FailedBlowIsDue(enemies[index]) else { return false }
        enemies[index].delayedRounds -= 1
        return true
    }

    public mutating func commitEnemyImpact(from enemyID: String) {
        guard outcome == .inProgress, enemies.contains(where: { $0.id == enemyID && $0.isAlive }) else { return }
        combatHasBegun = true
        committedEnemyImpacts.insert(enemyID)
        if enemies.first(where: { $0.id == enemyID })?.currentIntent == "repair_guard" || enemies.first(where: { $0.id == enemyID })?.currentIntent == "tower_mend" {
            committedRepairTargets[enemyID] = repairTargetID(for: enemyID)
            committedRepairCasters.insert(enemyID)
        }
        if enemies.first(where: { $0.id == enemyID })?.currentIntent == "tower_empower" {
            towerCommittedEmpower[enemyID] = towerEmpowerTargetID(for: enemyID)
            towerCommittedEmpowerCasters.insert(enemyID)
        }
    }

    /// Call only after the church presentation confirms that this dead actor's
    /// pending animation/contact was cancelled. A projectile still travelling
    /// must retain its commitment and resolve through endRound normally.
    /// Returns false for living actors, consumed contacts, and all main missions.
    @discardableResult
    public mutating func cancelCommittedEnemyImpact(enemyID: String, at now: TimeInterval) -> Bool {
        guard isChurchCombat, outcome == .inProgress, now.isFinite,
              enemies.contains(where: { $0.id == enemyID && !$0.isAlive }),
              committedEnemyImpacts.remove(enemyID) != nil else { return false }
        relicClock = max(relicClock, now)
        committedRepairTargets.removeValue(forKey: enemyID)
        committedRepairCasters.remove(enemyID)
        towerCommittedEmpower.removeValue(forKey: enemyID)
        towerCommittedEmpowerCasters.remove(enemyID)
        clearDefeatedTowerEffects()
        updateChapterObjective()
        return true
    }

    /// A charger killed mid-charge never releases its charge (the story stepper drops it):
    /// clear its commitment, main missions included, since a charge carries no projectile,
    /// and finish the wave if it was the last enemy. Without this the battle never ended.
    public mutating func releaseDeadCharger(enemyID: String) {
        guard outcome == .inProgress,
              let enemy = enemies.first(where: { $0.id == enemyID && !$0.isAlive }), enemy.currentIntent == "charge",
              committedEnemyImpacts.remove(enemyID) != nil else { return }
        if enemies.allSatisfy({ !$0.isAlive }) { advanceWaveOrWin() }
    }

    /// A live support actor whose already-frozen recipient disappeared may
    /// cancel only that support action. Never retarget, heal, or repeat it.
    @discardableResult
    public mutating func cancelTargetedSupport(enemyID: String, at now: TimeInterval) -> Bool {
        guard isChurchCombat, outcome == .inProgress, now.isFinite,
              let index = enemies.firstIndex(where: { $0.id == enemyID && $0.isAlive }),
              committedEnemyImpacts.contains(enemyID) else { return false }
        let intent = enemies[index].currentIntent
        let target: String?
        if intent == "tower_mend", committedRepairCasters.contains(enemyID) { target = committedRepairTargets[enemyID] }
        else if intent == "tower_empower", towerCommittedEmpowerCasters.contains(enemyID) { target = towerCommittedEmpower[enemyID] }
        else { return false }
        guard !enemies.contains(where: { $0.id == target && $0.isAlive }) else { return false }
        relicClock = max(relicClock, now)
        committedEnemyImpacts.remove(enemyID)
        committedRepairTargets.removeValue(forKey: enemyID)
        committedRepairCasters.remove(enemyID)
        towerCommittedEmpower.removeValue(forKey: enemyID)
        towerCommittedEmpowerCasters.remove(enemyID)
        enemies[index].intentIndex += 1
        lastEnemyActionResolutions.removeAll(keepingCapacity: true)
        round += 1
        updateChapterObjective()
        return true
    }

    /// Isolated presentation prototype: no campaign reward or save migration.
    /// Charge is uncommitted; only the launched attack survives caster death.
    public mutating func prepareEncoreBellPrototype() {
        guard encounter.id == "chapter01_q05_encounter", round == 1 else { return }
        loadout.relicIDs.removeAll { !MPCChapterOneCatalog.isRelicEnabled($0) || $0 == "relic_paper_raincoat" }
        q5PaperRelicReady = false
        q5PaperRelicTriggered = false
        encorePrototypePrepared = true
        timedMasqueradeExpiresAt = nil
        timedMasqueradeReadyAt = 0
        encoreDebtEnemyID = nil
        encoreDebtWasMarked = false
        masqueradeCharges = 0
        paperDoubleTutorialPhase = .inactive
        enemies = enemies.map { enemy in
            MPCRuntimeEnemy(id: enemy.id, contentID: enemy.contentID, name: enemy.name,
                maxHP: 2400, hp: 2400, attack: enemy.attack, defense: enemy.defense,
                intentPattern: ["charge", "memory_breath", "charge", "emerald_burst"], intentIndex: 0, delayedRounds: 0)
        }
    }

    /// Activates Q5's one-charge timed mask. This prototype is intentionally
    /// independent from the normal skill card and therefore has no skill
    /// cooldown or damage side effects.
    @discardableResult
    public mutating func activateTimedMasquerade(at now: TimeInterval) -> Bool {
        _ = expireTimedMasquerade(at: now)
        guard encorePrototypePrepared,
              encounter.id == "chapter01_q05_encounter",
              outcome == .inProgress,
              now.isFinite,
              loadout.normalSkillIDs.contains(.maskedWhisper),
              now >= timedMasqueradeReadyAt,
              masqueradeCharges == 0 else { return false }
        masqueradeCharges = 1
        timedMasqueradeExpiresAt = now + 4
        timedMasqueradeReadyAt = now + 12
        return true
    }

    /// Clears the timed mask after its four-second lifetime. Calling before
    /// expiry is a no-op and returns false.
    @discardableResult
    public mutating func expireTimedMasquerade(at now: TimeInterval) -> Bool {
        guard now.isFinite,
              let expiry = timedMasqueradeExpiresAt,
              now >= expiry else { return false }
        masqueradeCharges = 0
        timedMasqueradeExpiresAt = nil
        return true
    }

    public var isEncoreEncounter: Bool {
        encounter.id == "chapter01_q05_encounter"
            && (encorePrototypePrepared || enemies.contains { $0.contentID == "enemy_emerald_revenant" })
    }

    /// An unused bell only becomes available from an effective equipped loadout.
    /// The isolated prototype explicitly opts into its own trial equipment.
    public var canUseEncoreBell: Bool {
        outcome == .inProgress && !encoreDebtWasMarked
            && (encorePrototypePrepared || loadout.relicIDs.contains("relic_encore_bell"))
    }

    public var pendingEncoreDebtEnemyID: String? { encoreDebtEnemyID }

    /// Arms the next non-zero attack from the charging enemy for a single 50%
    /// damage boost. Zero damage does not consume the debt.
    @discardableResult
    public mutating func markEncoreDebt(enemyID: String) -> Bool {
        guard canUseEncoreBell,
              let enemy = enemies.first(where: { $0.id == enemyID }),
              enemy.currentIntent == "charge",
              encoreDebtEnemyID == nil,
              !encoreDebtWasMarked,
              enemy.isAlive else { return false }
        encoreDebtEnemyID = enemyID
        encoreDebtWasMarked = true
        return true
    }

    private var talentLastSkill: FoolSkillID? = nil
    private var talentLastDamageSkill: FoolSkillID? = nil
    private var talentDamageCount = 0
    private var talentEchoReady = false
    private var talentFinalEchoReady = false
    private var talentMaskReady = false
    private var talentEvidenceReady = false

    public private(set) var campaignPrototype: MPCCampaignBattleState? = nil
    /// The combat tempo this battle runs at (CombatTempo.swift); nil keeps the former rules.
    public private(set) var tempo: MPCCombatTempo? = nil
    public mutating func adoptTempo(_ tempo: MPCCombatTempo?) { self.tempo = tempo }
    public let encounter: MPCEncounterContent
    public private(set) var waveIndex: Int
    public private(set) var enemies: [MPCRuntimeEnemy]
    public private(set) var round: Int
    public private(set) var outcome: MPCEncounterOutcome
    public private(set) var playerHP: Int
    public let playerBaseMaxHP: Int
    public var playerNormalMaxHP: Int { max(1, playerBaseMaxHP - saltBreathingBagStored / 10) }
    public var playerMaxHP: Int { isUsurpedLifeMedalActive ? (playerNormalMaxHP * 3 + 1) / 2 : playerNormalMaxHP }
    public private(set) var saltBreathingBagStored = 0
    public var relicBalance = MPCSequenceNineRelicBalance()
    public static let archiveRecoveryDuration: TimeInterval = 4.5
    public private(set) var lastPoisonHealthDamage = 0
    /// Poison health damage not yet shown. `lastPoisonHealthDamage` only covers the latest
    /// `advanceEmeraldPoison` call, and the App's frame calls `advanceQ4Clock` first, which
    /// settles every due tick through `advanceRelicClock`; enemy actions (`endRound`,
    /// `resolveLightAttack`) do the same. The App's own poison call then read 0 every time:
    /// on the phone the emerald mist took health with no number (2026-10-03). Every tick
    /// adds here until the App takes it.
    public private(set) var pendingPoisonHealthDamage = 0
    public private(set) var sequenceNineRelics = MPCSequenceNineRelicState()
    public private(set) var lastRelicPlayerHealing = 0
    public private(set) var relicDamageEvents: [MPCRelicDamageEvent] = []
    public private(set) var relicHealingEvents: [MPCRelicDamageEvent] = []
    private var resolvingDeferredDamage = false

    public mutating func updateRelicTarget(_ targetID: String?, at now: TimeInterval) {
        sequenceNineRelics.select(targetID, at: now)
    }
    public func willSealPreparedSkill(_ skillID: FoolSkillID, at now: TimeInterval) -> Bool {
        loadout.relicIDs.contains("relic_sealed_paperweight") &&
        sequenceNineRelics.shouldSeal(slot: loadout.normalSkillIDs.firstIndex(of: skillID) ?? -1,
            preparedCount: loadout.normalSkillIDs.count, at: now)
    }
    @discardableResult
    public mutating func activateBlankNameCard(isOwned: Bool, targetID: String, at now: TimeInterval) -> Bool {
        guard isOwned, outcome == .inProgress, !playerIsDown, loadout.selectedActiveRelicID == "relic_blank_name_card",
              !isUsurpedLifeMedalActive, masqueradeCharges == 0,
              enemies.contains(where: { $0.id == targetID && $0.isAlive }) else { return false }
        let activated = sequenceNineRelics.activateBlankCard(targetID: targetID, at: now)
        if activated { combatHasBegun = true }
        return activated
    }
    private func isTrueImmune(_ enemy: MPCRuntimeEnemy) -> Bool {
        (enemy.contentID == "bounty_b03_drowned_captain" && enemies.contains { $0.isAlive && $0.contentID.hasPrefix("bounty_b03_escort_") }) ||
        ((enemy.contentID == "bounty_b06_dark_hold_captain" || MPCChurchTowerCatalog.isShieldJaw(enemy.contentID) || enemy.contentID == "enemy_archive_gatekeeper" || (chapterMissionNumber == 10 && enemy.contentID == "enemy_calibration_puppet")) && enemy.currentIntent == "guard")
    }
    private mutating func resolveDeferredRelicDamage(through now: TimeInterval) {
        guard outcome == .inProgress, let ticket = sequenceNineRelics.takeDueDamage(at: now) else { return }
        _ = advanceUsurpedLifeMedal(at: ticket.dueAt)
        relicClock = ticket.dueAt
        guard let target = enemies.first(where: { $0.id == ticket.targetID && $0.isAlive }), !isTrueImmune(target) else { return }
        resolvingDeferredDamage = true
        let actual = (try? applyPartyDamage(ticket.amount, to: ticket.targetID)) ?? 0
        resolvingDeferredDamage = false
        if actual > 0 { relicDamageEvents.append(.init(targetID: ticket.targetID, damage: actual)) }
    }

    public func authoredPreparationDuration(for enemyID: String) -> TimeInterval? {
        if let enemy = enemies.first(where: { $0.id == enemyID }), MPCChurchBountyCatalog.enemyDefinition(id: enemy.contentID) != nil {
            switch enemy.currentIntent {
            case "guard", "charge", "bounty_bind_charge", "bounty_copy_charge", "bounty_knock_charge", "bounty_veil_charge": return 3
            case "bounty_armor", "bounty_mirror": return 1.2
            case "recover": return 3.5
            default: return nil
            }
        }
        if let enemy = enemies.first(where: { $0.id == enemyID }), let duration = MPCChurchTowerCatalog.preparationDuration(contentID: enemy.contentID, intent: enemy.currentIntent) { return duration }
        guard chapterMissionNumber >= 16 || chapterMissionNumber == 10,
              let enemy = enemies.first(where: { $0.id == enemyID }) else { return nil }
        if MPCChurchTowerCatalog.isShieldJaw(enemy.contentID) || enemy.contentID == "enemy_archive_gatekeeper" || (chapterMissionNumber == 10 && enemy.contentID == "enemy_calibration_puppet") {
            return enemy.currentIntent == "guard" ? 3 : enemy.currentIntent == "recover" ? Self.archiveRecoveryDuration : nil
        }
        switch enemy.currentIntent {
        case "calibration": return 4.2
        case "recover": return 3.5
        case "guard": return 3
        case "charge": return 3
        default: return nil
        }
    }

    public func authoredRecoveryDelay(after intent: String, enemyID: String) -> TimeInterval? {
        if chapterMissionNumber >= 16, intent == "strike",
           enemies.contains(where: { $0.id == enemyID && ["enemy_codex_executor", "enemy_archive_convoy"].contains($0.contentID) }) { return 0 }
        guard encounter.id == "chapter01_q05_encounter",
              enemies.contains(where: { $0.id == enemyID && $0.contentID == "enemy_emerald_revenant" }) else { return nil }
        switch intent {
        case "memory_breath": return 11
        case "emerald_burst": return 19.9
        case "charge": return 0
        default: return nil
        }
    }
    public private(set) var enemyGiftShields: [String: Int] = [:]
    public private(set) var returnGiftClaspReadyAt: TimeInterval = 0
    private var returnGiftClaspDebtorID: String?
    private var relicClock: TimeInterval = 0
    public private(set) var orderedHasteUntil: TimeInterval = 0
    public private(set) var orderedCastReadyAt: TimeInterval = 0
    private var orderedPrepared: MPCOrderedPreparedCast?
    private var orderedPending: [MPCOrderedPendingHit] = []
    private var orderedDamageContext: MPCOrderedDamageContext? = nil
    private var orderedImpacts: [MPCOrderedSkillImpact] = []
    private var orderedLastDispatched: FoolSkillID?
    private var orderedShield = 0
    private var orderedShieldUntil: TimeInterval = 0
    private var orderedWardUntil: TimeInterval = 0
    private var brokenSwordReadyAt: [String: TimeInterval] = [:]
    /// Q12 wall: fortify stacks per puppet (MPCProgressionWalls.q12FortifyStackPercent).
    public private(set) var q12FortifyStacks: [String: Int] = [:]
    public var returnGiftClaspIsReady: Bool {
        relicClock >= returnGiftClaspReadyAt && (returnGiftClaspDebtorID == nil ||
            !enemies.contains { $0.id == returnGiftClaspDebtorID && $0.isAlive && enemyGiftShields[$0.id, default: 0] > 0 })
    }

    /// Buff expiry is processed against logical event deadlines, never render-frame order.
    @discardableResult
    public mutating func advanceRelicClock(at now: TimeInterval) -> Bool {
        guard now.isFinite, now >= relicClock else { return false }
        let oldHP = playerHP, oldMax = playerMaxHP
        _ = advanceEmeraldPoison(at: now)
        return oldHP != playerHP || oldMax != playerMaxHP
    }

    /// Terminal cleanup restores sealed capacity without creating healing.
    public mutating func finishRelicBattle() {
        _ = settleUsurpedLifeMedal()
        counter.clearWindow()
        saltBreathingBagStored = 0
        orderedPending.removeAll(); orderedPrepared = nil
        orderedShield = 0; orderedWardUntil = 0; orderedHasteUntil = 0
        enemyGiftShields.removeAll()
        finiteDamageTicks.removeAll()
        towerWaveReadyAt = nil
        towerEmpowers.removeAll()
        towerCommittedEmpower.removeAll()
        towerCommittedEmpowerCasters.removeAll()
        returnGiftClaspDebtorID = nil
    }
    public private(set) var playerShield: Int
    public private(set) var allyHP: [String: Int]
    public private(set) var sharedReviveCharges: Int
    public private(set) var bossPhase: MPCOldClockBossPhase?
    public private(set) var bossExposedRounds: Int
    public private(set) var bossEmpowermentStacks: Int
    public private(set) var thirteenthBellCountdown: Int
    public private(set) var log: [MPCEncounterLogEntry]
    public private(set) var foolStates: [String: FoolComboState]
    public private(set) var foolUltimateUsed: Bool
    public private(set) var foolCooldowns: FoolCooldownState
    public private(set) var consumables: [String: Int]
    public let activeCompanionIDs: [String]
    public private(set) var loadout: MPCChapterOneLoadout
    public var tacticMode: MPCPartyTacticMode
    public private(set) var borrowedSecondAvailable: Bool
    public private(set) var triggeredEffects: [String]
    public private(set) var behaviorTags: Set<MPCChapterOneBehaviorTag>
    public private(set) var executedSkills: [MPCExecutedSkill]
    public private(set) var comboRecords: [MPCComboExecutionRecord]
    public private(set) var masqueradeCharges: Int
    public private(set) var paperDoubleCounterCharges: Int
    public private(set) var paperDoubleTutorialPhase: MPCPaperDoubleTutorialPhase
    public private(set) var q5RageAttacksCompleted: Int
    public private(set) var q5PaperDoubleCountersCompleted: Int
    /// Q5's paper person is a relic handoff, not an equipped skill card.
    /// These two flags are exposed so the presentation layer can render the
    /// dedicated relic row and the one-use transition without owning combat
    /// rules.
    public private(set) var q5PaperRelicReady: Bool
    public private(set) var q5PaperRelicTriggered: Bool
    /// Q5-only timed mask prototype state. Times use the caller's monotonic clock.
    public private(set) var timedMasqueradeExpiresAt: TimeInterval?
    public private(set) var timedMasqueradeReadyAt: TimeInterval
    private var encorePrototypePrepared: Bool
    private var encoreDebtEnemyID: String?
    private var encoreDebtWasMarked: Bool
    /// Q6: one punish opportunity, shared by all sources and consumed once.
    public private(set) var counter = MPCCombatCounter()
    public var canRequestCounter: Bool {
        outcome == .inProgress && !playerIsDown && chapterMissionNumber >= 4
            && loadout.normalSkillIDs.filter(\.isOrderedOrdinary).count >= 2 && counter.isAvailable(at: relicClock)
    }
    public var isCounterActive: Bool { outcome == .inProgress && counter.isActive(at: relicClock) }
    @discardableResult public mutating func requestCounter(at now: TimeInterval) -> Bool {
        advanceQ4Clock(at: now)
        guard canRequestCounter else { return false }
        return counter.request(at: now)
    }
    @discardableResult public mutating func activateCounter(at now: TimeInterval) -> Bool {
        guard outcome == .inProgress, !playerIsDown, counter.activate(at: now) else { return false }
        if chapterMissionNumber == 4 { q4OpeningUntil = now + MPCCombatCounter.window }
        triggeredEffects.append("反击：普通牌冷却刷新，从第一张重启编排")
        return true
    }
    public private(set) var q4OpeningUntil: TimeInterval?
    private var q4Clock: TimeInterval = 0
    private var q4FirstFlameBlocked = false
    public var isQ4OpeningActive: Bool { encounter.id == "chapter01_q04_encounter" && outcome == .inProgress && (q4OpeningUntil ?? 0) > q4Clock }
    public mutating func advanceQ4Clock(at now: TimeInterval) {
        guard now.isFinite else { return }
        _ = expireOwnedManualMasquerade(at: now)
        _ = advanceRelicClock(at: now)
        q4Clock = now
        if outcome != .inProgress || now >= (q4OpeningUntil ?? 0) { q4OpeningUntil = nil }
    }
    public mutating func clearQ4HoundState() {
        q4OpeningUntil = nil
        q4FirstFlameBlocked = false
        counter.clearWindow()
    }
    public private(set) var houndOpeningReady = false
    private var houndPaperInterceptUsed = false
    public private(set) var freeEvasionCharges: Int
    public private(set) var mistAnchorWasConsumed: Bool
    public private(set) var controlSealActive: Bool
    public private(set) var lastEnemyActionResolutions: [MPCEnemyActionResolution]
    private var enemyDefenseBoosts: [String: MPCEnemyDefenseBoost]
    private var lateApplauseReady: Bool
    private var shieldBreakTriggered: Bool
    private var lowHPTriggered: Bool
    private var mirrorThreadBonusReady: Bool
    private var variedActionCategories: Set<MPCPlayerActionCategory>
    private var unifiedGearDamageReady: Bool
    public private(set) var ringExposurePending = false
    public private(set) var sealConversionReady = false
    private var memoryLeechCostPaid: Bool
    private var readySkillHeldActions: [FoolSkillID: Int]
    private var healingPenaltyBP: Int
    private var previousActionCategory: MPCPlayerActionCategory?
    /// Set by 悔笔 with the leech vial: the next 伪证 marks last 0.5 s longer per stack.
    private var enhancedSetupStacks: Int
    private var borrowedBellTriggeredRound: Int?
    private var unreliableNarratorTriggeredRound: Int?
    private var q5PaperDoubleWasTriggered: Bool
    private var q5FinishingTurnsCompleted: Int
    private var q5LastFinishingRound: Int?
    private var q4FinishingTurnsCompleted: Int
    private var q4LastFinishingRound: Int?
    private var houndNameHuntStacks: Int

    public static func start(
        encounterID: String,
        party: MPCPartyPersistentState = MPCPartyPersistentState(),
        consumables: [String: Int] = [:],
        companionIDs: [String]? = nil,
        loadout: MPCChapterOneLoadout = MPCChapterOneLoadout(),
        campaignPrototype: MPCCampaignScenario? = nil
    ) throws -> Self {
        if let campaignPrototype, campaignPrototype.id != encounterID { throw MPCEncounterRuntimeError.unknownEncounter }
        guard let encounter = (MPCChapterOneCatalog.encounters.first(where: { $0.id == encounterID }) ?? MPCChurchTowerCatalog.encounter(id: encounterID) ?? MPCChurchBountyCatalog.encounter(id: encounterID) ?? MPCChurchMaintenanceCatalog.encounter(id: encounterID) ?? campaignPrototype?.encounter) else {
            throw MPCEncounterRuntimeError.unknownEncounter
        }
        // Reject the retired paper relic in all formal battles. Ownership is
        // validated by the campaign effective loadout, including earlier-stage replays.
        var loadout = loadout
        if ["chapter01_q03_encounter", "chapter01_q04_encounter"].contains(encounterID) {
            loadout.selectedActiveRelicID = MPCChapterOneCatalog.ownerlessMaskRelicID
        }
        loadout.relicIDs.removeAll { !MPCChapterOneCatalog.isRelicEnabled($0) || $0 == "relic_paper_raincoat" }
        let availableIDs = companionIDs ?? MPCChapterOneCatalog.companions.map(\.id)
        let activeIDs = Array(availableIDs.filter { id in
            MPCChapterOneCatalog.companions.contains(where: { $0.id == id })
        }.prefix(encounter.companionSlots))
        // Final-boss party fights stand alone: allies at full health, one shared revive,
        // nothing read from (or later written to) the persistent party.
        let partyBoss = (28...30).contains(MPCChapterOneCatalog.mission(forEncounterID: encounter.id)?.number ?? 0)
        let allyMaxHP = Dictionary(uniqueKeysWithValues: activeIDs.map { ($0, Self.battleMaxHP(companionID: $0, partyBoss: partyBoss)) })
        var initialAllyHP = partyBoss ? [:] : party.allyHP
        for id in activeIDs where initialAllyHP[id] == nil { initialAllyHP[id] = allyMaxHP[id] }
        var session = Self(
            encounter: encounter,
            waveIndex: 0,
            enemies: [],
            round: 1,
            outcome: .inProgress,
            // Every encounter is a fresh combat instance. Persistent HP may
            // be used by other modes, but chapter stages always begin full.
            playerHP: (party.playerMaxHP + loadout.churchGear.maxHP) * (10_000 + loadout.housingRestBP) / 10_000,
            playerBaseMaxHP: (party.playerMaxHP + loadout.churchGear.maxHP) * (10_000 + loadout.housingRestBP) / 10_000,
            playerShield: (loadout.passiveIDs.contains("fool_passive_01") ? 50 : 0)
                + (loadout.ritual == .paperWard ? 100 : 0),
            allyHP: initialAllyHP,
            sharedReviveCharges: partyBoss ? 1 : party.sharedReviveCharges,
            bossPhase: encounter.id == "encounter_midnight_02" ? .calibration : nil,
            bossExposedRounds: 0,
            bossEmpowermentStacks: 0,
            thirteenthBellCountdown: 4,
            log: [],
            foolStates: [:],
            foolUltimateUsed: false,
            foolCooldowns: FoolCooldownState(),
            consumables: consumables,
            activeCompanionIDs: activeIDs,
            loadout: loadout,
            tacticMode: .balanced,
            borrowedSecondAvailable: loadout.ritual == .borrowedSecond,
            triggeredEffects: [],
            behaviorTags: [],
            executedSkills: [],
            comboRecords: [],
            masqueradeCharges: 0,
            paperDoubleCounterCharges: 0,
            paperDoubleTutorialPhase: .inactive,
            q5RageAttacksCompleted: 0,
            q5PaperDoubleCountersCompleted: 0,
            q5PaperRelicReady: loadout.relicIDs.contains("relic_paper_raincoat"),
            q5PaperRelicTriggered: false,
            timedMasqueradeExpiresAt: nil,
            timedMasqueradeReadyAt: 0,
            encorePrototypePrepared: false,
            encoreDebtEnemyID: nil,
            encoreDebtWasMarked: false,
            freeEvasionCharges: 0,
            mistAnchorWasConsumed: false,
            controlSealActive: encounter.id == "chapter01_q01_encounter",
            lastEnemyActionResolutions: [],
            enemyDefenseBoosts: [:],
            lateApplauseReady: false,
            shieldBreakTriggered: false,
            lowHPTriggered: false,
            mirrorThreadBonusReady: false,
            variedActionCategories: [],
            unifiedGearDamageReady: false,
            memoryLeechCostPaid: false,
            readySkillHeldActions: [:],
            healingPenaltyBP: 0,
            previousActionCategory: nil,
            enhancedSetupStacks: 0,
            borrowedBellTriggeredRound: nil,
            unreliableNarratorTriggeredRound: nil,
            q5PaperDoubleWasTriggered: false,
            q5FinishingTurnsCompleted: 0,
            q5LastFinishingRound: nil,
            q4FinishingTurnsCompleted: 0,
            q4LastFinishingRound: nil,
            houndNameHuntStacks: 0
        )
        session.campaignPrototype = campaignPrototype.map { MPCCampaignBattleState($0) }
        session.allyMaxHP = allyMaxHP
        session.loadWave(0)
        return session
    }

    public var announcedIntents: [(enemyID: String, intent: String)] {
        var intents = enemies.filter(\.isAlive).map {
            ($0.id, $0.delayedRounds > 0 ? "delayed" : $0.currentIntent)
        }
        if loadout.relicIDs.contains("relic_thirteenth_record"), round.isMultiple(of: 3),
           let enemy = enemies.first(where: \.isAlive), !enemy.intentPattern.isEmpty {
            let next = enemy.intentPattern[(enemy.intentIndex + 1) % enemy.intentPattern.count]
            intents.append((enemy.id, "下一意图：\(next)"))
        }
        return intents
    }

    public func foolState(for enemyID: String) -> FoolComboState? {
        foolStates[enemyID]
    }

    /// A positive value marks an authored, temporary enemy defense modifier.
    /// The presentation layer uses it to show support-state feedback without
    /// owning any combat result.
    public func enemyDefenseBonusBP(for enemyID: String) -> Int {
        enemyDefenseBoosts[enemyID]?.bonusBP ?? 0
    }

    /// Selects the living, wounded enemy with the greatest missing-health
    /// percentage. The caster participates: a support enemy must be able to
    /// repair itself when it is the most damaged combatant. Ties keep the
    /// authored formation order deterministic.
    static func lowestHealthEnemyIndex(
        in enemies: [MPCRuntimeEnemy]
    ) -> Int? {
        enemies.indices
            .filter {
                let enemy = enemies[$0]
                return enemy.isAlive && enemy.hp < enemy.maxHP
            }
            .min { leftIndex, rightIndex in
                let left = enemies[leftIndex]
                let right = enemies[rightIndex]
                let leftRatio = Int64(left.hp) * Int64(right.maxHP)
                let rightRatio = Int64(right.hp) * Int64(left.maxHP)
                if leftRatio == rightRatio { return leftIndex < rightIndex }
                return leftRatio < rightRatio
            }
    }

    public func remainingCooldownActions(for skillID: FoolSkillID) -> Int {
        foolCooldowns.remainingActions(for: skillID)
    }

    public func canUseFoolSkill(_ skillID: FoolSkillID) -> Bool {
        foolCooldowns.isAvailable(skillID)
            && !(skillID == .namelessStage && foolUltimateUsed)
            && !isFoolSkillSealed(skillID, at: relicClock)
    }

    /// Adds a mission-granted trial card to the active combat session without
    /// changing the player's persistent campaign inventory. Q1 uses this at
    /// Mara's intervention so the card becomes visible and executable in the
    /// same session that taught it.
    @discardableResult
    public mutating func grantTrialSkill(_ skillID: FoolSkillID) -> Bool {
        guard skillID != .namelessStage,
              !loadout.normalSkillIDs.contains(skillID),
              loadout.normalSkillIDs.count < 5 else { return false }
        loadout.normalSkillIDs.append(skillID)
        return true
    }

    /// The battle UI supplies only owned/trial cards from its selectable shelf.
    public private(set) var ownedManualMaskReadyAt: TimeInterval = 0

    public private(set) var usurpedLifeMedalExpiresAt: TimeInterval?
    public private(set) var usurpedLifeMedalReadyAt: TimeInterval = 0
    public private(set) var usurpedLifeMedalActivationID: UUID?
    public private(set) var usurpedLifeMedalSettledActivationID: UUID?
    public var isUsurpedLifeMedalActive: Bool { usurpedLifeMedalActivationID != nil }
    public static let usurpedLifeMedalDuration: TimeInterval = 8
    public static let usurpedLifeMedalCooldown: TimeInterval = 24

    /// Presentation permits selection only before combat starts; an existing activation
    /// cannot be swapped away to evade its settlement.
    @discardableResult
    public mutating func selectActiveRelic(_ id: String?, isOwned: Bool) -> Bool {
        guard !combatHasBegun, outcome == .inProgress, !isUsurpedLifeMedalActive, ownedManualMaskExpiresAt == nil,
              id == nil || (isOwned && [MPCChapterOneCatalog.ownerlessMaskRelicID, MPCChapterOneCatalog.usurpedLifeMedalRelicID, "relic_blank_name_card"].contains(id!)) else { return false }
        if ["chapter01_q03_encounter", "chapter01_q04_encounter"].contains(encounter.id), id == MPCChapterOneCatalog.usurpedLifeMedalRelicID { return false }
        loadout.selectedActiveRelicID = id
        return true
    }

    @discardableResult
    public mutating func activateUsurpedLifeMedal(isOwned: Bool, at now: TimeInterval) -> Bool {
        guard now.isFinite else { return false }
        _ = advanceUsurpedLifeMedal(at: now)
        guard isOwned, outcome == .inProgress, playerHP > 0, !isUsurpedLifeMedalActive,
              loadout.selectedActiveRelicID == MPCChapterOneCatalog.usurpedLifeMedalRelicID,
              ((MPCChapterOneCatalog.mission(forEncounterID: encounter.id)?.number ?? 0) >= 5 || isChurchCombat || campaignPrototype != nil),
              now >= usurpedLifeMedalReadyAt, masqueradeCharges == 0 else { return false }
        combatHasBegun = true
        usurpedLifeMedalActivationID = UUID()
        usurpedLifeMedalExpiresAt = now + Self.usurpedLifeMedalDuration
        usurpedLifeMedalReadyAt = now + Self.usurpedLifeMedalCooldown
        playerHP = min(playerMaxHP, (playerHP * 3 + 1) / 2)
        return true
    }

    @discardableResult
    public mutating func advanceUsurpedLifeMedal(at now: TimeInterval) -> Bool {
        guard now.isFinite, let expires = usurpedLifeMedalExpiresAt,
              now >= expires || outcome != .inProgress else { return false }
        return settleUsurpedLifeMedal()
    }

    /// Shared by expiry, victory, death and native retreat. No enemy damage hooks,
    /// healing hooks, shields or percentage rescaling are involved.
    @discardableResult
    public mutating func settleUsurpedLifeMedal() -> Bool {
        guard let activation = usurpedLifeMedalActivationID else { return false }
        if playerHP > 0 { playerHP = max(1, (playerHP + 1) / 2) }
        usurpedLifeMedalActivationID = nil
        usurpedLifeMedalExpiresAt = nil
        usurpedLifeMedalSettledActivationID = activation
        playerHP = min(playerHP, playerMaxHP)
        return true
    }

    public static let ownedManualMaskCooldown: TimeInterval = 18
    public static let ownedManualMaskDuration: TimeInterval = 4
    public private(set) var ownedManualMaskExpiresAt: TimeInterval?

    @discardableResult
    public mutating func expireOwnedManualMasquerade(at now: TimeInterval) -> Bool {
        guard now.isFinite, let deadline = ownedManualMaskExpiresAt,
              now >= deadline || outcome != .inProgress else { return false }
        ownedManualMaskExpiresAt = nil
        masqueradeCharges = 0
        return true
    }

    /// Defense is independent of card damage, misrecognition and action-count cooldowns.
    /// The tenth accepted use works normally; lifetime exhaustion rejects later taps.
    public mutating func useOwnedManualMasquerade(
        targetID: String?, isOwned: Bool, lifetimeCracks: Int = 0, at now: TimeInterval
    ) throws -> MPCFoolSkillEncounterResolution? {
        _ = expireOwnedManualMasquerade(at: now)
        let isTeaching = encounter.id == "chapter01_q03_encounter" || encounter.id == "chapter01_q04_encounter"
        guard loadout.selectedActiveRelicID != MPCChapterOneCatalog.usurpedLifeMedalRelicID, loadout.selectedActiveRelicID != "relic_blank_name_card", !isUsurpedLifeMedalActive, isOwned, (lifetimeCracks < 10 || isTeaching), now.isFinite, now >= ownedManualMaskReadyAt,
              outcome == .inProgress, !playerIsDown,
              ((MPCChapterOneCatalog.mission(forEncounterID: encounter.id)?.number ?? 0) >= 3 || isChurchCombat)
        else { return nil }
        advanceQ4Clock(at: now)
        masqueradeCharges = 2
        ownedManualMaskExpiresAt = now + Self.ownedManualMaskDuration
        ownedManualMaskReadyAt = now + Self.ownedManualMaskCooldown
        return .init(skillID: .maskedWhisper, damage: 0, targetID: nil, targets: [])
    }

    public mutating func setContinuousSkillSequence(_ skills: [FoolSkillID]) {
        var seen = Set<FoolSkillID>()
        let next = Array(skills.filter { $0 != .namelessStage && seen.insert($0).inserted }.prefix(4))
        if loadout.normalSkillIDs != next { orderedLastDispatched = nil }
        loadout.normalSkillIDs = next
    }

    /// Lands a cast on the realtime clock: callers (App loop, story/church steppers) own the
    /// 7 s card cooldowns. The turn-based manual card mode was removed (2026-10-15, user: 手动出牌模式删掉).
    @discardableResult
    public mutating func useFoolSkill(
        _ skillID: FoolSkillID,
        targetID: String?,
        sealedByPaperweight: Bool? = nil
    ) throws -> MPCFoolSkillEncounterResolution {
        combatHasBegun = true
        activeDamageSource = skillID.rawValue
        defer { activeDamageSource = "other" }
        guard outcome == .inProgress else { throw MPCEncounterRuntimeError.encounterFinished }
        guard !playerIsDown else { throw MPCEncounterRuntimeError.playerDown }
        guard loadout.battleSkillIDs.contains(skillID) else {
            throw MPCEncounterRuntimeError.skillNotEquipped(skillID)
        }
        // A card already on its way when the name seal fell still lands; the loop skips it next.
        foolSkillCastAt[skillID] = relicClock
        if (sealedByPaperweight ?? willSealPreparedSkill(skillID, at: relicClock)),
           loadout.relicIDs.contains("relic_sealed_paperweight"), relicClock >= sequenceNineRelics.paperweightReadyAt {
            orderedPrepared = nil
            sequenceNineRelics.establishPaperweight(baseHP: playerBaseMaxHP, at: relicClock)
            foolCooldowns.currentPlayerActionIndex += 1
            foolCooldowns.startCooldown(skillID, reuseDelayActions: reuseDelay(for: skillID))
            updateHeldReadySkills(used: skillID)
            triggeredEffects.append("缄卷镇纸：封存第3槽，护层建立")
            return .init(skillID: skillID, damage: 0, targetID: targetID)
        }
        if skillID.isOrderedOrdinary {
            return try resolveOrderedFirstImpact(skillID, targetID: targetID)
        }
        defer { talentLastSkill = skillID }
        let clockSpurBoost = loadout.relicIDs.contains("relic_clock_chaser_spur")
            && readySkillHeldActions[skillID, default: 0] >= 2

        let result: MPCFoolSkillEncounterResolution
        var calculationDetail = "效果技能；最终伤害0"
        switch skillID {
        case .paperDouble:
            paperDoubleCounterCharges = 1
            behaviorTags.insert(.defensiveResponse)
            applyBossActionCategory(.protection)
            result = .init(skillID: skillID, damage: 0, targetID: nil)
            calculationDetail = "召唤纸偶；本回合首次针对玩家的直接攻击由纸偶承受；回合结束消失；最终伤害0"
        case .namelessStage:
            guard !foolUltimateUsed else { throw FoolBattleError.ultimateAlreadyUsed }
            let hasSeal = loadout.relicIDs.contains("relic_nameless_seal")
            for id in foolStates.keys {
                foolStates[id]?.illusionStacks = hasSeal ? 2 : 4
                foolStates[id]?.illusionExpiresAt = relicClock + MPCOrderedSkillRules.markDuration
                foolStates[id]?.finaleReady = false
            }
            sealConversionReady = hasSeal
            foolUltimateUsed = true
            applyBossActionCategory(.setup)
            result = .init(skillID: skillID, damage: 0, targetID: nil)
            calculationDetail = "全体\(hasSeal ? 2 : 4)层误认并准备归谬；最终伤害0"
        case .maskedWhisper:
            // Retired card (now the ownerless-mask relic); old loadouts and fixtures may still cast it.
            let id = try validatedTargetID(targetID)
            let state = foolStates[id] ?? .init(targetDefense: enemies.first(where: { $0.id == id })?.defense ?? 20)
            var calculationState = state
            if isUsurpedLifeMedalActive { calculationState.attack = calculationState.attack * 130 / 100 }
            let monoclePiercesArmor = loadout.relicIDs.contains("relic_cracked_monocle")
                && state.illusionStacks == 4
            if monoclePiercesArmor {
                calculationState.targetDefense = state.targetDefense * 95 / 100
            }
            calculationState.targetDefense = talentDefense(calculationState.targetDefense, skill: skillID, stacks: state.illusionStacks)
            let resolution = try FoolComboSimulator.resolve(skillID: skillID, from: calculationState)
            var persistentResolutionState = resolution.state
            persistentResolutionState.attack = state.attack
            persistentResolutionState.targetDefense = state.targetDefense
            foolStates[id] = persistentResolutionState
            masqueradeCharges = 2
            if loadout.talents.has("phantom.0") { playerShield = min(playerMaxHP, playerShield + strengthenedSkillAmount(30, skill: skillID)) }
            if loadout.talents.has("phantom.4") { talentMaskReady = true }
            triggeredEffects.append("假面：幻影承接接下来的两次敌方攻击；再次施放刷新为两次，不叠加")
            if loadout.passiveIDs.contains("fool_passive_02"), unreliableNarratorTriggeredRound != round {
                var passiveState = foolStates[id] ?? resolution.state
                passiveState.illusionStacks = min(4, passiveState.illusionStacks + 1)
                foolStates[id] = passiveState
                unreliableNarratorTriggeredRound = round
                triggeredEffects.append("不可靠叙述者：额外1层误认，本回合承伤增加5%")
            }
            if enhancedSetupStacks > 0 {
                var enhancedState = foolStates[id] ?? resolution.state
                enhancedState.illusionStacks = min(4, enhancedState.illusionStacks + enhancedSetupStacks)
                foolStates[id] = enhancedState
                triggeredEffects.append("强化铺垫：额外施加\(enhancedSetupStacks)层误认")
                enhancedSetupStacks = 0
            }
            var damage = resolution.totalDamage
            var modifiers: [String] = []
            if loadout.relicIDs.contains("relic_cracked_monocle") {
                if monoclePiercesArmor {
                    modifiers.append("裂纹单镜：有效防御\(calculationState.targetDefense)")
                } else {
                    damage = damage * 97 / 100
                    modifiers.append("裂纹单镜×97%")
                }
            }
            if lateApplauseReady, resolution.damageHits.count == 1 {
                damage = damage * 110 / 100
                modifiers.append("迟到的掌声×110%")
                lateApplauseReady = false
                triggeredEffects.append("迟到的掌声：单段伤害提高10%")
            }
            if unifiedGearDamageReady, damage > 0 {
                damage = damage * 120 / 100
                modifiers.append("三证环×120%")
                unifiedGearDamageReady = false
            }
            if clockSpurBoost {
                damage = damage * 115 / 100
                modifiers.append("追钟人断刺×115%")
                triggeredEffects.append("追钟人断刺：保留技能伤害提高15%")
            }
            if loadout.relicIDs.contains("relic_thirteenth_record"), round.isMultiple(of: 3) {
                damage = damage * 95 / 100
                modifiers.append("第十三声录片×95%")
            }
            damage = talentDamage(damage, skill: skillID, stacks: state.illusionStacks, targetID: id)
            damage = strengthenedSkillAmount(damage, skill: skillID)
            if loadout.skillLevel(for: skillID) > 1 {
                modifiers.append("技能Lv.\(loadout.skillLevel(for: skillID))×\(MPCSkillGrowth.multiplierBasisPoints(for: loadout.skillLevel(for: skillID)) / 100)%")
            }
            if damage > 0, state.illusionStacks > 0, loadout.talents.has("omen.2") { playerShield = min(playerMaxHP, playerShield + strengthenedSkillAmount(15, skill: skillID)) }
            damage = try applyPartyDamage(damage, to: id, category: actionCategory(for: skillID))
            if damage > 0 {
                talentDamageCount += 1
                talentLastDamageSkill = skillID
                talentEchoReady = false
                talentFinalEchoReady = false
                talentMaskReady = false
                talentEvidenceReady = false
            }
            result = .init(skillID: skillID, damage: damage, targetID: id)
            let hits = resolution.damageHits.map(String.init).joined(separator: "+")
            let modifierText = modifiers.isEmpty ? "无额外倍率" : modifiers.joined(separator: "，")
            calculationDetail = "防御\(state.targetDefense)；基础命中[\(hits)]；\(modifierText)；最终伤害\(damage)"
        default:
            throw FoolComboError.unsupportedSkill(skillID)
        }
        borrowedSecondAvailable = false
        foolCooldowns.currentPlayerActionIndex += 1
        foolCooldowns.startCooldown(
            skillID,
            reuseDelayActions: reuseDelay(for: skillID)
        )
        updateHeldReadySkills(used: skillID)
        recordPlayerSkill(skillID, targetID: result.targetID)
        let targetText = result.targetID.map { " → \($0)" } ?? ""
        let stateText = result.targetID.flatMap { foolStates[$0] }.map {
            "；结算后误认\($0.illusionStacks)/错位\($0.misalignmentStacks)/归谬\($0.finaleReady ? "是" : "否")"
        } ?? ""
        log.append(.init(
            round: round,
            message: "玩家 \(skillID.rawValue)\(targetText)：\(calculationDetail)\(stateText)",
            damageTaken: 0,
            bossMechanicMissed: false
        ))
        return result
    }

    public mutating func useConsumable(_ itemID: String) throws {
        guard outcome == .inProgress else { throw MPCEncounterRuntimeError.encounterFinished }
        guard !playerIsDown else { throw MPCEncounterRuntimeError.playerDown }
        guard MPCChapterOneCatalog.items.contains(where: { $0.id == itemID && $0.kind == .consumable }) else {
            throw MPCEncounterRuntimeError.unknownConsumable
        }
        guard consumables[itemID, default: 0] > 0 else { throw MPCEncounterRuntimeError.noConsumableRemaining }
        switch itemID {
        case "consumable_salt_tea", "consumable_pain_salve":
            guard playerHP < playerMaxHP, relicClock >= sequenceNineRelics.healingBlockedUntil else { throw MPCEncounterRuntimeError.noHealingNeeded }
            receivePlayerHealing(playerMaxHP * (itemID == "consumable_pain_salve" ? 25 : 20) / 100)
        case "consumable_mirror_salve":
            grantPlayerShield(100)
        case "consumable_clock_key":
            triggeredEffects.append("校时钥：自动序列会跳过冷却中的卡牌")
        default: throw MPCEncounterRuntimeError.unknownConsumable
        }
        consumables[itemID, default: 0] -= 1
    }

    /// A restarted battle must not restore items already spent in the saved inventory.
    public mutating func limitConsumables(to inventory: [String: Int]) {
        for id in Array(consumables.keys) {
            consumables[id] = min(consumables[id, default: 0], max(0, inventory[id, default: 0]))
        }
    }

    @discardableResult
    public mutating func performCompanionActions(focusTargetID: String? = nil) -> [MPCCompanionActionResolution] {
        lastCompanionActions.removeAll()
        guard outcome == .inProgress, !activeCompanionIDs.isEmpty else { return [] }
        let playerID = Self.partyPlayerUnitID
        let partyBoss = isPartyBossEncounter
        var units = [MPCPartyUnitState(
            id: playerID, side: .party, hp: playerHP, maxHP: playerMaxHP, shield: playerShield,
            hasCleansableStatus: partyBoss && !sealedFoolSkillIDs(at: relicClock).isEmpty
        )]
        units += activeCompanionIDs.map {
            MPCPartyUnitState(id: $0, side: .party, hp: allyHP[$0, default: 0], maxHP: allyMaxHP[$0, default: 800],
                              hasCleansableStatus: partyBoss && isAllySealed($0))
        }
        units += enemies.filter(\.isAlive).map { enemy in
            let content = MPCChapterOneCatalog.enemies.first(where: { $0.id == enemy.contentID })
            return MPCPartyUnitState(
                id: enemy.id, side: .enemy, hp: enemy.hp, maxHP: enemy.maxHP,
                isInvulnerable: isTrueImmune(enemy) || isProtectedSovereign(enemy),
                isBoss: content?.rank == .boss, isElite: content?.rank == .elite
            )
        }
        let state = MPCPartyBattleState(
            playerUnitID: playerID,
            units: units,
            tacticMode: tacticMode,
            // Party fights: the revive is the healer's timed channel, not a planned action.
            sharedReviveCharges: partyBoss ? 0 : sharedReviveCharges,
            focusTargetUnitID: focusTargetID,
            enemyIntent: knownEnemyIntent(playerID: playerID)
        )
        // Party fights: each standing ally acts on its own cadence, not on every player hit.
        // The healer channelling the hero's revive does nothing else.
        let ready = activeCompanionIDs.filter { !partyBoss || (isAllyStanding($0) && relicClock >= allyReadyAt[$0, default: 0]
                                                               && !(heroReviveAt != nil && $0 == revivingHealerID)) }
        let candidates = Dictionary(uniqueKeysWithValues: ready.map { id in
            (id, companionCandidates(for: id, playerID: playerID))
        })
        // An ally with nothing legal to do (a sealed protector facing Q28's untouchable body)
        // must not keep the other from acting.
        let actors = partyBoss ? ready.filter { !MPCPartyAIPlanner.legalCandidates(candidates[$0, default: []], state: state).isEmpty } : ready
        guard !actors.isEmpty, let plan = MPCPartyAIPlanner.chooseActions(
            state: state, candidatesByActor: candidates, actorOrder: actors
        ) else { return [] }
        if partyBoss {
            for id in actors { allyReadyAt[id] = relicClock + Double(MPCProgressionWalls.partyAllyActionTenths) / 10 }
        }
        let resolved = plan.actions.compactMap { action in
            applyCompanionAction(action, playerID: playerID)
        }
        lastCompanionActions = resolved
        return resolved
    }

    /// Q28/Q29: outside authority absorbs every hit on the sovereign's body.
    private func isProtectedSovereign(_ enemy: MPCRuntimeEnemy) -> Bool {
        [28, 29].contains(chapterMissionNumber) && enemy.contentID == "boss_chronarch_sovereign"
    }

    /// What the allies plan against: in party fights the sovereign's real next action, its
    /// target and the blow the hero would take after armour (same rules as `endRound`).
    private func knownEnemyIntent(playerID: String) -> MPCKnownEnemyIntent {
        if isPartyBossEncounter, let boss = enemies.first(where: { $0.contentID == "boss_chronarch_sovereign" && $0.isAlive }) {
            let intent = boss.currentIntent
            if intent == "name_seal", let target = nameSealTarget()?.id, target != playerID {
                return MPCKnownEnemyIntent(targetUnitID: target, expectedDamage: allyMaxHP[target, default: 0] * MPCProgressionWalls.q30SealHealthPercent / 100)
            }
            // A fallen hero's blows land on the stand-in at the same share of its health.
            if playerHP <= 0, let standIn = heroStandInID {
                return MPCKnownEnemyIntent(targetUnitID: standIn, expectedDamage: sovereignBlow(boss, intent: intent) * allyMaxHP[standIn, default: 0] / max(1, playerBaseMaxHP))
            }
            return MPCKnownEnemyIntent(targetUnitID: playerID, expectedDamage: heroBlowAfterArmour(sovereignBlow(boss, intent: intent)))
        }
        let intentDamage = enemies.filter(\.isAlive).map(\.attack).max() ?? 0
        return MPCKnownEnemyIntent(targetUnitID: playerID, expectedDamage: intentDamage)
    }

    private func heroBlowAfterArmour(_ damage: Int) -> Int {
        damage * (10_000 - loadout.churchGear.damageReductionBP - loadout.outfitBonus.damageReductionBP) / 10_000
    }

    /// Companion hits obey the same protection as the player's (true immunity, gift shields,
    /// the Q28/Q29 sovereign's outside authority, objectives) but fire no player relic,
    /// talent or gear bonus.
    @discardableResult
    private mutating func applyCompanionDamage(_ damage: Int, to enemyID: String, companionID: String) -> Int {
        let source = activeDamageSource
        activeDamageSource = companionID
        resolvingCompanionDamage = true
        defer { activeDamageSource = source; resolvingCompanionDamage = false }
        return (try? applyPartyDamage(damage, to: enemyID)) ?? 0
    }

    @discardableResult
    public mutating func applyPartyDamage(
        _ damage: Int,
        to enemyID: String,
        category: MPCPlayerActionCategory = .damage,
        isBasicAttack: Bool = false,
        defenseIgnoreBP: Int = 0
    ) throws -> Int {
        guard outcome == .inProgress else { throw MPCEncounterRuntimeError.encounterFinished }
        guard let index = enemies.firstIndex(where: { $0.id == enemyID && $0.isAlive }) else {
            throw MPCEncounterRuntimeError.invalidTarget
        }
        // The visible Q6 ward blocks all damage; status/control rules remain separate.
        if isTrueImmune(enemies[index]) { return 0 }
        // The blank card pairs the hero and one enemy; an ally is a third party.
        if !resolvingCompanionDamage, sequenceNineRelics.blankCardBlocks(enemyID, at: relicClock) { return 0 }
        let defenseIntents = ["guard", "fortify", "calibrate", "架起防御"]
        var brokeDefense = false
        if !resolvingDeferredDamage, !resolvingCompanionDamage, loadout.bountyRelicID == MPCBountyRelicCatalog.brokenSword,
           enemyDefenseBoosts[enemyID] != nil || q12FortifyStacks[enemyID, default: 0] > 0
            || defenseIntents.contains(enemies[index].currentIntent),
           relicClock >= brokenSwordReadyAt[enemyID, default: 0] {
            brokenSwordReadyAt[enemyID] = relicClock + MPCProgressionWalls.brokenSwordCooldown
            q12FortifyStacks.removeValue(forKey: enemyID)
            if enemyDefenseBoosts.removeValue(forKey: enemyID) != nil { foolStates[enemyID]?.targetDefense = enemies[index].defense }
            brokeDefense = true
            triggeredEffects.append("七号缺齿剑：打破防御")
        }
        let guarded = !brokeDefense && !resolvingDeferredDamage && isBasicAttack && defenseIntents.contains(enemies[index].currentIntent)
        let clampedDefenseIgnore = min(10_000, max(0, defenseIgnoreBP))
        let effectiveReductionBP = guarded
            ? (encounter.id == "chapter01_q06_encounter" ? 7_500 : 5_000) * (10_000 - clampedDefenseIgnore) / 10_000
            : 0
        let defenseAdjustedDamage = isBasicAttack
            ? basicDamageAfterTemporaryDefenseBoost(
                max(0, damage),
                targetID: enemyID,
                enemy: enemies[index]
            )
            : max(0, damage)
        var finalDamage = defenseAdjustedDamage * (10_000 - effectiveReductionBP) / 10_000
        if !resolvingDeferredDamage,
           (isBasicAttack || FoolSkillID(rawValue: activeDamageSource) != nil) {
            finalDamage = finalDamage * (10_000 + loadout.churchGear.attackBP + loadout.outfitBonus.attackBP) / 10_000
        }
        // 灯芯长明 (Q30 离场祝福): the hero's own hits only, counted once before any deferral.
        if !resolvingDeferredDamage, !resolvingCompanionDamage, farewellBlessings?.hero == .lampWick,
           enemies[index].contentID == "boss_chronarch_sovereign" {
            finalDamage = finalDamage * (100 + MPCProgressionWalls.q30LampWickPercent) / 100
        }
        if !resolvingDeferredDamage, chapterMissionNumber == 12, let stacks = q12FortifyStacks[enemyID], stacks > 0 {
            let cut = min(MPCProgressionWalls.q12FortifyMaxPercent, stacks * MPCProgressionWalls.q12FortifyStackPercent)
            finalDamage = finalDamage * (100 - cut) / 100
        }
        if !resolvingDeferredDamage, (enemies[index].contentID == "bounty_b06_dark_hold_captain" || MPCChurchTowerCatalog.isShieldJaw(enemies[index].contentID) || enemies[index].contentID == "enemy_archive_gatekeeper"), enemies[index].currentIntent == "recover" {
            finalDamage = finalDamage * 175 / 100
        }
        if !resolvingDeferredDamage, enemies[index].contentID == "bounty_b09_contract_eater", enemies[index].currentIntent == "recover" {
            finalDamage = finalDamage * 150 / 100
        }
        if !resolvingDeferredDamage, chapterMissionNumber == 4, enemies[index].contentID == "enemy_clockwork_hound" {
            finalDamage = finalDamage * (isCounterActive ? 250 : 25) / 100
        } else if !resolvingDeferredDamage, isCounterActive, !resolvingCompanionDamage {
            finalDamage = finalDamage * 150 / 100
        }
        if encounter.id == "chapter01_q06_encounter", enemies[index].contentID == "enemy_clockwork_hound",
           houndOpeningReady, finalDamage > 0, !resolvingCompanionDamage {
            finalDamage = finalDamage * 150 / 100
            houndOpeningReady = false
            triggeredEffects.append("追名破绽：本次伤害提高50%，破绽消退")
        }

        if !resolvingDeferredDamage, !isBasicAttack,
           FoolSkillID(rawValue: activeDamageSource) != nil,
           loadout.relicIDs.contains("relic_deferred_stamp"),
           sequenceNineRelics.deferSkillDamage(finalDamage, targetID: enemyID, baseHP: playerBaseMaxHP, at: relicClock) {
            return 0
        }
        finalDamage = campaignMitigatedDamage(finalDamage, to: enemyID)
        // 黑盐外壳 (Q30 离场祝福): every source, a deferred hit when it finally lands.
        if farewellBlessings?.sovereign == .saltCrust, enemies[index].contentID == "boss_chronarch_sovereign" {
            finalDamage = finalDamage * (100 - MPCProgressionWalls.q30SaltCrustPercent) / 100
        }
        // Ordinary gift shields sit behind true immunity. Guard-phase zeroes returned above
        // cannot remove this debt, and the debt never expires merely with time.
        if [17,22].contains(chapterMissionNumber), enemies[index].currentIntent == "calibration", finalDamage > 0 {
            chapterVerificationHits += loadout.bountyRelicID == MPCBountyRelicCatalog.reverseSeal ? 2 : 1
        }
        let giftAbsorbed = min(enemyGiftShields[enemyID, default: 0], finalDamage)
        enemyGiftShields[enemyID, default: 0] -= giftAbsorbed
        finalDamage -= giftAbsorbed
        if [28,29].contains(chapterMissionNumber), enemies[index].contentID == "boss_chronarch_sovereign" {
            // A return-gift shield can still be paid down by an attack, then
            // external authority absorbs the rest. The body itself is never
            // damaged or falsely counted toward Q30.
            finalDamage = 0
        }
        if chapterMissionNumber == 26, chapterSupplyRemaining > 0 {
            let removed = min(chapterSupplyRemaining, finalDamage)
            chapterSupplyRemaining -= removed
            finalDamage -= removed
        }
        if [20,25].contains(chapterMissionNumber) {
            let validWindow = ["recover", "calibration"].contains(enemies[index].currentIntent)
            if validWindow { chapterObjectiveProgress = min(chapterObjectiveRequired, chapterObjectiveProgress + finalDamage) }
            updateChapterObjective()
            return 0 // This breaks the transport/contract, not the living body.
        }
        let campaignHealthDamage = min(enemies[index].hp, max(0, finalDamage))
        damageBySource[activeDamageSource, default: 0] += campaignHealthDamage
        enemies[index].hp = max(0, enemies[index].hp - finalDamage)
        campaignObserveDamage(to: enemyID, amount: campaignHealthDamage)
        clearDefeatedTowerEffects()
        if !enemies[index].isAlive, encoreDebtEnemyID == enemies[index].id {
            encoreDebtEnemyID = nil
        }
        splitQ2GhostIfDefeated(at: index)
        if !resolvingCompanionDamage { applyBossActionCategory(category) }
        updateBossPhaseIfNeeded()
        updateChapterObjective()
        if enemies.allSatisfy({ !$0.isAlive }) { advanceWaveOrWin() }
        return finalDamage
    }

    public mutating func grantPlayerShield(_ amount: Int) {
        playerShield = min(playerMaxHP * 4 / 10, playerShield + max(0, amount))
    }

    /// Basic attack and defense are full player actions: they advance skill
    /// cooldowns exactly like a played card. During Q1's opening probe the
    /// control seal absorbs basic damage until Sidestep Strike breaks it.
    @discardableResult
    public mutating func useBasicAction(
        _ category: MPCPlayerActionCategory,
        targetID: String? = nil
    ) throws -> Int {
        combatHasBegun = true
        activeDamageSource = "basic"
        defer { activeDamageSource = "other" }
        guard outcome == .inProgress else { throw MPCEncounterRuntimeError.encounterFinished }
        guard !playerIsDown else { throw MPCEncounterRuntimeError.playerDown }

        var damage: Int
        switch category {
        case .damage:
            let id = try validatedTargetID(targetID)
            if controlSealActive && encounter.id == "chapter01_q01_encounter" {
                applyBossActionCategory(.damage)
                damage = 0
            } else {
                let basic = chapterMissionNumber <= 3 && chapterMissionNumber > 0 ? 60 : 32
                damage = isUsurpedLifeMedalActive ? basic * 130 / 100 : basic
                if let tempo { damage = damage * tempo.basicDamagePercent / 100 }
                if loadout.relicIDs.contains("relic_reflecting_ink_mirror"), let idx = enemies.firstIndex(where: { $0.id == id }) {
                    let gift = sequenceNineRelics.offerMirrorGift(basicDamage: damage, targetID: id,
                        targetMissingHP: enemies[idx].maxHP - enemies[idx].hp,
                        targetCanTakeDamage: !isTrueImmune(enemies[idx]) && !sequenceNineRelics.blankCardBlocks(id, at: relicClock),
                        livingEnemies: enemies.filter(\.isAlive).count, baseHP: playerBaseMaxHP, at: relicClock)
                    if gift > 0 {
                        enemies[idx].hp += gift
                        relicHealingEvents.append(.init(targetID: id, damage: gift))
                        foolCooldowns.currentPlayerActionIndex += 1
                        return 0
                    }
                }
                if unifiedGearDamageReady {
                    damage = damage * 120 / 100
                    unifiedGearDamageReady = false
                }
                damage = try applyPartyDamage(
                    damage,
                    to: id,
                    category: .damage,
                    isBasicAttack: true
                )
            }
        case .protection:
            grantPlayerShield(100)
            applyBossActionCategory(.protection)
            damage = 0
        default:
            applyBossActionCategory(category)
            damage = 0
        }

        foolCooldowns.currentPlayerActionIndex += 1
        updateHeldReadySkills(used: nil)
        return damage
    }

    public mutating func endRound(response: MPCBossMechanicResponse = .none, actingEnemyID: String? = nil, at now: TimeInterval = 0, attackActionID: String? = nil) throws {
        guard outcome == .inProgress else { throw MPCEncounterRuntimeError.encounterFinished }
        _ = advanceRelicClock(at: now)
        guard outcome == .inProgress else { return }
        _ = expireOwnedManualMasquerade(at: now)
        expireEnemyDefenseBoostsBeforeEnemyTurn(actingEnemyID: actingEnemyID)
        lastEnemyActionResolutions.removeAll(keepingCapacity: true)
        lastRelicPlayerHealing = 0
        resolvingEnemyAction = true
        var damageTaken = 0
        var missedBossMechanic = false
        var correctlyAnsweredStrongAttack = false

        for index in enemies.indices where (enemies[index].isAlive || committedEnemyImpacts.contains(enemies[index].id)) && (actingEnemyID == nil || enemies[index].id == actingEnemyID) {
            if campaignPrototype != nil, outcome != .inProgress { break }
            let wasCommitted = committedEnemyImpacts.remove(enemies[index].id) != nil
            if !wasCommitted && enemies[index].delayedRounds > 0 {
                enemies[index].delayedRounds -= 1
                continue
            }
            let intent = enemies[index].currentIntent
            correctlyAnsweredStrongAttack = correctlyAnsweredStrongAttack
                || isCorrectStrongAttackResponse(enemy: enemies[index], intent: intent, response: response)
            let dispelsShield = intent == "trim_buff"
                || (intent == "calibrate" && enemies[index].contentID == "enemy_calibration_puppet")
            let removedShield = dispelsShield ? playerShield : 0
            if removedShield > 0 {
                playerShield = 0
                triggeredEffects.append("\(enemies[index].name)：裁去\(removedShield)护盾")
            }
            if removedShield > 0, loadout.relicIDs.contains("relic_trimmed_nameplate") {
                var state = foolStates[enemies[index].id] ?? .init(targetDefense: enemies[index].defense)
                state.illusionStacks = min(4, state.illusionStacks + 2)
                foolStates[enemies[index].id] = state
                healingPenaltyBP = 3_000
                triggeredEffects.append("裁去的名牌：敌方驱散触发2层误认")
            }
            let result = resolveEnemyIntent(enemy: enemies[index], intent: intent, response: response)
            let appliesEmeraldPoison = enemies[index].contentID == "enemy_emerald_revenant" && intent == "memory_breath"
            let protectionApplies = response == .protection
                && !enemyIntentIgnoresProtection(intent)
            var resolvedDamage = protectionApplies ? result.damage * 5_000 / 10_000 : result.damage
            if let tempo, resolvedDamage > 0 { resolvedDamage = max(1, resolvedDamage * tempo.authoredDamagePercent / 100) }
            clearDefeatedTowerEffects()
            if resolvedDamage > 0, var buff = towerEmpowers[enemies[index].id] {
                let cycle = enemies[index].intentIndex / max(1, enemies[index].intentPattern.count)
                if buff.activeCycle == nil { buff.activeCycle = cycle; towerEmpowers[enemies[index].id] = buff }
                if buff.activeCycle == cycle { resolvedDamage = resolvedDamage * 125 / 100 }
            }
            if encoreDebtEnemyID == enemies[index].id, resolvedDamage > 0 {
                resolvedDamage = resolvedDamage * 150 / 100
                encoreDebtEnemyID = nil
                triggeredEffects.append("余响欠账：本次攻击伤害提高50%")
            }
            missedBossMechanic = missedBossMechanic || result.missedBossMechanic
            if !appliesEmeraldPoison, !q22FailedBlowIsDue(enemies[index]), sequenceNineRelics.blankCardBlocks(enemies[index].id, at: now) { resolvedDamage = 0 }
            // Final-boss party: the seal's target, the protector's intercept, the slam on allies.
            var partyBeat = resolvePartyBossBeat(enemy: enemies[index], intent: intent, heroDamage: &resolvedDamage)
            if playerIsDown, resolvedDamage > 0 {
                // A blow meant for the fallen hero lands on the next standing ally at the same
                // share of its health; the slam has already struck every ally.
                let isSlam = enemies[index].contentID == "boss_chronarch_sovereign" && intent == "slam"
                if !isSlam, let standIn = heroStandInID {
                    partyBeat.allyDamage[standIn, default: 0] += damageAlly(standIn, resolvedDamage * allyMaxHP[standIn, default: 0] / max(1, playerBaseMaxHP))
                }
                resolvedDamage = 0
            }
            if resolvedDamage > 0, !appliesEmeraldPoison, !result.missedBossMechanic,
               chapterMissionNumber != 3, chapterMissionNumber != 4,
               masqueradeCharges == 0, paperDoubleCounterCharges == 0, freeEvasionCharges == 0,
               !enemyIntentIgnoresProtection(intent),
               loadout.outfit?.dodgesDirectHit(
                   encounterID: encounter.id,
                   enemyID: enemies[index].id,
                   intent: intent,
                   wave: waveIndex,
                   actionIndex: enemies[index].intentIndex
               ) == true {
                resolvedDamage = 0
                triggeredEffects.append("幸运：躲闪本次直接攻击")
            }
            let redirectedByMasquerade = !appliesEmeraldPoison && resolvedDamage > 0 && masqueradeCharges > 0
            let redirectedByPaperDouble = !appliesEmeraldPoison && !redirectedByMasquerade && resolvedDamage > 0
                && paperDoubleCounterCharges > 0
            if redirectedByMasquerade {
                masqueradeCharges -= 1
                if loadout.talents.has("phantom.1") { playerShield = min(playerMaxHP, playerShield + 20) }
                if loadout.talents.has("phantom.2") { talentEchoReady = true }
                if loadout.talents.has("phantom.3") { receivePlayerHealing(20) }
                if loadout.talents.has("phantom.5"), masqueradeCharges == 0 { talentFinalEchoReady = true }
                triggeredEffects.append("幻影：承接\(resolvedDamage)伤害，剩余\(masqueradeCharges)次")
            } else if redirectedByPaperDouble {
                var state = foolStates[enemies[index].id] ?? .init(targetDefense: enemies[index].defense)
                state.illusionStacks = min(4, state.illusionStacks + 2)
                foolStates[enemies[index].id] = state
                paperDoubleCounterCharges = 0
                behaviorTags.insert(.applyIllusion)
                triggeredEffects.append("纸人技能承接伤害并施加误认")
            } else {
                if appliesEmeraldPoison {
                    // This is battlefield mist, not a targeted hit. Repeated applications
                    // cannot restart its clock or reduce its accumulated intensity.
                    if !isEmeraldPoisonActive, enemies[index].isAlive, now.isFinite {
                        emeraldPoisonTicksRemaining = 1
                        emeraldPoisonIntensity = 1
                        emeraldPoisonDamagePerTick = max(1, playerBaseMaxHP * 2 / 100)
                        emeraldPoisonNextTick = now + 3
                        emeraldPoisonSourceID = enemies[index].id
                        triggeredEffects.append("翠毒漫天：毒雾持续至战斗结束，每3秒加浓，伤害逐次增加；假面留给绿焰重击")
                    }
                    resolvedDamage = 0
                }
                if ringExposurePending, resolvedDamage > 0, playerHP > 0, freeEvasionCharges == 0 {
                    resolvedDamage = resolvedDamage * 125 / 100
                    ringExposurePending = false
                    triggeredEffects.append("三证环：本次自身直接承伤提高25%，暴露消退")
                }
                if resolvedDamage > 0, freeEvasionCharges == 0 {
                    if loadout.relicIDs.contains("relic_countertide_anchor") {
                        let paired = ["enemy_codex_executor", "enemy_archive_convoy"].contains(enemies[index].contentID)
                            && [1, 2].contains(enemies[index].intentIndex % 4)
                        let authoredIndex = paired ? (enemies[index].intentIndex / 4) * 4 + 1 : enemies[index].intentIndex
                        let actionID = attackActionID ?? (enemies[index].id + ":" + String(authoredIndex))
                        resolvedDamage = sequenceNineRelics.anchorDamage(resolvedDamage, sourceID: enemies[index].id,
                            actionID: actionID, baseHP: playerBaseMaxHP, at: now)
                    }
                    if loadout.relicIDs.contains("relic_sealed_paperweight") {
                        resolvedDamage -= sequenceNineRelics.containWithPaperweight(resolvedDamage, at: now)
                    }
                    if loadout.relicIDs.contains("relic_reflecting_ink_mirror") {
                        let reflectedTarget = sequenceNineRelics.mirrorTargetID.flatMap { tid in enemies.first { $0.id == tid && $0.isAlive } }
                        if let reflected = sequenceNineRelics.reflectDirectDamage(resolvedDamage, sourceID: enemies[index].id,
                            targetIsValid: reflectedTarget.map { !isTrueImmune($0) } ?? false, baseHP: playerBaseMaxHP, at: now) {
                            // Debit only damage actually delivered to the other enemy.
                            let dealt = (try? applyPartyDamage(reflected.amount, to: reflected.target)) ?? 0
                            resolvedDamage -= min(resolvedDamage, dealt)
                            if dealt > 0 { relicDamageEvents.append(.init(targetID: reflected.target, damage: dealt)) }
                        }
                    }
                }
                // A prototype core killed by reflected damage ends combat before
                // the remainder of this contact can hurt the player.
                if campaignPrototype != nil, outcome != .inProgress { break }
                if resolvedDamage > 0, freeEvasionCharges == 0,
                   loadout.relicIDs.contains("relic_return_gift_clasp"), returnGiftClaspIsReady {
                    let contained = min(resolvedDamage, playerBaseMaxHP * 30 / 100)
                    resolvedDamage -= contained
                    enemyGiftShields[enemies[index].id, default: 0] += contained * relicBalance.giftShieldPercent / 100
                    returnGiftClaspDebtorID = enemies[index].id
                    returnGiftClaspReadyAt = now + 8
                    triggeredEffects.append("返礼银扣：收容\(contained)，返还\(contained / 2)礼盾")
                }
                resolvedDamage = resolvedDamage * (10_000 - loadout.churchGear.damageReductionBP - loadout.outfitBonus.damageReductionBP) / 10_000
                let healthBefore = playerHP
                absorbPlayerDamage(resolvedDamage)
                resolvedDamage = max(0, healthBefore - playerHP)
                damageTaken += resolvedDamage
            }
            if encounter.id == "chapter01_q04_encounter" {
                advanceQ4Clock(at: now)
                if intent == "charge" { q4FirstFlameBlocked = false }
                if intent == "q4_flame_first" { q4FirstFlameBlocked = redirectedByMasquerade }
                if intent == "q4_flame_second" {
                    if q4FirstFlameBlocked && redirectedByMasquerade {
                        q4OpeningUntil = now + MPCCombatCounter.window
                        if counter.offer(at: now) { triggeredEffects.append("双焰被承接：3秒内点击反击，刷新普通牌并重启编排") }
                    }
                    q4FirstFlameBlocked = false
                }
            }
            if chapterMissionNumber > 4, MPCCombatCounter.isHeavy(intent), !appliesEmeraldPoison,
               (redirectedByMasquerade || redirectedByPaperDouble || (response == .evasion && result.damage == 0)),
               counter.offer(at: now) {
                triggeredEffects.append("重招被化解：3秒内点击反击，刷新普通牌并重启编排")
            }
            if encounter.id == "chapter01_q06_encounter", intent == "name_hunt",
               redirectedByMasquerade || redirectedByPaperDouble {
                houndOpeningReady = true
                triggeredEffects.append("猎犬扑错名字：露出破绽，下一次命中伤害提高50%")
            }
            lastEnemyActionResolutions.append(.init(
                enemyID: enemies[index].id,
                intent: intent,
                playerDamage: (redirectedByPaperDouble || redirectedByMasquerade) ? 0 : resolvedDamage,
                redirectedByPaperDouble: redirectedByPaperDouble,
                healedTargetID: result.healedTargetID,
                healing: result.healing,
                defenseBoostBP: result.defenseBoostBP,
                allyDamage: partyBeat.allyDamage,
                interceptedBy: partyBeat.interceptedBy,
                sealedSkillID: partyBeat.sealedSkillID,
                sealedAllyID: partyBeat.sealedAllyID
            ))
            // The finite sac is spent after its first discharge. Preserve the
            // authored wind-up and cycle duration, but future releases are real salt hits.
            if intent == "tower_poison", towerPoisonSpent.contains(enemies[index].id) {
                enemies[index].intentPattern = enemies[index].intentPattern.map { $0 == "tower_poison" ? "tower_salt_spike" : $0 }
            }
            enemies[index].intentIndex += 1
            if let buff = towerEmpowers[enemies[index].id], let cycle = buff.activeCycle,
               enemies[index].intentIndex / max(1, enemies[index].intentPattern.count) > cycle { towerEmpowers.removeValue(forKey: enemies[index].id) }
            let bossCycleLength = [28,29].contains(chapterMissionNumber) ? 4 : enemies[index].intentPattern.count
            if enemies[index].contentID == "boss_chronarch_sovereign",
               enemies[index].intentIndex.isMultiple(of: bossCycleLength) {
                completedBossCycles += 1
                if loadout.bountyRelicID == MPCBountyRelicCatalog.lifeLedger, playerHP > 0 {
                    let heal = min(playerBaseMaxHP * MPCProgressionWalls.lifeLedgerCycleHealPercent / 100, max(0, playerMaxHP - playerHP))
                    if heal > 0 { playerHP += heal; triggeredEffects.append("绯月寿账签：回复\(heal)生命") }
                }
                if [28,29].contains(chapterMissionNumber), completedBossCycles >= 5 { enemies[index].hasDeparted = true }
                sovereignCycleSerial += 1
            }
            if chapterMissionNumber == 30, enemies[index].contentID == "boss_chronarch_sovereign", enemies[index].isAlive {
                swapSovereignPhaseIfNeeded(at: index)
            }
            if [17,22].contains(chapterMissionNumber), intent == "calibration" {
                chapterVerificationFailed = chapterVerificationHits < MPCProgressionWalls.verificationHitsRequired[chapterMissionNumber, default: 2]
                chapterVerificationHits = 0
            }
            if chapterMissionNumber == 19, intent == "recover" {
                emeraldPoisonIntensity = 1
                emeraldPoisonDamagePerTick = max(1, playerBaseMaxHP / 100)
            }
            if enemies[index].contentID == "enemy_emerald_revenant",
               enemies[index].currentIntent == "memory_breath",
               isEmeraldPoisonActive,
               enemies[index].intentPattern.contains("charge") {
                enemies[index].intentIndex += 1
            if let buff = towerEmpowers[enemies[index].id], let cycle = buff.activeCycle,
               enemies[index].intentIndex / max(1, enemies[index].intentPattern.count) > cycle { towerEmpowers.removeValue(forKey: enemies[index].id) }
            }
        }

        // Paper Double belongs to the authored player/enemy beat in which it
        // was played. It never leaks into a later beat when no attack lands.
        paperDoubleCounterCharges = 0

        if correctlyAnsweredStrongAttack, loadout.relicIDs.contains("relic_late_second_watch") {
            reduceLongestCooldown()
            triggeredEffects.append("迟秒怀表：正确应对后缩短冷却")
        }
        log.append(MPCEncounterLogEntry(
            round: round,
            message: damageTaken > 0 ? "敌方行动造成\(damageTaken)伤害" : "本轮敌方攻击被化解",
            damageTaken: damageTaken,
            bossMechanicMissed: missedBossMechanic
        ))

        settlePlayerDownIfNeeded()

        resolvingEnemyAction = false
        if outcome != .inProgress { clearEmeraldPoison(); finiteDamageTicks.removeAll() }
        updateChapterObjective()
        round += 1
        if bossExposedRounds > 0 { bossExposedRounds -= 1 }
        if bossPhase == .thirteenthBell { thirteenthBellCountdown = max(1, thirteenthBellCountdown - 1) }
        if outcome == .inProgress && enemies.allSatisfy({ !$0.isAlive }) { advanceWaveOrWin() }
    }

    private struct PartyBossBeat {
        var allyDamage: [String: Int] = [:]
        var interceptedBy: String?
        var sealedSkillID: FoolSkillID?
        var sealedAllyID: String?
    }

    /// The sovereign's beat against the party (Q28–Q30). 夺名代签 seals the hero's next card
    /// or holds an ally to its basic attack; an armed, standing, unsealed protector takes
    /// the thirteenth blow at a share; the slam reaches every standing ally. `heroDamage`
    /// is what is still bound for the hero's own defences.
    private mutating func resolvePartyBossBeat(enemy: MPCRuntimeEnemy, intent: String, heroDamage: inout Int) -> PartyBossBeat {
        var beat = PartyBossBeat()
        guard isPartyBossEncounter, enemy.contentID == "boss_chronarch_sovereign" else { return beat }
        // 照名之光 (Q30 离场祝福) shortens every seal, the hero's and the allies'.
        let sealTime = TimeInterval(farewellBlessings?.hero == .nameLight
                                    ? MPCProgressionWalls.q30NameLightSealSeconds : MPCProgressionWalls.partySealSeconds)
        switch intent {
        case "name_seal":
            guard let target = nameSealTarget() else { break }
            nameSealCursor = target.cursor
            if target.id == Self.partyPlayerUnitID {
                guard let skill = nextScheduledFoolSkill() else { break }
                sealedFoolSkillID = skill
                heroSealExpiresAt = relicClock + sealTime
                beat.sealedSkillID = skill
                triggeredEffects.append("夺名代签：\(skill.rawValue)被封\(Int(sealTime))秒")
            } else {
                heroDamage = 0
                beat.allyDamage[target.id] = damageAlly(target.id, allyMaxHP[target.id, default: 0] * MPCProgressionWalls.q30SealHealthPercent / 100)
                guard isAllyStanding(target.id) else { break }
                allySealExpiresAt[target.id] = relicClock + sealTime
                if armedInterceptAllyID == target.id { armedInterceptAllyID = nil }
                beat.sealedAllyID = target.id
                triggeredEffects.append("夺名代签：\(companionName(target.id))\(Int(sealTime))秒内只能普攻")
            }
        case "thirteenth_charge":
            guard heroDamage > 0, playerHP > 0, let guardID = armedInterceptAllyID, isAllyStanding(guardID), !isAllySealed(guardID) else { break }
            beat.allyDamage[guardID] = damageAlly(guardID, heroDamage * MPCProgressionWalls.partyInterceptPercent / 100)
            beat.interceptedBy = guardID
            armedInterceptAllyID = nil
            interceptUsedSerial = sovereignCycleSerial
            heroDamage = 0
            triggeredEffects.append("\(companionName(guardID))：替主角挡下第十三响")
        case "slam":
            // Q30 wall without F90-or-deeper gear: the slam takes the wall's share of each ally's health too, so the
            // shared revive cannot carry the party past it (2026-10-15: F80 won 3/168 audit lines by a revive).
            let unchecked = chapterMissionNumber == 30 && !MPCProgressionWalls.meetsTowerFloor(mission: 30, gear: loadout.churchGear)
            let percent = unchecked ? MPCProgressionWalls.towerCheckBlowHealthPercent[30, default: 100]
                : sovereignIsEnraged(enemy) ? MPCProgressionWalls.partySlamAllyEnragedPercent : MPCProgressionWalls.partySlamAllyPercent
            for id in activeCompanionIDs where isAllyStanding(id) {
                beat.allyDamage[id] = damageAlly(id, allyMaxHP[id, default: 0] * percent / 100)
            }
        default: break
        }
        return beat
    }

    /// Q30 phases by health (2026-10-10): the loop changes at the sovereign's next action,
    /// starting the new loop from its first beat; the index never runs backwards.
    private mutating func swapSovereignPhaseIfNeeded(at index: Int) {
        let phase = max(Self.q30Phase(of: enemies[index]), mistMendPhase)
        let pattern = Self.q30Pattern(phase: phase)
        guard enemies[index].intentPattern != pattern else { return }
        let count = pattern.count
        enemies[index].intentIndex = (enemies[index].intentIndex + count - 1) / count * count
        enemies[index].intentPattern = pattern
        sovereignCycleSerial += 1
        triggeredEffects.append(phase == 3 ? "瑟维安狂暴：第三阶段" : "瑟维安进入第\(phase)阶段")
        // 雾中续命 (Q30 离场祝福): one heal per new phase (a skip from one to three heals once),
        // capped at full health; the phase it was given for holds even above the health line.
        let maxHP = enemies[index].maxHP, hp = enemies[index].hp
        guard farewellBlessings?.sovereign == .mistMend, phase > max(1, mistMendPhase), hp > 0 else { return }
        mistMendPhase = phase
        let heal = min(maxHP * MPCProgressionWalls.q30MistMendPercent / 100, maxHP - hp)
        guard heal > 0 else { return }
        enemies[index].hp += heal
        triggeredEffects.append("雾中续命：瑟维安回复\(heal)生命")
    }

    /// Legacy preview callback: delivery cannot rewind a battle.
    public mutating func resolveQ5MaraIntervention() { }


    public func defeatAnalysis() -> MPCDefeatAnalysis? {
        guard outcome == .defeat else { return nil }
        let critical = log.max(by: { $0.damageTaken < $1.damageTaken }) ?? .init(round: round, message: "队伍倒地", damageTaken: 0, bossMechanicMissed: false)
        var recommendations: [String] = []
        if log.contains(where: \.bossMechanicMissed) {
            recommendations.append("为第十三声保留闪避、防护、破意志或满资源终结。")
        }
        if bossEmpowermentStacks > 0 {
            recommendations.append("轮换攻击、防护、控制和铺垫，避免连续使用同类行动。")
        }
        if recommendations.isEmpty {
            recommendations.append("根据已公布意图保留防御技能，并优先击杀最危险目标。")
        }
        return MPCDefeatAnalysis(
            criticalRound: critical.round,
            summary: "关键失败发生在第\(critical.round)回合：\(critical.message)。",
            recommendations: recommendations
        )
    }

    /// Writes back the health the party brought in. `start` adds the worn armor's health on
    /// top every battle, and the breathing bag and the medal end with the battle, so writing
    /// the live maximum would stack the armor once per victory.
    /// 羽翼庇护's extra revives are battle-only: they come off whatever is left.
    public func persistentPartyState(maxAllyHP: [String: Int] = [:]) -> MPCPartyPersistentState {
        let partyMaxHP = playerBaseMaxHP - loadout.churchGear.maxHP
        let blessedRevives = farewellBlessings?.hero == .featherShelter ? MPCProgressionWalls.q30FeatherRevives : 0
        return MPCPartyPersistentState(
            playerHP: min(playerHP, partyMaxHP),
            playerMaxHP: partyMaxHP,
            allyHP: allyHP,
            allyMaxHP: maxAllyHP,
            sharedReviveCharges: max(0, sharedReviveCharges - blessedRevives)
        )
    }

    private mutating func loadWave(_ index: Int) {
        orderedPending.removeAll(); orderedPrepared = nil
        counter.clearWindow()
        let enemyIDs = encounter.waves[index].enemyIDs
        enemyDefenseBoosts.removeAll()
        committedRepairTargets.removeAll()
        committedRepairCasters.removeAll()
        towerCommittedEmpower.removeAll()
        towerCommittedEmpowerCasters.removeAll()
        towerEmpowers.removeAll()
        enemies = enemyIDs.enumerated().compactMap { slot, contentID in
            guard let content = (MPCChapterOneCatalog.enemies.first(where: { $0.id == contentID }) ?? MPCChurchTowerCatalog.enemyDefinition(id: contentID) ?? MPCChurchBountyCatalog.enemyDefinition(id: contentID) ?? campaignPrototype?.scenario.enemy(contentID)) else { return nil }
            // The reusable hound content uses one memory-breath intent for its
            // pressure encounters. The rain-bell investigation authors a
            // separate wind-up beat followed by a pounce, so keep that
            // encounter-specific intent contract in the runtime wave state.
            let intentPattern: [String] = if chapterMissionNumber >= 16 {
                chapterThirtyIntentPattern(contentID: contentID, fallback: content.intentPattern)
            } else if encounter.id == "encounter_rain_02",
                                             contentID == "enemy_clockwork_hound" {
                ["charge", "pounce"]
            } else if encounter.id == "chapter01_q03_encounter", contentID == "enemy_clockwork_hound" {
                MPCQ3HoundTiming.intents
            } else if encounter.id == "chapter01_q04_encounter", contentID == "enemy_clockwork_hound" {
                ["q4_probe", "charge", "q4_flame_first", "q4_flame_second"]
            } else if (encounter.id == "chapter01_q06_encounter" && contentID == "enemy_archive_gatekeeper") || (chapterMissionNumber == 10 && contentID == "enemy_calibration_puppet") {
                ["guard", "archive_slam", "recover"]
            } else if encounter.id == "chapter01_q07_encounter", contentID == "enemy_memory_leech_node" {
                ["repair_guard", "memory_strike"]
            } else if encounter.id == "chapter01_q07_encounter", contentID == "enemy_hollow_clockmaker" {
                ["strike", "strike"]
            } else if encounter.id == "chapter01_q08_encounter", contentID == "enemy_memory_leech" {
                ["parasite", "parasite", "parasite", "charge", "name_devour"]
            } else if ["chapter01_q09_encounter", "chapter01_q12_encounter", "chapter01_q14_encounter"].contains(encounter.id), contentID == "enemy_calibration_puppet" {
                ["fortify", "slam", "calibrate", "slam"]
            } else if encounter.id == "chapter01_q13_encounter", contentID == "elite_clock_chaser" {
                ["fortify", "thirteenth_charge", "strike", "recover"]
            } else if ["chapter01_q09_encounter", "chapter01_q13_encounter", "chapter01_q15_encounter"].contains(encounter.id), contentID == "enemy_memory_leech_node" {
                ["repair_guard", "memory_strike"]
            } else if encounter.id == "chapter01_q15_encounter", contentID == "enemy_hollow_clockmaker" {
                ["strike", "guard", "slam"]
            } else if encounter.id == "chapter01_q03_encounter",
                      contentID == "enemy_hollow_clockmaker" {
                // Q3 is the rear-support lesson. Keep the front guard on
                // readable attacks while the memory core demonstrates its
                // own pressure; defensive posture is introduced later.
                ["strike", "strike"]
            } else if encounter.id == "chapter01_q03_encounter",
                      contentID == "enemy_memory_leech_node" {
                // Do not let the first Q3 demonstration heal the front unit
                // before the player has seen the core attack twice.
                ["parasite", "memory_strike"]
            } else if encounter.id == "chapter01_q19_encounter", contentID == "elite_clock_chaser" {
                // The execution pair alternate preparation and correction.
                // Each actor advances its own intent only on its own contact.
                ["calibration", "strike"]
            } else {
                content.intentPattern
            }
            let localHP: Int = switch encounter.id {
            case "chapter01_q03_encounter": MPCProgressionWalls.q3HoundHP
            case "chapter01_q05_encounter": 950
            case "chapter01_q04_encounter": 2200
            case "chapter01_q06_encounter": 1500
            case "chapter01_q07_encounter": 650
            case "chapter01_q08_encounter": MPCProgressionWalls.q8LeechHP
            case "chapter01_q09_encounter": contentID == "enemy_memory_leech_node" ? 850 : 1300
            case "chapter01_q10_encounter": contentID == "enemy_clockwork_hound" ? MPCProgressionWalls.q10HoundHP : MPCProgressionWalls.q10PuppetHP
            case "chapter01_q11_encounter": contentID == "enemy_memory_leech" ? 1050 : 900
            case "chapter01_q12_encounter": MPCProgressionWalls.q12PuppetHP
            case "chapter01_q18_encounter": MPCProgressionWalls.q18AdjudicatorHP
            case "chapter01_q13_encounter": contentID == "enemy_memory_leech_node" ? 750 : 1800
            case "chapter01_q14_encounter": contentID == "enemy_memory_leech" ? 1200 : 1600
            case "chapter01_q15_encounter": contentID == "enemy_memory_leech_node" ? 700 : 1800
            case "chapter01_q16_encounter": 2100
            case "chapter01_q21_encounter": contentID == "enemy_memory_leech_node" ? 850 : 2200
            case "chapter01_q22_encounter": MPCProgressionWalls.q22ClockmakerHP
            case "chapter01_q26_encounter": contentID == "enemy_archive_convoy" ? MPCProgressionWalls.q26ConvoyHP : content.maxHP
            case "chapter01_q24_encounter": contentID == "enemy_clockwork_hound" ? 2000 : 900
            case "chapter01_q27_encounter": contentID == "enemy_archive_gatekeeper" ? 2200 : 1800
            case "chapter01_q29_encounter": contentID == "boss_chronarch_sovereign" ? content.maxHP : contentID == "enemy_codex_executor" ? 1800 : 900
            case "chapter01_q30_encounter": contentID == "boss_chronarch_sovereign" ? MPCProgressionWalls.q30SovereignHP : content.maxHP
            default: content.maxHP
            }
            let localAttack: Int = switch encounter.id {
            case "chapter01_q03_encounter": 110
            case "chapter01_q06_encounter": 200
            case "chapter01_q07_encounter": contentID == "enemy_memory_leech_node" ? 70 : 65
            case "chapter01_q08_encounter": MPCProgressionWalls.q8LeechAttack
            case "chapter01_q09_encounter": contentID == "enemy_memory_leech_node" ? 100 : 120
            case "chapter01_q10_encounter": contentID == "enemy_clockwork_hound" ? 88 : 105
            case "chapter01_q11_encounter": contentID == "enemy_memory_leech" ? 76 : 100
            case "chapter01_q12_encounter": MPCProgressionWalls.q12PuppetAttack
            case "chapter01_q18_encounter": MPCProgressionWalls.q18AdjudicatorAttack
            case "chapter01_q26_encounter": contentID == "enemy_archive_convoy" ? MPCProgressionWalls.q26ConvoyAttack : content.attack
            case "chapter01_q13_encounter": contentID == "enemy_memory_leech_node" ? 100 : 130
            case "chapter01_q14_encounter": contentID == "enemy_memory_leech" ? 90 : 115
            case "chapter01_q15_encounter": contentID == "enemy_memory_leech_node" ? 90 : 120
            case "chapter01_q27_encounter": contentID == "enemy_archive_gatekeeper" ? 200 : content.attack
            case "chapter01_q29_encounter": contentID == "enemy_codex_executor" ? 75 : contentID == "enemy_hollow_clockmaker" ? 40 : content.attack
            default: content.attack
            }
            return MPCRuntimeEnemy(
                id: "\(contentID)#\(slot)", contentID: contentID, name: MPCChapterOneBattleIdentity.presentationName(contentID: contentID, encounterID: encounter.id, fallback: content.name),
                maxHP: localHP, hp: localHP, attack: localAttack, defense: content.defense,
                intentPattern: intentPattern,
                intentIndex: encounter.id == "chapter01_q19_encounter" ? slot % 2
                    : encounter.id == "chapter01_q12_encounter" ? slot * 2
                    : encounter.id == "chapter01_q15_encounter" && contentID == "enemy_memory_leech_node" ? slot % 2 : 0,
                delayedRounds: 0
            )
        }
        if [2,24].contains(chapterMissionNumber) {
            // Reserve stable visual slots before either parent dies. Dormant slots
            // are neither targetable nor part of the skill/status state.
            enemies += (0..<(chapterMissionNumber == 24 ? 2 : 4)).map { slot in
                MPCRuntimeEnemy(id: "enemy_resonant_clock_guard_q2_split#\(slot)",
                    contentID: "enemy_resonant_clock_guard_q2_split", name: "赤怨幽灵",
                    maxHP: encounter.id == "chapter01_q02_encounter" ? 150 : 260, hp: 0, attack: MPCChapterOneCatalog.enemies.first { $0.id == "enemy_resonant_clock_guard_q2_split" }?.attack ?? 32, defense: 12,
                    intentPattern: ["strike", "strike"], intentIndex: 0, delayedRounds: 0)
            }
        }
        foolStates = Dictionary(uniqueKeysWithValues: enemies.filter(\.isAlive).map {
            ($0.id, FoolComboState(targetDefense: $0.defense))
        })
        if chapterMissionNumber == 12, MPCProgressionWalls.q12OpeningFortifyStacks > 0 {
            for enemy in enemies where enemy.contentID == "enemy_calibration_puppet" { q12FortifyStacks[enemy.id] = MPCProgressionWalls.q12OpeningFortifyStacks }
        }
    }

    private mutating func splitQ2GhostIfDefeated(at index: Int) {
        guard [2,24].contains(chapterMissionNumber),
              enemies[index].contentID == "enemy_resonant_clock_guard_q2",
              !enemies[index].isAlive else { return }
        // This is called only after damaging a living parent. Children have a
        // separate content identity and can never recursively split.
        let parentSlot = chapterMissionNumber == 24 ? 0 : index
        for slot in (parentSlot * 2)..<(parentSlot * 2 + 2) {
            guard let child = enemies.firstIndex(where: { $0.id == "enemy_resonant_clock_guard_q2_split#\(slot)" }) else { continue }
            enemies[child].hp = enemies[child].maxHP
            foolStates[enemies[child].id] = FoolComboState(targetDefense: enemies[child].defense)
        }
        triggeredEffects.append("雾都幽灵分裂为两只赤怨幽灵，攻击速度加快")
    }

    private func validatedTargetID(_ targetID: String?) throws -> String {
        guard let targetID, enemies.contains(where: { $0.id == targetID && $0.isAlive }) else {
            throw MPCEncounterRuntimeError.invalidTarget
        }
        return targetID
    }

    private func actionCategory(for skillID: FoolSkillID) -> MPCPlayerActionCategory {
        switch skillID {
        case .identityDisplacement: .control
        case .maskedWhisper, .fabricatedEvidence: .setup
        case .paperDouble: .protection
        case .turnTheTables, .backstageChange: .utility
        default: .damage
        }
    }

    private func reuseDelay(for skillID: FoolSkillID) -> Int {
        switch skillID {
        case .sidestepStrike: 1
        case .maskedWhisper, .fabricatedEvidence, .mirrorPursuit: 2
        case .paperDouble, .identityDisplacement: 3
        case .turnTheTables: 4
        case .absurdFinale, .backstageChange: 5
        case .namelessStage: 0
        case .stolenTempo, .mirrorBarrage, .delayedSignature: 3
        }
    }

    private func companionCandidates(for companionID: String, playerID: String) -> [MPCAIActionCandidate] {
        guard let companion = MPCChapterOneCatalog.companions.first(where: { $0.id == companionID }) else { return [] }
        var candidates = enemies.filter(\.isAlive).enumerated().map { slot, enemy in
            MPCAIActionCandidate(
                actorUnitID: companionID,
                skillID: companion.role == .construct ? companion.normalSkillIDs[1]
                    : companion.role == .healer ? companion.normalSkillIDs[2]
                    : companion.normalSkillIDs[isPartyBossEncounter ? 1 : 0],
                skillPriority: 10,
                targetUnitID: enemy.id,
                targetSlot: slot,
                kind: .damage,
                magnitude: companion.role == .construct ? 120 : (companion.role == .healer ? 65 : 80),
                supportsPlayerCombo: companion.role == .construct
            )
        }
        if isPartyBossEncounter {
            // 夺名代签 holds a sealed ally to its basic attack.
            guard !isAllySealed(companionID) else { return candidates }
            let party = [playerID] + activeCompanionIDs.filter(isAllyStanding)
            switch companion.role {
            case .protector:
                // The intercept is armed only against the sovereign's announced thirteenth
                // blow, once per loop; otherwise the lantern guards when nothing can be hit.
                if playerHP > 0, armedInterceptAllyID == nil, interceptUsedSerial != sovereignCycleSerial,
                   let boss = enemies.first(where: { $0.contentID == "boss_chronarch_sovereign" && $0.isAlive }),
                   boss.currentIntent == "thirteenth_charge" {
                    let blow = heroBlowAfterArmour(sovereignBlow(boss, intent: "thirteenth_charge"))
                    candidates.append(.init(actorUnitID: companionID, skillID: companion.normalSkillIDs[2], skillPriority: 1,
                                            targetUnitID: playerID, kind: .protect, magnitude: blow, preventsKnownDamage: blow))
                }
                candidates.append(.init(actorUnitID: companionID, skillID: companion.normalSkillIDs[0], skillPriority: 2,
                                        targetUnitID: playerID, kind: .shield, magnitude: MPCProgressionWalls.partyGuardShield))
            case .healer:
                for (slot, id) in party.enumerated() {
                    if relicClock >= mendReadyAt[companionID, default: 0] {
                        candidates.append(.init(actorUnitID: companionID, skillID: companion.normalSkillIDs[0], skillPriority: 1,
                                                targetUnitID: id, targetSlot: slot, kind: .heal, magnitude: MPCProgressionWalls.partyHealAmount))
                    }
                    let sealed = id == playerID ? !sealedFoolSkillIDs(at: relicClock).isEmpty : isAllySealed(id)
                    if sealed {
                        // Lifting a seal outranks any mend (score 150 + magnitude in the planner).
                        candidates.append(.init(actorUnitID: companionID, skillID: companion.normalSkillIDs[1], skillPriority: 0,
                                                targetUnitID: id, targetSlot: slot, kind: .cleanse, magnitude: playerMaxHP))
                    }
                }
            case .construct:
                candidates.append(.init(actorUnitID: companionID, skillID: companion.normalSkillIDs[2], skillPriority: 1,
                                        targetUnitID: playerID, kind: .shield, magnitude: 100))
            }
            return candidates
        }
        switch companion.role {
        case .protector:
            candidates.append(.init(
                actorUnitID: companionID, skillID: companion.normalSkillIDs[2], skillPriority: 1,
                targetUnitID: playerID, kind: .protect, magnitude: 180, preventsKnownDamage: 180
            ))
        case .healer:
            candidates.append(.init(
                actorUnitID: companionID, skillID: companion.normalSkillIDs[0], skillPriority: 1,
                targetUnitID: playerID, kind: .heal, magnitude: 180
            ))
        case .construct:
            candidates.append(.init(
                actorUnitID: companionID, skillID: companion.normalSkillIDs[2], skillPriority: 1,
                targetUnitID: playerID, kind: .shield, magnitude: 100
            ))
        }
        return candidates
    }

    private mutating func applyCompanionAction(
        _ action: MPCAIActionCandidate,
        playerID: String
    ) -> MPCCompanionActionResolution? {
        let actorName = companionName(action.actorUnitID)
        func result(_ message: String, amount: Int = 0) -> MPCCompanionActionResolution {
            .init(companionID: action.actorUnitID, skillID: action.skillID, message: message, targetID: action.targetUnitID, amount: amount)
        }
        switch action.kind {
        case .damage:
            guard enemies.contains(where: { $0.id == action.targetUnitID && $0.isAlive }) else { return nil }
            var magnitude = action.magnitude
            if mirrorThreadBonusReady {
                magnitude += 80
                mirrorThreadBonusReady = false
                triggeredEffects.append("镜潮银线：AI追击增加80伤害")
            }
            if loadout.relicIDs.contains("relic_borrowed_bell"),
               action.actorUnitID == "ally_alchemy_construct",
               action.skillID == "ally_sunder_formula",
               borrowedBellTriggeredRound != round {
                grantPlayerShield(50)
                borrowedBellTriggeredRound = round
                triggeredEffects.append("借声铜铃：队友破甲获得50护盾")
            }
            // Through the same protection as the player's hits: the Q28/Q29 sovereign's body
            // stays untouched, guards and gift shields hold.
            let dealt = applyCompanionDamage(magnitude, to: action.targetUnitID, companionID: action.actorUnitID)
            return result("\(actorName)造成\(dealt)伤害", amount: dealt)
        case .heal where isPartyBossEncounter && action.targetUnitID != playerID:
            guard let hp = allyHP[action.targetUnitID], hp > 0 else { return nil }
            mendReadyAt[action.actorUnitID] = relicClock + Double(MPCProgressionWalls.partyHealCooldownTenths) / 10
            let restored = min(action.magnitude, max(0, allyMaxHP[action.targetUnitID, default: hp] - hp))
            allyHP[action.targetUnitID] = hp + restored
            return result("\(actorName)为\(companionName(action.targetUnitID))恢复\(restored)生命", amount: restored)
        case .heal:
            if isPartyBossEncounter { mendReadyAt[action.actorUnitID] = relicClock + Double(MPCProgressionWalls.partyHealCooldownTenths) / 10 }
            let healing = receivePlayerHealing(action.magnitude)
            return result("\(actorName)恢复\(healing)生命", amount: healing)
        case .cleanse:
            let lifted = action.targetUnitID == playerID ? clearHeroSeal() : allySealExpiresAt.removeValue(forKey: action.targetUnitID) != nil
            guard lifted else { return nil }
            triggeredEffects.append("\(actorName)：解除夺名代签")
            return result("\(actorName)解除夺名代签")
        case .protect where isPartyBossEncounter:
            armedInterceptAllyID = action.actorUnitID
            return result("\(actorName)护住主角，准备替挡第十三响")
        case .shield, .protect:
            grantPlayerShield(action.magnitude)
            return result("\(actorName)提供\(action.magnitude)护盾", amount: action.magnitude)
        default:
            return result("\(actorName)提供战术支援")
        }
    }

    private mutating func advanceWaveOrWin() {
        clearDefeatedTowerEffects()
        guard committedEnemyImpacts.isEmpty, !resolvingEnemyAction, partyStillStanding, finiteDamageTicks.isEmpty else { return }
        if [28,29].contains(chapterMissionNumber), completedBossCycles < 5 { return }
        if [20,25].contains(chapterMissionNumber), chapterObjectiveProgress < chapterObjectiveRequired { return }
        if waveIndex + 1 < encounter.waves.count {
            if isChurchCombat {
                if towerWaveReadyAt == nil { towerWaveReadyAt = relicClock + 1 }
                return
            }
            waveIndex += 1
            loadWave(waveIndex)
            round += 1
            log.append(.init(round: round, message: "下一波敌人进入战场", damageTaken: 0, bossMechanicMissed: false))
        } else {
            finishRelicBattle()
            outcome = .victory
            clearEmeraldPoison()
        }
    }

    /// The nameplate reduces the next healing event, regardless of source.
    @discardableResult
    private mutating func receivePlayerHealing(_ amount: Int) -> Int {
        guard amount > 0, relicClock >= sequenceNineRelics.healingBlockedUntil else { return 0 }
        let reduced = amount * (10_000 - healingPenaltyBP) / 10_000
        healingPenaltyBP = 0
        let restored = min(reduced, playerMaxHP - playerHP)
        playerHP += restored
        return restored
    }

    private mutating func applyBossActionCategory(_ category: MPCPlayerActionCategory) {
        if loadout.relicIDs.contains("relic_unified_gear") {
            if variedActionCategories.contains(category) {
                variedActionCategories.removeAll()
            }
            variedActionCategories.insert(category)
            if variedActionCategories.count == 3 {
                grantPlayerShield(playerMaxHP * 10 / 100)
                unifiedGearDamageReady = true
                ringExposurePending = true
                variedActionCategories.removeAll()
                triggeredEffects.append("三证环：获得10%护盾与下次伤害20%强化；下次自身直接承伤提高25%")
            }
        }
        guard bossPhase == .unifiedMoment || bossPhase == .thirteenthBell else {
            previousActionCategory = category
            return
        }
        if previousActionCategory == category { bossEmpowermentStacks += 1 }
        previousActionCategory = category
    }

    private mutating func updateBossPhaseIfNeeded() {
        guard let bossIndex = enemies.firstIndex(where: { $0.contentID == "boss_severian_unified_clock" }) else { return }
        let ratioBP = enemies[bossIndex].hp * 10_000 / enemies[bossIndex].maxHP
        if ratioBP <= 3_300 {
            bossPhase = .thirteenthBell
        } else if ratioBP <= 6_600 {
            bossPhase = .unifiedMoment
        }
    }

    private mutating func resolveEnemyIntent(
        enemy: MPCRuntimeEnemy,
        intent: String,
        response: MPCBossMechanicResponse
    ) -> MPCResolvedEnemyIntent {
        if MPCChurchBountyCatalog.enemyDefinition(id: enemy.contentID) != nil {
            switch intent {
            case "bounty_ambush": return .attack(enemy.attack * 5 / 2)
            case "bounty_knock": return .attack(enemy.attack * 7 / 4)
            case "bounty_spittle":
                if enemy.isAlive { queueFiniteDamage(source: "bounty-spittle:" + enemy.id, damage: max(1, enemy.attack / 3), ticks: 3) }
                return .attack(0)
            case "bounty_mirror", "bounty_armor":
                if intent == "bounty_armor", enemy.isAlive {
                    enemyGiftShields[enemy.id] = min(enemy.maxHP / 4, enemyGiftShields[enemy.id, default: 0] + enemy.maxHP / 5)
                    triggeredEffects.append("\(enemy.name)：歪甲裹住旧契，普通护甲可击破")
                }
                return .attack(0)
            case "bounty_true_stab": return .attack(enemy.attack * 3 / 2)
            case "bounty_rend":
                enemyGiftShields[enemy.id] = 0
                return .attack(enemy.attack * 2)
            case "bounty_veil": return .attack(enemy.attack * 9 / 5)
            case "bounty_transfer":
                guard enemy.isAlive,
                      let targetIndex = enemies.firstIndex(where: { $0.contentID == "bounty_b10_life_oracle" && $0.isAlive }),
                      enemies[targetIndex].hp < enemies[targetIndex].maxHP,
                      towerMendCasts[enemy.id, default: 0] < 3 else { return .attack(0) }
                towerMendCasts[enemy.id, default: 0] += 1
                let amount = min(enemies[targetIndex].maxHP * 8 / 100,
                                 enemies[targetIndex].maxHP - enemies[targetIndex].hp)
                let diverted = loadout.relicIDs.contains("relic_ownership_severing_needle")
                    ? sequenceNineRelics.interceptHealing(amount, recipientID: enemies[targetIndex].id, healerID: enemy.id,
                        playerMissingHP: playerMaxHP - playerHP, baseHP: playerBaseMaxHP, at: relicClock) : 0
                playerHP += diverted
                lastRelicPlayerHealing += diverted
                let restored = amount - diverted
                enemies[targetIndex].hp += restored
                triggeredEffects.append("收寿囊体：向\(enemies[targetIndex].name)转息\(restored)生命")
                return .init(damage: 0, missedBossMechanic: false,
                             healedTargetID: enemies[targetIndex].id, healing: restored)
            case "bounty_bind", "bounty_silk_bind":
                if enemy.isAlive { queueFiniteDamage(source: "bounty-poison:" + enemy.id, damage: max(1, enemy.attack / 4), ticks: intent == "bounty_bind" ? 2 : 3) }
                return .attack(enemy.attack)
            case "bounty_overwrite":
                let recent = Array(executedSkills.suffix(2))
                let repeats = recent.count == 2 && recent[0].skillID == recent[1].skillID
                return .attack(enemy.attack * (repeats ? 250 : 150) / 100)
            default: break
            }
        }
        if let tower = MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID) {
            switch intent {
            case "tower_poison":
                if enemy.isAlive, towerPoisonSpent.insert(enemy.id).inserted { queueFiniteDamage(source: "tower-poison:" + enemy.id, damage: max(1, enemy.attack / 2), ticks: 3) }
                return .attack(0)
            case "tower_mend":
                let target = repairTargetID(for: enemy.id)
                committedRepairTargets[enemy.id] = nil; committedRepairCasters.remove(enemy.id)
                guard enemy.isAlive, let idx = enemies.firstIndex(where: { $0.id == target && $0.isAlive && $0.id != enemy.id }) else { return .attack(0) }
                guard towerMendCasts[enemy.id, default: 0] < 4 else { return .attack(0) }
                towerMendCasts[enemy.id, default: 0] += 1
                let amount = tower.elite ? 80 : 60
                var transferred = 0
                if loadout.relicIDs.contains("relic_ownership_severing_needle") {
                    transferred = sequenceNineRelics.interceptHealing(amount, recipientID: enemies[idx].id, healerID: enemy.id,
                        playerMissingHP: playerMaxHP - playerHP, baseHP: playerBaseMaxHP, at: relicClock)
                    playerHP += transferred; lastRelicPlayerHealing += transferred
                }
                let restored = min(amount - transferred, enemies[idx].maxHP - enemies[idx].hp)
                enemies[idx].hp += restored
                return .init(damage: 0, missedBossMechanic: false, healedTargetID: enemies[idx].id, healing: restored)
            case "tower_empower":
                let target = towerEmpowerTargetID(for: enemy.id)
                towerCommittedEmpower[enemy.id] = nil; towerCommittedEmpowerCasters.remove(enemy.id)
                if enemy.isAlive, let target, enemies.contains(where: { $0.id == target && $0.isAlive }), towerEmpowers[target] == nil {
                    towerEmpowers[target] = TowerEmpower(sourceID: enemy.id, expiresAt: relicClock + 8, activeCycle: nil)
                }
                return .attack(0)
            case "tower_copperback_first", "tower_copperback_second", "tower_brute_first", "tower_brute_second", "tower_veil_first", "tower_veil_second", "tower_throat_first", "tower_throat_second", "tower_moonfang_first", "tower_moonfang_second": return .attack(enemy.attack)
            case "archive_slam", "tower_heavy_cut", "tower_piercing_claw", "tower_heavy_claw": return .attack(enemy.attack * 2)
            case "tower_hound_pounce", "tower_flame_first", "tower_flame_second", "tower_salt_spike", "tower_short_pounce", "tower_cut_first", "tower_cut_second", "tower_sound_arrow", "tower_tail_sweep": return .attack(enemy.attack)
            default: return .attack(0)
            }
        }
        if MPCChurchTowerCatalog.isShieldJaw(enemy.contentID) || enemy.contentID == "enemy_archive_gatekeeper" || (chapterMissionNumber == 10 && enemy.contentID == "enemy_calibration_puppet") {
            return .attack(intent == "archive_slam" ? enemy.attack * 2 : 0)
        }
        if MPCChurchTowerCatalog.isRiftHound(enemy.contentID) {
            return .attack(["tower_flame_first", "tower_flame_second"].contains(intent) ? enemy.attack : 0)
        }
        if chapterMissionNumber >= 16, let authored = resolveChapterThirtyIntent(enemy: enemy, intent: intent) { return authored }
        if intent == "repair_guard" {
            let targetID = repairTargetID(for: enemy.id)
            committedRepairTargets[enemy.id] = nil
            committedRepairCasters.remove(enemy.id)
            guard let index = enemies.firstIndex(where: { $0.id == targetID && $0.isAlive }) else { return .attack(0) }
            let repair = encounter.id == "chapter01_q07_encounter" ? 180 : enemies[index].maxHP * 12 / 100
            var transferred = 0
            if loadout.relicIDs.contains("relic_ownership_severing_needle") {
                transferred = sequenceNineRelics.interceptHealing(repair, recipientID: enemies[index].id,
                    healerID: enemy.id, playerMissingHP: playerMaxHP - playerHP, baseHP: playerBaseMaxHP, at: relicClock)
                playerHP += transferred
                lastRelicPlayerHealing += transferred
            }
            let restored = min(repair - transferred, enemies[index].maxHP - enemies[index].hp)
            enemies[index].hp += restored
            return .init(damage: 0, missedBossMechanic: false, healedTargetID: enemies[index].id, healing: restored)
        }
        if encounter.id == "chapter01_q08_encounter", intent == "parasite" { return .attack(MPCProgressionWalls.q8ParasiteDamage) }
        if encounter.id == "chapter01_q08_encounter", intent == "name_devour" {
            let devour = MPCProgressionWalls.q8DevourPercent
            let damage = playerBaseMaxHP * min(devour.max, devour.start + nameDevourCount * devour.step) / 100
            nameDevourCount += 1
            return .attack(damage)
        }
        if encounter.id == "chapter01_q04_encounter", enemy.contentID == "enemy_clockwork_hound" {
            if intent == "q4_probe" { return .attack(80) }
            if intent == "q4_flame_first" || intent == "q4_flame_second" {
                // One missed interception defeats the initial party, including its
                // starting shield. Damage still resolves through normal defenses.
                return .attack((playerBaseMaxHP * 110 + 99) / 100)
            }
        }
        if enemy.contentID == "enemy_emerald_revenant", intent == "emerald_burst" {
            return .attack((playerBaseMaxHP + 1) / 2)
        }
        let missionNumber = MPCChapterOneCatalog.mission(forEncounterID: encounter.id)?.number ?? 0
        if (9...15).contains(missionNumber), intent == "fortify",
           ["enemy_calibration_puppet", "elite_clock_chaser"].contains(enemy.contentID),
           let index = enemies.firstIndex(where: { $0.id == enemy.id && $0.isAlive }) {
            applyEnemyDefenseBoost(to: index, bonusBP: 5_000)
            if missionNumber == 12, MPCProgressionWalls.q12FortifyStackPercent > 0 { q12FortifyStacks[enemy.id, default: 0] += 1 }
            return .init(damage: 0, missedBossMechanic: false, defenseBoostBP: 5_000)
        }
        let attackPower = authoredAttackPower(for: enemy)
        if enemy.contentID == "enemy_clockwork_hound", intent == "memory_breath",
           ["chapter01_q03_encounter", "chapter01_q04_encounter"].contains(encounter.id) {
            // Q3's paired breaths teach the two-hit mask. Scale with base health
            // so growth cannot turn the lesson into two harmless hits.
            return .attack(encounter.id == "chapter01_q03_encounter"
                ? (playerBaseMaxHP * MPCProgressionWalls.q3BreathHealthPercent + 99) / 100 : 260)
        }
        if enemy.contentID == "enemy_clockwork_hound", intent != "name_hunt" {
            houndNameHuntStacks = 0
        }
        if let skill = (MPCChapterOneCatalog.enemies.first(where: { $0.id == enemy.contentID }) ?? MPCChurchBountyCatalog.enemyDefinition(id: enemy.contentID))?.skills.first(where: { $0.intent == intent }) {
            let damageBasisPoints: Int
            if enemy.contentID == "enemy_clockwork_hound", intent == "memory_breath" {
                damageBasisPoints = encounter.id == "chapter01_q05_encounter" ? 1_800
                    : encounter.id == "chapter01_q10_encounter" ? skill.damageBasisPoints * MPCProgressionWalls.q10HoundBreathPercent / 100
                    : skill.damageBasisPoints
            } else {
                damageBasisPoints = skill.damageBasisPoints
            }
            switch skill.target {
            case .lowestHealthAlly:
                guard let allyIndex = Self.lowestHealthEnemyIndex(in: enemies) else {
                    return .attack(attackPower * damageBasisPoints / 1_000)
                }
                let percentageHealing = enemies[allyIndex].maxHP * skill.healingBasisPoints / 10_000
                let restored = min(
                    max(skill.healing, percentageHealing),
                    enemies[allyIndex].maxHP - enemies[allyIndex].hp
                )
                enemies[allyIndex].hp += restored
                if skill.defenseBonusBP > 0 {
                    applyEnemyDefenseBoost(
                        to: allyIndex,
                        bonusBP: skill.defenseBonusBP
                    )
                }
                let defenseText = skill.defenseBonusBP > 0
                    ? "，防御提高\(skill.defenseBonusBP / 100)%"
                    : ""
                triggeredEffects.append("\(enemy.name)：为\(enemies[allyIndex].name)修复\(restored)生命\(defenseText)")
                return .init(
                    damage: 0,
                    missedBossMechanic: false,
                    healedTargetID: enemies[allyIndex].id,
                    healing: restored,
                    defenseBoostBP: skill.defenseBonusBP
                )
            case .selfUnit:
                guard let enemyIndex = enemies.firstIndex(where: { $0.id == enemy.id }) else {
                    return .attack(0)
                }
                if skill.tags.contains("transfer_buff_below_half"),
                   enemy.hp * 2 <= enemy.maxHP,
                   let sourceBoost = enemyDefenseBoosts.removeValue(forKey: enemy.id),
                   let targetIndex = enemies.firstIndex(where: {
                       $0.isAlive && $0.id != enemy.id
                   }) {
                    applyEnemyDefenseBoost(to: targetIndex, bonusBP: sourceBoost.bonusBP)
                    triggeredEffects.append(
                        "\(enemy.name)：生命低于50%，将\(sourceBoost.bonusBP / 100)%防御增益转存给\(enemies[targetIndex].name)"
                    )
                    return .init(
                        damage: 0,
                        missedBossMechanic: false,
                        defenseBoostBP: sourceBoost.bonusBP
                    )
                }
                guard skill.defenseBonusBP > 0 else { return .attack(0) }
                applyEnemyDefenseBoost(to: enemyIndex, bonusBP: skill.defenseBonusBP)
                triggeredEffects.append(
                    "\(enemy.name)：\(skill.name)使自身防御提高\(skill.defenseBonusBP / 100)%"
                )
                return .init(
                    damage: 0,
                    missedBossMechanic: false,
                    defenseBoostBP: skill.defenseBonusBP
                )
            case .player:
                var damage = attackPower * damageBasisPoints / 1_000
                if encounter.id == "chapter01_q06_encounter", enemy.contentID == "enemy_clockwork_hound", intent == "name_hunt" {
                    return .attack(attackPower * 3 / 2)
                }
                if enemy.contentID == "enemy_clockwork_hound", intent == "name_hunt" {
                    damage += damage * min(3, houndNameHuntStacks) * 10 / 100
                    houndNameHuntStacks = min(3, houndNameHuntStacks + 1)
                }
                return .attack(damage)
            }
        }

        if enemy.contentID == "boss_severian_unified_clock", bossPhase == .thirteenthBell,
           thirteenthBellCountdown == 1 {
            thirteenthBellCountdown = 4
            switch response {
            case .evasion:
                return .attack(0)
            case .protection:
                return .attack(attackPower)
            case .willBreak:
                if let index = enemies.firstIndex(where: { $0.id == enemy.id }) { enemies[index].delayedRounds = 1 }
                return .attack(0)
            case .fullFinisher:
                bossExposedRounds = 1
                return .attack(0)
            case .none:
                return .init(damage: playerMaxHP + playerShield, missedBossMechanic: true)
            }
        }

        let base: Int
        switch intent {
        case "charge", "recover", "guard", "fortify", "calibrate", "feint", "dim", "hide_minor_intent", "archive", "calibration", "unified_moment":
            base = 0
        case "pounce", "thirteenth_charge", "slam", "real_strike":
            base = attackPower * 2
        case "parasite", "transfer", "trim_buff", "shear":
            base = attackPower * 3 / 4
        default:
            base = attackPower
        }
        let empowered = base + base * bossEmpowermentStacks * 20 / 100
        return .attack(empowered)
    }

    /// Q4 and Q5 use the same authored hound. Q5 changes its state, not its
    /// identity: the hound keeps the enraged attack value through Mara's
    /// rewind so the next lethal breath can be intercepted by the relic.
    private func chapterThirtyIntentPattern(contentID: String, fallback: [String]) -> [String] {
        switch contentID {
        case "boss_chronarch_sovereign" where chapterMissionNumber == 28: return [
            "calibration", "strike", "guard", "recover",                 // one palm, first return located
            "calibration", "strike", "thirteenth_charge", "recover",    // palm and delayed seal
            "calibration", "thirteenth_charge", "strike", "recover",    // delayed seal and short palm
            "calibration", "strike", "slam", "recover",                 // paired blows
            "calibration", "thirteenth_charge", "slam", "recover"      // final sign after its contact
        ]
        case "boss_chronarch_sovereign" where chapterMissionNumber == 29: return [
            "calibration", "strike", "guard", "recover",                 // escort authority opens
            "calibration", "slam", "strike", "recover",                 // exposed direct blow
            "calibration", "strike", "thirteenth_charge", "recover",    // protection turns to the remaining escort
            "calibration", "thirteenth_charge", "slam", "recover",      // no simultaneous double heavy
            "calibration", "thirteenth_charge", "slam", "recover"      // final reserve pays for departure
        ]
        // Q30 opens in phase one; `endRound` swaps the loop as its health falls.
        case "boss_chronarch_sovereign": return Self.q30Pattern(phase: 1)
        case "enemy_archive_gatekeeper": return ["guard", "archive_slam", "recover"]
        case "enemy_codex_executor": return ["calibration", "strike", "slam", "recover"]
        case "enemy_archive_adjudicator": return chapterMissionNumber == 23 ? ["thirteenth_charge", "memory_breath", "recover"] : ["thirteenth_charge", "strike", "recover"]
        case "enemy_archive_convoy": return chapterMissionNumber == 26 ? ["guard", "strike", "slam", "recover"] : ["guard", "slam", "calibration", "recover"]
        case "elite_clock_chaser": return ["fortify", "thirteenth_charge", "strike", "recover"]
        case "enemy_memory_leech_node": return ["repair_guard", "memory_strike"]
        case "enemy_hollow_clockmaker" where chapterMissionNumber == 22: return ["calibration", "strike", "memory_breath", "calibration", "strike", "recover"]
        case "enemy_hollow_clockmaker" where chapterMissionNumber == 25: return ["calibration", "strike", "memory_breath", "recover"]
        case "enemy_emerald_revenant": return ["memory_breath", "charge", "emerald_burst", "recover"]
        case "enemy_clockwork_hound": return chapterMissionNumber == 16 ? ["memory_breath", "charge", "pounce", "recover"] : ["memory_breath", "pounce", "recover"]
        default: return fallback
        }
    }
    /// Q22 wall: the blow after a failed check is neither delayed (错认喜剧 waits for the wind-up after it)
    /// nor held by the blank card; only the reverse seal answers it (2026-10-15).
    func q22FailedBlowIsDue(_ enemy: MPCRuntimeEnemy) -> Bool {
        chapterMissionNumber == 22 && chapterVerificationFailed && enemy.currentIntent == "strike"
            && enemy.contentID == "enemy_hollow_clockmaker" && !MPCProgressionWalls.wearsWallRelic(mission: 22, bountyRelicID: loadout.bountyRelicID)
    }
    /// A failed Q17/Q22 verification empowers the next blow; the reverse seal caps it.
    private func verificationBlowPercent() -> Int {
        guard chapterVerificationFailed else { return 100 }
        let failed = MPCProgressionWalls.verificationFailPercent[chapterMissionNumber] ?? 100
        return loadout.bountyRelicID == MPCBountyRelicCatalog.reverseSeal ? min(failed, MPCProgressionWalls.reverseSealFailPercent) : failed
    }

    /// Q30 phase three without the life ledger (a 雾中续命 heal does not lift it).
    private func sovereignIsEnraged(_ enemy: MPCRuntimeEnemy) -> Bool {
        chapterMissionNumber == 30 && enemy.contentID == "boss_chronarch_sovereign"
            && (enemy.hp * 100 < enemy.maxHP * MPCProgressionWalls.q30EnrageBelowPercent || mistMendPhase >= 3)
            && !MPCProgressionWalls.wearsWallRelic(mission: 30, bountyRelicID: loadout.bountyRelicID)
    }

    /// The sovereign's blow at the hero before any player defence. Pure, so the allies'
    /// planner reads the same number `endRound` lands.
    private func sovereignBlow(_ enemy: MPCRuntimeEnemy, intent: String) -> Int {
        typealias W = MPCProgressionWalls
        // Q28/Q29 are no walls: flat blows, heavy enough that the party's mend does not erase them.
        guard chapterMissionNumber == 30 else { return W.finalBossEarlyBlows[intent, default: 0] }
        let enraged = sovereignIsEnraged(enemy)
        // Q30 blows are shares of the hero's health (2026-10-10), so gear cannot race past them.
        let share: Int = switch intent {
        case "strike": W.q30StrikeHealthPercent
        case "thirteenth_charge": W.q30ChargeHealthPercent
        case "slam": W.q30SlamHealthPercent
        case "name_seal": W.q30SealHealthPercent
        default: 0
        }
        var blow = playerBaseMaxHP * share / 100 * (enraged ? W.q30EnragePercent : 100) / 100
        // Q30 wall, tower half: without F90-or-deeper gear the slam takes a share of health.
        if intent == "slam", !W.meetsTowerFloor(mission: 30, gear: loadout.churchGear),
           let wall = W.towerCheckBlowHealthPercent[30] {
            blow = max(blow, playerBaseMaxHP * wall / 100)
        }
        // Q30 wall: every enraged blow (not the seal) takes at least this share of health.
        if enraged, share > 0, intent != "name_seal", W.q30EnragedBlowHealthPercent > 0 {
            blow = max(blow, playerBaseMaxHP * W.q30EnragedBlowHealthPercent / 100)
        }
        // 冷钟 (Q30 离场祝福): on top of every share above, so an intercept takes its part of more.
        if intent == "thirteenth_charge", farewellBlessings?.sovereign == .coldBell { blow = blow * (100 + W.q30ColdBellPercent) / 100 }
        return blow
    }

    private mutating func resolveChapterThirtyIntent(enemy: MPCRuntimeEnemy, intent: String) -> MPCResolvedEnemyIntent? {
        if enemy.contentID == "boss_chronarch_sovereign" { return .attack(sovereignBlow(enemy, intent: intent)) }
        if enemy.contentID == "enemy_codex_executor", intent == "slam" {
            return .attack(enemy.attack * verificationBlowPercent() / 100)
        }
        if ["enemy_archive_adjudicator", "enemy_archive_convoy"].contains(enemy.contentID) {
            if intent == "memory_breath" { queueFiniteDamage(source: enemy.id, damage: 45); return .attack(0) }
            if intent == "thirteenth_charge" || intent == "slam" {
                // Q18/Q26 walls: without deep enough tower gear the heavy blow takes a share of health.
                if !MPCProgressionWalls.meetsTowerFloor(mission: chapterMissionNumber, gear: loadout.churchGear),
                   let share = MPCProgressionWalls.towerCheckBlowHealthPercent[chapterMissionNumber] {
                    return .attack(playerBaseMaxHP * share / 100)
                }
                let percent = chapterMissionNumber == 18 ? MPCProgressionWalls.q18ChargePercent
                    : chapterMissionNumber == 26 ? MPCProgressionWalls.q26SlamPercent : 200
                return .attack(enemy.attack * percent / 100)
            }
            if ["guard", "calibration", "recover"].contains(intent) { return .attack(0) }
            return .attack(enemy.attack)
        }
        if [22,25].contains(chapterMissionNumber), enemy.contentID == "enemy_hollow_clockmaker" {
            if intent == "memory_breath" { queueFiniteDamage(source: enemy.id, damage: 40); return .attack(0) }
            if intent == "strike" {
                // Q22 wall: a failed verification without the reverse seal hits for a share
                // of the player's health, so armor and tower weapons cannot outpace it.
                if chapterMissionNumber == 22, chapterVerificationFailed,
                   !MPCProgressionWalls.wearsWallRelic(mission: 22, bountyRelicID: loadout.bountyRelicID) {
                    return .attack(playerBaseMaxHP * MPCProgressionWalls.q22FailedBlowHealthPercent / 100)
                }
                return .attack(enemy.attack * verificationBlowPercent() / 100)
            }
            return .attack(0)
        }
        return nil
    }

    private func authoredAttackPower(for enemy: MPCRuntimeEnemy) -> Int {
        guard enemy.contentID == "enemy_clockwork_hound" else {
            return enemy.attack
        }
        switch encounter.id {
        case "chapter01_q04_encounter":
            // Q4 is the normal first meeting. Keep its authored breath
            // visible and non-lethal so the player can complete the lesson.
            return 88
        case "chapter01_q05_encounter":
            // Q5 is the same hound after rage, not a different enemy.
            return 110
        default:
            return enemy.attack
        }
    }

    private mutating func applyEnemyDefenseBoost(
        to enemyIndex: Int,
        bonusBP: Int
    ) {
        let enemy = enemies[enemyIndex]
        let targetID = enemy.id
        let clampedBonus = min(10_000, max(0, bonusBP))
        enemyDefenseBoosts[targetID] = MPCEnemyDefenseBoost(
            bonusBP: clampedBonus
        )
        var state = foolStates[targetID] ?? .init(targetDefense: enemy.defense)
        state.targetDefense = enemy.defense * (10_000 + clampedBonus) / 10_000
        foolStates[targetID] = state
    }

    /// Support buffs are cast during an enemy turn. They protect exactly the
    /// following player phase, then clear before the next enemy action starts.
    /// This deliberately does not rely on a round-number comparison.
    private mutating func expireEnemyDefenseBoostsBeforeEnemyTurn(actingEnemyID: String?) {
        // Independent real-time actors must not erase another actor's readable
        // counter window merely because their own projectile arrived first.
        let stagedProgression = (9...15).contains(MPCChapterOneCatalog.mission(forEncounterID: encounter.id)?.number ?? 0)
        let expiredIDs = Array(enemyDefenseBoosts.keys).filter { !stagedProgression || actingEnemyID == nil || $0 == actingEnemyID }
        for targetID in expiredIDs {
            enemyDefenseBoosts.removeValue(forKey: targetID)
            guard let enemyIndex = enemies.firstIndex(where: { $0.id == targetID }) else { continue }
            var state = foolStates[targetID] ?? .init(targetDefense: enemies[enemyIndex].defense)
            state.targetDefense = enemies[enemyIndex].defense
            foolStates[targetID] = state
            triggeredEffects.append("\(enemies[enemyIndex].name)：防御强化消退")
        }
    }

    /// Basic attacks historically bypass a target's normal defense value.
    /// While an authored defense-up buff is active, apply the exact same
    /// 100 + defense curve as the skill resolver without changing unbuffed
    /// basic-attack balance elsewhere in Chapter One.
    private func basicDamageAfterTemporaryDefenseBoost(
        _ damage: Int,
        targetID: String,
        enemy: MPCRuntimeEnemy
    ) -> Int {
        guard damage > 0,
              enemyDefenseBoosts[targetID] != nil,
              let boostedDefense = foolStates[targetID]?.targetDefense,
              boostedDefense > enemy.defense
        else {
            return damage
        }
        let numerator = Int64(damage) * Int64(100 + enemy.defense)
        let denominator = Int64(100 + boostedDefense)
        return max(1, Int((numerator * 2 + denominator) / (denominator * 2)))
    }

    private func isCorrectStrongAttackResponse(
        enemy: MPCRuntimeEnemy,
        intent: String,
        response: MPCBossMechanicResponse
    ) -> Bool {
        if enemy.contentID == "boss_severian_unified_clock", bossPhase == .thirteenthBell,
           thirteenthBellCountdown == 1 {
            return response != .none
        }
        guard ["pounce", "thirteenth_charge", "slam", "real_strike"].contains(intent) else {
            return false
        }
        return response == .evasion || response == .protection
    }

    private func enemyIntentIgnoresProtection(_ intent: String) -> Bool {
        ["pounce", "thirteenth_charge", "slam", "real_strike", "parasite", "transfer", "shear"]
            .contains(intent)
    }

    private func strengthenedSkillAmount(_ amount: Int, skill: FoolSkillID) -> Int {
        MPCSkillGrowth.scaledAmount(amount, level: loadout.skillLevel(for: skill))
    }

    private func talentDefense(_ defense: Int, skill: FoolSkillID, stacks: Int) -> Int {
        var reduction = 0
        if loadout.talents.has("trickery.1"), skill == .sidestepStrike { reduction += 15 }
        if loadout.talents.has("omen.3"), stacks == 4 { reduction += 20 }
        return defense * (100 - reduction) / 100
    }

    private func talentDamage(_ base: Int, skill: FoolSkillID, stacks: Int, targetID: String) -> Int {
        guard base > 0 else { return base }
        let t = loadout.talents
        var bonus = 0
        if t.has("trickery.0"), skill == .sidestepStrike { bonus += 10 }
        if t.has("trickery.2"), let last = talentLastSkill, last != skill { bonus += 12 }
        if t.has("trickery.3"), talentLastDamageSkill == .sidestepStrike, skill != .sidestepStrike { bonus += 20 }
        if t.has("trickery.4"), let target = enemies.first(where: { $0.id == targetID }), target.hp * 100 <= target.maxHP * 35 { bonus += 18 }
        if t.has("trickery.5"), (talentDamageCount + 1).isMultiple(of: 3) { bonus += 35 }
        if talentEchoReady { bonus += 15 }
        if talentFinalEchoReady { bonus += 40 }
        if talentMaskReady { bonus += 20 }
        if t.has("omen.1") { bonus += stacks * 4 }
        if talentEvidenceReady { bonus += 20 }
        if t.has("omen.5"), stacks == 4, skill == .absurdFinale { bonus += 45 }
        return base * (100 + bonus) / 100
    }

    /// A shared revive if an active ally still stands, otherwise defeat: the hero down with
    /// no revive left loses even while allies stand (2026-10-10). Only this battle's allies
    /// count, never leftover persistent entries.
    private mutating func settlePlayerDownIfNeeded() {
        if playerHP <= 0 { counter.clearWindow() }
        if isPartyBossEncounter {
            // The party loses only when all three are down (2026-10-10, user); a fallen hero
            // waits for the healer's revive channel (`advanceCompanions`).
            guard playerHP <= 0 else { return }
            if partyStillStanding {
                if heroReviveAt == nil, sharedReviveCharges > 0, revivingHealerID != nil {
                    heroReviveAt = relicClock + Double(MPCProgressionWalls.partyReviveTenths) / 10
                }
                return
            }
            outcome = .defeat
            settleUsurpedLifeMedal()
            return
        }
        if playerHP <= 0 {
            if sharedReviveCharges > 0, activeCompanionIDs.contains { isAllyStanding($0) } {
                sharedReviveCharges -= 1
                playerHP = max(1, playerMaxHP * 3 / 10)
                if loadout.relicIDs.contains("relic_mist_anchor_shard") {
                    grantPlayerShield(playerMaxHP / 10)
                    mistAnchorWasConsumed = true
                    triggeredEffects.append("雾锚碎片：复活后获得护盾")
                }
                log.append(.init(round: round, message: "AI队友使用界锚复原", damageTaken: 0, bossMechanicMissed: false))
            } else {
                outcome = .defeat
                settleUsurpedLifeMedal()
            }
        }
    }

    /// A light attack (CombatTempo.swift) lands. Count-based defences are never used up:
    /// the mask's phantom parries it for `parryPercent`, the paper double and the free
    /// evasion ignore it. Damage reduction, shields and the blank card's window apply.
    /// Returns nil when the attacker can no longer hit (dead, departed, no tempo).
    @discardableResult
    public mutating func resolveLightAttack(enemyID: String, at now: TimeInterval) -> MPCLightAttackResolution? {
        guard let tempo, outcome == .inProgress else { return nil }
        _ = advanceRelicClock(at: now)
        guard outcome == .inProgress,
              let enemy = enemies.first(where: { $0.id == enemyID && $0.isAlive && !$0.hasDeparted }) else { return nil }
        _ = expireOwnedManualMasquerade(at: now)
        var damage = max(1, enemy.attack * tempo.lightAttackPercent / 100)
        if sequenceNineRelics.blankCardBlocks(enemyID, at: now) { damage = 0 }
        let parried = damage > 0 && masqueradeCharges > 0
        if parried { damage = max(1, damage * tempo.parryPercent / 100) }
        damage = damage * (10_000 - loadout.churchGear.damageReductionBP - loadout.outfitBonus.damageReductionBP) / 10_000
        if parried { triggeredEffects.append("招架：幻影挡开轻击，承受\(damage)") }
        let healthBefore = playerHP
        absorbPlayerDamage(damage, isLightHit: true)
        damage = max(0, healthBefore - playerHP)
        settlePlayerDownIfNeeded()
        if outcome != .inProgress { clearEmeraldPoison(); finiteDamageTicks.removeAll() }
        return .init(enemyID: enemyID, damage: damage, parried: parried)
    }

    private mutating func absorbPlayerDamage(_ damage: Int, isDamageOverTime: Bool = false, isLightHit: Bool = false) {
        if playerIsDown { return } // nothing more lands on a fallen hero
        let pressure = MPCOrderedSkillRules.pressureLayers(mission: chapterMissionNumber, at: relicClock)
        let damage = damage * (1 << pressure)
        var adjustedDamage = max(0, !isDamageOverTime && unreliableNarratorTriggeredRound == round ? damage * 105 / 100 : damage)
        if isDamageOverTime, adjustedDamage > 0, loadout.relicIDs.contains("relic_salt_sealed_breathing_bag") {
            let captured = min(adjustedDamage * relicBalance.poisonCapturePercent / 100, max(0, playerBaseMaxHP * relicBalance.poisonCapacityPercent / 100 - saltBreathingBagStored))
            saltBreathingBagStored += captured
            playerHP = min(playerHP, playerMaxHP)
            adjustedDamage -= captured
        }
        if !isDamageOverTime, !isLightHit, freeEvasionCharges > 0, adjustedDamage > 0 {
            freeEvasionCharges -= 1
            triggeredEffects.append("未写结局：闪避本次伤害")
            return
        }
        if !isDamageOverTime, adjustedDamage > 0, relicClock < orderedWardUntil {
            adjustedDamage = adjustedDamage * 40 / 100
            orderedWardUntil = 0
        }
        if relicClock >= orderedShieldUntil { orderedShield = 0 }
        let orderedAbsorbed = min(orderedShield, adjustedDamage)
        orderedShield -= orderedAbsorbed
        adjustedDamage -= orderedAbsorbed
        let shieldBefore = playerShield
        let absorbed = min(playerShield, adjustedDamage)
        playerShield -= absorbed
        let healthDamage = adjustedDamage - absorbed
        if playerHP > 0, healthDamage >= playerHP, q5PaperRelicReady {
            playerHP = 1
            q5PaperRelicReady = false
            q5PaperRelicTriggered = true
            triggeredEffects.append("纸人代身：封缄暗淡，保留1生命；本场已用尽")
        } else {
            playerHP = max(0, playerHP - healthDamage)
        }
        if loadout.passiveIDs.contains("fool_passive_05"), !shieldBreakTriggered,
           shieldBefore > 0, playerShield == 0 {
            foolCooldowns.reduceCooldown(.paperDouble)
            shieldBreakTriggered = true
            triggeredEffects.append("纸幕后路：护盾破裂缩短替身冷却")
        }
        if loadout.passiveIDs.contains("fool_passive_06"), !lowHPTriggered,
           playerHP > 0, playerHP * 100 < playerMaxHP * 30 {
            freeEvasionCharges = 1
            lowHPTriggered = true
            triggeredEffects.append("未写结局：获得一次闪避")
        }
    }

    private mutating func reduceLongestCooldown() {
        guard let skill = FoolSkillID.allCases
            .filter({ $0 != .namelessStage })
            .max(by: { remainingCooldownActions(for: $0) < remainingCooldownActions(for: $1) }),
              remainingCooldownActions(for: skill) > 0 else { return }
        foolCooldowns.reduceCooldown(skill)
    }

    private mutating func updateHeldReadySkills(used skillID: FoolSkillID?) {
        for id in FoolSkillID.allCases where id != .namelessStage {
            if id == skillID || !foolCooldowns.isAvailable(id) {
                readySkillHeldActions[id] = 0
            } else {
                readySkillHeldActions[id, default: 0] += 1
            }
        }
    }

    private mutating func recordPlayerSkill(_ skillID: FoolSkillID, targetID: String?) {
        executedSkills.append(.init(skillID: skillID, targetID: targetID, round: round))

        switch skillID {
        case .maskedWhisper, .fabricatedEvidence, .turnTheTables:
            behaviorTags.insert(.applyIllusion)
        case .identityDisplacement:
            break // Recorded only on an actual four-stack conversion.
        case .sidestepStrike:
            if let targetID, foolStates[targetID]?.misalignmentStacks ?? 0 > 0 {
                behaviorTags.insert(.consumeOrCheckMisalignment)
            }
            if let targetID, foolStates[targetID]?.finaleReady == true {
                behaviorTags.insert(.gainFinaleReady)
            }
        case .mirrorPursuit:
            behaviorTags.insert(.consumeOrCheckMisalignment)
        case .absurdFinale:
            behaviorTags.insert(.castFinale)
        case .paperDouble:
            behaviorTags.insert(.defensiveResponse)
        case .backstageChange, .namelessStage, .stolenTempo, .mirrorBarrage, .delayedSignature:
            break
        }

        guard executedSkills.count >= 2 else { return }
        let pair = Array(executedSkills.suffix(2))
        let skillPair = pair.map(\.skillID)
        let targetChainValid = pair.compactMap(\.targetID).count < 2 || pair[0].targetID == pair[1].targetID
        let comboID: String?
        switch skillPair {
        case [.maskedWhisper, .sidestepStrike]: comboID = "K01"
        case [.maskedWhisper, .fabricatedEvidence]: comboID = "K02"
        default: comboID = nil
        }
        guard let comboID else { return }
        let record = MPCComboExecutionRecord(
            comboID: comboID,
            battleID: encounter.id,
            skillSequence: skillPair,
            behaviorTags: behaviorTags,
            validTargetChain: targetChainValid
        )
        if targetChainValid {
            behaviorTags.insert(.targetChainValid)
        }
        if !comboRecords.contains(where: { $0.id == record.id }) {
            comboRecords.append(record)
        }
    }
}

// MARK: - Isolated campaign mechanics (explicit opt-in; no rewards/save writes)
extension MPCChapterOneEncounterSession {
    /// Authoritative cast timing shared by the visible loop and offline settlement.
    public mutating func prepareOrderedSkill(_ skill: FoolSkillID, targetID: String, at now: TimeInterval) -> MPCOrderedCastTiming? {
        guard skill.isOrderedOrdinary else { return nil }
        expireOrderedStatuses(at: now)
        let work = MPCOrderedSkillRules.timing(skill)
        let end = skill == .mirrorBarrage ? now + work.cast
            : MPCOrderedSkillRules.finishWork(start: now, work: work.cast, hasteUntil: orderedHasteUntil)
        let first = skill == .mirrorBarrage
            ? MPCOrderedSkillRules.finishWork(start: now, work: 0.6, hasteUntil: orderedHasteUntil)
            : skill == .mirrorPursuit
                ? MPCOrderedSkillRules.finishWork(start: now, work: work.cast / 2, hasteUntil: orderedHasteUntil) : end
        let ready = MPCOrderedSkillRules.finishWork(start: end, work: work.recovery, hasteUntil: orderedHasteUntil)
        let timing = MPCOrderedCastTiming(firstImpactAt: first, lastImpactAt: end, readyAt: ready)
        orderedPrepared = .init(skill: skill, target: targetID, start: now, timing: timing,
            empowered: (foolStates[targetID]?.misalignmentStacks ?? 0) > 0)
        orderedLastDispatched = skill
        orderedCastReadyAt = ready
        return timing
    }

    public mutating func drainOrderedSkillImpacts() -> [MPCOrderedSkillImpact] {
        defer { orderedImpacts.removeAll(keepingCapacity: true) }
        return orderedImpacts
    }

    private mutating func expireOrderedStatuses(at now: TimeInterval) {
        for id in Array(foolStates.keys) {
            if now >= foolStates[id]!.illusionExpiresAt { foolStates[id]!.illusionStacks = 0 }
            if now >= foolStates[id]!.misalignmentExpiresAt {
                foolStates[id]!.misalignmentStacks = 0; foolStates[id]!.orderedChainHits = 0
            }
        }
        if now >= orderedShieldUntil { orderedShield = 0 }
    }

    /// Extra hits retain their logical deadlines even when several become due in one frame.
    private mutating func advanceOrderedSkills(at now: TimeInterval) {
        let savedClock = relicClock
        defer { relicClock = max(savedClock, now); orderedDamageContext = nil; expireOrderedStatuses(at: now) }
        guard outcome == .inProgress, !playerIsDown else {
            orderedPending.removeAll(); orderedPrepared = nil; return
        }
        while let index = orderedPending.indices.min(by: { orderedPending[$0].at < orderedPending[$1].at }),
              orderedPending[index].at <= now + 0.000_001, outcome == .inProgress, !playerIsDown {
            let event = orderedPending.remove(at: index)
            relicClock = event.at
            orderedDamageContext = event.damageContext
            expireOrderedStatuses(at: event.at)
            // A new wave never inherits an old target's channel or delayed contract.
            guard event.damageContext?.waveIndex == waveIndex, enemies.contains(where: { $0.id == event.target }) else { continue }
            let alive = enemies.contains { $0.id == event.target && $0.isAlive }
            var targets: [MPCFoolSkillTargetResolution] = []
            switch event.kind {
            case .signature(let hits):
                guard alive else { continue }
                let recipients = [event.target] + enemies.filter { $0.isAlive && $0.id != event.target }.prefix(2).map(\.id)
                for (position, id) in recipients.enumerated() {
                    let coefficient = (5_000 + 7_000 * hits) / (position == 0 ? 1 : 2)
                    let damage = orderedDamage(event.skill, to: id, coefficient: coefficient, counts: false)
                    targets.append(.init(targetID: id, damage: damage))
                }
                triggeredEffects.append("附言：兑现\(hits)次命中")
            case .mirror:
                guard let id = alive ? event.target : enemies.first(where: \.isAlive)?.id else { continue }
                let boosted = event.empowered && (foolStates[id]?.misalignmentStacks ?? 0) > 0
                targets = [.init(targetID: id, damage: orderedDamage(event.skill, to: id, coefficient: boosted ? 18_000 : 4_000))]
                if event.empowered, foolStates[id] != nil { foolStates[id]!.misalignmentStacks = max(0, foolStates[id]!.misalignmentStacks - 1) }
            case .barrage(let end):
                guard let id = alive ? event.target : enemies.first(where: \.isAlive)?.id else { continue }
                targets = [.init(targetID: id, damage: orderedDamage(event.skill, to: id, coefficient: 3_600))]
                orderedMark(id, stacks: 1)
                let next = MPCOrderedSkillRules.finishWork(start: event.at, work: 0.6, hasteUntil: orderedHasteUntil)
                if next <= end + 0.000_001 {
                    orderedPending.append(.init(at: next, skill: event.skill, target: id, kind: .barrage(end: end), damageContext: orderedDamageContext))
                }
            }
            if loadout.passiveIDs.contains("fool_passive_04"), !orderedPending.contains(where: { $0.skill == event.skill }), targets.contains(where: { $0.damage > 0 }) {
                lateApplauseReady = true
            }
            orderedImpacts.append(.init(skill: event.skill, at: event.at, targets: targets))
        }
    }

    private mutating func orderedMark(_ id: String, stacks: Int) {
        guard orderedDamageContext?.waveIndex == waveIndex, foolStates[id] != nil, enemies.contains(where: { $0.id == id && $0.isAlive }) else { return }
        foolStates[id]!.illusionStacks = min(4, foolStates[id]!.illusionStacks + stacks)
        foolStates[id]!.illusionExpiresAt = relicClock + MPCOrderedSkillRules.markDuration
        if foolStates[id]!.illusionStacks == 4 { behaviorTags.insert(.reachFourIllusion) }
    }

    private mutating func orderedMisalign(_ id: String) {
        guard orderedDamageContext?.waveIndex == waveIndex, foolStates[id] != nil, enemies.contains(where: { $0.id == id && $0.isAlive }) else { return }
        foolStates[id]!.misalignmentStacks = 2
        foolStates[id]!.misalignmentExpiresAt = relicClock + MPCOrderedSkillRules.markDuration
        foolStates[id]!.armorBreakExpiresAt = relicClock + MPCOrderedSkillRules.markDuration
        foolStates[id]!.orderedChainHits = 0
        behaviorTags.insert(.convertToMisalignment)
    }

    private mutating func orderedDamage(_ skill: FoolSkillID, to id: String, coefficient: Int, penetration: Int = 0, counts: Bool = true) -> Int {
        guard outcome == .inProgress, orderedDamageContext?.waveIndex == waveIndex, let enemy = enemies.first(where: { $0.id == id && $0.isAlive }) else { return 0 }
        let state = foolStates[id] ?? .init(targetDefense: enemy.defense)
        var attack = state.attack
        if isUsurpedLifeMedalActive { attack = attack * 130 / 100 }
        let pierce = max(penetration, relicClock < state.armorBreakExpiresAt ? 7_000 : 0)
        var amount = MPCFixedPointCombatMath.damage(.init(attack: attack, coefficientBP: coefficient,
            targetDefense: talentDefense(state.targetDefense, skill: skill, stacks: state.illusionStacks),
            armorPenetrationBP: pierce)).damageAfterDefense
        // One-shot and alternating-cast bonuses are captured once for the entire spell.
        // Target health, marks and defense are still evaluated at each real contact.
        var bonus = orderedDamageContext?.actionBonusPercent ?? 0
        if loadout.talents.has("trickery.4"), enemy.hp * 100 <= enemy.maxHP * 35 { bonus += 18 }
        if loadout.talents.has("omen.1") { bonus += state.illusionStacks * 4 }
        if loadout.talents.has("omen.5"), state.illusionStacks == 4, skill == .absurdFinale { bonus += 45 }
        amount = amount * (100 + bonus) / 100
        amount = amount * (orderedDamageContext?.multiplierBP ?? 10_000) / 10_000
        if loadout.relicIDs.contains("relic_red_wax_seal"), skill == .fabricatedEvidence { amount = amount * 90 / 100 }
        amount = strengthenedSkillAmount(amount, skill: skill)
        if loadout.relicIDs.contains("relic_cracked_monocle"), state.illusionStacks < 4 { amount = amount * 97 / 100 }
        if loadout.relicIDs.contains("relic_thirteenth_record"), round.isMultiple(of: 3) { amount = amount * 95 / 100 }
        let oldSource = activeDamageSource
        activeDamageSource = skill.rawValue
        let dealt = (try? applyPartyDamage(amount, to: id, category: actionCategory(for: skill))) ?? 0
        activeDamageSource = oldSource
        if dealt > 0, counts {
            // Only damage reaching health fuels the contract, never fully absorbed hits.
            for index in orderedPending.indices where orderedPending[index].target == id {
                if case .signature(let hits) = orderedPending[index].kind, relicClock < orderedPending[index].at {
                    orderedPending[index].kind = .signature(hits: min(8, hits + 1))
                }
            }
            if (foolStates[id]?.misalignmentStacks ?? 0) > 0 {
                foolStates[id]!.orderedChainHits = min(3, foolStates[id]!.orderedChainHits + 1)
            }
        }
        return dealt
    }

    private mutating func resolveOrderedFirstImpact(_ skill: FoolSkillID, targetID: String?) throws -> MPCFoolSkillEncounterResolution {
        let id = try validatedTargetID(targetID ?? (skill == .backstageChange ? enemies.first(where: \.isAlive)?.id : nil))
        let prepared = orderedPrepared.flatMap { $0.skill == skill ? $0 : nil }
        orderedPrepared = nil
        let savedClock = relicClock
        if let prepared { relicClock = prepared.timing.firstImpactAt }
        defer { relicClock = savedClock; talentLastSkill = skill; orderedDamageContext = nil }
        let isMultiple = skill == .mirrorPursuit || skill == .mirrorBarrage || skill == .delayedSignature
        var multiplier = 10_000
        if lateApplauseReady, !isMultiple { multiplier = multiplier * 110 / 100; lateApplauseReady = false }
        if unifiedGearDamageReady { multiplier = multiplier * 120 / 100; unifiedGearDamageReady = false }
        if loadout.relicIDs.contains("relic_clock_chaser_spur"), readySkillHeldActions[skill, default: 0] >= 2 { multiplier = multiplier * 115 / 100 }
        orderedDamageContext = .init(waveIndex: waveIndex, actionBonusPercent: talentDamage(10_000, skill: skill, stacks: 0, targetID: "") / 100 - 100, multiplierBP: multiplier)

        expireOrderedStatuses(at: relicClock)
        var targets: [MPCFoolSkillTargetResolution] = []
        func result(_ damage: Int) -> MPCFoolSkillTargetResolution { .init(targetID: id, damage: damage) }
        switch skill {
        case .sidestepStrike:
            if controlSealActive && encounter.id == "chapter01_q01_encounter" {
                controlSealActive = false; applyBossActionCategory(.damage); targets = [result(0)]
            } else {
                let recipients = [id] + enemies.filter { $0.isAlive && $0.id != id }.prefix(2).map(\.id)
                for target in recipients { targets.append(.init(targetID: target, damage: orderedDamage(skill, to: target, coefficient: relicClock < orderedHasteUntil || (foolStates[target]?.illusionStacks ?? 0) >= 4 ? 15_000 : 6_500))) }
            }
        case .fabricatedEvidence:
            targets = [result(orderedDamage(skill, to: id, coefficient: 2_000))]
            orderedMark(id, stacks: 4)
            if loadout.relicIDs.contains("relic_red_wax_seal") { foolStates[id]?.illusionExpiresAt += 1 }
            if loadout.talents.has("omen.0") { foolStates[id]?.illusionExpiresAt += 0.5 }
            if enhancedSetupStacks > 0 { foolStates[id]?.illusionExpiresAt += Double(enhancedSetupStacks) * 0.5; enhancedSetupStacks = 0 }
            if loadout.passiveIDs.contains("fool_passive_02"), unreliableNarratorTriggeredRound != round {
                foolStates[id]?.illusionExpiresAt += 0.5
                unreliableNarratorTriggeredRound = round
            }
            if loadout.talents.has("omen.4") { talentEvidenceReady = true }
        case .stolenTempo:
            targets = [result(orderedDamage(skill, to: id, coefficient: 1_000))]
            orderedHasteUntil = relicClock + MPCOrderedSkillRules.hasteDuration
            triggeredEffects.append("急板：施法速度+100%，持续3.2秒")
        case .mirrorBarrage:
            targets = [result(orderedDamage(skill, to: id, coefficient: 3_600))]
            orderedMark(id, stacks: 1)
            let end = prepared?.timing.lastImpactAt ?? relicClock + 1.2
            let next = MPCOrderedSkillRules.finishWork(start: relicClock, work: 0.6, hasteUntil: orderedHasteUntil)
            if next <= end + 0.000_001 { orderedPending.append(.init(at: next, skill: skill, target: id, kind: .barrage(end: end), damageContext: orderedDamageContext)) }
        case .identityDisplacement:
            let stacks = foolStates[id]?.illusionStacks ?? 0
            let valid = stacks >= (sealConversionReady ? 2 : 4)
            targets = [result(orderedDamage(skill, to: id, coefficient: valid ? 11_000 : 3_000))]
            if valid {
                foolStates[id]?.illusionStacks = 0; orderedMisalign(id); sealConversionReady = false
                triggeredEffects.append("错认喜剧：4误认转为2错位，破甲70%，持续4秒")
                // A full four-stack conversion also delays the target's next wind-up by one beat
                // (Q8's 吞名). An attack already committed still lands (2026-10-15, user: 恢复错认喜剧能打断吞名).
                if stacks >= 4, let index = enemies.firstIndex(where: { $0.id == id && $0.isAlive }) {
                    enemies[index].delayedRounds = max(1, enemies[index].delayedRounds)
                    behaviorTags.insert(.reachFourIllusion)
                    triggeredEffects.append("错认喜剧：目标下次起手延迟一拍；在途攻击不取消")
                }
            } else { orderedMark(id, stacks: 1) }
            if valid, loadout.passiveIDs.contains("fool_passive_03") { _ = receivePlayerHealing(80) }
        case .mirrorPursuit:
            let empowered = prepared?.empowered ?? ((foolStates[id]?.misalignmentStacks ?? 0) > 0)
            let valid = empowered && (foolStates[id]?.misalignmentStacks ?? 0) > 0
            targets = [result(orderedDamage(skill, to: id, coefficient: valid ? 18_000 : 4_000))]
            orderedPending.append(.init(at: prepared?.timing.lastImpactAt ?? relicClock + 0.575, skill: skill, target: id, kind: .mirror, empowered: empowered, damageContext: orderedDamageContext))
            if loadout.relicIDs.contains("relic_mirror_thread") { mirrorThreadBonusReady = true }
        case .absurdFinale:
            let state = foolStates[id] ?? .init()
            let valid = state.misalignmentStacks > 0
            targets = [result(orderedDamage(skill, to: id, coefficient: 6_000 + (valid ? 50_000 + 8_000 * state.orderedChainHits : 0), penetration: valid ? 8_000 : 0))]
            foolStates[id]?.misalignmentStacks = 0; foolStates[id]?.orderedChainHits = 0
        case .turnTheTables:
            let boost = enemyDefenseBoosts.removeValue(forKey: id)
            let shield = enemyGiftShields.removeValue(forKey: id) ?? 0
            let empower = towerEmpowers.removeValue(forKey: id)
            let dispelled = boost != nil || shield > 0 || empower != nil
            if boost != nil { foolStates[id]?.targetDefense = enemies.first(where: { $0.id == id })?.defense ?? 0 }
            targets = [result(orderedDamage(skill, to: id, coefficient: dispelled ? 27_500 : 3_500))]
            if dispelled { orderedMisalign(id) } else { orderedMark(id, stacks: 2) }
            orderedWardUntil = relicClock + 4
        case .backstageChange:
            targets = [result(orderedDamage(skill, to: id, coefficient: 2_000))]
            var cleansed = (clearHeroSeal() ? ["夺名封印"] : []) + [cleanseOnePlayerDamageOverTime()].compactMap { $0 }
            orderedShield = max(orderedShield, strengthenedSkillAmount(240, skill: skill)); orderedShieldUntil = relicClock + 4
            if relicClock < orderedHasteUntil { orderedHasteUntil += 1.3 }
            if (foolStates[id]?.illusionStacks ?? 0) > 0 { foolStates[id]!.illusionExpiresAt += 1.3 }
            if (foolStates[id]?.misalignmentStacks ?? 0) > 0 { foolStates[id]!.misalignmentExpiresAt += 1.3 }
            if relicClock < (foolStates[id]?.armorBreakExpiresAt ?? 0) { foolStates[id]!.armorBreakExpiresAt += 1.3 }
            if loadout.relicIDs.contains("relic_memory_leech_vial") {
                if !memoryLeechCostPaid { playerHP = max(1, playerHP - 40); memoryLeechCostPaid = true }
                if let second = cleanseOnePlayerDamageOverTime() { cleansed.append(second) }
                enhancedSetupStacks = max(enhancedSetupStacks, 1)
            }
            // The App shows 净化 only for a real cleanse; this line was the manual path's (2026-10-15).
            triggeredEffects.append("悔笔：" + (cleansed.isEmpty ? "无可净化" : "划去" + cleansed.joined(separator: "、")))
        case .delayedSignature:
            targets = [result(orderedDamage(skill, to: id, coefficient: 2_000))]
            orderedPending.removeAll { $0.target == id && $0.skill == .delayedSignature }
            orderedPending.append(.init(at: relicClock + MPCOrderedSkillRules.signatureDelay, skill: skill, target: id, kind: .signature(hits: 0), damageContext: orderedDamageContext))
        default: throw FoolComboError.unsupportedSkill(skill)
        }
        if skill != .mirrorPursuit && skill != .mirrorBarrage {
            orderedCastReadyAt = MPCOrderedSkillRules.finishWork(start: relicClock, work: MPCOrderedSkillRules.timing(skill).recovery, hasteUntil: orderedHasteUntil)
        }
        borrowedSecondAvailable = false
        foolCooldowns.currentPlayerActionIndex += 1
        foolCooldowns.startCooldown(skill, reuseDelayActions: reuseDelay(for: skill))
        updateHeldReadySkills(used: skill); recordPlayerSkill(skill, targetID: id)
        if targets.contains(where: { $0.damage > 0 }) {
            if loadout.talents.has("omen.2"), (foolStates[id]?.illusionStacks ?? 0) > 0 {
                playerShield = min(playerMaxHP, playerShield + strengthenedSkillAmount(15, skill: skill))
            }
            talentDamageCount += 1; talentLastDamageSkill = skill
            talentEchoReady = false; talentFinalEchoReady = false; talentMaskReady = false
            if skill != .fabricatedEvidence { talentEvidenceReady = false }
        }
        log.append(.init(round: round, message: "编排 \(skill.rawValue)：首次命中\(targets.reduce(0) { $0 + $1.damage })", damageTaken: 0, bossMechanicMissed: false))
        return .init(skillID: skill, damage: targets.first?.damage ?? 0, targetID: id, targets: targets)
    }
    public mutating func campaignRecord(_ kind: String, target: String = "", amount: Int = 0, detail: String = "") {
        campaignPrototype?.record(kind, target: target, amount: amount, detail: detail)
    }
    public mutating func campaignFinishRecord() {
        guard outcome != .inProgress, let state = campaignPrototype, !state.events.contains(where: { $0.kind == "outcome" }) else { return }
        campaignRecord("outcome", detail: outcome.rawValue)
        finishRelicBattle()
    }
    public func campaignActorPaused(_ id: String) -> Bool {
        guard let state = campaignPrototype, let enemy = enemies.first(where: { $0.id == id }) else { return false }
        if enemy.contentID == state.scenario.coreID { return state.chargeUntil != nil || state.now < state.recoveryUntil }
        return state.channels[id] != nil
    }
    private func campaignMitigatedDamage(_ damage: Int, to id: String) -> Int {
        guard let state = campaignPrototype, state.scenario.isGuard,
              enemies.contains(where: { $0.id == id && $0.contentID == state.scenario.coreID }) else { return damage }
        let count = enemies.filter { $0.isAlive && $0.contentID == state.scenario.addID }.count
        return damage * (count >= 2 ? 40 : count == 1 ? 75 : 100) / 100
    }
    private mutating func campaignObserveDamage(to id: String, amount: Int) {
        guard var state = campaignPrototype, let target = enemies.first(where: { $0.id == id }),
              let core = enemies.first(where: { $0.contentID == state.scenario.coreID }) else { return }
        state.record("damage", target: id, amount: amount)
        if !core.isAlive {
            state.chargeUntil = nil; state.channels.removeAll(); state.reserveAt = nil; state.poisonRemaining = 0
            campaignPrototype = state; outcome = .victory; campaignFinishRecord(); return
        }
        let adds = enemies.filter { $0.isAlive && $0.contentID == state.scenario.addID }
        if state.scenario.isGuard {
            if state.chargeUntil != nil {
                if target.contentID == state.scenario.coreID { state.chargeDamage += amount }
                let guardKilled = target.contentID == state.scenario.addID && !target.isAlive
                if guardKilled || (adds.isEmpty && state.chargeDamage >= (core.maxHP * 8 + 99) / 100) {
                    state.chargeUntil = nil; state.recoveryUntil = state.now + 3
                    state.record("charge_interrupt", target: id, detail: guardKilled ? "护卫在蓄力期死亡" : "核心有效伤害达到8%")
                }
            }
            if adds.isEmpty, state.reserveAt != nil { state.reserveAt = nil; state.record("reserve_cancel", detail: "到达前清空护卫") }
        } else if var channel = state.channels[id] {
            channel.damage += amount
            if !target.isAlive || channel.damage >= (target.maxHP * 15 + 99) / 100 {
                state.channels[id] = nil; state.record("channel_interrupt", target: id, amount: channel.damage)
            } else { state.channels[id] = channel }
        }
        if !state.phaseTriggered, core.hp * 2 <= core.maxHP {
            state.phaseTriggered = true
            state.record("half_health", target: core.id)
            if state.scenario.isGuard {
                if adds.count == 1 { state.reserveAt = state.now + 4; state.record("reserve_warning", detail: "4秒后护卫抵达；清空护卫可取消") }
            } else {
                state.channels.removeAll(); state.recoveryUntil = state.now + 8
                state.nextMechanic = state.recoveryUntil + 20
                state.record("recovery", amount: 8, detail: "核心暂停攻击，取消所有回流；28秒后下一次回流")
                if adds.count < 2 { state.reserveAt = state.now + 4; state.record("reserve_warning", detail: "4秒后新支援者抵达") }
            }
        }
        campaignPrototype = state
    }
    /// Driver supplies fixed ticks. Repeated/backward/non-finite timestamps cannot replay an event.
    public mutating func advanceCampaignPrototype(at now: Double) {
        guard var state = campaignPrototype, now.isFinite, now > state.now, outcome == .inProgress else { return }
        state.now = now; campaignPrototype = state
        if now >= 180 {
            outcome = .defeat; campaignRecord("timeout"); campaignFinishRecord(); return
        }
        _ = advanceRelicClock(at: now)
        guard outcome == .inProgress, var current = campaignPrototype else { campaignFinishRecord(); return }
        // Deferred real skill hits may change phases at this tick. Read the updated state.
        if let due = current.reserveAt, now + 0.000001 >= due {
            current.reserveAt = nil
            if let content = current.scenario.enemy(current.scenario.addID) {
                let id = content.id + "#reserve"
                enemies.append(.init(id: id, contentID: content.id, name: content.name + "·援军", maxHP: content.maxHP, hp: content.maxHP, attack: content.attack, defense: content.defense, intentPattern: ["strike"], intentIndex: 0, delayedRounds: 0))
                foolStates[id] = .init(targetDefense: content.defense)
                current.record("reserve_arrive", target: id)
            }
        }
        if let due = current.chargeUntil, now + 0.000001 >= due {
            current.chargeUntil = nil; current.recoveryUntil = now + 6
            current.poisonRemaining = 6; current.poisonAt = now + 1
            current.poisonDamage = max(1, (playerNormalMaxHP * 3 + 99) / 100)
            current.poisonBudget = playerNormalMaxHP * 18 / 100
            current.record("charge_release", amount: current.poisonDamage, detail: "6次，每秒一次；核心恢复6秒")
        }
        for id in current.channels.keys.sorted() {
            guard let channel = current.channels[id], now + 0.000001 >= channel.until else { continue }
            current.channels[id] = nil
            guard enemies.contains(where: { $0.id == id && $0.isAlive }),
                  let coreIndex = enemies.firstIndex(where: { $0.contentID == current.scenario.coreID && $0.isAlive }) else { continue }
            let attempted = (enemies[coreIndex].maxHP * 6 + 99) / 100
            let actual = min(attempted, enemies[coreIndex].maxHP - enemies[coreIndex].hp)
            enemies[coreIndex].hp += actual
            current.record("core_heal", target: id, amount: actual, detail: "上限\(attempted)，溢出\(attempted - actual)")
        }
        if now + 0.000001 >= current.nextMechanic, now >= current.recoveryUntil {
            if current.scenario.isGuard {
                current.nextMechanic += 24; current.chargeUntil = now + 4; current.chargeDamage = 0
                current.record("charge_start", detail: "4秒：击杀护卫；无护卫时打掉核心8%生命")
            } else {
                current.nextMechanic += 20
                for add in enemies where add.isAlive && add.contentID == current.scenario.addID {
                    current.channels[add.id] = .init(until: now + 5)
                    current.record("channel_start", target: add.id, detail: "5秒内造成其最大生命15%的有效伤害可打断")
                }
            }
        }
        campaignPrototype = current
        if current.poisonRemaining > 0, now + 0.000001 >= current.poisonAt {
            campaignPrototype?.poisonRemaining -= 1; campaignPrototype?.poisonAt += 1
            let before = playerHP
            let rawDamage = min(current.poisonDamage, current.poisonBudget)
            campaignPrototype?.poisonBudget -= rawDamage
            absorbPlayerDamage(rawDamage, isDamageOverTime: true)
            campaignRecord("poison_tick", amount: before - playerHP, detail: "原始\(rawDamage)")
            if playerHP <= 0 { outcome = .defeat; campaignFinishRecord() }
        }
    }
}


/// A read-only projection of active combat rules. Cooldowns and unlocked passives
/// are deliberately excluded: they are not effects currently on a combatant.
public struct MPCCombatStatus: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let symbol: String
    public let harmful: Bool
    public let count: Int?
    public let countUnit: String
    public init(_ id: String, _ name: String, _ symbol: String, harmful: Bool = false,
                count: Int? = nil, unit: String = "层") {
        self.id = id; self.name = name; self.symbol = symbol; self.harmful = harmful
        self.count = count; self.countUnit = unit
    }
}

extension MPCChapterOneEncounterSession {
    public func playerCombatStatuses(at now: TimeInterval) -> [MPCCombatStatus] {
        guard outcome == .inProgress else { return [] }
        var result: [MPCCombatStatus] = []
        func add(_ id: String, _ name: String, _ symbol: String, _ active: Bool,
                 harmful: Bool = false, count: Int? = nil, unit: String = "层") {
            if active { result.append(.init(id, name, symbol, harmful: harmful, count: count, unit: unit)) }
        }
        add("counter", "反击", "arrow.clockwise", counter.isActive(at: now), count: max(0, Int(ceil((counter.activeUntil ?? now) - now))), unit: "秒")
        add("haste", "急板", "hourglass", now < orderedHasteUntil, count: max(0, Int(ceil(orderedHasteUntil - now))), unit: "秒")
        add("ordered-shield", "悔笔护盾", "shield.fill", orderedShield > 0 && now < orderedShieldUntil, count: orderedShield, unit: "护盾值")
        add("ordered-ward", "突转减伤", "shield.lefthalf.filled", now < orderedWardUntil, count: 1, unit: "次")
        add("shield", "护盾", "shield.fill", playerShield > 0, count: playerShield, unit: "护盾值")
        let maskLive = (ownedManualMaskExpiresAt.map { now < $0 } ?? true) && (timedMasqueradeExpiresAt.map { now < $0 } ?? true)
        add("mask", "幻影", "theatermasks.fill", masqueradeCharges > 0 && maskLive, count: masqueradeCharges, unit: "次")
        add("paper", "纸人反击", "person.fill", paperDoubleCounterCharges > 0, count: paperDoubleCounterCharges, unit: "次")
        add("evade", "闪避", "wind", freeEvasionCharges > 0, count: freeEvasionCharges, unit: "次")
        add("medal", "借命", "heart.fill", isUsurpedLifeMedalActive)
        add("control", "控制封印", "lock.fill", controlSealActive, harmful: true)
        add("skill-seal", "夺名封印", "lock.rectangle.fill", sealedFoolSkillID != nil && now < heroSealExpiresAt, harmful: true)
        add("poison", "翠毒", "drop.fill", isEmeraldPoisonActive, harmful: true, count: emeraldPoisonIntensity)
        add("tower-poison", "毒雾", "cloud.fog.fill", churchFinitePoisonActive, harmful: true)
        add("spittle", "腐蚀", "drop.triangle.fill", churchSpittleActive, harmful: true)
        add("binding", "缠缚", "link", !churchBindingSourceIDs.isEmpty, harmful: true)
        add("campaign-poison", "中毒", "drop.fill", (campaignPrototype?.poisonRemaining ?? 0) > 0, harmful: true)
        add("healing-block", "封疗", "cross.case.fill", now < sequenceNineRelics.healingBlockedUntil, harmful: true)
        add("healing-penalty", "治疗削弱", "heart.slash.fill", healingPenaltyBP > 0, harmful: true)
        add("exposure", "易伤", "exclamationmark.shield.fill", ringExposurePending, harmful: true)
        add("salt", "封存", "lungs.fill", saltBreathingBagStored > 0, harmful: true, count: saltBreathingBagStored, unit: "封存值")
        add("paperweight", "镇纸庇护", "shield.lefthalf.filled", sequenceNineRelics.paperweightCapacity > 0 && now < sequenceNineRelics.paperweightExpiresAt)
        add("anchor", "锚定减伤", "anchor", sequenceNineRelics.anchorCapacity > 0 && sequenceNineRelics.anchorSegments > 0 && now < sequenceNineRelics.anchorExpiresAt, count: sequenceNineRelics.anchorSegments, unit: "次")
        add("blank", "无名隔绝", "rectangle.dashed", sequenceNineRelics.blankCardTargetID != nil && now < sequenceNineRelics.blankCardExpiresAt)
        add("intercept", "队友守护", "person.badge.shield.checkmark.fill", armedInterceptAllyID != nil)
        add("conversion", "封印转化", "arrow.triangle.2.circlepath", sealConversionReady)
        add("applause", "迟到的掌声", "hands.clap.fill", lateApplauseReady)
        add("mirror-thread", "镜潮银线", "link", mirrorThreadBonusReady)
        add("gear-damage", "三证环强化", "bolt.fill", unifiedGearDamageReady)
        add("rewritten-setup", "强化铺垫", "pencil", enhancedSetupStacks > 0, count: enhancedSetupStacks)
        add("hound-opening", "反击机会", "scope", houndOpeningReady)
        add("talent-echo", "幻影回响强化", "waveform", talentEchoReady)
        add("talent-final-echo", "末次幻影强化", "sparkles", talentFinalEchoReady)
        add("talent-mask", "假面强化", "theatermasks.fill", talentMaskReady)
        add("talent-evidence", "污名强化", "doc.text.fill", talentEvidenceReady)
        add("second", "借来的秒针", "clock.fill", borrowedSecondAvailable)
        if let blessing = farewellBlessings?.hero { result.append(.init("blessing", blessing.name, "sparkles")) }
        return result
    }

    public func enemyCombatStatuses(enemyID: String, at now: TimeInterval) -> [MPCCombatStatus] {
        guard outcome == .inProgress, let enemy = enemies.first(where: { $0.id == enemyID && $0.isAlive }) else { return [] }
        var result: [MPCCombatStatus] = []
        func add(_ id: String, _ name: String, _ symbol: String, _ active: Bool,
                 harmful: Bool = false, count: Int? = nil, unit: String = "层") {
            if active { result.append(.init(id, name, symbol, harmful: harmful, count: count, unit: unit)) }
        }
        if let state = foolStates[enemyID] {
            add("illusion", "误认", "eye.trianglebadge.exclamationmark", state.illusionStacks > 0 && now < state.illusionExpiresAt, harmful: true, count: state.illusionStacks)
            add("misalignment", "错位", "arrow.triangle.swap", state.misalignmentStacks > 0 && now < state.misalignmentExpiresAt, harmful: true, count: state.misalignmentStacks)
            add("armor-break", "破甲", "shield.slash.fill", now < state.armorBreakExpiresAt, harmful: true)
            add("evidence", "污名", "doc.text.fill", state.fabricatedEvidenceCharges > 0, harmful: true, count: state.fabricatedEvidenceCharges, unit: "次")
            add("finale", "归谬", "sparkles", state.finaleReady, harmful: true)
        }
        if let stamp = orderedPending.first(where: { $0.target == enemyID && $0.skill == .delayedSignature }), case .signature(let hits) = stamp.kind {
            add("signature", "附言", "envelope.fill", now < stamp.at, harmful: true, count: hits, unit: "次命中")
        }
        let shield = enemyGiftShields[enemyID, default: 0]
        add("gift", "礼盾", "shield.fill", shield > 0, count: shield, unit: "护盾值")
        let pressure = MPCOrderedSkillRules.pressureLayers(mission: chapterMissionNumber, at: now)
        add("ordered-pressure", "追逼", "flame.fill", pressure > 0, count: pressure)
        let fortify = q12FortifyStacks[enemyID, default: 0]
        add("fortify", "固守", "shield.lefthalf.filled", fortify > 0, count: fortify)
        add("defense", "防御强化", "shield.fill", enemyDefenseBoosts[enemyID] != nil)
        add("immune", "免疫", "lock.shield.fill", isTrueImmune(enemy) || isProtectedSovereign(enemy))
        add("empower", "强化", "flame.fill", towerEmpowers[enemyID].map { effect in now < effect.expiresAt && enemies.contains(where: { $0.id == effect.sourceID && $0.isAlive }) } ?? false)
        add("hound-guard", "护体", "shield.fill", chapterMissionNumber == 4 && !counter.isActive(at: now), count: 75, unit: "%减伤")
        add("opening", "破绽", "scope", isQ4OpeningActive && enemy.contentID == "enemy_clockwork_hound", harmful: true)
        add("hunt", "猎名", "pawprint.fill", enemy.contentID == "enemy_clockwork_hound" && houndNameHuntStacks > 0, count: houndNameHuntStacks)
        add("deferred", "迟付伤害", "clock.fill", sequenceNineRelics.deferredDamage?.targetID == enemyID, harmful: true)
        add("mirror", "镜债", "arrow.uturn.backward", sequenceNineRelics.mirrorTargetID == enemyID && now < sequenceNineRelics.mirrorExpiresAt, harmful: true)
        add("blank", "无名隔绝", "rectangle.dashed", sequenceNineRelics.blankCardTargetID == enemyID && now < sequenceNineRelics.blankCardExpiresAt)
        if enemy.contentID == "boss_severian_unified_clock" {
            add("boss-empower", "威能", "bolt.fill", bossEmpowermentStacks > 0, count: bossEmpowermentStacks)
            add("exposed", "暴露", "scope", bossExposedRounds > 0, harmful: true)
        }
        if enemy.contentID == "boss_chronarch_sovereign" {
            add("enrage", "狂暴", "flame.fill", finalBossPhase == 3)
            if let blessing = farewellBlessings?.sovereign { result.append(.init("blessing", blessing.name, "sparkles")) }
        }
        return result
    }
}
