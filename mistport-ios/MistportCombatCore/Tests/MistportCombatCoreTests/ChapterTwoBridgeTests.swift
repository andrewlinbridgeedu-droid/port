import Foundation
import Testing
@testable import MistportCombatCore

@Suite("Chapter Two bridge: ritual gate, two contacts, return path")
struct ChapterTwoBridgeTests {
    @Test(arguments: [(false, false, MPCChapterTwoBridge.Failure.chapterOne),
                      (false, true, .chapterOne),
                      (true, false, .ritual)])
    func closedUntilQ30AndRitual(q30: Bool, ritual: Bool, expected: MPCChapterTwoBridge.Failure) {
        var bridge = MPCChapterTwoBridge()
        #expect(throws: expected) { try bridge.travelToStation(q30Complete: q30, ritualComplete: ritual) }
        #expect(bridge == MPCChapterTwoBridge())
    }

    @Test func contactsAreMetAtTheStationOnly() throws {
        var bridge = MPCChapterTwoBridge()
        #expect(throws: MPCChapterTwoBridge.Failure.notAtStation) {
            try bridge.meet(.aidaVein, q30Complete: true, ritualComplete: true)
        }
        let travelled = try bridge.travelToStation(q30Complete: true, ritualComplete: true)
        let travelledAgain = try bridge.travelToStation(q30Complete: true, ritualComplete: true)
        #expect(travelled && !travelledAgain)
        let metRowan = try bridge.meet(.rowanKell, q30Complete: true, ritualComplete: true)
        #expect(metRowan && !bridge.worldEventStoryReady)
        let metRowanAgain = try bridge.meet(.rowanKell, q30Complete: true, ritualComplete: true)
        let metAida = try bridge.meet(.aidaVein, q30Complete: true, ritualComplete: true)
        #expect(!metRowanAgain && metAida)
        #expect(bridge.worldEventStoryReady && bridge.metContacts == [.rowanKell, .aidaVein])
    }

    @Test func returnGoesToTheShoreAndKeepsMeetings() throws {
        var bridge = MPCChapterTwoBridge()
        let returnedFromShore = bridge.returnToShore()
        #expect(!returnedFromShore)
        try bridge.travelToStation(q30Complete: true, ritualComplete: true)
        try bridge.meet(.aidaVein, q30Complete: true, ritualComplete: true)
        let returned = bridge.returnToShore()
        #expect(returned && bridge.location == .shore)
        #expect(bridge.metContacts == [.aidaVein])
        let decoded = try JSONDecoder().decode(MPCChapterTwoBridge.self, from: JSONEncoder().encode(bridge))
        #expect(decoded == bridge)
    }

    @Test func contactIDsAreDistinctAndProvisional() {
        let ids = MPCChapterTwoBridge.Contact.allCases.map(\.rawValue)
        #expect(Set(ids).count == 2 && ids.allSatisfy { $0.hasSuffix(".provisional") })
        #expect(MPCChapterTwoBridge.Contact.allCases.allSatisfy { $0.lines.count == 3 })
    }
}
