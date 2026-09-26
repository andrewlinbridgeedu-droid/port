import Foundation
import Observation

@Observable
@MainActor
final class TurnBasedBattleViewModel {
    enum PresentationPhase: Equatable {
        case choosing
        case previewing
        case resolving
        case finished(TBCombatOutcome)
    }

    private(set) var battle: TBBattleState
    private(set) var phase: PresentationPhase = .choosing
    private(set) var preview: TBActionPreview?
    private(set) var message = "先看清敌人的下一行动，再选择正确回应。"
    private(set) var errorMessage: String?

    var selectedSkillID: TBSkillID?
    var selectedEnemyID: TBCombatantID?

    private var engine: TBCombatEngine

    init() {
        let state = Self.makeRainyAwakeningState()
        engine = TBCombatEngine(
            state: state,
            skills: OldClockCombatCatalog.skillLookup,
            playerLoadout: OldClockCombatCatalog.firstLoadout
        )
        battle = state
        selectedEnemyID = state.livingEnemies.first?.id
    }

    var player: TBCombatantState {
        guard let player = battle.player else {
            preconditionFailure("雨夜醒钟必须包含玩家单位")
        }
        return player
    }

    var enemies: [TBCombatantState] { battle.livingEnemies }

    var skills: [TBSkillDefinition] {
        let active = OldClockCombatCatalog.firstLoadout.activeSkillIDs.compactMap {
            OldClockCombatCatalog.skillLookup[$0]
        }
        let core = OldClockCombatCatalog.skillLookup[OldClockCombatCatalog.firstLoadout.coreSkillID]
        return active + [core].compactMap { $0 }
    }

    var combatLog: [TBCombatLogEntry] { engine.log }

    func cooldown(for skill: TBSkillDefinition) -> Int {
        player.cooldowns[skill.id, default: 0]
    }

    func canSelect(_ skill: TBSkillDefinition) -> Bool {
        phase != .resolving
            && battle.outcome == .ongoing
            && cooldown(for: skill) == 0
            && player.omen >= skill.omenCost
    }

    func selectEnemy(_ enemyID: TBCombatantID) {
        selectedEnemyID = enemyID
        if selectedSkillID != nil {
            updatePreview()
        }
    }

    func selectSkill(_ skillID: TBSkillID) {
        guard let skill = OldClockCombatCatalog.skillLookup[skillID], canSelect(skill) else { return }
        selectedSkillID = skillID
        updatePreview()
    }

    func cancelPreview() {
        preview = nil
        selectedSkillID = nil
        phase = .choosing
        errorMessage = nil
    }

    func confirmSelection() {
        guard let preview else { return }

        phase = .resolving
        errorMessage = nil

        do {
            _ = try engine.perform(preview.selection)
            battle = engine.state
            message = resultMessage(from: preview)
            self.preview = nil
            selectedSkillID = nil

            if battle.outcome == .ongoing {
                try resolveEnemyActions()
            }

            if battle.outcome == .ongoing {
                engine.beginRound()
                battle = engine.state
                phase = .choosing
            } else {
                phase = .finished(battle.outcome)
            }
        } catch {
            errorMessage = "行动无法结算：\(String(describing: error))"
            phase = .choosing
        }
    }

    func restart() {
        let state = Self.makeRainyAwakeningState()
        engine = TBCombatEngine(
            state: state,
            skills: OldClockCombatCatalog.skillLookup,
            playerLoadout: OldClockCombatCatalog.firstLoadout
        )
        battle = state
        phase = .choosing
        preview = nil
        selectedSkillID = nil
        selectedEnemyID = state.livingEnemies.first?.id
        message = "先看清敌人的下一行动，再选择正确回应。"
        errorMessage = nil
    }

    private func updatePreview() {
        guard let skillID = selectedSkillID,
              let skill = OldClockCombatCatalog.skillLookup[skillID] else { return }

        let targets: [TBCombatantID]
        switch skill.targetRule {
        case .selfOnly: targets = [player.id]
        case .singleEnemy:
            guard let selectedEnemyID else { return }
            targets = [selectedEnemyID]
        case .allEnemies: targets = enemies.map(\.id)
        }

        do {
            preview = try engine.preview(
                TBActionSelection(
                    actorID: player.id,
                    skillID: skillID,
                    targetIDs: targets
                )
            )
            phase = .previewing
            errorMessage = nil
        } catch {
            preview = nil
            phase = .choosing
            errorMessage = "无法预览：\(String(describing: error))"
        }
    }

    private func resolveEnemyActions() throws {
        let actingEnemyIDs = battle.livingEnemies.map(\.id)
        for enemyID in actingEnemyIDs where engine.state.outcome == .ongoing {
            try engine.performEnemyIntent(enemyID: enemyID)
        }
        battle = engine.state
    }

    private func resultMessage(from preview: TBActionPreview) -> String {
        guard let skill = OldClockCombatCatalog.skillLookup[preview.selection.skillID] else {
            return "行动已经结算。"
        }
        return "\(skill.name) 已结算。查看新的敌方意图，再决定下一步。"
    }

    private static func makeRainyAwakeningState() -> TBBattleState {
        let playerID = TBCombatantID(rawValue: "player.veil-observer")
        let clockmakerID = TBCombatantID(rawValue: "enemy.hollow-clockmaker")
        let houndID = TBCombatantID(rawValue: "enemy.demon-hound")

        let player = TBCombatantState(
            id: playerID,
            side: .player,
            name: "帷幕观测者",
            maxHealth: 100,
            health: 100,
            armor: 0,
            maxWill: 0,
            will: 0,
            omen: 0,
            statuses: [],
            cooldowns: [:],
            nextIntent: nil
        )

        let clockmaker = TBCombatantState(
            id: clockmakerID,
            side: .enemy,
            name: "空壳守卫",
            maxHealth: 64,
            health: 64,
            armor: 8,
            maxWill: 40,
            will: 40,
            omen: 0,
            statuses: [],
            cooldowns: [:],
            nextIntent: TBEnemyIntent(
                kind: .attack,
                sourceID: clockmakerID,
                targetID: playerID,
                magnitude: 9,
                remainingActions: 1,
                isFatal: false,
                isRevealed: true
            )
        )

        let hound = TBCombatantState(
            id: houndID,
            side: .enemy,
            name: "恶魔犬",
            maxHealth: 52,
            health: 52,
            armor: 0,
            maxWill: 30,
            will: 30,
            omen: 0,
            statuses: [],
            cooldowns: [:],
            nextIntent: TBEnemyIntent(
                kind: .heavyAttack,
                sourceID: houndID,
                targetID: playerID,
                magnitude: 24,
                remainingActions: 1,
                isFatal: true,
                isRevealed: true
            )
        )

        return TBBattleState(
            round: 1,
            actionIndex: 0,
            combatants: [
                playerID: player,
                clockmakerID: clockmaker,
                houndID: hound
            ],
            timeline: [playerID, houndID, clockmakerID],
            outcome: .ongoing
        )
    }
}
