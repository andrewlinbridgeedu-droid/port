import Foundation

/// Who comes to the player, and how they talk, follows the city trend (2026-10-17,
/// CITY_TREND_TASKS_PROPOSAL_20261017.md). The home street shows only the player's own task
/// NPCs, so whose people ask for help is how the trend shows on the street.
extension MPCNeighborCatalog {
    /// The side each neighbour speaks for.
    public static let sides: [String: MPCCityFaction] = [
        "baker": .neighbours, "dockworker": .neighbours, "cafe-lane": .neighbours, "market-lane": .neighbours,
        "flower-seller-walk": .neighbours, "musician": .neighbours, "east-houses": .neighbours,
        "clock-square": .neighbours, "sailor-walk": .neighbours,
        "postman": .offices, "west-lane": .offices, "cathedral-road": .offices, "south-quay": .offices,
        "archive-apprentice-walk": .offices, "street_warden": .offices, "upper-road": .offices,
        "merchant": .compacts, "courier": .compacts, "cafe_keeper": .compacts, "florist": .compacts,
        "clockmaker": .compacts, "visitor": .compacts, "scholar": .compacts,
    ]

    /// The day's askers with the city trend (yesterday's paper): the rotation's askers, except
    /// that the last seat goes to the next neighbour of the side leading the current stage and,
    /// on three-asker days, the seat before it to the side trailing — they come asking the
    /// player to set things right. Without a stage under way, the plain rotation.
    public static func askers(day: Int, trend: MPCCityTrendSnapshot?) -> [MPCNeighbor] {
        var askers = askers(day: day)
        guard let trend, MPCCityTrendStage.stage(day: day) != nil, !trend.stage.isEmpty, askers.count >= 2 else { return askers }
        let order = MPCCityFaction.allCases.sorted { trend.share($0, of: trend.stage) > trend.share($1, of: trend.stage) }
        func next(_ side: MPCCityFaction) -> MPCNeighbor? {
            let start = rotationStart(day: day)
            return (0..<all.count).map { all[(start + $0) % all.count] }
                .first { sides[$0.id] == side && !askers.contains($0) }
        }
        if !askers.contains(where: { sides[$0.id] == order[0] }), let lead = next(order[0]) { askers[askers.count - 1] = lead }
        if askers.count >= 3, !askers.contains(where: { sides[$0.id] == order[2] }), let behind = next(order[2]) {
            // Any seat but the first that does not hold the leading side's only neighbour.
            let leaders = askers.filter { sides[$0.id] == order[0] }.count
            if let seat = askers.indices.reversed().first(where: { $0 > 0 && !(leaders == 1 && sides[askers[$0].id] == order[0]) }) {
                askers[seat] = behind
            }
        }
        return askers
    }

    /// A line in the neighbour's voice about how their side is doing and how the player has
    /// been leaning: "这阵子谁家缺点什么……你一直帮着我们这边，我记着。"
    public static func tone(_ neighborID: String, trend: MPCCityTrendSnapshot, leaning: MPCCityFaction?) -> String? {
        guard let side = sides[neighborID] else { return nil }
        let points = trend.stage.isEmpty ? trend.total : trend.stage
        let order = MPCCityFaction.allCases.sorted { trend.share($0, of: points) > trend.share($1, of: points) }
        let place = order.firstIndex(of: side)!
        let mood: String = switch (side, place) {
        case (.neighbours, 0): "这阵子谁家缺点什么，喊一嗓子就有人送来。好久没这样了。"
        case (.neighbours, 2): "现在借把梯子都要先问登没登记，街坊见了面只点个头。"
        case (.neighbours, _): "街坊还撑着。你家借碗米，我家还把葱，就看能撑几天了。"
        case (.offices, 0): "这阵子名册齐了，窗口前的队也短了。有章可循，心里踏实。"
        case (.offices, 2): "章盖了没人认，规矩贴在墙上，风一吹就掉。"
        case (.offices, _): "公署那边还在等批文，章盖了一半，搁在那儿。"
        case (.compacts, 0): "这阵子钱一到，事就办成。谁都认这个理，连我也认了。"
        case (.compacts, 2): "合同签了也没人认，商行的人见面就叹气。"
        case (.compacts, _): "价钱还在谈，谁也不肯先松口。"
        }
        guard let leaning else { return mood }
        return mood + (leaning == side ? "你一直帮着我们这边，我记着。" : "听说你常替\(leaning.name)办事……那今天这件，你看着办吧。")
    }
}
