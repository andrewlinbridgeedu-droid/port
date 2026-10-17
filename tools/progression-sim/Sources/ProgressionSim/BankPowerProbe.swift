import Foundation
import MistportCombatCore

enum BankPowerProbe {
    struct Row: Codable {
        let mission: Int, floor: Int, profile: String, passive: String?, price: Int
        let won: Bool, hpPercent: Int, seconds: Double
    }
    static func run(to destination: URL) throws {
        var rows: [Row] = []
        for q in [5, 12, 18, 22, 26, 30] {
            let floor = MPCProgressionWalls.walls.filter { $0.mission <= q }.compactMap(\.towerFloor).max() ?? 0
            let relic = MPCProgressionWalls.wall(mission: q)?.caseID.flatMap { MPCBountyRelicCatalog.relic(forCase: $0)?.id }
            for profile in Profile.all {
                let items: [(String?, Int)] = [(nil, 0)] + Shop.passives.filter { $0.unlock < q }.map { (Optional($0.id), $0.price) }
                for (passive, price) in items {
                    let f = WallProbe.fight(q, profile, floor: floor, relic: relic, passive: passive,
                                           sequence: cards(forMission: q)[0], offset: 6, salve: true)
                    rows.append(.init(mission: q, floor: floor, profile: profile.name, passive: passive,
                                      price: price, won: f.won, hpPercent: f.hpPercent, seconds: f.seconds))
                }
            }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rows).write(to: destination)
        print("Wrote \(rows.count) fixed-loadout combat comparisons")
    }
}
