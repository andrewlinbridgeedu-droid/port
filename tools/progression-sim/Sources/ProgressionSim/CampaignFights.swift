import Foundation
import MistportCombatCore

/// Memoize identical deterministic combat inputs across bank counterfactuals.
/// Sessions are value types. No rewards, money, clocks or campaign state are cached.
/// Set BANK_CACHE=0 to compare the entire output against an uncached run.
enum CampaignFights {
    static let enabled = (CommandLine.arguments.contains("bank") || CommandLine.arguments.contains("housing")) && ProcessInfo.processInfo.environment["BANK_CACHE"] != "0"
    struct StoryInput: Equatable {
        let q: Int, sequence: [FoolSkillID], mask: Bool, consumables: [String: Int]
        let priorityCore: Bool, ultimate: Bool, loadout: MPCChapterOneLoadout
        let medalOffset: Double?, precise: Bool, actionDelay: Double
    }
    struct TowerInput: Equatable {
        let number: Int, medalOffset: Double, suppliedLoadout: MPCChapterOneLoadout
        let actionDelay: Double, encounterID: String?
    }
    nonisolated(unsafe) static var stories: [Int: [(StoryInput, ChapterDriver.Report)]] = [:]
    nonisolated(unsafe) static var towers: [String: [(TowerInput, TowerDriver.Report)]] = [:]
    static func story(q: Int, sequence: [FoolSkillID], mask: Bool, consumables: [String: Int],
                      priorityCore: Bool, ultimate: Bool, loadout: MPCChapterOneLoadout,
                      medalOffset: Double?, precise: Bool, actionDelay: Double) throws -> ChapterDriver.Report {
        let key = StoryInput(q: q, sequence: sequence, mask: mask, consumables: consumables,
                             priorityCore: priorityCore, ultimate: ultimate, loadout: loadout,
                             medalOffset: medalOffset, precise: precise, actionDelay: actionDelay)
        if enabled, let hit = stories[q]?.first(where: { $0.0 == key }) { return hit.1 }
        let r = try ChapterDriver.run(q: q, sequence: sequence, mask: mask, consumables: consumables,
                                      priorityCore: priorityCore, ultimate: ultimate, loadout: loadout,
                                      medalOffset: medalOffset, precise: precise, actionDelay: actionDelay)
        if enabled { stories[q, default: []].append((key, r)) }
        return r
    }
    static func tower(number: Int, medalOffset: Double, suppliedLoadout: MPCChapterOneLoadout,
                      actionDelay: Double, encounterID: String? = nil) throws -> TowerDriver.Report {
        let key = TowerInput(number: number, medalOffset: medalOffset, suppliedLoadout: suppliedLoadout,
                             actionDelay: actionDelay, encounterID: encounterID)
        let group = encounterID ?? "floor-\(number)"
        if enabled, let hit = towers[group]?.first(where: { $0.0 == key }) { return hit.1 }
        let r = try TowerDriver.run(number: number, medalOffset: medalOffset, suppliedLoadout: suppliedLoadout,
                                    actionDelay: actionDelay, encounterID: encounterID)
        if enabled { towers[group, default: []].append((key, r)) }
        return r
    }
}
