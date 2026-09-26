import Testing
@testable import MistportCombatCore
struct PaperRelicHandoffTests {
    @Test func staleOpeningEquipmentIsRejected() throws {
        for number in 1...4 {
            let s = try MPCChapterOneEncounterSession.start(encounterID: String(format: "chapter01_q%02d_encounter", number), loadout: .init(relicIDs: ["relic_paper_raincoat"]))
            #expect(!s.loadout.relicIDs.contains("relic_paper_raincoat"))
            #expect(!s.q5PaperRelicReady)
        }
    }
    @Test func retiredRelicIsRejectedInSixthMission() throws {
        let s = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q06_encounter", loadout: .init(relicIDs: ["relic_paper_raincoat"]))
        #expect(!s.loadout.relicIDs.contains("relic_paper_raincoat"))
    }
}
