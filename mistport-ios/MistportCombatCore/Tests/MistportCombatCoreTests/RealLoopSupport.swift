import Foundation
import Testing
@testable import MistportCombatCore

/// Real-loop balance helpers (2026-10-15). Every battle runs through the production steppers
/// (`MPCStoryVerificationRunner`, `MPCChurchTowerVerificationRunner`) with stage-legal loadouts
/// (`MPCStageLoadout`), the ordered cast timing, 7 s cards and pressure. They replace the test-only
/// simulators that kept the old 1.75/1.65 s cadence and hands.
enum RealLoop {
    static let clasp = MPCChapterOneCatalog.returnGiftClaspRelicID
    static let bag = MPCChapterOneCatalog.saltSealedBreathingBagRelicID
    static let medal = MPCChapterOneCatalog.usurpedLifeMedalRelicID
    /// `"11,12,01,05"` → 抢拍, 燃镜, 错步, 伪证.
    static func line(_ codes: String) -> [FoolSkillID] { codes.split(separator: ",").map { FoolSkillID(rawValue: "fool_skill_" + $0)! } }
    static func name(_ order: [FoolSkillID]) -> String { order.map { String($0.rawValue.suffix(2)) }.joined(separator: ",") }

    /// One battle per item on every core; results in item order.
    static func map<T: Sendable, R: Sendable>(_ items: [T], _ body: @escaping @Sendable (T) throws -> R) async throws -> [R] {
        try await withThrowingTaskGroup(of: (Int, R).self) { group in
            for (i, item) in items.enumerated() { group.addTask { (i, try body(item)) } }
            var out = [R?](repeating: nil, count: items.count)
            for try await (i, r) in group { out[i] = r }
            return out.map { $0! }
        }
    }
    /// The first item (in order) whose battle wins, trying a core's worth at a time.
    static func firstWin<T: Sendable>(_ items: [T], _ body: @escaping @Sendable (T) throws -> Bool) async throws -> T? {
        var start = 0
        while start < items.count {
            let chunk = Array(items[start..<min(items.count, start + 10)])
            if let i = try await map(chunk, body).firstIndex(of: true) { return chunk[i] }
            start += chunk.count
        }
        return nil
    }

    /// A story battle with the stage loadout before Q`q`: the walls' floors and relic unless given.
    static func story(_ q: Int, _ order: [FoolSkillID], gear: MPCChurchGearStats? = nil, relic: String?? = .none,
                      passive: String? = clasp, active: String? = nil, talents: HermitTalentAllocation? = nil, levels: Bool = true,
                      policy: MPCStoryVerificationRunner.Policy = .audit, consumables: [String: Int] = [:], delay: Double = 0,
                      outfit: MPCOutfit = .mistportNight,
                      configure: (@Sendable (inout MPCChapterOneEncounterSession) -> Void)? = nil) throws -> MPCStoryVerificationRunner.Report {
        var l = MPCStageLoadout.loadout(before: q, order: order, gear: gear ?? MPCStageLoadout.wallGear(beforeOrAt: q),
                                        bountyRelic: relic ?? MPCStageLoadout.wallRelic(q), passive: passive, activeRelic: active, outfit: outfit)
        if let talents { l.talents = talents }
        if !levels { l.skillLevels = [:] }
        return try MPCStoryVerificationRunner.run(mission: q, loadout: l, policy: policy, consumables: consumables,
                                                  tuning: .init(actionDelay: delay), configure: configure)
    }
    /// The no-mask route from Q5: the medal (from `medal` s) as the active relic, the mask never raised.
    static func noMask(_ q: Int, _ order: [FoolSkillID], medal at: Double, passive: String? = clasp, salve: Bool = false,
                       talents: HermitTalentAllocation? = nil, levels: Bool = true, gear: MPCChurchGearStats? = nil,
                       delay: Double = 0) throws -> MPCStoryVerificationRunner.Report {
        try story(q, order, gear: gear, passive: passive, active: medal, talents: talents, levels: levels,
                  policy: .init(mask: false, medalFrom: at, salveBelow: salve ? 400 : nil),
                  consumables: salve ? ["consumable_pain_salve": 1] : [:], delay: delay)
    }
    static func branch(_ name: String, _ count: Int = 4) -> HermitTalentAllocation {
        .restored((0..<count).map { "\(name).\($0)" }, budget: count)
    }

    /// A church battle (tower floor, bounty, maintenance, street) with the loadout before Q`n` (n = stage + 1),
    /// the given tower gear and the tower runner's inputs.
    static func church(_ encounterID: String, before n: Int, order: [FoolSkillID], gearThrough floor: Int,
                       passive: String? = nil, medalAt: Double = 6, jitter: Double = 0, seed: UInt64 = 1,
                       delay: Double = 0) throws -> MPCChurchTowerVerificationRunner.Report {
        let l = MPCStageLoadout.loadout(before: n, order: order, gear: MPCStageLoadout.towerGear(through: floor), passive: passive, activeRelic: medal)
        let floor = encounterID.hasPrefix("church_tower_") ? Int(encounterID.suffix(3)) : nil
        return try MPCChurchTowerVerificationRunner.run(number: floor ?? 1, medalOffset: medalAt, jitter: jitter, seed: seed,
                                                        suppliedLoadout: l, actionDelay: delay, encounterID: floor == nil ? encounterID : nil)
    }
    /// The deepest floor a player on the daily pace has cleared once Q`stage` is done.
    static func paceFloor(after stage: Int) -> Int {
        MPCChurchTowerCatalog.floors.last { MPCChurchTowerCatalog.paceMission(floor: $0.number) <= stage }?.number ?? 0
    }
    static func towerHand(before n: Int) -> [FoolSkillID] { MPCStageLoadout.towerHand(before: n) }

    /// Arrangements that won on the 2026-10-15 audit (Q5–Q9 with the medal), tried first so the focused
    /// checks stay fast; a search still falls back to every other arrangement.
    static let knownWinners: [Int: [String]] = [
        1: ["01"], 2: ["05,01", "01,05"], 3: ["05,01"], 4: ["05,01", "01,05"], 5: ["05,01", "01,09", "09,01", "01,05"],
        6: ["08,01", "05,08", "09,08", "01,08", "01,05", "05,01"], 7: ["11,05,01", "09,11,01", "08,11,01", "11,01,08", "11,08,01"],
        8: ["05,01,04", "05,08,04", "05,04,08", "08,05,04", "09,05,04", "01,05,04"],
        9: ["05,01,08", "05,08,01", "05,01,04", "11,01,12", "11,12,01", "11,12,04", "12,09,08", "12,08,09", "09,12,08"],
        10: ["05,04,06,01", "05,04,01,06", "09,01,11,12", "11,12,09,01"], 11: ["05,04,09,07", "05,09,04,07", "09,05,04,07", "09,07,05,04"],
        12: ["11,07,12,04", "05,04,06,07", "11,13,12,09", "13,11,12,09"], 13: ["11,13,09,12", "11,09,13,12", "09,11,13,12", "09,08,06,07"],
        14: ["06,09,08,07", "07,09,08,06", "05,04,09,07", "04,07,05,09"], 15: ["09,07,06,08", "11,09,13,12", "05,04,09,07", "09,05,04,07"],
        16: ["11,12,04,07", "11,07,12,04", "12,04,11,07", "12,04,07,11"], 17: ["11,12,04,07", "11,07,12,04", "12,04,07,11", "07,04,11,12"],
        18: ["05,04,07,09", "05,07,09,04", "05,09,04,07", "04,07,05,09"], 19: ["05,04,07,06", "05,04,07,09", "05,04,09,07", "12,04,07,11"],
        20: ["11,12,01,05", "11,12,05,01", "11,01,12,05", "11,01,05,12"], 21: ["12,04,11,07", "12,04,07,11", "07,04,11,12", "05,04,07,06"],
        22: ["05,01,11,12", "11,12,04,07", "11,07,12,04", "12,04,11,07"], 23: ["05,04,07,06", "05,04,07,09", "12,04,11,07", "12,04,07,11"],
        24: ["11,09,13,12", "13,11,12,09", "11,01,09,12", "11,01,12,09"], 25: ["05,04,07,06", "05,04,07,09", "12,04,11,07", "12,04,07,11"],
        26: ["05,04,07,09", "05,04,09,07", "05,09,04,07", "04,05,09,07"], 27: ["12,09,01,11", "12,09,11,01", "11,01,09,12", "06,05,04,07"],
        28: ["09,05,07,04", "11,12,04,07", "07,11,12,04", "04,07,05,06"], 29: ["04,07,09,05", "09,01,12,11", "11,09,01,12", "11,01,09,12"],
        30: ["05,04,07,06", "05,04,09,07", "09,04,07,05", "04,07,05,09"]
    ]
    /// The audit's arrangements before Q`q`, known winners first.
    static func orders(before q: Int) -> [[FoolSkillID]] {
        let known = (knownWinners[q] ?? []).map(line)
        return known + MPCStageLoadout.orders(before: q).filter { !known.contains($0) }
    }
}
