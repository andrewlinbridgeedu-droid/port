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
    /// All 23 take turns (`rotation`), so each asks about every nine days: two or three
    /// times in chapter one. Stories come at the second and third finished errand.
    public static let storyAffinity = [2, 3]
    public static let prefix = "church_maintenance_errand_"
    /// Pests are small early bodies: a chore, not a tower fight.
    public static let pestFloor = 10

    static var strap: String { MPCCraftingCatalog.strapID }
    static var salve: String { MPCCraftingCatalog.salveID }
    static var patch: String { MPCCraftingCatalog.patchID }
    static var cloth: String { MPCCraftingCatalog.clothID }

    /// First batch (2026-09-29): eight neighbours with their own errands and two stories each.
    static let firstBatch: [MPCNeighbor] = [
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

    /// Second batch (2026-09-29): the other fifteen, written at the user's request.
    static let secondBatch: [MPCNeighbor] = [
        .init(id: "courier", name: "信使", errands: [
            .pest("courier-pest", "东岸码头的邮筒底下钻进了一只塔怪，信一投进去就被它叼走。", [.copperback, .moonfang],
                  thanks: "邮筒清净了。今天的信一封都没少，我数过。"),
            .message("courier-message", "港务抄账员托我问一句：昨夜那条没敲钟的船，登记上写的是谁的名字？我得赶下一趟，你替我去问。",
                     to: "south-quay", reply: "船主一栏空着，只按了个指印。告诉他：空着的就是空着，我不会替谁补上。",
                     thanks: "空着就好。空着的地方，将来才能填上对的名字。"),
            .deliver("courier-strap", "跑得太急，信袋的背带又断了。两条维修绑带，我付钱。", item: strap, count: 2,
                     thanks: "系紧了。东岸到钟楼，我今天还能跑三趟。")
        ], stories: [
            "我送信从不看内容，只看地址。可有一回，同一个人每周都给同一间屋子写信，那屋子早就空了。我没把信退回去，而是塞进门缝——总得有个地方收着。后来门缝里的信不见了，我到现在也不知道是谁拿走的。",
            "有人出过十个银币，要我把一封信里的船号划掉再送。我没收，把信原样送到了。第二天那人在码头等我，我以为要挨打，他却说：‘我就是想看看，这城里还有没有不收钱的人。’后来他成了我的老主顾。"
        ]),
        .init(id: "west-lane", name: "旧街门牌登记员", errands: [
            .find("west-lane-find", "有人拿着一张旧门牌号来问路：旧街十七号。可旧街的门牌早就重编过了。", question: "旧十七号现在是哪一间？", [
                ("照登记簿上的新旧对照表，是现在的九号", "对照表是换门牌那天一户户核过的。"),
                ("门上还挂着‘17’铁牌的那间", "那块铁牌是后来有人捡去钉上的，不作数。"),
                ("从街口数第十七间", "旧街中间拆过两间屋，按顺序数会数错。")], correct: 0,
                  thanks: "九号。我这就带他过去——对照表总算派上了用场。"),
            .deliver("west-lane-patch", "门牌的铆钉锈断了，一刮风就晃。修甲片的铁皮正好能垫，给我两片。", item: patch, count: 2,
                     thanks: "铆上了。门牌不晃，找门的人就不会走错。"),
            .pest("west-lane-pest", "那间空屋的地窖里有东西在挠门，夜里整条旧街都听得见。", [.moonfang, .crimsonBrute],
                  thanks: "安静了。空屋就该是空的，不该有东西在里面等人。")
        ], stories: [
            "旧街换门牌那年，我挨家挨户记下新旧号码。有个老太太不肯换，说她儿子只认得旧号。我在她门框内侧偷偷刻了个小小的旧号，新的挂在外面。她到走都不知道，我也没说。",
            "你问那间空屋？以前住着一对姐妹，后来搬走了，一个往东，一个往西，走前说好把信都寄到这里。可来的信总是只有一边的。我每月去空屋收一次，攒着。哪天另一边的信也来了，我就知道她们还互相找得到。"
        ]),
        .init(id: "cafe-lane", name: "咖啡馆跑堂", errands: [
            .deliver("cafe-lane-salve", "端咖啡时被壶嘴烫了一下，店主让我别声张。你有止痛膏吗？", item: salve, count: 1,
                     thanks: "好多了。店里的人要是看见我手抖，会以为咖啡太苦。"),
            .message("cafe-lane-message", "店主让我给面包师带句话：明早的牛角包多要一打，今晚有船回港。",
                     to: "baker", reply: "多一打？行。有船回来的晚上，咖啡馆总是坐满。",
                     thanks: "谢了。店主说，回港的人喝第一口咖啡前，得先吃点热的。"),
            .find("cafe-lane-find", "有位客人落下一把伞，伞柄上刻着字，可三个常客都说是自己的。", question: "伞是谁的？", [
                ("说得最急的那位", "着急不说明什么。"),
                ("伞骨里夹着港务处的船期单——是那位抄账的客人", "船期单只有港务处的人随身带。"),
                ("坐得离门最近的那位", "座位每天都会换。")], correct: 1,
                  thanks: "果然是他。他说这伞是他父亲的，丢了要挨骂——都这把年纪了。")
        ], stories: [
            "咖啡馆晚熄灯，是店主定的规矩：只要港口还有一条船没回来，灯就不熄。有时候到半夜只剩我一个人擦杯子，钟一响，我就往窗外看一眼。其实我也不知道自己在等谁。",
            "我是从北边一个没有海的地方来的。第一次听见港口的钟，我以为是着火了。店主笑了半天，教我分辨：长的是开船，短的是回港，还有一种很急很乱的——她说那个我不用记，希望我永远用不上。"
        ]),
        .init(id: "market-lane", name: "花摊帮工", errands: [
            .pest("market-lane-pest", "花摊收工后巷口那几步不是人——我看见了，是塔怪，在翻装花根的筐。", [.goldenThroat, .moonfang],
                  thanks: "原来是它们。我还以为是有人跟着我，吓得三天没敢走那条巷子。"),
            .deliver("market-lane-cloth", "花商要用过滤布给花苗遮盐雾，让我来找你要三块。", item: cloth, count: 3,
                     thanks: "遮好了。花商说今年的紫藤能多开一个月。"),
            .message("market-lane-message", "花商让我跟流动花贩说：旧街的老墙今年剪过了，别再去剪，让它歇一年。",
                     to: "flower-seller-walk", reply: "歇一年？……好。那面墙的花，确实开得累了。",
                     thanks: "她肯听就好。那面墙是花商的宝贝。")
        ], stories: [
            "我来花摊帮工，是因为欠了花商一笔账。说是欠，其实是我娘病的那年，她每天送一束花去我家，从不收钱。后来我娘好了，我就来帮工抵账。她说早就不记得了，可我记得。",
            "巷口的脚步声我怕了很久，后来才知道一半是塔怪，另一半是巡街人。他每晚绕路过来，就为看一眼我们收摊的人是不是都平安回了家。他从没说过，是花商告诉我的。"
        ]),
        .init(id: "clock-square", name: "钟楼广场水手", errands: [
            .message("clock-square-message", "街头乐师那边……替我跟他说，那首《回港》他拉得比我船长哼得还好。别说是我说的。",
                     to: "musician", reply: "他真这么说？……那我明天再拉一遍，拉慢一点。",
                     thanks: "……谢谢。你没说是我吧？"),
            .find("clock-square-find", "我想给船上的老朋友留张字条，可不知道他们回港后先去哪儿。", question: "字条留在哪里，他们最可能看到？", [
                ("港务登记处，回港的船员都要先去销假", "登记是回港第一件事。"),
                ("钟楼底下", "他们不一定路过广场。"),
                ("酒馆门口", "贴在门口会被风吹走。")], correct: 0,
                  thanks: "登记处……对，他们第一件事就是销假。我怎么没想到。"),
            .pest("clock-square-pest", "我每天坐的那张长椅底下，藏着一只塔怪。", [.copperback, .goldenThroat],
                  thanks: "椅子空出来了。我还得在这儿等一阵子。")
        ], stories: [
            "我在等一条船。不是我的船——我的船去年就沉了，只有我一个人游了回来。我等的是船长的弟弟，他在另一条船上，说好回港后请全船的人喝酒。全船只剩我了，我得替大家去喝这一杯。",
            "那天我顺走了花商一束紫藤，放在码头边上。船长生前总说，回港第一眼看见的要是花，就说明这趟没白跑。后来花商知道了，没找我要钱，只是每隔几天，码头边就会多出一束新的。"
        ]),
        .init(id: "upper-road", name: "上坡守灯人", errands: [
            .deliver("upper-road-patch", "上坡的灯柱被货车撞歪了，灯座要两片修甲片垫平。", item: patch, count: 2,
                     thanks: "垫平了。歪着的灯，照得人心里也歪。"),
            .message("upper-road-message", "替我跟东岸提灯人说一声：上坡的灯油，我从下个月起自己买，不用他再分给我了。",
                     to: "east-houses", reply: "他要自己买？……那我把省下的油，添到老钟表铺门口那盏去。",
                     thanks: "他总把自己的油分给别人。这回该轮到他给自己留一点了。"),
            .pest("upper-road-pest", "守卫在上坡开箱，查出一只躲在空箱里的塔怪，箱子一开它就跑了，就躲在灯柱后面。", [.moonfang, .crimsonBrute],
                  thanks: "守卫查箱子，原来是在找它。明天他们能松口气了。")
        ], stories: [
            "上坡的灯比东岸少，只有十九盏，可每一盏都比东岸的高。守卫说，灯高一点，坏人就少一点地方躲。我倒觉得，灯高一点，下坡回家的人能看得远一点。",
            "我和东岸提灯人是同一年学点灯的。师傅说，点灯的人不能怕黑。他怕，我不怕。结果师傅把东岸那条长街给了他——师傅说，怕黑的人才知道每一盏灯有多要紧。"
        ]),
        .init(id: "south-quay", name: "港务抄账员", errands: [
            .find("south-quay-find", "今天的船期单抄错了一行，我得找出是哪条船的。", question: "哪一行最可能抄错？", [
                ("字写得最潦草的那行", "潦草不等于错。"),
                ("最后一行", "错误不挑位置。"),
                ("同一条船出现了两次的那行", "一条船一天只靠一次岸。")], correct: 2,
                  thanks: "果然是重抄了。一条船靠两次岸，账就对不上了。"),
            .deliver("south-quay-strap", "账本散页了，我用维修绑带捆一捆，给我两条。", item: strap, count: 2,
                     thanks: "捆好了。散掉的账本，比撕掉的还难找。"),
            .message("south-quay-message", "替我跟信使说：往后给港务处的信别放门口，直接交到我手上。",
                     to: "courier", reply: "直接交到他手上？行。门口那个信箱，我也觉得不太安全。",
                     thanks: "谢了。这阵子港务处的东西，还是少经几只手的好。")
        ], stories: [
            "抄账是件笨活：别人报数，我记数。可数字会说话。一条船吃水深了，账上的货却少了，多出来的是什么？我不问，我只记。记下来，总有一天会有人来问。",
            "我父亲也在港务处抄账，他的字比我好看得多。他退下来那天，把一支用了三十年的笔交给我，说：‘账可以抄错，改过来就是；但不能抄假。’那支笔我现在只在签年底总账时用。"
        ]),
        .init(id: "flower-seller-walk", name: "流动花贩", errands: [
            .deliver("flower-seller-walk-strap", "花筐的背带断了，我背着花走了一上午。两条维修绑带，救救我的肩膀。", item: strap, count: 2,
                     thanks: "系好了。今天下午能走到东岸去卖。"),
            .find("flower-seller-walk-find", "有人说在旧街看见我偷剪花商的紫藤。我没有。", question: "怎么证明不是她？", [
                ("她说自己没有", "说没有不算证据。"),
                ("她筐里的紫藤带着东岸野坡的红土，不是旧街老墙的灰土", "土不会说谎。"),
                ("花商跟她关系好", "关系好也不能代替证据。")], correct: 1,
                  thanks: "东岸红土……对，我一早去东岸野坡剪的。谢谢你，我不想和花商闹翻。"),
            .pest("flower-seller-walk-pest", "野坡上有只塔怪守着最好的那片紫藤，我不敢靠近。", [.goldenThroat, .crimsonBrute],
                  thanks: "那片花没被踩坏。我剪两枝最好的给你——拿着，不收钱。")
        ], stories: [
            "我没有摊位，背着筐走遍全城。好处是什么都能看见：谁家换了窗帘，谁家的孩子长高了。坏处是没人记得我——大家只记得花。我不介意，花本来就比人好记。",
            "我年轻时在花商的摊子上帮过工，后来吵了一架，自己出来单干。其实那次是我错了。她从没说过我一句坏话，还常把老墙上剪下的花分给我卖。我一直想道歉，可每次走到她摊前，都只买一枝花就走。"
        ]),
        .init(id: "sailor-walk", name: "离港水手", errands: [
            .message("sailor-walk-message", "我明天就走了。替我跟面包师说，给船上留两袋硬面包，钱我放在她门口的罐子里。",
                     to: "baker", reply: "门口罐子？……又放多了。告诉他，面包我装好了，多的钱我塞回袋子里了。",
                     thanks: "她总是这样。算了，到了海上，我替她多吃一块。"),
            .deliver("sailor-walk-salve", "出海前得带一罐止痛膏，船医那儿总是不够。", item: salve, count: 1,
                     thanks: "带上了。有这罐药，我在海上能少骂两句娘。"),
            .pest("sailor-walk-pest", "我的行李在码头仓库，里面钻进了一只塔怪，我不敢去拿。", [.copperback, .copperback],
                  thanks: "行李保住了。里面有我娘缝的毯子，丢了我就不走了。")
        ], stories: [
            "每次离港前，我都要在码头上站一会儿，把城里的声音记下来：钟声、面包师的炉门、乐师的琴。海上太安静，想家的时候，我就在脑子里放一遍。",
            "有人问我为什么总要走。其实我不是想走，是怕留下来就再也走不动了。我爹一辈子没离开过雾港，临走前跟我说，他最后悔的是没看过一次别处的日出。我替他看，一年看两次。"
        ]),
        .init(id: "archive-apprentice-walk", name: "档案学徒", errands: [
            .find("archive-apprentice-walk-find", "档案馆一卷旧名册里，有一页的装订孔和别的页对不上。", question: "这说明什么？", [
                ("这一页是后来补装进去的，先查补装记录", "孔对不上只说明是后来装的，不说明是假的。"),
                ("这一页是伪造的", "没查记录就说伪造，会冤枉人。"),
                ("装订工手抖", "别的页都对得上。")], correct: 0,
                  thanks: "补装记录里写着：那年大水泡坏过一页，照原稿重抄的。差点冤枉了人。"),
            .deliver("archive-apprentice-walk-cloth", "档案柜防潮要垫布，过滤布最合适，给我两块。", item: cloth, count: 2,
                     thanks: "垫上了。纸最怕潮，比怕火还怕。"),
            .pest("archive-apprentice-walk-pest", "档案馆地下室有只塔怪在啃旧卷宗，我一个人不敢下去。", [.moonfang, .goldenThroat],
                  thanks: "卷宗只啃坏了两个角，我会照着副本补回来。")
        ], stories: [
            "我进档案馆是因为字写得工整。第一年只让我抄目录，一个字都不许错。我抄错过一次，老档案员没骂我，只让我把那一整本重抄一遍。现在我抄东西，比吃饭还慢。",
            "档案里最多的不是大事，是小事：谁家添了孩子，谁家的船回来了。老档案员说，大事自有人记，小事没人记就真没了。所以我每天下班前，会多记一件街上的小事，写在我自己的本子里。"
        ]),
        .init(id: "cafe_keeper", name: "咖啡馆店主", errands: [
            .deliver("cafe-keeper-strap", "咖啡豆麻袋的口绳烂了，给我三条维修绑带扎口。", item: strap, count: 3,
                     thanks: "扎紧了。受潮的豆子，煮出来一股海腥味。"),
            .message("cafe-keeper-message", "替我跟跑堂说：今晚他可以早点回去，灯我来守。",
                     to: "cafe-lane", reply: "早点回去？……不了，我陪店主。一个人守灯太闷。",
                     thanks: "这孩子。那就两个人守吧，我给他留一杯热的。"),
            .find("cafe-keeper-find", "店招被人挪了位置，客人都找不到门了。", question: "该挂回哪里？", [
                ("挂得越高越好", "太高了路人看不见。"),
                ("看墙上留下的钉孔和晒出的浅色印子", "晒出的印子就是原来的位置。"),
                ("挂到隔壁门口", "那是别人家的门。")], correct: 1,
                  thanks: "挂回去了。客人说一看见招牌，就知道今晚有地方坐。")
        ], stories: [
            "这间咖啡馆是我母亲开的。她定下规矩：港口还有船没回来，灯就不熄。我小时候嫌这规矩傻，现在自己守着才明白，她不是在等船，是在让船上的人知道，岸上有人在等。",
            "有些客人来了从不点东西，只坐着听钟。我从不赶他们。有一回一位老人坐到天亮，走前在桌上留了一枚旧船徽。后来我才知道，那天是他儿子的船沉没十年的日子。船徽我一直挂在吧台后面。"
        ]),
        .init(id: "street_warden", name: "巡街人", errands: [
            .pest("street-warden-pest", "巷子里有两只塔怪，我一个人拦得住一只，拦不住两只。", [.crimsonBrute, .moonfang],
                  thanks: "两只都清了。你出手比我的警哨管用。"),
            .deliver("street-warden-patch", "警哨的铜片磨穿了，吹不响。给我一片修甲片，我自己剪。", item: patch, count: 1,
                     thanks: "能吹响了。巡街的人没有哨子，就像灯没有油。"),
            .message("street-warden-message", "替我跟花摊帮工说一声：往后收摊晚了别怕，那条巷子我每晚都会绕过去。",
                     to: "market-lane", reply: "……原来每天晚上那个脚步是他。替我谢谢他，就说我以后不绕远路了。",
                     thanks: "不绕远路就好。怕黑的人一绕路，就会走到更黑的地方去。")
        ], stories: [
            "我巡街二十年，最怕的不是塔怪，是谣言。塔怪看得见，谣言看不见，一传十、十传百，冤枉的人一辈子洗不清。所以我从不在街上乱说话，要说，就对着正式的卷宗说。",
            "我年轻时抓错过一个人。他被关了三天，放出来那天没骂我，只说了一句：‘下次看清楚点。’从那以后，我每抓一个人，都要先看三遍。看三遍，街上的人才信得过巡街的。"
        ]),
        .init(id: "scholar", name: "学者", errands: [
            .find("scholar-find", "我手上有两份抄本，内容一样，我想知道哪份更早。", question: "看什么最能分出先后？", [
                ("看哪份纸更旧", "纸可以做旧。"),
                ("看哪份字更好", "字好不说明先后。"),
                ("看后一份有没有照抄前一份的笔误", "照抄的错误会一代代传下去。")], correct: 2,
                  thanks: "后一份把前一份的笔误也抄了。先后清楚了——错也有它的用处。"),
            .deliver("scholar-salve", "我在书堆里熬了三夜，手腕疼得握不住笔。有止痛膏吗？", item: salve, count: 1,
                     thanks: "能握笔了。学问不等人，手腕却要人等。"),
            .message("scholar-message", "替我把这张借条交给档案学徒，我想借那卷补装过的旧名册看看。",
                     to: "archive-apprentice-walk", reply: "那卷？……可以，但只能在馆里看，不能带出去。告诉他，我给他留靠窗的位子。",
                     thanks: "靠窗的位子。这孩子懂规矩，也懂人。")
        ], stories: [
            "我研究印章，是因为一枚章能说出很多话：谁盖的，用了多大力，章面磨到了哪一步。人会说谎，章不会。可章也会被人拿去替别人说谎——所以光看章还不够，还得看人。",
            "我这辈子写过三本书，一本也没卖出去。我不在意。书写出来，就放在档案馆里，总有一天会有人需要它。上个月档案学徒说，有人借过我的第二本。我高兴了一整个星期。"
        ]),
        .init(id: "merchant", name: "商人", errands: [
            .deliver("merchant-patch", "货箱的铁角磕坏了，用修甲片补上，给我三片。", item: patch, count: 3,
                     thanks: "补好了。箱子体面，货就好卖一半。"),
            .find("merchant-find", "我进的一批布少了一匹，三个伙计说法不一。", question: "少的那匹最可能在哪里？", [
                ("对一对入库单和出货单，看哪一天的数没对上", "账对不上的那天，就是丢的那天。"),
                ("先搜伙计的身", "没有证据就搜人，是冤枉人。"),
                ("算了，当作损耗", "该查的要查清。")], correct: 0,
                  thanks: "是出货那天多装了一匹给老主顾。账对清了，谁也没冤枉。"),
            .pest("merchant-pest", "仓库里有只塔怪在啃布匹，伙计们都不敢进去。", [.moonfang, .copperback],
                  thanks: "布只啃坏了一匹。工钱照原价算，一分不少。")
        ], stories: [
            "我做买卖三十年，只有一条规矩：货要认得，账要清楚。运货的人我不一定认得，所以每批货我都亲手点一遍。别人说我多疑，我说这叫对得起买家。",
            "年轻时我亏过一大笔，赔光了家底。是面包师的父亲赊给我一个月的面包，让我撑了过来。他没立字据，只说：‘你以后别让别人饿着就行。’所以现在城里谁家揭不开锅，我都会悄悄送一袋面粉过去。"
        ]),
        .init(id: "visitor", name: "旅人", errands: [
            .message("visitor-message", "我想给家里寄封信，可不知道雾港的邮差在哪儿。你替我把信交给他吧。",
                     to: "postman", reply: "外地的信？寄到南边的……好，明早第一趟船就带走。",
                     thanks: "谢谢。家里人会高兴的，我写了三页，全是这座城。"),
            .find("visitor-find", "我迷路了，只记得旅店门口有一棵紫藤，傍晚回去时，钟楼的影子正好落在门口台阶上。", question: "旅店最可能在哪儿？", [
                ("旧街，那里紫藤多", "紫藤到处都有，不能指路。"),
                ("钟楼广场边上——影子能落到门口的只有那几间", "影子比紫藤可靠。"),
                ("东岸", "东岸离钟楼太远，影子落不过去。")], correct: 1,
                  thanks: "找到了！门口的紫藤还在，老板娘以为我被海浪卷走了。"),
            .pest("visitor-pest", "我想去旧港区看看，可路口有只塔怪拦着，我不敢过去。", [.crimsonBrute, .goldenThroat],
                  thanks: "路通了。……旧港区其实没那么可怕，就是太安静了。")
        ], stories: [
            "我是来找祖父出生的房子的。他走前说，雾港的钟声和别处不一样，一听就知道到家了。我下船第一天就听见了——他说得对。可那房子，我到现在还没找到。",
            "我在旧街门牌登记员那里查到了：祖父家原来的门牌，现在是一间仓库。仓库的主人听说了，让我进去站了一会儿。墙角还留着一道量身高的刻痕，旁边刻着一个名字——是我祖父的。"
        ])
    ]

    /// Asking order: districts and kinds interleave, and each day's askers are the next two
    /// or three in this cycle. The musician stays twelfth (first asks on day 7, a pest).
    public static let rotation = [
        "postman", "west-lane", "baker", "cafe-lane", "east-houses", "courier", "clockmaker", "market-lane",
        "florist", "clock-square", "dockworker", "south-quay", "musician", "upper-road", "cathedral-road",
        "flower-seller-walk", "sailor-walk", "archive-apprentice-walk", "cafe_keeper", "street_warden",
        "scholar", "merchant", "visitor"
    ]

    public static let all: [MPCNeighbor] = rotation.map { id in (firstBatch + secondBatch).first { $0.id == id }! }
    /// Every neighbour now has their own errands and stories.
    public static var written: [MPCNeighbor] { all.filter(\.isWritten) }

    static func slug(_ id: String) -> String { id.replacingOccurrences(of: "_", with: "-") }

    public static func neighbor(_ id: String) -> MPCNeighbor? { all.first { $0.id == id } }
    public static func errand(_ errandID: String) -> (neighbor: MPCNeighbor, errand: MPCNeighborErrand)? {
        for neighbor in all { if let errand = neighbor.errands.first(where: { $0.id == errandID }) { return (neighbor, errand) } }
        return nil
    }

    /// How many ask on a pacing day: two, three on every third day, nobody before day 2.
    public static func askerCount(day: Int) -> Int { day < firstDay ? 0 : day.isMultiple(of: 3) ? 3 : 2 }

    /// Who asks on a pacing day: the next neighbours in `rotation`, so everyone takes turns.
    public static func askers(day: Int) -> [MPCNeighbor] {
        let count = askerCount(day: day)
        guard count > 0 else { return [] }
        let start = (firstDay..<day).reduce(0) { $0 + askerCount(day: $1) }
        return (0..<count).map { all[(start + $0) % all.count] }
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
    /// Close an abandoned attempt once; today's request remains available to retry.
    public mutating func abandonPest(offerID: String, ticket: String) {
        guard let i = offers.firstIndex(where: { $0.id == offerID }), offers[i].activeTicket == ticket else { return }
        offers[i].activeTicket = nil
        offers[i].settledTickets.insert(ticket)
    }

}
