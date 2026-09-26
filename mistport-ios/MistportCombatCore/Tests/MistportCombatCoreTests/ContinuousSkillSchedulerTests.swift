import Testing
@testable import MistportCombatCore

struct ContinuousSkillSchedulerTests {
    @Test func openingPassDoesNotRepeatFastSkill() {
        var scheduler = ContinuousSkillScheduler()
        let sequence: [FoolSkillID] = [.sidestepStrike, .maskedWhisper, .identityDisplacement, .turnTheTables, .absurdFinale]
        for (index, skill) in sequence.enumerated() {
            let time = Double(index * 10)
            #expect(scheduler.next(in: sequence, at: time) == skill)
            scheduler.didCast(skill, at: time)
        }
        #expect(scheduler.next(in: sequence, at: 50) == .sidestepStrike)
    }
    @Test func earliestDeadlineWinsOverSlotOrder() {
        var scheduler = ContinuousSkillScheduler()
        let sequence: [FoolSkillID] = [.absurdFinale, .sidestepStrike]
        scheduler.didCast(.absurdFinale, at: 0)
        scheduler.didCast(.sidestepStrike, at: 1)
        #expect(scheduler.next(in: sequence, at: 4) == nil)
        #expect(scheduler.next(in: sequence, at: 12) == .sidestepStrike)
        scheduler.didCast(.sidestepStrike, at: 12)
        #expect(scheduler.next(in: sequence, at: 12) == .absurdFinale)
    }
    @Test func tiesUseOrderAndRemovedSkillsAreIgnored() {
        var scheduler = ContinuousSkillScheduler()
        scheduler.didCast(.sidestepStrike, at: 8)
        scheduler.didCast(.maskedWhisper, at: 0)
        #expect(scheduler.next(in: [.maskedWhisper, .sidestepStrike], at: 12) == .maskedWhisper)
        #expect(scheduler.next(in: [.sidestepStrike], at: 12) == .sidestepStrike)
    }
    @Test func oneEnemyDeadlineDoesNotAdvanceOtherEnemies() throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q02_encounter", companionIDs: [])
        let before = session.enemies
        try session.endRound(actingEnemyID: before[0].id)
        #expect(session.enemies[0].intentIndex == before[0].intentIndex + 1)
        #expect(session.enemies[1].intentIndex == before[1].intentIndex)
        #expect(session.lastEnemyActionResolutions.map(\.enemyID) == [before[0].id])
        // A player cast can resolve immediately, without advancing the second enemy.
        _ = try session.useFoolSkill(.sidestepStrike, targetID: before[0].id, usesRealtimeCooldown: true)
        #expect(session.enemies[1].intentIndex == before[1].intentIndex)
    }
}
