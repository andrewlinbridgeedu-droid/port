import Foundation

/// 雨后第一天 (2026-10-18, user: 打完第2关后，玛拉带你认城：汤棚、码头铺位、邮局、银行、午夜钟咖啡馆、
/// 守灯会。每站一小段戏、一件小事，顺便教会住房、体力、银行怎么用。按第一章的新写法写): six stops,
/// open after Q2, walked in order. Each stop is a scene in 玛拉's bubble, then one small thing to do, a
/// plain lesson, and a door to the real place.
public enum MPCCityTour {
    public static let unlockMission = 2

    public enum Task: Equatable, Sendable {
        /// A small question about what the stop just taught; the wrong answers get a nudge, not a penalty.
        case question(prompt: String, choices: [String], answer: Int, nudge: String)
        /// One thing to do with your hands.
        case action(label: String)
    }

    public struct Stop: Identifiable, Equatable, Sendable {
        public let id: String
        public let title: String
        /// What the stop teaches, for the subtitle ("体力").
        public let topic: String
        /// The home destination that opens the real place.
        public let destinationID: String
        public let scene: String
        public let task: Task
        /// The plain rules, numbers included (checked against the code 2026-10-18).
        public let lesson: String
        /// The line after the small thing is done.
        public let done: String
        /// Copper paid once, when the stop is done.
        public let reward: Int
    }

    public static let stops: [Stop] = [
        .init(id: "soup", title: "汤棚", topic: "体力", destinationID: "housing-soup",
              scene: "猎犬的叫声远了。玛拉带你穿过两条巷子，停在一个冒着白气的棚子前。\n锅比人还高。掌勺的是个独眼的老太太，大家叫她汤婆。她不问你是谁，先盛了一碗推过来：“喝吧。在雾港，先吃饱，再问别的。”\n玛拉在你旁边坐下：“你会累的。替人跑一趟腿，要花力气。吃一顿热的，睡一个整觉，力气才回得来。”\n“吃得好、睡得好，第二天回得多。吃得差，也回，就是慢。”",
              task: .question(prompt: "汤婆问你：力气是从哪儿回来的？", choices: ["吃饭和睡觉", "去深井里打", "把铜存进银行"], answer: 0,
                              nudge: "玛拉笑了：“那可回不来。吃一顿热的，睡一觉。”"),
              lesson: "体力上限 100，随时间慢慢回满，一天回一整槽。主线和深井不花体力；街坊委托、急件、邮务每件花 10 到 35 点。吃住得好，回得更快。",
              done: "汤婆又给你添了半勺：“明天还来。”", reward: 0),
        .init(id: "bunk", title: "码头铺位", topic: "住房", destinationID: "housing-agency",
              scene: "码头仓库的二楼隔成一排排铺位，帘子是旧帆布做的。你的那张在最里头。\n枕头底下有人塞了一块干面包，不知道是谁的好意。\n“这里便宜，床钱和饭钱一天加起来十二个铜，”玛拉替你把帘子拉好，“每天早上自动从你兜里扣，不用跑去交。”\n“以后有钱了，去赁屋行换合租、换联排。住得好，睡得也好。”\n她顿了顿：“三年前，这里睡过三十一个人。”",
              task: .question(prompt: "床钱和饭钱什么时候交？", choices: ["每天早上自动扣", "自己跑去赁屋行交", "打赢一仗才交"], answer: 0,
                              nudge: "玛拉摇头：“不用跑。每天早上，它自己就扣了。”"),
              lesson: "码头铺位一天 3 铜，汤棚饭食一天 9 铜，每天早上自动扣。打到第 5 关可以换合租，第 13 关可以换联排；住得越好，体力回得越快。",
              done: "你把那块干面包放回了枕头底下，留给下一个睡在这里的人。", reward: 0),
        .init(id: "post", title: "邮局", topic: "零工", destinationID: "postal-work",
              scene: "邮局里堆满了退信。一个年轻的邮差趴在柜台上，眼圈是黑的。\n“又是‘已送达’。”他把一封信扔进筐里，“明明没送到。”\n玛拉看着那筐信，很久没说话。\n邮差抬头看你：“你识字吗？帮我分一封，就一封。”\n信封上写着：旧街十七号，鞋匠莱斯收。背面有人用铅笔补了一行：鞋匠铺上个月搬到钟楼广场了。",
              task: .question(prompt: "这封信该放进哪一格？", choices: ["旧街", "钟楼广场", "退回寄信人"], answer: 1,
                              nudge: "邮差指了指信封背面：“看那行铅笔字。”"),
              lesson: "打到第 4 关，邮局可以接零工：核对单据，按件给铜，每件花 10 体力。不想打仗的时候，这是最稳的一份钱。",
              done: "邮差塞给你几个铜子：“第 4 关以后常来，我们缺人手。”", reward: 8),
        .init(id: "bank", title: "银行", topic: "存钱", destinationID: "bank",
              scene: "银行的门很重。柜员是个戴单片眼镜的老先生，看了看你的通行证，又看了看你的脸。\n“新客？”他翻开一本厚册子，“钱存在这儿，丢不了。放满日子，还有利息。”\n玛拉在你身后小声说：“钱揣在兜里，被偷了就没了。放在这儿，至少有本账。”\n柜员把笔递给你，等你写下自己的名字。",
              task: .question(prompt: "柜员问：把钱存进银行，图的是什么？", choices: ["丢不了，放满日子还有利息", "能多打一场仗", "能少花体力"], answer: 0,
                              nudge: "老先生扶了扶眼镜：“银行只管钱。”"),
              lesson: "银行可以开新客存单，存进去的钱放满日子有利息。钱不够用的时候别全存进去，兜里要留饭钱和床钱。以后还能找银行经理投产业。",
              done: "柜员在册子上写下你的名字，字迹工整。你看着那一行字，想起有人也这样替你写过一次。", reward: 0),
        .init(id: "cafe", title: "午夜钟咖啡馆", topic: "日刊", destinationID: "cafe-locked",
              scene: "午夜钟咖啡馆的钟永远停在十二点。店主是个嗓门很大的女人，叫莫莉。\n她不收玛拉的钱，也不收你的：“第一杯请客，规矩。”\n墙上钉着一张发黄的账单：咖啡三十一杯，未付。你多看了一眼，莫莉没解释。\n桌上摊着今天的《雾港日刊》。“每天早上看一眼，”莫莉说，“哪关开了，城里谁占上风，谁家缺人帮忙，都在上面。”\n玛拉喝了一口，皱了皱眉：“还是这么苦。”\n“三年都没变，”莫莉说，“你不也还是来。”",
              task: .question(prompt: "想知道今天能打到第几关，看哪儿？", choices: ["《雾港日刊》", "银行的账本", "邮局的退信"], answer: 0,
                              nudge: "莫莉把报纸往你面前一推：“看这个。”"),
              lesson: "每天早上的《雾港日刊》写着：今天能打到第几关，深井还能封几层，城里谁占上风，谁家要人帮忙。主线每天开一关，第一天开到第 7 关。",
              done: "莫莉把报纸塞进你手里：“拿着，明天还有新的。”", reward: 0),
        .init(id: "lamp", title: "守灯会", topic: "深井与通缉", destinationID: "church",
              scene: "守灯会的门口点着一排灯，白天也不熄。开门的是个女祭司，袖口挽着，手上有灯油的味道。\n“灯不问提灯的是谁。”她说。这是守灯会的第一句话。\n她领你去看后院那口井。井口封着铁板，底下有风声。“深井一共一百层，越往下越凶。每天能封几层，按日子来；封过的层，随时能再下去练手。”\n墙上贴着通缉令。“巡官查不完的案子，挂在这里。查清了，打赢了，有赏。”\n临走前，她替你点了一盏灯，挂在门口那一排的最后：“你回来的时候，看得见它。”",
              task: .action(label: "接过那盏灯"),
              lesson: "深井一共 100 层，第一天能封 8 层，之后每天 4 层，封过的层随时能再打。通缉案先查线索再找人，打赢有赏。主线和深井都不花体力。",
              done: "那盏灯在一排灯的最后亮着。玛拉站在灯下看了它很久，像在看一个很久以前的人。", reward: 30),
    ]

    public static func stop(_ id: String) -> Stop? { stops.first { $0.id == id } }

    /// The stops walked so far, in order; each pays once.
    public struct Ledger: Codable, Equatable, Sendable {
        public private(set) var done: [String] = []
        public init() {}
        public var nextStop: Stop? { MPCCityTour.stops.first { !done.contains($0.id) } }
        public var isFinished: Bool { nextStop == nil }
        /// Only the next stop can be done; returns false for a repeat or a stop out of order.
        public mutating func complete(_ id: String) -> Bool {
            guard nextStop?.id == id else { return false }
            done.append(id)
            return true
        }
    }

    public static func isOpen(completedMissionNumbers: Set<Int>) -> Bool {
        completedMissionNumbers.contains { $0 >= unlockMission }
    }
}
