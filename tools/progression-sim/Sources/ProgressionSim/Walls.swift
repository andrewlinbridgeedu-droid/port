import Foundation
import MistportCombatCore

/// Fast wall check for tuning MPCProgressionWalls and the wall enemies:
/// `ProgressionSim walls <output-dir>`. Shop relics unlocked by then are assumed bought.
enum WallProbe {
    struct Fight: Codable {
        let won: Bool
        /// Player health left at the end, percent of normal maximum.
        let hpPercent: Int
        let seconds: Double
    }

    struct Row: Codable {
        let mission: Int
        let profile: String
        let towerOpen: Int
        let requirement: String
        /// Nothing from the church: no tower gear, no bounty relic.
        let bare: Bool
        /// Everything earlier walls asked for (their floor, their relics), nothing more.
        let previousOnly: Bool
        /// Every tower floor open at this point, any relic but this wall's.
        let towerOpenNoWallRelic: Bool
        /// Least tower floor needed with the wall's relic worn (nil: not even F100).
        let minFloor: Int?
        /// Requirement met, first card order, 6 s medal, no salve; best shop relic.
        let firstTry: Fight
    }

    static let breakpoints = [0, 2, 4, 6, 8, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]

    static func towerGear(through floor: Int) -> MPCChurchGearStats {
        var ledger = MPCChurchGearLedger()
        if floor > 0 { for f in 1...floor { if let drop = MPCChurchGearCatalog.towerDrop(floor: f) { ledger.grant(drop.id) } } }
        return ledger.stats
    }

    static func fight(_ q: Int, _ profile: Profile, floor: Int, relic: String?, passive: String?,
                      sequence: [FoolSkillID], offset: Double?, salve: Bool) -> Fight {
        let l = loadout(mission: q, gear: towerGear(through: floor), passive: passive, sequence: sequence, bountyRelic: relic)
        let report = try! ChapterDriver.run(q: q, sequence: sequence, mask: q == 3 || q == 4,
                                            consumables: salve && q >= 5 ? ["consumable_pain_salve": 1] : [:],
                                            priorityCore: profile.priorityCore, ultimate: q >= 14, loadout: l,
                                            medalOffset: offset, precise: true, actionDelay: profile.actionDelay)
        let s = report.session
        let normalMax = max(1, s.playerBaseMaxHP)
        return Fight(won: s.outcome == .victory, hpPercent: max(0, s.playerHP) * 100 / normalMax, seconds: report.seconds)
    }

    /// Any card order, shop relic and medal time, with a salve: what the audit bots count as a win.
    static func wins(_ q: Int, _ profile: Profile, floor: Int, relic: String?) -> Bool {
        let owned = Shop.passives.filter { q - 1 >= $0.unlock }.map { Optional($0.id) }
        for sequence in cards(forMission: q) {
            for passive in q >= 5 && !owned.isEmpty ? owned : [nil] {
                for offset in q >= 5 ? [6.0, 14.0] as [Double?] : [nil] {
                    if fight(q, profile, floor: floor, relic: relic, passive: passive, sequence: sequence, offset: offset, salve: true).won { return true }
                }
            }
        }
        return false
    }

    static func rows(missions: [Int], profiles: [Profile]) -> [Row] {
        var out: [Row] = []
        for q in missions {
            let wall = MPCProgressionWalls.wall(mission: q)
            let earlier = MPCProgressionWalls.walls.filter { $0.mission < q }
            func relicID(_ w: MPCProgressionWalls.Wall) -> String? { w.caseID.flatMap { MPCBountyRelicCatalog.relic(forCase: $0)?.id } }
            let wallRelic = wall.flatMap(relicID)
            let previousRelics = Set(earlier.compactMap(relicID))
            let previousFloor = earlier.compactMap(\.towerFloor).max() ?? 0
            let requiredFloor = max(previousFloor, wall?.towerFloor ?? 0)
            let open = q - 1 >= 7 ? towerLimit(completed: q - 1) : 0
            let otherRelics = Set(MPCBountyRelicCatalog.all.map(\.id)).subtracting(wallRelic.map { [$0] } ?? [])
            let worn = wallRelic ?? bountyRelicCandidates(mission: q, owned: previousRelics)[0]
            for profile in profiles {
                var minimum: Int?
                if wins(q, profile, floor: 100, relic: worn) {
                    var lo = 0, hi = breakpoints.count - 1
                    while lo < hi { let mid = (lo + hi) / 2; if wins(q, profile, floor: breakpoints[mid], relic: worn) { hi = mid } else { lo = mid + 1 } }
                    minimum = breakpoints[lo]
                }
                let owned = Shop.passives.filter { q - 1 >= $0.unlock }.map { Optional($0.id) }
                let first = (q >= 5 && !owned.isEmpty ? owned : [nil]).map {
                    fight(q, profile, floor: requiredFloor, relic: worn, passive: $0, sequence: cards(forMission: q)[0],
                          offset: q >= 5 ? 6 : nil, salve: false)
                }.max { ($0.won ? 1 : 0, $0.hpPercent) < ($1.won ? 1 : 0, $1.hpPercent) }!
                let row = Row(mission: q, profile: profile.name, towerOpen: open,
                              requirement: [requiredFloor > 0 ? "F\(requiredFloor)" : nil, wall?.caseID?.uppercased()].compactMap { $0 }.joined(separator: "+"),
                              bare: wins(q, profile, floor: 0, relic: nil),
                              previousOnly: wins(q, profile, floor: previousFloor, relic: bountyRelicCandidates(mission: q, owned: previousRelics)[0]),
                              towerOpenNoWallRelic: wins(q, profile, floor: open, relic: bountyRelicCandidates(mission: q, owned: otherRelics)[0]),
                              minFloor: minimum, firstTry: first)
                func w(_ b: Bool) -> String { b ? "WIN " : "lose" }
                print("Q\(q) \(profile.name.padding(toLength: 6, withPad: " ", startingAt: 0)) req \(row.requirement.padding(toLength: 8, withPad: " ", startingAt: 0))"
                      + " bare \(w(row.bare)) prevOnly \(w(row.previousOnly)) open F\(open)-noWallRelic \(w(row.towerOpenNoWallRelic))"
                      + " minFloor \(minimum.map { "F\($0)" } ?? "none")"
                      + " | first try \(w(first.won)) hp \(first.hpPercent)% \(Int(first.seconds))s")
                out.append(row)
            }
        }
        return out
    }
}
