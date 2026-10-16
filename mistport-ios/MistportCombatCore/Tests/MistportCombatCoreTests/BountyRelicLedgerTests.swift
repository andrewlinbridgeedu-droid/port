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
        // Floor cleared but shallower gear worn: only the tower-checked walls ask to change it.
        #expect(MPCProgressionWalls.defeatHint(mission: 18, highestTowerFloor: 60, equippedRelicID: nil, ownedRelicIDs: [],
                                               wornTowerDepth: 40, caseTitle: title)?.contains("换上深井第 50 层或更深的装备") == true)
        #expect(MPCProgressionWalls.defeatHint(mission: 18, highestTowerFloor: 60, equippedRelicID: nil, ownedRelicIDs: [],
                                               wornTowerDepth: 60, caseTitle: title) == nil)
        #expect(MPCProgressionWalls.defeatHint(mission: 8, highestTowerFloor: 10, equippedRelicID: nil, ownedRelicIDs: [],
                                               wornTowerDepth: 2, caseTitle: title) == nil)
    }

    /// Pre-fight warning (2026-10-15, user: the walls stay lethal, but say first what the mission needs).
    @Test func prebattleHintNamesExactlyTheUnmetWallRequirement() throws {
        typealias W = MPCProgressionWalls
        typealias C = MPCBountyRelicCatalog
        func loadout(_ depth: Int, _ relic: String?) -> MPCChapterOneLoadout {
            var loadout = MPCChapterOneLoadout()
            loadout.churchGear = .init(towerDepth: depth)
            loadout.bountyRelicID = relic
            return loadout
        }
        #expect(W.prebattleHint(mission: 12, loadout: loadout(100, nil)) == "这一关需要：通缉遗落物「七号缺齿剑」")
        #expect(W.prebattleHint(mission: 12, loadout: loadout(0, C.reverseSeal)) == "这一关需要：通缉遗落物「七号缺齿剑」")
        #expect(W.prebattleHint(mission: 12, loadout: loadout(0, C.brokenSword)) == nil)
        #expect(W.prebattleHint(mission: 22, loadout: loadout(100, C.brokenSword)) == "这一关需要：通缉遗落物「伪造者倒签笔」")
        #expect(W.prebattleHint(mission: 22, loadout: loadout(0, C.reverseSeal)) == nil)
        #expect(W.prebattleHint(mission: 18, loadout: loadout(40, C.lifeLedger)) == "这一关需要：教会塔第 50 层或更深的装备")
        #expect(W.prebattleHint(mission: 18, loadout: loadout(50, nil)) == nil)
        #expect(W.prebattleHint(mission: 26, loadout: loadout(60, nil)) == "这一关需要：教会塔第 70 层或更深的装备")
        #expect(W.prebattleHint(mission: 26, loadout: loadout(70, nil)) == nil)
        #expect(W.prebattleHint(mission: 30, loadout: loadout(80, nil)) == "这一关需要：教会塔第 90 层或更深的装备、通缉遗落物「绯月寿账签」")
        #expect(W.prebattleHint(mission: 30, loadout: loadout(90, C.brokenSword)) == "这一关需要：通缉遗落物「绯月寿账签」")
        #expect(W.prebattleHint(mission: 30, loadout: loadout(80, C.lifeLedger)) == "这一关需要：教会塔第 90 层或更深的装备")
        #expect(W.prebattleHint(mission: 30, loadout: loadout(100, C.lifeLedger)) == nil)
        // Workshop pieces count by their tier, as in the fight.
        let craftedF50 = try #require(MPCChurchGearCatalog.craftedPiece(tier: 50, slot: .weapon))
        var ledger = MPCChurchGearLedger()
        ledger.grant(craftedF50.id)
        let wore = ledger.equip(craftedF50.id, highestTowerFloor: 50)
        #expect(wore)
        var crafted = loadout(0, nil)
        crafted.churchGear = ledger.stats
        #expect(W.prebattleHint(mission: 18, loadout: crafted) == nil)

        // Independent table of the lethal walls (PROGRESSION_WALLS_AND_BOUNTY_RELICS_20260928.md §10):
        // every mission, depth and worn relic gets exactly these requirements and nothing else (Q8's
        // recommended floor is no lethal check, Q28/Q29 are no walls).
        let walls: [Int: (floor: Int?, relic: String?)] = [12: (nil, C.brokenSword), 18: (50, nil), 22: (nil, C.reverseSeal),
                                                           26: (70, nil), 30: (90, C.lifeLedger)]
        for q in 1...30 {
            for depth in [0, 10, 40, 49, 50, 69, 70, 89, 90, 100] {
                for relic in [nil] + C.all.map(\.id) {
                    var expected: [W.Requirement] = []
                    if let floor = walls[q]?.floor, depth < floor { expected.append(.towerGear(floor: floor)) }
                    if let id = walls[q]?.relic, relic != id { expected.append(.bountyRelic(try #require(C.relic(id)))) }
                    #expect(W.unmetRequirements(mission: q, loadout: loadout(depth, relic)) == expected, "Q\(q) F\(depth) \(relic ?? "-")")
                    #expect(W.wearsWallRelic(mission: q, bountyRelicID: relic) == (walls[q]?.relic.map { $0 == relic } ?? true))
                    #expect((W.prebattleHint(mission: q, loadout: loadout(depth, relic)) == nil) == expected.isEmpty)
                }
            }
        }
    }
}
