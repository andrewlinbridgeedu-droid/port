import Foundation

enum TBCombatEngineError: Error, Equatable {
    case battleAlreadyFinished
    case unknownCombatant(TBCombatantID)
    case unknownSkill(TBSkillID)
    case actorDefeated
    case actorDoesNotOwnSkill
    case skillCoolingDown(Int)
    case insufficientOmen(required: Int, available: Int)
    case invalidTargets
}

struct TBCombatEngine: Sendable {
    private(set) var state: TBBattleState
    private(set) var log: [TBCombatLogEntry] = []

    let skills: [TBSkillID: TBSkillDefinition]
    let playerLoadout: TBLoadout

    private var nextEventID = 1
    private var nextLogID = 1

    init(
        state: TBBattleState,
        skills: [TBSkillID: TBSkillDefinition],
        playerLoadout: TBLoadout
    ) {
        self.state = state
        self.skills = skills
        self.playerLoadout = playerLoadout
    }

    func preview(_ selection: TBActionSelection) throws -> TBActionPreview {
        var simulation = self
        let events = try simulation.makeEvents(for: selection)
        let warnings = simulation.previewWarnings(for: selection, events: events)
        simulation.apply(events)
        simulation.refreshOutcome()
        return TBActionPreview(
            selection: selection,
            events: events,
            projectedState: simulation.state,
            warnings: warnings
        )
    }

    mutating func perform(_ selection: TBActionSelection) throws -> [TBCombatEvent] {
        guard state.outcome == .ongoing else {
            throw TBCombatEngineError.battleAlreadyFinished
        }

        let events = try makeEvents(for: selection)
        appendLog(
            stage: .actionDeclared,
            message: "宣布使用 \(skills[selection.skillID]?.name ?? selection.skillID.rawValue)",
            sourceID: selection.actorID,
            targetID: selection.targetIDs.first
        )

        spendResourcesAndStartCooldown(for: selection.skillID, actorID: selection.actorID)
        apply(events)
        state.actionIndex += 1
        refreshOutcome()
        return events
    }

    mutating func beginRound() {
        guard state.outcome == .ongoing else { return }

        state.round += 1
        state.actionIndex = 0

        for id in state.combatants.keys {
            guard var combatant = state.combatants[id], !combatant.isDefeated else { continue }
            combatant.cooldowns = combatant.cooldowns.mapValues { max(0, $0 - 1) }
            combatant.statuses = combatant.statuses.compactMap { status in
                var updated = status
                updated.remainingRounds -= 1
                return updated.remainingRounds > 0 ? updated : nil
            }
            state.combatants[id] = combatant
        }

        appendLog(
            stage: .roundStart,
            message: "第 \(state.round) 回合开始",
            sourceID: nil,
            targetID: nil
        )
    }

    mutating func performEnemyIntent(enemyID: TBCombatantID) throws {
        guard state.outcome == .ongoing else {
            throw TBCombatEngineError.battleAlreadyFinished
        }
        guard var enemy = state.combatants[enemyID], !enemy.isDefeated else {
            throw TBCombatEngineError.unknownCombatant(enemyID)
        }
        guard let intent = enemy.nextIntent,
              let targetID = intent.targetID,
              var target = state.combatants[targetID],
              !target.isDefeated else {
            throw TBCombatEngineError.invalidTargets
        }

        let evasionID = TBStatusID(rawValue: "veil.announced-evasion")
        if let evasionIndex = target.statuses.firstIndex(where: { $0.id == evasionID }) {
            target.statuses.remove(at: evasionIndex)
            state.combatants[targetID] = target
            appendLog(
                stage: .resultApplied,
                message: "\(target.name) 识破预告并完全闪避了 \(enemy.name) 的行动",
                sourceID: enemyID,
                targetID: targetID
            )
        } else {
            let rawDamage: Int
            switch intent.kind {
            case .attack: rawDamage = intent.magnitude
            case .heavyAttack: rawDamage = intent.magnitude
            default: rawDamage = 0
            }

            if rawDamage > 0 {
                let absorbed = min(target.armor, rawDamage)
                target.armor -= absorbed
                let appliedDamage = rawDamage - absorbed
                target.health = max(0, target.health - appliedDamage)
                state.combatants[targetID] = target
                appendLog(
                    stage: .resultApplied,
                    message: "\(enemy.name) 造成 \(appliedDamage) 点伤害（护甲吸收 \(absorbed)）",
                    sourceID: enemyID,
                    targetID: targetID
                )
            }
        }

        enemy.nextIntent = nextIntent(after: intent, enemyID: enemyID)
        state.combatants[enemyID] = enemy
        state.actionIndex += 1
        refreshOutcome()
    }

    private mutating func makeEvents(for selection: TBActionSelection) throws -> [TBCombatEvent] {
        guard state.outcome == .ongoing else {
            throw TBCombatEngineError.battleAlreadyFinished
        }
        guard let actor = state.combatants[selection.actorID] else {
            throw TBCombatEngineError.unknownCombatant(selection.actorID)
        }
        guard !actor.isDefeated else {
            throw TBCombatEngineError.actorDefeated
        }
        guard let skill = skills[selection.skillID] else {
            throw TBCombatEngineError.unknownSkill(selection.skillID)
        }
        guard playerLoadout.activeSkillIDs.contains(selection.skillID)
                || playerLoadout.coreSkillID == selection.skillID else {
            throw TBCombatEngineError.actorDoesNotOwnSkill
        }

        let remainingCooldown = actor.cooldowns[selection.skillID, default: 0]
        guard remainingCooldown == 0 else {
            throw TBCombatEngineError.skillCoolingDown(remainingCooldown)
        }
        guard actor.omen >= skill.omenCost else {
            throw TBCombatEngineError.insufficientOmen(
                required: skill.omenCost,
                available: actor.omen
            )
        }

        let resolvedTargets = try validateTargets(
            selection.targetIDs,
            for: skill,
            actorID: selection.actorID
        )

        return skill.effects.map { effect in
            defer { nextEventID += 1 }
            return TBCombatEvent(
                id: nextEventID,
                stage: .effectDetermined,
                sourceID: selection.actorID,
                targetIDs: effect.recipient == .source ? [selection.actorID] : resolvedTargets,
                skillID: skill.id,
                payload: payload(for: effect),
                tags: []
            )
        }
    }

    private func validateTargets(
        _ requestedTargetIDs: [TBCombatantID],
        for skill: TBSkillDefinition,
        actorID: TBCombatantID
    ) throws -> [TBCombatantID] {
        switch skill.targetRule {
        case .selfOnly:
            guard requestedTargetIDs.isEmpty || requestedTargetIDs == [actorID] else {
                throw TBCombatEngineError.invalidTargets
            }
            return [actorID]

        case .singleEnemy:
            guard requestedTargetIDs.count == 1,
                  let target = state.combatants[requestedTargetIDs[0]],
                  target.side == .enemy,
                  !target.isDefeated else {
                throw TBCombatEngineError.invalidTargets
            }
            return requestedTargetIDs

        case .allEnemies:
            let targets = state.livingEnemies.map(\.id)
            guard !targets.isEmpty else {
                throw TBCombatEngineError.invalidTargets
            }
            return targets
        }
    }

    private func payload(for effect: TBEffectDefinition) -> TBEventPayload {
        switch effect.kind {
        case .damage: .damage(effect.magnitude)
        case .willDamage: .willDamage(effect.magnitude)
        case .armor: .armor(effect.magnitude)
        case .veil: .veil(effect.magnitude)
        case .omen: .omen(effect.magnitude)
        case .cleanse: .cleanse(effect.magnitude)
        case .revealIntent: .revealIntent(effect.magnitude)
        case .evadeAnnouncedAttack: .evadeAnnouncedAttack
        }
    }

    private mutating func spendResourcesAndStartCooldown(
        for skillID: TBSkillID,
        actorID: TBCombatantID
    ) {
        guard let skill = skills[skillID], var actor = state.combatants[actorID] else { return }
        actor.omen = max(0, actor.omen - skill.omenCost)
        actor.cooldowns[skillID] = skill.cooldown
        state.combatants[actorID] = actor
    }

    private mutating func apply(_ events: [TBCombatEvent]) {
        for event in events {
            for targetID in event.targetIDs {
                guard var target = state.combatants[targetID], !target.isDefeated else { continue }

                switch event.payload {
                case .damage(let rawDamage):
                    let absorbed = min(target.armor, rawDamage)
                    target.armor -= absorbed
                    let applied = max(0, rawDamage - absorbed)
                    target.health = max(0, target.health - applied)
                    appendLog(
                        stage: .resultApplied,
                        message: "\(target.name) 受到 \(applied) 点伤害",
                        sourceID: event.sourceID,
                        targetID: targetID
                    )

                case .willDamage(let amount):
                    target.will = max(0, target.will - amount)
                    appendLog(
                        stage: .resultApplied,
                        message: "\(target.name) 的意志降低 \(amount)",
                        sourceID: event.sourceID,
                        targetID: targetID
                    )

                case .armor(let amount):
                    target.armor += amount

                case .veil(let amount):
                    target.armor += amount
                    target.statuses.append(
                        TBStatusState(
                            id: TBStatusID(rawValue: "veil.protection"),
                            stacks: amount,
                            remainingRounds: 1,
                            sourceID: event.sourceID,
                            isCoreRule: false
                        )
                    )

                case .omen(let amount):
                    target.omen = min(6, target.omen + amount)

                case .cleanse(let count):
                    let removableIndices = target.statuses.indices
                        .filter { !target.statuses[$0].isCoreRule }
                        .prefix(count)
                        .sorted(by: >)
                    for index in removableIndices {
                        target.statuses.remove(at: index)
                    }

                case .revealIntent:
                    if let intent = target.nextIntent {
                        target.nextIntent = TBEnemyIntent(
                            kind: intent.kind,
                            sourceID: intent.sourceID,
                            targetID: intent.targetID,
                            magnitude: intent.magnitude,
                            remainingActions: intent.remainingActions,
                            isFatal: intent.isFatal,
                            isRevealed: true
                        )
                    }

                case .evadeAnnouncedAttack:
                    target.statuses.append(
                        TBStatusState(
                            id: TBStatusID(rawValue: "veil.announced-evasion"),
                            stacks: 1,
                            remainingRounds: 1,
                            sourceID: event.sourceID,
                            isCoreRule: false
                        )
                    )
                }

                state.combatants[targetID] = target
            }
        }
    }

    private func previewWarnings(
        for selection: TBActionSelection,
        events: [TBCombatEvent]
    ) -> [String] {
        guard let actor = state.combatants[selection.actorID],
              let skill = skills[selection.skillID] else { return [] }

        var warnings: [String] = []
        if skill.slot == .core && actor.omen < 5 {
            warnings.append("当前预兆较低，提前兑现可能失去后续应对空间")
        }

        let fatalIntentExists = state.livingEnemies.contains { enemy in
            enemy.nextIntent?.isFatal == true
        }
        let protectsPlayer = events.contains { event in
            switch event.payload {
            case .armor, .veil, .evadeAnnouncedAttack: true
            default: false
            }
        }
        if fatalIntentExists && !protectsPlayer {
            warnings.append("时间轴存在致命行动，本次选择未提供直接防护")
        }
        return warnings
    }

    private mutating func refreshOutcome() {
        if state.player?.isDefeated == true {
            state.outcome = .defeat
        } else if state.livingEnemies.isEmpty {
            state.outcome = .victory
        }
    }

    private func nextIntent(
        after intent: TBEnemyIntent,
        enemyID: TBCombatantID
    ) -> TBEnemyIntent {
        let playerID = state.player?.id
        switch intent.kind {
        case .heavyAttack:
            return TBEnemyIntent(
                kind: .attack,
                sourceID: enemyID,
                targetID: playerID,
                magnitude: max(6, intent.magnitude / 2),
                remainingActions: 1,
                isFatal: false,
                isRevealed: true
            )
        default:
            return TBEnemyIntent(
                kind: .heavyAttack,
                sourceID: enemyID,
                targetID: playerID,
                magnitude: max(18, intent.magnitude * 2),
                remainingActions: 1,
                isFatal: true,
                isRevealed: true
            )
        }
    }

    private mutating func appendLog(
        stage: TBPipelineStage,
        message: String,
        sourceID: TBCombatantID?,
        targetID: TBCombatantID?
    ) {
        log.append(
            TBCombatLogEntry(
                id: nextLogID,
                round: state.round,
                stage: stage,
                message: message,
                sourceID: sourceID,
                targetID: targetID
            )
        )
        nextLogID += 1
    }
}
