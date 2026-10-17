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
    public init() {}

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

public enum MPCCityTrend {
    /// The city on `day` from this account's receipts and the simulated crowd (no server yet).
    public static func snapshot(day: Int, ledger: MPCCityTrendLedger, simulation: MPCCityTrendSimulation) -> MPCCityTrendSnapshot {
        let sides = MPCCityFaction.allCases
        var daily: [[MPCCityFaction: Double]] = []
        var total: [MPCCityFaction: Double] = [:]
        var shocks: [MPCCityTrendShock] = []
        var results: [MPCCityTrendSnapshot.StageResult] = []
        // A small, seeded lean the crowd starts with, so every world opens a little differently.
        let tilt = Dictionary(uniqueKeysWithValues: sides.enumerated().map { ($1, 0.85 + 0.3 * simulation.unit(0, $0)) })
        if day >= 1 {
            for d in 1...day {
                let recent = daily.suffix(3).reduce(into: [MPCCityFaction: Double]()) { acc, day in
                    for (k, v) in day { acc[k, default: 0] += v }
                }
                let recentSum = recent.values.reduce(0, +), totalSum = total.values.reduce(0, +)
                var shocked: MPCCityFaction?
                if let stage = MPCCityTrendStage.stage(day: d), d == simulation.shockDay(stage) {
                    // Half the time the side in front draws the trouble; otherwise anyone.
                    let leader = sides.max { (total[$0] ?? 0) < (total[$1] ?? 0) }!
                    let pick = simulation.unit(stage.rawValue, 2) < 0.5 ? leader : sides[Int(simulation.unit(stage.rawValue, 3) * 3) % 3]
                    shocked = pick
                    shocks.append(.init(day: d, side: pick, news: shockNews(stage, pick)))
                }
                var weights: [MPCCityFaction: Double] = [:]
                for (i, side) in sides.enumerated() {
                    let momentum = recentSum > 0 ? (recent[side] ?? 0) / recentSum : 1.0 / 3
                    let share = totalSum > 0 ? (total[side] ?? 0) / totalSum : 1.0 / 3
                    let backlash = max(0, share - MPCCityTrendSimulation.backlashShare) * 2.2
                    let swing = MPCCityTrendSimulation.noise
                    let noise = 1 - swing / 2 + swing * simulation.unit(d, i, 7)
                    let follow = MPCCityTrendSimulation.momentum
                    let mood = MPCCityTrendStage.stage(day: d).map {
                        1 - MPCCityTrendSimulation.stageLean + 2 * MPCCityTrendSimulation.stageLean * simulation.unit($0.rawValue, i, 5)
                    } ?? 1
                    weights[side] = tilt[side]! * mood * (1 + follow * (momentum - 1.0 / 3)) * max(0.15, 1 - backlash)
                        * noise * (shocked == side ? 0.45 : 1)
                }
                let weightSum = weights.values.reduce(0, +)
                let yours = ledger.points(on: d)
                var today: [MPCCityFaction: Double] = [:]
                for side in sides {
                    let crowd = d < MPCNeighborCatalog.firstDay ? 0 : MPCCityTrendSimulation.dailyVolume * weights[side]! / weightSum
                    today[side] = crowd + Double(yours[side] ?? 0)
                    total[side, default: 0] += today[side]!
                }
                daily.append(today)
            }
        }
        // A stage is settled once its last day has passed.
        for stage in MPCCityTrendStage.allCases where stage.days.upperBound < day {
            let points = sum(daily, stage.days)
            let winner = sides.max { a, b in
                (points[a] ?? 0) != (points[b] ?? 0) ? (points[a] ?? 0) < (points[b] ?? 0)
                    : simulation.unit(stage.rawValue, a.hashValueStable) > simulation.unit(stage.rawValue, b.hashValueStable)
            }!
            results.append(.init(stage: stage, winner: winner, shares: shares(points)))
        }
        let current = MPCCityTrendStage.stage(day: day)
        return .init(day: day, source: .simulated,
                     total: keyed(total),
                     week: keyed(sum(daily, max(1, day - 6)...max(1, day))),
                     lastWeek: day > 7 ? keyed(sum(daily, max(1, day - 13)...(day - 7))) : [:],
                     stage: current.map { keyed(sum(daily, $0.days.lowerBound...day)) } ?? [:],
                     yours: ledger.points(in: max(1, day - 6)...max(1, day)).reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                     results: results, shocks: shocks)
    }

    private static func sum(_ daily: [[MPCCityFaction: Double]], _ days: ClosedRange<Int>) -> [MPCCityFaction: Double] {
        var out: [MPCCityFaction: Double] = [:]
        for d in days where d >= 1 && d <= daily.count { for (k, v) in daily[d - 1] { out[k, default: 0] += v } }
        return out
    }
    private static func keyed(_ points: [MPCCityFaction: Double]) -> [String: Double] {
        points.reduce(into: [:]) { $0[$1.key.rawValue] = ($1.value * 10).rounded() / 10 }
    }
    private static func shares(_ points: [MPCCityFaction: Double]) -> [String: Double] {
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
