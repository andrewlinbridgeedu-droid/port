import Foundation

/// 托队友办事 (2026-10-22, user: 1 2 3 4 都做). Before logging off, send 奥黛尔 or 诺恩 on an errand
/// somewhere in the city; they come back hours later with a little copper, a material or skill dust, and a
/// few lines about what they saw. One errand each per pacing day, one at a time; nothing is lost by
/// leaving them home, and a trip that is back waits until claimed. Errands do not take them out of a
/// battle. Rewards are small on purpose (two trips a day are about half a day's paid work).
public struct MPCPartyErrand: Equatable, Sendable, Identifiable {
    public let id: String
    public let mateID: String
    public let title: String
    public let place: String
    public let hours: Int
    public let copper: Int
    public let itemID: String
    public let itemCount: Int
    /// The story mission after which the errand is offered.
    public let mission: Int
    /// What they tell you when they are back, in turn.
    public let notes: [String]
}

public enum MPCPartyErrandCatalog {
    public static let odelle = "ally_odelle_finn"
    public static let norn = "ally_norn_kade"
    public static let mates = [odelle, norn]
    public static func name(_ mateID: String) -> String { mateID == odelle ? "奥黛尔" : "诺恩" }
    /// 奥黛尔 after Q4 (she gives the medal there); 诺恩 once 第七号空壳 is closed (he is its witness).
    public static func isAvailable(_ mateID: String, highestMission: Int, closedCases: Set<String>) -> Bool {
        mateID == odelle ? highestMission >= 4 : mateID == norn && closedCases.contains("b01")
    }
    public static func lockText(_ mateID: String) -> String {
        mateID == odelle ? "打完第 4 关后，奥黛尔会帮你跑腿。" : "结了通缉《第七号空壳》后，诺恩会帮你跑腿。"
    }
    public static func errand(_ id: String) -> MPCPartyErrand? { all.first { $0.id == id } }
    /// What a teammate can do today: the three most recently opened errands.
    public static func offers(_ mateID: String, highestMission: Int) -> [MPCPartyErrand] {
        Array(all.filter { $0.mateID == mateID && $0.mission <= highestMission }.reversed().prefix(3))
    }

    static let dust = MPCMissionChallengeCatalog.dustItemID
    public static let all: [MPCPartyErrand] = [
        .init(id: "odelle-dock", mateID: odelle, title: "去码头换药", place: "码头", hours: 8, copper: 6,
              itemID: MPCTowerMaterials.hide, itemCount: 1, mission: 4, notes: [
                "码头上有个搬运工的手掌裂了，她缝了七针。他付不起钱，塞给她一包晒干的海带。她说诊所的药柜又空了一格。",
                "她给三个搬运工换了药。最年轻的那个一直问伊恩去哪儿了，说以前都是伊恩来送药。她没回答，只把他的绷带缠得紧了一点。"]),
        .init(id: "odelle-soup", mateID: odelle, title: "汤棚义诊", place: "汤棚", hours: 12, copper: 4,
              itemID: dust, itemCount: 1, mission: 4, notes: [
                "汤婆的眼睛又疼了。奥黛尔替她换了干净的纱布，坐下来喝了一碗汤才回来。她说汤婆问起你，问你吃得够不够。",
                "排队的人里有个发烧的孩子。她守到天亮，烧退了。回来时她的外套上还有一股葱花味。"]),
        .init(id: "odelle-records", mateID: odelle, title: "去补录处等号", place: "补录处", hours: 8, copper: 4,
              itemID: dust, itemCount: 1, mission: 7, notes: [
                "她在补录处的长凳上坐了一下午，没人叫她的号。回来时，她把那张领药号的拓片压在了柜台的玻璃下面。",
                "补录处换了个年轻职员，替她把领药号抄了一份，没收钱。她把那张纸折了两折，放进贴身的口袋。"]),
        .init(id: "odelle-gears", mateID: odelle, title: "齿轮工坊出诊", place: "齿轮工坊", hours: 12, copper: 8,
              itemID: MPCTowerMaterials.gland, itemCount: 1, mission: 9, notes: [
                "工坊的学徒烫伤了手。她包扎完，学徒教她修好了诊所那台漏气的蒸馏壶。她说这是这个月最划算的一次出诊。",
                "老师傅的手抖得拿不住锉刀。她开了药，又陪他坐着锉完了一个齿轮。她说手抖不要紧，人还在就好。"]),
        .init(id: "odelle-drain", mateID: odelle, title: "排渠口出诊", place: "雨水排渠", hours: 12, copper: 8,
              itemID: MPCTowerMaterials.membrane, itemCount: 1, mission: 13, notes: [
                "从排渠出来的人有的发烧，有的认不出自己的鞋。她一个一个记下名字，说等洛克回来，要把这张单子交给他。",
                "她在排渠口支了张小桌子，一整夜没人来。天快亮时来了个老太太，只是想找人说说话。她陪她说到了早上。"]),
        .init(id: "odelle-salt", mateID: odelle, title: "去盐栈看病人", place: "盐栈", hours: 20, copper: 10,
              itemID: dust, itemCount: 1, mission: 19, notes: [
                "盐栈的床位空了一半。她在一张床底下找到一瓶没开封的退烧药，标签上写着“给小米”。她把它带回来，放在了柜台上。",
                "她给剩下的人量了体温，又教他们用盐水漱口。临走时有人问，被带走的那些人还能回来吗。她说能，我们在找。"]),
        .init(id: "norn-night", mateID: norn, title: "巡夜", place: "雾灯街", hours: 8, copper: 6,
              itemID: MPCTowerMaterials.scale, itemCount: 1, mission: 7, notes: [
                "他在雾灯街走了一夜。灭了两盏灯，他记下编号，第二天去公署报修。他说报修单通常要等一个月，他每周去催一次。",
                "巡夜时他拦下一个往墙上贴“已认领”告示的人。那人说只是拿钱办事。诺恩把告示揭下来，叠好，收进了证物袋。"]),
        .init(id: "norn-coal", mateID: norn, title: "去封锁线看看", place: "封锁公告处", hours: 12, copper: 4,
              itemID: dust, itemCount: 1, mission: 7, notes: [
                "卖炭的老周家里还剩一个孙女。诺恩送去半袋煤，没说是谁让送的。",
                "封锁早撤了，公告还贴着。他一张一张揭下来，有一张背面写着一个女人的名字和“买药”两个字。他把它交给了奥黛尔。"]),
        .init(id: "norn-files", mateID: norn, title: "翻旧卷宗", place: "公署", hours: 12, copper: 6,
              itemID: dust, itemCount: 1, mission: 10, notes: [
                "他在公署的旧卷宗里翻了一整晚，找到三张同一个笔迹的认领单。他把编号抄给你，只说了一句：“先别声张。”",
                "卷宗室的灯坏了，他借守夜人的提灯看到天亮。他说三年前冬天的那几本，翻起来手都是黑的，全是烟灰。"]),
        .init(id: "norn-custody", mateID: norn, title: "去看管处", place: "看管处", hours: 8, copper: 4,
              itemID: dust, itemCount: 1, mission: 15, notes: [
                "他给看管处送了一床厚被子。维娅没说话，只问了一句外面冷不冷。",
                "看管处的登记簿上，维娅那一栏写着“无人探视”。他想了想，划掉，写上了自己的名字。"]),
        .init(id: "norn-tickets", mateID: norn, title: "码头核对船票", place: "码头", hours: 12, copper: 8,
              itemID: MPCTowerMaterials.silk, itemCount: 1, mission: 16, notes: [
                "外海来的船，船票上的名字和下船的人对不上。他扣下一张，说要拿回去慢慢对。",
                "他在码头核了一夜船票。有个老船员偷偷告诉他，有些船进港时吃水很深，出港时更深。"]),
        .init(id: "norn-route", mateID: norn, title: "沿押运路线走一趟", place: "押运线", hours: 20, copper: 10,
              itemID: MPCTowerMaterials.talon, itemCount: 1, mission: 20, notes: [
                "他沿着你记下的押运路线走到天亮，在一处岔口捡到一枚孩子的扣子。他把扣子放进证物袋，说总有人会来认。",
                "路线上有个岗亭，他在里面找到一本没烧完的值班簿。最后一页写着：今天车上的人一直在敲。"]),
    ]
}

/// One save's teammate errands. A trip pays once, when claimed after it is back.
public struct MPCPartyErrandLedger: Codable, Equatable, Sendable {
    public enum Failure: Error, Equatable { case unavailable, unknownErrand, away, sentToday, notBack, nothingToClaim }

    public struct Trip: Codable, Equatable, Sendable, Identifiable {
        /// "<mate>-d<day>": one trip a teammate a day.
        public let id: String
        public let mateID: String
        public let errandID: String
        public let day: Int
        public let startedAt: TimeInterval
        public let returnsAt: TimeInterval
        public var claimed = false
        public var errand: MPCPartyErrand? { MPCPartyErrandCatalog.errand(errandID) }
        public func isBack(at now: TimeInterval) -> Bool { now >= returnsAt }
    }
    public struct Reward: Equatable, Sendable {
        public let tripID: String
        public let mateName: String
        public let errandTitle: String
        public let copper: Int
        public let itemID: String
        public let itemCount: Int
        public let note: String
    }

    public private(set) var trips: [Trip] = []
    public init() {}

    /// The teammate's trip not yet claimed (away, or back and waiting).
    public func open(_ mateID: String) -> Trip? { trips.last { $0.mateID == mateID && !$0.claimed } }
    public func sentToday(_ mateID: String, day: Int) -> Bool { trips.contains { $0.mateID == mateID && $0.day == day } }
    public func canSend(_ mateID: String, day: Int) -> Bool { open(mateID) == nil && !sentToday(mateID, day: day) }

    public mutating func send(_ errandID: String, day: Int, at now: TimeInterval, highestMission: Int, closedCases: Set<String>) throws -> Trip {
        guard let errand = MPCPartyErrandCatalog.errand(errandID), errand.mission <= highestMission else { throw Failure.unknownErrand }
        guard MPCPartyErrandCatalog.isAvailable(errand.mateID, highestMission: highestMission, closedCases: closedCases) else { throw Failure.unavailable }
        guard open(errand.mateID) == nil else { throw Failure.away }
        guard !sentToday(errand.mateID, day: day) else { throw Failure.sentToday }
        let trip = Trip(id: "\(errand.mateID)-d\(day)", mateID: errand.mateID, errandID: errandID, day: day,
                        startedAt: now, returnsAt: now + Double(errand.hours) * 3_600)
        trips = Array((trips + [trip]).suffix(60))
        return trip
    }

    /// Marks the teammate's trip claimed and returns what it brought. The note is the errand's next one in turn.
    public mutating func claim(_ mateID: String, at now: TimeInterval) throws -> Reward {
        guard let index = trips.lastIndex(where: { $0.mateID == mateID && !$0.claimed }), let errand = trips[index].errand else {
            throw Failure.nothingToClaim
        }
        guard trips[index].isBack(at: now) else { throw Failure.notBack }
        let before = trips[..<index].filter { $0.errandID == errand.id && $0.claimed }.count
        trips[index].claimed = true
        return .init(tripID: trips[index].id, mateName: MPCPartyErrandCatalog.name(mateID), errandTitle: errand.title,
                     copper: errand.copper, itemID: errand.itemID, itemCount: errand.itemCount,
                     note: errand.notes[before % errand.notes.count])
    }
}
