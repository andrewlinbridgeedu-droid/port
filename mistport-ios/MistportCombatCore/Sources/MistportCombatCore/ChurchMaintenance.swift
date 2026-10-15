import Foundation

public enum MPCChurchMaintenanceKind: String, Codable, CaseIterable, Sendable { case patrol, towerMaintenance }
public struct MPCChurchMaintenanceObjective: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let evidence: String
    public let choices: [MPCChurchBountyChoice]
    public let correctChoiceID: String
}
public struct MPCChurchMaintenanceJob: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: MPCChurchMaintenanceKind
    public let floor: Int
    public var completedObjectiveIDs: Set<String> = []
    public var excludedChoiceIDs: Set<String> = []
    public var activeBattleID: String?
    public var successfulBattleID: String?
    public var settledBattleIDs: Set<String> = []
    public var claimed = false
    public var completedSites: Set<Int> = []
    public var siteCount: Int { 3 }
    public var allSitesComplete: Bool { (1...siteCount).allSatisfy { completedSites.contains($0) } }
    public var currentSite: Int { (1...siteCount).first { !completedSites.contains($0) } ?? siteCount }
    public var encounterID: String {
        kind == .patrol ? "church_maintenance_j1_s\(currentSite)_" + id : "church_maintenance_j2_f\(floor)_" + (floor.isMultiple(of: 10) ? "" : "legacy_") + "s\(currentSite)_" + id
    }
    public init(id: String, kind: MPCChurchMaintenanceKind, floor: Int) { self.id = id; self.kind = kind; self.floor = floor }
    enum CodingKeys: String, CodingKey { case id, kind, floor, completedObjectiveIDs, excludedChoiceIDs, activeBattleID, successfulBattleID, settledBattleIDs, claimed, completedSites }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id); kind = try c.decode(MPCChurchMaintenanceKind.self, forKey: .kind); floor = try c.decode(Int.self, forKey: .floor)
        completedObjectiveIDs = try c.decodeIfPresent(Set<String>.self, forKey: .completedObjectiveIDs) ?? []
        excludedChoiceIDs = try c.decodeIfPresent(Set<String>.self, forKey: .excludedChoiceIDs) ?? []
        activeBattleID = try c.decodeIfPresent(String.self, forKey: .activeBattleID)
        successfulBattleID = try c.decodeIfPresent(String.self, forKey: .successfulBattleID)
        settledBattleIDs = try c.decodeIfPresent(Set<String>.self, forKey: .settledBattleIDs) ?? []
        claimed = try c.decodeIfPresent(Bool.self, forKey: .claimed) ?? false
        completedSites = try c.decodeIfPresent(Set<Int>.self, forKey: .completedSites) ?? (claimed ? [1,2,3] : successfulBattleID != nil ? [1] : [])
        if !allSitesComplete { successfulBattleID = nil }
    }
    public var objectives: [MPCChurchMaintenanceObjective] { MPCChurchMaintenanceCatalog.objectives(kind:kind,floor:floor) }
}
public struct MPCChurchMaintenanceReward: Codable, Equatable, Sendable {
    public let receiptID: String
    public let jobID: String
    public let copper: Int
    public let merit: Int
}
public enum MPCChurchMaintenanceError: Error, Equatable { case locked, invalidFloor, duplicateJob, invalidJob, missingObjective, invalidChoice, battlePending, invalidBattle, alreadyClosed }
public enum MPCChurchMaintenanceCatalog {
    private static func descriptor(_ id: String) -> (floor: Int, site: Int, patrol: Bool)? {
        let patrol = id.hasPrefix("church_maintenance_j1_")
        let prefix = patrol ? "church_maintenance_j1_" : "church_maintenance_j2_f"
        guard id.hasPrefix(prefix) else { return nil }
        let parts = String(id.dropFirst(prefix.count)).split(separator: "_", omittingEmptySubsequences: false).map(String.init)
        if patrol {
            if parts.count == 2, parts[0].hasPrefix("s"), let site = Int(parts[0].dropFirst()), (1...3).contains(site), validJobID(parts[1]) { return (10, site, true) }
            if parts.count == 1, validJobID(parts[0]) { return (10, 1, true) }
        } else {
            if parts.count == 3, let floor = Int(parts[0]), (10...100).contains(floor), floor.isMultiple(of: 10), parts[1].hasPrefix("s"), let site = Int(parts[1].dropFirst()), (1...3).contains(site), validJobID(parts[2]) { return (floor, site, false) }
            // Unpublished single-floor jobs keep only species already seen there.
            if parts.count == 4, let floor = Int(parts[0]), (1...100).contains(floor), parts[1] == "legacy", parts[2].hasPrefix("s"), let site = Int(parts[2].dropFirst()), (1...3).contains(site), validJobID(parts[3]) { return (floor, site, false) }
            // Original encounter IDs remain readable during an interrupted battle.
            if parts.count == 2, let floor = Int(parts[0]), (1...100).contains(floor), validJobID(parts[1]) { return (floor, 1, false) }
        }
        return nil
    }
    public static func towerFloor(encounterID: String) -> Int? { descriptor(encounterID)?.floor }
    public static func enemyConfiguration(contentID: String) -> MPCChurchTowerCatalog.Enemy? {
        let pieces = contentID.components(separatedBy: "~maintenance-")
        guard pieces.count == 2, !pieces[1].isEmpty else { return nil }
        return MPCChurchTowerCatalog.enemyConfiguration(contentID: pieces[0])
    }
    public static func encounter(id: String) -> MPCEncounterContent? {
        if let lights = MPCLightsPublicTarget.encounter(id: id) { return lights }
        if let street = MPCStreetEncounters.encounter(id: id) { return street }
        guard let d = descriptor(id) else { return nil }
        let baseWaves: [[String]]
        if d.patrol {
            // Patrol only reuses the first two demon bodies. Do not tie the
            // contract's body count to future edits of a numbered floor.
            let early = MPCChurchTowerCatalog.floors.prefix(10).flatMap { $0.encounter.waves.flatMap(\.enemyIDs) }
            let jaw = early.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0)?.species == .shieldJaw }!
            let salt = early.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0)?.species == .saltSac } ?? jaw
            baseWaves = d.site == 1 ? [[jaw, jaw], [salt]] : d.site == 2 ? [[salt], [jaw, jaw]] : [[jaw, salt], [jaw]]
        } else {
            // Select authored, already encountered bodies. No player-level scaling.
            let seen = MPCChurchTowerCatalog.floors.filter { $0.number <= d.floor }.flatMap { $0.encounter.waves.flatMap(\.enemyIDs) }
            func source(_ species: MPCChurchTowerCatalog.Species) -> String {
                return seen.first { MPCChurchTowerCatalog.enemyConfiguration(contentID: $0)?.species == species } ?? seen[0]
            }
            let attacker: MPCChurchTowerCatalog.Species = d.floor >= 60 ? .boneclaw : d.floor >= 40 ? .scissor : d.floor >= 10 ? .saltSac : .shieldJaw
            let support: MPCChurchTowerCatalog.Species = d.floor >= 50 ? .crown : d.floor >= 30 ? .backSac : .shieldJaw
            let first = source(attacker), second = source(.shieldJaw), shield = source(.shieldJaw), aid = source(support)
            baseWaves = d.site == 1 ? [[first], [shield], [second, aid]] : d.site == 2 ? [[second, aid], [first], [shield]] : [[shield], [second], [first, aid]]
        }
        let waves = baseWaves.enumerated().map { wave, ids in
            MPCEncounterWave(enemyIDs: ids.enumerated().map { slot, source in source + "~maintenance-s\(d.site)-w\(wave)-p\(slot)" })
        }
        let title = (d.patrol ? "巡检" : "维护\(max(1, d.floor - 9))–\(d.floor)层") + " \(d.site)/3"
        return .init(id:id,name:title,investigationID:"church_maintenance",waves:waves,companionSlots:0,fixedRewardItemIDs:[],firstClearRelicID:nil,recommendedTags:["church_maintenance"])
    }
    static func validJobID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 80 && id.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || $0 == "-" }
    }
    public static func objectives(kind: MPCChurchMaintenanceKind, floor: Int) -> [MPCChurchMaintenanceObjective] {
        let rows: [(String,String,String,String,String)] = kind == .patrol ? [
            ("seal","核对入口封签","登记簿记载：东侧入口用双线封签，左下留检查孔。","双线封签、左下检查孔","单线封签、右上检查孔"),
            ("route","比对渗出路线","巡检员报告：盐粉只在东墙断开；西门脚印是正常换班留下的。","沿东墙断开的盐粉线检查","把西门换班脚印当成渗出口"),
            ("secure","确认疏散与清剿范围","值守记录：两名工人已离开东侧封口，北侧是仍有人值守的正常通道。","封住东侧渗出口后进入清剿","把仍有人值守的北侧封死")
        ] : [
            ("seal","核对已通层封条","维护单指定第\(floor)层；封条层号必须与维护单相同，不能擅自深入。","使用第\(floor)层维护封条","换成第\(min(100,floor+1))层探索封条"),
            ("route","确认损坏支路","报修单圈出回程通道，主阵仍在工作。工单只允许处理这条损坏支路。","先标记回程支路，保留主阵供能","为了省事停掉全部主阵"),
            ("secure","完成安全交接","值守者已退至标记后方，封堵线外禁止施法；残余怪物仍占着维护通道。","确认值守者退后，再清理维护通道","跳过残余怪物直接领取维护报酬")
        ]
        return rows.map { id,title,evidence,correct,wrong in
            .init(id:id,title:title,evidence:evidence,choices:[
                .init(id:id+"_match",text:correct,explanation:"与维护单和现场记录相符。"),
                .init(id:id+"_mismatch",text:wrong,explanation:"与工单不符，重新核对；不扣钱或功勋。")
            ],correctChoiceID:id+"_match")
        }
    }
}
/// Repeatable work has a new job ID and a new real battle each time. No first-
/// clear rewards are attached to its cloned encounter. Host atomically applies
/// claim receipts to the shared copper/M/G wallet; no daily or entry fee exists.
public struct MPCChurchMaintenanceLedger: Codable, Equatable, Sendable {
    public private(set) var jobs: [String:MPCChurchMaintenanceJob] = [:]
    public init() {}
    @discardableResult public mutating func accept(kind: MPCChurchMaintenanceKind, floor: Int? = nil, completedMissions: Set<Int>, clearedTowerFloors: Set<Int>, jobID: String = UUID().uuidString) throws -> MPCChurchMaintenanceJob {
        guard MPCChurchMaintenanceCatalog.validJobID(jobID) else { throw MPCChurchMaintenanceError.invalidJob }
        guard jobs[jobID] == nil else { throw MPCChurchMaintenanceError.duplicateJob }
        let target: Int
        if kind == .patrol {
            guard completedMissions.contains(9) else { throw MPCChurchMaintenanceError.locked }; target = 4
        } else {
            guard let floor, (10...100).contains(floor), floor.isMultiple(of: 10), (1...floor).allSatisfy({ clearedTowerFloors.contains($0) }) else { throw MPCChurchMaintenanceError.invalidFloor }; target = floor
        }
        let job = MPCChurchMaintenanceJob(id:jobID,kind:kind,floor:target)
        jobs[jobID] = job; return job
    }
    @discardableResult public mutating func verify(jobID: String, objectiveID: String, choiceID: String) throws -> Bool {
        guard var job = jobs[jobID], !job.claimed else { throw MPCChurchMaintenanceError.invalidJob }
        guard let index = job.objectives.firstIndex(where: {$0.id == objectiveID}) else { throw MPCChurchMaintenanceError.invalidChoice }
        let objective = job.objectives[index]
        guard objective.choices.contains(where: {$0.id == choiceID}) else { throw MPCChurchMaintenanceError.invalidChoice }
        guard index == 0 || job.completedObjectiveIDs.contains(job.objectives[index-1].id) else { throw MPCChurchMaintenanceError.missingObjective }
        let correct = choiceID == objective.correctChoiceID
        if correct { job.completedObjectiveIDs.insert(objectiveID) } else { job.excludedChoiceIDs.insert(choiceID) }
        jobs[jobID] = job; return correct
    }
    @discardableResult public mutating func beginBattle(jobID: String, battleID: String) throws -> String {
        guard var job = jobs[jobID] else { throw MPCChurchMaintenanceError.invalidJob }
        guard !job.claimed, !job.allSitesComplete else { throw MPCChurchMaintenanceError.alreadyClosed }
        guard job.objectives.allSatisfy({job.completedObjectiveIDs.contains($0.id)}) else { throw MPCChurchMaintenanceError.missingObjective }
        guard !battleID.isEmpty, !jobs.values.contains(where: {$0.settledBattleIDs.contains(battleID)}) else { throw MPCChurchMaintenanceError.invalidBattle }
        if let active = job.activeBattleID { guard active == battleID else { throw MPCChurchMaintenanceError.battlePending }; return job.encounterID }
        guard !jobs.values.contains(where: {$0.activeBattleID == battleID}) else { throw MPCChurchMaintenanceError.invalidBattle }
        job.activeBattleID = battleID; jobs[jobID] = job; return job.encounterID
    }
    @discardableResult public mutating func settleBattle(jobID: String, battleID: String, outcome: MPCChurchBattleOutcome) throws -> Bool {
        guard var job = jobs[jobID] else { throw MPCChurchMaintenanceError.invalidJob }
        if job.settledBattleIDs.contains(battleID) { return false }
        guard job.activeBattleID == battleID else { throw MPCChurchMaintenanceError.invalidBattle }
        job.activeBattleID = nil; job.settledBattleIDs.insert(battleID)
        if outcome == .victory {
            job.completedSites.insert(job.currentSite)
            if job.allSitesComplete { job.successfulBattleID = battleID }
        }
        jobs[jobID] = job; return true
    }
    public mutating func claim(jobID: String) throws -> MPCChurchMaintenanceReward? {
        guard var job = jobs[jobID] else { throw MPCChurchMaintenanceError.invalidJob }
        if job.claimed { return nil }
        guard job.allSitesComplete, job.successfulBattleID != nil else { return nil }
        job.claimed = true; jobs[jobID] = job
        return .init(receiptID:"maintenance-"+jobID,jobID:jobID,copper:job.kind == .patrol ? 60 : 80,merit:job.kind == .patrol ? 6 : 8)
    }
}
