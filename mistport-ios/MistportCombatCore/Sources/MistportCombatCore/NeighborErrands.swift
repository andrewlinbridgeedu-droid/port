import Foundation

/// Neighbour errands, agreed 2026-09-29 (DAILY_LOOP_AND_ECONOMY_20260929.md §4.5, §8.4):
/// the 23 walking citizens of the harbour map (Mistport/WisteriaMap/harbor-pedestrians.json)
/// ask for small favours, two or three a day from day 2: deliver a workshop good, find
/// something, chase off a tower pest, or carry a message. They pay a little copper and
/// affinity; affinity 3 and 6 unlock the neighbour's short stories. Never power.
public struct MPCNeighborErrand: Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable { case deliver, find, pest, message }
    public let id: String
    public let kind: Kind
    public let request: String
    public let thanks: String
    public let itemID: String?
    public let count: Int
    public let question: String?
    public let choices: [MPCChurchBountyChoice]
    public let correctChoiceID: String?
    /// Message errands: the neighbour to walk to and what they answer.
    public let recipientID: String?
    public let reply: String?
    public let pests: [MPCChurchTowerCatalog.Species]

    /// Goods at the workshop order price plus 5; other errands a flat fee.
    public var copper: Int {
        switch kind {
        case .deliver: count * (MPCWorkshopOrderBoard.prices[itemID ?? ""] ?? 0) + 5
        case .find: 12
        case .pest: 15
        case .message: 8
        }
    }
    /// Goods come from the workshop, which opens after Q5.
    public var needsWorkshop: Bool { kind == .deliver }

    static func deliver(_ id: String, _ request: String, item: String, count: Int, thanks: String) -> Self {
        .init(id: id, kind: .deliver, request: request, thanks: thanks, itemID: item, count: count, question: nil, choices: [],
              correctChoiceID: nil, recipientID: nil, reply: nil, pests: [])
    }
    static func find(_ id: String, _ request: String, question: String, _ choices: [(String, String)], correct: Int, thanks: String) -> Self {
        let ids = ["a", "b", "c"]
        return .init(id: id, kind: .find, request: request, thanks: thanks, itemID: nil, count: 0, question: question,
                     choices: choices.enumerated().map { .init(id: ids[$0], text: $1.0, explanation: $1.1) },
                     correctChoiceID: ids[correct], recipientID: nil, reply: nil, pests: [])
    }
    static func pest(_ id: String, _ request: String, _ pests: [MPCChurchTowerCatalog.Species], thanks: String) -> Self {
        .init(id: id, kind: .pest, request: request, thanks: thanks, itemID: nil, count: 0, question: nil, choices: [],
              correctChoiceID: nil, recipientID: nil, reply: nil, pests: pests)
    }
    static func message(_ id: String, _ request: String, to recipient: String, reply: String, thanks: String) -> Self {
        .init(id: id, kind: .message, request: request, thanks: thanks, itemID: nil, count: 0, question: nil, choices: [],
              correctChoiceID: nil, recipientID: recipient, reply: reply, pests: [])
    }
}

public struct MPCNeighbor: Equatable, Sendable, Identifiable {
    /// The citizen ID in harbor-pedestrians.json.
    public let id: String
    public let name: String
    public let errands: [MPCNeighborErrand]
    /// Unlocked at MPCNeighborCatalog.storyAffinity; empty until this neighbour's batch is written.
    public let stories: [String]
    public var isWritten: Bool { !stories.isEmpty }
}

public enum MPCNeighborCatalog {
    public static let firstDay = 2
    public static let storyAffinity = [3, 6]
    public static let prefix = "church_maintenance_errand_"
    /// Pests are small early bodies: a chore, not a tower fight.
    public static let pestFloor = 10

    static var strap: String { MPCCraftingCatalog.strapID }
    static var salve: String { MPCCraftingCatalog.salveID }
    static var patch: String { MPCCraftingCatalog.patchID }
    static var cloth: String { MPCCraftingCatalog.clothID }

    /// First batch (2026-09-29): eight neighbours with their own errands and two stories each.
    public static let written: [MPCNeighbor] = [
        .init(id: "postman", name: "邮差", errands: [
            .message("postman-letter", "有封信写着‘旧街门牌登记员收’，可我今天走不到旧街了。你替我跑一趟，把信交给他？",
                     to: "west-lane", reply: "又是寄给那间空屋的。门牌换了，可总有人记得旧号。我先替他收着。",
                     thanks: "送到了？好，这封信总算没在我包里过夜。"),
            .pest("postman-pest", "邮包在钟楼广场被一只塔怪叼走了，它就蹲在排水口边上啃信封。", [.copperback, .moonfang],
                  thanks: "信封湿了，字还认得。谢谢，这一包是整条街的工钱单。"),
            .deliver("postman-strap", "背带磨断了，邮包一路往下坠。有维修绑带的话，给我两条。", item: strap, count: 2,
                     thanks: "扎紧了。明天起我还能多走两条街。")
        ], stories: [
            "那些被刮掉名字的信，我一封都没扔。收件人多半已经不在了，可寄信的人不知道。我把它们按寄出的日子排好，放在邮局最底下的抽屉里——哪天有人来问，至少还找得到。",
            "我年轻时送错过一封信。信里写着‘别上船’，收信的人第二天就出海了，再没回来。从那以后，地址不清的信我都亲自跑一遍，跑到能确认为止。你问我为什么不嫌累？因为那一次我嫌过。"
        ]),
        .init(id: "east-houses", name: "东岸提灯人", errands: [
            .deliver("east-houses-cloth", "灯罩里的纱网被盐雾蚀穿了，风一吹就灭。给我两块过滤布，我自己缝上。", item: cloth, count: 2,
                     thanks: "新纱网透光，也挡风。今晚这条街不会黑。"),
            .find("east-houses-find", "昨晚提前熄的那盏灯，我想知道是谁熄的。", question: "看灯柱下的痕迹，灯是怎么熄的？", [
                ("有人故意吹灭的", "灯罩是扣紧的，吹不灭。"),
                ("灯油烧完了", "油壶还剩一半。"),
                ("灯罩内壁有被舔过的油痕，是小塔怪爬上去偷灯油", "油痕一路通到排水沟，不是人手。")], correct: 2,
                  thanks: "原来是馋灯油的东西。我明天在灯柱上抹一圈盐。"),
            .pest("east-houses-pest", "三号灯柱底下有东西在啃灯芯，我拿长杆也够不着它。", [.moonfang, .goldenThroat],
                  thanks: "灯芯保住了。你站在灯下的时候，影子比我还长。")
        ], stories: [
            "右岸一共四十一盏灯。我点灯的顺序从来不变：从码头往上坡走，最后一盏在老钟表铺门口。那盏灯是我自己出钱添的，灯油也是我买的——那家的老人说过，天黑以后他看不清钥匙孔。",
            "老人去年冬天走了，钟表铺换了主人。我还是每晚点那盏灯。新店主问我为什么，我说灯柱都立在那儿了，总得有光。其实我是怕哪天有人回来，找不到那扇门。"
        ]),
        .init(id: "baker", name: "面包师", errands: [
            .deliver("baker-salve", "揉面时被炉门烫了一下，手背起了泡。有止痛膏吗？一小罐就够。", item: salve, count: 1,
                     thanks: "凉下来了。明早的面包不会因为我的手晚出炉。"),
            .pest("baker-pest", "仓房里有东西偷面粉，袋子底下一串小牙印。我不敢一个人进去。", [.moonfang, .moonfang],
                  thanks: "是月牙鼠？怪不得专挑细面粉。拿两个刚出炉的圆面包走吧，工钱照付。"),
            .message("baker-message", "码头工人昨天订了一袋硬面包，没来拿。你帮我问问他还要不要。",
                     to: "dockworker", reply: "要！船期推了一天，我忘了去拿。跟她说我明早天亮前到。",
                     thanks: "好，那我给他留着，再多放一块黑麦的。")
        ], stories: [
            "天亮前来买硬面包的，多半是当天要出海的人。硬面包放得久，泡在汤里也不散。我会在每袋里多放一块，不说。出海的人饿的时候，会想起岸上有人记得他。",
            "我父亲做了一辈子面包，最后几年手抖得揉不动面。他就坐在炉边看我揉，揉错了也不说，只把火候调好。现在我闭着眼也知道炉子什么时候够热——那是他留给我的。"
        ]),
        .init(id: "clockmaker", name: "钟表匠", errands: [
            .deliver("clockmaker-patch", "钟台的齿轮垫片磨薄了，修甲片的钢刚好合用。给我两片？", item: patch, count: 2,
                     thanks: "垫上了，指针走得稳多了。你听，这一声‘嗒’比昨天清楚。"),
            .find("clockmaker-find", "我门口的钟被人拨过，快了七分钟。", question: "谁动了钟？", [
                ("钟壳里有树蛙的黏液，是它钻进去碰动了齿轮", "黏液还留在齿缝里。"),
                ("隔壁的孩子", "孩子够不着钟面。"),
                ("钟自己坏了", "钟不会自己倒转，也不会自己变快。")], correct: 0,
                  thanks: "又是这些树蛙。我得给钟壳加一道网。"),
            .pest("clockmaker-pest", "钟台底座里住进了几只金喉树蛙，每到整点就跟着钟一起叫。", [.goldenThroat, .goldenThroat],
                  thanks: "安静了。现在整点只剩钟声，这才对。")
        ], stories: [
            "这间铺子是我从一位老人手里接下的。他留下一整柜没修完的钟，每一只都贴着纸条：谁送来的，哪天要。有几只的主人早就不来了，我还是一只一只修好，挂在墙上走。",
            "东岸提灯人每晚都在我门口点灯，风雨不停。我起初以为是街上的规矩，后来才知道那盏灯是他自己添的，为了原来的店主。我没告诉他我知道了，只是每天把门口那只钟对准，让他点灯时看得见时间。"
        ]),
        .init(id: "dockworker", name: "码头工人", errands: [
            .deliver("dockworker-strap", "货箱的绑绳一天断三根。你做的维修绑带结实，给我三条。", item: strap, count: 3,
                     thanks: "这下捆得住了。工头问起，我就说是你做的。"),
            .pest("dockworker-pest", "货堆里钻进了一只铜背甲兽，把整排货箱当成了窝。", [.copperback, .shieldJaw],
                  thanks: "箱子上全是爪痕，可货没丢。你这一趟抵得上我半天工钱。"),
            .message("dockworker-message", "把这张工钱条子交给港务抄账员，上个月少记了我两天。",
                     to: "south-quay", reply: "两天……对上了，就是撕掉的那两页。我补记上，下次发工钱一起算。",
                     thanks: "补上就好。我不在乎那点钱——我在乎账上有我干过的活。")
        ], stories: [
            "你以为码头工只会搬东西。其实我们记得每条船的吃水线：一条船装了多少货，看它进港时压多深就知道。所以谁在封条上动了手脚，我们心里有数，只是没人来问。",
            "我哥哥也是码头工，力气比我大。有一年港口封了，活没了，他上了一条去外海的船。走前他把钩子留给我，说回来再要。钩子我一直用着，磨得比他走时还亮。"
        ]),
        .init(id: "florist", name: "花商", errands: [
            .find("florist-find", "有人从我摊上顺走了一束紫藤，只留下一个脚印。", question: "顺走花的人往哪去了？", [
                ("花瓣落在旧街口，往旧街去了", "花瓣会被风吹，不能指路。"),
                ("脚印沾着钟楼广场特有的青苔泥，往钟楼去了", "泥比花瓣可靠。"),
                ("往码头去了，买花送船上的人", "没有证据，只是猜。")], correct: 1,
                  thanks: "钟楼……是那个每天在广场上等人的水手吧。算了，那束花就当送他的。"),
            .deliver("florist-cloth", "包花的纱纸用完了。过滤布细，给我两块，我拿来裹花根。", item: cloth, count: 2,
                     thanks: "花根裹上湿布能撑到明天。今天卖不完，明天还是新鲜的。"),
            .pest("florist-pest", "花摊后面的水桶让一只塔怪占了，它拿紫藤当垫子。", [.goldenThroat, .moonfang],
                  thanks: "压坏了几枝，没关系。人没事就好。")
        ], stories: [
            "我卖的紫藤都是从旧街老墙上剪的。那面墙后面原来住着一户人家，现在空了。我每次剪花前都敲敲墙——不是迷信，就是觉得该打个招呼。",
            "我小时候以为花会记得是谁种的。现在我知道不会，可人会记得是谁送的。所以我卖花从不讲价：买花的人多半是要去见谁，我不想让他们在路上还想着吃了亏。"
        ]),
        .init(id: "musician", name: "街头乐师", errands: [
            .pest("musician-pest", "广场排水沟里有只金喉树蛙，我一拉琴它就跟着叫，还跑调。", [.goldenThroat, .copperback],
                  thanks: "安静了。现在跑调的只剩我自己。"),
            .message("musician-message", "钟楼广场那个水手总在听我拉琴，却从来不点歌。替我问问他想听什么。",
                     to: "clock-square", reply: "……《回港》。我以前的船长爱哼这首。别说是我点的。",
                     thanks: "《回港》？我会拉。明天这个时候，让他站近一点。"),
            .find("musician-find", "昨夜钟响三下时有人喊停船，我想知道后来怎么样了。", question: "去哪儿问最可靠？", [
                ("酒馆里的传言", "传言越传越离谱。"),
                ("去码头随便拉个人问", "夜班的人早下班了。"),
                ("港务登记处的夜班簿，停船都要登记", "登记簿上有时间，也有结果。")], correct: 2,
                  thanks: "登记簿上写着：船停下了，人都上了岸。那就好，我今晚拉一首轻快的。")
        ], stories: [
            "我在这个广场拉了七年琴。钟楼每刻钟响一次，我就把曲子切成一刻钟一段，钟一响刚好换下一首。听的人以为我在跟钟比赛，其实是钟在给我打拍子。",
            "有一年我的琴被人偷了，我在广场上干坐了三天。第四天早上，琴放在我常坐的台阶上，弦全换了新的，没有留名。后来我才知道，是每天听我拉琴的那些人凑钱赎回来的。现在我不收他们的钱。"
        ]),
        .init(id: "cathedral-road", name: "教会跑腿", errands: [
            .deliver("cathedral-road-salve", "教会收留的伤者夜里疼得睡不着。止痛膏能给我一罐吗？", item: salve, count: 1,
                     thanks: "他今晚能睡了。我会在登记簿上写一句：有人送药来。"),
            .message("cathedral-road-message", "替我把这张借阅单交给档案学徒，教会要调一份旧名册。",
                     to: "archive-apprentice-walk", reply: "旧名册？……这一页的纸跟别的不一样。我先抄一份给他，原件留在档案馆。",
                     thanks: "抄本也行，只要能找到他的名字。"),
            .find("cathedral-road-find", "伤者醒了一会儿，只说了一个词：‘桥’。", question: "哪座桥最可能跟他有关？", [
                ("他衣服上的焦油，只有旧港区的吊桥上才有", "焦油是证据，那个词只是提示。"),
                ("离教会最近的石桥", "近不代表有关。"),
                ("每座桥都去问一遍", "太费时间，线索已经够了。")], correct: 0,
                  thanks: "旧港区的吊桥……我去那边的值班室问问，也许有人认得他。")
        ], stories: [
            "我是在教会长大的。修女说我是在台阶上被捡到的，身上只有一块写着日子的布。所以我特别在意登记簿——没写名字的人，就像没来过一样。",
            "那个伤者醒了，自己说出了名字，我亲手写进了登记簿。他说醒来第一眼看见教会的彩窗，还以为自己死了。我告诉他没有，这里只是很多人没地方去时会来的地方。他哭了，我也是。"
        ])
    ]

    /// Neighbours whose own errands and stories are not written yet. They use the shared
    /// requests below, in a different order each, and have no stories.
    public static let unwritten: [(id: String, name: String)] = [
        ("courier", "信使"), ("west-lane", "旧街门牌登记员"), ("cafe-lane", "咖啡馆跑堂"), ("market-lane", "花摊帮工"),
        ("clock-square", "钟楼广场水手"), ("upper-road", "上坡守灯人"), ("south-quay", "港务抄账员"),
        ("flower-seller-walk", "流动花贩"), ("sailor-walk", "离港水手"), ("archive-apprentice-walk", "档案学徒"),
        ("cafe_keeper", "咖啡馆店主"), ("street_warden", "巡街人"), ("scholar", "学者"), ("merchant", "商人"), ("visitor", "旅人")
    ]

    static func slug(_ id: String) -> String { id.replacingOccurrences(of: "_", with: "-") }

    static func shared(_ id: String, rotation: Int) -> [MPCNeighborErrand] {
        let s = slug(id)
        let requests: [MPCNeighborErrand] = [
            .deliver(s + "-strap", "住处的门闩又松了，能帮我带两条维修绑带吗？", item: strap, count: 2, thanks: "扎好了，这门今晚关得上了。"),
            .pest(s + "-pest", "住处后巷有只塔怪，天一黑就在那儿翻东西。", [.moonfang, .copperback], thanks: "清干净了？谢谢你，今晚能睡个安稳觉。"),
            .find(s + "-find", "我丢了钥匙。今天只走过三个地方：歇脚的台阶、一直走的大路、买东西的摊子。", question: "钥匙最可能掉在哪？", [
                ("歇脚的台阶，起身时口袋朝下", "坐下时最容易掉东西。"),
                ("一直走的大路", "走路时口袋是扣着的。"),
                ("买东西的摊子", "摊主说没见过。")], correct: 0, thanks: "找到了，就卡在台阶缝里。"),
            .deliver(s + "-cloth", "窗缝漏盐雾，能给我两块过滤布挡一挡吗？", item: cloth, count: 2, thanks: "挡上了，屋里总算不呛了。"),
            .message(s + "-message", "替我给邮差带句话：这阵子寄给我的信先放在邮局，我自己去取。", to: "postman",
                     reply: "放邮局？行，我给他单独留一格。", thanks: "谢谢，这下不会再丢信了。")
        ]
        let shift = rotation % requests.count
        return Array(requests[shift...] + requests[..<shift])
    }

    public static let all: [MPCNeighbor] = written + unwritten.enumerated().map { index, citizen in
        MPCNeighbor(id: citizen.id, name: citizen.name, errands: shared(citizen.id, rotation: index), stories: [])
    }

    public static func neighbor(_ id: String) -> MPCNeighbor? { all.first { $0.id == id } }
    public static func errand(_ errandID: String) -> (neighbor: MPCNeighbor, errand: MPCNeighborErrand)? {
        for neighbor in all { if let errand = neighbor.errands.first(where: { $0.id == errandID }) { return (neighbor, errand) } }
        return nil
    }

    /// Who asks on a pacing day: two written neighbours in turn, and every third day
    /// one more from the rest. Nobody before day 2.
    public static func askers(day: Int) -> [MPCNeighbor] {
        guard day >= firstDay else { return [] }
        let others = all.filter { !$0.isWritten }
        var result = [written[(2 * day) % written.count], written[(2 * day + 1) % written.count]]
        if day.isMultiple(of: 3), !others.isEmpty { result.append(others[(day / 3) % others.count]) }
        return result
    }

    public static func encounterID(errandID: String, ticket: String) -> String { prefix + errandID + "_" + ticket }
    public static func encounter(id: String) -> MPCEncounterContent? {
        guard let parsed = MPCStreetEncounters.parse(id, prefix: prefix), let found = errand(parsed.key),
              found.errand.kind == .pest else { return nil }
        return MPCStreetEncounters.content(id: id, name: "帮\(found.neighbor.name)赶走塔怪", tag: "errand",
                                           waves: [found.errand.pests], floor: pestFloor)
    }
}

/// One save's errands. Each day's requests replace the last day's (a fight already
/// under way stays until settled); a finished errand pays once.
public struct MPCNeighborLedger: Codable, Equatable, Sendable {
    public enum Failure: Error, Equatable { case notOffered, done, wrongKind, stock, invalidChoice, wrongRecipient, pending, invalidBattle }

    public struct Offer: Codable, Equatable, Sendable, Identifiable {
        public let id: String
        public let day: Int
        public let neighborID: String
        public let errandID: String
        public fileprivate(set) var excludedChoiceIDs: Set<String> = []
        public fileprivate(set) var activeTicket: String?
        public fileprivate(set) var settledTickets: Set<String> = []
        public fileprivate(set) var done = false
        public var errand: MPCNeighborErrand? { MPCNeighborCatalog.errand(errandID)?.errand }
    }
    public struct Reward: Codable, Equatable, Sendable {
        public let copper: Int
        public let thanks: String
        public let affinity: Int
        /// A story unlocked by this errand, if it reached a story level.
        public let story: String?
    }

    public private(set) var day = 0
    public private(set) var offers: [Offer] = []
    public private(set) var affinity: [String: Int] = [:]
    public private(set) var completedErrands = 0
    public init() {}

    /// The stories this neighbour has told so far.
    public func stories(_ neighborID: String) -> [String] {
        guard let neighbor = MPCNeighborCatalog.neighbor(neighborID) else { return [] }
        let level = affinity[neighborID, default: 0]
        return zip(MPCNeighborCatalog.storyAffinity, neighbor.stories).filter { level >= $0.0 }.map(\.1)
    }

    /// Opens a new pacing day's requests. Each neighbour's next errand follows how many
    /// they have had done; goods are asked for only once the workshop is open.
    @discardableResult
    public mutating func open(day: Int, completedMissions: Set<Int>) -> [Offer] {
        guard day > self.day else { return offers }
        self.day = day
        offers = offers.filter { $0.activeTicket != nil }
        let workshop = MPCCraftingCatalog.isUnlocked(completedMissions: completedMissions)
        for neighbor in MPCNeighborCatalog.askers(day: day) {
            let usable = neighbor.errands.filter { workshop || !$0.needsWorkshop }
            guard !usable.isEmpty else { continue }
            let errand = usable[affinity[neighbor.id, default: 0] % usable.count]
            offers.append(.init(id: "d\(day)-" + MPCNeighborCatalog.slug(neighbor.id), day: day, neighborID: neighbor.id, errandID: errand.id))
        }
        return offers
    }

    private func index(_ offerID: String, _ kind: MPCNeighborErrand.Kind) throws -> (Int, MPCNeighborErrand) {
        guard let i = offers.firstIndex(where: { $0.id == offerID }), let errand = offers[i].errand else { throw Failure.notOffered }
        guard !offers[i].done else { throw Failure.done }
        guard errand.kind == kind else { throw Failure.wrongKind }
        return (i, errand)
    }

    private mutating func complete(_ i: Int, _ errand: MPCNeighborErrand, coins: inout Int) -> Reward {
        offers[i].done = true
        let id = offers[i].neighborID
        affinity[id, default: 0] += 1
        completedErrands += 1
        let level = affinity[id]!
        let stories = MPCNeighborCatalog.neighbor(id)?.stories ?? []
        coins += errand.copper
        return .init(copper: errand.copper, thanks: errand.thanks, affinity: level,
                     story: zip(MPCNeighborCatalog.storyAffinity, stories).first { $0.0 == level }?.1)
    }

    public mutating func deliver(offerID: String, coins: inout Int, inventory: inout [String: Int]) throws -> Reward {
        let (i, errand) = try index(offerID, .deliver)
        guard let item = errand.itemID, inventory[item, default: 0] >= errand.count else { throw Failure.stock }
        inventory[item, default: 0] -= errand.count
        return complete(i, errand, coins: &coins)
    }

    /// A wrong answer is struck out at no cost. Returns nil until the right one.
    public mutating func answer(offerID: String, choiceID: String, coins: inout Int) throws -> Reward? {
        let (i, errand) = try index(offerID, .find)
        guard errand.choices.contains(where: { $0.id == choiceID }), !offers[i].excludedChoiceIDs.contains(choiceID) else {
            throw Failure.invalidChoice
        }
        guard choiceID == errand.correctChoiceID else { offers[i].excludedChoiceIDs.insert(choiceID); return nil }
        return complete(i, errand, coins: &coins)
    }

    /// Called when the player talks to `recipientID` with the message in hand.
    public mutating func relay(offerID: String, to recipientID: String, coins: inout Int) throws -> Reward {
        let (i, errand) = try index(offerID, .message)
        guard recipientID == errand.recipientID else { throw Failure.wrongRecipient }
        return complete(i, errand, coins: &coins)
    }

    public mutating func beginPest(offerID: String, ticket: String) throws -> String {
        let (i, errand) = try index(offerID, .pest)
        if let active = offers[i].activeTicket {
            guard active == ticket else { throw Failure.pending }
            return MPCNeighborCatalog.encounterID(errandID: errand.id, ticket: ticket)
        }
        guard MPCStreetEncounters.validTicket(ticket),
              !offers.contains(where: { $0.activeTicket == ticket || $0.settledTickets.contains(ticket) }) else { throw Failure.invalidBattle }
        offers[i].activeTicket = ticket
        return MPCNeighborCatalog.encounterID(errandID: errand.id, ticket: ticket)
    }

    /// Settles the pest fight once; a loss leaves the errand open for another try today.
    public mutating func settlePest(offerID: String, ticket: String, session: MPCChapterOneEncounterSession,
                                    coins: inout Int) throws -> Reward? {
        guard let i = offers.firstIndex(where: { $0.id == offerID }), let errand = offers[i].errand else { throw Failure.notOffered }
        if offers[i].settledTickets.contains(ticket) { return nil }
        guard offers[i].activeTicket == ticket, session.encounter.id == MPCNeighborCatalog.encounterID(errandID: errand.id, ticket: ticket),
              session.outcome != .inProgress else { throw Failure.invalidBattle }
        offers[i].activeTicket = nil
        offers[i].settledTickets.insert(ticket)
        guard session.outcome == .victory, !offers[i].done else { return nil }
        return complete(i, errand, coins: &coins)
    }
}
