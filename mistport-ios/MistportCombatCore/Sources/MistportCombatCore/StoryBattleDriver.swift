import Foundation

/// The driver for chapter-one story battles (`chapter01_qNN_encounter`), one 50 ms step at
/// a time, so the shared server can replay Q1–Q30 from the player's inputs the same way it
/// replays church battles (user decision 2026-09-30: there is only the shared server).
///
/// Rules follow the App's `tickContinuousCombat()` story path (story-battle-v1):
/// - the automatic skill loop, the 2.4 s basic attack, 1.75 s / 1.65 s player recovery;
///   each cast re-applies the chosen loop (`setContinuousSkillSequence`), as the App does;
/// - player casts land at the authored Unity contacts (`MPCChurchBattleDriver.playerContact`),
///   sealed-paperweight casts included;
/// - enemy clocks: opening delays (hounds at once, Q2 split ghosts 0.5 s + 0.25 s, others
///   2.4 s + 0.35 s per slot, Q6 at once, Q8 2.9 s), attack intervals (3.2 s, hounds 3 s,
///   memory cores 5 s, Q2 ghosts 4 / 4.8 s, Q7 4 / 4.8 s) × the enemy's multiplier;
///   Q4's 20-second hound cycle; Q6 and Q8 recovery; authored preparations and recoveries;
/// - enemy contacts use the Unity timings sampled on 2026-09-15 (the App waits for Unity's
///   callback; the rule is now this table, and animations must match it);
/// - charges with bell timing (the encore bell) wind up for 2 s in Q4, 3 s against the
///   encore revenant and 1.1 s otherwise; ringing the bell defers the release;
/// - Q2 split ghosts reveal one second after they appear (Q24 waits until no attack is in
///   flight); the player does not cast while one is revealing;
/// - Q1 opens with three basic attacks; then Mara, goddess of the Night Church, intervenes
///   (`Events.intervention`; she appears only in the early tutorials and major events),
///   the attacks in flight are dropped, the trial card is granted and the battle goes on;
/// - a new wave drops every enemy attack and clock; one opened by the poison clock also drops
///   the player's cast in flight and resets the target.
/// Inputs add three kinds to the church set: `mask` (the ownerless mask, with its lifetime
/// cracks), `bell` (ring the encore bell during a charge) and `sequence` (reorder the loop).
public struct MPCStoryBattleStepper: Sendable {
    public typealias Failure = MPCChurchBattleDriver.Failure
    public typealias Events = MPCChurchBattleStepper.Events

    /// The ownerless mask as the server holds it: owned, lent for teaching, lifetime cracks.
    public struct Mask: Codable, Equatable, Sendable {
        public var owned: Bool
        public var teachingLoan: Bool
        public var cracks: Int
        public init(owned: Bool = true, teachingLoan: Bool = false, cracks: Int = 0) {
            self.owned = owned; self.teachingLoan = teachingLoan; self.cracks = cracks
        }
    }

    public let encounterID: String
    public let mission: Int
    public let loadout: MPCChapterOneLoadout
    public let tuning: MPCChurchBattleStepper.Tuning
    public private(set) var session: MPCChapterOneEncounterSession
    public private(set) var tick = 0
    public private(set) var target: String?
    public private(set) var consumablesUsed: [String: Int] = [:]
    public private(set) var inputs: [MPCBattleInput] = []
    public private(set) var mask: Mask?
    /// Cracks this battle added to the mask; the server adds them to the character.
    public private(set) var maskCracksAdded = 0
    public private(set) var maskUses = 0

    private var loop: [FoolSkillID]
    private var scheduler = ContinuousSkillScheduler()
    private var playerAt = 0.0, basicAt = -100.0
    private var hit: Events.Cast?
    private var hitAt = 0.0
    private var ready: [String: TimeInterval] = [:]
    private var pending: [String: TimeInterval] = [:]
    private var reveals: [String: TimeInterval] = [:]
    private var revealed: Set<String> = []
    /// Q4's current 20-second hound cycle start, for policies that time the mask.
    public private(set) var q4CycleStart: TimeInterval?
    private var bell = MPCEncoreBellState()
    private var ultimateRequested = false
    private var preludeBasics = 0
    private var preludeRevealAt: TimeInterval?
    private var preludeActive: Bool
    private var random: UInt64
    private var light: MPCLightAttackClock?

    public init(encounterID: String, loadout: MPCChapterOneLoadout, consumables: [String: Int] = [:],
                party: MPCPartyPersistentState = .init(), companionIDs: [String] = [], mask: Mask? = nil,
                tuning: MPCChurchBattleStepper.Tuning = .live, configure: ((inout MPCChapterOneEncounterSession) -> Void)? = nil) throws {
        guard let mission = MPCChapterOneCatalog.mission(forEncounterID: encounterID)?.number, encounterID.hasPrefix("chapter01_")
        else { throw Failure.unsupportedEncounter }
        self.encounterID = encounterID
        self.mission = mission
        self.loadout = loadout
        self.tuning = tuning
        self.mask = mask
        random = tuning.seed
        var session = try MPCChapterOneEncounterSession.start(encounterID: encounterID, party: party, consumables: consumables,
                                                              companionIDs: companionIDs, loadout: loadout)
        configure?(&session)
        let tempo = tuning.tempo.resolve(encounterID: encounterID)
        session.adoptTempo(tempo)
        light = tempo.map(MPCLightAttackClock.init)
        self.session = session
        loop = session.loadout.normalSkillIDs
        preludeActive = mission == 1
    }

    public var isFinished: Bool { session.outcome != .inProgress || tick >= MPCChurchBattleDriver.maxTicks }
    public var now: TimeInterval { Double(tick) * MPCChurchBattleDriver.step }
    public var log: MPCBattleInputLog { MPCBattleInputLog(version: MPCBattleInputLog.storyVersion, encounterID: encounterID, inputs: inputs) }
    public var result: MPCChurchBattleDriver.Result {
        .init(outcome: session.outcome, ticks: tick, playerHP: session.playerHP, consumablesUsed: consumablesUsed,
              inputsApplied: inputs.count, session: session)
    }

    /// Whether the ownerless mask is the manual relic here (the App's `usesManualEmeraldMask`).
    private var usesManualMask: Bool {
        guard let mask, mask.owned, mission >= 3 else { return false }
        return mask.teachingLoan || (session.loadout.selectedActiveRelicID ?? MPCChapterOneCatalog.ownerlessMaskRelicID) == MPCChapterOneCatalog.ownerlessMaskRelicID
    }
    private var isEncoreRevenant: Bool { session.isEncoreEncounter || mission == 19 }
    private var usesBellTiming: Bool {
        mission != 8 && (isEncoreRevenant || session.loadout.relicIDs.contains("relic_encore_bell")
                         || session.enemies.contains { $0.intentPattern.contains("charge") })
    }

    public var view: MPCChurchBattleDriver.View {
        var s = session
        let wave = s.waveIndex
        _ = s.expireOwnedManualMasquerade(at: now)
        s.advanceQ4Clock(at: now)
        _ = s.advanceEmeraldPoison(at: now)
        var current = s.waveIndex == wave ? target : nil
        if let id = current, !s.enemies.contains(where: { $0.id == id && $0.isAlive }) { current = nil }
        if current == nil { current = s.enemies.first(where: \.isAlive)?.id }
        let incoming = s.waveIndex == wave ? pending : [:]
        return .init(tick: tick, session: s, target: current,
                     incoming: incoming.mapValues { Int(($0 / MPCChurchBattleDriver.step).rounded(.up)) }, loadout: loadout)
    }

    /// Whether the mask could be used now (for policies and the App's button).
    public func maskIsReady(at now: TimeInterval) -> Bool {
        guard usesManualMask, let mask else { return false }
        return (mask.teachingLoan || mask.cracks < 10)
            && now >= max(session.ownedManualMaskReadyAt, scheduler.readyAt[.maskedWhisper, default: 0])
    }

    private mutating func variation() -> Double {
        guard tuning.jitter != 0 else { return 0 }
        random = random &* 6364136223846793005 &+ 1442695040888963407
        return (Double((random >> 32) % 10001) / 5000 - 1) * tuning.jitter
    }

    /// Enemy contact after an attack starts: Unity timings sampled 2026-09-15 at 30 fps.
    private func contact(_ enemy: MPCRuntimeEnemy, index: Int) -> TimeInterval {
        let q = mission
        let split = enemy.contentID == "enemy_resonant_clock_guard_q2_split"
        let ghost = enemy.contentID.contains("resonant_clock_guard_q2")
        let hound = ["enemy_clockwork_hound", "enemy_emerald_revenant"].contains(enemy.contentID)
        let core = enemy.contentID == "enemy_memory_leech_node"
        let leech = enemy.contentID.contains("memory_leech") && !core
        var duration = q == 4 ? 0.45 : leech ? 1.1 : ghost ? (split ? 0.68 : 0.94) : hound ? 1.1 : 0.65
        if !hound && !ghost && !core && !leech { duration = 0.967 }
        if core { duration = enemy.currentIntent == "repair_guard" ? 0.85 : 0.833 }
        if leech { duration = 1.067 }
        if q == 6 || q == 10 || (q == 15 && !core) { duration = 2.067 }
        if ["guard", "fortify", "calibrate", "calibration"].contains(enemy.currentIntent) && !core { duration = 0.65 }
        if q == 13 && enemy.currentIntent == "thirteenth_charge" { duration = 2.04 }
        if q == 13 && enemy.currentIntent == "recover" { duration = 0.65 }
        return duration
    }

    private mutating func beginWave(_ index: Int, into events: inout Events) {
        pending.removeAll(); ready.removeAll(); reveals.removeAll(); revealed.removeAll()
        light?.reset()
        q4CycleStart = nil
        session.clearQ4HoundState()
        events.newWave = index
    }

    public mutating func step(_ newInputs: [MPCBattleInput] = []) throws -> Events {
        guard !isFinished else { return Events() }
        let saved = self
        do { return try advance(newInputs) } catch { self = saved; throw error }
    }

    private mutating func advance(_ newInputs: [MPCBattleInput]) throws -> Events {
        let step = MPCChurchBattleDriver.step
        var events = Events()
        let now = self.now
        // Q2 split ghosts are noticed as soon as they stand; each reveals one second later.
        for enemy in session.enemies where enemy.isAlive && enemy.contentID == "enemy_resonant_clock_guard_q2_split"
            && !revealed.contains(enemy.id) && reveals[enemy.id] == nil {
            reveals[enemy.id] = now + 1
        }
        let canReveal = mission != 24 || (pending.isEmpty && hit == nil)
        for (id, at) in reveals.sorted(by: { $0.key < $1.key }) where canReveal && now >= at {
            reveals[id] = nil; revealed.insert(id)
        }

        var s = session
        let waveBefore = s.waveIndex
        _ = s.expireOwnedManualMasquerade(at: now)
        s.advanceQ4Clock(at: now)
        _ = s.advanceEmeraldPoison(at: now)
        guard s.outcome == .inProgress else {
            if !newInputs.isEmpty { throw Failure.refused(index: inputs.count, input: newInputs[0]) }
            session = s; tick += 1
            return events
        }
        let poisonWave = s.waveIndex != waveBefore
        var target = poisonWave ? nil : self.target
        if let current = target, !s.enemies.contains(where: { $0.id == current && $0.isAlive }) { target = nil }
        if target == nil { target = s.enemies.first(where: \.isAlive)?.id }

        // Inputs.
        var applied: [MPCBattleInput] = []
        var used = consumablesUsed
        var ultimateRequested = self.ultimateRequested
        var loop = self.loop
        var mask = self.mask
        var maskCracksAdded = self.maskCracksAdded, maskUses = self.maskUses
        var scheduler = self.scheduler
        var bell = self.bell
        var pending = self.pending, ready = self.ready
        for raw in newInputs {
            let input = MPCBattleInput(tick: tick, kind: raw.kind, enemyID: raw.enemyID, itemID: raw.itemID)
            var ok = false
            switch input.kind {
            case .target:
                ok = input.enemyID.map { id in s.enemies.contains { $0.id == id && $0.isAlive } } ?? false
                if ok { target = input.enemyID }
            case .medal:
                ok = s.activateUsurpedLifeMedal(isOwned: true, at: now)
            case .blankCard:
                ok = input.enemyID.map { s.activateBlankNameCard(isOwned: true, targetID: $0, at: now) } ?? false
            case .consumable:
                if let item = input.itemID, (try? s.useConsumable(item)) != nil { used[item, default: 0] += 1; ok = true }
            case .ultimate:
                ok = loadout.isUltimateUnlocked && !ultimateRequested && s.canUseFoolSkill(.namelessStage)
                if ok { ultimateRequested = true }
            case .mask:
                session = s; self.scheduler = scheduler; self.mask = mask
                if maskIsReady(at: now), let current = mask,
                   (try? s.useOwnedManualMasquerade(targetID: target, isOwned: current.owned, lifetimeCracks: current.cracks, at: now)) ?? nil != nil {
                    if !current.teachingLoan { mask?.cracks = min(10, current.cracks + 1); maskCracksAdded += 1 }
                    scheduler.didCast(.maskedWhisper, at: now)
                    maskUses += 1
                    ok = true
                }
            case .bell:
                if s.canUseEncoreBell, let id = bell.pendingEnemyID, s.enemies.contains(where: { $0.id == id && $0.isAlive }),
                   bell.phase == .windingUp {
                    var next = bell
                    var trial = s
                    if next.ring(at: now), let deadline = next.releaseDeadline, trial.markEncoreDebt(enemyID: id) {
                        bell = next; s = trial
                        pending[id] = deadline; ready[id] = deadline
                        ok = true
                    }
                }
            case .sequence:
                let skills = (input.itemID ?? "").split(separator: ",").compactMap { FoolSkillID(rawValue: String($0)) }
                let allowed = Set(self.loadout.normalSkillIDs + (mission == 1 ? [.sidestepStrike] : []))
                ok = skills.count <= 5 && Set(skills).count == skills.count && !skills.contains(.namelessStage)
                    && Set(skills).isSubset(of: allowed)
                if ok { loop = skills; s.setContinuousSkillSequence(skills) }
            }
            guard ok else { throw Failure.refused(index: inputs.count + applied.count, input: input) }
            applied.append(input)
        }
        inputs += applied
        consumablesUsed = used
        self.ultimateRequested = ultimateRequested
        self.loop = loop
        self.mask = mask
        self.maskCracksAdded = maskCracksAdded; self.maskUses = maskUses
        self.scheduler = scheduler
        self.bell = bell
        self.pending = pending; self.ready = ready
        if let current = target { s.updateRelicTarget(current, at: now) }
        session = s
        self.target = target
        if poisonWave {
            hit = nil
            beginWave(session.waveIndex, into: &events)
            tick += 1
            return events
        }
        s = session

        // The encore bell forgets a charger that died.
        if usesBellTiming, let id = self.bell.pendingEnemyID, !s.enemies.contains(where: { $0.id == id && $0.isAlive }) {
            _ = self.bell.enemyDied(id)
            self.pending[id] = nil
            s.releaseDeadCharger(enemyID: id)
            if s.outcome != .inProgress { session = s; tick += 1; return events }
        }

        // Q1: after three basic attacks Mara intervenes; the battle then goes on
        // with the trial card.
        if let reveal = preludeRevealAt {
            if now >= reveal {
                preludeRevealAt = nil
                preludeActive = false
                self.pending.removeAll(); self.ready.removeAll(); reveals.removeAll(); revealed.removeAll()
                q4CycleStart = nil
                s.clearQ4HoundState()
                _ = s.grantTrialSkill(.sidestepStrike)
                if !self.loop.contains(.sidestepStrike) { self.loop = s.loadout.normalSkillIDs }
                events.intervention = true
            }
            session = s; tick += 1
            return events
        }

        // The player's cast lands.
        if let p = hit, now >= hitAt {
            hit = nil
            if s.enemies.contains(where: { $0.id == p.targetID && $0.isAlive }) {
                let wave = s.waveIndex
                if let skill = p.skill {
                    if !s.loadout.normalSkillIDs.contains(skill) { s.setContinuousSkillSequence([skill] + self.loop) }
                    _ = try s.useFoolSkill(skill, targetID: p.targetID, usesRealtimeCooldown: true, sealedByPaperweight: p.sealed)
                    s.setContinuousSkillSequence(self.loop)
                } else {
                    _ = try s.useBasicAction(.damage, targetID: p.targetID)
                    if preludeActive {
                        preludeBasics += 1
                        if preludeBasics >= 3 { preludeRevealAt = max(now + 0.15, playerAt) }
                    }
                }
                if s.outcome == .inProgress { _ = s.performCompanionActions(focusTargetID: self.target) }
                events.landed = p
                if s.waveIndex != wave { session = s; beginWave(s.waveIndex, into: &events); s = session }
            }
        }
        guard s.outcome == .inProgress, preludeRevealAt == nil else { session = s; tick += 1; return events }

        // Enemy attacks resolve.
        for id in self.pending.keys.sorted() where now >= self.pending[id]! {
            let actor = s.enemies.first { $0.id == id }
            let windup = actor?.currentIntent == "charge"
            self.pending[id] = nil
            if usesBellTiming && windup {
                if self.bell.phase == .deferred { _ = self.bell.consumeReleaseIfDue(at: now) } else { _ = self.bell.completeCharge() }
                self.ready[id] = now
            }
            guard s.outcome == .inProgress, let actor else { continue }
            try s.endRound(actingEnemyID: id, at: now)
            events.enemyResolved.append(id)
            if let delay = s.authoredRecoveryDelay(after: actor.currentIntent, enemyID: id) { self.ready[id] = now + delay }
            if mission == 4, actor.currentIntent == "q4_flame_second" { q4CycleStart = (q4CycleStart ?? now) + 20 }
            if mission == 6 { self.ready[id] = now }
            if mission == 8 {
                self.ready[id] = now + (actor.currentIntent == "parasite" ? (actor.intentIndex % 5 < 2 ? 1.9 : 0.9)
                                        : actor.currentIntent == "charge" ? 0.9 : 2.9)
            }
            if s.outcome != .inProgress { break }
        }
        guard s.outcome == .inProgress else { session = s; tick += 1; return events }

        // Enemies start attacks, independently of the player.
        for (index, enemy) in s.enemies.enumerated() where enemy.isAlive {
            let split = enemy.contentID == "enemy_resonant_clock_guard_q2_split"
            if split && !revealed.contains(enemy.id) { continue }
            let hound = ["enemy_clockwork_hound", "enemy_emerald_revenant"].contains(enemy.contentID)
            let core = enemy.contentID == "enemy_memory_leech_node"
            let ghost = enemy.contentID == "enemy_resonant_clock_guard_q2" || split
            if self.ready[enemy.id] == nil {
                self.ready[enemy.id] = hound ? now : now + (split ? 0.5 + Double(index % 2) * 0.25 : 2.4 + Double(index) * 0.35)
                if mission == 6 { self.ready[enemy.id] = now }
                if mission == 8 { self.ready[enemy.id] = now + 2.9 }
            }
            if mission == 4 {
                if q4CycleStart == nil { q4CycleStart = now }
                let offset: Double = switch enemy.currentIntent {
                case "q4_probe": 2
                case "charge": 6
                case "q4_flame_first": 8
                default: 8.65
                }
                self.ready[enemy.id] = q4CycleStart! + offset
            }
            guard now >= self.ready[enemy.id]!, self.pending[enemy.id] == nil else { continue }
            self.ready[enemy.id] = now + (ghost ? (index.isMultiple(of: 2) ? 4.0 : 4.8) : hound ? 3.0 : core ? 5 : 3.2) * enemy.attackIntervalMultiplier
            if mission == 7 { self.ready[enemy.id] = now + (core ? 4 : 4.8) }
            if s.consumeEnemyDelay(for: enemy.id) {
                if mission == 8 { self.ready[enemy.id] = now + 4 }
                continue
            }
            let lands: TimeInterval
            if let duration = s.authoredPreparationDuration(for: enemy.id) {
                lands = now + duration; self.ready[enemy.id] = lands
            } else if enemy.contentID == "enemy_archive_gatekeeper", ["guard", "recover"].contains(enemy.currentIntent) {
                lands = now + (enemy.currentIntent == "recover" ? MPCChapterOneEncounterSession.archiveRecoveryDuration : 3)
                self.ready[enemy.id] = lands
            } else if mission == 8, enemy.currentIntent == "charge" {
                lands = now + 2; self.ready[enemy.id] = lands
            } else if usesBellTiming, enemy.currentIntent == "charge" {
                lands = now + (mission == 4 ? 2.0 : isEncoreRevenant ? 3.0 : 1.1)
                self.bell.beginCharge(enemyID: enemy.id, startedAt: now, windupDeadline: lands)
                self.ready[enemy.id] = lands
            } else {
                lands = now + max(0.15, contact(enemy, index: index) + variation())
            }
            s.commitEnemyImpact(from: enemy.id)
            self.pending[enemy.id] = lands
            events.enemyAttacks.append(.init(enemyID: enemy.id, intent: enemy.currentIntent, landsAtTick: Int((lands / step).rounded(.up))))
        }
        if s.outcome == .inProgress, var clock = light {
            // No light bites while the hound stands open after its twin flames (the mask's
            // payoff), nor from a delayed or unrevealed enemy.
            let q4Open = (s.q4OpeningUntil ?? -1) > now
            let revealed = self.revealed
            clock.advance(&s, now: now, step: step, authoredPending: pending, authoredReady: ready,
                          blocked: { enemy in
                              q4Open || enemy.delayedRounds > 0
                                  || (enemy.contentID == "enemy_resonant_clock_guard_q2_split" && !revealed.contains(enemy.id))
                          }, into: &events)
            light = clock
        }
        session = s
        tick += 1

        // The player's next action.
        guard reveals.isEmpty, now >= playerAt, hit == nil,
              let current = self.target.flatMap({ id in s.enemies.first { $0.id == id && $0.isAlive } }) ?? s.enemies.first(where: \.isAlive)
        else { return events }
        let automatic = usesManualMask ? self.loop.filter { $0 != .maskedWhisper } : self.loop
        let chosen: FoolSkillID?
        let requested: FoolSkillID? = self.ultimateRequested && loadout.isUltimateUnlocked && s.canUseFoolSkill(.namelessStage) ? .namelessStage : nil
        if !preludeActive, let skill = requested ?? scheduler.next(in: automatic, at: now) {
            if skill == .namelessStage { self.ultimateRequested = false }
            session.setContinuousSkillSequence(self.loop)
            self.scheduler.didCast(skill, at: now)
            playerAt = now + (light?.tempo.skillRecovery ?? 1.75) + tuning.actionDelay + (skill == .namelessStage ? 0 : max(0, variation()))
            chosen = skill
        } else if now >= basicAt + (light?.tempo.basicInterval ?? 2.4) {
            basicAt = now
            playerAt = now + (light?.tempo.basicRecovery ?? 1.65) + tuning.actionDelay + max(0, variation())
            chosen = nil
        } else {
            return events
        }
        let sealed = chosen.map { session.willSealPreparedSkill($0, at: now) } ?? false
        hitAt = now + (chosen == .namelessStage ? MPCChurchBattleDriver.playerContact(chosen) : max(0.15, MPCChurchBattleDriver.playerContact(chosen) + variation()))
        let cast = Events.Cast(skill: chosen, targetID: current.id, landsAtTick: Int((hitAt / step).rounded(.up)), sealed: sealed)
        hit = cast
        events.cast = cast
        return events
    }
}
