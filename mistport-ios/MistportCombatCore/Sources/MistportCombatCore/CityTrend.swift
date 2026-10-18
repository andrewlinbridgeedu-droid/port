import Foundation

/// The city's trend (2026-10-17, CITY_TREND_TASKS_PROPOSAL_20261017.md): whom Mistport trusts to
/// vouch for a person. Every errand can be finished in two ways, each a receipt for one of three
/// sides; the sum over all players settles each city event's stake and, after day 28, the world
/// chapter two opens in. While no shared server is connected the other players are simulated
/// (MPCCityTrendSimulation). The trend pays nothing, gates no story mission and grants no power.
public enum MPCCityFaction: String, Codable, CaseIterable, Sendable {
    /// People vouching for people: neighbours, the clinic, the dock crews.
    case neighbours
    /// Seals vouching for people: the registry, the police, the harbour office, the church.
    case offices
    /// Money vouching for people: contracts, the works committee, the merchants, the bank.
    case compacts

    public var name: String {
        switch self {
        case .neighbours: "街坊"
        case .offices: "公署"
        case .compacts: "商约"
        }
    }
    /// How this side vouches for a person.
    public var motto: String {
        switch self {
        case .neighbours: "人保人"
        case .offices: "印保人"
        case .compacts: "钱保人"
        }
    }
}

/// Chapter one's four stakes, one per city event (MPCCityEventCatalog).
public enum MPCCityTrendStage: Int, Codable, CaseIterable, Sendable {
    case casualties = 1, pump, blockade, workshop

    public var days: ClosedRange<Int> {
        switch self {
        case .casualties: 4...10
        case .pump: 11...17
        case .blockade: 18...24
        case .workshop: 25...28
        }
    }
    public var eventID: String {
        switch self {
        case .casualties: "casualty-wave"
        case .pump: "pump-station"
        case .blockade: "harbor-blockade"
        case .workshop: "workshop-foundation"
        }
    }
    public var title: String {
        switch self {
        case .casualties: "伤患潮"
        case .pump: "泵站修复"
        case .blockade: "港口封锁"
        case .workshop: "蒸汽工坊奠基"
        }
    }
    /// What the city is deciding in this stage.
    public var stake: String {
        switch self {
        case .casualties: "伤员的床位归谁管"
        case .pump: "泵站由谁来修"
        case .blockade: "封锁的港口怎么放行"
        case .workshop: "新工坊归谁"
        }
    }
    /// What it means for the city when a side takes this stage.
    public func outcome(_ side: MPCCityFaction) -> String {
        switch (self, side) {
        case (.casualties, .neighbours): "诊所的互助床位留下来，街坊轮流守夜，止痛膏照旧由诊所配"
        case (.casualties, .offices): "伤员按名册分到教会施济所，床位有序，名字都进了登记册"
        case (.casualties, .compacts): "商行包下药品和床位，来得快，但要先付押金"
        case (.pump, .neighbours): "街坊义修泵站，慢两天，水费不涨"
        case (.pump, .offices): "市政拨款修泵，表格齐全，旧街先通水"
        case (.pump, .compacts): "工业委员会包工，货场先通水，水价跟着涨"
        case (.blockade, .neighbours): "码头的人夜里接驳，货和人都过得去，警察厅盯上了码头"
        case (.blockade, .offices): "港务处逐船查验后放行，慢，但没有一个人被偷运出去"
        case (.blockade, .compacts): "商人包船出港，航路先开，船票贵了一倍"
        case (.workshop, .neighbours): "蒸汽工坊办成街坊合作社，谁出力谁分红"
        case (.workshop, .offices): "蒸汽工坊归市政，按名册招工"
        case (.workshop, .compacts): "蒸汽工坊归委员会私有，工钱高，不签约不进门"
        }
    }
    public static func stage(day: Int) -> Self? { allCases.first { $0.days.contains(day) } }
}

/// One finished choice: the account's vote for a side, counted under the shared rules.
public struct MPCCityTrendReceipt: Codable, Equatable, Sendable {
    /// Idempotent receipt (e.g. "errand-d5-florist"); the same ID records once.
    public let id: String
    public let day: Int
    public let side: MPCCityFaction
    /// A stage's key choice (weighs `MPCCityTrendLedger.keyWeight`, once per stage).
    public let key: Bool
    /// What the player did, for the newspaper: "把止痛膏直接送到了诊所".
    public let fact: String
    /// Points this receipt added to the city (0 past the day's cap).
    public let counted: Int
}

/// One account's trend receipts. The same rules hold on the shared server: a few ordinary
/// points a day and one key choice a stage, so nobody can carry the city alone.
public struct MPCCityTrendLedger: Codable, Equatable, Sendable {
    public static let ordinaryPerDay = 3
    public static let keyWeight = 3
    public private(set) var receipts: [MPCCityTrendReceipt] = []
    /// The account's one try at the leader exposed on day 21 (absent in older saves).
    public struct PlotTry: Codable, Equatable, Sendable {
        public let day: Int
        public let target: MPCCityFaction
        public let assassin: Bool
        public let success: Bool
    }
    public private(set) var plotTry: PlotTry?
    /// The plot fight under way, if any.
    public private(set) var plotTicket: String?
    public init() {}

    /// Opens the plot fight's ticket; one at a time, and only before the account has tried.
    public mutating func openPlotTicket(_ ticket: String) -> Bool {
        guard plotTry == nil, plotTicket == nil || plotTicket == ticket else { return false }
        plotTicket = ticket
        return true
    }
    /// Records the one try (a win is a success, a loss or a retreat a failure) and closes the ticket.
    @discardableResult
    public mutating func recordPlotTry(day: Int, target: MPCCityFaction, assassin: Bool, success: Bool) -> Bool {
        guard plotTry == nil else { return false }
        plotTry = .init(day: day, target: target, assassin: assassin, success: success)
        plotTicket = nil
        return true
    }

    /// Records a choice once per receipt ID; returns the points it added to the city.
    @discardableResult
    public mutating func record(id: String, day: Int, side: MPCCityFaction, key: Bool = false, fact: String) -> Int {
        guard !receipts.contains(where: { $0.id == id }) else { return 0 }
        let counted: Int
        if key {
            let stage = MPCCityTrendStage.stage(day: day)
            let used = receipts.contains { $0.key && $0.counted > 0 && MPCCityTrendStage.stage(day: $0.day) == stage }
            counted = (stage == nil || used) ? 0 : Self.keyWeight
        } else {
            let today = receipts.filter { !$0.key && $0.day == day && $0.counted > 0 }.count
            counted = today < Self.ordinaryPerDay ? 1 : 0
        }
        receipts.append(.init(id: id, day: day, side: side, key: key, fact: fact, counted: counted))
        return counted
    }
    public func points(on day: Int) -> [MPCCityFaction: Int] {
        receipts.filter { $0.day == day }.reduce(into: [:]) { $0[$1.side, default: 0] += $1.counted }
    }
    public func points(in days: ClosedRange<Int>) -> [MPCCityFaction: Int] {
        receipts.filter { days.contains($0.day) }.reduce(into: [:]) { $0[$1.side, default: 0] += $1.counted }
    }
    /// The side this account has backed most over the week up to `day`, if any.
    public func leaning(through day: Int) -> MPCCityFaction? {
        let week = points(in: max(1, day - 6)...max(1, day))
        guard let best = week.max(by: { $0.value < $1.value || ($0.value == $1.value && $0.key.rawValue > $1.key.rawValue) }),
              best.value > 0 else { return nil }
        return best.key
    }
}

/// A sudden turn in a stage: a fire, a theft, a scandal that pulls one side down for a day.
public struct MPCCityTrendShock: Codable, Equatable, Sendable {
    public let day: Int
    public let side: MPCCityFaction
    public let news: String
}

/// The other players of a shared world, simulated while the shared server is not connected.
/// A seeded crowd whose daily points follow momentum (people side with what is winning),
/// backlash (a side far ahead loses the middle) and the stage's shocks, with the player's
/// receipts on top: enough to push the city, not to decide it alone. The shared server replaces
/// these numbers with the real sums of every account's receipts; the rest of the rules stay.
public struct MPCCityTrendSimulation: Codable, Equatable, Sendable {
    public let seed: UInt64
    /// The crowd's points a day, against a player's three ordinary points (and a key choice of three).
    public static let dailyVolume = 45.0
    /// Above this share of the chapter so far, a side starts losing the middle.
    public static let backlashShare = 0.40
    /// How strongly the crowd follows the last three days, how much a day swings by chance, and
    /// how far the crowd leans to one side for a whole stage (a mood each world draws).
    /// Swept 2026-10-17 over 300 worlds: the crowd alone gives a side the first stage about 29%
    /// of the time; one player putting everything the rules allow into it raises that to about
    /// 60% — a real push, not a decision. `var` only so tests and tools can sweep them.
    nonisolated(unsafe) public static var momentum = 1.2
    nonisolated(unsafe) public static var noise = 0.4
    nonisolated(unsafe) public static var stageLean = 0.35
    public init(seed: UInt64) { self.seed = seed }

    /// 0..<1 from the seed and a few salts (SplitMix64).
    func unit(_ salts: Int...) -> Double {
        var z = seed &+ 0x9E37_79B9_7F4A_7C15
        for s in salts { z = (z ^ UInt64(bitPattern: Int64(s))) &* 0xBF58_476D_1CE4_E5B9; z ^= z >> 31 }
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
    /// The stage's shock day (not its first), or nil before day 4 and after day 28.
    func shockDay(_ stage: MPCCityTrendStage) -> Int {
        let days = Array(stage.days.dropFirst())
        return days[min(days.count - 1, Int(unit(stage.rawValue, 1) * Double(days.count)))]
    }
}

/// What the city looks like on a day: points so far, the stages settled, the shocks seen.
/// Shaped like the shared server's answer (string keys), so the app reads either the same way.
public struct MPCCityTrendSnapshot: Codable, Equatable, Sendable {
    public enum Source: String, Codable, Sendable { case simulated, server }
    public struct StageResult: Codable, Equatable, Sendable {
        public let stage: MPCCityTrendStage
        public let winner: MPCCityFaction
        public let shares: [String: Double]
    }
    public let day: Int
    public let source: Source
    /// Every side's points for the whole chapter so far (all players).
    public let total: [String: Double]
    /// The last seven days, and the seven before (for the week's rise and fall).
    public let week: [String: Double]
    public let lastWeek: [String: Double]
    /// The current stage's points so far (empty outside the stages).
    public let stage: [String: Double]
    /// This account's counted points over the last seven days.
    public let yours: [String: Int]
    public let results: [StageResult]
    public let shocks: [MPCCityTrendShock]
    /// The leader exposed on day 21 and how the plot stands (nil before, or when no side led enough).
    public var plot: MPCCityTrendWorld.Plot? = nil
    /// The chapter's end, once day 28 is through.
    public var ending: MPCCityTrendEnding? = nil

    public func share(_ side: MPCCityFaction, of points: [String: Double]? = nil) -> Double {
        let points = points ?? total
        let sum = points.values.reduce(0, +)
        return sum > 0 ? (points[side.rawValue] ?? 0) / sum : 1.0 / 3
    }
    public var leader: MPCCityFaction? {
        MPCCityFaction.allCases.max { share($0) < share($1) }.flatMap { share($0) > 1.0 / 3 + 0.005 ? $0 : nil }
    }
    public func result(_ stage: MPCCityTrendStage) -> MPCCityFaction? { results.first { $0.stage == stage }?.winner }
    /// "照这样下去……" for the stage under way, or nil outside the stages.
    public var forecast: String? {
        guard let current = MPCCityTrendStage.stage(day: day), !stage.isEmpty else { return nil }
        let order = MPCCityFaction.allCases.sorted { share($0, of: stage) > share($1, of: stage) }
        let lead = share(order[0], of: stage) - share(order[1], of: stage)
        let left = current.days.upperBound - day
        let when = left == 0 ? "今晚定局" : "还有 \(left) 天"
        if lead < 0.04 {
            return "\(current.title)·\(current.stake)：\(order[0].name)和\(order[1].name)咬得很紧，\(when)，谁也说不准。"
        }
        return "\(current.title)·\(current.stake)：照这样下去，\(current.outcome(order[0]))。\(when)。"
    }
}

/// The city stepped one day at a time (2026-10-17): one engine for the single-player world, the
/// shared server (which feeds it every account's points) and the outcome explorer
/// (tools/city-trend-sim). Days are added in order; nothing is recomputed or undone.
public struct MPCCityTrendWorld: Codable, Equatable, Sendable {
    /// Late in the chapter the side out in front shows its leader, who can be killed on the
    /// following days. Candidate rules after WORLD_CAMPAIGN_CORE_RACE_SPEC_20260927: one try per
    /// account, and a death needs `killMargin` more successful assassinations than successful guards.
    public struct Plot: Codable, Equatable, Sendable {
        /// What a death does to its side: the side falls apart, or the city rallies round it.
        public enum Aftermath: String, Codable, Sendable { case collapse, martyr }
        public let target: MPCCityFaction
        public fileprivate(set) var tried: Set<String> = []
        public fileprivate(set) var struck = 0
        public fileprivate(set) var held = 0
        public fileprivate(set) var killedDay: Int?
        public fileprivate(set) var aftermath: Aftermath?
        /// Tries taken on the day in progress, per role (each capped at `triesPerDay`).
        fileprivate var triesDay = 0
        fileprivate var assassinsToday = 0
        fileprivate var guardsToday = 0
        public var net: Int { struck - held }
    }
    public static let plotDays = 21...27
    /// Seats a day for assassins and for guards (like the 9-27 core: a few seats, not everyone).
    /// The attack has one more: it picks the moment (2026-10-17, tools/city-trend-sim: with two
    /// each, a 70:30 majority kept its workshop in 99.5% of worlds).
    public static let assassinSeats = 3
    public static let guardSeats = 2
    public static let killMargin = 4
    /// The lead over the second side (share of the chapter through day 20) that exposes a leader for days 21–27.
    public static let plotLead = 0.03
    /// Candidate tuning (swept with tools/city-trend-sim): the simulated crowd's tries a day and
    /// how a death moves its side (collapse for the rest of the chapter, or a three-day rally).
    nonisolated(unsafe) public static var crowdTries = 2.0
    nonisolated(unsafe) public static var collapseChance = 0.6

    public let simulation: MPCCityTrendSimulation
    /// Whether the simulated crowd also plots and guards (single player); the shared server
    /// leaves that to real accounts.
    public let crowdPlots: Bool
    public private(set) var daily: [[String: Double]] = []
    public private(set) var shocks: [MPCCityTrendShock] = []
    public private(set) var plot: Plot?
    public var day: Int { daily.count }

    public init(simulation: MPCCityTrendSimulation, crowdPlots: Bool = true) {
        self.simulation = simulation; self.crowdPlots = crowdPlots
    }

    /// One account tries to kill (assassin) or to guard the exposed leader on the day in
    /// progress. Once per account; returns whether the try was taken.
    @discardableResult
    public mutating func attempt(account: String, assassin: Bool, success: Bool) -> Bool {
        let today = day + 1
        guard var plot, plot.killedDay == nil, Self.plotDays.contains(today), !plot.tried.contains(account) else { return false }
        if plot.triesDay != today { plot.triesDay = today; plot.assassinsToday = 0; plot.guardsToday = 0 }
        guard assassin ? plot.assassinsToday < Self.assassinSeats : plot.guardsToday < Self.guardSeats else { return false }
        if assassin { plot.assassinsToday += 1 } else { plot.guardsToday += 1 }
        plot.tried.insert(account)
        if success { if assassin { plot.struck += 1 } else { plot.held += 1 } }
        self.plot = plot
        return true
    }

    /// Adds the next day: the crowd's points plus the players' (already capped by their ledgers).
    public mutating func advance(players: [MPCCityFaction: Double] = [:]) {
        let sides = MPCCityFaction.allCases
        let d = day + 1
        var total: [MPCCityFaction: Double] = [:]
        for day in daily { for side in sides { total[side, default: 0] += day[side.rawValue] ?? 0 } }
        let totalSum = total.values.reduce(0, +)
        var recent: [MPCCityFaction: Double] = [:]
        for day in daily.suffix(3) { for side in sides { recent[side, default: 0] += day[side.rawValue] ?? 0 } }
        let recentSum = recent.values.reduce(0, +)
        var shocked: MPCCityFaction?
        if let stage = MPCCityTrendStage.stage(day: d), d == simulation.shockDay(stage) {
            // Half the time the side in front draws the trouble; otherwise anyone.
            let leader = sides.max { (total[$0] ?? 0) < (total[$1] ?? 0) }!
            let pick = simulation.unit(stage.rawValue, 2) < 0.5 ? leader : sides[Int(simulation.unit(stage.rawValue, 3) * 3) % 3]
            shocked = pick
            shocks.append(.init(day: d, side: pick, news: MPCCityTrend.shockNews(stage, pick)))
        }
        // A death moves its side: it falls apart for the rest of the chapter, or the city rallies round it for three days.
        func afterDeath(_ side: MPCCityFaction) -> Double {
            guard let plot, plot.target == side, let killed = plot.killedDay, d > killed else { return 1 }
            return plot.aftermath == .collapse ? 0.55 : (d <= killed + 3 ? 1.4 : 1)
        }
        let tilt = Dictionary(uniqueKeysWithValues: sides.enumerated().map { ($1, 0.85 + 0.3 * simulation.unit(0, $0)) })
        var weights: [MPCCityFaction: Double] = [:]
        for (i, side) in sides.enumerated() {
            let momentum = recentSum > 0 ? (recent[side] ?? 0) / recentSum : 1.0 / 3
            let share = totalSum > 0 ? (total[side] ?? 0) / totalSum : 1.0 / 3
            let backlash = max(0, share - MPCCityTrendSimulation.backlashShare) * 2.2
            let swing = MPCCityTrendSimulation.noise
            let noise = 1 - swing / 2 + swing * simulation.unit(d, i, 7)
            let mood = MPCCityTrendStage.stage(day: d).map {
                1 - MPCCityTrendSimulation.stageLean + 2 * MPCCityTrendSimulation.stageLean * simulation.unit($0.rawValue, i, 5)
            } ?? 1
            weights[side] = tilt[side]! * mood * (1 + MPCCityTrendSimulation.momentum * (momentum - 1.0 / 3))
                * max(0.15, 1 - backlash) * noise * (shocked == side ? 0.45 : 1) * afterDeath(side)
        }
        let weightSum = weights.values.reduce(0, +)
        var today: [String: Double] = [:]
        for side in sides {
            let crowd = d < MPCNeighborCatalog.firstDay ? 0 : MPCCityTrendSimulation.dailyVolume * weights[side]! / weightSum
            // A shock undoes half of that side's day; after a death its people's work counts half
            // (the side falls apart) or a fifth more (the city rallies round it).
            let death = afterDeath(side)
            let own = (players[side] ?? 0) * (shocked == side ? 0.5 : 1) * (death < 1 ? 0.5 : death > 1 ? 1.2 : 1)
            today[side.rawValue] = crowd + own
        }
        daily.append(today)
        // At the end of day 20 the side out in front shows its leader, so tries on day 21 count.
        if d == Self.plotDays.lowerBound - 1, plot == nil {
            let points = self.points(1...d), sum = points.values.reduce(0, +)
            let order = sides.sorted { (points[$0] ?? 0) > (points[$1] ?? 0) }
            if sum > 0, ((points[order[0]] ?? 0) - (points[order[1]] ?? 0)) / sum >= Self.plotLead { plot = Plot(target: order[0]) }
        }
        if var plot, plot.killedDay == nil, Self.plotDays.contains(d) {
            if crowdPlots {
                // The other players simulated: tries split by how the city leans against or for the target.
                let s = totalSum > 0 ? (total[plot.target] ?? 0) / totalSum : 1.0 / 3
                for k in 0..<Int(Self.crowdTries.rounded()) {
                    if simulation.unit(d, k, 41) < 0.8 * (1 - s) { plot.struck += 1 }
                    if simulation.unit(d, k, 43) < 0.8 * s { plot.held += 1 }
                }
            }
            if plot.net >= Self.killMargin {
                plot.killedDay = d
                plot.aftermath = simulation.unit(plot.target.rawValue.count, 47) < Self.collapseChance ? .collapse : .martyr
            }
            self.plot = plot
        }
    }

    func points(_ days: ClosedRange<Int>) -> [MPCCityFaction: Double] {
        var out: [MPCCityFaction: Double] = [:]
        for d in days where d >= 1 && d <= daily.count {
            for side in MPCCityFaction.allCases { out[side, default: 0] += daily[d - 1][side.rawValue] ?? 0 }
        }
        return out
    }
    /// A stage's winner once the day after its last has begun (or the chapter is through).
    func result(_ stage: MPCCityTrendStage) -> MPCCityTrendSnapshot.StageResult? {
        guard daily.count >= stage.days.upperBound else { return nil }
        let points = points(stage.days)
        let winner = MPCCityFaction.allCases.max { a, b in
            (points[a] ?? 0) != (points[b] ?? 0) ? (points[a] ?? 0) < (points[b] ?? 0)
                : simulation.unit(stage.rawValue, a.hashValueStable) > simulation.unit(stage.rawValue, b.hashValueStable)
        }!
        return .init(stage: stage, winner: winner, shares: MPCCityTrend.shares(points))
    }

    /// How the newspaper sees the city on `day` (this world advanced through it).
    public func snapshot(day: Int, yours: MPCCityTrendLedger?, source: MPCCityTrendSnapshot.Source = .simulated) -> MPCCityTrendSnapshot {
        let current = MPCCityTrendStage.stage(day: day)
        return .init(day: day, source: source,
                     total: MPCCityTrend.keyed(points(1...max(1, day))),
                     week: MPCCityTrend.keyed(points(max(1, day - 6)...max(1, day))),
                     lastWeek: day > 7 ? MPCCityTrend.keyed(points(max(1, day - 13)...(day - 7))) : [:],
                     stage: current.map { MPCCityTrend.keyed(points($0.days.lowerBound...day)) } ?? [:],
                     yours: (yours?.points(in: max(1, day - 6)...max(1, day)) ?? [:]).reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                     // A stage is settled once its last day has passed.
                     results: MPCCityTrendStage.allCases.filter { $0.days.upperBound < day }.compactMap(result),
                     shocks: shocks.filter { $0.day <= day },
                     plot: day >= Self.plotDays.lowerBound ? plot : nil,
                     ending: day > MPCCityTrendStage.workshop.days.upperBound ? ending : nil)
    }

    /// The chapter's end, once day 28 is through: the world chapter two opens in.
    public var ending: MPCCityTrendEnding? {
        guard daily.count >= MPCCityTrendStage.workshop.days.upperBound else { return nil }
        let total = points(1...daily.count)
        return .init(stages: MPCCityTrendStage.allCases.map { result($0)!.winner },
                     dominant: MPCCityFaction.allCases.max { (total[$0] ?? 0) < (total[$1] ?? 0) }!,
                     plotTarget: plot?.target, killed: plot?.killedDay != nil, aftermath: plot?.aftermath)
    }
}

/// The world chapter one ends in: who took each stage (the last decides the workshop), who
/// leads the city, and whether the leader exposed on day 21 was killed, and how it fell out.
public struct MPCCityTrendEnding: Codable, Hashable, Sendable {
    public let stages: [MPCCityFaction]
    public let dominant: MPCCityFaction
    public let plotTarget: MPCCityFaction?
    public let killed: Bool
    public let aftermath: MPCCityTrendWorld.Plot.Aftermath?
    public var workshop: MPCCityFaction { stages[3] }
    public var summary: String {
        let plot: String = plotTarget.map { side in
            killed ? "\(side.name)领头人遇刺身亡（\(aftermath == .collapse ? "树倒猢狲散" : "全城为其举哀")）" : "\(side.name)领头人遇刺未死"
        } ?? "无人露面遇刺"
        return stages.map(\.name).joined(separator: "→") + " · 工坊归\(workshop.name) · \(dominant.name)主导 · " + plot
    }
}

public enum MPCCityTrend {
    /// The city on `day` from this account's receipts and the simulated crowd (no server yet).
    public static func snapshot(day: Int, ledger: MPCCityTrendLedger, simulation: MPCCityTrendSimulation) -> MPCCityTrendSnapshot {
        var world = MPCCityTrendWorld(simulation: simulation)
        if day >= 1 {
            for d in 1...day {
                if let try_ = ledger.plotTry, try_.day == d, world.plot?.target == try_.target {
                    world.attempt(account: "you", assassin: try_.assassin, success: try_.success)
                }
                world.advance(players: ledger.points(on: d).reduce(into: [:]) { $0[$1.key] = Double($1.value) })
            }
        }
        return world.snapshot(day: day, yours: ledger)
    }

    static func keyed(_ points: [MPCCityFaction: Double]) -> [String: Double] {
        points.reduce(into: [:]) { $0[$1.key.rawValue] = ($1.value * 10).rounded() / 10 }
    }
    static func shares(_ points: [MPCCityFaction: Double]) -> [String: Double] {
        let sum = points.values.reduce(0, +)
        return points.reduce(into: [:]) { $0[$1.key.rawValue] = sum > 0 ? (($1.value / sum) * 1000).rounded() / 1000 : 0 }
    }

    /// The day's shock as the newspaper reports it.
    static func shockNews(_ stage: MPCCityTrendStage, _ side: MPCCityFaction) -> String {
        switch (stage, side) {
        case (.casualties, .neighbours): "诊所后巷的互助床位夜里塌了两张，守夜的街坊吵了起来"
        case (.casualties, .offices): "施济所的登记册被人撕走半本，排队的人散了一半"
        case (.casualties, .compacts): "商行的止痛膏被查出掺了粉，押金退不回来"
        case (.pump, .neighbours): "义修的街坊里有人摔下泵井，没人敢再下去"
        case (.pump, .offices): "市政拨款的批文卡在第三个章上，泵站停工一天"
        case (.pump, .compacts): "委员会的包工头卷了半月工钱跑了"
        case (.blockade, .neighbours): "夜里接驳的小船翻了一条，警察厅连夜盘问码头"
        case (.blockade, .offices): "港务处查验时扣下了一船药，诊所断了货"
        case (.blockade, .compacts): "包船的商人被查出夹带名册，船被扣在港口"
        case (.workshop, .neighbours): "合作社的账目对不上，几家人闹着要退股"
        case (.workshop, .offices): "市政工坊的招工名册里多出几个查无此人的名字"
        case (.workshop, .compacts): "委员会的私厂合同被登了报，条款苛刻得吓人"
        }
    }
}

private extension MPCCityFaction {
    /// A fixed small number per side for seeded tie-breaks (Hashable's value changes per run).
    var hashValueStable: Int { MPCCityFaction.allCases.firstIndex(of: self)! + 11 }
}

extension MPCCityTrendStage {
    /// The stage's key choice (counts `MPCCityTrendLedger.keyWeight`, once a stage): who the
    /// player speaks up for when the stake is put to them.
    public var keyQuestion: String {
        switch self {
        case .casualties: "奥黛尔把三份床位方案摊在你面前：诊所人手不够，教会施济所有床但要登记姓名，商行愿意包下来但要押金。你替哪一份说话？"
        case .pump: "泵站停了好几天。码头工人说街坊轮流下井就能修；档案员说市政拨款下周批；维拉说委员会的人明天就能开工。"
        case .blockade: "港口封锁着。港务员要逐船查验；码头老水手说夜里能用小船接驳；商人说包一条船就能出港。"
        case .workshop: "蒸汽工坊就要奠基。市政厅摆着三份章程：街坊合作社、市政工坊、委员会私厂。"
        }
    }
    public var keyChoices: [MPCErrandWay] {
        let n = MPCCityFaction.neighbours, o = MPCCityFaction.offices, c = MPCCityFaction.compacts
        switch self {
        case .casualties: return [
            .init(side: n, label: "替诊所互助床位说话", fact: "在伤患潮里替诊所的互助床位说了话", reply: "奥黛尔：那就排班，今晚我守第一班。"),
            .init(side: o, label: "替施济所登记床位说话", fact: "在伤患潮里替教会施济所的登记床位说了话", reply: "伊莱：名字登上册，谁也不会被落下。"),
            .init(side: c, label: "替商行包床说话", fact: "在伤患潮里替商行包下床位说了话", reply: "商人：押金我先垫一半，床位今晚就有。")]
        case .pump: return [
            .init(side: n, label: "支持街坊义修", fact: "在泵站修复里支持了街坊义修", reply: "码头工人：那我明早带绳子来。"),
            .init(side: o, label: "支持市政拨款", fact: "在泵站修复里支持了市政拨款", reply: "档案员：表格我替你们填好了，签个字就行。"),
            .init(side: c, label: "支持委员会包工", fact: "在泵站修复里支持了工业委员会包工", reply: "维拉：好。合同明早送到。")]
        case .blockade: return [
            .init(side: n, label: "帮码头夜里接驳", fact: "在港口封锁里帮码头夜里接驳", reply: "老水手：天黑以后，旧栈桥见。"),
            .init(side: o, label: "支持逐船查验", fact: "在港口封锁里支持港务处逐船查验", reply: "港务员：查清楚了，放行才安心。"),
            .init(side: c, label: "替商人包船出力", fact: "在港口封锁里替商人包船出了力", reply: "商人：船票我给你留一张。")]
        case .workshop: return [
            .init(side: n, label: "签合作社章程", fact: "在工坊奠基时签了街坊合作社的章程", reply: "码头工人：谁出力谁分红，你也算一份。"),
            .init(side: o, label: "签市政工坊章程", fact: "在工坊奠基时签了市政工坊的章程", reply: "档案员：按名册招工，一个都不会漏。"),
            .init(side: c, label: "签委员会私厂章程", fact: "在工坊奠基时签了委员会私厂的章程", reply: "维拉：工钱高，规矩也严。欢迎。")]
        }
    }
}

/// The leaders a plot can expose (2026-10-17: only faction leaders, never characters the story
/// needs). New characters, so a death touches no errand, case or card table of the main cast.
extension MPCCityFaction {
    public var leaderID: String { "leader-" + rawValue }
    /// The leader's own name ("葛文"); sentences put `leaderTitle` before it.
    public var leaderName: String {
        switch self {
        case .neighbours: "葛文"
        case .offices: "卡索"
        case .compacts: "莫里斯"
        }
    }
    /// How plates, buttons and fights name the leader: "老会长葛文".
    public var leaderLabel: String {
        switch self {
        case .neighbours: "老会长葛文"
        case .offices: "秘书长卡索"
        case .compacts: "董事莫里斯"
        }
    }
    public var leaderTitle: String {
        switch self {
        case .neighbours: "码头互助会的老会长"
        case .offices: "市政厅秘书长"
        case .compacts: "工业委员会董事"
        }
    }
    public var leaderPlace: String {
        switch self {
        case .neighbours: "货场码头口"
        case .offices: "广场拱门下"
        case .compacts: "工坊货场北巷"
        }
    }
    /// What the leader did the night of the dock fire three years ago (2026-10-18 rewrite): each
    /// one did some good and some harm, so neither striking nor guarding is the easy side.
    public var leaderStory: String {
        switch self {
        case .neighbours: "三年前码头起火那夜，他带着码头的人挨家挨户敲门，背出来十一个人。也是他说，互助会的床先给会里的人。如今他腿脚不好了，每天早上还去码头口坐着，替没活干的人记名字。"
        case .offices: "大火之后，是他连夜写出避难所的新章程：在册的人先进。他说规矩不公平，可没有规矩，那晚会死更多人。那份章程的草稿，他一直锁在抽屉里。"
        case .compacts: "大火烧掉了他半个仓库。第二个月，他把剩下的一半改成工棚，按日结钱，不问来历。有人说他趁火压价，也有人说，那年冬天只有他的工棚管饭。"
        }
    }
    /// One line after the leader is killed.
    public var leaderEpitaph: String {
        switch self {
        case .neighbours: "码头口那张小凳子空了。"
        case .offices: "抽屉里那份章程草稿，被人送进了档案馆。"
        case .compacts: "那天工棚没有开工。"
        }
    }
}

extension MPCCityTrend {
    public static let plotPrefix = "church_maintenance_plot_"
    /// A plot fight: the assassin cuts through the leader's guards; the guard holds off the hired blades.
    public static func plotEncounterID(target: MPCCityFaction, assassin: Bool, ticket: String) -> String {
        plotPrefix + (assassin ? "strike" : "guard") + "-" + target.rawValue + "_" + ticket
    }
    public static func plotEncounter(id: String) -> MPCEncounterContent? {
        guard let parsed = MPCStreetEncounters.parse(id, prefix: plotPrefix) else { return nil }
        let parts = parsed.key.split(separator: "-").map(String.init)
        guard parts.count == 2, let side = MPCCityFaction(rawValue: parts[1]), ["strike", "guard"].contains(parts[0]) else { return nil }
        let strike = parts[0] == "strike"
        // Harder than a street errand (floors 10–20): a late-chapter fight with real risk.
        let waves: [[MPCStreetEncounters.Species]] = strike
            ? [[.crimsonBrute, .copperback], [.goldenThroat, .crimsonBrute, .moonfang]]   // the leader's bodyguards
            : [[.scissor, .moonfang, .moonfang], [.veilOracle, .scissor]]                // the hired blades
        return MPCStreetEncounters.content(id: id, name: (strike ? "刺杀·" : "护卫·") + side.leaderLabel, tag: "plot", waves: waves, floor: 30)
    }
}
