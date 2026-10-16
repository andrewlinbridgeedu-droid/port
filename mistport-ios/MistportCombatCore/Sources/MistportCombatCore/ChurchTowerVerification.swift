import Foundation

/// Deterministic driver of the shipping combat core. Never injects damage,
/// healing, HP or unlocks. Native presentation verification is a separate pass.
public enum MPCChurchTowerVerificationRunner {
    public enum Route: String, CaseIterable, Sendable { case medal, counter, blankCard, unprepared }
    public struct Report: Sendable {
        public let floor: Int
        public let mission: Int
        public let route: Route
        public let session: MPCChapterOneEncounterSession
        public let seconds: Double
        public let waveEntryHP: [Int]
        public let rosterDescriptors: [[String]]
        public let skillCasts: [String: Int]
        public let medalUses: Int
        public var tempoStats = MPCTempoStats()
    }
    /// The stage a floor is played at: missions completed when its first clear opens on the daily pace
    /// (`MPCChurchTowerCatalog.paceMission`; 2026-10-15, was the floor's gate alone).
    public static func mission(for floor: MPCChurchTowerCatalog.Floor) -> Int { MPCChurchTowerCatalog.paceMission(floor: floor.number) }
    /// The pace stage's loadout (`MPCStageLoadout`) with the gear of every floor below.
    public static func recommendedLoadout(for floor: MPCChurchTowerCatalog.Floor, route: Route = .medal) -> MPCChapterOneLoadout {
        let n = mission(for: floor) + 1
        let cards: [FoolSkillID]
        if route == .unprepared { cards = [] }
        else if route == .counter, n >= 10 { cards = [.turnTheTables, .fabricatedEvidence, .identityDisplacement, .absurdFinale] }
        else { cards = MPCStageLoadout.towerHand(before: n) }
        let active: String? = route == .unprepared ? nil : route == .blankCard && n > 17 ? "relic_blank_name_card" : MPCChapterOneCatalog.usurpedLifeMedalRelicID
        var loadout = MPCStageLoadout.loadout(before: n, order: cards, gear: MPCStageLoadout.towerGear(through: floor.number - 1), passive: nil, activeRelic: active)
        if route == .unprepared { loadout.isUltimateUnlocked = false; loadout.selectedActiveRelicID = nil }
        return loadout
    }
    public static func playerContact(_ skill: FoolSkillID) -> Double { MPCChurchBattleDriver.playerContact(skill) }

    /// Plays one church-family battle through `MPCChurchBattleStepper` (the App's rules)
    /// with this runner's choices as player inputs: target back sacs, then crowns, then
    /// escorts, then anything not guarding; the medal on a timer; the blank card against
    /// heavy hits (route .blankCard, Q17+); the ultimate once in the final wave.
    /// `encounterID` plays another church battle (bounty, street) with floor `number`'s
    /// loadout unless `suppliedLoadout` is given. `jitter` and `actionDelay` are model-only timing.
    public static func run(number: Int, route: Route = .medal, medalOffset: Double = 22, jitter: Double = 0, seed: UInt64 = 1,
                           passive: String? = nil, suppliedLoadout: MPCChapterOneLoadout? = nil, actionDelay: Double = 0,
                           encounterID: String? = nil, tempo: MPCTempoChoice = .automatic) throws -> Report {
        let floor = MPCChurchTowerCatalog.floor(number: number)!
        var loadout = recommendedLoadout(for: floor, route: route)
        if let passive { loadout.relicIDs = [passive] }
        if let suppliedLoadout { loadout = suppliedLoadout }
        let heavy: Set<String> = ["archive_slam", "tower_heavy_cut", "tower_piercing_claw", "tower_heavy_claw", "tower_cut_first"]
        // The policy's own clock noise (medal timing), separate from the stepper's.
        var randomState = seed ^ 0x9E37_79B9_7F4A_7C15
        func variation() -> Double {
            guard jitter != 0 else { return 0 }
            randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
            return (Double((randomState >> 32) % 10001) / 5000 - 1) * jitter
        }
        var nextMedalAt = max(0, medalOffset + variation())
        var ultimateAsked = false
        let usesMedal = loadout.selectedActiveRelicID == MPCChapterOneCatalog.usurpedLifeMedalRelicID
        let usesBlankCard = route == .blankCard && mission(for: floor) >= 17
        func policy(_ view: MPCChurchBattleDriver.View) -> [MPCBattleInput] {
            var out: [MPCBattleInput] = []
            var trial = view.session
            let alive = trial.enemies.filter(\.isAlive)
            let species = { (e: MPCRuntimeEnemy) in MPCChurchTowerCatalog.enemyConfiguration(contentID: e.contentID)?.species }
            guard let target = alive.first(where: { species($0) == .backSac }) ?? alive.first(where: { species($0) == .crown })
                    ?? alive.first(where: { $0.contentID.contains("escort") || $0.contentID.contains("life_vessel") })
                    ?? alive.first(where: { $0.currentIntent != "guard" }) ?? alive.first else { return out }
            if target.id != view.target { out.append(.init(tick: view.tick, kind: .target, enemyID: target.id)) }
            if usesBlankCard, let incoming = view.incoming.keys.sorted().first(where: { id in
                Double(view.incoming[id]! - view.tick) * MPCChurchBattleDriver.step <= 0.25
                    && trial.enemies.contains { $0.id == id && heavy.contains($0.currentIntent) }
            }), trial.activateBlankNameCard(isOwned: true, targetID: incoming, at: view.now) {
                out.append(.init(tick: view.tick, kind: .blankCard, enemyID: incoming))
            }
            if usesMedal, view.now >= nextMedalAt, target.currentIntent != "guard", trial.activateUsurpedLifeMedal(isOwned: true, at: view.now) {
                out.append(.init(tick: view.tick, kind: .medal))
                nextMedalAt = trial.usurpedLifeMedalReadyAt + max(0, variation())
            }
            if !ultimateAsked, loadout.isUltimateUnlocked, trial.waveIndex == floor.waves.count - 1, view.now >= 12,
               trial.canUseFoolSkill(.namelessStage) {
                ultimateAsked = true
                out.append(.init(tick: view.tick, kind: .ultimate))
            }
            return out
        }
        var stepper = try MPCChurchBattleStepper(encounterID: encounterID ?? floor.id, loadout: loadout,
                                                 tuning: .init(jitter: jitter, seed: seed, actionDelay: actionDelay, tempo: tempo))
        var wave = -1, waveHP: [Int] = [], rosters: [[String]] = []
        var casts: [String: Int] = [:]
        var stats = MPCTempoStats()
        while !stepper.isFinished {
            let view = stepper.view
            if view.session.outcome == .inProgress, wave != view.session.waveIndex {
                let s = view.session
                wave = s.waveIndex; waveHP.append(s.playerHP)
                rosters.append(s.enemies.compactMap { MPCChapterOneBattleIdentity.visualDescriptor(for: $0.id, in: s.enemies, encounterID: s.encounter.id) })
            }
            let events = try stepper.step(view.session.outcome == .inProgress ? policy(view) : [])
            if let cast = events.cast { casts[cast.skill?.rawValue ?? "basic", default: 0] += 1 }
            stats.record(events, session: stepper.session)
        }
        let medals = stepper.inputs.filter { $0.kind == .medal }.count
        return .init(floor: number, mission: mission(for: floor), route: route, session: stepper.session,
                     seconds: max(0, stepper.now - MPCChurchBattleDriver.step), waveEntryHP: waveHP,
                     rosterDescriptors: rosters, skillCasts: casts, medalUses: medals, tempoStats: stats)
    }
}
