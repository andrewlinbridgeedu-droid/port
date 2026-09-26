import Testing
@testable import MistportCombatCore

@Suite("Q2 crimson ghost split")
struct Q2GhostSplitTests {
    @Test("Either parent can split first with fixed identities; children never split again", arguments: [0, 1])
    func splitAndVictory(first: Int) throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q02_encounter", companionIDs: [])
        let originals = Array(session.enemies.prefix(2))
        let childIDs = Array(session.enemies.dropFirst(2)).map(\.id)
        #expect(session.enemies.filter(\.isAlive).count == 2)
        #expect(childIDs.allSatisfy { session.foolState(for: $0) == nil })
        #expect(throws: MPCEncounterRuntimeError.invalidTarget) { try session.applyPartyDamage(10, to: childIDs[0]) }
        _ = try session.applyPartyDamage(10_000, to: originals[first].id)
        #expect(session.outcome == .inProgress)
        #expect(session.enemies.filter(\.isAlive).count == 3)
        for slot in 0..<4 {
            let child = session.enemies[slot + 2]
            #expect(child.isAlive == (slot / 2 == first))
            #expect(MPCChapterOneBattleIdentity.battleID(for: child.id, in: session.enemies) == "clock-guard-instance-\(slot + 3)")
            #expect(child.attackIntervalMultiplier == 2.0 / 3.0)
        }
        _ = try session.applyPartyDamage(10_000, to: originals[1 - first].id)
        #expect(session.enemies.filter(\.isAlive).count == 4)
        #expect(session.outcome == .inProgress)
        for id in childIDs.dropLast() {
            _ = try session.applyPartyDamage(10_000, to: id)
            #expect(session.outcome == .inProgress)
        }
        _ = try session.applyPartyDamage(10_000, to: childIDs.last!)
        #expect(session.outcome == .victory)
        #expect(session.enemies.count == 6)
        #expect(session.enemies.allSatisfy { !$0.isAlive })
    }

    @Test("Killing the last original cannot retarget its newborn children in the same cast")
    func lastParentAreaKill() throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q02_encounter", companionIDs: [], loadout: MPCChapterOneCampaignState.fullyUnlockedTestState.loadout(forMissionID: "chapter01_q02"))
        _ = try session.applyPartyDamage(10000, to: session.enemies[0].id)
        for child in Array(session.enemies[2...3]) { _ = try session.applyPartyDamage(10000, to: child.id) }
        let parent = session.enemies[1]
        _ = try session.applyPartyDamage(parent.maxHP - 1, to: parent.id)
        let result = try session.useFoolSkill(.sidestepStrike, targetID: parent.id)
        #expect(result.targets.count == 1)
        #expect(session.enemies[4...5].allSatisfy { $0.hp == $0.maxHP })
    }

    @Test("AoE snapshots original targets and leaves new children undamaged")
    func areaKill() throws {
        var session = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q02_encounter", companionIDs: [], loadout: MPCChapterOneCampaignState.fullyUnlockedTestState.loadout(forMissionID: "chapter01_q02"))
        let originals = Array(session.enemies.prefix(2))
        for enemy in originals { _ = try session.applyPartyDamage(enemy.maxHP - 1, to: enemy.id) }
        let result = try session.useFoolSkill(.sidestepStrike, targetID: originals[0].id)
        #expect(result.targets.count == 2)
        #expect(session.enemies.filter(\.isAlive).count == 4)
        #expect(session.enemies.dropFirst(2).allSatisfy { $0.hp == $0.maxHP })
        #expect(session.outcome == .inProgress)
        let fresh = try MPCChapterOneEncounterSession.start(encounterID: "chapter01_q02_encounter", companionIDs: [])
        #expect(fresh.enemies.filter(\.isAlive).count == 2)
        #expect(fresh.enemies.dropFirst(2).allSatisfy { $0.hp == 0 })
    }
    @Test("After both parents split, any selected red child and one other take real HP damage", arguments: [0, 1, 2, 3])
    func sidestepAgainstFourChildren(selectedSlot: Int) throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q02_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        let parents = Array(session.enemies.prefix(2))
        for parent in parents { _ = try session.applyPartyDamage(10_000, to: parent.id) }
        let children = session.enemies.filter(\.isAlive)
        try #require(children.count == 4)
        let selectedID = children[selectedSlot].id
        for _ in 0..<2 {
            let before = Dictionary(uniqueKeysWithValues: session.enemies.map { ($0.id, $0.hp) })
            // Native cooldown scheduling calls this API only when the next cast is due.
            let result = try session.useFoolSkill(.sidestepStrike, targetID: selectedID, usesRealtimeCooldown: true)
            #expect(result.targets.count == 2)
            #expect(Set(result.targets.map(\.targetID)).count == 2)
            #expect(result.targets.contains { $0.targetID == selectedID })
            let changed = session.enemies.filter { $0.hp < before[$0.id, default: 0] }
            #expect(changed.count == 2)
            #expect(Set(changed.map(\.id)) == Set(result.targets.map(\.targetID)))
            for target in result.targets {
                let after = try #require(session.enemies.first { $0.id == target.targetID })
                #expect(target.damage > 0)
                #expect(before[target.targetID, default: 0] - after.hp == min(before[target.targetID, default: 0], target.damage))
            }
        }
    }

    @Test("One surviving red child is the sole target and its death completes Q2")
    func sidestepLastChild() throws {
        var session = try MPCChapterOneEncounterSession.start(
            encounterID: "chapter01_q02_encounter", companionIDs: [],
            loadout: .init(normalSkillIDs: [.sidestepStrike], isUltimateUnlocked: false, passiveIDs: [], relicIDs: []))
        for parent in Array(session.enemies.prefix(2)) { _ = try session.applyPartyDamage(10_000, to: parent.id) }
        let children = session.enemies.filter(\.isAlive)
        for child in children.dropLast() { _ = try session.applyPartyDamage(10_000, to: child.id) }
        let last = try #require(children.last)
        _ = try session.applyPartyDamage(last.maxHP - 1, to: last.id)
        let result = try session.useFoolSkill(.sidestepStrike, targetID: last.id, usesRealtimeCooldown: true)
        #expect(result.targets.map(\.targetID) == [last.id])
        #expect(session.outcome == .victory)
    }

}
