import Foundation

/// Explicitly opt-in, save-free combat fixtures. These IDs are NOT formal mission rewards.
public enum MPCCampaignScenario: String, CaseIterable, Codable, Sendable {
    case guardOrdinary, guardHard, relayOrdinary, relayHard
    public var isGuard: Bool { self == .guardOrdinary || self == .guardHard }
    public var isHard: Bool { self == .guardHard || self == .relayHard }
    public var id: String { "sandbox_campaign_" + rawValue }
    public var name: String { (isGuard ? "护卫阵" : "回流阵") + (isHard ? " · 高难" : " · 普通") }
    public var coreID: String { id + "_core" }
    public var addID: String { id + "_add" }
    public var encounter: MPCEncounterContent {
        .init(id: id, name: name, investigationID: "sandbox_only", waves: [.init(enemyIDs: [coreID, addID, addID])], companionSlots: 0, fixedRewardItemIDs: [], firstClearRelicID: nil, recommendedTags: ["prototype-v2", "no-settlement"])
    }
    func enemy(_ id: String) -> MPCEnemyContent? {
        guard id == coreID || id == addID else { return nil }
        let core = id == coreID
        return .init(id: id, name: core ? (isGuard ? "护卫阵核心" : "回流阵核心") : (isGuard ? "护卫" : "回流支援者"), rank: core ? .boss : .elite,
            maxHP: core ? (isHard ? 4200 : 2200) : (isHard ? 1100 : 500),
            attack: core ? (isHard ? 65 : 35) : (isHard ? 36 : 18), defense: core ? 22 : 12,
            intentPattern: ["strike"], teachingPurpose: "隔离战役机制实验，非正式角色", skills: [])
    }
}

public struct MPCCampaignBattleEvent: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let at: Double
    public let kind: String
    public let target: String
    public let amount: Int
    public let detail: String
}
public struct MPCCampaignChannel: Equatable, Sendable {
    public var until: Double
    public var damage: Int = 0
}
public struct MPCCampaignBattleState: Equatable, Sendable {
    public let scenario: MPCCampaignScenario
    public internal(set) var now = 0.0
    public internal(set) var nextMechanic: Double
    public internal(set) var chargeUntil: Double?
    public internal(set) var chargeDamage = 0
    public internal(set) var recoveryUntil = 0.0
    public internal(set) var channels: [String: MPCCampaignChannel] = [:]
    public internal(set) var phaseTriggered = false
    public internal(set) var reserveAt: Double?
    public internal(set) var poisonRemaining = 0
    public internal(set) var poisonAt = 0.0
    public internal(set) var poisonDamage = 0
    public internal(set) var poisonBudget = 0
    public internal(set) var events: [MPCCampaignBattleEvent] = []
    init(_ scenario: MPCCampaignScenario) { self.scenario = scenario; nextMechanic = scenario.isGuard ? 24 : 20 }
    mutating func record(_ kind: String, target: String = "", amount: Int = 0, detail: String = "") {
        events.append(.init(id: events.count, at: now, kind: kind, target: target, amount: amount, detail: detail))
    }
}

/// Fixed 50 ms clock shared by human UI and offline pilots. Render frequency cannot change combat.
public struct MPCCampaignBattleDriver: Sendable {
    public private(set) var session: MPCChapterOneEncounterSession
    public private(set) var scheduler = ContinuousSkillScheduler()
    public private(set) var time = 0.0
    public private(set) var selectedTarget: String?
    public private(set) var actionReadyAt = 0.0
    public private(set) var attacks: [String: Double] = [:]
    public private(set) var minimumHP: Int
    public private(set) var timeBelowQuarterHP = 0.0
    private var nextAttack: [String: Double] = [:]
    private var tick = 0
    private var pending: (skill: FoolSkillID?, target: String, at: Double)?
    private var basicReadyAt = 0.0
    private var medicineReadyAt = 0.0
    public var isComplete: Bool { session.outcome != .inProgress || time >= 180 }
    public var canAct: Bool { !isComplete && time >= actionReadyAt && pending == nil }
    public var basicCooldownRemaining: Double { max(0, basicReadyAt - time) }
    public var canUseMedicine: Bool { !isComplete && time >= medicineReadyAt && session.playerHP < session.playerMaxHP && session.consumables["consumable_pain_salve", default: 0] > 0 }
    public init(scenario: MPCCampaignScenario, gearFloor: Int = 30, passive: String? = nil, medicines: Int = 3, medal: Bool = true) throws {
        let sequence: [FoolSkillID] = [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .absurdFinale]
        var loadout = MPCChapterOneLoadout(normalSkillIDs: sequence, isUltimateUnlocked: false, passiveIDs: [], relicIDs: passive.map { [$0] } ?? [])
        loadout.selectedActiveRelicID = medal ? MPCChapterOneCatalog.usurpedLifeMedalRelicID : nil
        var gear = MPCChurchGearLedger()
        for floor in 1...max(1, min(100, gearFloor)) {
            if let drop = MPCChurchGearCatalog.towerDrop(floor: floor) { gear.grant(drop.id) }
        }
        loadout.churchGear = gear.stats
        let budget = (1...30).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for: $0)?.talentPoints }.reduce(0, +)
        loadout.talents = HermitTalentAllocation.restored((0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" }, budget: budget)
        session = try .start(encounterID: scenario.id, consumables: ["consumable_pain_salve": max(0, medicines)], companionIDs: [], loadout: loadout, campaignPrototype: scenario)
        minimumHP = session.playerHP
        selectedTarget = session.enemies.last?.id
        session.campaignRecord("start", detail: "rules-v2.1; gear=\(gearFloor); passive=\(passive ?? "none"); medicine=\(medicines); medal=\(medal)")
    }
    /// Isolated replay of an authored tower encounter. No first-clear settlement.
    public init(towerFloor: Int, gearFloor: Int = 30, medicines: Int = 0) throws {
        guard let floor = MPCChurchTowerCatalog.floor(number: towerFloor) else { throw MPCEncounterRuntimeError.unknownEncounter }
        try self.init(scenario: .guardOrdinary, gearFloor: gearFloor, medicines: medicines, medal: false)
        session = try .start(encounterID: floor.id, consumables: ["consumable_pain_salve": max(0, medicines)], companionIDs: [], loadout: session.loadout)
        minimumHP = session.playerHP
        selectedTarget = session.enemies.first?.id
    }
    public mutating func select(_ id: String) {
        guard !isComplete, session.enemies.contains(where: { $0.id == id && $0.isAlive }) else { return }
        if selectedTarget != id { session.campaignRecord("target", target: id) }
        selectedTarget = id
        session.updateRelicTarget(id, at: time)
    }
    @discardableResult public mutating func cast(_ skill: FoolSkillID?) -> Bool {
        guard !isComplete, canAct, let id = selectedTarget, session.enemies.contains(where: { $0.id == id && $0.isAlive }) else { return false }
        if let skill {
            guard session.loadout.normalSkillIDs.contains(skill), scheduler.readyAt[skill, default: 0] <= time else { return false }
            scheduler.didCast(skill, at: time)
        } else {
            guard time >= basicReadyAt else { return false }
            basicReadyAt = time + 2.4
        }
        let delay = skill.map { MPCChurchTowerVerificationRunner.playerContact($0) } ?? 0.58
        pending = (skill, id, time + delay)
        actionReadyAt = time + (skill == nil ? 1.65 : 1.75)
        session.campaignRecord("cast", target: id, detail: skill?.rawValue ?? "basic")
        return true
    }
    @discardableResult public mutating func medicine() -> Bool {
        guard canUseMedicine else { return false }
        let before = session.playerHP
        do { try session.useConsumable("consumable_pain_salve") }
        catch { session.campaignRecord("medicine_blocked", detail: String(describing: error)); return false }
        medicineReadyAt = time + 1 // prototype UI debounce, explicit candidate rule
        session.campaignRecord("medicine", amount: session.playerHP - before)
        return true
    }
    @discardableResult public mutating func medal() -> Bool {
        guard !isComplete else { return false }
        let result = session.activateUsurpedLifeMedal(isOwned: true, at: time)
        if result { session.campaignRecord("medal") }
        return result
    }
    public mutating func advance(to requested: Double) throws {
        guard requested.isFinite, requested >= time else { return }
        while Double(tick + 1) * 0.05 <= min(requested, 180) + 0.000001 && session.outcome == .inProgress {
            tick += 1; time = Double(tick) * 0.05
            session.advanceCampaignPrototype(at: time)
            if session.campaignPrototype == nil { _ = session.advanceRelicClock(at: time) }
            minimumHP = min(minimumHP, session.playerHP)
            guard session.outcome == .inProgress else { break }
            // Due enemy contacts precede a same-tick player contact. Paused/dead actors cancel windups.
            for enemy in session.enemies {
                // Authored tower contacts are committed. A dead actor's pending
                // impact must still be released through the runtime, or the
                // final kill/wave transition can remain blocked indefinitely.
                if session.campaignPrototype == nil, !enemy.isAlive, let due = attacks[enemy.id] {
                    if due <= time + 0.000001 {
                        attacks[enemy.id] = nil
                        try session.endRound(actingEnemyID: enemy.id, at: time)
                    }
                    continue
                }
                if !enemy.isAlive || session.campaignActorPaused(enemy.id) {
                    if attacks.removeValue(forKey: enemy.id) != nil { session.campaignRecord("attack_cancel", target: enemy.id) }
                    nextAttack[enemy.id] = time + 0.8
                    continue
                }
                if let due = attacks[enemy.id], due <= time + 0.000001 {
                    attacks[enemy.id] = nil
                    let before = session.playerHP
                    try session.endRound(actingEnemyID: enemy.id, at: time)
                    session.campaignRecord("enemy_hit", target: enemy.id, amount: before - session.playerHP)
                    nextAttack[enemy.id] = session.campaignPrototype == nil ? time : time + (enemy.contentID == session.campaignPrototype?.scenario.coreID ? 3.8 : 4.2)
                }
                if session.outcome != .inProgress { break }
                if nextAttack[enemy.id] == nil {
                    nextAttack[enemy.id] = time + (session.campaignPrototype == nil ? (MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID)?.initialDelay ?? 3) : 2 + Double(session.enemies.firstIndex(where: { $0.id == enemy.id }) ?? 0))
                }
                if attacks[enemy.id] == nil, time >= nextAttack[enemy.id]! {
                    if session.campaignPrototype == nil && session.churchPreparationMustWait(enemyID: enemy.id, pendingEnemyIDs: Set(attacks.keys)) { continue }
                    if session.consumeEnemyDelay(for: enemy.id) { nextAttack[enemy.id] = time + 3.2 * enemy.attackIntervalMultiplier }
                    else {
                        if session.campaignPrototype == nil {
                            session.commitEnemyImpact(from: enemy.id)
                            attacks[enemy.id] = time + (session.authoredPreparationDuration(for: enemy.id) ?? max(0.15, MPCChurchTowerCatalog.contactDuration(contentID: enemy.contentID, intent: enemy.currentIntent)))
                        } else { attacks[enemy.id] = time + 0.8 }
                        session.campaignRecord("attack_windup", target: enemy.id)
                    }
                }
            }
            if session.outcome == .inProgress, let hit = pending, time >= hit.at {
                pending = nil
                if session.enemies.contains(where: { $0.id == hit.target && $0.isAlive }) {
                    if let skill = hit.skill { _ = try session.useFoolSkill(skill, targetID: hit.target, usesRealtimeCooldown: true) }
                    else { _ = try session.useBasicAction(.damage, targetID: hit.target) }
                } else { session.campaignRecord("target_lost", target: hit.target) }
            }
            minimumHP = min(minimumHP, session.playerHP)
            if session.playerHP * 4 < session.playerNormalMaxHP { timeBelowQuarterHP += 0.05 }
        }
        if isComplete {
            pending = nil; attacks.removeAll()
            session.campaignFinishRecord()
            if session.campaignPrototype == nil { session.finishRelicBattle() }
        }
    }
}
