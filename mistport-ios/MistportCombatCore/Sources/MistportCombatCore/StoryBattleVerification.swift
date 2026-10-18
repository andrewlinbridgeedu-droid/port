import Foundation

/// What a player legally holds before story mission `n` on the ordered-card rules (2026-10-12):
/// the cards unlocked by then, their slots, chapter talent points spent on 诡术 then 秘兆, the two
/// dust upgrades, the ultimate after Q13, the medal after Q4 and the return clasp from the Q4 shop.
/// Tower gear and the bounty slot are the caller's; the hero wears the App's default outfit, as every App
/// battle wears one. A tower floor first cleared after Qs plays with the loadout before Q(s+1). Shared by
/// the balance tests, the tower runner and tools/progression-sim.
public enum MPCStageLoadout {
    public static func available(before n: Int) -> [FoolSkillID] {
        MPCOrderedSkillRules.ordinarySkills.filter { (MPCOrderedSkillRules.unlockMission($0) ?? 99) <= n }
    }
    public static func capacity(before n: Int) -> Int { min(MPCOrderedSkillRules.slotCapacity(availableThrough: n), available(before: n).count) }
    public static func talentBudget(before n: Int) -> Int {
        (1..<max(1, n)).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for: $0)?.talentPoints }.reduce(0, +)
    }
    public static func talents(budget: Int) -> HermitTalentAllocation {
        .restored((0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" }, budget: budget)
    }
    /// Every tower piece through `floor`, the strongest of each slot worn.
    public static func towerGear(through floor: Int) -> MPCChurchGearStats {
        var ledger = MPCChurchGearLedger()
        if floor > 0 { for f in 1...floor { if let drop = MPCChurchGearCatalog.towerDrop(floor: f) { ledger.grant(drop.id) } } }
        return ledger.stats
    }
    /// Tower gear for every floor the walls up to `q` name, nothing deeper.
    public static func wallGear(beforeOrAt q: Int) -> MPCChurchGearStats {
        towerGear(through: MPCProgressionWalls.walls.filter { $0.mission <= q }.compactMap(\.towerFloor).max() ?? 0)
    }
    /// The bounty relic a mechanism wall at `q` asks for, if any.
    public static func wallRelic(_ q: Int) -> String? {
        MPCProgressionWalls.wall(mission: q)?.caseID.flatMap { MPCBountyRelicCatalog.relic(forCase: $0)?.id }
    }
    public static func loadout(before n: Int, order: [FoolSkillID], gear: MPCChurchGearStats = .init(), bountyRelic: String? = nil,
                               passive: String? = MPCChapterOneCatalog.returnGiftClaspRelicID, talentBudget budget: Int? = nil,
                               activeRelic: String? = nil, outfit: MPCOutfit? = .mistportNight) -> MPCChapterOneLoadout {
        var l = MPCChapterOneLoadout(normalSkillIDs: order, isUltimateUnlocked: n >= 14, passiveIDs: [], relicIDs: n >= 5 ? passive.map { [$0] } ?? [] : [])
        l.churchGear = gear
        l.outfit = outfit
        l.bountyRelicID = bountyRelic
        l.selectedActiveRelicID = activeRelic ?? (n <= 9 ? MPCChapterOneCatalog.ownerlessMaskRelicID : MPCChapterOneCatalog.usurpedLifeMedalRelicID)
        l.talents = talents(budget: budget ?? talentBudget(before: n))
        // Earned dust only: Q9 pays 30 (one Lv2), Q14 the next 30.
        if n >= 10 { l.skillLevels[.mirrorPursuit] = 2 }
        if n >= 15 { l.skillLevels[.absurdFinale] = 2 }
        return l
    }
    /// The tower and church hand before Q`n`: 抢拍 speeds 悔笔's shield and 燃镜's six hits, 错步 cuts
    /// through three minions (2026-10-15: the steadiest arrangement on the calibrated floors).
    public static func towerHand(before n: Int) -> [FoolSkillID] {
        n < 10 ? [.stolenTempo, .sidestepStrike, .backstageChange] : [.stolenTempo, .backstageChange, .sidestepStrike, .mirrorBarrage]
    }
    /// The card families the production audit arranges from Q10 on; below Q10 it tries every hand.
    public static let families: [[FoolSkillID]] = [
        [.stolenTempo, .mirrorBarrage, .sidestepStrike, .fabricatedEvidence],
        [.stolenTempo, .mirrorBarrage, .identityDisplacement, .absurdFinale],
        [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .absurdFinale],
        [.stolenTempo, .delayedSignature, .mirrorBarrage, .backstageChange],
        [.turnTheTables, .mirrorPursuit, .absurdFinale, .backstageChange],
        [.stolenTempo, .sidestepStrike, .backstageChange, .mirrorBarrage],
        [.fabricatedEvidence, .identityDisplacement, .absurdFinale, .backstageChange]
    ]
    /// The audit lines before mission `n`: each legal arrangement once.
    public static func orders(before n: Int) -> [[FoolSkillID]] {
        func permutations(_ cards: [FoolSkillID]) -> [[FoolSkillID]] {
            guard cards.count > 1 else { return [cards] }
            return cards.flatMap { first in permutations(cards.filter { $0 != first }).map { [first] + $0 } }
        }
        func combinations(_ cards: [FoolSkillID], _ count: Int) -> [[FoolSkillID]] {
            if count == 0 { return [[]] }
            guard cards.count >= count, let first = cards.first else { return [] }
            let rest = Array(cards.dropFirst())
            return combinations(rest, count - 1).map { [first] + $0 } + combinations(rest, count)
        }
        let cards = available(before: n), slots = capacity(before: n)
        var seen = Set<[FoolSkillID]>(), out: [[FoolSkillID]] = []
        for family in n < 10 ? combinations(cards, slots) : families {
            var deck = Array(family.filter(cards.contains).prefix(slots))
            deck += cards.filter { !deck.contains($0) }.prefix(max(0, slots - deck.count))
            for order in permutations(deck) where seen.insert(order).inserted { out.append(order) }
        }
        return out
    }
}

/// Plays a chapter-one story battle through `MPCStoryBattleStepper` (the App's loop: ordered cast
/// timing, 7 s cards, pressure, the allies' clock) with the production audit's choices as player
/// inputs. Never injects damage, healing, HP or unlocks; refused inputs are dropped as a client would.
public enum MPCStoryVerificationRunner {
    public enum Target: Sendable { case first, supportFirst, bodyFirst }
    public struct Policy: Sendable {
        /// Raise the mask (when it is the usable active relic) against a heavy blow about to land.
        public var mask = true
        public var counter = true
        /// The medal from this second on, again at each cooldown; nil never.
        public var medalFrom: TimeInterval? = 6
        public var ultimateFrom: TimeInterval = 1
        /// `.supportFirst`: memory cores, Q27's hound, Q29's escort before the sovereign.
        public var target: Target = .first
        /// Pain salve under this health, mirror salve 100 lower; nil keeps them.
        public var salveBelow: Int? = nil
        /// Hold the blank name card (when it is the active relic) against a heavy blow, or a blow after a
        /// failed check, landing within 0.25 s.
        public var blankCard = true
        /// Model only: Q4's mask stays down through this 20-second hound cycle (0 the first).
        public var skipQ4Cycle: Int? = nil
        public init(mask: Bool = true, counter: Bool = true, medalFrom: TimeInterval? = 6, ultimateFrom: TimeInterval = 1,
                    target: Target = .first, salveBelow: Int? = nil, blankCard: Bool = true, skipQ4Cycle: Int? = nil) {
            self.mask = mask; self.counter = counter; self.medalFrom = medalFrom; self.ultimateFrom = ultimateFrom
            self.target = target; self.salveBelow = salveBelow; self.blankCard = blankCard; self.skipQ4Cycle = skipQ4Cycle
        }
        public static let audit = Policy()
    }
    public struct Report: Sendable {
        public let session: MPCChapterOneEncounterSession
        public let seconds: Double
        public let maskUses: Int
        public let medicinesUsed: Int
        public var won: Bool { session.outcome == .victory }
        public var enemyHPLeft: Int { session.enemies.reduce(0) { $0 + max(0, $1.hp) } }
    }

    /// `mask` defaults to an owned mask, lent for teaching in Q3/Q4.
    public static func run(mission q: Int, loadout: MPCChapterOneLoadout, policy: Policy = .audit, consumables: [String: Int] = [:],
                           party: MPCPartyPersistentState = .init(), mask: MPCStoryBattleStepper.Mask? = nil,
                           tuning: MPCChurchBattleStepper.Tuning = .live,
                           configure: ((inout MPCChapterOneEncounterSession) -> Void)? = nil) throws -> Report {
        let encounterID = String(format: "chapter01_q%02d_encounter", q)
        var game = try MPCStoryBattleStepper(encounterID: encounterID, loadout: loadout, consumables: consumables, party: party,
                                             companionIDs: MPCChapterOneCatalog.mission(forEncounterID: encounterID)?.companionIDs ?? [],
                                             mask: mask ?? .init(owned: true, teachingLoan: q <= 4), tuning: tuning, configure: configure)
        var medicines = 0, ultimateAsked = false
        while !game.isFinished {
            let view = game.view
            let s = view.session
            guard s.outcome == .inProgress else { _ = try game.step(); continue }
            var trial = s, out: [MPCBattleInput] = [], salves = 0
            let alive = s.enemies.filter(\.isAlive)
            let support = alive.first { $0.contentID == "enemy_memory_leech_node" }
                ?? (q == 27 ? alive.first { $0.contentID == "enemy_clockwork_hound" } : nil)
                ?? (q == 29 ? alive.first { $0.contentID != "boss_chronarch_sovereign" } : nil)
            let wanted: MPCRuntimeEnemy? = switch policy.target {
            case .first: nil
            case .supportFirst: support
            case .bodyFirst: alive.first { $0.contentID != "enemy_memory_leech_node" }
            }
            if let wanted, wanted.id != view.target { out.append(.init(tick: view.tick, kind: .target, enemyID: wanted.id)) }
            let heavy = s.enemies.contains { enemy in
                guard let lands = view.incoming[enemy.id], lands - view.tick <= 6 else { return false }
                if q == 3 { return enemy.currentIntent == "memory_breath" }
                if q == 4 { return ["q4_flame_first", "q4_flame_second"].contains(enemy.currentIntent) }
                return MPCCombatCounter.isHeavy(enemy.currentIntent)
            }
            let skipped = q == 4 && policy.skipQ4Cycle != nil && game.q4CycleStart.map { Int($0 / 20) } == policy.skipQ4Cycle
            if policy.mask, !skipped, !s.playerIsDown, game.maskIsReady(at: view.now), heavy { out.append(.init(tick: view.tick, kind: .mask)) }
            if policy.counter, s.canRequestCounter { out.append(.init(tick: view.tick, kind: .counter)) }
            if policy.blankCard, loadout.selectedActiveRelicID == "relic_blank_name_card", let blow = s.enemies.first(where: { enemy in
                guard let lands = view.incoming[enemy.id], lands - view.tick <= 5 else { return false }
                return MPCCombatCounter.isHeavy(enemy.currentIntent) || (s.chapterVerificationFailed && enemy.currentIntent == "strike")
            }), trial.activateBlankNameCard(isOwned: true, targetID: blow.id, at: view.now) {
                out.append(.init(tick: view.tick, kind: .blankCard, enemyID: blow.id))
            }
            if let from = policy.medalFrom, view.now >= from, trial.activateUsurpedLifeMedal(isOwned: true, at: view.now) {
                out.append(.init(tick: view.tick, kind: .medal))
            }
            if let below = policy.salveBelow, !s.playerIsDown {
                for (item, line) in [("consumable_pain_salve", below), ("consumable_mirror_salve", below - 100)]
                where trial.playerHP <= line && (try? trial.useConsumable(item)) != nil {
                    out.append(.init(tick: view.tick, kind: .consumable, itemID: item)); salves += 1
                }
            }
            if loadout.isUltimateUnlocked, !ultimateAsked, !s.playerIsDown, !s.foolUltimateUsed, view.now >= policy.ultimateFrom {
                out.append(.init(tick: view.tick, kind: .ultimate)); ultimateAsked = true
            }
            do { _ = try game.step(out); medicines += salves }
            catch MPCChurchBattleDriver.Failure.refused { _ = try game.step() } // the whole step's choices drop, the ultimate's too
        }
        return .init(session: game.session, seconds: max(0, game.now - MPCChurchBattleDriver.step), maskUses: game.maskUses, medicinesUsed: medicines)
    }

    /// The production audit's battle: legal stage loadout before Q`q`, the walls' floors and relic.
    public static func audit(mission q: Int, order: [FoolSkillID], policy: Policy = .audit) throws -> Report {
        try run(mission: q, loadout: MPCStageLoadout.loadout(before: q, order: order, gear: MPCStageLoadout.wallGear(beforeOrAt: q),
                                                            bountyRelic: MPCStageLoadout.wallRelic(q)), policy: policy)
    }
}
