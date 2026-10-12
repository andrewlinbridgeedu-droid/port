import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Church equipment changes real encounters")
struct ChurchGearTests {
    @Test func towerAndBountyDropsAreUniqueAndEquipAfterClaim() throws {
        #expect(MPCChurchGearCatalog.towerDrop(floor: 1) == nil)
        #expect(MPCChurchGearCatalog.towerDrop(floor: 2)?.name == "石颚裂刃")
        #expect(MPCChurchGearCatalog.bountyDrop(caseID: "b07")?.name == "金喉铃护")
        #expect(Set(MPCChurchGearCatalog.all.map(\.id)).count == MPCChurchGearCatalog.all.count)
        var ledger = MPCChurchGearLedger()
        let firstGrant = ledger.grant("tower-f02-jaw-edge")
        #expect(firstGrant)
        let replayGrant = ledger.grant("tower-f02-jaw-edge")
        #expect(!replayGrant)
        #expect(ledger.stats.attackBP == 1_500)
        let armorGrant = ledger.grant("tower-f04-seal-plate")
        #expect(armorGrant)
        #expect(ledger.stats.maxHP == 160)
        let bountyGrant = ledger.grant("bounty-b07-bell-throat")
        #expect(bountyGrant)
        #expect(ledger.equippedArmorID == "bounty-b07-bell-throat")
        let equippedOldArmor = ledger.equip("tower-f04-seal-plate")
        #expect(equippedOldArmor)
        #expect(ledger.equippedArmorID == "tower-f04-seal-plate")
        let unownedEquip = ledger.equip("bounty-b10-life-ledger")
        #expect(!unownedEquip)
        let restored = try JSONDecoder().decode(MPCChurchGearLedger.self, from: JSONEncoder().encode(ledger))
        #expect(restored == ledger)
    }

    @Test func earnedWeaponAndArmorChangeDamageAndSurvival() throws {
        let bareLoadout = MPCChapterOneLoadout(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: [])
        var gearedLoadout = bareLoadout
        gearedLoadout.churchGear = .init(attackBP: 3_600, maxHP: 270, damageReductionBP: 1_100)
        var bare = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_011", companionIDs: [], loadout: bareLoadout)
        var geared = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_011", companionIDs: [], loadout: gearedLoadout)
        #expect(bare.playerMaxHP == 1_000)
        #expect(geared.playerMaxHP == 1_270)
        let target = bare.enemies[0].id
        let bareHit = try bare.useBasicAction(.damage, targetID: target)
        let gearedHit = try geared.useBasicAction(.damage, targetID: target)
        #expect(gearedHit > bareHit)

        bare = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_001", companionIDs: [], loadout: bareLoadout)
        geared = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_001", companionIDs: [], loadout: gearedLoadout)
        let jaw = bare.enemies[0].id
        for tick in 0...2 {
            try bare.endRound(actingEnemyID: jaw, at: Double(tick))
            try geared.endRound(actingEnemyID: jaw, at: Double(tick))
        }
        #expect(geared.playerMaxHP - geared.playerHP < bare.playerMaxHP - bare.playerHP)
    }

    /// Armor health is added at every battle start, so story victories must not
    /// write it back into the persistent party (it would stack once per win).
    @Test func armorHealthNeverStacksIntoThePersistentParty() throws {
        var ledger = MPCChurchGearLedger()
        for floor in 1...10 {
            if let drop = MPCChurchGearCatalog.towerDrop(floor: floor) { ledger.grant(drop.id) }
        }
        #expect(ledger.stats.maxHP == 270)
        var campaign = MPCChapterOneCampaignState.chapterStartState
        let baseMaxHP = campaign.party.playerMaxHP
        for number in 1...2 {
            let mission = try #require(MPCChapterOneCatalog.mission(forOldClockMissionNumber: number))
            var loadout = campaign.loadout(forMissionID: mission.id)
            loadout.churchGear = ledger.stats
            var session = try MPCChapterOneEncounterSession.start(
                encounterID: mission.encounterID, party: campaign.party, companionIDs: [], loadout: loadout)
            #expect(session.playerBaseMaxHP == baseMaxHP + 270)
            for step in 0..<200 where session.outcome == .inProgress {
                for enemy in session.enemies.filter(\.isAlive) {
                    _ = try session.applyPartyDamage(99_999, to: enemy.id)
                    if session.outcome == .inProgress, session.enemies.contains(where: { $0.id == enemy.id && $0.isAlive }) {
                        session.commitEnemyImpact(from: enemy.id)
                        try session.endRound(actingEnemyID: enemy.id, at: Double(step))
                    }
                }
            }
            try #require(session.outcome == .victory)
            campaign.completeEncounter(session)
            #expect(campaign.party.playerMaxHP == baseMaxHP)
            #expect(campaign.party.playerHP <= campaign.party.playerMaxHP)
        }
    }
}
