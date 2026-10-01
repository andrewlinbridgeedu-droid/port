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
        /// Story battles: raise the ownerless mask.
        case mask
        /// Story battles: ring the encore bell during a charge.
        case bell
        /// Story battles: reorder the automatic loop; `itemID` lists skill IDs, comma-separated.
        case sequence
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
    public static let currentVersion = "church-battle-v3"
    /// Chapter-one story battles (`MPCStoryBattleStepper`).
    public static let storyVersion = "story-battle-v2"
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
/// only `MPCBattleInput`s come from the player. Since church-battle-v2 the rules are the
/// App's (see `MPCChurchBattleStepper`); the tower verification runner and the
/// progression model drive battles through it too. The App must adopt the stepper
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

    /// Server side: replays a story battle's log with the character the server holds.
    public static func replayStory(_ log: MPCBattleInputLog, loadout: MPCChapterOneLoadout, consumables: [String: Int] = [:],
                                   party: MPCPartyPersistentState = .init(), companionIDs: [String] = [],
                                   mask: MPCStoryBattleStepper.Mask? = nil) throws -> (Result, maskCracksAdded: Int) {
        guard log.version == MPCBattleInputLog.storyVersion else { throw Failure.version(log.version) }
        if let first = log.inputs.first, first.tick < 0 { throw Failure.unordered(index: 0) }
        for index in log.inputs.indices.dropFirst() where log.inputs[index].tick < log.inputs[index - 1].tick {
            throw Failure.unordered(index: index)
        }
        var stepper = try MPCStoryBattleStepper(encounterID: log.encounterID, loadout: loadout, consumables: consumables,
                                                party: party, companionIDs: companionIDs, mask: mask)
        var cursor = 0
        while !stepper.isFinished {
            var due: [MPCBattleInput] = []
            while cursor < log.inputs.count, log.inputs[cursor].tick == stepper.tick { due.append(log.inputs[cursor]); cursor += 1 }
            _ = try stepper.step(due)
        }
        if cursor < log.inputs.count { throw Failure.refused(index: cursor, input: log.inputs[cursor]) }
        return (stepper.result, stepper.maskCracksAdded)
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
    /// `tuning` is for balance models only; a log recorded with any tuning but `.live`
    /// will not replay to the same battle.
    public static func record(encounterID: String, loadout: MPCChapterOneLoadout, consumables: [String: Int] = [:],
                              tuning: MPCChurchBattleStepper.Tuning = .live,
                              policy: (View) -> [MPCBattleInput]) throws -> (Result, MPCBattleInputLog) {
        var stepper = try MPCChurchBattleStepper(encounterID: encounterID, loadout: loadout, consumables: consumables, tuning: tuning)
        while !stepper.isFinished {
            // A step can end the battle before inputs are read (poison ticks first);
            // a client sends nothing then, so nothing is recorded.
            let view = stepper.view
            _ = try stepper.step(view.session.outcome == .inProgress ? policy(view) : [])
        }
        return (stepper.result, stepper.log)
    }

    /// The player's contact time for each skill, seconds: the shipped Unity hero spell
    /// contacts (the App's sealed-skill table uses the same values). nil is a basic attack.
    public static func playerContact(_ skill: FoolSkillID?) -> TimeInterval {
        switch skill {
        case .sidestepStrike?: 0.6192
        case .maskedWhisper?: 0.38
        case .identityDisplacement?: 0.441
        case .fabricatedEvidence?:
            // Unity eases the evidence strike with smoothstep and lands at 86 % of the ease.
            { () -> TimeInterval in
                var low = 0.0, high = 1.0
                for _ in 0..<24 {
                    let middle = (low + high) / 2
                    if middle * middle * (3 - 2 * middle) < 0.86 { low = middle } else { high = middle }
                }
                return 0.95 * (0.38 + 0.25 * (low + high) / 2)
            }()
        case .absurdFinale?: 0.885
        case .turnTheTables?: 0.63
        case .mirrorPursuit?, .backstageChange?: 0.705
        case .namelessStage?: 0.96
        case .paperDouble?: 0.78
        case nil: 0.58
        }
    }
}

/// The driver one 50 ms step at a time, for the App: call `step` each time 50 ms of
/// battle time has passed, pass the inputs the player made since the last step, and
/// present the returned events (Unity only animates; it never decides timing or damage).
/// `log` is what the client sends to the server when the battle ends.
///
/// Rules moved in from the App's `tickContinuousCombat` (church-battle-v2):
/// 1. An enemy that dies with an attack committed has that attack cancelled.
/// 2. A mend or empower whose frozen recipient died is cancelled; the caster may act again at once.
/// 3. A new wave clears every committed enemy attack and enemy clock; a wave that the
///    poison clock opens also drops the player's cast in flight and resets the target.
/// 4. After an attack resolves the enemy may act again at once (0.3 s after the tower's
///    first flame, or its authored recovery delay).
/// 5. Player casts land after the authored Unity contact of the skill (`playerContact`);
///    a skill the sealed paperweight seals lands at the same time, sealed.
/// 6. Fixed 50 ms steps instead of wall-clock time.
/// 7. A high-threat preparation that must wait for another retries after 0.25 s.
/// 8. Enemies without a tower configuration open 2.4 s + 0.35 s per roster slot into the
///    wave (hounds and emerald revenants at once), as in the App.
public struct MPCChurchBattleStepper: Sendable {
    public typealias Failure = MPCChurchBattleDriver.Failure

    /// Timing noise and reaction delay for balance models only. A client and the server
    /// always use `.live`; a log never carries tuning.
    public struct Tuning: Sendable {
        public var jitter: Double
        public var seed: UInt64
        public var actionDelay: Double
        /// Model-only: compare tempo rules (the App and the server always use `.automatic`).
        public var tempo: MPCTempoChoice
        public init(jitter: Double = 0, seed: UInt64 = 1, actionDelay: Double = 0, tempo: MPCTempoChoice = .automatic) {
            self.jitter = jitter; self.seed = seed; self.actionDelay = actionDelay; self.tempo = tempo
        }
        public static let live = Tuning()
    }

    /// What happened in one step, for presentation.
    public struct Events: Sendable, Equatable {
        public struct Cast: Sendable, Equatable {
            /// nil is a basic attack.
            public let skill: FoolSkillID?
            public let targetID: String
            public let landsAtTick: Int
            /// The sealed paperweight seals this cast: skip its renderer, keep its timing.
            public var sealed: Bool = false
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
        /// Enemies whose committed attack was cancelled this step (rules 1 and 2).
        public var enemyCancelled: [String] = []
        /// Set when a new wave began this step: rebuild the battlefield for it.
        public var newWave: Int?
        /// Story battles: Q1 Mara intervention happened this step; show it, then keep stepping.
        public var intervention = false
        /// Combat tempo (CombatTempo.swift): light attacks started, landed and cancelled.
        public struct LightAttack: Sendable, Equatable {
            public let enemyID: String
            public let landsAtTick: Int
        }
        public var lightAttacks: [LightAttack] = []
        public var lightResolved: [MPCLightAttackResolution] = []
        public var lightCancelled: [String] = []
    }

    public let encounterID: String
    public let loadout: MPCChapterOneLoadout
    public let tuning: Tuning
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
    private var random: UInt64
    private var light: MPCLightAttackClock?

    public init(encounterID: String, loadout: MPCChapterOneLoadout, consumables: [String: Int] = [:], tuning: Tuning = .live) throws {
        guard encounterID.hasPrefix("church_") else { throw Failure.unsupportedEncounter }
        self.encounterID = encounterID
        self.loadout = loadout
        self.tuning = tuning
        random = tuning.seed
        session = try MPCChapterOneEncounterSession.start(encounterID: encounterID, consumables: consumables,
                                                          companionIDs: [], loadout: loadout)
        let tempo = tuning.tempo.resolve(encounterID: encounterID)
        session.adoptTempo(tempo)
        light = tempo.map(MPCLightAttackClock.init)
        sequence = loadout.normalSkillIDs
    }

    public var isFinished: Bool { session.outcome != .inProgress || tick >= MPCChurchBattleDriver.maxTicks }
    public var now: TimeInterval { Double(tick) * MPCChurchBattleDriver.step }
    public var log: MPCBattleInputLog { MPCBattleInputLog(encounterID: encounterID, inputs: inputs) }
    private var skillRecovery: TimeInterval { light?.tempo.skillRecovery ?? 1.75 }

    /// What a policy sees before this step's inputs are applied. If its session is already
    /// over, the step ends the battle before reading inputs: send none.
    public var view: MPCChurchBattleDriver.View {
        var s = session
        let wave = s.waveIndex
        _ = s.advanceEmeraldPoison(at: now)
        var current = s.waveIndex == wave ? target : nil
        if let id = current, !s.enemies.contains(where: { $0.id == id && $0.isAlive }) { current = nil }
        if current == nil { current = s.enemies.first(where: \.isAlive)?.id }
        let incoming = s.waveIndex == wave ? pending : [:]
        return .init(tick: tick, session: s, target: current,
                     incoming: incoming.mapValues { Int(($0 / MPCChurchBattleDriver.step).rounded(.up)) }, loadout: loadout)
    }

    public var result: MPCChurchBattleDriver.Result {
        .init(outcome: session.outcome, ticks: tick, playerHP: session.playerHP, consumablesUsed: consumablesUsed,
              inputsApplied: inputs.count, session: session)
    }

    private mutating func variation() -> Double {
        guard tuning.jitter != 0 else { return 0 }
        random = random &* 6364136223846793005 &+ 1442695040888963407
        return (Double((random >> 32) % 10001) / 5000 - 1) * tuning.jitter
    }

    /// Rules 1 and 2: cancels committed attacks that can no longer land.
    private mutating func cancelOrphanedAttacks(_ s: inout MPCChapterOneEncounterSession, at now: TimeInterval, into events: inout Events) {
        for enemy in s.enemies {
            if !enemy.isAlive {
                if s.cancelCommittedEnemyImpact(enemyID: enemy.id, at: now) || pending[enemy.id] != nil {
                    if pending.removeValue(forKey: enemy.id) != nil { events.enemyCancelled.append(enemy.id) }
                }
            } else if pending[enemy.id] != nil, s.cancelTargetedSupport(enemyID: enemy.id, at: now) {
                pending[enemy.id] = nil
                ready[enemy.id] = now
                events.enemyCancelled.append(enemy.id)
            }
        }
    }

    /// Rule 3: a new wave starts with no enemy attacks or enemy clocks carried over.
    private mutating func beginWave(_ index: Int, into events: inout Events) {
        pending.removeAll()
        ready.removeAll()
        light?.reset()
        events.newWave = index
    }

    /// Advances one 50 ms step. `inputs` are applied at this step's tick (their own
    /// `tick` is ignored). Throws `refused` if the rules reject one; the step is then void.
    public mutating func step(_ newInputs: [MPCBattleInput] = []) throws -> Events {
        guard !isFinished else { return Events() }
        let saved = self
        do { return try advance(newInputs) } catch { self = saved; throw error }
    }

    private mutating func advance(_ newInputs: [MPCBattleInput]) throws -> Events {
        let step = MPCChurchBattleDriver.step
        var events = Events()
        let now = self.now
        var s = session
        let waveBefore = s.waveIndex
        _ = s.advanceEmeraldPoison(at: now)
        guard s.outcome == .inProgress else {
            if !newInputs.isEmpty { throw Failure.refused(index: inputs.count, input: newInputs[0]) }
            session = s; tick += 1
            return events
        }
        // Rule 3: the poison clock opened a new wave; nothing else happens this step.
        let poisonWave = s.waveIndex != waveBefore
        if poisonWave {
            beginWave(s.waveIndex, into: &events)
            hit = nil
            target = nil
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
            case .mask, .bell, .sequence:
                // Story-battle inputs; church battles have none of these.
                ok = false
            }
            guard ok else { throw Failure.refused(index: inputs.count + applied.count, input: input) }
            applied.append(input)
        }
        inputs += applied
        consumablesUsed = used
        self.ultimateRequested = ultimateRequested
        if let current = target { s.updateRelicTarget(current, at: now) }
        if poisonWave {
            session = s; self.target = target; tick += 1
            return events
        }
        cancelOrphanedAttacks(&s, at: now, into: &events)

        if let p = hit, now >= hitAt {
            hit = nil
            if s.enemies.contains(where: { $0.id == p.targetID && $0.isAlive }) {
                let wave = s.waveIndex
                if let skill = p.skill {
                    _ = try s.useFoolSkill(skill, targetID: p.targetID, usesRealtimeCooldown: true, sealedByPaperweight: p.sealed)
                } else { _ = try s.useBasicAction(.damage, targetID: p.targetID) }
                events.landed = p
                if s.waveIndex != wave { beginWave(s.waveIndex, into: &events) }
                // Rule 1 again: this cast may have killed an enemy whose attack is in flight.
                cancelOrphanedAttacks(&s, at: now, into: &events)
            }
        }
        if s.outcome == .inProgress {
            for id in pending.keys.sorted() where now >= pending[id]! {
                pending[id] = nil
                guard let actor = s.enemies.first(where: { $0.id == id }) else { continue }
                let intent = actor.currentIntent
                try s.endRound(actingEnemyID: id, at: now)
                events.enemyResolved.append(id)
                // Rule 4.
                ready[id] = now + (intent == "tower_flame_first" ? 0.3 : 0)
                if let delay = s.authoredRecoveryDelay(after: intent, enemyID: id) { ready[id] = now + delay }
                if s.outcome != .inProgress { break }
            }
        }
        if s.outcome == .inProgress {
            for (index, enemy) in s.enemies.enumerated() where enemy.isAlive {
                if ready[enemy.id] == nil {
                    // Rule 8.
                    let opensAtOnce = ["enemy_clockwork_hound", "enemy_emerald_revenant"].contains(enemy.contentID)
                    ready[enemy.id] = now + (MPCChurchTowerCatalog.enemyConfiguration(contentID: enemy.contentID)?.initialDelay
                                             ?? (opensAtOnce ? 0 : 2.4 + Double(index) * 0.35))
                }
                guard now >= ready[enemy.id]!, pending[enemy.id] == nil else { continue }
                // Rule 7.
                if s.churchPreparationMustWait(enemyID: enemy.id, pendingEnemyIDs: Set(pending.keys)) { ready[enemy.id] = now + 0.25; continue }
                let isHound = ["enemy_clockwork_hound", "enemy_emerald_revenant"].contains(enemy.contentID)
                let interval = isHound ? 3.0 : enemy.contentID == "enemy_memory_leech_node" ? 5 : 3.2
                ready[enemy.id] = now + interval * enemy.attackIntervalMultiplier
                if s.consumeEnemyDelay(for: enemy.id) { continue }
                let preparation = s.authoredPreparationDuration(for: enemy.id)
                let contact = MPCChurchTowerCatalog.contactDuration(contentID: enemy.contentID, intent: enemy.currentIntent)
                s.commitEnemyImpact(from: enemy.id)
                let lands = now + (preparation ?? max(0.15, contact + variation()))
                pending[enemy.id] = lands
                events.enemyAttacks.append(.init(enemyID: enemy.id, intent: enemy.currentIntent, landsAtTick: Int((lands / step).rounded(.up))))
            }
        }
        if s.outcome == .inProgress, var clock = light {
            // A delayed enemy skips its turn.
            clock.advance(&s, now: now, step: step, authoredPending: pending, authoredReady: ready,
                          blocked: { $0.delayedRounds > 0 }, into: &events)
            light = clock
        }
        session = s
        self.target = target
        tick += 1
        guard s.outcome == .inProgress, let current = target, s.enemies.contains(where: { $0.id == current && $0.isAlive }),
              now >= playerAt, hit == nil else { return events }
        let chosen: FoolSkillID?
        if ultimateRequested && !ultimateCast && s.canUseFoolSkill(.namelessStage) {
            ultimateCast = true; chosen = .namelessStage; playerAt = now + skillRecovery + tuning.actionDelay
            hitAt = now + MPCChurchBattleDriver.playerContact(chosen)
        } else if let skill = scheduler.next(in: sequence, at: now) {
            scheduler.didCast(skill, at: now); chosen = skill
            playerAt = now + skillRecovery + tuning.actionDelay + max(0, variation())
            hitAt = now + max(0.15, MPCChurchBattleDriver.playerContact(chosen) + variation())
        } else if now >= basicAt {
            basicAt = now + (light?.tempo.basicInterval ?? 2.4); chosen = nil
            playerAt = now + (light?.tempo.basicRecovery ?? 1.65) + tuning.actionDelay + max(0, variation())
            hitAt = now + max(0.15, MPCChurchBattleDriver.playerContact(nil) + variation())
        } else {
            return events
        }
        // Rule 5.
        let sealed = chosen.map { s.willSealPreparedSkill($0, at: now) } ?? false
        let cast = Events.Cast(skill: chosen, targetID: current, landsAtTick: Int((hitAt / step).rounded(.up)), sealed: sealed)
        hit = cast
        events.cast = cast
        return events
    }
}
