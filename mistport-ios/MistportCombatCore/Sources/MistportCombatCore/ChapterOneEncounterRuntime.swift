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
    public var outfit: MPCOutfit? = nil
    /// The separate bounty slot (MPCBountyRelicCatalog); independent of shop relics.
    public var bountyRelicID: String? = nil

    public var outfitBonus: MPCOutfitBonus { outfit?.bonus ?? .none }

    public func skillLevel(for skillID: FoolSkillID) -> Int {
        MPCSkillGrowth.clampedLevel(skillLevels[skillID, default: 1])
    }

    public init(
        normalSkillIDs: [FoolSkillID] = [
            .sidestepStrike, .maskedWhisper, .identityDisplacement, .fabricatedEvidence,
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
        self.normalSkillIDs = Array(uniqueNormalSkills.prefix(5))
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
                allyHP: Dictionary(uniqueKeysWithValues: MPCChapterOneCatalog.companions.map { ($0.id, 800) }),
                allyMaxHP: Dictionary(uniqueKeysWithValues: MPCChapterOneCatalog.companions.map { ($0.id, 800) })
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

        let skillID: FoolSkillID? = switch (districtID, missionNumber) {
        case ("old-clock", 3): nil
        case ("old-clock", 8): .identityDisplacement
        case ("old-clock", 9): .fabricatedEvidence
        case ("old-clock", 10): .mirrorPursuit
        case ("old-clock", 11): .absurdFinale
        case ("old-clock", 12): .turnTheTables
        case ("old-clock", 13): .namelessStage
        case ("tide-gate", 5): .backstageChange
        default: nil
        }
        guard let skillID else { return nil }
        let wasNew = unlockedSkillIDs.insert(skillID).inserted
        skillUnlockStates[skillID] = .permanent
        if skillID == .namelessStage {
            loadout.isUltimateUnlocked = true
        } else if !loadout.normalSkillIDs.contains(skillID), loadout.normalSkillIDs.count < loadoutSlotCapacity {
            loadout.normalSkillIDs.append(skillID)
        }
        return wasNew ? skillID : nil
    }

    public var ownsManualMask: Bool { ownedRelicIDs.contains(MPCChapterOneCatalog.ownerlessMaskRelicID) }

    /// Compatibility entry point: Q3 now grants a relic, never a skill card.
    public mutating func grantHoundTutorialCard() {
        _ = applyChapterMissionProgress(districtID: "old-clock", missionNumber: 3)
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
        result.normalSkillIDs.removeAll { $0 == .maskedWhisper }
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
        party = session.persistentPartyState()
        if session.mistAnchorWasConsumed {
            depletedRelicIDs.insert("relic_mist_anchor_shard")
        }
        applyPostEncounterRecovery()
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
    case skillOnCooldown(FoolSkillID, remainingActions: Int)
    case skillNotEquipped(FoolSkillID)
    case unknownConsumable
    case noConsumableRemaining
    case noHealingNeeded
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
            if tick.remaining > 1 { finiteDamageTicks[next] = .init(source: tick.source, damage: tick.damage, dueAt: tick.dueAt + 3, remaining: tick.remaining - 1) }
            else { finiteDamageTicks.remove(at: next) }
            if playerHP <= 0 { outcome = .defeat; finishRelicBattle() }
        }
    }
    private mutating func queueFiniteDamage(source: String, damage: Int, ticks: Int = 3) {
        // Same source cannot stack unlimited carpets by repeatedly refreshing a timer.
        guard !finiteDamageTicks.contains(where: { $0.source == source }) else { return }
        finiteDamageTicks.append(.init(source: source, damage: damage, dueAt: relicClock + 3, remaining: ticks))
    }
    private mutating func updateChapterObjective() {
        guard outcome == .inProgress, playerHP > 0, !resolvingEnemyAction, committedEnemyImpacts.isEmpty else { return }
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

    /// 后手改写's cleanse, worst first: thins the emerald fog back to its first concentration
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
        relicClock = max(relicClock, now)
        return hpBefore - playerHP
    }

    /// A delayed actor spends this ready beat without starting a new attack.
    public mutating func consumeEnemyDelay(for id: String) -> Bool {
        guard let index = enemies.firstIndex(where: { $0.id == id }),
              enemies[index].delayedRounds > 0 else { return false }
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
        guard isOwned, outcome == .inProgress, loadout.selectedActiveRelicID == "relic_blank_name_card",
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
        saltBreathingBagStored = 0
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
    private var finaleReadyExpiresAtAction: Int?
    private var blankTicketUsed: Bool
    private var healingPenaltyBP: Int
    private var previousActionCategory: MPCPlayerActionCategory?
    /// Extra misread stacks the next setup card applies (后手改写 1, with the leech vial 2).
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
        var initialAllyHP = party.allyHP
        for id in activeIDs where initialAllyHP[id] == nil { initialAllyHP[id] = 800 }
        var session = Self(
            encounter: encounter,
            waveIndex: 0,
            enemies: [],
            round: 1,
            outcome: .inProgress,
            // Every encounter is a fresh combat instance. Persistent HP may
            // be used by other modes, but chapter stages always begin full.
            playerHP: party.playerMaxHP + loadout.churchGear.maxHP,
            playerBaseMaxHP: party.playerMaxHP + loadout.churchGear.maxHP,
            playerShield: (loadout.passiveIDs.contains("fool_passive_01") ? 50 : 0)
                + (loadout.ritual == .paperWard ? 100 : 0),
            allyHP: initialAllyHP,
            sharedReviveCharges: party.sharedReviveCharges,
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
            finaleReadyExpiresAtAction: nil,
            blankTicketUsed: false,
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
              outcome == .inProgress,
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
        loadout.normalSkillIDs = Array(skills.filter { $0 != .namelessStage && seen.insert($0).inserted }.prefix(5))
    }

    /// Prevents a battle from deadlocking when every equipped action is on
    /// cooldown (notably the opening tutorial, which starts with one card).
    @discardableResult
    public mutating func recoverPlayableSkillIfNeeded() -> FoolSkillID? {
        nil
    }

    @discardableResult
    public mutating func useFoolSkill(
        _ skillID: FoolSkillID,
        targetID: String?,
        usesRealtimeCooldown: Bool = false,
        sealedByPaperweight: Bool? = nil
    ) throws -> MPCFoolSkillEncounterResolution {
        combatHasBegun = true
        activeDamageSource = skillID.rawValue
        defer { activeDamageSource = "other" }
        guard outcome == .inProgress else { throw MPCEncounterRuntimeError.encounterFinished }
        guard loadout.battleSkillIDs.contains(skillID) else {
            throw MPCEncounterRuntimeError.skillNotEquipped(skillID)
        }
        guard usesRealtimeCooldown || foolCooldowns.isAvailable(skillID) else {
            throw MPCEncounterRuntimeError.skillOnCooldown(
                skillID,
                remainingActions: remainingCooldownActions(for: skillID)
            )
        }
        if (sealedByPaperweight ?? willSealPreparedSkill(skillID, at: relicClock)),
           loadout.relicIDs.contains("relic_sealed_paperweight"), relicClock >= sequenceNineRelics.paperweightReadyAt {
            sequenceNineRelics.establishPaperweight(baseHP: playerBaseMaxHP, at: relicClock)
            foolCooldowns.currentPlayerActionIndex += 1
            foolCooldowns.startCooldown(skillID, reuseDelayActions: reuseDelay(for: skillID))
            updateHeldReadySkills(used: skillID)
            triggeredEffects.append("缄卷镇纸：封存第3槽，护层建立")
            return .init(skillID: skillID, damage: 0, targetID: targetID)
        }
        defer { talentLastSkill = skillID }
        expireFinaleReadyIfNeeded()
        let clockSpurBoost = loadout.relicIDs.contains("relic_clock_chaser_spur")
            && readySkillHeldActions[skillID, default: 0] >= 2

        let result: MPCFoolSkillEncounterResolution
        var calculationDetail = "效果技能；最终伤害0"
        switch skillID {
        case .sidestepStrike where controlSealActive && encounter.id == "chapter01_q01_encounter":
            let id = try validatedTargetID(targetID)
            controlSealActive = false
            applyBossActionCategory(.damage)
            result = .init(skillID: skillID, damage: 0, targetID: id)
            calculationDetail = "错步切断控制印记；保护层破除；最终伤害0"
        case .paperDouble:
            paperDoubleCounterCharges = 1
            behaviorTags.insert(.defensiveResponse)
            applyBossActionCategory(.protection)
            result = .init(skillID: skillID, damage: 0, targetID: nil)
            calculationDetail = "召唤纸偶；本回合首次针对玩家的直接攻击由纸偶承受；回合结束消失；最终伤害0"
        case .backstageChange:
            // The skill works on its own: strike out one enemy-applied damage over time and
            // write one extra misread into the next setup card. The leech vial adds a second
            // cleanse and a second extra misread. Relic costs (the needle's healing block)
            // are the player's own bargain and are not cleansed.
            let hasVial = loadout.relicIDs.contains("relic_memory_leech_vial")
            var cleansed = [cleanseOnePlayerDamageOverTime()].compactMap { $0 }
            if hasVial {
                if !memoryLeechCostPaid {
                    playerHP = max(1, playerHP - 40)
                    memoryLeechCostPaid = true
                }
                if let second = cleanseOnePlayerDamageOverTime() { cleansed.append(second) }
                triggeredEffects.append("记忆蛭标本：再净化一次，下一张铺垫再多1层误认")
            }
            enhancedSetupStacks = max(enhancedSetupStacks, hasVial ? 2 : 1)
            triggeredEffects.append("后手改写：" + (cleansed.isEmpty ? "无可净化" : "划去" + cleansed.joined(separator: "、")) + "；下一张铺垫额外\(enhancedSetupStacks)层误认")
            applyBossActionCategory(.setup)
            result = .init(skillID: skillID, damage: 0, targetID: nil)
            calculationDetail = "净化\(cleansed.count)项持续伤害，下一张铺垫额外\(enhancedSetupStacks)层误认；最终伤害0"
        case .namelessStage:
            guard !foolUltimateUsed else { throw FoolBattleError.ultimateAlreadyUsed }
            let hasSeal = loadout.relicIDs.contains("relic_nameless_seal")
            for id in foolStates.keys {
                foolStates[id]?.illusionStacks = hasSeal ? 2 : 4
                foolStates[id]?.finaleReady = true
            }
            sealConversionReady = hasSeal
            foolUltimateUsed = true
            finaleReadyExpiresAtAction = foolCooldowns.currentPlayerActionIndex + 3
            applyBossActionCategory(.setup)
            result = .init(skillID: skillID, damage: 0, targetID: nil)
            calculationDetail = "全体\(hasSeal ? 2 : 4)层误认并准备归结；最终伤害0"
        case .turnTheTables:
            let id = try validatedTargetID(targetID)
            var state = foolStates[id] ?? .init()
            if let boost = enemyDefenseBoosts.removeValue(forKey: id) {
                state.targetDefense = enemies.first(where: { $0.id == id })?.defense ?? state.targetDefense
                state.misalignmentStacks = 1
                triggeredEffects.append("反客为主：驱散\(boost.bonusBP / 100)%防御增益并施加1幕错位")
            } else {
                state.illusionStacks = min(4, state.illusionStacks + 2)
                triggeredEffects.append("反客为主：目标没有可驱散增益，施加2层误认")
            }
            foolStates[id] = state
            applyBossActionCategory(.utility)
            result = .init(skillID: skillID, damage: 0, targetID: id)
            calculationDetail = "驱散防御增益并施加错位；无增益则追加2层误认，最终伤害0"
        default:
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
            if skillID == .identityDisplacement, state.illusionStacks >= 4, sealConversionReady {
                persistentResolutionState.illusionStacks = 4
                sealConversionReady = false
                triggeredEffects.append("无主印章：成功转换保留4层误认，免费机会已用尽")
            }
            foolStates[id] = persistentResolutionState
            if skillID == .identityDisplacement, state.illusionStacks >= 4,
               let index = enemies.firstIndex(where: { $0.id == id }) {
                enemies[index].delayedRounds = max(1, enemies[index].delayedRounds)
                behaviorTags.formUnion([.convertToMisalignment, .reachFourIllusion])
                triggeredEffects.append("身份错置：转换4层误认，目标下次起手延迟一拍；在途攻击不取消")
            }
            if skillID == .maskedWhisper {
                masqueradeCharges = 2
                if loadout.talents.has("phantom.0") { playerShield = min(playerMaxHP, playerShield + strengthenedSkillAmount(30, skill: skillID)) }
                if loadout.talents.has("phantom.4") { talentMaskReady = true }
                triggeredEffects.append("假面谕令：幻影承接接下来的两次敌方攻击；再次施放刷新为两次，不叠加")
            }
            if loadout.passiveIDs.contains("fool_passive_02"),
               skillID == .maskedWhisper || skillID == .fabricatedEvidence,
               unreliableNarratorTriggeredRound != round {
                var passiveState = foolStates[id] ?? resolution.state
                passiveState.illusionStacks = min(4, passiveState.illusionStacks + 1)
                foolStates[id] = passiveState
                unreliableNarratorTriggeredRound = round
                triggeredEffects.append("不可靠叙述者：额外1层误认，本回合承伤增加5%")
            }
            if enhancedSetupStacks > 0, skillID == .maskedWhisper || skillID == .fabricatedEvidence {
                var enhancedState = foolStates[id] ?? resolution.state
                enhancedState.illusionStacks = min(4, enhancedState.illusionStacks + enhancedSetupStacks)
                foolStates[id] = enhancedState
                triggeredEffects.append("强化铺垫：额外施加\(enhancedSetupStacks)层误认")
                enhancedSetupStacks = 0
            }
            if loadout.passiveIDs.contains("fool_passive_03"), skillID == .identityDisplacement {
                let healing = receivePlayerHealing(80)
                triggeredEffects.append("借来的名字：恢复\(healing)生命")
            }
            if skillID == .fabricatedEvidence {
                if loadout.talents.has("omen.0") { var marked = foolStates[id] ?? .init(); marked.illusionStacks = min(4, marked.illusionStacks + 1); foolStates[id] = marked }
                if loadout.talents.has("omen.4") { talentEvidenceReady = true }
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
            let nonTalentDamage = damage
            damage = talentDamage(damage, skill: skillID, stacks: state.illusionStacks, targetID: id)
            damage = strengthenedSkillAmount(damage, skill: skillID)
            if loadout.skillLevel(for: skillID) > 1 {
                modifiers.append("技能Lv.\(loadout.skillLevel(for: skillID))×\(MPCSkillGrowth.multiplierBasisPoints(for: loadout.skillLevel(for: skillID)) / 100)%")
            }
            if damage > 0, state.illusionStacks > 0, loadout.talents.has("omen.2") { playerShield = min(playerMaxHP, playerShield + strengthenedSkillAmount(15, skill: skillID)) }
            // Select the second target before the first hit can spawn children.
            let secondaryAtImpact = enemies.first(where: { $0.isAlive && $0.id != id })
            damage = try applyPartyDamage(damage, to: id, category: actionCategory(for: skillID))
            var affectedTargets = [MPCFoolSkillTargetResolution(targetID: id, damage: damage)]

            // 错步穿行会同时撕开最多两个目标的错误方位。第二个目标
            // 独立保存状态和承受伤害，避免表现层把它当作第一只敌人的复制品。
            if outcome == .inProgress, skillID == .sidestepStrike,
               let secondary = secondaryAtImpact {
                let secondaryState = foolStates[secondary.id]
                    ?? .init(targetDefense: secondary.defense)
                var secondaryCalculationState = secondaryState
                if isUsurpedLifeMedalActive { secondaryCalculationState.attack = secondaryState.attack * 130 / 100 }
                if loadout.relicIDs.contains("relic_cracked_monocle"),
                   secondaryState.illusionStacks == 4 {
                    secondaryCalculationState.targetDefense = secondaryState.targetDefense * 95 / 100
                }
                secondaryCalculationState.targetDefense = talentDefense(secondaryCalculationState.targetDefense, skill: skillID, stacks: secondaryState.illusionStacks)
                let secondaryResolution = try FoolComboSimulator.resolve(
                    skillID: skillID,
                    from: secondaryCalculationState
                )
                var persistedSecondaryState = secondaryResolution.state
                persistedSecondaryState.attack = secondaryState.attack
                persistedSecondaryState.targetDefense = secondaryState.targetDefense
                foolStates[secondary.id] = persistedSecondaryState

                // Reuse the action-wide relic/passive multiplier already consumed above,
                // while retaining this target's own defense and Fool-state calculation.
                var secondaryDamage: Int
                if resolution.totalDamage > 0 {
                    secondaryDamage = max(
                        0,
                        secondaryResolution.totalDamage * nonTalentDamage / resolution.totalDamage
                    )
                } else {
                    secondaryDamage = 0
                }
                secondaryDamage = talentDamage(secondaryDamage, skill: skillID, stacks: secondaryState.illusionStacks, targetID: secondary.id)
                secondaryDamage = strengthenedSkillAmount(secondaryDamage, skill: skillID)
                secondaryDamage = try applyPartyDamage(
                    secondaryDamage,
                    to: secondary.id,
                    category: actionCategory(for: skillID)
                )
                affectedTargets.append(.init(
                    targetID: secondary.id,
                    damage: secondaryDamage
                ))
            }
            if damage > 0 {
                talentDamageCount += 1
                talentLastDamageSkill = skillID
                talentEchoReady = false
                talentFinalEchoReady = false
                talentMaskReady = false
                talentEvidenceReady = false
            }
            if loadout.passiveIDs.contains("fool_passive_04"), resolution.damageHits.count > 1 {
                lateApplauseReady = true
                triggeredEffects.append("迟到的掌声：下一次单段技能已强化")
            }
            if loadout.relicIDs.contains("relic_mirror_thread"), skillID == .mirrorPursuit {
                mirrorThreadBonusReady = true
            }
            if skillID == .sidestepStrike, foolStates[id]?.finaleReady == true {
                finaleReadyExpiresAtAction = foolCooldowns.currentPlayerActionIndex + 3
            }
            result = .init(
                skillID: skillID,
                damage: damage,
                targetID: id,
                targets: affectedTargets
            )
            let hits = resolution.damageHits.map(String.init).joined(separator: "+")
            let modifierText = modifiers.isEmpty ? "无额外倍率" : modifiers.joined(separator: "，")
            calculationDetail = "防御\(state.targetDefense)；基础命中[\(hits)]；\(modifierText)；最终伤害\(damage)"
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
            "；结算后误认\($0.illusionStacks)/错位\($0.misalignmentStacks)/归结\($0.finaleReady ? "是" : "否")"
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
        guard outcome == .inProgress, !activeCompanionIDs.isEmpty else { return [] }
        let playerID = "chapter_one_player"
        var units = [MPCPartyUnitState(
            id: playerID, side: .party, hp: playerHP, maxHP: playerMaxHP, shield: playerShield
        )]
        units += activeCompanionIDs.map {
            MPCPartyUnitState(id: $0, side: .party, hp: allyHP[$0, default: 800], maxHP: 800)
        }
        units += enemies.filter(\.isAlive).map { enemy in
            let content = MPCChapterOneCatalog.enemies.first(where: { $0.id == enemy.contentID })
            return MPCPartyUnitState(
                id: enemy.id, side: .enemy, hp: enemy.hp, maxHP: enemy.maxHP,
                isBoss: content?.rank == .boss, isElite: content?.rank == .elite
            )
        }
        let intentDamage = enemies.filter(\.isAlive).map(\.attack).max() ?? 0
        let state = MPCPartyBattleState(
            playerUnitID: playerID,
            units: units,
            tacticMode: tacticMode,
            sharedReviveCharges: sharedReviveCharges,
            focusTargetUnitID: focusTargetID,
            enemyIntent: MPCKnownEnemyIntent(targetUnitID: playerID, expectedDamage: intentDamage)
        )
        let candidates = Dictionary(uniqueKeysWithValues: activeCompanionIDs.map { id in
            (id, companionCandidates(for: id, playerID: playerID))
        })
        guard let plan = MPCPartyAIPlanner.chooseActions(
            state: state, candidatesByActor: candidates, actorOrder: activeCompanionIDs
        ) else { return [] }

        return plan.actions.compactMap { action in
            applyCompanionAction(action, playerID: playerID)
        }
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
        if sequenceNineRelics.blankCardBlocks(enemyID, at: relicClock) { return 0 }
        let defenseIntents = ["guard", "fortify", "calibrate", "架起防御"]
        var brokeDefense = false
        if !resolvingDeferredDamage, loadout.bountyRelicID == MPCBountyRelicCatalog.brokenSword,
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
        if !resolvingDeferredDamage, isQ4OpeningActive, enemies[index].contentID == "enemy_clockwork_hound" {
            finalDamage = finalDamage * 150 / 100
        }
        if encounter.id == "chapter01_q06_encounter", enemies[index].contentID == "enemy_clockwork_hound",
           houndOpeningReady, finalDamage > 0 {
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
        applyBossActionCategory(category)
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
        expireFinaleReadyIfNeeded()

        var damage: Int
        switch category {
        case .damage:
            let id = try validatedTargetID(targetID)
            if controlSealActive && encounter.id == "chapter01_q01_encounter" {
                applyBossActionCategory(.damage)
                damage = 0
            } else {
                damage = isUsurpedLifeMedalActive ? 78 : 60
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
            if !appliesEmeraldPoison, sequenceNineRelics.blankCardBlocks(enemies[index].id, at: now) { resolvedDamage = 0 }
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
                triggeredEffects.append("假面谕令：幻影承接\(resolvedDamage)伤害，剩余\(masqueradeCharges)次")
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
                damageTaken += resolvedDamage
                absorbPlayerDamage(resolvedDamage)
            }
            if encounter.id == "chapter01_q04_encounter" {
                advanceQ4Clock(at: now)
                if intent == "charge" { q4FirstFlameBlocked = false }
                if intent == "q4_flame_first" { q4FirstFlameBlocked = redirectedByMasquerade }
                if intent == "q4_flame_second" {
                    if q4FirstFlameBlocked && redirectedByMasquerade {
                        q4OpeningUntil = now + 3
                        triggeredEffects.append("猎犬认错名字：3秒内受到伤害提高50%")
                    }
                    q4FirstFlameBlocked = false
                }
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
                defenseBoostBP: result.defenseBoostBP
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

        if playerHP <= 0 {
            if sharedReviveCharges > 0, allyHP.values.contains(where: { $0 > 0 }) {
                sharedReviveCharges -= 1
                playerHP = max(1, playerMaxHP * 3 / 10)
                if loadout.relicIDs.contains("relic_mist_anchor_shard") {
                    grantPlayerShield(playerMaxHP / 10)
                    mistAnchorWasConsumed = true
                    triggeredEffects.append("雾锚碎片：复活后获得护盾")
                }
                log.append(.init(round: round, message: "AI队友使用界锚复原", damageTaken: 0, bossMechanicMissed: false))
            } else if allyHP.isEmpty || allyHP.values.allSatisfy({ $0 <= 0 }) {
                outcome = .defeat
                settleUsurpedLifeMedal()
            }
        }

        resolvingEnemyAction = false
        if outcome != .inProgress { clearEmeraldPoison(); finiteDamageTicks.removeAll() }
        updateChapterObjective()
        round += 1
        if bossExposedRounds > 0 { bossExposedRounds -= 1 }
        if bossPhase == .thirteenthBell { thirteenthBellCountdown = max(1, thirteenthBellCountdown - 1) }
        if outcome == .inProgress && enemies.allSatisfy({ !$0.isAlive }) { advanceWaveOrWin() }
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

    public func persistentPartyState(maxAllyHP: [String: Int] = [:]) -> MPCPartyPersistentState {
        MPCPartyPersistentState(
            playerHP: playerHP,
            playerMaxHP: playerMaxHP,
            allyHP: allyHP,
            allyMaxHP: maxAllyHP,
            sharedReviveCharges: sharedReviveCharges
        )
    }

    private mutating func loadWave(_ index: Int) {
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
            case "chapter01_q05_encounter": 1600
            case "chapter01_q04_encounter": 2200
            case "chapter01_q06_encounter": 1500
            case "chapter01_q07_encounter": 650
            case "chapter01_q08_encounter": MPCProgressionWalls.q8LeechHP
            case "chapter01_q09_encounter": contentID == "enemy_memory_leech_node" ? 850 : 1300
            case "chapter01_q10_encounter": contentID == "enemy_clockwork_hound" ? 1050 : 1200
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
                    maxHP: 260, hp: 0, attack: MPCChapterOneCatalog.enemies.first { $0.id == "enemy_resonant_clock_guard_q2_split" }?.attack ?? 32, defense: 12,
                    intentPattern: ["strike", "strike"], intentIndex: 0, delayedRounds: 0)
            }
        }
        foolStates = Dictionary(uniqueKeysWithValues: enemies.filter(\.isAlive).map {
            ($0.id, FoolComboState(targetDefense: $0.defense))
        })
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
        }
    }

    private func companionCandidates(for companionID: String, playerID: String) -> [MPCAIActionCandidate] {
        guard let companion = MPCChapterOneCatalog.companions.first(where: { $0.id == companionID }) else { return [] }
        var candidates = enemies.filter(\.isAlive).enumerated().map { slot, enemy in
            MPCAIActionCandidate(
                actorUnitID: companionID,
                skillID: companion.role == .construct ? companion.normalSkillIDs[1] : companion.normalSkillIDs[0],
                skillPriority: 10,
                targetUnitID: enemy.id,
                targetSlot: slot,
                kind: .damage,
                magnitude: companion.role == .construct ? 120 : (companion.role == .healer ? 65 : 80),
                supportsPlayerCombo: companion.role == .construct
            )
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
        let companionName = MPCChapterOneCatalog.companions.first(where: { $0.id == action.actorUnitID })?.name ?? action.actorUnitID
        switch action.kind {
        case .damage:
            guard let index = enemies.firstIndex(where: { $0.id == action.targetUnitID && $0.isAlive }) else { return nil }
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
            enemies[index].hp = max(0, enemies[index].hp - magnitude)
            splitQ2GhostIfDefeated(at: index)
            updateBossPhaseIfNeeded()
            if enemies.allSatisfy({ !$0.isAlive }) { advanceWaveOrWin() }
            return .init(companionID: action.actorUnitID, skillID: action.skillID, message: "\(companionName)造成\(magnitude)伤害")
        case .heal:
            let healing = receivePlayerHealing(action.magnitude)
            return .init(companionID: action.actorUnitID, skillID: action.skillID, message: "\(companionName)恢复\(healing)生命")
        case .shield, .protect:
            grantPlayerShield(action.magnitude)
            return .init(companionID: action.actorUnitID, skillID: action.skillID, message: "\(companionName)提供\(action.magnitude)护盾")
        default:
            return .init(companionID: action.actorUnitID, skillID: action.skillID, message: "\(companionName)提供战术支援")
        }
    }

    private mutating func advanceWaveOrWin() {
        clearDefeatedTowerEffects()
        guard committedEnemyImpacts.isEmpty, !resolvingEnemyAction, playerHP > 0, finiteDamageTicks.isEmpty else { return }
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
            // Fixed damage belongs to the early hound lessons only. Later
            // formations use the authored enemy attack and skill multiplier.
            // Q3 is the first lesson and must stay winnable for slow hands (sim 2026-09-29).
            return .attack(encounter.id == "chapter01_q03_encounter" ? MPCProgressionWalls.q3BreathDamage : 260)
        }
        if enemy.contentID == "enemy_clockwork_hound", intent != "name_hunt" {
            houndNameHuntStacks = 0
        }
        if let skill = (MPCChapterOneCatalog.enemies.first(where: { $0.id == enemy.contentID }) ?? MPCChurchBountyCatalog.enemyDefinition(id: enemy.contentID))?.skills.first(where: { $0.intent == intent }) {
            let damageBasisPoints: Int
            if enemy.contentID == "enemy_clockwork_hound", intent == "memory_breath" {
                damageBasisPoints = encounter.id == "chapter01_q05_encounter" ? 1_800 : skill.damageBasisPoints
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
        case "boss_chronarch_sovereign": return ["strike", "thirteenth_charge", "slam", "recover"]
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
    /// A failed Q17/Q22 verification empowers the next blow; the reverse seal caps it.
    private func verificationBlowPercent() -> Int {
        guard chapterVerificationFailed else { return 100 }
        let failed = MPCProgressionWalls.verificationFailPercent[chapterMissionNumber] ?? 100
        return loadout.bountyRelicID == MPCBountyRelicCatalog.reverseSeal ? min(failed, MPCProgressionWalls.reverseSealFailPercent) : failed
    }

    private mutating func resolveChapterThirtyIntent(enemy: MPCRuntimeEnemy, intent: String) -> MPCResolvedEnemyIntent? {
        if enemy.contentID == "boss_chronarch_sovereign" {
            let enraged = enemy.hp * 100 < enemy.maxHP * MPCProgressionWalls.q30EnrageBelowPercent
                && loadout.bountyRelicID != MPCBountyRelicCatalog.lifeLedger
            let multiplier = chapterMissionNumber == 30 ? (enraged ? MPCProgressionWalls.q30EnragePercent : 100)
                : chapterMissionNumber == 29 ? 65 : 100
            let base: Int = switch intent { case "strike": 65; case "thirteenth_charge": 85; case "slam": 110; default: 0 }
            // Q30 wall, tower half: without F90-or-deeper gear the slam takes a share of health.
            if chapterMissionNumber == 30, intent == "slam",
               !MPCProgressionWalls.meetsTowerFloor(mission: 30, gear: loadout.churchGear),
               let share = MPCProgressionWalls.towerCheckBlowHealthPercent[30] {
                return .attack(max(base * multiplier / 100, playerBaseMaxHP * share / 100))
            }
            // Q30 wall: enraged blows take a share of the player's health, so gear cannot race past them.
            if chapterMissionNumber == 30, enraged, base > 0, MPCProgressionWalls.q30EnragedBlowHealthPercent > 0 {
                return .attack(max(base * multiplier / 100, playerBaseMaxHP * MPCProgressionWalls.q30EnragedBlowHealthPercent / 100))
            }
            return .attack(base * multiplier / 100)
        }
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
                if chapterMissionNumber == 22, chapterVerificationFailed, loadout.bountyRelicID != MPCBountyRelicCatalog.reverseSeal {
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

    private mutating func absorbPlayerDamage(_ damage: Int, isDamageOverTime: Bool = false) {
        var adjustedDamage = max(0, !isDamageOverTime && unreliableNarratorTriggeredRound == round ? damage * 105 / 100 : damage)
        if isDamageOverTime, adjustedDamage > 0, loadout.relicIDs.contains("relic_salt_sealed_breathing_bag") {
            let captured = min(adjustedDamage * relicBalance.poisonCapturePercent / 100, max(0, playerBaseMaxHP * relicBalance.poisonCapacityPercent / 100 - saltBreathingBagStored))
            saltBreathingBagStored += captured
            playerHP = min(playerHP, playerMaxHP)
            adjustedDamage -= captured
        }
        if !isDamageOverTime, freeEvasionCharges > 0, adjustedDamage > 0 {
            freeEvasionCharges -= 1
            triggeredEffects.append("未写结局：闪避本次伤害")
            return
        }
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
        case .backstageChange, .namelessStage:
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

    private mutating func expireFinaleReadyIfNeeded() {
        guard let expiration = finaleReadyExpiresAtAction,
              foolCooldowns.currentPlayerActionIndex >= expiration else { return }
        let hasReadyState = foolStates.values.contains(where: \.finaleReady)
        if hasReadyState, loadout.relicIDs.contains("relic_blank_ticket"), !blankTicketUsed {
            blankTicketUsed = true
            finaleReadyExpiresAtAction = nil
            enhancedSetupStacks = max(enhancedSetupStacks, 1)
            triggeredEffects.append("空白戏票：终幕准备被保留一次")
            return
        }
        for id in foolStates.keys {
            foolStates[id]?.finaleReady = false
        }
        finaleReadyExpiresAtAction = nil
    }
}

// MARK: - Isolated campaign mechanics (explicit opt-in; no rewards/save writes)
extension MPCChapterOneEncounterSession {
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
