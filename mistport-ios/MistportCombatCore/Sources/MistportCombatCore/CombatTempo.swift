import Foundation

/// Combat tempo (COMBAT_TEMPO_PLAN_20261001.md, user-approved 2026-10-01). The fight
/// gets denser without getting deadlier: light attacks fill the time between each enemy's
/// authored actions; authored hits get lighter to keep the damage per second; the
/// player's basic attack comes twice as often for half the damage and recovers faster.
///
/// Light attacks never use up a count-based defence (the mask's phantom, the paper
/// double, the free evasion): while the phantom stands, it parries them for half damage.
/// Shields, damage reduction and the blank card's window still apply.
///
/// Samples first (user 2026-10-01): only `sampleEncounterIDs` use it until the user
/// approves them on device; every other battle keeps its current rules.
public struct MPCCombatTempo: Equatable, Sendable {
    public init(lightInterval: TimeInterval, lightWindup: TimeInterval, lightOpening: TimeInterval, lightOpeningPerSlot: TimeInterval,
                lightAttackPercent: Int, authoredDamagePercent: Int, parryPercent: Int, authoredClearance: TimeInterval,
                basicInterval: TimeInterval, basicRecovery: TimeInterval, skillRecovery: TimeInterval, basicDamagePercent: Int) {
        self.lightInterval = lightInterval; self.lightWindup = lightWindup; self.lightOpening = lightOpening
        self.lightOpeningPerSlot = lightOpeningPerSlot; self.lightAttackPercent = lightAttackPercent
        self.authoredDamagePercent = authoredDamagePercent; self.parryPercent = parryPercent
        self.authoredClearance = authoredClearance; self.basicInterval = basicInterval; self.basicRecovery = basicRecovery
        self.skillRecovery = skillRecovery; self.basicDamagePercent = basicDamagePercent
    }
    /// Seconds between one enemy's light attacks.
    public let lightInterval: TimeInterval
    /// From the light attack's start to its contact.
    public let lightWindup: TimeInterval
    /// First light attack: this, plus `lightOpeningPerSlot` for each roster slot.
    public let lightOpening: TimeInterval
    public let lightOpeningPerSlot: TimeInterval
    /// A light hit is this share of the enemy's attack, before damage reduction.
    public let lightAttackPercent: Int
    /// Authored enemy hits deal this share of their former damage.
    public let authoredDamagePercent: Int
    /// What a light hit still does while the phantom parries it.
    public let parryPercent: Int
    /// No light attack starts this close before the enemy's next authored action.
    public let authoredClearance: TimeInterval
    public let basicInterval: TimeInterval
    public let basicRecovery: TimeInterval
    public let skillRecovery: TimeInterval
    public let basicDamagePercent: Int

    public static let standard = MPCCombatTempo(
        lightInterval: 1.4, lightWindup: 0.35, lightOpening: 0.8, lightOpeningPerSlot: 0.25,
        lightAttackPercent: 15, authoredDamagePercent: 70, parryPercent: 50, authoredClearance: 0.85,
        basicInterval: 1.2, basicRecovery: 0.8, skillRecovery: 1.1, basicDamagePercent: 50)

    /// The three sample battles: Q4 the hound's twin flames, tower floor 1 (D01 stone
    /// jaw), bounty B01 (No. 7 hollow).
    public static let sampleEncounterIDs: Set<String> = ["chapter01_q04_encounter", "church_tower_001", "church_bounty_b01"]

    /// Light-hit size per battle, calibrated with the progression simulator (`ProgressionSim
    /// tempo`) so the player ends with about the HP they ended with before: Q4's hound
    /// attacked seldom, so its bites are small; B01's ambush lost the most to the 70% scale.
    static let lightAttackPercentByEncounter: [String: Int] = [
        "chapter01_q04_encounter": 5, "church_tower_001": 15, "church_bounty_b01": 22]

    public static func profile(encounterID: String) -> MPCCombatTempo? {
        guard sampleEncounterIDs.contains(encounterID) else { return nil }
        return standard.with(lightAttackPercent: lightAttackPercentByEncounter[encounterID] ?? standard.lightAttackPercent)
    }

    public func with(lightAttackPercent: Int) -> MPCCombatTempo {
        MPCCombatTempo(lightInterval: lightInterval, lightWindup: lightWindup, lightOpening: lightOpening,
                       lightOpeningPerSlot: lightOpeningPerSlot, lightAttackPercent: lightAttackPercent,
                       authoredDamagePercent: authoredDamagePercent, parryPercent: parryPercent, authoredClearance: authoredClearance,
                       basicInterval: basicInterval, basicRecovery: basicRecovery, skillRecovery: skillRecovery,
                       basicDamagePercent: basicDamagePercent)
    }

    /// Per enemy: hounds bite a little faster, memory-leech cores pulse slower. Tutorial
    /// missions (Q1–Q3) and the final boss (Q28–Q30) get 2.0 s and 1.2 s once rolled out.
    public func lightInterval(contentID: String) -> TimeInterval {
        if ["enemy_clockwork_hound", "enemy_emerald_revenant"].contains(contentID) { return lightInterval * 13 / 14 }
        if contentID == "enemy_memory_leech_node" { return lightInterval * 25 / 14 }
        return lightInterval
    }
}

/// Which tempo a stepper runs. The App and the server always use `.automatic`.
public enum MPCTempoChoice: Sendable, Equatable {
    case automatic, off
    case custom(MPCCombatTempo)
    public func resolve(encounterID: String) -> MPCCombatTempo? {
        switch self {
        case .automatic: MPCCombatTempo.profile(encounterID: encounterID)
        case .off: nil
        case .custom(let tempo): tempo
        }
    }
}

/// One light attack's outcome, for presentation (a "招架" popup when parried).
public struct MPCLightAttackResolution: Equatable, Sendable {
    public let enemyID: String
    /// Damage after parry and damage reduction, before shields.
    public let damage: Int
    public let parried: Bool
}

/// What a battle looked like, for tempo calibration: how dense and how spiky.
public struct MPCTempoStats: Equatable, Sendable {
    public private(set) var lightHits = 0
    public private(set) var parries = 0
    public private(set) var authoredHits = 0
    /// Largest single hit on the player, as a share of maximum HP (basis points).
    public private(set) var largestLightBP = 0
    public private(set) var largestAuthoredBP = 0
    /// Starts and landings of attacks and casts: what the player sees happen.
    public private(set) var visibleEvents = 0
    public init() {}

    public mutating func record(_ events: MPCChurchBattleStepper.Events, session: MPCChapterOneEncounterSession) {
        let maxHP = max(1, session.playerMaxHP)
        visibleEvents += (events.cast == nil ? 0 : 1) + (events.landed == nil ? 0 : 1)
            + events.enemyAttacks.count + events.enemyResolved.count + events.lightAttacks.count + events.lightResolved.count
        for hit in events.lightResolved {
            lightHits += 1
            if hit.parried { parries += 1 }
            largestLightBP = max(largestLightBP, hit.damage * 10_000 / maxHP)
        }
        for id in events.enemyResolved {
            for r in session.lastEnemyActionResolutions where r.enemyID == id && r.playerDamage > 0 {
                authoredHits += 1
                largestAuthoredBP = max(largestAuthoredBP, r.playerDamage * 10_000 / maxHP)
            }
        }
    }
}

/// Light-attack timing for one battle, shared by the church and story steppers. Public
/// so the App's own battle loop can use the very same rules until it runs on the steppers.
public struct MPCLightAttackClock: Sendable {
    public let tempo: MPCCombatTempo
    private var ready: [String: TimeInterval] = [:]
    private var pending: [String: TimeInterval] = [:]

    public init(tempo: MPCCombatTempo) { self.tempo = tempo }

    /// Authored intents during which an enemy makes no light attack: every charge, so the
    /// telegraph reads clearly. In recovery (the player's output window) it still flails,
    /// at half the rate.
    public static func holdsLightAttacks(_ intent: String) -> Bool { intent.contains("charge") }

    public mutating func reset() { ready.removeAll(); pending.removeAll() }

    /// Lands due light attacks, then starts new ones. `authoredPending` are enemies whose
    /// authored attack is in flight; `authoredReady` is when each may start its next one.
    /// `blocked` holds an enemy back (charging, stunned, recovering, departed).
    public mutating func advance(_ s: inout MPCChapterOneEncounterSession, now: TimeInterval, step: TimeInterval,
                          authoredPending: [String: TimeInterval], authoredReady: [String: TimeInterval],
                          blocked: (MPCRuntimeEnemy) -> Bool, into events: inout MPCChurchBattleStepper.Events) {
        for id in pending.keys.sorted() where now >= pending[id]! {
            pending[id] = nil
            guard s.outcome == .inProgress else { break }
            if let hit = s.resolveLightAttack(enemyID: id, at: now) { events.lightResolved.append(hit) }
            else { events.lightCancelled.append(id) }
        }
        guard s.outcome == .inProgress else { return }
        for (index, enemy) in s.enemies.enumerated() {
            guard enemy.isAlive, !enemy.hasDeparted else {
                if pending.removeValue(forKey: enemy.id) != nil { events.lightCancelled.append(enemy.id) }
                continue
            }
            if ready[enemy.id] == nil { ready[enemy.id] = now + tempo.lightOpening + Double(index) * tempo.lightOpeningPerSlot }
            guard now >= ready[enemy.id]!, pending[enemy.id] == nil, !blocked(enemy) else { continue }
            let clearance = tempo.lightWindup + tempo.authoredClearance
            if let lands = authoredPending[enemy.id] {
                // An authored action in flight: light attacks go on through a stance (guard,
                // armour, mirror) but never through a telegraphed charge or the player's
                // recovery window, and stop short of the authored hit.
                if Self.holdsLightAttacks(enemy.currentIntent) || lands - now < clearance { continue }
            } else if let next = authoredReady[enemy.id], next - now < clearance { continue }
            ready[enemy.id] = now + tempo.lightInterval(contentID: enemy.contentID) * (enemy.currentIntent == "recover" ? 2 : 1)
            let lands = now + tempo.lightWindup
            pending[enemy.id] = lands
            events.lightAttacks.append(.init(enemyID: enemy.id, landsAtTick: Int((lands / step).rounded(.up))))
        }
    }
}
