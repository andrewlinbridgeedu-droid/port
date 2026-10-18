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
    /// Rewritten 2026-10-18 (STORY_HUMAN_REWRITE_DRAFT_20261018.md §三): each neighbour keeps one
    /// voice and one private sorrow that the two stories let out; the errands are unchanged.
    static let firstBatch: [MPCNeighbor] = [
        .init(id: "postman", name: "邮差", errands: [
            .message("postman-letter", "这封写着‘旧街门牌登记员收’。我还剩半条街，膝盖又不听话。你替我跑一趟——别折，别揣裤兜里。",
                     to: "west-lane", reply: "又是那间空屋的。放下吧，我替她收着。跟邮差说，地址没写错。",
                     thanks: "送到了？好。这封信没在我包里过夜，我今晚睡得着。"),
            .pest("postman-pest", "邮包在钟楼广场落了地，一只塔怪叼了就跑，这会儿蹲在排水口边上啃信封。我追了半条街，它还冲我龇牙。", [.copperback, .moonfang],
                  thanks: "湿了，字还认得。这一包是整条街的工钱单，丢了我得挨家挨户去赔笑脸。"),
            .deliver("postman-strap", "背带磨断了，邮包一路往下坠，我拿麻绳将就了三天，丢人。有维修绑带的话，给我两条。", item: strap, count: 2,
                     thanks: "扎紧了。明天我又能比钟楼早到一刻。")
        ], stories: [
            "地址写不清的信，别人退回去了事，我不退。我拆开看落款，再一条街一条街地问。同事笑我多管闲事。你知道一封信在邮局最底下的抽屉里能躺多少年吗？我知道。最久那封躺了九年。",
            "二十岁那年，我包里有封信，信封上写着‘急’。那天码头放烟火，我想看完再送。第二天一早送到，那家的人已经上船了。信里就三个字：别上船。我后来再没看过烟火。"
        ]),
        .init(id: "east-houses", name: "东岸提灯人", errands: [
            .deliver("east-houses-cloth", "灯罩的纱网叫盐雾蚀穿了，风一吹就灭。灭一盏，那一段就黑了。给我两块过滤布，我自己缝。", item: cloth, count: 2,
                     thanks: "新纱透光，也挡风。今晚这条街黑不了。"),
            .find("east-houses-find", "昨晚三号灯柱提前灭了。我站在底下，四周黑得……总之，我得知道是谁弄灭的。", question: "看灯柱下的痕迹，灯是怎么灭的？", [
                ("有人故意吹灭的", "灯罩扣得严严的，吹不灭。"),
                ("灯油烧完了", "油壶还剩一半。"),
                ("灯罩内壁有一道舔过的油痕，是小塔怪爬上去偷灯油", "油痕一路拖到排水沟，不是人手。")], correct: 2,
                  thanks: "原来是馋油的小东西。不是人就好。我明天在灯柱上抹一圈盐。"),
            .pest("east-houses-pest", "三号灯柱底下有东西在啃灯芯，咔哧咔哧的。我拿长杆够不着，也……不太想凑近。", [.moonfang, .goldenThroat],
                  thanks: "灯芯保住了。你站在灯下那会儿，影子比我的还长，挺好。")
        ], stories: [
            "我怕黑。点灯的人怕黑，说出去要被人笑的。所以四十一盏灯，我从码头一路点上坡，嘴里一直哼歌。点亮一盏，往前走一段，身后就亮一段。这事别跟上坡那位说。",
            "钟表铺门口那盏灯，是我自己出钱添的。老钟表匠说他天黑看不清钥匙孔。有一晚下大雨，我想少一盏不要紧，就没去。第二天才听说，他在台阶上摔了。那年冬天他走了。现在那盏灯，我第一个点。"
        ]),
        .init(id: "baker", name: "面包师", errands: [
            .deliver("baker-salve", "揉面时让炉门亲了一口，手背起了个泡。别笑。有止痛膏吗？一小罐就够。", item: salve, count: 1,
                     thanks: "凉下来了。明早的面包照样出炉——它们可不管我手疼不疼。"),
            .pest("baker-pest", "仓房里有东西偷面粉，专挑细面，袋子底下一串小牙印。我不是不敢进去，我是……忙。", [.moonfang, .moonfang],
                  thanks: "月牙鼠？难怪那么挑嘴。拿两个刚出炉的圆面包，别推，推了我不高兴。工钱照付。"),
            .message("baker-message", "码头那个大个子昨天订了一袋硬面包，到现在没来拿。你去问问他还要不要。不要也得给句话。",
                     to: "dockworker", reply: "要！船期推了一天，我给忘了。跟她说我明早天不亮就到，别卖给别人。",
                     thanks: "就知道。我给他留着，再塞一块黑麦的，他吃到才会知道。")
        ], stories: [
            "我爹做了一辈子面包。最后两年他手抖，揉不动面，就坐在炉子边看我揉。揉错了也不说，只伸手把火调小一点。他走的那天早上，炉子是我生的。火候刚好。他没看见。",
            "我爹的账本我还留着。赊出去的都划掉了，只剩一页：一个年轻人，一个月的面包。那人如今是街上最有钱的商人，见了我点个头，从来不提。我也不提。我就等着，看他哪天自己想起来。"
        ]),
        .init(id: "clockmaker", name: "钟表匠", errands: [
            .deliver("clockmaker-patch", "钟台的齿轮垫片磨薄了，修甲片的钢刚好合用。给我两片。照工坊价，我不占人便宜，也不让人占我的。", item: patch, count: 2,
                     thanks: "垫上了。你听，这一声‘嗒’比昨天清楚吧？……你说清楚，那就是清楚了。"),
            .find("clockmaker-find", "我门口的钟快了七分钟。有人动过它，我要知道是谁。七分钟，够一个人误一条船。", question: "谁动了钟？", [
                ("钟壳里有树蛙的黏液，是它钻进去碰动了齿轮", "黏液还挂在齿缝里。"),
                ("隔壁的孩子", "孩子踮起脚也够不着钟面。"),
                ("钟自己坏了", "坏钟只会走慢，不会自己快七分钟。")], correct: 0,
                  thanks: "又是树蛙。我还以为是哪个嫌我的钟走得慢的。得给钟壳加道网。"),
            .pest("clockmaker-pest", "钟台底座里住进了几只金喉树蛙，一到整点就跟着叫。客人以为我的钟走调了，这比咬人还要命。", [.goldenThroat, .goldenThroat],
                  thanks: "安静了。整点只剩钟声，这才像话。")
        ], stories: [
            "我右耳去年就不太灵了。修钟靠听，一个聋了半边的钟表匠，传出去这铺子就完了。所以我总让客人替我听：‘你听，这声清楚吧？’他们说清楚，我就收钱。你也替我听过。别说出去。",
            "这铺子是我在拍卖行拍下的，便宜得像捡的。老店主没有后人，柜里留着一排没修完的钟，每只都贴着条子。我一只一只修好，挂在墙上走。门口那个提灯人，每晚头一个点我家门前的灯。他以为我不知道为什么。"
        ]),
        .init(id: "dockworker", name: "码头工人", errands: [
            .deliver("dockworker-strap", "货箱的绑绳一天断三根。你做的维修绑带结实，给我三条。货要是散在栈桥上，工头扣的是我的钱。", item: strap, count: 3,
                     thanks: "捆得住了。工头问起，我说是你做的。他不信，我说你自己去问。"),
            .pest("dockworker-pest", "货堆里钻进一只铜背甲兽，把一整排货箱当了窝。我拿钩子捅它，钩子差点叫它咬断——那是我哥的钩子。", [.copperback, .shieldJaw],
                  thanks: "箱子上全是爪印，货没丢，钩子也没事。你这一趟顶我半天工钱。"),
            .message("dockworker-message", "把这张工钱条子交给港务抄账员，上个月少记了我两天。别跟他吵，他胆小，一吵就结巴。",
                     to: "south-quay", reply: "两、两天……对上了，就是撕掉的那两页。我补记上，下回发工钱一起算。不、不是我撕的。",
                     thanks: "补上就行。那点钱我不在乎——我在乎账上有我干过的活。")
        ], stories: [
            "码头上的人都会看吃水线。船进港压多深，就知道装了多少货。所以哪条船的封条被人动过，我们心里都有数。没人说。说了，明天就没有船肯雇你。别这么看我，我家里还有人要吃饭。",
            "三年前东仓那场火，码头封了一个月，没活干。我哥上了一条去外海的船，走前把钩子塞给我：‘回来再要。’钩子我天天用，磨得比他走时还亮。那条船回来过两趟。他不在上面。"
        ]),
        .init(id: "florist", name: "花商", errands: [
            .find("florist-find", "有人从我摊上顺走一束紫藤，钱也没放，只留了个泥脚印。几个铜我不在乎，我在乎有人当我好欺负。", question: "顺走花的人往哪去了？", [
                ("花瓣落在旧街口，往旧街去了", "花瓣会被风吹着走，指不了路。"),
                ("脚印沾着钟楼广场特有的青苔泥，往钟楼去了", "泥比花瓣老实。"),
                ("往码头去了，买花送船上的人", "没有凭据，只是猜。")], correct: 1,
                  thanks: "钟楼……是那个天天坐长椅的水手吧。算了。那束花，就当我送他的。别告诉他。"),
            .deliver("florist-cloth", "包花的纱纸用完了。过滤布细，给我两块，我拿来裹花根。纸可以将就，花根不能。", item: cloth, count: 2,
                     thanks: "裹上湿布能撑到明天。我不卖蔫花，这是我娘定的规矩。"),
            .pest("florist-pest", "花摊后面的水桶让一只塔怪占了，它拿我的紫藤当褥子睡。那是今早刚剪的。", [.goldenThroat, .moonfang],
                  thanks: "压坏了几枝，不要紧，明年还开。人没伤着就好。")
        ], stories: [
            "我卖的紫藤都是旧街那面老墙上剪的。墙后那间空屋，是我小时候的家。我爹欠了债，房子抵了出去。我剪花前总要敲两下墙。别人当我迷信。其实我只是想说一声：我回来了。",
            "流动花贩以前在我摊上帮工。走那天，她说我卖花像施舍。我回了她一句更难听的，现在想起来脸还烫。她如今路过，只买一枝就走。我每回都多包一片叶子。我们谁也不先开口。"
        ]),
        .init(id: "musician", name: "街头乐师", errands: [
            .pest("musician-pest", "广场排水沟里有只金喉树蛙，我一拉琴它就跟着叫，还跑调。人家以为跑调的是我。", [.goldenThroat, .copperback],
                  thanks: "安静了。现在跑调的只剩我自己，起码是我自己的调。"),
            .message("musician-message", "钟楼广场那个水手天天听我拉琴，从不点歌，也从不扔钱。替我问问他到底想听什么。别说我嫌他不给钱。",
                     to: "clock-square", reply: "……《回港》。以前我们船长爱哼这首。别说是我点的。还有，我没钱。",
                     thanks: "《回港》？我会。明天这个时候让他站近点，别老躲在柱子后面。"),
            .find("musician-find", "昨夜钟敲三下的时候，有人在码头喊停船，嗓子都喊劈了。后来怎么样了，我一夜没睡着。", question: "去哪儿问最靠得住？", [
                ("酒馆里的传言", "传言越传越邪乎。"),
                ("去码头随便拉个人问", "夜班的人早回家睡了。"),
                ("港务登记处的夜班簿，停船都要登记", "登记簿上有时辰，也有下文。")], correct: 2,
                  thanks: "‘船已停，人都上了岸。’那就好。我今晚拉首轻快的，给那个喊停船的人。")
        ], stories: [
            "我在这广场拉了七年琴，从没拉完过一整首。钟每一刻响一次，我就换一首。大家以为我在跟钟较劲。其实是后半段我记不住。我师父还没教完，就跟人跑了。",
            "有一年琴被人偷了，我在台阶上干坐了三天。第四天早上，琴回来了，弦全换了新的，没留名。后来才知道，是天天听我拉琴的那些人凑钱赎的。从那以后我不收他们的钱。他们照样往琴盒里扔东西：扣子、糖、半个梨。"
        ]),
        .init(id: "cathedral-road", name: "教会跑腿", errands: [
            .deliver("cathedral-road-salve", "教会收留的伤者夜里疼得睡不着，一直数天花板上的裂缝。止痛膏能给我一罐吗？我记在簿子上。", item: salve, count: 1,
                     thanks: "他今晚能睡了。我在簿子上写：某日，有人送药来。你愿意的话，名字我也写上。"),
            .message("cathedral-road-message", "替我把这张借阅单交给档案学徒，教会要调一份旧名册。那个伤者说不全自己的名字，我想在册子里找找。",
                     to: "archive-apprentice-walk", reply: "旧名册？……这一页的纸跟别的不一样。我先抄一份给他，原件不能出馆。",
                     thanks: "抄本也好。只要能找到他的名字，抄本我也当原件供着。"),
            .find("cathedral-road-find", "伤者醒了一会儿，只说了一个字：‘桥’，又睡过去了。我得替他把后半句找回来。", question: "哪座桥最可能跟他有关？", [
                ("他衣服上的焦油，只有旧港区的吊桥上才有", "焦油是凭据，那个字只是提示。"),
                ("离教会最近的石桥", "近不等于有关。"),
                ("每座桥都去问一遍", "线索已经够了，不用满城跑。")], correct: 0,
                  thanks: "旧港区的吊桥……我去那边值班室问。也许有人在等他回家，等了很久了。")
        ], stories: [
            "修女说，我是在台阶上被捡到的。身上裹着一块布，布角写着一个日子，没有名字。所以我在意登记簿。名字写下来，人就算来过。没写下来，哪天不见了，连少了谁都说不清。",
            "三年前码头起火那夜，我在避难所门口拿着名册放人。规矩是册上没有的不能进。有个抱孩子的女人，名字不在上面。我照规矩说了‘不行’。她没跟我吵，转身走进雨里。现在不管谁来，我都先让人进门，名字以后再写。"
        ])
    ]

    /// Second batch (2026-09-29): the other fifteen, written at the user's request.
    static let secondBatch: [MPCNeighbor] = [
        .init(id: "courier", name: "信使", errands: [
            .pest("courier-pest", "东岸码头的邮筒底下钻进一只塔怪，信一投进去就被它叼走。我跑得再快，也快不过一张嘴。", [.copperback, .moonfang],
                  thanks: "邮筒干净了。今天的信一封没少，我数了两遍。"),
            .message("courier-message", "有位船主出钱让我打听：昨夜那条没敲钟的船，登记上写的谁的名字。我得赶下一趟，你替我去问问抄账员。",
                     to: "south-quay", reply: "船主那一栏空着，只按了个指印。告诉她：空着就是空着，谁出钱我也不、不替谁补。",
                     thanks: "空着啊。那位船主要不高兴了。……我倒挺高兴。"),
            .deliver("courier-strap", "跑太急，信袋的背带又断了。两条维修绑带，我付钱。别跟我讲交情，交情最贵。", item: strap, count: 2,
                     thanks: "系紧了。东岸到钟楼，我今天还能跑三趟。")
        ], stories: [
            "有人出过十个银币，让我把一封信里的船号划掉再送。我没收，原样送到了。别人都说我有骨气。我没跟人说过：那天夜里我一直在想，他要是出一百个呢？我到现在也不知道。",
            "码头边有个老太太，每月托我给外海的儿子寄一封信。我跟人说她每封付我两个铜。其实她一个铜也没付过。她儿子也一封都没回过。我还是每月送。别说出去，我这行，好说话的人活不长。"
        ]),
        .init(id: "west-lane", name: "旧街门牌登记员", errands: [
            .find("west-lane-find", "有人拿着一张旧门牌来问路：旧街十七号。门牌重编以后旧号就不作数了，可来问的人不知道。", question: "旧十七号现在是哪一间？", [
                ("照登记簿上的新旧对照表，是现在的九号", "对照表是换牌那天一户一户核过的。"),
                ("门上还挂着‘17’铁牌的那间", "那块铁牌是后来有人捡去钉上的，不作数。"),
                ("从街口数第十七间", "旧街中间拆过两间屋，一数就错。")], correct: 0,
                  thanks: "九号。我带他过去。对照表我抄了三个晚上，总算有人用上了。"),
            .deliver("west-lane-patch", "门牌的铆钉锈断了，一刮风就晃得叮当响。修甲片的铁皮正好能垫，给我两片。门牌歪一寸，人就找错一家。", item: patch, count: 2,
                     thanks: "铆上了，不晃了。找门的人，总算能少走一段冤枉路。"),
            .pest("west-lane-pest", "那间空屋的地窖里有东西在挠门，整夜整夜地挠，旧街的人都睡不着。我也睡不着，不过我本来就睡不着。", [.moonfang, .crimsonBrute],
                  thanks: "安静了。空屋就该是空的，不该有东西在里面等。")
        ], stories: [
            "换门牌那年，有个老太太不肯换，说她儿子只认得旧号。规矩不许留旧牌。我把新牌挂在外面，在她门框里侧刻了个小小的旧号。她到走都不知道。干这行，我就这一回没照规矩。",
            "那间空屋原来住着一对姐妹，后来一个往东，一个往西，说好把信都寄回这里。来的信总是东边那个的。西边那个，我托人查过，前年冬天就没了。东边的还不知道，每月照样写。信我都收着，一封没拆，也一封没回。"
        ]),
        .init(id: "cafe-lane", name: "咖啡馆跑堂", errands: [
            .deliver("cafe-lane-salve", "端咖啡时让壶嘴烫了一下。店主说别声张，客人看见了倒胃口。你有止痛膏吗？我不疼，就是手有点不听使唤。", item: salve, count: 1,
                     thanks: "好多了。客人要是看见我手抖，会以为咖啡太苦。"),
            .message("cafe-lane-message", "店主让我给面包师带句话：明早的牛角包多要一打，今晚有船回港。我走不开，你帮我跑一趟？",
                     to: "baker", reply: "多一打？行。有船回来的晚上，咖啡馆总是坐满。跟那孩子说，别跑，面包又不会飞。",
                     thanks: "谢了。店主说，回港的人喝第一口咖啡前，得先吃点热乎的。"),
            .find("cafe-lane-find", "有位客人落下一把伞，伞柄上刻着字，三个常客都说是自己的。我要是再弄错，店主要扣我工钱。", question: "伞是谁的？", [
                ("说得最急的那位", "急不说明什么。"),
                ("伞骨里夹着港务处的船期单——是那位抄账的客人", "船期单只有港务处的人随身带。"),
                ("坐得离门最近的那位", "座位天天换。")], correct: 1,
                  thanks: "果然是他。他说这伞是他爹的，丢了要挨骂。他头发都白了一半。")
        ], stories: [
            "我从北边来，那儿没有海。头一回听见港口的钟，我以为着火了。店主笑我，教我分：长的是开船，短的是回港。还有一种又急又乱的，她说不用学。后来我才知道，她最后一次听见那种钟，是三年前码头起火那夜。",
            "我每月往家里写信，说我在大饭店当领班，手底下管着二十个人。其实我连托盘都端不稳。我娘把信念给全村听，邻居家的孩子说长大也要来雾港。我不知道怎么跟他们说。下一封，我打算说我升了。"
        ]),
        .init(id: "market-lane", name: "花摊帮工", errands: [
            .pest("market-lane-pest", "收摊以后，巷口总有脚步声跟着我。我壮着胆子回头看了——是塔怪，在翻装花根的筐。……我还以为是人。", [.goldenThroat, .moonfang],
                  thanks: "原来是它们。我吓得三天没敢走那条巷子，绕了好远的路。"),
            .deliver("market-lane-cloth", "花商要拿过滤布给花苗遮盐雾，让我来找你要三块。她说你的布密，别家的不行。", item: cloth, count: 3,
                     thanks: "遮好了。花商说今年的紫藤能多开一个月。她说这话的时候在笑，难得。"),
            .message("market-lane-message", "花商让我跟流动花贩说：旧街老墙今年剪过了，别再去剪，让它歇一年。她说就说这个，别的不用说。",
                     to: "flower-seller-walk", reply: "歇一年？……好。那面墙确实开累了。她还说别的了吗？没有啊。好。",
                     thanks: "她肯听就好。那面墙，花商宝贝得很。")
        ], stories: [
            "我娘病的那年，花商每天送一束花到我家，一个铜也不收。后来我娘好了，我就来帮工抵账。花商说她早忘了。可她每回见到我娘，都要问一句‘还咳吗’。忘了的人，不会问这个。",
            "我偷拿过摊上一枝花，想插在我娘床头。第二天，花商往我手里多塞了一枝，说是剩的。花摊的花从来不剩，我知道。我到现在也没跟她认这个错。她也一直没提。"
        ]),
        .init(id: "clock-square", name: "钟楼广场水手", errands: [
            .message("clock-square-message", "街头乐师那边……替我跟她说，那首《回港》她拉得比我们船长哼得好。别说是我说的。说了我就不去广场了。",
                     to: "musician", reply: "他真这么说？……那我明天再拉一遍，拉慢一点。告诉他，躲在柱子后面听不清的。",
                     thanks: "……谢了。你没说是我吧？"),
            .find("clock-square-find", "我想给船上的老伙计留张字条，可不知道他们回港先去哪儿。我总不能天天在码头上站着。", question: "字条留在哪儿，他们最可能看到？", [
                ("港务登记处，回港的船员都要先去销假", "销假是回港第一件事。"),
                ("钟楼底下", "他们不一定路过广场。"),
                ("酒馆门口", "贴在门口，一阵风就没了。")], correct: 0,
                  thanks: "登记处……对，第一件事就是销假。我自己也销过的，怎么就忘了。"),
            .pest("clock-square-pest", "我天天坐的那张长椅底下，藏着一只塔怪。我不是怕它，是它占了我的位子。", [.copperback, .goldenThroat],
                  thanks: "椅子空出来了。我还得在这儿等一阵子。")
        ], stories: [
            "我在等一条船，不是我的船。我的船去年沉了，只有我一个人游回来。我等的是船长的哥哥，他在另一条船上跑远洋。船长说过，回港了全船去他哥那儿喝酒。现在全船就剩我了，这杯酒，我得替他们喝。",
            "你知道我为什么活下来吗？那晚我喝多了，在甲板上睡着了。船翻的时候，他们都在舱里。我水性好，可一个也没拉上来。有人说我命大。这话我从来不接。"
        ]),
        .init(id: "upper-road", name: "上坡守灯人", errands: [
            .deliver("upper-road-patch", "上坡的灯柱被货车撞歪了，灯座得用两片修甲片垫平。东岸那位的灯从没歪过——他那条街不走货车。", item: patch, count: 2,
                     thanks: "垫平了。歪着的灯，照得人心里也歪。"),
            .message("upper-road-message", "替我跟东岸提灯人说一声：上坡的灯油，从下个月起我自己买，不用他再分了。就这么说，别添别的。",
                     to: "east-houses", reply: "他要自己买？……好。那我把省下的油，添到老钟表铺门口那盏去。替我问问他，膝盖好些没有。",
                     thanks: "问我膝盖？……他总这样。这回该轮到他给自己留一点了。"),
            .pest("upper-road-pest", "守卫在上坡开箱查货，一只塔怪从空箱里蹿出来，躲到灯柱后头去了。守卫追不上，我追不动。", [.moonfang, .crimsonBrute],
                  thanks: "守卫查箱子，原来是在找它。明天他们能松口气了，我也能。")
        ], stories: [
            "上坡的灯比东岸少，只有十九盏，可每一盏都比东岸的高。守卫说，灯高一点，坏人就少一处躲。我不这么想。灯高一点，下坡回家的人能看得远一点。这话我没跟守卫说，他不爱听。",
            "我跟东岸那位同一年学点灯。师傅说点灯的人不能怕黑。他怕，我不怕。结果师傅把东岸那条长街给了他，说怕黑的人才知道一盏灯多要紧。我恨了二十年。他每月分我灯油，我收着，心里还骂他。"
        ]),
        .init(id: "south-quay", name: "港务抄账员", errands: [
            .find("south-quay-find", "今天的船期单抄错了一行，开市前就要贴出去。错一行，就有人白跑一趟码头。我、我得找出是哪条船。", question: "哪一行最可能抄错？", [
                ("字写得最潦草的那行", "潦草不等于错。"),
                ("最后一行", "错不挑位置。"),
                ("同一条船出现了两次的那行", "一条船一天只靠一次岸。")], correct: 2,
                  thanks: "果然是重抄了。一条船靠两次岸，账就对不上。还好，还好没贴出去。"),
            .deliver("south-quay-strap", "账本散页了，风一吹满屋子飞。给我两条维修绑带捆一捆。", item: strap, count: 2,
                     thanks: "捆好了。散掉的账本，比撕掉的还难找。"),
            .message("south-quay-message", "替我跟信使说：往后港务处的信别放门口，直接交到我手上。别问为什么。我、我也说不好为什么。",
                     to: "courier", reply: "交到他手上？行。门口那个信箱，我早觉得有人翻过。告诉他，这回不收他加急钱。",
                     thanks: "谢了。这阵子港务处的东西，还是少经几只手的好。")
        ], stories: [
            "抄账是笨活：别人报数，我记数。可数字会说话。一条船吃水深了，账上的货却少了，多出来的是什么？我不问。我胆子小，只敢记。记下来，总有一天会有人来问。但愿那天别太晚。",
            "我爹退下来那天，把用了三十年的笔给我，说账可以抄错，不能抄假。三年前东仓烧完，上头让我把那夜的住客誊一份，‘无归属’的单列。三十一个名字，我一个一个抄进那一栏，字很工整。那支笔，我后来再没用过。"
        ]),
        .init(id: "flower-seller-walk", name: "流动花贩", errands: [
            .deliver("flower-seller-walk-strap", "花筐的背带断了，我背着一筐花走了一上午，肩膀都不是我的了。两条维修绑带，救救我。", item: strap, count: 2,
                     thanks: "系好了。下午能走到东岸。东岸的人买花不还价，都是好人。"),
            .find("flower-seller-walk-find", "有人说在旧街看见我偷剪花商的紫藤。我没有！我脾气是坏，手可干净。", question: "怎么证明不是她？", [
                ("她说自己没有", "说没有不算证据。"),
                ("她筐里的紫藤带着东岸野坡的红土，不是旧街老墙的灰土", "土不会撒谎。"),
                ("她跟花商有过交情", "交情不是证据，何况早就断了。")], correct: 1,
                  thanks: "东岸红土……对，我天不亮就去野坡剪的。谢谢你。我跟花商已经够僵了，不能再添一笔。"),
            .pest("flower-seller-walk-pest", "野坡上有只塔怪守着最好的那片紫藤。我在边上转了三圈，最后只剪了点边角。", [.goldenThroat, .crimsonBrute],
                  thanks: "那片花没被踩坏。我剪两枝最好的给你——拿着，不要钱。别跟花商说，她会笑我学她。")
        ], stories: [
            "我没有摊位，背着筐走遍全城。好处是什么都看得见：谁家换了窗帘，谁家孩子又长高一截。坏处是没人记得我，大家只记得花。我不介意。……好吧，有一点介意。",
            "我以前在花商摊上帮工。走那天，我说她卖花像施舍，她回了我一句，我们就散了。那话是我先说的，也是最狠的一句。我一直想道歉。每回走到她摊前，张了嘴，最后只买一枝花。她每回都多包一片叶子。"
        ]),
        .init(id: "sailor-walk", name: "离港水手", errands: [
            .message("sailor-walk-message", "我明天就走了。替我跟面包师说，给船上留两袋硬面包，钱我放在她门口的罐子里了。",
                     to: "baker", reply: "门口罐子？……又放多了。告诉他，面包装好了，多的钱塞回袋子里。姜片在左边那袋。",
                     thanks: "她又塞姜。……她怎么知道的？"),
            .deliver("sailor-walk-salve", "出海前得带一罐止痛膏。船医那儿的药总不够，轮到我就只剩空罐子了。", item: salve, count: 1,
                     thanks: "带上了。有这罐药，我在海上能少骂两句娘。"),
            .pest("sailor-walk-pest", "我的行李放在码头仓库，里头钻进一只塔怪。我不是不敢去拿，是行李里有样东西，不能让它咬坏。", [.copperback, .copperback],
                  thanks: "保住了。里头有我娘缝的毯子。丢了，我就不走了。")
        ], stories: [
            "每回离港前，我都在码头站一会儿，把城里的声音记下来：钟声、面包房的炉门、乐师跑调的琴。海上太安静。还有，我晕船，十一年了，回回都晕。我谁也没说过。可面包师每回都往我袋子里塞姜片。",
            "我爹一辈子没离开过雾港。走前那天他跟我说，最后悔的是没看过一回别处的日出。所以我替他看，一年两回。说实话，海上的日出跟码头上的差不多。这话我没跟他说。现在也没地方说了。"
        ]),
        .init(id: "archive-apprentice-walk", name: "档案学徒", errands: [
            .find("archive-apprentice-walk-find", "档案馆一卷旧名册里，有一页的装订孔跟别的页对不上。老档案员不在，我不敢乱说，也不敢不说。", question: "这说明什么？", [
                ("这一页是后来补装的，先查补装记录", "孔对不上只说明是后来装的，不说明是假的。"),
                ("这一页是伪造的", "没查记录就说伪造，会冤枉人。"),
                ("装订工手抖", "别的页都对得上。")], correct: 0,
                  thanks: "补装记录写着：那年大水泡坏过一页，照原稿重抄的。差点冤枉了人。我手心全是汗。"),
            .deliver("archive-apprentice-walk-cloth", "档案柜防潮要垫布，过滤布最合适，给我两块。梅雨一来，纸就软得像饼。", item: cloth, count: 2,
                     thanks: "垫上了。纸最怕潮，比怕火还怕。……火也怕。"),
            .pest("archive-apprentice-walk-pest", "档案馆地下室有只塔怪在啃旧卷宗。我一个人不敢下去。老档案员说我胆小，他说得对。", [.moonfang, .goldenThroat],
                  thanks: "卷宗只啃坏了两个角，我照副本补回来。今晚又要抄到半夜了。")
        ], stories: [
            "我进档案馆头一年，抄错过一个数，就一个。码头上有个老人的抚恤因为这个晚发了三个月。我去他家赔不是，他没骂我，给我倒了碗茶。茶是凉的，他家没生火。从那以后，我抄东西比吃饭还慢。",
            "档案里记的都是大事。老档案员说，大事自有人记，小事没人记就真没了。所以我有个自己的本子，每天记一件街上的小事：谁家添了孩子，面包师哪天多烤了一炉，哪个水手回来了。你今天也在上面。"
        ]),
        .init(id: "cafe_keeper", name: "咖啡馆店主", errands: [
            .deliver("cafe-keeper-strap", "咖啡豆麻袋的口绳烂了，给我三条维修绑带扎口。受潮的豆子煮出来一股海腥味，客人喝一口就知道。", item: strap, count: 3,
                     thanks: "扎紧了。一个铜我不让你少拿，一个铜你也别想多拿。"),
            .message("cafe-keeper-message", "替我跟跑堂说：今晚他可以早点回去，灯我来守。别说是我心疼他，就说店里用不着那么多人。",
                     to: "cafe-lane", reply: "早点回去？……不了，我陪店主。一个人守灯太闷。别告诉她，我是怕她一个人。",
                     thanks: "这孩子。那就两个人守吧。我给他留一杯热的，不算钱。"),
            .find("cafe-keeper-find", "店招被人挪了，客人找不着门，今晚等于白开。我得把它挂回原处，一寸都不能差。", question: "该挂回哪里？", [
                ("挂得越高越好", "太高了，路人看不见。"),
                ("看墙上留下的钉孔和晒出来的浅色印子", "晒出的印子就是原来的位置。"),
                ("挂到隔壁门口", "那是别人家的门。")], correct: 1,
                  thanks: "挂回去了。客人说，一看见招牌就知道今晚有地方坐。这话比钱好听。")
        ], stories: [
            "这家店是我娘开的。她定的规矩：港口还有船没回来，灯就不熄。我小时候嫌这规矩傻，费油。现在自己守着才明白，她不是在等船。她是让船上的人知道，岸上有个地方亮着。",
            "三年前东仓着火那夜，我没关门。三十一个人坐满了每一把椅子，还有人蜷在吧台底下。第二天我照常开张，把账记上：咖啡三十一杯，未付。那一页我一直没撕。我是生意人，账得记。可我也没打算去收。"
        ]),
        .init(id: "street_warden", name: "巡街人", errands: [
            .pest("street-warden-pest", "巷子里有两只塔怪。我一个人拦得住一只，拦不住两只。年轻时也许拦得住。", [.crimsonBrute, .moonfang],
                  thanks: "两只都清了。你出手比我的警哨管用。这话别跟我上头说。"),
            .deliver("street-warden-patch", "警哨的铜片磨穿了，吹出来像鸭子叫。给我一片修甲片，我自己剪。", item: patch, count: 1,
                     thanks: "能吹响了。巡街的没有哨子，就像灯没有油。像鸭子叫也不行。"),
            .message("street-warden-message", "替我跟花摊帮工说一声：往后收摊晚了别怕，那条巷子我每晚都会绕过去。别说得像我是特意去的。",
                     to: "market-lane", reply: "……原来每晚那个脚步是他。替我谢谢他。就说我以后不绕远路了。",
                     thanks: "不绕远路就好。怕黑的人一绕路，就会走到更黑的地方去。")
        ], stories: [
            "我闺女小时候也在花摊帮过工，收摊晚，就走那条巷子。我那会儿每晚去巷口接她。后来她嫁到外港去了，一年回来一趟。可到了那个钟点，我这两条腿还是往巷口走。走着走着，又多了个要接的孩子。",
            "我年轻时抓错过一个人。他关了三天，放出来那天没骂我，只说：‘下次看清楚点。’后来码头再没人雇他。我每月往他门口放半袋米。他知道是我，我也知道他知道。街上碰见，点个头，谁也不提。"
        ]),
        .init(id: "scholar", name: "学者", errands: [
            .find("scholar-find", "我手上有两份抄本，一字不差，我想知道哪份更早。这个问题我想了三天，现在轮到你了。", question: "看什么最能分出先后？", [
                ("看哪份纸更旧", "纸可以做旧。"),
                ("看哪份字更好", "字好不说明先后。"),
                ("看后一份有没有照抄前一份的笔误", "照抄的错，会一代一代传下去。")], correct: 2,
                  thanks: "后一份连前一份的笔误也抄了。先后清楚了。你看，错也有它的用处——我这辈子就靠这句话活着。"),
            .deliver("scholar-salve", "我在书堆里熬了三夜，手腕疼得握不住笔。有止痛膏吗？别劝我早睡，劝了也没用。", item: salve, count: 1,
                     thanks: "能握笔了。学问不等人，手腕却要人等。"),
            .message("scholar-message", "替我把这张借条交给档案学徒，我想借那卷补装过的旧名册看看。就说是学者要借——他知道我是谁。应该知道。",
                     to: "archive-apprentice-walk", reply: "那卷？……可以，只能在馆里看，不能带出去。告诉他，我给他留靠窗的位子。他上回一坐就是一整天。",
                     thanks: "靠窗的位子。这孩子懂规矩，也懂人。")
        ], stories: [
            "我研究印章。一枚章能说很多话：谁盖的，用了几分力，章面磨到哪一步。人会撒谎，章不会。可我年轻时替人看过一枚章，收了五个银币，说是真的。其实我没把握。那五个银币是怎么花掉的，我到现在都记得。",
            "我写过三本书，一本也没卖出去。上个月档案学徒说，有人借过我的第二本，我高兴了一整个星期。后来才知道，那人是拿它去垫桌脚的，说厚度正好。……我还是高兴。至少它有用。"
        ]),
        .init(id: "merchant", name: "商人", errands: [
            .deliver("merchant-patch", "货箱的铁角磕坏了，用修甲片补上，给我三片。箱子不体面，货就卖不上价。", item: patch, count: 3,
                     thanks: "补好了。箱子体面，货就好卖一半。另一半靠嘴。"),
            .find("merchant-find", "我进的一批布少了一匹，三个伙计说法不一。我不想冤枉谁，可也不想当傻子。", question: "少的那匹最可能在哪里？", [
                ("对一对入库单和出货单，看哪一天的数没对上", "账对不上的那天，就是丢的那天。"),
                ("先搜伙计的身", "没凭据就搜人，是冤枉人。"),
                ("算了，当作损耗", "该查的要查清。")], correct: 0,
                  thanks: "是出货那天多装了一匹给老主顾。账对清了，谁也没冤枉。我差点就搜了那个新来的孩子。"),
            .pest("merchant-pest", "仓库里有只塔怪在啃布，伙计们都不敢进去。我加钱也不进，这年头，钱都不好使了。", [.moonfang, .copperback],
                  thanks: "只啃坏一匹。工钱照原价算，一个铜不少。")
        ], stories: [
            "我年轻时赔光过家底。是面包师她爹赊了我一个月面包，没立字据，只说：‘以后别让别人饿着就行。’那笔账他不让还。现在谁家揭不开锅，我就悄悄送袋面粉去。面包师不知道。她看我的眼神，像我还欠着。我是还欠着。",
            "三年前东仓起火那夜，满街的人要毯子。我仓里有两百条，平时卖三个铜，那晚我卖十一个，全卖光了。第二天听说，码头上有人冻坏了脚。现在每年入冬，我都按本钱卖毯子。没人知道为什么，也别让他们知道。"
        ]),
        .init(id: "visitor", name: "旅人", errands: [
            .message("visitor-message", "我想给家里寄封信，可找不着雾港的邮差。你替我交给他吧。我写了三页，全是这座城。",
                     to: "postman", reply: "外地的信？寄到南边的……好，明早头一趟船带走。三页？邮票贴得不够。算了，我补上。",
                     thanks: "谢谢！家里人会高兴的。我写了钟声，写了雾，还写了你。"),
            .find("visitor-find", "我迷路了。只记得旅店门口有棵紫藤，傍晚回去时，钟楼的影子正好落在门口台阶上。", question: "旅店最可能在哪儿？", [
                ("旧街，那里紫藤多", "紫藤到处都有，指不了路。"),
                ("钟楼广场边上——影子能落到门口的只有那几间", "影子比紫藤靠得住。"),
                ("东岸", "东岸离钟楼太远，影子够不着。")], correct: 1,
                  thanks: "找到了！老板娘以为我被海浪卷走了，还给我留着汤。"),
            .pest("visitor-pest", "我想去旧港区看看，祖父说他小时候在那儿捡过贝壳。可路口有只塔怪拦着，我不敢过去。", [.crimsonBrute, .goldenThroat],
                  thanks: "路通了。……旧港区没想的那么可怕，就是太安静了，安静得像有人刚走。")
        ], stories: [
            "我是来找祖父出生的那间房子的。他走前说，雾港的钟和别处不一样，一听就知道到家了。我下船头一天就听见了——他说得对。可他为什么五十年没回来过，他没说。",
            "登记员替我查到了：祖父家原来的门牌，现在是一间仓库。仓库主人让我进去站了一会儿。墙角有两道量身高的刻痕。一道刻着祖父的名字。另一道是个女孩的名字，刻到我腰那么高，就没有了。祖父从没说过他有个妹妹。"
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
        // Playtest 2026-10-04: day one had nothing to do after Q3. Two
        // neighbours from the far end of the rotation ask once on day one,
        // leaving the day-two-onward rotation exactly as designed.
        if day == 1 { return Array(all.suffix(2)) }
        let count = askerCount(day: day)
        guard count > 0 else { return [] }
        let start = rotationStart(day: day)
        return (0..<count).map { all[(start + $0) % all.count] }
    }

    /// Position in `rotation` of the day's first asker.
    public static func rotationStart(day: Int) -> Int {
        day <= firstDay ? 0 : (firstDay..<day).reduce(0) { $0 + askerCount(day: $1) } % all.count
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
        /// A user-requested retry of an already-paid offer; absent in older saves.
        public fileprivate(set) var replayWithoutReward: Bool?
        /// How the player will finish it (MPCNeighborCatalog.ways); absent in older saves.
        public fileprivate(set) var way: MPCCityFaction?
        public var errand: MPCNeighborErrand? { MPCNeighborCatalog.errand(errandID)?.errand }
        public var chosenWay: MPCErrandWay? { way.flatMap { side in MPCNeighborCatalog.ways(errandID).first { $0.side == side } } }
    }
    public struct Reward: Codable, Equatable, Sendable {
        public let copper: Int
        public let thanks: String
        public let affinity: Int
        /// A story unlocked by this errand, if it reached a story level.
        public let story: String?
        /// The way it was finished, for the city trend (nil if none was chosen).
        public var way: MPCErrandWay? = nil
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
    /// `trend`: yesterday's paper; the side out in front and the side behind send their people
    /// (MPCNeighborCatalog.askers(day:trend:)). Without it, the plain rotation.
    @discardableResult
    public mutating func open(day: Int, completedMissions: Set<Int>, trend: MPCCityTrendSnapshot? = nil) -> [Offer] {
        guard day > self.day else { return offers }
        self.day = day
        offers = offers.filter { $0.activeTicket != nil }
        let workshop = MPCCraftingCatalog.isUnlocked(completedMissions: completedMissions)
        for neighbor in MPCNeighborCatalog.askers(day: day, trend: trend) {
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

    /// Reopens only this completed offer once, keeping its old payout and fight receipts.
    @discardableResult
    public mutating func reopenCompletedOfferForReplay(_ offerID: String) throws -> Bool {
        guard let i = offers.firstIndex(where: { $0.id == offerID }) else { throw Failure.notOffered }
        guard offers[i].activeTicket == nil else { throw Failure.pending }
        guard offers[i].done, offers[i].replayWithoutReward != true else { return false }
        offers[i].replayWithoutReward = true
        offers[i].done = false
        offers[i].excludedChoiceIDs = []
        return true
    }

    /// Picks how an open errand will be finished; it can change until the errand is done.
    /// Both ways pay the same; the choice only counts for the city trend.
    public mutating func choose(offerID: String, way side: MPCCityFaction) throws {
        guard let i = offers.firstIndex(where: { $0.id == offerID }) else { throw Failure.notOffered }
        guard !offers[i].done else { throw Failure.done }
        guard MPCNeighborCatalog.ways(offers[i].errandID).contains(where: { $0.side == side }) else { throw Failure.invalidChoice }
        offers[i].way = side
    }

    private mutating func complete(_ i: Int, _ errand: MPCNeighborErrand, coins: inout Int) -> Reward {
        offers[i].done = true
        let id = offers[i].neighborID
        let way = offers[i].chosenWay
        if offers[i].replayWithoutReward == true {
            return .init(copper: 0, thanks: errand.thanks, affinity: affinity[id, default: 0], story: nil, way: nil)
        }
        affinity[id, default: 0] += 1
        completedErrands += 1
        let level = affinity[id]!
        let stories = MPCNeighborCatalog.neighbor(id)?.stories ?? []
        coins += errand.copper
        return .init(copper: errand.copper, thanks: errand.thanks, affinity: level,
                     story: zip(MPCNeighborCatalog.storyAffinity, stories).first { $0.0 == level }?.1, way: way)
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

    /// Street tasks (urgent errands, joint errands) raise a neighbour's affinity too. The
    /// street task ledger pays each finished task once, so this is called once per task.
    /// Returns the story unlocked at the new level, if any.
    @discardableResult
    public mutating func raiseAffinity(_ neighborID: String) -> String? {
        guard let neighbor = MPCNeighborCatalog.neighbor(neighborID) else { return nil }
        affinity[neighborID, default: 0] += 1
        let level = affinity[neighborID]!
        return zip(MPCNeighborCatalog.storyAffinity, neighbor.stories).first { $0.0 == level }?.1
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
