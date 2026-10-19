import Foundation
import Testing
@testable import MistportCombatCore

/// Mission challenge model (2026-10-18). Every battle runs through the production story stepper
/// (`MPCStoryVerificationRunner`) with the stage loadout before the mission (`MPCStageLoadout`: unlocked
/// cards and slots, earned talents and dust, the walls' floors and relic) and `MPCMissionChallengeRecorder`
/// watching each 50 ms tick, exactly as the App would.
enum ChallengeSim {
    struct Setup: Sendable {
        var order: [FoolSkillID]
        var policy: MPCStoryVerificationRunner.Policy = .audit
        var delay: Double = 0
        var jitter: Double = 0
        var seed: UInt64 = 1
        var active: String? = nil
        var passive: String? = MPCChapterOneCatalog.returnGiftClaspRelicID
    }

    /// Named input styles: `audit` (mask on heavy blows, counter, medal at 6 s, ultimate at once), `medal14`,
    /// `nomask` (the medal as the active relic, never the mask), `nocounter`, `noult` (never 我叫无人), `nomask_noult`.
    static func policy(_ name: String, order: [FoolSkillID]) -> Setup {
        var s = Setup(order: order)
        switch name {
        case "medal14": s.policy = .init(medalFrom: 14)
        case "nomask": s.policy = .init(mask: false, medalFrom: 6); s.active = RealLoop.medal
        case "nocounter": s.policy = .init(counter: false)
        case "noult": s.policy = .init(ultimateFrom: .infinity)
        case "nomask_noult": s.policy = .init(mask: false, medalFrom: 6, ultimateFrom: .infinity); s.active = RealLoop.medal
        case "nomask14": s.policy = .init(mask: false, medalFrom: 14); s.active = RealLoop.medal
        case "cores": s.policy = .init(target: .supportFirst)
        case "nomask_cores": s.policy = .init(mask: false, medalFrom: 6, target: .supportFirst); s.active = RealLoop.medal
        case "norelic": s.policy = .init(mask: false, medalFrom: nil); s.active = RealLoop.medal
        default: break
        }
        return s
    }

    static func run(_ q: Int, _ s: Setup) throws -> MPCMissionBattleStats {
        let loadout = MPCStageLoadout.loadout(before: q, order: s.order, gear: MPCStageLoadout.wallGear(beforeOrAt: q),
                                              bountyRelic: MPCStageLoadout.wallRelic(q), passive: s.passive, activeRelic: s.active)
        nonisolated(unsafe) var recorder = MPCMissionChallengeRecorder()
        let report = try MPCStoryVerificationRunner.run(mission: q, loadout: loadout, policy: s.policy,
                                                        tuning: .init(jitter: s.jitter, seed: s.seed, actionDelay: s.delay),
                                                        observe: { recorder.observe($0.session, at: $0.now - MPCChurchBattleDriver.step) })
        return recorder.stats(for: report.session)
    }
}

@Suite("Mission challenges")
struct MissionChallengeTests {
    /// Model dump for tuning (MISSION_CHALLENGE_DUMP=<csv path>): every audit arrangement before each mission,
    /// with perfect and non-perfect inputs.
    @Test func dumpModel() async throws {
        guard let path = ProcessInfo.processInfo.environment["MISSION_CHALLENGE_DUMP"] else { return }
        struct Item: Sendable { let q: Int; let variant: String; let setup: ChallengeSim.Setup }
        var items: [Item] = []
        let only = ProcessInfo.processInfo.environment["MISSION_CHALLENGE_ONLY"].map { Set($0.split(separator: ",").compactMap { Int($0) }) }
        for q in 1...30 where only?.contains(q) ?? true {
            for order in MPCStageLoadout.orders(before: q) {
                items.append(.init(q: q, variant: "audit", setup: .init(order: order)))
                items.append(.init(q: q, variant: "slow", setup: .init(order: order, delay: 0.2, jitter: 0.1, seed: 7)))
                if q >= 10 { items.append(.init(q: q, variant: "medal14", setup: .init(order: order, policy: .init(medalFrom: 14), delay: 0.1, jitter: 0.1, seed: 3))) }
                if (5...9).contains(q) {
                    items.append(.init(q: q, variant: "nomask", setup: .init(order: order, policy: .init(mask: false, medalFrom: 6), delay: 0.1, jitter: 0.1, seed: 3, active: RealLoop.medal)))
                }
            }
        }
        let rows = try await RealLoop.map(items) { item -> String in
            let s = try ChallengeSim.run(item.q, item.setup)
            let casts = s.casts.map { String($0.skill.rawValue.suffix(2)) + "@" + ($0.targetID ?? "-") }.joined(separator: " ")
            return [String(item.q), item.variant, RealLoop.name(item.setup.order), s.won ? "1" : "0", String(format: "%.2f", s.seconds),
                    String(format: "%.1f", s.damageTakenPercent), String(s.maskCatches), String(s.counters), s.ultimateUsed ? "1" : "0",
                    String(s.revivesUsed), String(s.medicinesUsed), casts].joined(separator: ",")
        }
        try (["q,variant,order,won,seconds,damage,mask,counters,ultimate,revives,medicines,casts"] + rows).joined(separator: "\n")
            .write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Retry robustness for tuning (MISSION_CHALLENGE_SPEC=<spec>, MISSION_CHALLENGE_OUT=<csv>): each spec line
    /// `q;label;order;policy` plays seeds 1–6 at 0.15 s and 0.3 s reaction delay with 0.1 s jitter.
    @Test func exploreRetries() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let spec = env["MISSION_CHALLENGE_SPEC"], let out = env["MISSION_CHALLENGE_OUT"] else { return }
        struct Item: Sendable { let q: Int; let label: String; let policy: String; let setup: ChallengeSim.Setup }
        var byMission: [Int: [Item]] = [:]
        for line in try String(contentsOfFile: spec, encoding: .utf8).split(separator: "\n") {
            let f = line.split(separator: ";").map(String.init)
            guard f.count >= 4, let q = Int(f[0]) else { continue }
            let single = f.count > 4 && f[4] == "1"
            for seed in UInt64(1)...(single ? 1 : 6) {
                for delay in single ? [0.15] : [0.15, 0.3] {
                    var setup = ChallengeSim.policy(f[3], order: RealLoop.line(f[2]))
                    setup.delay = delay; setup.jitter = 0.1; setup.seed = seed
                    byMission[q, default: []].append(.init(q: q, label: f[1], policy: f[3], setup: setup))
                }
            }
        }
        FileManager.default.createFile(atPath: out, contents: Data("q,label,policy,seed,delay,order,won,seconds,damage,mask,counters,ultimate,revives,medicines,relics,fallen,casts\n".utf8))
        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: out))
        defer { try? handle.close() }
        for q in byMission.keys.sorted() {
            let items = byMission[q]!
            let rows = try await RealLoop.map(items) { item -> String in
                let s = try ChallengeSim.run(item.q, item.setup)
                let casts = s.casts.map { String($0.skill.rawValue.suffix(2)) + "@" + ($0.targetID ?? "-") }.joined(separator: " ")
                return [String(item.q), item.label, item.policy, String(item.setup.seed), String(item.setup.delay), RealLoop.name(item.setup.order).replacingOccurrences(of: ",", with: "-"),
                        s.won ? "1" : "0", String(format: "%.2f", s.seconds), String(format: "%.1f", s.damageTakenPercent), String(s.maskCatches),
                        String(s.counters), s.ultimateUsed ? "1" : "0", String(s.revivesUsed), String(s.medicinesUsed), String(s.activeRelicUses),
                        s.defeatOrder.joined(separator: "|"), casts].joined(separator: ",")
            }
            handle.seekToEndOfFile()
            handle.write(Data((rows.joined(separator: "\n") + "\n").utf8))
        }
    }

    /// One steady line per star, from the retry runs (each met the star in at least 10 of 12 tries at 0.15 s
    /// and 0.3 s reaction delay; most 12 of 12). (mission, star, order, ChallengeSim.policy name)
    static let proofs: [(Int, Int, String, String)] = [
        (1, 1, "01", "audit"),
        (1, 2, "01", "audit"),
        (1, 3, "01", "audit"),
        (2, 1, "05,01", "audit"),
        (2, 2, "05,01", "audit"),
        (2, 3, "05,01", "audit"),
        (3, 1, "05,01", "audit"),
        (3, 2, "05,01", "audit"),
        (3, 3, "05,01", "audit"),
        (4, 1, "05,01", "audit"),
        (4, 2, "05,01", "audit"),
        (4, 3, "05,01", "audit"),
        (5, 1, "05,01", "audit"),
        (5, 2, "05,01", "norelic"),
        (5, 3, "05,01", "audit"),
        (6, 1, "05,08", "norelic"),
        (6, 2, "05,01", "audit"),
        (6, 3, "05,08", "norelic"),
        (7, 1, "11,01,09", "nomask"),
        (7, 2, "11,09,01", "nomask"),
        (7, 3, "08,11,01", "audit"),
        (8, 1, "09,05,04", "audit"),
        (8, 2, "05,08,04", "audit"),
        (8, 3, "09,05,04", "audit"),
        (9, 1, "12,09,08", "audit"),
        (9, 2, "11,12,04", "audit"),
        (9, 3, "12,11,01", "cores"),
        (10, 1, "11,01,09,12", "audit"),
        (10, 2, "11,01,09,12", "audit"),
        (10, 3, "11,01,09,12", "audit"),
        (11, 1, "12,11,01,09", "audit"),
        (11, 2, "11,12,04,07", "audit"),
        (11, 3, "12,04,07,11", "audit"),
        (12, 1, "13,11,12,09", "audit"),
        (12, 2, "13,11,12,09", "audit"),
        (12, 3, "09,08,06,07", "audit"),
        (13, 1, "12,04,07,11", "audit"),
        (13, 2, "11,13,12,09", "audit"),
        (13, 3, "11,13,12,09", "audit"),
        (14, 1, "13,12,09,11", "audit"),
        (14, 2, "13,12,09,11", "audit"),
        (14, 3, "07,05,04,06", "audit"),
        (15, 1, "13,12,09,11", "audit"),
        (15, 2, "13,12,09,11", "audit"),
        (15, 3, "11,01,09,12", "audit"),
        (16, 1, "13,12,09,11", "audit"),
        (16, 2, "12,04,11,07", "audit"),
        (16, 3, "12,04,07,11", "audit"),
        (17, 1, "13,12,09,11", "audit"),
        (17, 2, "12,04,07,11", "audit"),
        (17, 3, "09,08,06,07", "audit"),
        (18, 1, "13,12,09,11", "audit"),
        (18, 2, "12,04,11,07", "audit"),
        (18, 3, "13,12,09,11", "audit"),
        (19, 1, "12,04,11,07", "audit"),
        (19, 2, "12,04,11,07", "audit"),
        (19, 3, "07,05,04,06", "audit"),
        (20, 1, "12,11,01,09", "audit"),
        (20, 2, "11,12,05,01", "norelic"),
        (20, 3, "12,11,01,09", "audit"),
        (21, 1, "13,12,09,11", "audit"),
        (21, 2, "13,12,09,11", "audit"),
        (21, 3, "12,11,01,09", "audit"),
        (22, 1, "13,12,09,11", "audit"),
        (22, 2, "12,04,11,07", "audit"),
        (22, 3, "12,04,07,11", "audit"),
        (23, 1, "13,12,09,11", "audit"),
        (23, 2, "13,12,09,11", "audit"),
        (23, 3, "13,12,09,11", "audit"),
        (24, 1, "13,12,09,11", "audit"),
        (24, 2, "12,11,01,09", "audit"),
        (24, 3, "12,11,01,09", "audit"),
        (25, 1, "13,12,09,11", "audit"),
        (25, 2, "12,11,01,09", "audit"),
        (25, 3, "05,04,06,07", "audit"),
        (26, 1, "12,04,07,11", "audit"),
        (26, 2, "12,04,07,11", "audit"),
        (26, 3, "12,04,07,11", "audit"),
        (27, 1, "13,12,09,11", "audit"),
        (27, 2, "13,12,09,11", "audit"),
        (27, 3, "11,13,12,09", "audit"),
        (28, 1, "13,12,09,11", "audit"),
        (28, 2, "12,04,07,11", "audit"),
        (28, 3, "09,08,06,07", "audit"),
        (29, 1, "12,11,01,09", "audit"),
        (29, 2, "13,12,09,11", "audit"),
        (29, 3, "12,04,07,11", "audit"),
        (30, 1, "12,04,11,07", "audit"),
        (30, 2, "12,04,11,07", "audit"),
        (30, 3, "07,05,04,06", "audit")
    ]

    @Test func everyMissionHasThreeReadableStars() {
        for q in 1...30 {
            let stars = MPCMissionChallengeCatalog.challenges(for: q)
            #expect(stars.count == 3, "Q\(q)")
            #expect(Set(stars.map(\.id)).count == 3)
            for star in stars {
                #expect(!star.title.isEmpty && !star.detail.isEmpty && !star.title.contains("fool_skill"), "\(star.id)")
                switch star.kind {
                case .combo(let id):
                    let cards = MPCMissionChallengeCatalog.comboCards(id)
                    #expect(cards?.count == 4, "\(star.id)")
                    #expect(cards?.allSatisfy { MPCStageLoadout.available(before: q).contains($0) } == true, "\(star.id) uses a card not held yet")
                case .chain(let cards):
                    #expect(cards.count <= MPCStageLoadout.capacity(before: q) && cards.allSatisfy { MPCStageLoadout.available(before: q).contains($0) }, "\(star.id)")
                case .defeatFirst(let contentID):
                    let encounter = MPCChapterOneCatalog.encounters.first { $0.id == String(format: "chapter01_q%02d_encounter", q) }
                    #expect(encounter?.waves.flatMap(\.enemyIDs).contains(contentID) == true, "\(star.id)")
                case .withoutRevive: #expect(q >= 28)
                default: break
                }
            }
        }
        #expect(MPCMissionChallengeCatalog.all.count == 90)
        #expect(Self.proofs.count == 90)
    }

    /// Every star is reachable: its proof line, played through the production stepper with a 0.15 s
    /// reaction delay, wins and meets it.
    @Test func everyStarHasAProofRoute() async throws {
        let results = try await RealLoop.map(Self.proofs.map { $0 }) { proof -> String? in
            let (q, star, order, policy) = proof
            var setup = ChallengeSim.policy(policy, order: RealLoop.line(order))
            setup.delay = 0.15; setup.jitter = 0.1; setup.seed = 1
            let stats = try ChallengeSim.run(q, setup)
            let challenge = MPCMissionChallengeCatalog.challenges(for: q)[star - 1]
            return stats.won && challenge.isMet(by: stats) ? nil
                : "\(challenge.id) \(challenge.title): \(order)/\(policy) won=\(stats.won) t=\(stats.seconds) dmg=\(stats.damageTakenPercent)"
        }
        let misses = results.compactMap { $0 }
        #expect(misses.isEmpty, "\(misses)")
    }

    @Test func starsPayTheirDustOnce() {
        var ledger = MPCMissionChallengeLedger()
        let win = MPCMissionBattleStats(mission: 10, won: true, seconds: 20, enteringMaxHP: 1000, damageTaken: 100)
        let first = ledger.claim(win)
        #expect(first.newlyEarned.map(\.star) == [1, 2])
        #expect(first.dust == 2 * MPCMissionChallengeCatalog.dustPerStar(mission: 10))
        let again = ledger.claim(win)
        #expect(again.newlyEarned.isEmpty && again.dust == 0 && again.alreadyEarned.count == 2)
        let loss = MPCMissionBattleStats(mission: 10, won: false, seconds: 5, enteringMaxHP: 1000, damageTaken: 0)
        #expect(ledger.claim(loss).dust == 0)
        #expect(ledger.stars(mission: 10) == 2 && ledger.totalStars == 2)
        let decoded = try? JSONDecoder().decode(MPCMissionChallengeLedger.self, from: JSONEncoder().encode(ledger))
        #expect(decoded == ledger)
    }

    @Test func probeTiming() throws {
        let start = Date()
        let s = try ChallengeSim.run(12, .init(order: RealLoop.line("11,07,12,04")))
        print("PROBE Q12 won=\(s.won) t=\(s.seconds) dmg=\(s.damageTakenPercent) casts=\(s.casts.count) wall=\(Date().timeIntervalSince(start))")
    }
}
