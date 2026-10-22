import Foundation
import MistportCombatCore

/// Modelled human play time (user decision 2026-09-29: timing comes from a simulator,
/// not from device sessions). It is a model, not a measurement: every non-battle second
/// is built from the constants below, the authored text actually on screen, the street
/// view's walking speed and map positions, and the number of taps in each flow. Battle
/// seconds come from the shipping combat core driven at human action speeds.
struct HumanPace: Codable, Sendable {
    let name: String
    /// Chinese characters read per minute (dialogue, evidence, UI text).
    let readingCPM: Double
    /// One tap, including finding the button on a phone screen.
    let tapSeconds: Double
    /// One decision: which answer, which card set, which recipe.
    let decisionSeconds: Double
    /// Added after every combat action lock. The App casts the skill sequence itself (every
    /// battle runs the automatic loop; the manual card mode was removed 2026-10-15), so a
    /// person's reaction time does not slow casting: 0 for every pace. People differ in the manual parts.
    let battleActionDelay: Double
    /// Casual players do not always hit the priority target first.
    let priorityCore: Bool
    /// Chance of a wrong first pick at a three-way question.
    let wrongAnswerChance: Double
    /// Finding a person or a place on the street map before tapping it.
    let searchSeconds: Double
    /// Replays per missing challenge star (2026-10-22 assumption): every star has a route that wins
    /// at least 10 of 12 bot runs (MISSION_CHALLENGES_20261018.md), but a person has to find it.
    let starTries: Double
    /// Story tries per mission counted as play time (2026-10-22 assumption). The bot searches every card,
    /// relic and medal plan in turn (Q18 over a thousand); a person reads the defeat hint after a few
    /// losses. Tries beyond this are reported apart (`uncountedRetryMinutes`), not added to the day.
    let storyTriesCounted: Int

    /// Reading speeds from typical Chinese reading rates (careful 250–300, game dialogue
    /// skimmed 400–600 characters a minute); taps and decisions from the keystroke-level
    /// model (a mental step about 1.35 s, a touch with pointing about 0.8–1.5 s). In battle
    /// the casual pace does not pick the priority target first.
    static let all = [
        HumanPace(name: "quick", readingCPM: 600, tapSeconds: 0.8, decisionSeconds: 2.0, battleActionDelay: 0,
                  priorityCore: true, wrongAnswerChance: 0.1, searchSeconds: 6, starTries: 1.2, storyTriesCounted: 4),
        HumanPace(name: "typical", readingCPM: 400, tapSeconds: 1.1, decisionSeconds: 3.5, battleActionDelay: 0,
                  priorityCore: true, wrongAnswerChance: 0.2, searchSeconds: 12, starTries: 1.5, storyTriesCounted: 5),
        HumanPace(name: "casual", readingCPM: 260, tapSeconds: 1.5, decisionSeconds: 5.0, battleActionDelay: 0,
                  priorityCore: false, wrongAnswerChance: 0.3, searchSeconds: 20, starTries: 2.0, storyTriesCounted: 6)
    ]
    var profile: Profile { Profile(name: name, actionDelay: battleActionDelay, priorityCore: priorityCore) }
}

/// Device-side waits: scene changes, battle loading, result screens. Assumptions to
/// replace with device logs when available.
enum DeviceWaits {
    static let battleEnter = 3.0
    static let battleExit = 2.0
    static let screen = 0.8
    static let streetOpen = 3.0
    /// Street view hero speed: 3.2 world units a second (viewer.js), 2048/80 map pixels a unit.
    static let streetPixelsPerSecond = 3.2 * 2048 / 80
    /// Streets are not straight lines.
    static let streetDetour = 1.3
    /// Walking between places on the bounty investigation and district maps.
    static let districtWalk = 15.0
    static let investigationWalk = 10.0
    /// A computer turn in the card game, read from the table.
    static let computerCardTurn = 1.2
}

/// One timed step, for the report.
struct TimedStep: Codable {
    let label: String
    let seconds: Double
}

struct ActivityTiming: Codable {
    let activity: String
    let scope: String
    /// Everything but combat, from the step model.
    let steps: [TimedStep]
    var nonBattleSeconds: Double { steps.reduce(0) { $0 + $1.seconds } }
    /// Combat seconds per activity (median of the sampled battles, all attempts included).
    var battleSeconds: Double
    var battles: Int
    var totalSeconds: Double { nonBattleSeconds + battleSeconds }
    enum CodingKeys: String, CodingKey { case activity, scope, steps, battleSeconds, battles, nonBattleSeconds, totalSeconds }
    init(activity: String, scope: String, steps: [TimedStep], battleSeconds: Double = 0, battles: Int = 0) {
        self.activity = activity; self.scope = scope; self.steps = steps; self.battleSeconds = battleSeconds; self.battles = battles
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(activity, forKey: .activity); try c.encode(scope, forKey: .scope); try c.encode(steps, forKey: .steps)
        try c.encode(battleSeconds, forKey: .battleSeconds); try c.encode(battles, forKey: .battles)
        try c.encode(nonBattleSeconds, forKey: .nonBattleSeconds); try c.encode(totalSeconds, forKey: .totalSeconds)
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        activity = try c.decode(String.self, forKey: .activity); scope = try c.decode(String.self, forKey: .scope)
        steps = try c.decode([TimedStep].self, forKey: .steps); battleSeconds = try c.decode(Double.self, forKey: .battleSeconds)
        battles = try c.decode(Int.self, forKey: .battles)
    }
}

/// Where the 23 neighbours stand in the street view, as viewer.js places them: the twelve
/// of navigation.json at their fixed positions, the others at `phase` along their first
/// route in harbor-pedestrians.json. The player enters at navigation node `spawn`.
enum StreetMap {
    struct Citizen: Decodable { let id: String; let routes: [[[Double]]]; let phase: Double? }
    struct Pedestrians: Decodable { let citizens: [Citizen] }
    struct Npc: Decodable { let model: String; let position: [Double] }
    struct Navigation: Decodable { let nodes: [[Double]]; let spawn: Int; let npcs: [Npc] }
    static var folder: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("mistport-ios/Mistport/WisteriaMap")
    }
    static let navigation: Navigation? = (try? Data(contentsOf: folder.appendingPathComponent("navigation.json")))
        .flatMap { try? JSONDecoder().decode(Navigation.self, from: $0) }
    static let spawn: (Double, Double) = navigation.map { n in (n.nodes[n.spawn][0], n.nodes[n.spawn][1]) } ?? (322, 1067)
    static let positions: [String: (Double, Double)] = {
        var result: [String: (Double, Double)] = [:]
        for npc in navigation?.npcs ?? [] where npc.position.count == 2 { result[npc.model] = (npc.position[0], npc.position[1]) }
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("harbor-pedestrians.json")),
              let file = try? JSONDecoder().decode(Pedestrians.self, from: data) else { return result }
        for citizen in file.citizens where result[citizen.id] == nil {
            guard let route = citizen.routes.first, !route.isEmpty else { continue }
            let point = route[min(route.count - 1, Int((citizen.phase ?? 0) * Double(route.count)))]
            if point.count == 2 { result[citizen.id] = (point[0], point[1]) }
        }
        return result
    }()
    /// From the street entrance to a neighbour.
    static func fromSpawnSeconds(_ id: String) -> Double {
        guard let p = positions[id] else { return averageWalkSeconds }
        return hypot(p.0 - spawn.0, p.1 - spawn.1) * DeviceWaits.streetDetour / DeviceWaits.streetPixelsPerSecond
    }
    static func walkSeconds(_ a: String, _ b: String) -> Double {
        guard let p = positions[a], let q = positions[b] else { return averageWalkSeconds }
        return hypot(p.0 - q.0, p.1 - q.1) * DeviceWaits.streetDetour / DeviceWaits.streetPixelsPerSecond
    }
    /// From one neighbour to another, averaged over every pair.
    static let averageWalkSeconds: Double = {
        let ids = Array(positions.keys)
        guard ids.count > 1 else { return 15 }
        var total = 0.0, pairs = 0.0
        for a in ids { for b in ids where a != b {
            let p = positions[a]!, q = positions[b]!
            total += hypot(p.0 - q.0, p.1 - q.1) * DeviceWaits.streetDetour / DeviceWaits.streetPixelsPerSecond; pairs += 1
        } }
        return total / pairs
    }()
}

/// The story pages around each mission (the 2026-10-18 rewrite): each cue's `message` and rules
/// `hint` in Mistport/ChapterOneOnboarding.swift, read from the App source. The bubble shows 54
/// characters a page, one tap a page; its typewriter (12 ms a character) is faster than reading.
enum StoryPages {
    static var file: URL { StreetMap.folder.deletingLastPathComponent().appendingPathComponent("ChapterOneOnboarding.swift") }
    /// Cues without a mission number in their name.
    static let early = ["opening": 1, "cityMission": 1, "mapEntry": 1, "firstBattle": 1, "rainFirstAftermath": 1,
                        "fogGhostPrelude": 2, "rainInterlude": 2, "houndPrelude": 3, "secondBattle": 3,
                        "q5Delivery": 5, "q5PaperDoubleIntervention": 5]
    static let pageCharacters = 54
    static let byMission: [Int: (characters: Int, pages: Int)] = {
        guard let source = try? String(contentsOf: file, encoding: .utf8),
              let start = source.range(of: "var message: String {"), let end = source.range(of: "var kicker: String {"),
              let literal = try? NSRegularExpression(pattern: #"case \.(\w+):\s*"((?:[^"\\]|\\.)*)""#) else { return [:] }
        let text = String(source[start.lowerBound..<end.lowerBound])
        var result: [Int: (characters: Int, pages: Int)] = [:]
        for match in literal.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let name = Range(match.range(at: 1), in: text).map({ String(text[$0]) }),
                  let body = Range(match.range(at: 2), in: text).map({ String(text[$0]) }) else { continue }
            let mission = early[name] ?? name.firstMatch(of: /^q(\d+)/).flatMap { Int($0.1) }
            guard let mission else { continue }
            let paragraphs = body.components(separatedBy: "\\n").map { $0.replacingOccurrences(of: "\\", with: "") }
            let characters = paragraphs.reduce(0) { $0 + $1.count }
            guard characters > 0 else { continue }
            let pages = max(1, Int((Double(characters) / Double(pageCharacters)).rounded(.up)))
            result[mission, default: (0, 0)].characters += characters
            result[mission, default: (0, 0)].pages += pages
        }
        return result
    }()
}

/// The step model for one pace. Text lengths are counted from the authored content.
struct HumanTimingModel {
    let pace: HumanPace

    func read(_ chars: Int) -> Double { Double(chars) / pace.readingCPM * 60 }
    func read(_ text: String) -> Double { read(text.count) }
    func taps(_ n: Double) -> Double { n * pace.tapSeconds }
    func decide(_ n: Double = 1) -> Double { n * pace.decisionSeconds }
    /// A three-way question: read it, decide, tap; a wrong pick costs its explanation and another try.
    func question(_ text: Int, explanation: Int = 14) -> Double {
        read(text) + decide() + taps(1) + pace.wrongAnswerChance * (read(explanation) + decide(0.5) + taps(1))
    }
    func step(_ label: String, _ seconds: Double) -> TimedStep { .init(label: label, seconds: (seconds * 10).rounded() / 10) }
    /// Loadout check, entering and leaving the battle, reading the result.
    func battleFrame(result: Int = 30, planning: Double = 0.5) -> [TimedStep] {
        [step("战前配置", decide(planning) + taps(2)), step("进出战斗（设备）", DeviceWaits.battleEnter + DeviceWaits.battleExit),
         step("读结算", read(result) + taps(1))]
    }

    /// The daily paper on the day's first opening: about 300 characters across its rows.
    var newspaper: [TimedStep] { [step("读日刊（每天一次）", read(300) + taps(2) + DeviceWaits.screen)] }

    // MARK: Story, tower, bounty

    static let missions = (1...30).compactMap { MPCChapterOneCatalog.mission(forOldClockMissionNumber: $0) }
    /// First visit of a mission: getting there and reading its story; retries only pay `battleFrame`.
    func storyFirstVisit(_ mission: Int) -> [TimedStep] {
        guard let m = Self.missions.first(where: { $0.number == mission }) else { return [] }
        var steps = [step("城市→任务板→选关", taps(3) + DeviceWaits.screen * 2), step("街区地图走到关卡", DeviceWaits.districtWalk + taps(2)),
                     step("读剧情", read(m.name + m.location + m.storyText) + taps(1)), step("首通奖励", read(40) + taps(1))]
        if let pages = StoryPages.byMission[mission] {
            steps.append(step("剧情页（\(pages.pages) 页）", read(pages.characters) + taps(Double(pages.pages))))
        }
        if !m.permanentSkillIDs.isEmpty { steps.append(step("新技能说明", read(80) + taps(2) + decide(1))) }
        return steps
    }
    var storyAttempt: [TimedStep] { battleFrame(result: 40, planning: 1) }
    var storyRetry: [TimedStep] { [step("换打法再来", decide(1) + taps(1))] + battleFrame(result: 20, planning: 0.5) }

    /// Challenge stars expected on a first clear, Q1–Q30 (MISSION_CHALLENGES_20261018.md, model table;
    /// stars the export had no data for count as missing).
    static let firstClearStars: [Double] = [3.00, 2.50, 3.00, 2.50, 1.50, 1.33, 1.00, 1.54, 1.21, 1.74,
                                            1.33, 1.30, 1.43, 1.41, 1.29, 1.48, 1.73, 1.54, 1.25, 0.68,
                                            1.58, 1.43, 1.70, 1.47, 1.44, 1.33, 1.38, 1.48, 1.06, 1.51]
    /// One replay for a missing star, battle excluded: the star list, the three conditions, arranging
    /// the cards for the one wanted, the battle frame and the result's "上次 → 本场" line.
    var starReplay: [TimedStep] {
        [step("首页星星→旧关挑战→选关", taps(3) + DeviceWaits.screen * 2), step("读三条条件", read(45)),
         step("照条件排牌", decide(1.5) + taps(4))] + battleFrame(result: 60, planning: 0)
    }

    /// 雨后第一天 (MPCCityTour), once after Q2: each stop's scene, its small task, the lesson and the
    /// line after, then the door into the real place and back.
    var cityTour: [TimedStep] {
        [step("首页提示条→认城", taps(1) + DeviceWaits.screen)] + MPCCityTour.stops.map { stop in
            let task: Double
            switch stop.task {
            case let .question(prompt, choices, _, nudge):
                task = question(prompt.count + choices.reduce(0) { $0 + $1.count }, explanation: nudge.count)
            case let .action(label): task = read(label) + taps(1)
            }
            let scene = stop.scene.replacingOccurrences(of: "\n", with: "")
            let pages = (Double(scene.count) / Double(StoryPages.pageCharacters)).rounded(.up)
            return step("\(stop.title)：剧情、小事、说明、去看看", read(scene) + taps(pages) + task
                        + read(stop.lesson + stop.done) + taps(3) + DeviceWaits.screen * 2)
        }
    }

    /// 今日小目标 in the paper, and going back to claim once all are done.
    var dailyGoalsRead: TimedStep { step("读今日小目标", read(70)) }
    var dailyGoalsClaim: TimedStep { step("回日刊领小目标奖励", taps(3) + DeviceWaits.screen + read(24)) }

    /// One floor inside a climbing session (the walk to the church is shared by the day's floors).
    var towerFloor: [TimedStep] {
        [step("选层", taps(1)), step("塔装备：换上新掉落（每层一半机会）", 0.5 * (taps(3) + decide(0.5)))] + battleFrame(result: 30)
    }
    var churchVisit: [TimedStep] { [step("城市→教会→深井", taps(2) + DeviceWaits.screen * 2)] }

    /// Investigation from accepting the case to presenting the warrant; the fight and claim are added per attempt.
    func bountyInvestigation(_ caseID: String) -> [TimedStep] {
        guard let b = MPCChurchBountyCatalog.all.first(where: { $0.id == caseID }) else { return [] }
        var steps = [step("教会接案、读案情", taps(3) + DeviceWaits.screen + read(b.title + b.visualIdentity))]
        for node in b.nodes {
            steps.append(step("前往\(node.location)并对话", DeviceWaits.investigationWalk + taps(2) + read(node.speaker + node.dialogue + node.evidence)))
            if let c = MPCChurchBountyCatalog.challenge(caseID: caseID, nodeID: node.id) {
                steps.append(step("判断：\(node.id)", question(c.question.count + c.choices.reduce(0) { $0 + $1.text.count })))
            }
        }
        steps.append(step("现场特征与出示拘票", taps(4) + decide(1)))
        steps.append(step("结案领奖", read(b.closure) + taps(2)))
        return steps
    }

    // MARK: Repeatable work

    var postal: [TimedStep] {
        [step("打开邮务", taps(2) + DeviceWaits.screen)] + (0..<3).map { i in step("核对第\(i + 1)栏（三选一）", read(14) + decide(0.5) + taps(1)) }
            + [step("结算", read(12) + taps(1))]
    }
    func maintenance(_ kind: MPCChurchMaintenanceKind, floor: Int) -> [TimedStep] {
        let objectives = MPCChurchMaintenanceCatalog.objectives(kind: kind, floor: floor)
        return [step("教会接单", taps(3) + DeviceWaits.screen)]
            + objectives.map { o in step("核对：\(o.title)", read(o.title + o.evidence) + question(o.choices.reduce(0) { $0 + $1.text.count }, explanation: 14)) }
            + (1...3).flatMap { _ in battleFrame(result: 20, planning: 0.3) }
            + [step("领报酬", read(20) + taps(1))]
    }

    // MARK: Workshop

    var craft: [TimedStep] { [step("选配方", taps(1) + read(20) + decide(0.3)), step("制作", taps(1) + 1)] }
    var sale: [TimedStep] { [step("选货和数量", taps(2) + decide(0.3)), step("确认卖出", taps(1) + 1)] }
    var workshopVisit: [TimedStep] { [step("城市→工坊", taps(2) + DeviceWaits.screen)] }

    // MARK: Neighbours, events, remnants

    func errand(_ errand: MPCNeighborErrand, asker: String) -> [TimedStep] {
        var steps = [step("在街上找到并走到\(asker)", pace.searchSeconds + StreetMap.averageWalkSeconds + taps(1)),
                     step("读请求", read(errand.request))]
        let ways = MPCNeighborCatalog.ways(errand.id)
        if !ways.isEmpty { steps.append(chooseWay(ways)) }
        switch errand.kind {
        case .deliver: steps.append(step("交货", taps(2)))
        case .find: steps.append(step("找东西（三选一）", question((errand.question ?? "").count + errand.choices.reduce(0) { $0 + $1.text.count })))
        case .message:
            let to = errand.recipientID ?? ""
            steps.append(step("走到收话人", pace.searchSeconds + StreetMap.walkSeconds(asker, to) + taps(1)))
            steps.append(step("读回话", read(errand.reply ?? "")))
        case .pest: steps.append(step("开战", taps(1))); steps += battleFrame(result: 20, planning: 0.3)
        }
        steps.append(step("读感谢", read(errand.thanks + (ways.first?.reply ?? "")) + taps(1)))
        return steps
    }
    /// Two ways to do an errand (2026-10-17): read both buttons, pick one.
    func chooseWay(_ ways: [MPCErrandWay]) -> TimedStep {
        step("选办法（\(ways.count) 种）", read(ways.reduce(0) { $0 + $1.label.count }) + decide() + taps(1))
    }

    /// A street task (MPCStreetTask: urgent, joint, commission) from its poster to the thanks. A person is
    /// walked to on the street; a place is tapped on the home map. Fight seconds are added by the caller.
    func streetTask(_ task: MPCStreetTask) -> [TimedStep] {
        let ways = MPCStreetTaskCatalog.ways(task.id)
        var steps = [step("找到发布处、读请求", pace.searchSeconds + taps(2) + DeviceWaits.screen + read(task.title + task.request))]
        if !ways.isEmpty { steps.append(chooseWay(ways)) }
        for s in task.steps {
            var seconds = (s.isPerson ? pace.searchSeconds + StreetMap.averageWalkSeconds + taps(1) : taps(2) + DeviceWaits.screen * 2)
                + read(s.goal) + read(s.line) + taps(1)
            switch s.action {
            case .talk: break
            case .handOver: seconds += taps(2)
            case .answer: seconds += question((s.question ?? "").count + s.choices.reduce(0) { $0 + $1.text.count })
            case .battle: seconds += battleFrame(result: 20, planning: 0.3).reduce(0) { $0 + $1.seconds }
            }
            steps.append(step(s.goal, seconds))
        }
        steps.append(step("读感谢", read(task.thanks + (ways.first?.reply ?? "")) + taps(1)))
        return steps
    }
    /// A story unlocked by the errand, read once.
    func story(_ text: String) -> TimedStep { step("读小故事", read(text) + taps(1)) }
    var streetOpen: [TimedStep] { [step("打开街道（每天一次）", taps(1) + DeviceWaits.streetOpen)] }

    var eventDelivery: [TimedStep] { [step("事件板选物资", taps(1) + read(20)), step("选数量并确认", taps(2) + decide(0.3))] }
    func eventBriefing(_ event: MPCCityEvent) -> TimedStep { step("读事件简报（每场一次）", read(event.briefing + event.partner) + taps(1)) }
    var eventBattle: [TimedStep] { [step("事件板开战", taps(2) + DeviceWaits.screen)] + battleFrame(result: 30) }

    func remnant(_ r: MPCRemnantCase, lead: Int) -> [TimedStep] {
        let l = r.leads[lead]
        return [step("接案", taps(2) + read(r.title + r.area)), step("读线索", read(l.evidence)),
                step("判断（三选一）", question(l.question.count + l.choices.reduce(0) { $0 + $1.text.count }))]
            + battleFrame(result: 30) + [step("领报酬", read(20) + taps(1))]
    }

    // MARK: Tavern

    /// Five-card draw: wager, one discard decision, showdown.
    var poker: [TimedStep] {
        [step("入座选注", taps(2) + decide(0.5) + DeviceWaits.screen), step("发牌", 1.5),
         step("选弃牌并换牌", decide(1.5) + taps(3)), step("亮牌结算", 2 + read(20) + taps(1))]
    }
    /// Two-deck landlord game, played with the library's own rules and its computer players.
    /// The person plays with the same heuristic; only the number of their turns is used.
    func douDizhu(games: Int = 20) -> (steps: [TimedStep], playerTurns: Double, computerTurns: Double) {
        var playerTurns = 0.0, computerTurns = 0.0, cardsPlayed = 0.0, played = 0.0
        var seed: UInt64 = 20260929
        func next() -> UInt64 { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return seed >> 33 }
        for g in 0..<games {
            var deck = MPCDouRules.standardDeck
            for i in stride(from: deck.count - 1, to: 0, by: -1) { deck.swapAt(i, Int(next() % UInt64(i + 1))) }
            guard var game = try? MPCDouRules.deal(caseID: "b08", wager: 10, gameID: "timing-\(g)", shuffledDeck: deck, startingPlayer: g % 3) else { continue }
            var guardSteps = 0
            while game.phase != .finished && game.phase != .redeal && guardSteps < 400 {
                guardSteps += 1
                if game.currentPlayer != 0 {
                    let before = game.movesMade.reduce(0, +)
                    try? game.runComputerTurns()
                    computerTurns += Double(max(1, game.movesMade.reduce(0, +) - before))
                    continue
                }
                playerTurns += 1
                if game.phase == .bidding { try? game.bid(game.highestBid < 3 && g % 2 == 0 ? game.highestBid + 1 : 0); continue }
                let target = MPCDouRules.classify(game.lastPlay)
                let moves = game.lastPlayer == 0 || game.lastPlay.isEmpty
                    ? MPCDouRules.legalMoves(game.hands[0], beating: nil) : MPCDouRules.legalMoves(game.hands[0], beating: target)
                if let move = moves.sorted(by: { $0.count == $1.count ? MPCDouRules.classify($0)!.primary < MPCDouRules.classify($1)!.primary : $0.count > $1.count }).first,
                   (try? game.play(cardIDs: Set(move.map(\.id)))) != nil {
                    cardsPlayed += Double(move.count)
                } else { try? game.pass() }
            }
            played += 1
        }
        let perGame = max(1, played)
        let turns = playerTurns / perGame, computer = computerTurns / perGame, cards = cardsPlayed / perGame
        return ([step("入座选注", taps(2) + decide(0.5) + DeviceWaits.screen),
                 step("我方出牌（\(Int(turns.rounded())) 手，每手决定并点选牌）", turns * (decide(0.8) + taps(1)) + cards * taps(0.5)),
                 step("看电脑出牌（\(Int(computer.rounded())) 手）", computer * DeviceWaits.computerCardTurn),
                 step("结算", read(20) + taps(1))], turns, computer)
    }
}
