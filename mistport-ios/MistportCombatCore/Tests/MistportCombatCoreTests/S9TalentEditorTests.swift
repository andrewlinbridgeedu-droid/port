import XCTest
@testable import MistportCombatCore

final class S9TalentEditorTests: XCTestCase {
    private func id(_ code: String) -> String { "hermit/sequence9/\(code)" }
    private func ranks(_ values: [Int]) -> [String: Int] { Dictionary(uniqueKeysWithValues: values.enumerated().map { (id("T\($0.offset+1)"), $0.element) }) }
    func testFiveLevelsAndText() throws {
        XCTAssertEqual(S9TalentNode.all.count, 18)
        for node in S9TalentNode.all {
            XCTAssertEqual(node.values.count, 5)
            XCTAssertEqual(node.effect(rank: 0), "尚未投入")
            XCTAssertFalse(node.effect(rank: 5).contains("{"))
        }
        var draft = try S9TalentDraft(earned: 30)
        for _ in 0..<5 { try draft.add(id("T1")) }
        XCTAssertThrowsError(try draft.add(id("T1")))
        XCTAssertEqual(draft.spent, 5)
    }
    func testCascadeSixAndEleven() throws {
        var a = try S9TalentDraft(ranks: ranks([5,1,4,0,5,0]), earned: 30)
        let preview = try a.removal(id("T2"))
        XCTAssertEqual(preview.total, 6)
        try a.confirm(preview)
        XCTAssertEqual(a.ranks[id("T3")], 4)
        XCTAssertNil(a.ranks[id("T5")])
        let b = try S9TalentDraft(ranks: ranks([5,0,5,0,5,0]), earned: 30)
        XCTAssertEqual(try b.removal(id("T1")).total, 11)
    }
    func testStaleDraftAndBudgetAndStory() throws {
        var d = try S9TalentDraft(ranks: ranks([1,0,0,0,0,0]), earned: 2)
        let p = try d.removal(id("T1"))
        try d.add(id("T2"))
        XCTAssertThrowsError(try d.confirm(p))
        XCTAssertThrowsError(try d.add(id("P1")))
        var locked = try S9TalentDraft(earned: 30, unlocked: [id("T1")])
        XCTAssertThrowsError(try locked.add(id("P1")))
        XCTAssertThrowsError(try S9TalentDraft(ranks: ranks([0,0,5,0,5,0]), earned: 30))
    }
    @MainActor func testRealStorageConflictBackupAndFutureVersion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = S9TalentFileStore(url: directory.appendingPathComponent("save.json"))
        var a = try S9TalentDraft(earned: 30)
        let stale = a
        try a.add(id("T1"))
        a.didSave(try store.commit(a))
        XCTAssertThrowsError(try store.commit(stale))
        try a.add(id("T2"))
        a.didSave(try store.commit(a))
        XCTAssertEqual(try store.load(earned: 30, unlocked: S9TalentRules.ids).nodes.count, 2)
        let backup = try JSONDecoder().decode(S9TalentSave.self, from: Data(contentsOf: store.url.appendingPathExtension("backup")))
        XCTAssertEqual(backup.saveRevision, 1)
        try Data("{\"saveSchemaVersion\":99}".utf8).write(to: store.url)
        let original = try Data(contentsOf: store.url)
        XCTAssertThrowsError(try store.commit(a))
        XCTAssertEqual(try Data(contentsOf: store.url), original)
    }
}
