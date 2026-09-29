import Foundation
import Testing
@testable import MistportCombatCore

@Suite("New campaign mechanics, isolated from formal rewards")
struct CampaignBattleSandboxTests {
    func start(_ scenario: MPCCampaignScenario) throws -> MPCChapterOneEncounterSession {
        try .start(encounterID: scenario.id, companionIDs: [], campaignPrototype: scenario)
    }
    func advance(_ session: inout MPCChapterOneEncounterSession, to end: Double) {
        let start = Int((session.campaignPrototype?.now ?? 0) * 20 + 0.0001)
        for tick in (start + 1)...max(start + 1, Int(end * 20)) { session.advanceCampaignPrototype(at: Double(tick) / 20) }
    }
    @Test func prototypeRequiresExplicitOptInAndHasNoRewards() throws {
        for scenario in MPCCampaignScenario.allCases {
            #expect(throws: MPCEncounterRuntimeError.unknownEncounter) { try MPCChapterOneEncounterSession.start(encounterID: scenario.id) }
            let s = try start(scenario)
            #expect(s.enemies.count == 3 && s.encounter.fixedRewardItemIDs.isEmpty && s.encounter.firstClearRelicID == nil)
            #expect(s.enemies[1].id != s.enemies[2].id)
        }
        #expect(throws: MPCEncounterRuntimeError.unknownEncounter) { try MPCChapterOneEncounterSession.start(encounterID: MPCCampaignScenario.guardHard.id, campaignPrototype: .relayHard) }
    }
    @Test func guardDamageReductionAndCoreTerminal() throws {
        var s = try start(.guardHard)
        let ids = s.enemies.map(\.id)
        #expect(try s.applyPartyDamage(100, to: ids[0]) == 40)
        _ = try s.applyPartyDamage(99999, to: ids[1])
        #expect(try s.applyPartyDamage(100, to: ids[0]) == 75)
        _ = try s.applyPartyDamage(99999, to: ids[2])
        #expect(try s.applyPartyDamage(100, to: ids[0]) == 100)
        var rush = try start(.guardHard)
        _ = try rush.applyPartyDamage(99999, to: rush.enemies[0].id)
        #expect(rush.outcome == .victory && rush.enemies.dropFirst().allSatisfy(\.isAlive))
        let finished = rush
        rush.advanceCampaignPrototype(at: 100)
        #expect(rush == finished)
    }
    @Test func chargeInterruptByGuardAndByEightPercentCore() throws {
        var s = try start(.guardHard)
        advance(&s, to: 24)
        #expect(s.campaignPrototype?.chargeUntil == 28)
        _ = try s.applyPartyDamage(99999, to: s.enemies[1].id)
        #expect(s.campaignPrototype?.chargeUntil == nil && s.campaignPrototype?.recoveryUntil == 27)
        advance(&s, to: 34)
        #expect(s.campaignPrototype?.poisonRemaining == 0)
        var empty = try start(.guardHard)
        for e in empty.enemies.dropFirst() { _ = try empty.applyPartyDamage(99999, to: e.id) }
        advance(&empty, to: 24)
        _ = try empty.applyPartyDamage(335, to: empty.enemies[0].id)
        #expect(empty.campaignPrototype?.chargeUntil != nil)
        _ = try empty.applyPartyDamage(1, to: empty.enemies[0].id)
        #expect(empty.campaignPrototype?.chargeUntil == nil)
    }
    @Test func poisonIsSixFiniteTicksAndClockCannotReplay() throws {
        var s = try start(.guardOrdinary)
        let hp = s.playerHP
        advance(&s, to: 34)
        let ticks = s.campaignPrototype!.events.filter { $0.kind == "poison_tick" }
        #expect(ticks.count == 6 && s.campaignPrototype?.poisonRemaining == 0)
        #expect(hp - s.playerHP == ticks.reduce(0) { $0 + $1.amount })
        let after = s
        s.advanceCampaignPrototype(at: 34); s.advanceCampaignPrototype(at: .nan); s.advanceCampaignPrototype(at: 33)
        #expect(s == after)
    }
    @Test func poisonRoundingCannotExceedEighteenPercentSnapshot() throws {
        var s = try MPCCampaignBattleDriver(scenario: .guardOrdinary, gearFloor: 30, medal: false).session
        let hp = s.playerNormalMaxHP
        advance(&s, to: 34)
        #expect(s.campaignPrototype?.poisonBudget == 0)
        #expect(hp - s.playerHP == hp * 18 / 100)
        #expect(s.campaignPrototype?.events.filter { $0.kind == "poison_tick" }.count == 6)
    }
    @Test func guardReserveCancellationAndUniqueArrival() throws {
        var s = try start(.guardHard)
        _ = try s.applyPartyDamage(99999, to: s.enemies[1].id)
        _ = try s.applyPartyDamage(2800, to: s.enemies[0].id)
        #expect(s.campaignPrototype?.reserveAt == 4)
        var arrival = s
        advance(&arrival, to: 4)
        #expect(arrival.enemies.count == 4 && arrival.enemies.last?.id.hasSuffix("#reserve") == true)
        #expect(arrival.enemies[1].hp == 0)
        _ = try s.applyPartyDamage(99999, to: s.enemies[2].id)
        advance(&s, to: 4)
        #expect(s.enemies.count == 3 && s.campaignPrototype?.reserveAt == nil)
    }
    @Test func supportInterruptRequiresActualDamageAndOtherChannelHeals() throws {
        var s = try start(.relayHard)
        _ = try s.applyPartyDamage(500, to: s.enemies[0].id)
        advance(&s, to: 20)
        #expect(s.campaignPrototype?.channels.count == 2)
        _ = try s.applyPartyDamage(164, to: s.enemies[1].id)
        #expect(s.campaignPrototype?.channels.count == 2)
        _ = try s.applyPartyDamage(1, to: s.enemies[1].id)
        #expect(s.campaignPrototype?.channels.count == 1)
        advance(&s, to: 25)
        #expect(s.enemies[0].hp == 4200 - 500 + 252)
        #expect(s.campaignPrototype?.events.filter { $0.kind == "core_heal" }.count == 1)
    }
    @Test func relayHalfHealthCancelsChannelsAndAddsFreshSupport() throws {
        var s = try start(.relayHard)
        _ = try s.applyPartyDamage(99999, to: s.enemies[1].id)
        advance(&s, to: 20)
        _ = try s.applyPartyDamage(2100, to: s.enemies[0].id)
        #expect(s.campaignPrototype?.channels.isEmpty == true)
        #expect(s.campaignPrototype?.recoveryUntil == 28 && s.campaignPrototype?.nextMechanic == 48)
        #expect(s.campaignActorPaused(s.enemies[0].id))
        advance(&s, to: 24)
        #expect(s.enemies.count == 4 && s.enemies[1].hp == 0 && s.enemies[3].isAlive)
        advance(&s, to: 28)
        #expect(!s.campaignActorPaused(s.enemies[0].id))
    }
    @Test func overhealDoesNotInventDemand() throws {
        var s = try start(.relayOrdinary)
        advance(&s, to: 25)
        let heals = s.campaignPrototype!.events.filter { $0.kind == "core_heal" }
        #expect(heals.count == 2 && heals.allSatisfy { $0.amount == 0 })
    }
    @Test func timeoutIsTerminalWithoutRewards() throws {
        var s = try start(.relayOrdinary)
        advance(&s, to: 180)
        #expect(s.outcome == .defeat)
        #expect(s.campaignPrototype?.events.last?.kind == "outcome")
    }
    @Test func reflectedCoreKillStopsRemainderOfEnemyContact() throws {
        let scenario = MPCCampaignScenario.relayHard
        let loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: ["relic_reflecting_ink_mirror"])
        var s = try MPCChapterOneEncounterSession.start(encounterID: scenario.id, companionIDs: [], loadout: loadout, campaignPrototype: scenario)
        let core = s.enemies[0].id, support = s.enemies[1].id
        _ = try s.applyPartyDamage(4000, to: core)
        s.updateRelicTarget(core, at: 0)
        advance(&s, to: 2)
        _ = try s.useBasicAction(.damage, targetID: core) // actual mirror gift establishes reflection
        let remaining = s.enemies[0].hp
        _ = try s.applyPartyDamage(remaining - 5, to: core)
        let hp = s.playerHP
        try s.endRound(actingEnemyID: support, at: 2.1)
        #expect(s.outcome == .victory && s.playerHP == hp)
    }
    @Test func renderingCadenceDoesNotChangeEnemyDamage() throws {
        var a = try MPCCampaignBattleDriver(scenario: .relayHard, medal: false)
        var b = a
        try a.advance(to: 35)
        for i in 1...350 { try b.advance(to: Double(i) / 10) }
        #expect(a.session == b.session && a.time == b.time)
    }
    @Test func optedInPrototypeCanUseOwnedMedalAndCannotUseUnequippedOne() throws {
        var equipped = try MPCCampaignBattleDriver(scenario: .guardHard, medal: true)
        let hp = equipped.session.playerHP
        let activated = equipped.medal()
        #expect(activated && equipped.session.isUsurpedLifeMedalActive)
        #expect(equipped.session.playerHP == (hp * 3 + 1) / 2)
        let duplicate = equipped.medal()
        #expect(!duplicate)
        var absent = try MPCCampaignBattleDriver(scenario: .guardHard, medal: false)
        let rejected = absent.medal()
        #expect(!rejected && !absent.session.isUsurpedLifeMedalActive)
    }
    @Test func medicineAndActionsCannotBeSpammed() throws {
        var d = try MPCCampaignBattleDriver(scenario: .relayHard, medicines: 3, medal: false)
        let fullMedicine = d.medicine()
        let firstCast = d.cast(.fabricatedEvidence)
        let spamCast = d.cast(.mirrorPursuit)
        #expect(!fullMedicine && firstCast && !spamCast)
        try d.advance(to: 5)
        let healed = d.medicine()
        let spamMedicine = d.medicine()
        #expect(healed && !spamMedicine)
        #expect(d.session.consumables["consumable_pain_salve"] == 2)
    }
}

@Suite("Paired sandbox pilots; assumed operators, not human win rates")
struct CampaignSandboxPilotTests {
    @Test func pairedTrials() throws {
        // A time-indexed error tape is generated BEFORE each fight. It never branches on HP/items/results.
        for scenario in MPCCampaignScenario.allCases {
            for gear in [30, 100] {
                for passive in [nil, "relic_return_gift_clasp", "relic_salt_sealed_breathing_bag"] as [String?] {
                    for medicines in [0, 3] {
                        for aggressive in [false, true] {
                            for severity in 0...2 {
                                var random: UInt64 = 211
                                let tape: [Bool] = (0..<3601).map { _ in
                                    random = random &* 6364136223846793005 &+ 1442695040888963407
                                    return Int((random >> 32) % 100) >= [0, 25, 50][severity]
                                }
                                var d = try MPCCampaignBattleDriver(scenario: scenario, gearFloor: gear, passive: passive, medicines: medicines)
                                for tick in 1...3600 where d.session.outcome == .inProgress {
                                    try d.advance(to: Double(tick) / 20)
                                    guard d.session.outcome == .inProgress, tape[tick / 10] else { continue }
                                    let alive = d.session.enemies.filter(\.isAlive)
                                    let core = alive.first { $0.contentID == scenario.coreID }
                                    let adds = alive.filter { $0.contentID == scenario.addID }
                                    let target: MPCRuntimeEnemy?
                                    if aggressive, adds.count <= 1 {
                                        target = adds.first { d.session.campaignPrototype?.channels[$0.id] != nil } ?? core
                                    } else { target = adds.first ?? core }
                                    if let target { d.select(target.id) }
                                    if d.session.playerHP * 2 < d.session.playerNormalMaxHP { _ = d.medicine() }
                                    if d.time >= 6 { _ = d.medal() }
                                    if let skill = d.scheduler.next(in: d.session.loadout.normalSkillIDs, at: d.time) { _ = d.cast(skill) }
                                    else { _ = d.cast(nil) }
                                }
                                #expect(d.session.outcome != .inProgress)
                                #expect(d.session.campaignPrototype!.events.contains { $0.kind == "medal" })
                                let events = d.session.campaignPrototype!.events
                                let row: [String: Any] = ["scenario": scenario.rawValue, "gear": gear, "passive": passive ?? "none", "medicine": medicines,
                                    "route": aggressive ? "aggressive" : "clear_adds", "assumed_error_tape": severity, "seed": 211,
                                    "outcome": d.session.outcome.rawValue, "seconds": d.time, "hp": d.session.playerHP, "minimum_hp": d.minimumHP,
                                    "below_quarter_seconds": d.timeBelowQuarterHP, "medicine_used": medicines - d.session.consumables["consumable_pain_salve", default: 0],
                                    "core_healing": events.filter { $0.kind == "core_heal" }.reduce(0) { $0 + $1.amount },
                                    "interrupts": events.filter { ["charge_interrupt", "channel_interrupt"].contains($0.kind) }.count,
                                    "poison_ticks": events.filter { $0.kind == "poison_tick" }.count,
                                    "medal_uses": events.filter { $0.kind == "medal" }.count]
                                print("CAMPAIGN_SANDBOX " + String(decoding: try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]), as: UTF8.self))
                            }
                        }
                    }
                }
            }
        }
    }
}
