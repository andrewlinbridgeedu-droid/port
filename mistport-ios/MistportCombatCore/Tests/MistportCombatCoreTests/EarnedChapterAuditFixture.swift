import Testing
@testable import MistportCombatCore

/// Core campaign plus a paid shop ledger on the real loop (2026-10-15: `MPCStoryVerificationRunner`
/// with the campaign's own unlocks, inventory and party); no native UI or device-play claim.
enum EarnedChapterAuditFixture {
    /// Tower gear for every floor the walls up to `q` name.
    static func wallGear(beforeOrAt q: Int) -> MPCChurchGearStats { MPCStageLoadout.wallGear(beforeOrAt: q) }
    /// The bounty relic a mechanism wall at `q` asks for, if any.
    static func wallRelic(_ q: Int) -> String? { MPCStageLoadout.wallRelic(q) }

    static func run(through last: Int) async throws -> MPCChapterOneCampaignState {
        var campaign = MPCChapterOneCampaignState.chapterStartState
        var wallet = 180 // Native new-save starting copper.
        var spent = 0
        for q in 1...last {
            let mission = try #require(MPCChapterOneCatalog.mission(forOldClockMissionNumber: q))
            if q == 3 { campaign.grantHoundTutorialCard() }
            if q == 5 {
                _ = campaign.grantUsurpedLifeMedalAfterQ4()
                #expect(campaign.ownedRelicIDs.contains(MPCChapterOneCatalog.usurpedLifeMedalRelicID))
                for (relic, price) in [(MPCChapterOneCatalog.saltSealedBreathingBagRelicID, 120), (MPCChapterOneCatalog.returnGiftClaspRelicID, 160)] {
                    try #require(wallet >= price)
                    wallet -= price; spent += price
                    campaign.ownedRelicIDs.insert(relic)
                }
            }
            if q >= 5, wallet >= 30, campaign.inventory["consumable_pain_salve", default: 0] == 0 {
                wallet -= 30; spent += 30
                campaign.inventory["consumable_pain_salve"] = 1
            }
            if q == 8 { _ = campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 8) }
            var base = campaign.loadout(forMissionID: mission.id)
            base.talents = MPCStageLoadout.talents(budget: campaign.chapterTalentPointsEarned)
            // Story walls (2026-09-28) ask for side content: the tower floors and bounty relic they name.
            base.churchGear = wallGear(beforeOrAt: q)
            base.bountyRelicID = wallRelic(q)
            // From Q5 the medal is the active relic: no mask cracks are spent (the no-mask route).
            if q >= 5 { base.selectedActiveRelicID = MPCChapterOneCatalog.usurpedLifeMedalRelicID }
            struct Try: Sendable { let loadout: MPCChapterOneLoadout; let medal: Double? }
            var tries: [Try] = []
            let passives: [String?] = q < 5 ? [nil] : [MPCChapterOneCatalog.saltSealedBreathingBagRelicID, MPCChapterOneCatalog.returnGiftClaspRelicID]
            for cards in RealLoop.orders(before: q) {
                try #require(cards.count <= campaign.loadoutSlotCapacity)
                try #require(cards.allSatisfy { campaign.unlockedSkillIDs.contains($0) || mission.trialSkillID == $0 })
                for passive in passives {
                    for medal in q >= 5 ? [6.0, 14.0] : [nil] {
                        var loadout = base
                        loadout.normalSkillIDs = cards
                        loadout.relicIDs = passive.map { [$0] } ?? []
                        try #require(loadout.relicIDs.allSatisfy(campaign.ownedRelicIDs.contains))
                        tries.append(.init(loadout: loadout, medal: medal))
                    }
                }
            }
            let inventory = campaign.inventory, party = campaign.party
            @Sendable func play(_ t: Try) throws -> MPCStoryVerificationRunner.Report {
                try MPCStoryVerificationRunner.run(mission: q, loadout: t.loadout, policy: .init(medalFrom: t.medal, salveBelow: 400),
                                                   consumables: inventory, party: party)
            }
            let chosen = try #require(try await RealLoop.firstWin(tries) { try play($0).won }, "No earned Q\(q) build wins with actual inventory")
            let report = try play(chosen)
            print("EARNED_AUDIT Q\(q) cards=\(RealLoop.name(chosen.loadout.normalSkillIDs)) end=\(report.session.playerHP) masks=\(report.maskUses)")
            if q >= 5 { #expect(report.maskUses == 0) }
            let before = campaign.inventory["currency_copper", default: 0]
            campaign.completeEncounter(report.session)
            wallet += campaign.inventory["currency_copper", default: 0] - before
            let settled = campaign
            campaign.completeEncounter(report.session)
            #expect(campaign == settled)
            #expect(campaign.completedMissionIDs.contains(mission.id))
            #expect(wallet == campaign.inventory["currency_copper", default: 0] - spent)
            #expect(wallet >= 0)
        }
        #expect(campaign.completedMissionIDs.count == last)
        #expect(campaign.masqueradeCrackCount == 0)
        return campaign
    }
}
