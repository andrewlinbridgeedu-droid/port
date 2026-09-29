import Foundation
import MistportCombatCore

/// Bot proxies for player skill. They are not measured human players:
/// `actionDelay` is added after every action, and the low profile also
/// picks worse targets in story battles.
struct Profile: Sendable {
    let name: String
    let actionDelay: Double
    let priorityCore: Bool
    static let all = [Profile(name: "high", actionDelay: 0, priorityCore: true),
                      Profile(name: "medium", actionDelay: 0.25, priorityCore: true),
                      Profile(name: "low", actionDelay: 0.8, priorityCore: false)]
}

/// What the player is willing to do when the next story battle is lost.
/// Every policy may earn copper at the J0 postal job and buy shop relics:
/// neither is church or bounty content. `hinted` does, at a wall, only what the
/// wall's defeat hint names (its floor, then its case); elsewhere it plays like `all`.
/// Its side time is the "needed side content" of acceptance criterion 4.
enum Policy: String, CaseIterable, Sendable {
    case mainOnly, mainTower, mainBounty, all, completionist, hinted
}

/// Time costs and limits that are not game data. Reported with every run.
/// Story and tower first clears open by day through MPCDailyPacing (game rules).
struct Assumptions: Codable, Sendable {
    var battleOverheadSeconds = 20.0
    var postalSeconds = 150.0
    var maxWaitDays = 10
    /// A run that has not finished by this day is reported as stuck.
    var maxDays = 120
}

/// Shop and job constants from GameStore.swift (EarlyRelicShop, purchasePainSalve, J0).
enum Shop {
    static let salve = 30
    static let postalPay = 40
    static let passives: [(id: String, price: Int, unlock: Int)] = [
        ("relic_salt_sealed_breathing_bag", 120, 4), ("relic_return_gift_clasp", 160, 4),
        ("relic_deferred_stamp", 360, 9), ("relic_reflecting_ink_mirror", 520, 14),
        ("relic_sealed_paperweight", 400, 18), ("relic_countertide_anchor", 640, 20),
        ("relic_ownership_severing_needle", 720, 26)]
    static func value(_ id: String) -> Int { passives.first { $0.id == id }?.price ?? 0 }
}

/// Cards available for the next story mission, as in the 2026-09-25 audit.
func cards(forMission q: Int) -> [[FoolSkillID]] {
    switch q {
    case ...7: return [[.sidestepStrike]]
    case 8...9: return [[.identityDisplacement, .sidestepStrike], [.sidestepStrike, .identityDisplacement]]
    case 10: return [[.fabricatedEvidence, .sidestepStrike], [.identityDisplacement, .sidestepStrike]]
    case 11: return [[.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .sidestepStrike]]
    default: return [[.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .absurdFinale],
                     [.sidestepStrike, .fabricatedEvidence, .mirrorPursuit, .absurdFinale]]
    }
}

func talentBudget(completed: Int) -> Int {
    completed > 0 ? (1...completed).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for: $0)?.talentPoints }.reduce(0, +) : 0
}

/// The loadout a player has when the next story mission is `q`: cards, talents,
/// the two dust upgrades (Q9, Q14), the medal from Q5, one passive relic, the bounty-slot relic and church gear.
func loadout(mission q: Int, gear: MPCChurchGearStats, passive: String?, sequence: [FoolSkillID],
             bountyRelic: String? = nil) -> MPCChapterOneLoadout {
    var l = MPCChapterOneLoadout(normalSkillIDs: sequence, isUltimateUnlocked: q >= 14, passiveIDs: [], relicIDs: passive.map { [$0] } ?? [])
    l.bountyRelicID = bountyRelic
    l.talents = .restored((0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" } + (0...5).map { "phantom.\($0)" },
                          budget: talentBudget(completed: q - 1))
    if q >= 10 { l.skillLevels[.sidestepStrike] = 2 }
    if q >= 15 { l.skillLevels[.mirrorPursuit] = 2 }
    if q >= 5 { l.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID }
    l.churchGear = gear
    l.outfit = .mistportNight
    return l
}

/// Bounty-slot relics worth wearing for `mission`, the wall's own counter first.
func bountyRelicCandidates(mission: Int, owned: Set<String>) -> [String?] {
    let wallRelic = MPCProgressionWalls.wall(mission: mission)?.caseID.flatMap { MPCBountyRelicCatalog.relic(forCase: $0)?.id }
    let useful = MPCBountyRelicCatalog.all.filter { $0.hasEffect && owned.contains($0.id) }.map(\.id)
        .sorted { a, b in (a == wallRelic ? 0 : 1, a) < (b == wallRelic ? 0 : 1, b) }
    return useful.isEmpty ? [nil] : useful.map { Optional($0) }
}

func towerLimit(completed q: Int) -> Int { q >= 20 ? 100 : q >= 16 ? 70 : q >= 13 ? 50 : q >= 10 ? 30 : 10 }

struct Visit: Codable {
    let day: Int
    let kind: String
    let target: String
    let won: Bool
    let attempts: Int
    let seconds: Double
    let copperAfter: Int
    let attackBP: Int
    let gearHP: Int
    let reductionBP: Int
}

struct Milestone: Codable {
    let mission: Int
    let day: Int
    let minutes: Double
    let towerFloor: Int
    let bountiesCleared: Int
    let copper: Int
    let attackBP: Int
    let gearHP: Int
    let reductionBP: Int
}

struct RunResult: Codable {
    let policy: String
    let profile: String
    let startOffset: Int
    let assumptions: Assumptions
    let finalMission: Int
    let stuckAt: Int?
    let days: Int
    let minutes: [String: Double]
    /// Minutes played on each day (index 0 is day 1): battles, overhead and postal jobs.
    let minutesByDay: [Double]
    let battles: [String: Int]
    let losses: [String: Int]
    let salvesUsed: Int
    let postalJobs: Int
    let repairCopper: Int
    let defeatCopperLost: Int
    let relicsLost: [String]
    let copper: Int
    let merit: Int
    let towerFloor: Int
    let bountiesCleared: [String]
    let passives: [String]
    let bountyRelics: [String]
    let milestones: [Milestone]
    let visits: [Visit]
}

/// One new save played in order. Every battle is the shipping combat core
/// driven by the audit bots; rewards are granted only after real wins.
final class Campaign {
    let policy: Policy, profile: Profile, assumptions: Assumptions
    let startDate: Date, startOffset: Int
    let calendar = Calendar(identifier: .gregorian)
    var q = 0, tower = 0, day = 0
    var dayMinutes: [Double] = [0]
    /// Set when today's tower first-clear allowance, not a loss, stopped the climb.
    var towerGated = false
    var cleared = Set<String>(), accepted = Set<String>()
    var gear = MPCChurchGearLedger()
    var relics = MPCBountyRelicLedger()
    var copper = 180, merit = 0, salve = 0
    var passives: [String] = []
    var seconds: [String: Double] = [:], battles: [String: Int] = [:], losses: [String: Int] = [:]
    var salvesUsed = 0, postalJobs = 0, repairCopper = 0, defeatCopperLost = 0, serial = 0
    var relicsLost: [String] = []
    var visits: [Visit] = [], milestones: [Milestone] = []
    /// States already known to lose a target; the bots are deterministic.
    var failed: [String: Set<String>] = [:]

    init(policy: Policy, profile: Profile, assumptions: Assumptions, startDate: Date, startOffset: Int) {
        self.policy = policy; self.profile = profile; self.assumptions = assumptions
        self.startDate = startDate; self.startOffset = startOffset
    }

    var churchOpen: Bool { q >= 7 }
    /// MPCDailyPacing counts the save's first day as day 1.
    var dayNumber: Int { day + 1 }
    var storyOpen: Bool { MPCDailyPacing.isMissionOpen(q + 1, day: dayNumber) }
    var stats: MPCChurchGearStats { gear.stats }
    var signature: String {
        "\(stats.attackBP)/\(stats.maxHP)/\(stats.damageReductionBP)|\(passives.sorted().joined(separator: ","))|\(relics.ownedIDs.sorted().joined(separator: ","))|\(q)|\(salve)|\(rotation)"
    }
    /// A story retry leads with a different plan (and a tower or case retry with a
    /// different relic), as a player changing plan would.
    var rotation = 0
    var passiveCandidates: [String?] {
        guard !passives.isEmpty else { return [nil] }
        let shift = rotation % passives.count
        return (passives[shift...] + passives[..<shift]).map { Optional($0) }
    }
    /// Towers and cases wear one bounty relic; the story swaps in the wall's counter.
    var worn: String? { bountyRelicCandidates(mission: q + 1, owned: relics.ownedIDs)[0] }

    func spend(_ kind: String, _ battleSeconds: Double) {
        seconds[kind, default: 0] += battleSeconds + assumptions.battleOverheadSeconds
        dayMinutes[day] += (battleSeconds + assumptions.battleOverheadSeconds) / 60
        battles[kind, default: 0] += 1
    }

    /// Normal wear 2 per win, 5 per defeat, repaired at ceil(value * wear / 200).
    func wear(_ passive: String?, won: Bool) {
        guard let passive else { return }
        let cost = (Shop.value(passive) * (won ? 2 : 5) + 199) / 200
        copper -= cost; repairCopper += cost
    }

    func shop() {
        guard q >= 4 else { return }
        if salve == 0 && copper >= Shop.salve { copper -= Shop.salve; salve = 1 }
        for relic in Shop.passives where q >= relic.unlock && !passives.contains(relic.id) && copper - relic.price >= Shop.salve {
            copper -= relic.price; passives.append(relic.id)
        }
    }

    func postal(jobs: Int) {
        guard jobs > 0 else { return }
        postalJobs += jobs; copper += jobs * Shop.postalPay
        seconds["postal", default: 0] += Double(jobs) * assumptions.postalSeconds
        dayMinutes[day] += Double(jobs) * assumptions.postalSeconds / 60
    }

    func nextDay() {
        day += 1; dayMinutes.append(0)
        if churchOpen { refreshBoard() }
    }

    /// The daily board offers 3-6 unaccepted cases; accepting keeps them across days.
    func refreshBoard() {
        let date = calendar.date(byAdding: .day, value: startOffset + day, to: startDate)!
        let ordinal = MPCDailyBountyRotation.dayOrdinal(for: date, calendar: calendar)
        let eligible = MPCChurchBountyCatalog.all.map(\.id).filter { !accepted.contains($0) && !cleared.contains($0) }
        let guaranteed = MPCProgressionWalls.guaranteedCase(nextMission: q + 1, ownedRelicIDs: relics.ownedIDs)
        accepted.formUnion(MPCDailyBountyRotation.issue(dayOrdinal: ordinal, eligibleIDs: eligible).guaranteeing(guaranteed).offerIDs)
    }

    func visit(_ kind: String, _ target: String, won: Bool, attempts: Int, seconds: Double) {
        visits.append(.init(day: day, kind: kind, target: target, won: won, attempts: attempts, seconds: seconds,
                            copperAfter: copper, attackBP: stats.attackBP, gearHP: stats.maxHP, reductionBP: stats.damageReductionBP))
    }

    func knownLoss(_ key: String) -> Bool { failed[key]?.contains(signature) ?? false }

    // MARK: Battles

    func attemptMain(stopAfterSalve: Bool = false) -> Bool {
        shop()
        let mission = q + 1, key = "main-\(mission)"
        guard storyOpen, !knownLoss(key) else { return false }
        var attempts = 0, total = 0.0
        // A retry starts from a different whole plan (cards, relics, medal time), so the
        // one salve is not always spent on the same losing plan first.
        let plans = cards(forMission: mission).flatMap { sequence in
            bountyRelicCandidates(mission: mission, owned: relics.ownedIDs).flatMap { bountyRelic in
                (mission >= 5 && !passives.isEmpty ? passives.map { Optional($0) } : [nil]).flatMap { passive in
                    (mission >= 5 ? [6.0, 14.0] as [Double?] : [nil]).map { (sequence, bountyRelic, passive, $0) } } } }
        let shift = plans.isEmpty ? 0 : rotation % plans.count
        for (sequence, bountyRelic, passive, offset) in plans[shift...] + plans[..<shift] {
            attempts += 1
            let consumables = mission >= 5 && salve > 0 ? ["consumable_pain_salve": 1] : [:]
            let l = loadout(mission: mission, gear: stats, passive: passive, sequence: sequence, bountyRelic: bountyRelic)
            let report = try! ChapterDriver.run(q: mission, sequence: sequence, mask: mission == 3 || mission == 4,
                                                consumables: consumables, priorityCore: profile.priorityCore,
                                                ultimate: mission >= 14, loadout: l, medalOffset: offset,
                                                precise: true, actionDelay: profile.actionDelay)
            spend("main", report.seconds); total += report.seconds
            if report.medicinesUsed > 0 { salve = 0; salvesUsed += 1 }
            let won = report.session.outcome == .victory
            wear(passive, won: won)
            if won {
                let reward = MPCChapterOneThirtyMissionContract.firstClear(for: mission)!
                copper += reward.copper; merit += reward.merit
                q = mission
                visit("main", key, won: true, attempts: attempts, seconds: total)
                milestones.append(.init(mission: q, day: day, minutes: seconds.values.reduce(0, +) / 60,
                                        towerFloor: tower, bountiesCleared: cleared.count, copper: copper,
                                        attackBP: stats.attackBP, gearHP: stats.maxHP, reductionBP: stats.damageReductionBP))
                if q == 7 { refreshBoard() }
                return true
            }
            losses["main", default: 0] += 1
            if stopAfterSalve && report.medicinesUsed > 0 { break }
            shop()
        }
        failed[key, default: []].insert(signature)
        visit("main", key, won: false, attempts: attempts, seconds: total)
        return false
    }

    func attemptTower() -> Bool {
        let floor = tower + 1, key = "tower-\(floor)"
        guard churchOpen, floor <= towerLimit(completed: q), !knownLoss(key) else { return false }
        guard MPCDailyPacing.canFirstClearTower(clearedFloors: tower, day: dayNumber) else { towerGated = true; return false }
        let mission = q + 1
        var attempts = 0, total = 0.0
        for passive in passiveCandidates {
            for offset in [6.0, 14.0, 22.0] {
                attempts += 1
                let l = loadout(mission: mission, gear: stats, passive: passive, sequence: cards(forMission: mission)[0], bountyRelic: worn)
                let report = try! TowerDriver.run(number: floor, medalOffset: offset, suppliedLoadout: l, actionDelay: profile.actionDelay)
                spend("tower", report.seconds); total += report.seconds
                let won = report.session.outcome == .victory
                wear(passive, won: won)
                if won {
                    tower = floor
                    let reward = MPCChurchTowerCatalog.floor(number: floor)!.firstClearReward
                    copper += reward.coins; merit += reward.merit
                    if let drop = MPCChurchGearCatalog.towerDrop(floor: floor) { gear.grant(drop.id) }
                    visit("tower", key, won: true, attempts: attempts, seconds: total)
                    return true
                }
                losses["tower", default: 0] += 1
            }
        }
        failed[key, default: []].insert(signature)
        visit("tower", key, won: false, attempts: attempts, seconds: total)
        return false
    }

    func attemptBounty(_ id: String) -> Bool {
        let key = "bounty-\(id)"
        guard churchOpen, accepted.contains(id), !cleared.contains(id), !knownLoss(key),
              let bounty = MPCChurchBountyCatalog.all.first(where: { $0.id == id }) else { return false }
        let mission = q + 1
        var attempts = 0, total = 0.0
        for passive in passiveCandidates {
            for offset in [6.0, 14.0, 22.0] {
                attempts += 1
                let l = loadout(mission: mission, gear: stats, passive: passive, sequence: cards(forMission: mission)[0], bountyRelic: worn)
                let report = try! TowerDriver.run(number: 1, medalOffset: offset, suppliedLoadout: l,
                                                  actionDelay: profile.actionDelay, encounterID: bounty.encounterID)
                spend("bounty", report.seconds); total += report.seconds
                let won = report.session.outcome == .victory
                wear(passive, won: won)
                if won {
                    cleared.insert(id)
                    copper += bounty.copper; merit += bounty.merit
                    relics.grant(caseID: id)
                    visit("bounty", key, won: true, attempts: attempts, seconds: total)
                    return true
                }
                losses["bounty", default: 0] += 1
                serial += 1
                let loss = MPCBountyDefeatRisk.loss(battleID: "sim-\(policy.rawValue)-\(profile.name)-\(startOffset)-\(serial)",
                                                    availableCopper: max(0, copper), carriedOrdinaryRelicIDs: passive.map { [$0] } ?? [])
                copper -= loss.copper; defeatCopperLost += loss.copper
                if let lost = loss.relicID, let index = passives.firstIndex(of: lost) {
                    passives.remove(at: index); relicsLost.append(lost)
                    break
                }
            }
        }
        failed[key, default: []].insert(signature)
        visit("bounty", key, won: false, attempts: attempts, seconds: total)
        return false
    }

    // MARK: Policies

    /// Earn copper at J0 for the next unlocked shop relic, then buy it.
    func buyNextRelicWithPostal() -> Bool {
        guard let next = Shop.passives.first(where: { q >= $0.unlock && !passives.contains($0.id) }) else { return false }
        postal(jobs: max(0, (next.price + Shop.salve - copper + Shop.postalPay - 1) / Shop.postalPay))
        shop()
        return passives.contains(next.id)
    }

    /// Climbs the tower; retries the story whenever gear improves. True if the story advanced.
    func grindTower() -> (storyWon: Bool, progressed: Bool) {
        var progressed = false
        while attemptTower() {
            progressed = true
            if attemptMain() { return (true, true) }
        }
        return (false, progressed)
    }

    /// Works accepted cases, waiting for new boards when none can be won.
    func grindBounties() -> (storyWon: Bool, progressed: Bool) {
        guard churchOpen else { return (false, false) }
        var progressed = false, idle = 0
        while idle <= assumptions.maxWaitDays && cleared.count < MPCChurchBountyCatalog.all.count {
            var today = false
            for id in accepted.subtracting(cleared).sorted() where attemptBounty(id) {
                today = true; progressed = true
                if attemptMain() { return (true, true) }
            }
            if today { idle = 0 } else { nextDay(); idle += 1 }
        }
        return (false, progressed)
    }

    /// At a wall: climb to its floor, retry; then work its case (waiting for the
    /// guaranteed board), retry. True if the story advanced.
    func followWallHint() -> Bool {
        guard churchOpen, let wall = MPCProgressionWalls.wall(mission: q + 1) else { return false }
        if let floor = wall.towerFloor, tower < floor {
            while tower < floor && attemptTower() {}
            if tower >= floor && attemptMain() { return true }
        }
        if let caseID = wall.caseID, let relic = MPCBountyRelicCatalog.relic(forCase: caseID),
           !relics.ownedIDs.contains(relic.id) {
            var idle = 0
            while !cleared.contains(caseID) && idle <= assumptions.maxWaitDays {
                if accepted.contains(caseID) && attemptBounty(caseID) { break }
                nextDay(); idle += 1
            }
            if cleared.contains(caseID) && attemptMain() { return true }
        }
        return false
    }

    func clearAvailableSide() {
        guard churchOpen else { return }
        var progressed = true
        while progressed {
            progressed = false
            while attemptTower() { progressed = true }
            for id in accepted.subtracting(cleared).sorted() where attemptBounty(id) { progressed = true }
        }
    }

    /// Out of salve: a player runs J0 for one more and retries, leading each time with a
    /// different whole plan and stopping once that salve is spent on a loss.
    func retryWithFreshSalves() -> Bool {
        defer { rotation = 0 }
        for retry in 1...8 where q >= 4 {
            if salve == 0 { postal(jobs: max(0, (Shop.salve - copper + Shop.postalPay - 1) / Shop.postalPay)) }
            rotation = retry
            if attemptMain(stopAfterSalve: true) { return true }
        }
        return false
    }

    func run() -> RunResult {
        var stuckAt: Int?
        while q < 30 {
            if dayNumber > assumptions.maxDays { stuckAt = q + 1; break }
            towerGated = false
            if policy == .completionist { clearAvailableSide() }
            // The next mission opens on a later day: today's usual side content, then tomorrow.
            if !storyOpen {
                switch policy {
                case .mainOnly, .hinted: break
                case .mainTower: while attemptTower() {}
                case .mainBounty: for id in accepted.subtracting(cleared).sorted() { _ = attemptBounty(id) }
                case .all, .completionist: clearAvailableSide()
                }
                nextDay()
                continue
            }
            if attemptMain() { continue }
            var advanced = false
            while !advanced && buyNextRelicWithPostal() { advanced = attemptMain() }
            if advanced { continue }
            if retryWithFreshSalves() { continue }
            switch policy {
            case .mainOnly: break
            case .mainTower: advanced = grindTower().storyWon
            case .mainBounty: advanced = grindBounties().storyWon
            case .all, .completionist, .hinted:
                // Hinted: do what the wall asks, then retry other plans before any further side
                // content; if today's tower floors ran out first, wait for tomorrow's.
                if policy == .hinted {
                    advanced = followWallHint()
                    if !advanced && towerGated { break }
                    if !advanced { advanced = retryWithFreshSalves() }
                }
                var moving = true
                while !advanced && moving {
                    let climb = grindTower()
                    if climb.storyWon { advanced = true; break }
                    let cases = grindBounties()
                    advanced = cases.storyWon
                    moving = climb.progressed || cases.progressed
                }
            }
            // Today's tower floors ran out before the story moved: more open tomorrow.
            if !advanced && towerGated { nextDay(); continue }
            // Side content may have made a plan winnable that only works with the salve.
            if !advanced { advanced = retryWithFreshSalves() }
            if !advanced { stuckAt = q + 1; break }
        }
        return RunResult(policy: policy.rawValue, profile: profile.name, startOffset: startOffset, assumptions: assumptions,
                         finalMission: q, stuckAt: stuckAt, days: dayNumber,
                         minutes: seconds.mapValues { ($0 / 60 * 10).rounded() / 10 },
                         minutesByDay: dayMinutes.map { ($0 * 10).rounded() / 10 },
                         battles: battles, losses: losses, salvesUsed: salvesUsed, postalJobs: postalJobs,
                         repairCopper: repairCopper, defeatCopperLost: defeatCopperLost, relicsLost: relicsLost,
                         copper: copper, merit: merit, towerFloor: tower, bountiesCleared: cleared.sorted(),
                         passives: passives, bountyRelics: relics.ownedIDs.sorted(), milestones: milestones, visits: visits)
    }
}
