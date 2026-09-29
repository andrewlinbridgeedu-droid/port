import Foundation

/// Minimal Chapter Two bridge: Black Salt Shore → the outer-harbour transfer
/// station → back to the shore. Opens only after Q30 and the Sequence 8
/// ritual; records which of the two event contacts the player has met.
/// It never reads or writes Chapter One progress, so the Q30 outcome stands.
/// Places, people and IDs are provisional until the content freeze; meeting
/// both contacts is personal story eligibility only, not an open world event.
public struct MPCChapterTwoBridge: Codable, Equatable, Sendable {
    public static let ruleVersion = "chapter2-saltport-bridge-v1"
    public static let storyMission = 30
    public static let shoreID = "loc.black_salt_shore.quarantine_pier.provisional"
    public static let stationID = "loc.saltport.outer_transfer_station.provisional"

    public enum Location: String, Codable, Sendable { case shore, station }

    public enum Contact: String, Codable, CaseIterable, Sendable {
        case aidaVein = "npc.saltport.aida_vein.provisional"
        case rowanKell = "npc.saltport.rowan_kell.provisional"

        public var name: String { self == .aidaVein ? "艾妲·维恩" : "罗文·凯尔" }
        public var role: String { self == .aidaVein ? "泵站联合会 · 工程监理" : "灰帆联营 · 护航总管" }
        public var lines: [String] {
            switch self {
            case .aidaVein: [
                "“你从雾港来？那边住宅楼的楼梯，已经连着三夜没有灯了。”",
                "“这座转运站只有一套主接驳装置。我要先把它接回住宅和诊所的药基处理。账册随时可以查。”",
                "“先有能安稳过夜的人，才会有明天来买你货的人。”",
            ]
            case .rowanKell: [
                "“燃料船在外锚地等了两天。卸不下来，雾港的炉子就只能等。”",
                "“先让码头和工坊复工，城里才付得起下一船燃料，也付得起修理。”",
                "“没有下一船燃料，今天承诺亮着的灯，明天一盏也留不住。”",
            ]
            }
        }
    }

    public enum Failure: Error, Equatable { case chapterOne, ritual, notAtStation }

    public private(set) var location: Location = .shore
    public private(set) var metContacts: [Contact] = []

    public init() {}

    public static func isOpen(q30Complete: Bool, ritualComplete: Bool) -> Bool { q30Complete && ritualComplete }

    /// Both contacts met: the player may later see the supply dispute's
    /// sign-up once that event exists. Grants nothing by itself.
    public var worldEventStoryReady: Bool { Contact.allCases.allSatisfy(metContacts.contains) }

    /// Returns whether anything changed; a repeated tap is a no-op.
    @discardableResult
    public mutating func travelToStation(q30Complete: Bool, ritualComplete: Bool) throws -> Bool {
        try Self.requireOpen(q30Complete: q30Complete, ritualComplete: ritualComplete)
        guard location != .station else { return false }
        location = .station
        return true
    }

    @discardableResult
    public mutating func meet(_ contact: Contact, q30Complete: Bool, ritualComplete: Bool) throws -> Bool {
        try Self.requireOpen(q30Complete: q30Complete, ritualComplete: ritualComplete)
        guard location == .station else { throw Failure.notAtStation }
        guard !metContacts.contains(contact) else { return false }
        metContacts.append(contact)
        return true
    }

    /// The return path is always open, so the player is never stranded at
    /// the station. It goes back to the shore, not to Mistport.
    @discardableResult
    public mutating func returnToShore() -> Bool {
        guard location != .shore else { return false }
        location = .shore
        return true
    }

    private static func requireOpen(q30Complete: Bool, ritualComplete: Bool) throws {
        guard q30Complete else { throw Failure.chapterOne }
        guard ritualComplete else { throw Failure.ritual }
    }
}
