import Foundation

/// Rules publish targets; the home map owns placement and animation only.
public struct MPCStreetTaskTarget: Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case postal, neighbor, bounty, remnant, urgentErrand, jointErrand, commission }
    public let id: String
    public let taskID: String
    public let kind: Kind
    public let personID: String?
    public let placeID: String?
    public let title: String
    public init(id: String, taskID: String, kind: Kind, personID: String? = nil,
                placeID: String? = nil, title: String) {
        self.id = id; self.taskID = taskID; self.kind = kind
        self.personID = personID; self.placeID = placeID; self.title = title
    }
}

public enum MPCStreetTaskCatalog {
    public static func bountyTargets(_ ledger: MPCChurchBountyLedger) -> [MPCStreetTaskTarget] {
        MPCChurchBountyCatalog.all.flatMap { bounty -> [MPCStreetTaskTarget] in
            guard let progress = ledger.cases[bounty.id], progress.accepted, !progress.claimed else { return [] }
            if progress.pendingTurnIn {
                return [.init(id: bounty.id + ":turn-in", taskID: bounty.id, kind: .bounty,
                              placeID: "church", title: "回教会交案：" + bounty.title)]
            }
            return bounty.nodes.filter { node in
                (!progress.evidenceIDs.contains(node.id) || node.id == "identity")
                    && node.requires.isSubset(of: progress.evidenceIDs)
            }.map { node in
                let person = personID(speaker: node.speaker)
                return .init(id: bounty.id + ":" + node.id, taskID: bounty.id, kind: .bounty,
                             personID: node.id == "identity" ? nil : person,
                             placeID: node.id == "identity" ? bounty.id : (person == nil ? placeID(location: node.location) : nil),
                             title: bounty.title + " · " + node.location)
            }
        }
    }
    private static func personID(speaker: String) -> String? {
        // Exact citizen identities precede short aliases such as "档案".
        if let person = MPCNeighborCatalog.all.first(where: { speaker.contains($0.name) }) { return person.id }
        let names = [("邮差", "postman"), ("门牌登记", "west-lane"), ("花摊", "market-lane"),
                     ("奥黛尔", "odelle"), ("维拉", "vera"), ("档案", "archivist"),
                     ("诺恩", "norn"), ("港务员", "harbor-officer"), ("伊莱", "ilya"),
                     ("莫尔", "mohr"), ("老水手", "old-sailor")]
        return names.first { speaker.contains($0.0) }?.1
    }
    private static func placeID(location: String) -> String {
        if location.contains("排水") { return "drain" }
        if ["巡逻", "封锁公告", "警察"].contains(where: location.contains) { return "police" }
        if location.contains("港务") || location.contains("码头") || location.contains("沉船") { return "harbor" }
        if ["市政", "档案", "卷宗", "民事", "公证", "验印", "雇工"].contains(where: location.contains) { return "cityhall" }
        if location.contains("诊所") { return "clinic" }
        if ["教会", "钟台", "施济", "避难", "联络"].contains(where: location.contains) { return "church" }
        if location.contains("酒馆") { return "tavern" }
        if location.contains("咖啡馆") { return "cafe" }
        if location.contains("工坊") || location.contains("工业") { return "industry" }
        return "oldstreet"
    }
}
