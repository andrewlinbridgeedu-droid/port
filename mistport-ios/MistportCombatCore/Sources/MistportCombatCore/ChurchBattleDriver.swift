import Foundation

/// One player input in a church-family battle (tower floors, maintenance and street
/// battles, the lights public target). Skills are cast by the automatic sequence, so
/// the only choices a player makes are these. `tick` counts fixed 50 ms steps.
public struct MPCBattleInput: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// Switch the attack target to `enemyID` (must be alive).
        case target
        /// Activate the usurped-life medal.
        case medal
        /// Activate the blank name card against the incoming attack of `enemyID`.
        case blankCard
        /// Use the consumable `itemID`.
        case consumable
        /// Cast the ultimate at the next free player action.
        case ultimate
    }
    public var tick: Int
    public var kind: Kind
    public var enemyID: String?
    public var itemID: String?

    public init(tick: Int, kind: Kind, enemyID: String? = nil, itemID: String? = nil) {
        self.tick = tick; self.kind = kind; self.enemyID = enemyID; self.itemID = itemID
    }
}

/// What a client sends to have a battle settled: the rule version it played under and
/// its inputs. Never the outcome, the loadout or the inventory; the server holds those.
public struct MPCBattleInputLog: Codable, Equatable, Sendable {
    public static let currentVersion = "church-battle-v1"
    public var version: String
    public var encounterID: String
    public var inputs: [MPCBattleInput]

    public init(version: String = Self.currentVersion, encounterID: String, inputs: [MPCBattleInput]) {
        self.version = version; self.encounterID = encounterID; self.inputs = inputs
    }
}

/// Deterministic real-time driver for church-family battles. The same code plays the
/// battle on the device and replays it on the server: the enemy clock (initial delay,
/// contact durations, preparations) and the automatic skill sequence are rules, and
/// only `MPCBattleInput`s come from the player. The enemy timings follow the
/// progression model's tower driver with no jitter; the App must adopt this driver
/// before its outcomes are guaranteed to match a server replay.
public enum MPCChurchBattleDriver {
    public static let step: TimeInterval = 0.05
    public static let maxTicks = 12_000

    public enum Failure: Error, Equatable, Sendable {
        case version(String)
        case encounterMismatch
        /// Inputs must be in tick order, inside the battle, and each one must be legal
        /// when it is applied. An honest client running the same rules never sends a
        /// refused input, so one refusal rejects the whole log.
        case unordered(index: Int)
        case refused(index: Int, input: MPCBattleInput)
        case unsupportedEncounter
    }

    public struct Result: Sendable {
        public let outcome: MPCEncounterOutcome
        public let ticks: Int
        public let playerHP: Int
        public let consumablesUsed: [String: Int]
        public let inputsApplied: Int
        public let session: MPCChapterOneEncounterSession
        public var seconds: TimeInterval { Double(ticks) * MPCChurchBattleDriver.step }
    }

    /// What a policy sees each tick when recording a battle.
    public struct View: Sendable {
        public let tick: Int
        public let session: MPCChapterOneEncounterSession
        public let target: String?
        /// Enemy IDs with a committed attack and the tick at which it lands.
        public let incoming: [String: Int]
        public let loadout: MPCChapterOneLoadout
        public var now: TimeInterval { Double(tick) * MPCChurchBattleDriver.step }
    }

    /// Server side: replays a client's log. Throws if the log is not a legal battle.
    public static func replay(_ log: MPCBattleInputLog, loadout: MPCChapterOneLoadout,
                              consumables: [String: Int] = [:]) throws -> Result {
        guard log.version == MPCBattleInputLog.currentVersion else { throw Failure.version(log.version) }
        if let first = log.inputs.first, first.tick < 0 { throw Failure.unordered(index: 0) }
        for index in log.inputs.indices.dropFirst() where log.inputs[index].tick < log.inputs[index - 1].tick {
            throw Failure.unordered(index: index)
        }
        var stepper = try MPCChurchBattleStepper(encounterID: log.encounterID, loadout: loadout, consumables: consumables)
        var cursor = 0
        while !stepper.isFinished {
            var due: [MPCBattleInput] = []
            while cursor < log.inputs.count, log.inputs[cursor].tick == stepper.tick { due.append(log.inputs[cursor]); cursor += 1 }
            _ = try stepper.step(due)
        }
        // Inputs after the battle ended were never applied; an honest log has none.
        if cursor < log.inputs.count { throw Failure.refused(index: cursor, input: log.inputs[cursor]) }
        return stepper.result
    }

    /// Client side (and tests): plays the battle with a policy and records its inputs.
    public static func record(encounterID: String, loadout: MPCChapterOneLoadout, consumables: [String: Int] = [:],
                              policy: (View) -> [MPCBattleInput]) throws -> (Result, MPCBattleInputLog) {
        var stepper = try MPCChurchBattleStepper(encounterID: encounterID, loadout: loadout, consumables: consumables)
        while !stepper.isFinished {
            // A step can end the battle before inputs are read (poison ticks first);
            // a client sends nothing then, so nothing is recorded.
            let view = stepper.view
            _ = try stepper.step(view.session.outcome == .inProgress ? policy(view) : [])
        }
        return (stepper.result, stepper.log)
    }

    /// The player's contact time for each skill (authored VFX contacts), seconds.
    public static func playerContact(_ skill: FoolSkillID?) -> TimeInterval {
        switch skill {
        case .sidestepStrike?: 0.6192
        case .identityDisplacement?: 0.441
        case .fabricatedEvidence?: 0.543
        case .mirrorPursuit?, .backstageChange?: 0.705
        case .absurdFinale?: 0.885
        case .turnTheTables?: 0.63
        case .namelessStage?: 0.96
        case nil: 0.58
        default: 0.38
        }
    }
}

/// The driver one 50 ms step at a time, for the App: call `step` each time 50 ms of
/// battle time has passed, pass the inputs the player made since the last step, and
/// present the returned events (Unity only animates; it never decides timing or damage).
/// `log` is what the client sends to the server when the battle ends.
public struct MPCChurchBattleStepper: Sendable {
    public typealias Failure = MPCChurchBattleDriver.Failure

    /// What happened in one step, for presentation.
    public struct Events: Sendable, Equatable {
        public struct Cast: Sendable, Equatable {
            /// nil is a basic attack.
            public let skill: FoolSkillID?
            public let targetID: String
            public let landsAtTick: Int
        }
        public struct EnemyAttack: Sendable, Equatable {
            public let enemyID: String
            public let intent: String
            public let landsAtTick: Int
        }
        /// The player starts a cast or basic attack this step.
        public var cast: Cast?
        /// The player's cast that landed this step (its damage is now in the session).
        public var landed: Cast?
        /// Enemies that start an attack this step.
        public var enemyAttacks: [EnemyAttack] = []
        /// Enemies whose attack resolved this step.
        public var enemyResolved: [String] = []
    }

    public let encounterID: String
    public let loadout: MPCChapterOneLoadout
    public private(set) var session: MPCChapterOneEncounterSession
    public private(set) var tick = 0
    public private(set) var target: String?
    public private(set) var consumablesUsed: [String: Int] = [:]
    public private(set) var inputs: [MPCBattleInput] = []

    private let sequence: [FoolSkillID]
    private var scheduler = ContinuousSkillScheduler()
    private var playerAt = 0.0, basicAt = 0.0
    private var hit: Events.Cast?
    private var hitAt = 0.0
    private var ready: [String: TimeInterval] = [:]
    private var pending: [String: TimeInterval] = [:]
    private var ultimateRequested = false, ultimateCast = false

    public init(encounterID: String, loadout: MPCChapterOneLoadout, consumables: [String: Int] = [:]) throws {
        guard encounterID.hasPrefix("church_") else { throw Failure.unsupportedEncounter }
        self.encounterID = encounterID
        self.loadout = loadout
        session = try MPCChapterOneEncounterSession.start(encounterID: encounterID, consumables: consumables,
                                                          companionIDs: [], loadout: loadout)
        sequence = loadout.normalSkillIDs
    }

    public var isFinished: Bool { session.outcome != .inProgress || tick >= MPCChurchBattleDriver.maxTicks }
    public var now: TimeInterval { Double(tick) * MPCChurchBattleDriver.step }
    public var log: MPCBattleInputLog { MPCBattleInputLog(encounterID: encounterID, inputs: inputs) }

    /// What a policy sees before this step's inputs are applied. If its session is already
    /// over, the step ends the battle before reading inputs: send none.
    public var view: MPCChurchBattleDriver.View {
        var s = session
        _ = s.advanceEmeraldPoison(at: now)
        var current = target
        if let id = current, !s.enemies.contains(where: { $0.id == id && $0.isAlive }) { current = nil }
        if current == nil { current = s.enemies.first(where: \.isAlive)?.id }
        return .init(tick: tick, session: s, target: current,
                     incoming: pending.mapValues { Int(($0 / MPCChurchBattleDriver.step).rounded(.up)) }, loadout: loadout)
    }

    public var result: MPCChurchBattleDriver.Result {
        .init(outcome: session.outcome, ticks: tick, playerHP: session.playerHP, consumablesUsed: consumablesUsed,
              inputsApplied: inputs.count, session: session)
    }

    /// Advances one 50 ms step. `inputs` are applied at this step's tick (their own
    /// `tick` is ignored). Throws `refused` if the rules reject one; the step is then void.
    public mutating func step(_ newInputs: [MPCBattleInput] = []) throws -> Events {
        guard !isFinished else { return Events() }
        let step = MPCChurchBattleDriver.step
        var events = Events()
        let now = self.now
        var s = session
        _ = s.advanceEmeraldPoison(at: now)
        guard s.outcome == .inProgress else {
            if !newInputs.isEmpty { throw Failure.refused(index: inputs.count, input: newInputs[0]) }
            session = s; tick += 1
            return events
        }
        var target = self.target
        if let current = target, !s.enemies.contains(where: { $0.id == current && $0.isAlive }) { target = nil }
        if target == nil { target = s.enemies.first(where: \.isAlive)?.id }

        var applied: [MPCBattleInput] = []
        var used = consumablesUsed
        var ultimateRequested = self.ultimateRequested
        for raw in newInputs {
            let input = MPCBattleInput(tick: tick, kind: raw.kind, enemyID: raw.enemyID, itemID: raw.itemID)
            let ok: Bool
            switch input.kind {
            case .target:
                ok = input.enemyID.map { id in s.enemies.contains { $0.id == id && $0.isAlive } } ?? false
                if ok { target = input.enemyID }
            case .medal:
                ok = s.activateUsurpedLifeMedal(isOwned: true, at: now)
            case .blankCard:
                ok = input.enemyID.map { s.activateBlankNameCard(isOwned: true, targetID: $0, at: now) } ?? false
            case .consumable:
                if let item = input.itemID, (try? s.useConsumable(item)) != nil { used[item, default: 0] += 1; ok = true } else { ok = false }
            case .ultimate:
                ok = loadout.isUltimateUnlocked && !ultimateRequested && s.canUseFoolSkill(.namelessStage)
                if ok { ultimateRequested = true }
            }
            guard ok else { throw Failure.refused(index: inputs.count + applied.count, input: input) }
            applied.append(input)
        }
        inputs += applied
        consumablesUsed = used
        self.ultimateRequested = ultimateRequested
        if let current = target { s.updateRelicTarget(current, at: now) }

        if let p = hit, now >= hitAt {
            hit = nil
            if s.enemies.contains(where: { $0.id == p.targetID && $0.isAlive }) {
                if let skill = p.skill { _ = try s.useFoolSkill(skill, targetID: p.targetID, usesRealtimeCooldown: true) }
                else { _ = try s.useBasicAction(.damage, targetID: p.targetID) }
                events.landed = p
            }
        }
        if s.outcome == .inProgress {
            for id in pending.keys.sorted() where now >= pending[id]! {
                pending[id] = nil
                guard s.enemies.contains(where: { $0.id == id }) else { continue }
                try s.endRound(actingEnemyID: id, at: now)
                events.enemyResolved.append(id)
                ready[id] = now
                if s.outcome != .inProgress { break }
            }
        }
        if s.outcome == .inProgress {
            for enemy in s.enemies.filter(\.isAlive) {
                if ready[enemy.id] == nil { ready[enemy.id] = now + (MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID)?.initialDelay ?? 3) }
                guard now >= ready[enemy.id]!, pending[enemy.id] == nil else { continue }
                let preparation = s.authoredPreparationDuration(for: enemy.id)
                if s.churchPreparationMustWait(enemyID: enemy.id, pendingEnemyIDs: Set(pending.keys)) { continue }
                if s.consumeEnemyDelay(for: enemy.id) { ready[enemy.id] = now + 3.2 * enemy.attackIntervalMultiplier; continue }
                let contact = MPCChurchTowerCatalog.contactDuration(contentID: enemy.contentID, intent: enemy.currentIntent)
                s.commitEnemyImpact(from: enemy.id)
                let lands = now + (preparation ?? max(0.15, contact))
                pending[enemy.id] = lands
                events.enemyAttacks.append(.init(enemyID: enemy.id, intent: enemy.currentIntent, landsAtTick: Int((lands / step).rounded(.up))))
            }
        }
        session = s
        self.target = target
        tick += 1
        guard s.outcome == .inProgress, let current = target, s.enemies.contains(where: { $0.id == current && $0.isAlive }),
              now >= playerAt, hit == nil else { return events }
        let chosen: FoolSkillID?
        if ultimateRequested && !ultimateCast && s.canUseFoolSkill(.namelessStage) {
            ultimateCast = true; chosen = .namelessStage; playerAt = now + 1.75
        } else if let skill = scheduler.next(in: sequence, at: now) {
            scheduler.didCast(skill, at: now); chosen = skill; playerAt = now + 1.75
        } else if now >= basicAt {
            basicAt = now + 2.4; chosen = nil; playerAt = now + 1.65
        } else {
            return events
        }
        hitAt = now + MPCChurchBattleDriver.playerContact(chosen)
        let cast = Events.Cast(skill: chosen, targetID: current, landsAtTick: Int((hitAt / step).rounded(.up)))
        hit = cast
        events.cast = cast
        return events
    }
}
