import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Lights local event: one side, one order, one public attempt")
struct LightsLocalEventTests {
    typealias E = MPCLightsLocalEvent
    let strap = E.strapID

    func ready(_ side: E.Faction = .pumps) throws -> (E, Int, [String: Int]) {
        var event = E(), coins = 100, inventory = [strap: 3]
        try event.choose(side, id: "side", eligible: true)
        try event.deliver(id: "d", eligible: true, coins: &coins, inventory: &inventory)
        try event.install(id: "i", eligible: true)
        return (event, coins, inventory)
    }

    /// Plays the real runtime to the requested end, as the reward regression tests do.
    func play(_ encounterID: String, to outcome: MPCEncounterOutcome) throws -> MPCChapterOneEncounterSession {
        let win = outcome == .victory
        var s = try MPCChapterOneEncounterSession.start(
            encounterID: encounterID,
            party: MPCPartyPersistentState(playerHP: win ? 100_000 : 1, playerMaxHP: win ? 100_000 : 1, sharedReviveCharges: 0),
            companionIDs: [])
        for step in 0..<400 where s.outcome == .inProgress {
            if s.isAwaitingTowerWave {  // church waves enter after a one-second clock gap
                let now = Double(step) * 2 + 10
                _ = s.advanceRelicClock(at: now)
                s.advanceChurchTowerEffects(at: now)
            }
            for enemy in s.enemies.filter(\.isAlive) where s.outcome == .inProgress {
                if win { _ = try s.applyPartyDamage(99_999, to: enemy.id) }
                if s.outcome == .inProgress, s.enemies.contains(where: { $0.id == enemy.id && $0.isAlive }) || !win {
                    s.commitEnemyImpact(from: enemy.id)
                    try? s.endRound(actingEnemyID: enemy.id, at: Double(step))
                }
            }
        }
        return s
    }
    func session(_ event: E, ticket: String, outcome: MPCEncounterOutcome) throws -> MPCChapterOneEncounterSession {
        let s = try play(MPCLightsPublicTarget.encounterID(side: event.side!, ticket: ticket), to: outcome)
        try #require(s.outcome == outcome)
        return s
    }

    @Test func nothingWithoutStoryEligibility() {
        var event = E(), coins = 100, inventory = [strap: 3]
        #expect(throws: E.Failure.locked) { try event.choose(.pumps, id: "a", eligible: false) }
        #expect(throws: E.Failure.locked) { try event.deliver(id: "b", eligible: true, coins: &coins, inventory: &inventory) }
        #expect(event == E() && coins == 100 && inventory[strap] == 3)
    }

    @Test func deliveryMovesExactlyTheFundedMoneyAndGoods() throws {
        let (event, coins, inventory) = try ready()
        #expect(coins == 118 && inventory[strap] == 1 && event.projectCash == 0)
        #expect(coins + event.projectCash == 100 + E.orderBudget)
        #expect(event.installedKits == 12 && event.projectStraps == 0 && event.worksComplete)
    }

    @Test func shortStockOrRepeatChangesNothing() throws {
        var event = E(), coins = 100, inventory = [strap: 1]
        try event.choose(.shipping, id: "side", eligible: true)
        #expect(throws: E.Failure.stock) { try event.deliver(id: "d", eligible: true, coins: &coins, inventory: &inventory) }
        #expect(coins == 100 && inventory[strap] == 1 && event.projectCash == E.orderBudget)
        inventory[strap] = 4
        #expect(try event.deliver(id: "d", eligible: true, coins: &coins, inventory: &inventory))
        #expect(try !event.deliver(id: "d", eligible: true, coins: &coins, inventory: &inventory))
        #expect(throws: E.Failure.order) { try event.deliver(id: "d2", eligible: true, coins: &coins, inventory: &inventory) }
        #expect(coins == 118 && inventory[strap] == 2)
        #expect(throws: E.Failure.side) { try event.choose(.pumps, id: "side2", eligible: true) }
    }

    @Test func publicNeedsCompletedWorksAndIsSingleUse() throws {
        var early = E(), coins = 0, inv = [strap: 2]
        try early.choose(.pumps, id: "side", eligible: true)
        #expect(throws: E.Failure.order) { try early.beginPublic(id: "t1", eligible: true) }
        try early.deliver(id: "d", eligible: true, coins: &coins, inventory: &inv)
        try early.install(id: "i", eligible: true)
        _ = try early.beginPublic(id: "t1", eligible: true)
        #expect(throws: E.Failure.pending) { try early.beginPublic(id: "t2", eligible: true) }
        early.abandonPublic(id: "t1")
        #expect(throws: E.Failure.attempted) { try early.beginPublic(id: "t3", eligible: true) }
        #expect(early.closed && !early.publicWon)
    }

    @Test(arguments: [(MPCEncounterOutcome.victory, "own"), (.defeat, "opponent")])
    func resultFollowsTheContractTable(outcome: MPCEncounterOutcome, winner: String) throws {
        for side in E.Faction.allCases {
            var (event, _, _) = try ready(side)
            let encounter = try event.beginPublic(id: "t1", eligible: true)
            #expect(MPCChapterOneBattleIdentity.supportsUnity(encounterID: encounter))
            let battle = try session(event, ticket: "t1", outcome: outcome)
            #expect(try event.settlePublic(id: "t1", session: battle))
            #expect(try !event.settlePublic(id: "t1", session: battle))
            let expected: E.Faction = winner == "own" ? side : side.opponent
            #expect(event.contract == .awarded(expected))
        }
    }

    @Test func settlementRejectsAnotherEncounter() throws {
        var (event, _, _) = try ready()
        _ = try event.beginPublic(id: "t1", eligible: true)
        let tower = try play(MPCChurchTowerCatalog.floor(number: 1)!.id, to: .victory)
        try #require(tower.outcome == .victory)
        #expect(throws: E.Failure.invalidBattle) { try event.settlePublic(id: "t1", session: tower) }
        #expect(event.activeTicket == "t1" && !event.publicWon)
    }

    @Test func publicTargetUsesAuthoredTowerBodies() throws {
        for side in E.Faction.allCases {
            let encounter = try #require(MPCLightsPublicTarget.encounter(id: MPCLightsPublicTarget.encounterID(side: side, ticket: "abc-1")))
            let ids = encounter.waves.flatMap(\.enemyIDs)
            #expect(ids.count == 3 && Set(ids).count == 3)
            #expect(ids.allSatisfy { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0) != nil })
        }
        #expect(MPCLightsPublicTarget.encounter(id: MPCLightsPublicTarget.prefix + "pumps_bad_id!") == nil)
    }

    @Test func codableRoundTrip() throws {
        let (event, _, _) = try ready(.shipping)
        let decoded = try JSONDecoder().decode(E.self, from: JSONEncoder().encode(event))
        #expect(decoded == event)
    }
}
