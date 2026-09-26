import Foundation

public enum MPCChapterOneEndingChoice: String, CaseIterable, Codable, Sendable {
    case destroyClock
    case sealClock
    case returnMemories

    public var worldState: String {
        switch self {
        case .destroyClock: "归一档案库被摧毁，失去归属的记忆不再被继续保存。"
        case .sealClock: "归一档案库被教会封存，旧城区保留了一份危险证据。"
        case .returnMemories: "被保存的记忆分还居民，旧城区开始面对彼此冲突的过去。"
        }
    }
}

public enum MPCMisdirectionTrainingResponse: String, CaseIterable, Codable, Sendable {
    case redirectToIllusion
    case suppressAttachedStatus
}

public struct MPCMisdirectionTrainingResult: Equatable, Sendable {
    public let response: MPCMisdirectionTrainingResponse
    public let finalTarget: String
    public let attachedStatusApplied: Bool
    public let summary: String
}

public struct MPCMisdirectionTrainingSession: Equatable, Sendable {
    public private(set) var incomingTarget = "玩家本体"
    public private(set) var attachedStatus = "记忆剥离"
    public private(set) var result: MPCMisdirectionTrainingResult?

    public init() {}

    @discardableResult
    public mutating func perform(_ response: MPCMisdirectionTrainingResponse) -> MPCMisdirectionTrainingResult {
        let value: MPCMisdirectionTrainingResult
        switch response {
        case .redirectToIllusion:
            incomingTarget = "舞台幻象"
            value = .init(
                response: response,
                finalTarget: incomingTarget,
                attachedStatusApplied: true,
                summary: "攻击被偏转到舞台幻象；记忆剥离随幻象一同消散。"
            )
        case .suppressAttachedStatus:
            attachedStatus = "无"
            value = .init(
                response: response,
                finalTarget: incomingTarget,
                attachedStatusApplied: false,
                summary: "攻击仍命中本体，但误导令记忆剥离失去效力。"
            )
        }
        result = value
        return value
    }
}

public extension MPCChapterOneCampaignState {
    mutating func completeConclusion(
        ending: MPCChapterOneEndingChoice,
        trainingResult: MPCMisdirectionTrainingResult
    ) {
        endingChoice = ending
        endingWorldState = ending.worldState
        misdirectionTrainingCompleted = true
        misdirectionTrainingResponse = trainingResult.response
        // The final utility skill is earned by completing the misdirection
        // lesson, separating narrative mastery from ordinary battle drops.
        unlockedSkillIDs.insert(.backstageChange)
        if !loadout.normalSkillIDs.contains(.backstageChange), loadout.normalSkillIDs.count < 4 {
            loadout.normalSkillIDs.append(.backstageChange)
        }
    }
}
