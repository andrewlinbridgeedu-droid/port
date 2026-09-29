import Foundation
import MistportCombatCore

// Usage: swift run -c release ProgressionSim <output-dir> [start-offsets comma separated]
//        swift run -c release ProgressionSim walls <output-dir> [missions comma separated] [profiles comma separated]
WallTuning.apply(ProcessInfo.processInfo.environment["WALLS"])
PacingTuning.apply(ProcessInfo.processInfo.environment["PACING"])
var arguments = CommandLine.arguments
if arguments.count > 5 && arguments[1] == "fight" {
    // fight <mission> <profile> <floor> <bounty relic id or -> : every shop relic, medal time and salve choice.
    let q = Int(arguments[2])!, profile = (Profile.all + HumanPace.all.map(\.profile)).first { $0.name == arguments[3] } ?? Profile(name: "delay", actionDelay: Double(arguments[3]) ?? 0, priorityCore: true), floor = Int(arguments[4])!
    let relic = arguments[5] == "-" ? nil : arguments[5]
    let owned = Shop.passives.filter { q - 1 >= $0.unlock }.map { Optional($0.id) }
    for (n, sequence) in cards(forMission: q).enumerated() {
        for passive in q >= 5 && !owned.isEmpty ? owned : [nil] {
            for offset in q >= 5 ? [6.0, 14.0] as [Double?] : [nil] {
                for salve in [false, true] {
                    let f = WallProbe.fight(q, profile, floor: floor, relic: relic, passive: passive, sequence: sequence, offset: offset, salve: salve)
                    print("cards#\(n) \((passive ?? "-").padding(toLength: 34, withPad: " ", startingAt: 0)) medal \(offset.map { String(Int($0)) } ?? "-") salve \(salve ? "y" : "n")  \(f.won ? "WIN " : "lose") hp \(f.hpPercent)% \(Int(f.seconds))s")
                }
            }
        }
    }
    exit(0)
}
if arguments.count > 1 && arguments[1] == "human" {
    // human <output-dir> [start offsets]: modelled human timing table and human-pace campaign runs.
    let destination = URL(fileURLWithPath: arguments.count > 2 ? arguments[2] : FileManager.default.currentDirectoryPath)
    let offsets = arguments.count > 3 ? arguments[3].split(separator: ",").compactMap { Int($0) } : [0, 30, 90]
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let start = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 12))!
    try HumanReport.run(destination: destination, offsets: offsets, startDate: start)
    exit(0)
}
if arguments.count > 1 && arguments[1] == "walls" {
    arguments.remove(at: 1)
    let destination = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : FileManager.default.currentDirectoryPath)
    let missions = arguments.count > 2 ? arguments[2].split(separator: ",").compactMap { Int($0) } : MPCProgressionWalls.walls.map(\.mission)
    let names = arguments.count > 3 ? arguments[3].split(separator: ",").map(String.init) : ["high", "medium"]
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    let rows = WallProbe.rows(missions: missions, profiles: Profile.all.filter { names.contains($0.name) })
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(rows).write(to: destination.appendingPathComponent("walls.json"))
    exit(0)
}
let destination = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : FileManager.default.currentDirectoryPath)
let offsets = arguments.count > 2 ? arguments[2].split(separator: ",").compactMap { Int($0) } : [0, 30, 90]
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let startDate = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 12))!
let assumptions = Assumptions()
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

// 1. Serial new saves. Only the bounty board depends on the start date.
var runs: [RunResult] = []
for policy in Policy.allCases {
    for profile in Profile.all {
        for offset in (policy == .mainOnly || policy == .mainTower) ? [offsets[0]] : offsets {
            let result = Campaign(policy: policy, profile: profile, assumptions: assumptions,
                                  startDate: startDate, startOffset: offset).run()
            runs.append(result)
            let total = result.minutes.values.reduce(0, +)
            print("\(policy.rawValue.padding(toLength: 13, withPad: " ", startingAt: 0)) \(profile.name.padding(toLength: 6, withPad: " ", startingAt: 0)) day+\(offset): reached Q\(result.finalMission)"
                  + (result.stuckAt.map { " STUCK at Q\($0)" } ?? " done") + String(format: " · %.0f min", total))
        }
    }
}
try encoder.encode(runs).write(to: destination.appendingPathComponent("runs.json"))

// 2. Gate map: least tower gear a well-equipped story player needs for each mission.
// Shop relics unlocked by then are assumed bought (J0 can always pay for them).
struct Gate: Codable {
    let mission: Int
    let profile: String
    let winsWithoutChurchGear: Bool
    let minTowerFloor: Int?
    let towerFloorOpenAtThisPoint: Int
    let winsWithAllBountyRelics: Bool
}
let breakpoints = [0, 2, 4, 6, 8, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
func towerGear(through floor: Int) -> MPCChurchGearStats {
    var ledger = MPCChurchGearLedger()
    if floor > 0 { for f in 1...floor { if let drop = MPCChurchGearCatalog.towerDrop(floor: f) { ledger.grant(drop.id) } } }
    return ledger.stats
}
let allBountyRelics = Set(MPCBountyRelicCatalog.all.map(\.id))
func wins(_ q: Int, _ profile: Profile, _ gear: MPCChurchGearStats, bountyRelics: Set<String> = []) -> Bool {
    let owned = Shop.passives.filter { q - 1 >= $0.unlock }.map { Optional($0.id) }
    for sequence in cards(forMission: q) {
        for passive in q >= 5 && !owned.isEmpty ? owned : [nil] {
            for offset in q >= 5 ? [6.0, 14.0] as [Double?] : [nil] {
                let relic = bountyRelicCandidates(mission: q, owned: bountyRelics)[0]
                let l = loadout(mission: q, gear: gear, passive: passive, sequence: sequence, bountyRelic: relic)
                let report = try! ChapterDriver.run(q: q, sequence: sequence, mask: q == 3 || q == 4,
                                                    consumables: q >= 5 ? ["consumable_pain_salve": 1] : [:],
                                                    priorityCore: profile.priorityCore, ultimate: q >= 14, loadout: l,
                                                    medalOffset: offset, precise: true, actionDelay: profile.actionDelay)
                if report.session.outcome == .victory { return true }
            }
        }
    }
    return false
}
var gates: [Gate] = []
for q in 1...30 {
    for profile in Profile.all {
        let bare = wins(q, profile, .init())
        var minimum: Int? = bare ? 0 : nil
        if !bare {
            // More gear never makes a battle harder: binary search the breakpoints.
            var lo = 1, hi = breakpoints.count - 1
            if wins(q, profile, towerGear(through: 100)) {
                while lo < hi { let mid = (lo + hi) / 2; if wins(q, profile, towerGear(through: breakpoints[mid])) { hi = mid } else { lo = mid + 1 } }
                minimum = breakpoints[lo]
            }
        }
        gates.append(.init(mission: q, profile: profile.name, winsWithoutChurchGear: bare, minTowerFloor: minimum,
                           towerFloorOpenAtThisPoint: q - 1 >= 7 ? towerLimit(completed: q - 1) : 0,
                           winsWithAllBountyRelics: bare || wins(q, profile, .init(), bountyRelics: allBountyRelics)))
    }
}
try encoder.encode(gates).write(to: destination.appendingPathComponent("gate-map.json"))
print("Wrote \(runs.count) serial runs and \(gates.count) gate checks to \(destination.path)")
