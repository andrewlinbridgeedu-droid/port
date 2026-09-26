import Foundation

/// Authored chapter contract. Defining a mission never makes its unfinished runtime available.
public enum MPCChapterOneVictoryObjective: Equatable, Sendable {
    case defeatRoster
    case subdueAndDisconnect
    case rescueConvoy
    case severVoluntaryContract
    case surviveBossCycles(Int)
    case surviveBossCyclesThenClearEscorts(Int)
    case defeatBossAlive
}

public struct MPCChapterOneActorContract: Equatable, Sendable {
    public let entityID: String
    public let modelID: String
    public let contentID: String
}

public struct MPCChapterOneFirstClearContract: Equatable, Sendable {
    public let copper: Int
    public let merit: Int
    public let talentPoints: Int
    public let skillDust: Int
    public let itemIDs: [String]
    public var experience: Int { 0 }
}

public enum MPCChapterOneThirtyMissionContract {
    public static let missionCount = 30
    // Do not change this gate merely because a static definition exists.
    public static let acceptedPlayableMissionCount = 30

    public static func objective(for number: Int) -> MPCChapterOneVictoryObjective {
        switch number {
        case 13, 15, 21, 22: .subdueAndDisconnect
        case 20: .rescueConvoy
        case 25: .severVoluntaryContract
        case 28: .surviveBossCycles(5)
        case 29: .surviveBossCyclesThenClearEscorts(5)
        case 30: .defeatBossAlive
        default: .defeatRoster
        }
    }

    /// This predicate is deliberately fed completed logical actions, not projectile hits.
    /// Every objective checks survival after the final impact. Mutual defeat never wins.
    public static func objectiveSatisfied(
        mission number: Int, playerAlive: Bool, enemiesRemaining: Int,
        bossCyclesCompleted: Int = 0, escortsRemaining: Int = 0,
        localControlDisconnected: Bool = false, rescueCompleted: Bool = false,
        voluntaryContractSevered: Bool = false, bossDefeated: Bool = false
    ) -> Bool {
        guard (1...missionCount).contains(number), playerAlive else { return false }
        switch objective(for: number) {
        case .defeatRoster: return enemiesRemaining == 0
        case .subdueAndDisconnect: return localControlDisconnected && enemiesRemaining == 0
        case .rescueConvoy: return rescueCompleted
        case .severVoluntaryContract: return voluntaryContractSevered
        case .surviveBossCycles(let count): return bossCyclesCompleted >= count
        case .surviveBossCyclesThenClearEscorts(let count): return bossCyclesCompleted >= count && escortsRemaining == 0
        case .defeatBossAlive: return bossDefeated && enemiesRemaining == 0
        }
    }

    public static func firstClear(for number: Int) -> MPCChapterOneFirstClearContract? {
        guard (1...missionCount).contains(number) else { return nil }
        let copper: Int
        switch number {
        case 1...5: copper = 30
        case 6...10: copper = 40
        case 11...15: copper = 50
        case 16...20: copper = 80
        case 21...25: copper = 100
        case 26...29: copper = 120
        default: copper = 300
        }
        let talent = [9: 4, 16: 4, 18: 6, 22: 8, 24: 8][number] ?? 0
        let merit = [9: 20, 15: 20, 21: 20, 30: 40][number] ?? 0
        var items = evidenceByMission[number] ?? []
        if number == 1 { items.append("consumable_pain_salve") }
        if number == 12 { items.append("consumable_mirror_salve") }
        if number == 25 { items += ["chapter30_p04_personal_proof", "chapter30_u01_needle_permit"] }
        if number == 26 { items.append("chapter30_p05_paradox_proof") }
        if number == 30 { items += ["chapter30_p06_ownerless_echo", "chapter30_u02_church_continuation"] }
        return .init(copper: copper, merit: merit, talentPoints: talent,
                     skillDust: [9, 14].contains(number) ? 30 : 0, itemIDs: items)
    }

    /// Same entity survives early encounters. Similar bodies do not imply resurrection.
    public static func actors(for number: Int) -> [MPCChapterOneActorContract] {
        let authored: [(String, String, String)]
        switch number {
        case 1: authored = [("G01", "M01", "enemy_hollow_clockmaker_q1")]
        case 2: authored = [("G02A", "M02", "enemy_resonant_clock_guard_q2"), ("G02B", "M02", "enemy_resonant_clock_guard_q2")]
        case 5: authored = [("E05", "M04", "enemy_emerald_revenant")]
        case 6: authored = [("W06", "M05", "enemy_archive_gatekeeper")]
        case 7: authored = [("G07A", "M01", "enemy_hollow_clockmaker"), ("G07B", "M01", "enemy_hollow_clockmaker"), ("K07", "M06", "enemy_memory_leech_node")]
        case 8: authored = [("L08", "M07", "enemy_memory_leech")]
        case 9: authored = [("S09", "M10", "enemy_calibration_puppet"), ("K09", "M06", "enemy_memory_leech_node")]
        case 11: authored = [("L11A", "M07", "enemy_memory_leech"), ("L11B", "M07", "enemy_memory_leech"), ("G11", "M01", "enemy_hollow_clockmaker")]
        case 12: authored = [("S12A", "M10", "enemy_calibration_puppet"), ("S12B", "M10", "enemy_calibration_puppet")]
        case 14: authored = [("L14", "M07", "enemy_memory_leech"), ("S14", "M10", "enemy_calibration_puppet")]
        case 3, 4, 16: authored = [("H03", "M03", "enemy_clockwork_hound")]
        case 10: authored = [("A10", "M08", "enemy_clockwork_hound"), ("B10", "M05", "enemy_calibration_puppet")]
        case 13, 21: authored = [("R-01", "M11", "elite_clock_chaser"), ("K\(number)", "M06", "enemy_memory_leech_node")]
        case 15: authored = [("WVR-01", "M09", "enemy_hollow_clockmaker"), ("K15A", "M06", "enemy_memory_leech_node"), ("K15B", "M06", "enemy_memory_leech_node")]
        case 17: authored = [("P17", "M12", "enemy_codex_executor")]
        case 18: authored = [("J19", "M13", "enemy_archive_adjudicator")]
        case 19: authored = [("E20", "M04", "enemy_emerald_revenant")]
        case 20, 26: authored = [("V21", "M14", "enemy_archive_convoy")]
        case 22, 25: authored = [("WVR-01", "M09", "enemy_hollow_clockmaker")]
        case 23: authored = [("J25", "M13", "enemy_archive_adjudicator")]
        case 24: authored = [("A26", "M08", "enemy_clockwork_hound"), ("G26", "M02", "enemy_resonant_clock_guard_q2")]
        case 27: authored = [("W29", "M05", "enemy_archive_gatekeeper"), ("A29", "M08", "enemy_clockwork_hound")]
        case 28, 30: authored = [("BOSS01", "M15", "boss_chronarch_sovereign")]
        case 29: authored = [("BOSS01", "M15", "boss_chronarch_sovereign"), ("P29", "M12", "enemy_codex_executor"), ("G29", "M01", "enemy_hollow_clockmaker")]
        default: return []
        }
        return authored.map { .init(entityID: $0.0, modelID: $0.1, contentID: $0.2) }
    }

    public static let evidenceByMission: [Int: [String]] = [
        1: ["item_old_clock_pass"],
        2: ["chapter30_e02"],
        3: ["chapter30_e03", "item_late_second_watch"],
        4: ["chapter30_e05", "chapter30_e06"],
        5: ["evidence_delivery_stub"],
        6: ["chapter30_e08"],
        7: ["item_blank_identity"],
        8: ["chapter30_e10"],
        9: ["evidence_testimony_versions"],
        10: ["evidence_missing_register"],
        11: ["evidence_family_dossier", "chapter30_e14"],
        12: ["evidence_transfer_order", "chapter30_e16"],
        13: ["key_thirteenth_recording"],
        14: ["evidence_nameplate_box"],
        15: ["evidence_belonging_threads", "chapter30_e20"],
        16: ["chapter30_e21"],
        17: ["chapter30_e22", "chapter30_e23"],
        18: ["chapter30_e24", "chapter30_e25"],
        19: ["chapter30_e26", "chapter30_e27"],
        20: ["chapter30_e28"],
        21: ["chapter30_e29", "chapter30_e30"],
        22: ["chapter30_e31"],
        23: ["chapter30_e32"],
        24: ["chapter30_e33", "chapter30_e34"],
        25: ["chapter30_e35"],
        26: ["chapter30_e36", "chapter30_e37"],
        27: ["chapter30_e38", "chapter30_e39", "chapter30_e40", "chapter30_e41"],
        28: ["chapter30_e42"],
        29: ["chapter30_e43"],
        30: ["chapter30_e44"],
    ]
}
