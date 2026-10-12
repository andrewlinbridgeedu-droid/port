import Testing
@testable import MistportCombatCore

@Suite("Ready cards chain at the same cadence across story battles")
struct PlayerCastCadenceTests {
    @Test(arguments: ["chapter01_q03_encounter", "chapter01_q04_encounter", "chapter01_q05_encounter"])
    func twoReadyCardsFollowOneAnother(encounterID: String) throws {
        let loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike, .identityDisplacement],
            isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        var s = try MPCStoryBattleStepper(encounterID: encounterID, loadout: loadout)
        var casts: [(FoolSkillID?, Double)] = []
        while !s.isFinished && s.now < 3 {
            let now = s.now
            if let cast = try s.step().cast { casts.append((cast.skill, now)) }
        }
        try #require(casts.count >= 2)
        #expect(casts[0].0 == .sidestepStrike && casts[1].0 == .identityDisplacement)
        #expect(abs(casts[1].1 - casts[0].1 - 1.1) < 0.051)
    }

    @Test func q5StillRespectsCardCooldownAndBasicInterval() throws {
        let loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike, .identityDisplacement],
            isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        var s = try MPCStoryBattleStepper(encounterID: "chapter01_q05_encounter", loadout: loadout)
        var cards: [FoolSkillID: [Double]] = [:]
        var basics: [Double] = []
        while !s.isFinished && s.now < 8 {
            let now = s.now
            if let cast = try s.step().cast {
                if let skill = cast.skill { cards[skill, default: []].append(now) }
                else { basics.append(now) }
            }
        }
        let strikes = try #require(cards[.sidestepStrike])
        try #require(strikes.count >= 2)
        #expect(strikes[1] >= 4 && strikes[1] < 4.1)
        for (skill, times) in cards {
            #expect(zip(times.dropFirst(), times).allSatisfy {
                $0 - $1 + 0.000001 >= ContinuousSkillScheduler.duration(for: skill)
            })
        }
        #expect(zip(basics.dropFirst(), basics).allSatisfy { $0 - $1 + 0.000001 >= 2.4 })
    }

    @Test func basicFollowThroughDoesNotHoldAReadyCardForTheOldLockout() throws {
        let loadout = MPCChapterOneLoadout(normalSkillIDs: [.sidestepStrike],
            isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        var s = try MPCStoryBattleStepper(encounterID: "chapter01_q05_encounter", loadout: loadout)
        var strikes: [Double] = []
        while !s.isFinished && s.now < 5.5 {
            let now = s.now
            if let cast = try s.step().cast, cast.skill == .sidestepStrike { strikes.append(now) }
        }
        try #require(strikes.count >= 2)
        #expect(strikes[1] >= 4 && strikes[1] <= 4.45)
    }
}
