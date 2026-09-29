import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Bounty slot ledger, save migration, daily guarantee and wall hints")
struct BountyRelicLedgerTests {
    @Test func grantingIsOncePerCaseAndTheFirstRelicIsWorn() {
        var ledger = MPCBountyRelicLedger()
        let first = ledger.grant(caseID: "b04"), again = ledger.grant(caseID: "b04")
        let second = ledger.grant(caseID: "b01"), unknown = ledger.grant(caseID: "missing")
        #expect(first == MPCBountyRelicCatalog.reverseSeal && again == nil && unknown == nil)
        #expect(second == MPCBountyRelicCatalog.brokenSword && ledger.equippedID == MPCBountyRelicCatalog.reverseSeal)
        let wore = ledger.equip(MPCBountyRelicCatalog.brokenSword)
        #expect(wore && ledger.equippedID == MPCBountyRelicCatalog.brokenSword)
        let notOwned = ledger.equip(MPCBountyRelicCatalog.lifeLedger)
        #expect(!notOwned)
        let removed = ledger.equip(nil)
        #expect(removed && ledger.equippedID == nil)
    }

    @Test func migrationRetiresBountyGearAndPaysRelicsExactlyOnce() throws {
        var gear = MPCChurchGearLedger()
        for id in ["tower-f10-anchor-blade", "bounty-b01-broken-sword", "bounty-b07-bell-throat"] { gear.grant(id) }
        var ledger = MPCBountyRelicLedger()
        let migrated = ledger.migrate(gear: &gear, claimedCaseIDs: ["b07", "b01"])
        #expect(migrated)
        #expect(gear.ownedIDs == ["tower-f10-anchor-blade"] && gear.equippedWeaponID == "tower-f10-anchor-blade")
        #expect(ledger.retiredGearIDs == ["bounty-b01-broken-sword", "bounty-b07-bell-throat"])
        #expect(ledger.ownedIDs == [MPCBountyRelicCatalog.brokenSword, "bounty_relic_b07_bell_throat"])
        #expect(ledger.equippedID == MPCBountyRelicCatalog.brokenSword)
        gear.grant("bounty-b02-backframe")
        let repeated = ledger.migrate(gear: &gear, claimedCaseIDs: ["b02"])
        #expect(!repeated)
        #expect(gear.ownedIDs.contains("bounty-b02-backframe") && ledger.ownedIDs.count == 2)
        let decoded = try JSONDecoder().decode(MPCBountyRelicLedger.self, from: JSONEncoder().encode(ledger))
        #expect(decoded == ledger && decoded.hasMigrated)
    }

    @Test func mechanismWallsPutTheirCaseOnTheBoardUntilTheRelicIsOwned() {
        #expect(MPCProgressionWalls.guaranteedCase(nextMission: 12, ownedRelicIDs: []) == "b01")
        #expect(MPCProgressionWalls.guaranteedCase(nextMission: 22, ownedRelicIDs: []) == "b04")
        #expect(MPCProgressionWalls.guaranteedCase(nextMission: 30, ownedRelicIDs: []) == "b10")
        #expect(MPCProgressionWalls.guaranteedCase(nextMission: 12, ownedRelicIDs: [MPCBountyRelicCatalog.brokenSword]) == nil)
        #expect(MPCProgressionWalls.guaranteedCase(nextMission: 8, ownedRelicIDs: []) == nil)
        let day = MPCDailyBountyRotation.issue(dayOrdinal: 2026_09_28, eligibleIDs: ["b02", "b03", "b05", "b06", "b07"])
        let carried = day.guaranteeing("b01")
        #expect(carried.offerIDs == day.offerIDs + ["b01"] && carried.dayOrdinal == day.dayOrdinal)
        #expect(carried.guaranteeing("b01") == carried && day.guaranteeing(nil) == day)
    }

    @Test func wallHintNamesOnlyWhatIsStillMissing() {
        let title: (String) -> String? = { MPCChurchBountyCatalog.bounty(id: $0)?.title }
        let q12 = MPCProgressionWalls.defeatHint(mission: 12, highestTowerFloor: 0, equippedRelicID: nil, ownedRelicIDs: [], caseTitle: title)
        #expect(q12?.contains("第七号空壳") == true && q12?.contains("七号缺齿剑") == true)
        let owned = MPCProgressionWalls.defeatHint(mission: 12, highestTowerFloor: 0, equippedRelicID: nil,
                                                   ownedRelicIDs: [MPCBountyRelicCatalog.brokenSword], caseTitle: title)
        #expect(owned?.contains("换上七号缺齿剑") == true)
        #expect(MPCProgressionWalls.defeatHint(mission: 12, highestTowerFloor: 0, equippedRelicID: MPCBountyRelicCatalog.brokenSword,
                                               ownedRelicIDs: [MPCBountyRelicCatalog.brokenSword], caseTitle: title) == nil)
        let q30 = MPCProgressionWalls.defeatHint(mission: 30, highestTowerFloor: 90, equippedRelicID: nil, ownedRelicIDs: [], caseTitle: title)
        #expect(q30?.contains("第 90 层") == false && q30?.contains("绯月寿账签") == true)
        #expect(MPCProgressionWalls.defeatHint(mission: 8, highestTowerFloor: 3, equippedRelicID: nil, ownedRelicIDs: [], caseTitle: title)?
            .contains("第 10 层") == true)
        #expect(MPCProgressionWalls.defeatHint(mission: 9, highestTowerFloor: 0, equippedRelicID: nil, ownedRelicIDs: [], caseTitle: title) == nil)
    }
}
