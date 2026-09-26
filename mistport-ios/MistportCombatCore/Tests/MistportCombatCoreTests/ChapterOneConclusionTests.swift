import Testing
@testable import MistportCombatCore

@Suite("Chapter one conclusion and misdirection preview")
struct ChapterOneConclusionTests {
    @Test("Every regional ending produces a distinct persistent world state", arguments: MPCChapterOneEndingChoice.allCases)
    func everyEndingPersists(_ choice: MPCChapterOneEndingChoice) {
        var campaign = MPCChapterOneCampaignState.fullyUnlockedTestState
        var training = MPCMisdirectionTrainingSession()
        let result = training.perform(.redirectToIllusion)
        campaign.completeConclusion(ending: choice, trainingResult: result)
        #expect(campaign.endingChoice == choice)
        #expect(campaign.endingWorldState == choice.worldState)
        #expect(!choice.worldState.isEmpty)
    }

    @Test("Both rank-eight preview responses complete with different consequences", arguments: MPCMisdirectionTrainingResponse.allCases)
    func bothTrainingResponses(_ response: MPCMisdirectionTrainingResponse) throws {
        var training = MPCMisdirectionTrainingSession()
        let result = training.perform(response)
        #expect(training.result == result)
        switch response {
        case .redirectToIllusion:
            #expect(result.finalTarget == "舞台幻象")
            #expect(result.attachedStatusApplied)
        case .suppressAttachedStatus:
            #expect(result.finalTarget == "玩家本体")
            #expect(!result.attachedStatusApplied)
        }
    }

    @Test("Conclusion records the regional choice and completed preview")
    func completeConclusion() {
        var campaign = MPCChapterOneCampaignState()
        var training = MPCMisdirectionTrainingSession()
        let result = training.perform(.suppressAttachedStatus)
        campaign.completeConclusion(ending: .sealClock, trainingResult: result)
        #expect(campaign.misdirectionTrainingCompleted)
        #expect(campaign.misdirectionTrainingResponse == .suppressAttachedStatus)
    }
}
