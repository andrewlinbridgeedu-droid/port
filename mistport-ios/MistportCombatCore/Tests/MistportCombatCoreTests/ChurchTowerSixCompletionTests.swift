import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Six demon full tower completion")
struct ChurchTowerSixCompletionTests {
    @Test func actualCoreSequentialHundred() throws {
        var progress = MPCChurchTowerProgress()
        var rows = ["floor,mission,waves,seconds,hp,outcome,medal_uses,wave_entry_hp,skills,coins,merit"]
        var rosters = [String]()
        var economy = ["floor,story_complete,story_copper,tower_copper,tower_merit,material_purchase_reserve,dust_earned,dust_spent,talent_points_earned,talents_learned,medal_cost,potions_cost,repair_cost,available_copper"]
        var towerCopper = 0, towerMerit = 0
        for f in MPCChurchTowerCatalog.floors {
            let r = try MPCChurchTowerVerificationRunner.run(number: f.number)
            #expect(r.session.outcome == .victory, "floor \(f.number) ended \(r.session.outcome) HP \(r.session.playerHP)")
            #expect(progress.canEnter(f.number, completedMissionNumbers: Set(1...r.mission)))
            if r.session.outcome == .victory { #expect(progress.claimVictory(floor: f.number, completedMissionNumbers: Set(1...r.mission)) != nil) }
            towerCopper += f.firstClearReward.coins; towerMerit += f.firstClearReward.merit
            let rewards = (1...r.mission).compactMap { MPCChapterOneThirtyMissionContract.firstClear(for: $0) }
            let copper = rewards.reduce(0) { $0 + $1.copper }
            let dust = rewards.reduce(0) { $0 + $1.skillDust }
            let loadout = MPCChurchTowerVerificationRunner.recommendedLoadout(for: f)
            let dustSpent = loadout.skillLevels.values.reduce(0) { sum, level in sum + (1..<level).compactMap { MPCSkillGrowth.upgradeCost(from: $0) }.reduce(0,+) }
            let materialReserve = r.mission >= 20 ? 600 : r.mission >= 17 ? 260 : 0
            #expect(dustSpent <= dust)
            economy.append("\(f.number),\(r.mission),\(copper),\(towerCopper),\(towerMerit),\(materialReserve),\(dust),\(dustSpent),\(rewards.reduce(0) { $0 + $1.talentPoints }),\(loadout.talents.learned.sorted().joined(separator: ";")),0,0,0,\(180+copper+towerCopper-materialReserve)")
            let skills = r.skillCasts.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ";")
            rows.append("\(f.number),\(r.mission),\(f.waves.count),\(r.seconds),\(r.session.playerHP),\(r.session.outcome),\(r.medalUses),\(r.waveEntryHP.map(String.init).joined(separator: ";")),\(skills),\(f.firstClearReward.coins),\(f.firstClearReward.merit)")
            for (w, descriptors) in r.rosterDescriptors.enumerated() { rosters.append("\(f.number)\t\(w)\t\(descriptors.joined(separator: ","))") }
        }
        if let dir = ProcessInfo.processInfo.environment["TOWER_REPORT_DIR"] {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try rows.joined(separator: "\n").write(toFile: dir + "/core-hundred.csv", atomically: true, encoding: .utf8)
            try economy.joined(separator: "\n").write(toFile: dir + "/core-economy.csv", atomically: true, encoding: .utf8)
            try rosters.joined(separator: "\n").write(toFile: dir + "/rosters.tsv", atomically: true, encoding: .utf8)
        }
        #expect(progress.clearedFloors.count == 100)
    }
    @Test func elevenSpeciesAndEarnedGrowth() {
        #expect(Set(MPCChurchTowerCatalog.floors.flatMap { $0.waves.flatMap { $0.map(\.species) } }) == Set<MPCChurchTowerCatalog.Species>([.shieldJaw, .saltSac, .backSac, .scissor, .crown, .boneclaw, .copperback, .crimsonBrute, .veilOracle, .goldenThroat, .moonfang]))
        #expect(!MPCChurchTowerCatalog.floors.flatMap { $0.waves.flatMap { $0 } }.contains { $0.species == .riftHound })
        for f in MPCChurchTowerCatalog.floors {
            let q = MPCChurchTowerVerificationRunner.mission(for: f)
            let l = MPCChurchTowerVerificationRunner.recommendedLoadout(for: f)
            let unlocked = Set(MPCChapterOneCatalog.missions.filter { $0.number <= q }.flatMap(\.permanentSkillIDs))
            #expect(Set(l.normalSkillIDs).isSubset(of: unlocked))
            #expect(!l.normalSkillIDs.contains(.backstageChange))
            #expect(l.normalSkillIDs.count <= 4)
        }
    }
    @Test func milestonesCompareRealRelicBuildsAndPoorPreparation() throws {
        var rows = ["floor,route,passive,medal_offset,seconds,hp,outcome,medal_uses"]
        for n in [10, 30, 50, 70, 90, 100] {
            let q = MPCChurchTowerVerificationRunner.mission(for: MPCChurchTowerCatalog.floor(number: n)!)
            let passives: [String?] = [nil] + MPCChurchLoanOffer.all.filter { $0.unlockMission <= q && $0.relicID != "relic_blank_name_card" }.map { Optional($0.relicID) }
            for route in MPCChurchTowerVerificationRunner.Route.allCases where route != .blankCard || q >= 17 {
                for passive in route == .unprepared ? [nil] : passives {
                    let r = try MPCChurchTowerVerificationRunner.run(number: n, route: route, passive: passive)
                    rows.append("\(n),\(route.rawValue),\(passive ?? "none"),22,\(r.seconds),\(r.session.playerHP),\(r.session.outcome),\(r.medalUses)")
                }
            }
            let rushed = try MPCChurchTowerVerificationRunner.run(number: n, medalOffset: 0)
            rows.append("\(n),medal_rushed,none,0,\(rushed.seconds),\(rushed.session.playerHP),\(rushed.session.outcome),\(rushed.medalUses)")
        }
        if let dir = ProcessInfo.processInfo.environment["TOWER_REPORT_DIR"] {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try rows.joined(separator: "\n").write(toFile: dir + "/milestone-builds.csv", atomically: true, encoding: .utf8)
        }
    }

    @Test func timingPerturbationIsReportedRatherThanHidden() throws {
        var rows = ["floor,seed,jitter,seconds,hp,outcome"]
        for n in [10, 30, 50, 70, 90, 100] {
            for seed in 1...20 {
                let r = try MPCChurchTowerVerificationRunner.run(number: n, jitter: 0.2, seed: UInt64(seed))
                rows.append("\(n),\(seed),0.2,\(r.seconds),\(r.session.playerHP),\(r.session.outcome)")
            }
        }
        if let dir = ProcessInfo.processInfo.environment["TOWER_REPORT_DIR"] {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try rows.joined(separator: "\n").write(toFile: dir + "/timing-samples.csv", atomically: true, encoding: .utf8)
        }
    }

    @Test func supportCastsAreFiniteAndEmpowerExpiresOnWallClock() throws {
        var healer = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_021", companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        let source = healer.enemies[0].id, recipient = healer.enemies[1].id
        try healer.endRound(actingEnemyID: recipient, at: 0) // open true shield
        for cycle in 0..<5 {
            _ = try healer.applyPartyDamage(70, to: recipient)
            try healer.endRound(actingEnemyID: source, at: Double(cycle * 4))
            try healer.endRound(actingEnemyID: source, at: Double(cycle * 4 + 1))
            #expect(healer.lastEnemyActionResolutions.last?.healing == (cycle < 4 ? 60 : 0))
            try healer.endRound(actingEnemyID: source, at: Double(cycle * 4 + 2))
            try healer.endRound(actingEnemyID: source, at: Double(cycle * 4 + 3))
        }
        var crown = try MPCChapterOneEncounterSession.start(encounterID: "church_tower_041", companionIDs: [], loadout: .init(normalSkillIDs: [], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        let id = crown.enemies[0].id
        try crown.endRound(actingEnemyID: id, at: 0)
        try crown.endRound(actingEnemyID: id, at: 1)
        crown.advanceChurchTowerEffects(at: 8.99)
        #expect(crown.towerEmpoweredEnemyIDs.count == 1)
        crown.advanceChurchTowerEffects(at: 9)
        #expect(crown.towerEmpoweredEnemyIDs.isEmpty)
    }

}
