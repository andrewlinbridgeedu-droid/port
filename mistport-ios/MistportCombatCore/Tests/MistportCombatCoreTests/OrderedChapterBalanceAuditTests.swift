import Foundation
import Testing
@testable import MistportCombatCore

/// The exhaustive real-loop audits, env-gated (minutes each); the default suite runs the focused
/// per-contract checks. Every battle goes through the production steppers with stage-legal loadouts.
@Suite(.serialized)
struct OrderedChapterBalanceAuditTests {
    var env: [String: String] { ProcessInfo.processInfo.environment }

    /// MISTPORT_ORDER_AUDIT=<json> [MISTPORT_ORDER_MISSIONS=1,…]: every audit arrangement of every listed mission.
    @Test func productionAudit() async throws {
        guard let output = env["MISTPORT_ORDER_AUDIT"] else { return }
        let missions = (env["MISTPORT_ORDER_MISSIONS"] ?? "4,8,12,18,30").split(separator: ",").compactMap { Int($0) }
        var rows: [[String: Any]] = []
        for q in missions {
            let orders = MPCStageLoadout.orders(before: q)
            let reports = try await RealLoop.map(orders) { try MPCStoryVerificationRunner.audit(mission: q, order: $0) }
            var wins: [[String: Any]] = [], losses: [[String: Any]] = []
            for (order, r) in zip(orders, reports) {
                let result: [String: Any] = ["order": order.map(\.rawValue), "hp": r.session.playerHP,
                    "ticks": Int((r.seconds / MPCChurchBattleDriver.step).rounded()) + 1, "remaining": r.enemyHPLeft]
                if r.won { wins.append(result) } else { losses.append(result) }
            }
            #expect(!wins.isEmpty, "Q\(q) needs an earned winning arrangement")
            rows.append(["mission": q, "tested": orders.count, "wins": wins, "losses": losses])
            print("ORDER_AUDIT Q\(q) wins=\(wins.count)/\(orders.count)")
            let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: URL(fileURLWithPath: output))
        }
    }

    /// MISTPORT_WALL_AUDIT=1: each wall at every arrangement, outfit and reaction profile (0, 0.25, 0.8 s),
    /// without its requirement (must be 0) and with it.
    @Test func wallAudit() async throws {
        guard env["MISTPORT_WALL_AUDIT"] != nil else { return }
        struct Case: Sendable { let q: Int; let bareGear: Int; let bareRelic: Bool }
        // Mechanism walls without their relic wear all the tower open then; tower walls a decade short.
        let cases = [Case(q: 12, bareGear: 30, bareRelic: false), Case(q: 22, bareGear: 80, bareRelic: false), Case(q: 30, bareGear: 100, bareRelic: false),
                     Case(q: 18, bareGear: 40, bareRelic: true), Case(q: 26, bareGear: 60, bareRelic: true), Case(q: 30, bareGear: 80, bareRelic: true)]
        for c in cases {
            let orders = MPCStageLoadout.orders(before: c.q)
            for outfit in MPCOutfit.allCases {
                for delay in [0.0, 0.25, 0.8] {
                    let bare = try await RealLoop.map(orders) { try RealLoop.story(c.q, $0, gear: MPCStageLoadout.towerGear(through: c.bareGear),
                        relic: c.bareRelic ? .none : .some(nil), delay: delay, outfit: outfit).won }.filter { $0 }.count
                    let worn = try await RealLoop.map(orders) { try RealLoop.story(c.q, $0, delay: delay, outfit: outfit).won }.filter { $0 }.count
                    print("WALL_AUDIT Q\(c.q) short=\(c.bareRelic ? "F\(c.bareGear)" : "no relic") \(outfit.rawValue) d=\(delay) short=\(bare)/\(orders.count) met=\(worn)/\(orders.count)")
                    #expect(bare == 0)
                }
            }
        }
    }

    /// MISTPORT_Q30_AUDIT=1: Q30 with F90 and the ledger in every farewell-blessing pair: the four ordinary
    /// relics against the clasp, every arrangement.
    @Test func q30BlessingAudit() async throws {
        guard env["MISTPORT_Q30_AUDIT"] != nil else { return }
        let orders = MPCStageLoadout.orders(before: 30)
        let pairs: [MPCFarewellBlessings?] = [nil] + MPCFarewellBlessings.Hero.allCases.flatMap { h in MPCFarewellBlessings.Sovereign.allCases.map { MPCFarewellBlessings(hero: h, sovereign: $0) } }
        for passive in [RealLoop.clasp, RealLoop.bag, "relic_reflecting_ink_mirror", "relic_countertide_anchor", "relic_ownership_severing_needle"] {
            for pair in pairs {
                let wins = try await RealLoop.map(orders) { order in try RealLoop.story(30, order, passive: passive) { s in if let pair { _ = s.applyFarewellBlessings(pair) } }.won }.filter { $0 }.count
                print("Q30_AUDIT \(passive) \(pair.map { "\($0.hero.rawValue)+\($0.sovereign.rawValue)" } ?? "none") wins=\(wins)/\(orders.count)")
            }
        }
    }

    /// MISTPORT_TOWER_AUDIT=1: the tower curve, every arrangement of the stage: at the pace stage with the gear
    /// below, three missions earlier, a decade of gear short, and with no gear; then the Q7 hand without input.
    @Test func towerAudit() async throws {
        guard env["MISTPORT_TOWER_AUDIT"] != nil else { return }
        // MISTPORT_TOWER_STRENGTH=100 replays the uncalibrated tower (before the catalog is first built).
        if let flat = env["MISTPORT_TOWER_STRENGTH"].flatMap(Int.init) { MPCChurchTowerCatalog.decadeStrength = Array(repeating: (flat, flat), count: 10) }
        let floors = (env["MISTPORT_TOWER_FLOORS"] ?? "10,20,30,40,50,60,70,80,90,100").split(separator: ",").compactMap { Int($0) }
        for n in floors {
            let id = try #require(MPCChurchTowerCatalog.floor(number: n)).id, pace = MPCChurchTowerCatalog.paceMission(floor: n)
            var line = "TOWER_AUDIT F\(n) pace=Q\(pace)"
            for (label, stage, gear) in [("pace", pace, n - 1), ("pace-3", max(2, pace - 3), n - 1), ("gear-10", pace, max(0, n - 11)), ("no-gear", pace, 0)] {
                let orders = MPCStageLoadout.orders(before: stage + 1)
                let reports = try await RealLoop.map(orders) { try RealLoop.church(id, before: stage + 1, order: $0, gearThrough: gear) }
                let won = reports.filter { $0.session.outcome == .victory }
                let best = won.map { $0.session.playerHP * 100 / max(1, $0.session.playerNormalMaxHP) }.max() ?? -1
                line += " \(label)=\(won.count)/\(orders.count)(best \(best)%)"
            }
            let q7 = try await RealLoop.map(MPCStageLoadout.orders(before: 7)) { order -> Bool in
                var game = try MPCChurchBattleStepper(encounterID: id, loadout: MPCStageLoadout.loadout(before: 7, order: order, passive: nil))
                while !game.isFinished { _ = try game.step() }
                return game.session.outcome == .victory
            }.filter { $0 }.count
            print(line + " q7-no-input=\(q7)/60")
        }
    }
}
