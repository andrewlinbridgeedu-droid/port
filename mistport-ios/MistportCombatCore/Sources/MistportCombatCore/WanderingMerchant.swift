import Foundation

/// 跑船的货郎 (2026-10-22, user: 1 2 3 4 都做; the 10-13 rule: players at the same progress may buy stronger
/// relics with more copper). 阿德拉 puts in on day 3 and every fourth day after, and stays two days, so a
/// player who misses one day still meets her. She brings one passive relic the shop does not sell yet, at
/// half again its shop price; once the shop sells everything she would bring, she brings the dearest one
/// the player still lacks at a tenth off. Missing her costs only the wait for her next visit.
public enum MPCWanderingMerchant {
    public static let name = "阿德拉"
    public static let firstDay = 3
    public static let every = 4
    public static let stay = 2

    public static func isInPort(day: Int) -> Bool { day >= firstDay && (day - firstDay) % every < stay }
    /// The day she arrived and the day she leaves, when she is in port on `day`. A visit is named by its arrival day.
    public static func arrivalDay(day: Int) -> Int? { isInPort(day: day) ? day - (day - firstDay) % every : nil }
    public static func leavingDay(day: Int) -> Int? { arrivalDay(day: day).map { $0 + stay - 1 } }
    /// The first day on or after `day` that she is in port.
    public static func nextArrival(onOrAfter day: Int) -> Int {
        if isInPort(day: day) { return day }
        guard day > firstDay else { return firstDay }
        return firstDay + ((day - firstDay) / every + 1) * every
    }

    /// One relic she may bring, with the shop's price and the mission after which the shop sells it.
    public struct Relic: Equatable, Sendable {
        public let id: String
        public let shopPrice: Int
        public let shopMission: Int
        public init(id: String, shopPrice: Int, shopMission: Int) { self.id = id; self.shopPrice = shopPrice; self.shopMission = shopMission }
    }
    public struct Offer: Equatable, Sendable {
        public let relicID: String
        public let price: Int
        /// Before the shop sells it (at half again the price); false: a tenth off the shop price.
        public let early: Bool
        public let shopMission: Int
    }

    /// `soldVisits`: arrival days of the visits she already sold something on; one relic a visit.
    public static func offer(day: Int, relics: [Relic], owned: Set<String>, highestMission: Int, soldVisits: Set<Int> = []) -> Offer? {
        guard let visit = arrivalDay(day: day), !soldVisits.contains(visit) else { return nil }
        let unowned = relics.filter { !owned.contains($0.id) }
        if let early = unowned.filter({ $0.shopMission > highestMission }).min(by: { ($0.shopMission, $0.id) < ($1.shopMission, $1.id) }) {
            return .init(relicID: early.id, price: roundTen(early.shopPrice * 3 / 2), early: true, shopMission: early.shopMission)
        }
        guard let dearest = unowned.max(by: { ($0.shopPrice, $0.id) < ($1.shopPrice, $1.id) }) else { return nil }
        return .init(relicID: dearest.id, price: roundTen(dearest.shopPrice * 9 / 10), early: false, shopMission: dearest.shopMission)
    }
    static func roundTen(_ value: Int) -> Int { (value + 5) / 10 * 10 }

    /// The paper's line about her, for a day she is in port.
    public static func arrivalLine(day: Int) -> String? {
        guard let leaving = leavingDay(day: day) else { return nil }
        return leaving == day ? "跑船的货郎\(name)今天傍晚开船。" : "跑船的货郎\(name)靠岸了，在码头支了个摊，明天傍晚开船。"
    }
    public static let nothingLine = "她翻了翻货箱，说没什么能卖给你的了，请你喝了一杯热姜茶。"
    public static let soldLine = "这一趟的货已经卖给你了。\(name)把货箱扣上：“下回见。”"
}
