import Foundation
import MistportCombatCore

/// `ProgressionSim human <output-dir> [start offsets]`: the modelled human timing table for
/// the sixteen activities of the timing template, and the day-by-day campaign at human pace.
/// Output is a model (status "modeled"); it never goes into the device-observation file.
enum HumanReport {
    struct PaceResult: Codable {
        let pace: HumanPace
        let activities: [ActivityTiming]
    }
    struct Output: Codable {
        let schema: Int
        let status: String
        let note: String
        let streetAverageWalkSeconds: Double
        let paces: [PaceResult]
    }

    static func mean(_ values: [Double]) -> Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
    static func averaged(_ lists: [[TimedStep]]) -> [TimedStep] {
        guard let first = lists.first else { return [] }
        if lists.count == 1 { return first }
        // Different items have different step labels: report one averaged line per kind of step count.
        return [TimedStep(label: "平均（\(lists.count) 个内容）", seconds: (mean(lists.map { $0.reduce(0) { $0 + $1.seconds } }) * 10).rounded() / 10)]
    }

    /// Three maintenance sites with a loadout of that point in the story.
    static func maintenanceBattles(_ kind: MPCChurchMaintenanceKind, floor: Int, mission: Int, pace: HumanPace) -> (seconds: Double, wins: Int) {
        var gear = MPCChurchGearLedger()
        for f in 1...floor { if let drop = MPCChurchGearCatalog.towerDrop(floor: f) { gear.grant(drop.id) } }
        let passive = Shop.passives.filter { $0.unlock < mission }.last?.id
        let l = loadout(mission: mission, gear: gear.stats, passive: passive, sequence: cards(forMission: mission)[0], bountyRelic: nil)
        var seconds = 0.0, wins = 0
        for site in 1...3 {
            let id = kind == .patrol ? "church_maintenance_j1_s\(site)_timing-\(site)" : "church_maintenance_j2_f\(floor)_s\(site)_timing-\(site)"
            guard let report = try? TowerDriver.run(number: 1, medalOffset: 6, suppliedLoadout: l, actionDelay: pace.battleActionDelay, encounterID: id) else { continue }
            seconds += report.seconds
            if report.session.outcome == .victory { wins += 1 }
        }
        return (seconds, wins)
    }

    static func activities(pace: HumanPace, run: RunResult?) -> [ActivityTiming] {
        let m = HumanTimingModel(pace: pace)
        func battle(_ kind: String, per count: Double) -> (Double, Int) {
            guard let run, count > 0 else { return (0, 0) }
            return ((run.battleSecondsByKind[kind, default: 0] / count * 10).rounded() / 10,
                    Int((Double(run.battles[kind, default: 0]) / count).rounded()))
        }
        var rows: [ActivityTiming] = []
        // Story: the first visit of an average mission plus every attempt's frame (retries included).
        let story = battle("main", per: 30)
        let storyVisit = averaged((1...30).map { m.storyFirstVisit($0) })
        rows.append(.init(activity: "story", scope: "一关主线，含剧情、准备和结算（含重试）",
                          steps: storyVisit + m.storyAttempt.map { .init(label: $0.label + " ×\(max(1, story.1))", seconds: $0.seconds * Double(max(1, story.1))) },
                          battleSeconds: story.0, battles: story.1))
        let floors = Double(run?.towerFloor ?? 100)
        let tower = battle("tower", per: floors)
        rows.append(.init(activity: "tower", scope: "一层塔，含进出和结算（每天 4 层共用一次进教会）",
                          steps: m.churchVisit.map { .init(label: $0.label + "（÷4）", seconds: $0.seconds / 4) } + m.towerFloor.map { .init(label: $0.label + " ×\(max(1, tower.1))", seconds: $0.seconds * Double(max(1, tower.1))) },
                          battleSeconds: tower.0, battles: tower.1))
        let cases = Double(run?.bountiesCleared.count ?? 10)
        let bounty = battle("bounty", per: cases)
        rows.append(.init(activity: "bounty", scope: "一个通缉案，调查到领奖",
                          steps: averaged(MPCChurchBountyCatalog.all.map { m.bountyInvestigation($0.id) })
                            + m.battleFrame(result: 40, planning: 1).map { .init(label: $0.label + " ×\(max(1, bounty.1))", seconds: $0.seconds * Double(max(1, bounty.1))) },
                          battleSeconds: bounty.0, battles: bounty.1))
        rows.append(.init(activity: "J0", scope: "一单邮务核验，接单到结算", steps: m.postal))
        let j1 = maintenanceBattles(.patrol, floor: 10, mission: 12, pace: pace)
        rows.append(.init(activity: "J1", scope: "一单封口巡检（三处），Q12 时的装备", steps: m.maintenance(.patrol, floor: 10), battleSeconds: (j1.seconds * 10).rounded() / 10, battles: 3))
        let j2 = maintenanceBattles(.towerMaintenance, floor: 50, mission: 17, pace: pace)
        rows.append(.init(activity: "J2", scope: "一单塔内维护（F50 层段三处），Q17 时的装备", steps: m.maintenance(.towerMaintenance, floor: 50), battleSeconds: (j2.seconds * 10).rounded() / 10, battles: 3))
        rows.append(.init(activity: "craft", scope: "一次制作，材料预先持有（进工坊另计 \(Int(m.workshopVisit.reduce(0) { $0 + $1.seconds })) 秒/次）", steps: m.craft))
        rows.append(.init(activity: "sale", scope: "一次卖货，商品预先持有", steps: m.sale))
        let errands = MPCNeighborCatalog.all.flatMap { n in n.errands.map { (n.id, $0) } }
        let pest = battle("errand", per: Double(run?.battles["errand"] ?? 0))
        for kind in [MPCNeighborErrand.Kind.deliver, .find, .message, .pest] {
            let lists = errands.filter { $0.1.kind == kind }.map { m.errand($0.1, asker: $0.0) }
            rows.append(.init(activity: "neighbor_" + kind.rawValue, scope: "街坊委托（\(lists.count) 条平均），走近接单到完成",
                              steps: averaged(lists), battleSeconds: kind == .pest ? pest.0 : 0, battles: kind == .pest ? 1 : 0))
        }
        let street = battle("street", per: Double(run?.battles["street"] ?? 0))
        for kind in MPCStreetTask.Kind.allCases {
            let tasks = MPCStreetTaskCatalog.streetTasks.filter { $0.kind == kind }
            let lists = tasks.map { t in m.streetTaskPost(t) + t.steps.indices.flatMap { m.streetStep(t, $0) } + [m.streetThanks(t)] }
            let fights = Double(tasks.reduce(0) { $0 + $1.steps.filter { $0.action == .battle }.count }) / Double(max(1, tasks.count))
            let scope = ["urgent": "加急委托", "joint": "街区难题", "commission": "城市委托"][kind.rawValue]!
            rows.append(.init(activity: "street_" + kind.rawValue, scope: "\(scope)（\(tasks.count) 条平均），接单到领奖",
                              steps: averaged(lists), battleSeconds: (street.0 * fights * 10).rounded() / 10, battles: Int(fights.rounded())))
        }
        let dou = m.douDizhu()
        rows.append(.init(activity: "tavern", scope: "一局两副牌斗地主（按规则库的出牌规则模拟 20 局）", steps: dou.steps))
        rows.append(.init(activity: "tavern_poker", scope: "一手五张换牌", steps: m.poker))
        rows.append(.init(activity: "event_delivery", scope: "一次事件交货，商品预先持有（每场事件另读一次简报）", steps: m.eventDelivery))
        let event = battle("event", per: Double(run?.battles["event"] ?? 0))
        rows.append(.init(activity: "event_battle", scope: "一场事件战，进板到结算", steps: m.eventBattle, battleSeconds: event.0, battles: 1))
        let remnant = battle("remnant", per: Double(run?.battles["remnant"] ?? 0))
        rows.append(.init(activity: "remnant", scope: "一个残余案，接案、调查、战斗到领奖",
                          steps: averaged(MPCRemnantCatalog.all.flatMap { r in r.leads.indices.map { m.remnant(r, lead: $0) } }),
                          battleSeconds: remnant.0, battles: 1))
        return rows
    }

    static func run(destination: URL, offsets: [Int], startDate: Date) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var runs: [RunResult] = [], results: [PaceResult] = []
        for pace in HumanPace.all {
            var assumptions = Assumptions()
            assumptions.pace = pace
            var reference: RunResult?
            for policy in [Policy.all, .completionist, .hinted] {
                for offset in offsets {
                    let result = Campaign(policy: policy, profile: pace.profile, assumptions: assumptions,
                                          startDate: startDate, startOffset: offset).run()
                    runs.append(result)
                    if policy == .all && offset == offsets[0] { reference = result }
                    let total = result.minutes.values.reduce(0, +)
                    print("human \(pace.name.padding(toLength: 8, withPad: " ", startingAt: 0)) \(policy.rawValue.padding(toLength: 13, withPad: " ", startingAt: 0)) day+\(offset): reached Q\(result.finalMission)"
                          + (result.stuckAt.map { " STUCK at Q\($0)" } ?? " done") + String(format: " · %.0f min · day %d", total, result.days))
                }
            }
            results.append(.init(pace: pace, activities: activities(pace: pace, run: reference)))
        }
        let output = Output(schema: 1, status: "modeled",
                            note: "模拟器估算，不是真人或真机测量；不能写进 timings-template.json 的 samples。",
                            streetAverageWalkSeconds: (StreetMap.averageWalkSeconds * 10).rounded() / 10, paces: results)
        try encoder.encode(output).write(to: destination.appendingPathComponent("timings.json"))
        try encoder.encode(runs).write(to: destination.appendingPathComponent("runs.json"))
        print("Wrote \(runs.count) human-pace runs and the timing table to \(destination.path)")
    }
}
