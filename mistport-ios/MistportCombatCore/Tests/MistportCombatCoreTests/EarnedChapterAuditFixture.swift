import Testing
@testable import MistportCombatCore

/// Core campaign plus a paid shop ledger; no native UI or device-play claim.
enum EarnedChapterAuditFixture {
    /// Tower gear for every floor the walls up to `q` name.
    static func wallGear(beforeOrAt q: Int) -> MPCChurchGearStats {
        let floor = MPCProgressionWalls.walls.filter { $0.mission <= q }.compactMap(\.towerFloor).max() ?? 0
        var ledger = MPCChurchGearLedger()
        if floor > 0 { for f in 1...floor { if let drop = MPCChurchGearCatalog.towerDrop(floor: f) { ledger.grant(drop.id) } } }
        return ledger.stats
    }

    /// The bounty relic a mechanism wall at `q` asks for, if any.
    static func wallRelic(_ q: Int) -> String? {
        MPCProgressionWalls.wall(mission: q)?.caseID.flatMap { MPCBountyRelicCatalog.relic(forCase: $0)?.id }
    }

    static func run(through last: Int) throws -> MPCChapterOneCampaignState {
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
                try #require(wallet >= 30)
                wallet -= 30; spent += 30
                campaign.inventory["consumable_pain_salve"] = 1
            }
            if q == 8 { _ = campaign.applyChapterMissionProgress(districtID: "old-clock", missionNumber: 8) }
            let cards: [FoolSkillID] = q < 8 ? [.sidestepStrike]
                : q <= 9 ? [.identityDisplacement, .sidestepStrike]
                : q == 10 ? [.fabricatedEvidence, .sidestepStrike]
                : q == 11 ? [.fabricatedEvidence, .identityDisplacement, .mirrorPursuit, .sidestepStrike]
                : [.sidestepStrike, .fabricatedEvidence, .mirrorPursuit, .absurdFinale]
            var base = campaign.loadout(forMissionID: mission.id)
            base.normalSkillIDs = cards
            try #require(cards.count <= campaign.loadoutSlotCapacity)
            try #require(cards.allSatisfy { campaign.unlockedSkillIDs.contains($0) || mission.trialSkillID == $0 })
            base.talents = .restored((0...5).map { "trickery.\($0)" } + (0...5).map { "omen.\($0)" }, budget: campaign.chapterTalentPointsEarned)
            // Story walls (2026-09-28) ask for side content: the tower floors and bounty relic they name.
            base.churchGear = wallGear(beforeOrAt: q)
            base.bountyRelicID = wallRelic(q)
            let passives = q < 5 ? [""] : [MPCChapterOneCatalog.saltSealedBreathingBagRelicID, MPCChapterOneCatalog.returnGiftClaspRelicID]
            var winner: NewMaskBalanceSimulator.Report?
            for passive in passives where winner == nil {
                for offset in [6.0, 14.0] where winner == nil {
                    var loadout = base
                    loadout.relicIDs = passive.isEmpty ? [] : [passive]
                    try #require(loadout.relicIDs.allSatisfy(campaign.ownedRelicIDs.contains))
                    let report = try NewMaskBalanceSimulator.run(q: q, sequence: cards, mask: q == 3 || q == 4,
                        consumables: campaign.inventory, loadout: loadout, party: campaign.party,
                        medalOffset: q >= 5 ? offset : nil, precise: true)
                    print("EARNED_AUDIT Q\(q) HP=\(campaign.party.playerHP) outcome=\(report.session.outcome) end=\(report.session.playerHP)")
                    if report.session.outcome == .victory { winner = report }
                }
            }
            let report = try #require(winner, "No earned Q\(q) build wins with actual inventory")
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
