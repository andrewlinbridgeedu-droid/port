import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Battle music follows authored scenes")
struct BattleMusicRouteTests {
    @Test func allChapterBattlesHaveTheirChapterTheme() {
        for number in 1...30 {
            let encounterID = String(format: "chapter01_q%02d_encounter", number)
            let expected: MPCBattleMusicCue = number <= 5 ? .petals : number <= 15 ? .gears : number <= 27 ? .harbor : .brass
            #expect(MPCBattleMusicCue.forEncounterID(encounterID) == expected)
        }
    }

    @Test func towerFloorTransitions() {
        let cases: [(Int, MPCBattleMusicCue)] = [
            (1, .gears), (30, .gears), (31, .harbor), (70, .harbor), (71, .brass), (100, .brass)
        ]
        for (floor, cue) in cases {
            #expect(MPCBattleMusicCue.forEncounterID(String(format: "church_tower_%03d", floor)) == cue)
        }
    }

    @Test func maintenanceUsesItsTowerFloor() {
        #expect(MPCBattleMusicCue.forEncounterID("church_maintenance_j1_s1_job1") == .gears)
        #expect(MPCBattleMusicCue.forEncounterID("church_maintenance_j2_f50_s1_job1") == .harbor)
        #expect(MPCBattleMusicCue.forEncounterID("church_maintenance_j2_f90_s1_job1") == .brass)
    }

    @Test func allBountiesHaveATheme() {
        let expected: [String: MPCBattleMusicCue] = [
            "b01": .gears, "b02": .harbor, "b03": .harbor, "b04": .gears,
            "b05": .brass, "b06": .harbor, "b07": .petals, "b08": .petals,
            "b09": .gears, "b10": .brass
        ]
        #expect(MPCChurchBountyCatalog.all.count == expected.count)
        for bounty in MPCChurchBountyCatalog.all {
            #expect(MPCBattleMusicCue.forEncounterID(bounty.encounterID) == expected[bounty.id])
        }
    }

    @Test func unknownBattleHasPredictableFallback() {
        #expect(MPCBattleMusicCue.forEncounterID("unknown_battle") == .gears)
        #expect(Set(MPCBattleMusicCue.allCases.map(\.assetName)).count == 4)
    }
}
