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
    var craftSeconds = 60.0
    var saleSeconds = 20.0
    /// Phase 2 daily content, outside battles: walking to a neighbour and talking,
    /// the extra walk to a message's recipient, a remnant case's investigation,
    /// and handing goods to an event.
    var errandSeconds = 120.0
    var messageWalkSeconds = 60.0
    var remnantInvestigationSeconds = 240.0
    var eventDeliverySeconds = 30.0
    /// Human-pace runs (HumanTiming.swift): when set, every non-battle second above is
    /// replaced by the step model and battles run at the pace's action delay.
    var pace: HumanPace? = nil
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
    /// Combat alone, in seconds, by kind (the rest of `minutes` is overhead and non-battle steps).
    let battleSecondsByKind: [String: Double]
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
    /// Copper earned by source: main, tower, bounty (first clears), postal (J0 after the
    /// daily taper) and workshop (NPC orders, before base-stock costs).
    let copperBySource: [String: Int]
    let workshop: WorkshopSummary
    let daily: DailyContentSummary
    let merit: Int
    let towerFloor: Int
    let bountiesCleared: [String]
    let passives: [String]
    let bountyRelics: [String]
    let milestones: [Milestone]
    let visits: [Visit]
}

/// City events, remnant cases and neighbour errands (all and completionist policies).
struct DailyContentSummary: Codable {
    let errands: Int
    let remnants: Int
    let eventWins: [String: Int]
    /// Each event's status on the run's last day: succeeded, failed or running.
    let eventStatus: [String: String]
    let storiesUnlocked: Int
    /// Errands offered on a day the run finished but not done that day, by errand ID.
    let missedErrands: [String]
    /// City contribution at the end (MPCCityContributionLedger) and the day each tier was reached.
    let contribution: Int
    let contributionTierDays: [String: Int]
    /// Contribution at the end of each day, day 1 first.
    let contributionByDay: [Int]
}

struct WorkshopSummary: Codable {
    let crafts: Int
    let salvesCrafted: Int
    let salvesUsedFromStock: Int
    let unitsSold: Int
    let boardPaid: Int
    let baseStockCopper: Int
    let replays: Int
    let proficiency: [String: Int]
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
    /// Repeatable pay taper, workshop and its orders (MPCDailyWorkLedger, MPCCraftingLedger, MPCWorkshopOrderBoard).
    var work = MPCDailyWorkLedger()
    var crafting = MPCCraftingLedger()
    var orders = MPCWorkshopOrderBoard()
    var inventory: [String: Int] = [:]
    var earned: [String: Int] = [:]
    var crafts = 0, salvesCrafted = 0, salvesFromStock = 0, unitsSold = 0, baseStockCopper = 0, replays = 0
    /// Set when today's J0 pay has tapered off before the copper needed was reached.
    var copperShort = false
    /// Policies that use the workshop: it needs tower materials and is optional content.
    var usesWorkshop: Bool { policy == .all || policy == .completionist }
    /// City events, remnant cases and errands (MPCCityEventLedger, MPCRemnantLedger, MPCNeighborLedger).
    /// Every policy lives in the same city: events nobody works on fail and their costs apply.
    var events = MPCCityEventLedger()
    var remnants = MPCRemnantLedger()
    var neighbors = MPCNeighborLedger()
    var tickets = 0, errandsDone = 0, remnantsDone = 0
    var missedErrands: [String] = []
    var contribution = MPCCityContributionLedger()
    var contributionTierDays: [String: Int] = [:]
    var contributionByDay: [Int] = []
    var usesDailyContent: Bool { usesWorkshop }
    var city: MPCCityEvent.Effects { events.effects(day: dayNumber) }
    var salvePrice: Int { Shop.salve + city.salveSurcharge }
    var completedMissions: Set<Int> { q > 0 ? Set(1...q) : [] }
    /// States already known to lose a target; the bots are deterministic.
    var failed: [String: Set<String>] = [:]

    init(policy: Policy, profile: Profile, assumptions: Assumptions, startDate: Date, startOffset: Int) {
        self.policy = policy; self.profile = profile; self.assumptions = assumptions
        self.startDate = startDate; self.startOffset = startOffset
    }

    /// The church (tower, bounties) opens after Q7 (MPCChurchTowerCatalog, user decision 2026-09-29).
    var churchOpen: Bool { MPCChurchTowerCatalog.isUnlocked(completedMissionNumbers: completedMissions) }
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

    /// Set for human-pace runs: every non-battle second comes from the step model.
    var model: HumanTimingModel? { assumptions.pace.map { HumanTimingModel(pace: $0) } }
    var battleOnly: [String: Double] = [:]
    var visitedMissions = Set<Int>(), investigatedCases = Set<String>(), briefedEvents = Set<String>()
    var churchVisitDay = -1
    func total(_ steps: [TimedStep]) -> Double { steps.reduce(0) { $0 + $1.seconds } }
    /// Non-battle seconds around one battle. Errand and remnant fights have theirs in their step models.
    func overhead(_ kind: String) -> Double {
        guard let m = model else { return assumptions.battleOverheadSeconds }
        switch kind {
        case "main": return total(m.storyAttempt)
        case "tower", "workshop": return total(m.towerFloor)
        case "bounty": return total(m.battleFrame(result: 40, planning: 1))
        case "event": return total(m.eventBattle)
        default: return 0
        }
    }

    func spend(_ kind: String, _ battleSeconds: Double) {
        let extra = overhead(kind)
        seconds[kind, default: 0] += battleSeconds + extra
        dayMinutes[day] += (battleSeconds + extra) / 60
        battleOnly[kind, default: 0] += battleSeconds
        battles[kind, default: 0] += 1
    }

    /// Normal wear 2 per win, 5 per defeat, repaired at ceil(value * wear / 200).
    /// Repair is optional in the game: with no copper left the relic is simply not mended yet.
    func wear(_ passive: String?, won: Bool) {
        guard let passive else { return }
        let cost = min(max(0, copper), (Shop.value(passive) * (won ? 2 : 5) + 199) / 200)
        copper -= cost; repairCopper += cost
    }

    func shop() {
        guard q >= 4 else { return }
        if salve == 0, inventory[MPCCraftingCatalog.salveID, default: 0] > 0 {
            inventory[MPCCraftingCatalog.salveID, default: 0] -= 1; salve = 1; salvesFromStock += 1
        }
        if salve == 0 && copper >= salvePrice { copper -= salvePrice; salve = 1 }
        for relic in Shop.passives where q >= relic.unlock && !passives.contains(relic.id) && copper - relic.price >= salvePrice {
            copper -= relic.price; passives.append(relic.id)
        }
    }

    /// Time spent outside battles (crafting, selling), counted like battle time.
    func busy(_ kind: String, _ seconds: Double) {
        self.seconds[kind, default: 0] += seconds
        dayMinutes[day] += seconds / 60
    }

    /// J0 seal checks until `target` copper, paid through the day's taper. A player stops
    /// once a job would pay only a tenth; if that leaves them short, they wait for tomorrow.
    func contribute(_ receiptID: String, _ source: MPCCityContribution.Source) {
        contribution.record(receiptID: receiptID, source: source, day: dayNumber)
        while contributionByDay.count < dayNumber { contributionByDay.append(contributionByDay.last ?? 0) }
        contributionByDay[dayNumber - 1] = contribution.points
        let tier = contribution.tier
        if contributionTierDays["\(tier.level)"] == nil {
            for t in MPCCityContribution.tiers where t.level <= tier.level && contributionTierDays["\(t.level)"] == nil {
                contributionTierDays["\(t.level)"] = dayNumber
            }
        }
    }

    @discardableResult func postal(upTo target: Int) -> Bool {
        while copper < target && work.preview(day: dayNumber, copper: Shop.postalPay) * 2 >= Shop.postalPay {
            postalJobs += 1
            let pay = work.settle(receiptID: "postal-\(postalJobs)", day: dayNumber, copper: Shop.postalPay, merit: 0)
            copper += pay.copper; earned["postal", default: 0] += pay.copper
            contribute("postal-\(postalJobs)", .post)
            busy("postal", model.map { total($0.postal) } ?? assumptions.postalSeconds)
        }
        if copper < target { copperShort = true }
        return copper >= target
    }

    func nextDay() {
        if let m = model { busy("newspaper", total(m.newspaper)) }
        if usesDailyContent { neighbors.open(day: dayNumber, completedMissions: completedMissions) }
        workshopSession()
        dailyContent()
        missedErrands += neighbors.offers.filter { $0.day == dayNumber && !$0.done }.map(\.errandID)
        day += 1; dayMinutes.append(0)
        if churchOpen { refreshBoard() }
    }

    /// The day's workshop visit (workshop policies, from Q5): keep three salves of our own,
    /// then make goods for what the NPC orders can still pay today, replaying a low floor
    /// (at most twice) when materials run short.
    func workshopSession() {
        guard usesWorkshop, MPCCraftingCatalog.isUnlocked(completedMissions: completedMissions) else { return }
        let effects = city
        if let m = model { busy("workshop", total(m.workshopVisit)) }
        orders.open(day: dayNumber, bonus: effects.orderBudgetBonus)
        func craft(_ recipeID: String) -> Bool {
            let cost = MPCCraftingCatalog.baseStock(MPCCraftingCatalog.recipe(recipeID)!, surcharge: effects.craftSurcharge)
            guard copper - cost >= salvePrice else { return false }
            let made = (try? crafting.craft(receiptID: "craft-\(crafts)", recipeID: recipeID, day: dayNumber,
                                            completedMissions: completedMissions, coins: &copper,
                                            inventory: &inventory, gear: &gear, surcharge: effects.craftSurcharge)) == true
            if made { crafts += 1; baseStockCopper += cost; busy("workshop", model.map { total($0.craft) } ?? assumptions.craftSeconds) }
            return made
        }
        func sell(_ item: String, keeping keep: Int) -> Bool {
            let spare = inventory[item, default: 0] - keep
            guard spare > 0 else { return false }
            let units = (try? orders.sell(receiptID: "sale-\(unitsSold)-\(item)", itemID: item, count: spare,
                                           day: dayNumber, coins: &copper, inventory: &inventory, bonus: effects.orderBudgetBonus)) ?? 0
            guard units > 0 else { return false }
            unitsSold += units
            earned["workshop", default: 0] += units * MPCWorkshopOrderBoard.prices[item]!
            busy("workshop", model.map { total($0.sale) } ?? assumptions.saleSeconds)
            return true
        }
        let salveID = MPCCraftingCatalog.salveID
        while inventory[salveID, default: 0] < 3 && craft("recipe_pain_salve") { salvesCrafted += 1 }
        // Goods the city event and today's neighbours ask for come before the orders.
        let recipeFor = [salveID: "recipe_pain_salve", MPCCraftingCatalog.strapID: "recipe_repair_strap",
                         MPCCraftingCatalog.patchID: "recipe_armor_patch", MPCCraftingCatalog.clothID: "recipe_filter_cloth"]
        func stock(_ item: String, _ count: Int) {
            while inventory[item, default: 0] < count && craft(recipeFor[item]!) { if item == salveID { salvesCrafted += 1 } }
        }
        // Kept back from the event and the orders: three salves of our own and today's errand goods.
        var reserved = [salveID: 3]
        if usesDailyContent {
            for offer in neighbors.offers where !offer.done {
                if let errand = offer.errand, errand.kind == .deliver, let item = errand.itemID { reserved[item, default: 0] += errand.count }
            }
        }
        if usesDailyContent, let event = MPCCityEventCatalog.running(day: dayNumber), events.status(event.id, day: dayNumber) == .running {
            for need in event.deliveries where events.remaining(event, itemID: need.itemID) > 0 {
                let keep = reserved[need.itemID, default: 0]
                stock(need.itemID, events.remaining(event, itemID: need.itemID) + keep)
                let spare = inventory[need.itemID, default: 0] - keep
                guard spare > 0 else { continue }
                tickets += 1
                let before = copper
                if (try? events.deliver(id: "deliver-\(tickets)", eventID: event.id, itemID: need.itemID, count: spare,
                                        day: dayNumber, coins: &copper, inventory: &inventory)) != nil {
                    earned["event", default: 0] += copper - before
                    busy("event", model.map { total($0.eventDelivery) } ?? assumptions.eventDeliverySeconds)
                    if let m = model, briefedEvents.insert(event.id).inserted { busy("event", total([m.eventBriefing(event)])) }
                }
            }
        }
        for (item, count) in reserved.sorted(by: { $0.key < $1.key }) { stock(item, count) }
        // Best copper per material first: salves, straps, then patches and cloth.
        let goods: [(recipe: String, item: String)] = [("recipe_pain_salve", salveID), ("recipe_repair_strap", MPCCraftingCatalog.strapID),
                                                      ("recipe_armor_patch", MPCCraftingCatalog.patchID), ("recipe_filter_cloth", MPCCraftingCatalog.clothID)]
        let cheapest = MPCWorkshopOrderBoard.prices.values.min()!
        var replaysToday = 0
        while orders.budget >= cheapest {
            var progressed = false
            for good in goods where orders.budget >= MPCWorkshopOrderBoard.prices[good.item]! {
                let keep = reserved[good.item, default: 0]
                if inventory[good.item, default: 0] > keep {
                    if sell(good.item, keeping: keep) { progressed = true }
                } else if craft(good.recipe) {
                    if good.item == salveID { salvesCrafted += 1 }
                    progressed = true
                }
            }
            if progressed { continue }
            guard replaysToday < 2, tower >= 1 else { break }
            replaysToday += 1
            replayForMaterials()
        }
    }

    /// Street fights of the daily content, on the shipping combat core like every other battle.
    func streetFight(_ encounterID: String, kind: String) -> TowerDriver.Report {
        let l = loadout(mission: q + 1, gear: stats, passive: passives.last, sequence: cards(forMission: q + 1)[0], bountyRelic: worn)
        let report = try! TowerDriver.run(number: 1, medalOffset: 6, suppliedLoadout: l, actionDelay: profile.actionDelay,
                                          encounterID: encounterID)
        spend(kind, report.seconds)
        let won = report.session.outcome == .victory
        wear(passives.last, won: won)
        if !won { losses[kind, default: 0] += 1 }
        return report
    }

    /// The rest of the day (all and completionist): today's neighbour errands, up to two
    /// counted event battles (three tries), and today's remnant case once a bounty is closed.
    func dailyContent() {
        guard usesDailyContent else { return }
        if let m = model, neighbors.offers.contains(where: { $0.day == dayNumber && !$0.done }) { busy("errand", total(m.streetOpen)) }
        for offer in neighbors.offers where offer.day == dayNumber && !offer.done {
            guard let errand = offer.errand else { continue }
            var reward: MPCNeighborLedger.Reward?
            switch errand.kind {
            case .deliver: reward = try? neighbors.deliver(offerID: offer.id, coins: &copper, inventory: &inventory)
            case .find: reward = try? neighbors.answer(offerID: offer.id, choiceID: errand.correctChoiceID!, coins: &copper)
            case .message: reward = try? neighbors.relay(offerID: offer.id, to: errand.recipientID!, coins: &copper)
            case .pest:
                tickets += 1
                let ticket = "errand-\(tickets)"
                guard let id = try? neighbors.beginPest(offerID: offer.id, ticket: ticket) else { continue }
                let fight = streetFight(id, kind: "errand")
                reward = try? neighbors.settlePest(offerID: offer.id, ticket: ticket, session: fight.session, coins: &copper)
            }
            busy("errand", model.map { total($0.errand(errand, asker: offer.neighborID)) }
                 ?? assumptions.errandSeconds + (errand.kind == .message ? assumptions.messageWalkSeconds : 0))
            if let reward { errandsDone += 1; earned["errand", default: 0] += reward.copper; contribute("errand-\(offer.id)", .errand) }
            if let m = model, let story = reward?.story { busy("errand", total([m.story(story)])) }
        }
        if let event = MPCCityEventCatalog.running(day: dayNumber) {
            var tries = 0
            while tries < 3, events.status(event.id, day: dayNumber) == .running, events.winsLeft(event) > 0,
                  events.winsCounted(event.id, day: dayNumber) < MPCCityEventCatalog.countedWinsPerDay {
                tries += 1; tickets += 1
                let ticket = "event-\(tickets)"
                guard let id = try? events.beginBattle(ticket: ticket, eventID: event.id, day: dayNumber) else { break }
                let fight = streetFight(id, kind: "event")
                let before = copper, winsBefore = events.progress[event.id]?.wins ?? 0
                _ = try? events.settleBattle(ticket: ticket, session: fight.session, day: dayNumber, coins: &copper)
                earned["event", default: 0] += copper - before
                if (events.progress[event.id]?.wins ?? 0) > winsBefore { contribute(ticket, .eventBattle) }
                if events.status(event.id, day: dayNumber) == .succeeded { contribute("event-success-\(event.id)", .eventSuccess) }
            }
        }
        if let job = try? remnants.accept(day: dayNumber, closedCaseIDs: cleared, highestTowerFloor: tower), !job.claimed {
            busy("remnant", model.map { total($0.remnant(job.remnant!, lead: job.lead)) } ?? assumptions.remnantInvestigationSeconds)
            _ = try? remnants.answer(day: dayNumber, choiceID: job.remnant!.leads[job.lead].correctChoiceID)
            for _ in 0..<2 where remnants.job(day: dayNumber)?.won == false {
                tickets += 1
                let ticket = "remnant-\(tickets)"
                guard let id = try? remnants.beginBattle(day: dayNumber, ticket: ticket) else { break }
                let fight = streetFight(id, kind: "remnant")
                _ = try? remnants.settleBattle(day: dayNumber, ticket: ticket, session: fight.session)
            }
            if let payout = try? remnants.claim(day: dayNumber, today: dayNumber, work: &work, coins: &copper, inventory: &inventory) {
                remnantsDone += 1; earned["remnant", default: 0] += payout.copper
                contribute("remnant-day-\(dayNumber)", .remnant)
            }
        }
    }

    /// Replays the richest low floor already cleared for materials (no first-clear reward).
    func replayForMaterials() {
        let floor = min(tower, 10)
        let l = loadout(mission: q + 1, gear: stats, passive: passives.last, sequence: cards(forMission: q + 1)[0], bountyRelic: worn)
        guard let report = try? TowerDriver.run(number: floor, medalOffset: 6, suppliedLoadout: l, actionDelay: profile.actionDelay) else { return }
        spend("workshop", report.seconds); replays += 1
        guard report.session.outcome == .victory else { return }
        for (id, n) in MPCTowerMaterials.drops(floor: floor) { inventory[id, default: 0] += n }
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
        if let m = model, visitedMissions.insert(mission).inserted { busy("main", total(m.storyFirstVisit(mission))) }
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
                copper += reward.copper; merit += reward.merit; earned["main", default: 0] += reward.copper
                q = mission
                contribute("mission-\(mission)", .mission)
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
        if let m = model, churchVisitDay != day { churchVisitDay = day; busy("tower", total(m.churchVisit)) }
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
                    copper += reward.coins; merit += reward.merit; earned["tower", default: 0] += reward.coins
                    for (id, n) in MPCTowerMaterials.drops(floor: floor) { inventory[id, default: 0] += n }
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
        if let m = model, investigatedCases.insert(id).inserted { busy("bounty", total(m.bountyInvestigation(id))) }
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
                    contribute("bounty-\(id)", .bounty)
                    copper += bounty.copper; merit += bounty.merit; earned["bounty", default: 0] += bounty.copper
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
        postal(upTo: next.price + salvePrice)
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
            if salve == 0 { postal(upTo: salvePrice) }
            rotation = retry
            if attemptMain(stopAfterSalve: true) { return true }
        }
        return false
    }

    func run() -> RunResult {
        var stuckAt: Int?
        // Days waited for J0 pay since the story last moved; three in a row with nothing new is stuck.
        var copperWaits = 0, lastMission = q
        while q < 30 {
            if q != lastMission { lastMission = q; copperWaits = 0 }
            if dayNumber > assumptions.maxDays { stuckAt = q + 1; break }
            towerGated = false; copperShort = false
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
            // Out of today's J0 work before the copper was there: tomorrow pays in full again.
            if !advanced && copperShort && copperWaits < 3 { copperWaits += 1; nextDay(); continue }
            if !advanced { stuckAt = q + 1; break }
        }
        return RunResult(policy: policy.rawValue, profile: profile.name, startOffset: startOffset, assumptions: assumptions,
                         finalMission: q, stuckAt: stuckAt, days: dayNumber,
                         minutes: seconds.mapValues { ($0 / 60 * 10).rounded() / 10 },
                         battleSecondsByKind: battleOnly.mapValues { ($0 * 10).rounded() / 10 },
                         minutesByDay: dayMinutes.map { ($0 * 10).rounded() / 10 },
                         battles: battles, losses: losses, salvesUsed: salvesUsed, postalJobs: postalJobs,
                         repairCopper: repairCopper, defeatCopperLost: defeatCopperLost, relicsLost: relicsLost,
                         copper: copper, copperBySource: earned,
                         workshop: .init(crafts: crafts, salvesCrafted: salvesCrafted, salvesUsedFromStock: salvesFromStock,
                                         unitsSold: unitsSold, boardPaid: orders.paid, baseStockCopper: baseStockCopper,
                                         replays: replays, proficiency: crafting.proficiency),
                         daily: .init(errands: errandsDone, remnants: remnantsDone,
                                      eventWins: Dictionary(uniqueKeysWithValues: MPCCityEventCatalog.all.map { ($0.id, events.progress[$0.id]?.wins ?? 0) }),
                                      eventStatus: Dictionary(uniqueKeysWithValues: MPCCityEventCatalog.all.map { ($0.id, events.status($0.id, day: dayNumber).rawValue) }),
                                      storiesUnlocked: MPCNeighborCatalog.all.reduce(0) { $0 + neighbors.stories($1.id).count },
                                      missedErrands: missedErrands,
                                      contribution: contribution.points, contributionTierDays: contributionTierDays,
                                      contributionByDay: contributionByDay),
                         merit: merit, towerFloor: tower, bountiesCleared: cleared.sorted(),
                         passives: passives, bountyRelics: relics.ownedIDs.sorted(), milestones: milestones, visits: visits)
    }
}
