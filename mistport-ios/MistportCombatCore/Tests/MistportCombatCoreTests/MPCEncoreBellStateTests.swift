import Testing
@testable import MistportCombatCore

@Suite("Encore Bell state", .enabled(if: MPCChapterOneCatalog.relicsEnabled))
struct MPCEncoreBellStateTests {
    private func q5(maskSelected: Bool = true) throws -> MPCChapterOneEncounterSession {
        try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q05_encounter",
            companionIDs: [],
            loadout: .init(normalSkillIDs: maskSelected ? [.maskedWhisper] : [], passiveIDs: [], relicIDs: ["relic_paper_raincoat"])
        )
    }

    @Test("Q5 timed mask requires preparation and selected mask")
    func timedMaskGating() throws {
        var noMask = try q5(maskSelected: false)
        noMask.prepareEncoreBellPrototype()
        let noMaskActivated = noMask.activateTimedMasquerade(at: 0)
        #expect(!noMaskActivated)

        var session = try q5()
        #expect(session.timedMasqueradeExpiresAt == nil)
        session.prepareEncoreBellPrototype()
        #expect(session.loadout.relicIDs.isEmpty)
        let activated = session.activateTimedMasquerade(at: 10)
        #expect(activated)
        #expect(session.masqueradeCharges == 1)
        #expect(session.timedMasqueradeExpiresAt == 14)
        #expect(session.timedMasqueradeReadyAt == 22)
        let earlyExpiry = session.expireTimedMasquerade(at: 13.99)
        #expect(!earlyExpiry)
        let expired = session.expireTimedMasquerade(at: 14)
        #expect(expired)
        #expect(session.masqueradeCharges == 0)
        let cooldownActivation = session.activateTimedMasquerade(at: 21.99)
        #expect(!cooldownActivation)
        let reactivated = session.activateTimedMasquerade(at: 22)
        #expect(reactivated)
    }

    @Test("Encore debt boosts one enemy attack and mask absorbs the amplified hit")
    func encoreDebtAndMaskAbsorption() throws {
        var session = try q5()
        session.prepareEncoreBellPrototype()
        let enemyID = try #require(session.enemies.first?.id)
        let activated = session.activateTimedMasquerade(at: 0)
        #expect(activated)
        let marked = session.markEncoreDebt(enemyID: enemyID)
        #expect(marked)
        let before = session.playerHP
        try session.endRound(actingEnemyID: enemyID)
        #expect(session.masqueradeCharges == 1)
        try session.endRound(actingEnemyID: enemyID)
        #expect(session.playerHP == before)
        #expect(session.masqueradeCharges == 0)
        let markedAgain = session.markEncoreDebt(enemyID: enemyID)
        #expect(!markedAgain)
    }

    @Test("Encore debt works without an active mask and boosts only the next hit")
    func encoreDebtWithoutMask() throws {
        var session = try q5()
        session.prepareEncoreBellPrototype()
        let enemyID = try #require(session.enemies.first?.id)
        let marked = session.markEncoreDebt(enemyID: enemyID)
        #expect(marked)
        let before = session.playerHP
        try session.endRound(actingEnemyID: enemyID)
        try session.endRound(actingEnemyID: enemyID)
        session.advanceEmeraldPoison(at: 9)
        let amplifiedLoss = before - session.playerHP
        #expect(amplifiedLoss == 297)
        let nextBefore = session.playerHP
        try session.endRound(actingEnemyID: enemyID)
        #expect(nextBefore == session.playerHP)
        try session.endRound(actingEnemyID: enemyID)
        #expect(nextBefore - session.playerHP == 198)
    }

    @Test("An early mask expires before the bell-delayed hit")
    func earlyMaskCannotLastThroughBell() throws {
        var session = try q5()
        session.prepareEncoreBellPrototype()
        let id = try #require(session.enemies.first?.id)
        let activated = session.activateTimedMasquerade(at: 0)
        #expect(activated)
        let marked = session.markEncoreDebt(enemyID: id)
        #expect(marked)
        let expired = session.expireTimedMasquerade(at: 6)
        #expect(expired)
        let hp = session.playerHP
        try session.endRound(actingEnemyID: id)
        try session.endRound(actingEnemyID: id)
        session.advanceEmeraldPoison(at: 9)
        #expect(hp - session.playerHP == 297)
        let tooSoon = session.activateTimedMasquerade(at: 11.99)
        #expect(!tooSoon)
        let ready = session.activateTimedMasquerade(at: 12)
        #expect(ready)
    }

    @Test("Only an active windup can be rung and it releases after three seconds")
    func ringAndRelease() throws {
        var bell = MPCEncoreBellState()
        let began = bell.beginCharge(enemyID: "hound", startedAt: 10, windupDeadline: 12)
        #expect(began)
        let rang = bell.ring(at: 11.5)
        #expect(rang)
        #expect(bell.phase == .deferred)
        #expect(!bell.isReleaseDue(at: 14.99))
        #expect(bell.isReleaseDue(at: 15))
        let consumed = bell.consumeReleaseIfDue(at: 15)
        #expect(consumed)
        #expect(bell.phase == .spent)
        let consumedAgain = bell.consumeReleaseIfDue(at: 20)
        #expect(!consumedAgain)
    }

    @Test("Late, repeated, and out-of-phase rings do not consume the bell")
    func invalidRingsDoNotConsume() {
        var bell = MPCEncoreBellState()
        let earlyRing = bell.ring(at: 0)
        #expect(!earlyRing)
        let began = bell.beginCharge(enemyID: "wisp", startedAt: 5, windupDeadline: 8)
        #expect(began)
        let beforeStartRing = bell.ring(at: 4.99)
        #expect(!beforeStartRing)
        let lateRing = bell.ring(at: 8)
        #expect(!lateRing)
        #expect(bell.phase == .windingUp)
        let rang = bell.ring(at: 6)
        #expect(rang)
        let repeatedRing = bell.ring(at: 6.1)
        #expect(!repeatedRing)
        #expect(bell.phase == .deferred)
    }

    @Test("Enemy death cancels deferred debt but keeps the bell spent")
    func deferredEnemyDeathSpendsBell() {
        var bell = MPCEncoreBellState()
        let began = bell.beginCharge(enemyID: "shade", startedAt: 2, windupDeadline: 4)
        #expect(began)
        let rang = bell.ring(at: 3)
        #expect(rang)
        let died = bell.enemyDied("shade")
        #expect(died)
        #expect(bell.phase == .spent)
        #expect(bell.pendingEnemyID == nil)
        #expect(!bell.isReleaseDue(at: 100))
        let reused = bell.beginCharge(enemyID: "shade-2", startedAt: 5, windupDeadline: 6)
        #expect(!reused)
    }

    @Test("An un-rung charge can complete and leave the bell ready")
    func ordinaryChargeCompletion() {
        var bell = MPCEncoreBellState()
        let began = bell.beginCharge(enemyID: "rat", startedAt: 1, windupDeadline: 2)
        #expect(began)
        let completed = bell.completeCharge()
        #expect(completed)
        #expect(bell.phase == .ready)
        #expect(bell.pendingEnemyID == nil)
        let beganAgain = bell.beginCharge(enemyID: "rat-2", startedAt: 3, windupDeadline: 5)
        #expect(beganAgain)
    }

    @Test("Reset clears a spent relic for a fresh battle")
    func reset() {
        var bell = MPCEncoreBellState()
        let began = bell.beginCharge(enemyID: "bird", startedAt: 0, windupDeadline: 1)
        #expect(began)
        let rang = bell.ring(at: 0.5)
        #expect(rang)
        let consumed = bell.consumeReleaseIfDue(at: 4)
        #expect(consumed)
        bell.reset()
        #expect(bell == MPCEncoreBellState())
    }
}
