import Foundation
import MistportCombatCore

// City-trend outcome explorer (user 2026-10-17: "我一个人无法预演，你自己写个程序，看最后能发展出多少种
// 可能性"). Every world runs days 1–28 through MPCCityTrendWorld, the engine the game and the shared
// server use; only the players are made up here: how many, what kind, how often they play and how
// good they are in a fight. Each player follows the shared rules through their own ledger (three
// ordinary points a day, one key vote a stage). Prints a report and writes it as Markdown.
//
//   swift run -c release CityTrendSim [OUTPUT.md] [--quick]

struct RNG {
    var state: UInt64
    init(_ seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func int(_ n: Int) -> Int { Int(next() % UInt64(n)) }
}

let sides = MPCCityFaction.allCases

enum Profile: Hashable {
    case loyal(MPCCityFaction), bandwagon, underdog, swing
    var name: String {
        switch self {
        case .loyal(let side): "死忠\(side.name)"
        case .bandwagon: "随大流"
        case .underdog: "帮弱势"
        case .swing: "随便选"
        }
    }
}

struct Player {
    let id: String
    let profile: Profile
    /// Chance of playing on a given day.
    let presence: Double
    /// Chance of winning an assassination fight (a guard's chance is 80% of it: the attack has the initiative).
    let skill: Double
    /// Own order of sides when the preferred one is not on offer.
    let preference: [MPCCityFaction]
    var ledger = MPCCityTrendLedger()
    var voted: Set<Int> = []
}

/// The two sides each of the 69 neighbour errands offers.
let pairs: [[MPCCityFaction]] = MPCNeighborCatalog.all.flatMap(\.errands).map { MPCNeighborCatalog.ways($0.id).map(\.side) }

func pick(_ player: Player, _ offered: [MPCCityFaction], _ view: MPCCityTrendSnapshot, _ rng: inout RNG) -> MPCCityFaction {
    let points = view.stage.isEmpty ? view.total : view.stage
    let ranked: [MPCCityFaction]
    switch player.profile {
    case .loyal: ranked = player.preference
    // Ties (an empty first morning) are broken at random, not in a fixed order.
    case .bandwagon: ranked = sides.shuffledWith(&rng).sorted { view.share($0, of: points) > view.share($1, of: points) }
    case .underdog: ranked = sides.shuffledWith(&rng).sorted { view.share($0, of: points) < view.share($1, of: points) }
    case .swing: return offered[rng.int(offered.count)]
    }
    return ranked.first { offered.contains($0) }!
}

struct Scenario {
    let name: String
    let players: Int
    let worlds: Int
    let crowdPlots: Bool
    let mix: (Int, inout RNG) -> Profile
}

struct Tally {
    var endings: [MPCCityTrendEnding: Int] = [:]
    var worlds = 0
    var plots = 0, kills = 0, collapses = 0
    /// Worlds where the side with the most loyal players did not end up running the workshop.
    var minorityWorkshop = 0
}

func run(_ scenario: Scenario, salt: UInt64) -> Tally {
    var tally = Tally()
    for w in 0..<scenario.worlds {
        var rng = RNG(salt &* 1_000_003 &+ UInt64(w))
        var world = MPCCityTrendWorld(simulation: .init(seed: rng.next()), crowdPlots: scenario.crowdPlots)
        var players: [Player] = (0..<scenario.players).map { i in
            let profile = scenario.mix(i, &rng)
            var rest = sides.shuffledWith(&rng)
            if case .loyal(let side) = profile { rest.removeAll { $0 == side }; rest.insert(side, at: 0) }
            return Player(id: "p\(i)", profile: profile, presence: 0.55 + 0.45 * rng.unit(), skill: 0.3 + 0.3 * rng.unit(), preference: rest)
        }
        var loyal: [MPCCityFaction: Int] = [:]
        for p in players { if case .loyal(let side) = p.profile { loyal[side, default: 0] += 1 } }
        for day in 1...MPCCityTrendStage.workshop.days.upperBound {
            let view = world.snapshot(day: max(1, day - 1), yours: nil)
            var points: [MPCCityFaction: Double] = [:]
            for i in Array(players.indices).shuffledWith(&rng) {
                guard rng.unit() < players[i].presence else { continue }
                for e in 0..<(2 + rng.int(2)) {
                    let side = pick(players[i], pairs[rng.int(pairs.count)], view, &rng)
                    players[i].ledger.record(id: "d\(day)e\(e)", day: day, side: side, fact: "")
                }
                if let stage = MPCCityTrendStage.stage(day: day), !players[i].voted.contains(stage.rawValue),
                   rng.unit() < 1 / Double(stage.days.upperBound - day + 1) {
                    players[i].ledger.record(id: "key\(stage.rawValue)", day: day, side: pick(players[i], sides, view, &rng), key: true, fact: "")
                    players[i].voted.insert(stage.rawValue)
                }
                if let plot = world.plot, plot.killedDay == nil, MPCCityTrendWorld.plotDays.contains(day) {
                    // Who takes a seat: the other sides' loyalists strike, the target's guard;
                    // the others now and then.
                    var role: Bool?
                    switch players[i].profile {
                    case .loyal(let side): role = rng.unit() < 0.8 ? (side != plot.target) : nil
                    case .bandwagon: role = rng.unit() < 0.5 ? (view.leader != plot.target) : nil
                    case .underdog: role = rng.unit() < 0.7 ? true : nil
                    case .swing: let r = rng.unit(); role = r < 0.3 ? true : r < 0.5 ? false : nil
                    }
                    if let assassin = role {
                        world.attempt(account: players[i].id, assassin: assassin,
                                      success: rng.unit() < (assassin ? players[i].skill : players[i].skill * 0.8))
                    }
                }
                for (side, v) in players[i].ledger.points(on: day) { points[side, default: 0] += Double(v) }
            }
            world.advance(players: points)
        }
        let ending = world.ending!
        tally.endings[ending, default: 0] += 1
        tally.worlds += 1
        if ending.plotTarget != nil { tally.plots += 1 }
        if ending.killed { tally.kills += 1; if ending.aftermath == .collapse { tally.collapses += 1 } }
        if let most = loyal.max(by: { $0.value < $1.value }), most.value > 0, ending.workshop != most.key { tally.minorityWorkshop += 1 }
    }
    return tally
}

extension Array {
    func shuffledWith(_ rng: inout RNG) -> [Element] {
        var a = self
        if a.count > 1 { for i in stride(from: a.count - 1, to: 0, by: -1) { a.swapAt(i, rng.int(i + 1)) } }
        return a
    }
}

let arguments = CommandLine.arguments.dropFirst()
let quick = arguments.contains("--quick")
let output = arguments.first { !$0.hasPrefix("--") }
func n(_ full: Int) -> Int { quick ? max(20, full / 10) : full }

let uniform: (Int, inout RNG) -> Profile = { _, rng in
    [.loyal(.neighbours), .loyal(.offices), .loyal(.compacts), .bandwagon, .underdog, .swing][rng.int(6)]
}
func solo(_ profile: Profile?) -> (Int, inout RNG) -> Profile { { _, _ in profile ?? .swing } }
var scenarios: [Scenario] = [
    .init(name: "单机·不选边（只看模拟人群）", players: 0, worlds: n(3000), crowdPlots: true, mix: solo(nil)),
    .init(name: "单机·死忠街坊", players: 1, worlds: n(3000), crowdPlots: true, mix: solo(.loyal(.neighbours))),
    .init(name: "单机·死忠公署", players: 1, worlds: n(3000), crowdPlots: true, mix: solo(.loyal(.offices))),
    .init(name: "单机·死忠商约", players: 1, worlds: n(3000), crowdPlots: true, mix: solo(.loyal(.compacts))),
    .init(name: "单机·随大流", players: 1, worlds: n(3000), crowdPlots: true, mix: solo(.bandwagon)),
    .init(name: "单机·帮弱势", players: 1, worlds: n(3000), crowdPlots: true, mix: solo(.underdog)),
    .init(name: "单机·随便选", players: 1, worlds: n(3000), crowdPlots: true, mix: solo(.swing)),
    .init(name: "共享服·20 人·各种性格", players: 20, worlds: n(1500), crowdPlots: false, mix: uniform),
    .init(name: "共享服·100 人·各种性格", players: 100, worlds: n(800), crowdPlots: false, mix: uniform),
    .init(name: "共享服·100 人·七三开（七成死忠街坊，三成死忠公署）", players: 100, worlds: n(800), crowdPlots: false,
          mix: { i, _ in i < 70 ? .loyal(.neighbours) : .loyal(.offices) }),
    .init(name: "共享服·400 人·各种性格", players: 400, worlds: n(300), crowdPlots: false, mix: uniform),
    .init(name: "共享服·400 人·六成随大流", players: 400, worlds: n(300), crowdPlots: false,
          mix: { i, rng in i % 10 < 6 ? .bandwagon : uniform(i, &rng) }),
    .init(name: "共享服·400 人·六成帮弱势", players: 400, worlds: n(300), crowdPlots: false,
          mix: { i, rng in i % 10 < 6 ? .underdog : uniform(i, &rng) }),
]

func pct(_ a: Int, _ b: Int) -> String { b == 0 ? "–" : String(format: "%.1f%%", 100 * Double(a) / Double(b)) }

var report: [String] = []
var allEndings: [MPCCityTrendEnding: Int] = [:]
var allWorlds = 0
let started = Date()
report.append("# 城势结局推演（\(quick ? "快速" : "完整")，\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))）\n")
report.append("每个世界都用游戏自己的城势规则（`MPCCityTrendWorld`）从第 1 天跑到第 28 天；只有玩家是程序编的：人数、性格、出勤率和战斗胜率。结局 = 四段各归谁（最后一段定工坊）、整章谁主导、第 21 天谁的领头人露面、是否遇刺身亡以及死后是树倒还是举哀。\n")
for (index, scenario) in scenarios.enumerated() {
    let t = run(scenario, salt: UInt64(index + 1))
    for (k, v) in t.endings { allEndings[k, default: 0] += v }
    allWorlds += t.worlds
    let sorted = t.endings.sorted { $0.value > $1.value }
    let sequences = Set(t.endings.keys.map(\.stages)).count
    var workshop: [MPCCityFaction: Int] = [:], dominant: [MPCCityFaction: Int] = [:]
    for (k, v) in t.endings { workshop[k.workshop, default: 0] += v; dominant[k.dominant, default: 0] += v }
    report.append("## \(scenario.name)（\(t.worlds) 个世界）\n")
    report.append("- 出现了 **\(t.endings.count)** 种不同结局；四段归属的组合出现了 \(sequences)/81 种。")
    report.append("- 最常见的一种占 \(pct(sorted.first?.value ?? 0, t.worlds))，前五种合计 \(pct(sorted.prefix(5).map(\.value).reduce(0, +), t.worlds))。")
    report.append("- 工坊归属：" + sides.map { "\($0.name) \(pct(workshop[$0] ?? 0, t.worlds))" }.joined(separator: " · "))
    report.append("- 整章主导：" + sides.map { "\($0.name) \(pct(dominant[$0] ?? 0, t.worlds))" }.joined(separator: " · "))
    report.append("- 第 21 天有领头人露面：\(pct(t.plots, t.worlds))；露面后遇刺身亡：\(pct(t.kills, t.plots))（其中树倒 \(pct(t.collapses, t.kills))、举哀 \(pct(t.kills - t.collapses, t.kills))）")
    if scenario.players > 1 { report.append("- 死忠人数最多的一边没拿到工坊：\(pct(t.minorityWorkshop, t.worlds))") }
    report.append("\n| 结局 | 占比 |\n|---|---|")
    for (ending, count) in sorted.prefix(6) { report.append("| \(ending.summary) | \(pct(count, t.worlds)) |") }
    report.append("")
    print("DONE \(scenario.name): \(t.endings.count) endings")
}
let theoretical = 81 * 3 * 10
report.insert("**总计**：\(allWorlds) 个世界里出现了 **\(allEndings.count)** 种不同结局（按四段归属 × 主导 × 刺杀情况算，组合上限 \(theoretical) 种，其中很多互相矛盾、不可能出现）；四段归属组合出现了 \(Set(allEndings.keys.map(\.stages)).count)/81 种；工坊三种归属都出现了：\(Set(allEndings.keys.map(\.workshop)).count == 3 ? "是" : "否")。用时 \(Int(Date().timeIntervalSince(started))) 秒。\n", at: 2)
let text = report.joined(separator: "\n")
print(text)
if let output { try text.write(toFile: output, atomically: true, encoding: .utf8) }
